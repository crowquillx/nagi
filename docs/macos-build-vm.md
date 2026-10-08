# Local macOS build VM

## Selected toolchain

The current target is macOS Tahoe 26.6.2 with stable Xcode 26.6. Xcode 26.6
supports Tahoe 26.2 and later and includes the tvOS 26.5 SDK and Swift 6.3.
Xcode 27 is stable but Apple-silicon-only, so it is not suitable for this
x86_64 host. The selected versions match [Apple's current Xcode requirements]
(https://developer.apple.com/xcode/system-requirements), [Xcode 27 release
notes](https://developer.apple.com/documentation/Xcode-Release-Notes/xcode-27-release-notes),
and [Tahoe 26.6.2 update information](https://support.apple.com/en-ca/122868).

The inspected Vivid `personal-tvos` branch requires Xcode 26.3 or newer,
generates `Vivid.xcodeproj` with XcodeGen, uses scheme `VividTV`, and targets
tvOS 26.0. Silo requires Xcode 26 or newer and also targets tvOS 26.0. Xcode
26.6 meets both project requirements.

## Host and VM

- Host: NixOS `tandesk`, AMD Ryzen 7 5800X, 8 cores / 16 threads, 32 GiB RAM.
- VM: 8 vCPUs, 16 GiB RAM, Q35, OVMF UEFI, KVM, and a simple VMware virtual
  display. The NVIDIA GPU is not passed through.
- The guest CPU uses the current OSX-KVM Tahoe-compatible Skylake-Client
  profile, with GenuineIntel vendor, `invtsc`, disabled HLE/RTM, and
  `vmware-cpuid-freq`. The final QEMU CPU option adds a timing property that
  libvirt's CPU feature map does not expose. KVM still accelerates execution
  on the AMD host. The
  host KVM `ignore_msrs` setting is enabled for this macOS VM configuration;
  a reboot is needed before that kernel parameter takes effect.
- Image directory: `/var/lib/libvirt/images/macos-build-vm/`, on the P5 NVMe
  that backs `/var` and the existing libvirt image storage.
- System disk: `macbuild-system.qcow2`, with a 256 GiB virtual maximum.
  `qemu-img create` disables preallocation, so the host file starts small and
  grows as macOS writes blocks. `macvm-storage` shows the virtual maximum and
  current host allocation. Guest deletes may not reduce host allocation unless
  macOS sends discard/TRIM for those blocks.
- OpenCore, Apple recovery files, and `OVMF_VARS.fd` are stored beside the
  system disk. Back up `OpenCore.qcow2` and `OVMF_VARS.fd` separately from the
  large system disk. Shut the VM down before copying the system disk; use
  `cp --sparse=always` to preserve its sparse allocation.
- The VM does not autostart.

## Network and access

The guest has two virtual interfaces. One attaches in macvtap bridge mode to
the wired `enp5s0` connection, so it can receive its own LAN address and LAN
multicast. The second uses QEMU user-mode networking and forwards guest SSH to
`127.0.0.1:2222`. The SSH forward is loopback-only; no host firewall port is
opened. The existing NetworkManager profile is not changed.

The QEMU user-mode interface makes host-to-guest SSH stable even though macvtap
does not provide the host a direct path to the guest's LAN interface. The Home
Manager alias is `macbuild`, so use `ssh macbuild`. Guest LAN discovery uses
the guest's Bonjour name, set to `macbuild.local` during first setup. After
the guest is installed, check Apple TV discovery with:

```sh
macvm-ssh dns-sd -B _airplay._tcp local
```

This needs a live LAN test. If multicast discovery does not work over the
physical NIC's macvtap link, basic builds and SSH remain available through the
loopback-only QEMU user-mode forward. No broad Avahi reflector is configured.

## Commands

```sh
macvm-prepare        # pinned OpenCore and Apple Tahoe recovery; sparse disk
macvm-define         # define the persistent libvirt domain
macvm-start
macvm-status
macvm-console        # local SPICE window through virt-viewer
macvm-ssh
macvm-stop           # ACPI shutdown, waits up to 120 seconds
macvm-force-stop     # emergency power-off
macvm-storage        # virtual disk limit and current host allocation
```

The first macOS installation needs the graphical console. Start the VM and
open `macvm-console`. Use Disk Utility to erase `macbuild-system.qcow2` as
APFS/GUID, then run the macOS recovery installer. The VM has no guest SSH until
Remote Login is enabled.

In macOS, create the local account `tan`, set Computer Name to `macbuild`, and
enable **System Settings → General → Sharing → Remote Login** for that account.
Then run `macvm-enroll-key` once from NixOS. It asks for the guest account
password to install the dedicated host key; the password is not saved. Use
`macvm-guest-setup` after Xcode is installed.

The VM is manual/on-demand. `macvm-stop` sends a graceful ACPI shutdown. Use
`macvm-force-stop` only if the guest does not shut down.

## Xcode and guest setup

Download the stable Xcode 26.6 `.xip` from Apple's developer downloads using
your own Apple account session. Extract it inside the guest to
`/Applications/Xcode.app`. Do not place Apple credentials in this repository,
Nix, or shell history. Then run `macvm-guest-setup`. It selects that Xcode,
shows the Xcode licence for interactive acceptance, runs first-launch setup,
installs Homebrew only if needed, installs XcodeGen, and prints:

```sh
xcodebuild -version
xcrun --sdk appletvos --show-sdk-version
swift --version
xcodegen --version
```

The licence command is interactive. The helper does not accept the Xcode
licence on your behalf.

## Source and build workflow

Sync a local worktree without `.git` for quick iteration:

```sh
macvm-sync /home/tan/REPOS/vivid
```

Or push a private branch and fetch it from the guest with Git over SSH. Keep
working source under `~/Developer`, not in the Nix store.

For the inspected Vivid checkout (`personal-tvos`, commit `6c76a7c`):

```sh
macvm-ssh bash -lc 'cd ~/Developer/<project>/iosApp && xcodegen generate --spec project.yml && xcodebuild -resolvePackageDependencies -project Vivid.xcodeproj -scheme VividTV && xcodebuild -list -project Vivid.xcodeproj'

macvm-build <project> \
  -project iosApp/Vivid.xcodeproj \
  -scheme VividTV \
  -destination 'generic/platform=tvOS' \
  -archivePath iosApp/build/tvos-unsigned/VividTV.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= CODE_SIGN_ENTITLEMENTS= \
  archive
```

Package an existing app as an unsigned IPA, then retrieve it:

```sh
macvm-package-ipa ~/Developer/<project>/iosApp/build/tvos-unsigned/VividTV.xcarchive/Products/Applications/VividTV.app
macvm-fetch-ipa Developer/artifacts/VividTV-tvOS-unsigned.ipa
```

The guest creates `~/Developer/artifacts/VividTV-tvOS-unsigned.ipa`; the host
retrieves it into `./artifacts/`. The package contains `Payload/App.app` and
preserves nested frameworks and extensions. It is unsigned and is not directly
installable. It is intended for a later, separate signing workflow.

`macvm-build-and-copy` can also sync the IPA to a directory on `tanmedia`:

```sh
macvm-build-and-copy <project> <guest-app-path> /path/on/tanmedia -- <xcodebuild arguments...>
```

The destination is explicit. This does not change or expose atvloadly and does
not add Apple credentials to the transfer. tanmedia's existing SSH access and
atvloadly service were reachable during inspection; no changes were made there.

## Updating and recovery

- Update macOS through the guest's normal Software Update UI.
- Download and extract a newer stable Xcode from Apple's developer downloads,
  then run `macvm-guest-setup` and confirm the selected versions.
- `macvm-prepare` pins OSX-KVM support files to commit
  `4c378a4b5e0b219783683012bec680325eb40719`; review and update that pin
  deliberately rather than replacing OpenCore automatically.
- If OpenCore settings are damaged, stop the VM and restore the separate
  `OpenCore.qcow2` backup. Keep an offline backup of `OVMF_VARS.fd` as well.
- If macOS recovery fails, leave the system disk intact and inspect the SPICE
  console and libvirt log before retrying. The Apple recovery image is fetched
  directly by the pinned OSX-KVM downloader; no preinstalled third-party VM
  image is used.

## Platform and licence limits

This is non-Apple AMD hardware. Apple does not support macOS virtualization on
this host, and [the current Tahoe software licence](https://www.apple.com/legal/sla/docs/macOSTahoe.pdf)
Section 2J says macOS may not be installed or run on a non-Apple-branded
computer. The VM setup does not make that use licensed or supported. Do not
proceed with the macOS installation unless you have resolved that restriction
for your use. There is no NVIDIA passthrough or macOS NVIDIA driver. Apple TV
multicast discovery remains unverified until the guest is running on the LAN.
