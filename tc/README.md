Traffic control on Linux.

# Script

The script `tc.sh` uses the tool `tc` to emulate bandwidth change.

It reads lines from a file (e.g. `bandwidth.txt`).
Each line specifies a bandwidth value and how many seconds this bandwidth lasts.

# Note

`iperf` can be used to perform network throughput tests (generate and send data).

For example, run `iperf -s -u` on server and `iperf -c <SERVER> -u -n 1G -b 300k` on client.
This will send 1G bytes data to `<SERVER>` via UDP at the rate of 300kbps.

`iftop` can be used to display bandwidth usage on an interface.


