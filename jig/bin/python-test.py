#!/usr/bin/env python3

import tinyfpgaq
import os
import serial

ser = serial.Serial('/dev/ttyACM0', 115200, timeout=60, writeTimeout=60)
print("Creating TinyFPGAQ")
tfpga = tinyfpgaq.TinyFPGAQ(ser)
print("Getting SPI ID: ")
print(str(tfpga.read_id()))
print("Checking if boot is active")
print("Boot active? {}".format(tfpga.is_bootloader_active()))
