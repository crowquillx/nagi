{
  config,
  lib,
  pkgs,
  ...
}:
let
  v = config.nagi.variables.features.virtualisation.macosBuilder;
  enabled = v.enable;
  dataDir = "/var/lib/libvirt/images/macos-build-vm";
  ovmf = pkgs.OVMFFull.fd;

  domainXml = pkgs.writeText "macbuild-domain.xml" ''
    <domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
      <name>macbuild</name>
      <memory unit='MiB'>${toString v.memoryMiB}</memory>
      <currentMemory unit='MiB'>${toString v.memoryMiB}</currentMemory>
      <vcpu placement='static'>${toString v.vcpus}</vcpu>
      <os>
        <type arch='x86_64' machine='q35'>hvm</type>
        <loader readonly='yes' type='pflash'>${ovmf}/FV/OVMF_CODE.fd</loader>
        <nvram template='${ovmf}/FV/OVMF_VARS.fd'>${dataDir}/OVMF_VARS.fd</nvram>
      </os>
      <features>
        <acpi/>
        <apic/>
        <smm state='on'/>
      </features>
      <cpu mode='custom' match='exact' check='none'>
        <model fallback='allow'>Skylake-Client</model>
        <vendor>GenuineIntel</vendor>
        <topology sockets='1' dies='1' cores='${toString v.vcpus}' threads='1'/>
        <feature policy='require' name='invtsc'/>
        <feature policy='disable' name='hle'/>
        <feature policy='disable' name='rtm'/>
      </cpu>
      <clock offset='localtime'>
        <timer name='rtc' tickpolicy='catchup'/>
        <timer name='hpet' present='no'/>
      </clock>
      <devices>
        <controller type='sata' index='0'/>
        <controller type='usb' model='qemu-xhci'/>
        <disk type='file' device='disk'>
          <driver name='qemu' type='qcow2' cache='none'/>
          <source file='${dataDir}/OpenCore.qcow2'/>
          <target dev='sda' bus='sata'/>
          <boot order='1'/>
        </disk>
        <disk type='file' device='cdrom'>
          <driver name='qemu' type='raw' cache='none'/>
          <source file='${dataDir}/BaseSystem.img'/>
          <target dev='sdb' bus='sata'/>
          <boot order='2'/>
        </disk>
        <disk type='file' device='disk'>
          <driver name='qemu' type='qcow2' cache='none' discard='unmap'/>
          <source file='${dataDir}/macbuild-system.qcow2'/>
          <target dev='sdc' bus='sata'/>
          <boot order='3'/>
        </disk>
        <interface type='direct'>
          <mac address='52:54:00:ca:fe:01'/>
          <source dev='${lib.escapeXML v.ethernetInterface}' mode='bridge'/>
          <model type='virtio'/>
        </interface>
        <input type='keyboard' bus='usb'/>
        <input type='tablet' bus='usb'/>
        <graphics type='spice' autoport='yes' listen='127.0.0.1'>
          <listen type='address' address='127.0.0.1'/>
        </graphics>
        <video>
          <model type='none'/>
        </video>
        <memballoon model='none'/>
      </devices>
      <qemu:commandline>
        <qemu:arg value='-device'/>
        <qemu:arg value='vmware-svga'/>
        <qemu:arg value='-device'/>
        <qemu:arg value='isa-applesmc,osk=ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc'/>
        <qemu:arg value='-smbios'/>
        <qemu:arg value='type=2'/>
        <qemu:arg value='-netdev'/>
        <qemu:arg value='user,id=net1,hostfwd=tcp:127.0.0.1:${toString v.sshPort}-:22'/>
        <qemu:arg value='-device'/>
        <qemu:arg value='virtio-net-pci,netdev=net1,id=net1,mac=52:54:00:ca:fe:02'/>
        <!-- Current QEMU has a timing property absent from libvirt's CPU feature map. -->
        <qemu:arg value='-cpu'/>
        <qemu:arg value='Skylake-Client,-hle,-rtm,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check'/>
      </qemu:commandline>
    </domain>
  '';

  macvm = pkgs.writeShellApplication {
    name = "macvm";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.dmg2img
      pkgs.git
      pkgs.libvirt
      pkgs.openssh
      pkgs.python3
      pkgs.qemu
      pkgs.rsync
      pkgs.virt-viewer
    ];
    text = ''
      export MACVM_DATA_DIR=${lib.escapeShellArg dataDir}
      export MACVM_DOMAIN_XML=${lib.escapeShellArg (toString domainXml)}
      export MACVM_REFERENCE_COMMIT=4c378a4b5e0b219783683012bec680325eb40719
      export MACVM_DISK_GIB=${toString v.diskGiB}
      export MACVM_SSH_PORT=${toString v.sshPort}
      export MACVM_SSH_KEY="$HOME/.ssh/macbuild_ed25519"
      ${builtins.readFile ../../../scripts/macvm}
    '';
  };

  helperNames = [
    "macvm-prepare"
    "macvm-define"
    "macvm-start"
    "macvm-stop"
    "macvm-force-stop"
    "macvm-status"
    "macvm-storage"
    "macvm-console"
    "macvm-ssh"
    "macvm-enroll-key"
    "macvm-guest-setup"
    "macvm-sync"
    "macvm-build"
    "macvm-package-ipa"
    "macvm-fetch-ipa"
    "macvm-build-and-copy"
  ];

  helperPackage = pkgs.runCommand "macvm-helpers" { } ''
    mkdir -p "$out/bin"
    ln -s ${macvm}/bin/macvm "$out/bin/macvm"
    ${lib.concatMapStringsSep "\n" (name: "ln -s macvm \"$out/bin/${name}\"") helperNames}
  '';
in
{
  config = lib.mkIf enabled {
    assertions = [
      {
        assertion = v.vcpus <= 16;
        message = "features.virtualisation.macosBuilder.vcpus must not exceed 16 on tandesk.";
      }
      {
        assertion = builtins.match "[a-zA-Z0-9_.:-]+" v.ethernetInterface != null;
        message = "features.virtualisation.macosBuilder.ethernetInterface must be a safe Linux interface name.";
      }
    ];

    systemd.tmpfiles.rules = [
      "d ${dataDir} 2770 ${config.nagi.variables.users.primary} libvirtd -"
    ];

    environment.systemPackages = [ helperPackage ];
  };
}
