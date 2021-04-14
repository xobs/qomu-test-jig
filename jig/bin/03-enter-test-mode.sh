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

# Reset the target
gpio -g mode $reset_pin out
gpio -g write $reset_pin 0
sleep .1
gpio -g write $reset_pin 1
sleep .1

if [ -e $acm_file ]
then
    echo "ACM file $acm_file existed immediately following reset!"
    exit 1
fi

# When the device appears, it will create this ACM file. This takes a
# while.

echo "Waiting for $acm_file to appear"
sleep 1
for i in $(seq $acm_file_timeout)
do
    if [ -e $acm_file ]
    then
        echo "$acm_file appeared after $i seconds"
        break
    fi
    sleep 1
done

[ -e $acm_file ] 
