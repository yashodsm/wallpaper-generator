#!/bin/bash

# This script configures a cron job to automatically update the wallpaper
# using your generate_wallpaper.sh script, or runs it once.

# --- Configuration ---
# IMPORTANT: Adjust these paths if your setup is different!
SCRIPT_DIR="$HOME/wallpaper-generator"
WALLPAPER_SCRIPT="$SCRIPT_DIR/generate_wallpaper.sh"
CRON_LOG_FILE="$SCRIPT_DIR/cron_wallpaper.log"
DEFAULT_CRON_INTERVAL="*/5 * * * *" # Run every 5 minutes by default

# --- Pre-requisite Checks ---
echo "--- Checking prerequisites ---"

if [ ! -f "$WALLPAPER_SCRIPT" ]; then
    echo "Error: Wallpaper script not found at '$WALLPAPER_SCRIPT'."
    echo "Please ensure 'generate_wallpaper.sh' is in '$SCRIPT_DIR' or update the SCRIPT_DIR variable in this script."
    exit 1
fi

if [ ! -x "$WALLPAPER_SCRIPT" ]; then
    echo "Warning: Wallpaper script '$WALLPAPER_SCRIPT' is not executable."
    echo "Attempting to make it executable..."
    chmod +x "$WALLPAPER_SCRIPT"
    if [ $? -eq 0 ]; then
        echo "Successfully made '$WALLPAPER_SCRIPT' executable."
    else
        echo "Error: Failed to make '$WALLPAPER_SCRIPT' executable. Please run 'chmod +x \"$WALLPAPER_SCRIPT\"' manually."
        exit 1
    fi
fi

# Ensure the script directory exists and is writable for the log file
mkdir -p "$SCRIPT_DIR"
touch "$CRON_LOG_FILE"
if [ $? -ne 0 ]; then
    echo "Error: Could not create or touch log file '$CRON_LOG_FILE'. Check directory permissions."
    exit 1
fi

echo "Prerequisites checked successfully."
echo ""

# --- Determine DISPLAY, XAUTHORITY, and XDG_RUNTIME_DIR for cron ---
# These are crucial for cron jobs to interact with your graphical session.
echo "--- Determining DISPLAY, XAUTHORITY, and XDG_RUNTIME_DIR for your session ---"

CURRENT_DISPLAY=""
CURRENT_XAUTHORITY=""
CURRENT_XDG_RUNTIME_DIR=""

# Get XDG_RUNTIME_DIR from the current environment (most reliable)
CURRENT_XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR"

# Attempt to get DISPLAY and XAUTHORITY from active user sessions
# This is generally the most reliable way.
# Check for Wayland sessions first, as gsettings might be the primary tool
if [[ "$(loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p Type | cut -d'=' -f2)" == "wayland" ]]; then
    echo "Detected Wayland session."
    CURRENT_DISPLAY=${DISPLAY:-":0"} # Xwayland often runs on :0
    CURRENT_XAUTHORITY=${XAUTHORITY:-"$HOME/.Xauthority"}
else
    # Fallback for X11 sessions (more common in cron contexts)
    # Iterate through X11 display sockets to find an active display.
    for x in /tmp/.X11-unix/X*; do
        display_num="${x##*/X}"
        if [ -n "$display_num" ] && [ -S "$x" ]; then
            # Verify if an X server is actually listening
            if xhost + >/dev/null 2>&1; then
                CURRENT_DISPLAY=":$display_num"
                break
            fi
        fi
    done

    # If still no DISPLAY, try common :0
    if [ -z "$CURRENT_DISPLAY" ]; then
        CURRENT_DISPLAY=":0"
    fi

    # Try to find XAUTHORITY file
    if [ -f "$HOME/.Xauthority" ]; then
        CURRENT_XAUTHORITY="$HOME/.Xauthority"
    elif [ -n "$XDG_RUNTIME_DIR" ] && [ -f "$XDG_RUNTIME_DIR/Xauthority" ]; then
        CURRENT_XAUTHORITY="$XDG_RUNTIME_DIR/Xauthority"
    fi
fi

# Final checks and messages for DISPLAY and XAUTHORITY
if [ -z "$CURRENT_DISPLAY" ]; then
    echo "Warning: Could not automatically determine DISPLAY variable. Defaulting to :0."
    echo "If wallpaper doesn't change from cron, you might need to manually specify DISPLAY (e.g., :1, :0.0) in the cron job."
    CURRENT_DISPLAY=":0"
fi

XAUTH_VAR=""
if [ -n "$CURRENT_XAUTHORITY" ] && [ -f "$CURRENT_XAUTHORITY" ]; then
    XAUTH_VAR="export XAUTHORITY=$CURRENT_XAUTHORITY;"
    echo "Using XAUTHORITY=$CURRENT_XAUTHORITY"
else
    echo "Warning: XAUTHORITY file not found or empty. This might prevent wallpaper changes in some DEs."
    echo "If wallpaper doesn't change, verify your .Xauthority path."
fi

XDG_RUNTIME_DIR_VAR=""
if [ -n "$CURRENT_XDG_RUNTIME_DIR" ]; then
    XDG_RUNTIME_DIR_VAR="export XDG_RUNTIME_DIR=$CURRENT_XDG_RUNTIME_DIR;"
    echo "Using XDG_RUNTIME_DIR=$CURRENT_XDG_RUNTIME_DIR"
else
    echo "Warning: XDG_RUNTIME_DIR not found. This might prevent wallpaper changes in modern DEs, especially Wayland."
fi


echo "Using DISPLAY=$CURRENT_DISPLAY"
echo ""

# --- User Choice: One-time or Cron Job ---
echo "--- Choose wallpaper update mode ---"
echo "Do you want to:"
echo "1) Generate and apply the wallpaper once now?"
echo "2) Set up a cron job to update the wallpaper periodically?"
read -p "Enter your choice (1 or 2): " choice

case "$choice" in
    1)
        echo "Running wallpaper generation and application once..."
        # Set DISPLAY, XAUTHORITY, and XDG_RUNTIME_DIR for the immediate run
        export DISPLAY="$CURRENT_DISPLAY"
        if [ -n "$CURRENT_XAUTHORITY" ]; then
            export XAUTHORITY="$CURRENT_XAUTHORITY"
        fi
        if [ -n "$CURRENT_XDG_RUNTIME_DIR" ]; then
            export XDG_RUNTIME_DIR="$CURRENT_XDG_RUNTIME_DIR"
        fi
        "$WALLPAPER_SCRIPT"
        if [ $? -eq 0 ]; then
            echo "One-time wallpaper update completed successfully."
        else
            echo "One-time wallpaper update failed. Check the script's output above for errors."
        fi
        ;;
    2)
        echo "--- Setting up cron job ---"
        read -p "Enter cron interval (e.g., '*/5 * * * *' for every 5 mins, press Enter for default '$DEFAULT_CRON_INTERVAL'): " user_cron_interval
        CRON_INTERVAL=${user_cron_interval:-$DEFAULT_CRON_INTERVAL}

        # Build the cron job entry with all necessary exports
        CRON_JOB_ENTRY="$CRON_INTERVAL $XAUTH_VAR $XDG_RUNTIME_DIR_VAR export DISPLAY=$CURRENT_DISPLAY; $WALLPAPER_SCRIPT >> \"$CRON_LOG_FILE\" 2>&1"

        echo "Cron job entry to be added:"
        echo "$CRON_JOB_ENTRY"
        echo ""

        echo "--- Modifying crontab ---"
        # Get current crontab entries, remove any existing lines for this script
        (crontab -l 2>/dev/null | grep -v "$WALLPAPER_SCRIPT") > /tmp/crontab_temp_$$
        # Add the new cron job entry
        echo "$CRON_JOB_ENTRY" >> /tmp/crontab_temp_$$

        # Install the updated crontab
        crontab /tmp/crontab_temp_$$
        if [ $? -eq 0 ]; then
            echo "Cron job successfully added/updated."
            echo "Your wallpaper should now update every ${CRON_INTERVAL% *}."
            echo "Check '$CRON_LOG_FILE' for script output and errors."
            rm /tmp/crontab_temp_$$
        else
            echo "Error: Failed to add/update cron job."
            echo "Please check permissions or try adding it manually with 'crontab -e'."
            rm /tmp/crontab_temp_$$
            exit 1
        fi
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo ""
echo "--- Setup complete ---"
echo "To remove the cron job later, run 'crontab -e' and delete the line containing '$WALLPAPER_SCRIPT'."
