#!/bin/bash

# This script configures a cron job to automatically update the wallpaper
# using your generate_wallpaper.sh script.

# --- Configuration ---
# IMPORTANT: Adjust these paths if your setup is different!
SCRIPT_DIR="$HOME/wallpaper-generator"
WALLPAPER_SCRIPT="$SCRIPT_DIR/generate_wallpaper.sh"
CRON_LOG_FILE="$SCRIPT_DIR/cron_wallpaper.log"
CRON_INTERVAL="*/5 * * * *" # Run every 5 minutes. Change as desired (e.g., "0 */1 * * *" for every hour)

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

# --- Determine DISPLAY and XAUTHORITY ---
# These are crucial for cron jobs to interact with your graphical session.
echo "--- Determining DISPLAY and XAUTHORITY for your session ---"
# Attempt to get DISPLAY and XAUTHORITY from active user sessions
# This is a common method for desktop users but might vary.
CURRENT_DISPLAY=$(echo $DISPLAY)
CURRENT_XAUTHORITY=$(echo $XAUTHORITY)

# If XAUTHORITY is empty, try a common default path
if [ -z "$CURRENT_XAUTHORITY" ]; then
    CURRENT_XAUTHORITY="$HOME/.Xauthority"
fi

# Fallback for DISPLAY if not found in current environment
if [ -z "$CURRENT_DISPLAY" ]; then
    # Try to find an active display using loginctl or who
    # This is less reliable but might work on some systems
    USER_ID=$(id -u)
    ACTIVE_SESSION_ID=$(loginctl list-sessions --no-legend | grep "$USER_ID" | awk '{print $1}' | head -n 1)
    if [ -n "$ACTIVE_SESSION_ID" ]; then
        SESSION_TYPE=$(loginctl show-session "$ACTIVE_SESSION_ID" -p Type | cut -d'=' -f2)
        if [ "$SESSION_TYPE" == "x11" ]; then
            CURRENT_DISPLAY=":0" # Common default for X11 sessions
            echo "Guessed DISPLAY as :0 based on active X11 session."
        elif [ "$SESSION_TYPE" == "wayland" ]; then
            # Wayland specific handling might be needed, gsettings usually works
            # but xfconf-query (XFCE) might still rely on Xwayland's DISPLAY.
            # For simplicity, we'll keep :0 as a general fallback for now.
             CURRENT_DISPLAY=":0" # Xwayland might still use :0
            echo "Guessed DISPLAY as :0 for Wayland (via Xwayland if used)."
        fi
    fi
fi


if [ -z "$CURRENT_DISPLAY" ]; then
    echo "Warning: Could not automatically determine DISPLAY variable. Defaulting to :0."
    echo "If wallpaper doesn't change, you might need to manually specify DISPLAY (e.g., :1, :0.0) in the cron job."
    CURRENT_DISPLAY=":0"
fi

if [ ! -f "$CURRENT_XAUTHORITY" ]; then
    echo "Warning: XAUTHORITY file not found at '$CURRENT_XAUTHORITY'. This might prevent wallpaper changes."
    echo "If wallpaper doesn't change, verify your .Xauthority path."
    # If the file doesn't exist, remove the variable from the cron entry to avoid errors,
    # hoping the DE's wallpaper setter can still operate.
    XAUTH_VAR=""
else
    XAUTH_VAR="export XAUTHORITY=$CURRENT_XAUTHORITY;"
fi

echo "Using DISPLAY=$CURRENT_DISPLAY"
if [ -n "$XAUTH_VAR" ]; then
    echo "Using XAUTHORITY=$CURRENT_XAUTHORITY"
fi
echo ""

# --- Prepare the cron job entry ---
CRON_JOB_ENTRY="$CRON_INTERVAL $XAUTH_VAR export DISPLAY=$CURRENT_DISPLAY; $WALLPAPER_SCRIPT >> \"$CRON_LOG_FILE\" 2>&1"

echo "--- Preparing cron job ---"
echo "Cron job entry to be added:"
echo "$CRON_JOB_ENTRY"
echo ""

# --- Add/Update cron job ---
echo "--- Modifying crontab ---"
# Get current crontab entries
(crontab -l 2>/dev/null | grep -v "$WALLPAPER_SCRIPT") > /tmp/crontab_temp_$$
# The grep -v part removes any existing lines containing the script path,
# ensuring we don't duplicate entries if the script is run multiple times.

# Add the new cron job entry
echo "$CRON_JOB_ENTRY" >> /tmp/crontab_temp_$$

# Install the updated crontab
crontab /tmp/crontab_temp_$$
if [ $? -eq 0 ]; then
    echo "Cron job successfully added/updated."
    echo "Your wallpaper should now update every ${CRON_INTERVAL% *} minutes."
    echo "Check '$CRON_LOG_FILE' for script output and errors."
    rm /tmp/crontab_temp_$$
else
    echo "Error: Failed to add/update cron job."
    echo "Please check permissions or try adding it manually with 'crontab -e'."
    rm /tmp/crontab_temp_$$
    exit 1
fi

echo ""
echo "--- Installation complete ---"
echo "To remove the cron job later, run 'crontab -e' and delete the line containing '$WALLPAPER_SCRIPT'."
