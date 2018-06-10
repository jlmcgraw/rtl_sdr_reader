#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace
IFS=$(printf '\n\t')   # IFS is newline or tab

# If you did not "make install" rtl_433 you will need to adjust the path to it
# eg ~/Documents/github/rtl_433/build/src/rtl_433 

# Where data from the programs is stored
rtl_433_data_file="rtl_433_data.json"
rtlamr_data_file="rtlamr_data.json"

function finish {
    stop_rtl_tcp
    exit 0
}

function playbeep {
    # Beep forever to signify that something is wrong
    while true
    # for i in {1..5}
    do
        echo -ne '\007'
        sleep 1
    done
}

function stop_rtl_tcp {
    # Kill the rtl_tcp process we started
    echo "killing rtl_tcp process started with PID ${rtl_tcp_pid}"
    kill -9 "${rtl_tcp_pid}"
    echo $?
    sleep 5
}

function start_rtl_tcp {
    # Start the rtl_tcp process in the background and save the PID for stopping
    # the process later
    # ouput is is "rtl_tcp.log" for troubleshooting
    (rtl_tcp &>rtl_tcp.log) & rtl_tcp_pid=$!
    echo "rtl_tcp process started with PID ${rtl_tcp_pid}"
    # Give the rtl_tcp process time to initialize
    sleep 5
}

# Start the rtl_tcp process
start_rtl_tcp

# Set up traps so we can kill rtl_tcp process if script is interrupted
trap finish HUP INT QUIT PIPE TERM EXIT

# Create these files if they don't exist ( or update time if they do )
touch "$rtlamr_data_file"
touch "$rtl_433_data_file"

while true
do
    ## Start the rtl_tcp process in the background
    #start_rtl_tcp


        echo "--------------------------------------------"
        echo "900 Mhz Utilities reader"

        size_before=$(stat -c%s "$rtlamr_data_file" )
        # echo "Size before is ${size_before}"
        
        ~/go/bin/rtlamr         \
                -duration=120s  \
                -unique=true    \
                -format=json    \
                >> "$rtlamr_data_file"

        size_after=$(stat -c%s "$rtlamr_data_file")
        #echo "Size after is ${size_after}"
        
        if [[ $size_after == "$size_before" ]]; then
            echo "No data collected from 900 mhz devices"
            stop_rtl_tcp            
            start_rtl_tcp
            playbeep
            # exit 1
        fi
        echo "--------------------------------------------"
        # Seeing if there are any IDM messages
        ~/go/bin/rtlamr         \
                -msgtype=idm    \
                -duration=120s  \
                -unique=true    \
                -format=json    \
                >> "$rtlamr_data_file"

        echo "--------------------------------------------"
        echo "433 Mhz reader"

        size_before=$(stat -c%s "$rtl_433_data_file")
        # echo "Size before is ${size_before}"

        # Use process redirection to treat stdout from rtl_client.sh as an input
        # file for rtl_433
        ~/Documents/github/rtl_433/build/src/rtl_433    \
                -r <( ./rtl_client.sh  -f 433920000  -s 250000 -g 0 )    \
                -F json \
                -q      \
                -T 120  \
                >> "$rtl_433_data_file"

        size_after=$(stat -c%s "$rtl_433_data_file")
        # echo "Size after is ${size_after}"

        if [[ $size_after == "$size_before" ]]; then
            echo "No data collected from 433 mhz devices"
            stop_rtl_tcp            
            start_rtl_tcp
            playbeep
            # exit 1
        fi
done


