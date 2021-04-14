#!/bin/sh

# Exit on error
set -e

# Toggle a pin at a 1-second interval
toggle() {
    gpio -g mode $1 out
    echo "Toggling GPIO $1..."
    while true; do
        gpio -g write $1 0
        sleep 1
        gpio -g write $1 1
        sleep 1
    done
}

# Set Raspberry Pi drive strength for pads 0-27 to 12 mA.
# 0 = 2mA
# 1 = 4mA
# 2 = 6mA
# 3 = 8mA
# 4 = 10mA
# 5 = 12mA
# 6 = 14mA
# 7 = 16mA
gpio drive 0 5

gpio -g mode 27 out
./fomu-flash -w test-image.bin || exit 1
./fomu-flash -v test-image.bin || exit 1

# Bring the device out of reset
gpio -g write 27 1
