#!/bin/sh

set -e
ff=./fomu-flash

program() {
    filename="$1"
    start="$2"
    length="$3" # Ignored
    if [ -z $length ] || [ -z $start ] || [ -z $filename ]
    then
        echo "Missing filename, start, or length"
        return 1
    fi

    echo "Writing $filename.bin to $start..."
    $ff -w image/$filename.bin -a $start
}

gpio drive 0 6
$ff -i
program 01-bootloader 0 0x10000
program 02-bootfpga-metadata 0x10000 0x1000
program 03-appfpga-metadata 0x11000 0x1000
program 04-appfile-metadata 0x12000 0x1000 # Future
program 05-m4app-metadata 0x13000 0x1000
# Reserved 0x14000 0xb000
program 07-bootloader-metadata 0x1f000 0x1000 # Future
program 08-bootfpga 0x20000 0x20000
program 09-appfpga 0x40000 0x20000
program 10-appffe 0x60000 0x20000 # Future
program 11-m4app 0x80000 0x6e000 # Future
# Reserved 0xee000 0x12000
