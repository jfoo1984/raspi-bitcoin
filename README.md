# raspi-bitcoin
This project contains scripts and other things I used to set up and maintain a raspi powered antminer U3.

# cgmon script
I found this cgmon script on the bitcointalk forum.  It does not seem to have been updated in about a year (as of this writing), so I made some modifications to it to work with the Raspberry Pi cgminer setup.
[Original cgmon description](https://bitcointalk.org/index.php?topic=353436.0)
[Original cgmon download](http://www.forked.net/~apex/cgmon/cgmon.tcl)

Made some tweaks to correctly run cgminer with sudo, and to use a conf file to set mining pools and other settings.
