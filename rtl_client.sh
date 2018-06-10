#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace
IFS=$(printf '\n\t')   # IFS is newline or tab

# A simple bash rtl_tcp client
# From http://flux242.blogspot.com/2017/04/how-to-connect-rtl433-to-remote-rtltcp.html

SET_FREQUENCY=1
SET_SAMPLE_RATE=2
SET_GAIN_MODE=3
SET_GAIN=4
SET_FREQUENCY_CORRECTION=5
SET_AGC_MODE=8

show_error_exit()
    {
      echo "$1" >&2
      echo "For help: $0 -h"
      exit 2
    }

show_usage()
{
cat <<HEREDOC
Usage: $1 [options]

Options:
  -h,             show this help message and exit
  -f FREQUENCY,   Frequency in Hz to tune to
  -a ADDRESS,     Address of the server to connect to (default: localhost)
  -p PORT,        Port of the server to connect to (default:1234)
  -s SAMPLERATE,  Sample rate to use (default: 2400000)
  -g GAIN,        Gain to use (default: 0 for auto)
  -P PPM,         PPM error (default: 0)
HEREDOC
}

byte()
    {
      printf \\$(printf "%03o" "$1")
    }

int2bytes()
    {
      byte $(($1>>24))
      byte $(($1>>16&255))
      byte $(($1>>8&255))
      byte $(($1&255))
    }

set_frequency()
    {
      byte $SET_FREQUENCY
      int2bytes "$1"
    }

set_sample_rate()
    {
      byte $SET_SAMPLE_RATE
      int2bytes "$1"
    }

set_gain()
    {
      if [ "$1" -eq 0 ]; then
        # automatic gain control
        byte $SET_GAIN_MODE
        int2bytes 0
        byte $SET_AGC_MODE
        int2bytes 1
      else
        byte $SET_GAIN_MODE
        int2bytes 1
        byte $SET_AGC_MODE
        int2bytes 0
        byte $SET_GAIN
        int2bytes 0
        byte $SET_GAIN
        int2bytes "$1"
      fi
    }

set_ppm()
    {
      byte $SET_FREQUENCY_CORRECTION
      int2bytes "$1"
    }

# Default values
address='localhost'
port=1234
frequency=0
samplerate=0
gain=0
ppm=0

# reset index
OPTIND=1 
while getopts "ha:p:f:s:g:P:" opt; do
  case $opt in
     h)  show_usage "$(basename "$0")"; exit 0; ;;
     a)  address="$OPTARG" ;;
     p)  port="$OPTARG" ;;
     f)  frequency="$OPTARG" ;;
     s)  samplerate="$OPTARG" ;;
     g)  gain="$OPTARG" ;;
     P)  ppm="$OPTARG" ;;
     \?) exit 1 ;;
     :)  echo "Option -$OPTARG requires an argument" >&2;exit 1 ;;
  esac
done
shift $((OPTIND-1)) 
 
[ ! "$frequency" -eq 0 ] || show_error_exit "Wrong frequency"
[ ! "$samplerate" -eq 0 ] || show_error_exit "Wrong sample rate"

(set_frequency "$frequency";
 set_sample_rate "$samplerate";
 set_gain "$gain";
 set_ppm "$ppm") | nc "$address" "$port"
