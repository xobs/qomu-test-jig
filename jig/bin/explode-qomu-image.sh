#!/bin/sh

#set -e

explode() {
    filename="$1"
    start="$2"
    length="$3"
    if [ -z $length ] || [ -z $start ] || [ -z $filename ]
    then
        echo "Missing filename, start, or length"
        return 1
    fi

    echo "Extracting $filename from" $(($start)) "that's" $(($length)) "long"
    dd \
        if=qomu_diagnostic.bin \
        of=$filename.bin \
        bs=4096 \
        skip=$(($start/4096)) \
        count=$((($length)/4096))

    # Trim if necessary
    end_of_data=$(hexdump -C $filename.bin | tail -n 3 | grep -C 3 '^\*$' | grep 'ff ff ff ff ff ff ff ff  ff ff ff ff ff ff ff ff' | awk '{print $1}')
    if [ $? -ne 0 ]
    then
        return 0
    fi
    end_of_data=$((0x$end_of_data))
    dd \
        if=$filename.bin \
        bs=$end_of_data \
        count=1 \
        of=trimmed.bin
    mv trimmed.bin $filename.bin
}

explode 01-bootloader 0 0x10000
explode 02-bootfpga-metadata 0x10000 0x1000
explode 03-appfpga-metadata 0x11000 0x1000
explode 04-appfile-metadata 0x12000 0x1000 # Future
explode 05-m4app-metadata 0x13000 0x1000
# Reserved 0x14000 0xb000
explode 07-bootloader-metadata 0x1f000 0x1000 # Future
explode 08-bootfpga 0x20000 0x20000
explode 09-appfpga 0x40000 0x20000
explode 10-appffe 0x60000 0x20000 # Future
explode 11-m4app 0x80000 0x6e000 # Future
# Reserved 0xee000 0x12000
