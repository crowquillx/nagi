{
  lib,
  pkgs,
  inputs,
  self,
  vars ? { },
  ...
}:
let
  fishEnabled = lib.attrByPath [ "features" "shell" "fish" "enable" ] true vars;
  zshEnabled = lib.attrByPath [ "features" "shell" "zsh" "enable" ] false vars;
  sharedAliases = {
    fu = "tcli update";
    fr = "tcli rebuild";
    ncg = "tcli gc";
    winblows = "systemctl reboot --boot-loader-entry=auto-windows";
    enterbios = "systemctl reboot --boot-loader-entry=auto-reboot-to-firmware-setup";
    codebox = "ssh tan@codebox";
    tanime = "ssh root@192.168.0.85";
    tanmedia = "ssh tan@192.168.0.116";
    uc = "jellyfin-uc";
  };
  homeManagerPkg =
    let
      pkgsBySystem = inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system};
    in
    pkgsBySystem.home-manager or pkgsBySystem.default;
  tcli = self.packages.${pkgs.stdenv.hostPlatform.system}.tcli;
  # One-shot jellyfin maintenance for tanmedia: cold-backup the DB and strip
  # duplicate UserData rows, with the stack stopped the whole time. The quoted
  # REMOTE block lives in a real sh script so every interactive shell invokes
  # the same implementation; remote bash -s then runs it. An EXIT trap
  # guarantees the stack comes back up even if the backup or dedupe step fails.
  # tanmedia has no sqlite3 CLI, so the dedupe runs through python3.
  jellyfinUc = pkgs.writeShellScriptBin "jellyfin-uc" ''
    ssh tan@192.168.0.116 'bash -s' <<'REMOTE'
    set -euo pipefail
    cd /opt/stacks/jellyfin
    db=/opt/apps/jellyfin/data/jellyfin.db

    trap 'echo "==> Bringing jellyfin stack back up"; docker compose up -d' EXIT

    echo "==> Bringing jellyfin stack down"
    docker compose down

    echo "==> Backing up database (overwriting previous backup)"
    cp -f "$db" "$db.backup"

    echo "==> Running dedupe SQL against UserData"
    python3 - <<'PY'
    import sqlite3
    con = sqlite3.connect('/opt/apps/jellyfin/data/jellyfin.db')
    con.execute("""
    delete from `UserData`
    where CustomDataKey IN (
      select CustomDataKey
      from `UserData`
      group by UserId, CustomDataKey
      having count(*) > 1
    )
    """)
    con.commit()
    con.close()
    PY

    echo "==> Dedupe complete"
    REMOTE
  '';
in
{
  home.packages = [
    tcli
    homeManagerPkg
    jellyfinUc
  ];

  programs = {
    bash.shellAliases = {
      fu = "tcli update";
      fr = "tcli rebuild";
      ncg = "tcli gc";
      winblows = "systemctl reboot --boot-loader-entry=auto-windows";
      enterbios = "systemctl reboot --boot-loader-entry=auto-reboot-to-firmware-setup";
      uc = "jellyfin-uc";
    };

    fish.shellAliases = lib.mkIf fishEnabled sharedAliases;
    zsh.shellAliases = lib.mkIf zshEnabled sharedAliases;
  };
}
