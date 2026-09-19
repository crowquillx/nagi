import importlib.util
import os
from pathlib import Path
import subprocess
import threading
import unittest
from types import SimpleNamespace
from unittest.mock import patch


MODULE_PATH = Path(os.environ.get(
    'NAGI_DISCORD_MUTE_TOGGLE',
    Path(__file__).parents[1] / 'modules/home/desktop/discord-mute-toggle.py',
))
spec = importlib.util.spec_from_file_location('discord_mute_toggle', MODULE_PATH)
app = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(app)


class ToggleTests(unittest.TestCase):
    def test_lost_events_resync_other_buttons_without_toggling_discord(self):
        written = []
        virtual = SimpleNamespace(write=lambda *event: written.append(event), syn=lambda: None)
        device = SimpleNamespace(active_keys=lambda: [273, 276])
        clicked = []
        relay = app.MouseRelay(device, virtual, 276, lambda: clicked.append(True))
        relay.forwarded_keys = {272}
        for kind, code, value in [(0, 3, 0), (1, 276, 1), (0, 0, 0)]:
            relay.handle(SimpleNamespace(type=kind, code=code, value=value))
        self.assertEqual(written, [(1, 272, 0), (1, 273, 1)])
        self.assertEqual(clicked, [])
        self.assertTrue(relay.presses.held)
        relay.release()
        self.assertEqual(written[-1], (1, 273, 0))

    def test_only_forward_button_is_consumed(self):
        class VirtualMouse:
            def __init__(self):
                self.events = []

            def write_event(self, event):
                self.events.append((event.type, event.code, event.value))

        virtual = VirtualMouse()
        clicked = []
        relay = app.MouseRelay(None, virtual, 276, lambda: clicked.append(True))
        events = [(2, 0, 4), (1, 272, 1), (1, 276, 1), (1, 276, 2),
                  (0, 0, 0), (1, 276, 0), (1, 272, 0), (2, 8, -1), (0, 0, 0)]
        for kind, code, value in events:
            relay.handle(SimpleNamespace(type=kind, code=code, value=value))
        self.assertEqual(clicked, [True])
        self.assertEqual(virtual.events, [event for event in events if event[:2] != (1, 276)])
        self.assertEqual(relay.forwarded_keys, set())

    def test_duplicate_down_is_suppressed_until_release(self):
        presses = app.PressFilter(276)
        events = [(1, 275, 1), (1, 276, 1), (1, 276, 2), (1, 276, 1),
                  (1, 276, 0), (1, 276, 1), (1, 276, 0)]
        result = [presses.accept(*event, lambda: False) for event in events]
        self.assertEqual(result, [False, True, False, False, False, True, False])

    def test_dropped_events_do_not_replay_a_press(self):
        presses = app.PressFilter(276)
        for event in [(0, 3, 0), (1, 276, 1), (0, 0, 0), (1, 276, 1)]:
            self.assertFalse(presses.accept(*event, lambda: True))
        presses.accept(1, 276, 0, lambda: False)
        self.assertTrue(presses.accept(1, 276, 1, lambda: True))

    def test_discord_restart_uses_new_menu_item_and_hidden_item(self):
        session = {'destination': ':1.92', 'item_id': 30}
        clicks = []

        def fake_bus(*args, json_output=True):
            if args[0] == 'get-property':
                if args[-1] == 'RegisteredStatusNotifierItems':
                    return [':1.1/StatusNotifierItem', session['destination'] + '/StatusNotifierItem']
                if args[-1] == 'Id':
                    return 'spotify' if args[1] == ':1.1' else 'discord_status_icon_1'
                if args[-1] == 'Menu':
                    return '/com/canonical/dbusmenu'
            if 'GetLayout' in args:
                return [1, [0, {}, [{'type': '(ia{sv}av)', 'data': [session['item_id'], {
                    'label': {'type': 's', 'data': 'Mute'},
                    'visible': {'type': 'b', 'data': False},
                    'toggle-state': {'type': 'i', 'data': 0}}, []]}]]]
            if 'Event' in args:
                clicks.append(args)
                self.assertFalse(json_output)
                return None
            self.fail(args)

        with patch.object(app, 'bus', side_effect=fake_bus):
            app.toggle_discord()
            session.update(destination=':1.200', item_id=77)
            app.toggle_discord()
        self.assertEqual(len(clicks), 2)
        self.assertEqual((clicks[0][2], clicks[0][7]), (':1.92', '30'))
        self.assertEqual((clicks[1][2], clicks[1][7]), (':1.200', '77'))

    def test_ambiguous_click_timeout_is_never_retried(self):
        with patch.object(app, 'discord_mute_item', return_value=(':1.2', '/menu', 3, 0)), \
                patch.object(app, 'bus', side_effect=subprocess.TimeoutExpired('busctl', 2)) as request:
            with self.assertRaises(subprocess.TimeoutExpired):
                app.toggle_discord()
        self.assertEqual(request.call_count, 1)

    def test_start_waits_for_held_button_and_drops_startup_queue(self):
        class Mouse:
            def __init__(self):
                self.states = iter(([276], [], []))
                self.reads = 0
                self.grabs = 0
                self.ungrabs = 0

            def active_keys(self):
                return next(self.states)

            def read(self):
                self.reads += 1
                return []

            def grab(self):
                self.grabs += 1

            def ungrab(self):
                self.ungrabs += 1

        mouse = Mouse()
        self.assertTrue(app._grab_after_release(mouse, threading.Event()))
        self.assertEqual(mouse.grabs, 1)
        self.assertEqual(mouse.ungrabs, 0)
        self.assertEqual(mouse.reads, 2)

    def test_startup_press_race_ungrabs_and_waits_again(self):
        class Mouse:
            def __init__(self):
                self.states = iter(([], [276], [276], [], []))
                self.grabs = 0
                self.ungrabs = 0

            def active_keys(self):
                return next(self.states)

            def read(self):
                return []

            def grab(self):
                self.grabs += 1

            def ungrab(self):
                self.ungrabs += 1

        mouse = Mouse()
        self.assertTrue(app._grab_after_release(mouse, threading.Event()))
        self.assertEqual(mouse.grabs, 2)
        self.assertEqual(mouse.ungrabs, 1)

    def test_startup_drain_consumes_multiple_input_batches(self):
        class Mouse:
            def __init__(self):
                self.batches = iter(([(1, 276, 1)], [(1, 276, 0)], [], []))
                self.reads = 0

            def active_keys(self):
                return []

            def read(self):
                self.reads += 1
                return next(self.batches)

            def grab(self):
                pass

            def ungrab(self):
                pass

        mouse = Mouse()
        self.assertTrue(app._grab_after_release(mouse, threading.Event()))
        self.assertEqual(mouse.reads, 4)

    def test_cancelled_discovery_does_not_dispatch_event(self):
        disconnected = threading.Event()

        def discovery():
            disconnected.set()
            return (':1.2', '/menu', 3, 0)

        with patch.object(app, 'discord_mute_item', side_effect=discovery), \
                patch.object(app, 'bus') as request:
            self.assertFalse(app.toggle_discord(disconnected.is_set))
        request.assert_not_called()

    def test_cleanup_releases_forwarded_buttons_and_ungrabs(self):
        writes = []
        relay = SimpleNamespace(
            release=lambda: writes.append('released'),
        )
        mouse = SimpleNamespace(ungrab=lambda: writes.append('ungrabbed'))
        app._release_relay(relay, mouse)
        self.assertEqual(writes, ['released', 'ungrabbed'])


if __name__ == '__main__':
    unittest.main()
