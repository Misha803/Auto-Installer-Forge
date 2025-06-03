# Auto-Installer-Forge
## WIP for linux and windows pc
An automated tool that processes ROMs containing **payload.bin**, converts them into a ready-to-flash **super.img**, and generates a fully automated installation package for Fastboot or Recovery, which can later be flashed using my custom flasher scripts.

## WIP for linux and windows pc
#### Test run - copy and paste in Windows Terminal or Powershell

```shell
powershell.exe -C "irm https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/auto_installer.ps1 | iex"
```

#### For android shell arm64 - copy and paste in termux or adb shell with root access to termux/shell app

```bash
su -c "cd / && mkdir -p /tmp/Auto-Installer-Forge && cd /tmp/Auto-Installer-Forge && curl -sSL -o auto_installer https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/auto_installer && chmod 777 auto_installer && su -c ./auto_installer"
```

