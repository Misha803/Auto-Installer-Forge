# ⚡ Auto-Installer-Forge
### An automated tool that processes Android Recovery ROMs containing `payload.bin`, converts them into a ready-to-flash easily in fastboot or recovery mode.

---

## 🌟 Overview

#### It generates a fully automated installation package with custom flasher scripts for flashing easily in Fastboot or Recovery mode which works on Linux, Windows, or any Android recovery (with or without a PC) also Includes root selection and format/update options on the go... 😎

---
## 🔁 Automated Builds via GitHub Actions

### ✨ Easiest Method (No Local Setup Required) to Build an auto-installer package automatically using the GitHub Actions [workflow](https://github.com/ArKT-7/Auto-Installer-Forge/actions/workflows/forge-auto-installer.yml)

### 🤔 How to Use:

1. **Fork this repository** (required for Actions access)
2. **Go to**: [`Actions`](https://github.com/ArKT-7/Auto-Installer-Forge/actions) tab → [`Forge Auto-Installer zip`](https://github.com/ArKT-7/Auto-Installer-Forge/actions/workflows/forge-auto-installer.yml) workflow
3. Click, **Run workflow** then **Fill in the form** with your ROM details
4. Now, Click on **Run workflow in bottom** and **Wait for completion**: ~5-8 minutes depending on ROM size
5. **Download artifact**: Your `<rom>_FASTBOOT_RECOVERY.zip` from the workflow run
6. **Usage: how to flash via fastboot or recovery [`see below for instructions...`](https://github.com/ArKT-7/Auto-Installer-Forge/tree/main#-how-to-use-the-generated-auto-installer-zip)**

---

## 💀 Build using your own device

### 🐧 Linux (best...)

**Copy and paste in your Linux `terminal`:**

```bash
cd && mkdir -p ~/Auto-Installer-Forge && cd ~/Auto-Installer-Forge && curl -sSL -o auto_installer.sh https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/auto_installer.sh && chmod +x auto_installer.sh && ./auto_installer.sh
```

### 🤖 Android Shell (ARM64)

**For `Termux` or ADB `shell` with root access:**

```bash
su -c "cd / && mkdir -p /tmp/Auto-Installer-Forge && cd /tmp/Auto-Installer-Forge && curl -sSL -o auto_installer https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/auto_installer && chmod +x auto_installer && ./auto_installer"
```

### 😂 Windows (WIP)

**Copy and paste in `Windows Terminal` or `PowerShell`:**

```powershell
powershell.exe -C "irm https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/auto_installer.ps1 | iex"
```

---

## 💡 Important Notes

- **Auto Magisk boot patching** is currently supported on the  **Workflow builder, Linux, and Android scripts**
- Windows scripts do **not yet support** auto Magisk boot patching
- **Currently Tested: Xiaomi Pad 5 (***`nabu`***)**
- ***`Other devices:`*** **Use at your own risk** — report results via [**Issues**](https://github.com/ArKT-7/Auto-Installer-Forge/issues)
- **Help in expand**: Successfully used on another device? [**Submit a PR**](https://github.com/ArKT-7/Auto-Installer-Forge/pulls) with device info

---

## ⚡ How to Use the Generated Auto-Installer Zip:
---
### Option 1: Using Fastboot (With PC):

- Reboot your device to Fastboot mode
- Connect to your PC via USB
- Extract the auto-installer zip

**For Windows:**
- **Double-click and run:**
  - **`install_<rom>_windows.bat`** ***(first-time install/with data format)***
  - **`update_<rom>_windows.bat`** ***(update without data format)***
- **Follow on-screen instructions**

**For Linux:**
- **Open terminal and run:**
  - **`bash ./install_<rom>_linux.sh`** ***(first-time install/with data format)***
  - **`bash ./update_<rom>_linux.sh`** ***(update without data format)***
- **Follow on-screen instructions**
---
### Option 2: Using Recovery (On Device, No PC Required):

- Transfer the auto-installer zip to your device
- Boot into TWRP/PBRP or any recovery
- Select **Install** → choose the zip file → flash
- Reboot when finished (or wait if it reboots automatically)


---

## ❤️ Support My Work

If you find this project helpful, consider supporting my work!

<p align="left">
  <a href="https://www.buymeacoffee.com/ArKT" target="_blank">
    <img src="https://github.com/ArKT-7/Temp-files/blob/main/assets/buymecoffee.png" alt="Buy Me A Coffee" style="height: 60px !important; width: 217px !important;">
  </a>
  <a href="https://www.paypal.me/arkt7" target="_blank">
    <img src="https://github.com/ArKT-7/Temp-files/blob/main/assets/Paypal.png" alt="Donate with PayPal" style="height: 60px !important; width: 217px !important;">
  </a>
</p>

---

### 🎉 Enjoy Forging Auto-Installer Zips...
