#!/usr/bin/tclsh
##############################
###  Usage instructions  ### 
# 
# 1) Install PHP, TCL and screen.  
# CentOS: yum install php53 tcl screen
# Ubuntu: apt-get install php5 php5-cli tcl screen
#
# 2) Edit the following line with your path to cgmon.tcl and then add it to /etc/crontab. *must run as root for DEAD/SICK GPU rebooting.
#    */2 * * * *	root	/home/user/cgmon.tcl >/dev/null 2>&1
#
# 3) chmod +x cgmon.tcl
#
# 4) Fill out the configuration sections below and test the script by running it directly: ./cgmon.tcl
#
# *) Sit back and enjoy a steadier flow of income :)
#############################

# GPU settings
set conf(cgminer_gpu_options) ""

# TODO: break out conf file setting and put a check to set it
# configuration file for miner executable
set conf(miner_conf) ""

# Extra options to pass to cgminer
# At least --api-listen is required for cgmon to work.
set conf(cgminer_extra_options) "--api-listen  --bmsc-options 115200:0.57 -c /home/pi/.cgminer/cgminer.conf --bmsc-voltage 0800 --bmsc-freq 1286"

# Username running X server (i.e. the username you use when logging into the Linux graphical interface)
# This must be correct or cgminer wont run properly.
set conf(mining_user) "pi"

# Primary mining pool 
#set pool(address1) ""
#set pool(user1) ""
#set pool(pass1) ""

# Additional mining pools (optional) 
#set pool(address2) ""
#set pool(user2) ""
#set pool(pass2) ""

# Email Notification (optional)
# set to 'yes' to enable
set mail(notify) "no"
set mail(host) "smtp.gmail.com"
set mail(port) "587"
set mail(to) "user@domain.com"
set mail(from) "user@domain.com"


# Use SMTP Authentication for email notifications? (required for Gmail and many ISPs)
# You must install 'tcllib' and 'tcl-tls'
# Ubuntu: apt-get install tcllib tcl-tls
# set to 'yes' to enable SMTP AUTH
set mail(auth) "no"
set mail(auth_user) "user@domain.com"
# gmail requires an 'application password' here.  For most other ISPs use your normal smtp auth password.
set mail(auth_pass) "password"

# send email when running script by hand (no or yes)
set mail(notify_on_manual_runs) "no"

# Executable to mine with.  cgminer, sgminer, vertminer* supported. 
# *vertminer - copy vertminers *.cl files (such as scrypt140120.cl) to /usr/local/bin/ for cgmon to start vertminer correctly via crontab.
set conf(cgminer_exec) "cgminer"

# this is required only if your cgminer_exec binary is NOT installed in your $mining_user's PATH (i.e. /usr/bin/)
# example:  /home/user/cgminer-3.1.1/       (must end with a '/')
set conf(cgminer_path) "/home/pi/cgminer/"

# Use --scrypt in mining command
# cgminer requires this option to be 'yes' when mining for scrypt based coins.  
# Set this to no for sgminer, vertminer, and any sha-256 mining (i.e. Bitcoin).
set conf(miner_requires_scrypt_flag) "no"

# Monitor the Accepted share count for each GPU.  
# If a GPU does not output at least one accepted share within $share_timer, cgmon will restart the computer.
set conf(checkshares) "yes"

# Minutes allowed without an accepted share
# 10 is a good number for GPU with a hashrate of at least 200KH/sec.  If you have a GPU under 200KH/sec increase this number.
set conf(share_timer) "10"

# Monitor the network status of all mining pools.  
set conf(checkpools) "yes"

# Reboot if all mining pools are unreachable.
set conf(reboot_when_pools_are_down) "no"

# You probably dont need to these two settings.
set conf(screen_cmd) "screen -mdS cgminer"
set conf(cgmon_logfile) "~$conf(mining_user)/cgmon.log"

set conf(ltc_add) "LPKwhKzFHypAw9yVqpFBEwTkxYTjTeTLan"
set conf(btc_add) "13D196kLTMPQMattuz2AtpzasX8pVW6G4U"
set conf(doge_add) "D9ULdP372WqcvgYbu5f1nWFLRPr3ugx3Nh"

set conf(cgminer_api) "/tmp/cgmon-api.php"
set conf(version) "1.0.9"
# change this to yes if you donated
set conf(donated) "yes"

#set conf(BAMT) "no"

# END configuration.


proc update_cgmon {} {
global conf pool mail

	set stop false
	set fd [open "cgmon.tcl.autoupdate" r]
	set newfd [open "cgmon.tcl.tmp" w]
	while {1} {
		set line [subst -nobackslashes -nocommands -novariables [gets $fd]]
		if {!$stop && [lindex $line 0] == "set"} { 
			set oldvarname [lindex $line 1]
			set oldvarvalue [lindex $line 2]
			if {[info exists $oldvarname]} {
				if {$oldvarname == "conf(version)"} {
					set newv $oldvarvalue
					puts $newfd $line
				} else {
					puts $newfd "set $oldvarname \"[expr $$oldvarname]\""
				}
			} else {
				# new variable found. just write it back to file
				puts $newfd "set $oldvarname \"$oldvarvalue\""
			}
		} else {
			puts $newfd $line
		}
		if {!$stop && [lindex $line 1] == "END"} { 
			#stop checking the rest of the code
			set stop true
		}
		if {[eof $fd]} {
			close $fd
			set cwd [exec pwd]
			catch {exec chmod +x $cwd/cgmon.tcl.tmp} out
			catch {exec cp $cwd/cgmon.tcl $cwd/cgmon.tcl.$config(version)} out
			puts "The previous version has been moved to $cwd/cgmon.tcl.$conf(version)."
			puts "Your customized cgmon $newv is now located at $cwd/cgmon.tcl.tmp. To finish the update process run this command:\nmv $cwd/cgmon.tcl.tmp $cwd/cgmon.tcl"
			exit
		}
	}

}

proc check_update {update} {
global conf

	catch {exec which wget} wgetexists
	if {$wgetexists == "child process exited abnormally"} {
		notice "Couldn't find wget.  Please install it.\n Ubuntu Example: apt-get install wget\n CentOS Example: yum install wget"
		exit
	}
	catch {exec wget -q http://www.forked.net/~apex/cgmon/cgmon.tcl -O cgmon.tcl.autoupdate} out
	puts $out
	if {[string first "denied" $out] > 0} {
		puts "exiting..."
		exit
	}
	exec chown $conf(mining_user) cgmon.tcl.autoupdate

	catch {exec grep "set conf(version)" cgmon.tcl.autoupdate} out
	set latest_version [lindex $out 2]
	if {$conf(version) >= $latest_version} {
		puts "Version Check:  You have $conf(version), latest is $latest_version."
		puts "cgmon is up to date."
	} else {
		puts "Version Check:  You have $conf(version), latest is $latest_version."
		after 1000
		if {$update} {
			puts "Updating now..."
			after 1000
			update_cgmon
		} else {
			return $latest_version
		}
	}
}





proc check_status {} {
global hostname pool conf

	set i 0
	
	catch {exec which php} phpexists
	if {$phpexists == "child process exited abnormally"} {
		notice "Couldn't find PHP.  Please install it.\n Ubuntu Example: apt-get install php5\n CentOS Example: yum install php5"
		exit
	}
	catch {exec which $conf(cgminer_exec)} cgminerexists
	
	if {$cgminerexists == "child process exited abnormally"} {
	catch {exec ls $conf(cgminer_path)$conf(cgminer_exec)} custom_path_exists
		if {[string first "No such" $custom_path_exists] > 0} {
			notice "Couldn't find \'$conf(cgminer_exec)\' in $::env(PATH) nor custom path \'$conf(cgminer_path)$conf(cgminer_exec)\'.  Please copy your $conf(cgminer_exec) executable to /bin/$conf(cgminer_exec) or edit cgminer_path in cgmon.tcl with the full path.\n"
			exit
		} else {
			if {$conf(cgminer_path) == ""} {
				#found local exec but no global exec, using local exec.
				catch {exec pwd} cwd
				set conf(cgminer_path) "$cwd/"
			}
		}
	}

	catch {exec ls $conf(cgminer_api)} apiexists
	if {[string first "No such" $apiexists] > 0} {
		notice "$conf(cgminer_exec) API $conf(cgminer_api) not found.  Do you have write permission to /tmp/?"
		exit
	}


	catch {exec ps -A | grep $conf(cgminer_exec)$} cg_status
	if {$cg_status == "child process exited abnormally"} {
		# cgminer is not running, restart it.
		notice "$conf(cgminer_exec) not running, starting via this command: "	

		# check if we need --scrypt.  Dont add --scrypt for sgminer or vertminer even if option was specified. (save user from themselves)
		if {$conf(miner_requires_scrypt_flag) == "yes" && $conf(cgminer_exec) != "sgminer" && $conf(cgminer_exec) != "vertminer"} {
			set cgminer_option1 "--scrypt"
		} else {
			set cgminer_option1 ""
		}
		
		# do not edit this unless you know what youre doing
		set mining_command "sudo $conf(cgminer_path)$conf(cgminer_exec) $conf(cgminer_extra_options) $cgminer_option1 "

		# Add pools
		if {[info exists pool(address1)] && $pool(address1) != ""} {append mining_command " -o $pool(address1) -u $pool(user1) -p $pool(pass1) "}
		if {[info exists pool(address2)] && $pool(address2) != ""} {append mining_command " -o $pool(address2) -u $pool(user2) -p $pool(pass2) "}
		if {[info exists pool(address3)] && $pool(address3) != ""} {append mining_command " -o $pool(address3) -u $pool(user3) -p $pool(pass3) "}
		if {[info exists pool(address4)] && $pool(address4) != ""} {append mining_command " -o $pool(address4) -u $pool(user4) -p $pool(pass4) "}
		if {[info exists pool(address5)] && $pool(address5) != ""} {append mining_command " -o $pool(address5) -u $pool(user5) -p $pool(pass5) "}
 		
 		append mining_command " $conf(cgminer_gpu_options)"
 		
		notice $mining_command

		# delete count of accepted shares when starting miner - otherwise a reboot could occur from reading irrelavent share counts
		exec rm -f /tmp/accepted_count

		# create bash script in /tmp/ to max use of environment variables for mining
		if {![catch { set outfd [open "/tmp/cgmon-mine.sh" w] }]} {
			puts $outfd "#!/bin/bash"
			puts $outfd "export DISPLAY=:0"
			puts $outfd "export GPU_MAX_ALLOC_PERCENT=100"
			puts $outfd "export GPU_USE_SYNC_OBJECTS=1"
			puts $outfd "$conf(screen_cmd) $mining_command"
			close $outfd
		}
		exec chmod 755 /tmp/cgmon-mine.sh
		exec chown $conf(mining_user) /tmp/cgmon-mine.sh
		set exec_cmd "/tmp/cgmon-mine.sh"

		# run the bash script as the correct user (the one running X hopefully)
		catch {exec whoami} script_user
		if {$script_user == $conf(mining_user)} {
			catch {exec /bin/bash -c $exec_cmd} out
		} elseif {$script_user == "root"} {
			catch {exec su $conf(mining_user) -c /bin/bash -c $exec_cmd} out
		} else {
			notice "attempted to start $conf(cgminer_exec) as the wrong user.  exiting."
			exit
		}
		
		# Check if miner started or not.
		if {$out == ""} {
			# delay required to give cgminer time to exit if it's going to
			after 1000
			catch {exec ps -A | grep $conf(cgminer_exec)$} cg_status
			if {$cg_status == "child process exited abnormally"} {
				# cgminer is not running, startup did not work.
				notice "$conf(cgminer_exec) failed to start.  Try running the mining command above to find the error.  Also, double check your GPU options."	
				sendmail "[stamp] $hostname - $conf(cgminer_exec) failed to start" "$hostname $conf(cgminer_exec) failed to start.\n mining command was: $mining_command\n"
			} else {
				notice "$conf(cgminer_exec) started successfully.  Use 'screen -r' to attach to $conf(cgminer_exec) and Control-a-d to detach."
				sendmail "[stamp] $hostname - Started $conf(cgminer_exec)" "$hostname $conf(cgminer_exec) was not running... starting $conf(cgminer_exec).\n"
			}
		}
		# need error checking here
		
		exit
			

	} else {
		# cgminer IS running.  Check if GPUs are healthy.
		# if the php script times out (after 2 seconds) this means cgminer is frozen and a reboot is required.
		catch {exec php -f $conf(cgminer_api) notify | grep "=>" | grep "Last Not Well"} argx
		if {![string match $argx "child process exited abnormally"]} {
			if {[string first "Connection refused" $argx] >1} {
				notice "$conf(cgminer_exec) API is not enabled/responding.  Restart $conf(cgminer_exec) with '--api-listen' or check the status of mining pools."
				exit
			} elseif {[string first "Connection reset" $argx] >1} {
				notice "$conf(cgminer_exec) unknown API error.  Make sure $conf(cgminer_exec) is listening on 127.0.0.1:4028"
				exit
			}
			
			# Find out which GPU is having a problem
			set data [split $argx "\n"]
			foreach line $data {
				set gpu_status [lindex $line 4]
				if {$gpu_status >1}  { 
					notice "GPU $i is sick or dead, rebooting...\n Status: $line"
					sendmail "[stamp] $hostname - GPU $i DEAD - Rebooting" "$hostname GPU $i was dead or sick... rebooting.\n Status: $line"			
					catch {exec echo "GPU $i DEAD - Rebooting in 10s..." | wall} out
					reboot
					exit
				}
				incr i
			}
		} else {
			# php API command timed out.  miner might be frozen.  wait 5 secs and try checking one more time...
			# it appears cgminer may become unresponsive when there are network issues connecting to a pool.  This can cause a false-positive reboot here.
			after 5000
			catch {exec php -f $conf(cgminer_api) notify | grep "=>" | grep "Last Not Well"} argx
			if {[string match $argx "child process exited abnormally"]} {
				notice "$conf(cgminer_exec) is not responding.  Rebooting."
				sendmail "[stamp] $hostname - $conf(cgminer_exec) is not responding - Rebooting" "$hostname $conf(cgminer_exec) is not responding... rebooting."			
				catch {exec echo "$conf(cgminer_exec) is not responding - Rebooting in 10s..." | wall} out
				reboot
				exit
			}
		}


	   # Check for dead AMD driver (when cgminer/sgminer hangs and only "responds" to q, but wont quit
	   # Thanks dr00g!
		catch {exec dmesg | grep "ASIC hang happened"} out
		if {[string first "ASIC hang happened" $out] > 0} {
				notice "AMD driver has crashed! Rebooting..."
				sendmail "[stamp] $hostname - AMD driver crashed - Rebooting" "$hostname AMD driver crashed... rebooting.\n"			
				reboot
		}

		# check for alive mining pools
		if {$conf(checkpools) == "yes"} {
			set livepools [check_pools]
			if {$livepools > 0} {
				# puts "$livepools alive pool(s)"
			} else {
				# miner is reporting all pools are unreachable
				if {$conf(reboot_when_pools_are_down) == "yes"} {
					sendmail "[stamp] $hostname - All pools unreachable - Rebooting" "$hostname All pools unreachable... rebooting.\n"
					notice "All pools unreachable.  Rebooting..."
					reboot
				} else {
					notice "All pools unreachable."
				}
			}
		}
			
		
		# check for cgminers that are running but are not ouputting good shares...
		if {$conf(checkshares)} {
			catch {exec php -f $conf(cgminer_api) devs | grep "Accepted\] =>" | grep -v Diff} argx
			set data [split $argx "\n"]
			set x 0
			foreach gpu $data {
				set current_accepted($x) [lindex $gpu 2]
				incr x
			}
			# Create the file to store the share counts in between runs 
			if {![file exists "/tmp/accepted_count"]} {
				exec touch /tmp/accepted_count
				exec chmod 777 /tmp/accepted_count
				exec chown $conf(mining_user) /tmp/accepted_count
			}
			set fd [open "/tmp/accepted_count" r]
			for {set n 0} {$n<=[expr $x-1]} {incr n} {
				set line "[gets $fd]"
				set previous_accepted($n) [lindex $line 0]
				set previous_time [lindex $line 1]
				if {$previous_time != ""} {
					set elapsed_seconds [expr [clock seconds] - $previous_time]
					if {$elapsed_seconds > [expr $conf(share_timer) * 60]} {
						set acc_rate_sec [expr [expr  $current_accepted($n) -  $previous_accepted($n)] / [expr $elapsed_seconds/60.0]]
						if {$current_accepted($n) > $previous_accepted($n)} {
							notice [format "GPU $n Shares accepted since last run:  [expr  $current_accepted($n) -  $previous_accepted($n)]  \(%.2f shares/min\)" $acc_rate_sec]
						} else {
							notice "GPU $n no accepted shares in $elapsed_seconds seconds. GPU probably hung."
							sendmail "[stamp] $hostname GPU $n - No shares" "$hostname - GPU $n no accepted shares in $elapsed_seconds seconds. GPU probably hung."
							catch {exec echo "GPU $n No Shares - Rebooting..." | wall} out
							reboot
							exit

						}
					}
				}
			}
			close $fd
			if {$previous_time != ""} {
				if {$elapsed_seconds > [expr $conf(share_timer) *60]} {
					set fd [open "/tmp/accepted_count" w]
					for {set x 0} {$x<$n} {incr x} {
						puts $fd "$current_accepted($x) [clock seconds]"
					}
					close $fd
				}
			} else {
			# seed initial data
				set fd [open "/tmp/accepted_count" w]
				for {set x 0} {$x<$n} {incr x} {
					puts $fd "$current_accepted($x) [clock seconds]"
				}
				close $fd

			}
			
		}
		notice "cgmon $conf(version) - $conf(cgminer_exec) running and all GPUs healthy."
	}
}



# Run API command to see if we have alive pools
proc check_pools {} {
global conf 
	catch {exec php -f $conf(cgminer_api) pools | grep "=>" | grep "Alive" | wc -l} argx
	if {[string first "child process exited abnormally" $argx] > 0} {
		return 0
	} else {
		return $argx
	}
}


proc reboot {} {
global conf

	catch {exec whoami} me
	if {$me != "root"} {
		notice "cgmon.tcl is NOT running as root.   The reboot probably wont work.  Trying it anyhow..."
	}
	if {[info exists conf(BAMT)]} {
		if {$conf(BAMT) == "yes"} {
			after 5000
			catch {exec reboot -f -n} out
			notice $out
		} else {
			# wait 10 seconds so emails can possibly be delivered before rebooting
			after 10000
			catch {exec /sbin/shutdown -r now} out
			notice $out
			catch {exec shutdown -r now} out
			notice $out
			catch {exec reboot -f -n} out
			notice $out	
		}
	} else {
		# wait 10 seconds so emails can possibly be delivered before rebooting
		after 10000
		catch {exec /sbin/shutdown -r now} out
		notice $out
		catch {exec shutdown -r now} out
		notice $out
		catch {exec reboot -f -n} out
		notice $out		
	}
}

proc sendmail {subject body {trace 0}} {
global mail conf
global hostname tcl_interactive

	if {$mail(notify) == "yes"} {
	if {$mail(notify_on_manual_runs) == "no" && $::env(SHELL) != "/bin/sh"} {exit}


		set latest_version [check_update false]
		if {$conf(version) < $latest_version} {
			append body "\n\nA new version of cgmon ($latest_version) is available at http://www.forked.net/~apex/cgmon.tcl or use './cgmon.tcl update' for automatic script updating.\n\n"
		}

		if {$mail(auth) == "yes"} {
			# use auth

			if {$conf(donated) == "no"} {
				append body "\n\n If you find cgmon useful, you can support further features and updates by donating to these addresses:\n\nBitcoin: $conf(btc_add) \n Litecoin: $conf(ltc_add) \n Dogecoin: $conf(doge_add)\n\nThanks!"
			}
			set token [mime::initialize -canonical text/plain -string $body]
			mime::setheader $token Subject $subject
			smtp::sendmessage $token \
			-recipients $mail(to) -servers $mail(host) -ports $mail(port) -usetls true -queue false -atleastone true \
			-debug false \
			-username $mail(auth_user) -password $mail(auth_pass) \
			-header [list From "$mail(from)"] \
            -header [list To "$mail(to)"] \
            -header [list Date "[clock format [clock seconds]]"] \
			
			mime::finalize $token

		} else {
			if {$mail(notify_on_manual_runs) == "no" && $::env(SHELL) != "/bin/sh"} {exit}
			if $trace then {
					puts stdout "Connecting to $mail(host):$mail(port)"
			}
			set sockid [socket $mail(host) $mail(port)]
			puts $sockid "HELO $hostname"
			puts $sockid "MAIL From:<$mail(from)>"
			flush $sockid
			set result ""
			while {1} {
				set tmp [gets $sockid]
				append result $tmp "\n"
				set extended_code [string range $tmp 0 3]
				if {[string compare [string range $extended_code end end] "-"]} {
					break
				}
			}
			if $trace then {
					puts stdout "MAIL From:<$mail(from)>\n\t$result"
			}
			foreach to $mail(to) {
				puts $sockid "RCPT To:<$to>"
				flush $sockid
			}
			set result [gets $sockid]
			if $trace then {
					puts stdout "RCPT To:<$to>\n\t$result"
			}
			puts  $sockid "DATA "
			flush $sockid
			set result [gets  $sockid]
			if $trace then {
					puts stdout "DATA \n\t$result"
			}
			puts  $sockid "From: <$mail(from)>"
			puts  $sockid "To: <$to>"
			puts  $sockid "Subject: $subject"
			puts  $sockid "\n"
			if {$conf(donated) == "no"} {
				append body "\n\n If you find cgmon useful, you can support further features and updates by donating to these addresses:\n\nBitcoin: $conf(btc_add) \n Litecoin: $conf(ltc_add) \n Dogecoin: $conf(doge_add)\n\nThanks!"
			}
			foreach line [split $body  "\n"] {
					puts  $sockid "[join $line]"
			}
			puts  $sockid "."
			puts  $sockid "QUIT"
			flush $sockid
			set result [gets  $sockid]
			if $trace then {
					puts stdout "QUIT\n\t$result"
			}
			close $sockid
		}
	}
	return;
}

proc notice {msg} {
	global hostname conf
	set notice "[stamp] $hostname - $msg"
	puts $notice
	exec echo $notice >> $conf(cgmon_logfile)
}

proc stamp {} {return [clock format [clock seconds] -format {%b %d %H:%M:%S}]}

if {$mail(auth) == "yes"} {
	package require SASL
	package require smtp
	package require mime
	package require tls
}

# Create the cgminer API file if it doesnt exist
# Modified from default API to timeout after 2 seconds
if {![file exists $conf(cgminer_api)]} {
	set n [subst -nocommands -novariables { <?php\n\n#\n# Sample Socket I/O to CGMiner API\n#\nfunction getsock($addr, $port)\n\{\n $socket = null;\n $socket = socket_create(AF_INET, SOCK_STREAM, SOL_TCP);\n if ($socket === false || $socket === null)\n \{\n	$error = socket_strerror(socket_last_error());\n	$msg = "socket create(TCP) failed";\n	echo "ERR: $msg '$error'\\n";\n	return null;\n \}\n\n $res = socket_connect($socket, $addr, $port);\n if ($res === false)\n \{\n	$error = socket_strerror(socket_last_error());\n	$msg = "socket connect($addr,$port) failed";\n	echo "ERR: $msg '$error'\\n";\n	socket_close($socket);\n	return null;\n \}\n return $socket;\n\}\n#\n# Slow ...\nfunction readsockline($socket)\n\{\n $line = '';\n while (true)\n \{\n	$byte = socket_read($socket, 1);\n	if ($byte === false || $byte === '')\n		break;\n	if ($byte === "\0")\n		break;\n	$line .= $byte;\n \}\n return $line;\n\}\n#\nfunction request($cmd)\n\{\n $socket = getsock('127.0.0.1', 4028);\n if ($socket != null)\n \{\nsocket_set_option($socket, SOL_SOCKET, SO_RCVTIMEO, array('sec'=>2, 'usec'=>2000));\nsocket_set_option($socket, SOL_SOCKET, SO_SNDTIMEO, array('sec'=>2, 'usec'=>2000));\nsocket_write($socket, $cmd, strlen($cmd));\n	$line = readsockline($socket);\n	socket_close($socket);\n\n	if (strlen($line) == 0)\n	\{\n		echo "WARN: '$cmd' returned nothing\\n";\n		return $line;\n	\}\n\n	print "$cmd returned '$line'\\n";\n\n	if (substr($line,0,1) == '\{')\n	return json_decode($line, true);\n\n	$data = array();\n\n	$objs = explode('|', $line);\n	foreach ($objs as $obj)\n	\{\n		if (strlen($obj) > 0)\n		\{\n			$items = explode(',', $obj);\n			$item = $items[0];\n			$id = explode('=', $items[0], 2);\n			if (count($id) == 1 or !ctype_digit($id[1]))\n			$name = $id[0];\n			else\n				$name = $id[0].$id[1];\n\n	if (strlen($name) == 0)\n				$name = 'null';\n\n			if (isset($data[$name]))\n			\{\n				$num = 1;\n			while (isset($data[$name.$num]))\n					$num++;\n			$name .= $num;\n			\}\n\n			$counter = 0;\n			foreach ($items as $item)\n			\{\n				$id = explode('=', $item, 2);\n		if (count($id) == 2)\n					$data[$name][$id[0]] = $id[1];\n		else\n					$data[$name][$counter] = $id[0];\n\n				$counter++;\n			\}\n		\}\n	\}\n\n	return $data;\n \}\n\n return null;\n\}\n#\nif (isset($argv) and count($argv) > 1)\n $r = request($argv[1]);\nelse\n $r = request('summary');\n#\necho print_r($r, true)."\\n";\n#\n?>\n } ]
	set fd [open $conf(cgminer_api) w]
	puts $fd $n
	close $fd
}

catch {exec hostname} hostname
if {$argv == "update"} { check_update true }


# start
check_status

# Changelog
# 0.1b3 added cgminer api
#	Timestamps
#	HELO mail fix
#	Simplified configuration
#	Added broadcast message before rebooting.
# 0.1b4
#   Moved cgmon-mine.sh to /tmp/ so the script can run as the cgminer user.
#	Moved cgminer api to /tmp/
#	Secondary mining pool is now optional.
# 0.1b5
#	Fixed .sh ownership problem
#   Added test for cgminer/cgminer path
#   Split cgminer_cmd into cgminer_path and cgminer_extra_options for ease of use.
# 0.1b6
#   Now checks accepted share outputs.  If no shares in 5 (default) minutes, send email notice and reboots rig.
#   Moved all log messages to ~$mining_user/cgmon.log instead of the current working directory of whichever user ran cgmon.
#	Split cgminer_path into cgminer_path and cmginer_exec to support sgminer.
#   Added support for sgminer 4.0.0.
# 0.1b7
#   Added detection of cgminer/AMD crash aka 'asic hang' (thanks dr00g!)
#   Fixed rebooting on BAMT.
#   Default share timer changed from 5 to 10 minutes.
#   Accepted share counts and rate added to logfile.  
# 0.1b8
#   All messages now correctly specify the currently running mining software (i.e. cgminer or sgminer, etc.)
# 0.1b9
#   Fixed bug with custom cgminer_path
#   If a local mining_exec is found and no executable is installed globally nor via custom_path, local exec will be used.
#   The actual mining command is now displayed when mining is attempted.  This should help with debugging problem.
# 0.1b10
#   Added support for up to 5 mining pools.
#   Now really checks to see if the mining command worked and the miner is running.  Sends email/notice upon success.  If not, displays suggestion on fixing.  
#   Now logs the command used to mine for both success and failure.   Easier troubleshooting.
#   Cleaned up configuration and instructions.
#   Now shows the GPU options at the top of cgmon.tcl since that line gets edited the most.
# 0.1b11
#   Added detection of unresponsive cgminer/sgminer.
# 0.1b12
#   Added check for connection reset when using cgminer API.
#   Moved share monitoring option into config section.
#   Changed pool configuration.  Now you can comment out unused pools or leave them blank.
#   Added option to disable email notifications when cgmon.tcl is run by hand.  Keeps the inbox spam down when adjusting settings, etc.
#   Cleaned up some code.
#   Changed cronjob default to every 2 minutes.  If you have an existing cronjob, you'll need to edit /etc/crontab yourself to make this change.
# 0.1b13
#   Some updated pool code didnt make it into the last three(!) release.
#   Fixed shutdown error on CentOS
# 0.1b14
#   New: Now checks and warns if script isnt running as root before trying to reboot/shutdown.
#   New: Check status of all mining pools.  Send an email notification and reboot (optional) if all pools are unreachable.
#   Upd: More info on non responsive api errors. i.e. when cgminer starts, but all pools are unreachable.
# 0.1b15
#   Now sends email on failure to start mining.
#   Cleaned up some code and config section.  
#   Removed $mine_for and $use_sgminer options (replaced with $miner_requires_scrypt_flag).
# 0.1b16
#   Added a fix for MacOS X.
# 1.0
#   Added auto update procedure:  ./cgmon.tcl update
#   Added SMTP AUTH support.
#   Added screen command to output when starting.
# 1.0.1 & 1.0.2
#   Bug fixes
# 1.0.3
#   Added new version notifications to emails, when applicable.
# 1.0.4
#   notify_on_manual_runs was not being obeyed.
#   Added quiet flag (-q) to wget when version checking.
# 1.0.5
#   Now adds mining pools before gpu options when setting up the mining command (request by Angela8488).
# 1.0.6
#   Fixed bug introduced in 1.0.3 that caused emails not to get sent and reboots to stop working.
# 1.0.7
#   Made update procedure future proof - requires a one time manual update if upgrading from earlier than 1.0.7 to 1.0.8
#   No longer says 'Updating...' when rebooting.
#   Added BAMT config option to try 'reboot -f -n' first.
# 1.0.8
#   Now waits 5 seconds and retries accessing cgminer API before deciding cgminer is unresponsive and rebooting.  Prevents some false positives.
#   Now creates a copy of previous cgmon.tcl when auto updating.
# 1.0.9
#   No longer sends 'rebooting' email when all pools are ureachable and reboot_when_pools_are_down is set to 'no'. 

#TODO: 
#	notify on GPU overheat
#   email/notify upon network reconnect with duration of outage.
#   finish automated script update code.
#   add debug smtp auth/mail option
#   add debug mode for entire script.
#   add option to disable version checks?
#   make a backup of previous .tcl when updating.
