#!/usr/bin/env python3
import evdev
import subprocess
import time
import os
from evdev import InputDevice, ecodes

# Function to find the keyboard device
def find_keyboard():
    devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
    for dev in devices:
        # This heuristic might need tuning based on the specific keyboard
        if "keyboard" in dev.name.lower():
            return dev
    return None

def main():
    dev = find_keyboard()
    if not dev:
        print("No keyboard found")
        return

    # Key constants
    F8 = ecodes.KEY_F8
    F12 = ecodes.KEY_F12

    # State tracking
    pressed = {F8: False, F12: False}

    # Grab the device? 
    # NO. If we grab it, 86Box gets nothing. We must passively sniff.
    
    for event in dev.read_loop():
        if event.type == ecodes.EV_KEY:
            if event.code in pressed:
                # Update state: 1=Down, 2=Hold, 0=Up
                pressed[event.code] = (event.value > 0)

            # Check for Combo
            if pressed[F8] and pressed[F12]:
                # DEBOUNCE: Wait to ensure it wasn't a fluke
                time.sleep(0.1)
                
                # TRIGGER SEQUENCE
                trigger_menu()
                
                # Reset states to avoid loop
                pressed[F8] = False
                pressed[F12] = False

def trigger_menu():
    # 1. Pause 86Box (Critical for stable menu usage)
    # We use xdotool to send the 86Box specific pause shortcut (Configured to Ctrl+Alt+P)
    subprocess.run(["xdotool", "search", "--class", "86Box", "key", "Ctrl+Alt+P"])
    
    # 2. Release Input Grab
    # We send the 86Box "Release Mouse" shortcut (Configured to F8+F12 or Ctrl+End)
    # Since the user is physically holding F8+F12, 86Box *should* have seen it, 
    # but we force a release to be sure.
    # NOTE: Assuming F8+F12 is also the mouse release key in 86Box config, or Ctrl+End
    subprocess.run(["xdotool", "search", "--class", "86Box", "key", "Ctrl+End"])
    
    # 3. Launch the GUI Menu (YAD)
    # Run as the 'pi' user on Display :0
    cmd = ["sudo", "-u", "pi", "DISPLAY=:0", "/usr/local/bin/show_menu.sh"]
    subprocess.run(cmd)

    # 4. Resume on Exit
    # When menu closes, unpause 86Box
    subprocess.run(["xdotool", "search", "--class", "86Box", "key", "Ctrl+Alt+P"])

if __name__ == "__main__":
    main()
