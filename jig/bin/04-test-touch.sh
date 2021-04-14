#!/bin/sh
touch1_pin=21
touch2_pin=20
touch3_pin=16
touch4_pin=12
acm_file=/dev/ttyACM0

set -e

gpio -g mode $touch1_pin in
gpio -g mode $touch2_pin in
gpio -g mode $touch3_pin in
gpio -g mode $touch4_pin in

acm_command() {
    echo $1 > $acm_file
    sleep 0.1
}

acm_setup() {
    stty -F $acm_file \
line 0 \
min 1 \
time 0 \
-brkint -icrnl -imaxbel \
-opost \
-isig -icanon -iexten -echo
}

led_test() {
    echo "Test Red"
    acm_command red
    sleep 1
    acm_command red
    echo "Test Blue"
    acm_command blue
    sleep 1
    acm_command blue
    echo "Test Green"
    acm_command green
    sleep 1
    acm_command green
}

touch_test() {
    error_count=0
    acm_command setalltp0
    if [ "x$1" = "x1" ]
    then
        acm_command tp1
    fi

    if [ "x$2" = "x1" ]
    then
        acm_command tp2
    fi

    if [ "x$3" = "x1" ]
    then
        acm_command tp3
    fi

    if [ "x$4" = "x1" ]
    then
        acm_command tp4
    fi

    touch1_val=$(gpio -g read $touch1_pin)
    touch2_val=$(gpio -g read $touch2_pin)
    touch3_val=$(gpio -g read $touch3_pin)
    touch4_val=$(gpio -g read $touch4_pin)

    echo -n "TOUCH1:$touch1_val "
    echo -n "TOUCH2:$touch2_val "
    echo -n "TOUCH3:$touch3_val "
    echo "TOUCH4:$touch4_val"

    if [ "x$1" = "x1" ] && [ $touch1_val -ne 1 ]
    then
        echo "TOUCH1 was supposed to be 1, but was 0" 1>&2
        error_count=$(($error_count+1))
    elif [ "x$1" != "x1" ] && [ $touch1_val -ne 0 ]
    then
        echo "TOUCH1 was supposed to be 0, but was 1" 1>&2
        error_count=$(($error_count+1))
    fi

    if [ "x$2" = "x1" ] && [ $touch2_val -ne 1 ]
    then
        echo "TOUCH2 was supposed to be 1, but was 0" 1>&2
        error_count=$(($error_count+1))
    elif [ "x$2" != "x1" ] && [ $touch2_val -ne 0 ]
    then
        echo "TOUCH2 was supposed to be 0, but was 1" 1>&2
        error_count=$(($error_count+1))
    fi

    if [ "x$3" = "x1" ] && [ $touch3_val -ne 1 ]
    then
        echo "TOUCH3 was supposed to be 1, but was 0" 1>&2
        error_count=$(($error_count+1))
    elif [ "x$3" != "x1" ] && [ $touch3_val -ne 0 ]
    then
        echo "TOUCH3 was supposed to be 0, but was 1" 1>&2
        error_count=$(($error_count+1))
    fi

    if [ "x$4" = "x1" ] && [ $touch4_val -ne 1 ]
    then
        echo "TOUCH4 was supposed to be 1, but was 0" 1>&2
        error_count=$(($error_count+1))
    elif [ "x$4" != "x1" ] && [ $touch4_val -ne 0 ]
    then
        echo "TOUCH4 was supposed to be 0, but was 1" 1>&2
        error_count=$(($error_count+1))
    fi

    return $error_count
}

acm_setup
acm_command exit
acm_command diag

echo "Should be all zero:"
touch_test 0 0 0 0

echo "Should be TOUCH1 only:"
touch_test 1 0 0 0

echo "Should be TOUCH2 only:"
touch_test 0 1 0 0

echo "Should be TOUCH3 only:"
touch_test 0 0 1 0

echo "Should be TOUCH4 only:"
touch_test 0 0 0 1

echo "Should be all ones:"
touch_test 1 1 1 1

led_test
led_test
