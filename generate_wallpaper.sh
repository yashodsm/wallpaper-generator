#!/bin/bash

# Configuration
OUTPUT_WALLPAPER="/tmp/dynamic_wallpaper.png"
TEMPLATE_WALLPAPER="wallpaper_template.png" # Make sure this file exists in the same directory
FONT_SIZE="40"
FONT_COLOR="white"
TEXT_COLOR="white" # For the system info
TEXT_OFFSET_X="50" # X-offset from the left edge
TEXT_OFFSET_Y_START="100" # Y-offset for the first line

# --- Function to get system information ---
get_system_info() {
    USERNAME=$(whoami)
    HOSTNAME=$(hostname)
    KERNEL=$(uname -r)
    UPTIME=$(uptime -p) # -p for pretty format

    # Get active network interface (basic attempt, might need refinement)
    NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)

    # Get IPv4 information
    IPV4_INFO=$(ip -4 a show dev "$NETWORK_INTERFACE" | grep inet | awk '{print "IPv4: " $2 " (Mask: " $4 ")"}' | head -n 1)

    # Get IPv6 information
    IPV6_INFO=$(ip -6 a show dev "$NETWORK_INTERFACE" | grep inet6 | awk '{print "IPv6: " $2}' | head -n 1)

    # DHCP Status (very basic inference - needs more robust checking)
    # This is a very simplified check. A proper check would involve parsing NetworkManager logs, dhclient logs, or configuration files.
    if ip -4 a show dev "$NETWORK_INTERFACE" | grep -q 'dynamic'; then
        DHCP_STATUS="DHCP: Yes"
    else
        DHCP_STATUS="DHCP: No (Static/Manual)"
    fi

    echo "User: $USERNAME"
    echo "Hostname: $HOSTNAME"
    echo "Kernel: $KERNEL"
    echo "Uptime: $UPTIME"
    echo "$IPV4_INFO"
    echo "$IPV6_INFO"
    echo "$DHCP_STATUS"
    echo "Interface: $NETWORK_INTERFACE"
}

# --- Generate the wallpaper ---
generate_wallpaper() {
    INFO_TEXT=$(get_system_info)
    LINE_HEIGHT=$(($FONT_SIZE + 10)) # Adjust as needed for spacing

    # Start with the template image
    cp "$TEMPLATE_WALLPAPER" "$OUTPUT_WALLPAPER"

    # Overlay each line of text
    CURRENT_Y=$TEXT_OFFSET_Y_START
    while IFS= read -r line; do
        convert "$OUTPUT_WALLPAPER" \
                -pointsize "$FONT_SIZE" \
                -fill "$TEXT_COLOR" \
                -gravity NorthWest \
                -annotate +"$TEXT_OFFSET_X+$CURRENT_Y" "$line" \
                "$OUTPUT_WALLPAPER"
        CURRENT_Y=$(($CURRENT_Y + $LINE_HEIGHT))
    done <<< "$INFO_TEXT"

    echo "Generated wallpaper: $OUTPUT_WALLPAPER"
}

# --- Apply the wallpaper ---
apply_wallpaper() {
    # Detect Desktop Environment and apply wallpaper accordingly
    if [ "$XDG_CURRENT_DESKTOP" == "GNOME" ]; then
        gsettings set org.gnome.desktop.background picture-uri "file://$OUTPUT_WALLPAPER"
        echo "Wallpaper applied for GNOME."
    elif [ "$XDG_CURRENT_DESKTOP" == "KDE" ]; then
        # KDE application is more complex, you might need a QML script or direct DBus calls.
        # This is a simplified example and might not work on all KDE setups.
        qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "var wallpaper = 'file://$OUTPUT_WALLPAPER'; var activity = desktops()[0]; activity.wallpaperPlugin = 'org.kde.image'; activity.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General']; activity.writeConfig('Image', wallpaper);"
        echo "Wallpaper applied for KDE (attempted)."
    elif [[ "$XDG_CURRENT_DESKTOP" == *"XFCE"* ]]; then
        xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "$OUTPUT_WALLPAPER"
        echo "Wallpaper applied for XFCE."
    else
        echo "Unsupported Desktop Environment: $XDG_CURRENT_DESKTOP. Please apply wallpaper manually from $OUTPUT_WALLPAPER"
    fi
}

# --- Main execution ---
generate_wallpaper
apply_wallpaper
