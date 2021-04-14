#!/bin/sh
touch1_pin=21
touch2_pin=20
touch3_pin=16
touch4_pin=12
reset_pin=27

acm_file=/dev/ttyACM0
acm_file_timeout=10

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

# Reset the target
gpio -g write $reset_pin 0
gpio -g write $reset_pin 1

# Toggle TOUCH1
gpio -g mode $touch1_pin out
echo "Toggling TOUCH1..."
gpio -g write $touch1_pin 0; sleep 1
gpio -g write $touch1_pin 1; sleep 1
gpio -g write $touch1_pin 0; sleep 1
gpio -g write $touch1_pin 1; sleep 1

gpio -g mode $touch1_pin in
echo "Waiting for $acm_file to appear"
sleep 1
for i in $(seq $acm_file_timeout)
do
    if [ -e $acm_file ]
    then
        echo "$acm_file appeared after $i seconds"
        echo "Board should be in programmer mode"
        break
    fi
    sleep 1
done
[ -e $acm_file ]
