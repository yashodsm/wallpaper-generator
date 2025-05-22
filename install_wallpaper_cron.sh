#!/bin/bash

# install_wallpaper_cron.sh
# This script sets up a cron job to automatically run generate_wallpaper.sh
# at a specified interval.

# --- Configuration ---
# IMPORTANT: Customize these paths and settings!
# The directory where generate_wallpaper.sh and wallpaper_template.png are located.
# This defaults to the directory where install_wallpaper_cron.sh is located.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
WALLPAPER_SCRIPT="$SCRIPT_DIR/generate_wallpaper.sh"
CRON_LOG_FILE="$SCRIPT_DIR/cron_wallpaper.log"

# Cron interval:
# Examples:
#   "*/5 * * * *"  = Every 5 minutes
#   "0 */1 * * *"  = Every hour on the hour (e.g., 08:00, 09:00)
#   "0 9 * * *"    = Every day at 9:00 AM
CRON_INTERVAL="*/5 * * * *"

# --- Pre-requisite Checks ---
echo "--- Starting cron job installer ---"
echo "Verifying prerequisites..."

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
touch "$CRON_LOG_FILE" &>/dev/null # Attempt to create/touch log file silently
if [ $? -ne 0 ]; then
    echo "Error: Could not create or touch log file '$CRON_LOG_FILE'. Check directory permissions."
    echo "Please ensure '$SCRIPT_DIR' is writable by your user."
    exit 1
fi

echo "Prerequisites checked successfully."
echo ""

# --- Determine DISPLAY and XAUTHORITY ---
# These variables are essential for cron jobs to interact with your graphical session
# and set the wallpaper.
echo "--- Detecting graphical session environment variables ---"
CURRENT_DISPLAY=$(echo $DISPLAY)
CURRENT_XAUTHORITY=$(echo $XAUTHORITY)

# Fallback for XAUTHORITY if empty (common default path)
if [ -z "$CURRENT_XAUTHORITY" ]; then
    CURRENT_XAUTHORITY="$HOME/.Xauthority"
    echo "XAUTHORITY not found in current session, defaulting to: $HOME/.Xauthority"
fi

# Fallback for DISPLAY if empty
if [ -z "$CURRENT_DISPLAY" ]; then
    # Try to find an active display using loginctl for desktop sessions
    # This is a common method for X11 on modern Linux systems.
    USER_ID=$(id -u)
    ACTIVE_SESSION_ID=$(loginctl list-sessions --no-legend | grep "$USER_ID" | awk '{print $1}' | head -n 1)
    if [ -n "$ACTIVE_SESSION_ID" ]; then
        SESSION_TYPE=$(loginctl show-session "$ACTIVE_SESSION_ID" -p Type | cut -d'=' -f2)
        if [ "$SESSION_TYPE" == "x11" ]; then
            CURRENT_DISPLAY=":0" # Standard X11 display
            echo "Guessed DISPLAY as :0 based on active X11 session."
        elif [ "$SESSION_TYPE" == "wayland" ]; then
            # Wayland sessions often still use Xwayland for X11 apps like gsettings
            # so :0 is often still valid for setting wallpaper via X11 methods.
            CURRENT_DISPLAY=":0"
            echo "Guessed DISPLAY as :0 for Wayland (via Xwayland if used)."
        fi
    fi
    # If still not found, a very common default
    if [ -z "$CURRENT_DISPLAY" ]; then
        CURRENT_DISPLAY=":0"
        echo "DISPLAY variable still unknown, defaulting to :0. This might require manual adjustment."
    fi
fi

# Confirming the found values
echo "Detected DISPLAY=$CURRENT_DISPLAY"
if [ -f "$CURRENT_XAUTHORITY" ]; then
    echo "Detected XAUTHORITY=$CURRENT_XAUTHORITY"
    XAUTH_VAR="export XAUTHORITY=$CURRENT_XAUTHORITY;"
else
    echo "Warning: XAUTHORITY file '$CURRENT_XAUTHORITY' not found. This might prevent wallpaper changes if the DE requires it."
    XAUTH_VAR="" # Don't export if file doesn't exist
fi
echo ""

# --- Prepare the cron job entry ---
# The full command to be executed by cron
CRON_JOB_COMMAND="$XAUTH_VAR export DISPLAY=$CURRENT_DISPLAY; $WALLPAPER_SCRIPT >> \"$CRON_LOG_FILE\" 2>&1"
CRON_JOB_ENTRY="$CRON_INTERVAL $CRON_JOB_COMMAND"

echo "--- Preparing cron job entry ---"
echo "The following line will be added/updated in your crontab:"
echo "$CRON_JOB_ENTRY"
echo ""

# --- Add/Update cron job ---
echo "--- Modifying user crontab ---"
# Get current crontab entries, filter out old entries of this script, then add the new one.
# '2>/dev/null' suppresses "no crontab for user" error if crontab is empty.
(crontab -l 2>/dev/null | grep -v "$WALLPAPER_SCRIPT") > /tmp/crontab_temp_$$
echo "$CRON_JOB_ENTRY" >> /tmp/crontab_temp_$$

# Install the updated crontab
crontab /tmp/crontab_temp_$$
if [ $? -eq 0 ]; then
    echo "Cron job successfully added/updated."
    echo "Your wallpaper should now attempt to update every ${CRON_INTERVAL%% *} minutes."
    echo "Check '$CRON_LOG_FILE' for script output and any errors."
    rm /tmp/crontab_temp_$$ # Clean up temporary file
else
    echo "Error: Failed to add/update cron job."
    echo "Please check permissions or try adding it manually with 'crontab -e'."
    rm /tmp/crontab_temp_$$ # Clean up temporary file
    exit 1
fi

echo ""
echo "--- Installation complete ---"
echo "To remove this cron job later, run 'crontab -e' and delete the line containing '$WALLPAPER_SCRIPT'."
echo "To manually test the wallpaper script, run: '$WALLPAPER_SCRIPT'"
