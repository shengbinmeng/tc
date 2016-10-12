#!/bin/bash

DST_IP_RANGE=10.9.26.121/32
DST_PORT_RANGE="7012 0xffff" # u32 match
METHOD="tbf"

function finish {
  # Restore to system default
  tc qdisc del dev eth0 root 1>/dev/null 2>&1
}
# Need to cleanup no matter how we exit
trap finish EXIT

function init {
    echo "Init with rate limit of 990kbps (kbits per second)"
    if [ ${METHOD} == "htb" ]; then
        # Add the new root qdisc
        tc qdisc replace dev eth0 root handle 1: htb
        tc class add dev eth0 parent 1: classid 1:1 htb rate 990kbit
        # Set our rate limit
        tc filter add dev eth0 protocol ip parent 1:0 prio 1 u32 match ip dst ${DST_IP_RANGE} match ip dport ${DST_PORT_RANGE} flowid 1:1
    elif [ ${METHOD} == "tbf" ]; then
        # See https://wiki.linuxfoundation.org/networking/netem
        tc qdisc replace dev eth0 root handle 1: prio
        tc qdisc add dev eth0 parent 1:3 handle 30: tbf rate 990kbit buffer 1600 limit 3000
        # Add delay with netem (netem can also emulate packet loss, corrupt, reorder, etc)
        tc qdisc add dev eth0 parent 30:1 handle 31: netem delay 100ms loss 5%
        tc filter add dev eth0 protocol ip parent 1:0 prio 3 u32 match ip dst ${DST_IP_RANGE} match ip dport ${DST_PORT_RANGE} flowid 1:3
    fi
    tc -s -d qdisc show dev eth0
    tc -s -d class show dev eth0
}

function limit_rate {
    rate=$1
    echo "Limit rate to ${rate}kbps (kbits per second)"
    if [ ${METHOD} == "htb" ]; then
        tc class change dev eth0 parent 1: classid 1:1 htb rate ${rate}kbit
    elif [ ${METHOD} == "tbf" ]; then
        tc qdisc change dev eth0 parent 1:3 handle 30: tbf rate ${rate}kbit buffer 1600 limit 3000
    fi
    tc -s -d qdisc show dev eth0
    tc -s -d class show dev eth0
}


#
# Read samples
#
if [ $# -ne 1 ]; then
    echo "Usage: $0 FILE"
    exit
fi

filename=$1
count=0
while read bandwidth[count] duration[count]; do
    if [ -n "${bandwidth[count]}" ] && [ -n "${duration[count]}" ]; then
        count=$count+1
    fi
done < ${filename}

#
# Initialize
#
init


#
# Simulate
#
# First wait for a while
unit=60
current=`date +"%s"`
wait=$(($unit - $current % $unit))
echo "$wait seconds before changing rate limit"
sleep $wait

# Change bandwidth according to read data
for ((i=0; i<$count; i++)) do
    limit_rate ${bandwidth[i]}
    sleep ${duration[i]}
done

#
# Cleanup
#
finish
echo "Done"
