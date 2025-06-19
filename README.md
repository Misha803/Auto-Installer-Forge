# Auto-Installer-Forge
An automated tool that processes ROMs containing **payload.bin**, converts them into a ready-to-flash **super.img**, and generates a fully automated installation package for Fastboot or Recovery, which can later be flashed using my custom flasher scripts.

#### For android shell arm64 - copy and paste in termux or adb shell with root access to termux/shell app

```bash
su -c "cd / && mkdir -p /tmp/Auto-Installer-Forge && cd /tmp/Auto-Installer-Forge && curl -sSL -o auto_installer https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/auto_installer && chmod 777 auto_installer && su -c ./auto_installer"
```

#### Linux and Windows Scripts not yet supports Auto magisk boot patching 

#### For Linux Test run - copy and paste in Terminal of your Linux pc
```shell
cd && mkdir -p ~/Auto-Installer-Forge && cd ~/Auto-Installer-Forge && curl -sSL -o auto_installer.sh https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/auto_installer.sh && chmod 777 auto_installer.sh && ./auto_installer.sh
```

#### For Windows Test run - copy and paste in Windows Terminal or Powershell

```shell
powershell.exe -C "irm https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/auto_installer.ps1 | iex"
```


