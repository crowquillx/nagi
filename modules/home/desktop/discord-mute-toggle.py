#!/usr/bin/env python3
"""Toggle Discord mute from one physical mouse button.

The forward button is consumed by the grabbed physical device and all other
mouse events are relayed through a virtual device.  Discord is queried afresh
for every accepted press so tray restarts do not leave stale menu ids around.
"""

import argparse
from contextlib import closing
import fcntl
import json
import logging
import os
import queue
import select
import signal
import subprocess
import threading
import time

from evdev import InputDevice, UInput, ecodes


WATCHER = 'org.kde.StatusNotifierWatcher'
ITEM = 'org.kde.StatusNotifierItem'
MENU = 'com.canonical.dbusmenu'
LOCK_NAME = 'nagi-discord-mute-toggle.lock'


def bus(*args, json_output=True):
    command = ['busctl', '--user', '--timeout=1s']
    if json_output:
        command.append('--json=short')
    result = subprocess.run(command + list(args), capture_output=True, text=True,
                            timeout=2, check=True)
    return json.loads(result.stdout)['data'] if json_output else None


def property_value(destination, path, interface, name):
    return bus('get-property', destination, path, interface, name)


def menu_nodes(node):
    if isinstance(node, dict):
        node = node['data']
    yield node
    for child in node[2]:
        yield from menu_nodes(child)


def discord_mute_item():
    entries = property_value(WATCHER, '/StatusNotifierWatcher', WATCHER,
                             'RegisteredStatusNotifierItems')
    matches = []
    for entry in entries:
        destination, separator, suffix = entry.partition('/')
        path = '/' + suffix if separator else '/StatusNotifierItem'
        try:
            identity = property_value(destination, path, ITEM, 'Id')
            if not identity.startswith('discord_status_icon_'):
                continue
            menu_path = property_value(destination, path, ITEM, 'Menu')
            layout = bus('call', '--', destination, menu_path, MENU, 'GetLayout',
                         'iias', '0', '-1', '3', 'label', 'toggle-state', 'enabled')
            for item_id, properties, _ in menu_nodes(layout[1]):
                label = properties.get('label', {}).get('data', '')
                if label.replace('&', '').replace('_', '') != 'Mute':
                    continue
                if not properties.get('enabled', {}).get('data', True):
                    continue
                matches.append((destination, menu_path, item_id,
                                properties.get('toggle-state', {}).get('data')))
        except (subprocess.SubprocessError, KeyError, ValueError, TypeError):
            continue
    if len(matches) != 1:
        raise RuntimeError(f'Expected one Discord Mute control; found {len(matches)}')
    return matches[0]


def toggle_discord(cancelled=None):
    destination, path, item_id, _ = discord_mute_item()
    # A timed-out click may already have run, so never retry it automatically.
    if cancelled is not None and cancelled():
        return False
    bus('call', '--', destination, path, MENU, 'Event', 'isvu', str(item_id),
        'clicked', 'i', '0', '0', json_output=False)
    return True


class PressFilter:
    """Accept one physical down event until its matching release."""

    def __init__(self, button, held=False):
        self.button = button
        self.held = held
        self.dropped = False

    def accept(self, kind, code, value, current_held):
        if kind == ecodes.EV_SYN and code == ecodes.SYN_DROPPED:
            self.dropped = True
        if self.dropped:
            if kind == ecodes.EV_SYN and code == ecodes.SYN_REPORT:
                self.held = current_held()
                self.dropped = False
            return False
        if kind != ecodes.EV_KEY or code != self.button:
            return False
        if value == 0:
            self.held = False
        elif value == 1 and not self.held:
            self.held = True
            return True
        return False


class MouseRelay:
    def __init__(self, device, virtual, button, on_press):
        self.device = device
        self.virtual = virtual
        self.button = button
        self.on_press = on_press
        self.presses = PressFilter(button)
        self.forwarded_keys = set()
        self.dropped = False

    def handle(self, event):
        if event.type == ecodes.EV_SYN and event.code == ecodes.SYN_DROPPED:
            self.dropped = True
            return
        if self.dropped:
            if event.type == ecodes.EV_SYN and event.code == ecodes.SYN_REPORT:
                held = set(self.device.active_keys())
                wanted = held - {self.button}
                for code in self.forwarded_keys - wanted:
                    self.virtual.write(ecodes.EV_KEY, code, 0)
                for code in wanted - self.forwarded_keys:
                    self.virtual.write(ecodes.EV_KEY, code, 1)
                self.virtual.syn()
                self.forwarded_keys = wanted
                self.presses.held = self.button in held
                self.dropped = False
            return
        if event.type == ecodes.EV_KEY and event.code == self.button:
            if self.presses.accept(event.type, event.code, event.value, lambda: False):
                self.on_press()
            return
        self.virtual.write_event(event)
        if event.type == ecodes.EV_KEY:
            if event.value == 1:
                self.forwarded_keys.add(event.code)
            elif event.value == 0:
                self.forwarded_keys.discard(event.code)

    def release(self):
        for code in tuple(self.forwarded_keys):
            self.virtual.write(ecodes.EV_KEY, code, 0)
        self.forwarded_keys.clear()
        self.virtual.syn()


def _validate_mouse(mouse, button):
    capabilities = mouse.capabilities()
    relative_axes = set(capabilities.get(ecodes.EV_REL, ()))
    if not {ecodes.REL_X, ecodes.REL_Y}.issubset(relative_axes):
        raise RuntimeError('Configured device is not a relative mouse')
    if button not in set(capabilities.get(ecodes.EV_KEY, ())):
        raise RuntimeError(f'Configured device does not provide button {button}')


def _drain_input(mouse, stopping=None):
    while stopping is None or not stopping.is_set():
        had_events = False
        try:
            for _ in mouse.read():
                had_events = True
                if stopping is not None and stopping.is_set():
                    return False
        except BlockingIOError:
            return True
        if not had_events:
            return True
    return False


def _grab_after_release(mouse, stopping):
    waiting = False
    while not stopping.is_set():
        if mouse.active_keys():
            if not waiting:
                logging.info('Mouse buttons held; waiting for release before listening')
                waiting = True
            if stopping.wait(0.05):
                return False
            continue
        waiting = False
        # Events queued before the exclusive grab must not become a startup
        # toggle when they are delivered to the new worker.
        if not _drain_input(mouse, stopping):
            return False
        if stopping.is_set():
            return False
        grabbed = False
        try:
            mouse.grab()
            grabbed = True
            if stopping.is_set():
                mouse.ungrab()
                return False
            # A press can race the pre-grab active_keys check.  Drop this
            # attempt and wait for release rather than dispatching it.
            if mouse.active_keys():
                mouse.ungrab()
                grabbed = False
                waiting = True
                continue
            if not _drain_input(mouse, stopping):
                mouse.ungrab()
                return False
            return True
        except Exception:
            if grabbed:
                try:
                    mouse.ungrab()
                except OSError:
                    pass
            raise
    return False


def _toggle_worker(stopping, disconnected, clicks, observe):
    while not stopping.is_set() and not disconnected.is_set():
        try:
            pressed_at = clicks.get(timeout=0.25)
        except queue.Empty:
            continue
        def cancelled():
            return (stopping.is_set() or disconnected.is_set() or
                    time.monotonic() - pressed_at > 2)

        if cancelled():
            continue
        if observe:
            logging.info('Forward button consumed; observe mode')
            continue
        try:
            if toggle_discord(cancelled):
                logging.info('Forward button consumed: Discord mute toggle sent')
        except (RuntimeError, subprocess.SubprocessError, ValueError) as error:
            # In particular, do not retry a busctl timeout: the click may have
            # reached Discord even when its reply did not arrive.
            logging.error('Toggle failed; no retry: %s', error)


def _release_relay(relay, mouse):
    try:
        relay.release()
    except (OSError, RuntimeError) as error:
        logging.debug('Could not release virtual mouse buttons: %s', error)
    try:
        mouse.ungrab()
    except OSError:
        pass


def listen_once(device, button, observe, stopping):
    with closing(InputDevice(device)) as mouse:
        _validate_mouse(mouse, button)
        with UInput.from_device(device, name='nagi-discord-mouse',
                                phys='nagi/discord-mouse') as virtual:
            if not _grab_after_release(mouse, stopping):
                return
            disconnected = threading.Event()
            clicks = queue.Queue(maxsize=8)
            relay = MouseRelay(mouse, virtual, button, lambda: _enqueue_click(clicks))
            worker = threading.Thread(target=_toggle_worker,
                                      args=(stopping, disconnected, clicks, observe), daemon=True)
            worker.start()
            try:
                logging.info('Ready: button %s toggles Discord only; other mouse input is forwarded', button)
                while not stopping.is_set():
                    if not select.select([mouse.fd], [], [], 0.25)[0]:
                        continue
                    for event in mouse.read():
                        relay.handle(event)
            finally:
                disconnected.set()
                _release_relay(relay, mouse)
                worker.join(timeout=0.5)


def _enqueue_click(clicks):
    try:
        clicks.put_nowait(time.monotonic())
    except queue.Full:
        logging.warning('Toggle queue full; press skipped')


def listen(device, button, observe):
    runtime = os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')
    lock_path = os.path.join(runtime, LOCK_NAME)
    stop = threading.Event()

    def stop_signal(_signum, _frame):
        stop.set()

    signal.signal(signal.SIGTERM, stop_signal)
    signal.signal(signal.SIGINT, stop_signal)
    with open(lock_path, 'a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise RuntimeError(f'another Discord mute toggle already holds {lock_path}') from error

        waiting_logged = False
        while not stop.is_set():
            try:
                listen_once(device, button, observe, stop)
                waiting_logged = False
            except OSError as error:
                if not waiting_logged:
                    logging.warning('Mouse unavailable; retrying in 1s: %s', error)
                    waiting_logged = True
                stop.wait(1.0)
        logging.info('Stopped; normal mouse input restored; Discord mute unchanged')


def main(argv=None):
    parser = argparse.ArgumentParser(description='Toggle Discord mute with a mouse button')
    parser.add_argument('--device', required=True,
                        help='mouse event device (for example /dev/input/by-id/...)')
    parser.add_argument('--button', type=int, default=276, choices=range(768), metavar='CODE')
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--status', action='store_true')
    modes.add_argument('--observe', action='store_true')
    args = parser.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format='%(asctime)s %(message)s')
    if args.status:
        destination, path, item_id, state = discord_mute_item()
        print(json.dumps({'destination': destination, 'menu': path, 'item_id': item_id,
                          'reported_muted': state,
                          'note': 'Tray state may be stale outside voice'}))
        return 0
    listen(args.device, args.button, args.observe)
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError, ValueError) as error:
        logging.error('%s', error)
        raise SystemExit(1)
