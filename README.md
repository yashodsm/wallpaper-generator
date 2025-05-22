This updated `README.md` incorporates the details from your `generate_wallpaper.sh` script, providing a more complete and accurate overview of your project's capabilities.

---

# 🌄 Dynamic Linux Wallpaper Generator

Transform your Linux desktop with dynamic wallpapers that display real-time system information! This project includes `generate_wallpaper.sh` to create custom wallpapers by overlaying system details onto a template image, and `setup-cron.sh` to automate these updates, ensuring your desktop always looks fresh and informative.

---

## ✨ Features

* **Customizable Wallpapers:** Generates unique wallpapers by adding system information directly onto a base image.
* **Real-time System Info:** Displays crucial details like username, hostname, kernel version, uptime, and network (IPv4, IPv6, DHCP status) directly on your desktop.
* **Automatic Updates:** The `setup-cron.sh` script sets up a cron job to periodically update your wallpaper, keeping the displayed information current.
* **Broad Desktop Environment Support:** Automatically detects and applies wallpapers for popular DEs including GNOME, KDE, XFCE, MATE, Cinnamon, LXDE, and Deepin.
* **Flexible Scheduling:** Easily configure how often your wallpaper changes – from every few minutes to daily.
* **One-Time Generation Option:** Test your wallpaper generation instantly without setting up a recurring cron job.
* **Error Handling & Logging:** Includes checks for script executability and logs cron job output for easy troubleshooting.
* **Customizable Appearance:** Adjust font size, text color, and text position by editing variables in `generate_wallpaper.sh`.

---

## 🚀 Getting Started

These instructions will help you get your dynamic wallpaper generator up and running on your Linux system.

### Prerequisites

* **ImageMagick:** Used by `generate_wallpaper.sh` to create and manipulate images. Install it using your distribution's package manager:
    * **Debian/Ubuntu:** `sudo apt install imagemagick`
    * **Arch Linux:** `sudo pacman -S imagemagick`
    * **Fedora:** `sudo dnf install imagemagick`
* **A Base Wallpaper Template:** You'll need a `.png` image named `wallpaper_template.png` placed in the same directory as the scripts. This will be the background onto which system information is overlaid.

### Installation

1.  **Clone the Repository or Place Scripts:**
    It's recommended to place both `generate_wallpaper.sh` and `setup-cron.sh` in a dedicated directory in your home folder. For example:

    ```bash
    mkdir -p "$HOME/wallpaper-generator"
    cd "$HOME/wallpaper-generator"
    # Download the scripts into this directory
    # For example, using curl:
    # curl -O https://raw.githubusercontent.com/yashodsm/wallpaper-generator-linux/main/generate_wallpaper.sh
    # curl -O https://raw.githubusercontent.com/yashodsm/wallpaper-generator-linux/main/setup-cron.sh
    ```

2.  **Add Your Template Wallpaper:**
    Place your base image file (e.g., `wallpaper_template.png`) into the `~/wallpaper-generator/` directory. This image will be the background for your dynamic wallpaper.

3.  **Make Scripts Executable:**
    Navigate to the `wallpaper-generator` directory and make both scripts executable:

    ```bash
    cd "$HOME/wallpaper-generator"
    chmod +x generate_wallpaper.sh setup-cron.sh
    ```

---

## 🛠️ Usage

### Configuring `generate_wallpaper.sh` (Optional)

Before running the setup, you can customize the appearance of the overlaid text by editing `generate_wallpaper.sh`:

* `TEMPLATE_WALLPAPER`: Ensure this path is correct if you've placed your template elsewhere (default: `wallpaper_template.png` in the script's directory).
* `FONT_SIZE`: Change the size of the text (default: `40`).
* `TEXT_COLOR`: Modify the color of the text (default: `white`).
* `TEXT_OFFSET_X`: Adjust the horizontal position of the text from the left edge (default: `50`).
* `TEXT_OFFSET_Y_START`: Adjust the vertical starting position for the first line of text (default: `100`).

### Running the Setup Script

Execute the setup script from your terminal:

```bash
cd "$HOME/wallpaper-generator" # Navigate to your script directory
./setup-cron.sh
```

The script will guide you through the setup process:

1.  **Prerequisite Checks:** It verifies if `generate_wallpaper.sh` exists and is executable.
2.  **Session Variable Detection:** It intelligently tries to determine your `DISPLAY`, `XAUTHORITY`, and `XDG_RUNTIME_DIR` variables. These are critical for cron jobs to interact with your graphical session.
3.  **Choose Mode:**
    * **1) Generate wallpaper once now:** This is great for testing your `generate_wallpaper.sh` script immediately without setting up a cron job.
    * **2) Set up a cron job:** This will prompt you for a **cron interval** (e.g., `*/5 * * * *` for every 5 minutes, or press Enter for the default `*/5 * * * *`). It then adds the necessary entry to your user's crontab.

    **Cron Interval Examples:**
    * `*/5 * * * *`: Every 5 minutes
    * `0 * * * *`: Every hour
    * `0 9 * * *`: Every day at 9:00 AM
    * `0 0 * * 0`: Every Sunday at midnight

---

## 🗑️ Removing the Cron Job

If you decide to stop the automatic wallpaper updates:

1.  Open your crontab for editing:
    ```bash
    crontab -e
    ```
2.  Locate and **delete** the line containing `generate_wallpaper.sh`. It will look something like this:
    ```
    */5 * * * * export XAUTHORITY=/home/youruser/.Xauthority; export XDG_RUNTIME_DIR=/run/user/1000; export DISPLAY=:0; /home/youruser/wallpaper-generator/generate_wallpaper.sh >> "/home/youruser/wallpaper-generator/cron_wallpaper.log" 2>&1
    ```
3.  Save and exit the crontab editor. The cron job will be removed immediately.

---

##  troubleshooting

* **Wallpaper Not Changing:**
    * **Check `cron_wallpaper.log`:** The cron job's output is redirected to `~/wallpaper-generator/cron_wallpaper.log`. Open this file (`cat ~/wallpaper-generator/cron_wallpaper.log`) to check for any errors or warnings from `generate_wallpaper.sh` or the wallpaper application process.
    * **`DISPLAY`, `XAUTHORITY`, `XDG_RUNTIME_DIR`:** Cron jobs run in a minimal environment. The `setup-cron.sh` script attempts to set these crucial environment variables, but sometimes manual adjustment might be needed, especially with complex Wayland setups.
    * **Manual Test:** Run `generate_wallpaper.sh` directly from your terminal (`./generate_wallpaper.sh`). If it works manually but not via cron, the issue is almost certainly environmental variables or permissions within the cron context.
* **ImageMagick Errors:** Ensure ImageMagick is correctly installed and its `convert` command is available in your PATH.
* **`wallpaper_template.png` Not Found:** Make sure your base image file exists in the correct location (by default, in the same directory as the scripts) and is named `wallpaper_template.png`.

---
