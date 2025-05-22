#!/bin/bash

# generate_wallpaper.sh
# This script gathers system information, overlays it onto a template image,
# and sets the resulting image as the desktop wallpaper.

# --- Configuration ---
# IMPORTANT: Adjust these paths and settings as needed.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )" # Gets the directory where the script itself is located
OUTPUT_WALLPAPER="/tmp/dynamic_wallpaper.png"
TEMPLATE_WALLPAPER="$SCRIPT_DIR/wallpaper_template.png" # Template image must be in the same directory as this script

# Image Text Styling
FONT_SIZE="40"
FONT_COLOR="white" # Color of the text (e.g., white, black, red, #RRGGBB)
TEXT_OFFSET_X="50" # X-offset from the left edge of the wallpaper
TEXT_OFFSET_Y_START="100" # Y-offset for the first line of text from the top

# --- Function to get system information ---
get_system_info() {
    USERNAME=$(whoami)
    HOSTNAME=$(hostname)
    KERNEL=$(uname -r)
    UPTIME=$(uptime -p) # -p for pretty format

    # Determine the primary active network interface
    NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)

    # Fallback if no default interface is found (e.g., on a system with no active network or specific setups)
    if [ -z "$NETWORK_INTERFACE" ]; then
        # Try common interfaces that might be up
        if ip a show eth0 up &>/dev/null; then
            NETWORK_INTERFACE="eth0"
        elif ip a show wlan0 up &>/dev/null; then
            NETWORK_INTERFACE="wlan0"
        elif ip a show enp &>/dev/null; then # Generic for common ethernet names like enp0s3
            NETWORK_INTERFACE=$(ip -o link show | awk -F': ' '$2 ~ /^enp/ {print $2}' | head -n 1)
        elif ip a show wl &>/dev/null; then # Generic for common wireless names like wlp2s0
            NETWORK_INTERFACE=$(ip -o link show | awk -F': ' '$2 ~ /^wl/ {print $2}' | head -n 1)
        else
            NETWORK_INTERFACE="lo" # Fallback to loopback if all else fails
        fi
    fi

    # Get IPv4 information
    IPV4_INFO=$(ip -4 a show dev "$NETWORK_INTERFACE" 2>/dev/null | grep inet | awk '{print "IPv4: " $2 " (Mask: " $4 ")"}' | head -n 1)
    if [ -z "$IPV4_INFO" ]; then
        IPV4_INFO="IPv4: Not configured or interface not found"
    fi

    # Get IPv6 information
    IPV6_INFO=$(ip -6 a show dev "$NETWORK_INTERFACE" 2>/dev/null | grep inet6 | awk '{print "IPv6: " $2}' | head -n 1)
    if [ -z "$IPV6_INFO" ]; then
        IPV6_INFO="IPv6: Not configured or interface not found"
    fi

    # DHCP Status (simplified inference - a robust check would involve parsing network manager logs or config)
    DHCP_STATUS="DHCP: Unknown"
    if ip -4 a show dev "$NETWORK_INTERFACE" | grep -q 'dynamic'; then
        DHCP_STATUS="DHCP: Yes"
    elif ip -4 a show dev "$NETWORK_INTERFACE" | grep -q 'static'; then
        DHCP_STATUS="DHCP: No (Static/Manual)"
    fi

    # Disk Usage for root partition
    DISK_USAGE=$(df -h / | awk 'NR==2 {print "Disk Usage: " $5 " of " $2}')

    # Output collected info
    echo "User: $USERNAME"
    echo "Hostname: $HOSTNAME"
    echo "Kernel: $KERNEL"
    echo "Uptime: $UPTIME"
    echo "$IPV4_INFO"
    echo "$IPV6_INFO"
    echo "$DHCP_STATUS"
    echo "Interface: $NETWORK_INTERFACE"
    echo "$DISK_USAGE"
}

# --- Generate the wallpaper image with text overlay ---
generate_wallpaper_image() {
    # Check if template wallpaper exists
    if [ ! -f "$TEMPLATE_WALLPAPER" ]; then
        echo "Error: Template wallpaper '$TEMPLATE_WALLPAPER' not found."
        echo "Please create a base image file (e.g., a blank .png) named 'wallpaper_template.png' in the same directory as this script ('$SCRIPT_DIR')."
        exit 1
    fi

    INFO_TEXT=$(get_system_info)
    LINE_HEIGHT=$(($FONT_SIZE + 10)) # Adjust as needed for spacing between lines

    # Start with the template image
    cp "$TEMPLATE_WALLPAPER" "$OUTPUT_WALLPAPER" || { echo "Error: Failed to copy template wallpaper. Check permissions."; exit 1; }

    # Overlay each line of text onto the image
    CURRENT_Y=$TEXT_OFFSET_Y_START
    while IFS= read -r line; do
        convert "$OUTPUT_WALLPAPER" \
                -pointsize "$FONT_SIZE" \
                -fill "$FONT_COLOR" \
                -gravity NorthWest \
                -annotate +"$TEXT_OFFSET_X+$CURRENT_Y" "$line" \
                "$OUTPUT_WALLPAPER"
        CURRENT_Y=$(($CURRENT_Y + $LINE_HEIGHT))
    done <<< "$INFO_TEXT"

    echo "Generated wallpaper: $OUTPUT_WALLPAPER"
}

# --- Apply the wallpaper to the desktop environment ---
apply_wallpaper() {
    # Determine the current Desktop Environment
    DE=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')

    echo "Attempting to apply wallpaper for Desktop Environment: $DE"

    case "$DE" in
        *gnome*|*unity*|*cinnamon*)
            gsettings set org.gnome.desktop.background picture-uri "file://$OUTPUT_WALLPAPER"
            echo "Wallpaper applied for GNOME/Unity/Cinnamon."
            ;;
        *kde*)
            # KDE Plasma uses qdbus to set wallpaper. This method can be complex and
            # might not work across all KDE versions reliably.
            qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "var wallpaper = 'file://$OUTPUT_WALLPAPER'; var activity = desktops()[0]; activity.wallpaperPlugin = 'org.kde.image'; activity.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General']; activity.writeConfig('Image', wallpaper);"
            echo "Wallpaper applied for KDE (attempted via qdbus)."
            ;;
        *xfce*)
            # XFCE uses xfconf-query. --create is necessary if the property doesn't exist yet.
            xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "$OUTPUT_WALLPAPER" --create -t string
            echo "Wallpaper applied for XFCE."
            ;;
        *mate*)
            # MATE Desktop Environment
            gsettings set org.mate.background picture-filename "$OUTPUT_WALLPAPER"
            echo "Wallpaper applied for MATE."
            ;;
        *lxde*|*lxqt*)
            # LXDE/LXQt might use pcmanfm
            pcmanfm --set-wallpaper "$OUTPUT_WALLPAPER" --wallpaper-mode=stretch # adjust mode as needed (stretch, zoom, center, fit, tile)
            echo "Wallpaper applied for LXDE/LXQt (attempted via pcmanfm)."
            ;;
        *)
            echo "Unsupported Desktop Environment: $XDG_CURRENT_DESKTOP."
            echo "Please apply wallpaper manually from: $OUTPUT_WALLPAPER"
            ;;
    esac
}

# --- Main execution ---
echo "--- Starting wallpaper generation script ---"
generate_wallpaper_image
apply_wallpaper
echo "--- Script execution finished ---"
