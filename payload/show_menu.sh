#!/bin/bash
export DISPLAY=:0

# Define the menu actions
ACTION=$(yad --list --title="Retro Appliance Control" \
   --text="System Paused. Select an option:" \
   --column="Function" --column="Description" \
   "Resume" "Return to emulation" \
   "Settings" "Open 86Box Configuration" \
   "Reset" "Hard Reset the Machine" \
   "Media" "Change CD-ROM / Floppy" \
   "Shutdown" "Power off the Raspberry Pi" \
   --width=500 --height=400 --center --no-buttons \
   --window-icon="preferences-system")

# Process the selection
case $ACTION in
   "Resume"*)
       exit 0
       ;;
   "Settings"*)
       # Send the shortcut to open 86Box's internal Qt Settings window
       # We assume Ctrl+Alt+S is configured in 86Box for settings
       xdotool search --class "86Box" key "Ctrl+Alt+S"
       ;;
   "Reset"*)
       # Send Hard Reset shortcut
       xdotool search --class "86Box" key "Ctrl+Alt+F12"
       ;;
   "Media"*)
       # Sub-menu for media (simplified)
       IMAGE=$(yad --file --title="Select Disk Image" --file-filter="*.iso *.img *.vhd")
       if [ ! -z "$IMAGE" ]; then
            # This requires 86Box to support CLI media changing or editing cfg
            # For appliance, simpler to just message the user to use internal menu
            yad --info --text="Please use the 'Settings' menu to mount: $IMAGE"
       fi
       ;;
   "Shutdown"*)
       # Graceful shutdown of the host
       sudo systemctl poweroff
       ;;
esac
