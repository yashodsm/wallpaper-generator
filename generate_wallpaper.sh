#!/bin/bash

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Configuration
OUTPUT_WALLPAPER="$SCRIPT_DIR/dynamic_wallpaper.png"
TEMPLATE_WALLPAPER="$SCRIPT_DIR/wallpaper_template.png" # Make sure this file exists in the same directory
FONT_SIZE="40"
TEXT_COLOR="white" # For the system info text
TEXT_OFFSET_X="50" # X-offset from the left edge
TEXT_OFFSET_Y_START="100" # Y-offset for the first line

# --- Function to get system information ---
get_system_info() {
    USERNAME=$(whoami)
    HOSTNAME=$(hostname)
    KERNEL=$(uname -r)
    UPTIME=$(uptime -p) # -p for pretty format

    # Get active network interface
    NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)

    if [ -z "$NETWORK_INTERFACE" ]; then
        if ip a show eth0 &>/dev/null; then
            NETWORK_INTERFACE="eth0"
        elif ip a show wlan0 &>/dev/null; then
            NETWORK_INTERFACE="wlan0"
        else
            NETWORK_INTERFACE="lo" # Fallback to loopback
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

    # DHCP Status
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

# --- Generate the wallpaper image ---
generate_wallpaper_image() {
    # Check if template wallpaper exists
    if [ ! -f "$TEMPLATE_WALLPAPER" ]; then
        echo "Error: Template wallpaper '$TEMPLATE_WALLPAPER' not found."
        echo "Please create a base image file (e.g., a blank .png) named 'wallpaper_template.png' in the same directory as the script."
        exit 1
    fi

    INFO_TEXT=$(get_system_info)
    LINE_HEIGHT=$((FONT_SIZE + 10)) # Adjust as needed for spacing

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
        2>/dev/null # Suppress ImageMagick warnings if any
        CURRENT_Y=$((CURRENT_Y + LINE_HEIGHT))
    done <<< "$INFO_TEXT"

    echo "Generated wallpaper: $OUTPUT_WALLPAPER"
}

# --- Apply the wallpaper ---
apply_wallpaper() {
    # Detect Desktop Environment and apply wallpaper accordingly
    # Prioritize XDG_CURRENT_DESKTOP, then try to guess from running processes.
    DE=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')

    # If XDG_CURRENT_DESKTOP is empty or unreliable (e.g., in cron), guess based on processes.
    if [ -z "$DE" ] || ! (echo "gnome kde xfce lxqt mate cinnamon deepin" | grep -w "$DE" > /dev/null); then
        echo "Attempting to guess Desktop Environment for wallpaper application..."
        if pgrep -x "gnome-shell" > /dev/null; then DE="gnome";
        elif pgrep -x "plasmashell" > /dev/null; then DE="kde";
        elif pgrep -x "xfce4-session" > /dev/null; then DE="xfce";
        elif pgrep -x "lxqt-session" > /dev/null; then DE="lxqt";
        elif pgrep -x "mate-session" > /dev/null; then DE="mate";
        elif pgrep -x "cinnamon" > /dev/null; then DE="cinnamon";
        elif pgrep -x "dde-session-daemon" > /dev/null; then DE="deepin";
        else DE="unknown";
        fi
        echo "Guessed DE: $DE"
    fi

    case "$DE" in
        *gnome*)
            gsettings set org.gnome.desktop.background picture-uri "file://$OUTPUT_WALLPAPER"
            gsettings set org.gnome.desktop.background picture-uri-dark "file://$OUTPUT_WALLPAPER" # For dark mode
            echo "Wallpaper applied for GNOME."
            ;;
        *kde*)
            # KDE requires qdbus and might be version-dependent.
            qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "var wallpaper = 'file://$OUTPUT_WALLPAPER'; var activity = desktops()[0]; activity.wallpaperPlugin = 'org.kde.image'; activity.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General']; activity.writeConfig('Image', wallpaper);"
            echo "Wallpaper applied for KDE (attempted)."
            ;;
        *xfce*)
            # XFCE uses xfconf-query. --create -t string/int ensures property is created if it doesn't exist.
            xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "$OUTPUT_WALLPAPER" --create -t string
            # Fix for image-style property not existing:
            xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/image-style -s 5 --create -t int # Style: 5=zoom, 2=stretch, 1=center etc.
            echo "Wallpaper applied for XFCE."
            ;;
        *mate*)
            gsettings set org.mate.background picture-filename "$OUTPUT_WALLPAPER"
            echo "Wallpaper applied for MATE."
            ;;
        *cinnamon*)
            gsettings set org.cinnamon.desktop.background picture-uri "file://$OUTPUT_WALLPAPER"
            echo "Wallpaper applied for Cinnamon."
            ;;
        *lxde*)
            # PCManFM is common in LXDE. Replace 'fit' with 'stretch', 'center', 'tile' as preferred.
            pcmanfm --set-wallpaper "$OUTPUT_WALLPAPER" --wallpaper-mode=fit
            echo "Wallpaper applied for LXDE (via PCManFM)."
            ;;
        *deepin*)
            # Deepin uses dconf. Note the quotes for the URI.
            dconf write /com/deepin/dde/desktop/appearance/picture-uri "'file://$OUTPUT_WALLPAPER'"
            echo "Wallpaper applied for Deepin (attempted via dconf)."
            ;;
        *)
            echo "Unsupported Desktop Environment: '$XDG_CURRENT_DESKTOP' (or guessed as '$DE')."
            echo "Please apply wallpaper manually from $OUTPUT_WALLPAPER"
            ;;
    esac
}

# --- Main execution ---
generate_wallpaper_image
apply_wallpaper
