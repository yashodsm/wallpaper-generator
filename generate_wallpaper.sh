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
    # This tries to find the default route's interface.
    NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)

    # If no default interface is found, try to list common ones
    if [ -z "$NETWORK_INTERFACE" ]; then
        if ip a show eth0 &>/dev/null; then
            NETWORK_INTERFACE="eth0"
        elif ip a show wlan0 &>/dev/null; then
            NETWORK_INTERFACE="wlan0"
        else
            NETWORK_INTERFACE="lo" # Fallback to loopback if no other active interface found
        fi
    fi


    # Get IPv4 information
    IPV4_INFO=$(ip -4 a show dev "$NETWORK_INTERFACE" 2>/dev/null | grep inet | awk '{print "IPv4: " $2 " (Mask: " $4 ")"}' | head -n 1)
    if [ -z "$IPV4_INFO" ]; then
        IPV4_INFO="IPv4: Not configured"
    fi

    # Get IPv6 information
    IPV6_INFO=$(ip -6 a show dev "$NETWORK_INTERFACE" 2>/dev/null | grep inet6 | awk '{print "IPv6: " $2}' | head -n 1)
    if [ -z "$IPV6_INFO" ]; then
        IPV6_INFO="IPv6: Not configured"
    fi

    # DHCP Status (very basic inference - needs more robust checking)
    # This is a very simplified check. A proper check would involve parsing NetworkManager logs,
    # dhclient logs, or configuration files (e.g., /etc/network/interfaces).
    DHCP_STATUS="DHCP: Unknown"
    if ip -4 a show dev "$NETWORK_INTERFACE" | grep -q 'dynamic'; then
        DHCP_STATUS="DHCP: Yes"
    elif ip -4 a show dev "$NETWORK_INTERFACE" | grep -q 'static'; then
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
    # Check if template wallpaper exists
    if [ ! -f "$TEMPLATE_WALLPAPER" ]; then
        echo "Error: Template wallpaper '$TEMPLATE_WALLPAPER' not found."
        echo "Please create a base image file (e.g., a blank .png) named 'wallpaper_template.png' in the same directory as the script."
        exit 1
    fi

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
    # XDG_CURRENT_DESKTOP is a common environment variable used for this.
    # We use a case statement for cleaner handling of multiple DEs.

    DE=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]') # Convert to lowercase for easier matching

    case "$DE" in
        *gnome*)
            gsettings set org.gnome.desktop.background picture-uri "file://$OUTPUT_WALLPAPER"
            echo "Wallpaper applied for GNOME."
            ;;
        *kde*)
            # KDE application is more complex, requiring DBus calls.
            # This is a simplified example and might not work on all KDE setups or versions.
            qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "var wallpaper = 'file://$OUTPUT_WALLPAPER'; var activity = desktops()[0]; activity.wallpaperPlugin = 'org.kde.image'; activity.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General']; activity.writeConfig('Image', wallpaper);"
            echo "Wallpaper applied for KDE (attempted)."
            ;;
        *xfce*)
            # Fix for the "Property does not exist" error: use --create
            xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "$OUTPUT_WALLPAPER" --create -t string
            echo "Wallpaper applied for XFCE."
            ;;
        *)
            echo "Unsupported Desktop Environment: $XDG_CURRENT_DESKTOP."
            echo "Please apply wallpaper manually from $OUTPUT_WALLPAPER"
            ;;
    esac
}

# --- Main execution ---
generate_wallpaper
apply_wallpaper
