#!/bin/sh

led_1=19
led_2=13

led_idle=19
led_fail=13

if [ "x$(which gpio)" = "x" ]
then
	echo "No 'gpio' command found! Install wiringpi."
	exit 1
fi

all_off() {
	gpio -g write ${led_1} 0
	gpio -g write ${led_2} 0
}

fail_on() {
	gpio -g write ${led_fail} 1
}

fail_off() {
	gpio -g write ${led_fail} 0
}

idle_on() {
	gpio -g write ${led_idle} 1
}

idle_off() {
	gpio -g write ${led_idle} 0
}

led_on() {
	case $1 in
	1) gpio -g write ${led_1} on ;;
	2) gpio -g write ${led_2} on ;;
	esac
}

led_off() {
	case $1 in
	1) gpio -g write ${led_1} off ;;
	2) gpio -g write ${led_2} off ;;
	esac
}

gpio_setup() {
	gpio -g mode ${led_1} out
	gpio -g mode ${led_2} out
	for i in $(seq 1 2)
	do
		all_off
		led_on $i
		sleep .2
	done

	all_off
	idle_on
	fail_on
	sleep 1

	all_off
	idle_on
}

fail_test() {
	fail_on
}

gpio_setup

echo "HELLO bash-ltc-jig 1.0"
while read line
do
	if echo "${line}" | grep -iq '^start'
	then
		all_off
		failures=0
	elif echo "${line}" | grep -iq '^fail'
	then
		if [ $failures -ne 1 ]
		then
			failures=1
			fail_test $(echo "${line}" | awk '{print $2}')
		fi
		fail_on
	elif echo "${line}" | grep -iq '^finish'
	then
		idle_on
	elif echo "${line}" | grep -iq '^exit'
	then
		all_off
		exit 0
	fi
done
