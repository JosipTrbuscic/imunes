global VROOT_MASTER ULIMIT_FILE ULIMIT_PROC
set VROOT_MASTER "imunes/template"
set ULIMIT_FILE "1024:16384"
set ULIMIT_PROC "512:1024"

#****f* freebsd.tcl/moveFileFromNode
# NAME
#   moveFileFromNode -- copy file from virtual node
# SYNOPSIS
#   moveFileFromNode $node $path $ext_path
# FUNCTION
#   Moves file from virtual node to a specified external path.
# INPUTS
#   * node -- virtual node id
#   * path -- path to file in node
#   * ext_path -- external path
#****
proc moveFileFromNode { node path ext_path } {
    upvar 0 ::cf::[set ::curcfg]::eid eid
    set node_dir [getVrootDir]/$eid/$node
    catch {exec mv $node_dir$path $ext_path}
}

#****f* linux.tcl/writeDataToNodeFile
# NAME
#   writeDataToNodeFile -- write data to virtual node
# SYNOPSIS
#   writeDataToNodeFile $node $path $data
# FUNCTION
#   Writes data to a file on the specified virtual node.
# INPUTS
#   * node -- virtual node id
#   * path -- path to file in node
#   * data -- data to write
#****
proc writeDataToNodeFile { node path data } {
    upvar 0 ::cf::[set ::curcfg]::eid eid

    set node_id "$eid.$node"
    set node_dir [getVrootDir]/$eid/$node

    writeDataToFile $node_dir/$path $data
    exec docker exec -i $node_id sh -c "cat > $path" < $node_dir/$path
}

#****f* linux.tcl/execCmdNode
# NAME
#   execCmdNode -- execute command on virtual node
# SYNOPSIS
#   execCmdNode $node $cmd
# FUNCTION
#   Executes a command on a virtual node and returns the output.
# INPUTS
#   * node -- virtual node id
#   * cmd -- command to execute
# RESULT
#   * returns the execution output
#****
proc execCmdNode { node cmd } {
    upvar 0 ::cf::[set ::curcfg]::eid eid

    catch {eval [concat "nexec docker exec " $eid.$node $cmd] } output
    return $output
}

#****f* linux.tcl/checkForExternalApps
# NAME
#   checkForExternalApps -- check whether external applications exist
# SYNOPSIS
#   checkForExternalApps $app_list
# FUNCTION
#   Checks whether a list of applications exist on the machine running IMUNES
#   by using the which command.
# INPUTS
#   * app_list -- list of applications
# RESULT
#   * returns 0 if the applications exist, otherwise it returns 1.
#****
proc checkForExternalApps { app_list } {
    upvar 0 ::cf::[set ::curcfg]::eid eid
    foreach app $app_list {
	set status [ catch { exec which $app } err ]
	if { $status } {
	    return 1
	}
    }
    return 0
}

#****f* linux.tcl/checkForApplications
# NAME
#   checkForApplications -- check whether applications exist
# SYNOPSIS
#   checkForApplications $node $app_list
# FUNCTION
#   Checks whether a list of applications exist on the virtual node by using
#   the which command.
# INPUTS
#   * node -- virtual node id
#   * app_list -- list of applications
# RESULT
#   * returns 0 if the applications exist, otherwise it returns 1.
#****
proc checkForApplications { node app_list } {
    upvar 0 ::cf::[set ::curcfg]::eid eid
    foreach app $app_list {
    set status [ catch { exec docker exec $eid.$node which $app } err ]
        if { $status } {
            return 1
        }
    }
    return 0
}

#****f* linux.tcl/startWiresharkOnNodeIfc
# NAME
#   startWiresharkOnNodeIfc -- start wireshark on an interface
# SYNOPSIS
#   startWiresharkOnNodeIfc $node $ifc
# FUNCTION
#   Start Wireshark on a virtual node on the specified interface.
# INPUTS
#   * node -- virtual node id
#   * ifc -- virtual node interface
#****
proc startWiresharkOnNodeIfc { node ifc } {
    upvar 0 ::cf::[set ::curcfg]::eid eid

    if {[checkForExternalApps "startxcmd"] == 0 && \
    [checkForApplications $node "wireshark"] == 0} {
        startXappOnNode $node "wireshark -ki $ifc"
    } else {
	set wiresharkComm ""
	foreach wireshark "wireshark wireshark-gtk wireshark-qt" {
	    if {[checkForExternalApps $wireshark] == 0} {
		set wiresharkComm $wireshark
		break
	    }
	}

	if { $wiresharkComm != "" } {
	    exec docker exec $eid.$node tcpdump -s 0 -U -w - -i $ifc 2>/dev/null |\
	    $wiresharkComm -o "gui.window_title:$ifc@[getNodeName $node] ($eid)" -k -i - &
	} else {
            tk_dialog .dialog1 "IMUNES error" \
	"IMUNES could not find an installation of Wireshark.\
	If you have Wireshark installed, submit a bug report." \
            info 0 Dismiss
	}
    }
}

#****f* freebsd.tcl/captureOnExtIfc
# NAME
#   captureOnExtIfc -- start wireshark on an interface
# SYNOPSIS
#   captureOnExtIfc $node $command
# FUNCTION
#   Start tcpdump or Wireshark on the specified external interface.
# INPUTS
#   * node -- node id
#   * command -- tcpdump or wireshark
#****
proc captureOnExtIfc { node command } {
    set ifc [lindex [ifcList $node] 0]
    if { "$ifc" == "" } {
	return
    }

    upvar 0 ::cf::[set ::curcfg]::eid eid

    if { $command == "tcpdump" } {
	exec xterm -T "Capturing $eid-$node" -e "tcpdump -ni $eid-$node" 2> /dev/null &
    } else {
	exec $command -o "gui.window_title:[getNodeName $node] ($eid)" -k -i $eid-$node 2> /dev/null &
    }
}

#****f* linux.tcl/startXappOnNode
# NAME
#   startXappOnNode -- start X application in a virtual node
# SYNOPSIS
#   startXappOnNode $node $app
# FUNCTION
#   Start X application on virtual node
# INPUTS
#   * node -- virtual node id
#   * app -- application to start
#****
proc startXappOnNode { node app } {
    upvar 0 ::cf::[set ::curcfg]::eid eid
    global debug
    if {[checkForExternalApps "socat"] != 0 } {
        puts "To run X applications on the node, install socat on your host."
        return
    }

    set logfile "/dev/null"
    if {$debug} {
        set logfile "/tmp/startxcmd_$eid\_$node.log"
    }

    eval exec startxcmd [getNodeName $node]@$eid $app > $logfile 2>> $logfile &
}

#****f* linux.tcl/startTcpdumpOnNodeIfc
# NAME
#   startTcpdumpOnNodeIfc -- start tcpdump on an interface
# SYNOPSIS
#   startTcpdumpOnNodeIfc $node $ifc
# FUNCTION
#   Start tcpdump in xterm on a virtual node on the specified interface.
# INPUTS
#   * node -- virtual node id
#   * ifc -- virtual node interface
#****
proc startTcpdumpOnNodeIfc { node ifc } {
    if {[checkForApplications $node "tcpdump"] == 0} {
        spawnShell $node "tcpdump -ni $ifc"
    }
}

#****f* linux.tcl/existingShells
# NAME
#   existingShells -- check which shells exist in a node
# SYNOPSIS
#   existingShells $shells $node
# FUNCTION
#   This procedure checks which of the provided shells are available
#   in a running node.
# INPUTS
#   * shells -- list of shells.
#   * node -- node id of the node for which the check is performed.
#****
proc existingShells { shells node } {
    upvar 0 ::cf::[set ::curcfg]::eid eid

    set existing []
    foreach shell $shells {
        set cmd "docker exec $eid.$node which $shell"
        set err [catch {eval exec $cmd} res]
        if  {!$err} {
            lappend existing $res
        }
    }
    return $existing
}

#****f* linux.tcl/spawnShell
# NAME
#   spawnShell -- spawn shell
# SYNOPSIS
#   spawnShell $node $cmd
# FUNCTION
#   This procedure spawns a new shell for a specified node.
#   The shell is specified in cmd parameter.
# INPUTS
#   * node -- node id of the node for which the shell is spawned.
#   * cmd -- the path to the shell.
#****
proc spawnShell { node cmd } {
    upvar 0 ::cf::[set ::curcfg]::eid eid

    set node_id $eid\.$node

    # FIXME make this modular
    nexec xterm -sb -rightbar \
    -T "IMUNES: [getNodeName $node] (console) [string trim [lindex [split $cmd /] end] ']" \
    -e "docker exec -it $node_id $cmd" 2> /dev/null &
}

#****f* linux.tcl/fetchRunningExperiments
# NAME
#   fetchRunningExperiments -- fetch running experiments
# SYNOPSIS
#   fetchRunningExperiments
# FUNCTION
#   Returns IDs of all running experiments as a list.
# RESULT
#   * exp_list -- experiment id list
#****
proc fetchRunningExperiments {} {
    catch {exec himage -l | cut -d " " -f 1} exp_list
    set exp_list [split $exp_list "
"]
    return "$exp_list"
}

#****f* freebsd.tcl/createIfc
# NAME
#   createIfc -- create interface
# SYNOPSIS
#   set name [createIfc $eid $type $hook]
# FUNCTION
#   Creates a new netgraph interface, of the type $type.
#   Returns the name of the newly created interface.
# INPUTS
#   * eid -- experiment id
#   * type -- new interface type. In imunes are used only eiface or iface
#     types. Additional specification on this types can be found in manual
#     pages for netgraph nodes.
#   * hook -- parameter specific for every netgraph node. For iface hook hook
#     is inet, and for eiface type the hook is ether.
# RESULT
#   * name -- the name of the new interface
#****
proc createIfc { eid type hook } {
    catch { exec printf "mkpeer $type $hook $hook \n show .$hook" | jexec $eid ngctl -f - } nglist
    return [lindex $nglist 1]
}

#****f* linux.tcl/allSnapshotsAvailable
# NAME
#   allSnapshotsAvailable -- all snapshots available
# SYNOPSIS
#   allSnapshotsAvailable
# FUNCTION
#   Procedure that checks whether all node snapshots are available on the
#   current system.
#****
proc allSnapshotsAvailable {} {
    upvar 0 ::cf::[set ::curcfg]::node_list node_list
    global VROOT_MASTER execMode

    set snapshots $VROOT_MASTER
    foreach node $node_list {
	set img [getNodeDockerImage $node]
	if {$img != ""} {
	    lappend snapshots $img
	}
    }
    set snapshots [lsort -uniq $snapshots]
    set missing 0

    foreach template $snapshots {
	set search_template $template
	if {[string match "*:*" $template] != 1} {
	    append search_template ":latest"
	}

	catch {exec docker images -q $search_template} images
	if {[llength $images] > 0} {
	    continue
	} else {
	    # be nice to the user and see whether there is an image id matching
	    if {[string length $template] == 12} {
                catch {exec docker images -q} all_images
		if {[lsearch $all_images $template] == -1} {
		    incr missing
		}
	    } else {
		incr missing
	    }
	    if {$missing} {
                if {$execMode == "batch"} {
                    puts "Docker image for some virtual nodes:
    $template
is missing.
Run 'docker pull $template' to pull the template."
	        } else {
                   tk_dialog .dialog1 "IMUNES error" \
	    "Docker image for some virtual nodes:
    $template
is missing.
Run 'docker pull $template' to pull the template." \
                   info 0 Dismiss
	        }
	        return 0
	    }
	}
    }
    return 1
}

#****f* freebsd.tcl/execSetIfcQDisc
# NAME
#   execSetIfcQDisc -- in exec mode set interface queuing discipline
# SYNOPSIS
#   execSetIfcQDisc $eid $node $ifc $qdisc
# FUNCTION
#   Sets the queuing discipline during the simulation.
#   New queuing discipline is defined in qdisc parameter.
#   Queueing discipline can be set to fifo, wfq or drr.
# INPUTS
#   eid -- experiment id
#   node -- node id
#   ifc -- interface name
#   qdisc -- queuing discipline
#****
proc execSetIfcQDisc { eid node ifc qdisc } {
    set target [linkByIfc $node $ifc]
    set peers [linkPeers [lindex $target 0]]
    set dir [lindex $target 1]
    set lnode1 [lindex $peers 0]
    set lnode2 [lindex $peers 1]
    if { [nodeType $lnode2] == "pseudo" } {
	set mirror_link [getLinkMirror [lindex $target 0]]
	set lnode2 [lindex [linkPeers $mirror_link] 0]
    }
    switch -exact $qdisc {
	FIFO { set qdisc fifo }
	WFQ { set qdisc wfq }
	DRR { set qdisc drr }
    }
    set ngnode "$lnode1-$lnode2"
    if { [catch { exec jexec $eid ngctl msg $ngnode: setcfg "{ $dir={ $qdisc=1 } }" }] } {
	set ngnode "$lnode2-$lnode1"
	exec jexec $eid ngctl msg $ngnode: setcfg "{ $dir={ $qdisc=1 } }"
    }
}

#****f* freebsd.tcl/execSetIfcQDrop
# NAME
#   execSetIfcQDrop -- in exec mode set interface queue drop
# SYNOPSIS
#   execSetIfcQDrop $eid $node $ifc $qdrop
# FUNCTION
#   Sets the queue dropping policy during the simulation.
#   New queue dropping policy is defined in qdrop parameter.
#   Queue dropping policy can be set to drop-head or drop-tail.
# INPUTS
#   eid -- experiment id
#   node -- node id
#   ifc -- interface name
#   qdrop -- queue dropping policy
#****
proc execSetIfcQDrop { eid node ifc qdrop } {
    set target [linkByIfc $node $ifc]
    set peers [linkPeers [lindex $target 0]]
    set dir [lindex $target 1]
    set lnode1 [lindex $peers 0]
    set lnode2 [lindex $peers 1]
    if { [nodeType $lnode2] == "pseudo" } {
	set mirror_link [getLinkMirror [lindex $target 0]]
	set lnode2 [lindex [linkPeers $mirror_link] 0]
    }
    switch -exact $qdrop {
	drop-head { set qdrop drophead }
	drop-tail { set qdrop droptail }
    }
    set ngnode "$lnode1-$lnode2"
    if { [catch { exec jexec $eid ngctl msg $ngnode: setcfg "{ $dir={ $qdrop=1 } }" }] } {
	# XXX dir should be reversed!
	set ngnode "$lnode2-$lnode1"
	exec jexec $eid ngctl msg $ngnode: setcfg "{ $dir={ $qdrop=1 } }"
    }
}

#****f* freebsd.tcl/execSetIfcQLen
# NAME
#   execSetIfcQLen -- in exec mode set interface queue length
# SYNOPSIS
#   execSetIfcQDrop $eid $node $ifc $qlen
# FUNCTION
#   Sets the queue length during the simulation.
#   New queue length is defined in qlen parameter.
# INPUTS
#   eid -- experiment id
#   node -- node id
#   ifc -- interface name
#   qlen -- new queue's length
#****
proc execSetIfcQLen { eid node ifc qlen } {
    set target [linkByIfc $node $ifc]
    set peers [linkPeers [lindex $target 0]]
    set dir [lindex $target 1]
    set lnode1 [lindex $peers 0]
    set lnode2 [lindex $peers 1]
    if { [nodeType $lnode2] == "pseudo" } {
	set mirror_link [getLinkMirror [lindex $target 0]]
	set lnode2 [lindex [linkPeers $mirror_link] 0]
    }
    set ngnode "$lnode1-$lnode2"
    if { $qlen == 0 } {
	set qlen -1
    }
    if { [catch { exec jexec $eid ngctl msg $ngnode: setcfg "{ $dir={ queuelen=$qlen } }" }] } {
	set ngnode "$lnode2-$lnode1"
	exec jexec $eid ngctl msg $ngnode: setcfg "{ $dir={ queuelen=$qlen } }"
    }
}

#****f* freebsd.tcl/execSetLinkParams
# NAME
#   execSetLinkParams -- in exec mode set link parameters
# SYNOPSIS
#   execSetLinkParams $eid $link
# FUNCTION
#   Sets the link parameters during the simulation.
#   All the parameters are set at the same time.
# INPUTS
#   eid -- experiment id
#   link -- link id
#****
proc execSetLinkParams { eid link } {
    global debug

    set lnode1 [lindex [linkPeers $link] 0]
    set lnode2 [lindex [linkPeers $link] 1]

    if { [getLinkMirror $link] != "" } {
	set mirror_link [getLinkMirror $link]
	if { [nodeType $lnode1] == "pseudo" } {
	    set lnode1 [lindex [linkPeers $mirror_link] 0]
	} else {
	    set lnode2 [lindex [linkPeers $mirror_link] 0]
	}
    }

    set lname $lnode1-$lnode2

    set bandwidth [expr [getLinkBandwidth $link] + 0]
    set delay [expr [getLinkDelay $link] + 0]
    set ber [expr [getLinkBER $link] + 0]
    set dup [expr [getLinkDup $link] + 0]

    if { $bandwidth == 0 } {
	set bandwidth -1
    }
    if { $delay == 0 } {
	set delay -1
    }
    if { $ber == 0 } {
	set ber -1
    }
    if { $dup == 0 } {
	set dup -1
    }

    catch {exec jexec $eid ngctl msg $lname: setcfg \
	"{ bandwidth=$bandwidth delay=$delay \
	upstream={ BER=$ber duplicate=$dup } \
	downstream={ BER=$ber duplicate=$dup } }"} err
    if { $debug && $err != "" } {
	puts $err
    }
}

#****f* freebsd.tcl/execSetLinkJitter
# NAME
#   execSetLinkJitter -- in exec mode set link jitter
# SYNOPSIS
#   execSetLinkJitter $eid $link
# FUNCTION
#   Sets the link jitter parameters during the simulation.
#   All the parameters are set at the same time.
# INPUTS
#   eid -- experiment id
#   link -- link id
#****
proc execSetLinkJitter { eid link } {
    set lnode1 [lindex [linkPeers $link] 0]
    set lnode2 [lindex [linkPeers $link] 1]
    set lname $lnode1-$lnode2

    set jitter_up [getLinkJitterUpstream $link]
    set jitter_mode_up [getLinkJitterModeUpstream $link]
    set jitter_hold_up [expr [getLinkJitterHoldUpstream $link] + 0]

    set jitter_down [getLinkJitterDownstream $link]
    set jitter_mode_down [getLinkJitterModeDownstream $link]
    set jitter_hold_down [expr [getLinkJitterHoldDownstream $link] + 0]

    if {$jitter_mode_up in {"sequential" ""}} {
	set jit_mode_up 1
    } else {
	set jit_mode_up 2
    }

    if {$jitter_mode_down in {"sequential" ""}} {
	set jit_mode_down 1
    } else {
	set jit_mode_down 2
    }

    set exec_pipe [open "| jexec $eid ngctl -f -" r+]

    if {$jitter_up != ""} {
	puts $exec_pipe "msg $lname: setcfg {upstream={jitmode=-1}}"
	foreach val $jitter_up {
	    puts $exec_pipe "msg $lname: setcfg {upstream={addjitter=[expr round($val*1000)]}}"
	}
	puts $exec_pipe "msg $lname: setcfg {upstream={jitmode=$jit_mode_up}}"
	puts $exec_pipe "msg $lname: setcfg {upstream={jithold=[expr round($jitter_hold_up*1000)]}}"
    }

    if {$jitter_down != ""} {
	puts $exec_pipe "msg $lname: setcfg {downstream={jitmode=-1}}"
	foreach val $jitter_down {
	    puts $exec_pipe "msg $lname: setcfg {downstream={addjitter=[expr round($val*1000)]}}"
	}
	puts $exec_pipe "msg $lname: setcfg {downstream={jitmode=$jit_mode_down}}"
	puts $exec_pipe "msg $lname: setcfg {downstream={jithold=[expr round($jitter_hold_down*1000)]}}"
    }

    close $exec_pipe
}

#****f* freebsd.tcl/execResetLinkJitter
# NAME
#   execResetLinkJitter -- in exec mode reset link jitter
# SYNOPSIS
#   execResetLinkJitter $eid $link
# FUNCTION
#   Resets the link jitter parameters to defaults during the simulation.
#   All the parameters are set at the same time.
# INPUTS
#   * eid -- experiment id
#   * link -- link id
#****
proc execResetLinkJitter { eid link } {
    set lnode1 [lindex [linkPeers $link] 0]
    set lnode2 [lindex [linkPeers $link] 1]
    set lname $lnode1-$lnode2

    exec jexec $eid ngctl msg $lname: setcfg \
	"{upstream={jitmode=-1} downstream={jitmode=-1}}"
}

#****f* freebsd.tcl/l3node.nghook
# NAME
#   l3node.nghook -- layer 3 node netgraph hook
# SYNOPSIS
#   l3node.nghook $eid $node $ifc
# FUNCTION
#   Returns the netgraph node name and the hook name for a given experiment
#   id, node id, and interface name.
# INPUTS
#   * eid -- experiment id
#   * node -- node id
#   * ifc -- interface name
# RESULT
#   * list -- list in the form of {netgraph_node_name hook}
#****
proc l3node.nghook { eid node ifc } {
    set ifnum [string range $ifc 3 end]
    set node_id "$eid\.$node"
    switch -exact [string trim $ifc 0123456789] {
	wlan -
	ext -
	eth {
	    return [list $ifc@$node_id ether]
	}
	ser {
	    return [list hdlc$ifnum@$node_id downstream]
	}
    }
}

#****f* freebsd.tcl/vimageCleanup
# NAME
#   vimageCleanup -- vimage cleanup
# SYNOPSIS
#   vimageCleanup
# FUNCTION
#   Called in special circumstances only. It cleans all the imunes objects
#   from the kernel (vimages and netgraph nodes).
#****
proc vimageCleanup { eid } {
    global .c
    global execMode
    global vroot_unionfs vroot_linprocfs

    #check whether a jail with eid actually exists
    if {[catch {exec jls -v | grep "$eid *ACTIVE"}]} {
	statline "Experiment with eid $eid doesn't exist."
	return
    }

    if {$execMode != "batch"} {
	upvar 0 ::cf::[set ::curcfg]::node_list node_list
	set nodeCount [llength $node_list]
	set count [expr {$nodeCount}]
	set w .termWait
	catch {destroy $w}
	toplevel $w -takefocus 1
	wm transient $w .
	wm title $w "Terminating experiment ..."
	message $w.msg -justify left -aspect 1200 \
	-text "Deleting virtual nodes and links."
	pack $w.msg
	ttk::progressbar $w.p -orient horizontal -length 250 \
	-mode determinate -maximum $count -value $count
	pack $w.p
	update

	grab $w
	wm protocol $w WM_DELETE_WINDOW {
	}
    }

    statline "Terminating experiment with experiment id: $eid."

    set t_start [clock milliseconds]
    if {[catch {exec jexec $eid jls -v | fgrep ACTIVE | cut -c9-32} res] \
	!= 0 } {
	set res ""
    }
    set vimages [join $res]
    set defindex [lsearch $vimages .]
    set vimages [lreplace $vimages $defindex $defindex]

    if { [lindex [split [exec uname -r] "-"] 0] < 9.0 } {
	# Kill all processes in all vimages
	statline "Terminating processes..."

	set step 0
	set allVimages [ llength $vimages ]
	foreach node $vimages {
	    if {$execMode != "batch"} {
		statline "Terminating processes in vimage $node"
	    }
	    incr step
	    displayBatchProgress $step $allVimages

	    [typemodel $node].shutdown $eid $node
	}

	statline ""
	timeoutPatch $eid $vimages
    }

    statline "Shutting down netgraph nodes..."

    pipesCreate

    # Detach / destroy / reassign interfaces pipe, eiface, iface, bridge
    set i 0
    catch "exec sh -c {jexec $eid ngctl t | grep eiface | awk '{print \$2}'}" maxi
    set res [catch "exec jexec $eid ngctl l"]
    while { $res } {
	#This should never, ever happen.
	if { $i > $maxi } {
	    statline ""
	#    statline "Couldn't terminate all ngeth interfaces. Skipping..."
	    break
	}
	if {[expr {$i%240} == 0]} {
	    if { $execMode == "batch" } {
		puts -nonewline "."
		flush stdout
	    }
	    set res [catch "exec jexec $eid ngctl l"]
	}

	# Attempt to kill hubs & bridges
	set ngnode "n$i"
	if { $ngnode ni $vimages } {
	    pipesExec "jexec $eid ngctl shutdown $ngnode" "hold"
	}
	# Attempt to kill ngeth interfaces
	set ngnode "ngeth$i"
	pipesExec "jexec $eid ngctl shutdown $ngnode:" "hold"
	incr i

	pipesExec ""
    }
    pipesClose

    catch "exec jexec $eid ngctl l | tail -n +2 | grep -v socket" output

    set ngnodes [split $output "
"]

    pipesCreate
    set allNgnodes [llength $ngnodes]
    set step 0
    foreach ngline $ngnodes {
	incr step
	if { $execMode != "batch" } {
	    statline "Shutting down netgraph node $ngline"
	}
	displayBatchProgress $step $allNgnodes
	set ngnode [lindex [eval list $ngline] 1]

	pipesExec "jexec $eid ngctl shutdown $ngnode:"
    }
    pipesClose

    statline ""

    # Shut down all vimages
    if {$vroot_unionfs} {
	set VROOT_BASE /var/imunes
    } else {
	set VROOT_BASE /vroot
    }

    statline "Shutting down vimages..."

    set step 0
    set steps [expr {[llength $vimages]} ]

    pipesCreate
    foreach node $vimages {
	if {$execMode != "batch"} {
	    statline "Shutting down vimage $node"
	    $w.p step -1
	}

	incr step
	displayBatchProgress $step $steps

	pipesExec "jexec $eid.$node kill -9 -1 2> /dev/null" "hold"
	pipesExec "jexec $eid.$node tcpdrop -a 2> /dev/null" "hold"
	pipesExec "for iface in `jexec $eid.$node ifconfig -l`; do jexec $eid.$node ifconfig \$iface destroy; done" "hold"

	set VROOT_RUNTIME $VROOT_BASE/$eid/$node
	set VROOT_RUNTIME_DEV $VROOT_RUNTIME/dev
	pipesExec "umount -f $VROOT_RUNTIME_DEV" "hold"
	if {$vroot_unionfs} {
	    # 1st: unionfs RW overlay
	    pipesExec "umount -f $VROOT_RUNTIME" "hold"
	    # 2nd: nullfs RO loopback
	    pipesExec "umount -f $VROOT_RUNTIME" "hold"
	}
	if {$vroot_linprocfs} {
	    pipesExec "umount -f $VROOT_RUNTIME/compat/linux/proc" "hold"
	}
	pipesExec ""
    }
    pipesClose

    statline ""

    # remeber all vlan interfaces in the experiment to destroy them later
    set vlanlist ""
    catch {exec jexec $eid ifconfig -l} ifclist
    foreach ifc $ifclist {
	if { [string match "*.*" $ifc]} {
	    lappend vlanlist $ifc
	}
    }

    if {$vroot_unionfs} {
	# UNIONFS
	exec jail -r $eid
	exec rm -fr $VROOT_BASE/$eid &
    } else {
	# ZFS
	if {$execMode == "batch"} {
	    exec jail -r $eid
	    exec zfs destroy -fr vroot/$eid
	} else {
	    exec jail -r $eid &
	    exec zfs destroy -fr vroot/$eid &

	    catch {exec zfs list | grep -c "$eid"} output
	    set zfsCount [lindex [split $output] 0]

	    while {$zfsCount != 0} {
		catch {exec zfs list | grep -c "$eid/"} output
		set zfsCount [lindex [split $output] 0]
		$w.p configure -value $zfsCount
		update
		after 200
	    }
	}
    }

    foreach ifc $vlanlist {
	catch {exec ifconfig $ifc destroy}
    }

    if {$execMode != "batch"} {
	destroy $w
    }

    statline "Cleanup completed in [expr ([clock milliseconds] - $t_start)/1000.0] seconds."
}

#****f* freebsd.tcl/killProcess
# NAME
#   killProcess -- kill processes with the given regex
# SYNOPSIS
#   killProcess $regex
# FUNCTION
#   Executes a pkill command to kill all processes with a corresponding regex.
# INPUTS
#   * regex -- regularl expression of the processes
#****
proc killExtProcess { regex } {
    catch "exec pkill -f \"$regex\""
}

#****f* freebsd.tcl/getRunningNodeIfcList
# NAME
#   getRunningNodeIfcList -- get interfaces list from the node
# SYNOPSIS
#   getRunningNodeIfcList $node
# FUNCTION
#   Returns the list of all network interfaces for the given node.
# INPUTS
#   * node -- node id
# RESULT
#   * list -- list in the form of {netgraph_node_name hook}
#****
proc getRunningNodeIfcList { node } {
    upvar 0 ::cf::[set ::curcfg]::eid eid

    catch {exec jexec $eid.$node ifconfig} full
    set lines [split $full "\n"]

    return $lines
}

# ifconfig parse proc !

#****f* freebsd.tcl/getHostIfcList
# NAME
#   getHostIfcList -- get interfaces list from host
# SYNOPSIS
#   getHostIfcList
# FUNCTION
#   Returns the list of all network interfaces on the host.
# RESULT
#   * extifcs -- list of all external interfaces
#****
proc getHostIfcList {} {
    # fetch interface list from the system
    set extifcs [exec ifconfig -l]
    # exclude loopback interface
    set ilo [lsearch $extifcs lo0]
    set extifcs [lreplace $extifcs $ilo $ilo]

    return $extifcs
}

#****f* freebsd.tcl/getHostIfcVlanExists
# NAME
#   getHostIfcVlanExists -- check if host VLAN interface exists
# SYNOPSIS
#   getHostIfcVlanExists $node $name
# FUNCTION
#   Returns 1 if VLAN interface with the name $name for the given node cannot
#   be created.
# INPUTS
#   * node -- node id
#   * name -- interface name
# RESULT
#   * check -- 1 if interface exists, 0 otherwise
#****
proc getHostIfcVlanExists { node name } {
    global execMode

    # check if the VLAN is available
    set ifname [getNodeName $node]
    set vlan [lindex [split [getNodeName $node] .] 1]
    # if the VLAN is available then it can be created
    if { [catch {exec ifconfig $ifname create} err] } {
	set msg "Error: external interface $name can't be\
	    created.\nVLAN $vlan is already in use. \n($err)"
	if { $execMode == "batch" } {
	    puts $msg
	} else {
	    after idle {.dialog1.msg configure -wraplength 4i}
	    tk_dialog .dialog1 "IMUNES error" $msg \
		info 0 Dismiss
	}
	return 1
    } else {
	# destroy it, if it was created
	catch {exec ifconfig $ifname destroy}
	return 0
    }
}

#****f* freebsd.tcl/getVrootDir
# NAME
#   getVrootDir -- get virtual root directory
# SYNOPSIS
#   getVrootDir
# FUNCTION
#   Helper function that returns virtual root directory.
# RESULT
#   * vroot_dir -- virtual root directory
#****
proc getVrootDir {} {
    global vroot_unionfs

    if {$vroot_unionfs} {
	return "/var/imunes"
    } else {
	return "/vroot"
    }
}

#****f* freebsd.tcl/dumpNgnodesToFile
# NAME
#   dumpNgnodesToFile -- dump ngnodemap list to file
# SYNOPSIS
#   dumpNgnodesToFile $path
# FUNCTION
#   Saves the list of all the ngnodes to $path.
# INPUTS
#   * path -- absolute path of the file
#****
proc dumpNgnodesToFile { path } {
    upvar 0 ::cf::[set ::curcfg]::ngnodemap ngnodemap

    writeDataToFile $path [array get ngnodemap]
}

#****f* freebsd.tcl/readNgnodesFromFile
# NAME
#   readNgnodesFromFile -- read ngnodes list from file
# SYNOPSIS
#   readNgnodesFromFile $eid
# FUNCTION
#   Sets the global array ngnodemap to the content of the running config file
#   for the given eid.
# INPUTS
#   * exp -- experiment id
#****
proc readNgnodesFromFile { exp } {
    upvar 0 ::cf::[set ::curcfg]::ngnodemap ngnodemap
    global runtimeDir

#    set fileId [open  r]
#    array set ngnodemap [gets $fileId]
#    close $fileId
    array set ngnodemap [readDataFromFile $runtimeDir/$exp/ngnodemap]
}

#****f* freebsd.tcl/prepareFilesystemForNode
# NAME
#   prepareFilesystemForNode -- prepare node filesystem
# SYNOPSIS
#   prepareFilesystemForNode $node
# FUNCTION
#   Prepares the node virtual filesystem.
# INPUTS
#   * node -- node id
#****
proc prepareFilesystemForNode { node } {
    upvar 0 ::cf::[set ::curcfg]::eid eid
    global vroot_unionfs vroot_linprocfs devfs_number

    # Prepare a copy-on-write filesystem root
    if {$vroot_unionfs} {
	# UNIONFS
	set VROOTDIR /var/imunes
	set VROOT_RUNTIME $VROOTDIR/$eid/$node
	set VROOT_OVERLAY $VROOTDIR/$eid/upper/$node
	set VROOT_RUNTIME_DEV $VROOT_RUNTIME/dev
	pipesExec "mkdir -p $VROOT_RUNTIME" "hold"
	pipesExec "mkdir -p $VROOT_OVERLAY" "hold"
	pipesExec "mount_nullfs -o ro $VROOTDIR/vroot $VROOT_RUNTIME" "hold"
	pipesExec "mount_unionfs -o noatime $VROOT_OVERLAY $VROOT_RUNTIME" "hold"
    } else {
	# ZFS
	set VROOT_ZFS vroot/$eid/$node
	set VROOT_RUNTIME /$VROOT_ZFS
	set VROOT_RUNTIME_DEV $VROOT_RUNTIME/dev

	set snapshot [getNodeSnapshot $node]
	if {$snapshot == ""} {
	    set snapshot "vroot/vroot@clean"
	}
	pipesExec "zfs clone $snapshot $VROOT_ZFS" "hold"
    }

    if {$vroot_linprocfs} {
	pipesExec "mount -t linprocfs linprocfs $VROOT_RUNTIME/compat/linux/proc" "hold"
	#HACK - linux_sun_jdk16 - java hack, won't work if proc isn't accessed
	#before execution, so we need to cd to it.
	pipesExec "cd $VROOT_RUNTIME/compat/linux/proc" "hold"
    }

    # Mount and configure a restricted /dev
    pipesExec "mount -t devfs devfs $VROOT_RUNTIME_DEV" "hold"
    pipesExec "devfs -m $VROOT_RUNTIME_DEV ruleset $devfs_number" "hold"
    pipesExec "devfs -m $VROOT_RUNTIME_DEV rule applyset" "hold"
}

#****f* freebsd.tcl/createNodeContainer
# NAME
#   createNodeContainer -- create a node container
# SYNOPSIS
#   createNodeContainer $node
# FUNCTION
#   Creates a jail (container) for the given node.
# INPUTS
#   * node -- node id
#****
proc createNodeContainer { node } {
    upvar 0 ::cf::[set ::curcfg]::eid eid

    set node_dir [getVrootDir]/$eid/$node

    pipesExec "jail -c name=$eid.$node path=$node_dir securelevel=1 \
	host.hostname=\"[getNodeName $node]\" vnet persist" "hold"
}

#****f* freebsd.tcl/createNodePhysIfcs
# NAME
#   createNodePhysIfcs -- create node physical interfaces
# SYNOPSIS
#   createNodePhysIfcs $node
# FUNCTION
#   Creates physical interfaces for the given node.
# INPUTS
#   * node -- node id
#****
proc createNodePhysIfcs { node } {
    upvar 0 ::cf::[set ::curcfg]::ngnodemap ngnodemap
    upvar 0 ::cf::[set ::curcfg]::eid eid
    global ifc_dad_disable

    set node_id "$eid.$node"
    # Create a vimage
    # Create "physical" network interfaces
    foreach ifc [ifcList $node] {
	switch -exact [string range $ifc 0 2] {
	    eth {
		set ifid [createIfc $eid eiface ether]
		pipesExec "jexec $eid ifconfig $ifid vnet $node" "hold"
		pipesExec "jexec $node_id ifconfig $ifid name $ifc" "hold"

		# XXX ng renaming is automatic in FBSD 8.4 and 9.2, remove this!
		pipesExec "jexec $node_id ngctl name [set ifid]: $ifc" "hold"

#		set peer [peerByIfc $node $ifc]
		set ether [getIfcMACaddr $node $ifc]
                if {$ether == ""} {
                    autoMACaddr $node $ifc
                }
                set ether [getIfcMACaddr $node $ifc]
		global ifc_dad_disable
		if {$ifc_dad_disable} {
		    pipesExec "jexec $node_id sysctl net.inet6.ip6.dad_count=0" "hold"
		}
		pipesExec "jexec $node_id ifconfig $ifc link $ether" "hold"
		set ngnodemap($ifc@$node_id) $ifid
	    }
	    ext {
		set ifid [createIfc $eid eiface ether]
		set outifc "$eid-$node"
		pipesExec "ifconfig $ifid -vnet $eid" "hold"
		pipesExec "ifconfig $ifid name $outifc" "hold"

		# XXX ng renaming is automatic in FBSD 8.4 and 9.2, remove this!
		pipesExec "ngctl name [set ifid]: $outifc" "hold"

		set ether [getIfcMACaddr $node $ifc]
                if {$ether == ""} {
                    autoMACaddr $node $ifc
                }
                set ether [getIfcMACaddr $node $ifc]
		pipesExec "ifconfig $outifc link $ether" "hold"
		set ngnodemap($ifc@$node_id) $ifid
	    }
	    ser {
#		set ifnum [string range $ifc 3 end]
#		set ifid [createIfc $eid iface inet]
#		pipesExec "jexec $eid ngctl mkpeer $ifid: cisco inet inet" "hold"
#		pipesExec "jexec $eid ngctl connect $ifid: $ifid:inet inet6 inet6" "hold"
#		pipesExec "jexec $eid ngctl msg $ifid: broadcast" "hold"
#		pipesExec "jexec $eid ngctl name $ifid:inet hdlc$ifnum\@$node" "hold"
#		pipesExec "jexec $eid ifconfig $ifid vnet $node" "hold"
#		pipesExec "jexec $node_id ifconfig $ifid name $ifc" "hold"
#		set ngnodemap(hdlc$ifnum@$node_id) hdlc$ifnum\@$node"
	    }
	}
    }
}

#****f* freebsd.tcl/createNodeLogIfcs
# NAME
#   createNodeLogIfcs -- create node logical interfaces
# SYNOPSIS
#   createNodeLogIfcs $node
# FUNCTION
#   Creates logical interfaces for the given node.
# INPUTS
#   * node -- node id
#****
proc createNodeLogIfcs { node } {
    upvar 0 ::cf::[set ::curcfg]::eid eid

    set node_id "$eid.$node"

    foreach ifc [logIfcList $node] {
	switch -exact [getLogIfcType $node $ifc] {
	    vlan {
		set tag [getIfcVlanTag $node $ifc]
		set dev [getIfcVlanDev $node $ifc]
		if {$tag != "" && $dev != ""} {
		    pipesExec "jexec $node_id ifconfig $ifc create" "hold"
		    pipesExec "jexec $node_id ifconfig $ifc vlan $tag vlandev $dev" "hold"
		}
	    }
	    lo {
		if {$ifc != "lo0"} {
		    pipesExec "jexec $node_id ifconfig $ifc create" "hold"
		}
	    }
	}
    }
}

#****f* freebsd.tcl/configureICMPoptions
# NAME
#   configureICMPoptions -- configure ICMP options
# SYNOPSIS
#   configureICMPoptions $node
# FUNCTION
#  Configures the necessary ICMP sysctls in the given node. 
# INPUTS
#   * node -- node id
#****
proc configureICMPoptions { node } {
    upvar 0 ::cf::[set ::curcfg]::eid eid

    set node_id "$eid.$node"

    pipesExec "jexec $node_id sysctl net.inet.icmp.bmcastecho=1" "hold"
    pipesExec "jexec $node_id sysctl net.inet.icmp.icmplim=0" "hold"

    # Enable more fragments per packet for IPv4
    pipesExec "jexec $node_id sysctl net.inet.ip.maxfragsperpacket=64000" "hold"
}

#****f* freebsd.tcl/startIfcsNode
# NAME
#   startIfcsNode -- start interfaces on node
# SYNOPSIS
#   startIfcsNode $node
# FUNCTION
#  Starts all interfaces on the given node.
# INPUTS
#   * node -- node id
#****
proc startIfcsNode { node } {
    upvar 0 ::cf::[set ::curcfg]::eid eid

    set node_id "$eid.$node"
    set cmds ""
    foreach ifc [allIfcList $node] {
	set mtu [getIfcMTU $node $ifc]
	if {[getIfcOperState $node $ifc] == "up"} {
	    set cmds "$cmds\n jexec $node_id ifconfig $ifc mtu $mtu up"
	} else {
	    set cmds "$cmds\n jexec $node_id ifconfig $ifc mtu $mtu"
	}
    }
    exec sh << $cmds
}

#****f* freebsd.tcl/runConfOnNode
# NAME
#   runConfOnNode -- run configuration script on node
# SYNOPSIS
#   runConfOnNode $node
# FUNCTION
#   Run startup configuration file on the given node.
# INPUTS
#   * node -- node id
#****
proc runConfOnNode { node } {
    upvar 0 ::cf::[set ::curcfg]::eid eid
    global vroot_unionfs
    global viewcustomid vroot_unionfs
    global execMode

    set node_dir [getVrootDir]/$eid/$node
    set node_id "$eid.$node"

    if { [getCustomEnabled $node] == true } {
	set selected [getCustomConfigSelected $node]

	set bootcmd [getCustomConfigCommand $node $selected]
	set bootcfg [getCustomConfig $node $selected]
	set confFile "custom.conf"
    } else {
	set bootcfg [[typemodel $node].cfggen $node]
	set bootcmd [[typemodel $node].bootcmd $node]
	set confFile "boot.conf"
    }

    set cmds ""

    writeDataToFile $node_dir/$confFile [join $bootcfg "\n"]
    if {[typemodel $node] in "click_l2 click_l3 router.xorp"} {
	# click has no daemon mode, run in backgorund
	# xorp in daemon mode is too slow, run in background
	set cmds "\njexec $node_id $bootcmd $confFile > $node_dir/out.log 2>&1 &"
    } else {
	set cmds "\njexec $node_id $bootcmd $confFile > $node_dir/out.log 2>&1"
    }

    foreach ifc [allIfcList $node] {
	if {[getIfcOperState $node $ifc] == "down"} {
	    set cmds "$cmds\njexec $node_id ifconfig $ifc down"
	}
    }

    generateHostsFile $node

    catch {exec sh << $cmds} err
    if { $err != "" } {
	if { $execMode != "batch" } {
	    after idle {.dialog1.msg configure -wraplength 4i}
	    tk_dialog .dialog1 "IMUNES warning" \
		"There was a problem with configuring the node [getNodeName $node] ($node_id).\nCheck its /$confFile and /out.log files." \
	    info 0 Dismiss
	} else {
	    puts "IMUNES warning"
	    puts "\nThere was a problem with configuring the node [getNodeName $node] ($node_id).\nCheck its /$confFile and /out.log files."
	}
    }

}

#****f* freebsd.tcl/killAllNodeProcesses
# NAME
#   killAllNodeProcesses -- kill all node processes
# SYNOPSIS
#   killAllNodeProcesses $eid $node
# FUNCTION
#   Kills all processes in the given node.
# INPUTS
#   * eid -- experiment id
#   * node -- node id
#****
proc killAllNodeProcesses { eid node } {
    set node_id "$eid.$node"

    catch "exec jexec $node_id kill -9 -1 2> /dev/null"
    catch "exec jexec $node_id tcpdrop -a 2> /dev/null"
}

#****f* freebsd.tcl/removeNodeIfcIPaddrs
# NAME
#   removeNodeIfcIPaddrs -- remove node iterfaces' IP addresses
# SYNOPSIS
#   removeNodeIfcIPaddrs $eid $node
# FUNCTION
#   Remove all IPv4 and IPv6 addresses from interfaces on the given node.
# INPUTS
#   * eid -- experiment id
#   * node -- node id
#****
proc removeNodeIfcIPaddrs { eid node } {
    set node_id "$eid.$node"

    foreach ifc [ifcList $node] {
	foreach ipv4 [getIfcIPv4addr $node $ifc] {
	    catch "exec jexec $node_id ifconfig $ifc $ipv4 -alias"
	}
	foreach ipv6 [getIfcIPv6addr $node $ifc] {
	    catch "exec jexec $node_id ifconfig $ifc inet6 $ipv6 -alias"
	}
    }
}

#****f* freebsd.tcl/destroyNodeVirtIfcs
# NAME
#   destroyNodeVirtIfcs -- destroy node virtual interfaces
# SYNOPSIS
#   destroyNodeVirtIfcs $eid $node
# FUNCTION
#   Destroy any virtual interfaces (tun, vlan, gif, ..) before removing the #
#   jail. This is to avoid possible kernel panics.
# INPUTS
#   * eid -- experiment id
#   * node -- node id
#****
proc destroyNodeVirtIfcs { eid node } {
    set node_id $eid.$node
    puts "destroyNodeVirtIfcs: Destroying virtual ifc for $node"

    pipesExec "for iface in `jexec $node_id ifconfig -l`; do jexec $node_id ifconfig \$iface destroy; done" "hold"
}

#****f* freebsd.tcl/removeNodeContainer
# NAME
#   removeNodeContainer -- remove node container
# SYNOPSIS
#   removeNodeContainer $eid $node
# FUNCTION
#   Removes the jail (container) of the given node.
# INPUTS
#   * eid -- experiment id
#   * node -- node id
#****
proc removeNodeContainer { eid node } {
    set node_id $eid.$node

    pipesExec "jail -r $node_id" "hold"
}

#****f* freebsd.tcl/removeNodeFS
# NAME
#   removeNodeFS -- remove node filesystem
# SYNOPSIS
#   removeNodeFS $eid $node
# FUNCTION
#   Removes the filesystem of the given node.
# INPUTS
#   * eid -- experiment id
#   * node -- node id
#****
proc removeNodeFS { eid node } {
    global vroot_unionfs vroot_linprocfs

    set node_id $eid.$node

    set VROOTDIR [getVrootDir]
    set VROOT_RUNTIME $VROOTDIR/$eid/$node
    set VROOT_RUNTIME_DEV $VROOT_RUNTIME/dev
    pipesExec "umount -f $VROOT_RUNTIME_DEV" "hold"
    if {$vroot_unionfs} {
	# 1st: unionfs RW overlay
	pipesExec "umount -f $VROOT_RUNTIME" "hold"
	# 2nd: nullfs RO loopback
	pipesExec "umount -f $VROOT_RUNTIME" "hold"
	pipesExec "rmdir $VROOT_RUNTIME" "hold"
    }

    if {$vroot_linprocfs} {
	pipesExec "umount -f $VROOT_RUNTIME/compat/linux/proc" "hold"
    }
}

#****f* freebsd.tcl/loadKernelModules
# NAME
#   loadKernelModules -- load kernel modules
# SYNOPSIS
#   loadKernelModules
# FUNCTION
#   Load necessary kernel modules.
#****
proc loadKernelModules {} {
    global all_modules_list

    catch {exec kldload nullfs}
    catch {exec kldload unionfs}

    catch {exec kldload ng_eiface}
    catch {exec kldload ng_pipe}
    catch {exec kldload ng_socket}
    catch {exec kldload if_tun}
    catch {exec kldload vlan}
#   catch {exec kldload ng_iface}
#   catch {exec kldload ng_cisco}

    foreach module $all_modules_list {
	if {[info procs $module.prepareSystem] == "$module.prepareSystem"} {
	    $module.prepareSystem
	}
    }
}

#****f* freebsd.tcl/prepareVirtualFS
# NAME
#   prepareVirtualFS -- prepare virtual filesystem
# SYNOPSIS
#   prepareVirtualFS
# FUNCTION
#   Prepares all necessary files for the virtual filesystem.
#****
proc prepareVirtualFS {} {
    upvar 0 ::cf::[set ::curcfg]::eid eid
    global vroot_unionfs

    if {$vroot_unionfs} {
	# UNIONFS - anything to do here?
    } else {
	exec zfs create vroot/$eid
    }
}

proc prepareDevfs {} {}

#****f* linux.tcl/getHostIfcList
# NAME
#   getHostIfcList -- get interfaces list from host
# SYNOPSIS
#   getHostIfcList
# FUNCTION
#   Returns the list of all network interfaces on the host.
# RESULT
#   * extifcs -- list of all external interfaces
#****
proc getHostIfcList {} {
    # fetch interface list from the system
    set extifcs [exec ls /sys/class/net]
    # exclude loopback interface
    set ilo [lsearch $extifcs lo]
    set extifcs [lreplace $extifcs $ilo $ilo]

    return $extifcs
}

proc createExperimentContainer {} {}

proc loadKernelModules {} {
    global all_modules_list

    foreach module $all_modules_list {
        if {[info procs $module.prepareSystem] == "$module.prepareSystem"} {
            $module.prepareSystem
        }
    }
}

proc prepareVirtualFS {} {}

#****f* linux.tcl/prepareFilesystemForNode
# NAME
#   prepareFilesystemForNode -- prepare node filesystem
# SYNOPSIS
#   prepareFilesystemForNode $node
# FUNCTION
#   Prepares the node virtual filesystem.
# INPUTS
#   * node -- node id
#****
proc prepareFilesystemForNode { node } {
    upvar 0 ::cf::[set ::curcfg]::eid eid

    set VROOTDIR /var/imunes
    set VROOT_RUNTIME $VROOTDIR/$eid/$node
    pipesExec "mkdir -p $VROOT_RUNTIME" "hold"
    pipesExec "mkdir -p /var/run/netns" "hold"
}

#****f* linux.tcl/createNodeContainer
# NAME
#   createNodeContainer -- creates a virtual node container
# SYNOPSIS
#   createNodeContainer $node
# FUNCTION
#   Creates a docker instance using the defined template and
#   assigns the hostname. Waits for the node to be up.
# INPUTS
#   * node -- node id
#****
proc createNodeContainer { node } {
    upvar 0 ::cf::[set ::curcfg]::eid eid
    global VROOT_MASTER ULIMIT_FILE ULIMIT_PROC debug

    set node_id "$eid.$node"

    set network "none"
    if { [getNodeDockerAttach $node] } {
	set network "bridge"
    }
    set vroot [getNodeDockerImage $node]
    if { $vroot == "" } {
        set vroot $VROOT_MASTER
    }

    catch { exec docker run --detach --init --tty \
	--privileged --cap-add=ALL --net=$network \
	--name $node_id --hostname=[getNodeName $node] \
	--volume /tmp/.X11-unix:/tmp/.X11-unix \
	--sysctl net.ipv6.conf.all.disable_ipv6=0 \
	--ulimit nofile=$ULIMIT_FILE --ulimit nproc=$ULIMIT_PROC \
	$vroot } err
    if { $debug } {
        puts "'exec docker run' ($node_id) caught:\n$err"
    }
    if { [getNodeDockerAttach $node] } {
	catch "exec docker exec $node_id ip l set eth0 down"
	catch "exec docker exec $node_id ip l set eth0 name ext0"
	catch "exec docker exec $node_id ip l set ext0 up"
    }

    set status ""
    while { [string match 'true' $status] != 1 } {
        catch {exec docker inspect --format '{{.State.Running}}' $node_id} status
    }
}

#****f* linux.tcl/createNodePhysIfcs
# NAME
#   createNodePhysIfcs -- create node physical interfaces
# SYNOPSIS
#   createNodePhysIfcs $node
# FUNCTION
#   Creates physical interfaces for the given node.
# INPUTS
#   * node -- node id
#****
proc createNodePhysIfcs { node } {}

proc createNodeLogIfcs { node } {}

#****f* linux.tcl/configureICMPoptions
# NAME
#   configureICMPoptions -- configure ICMP options
# SYNOPSIS
#   configureICMPoptions $node
# FUNCTION
#  Configures the necessary ICMP sysctls in the given node.
# INPUTS
#   * node -- node id
#****
proc configureICMPoptions { node } {
    upvar 0 ::cf::[set ::curcfg]::eid eid

    array set sysctl_icmp {
	net.ipv4.icmp_ratelimit			0
	net.ipv4.icmp_echo_ignore_broadcasts	1
    }

    foreach {name val} [array get sysctl_icmp] {
	lappend cmd "sysctl $name=$val"
    }
    set cmds [join $cmd "; "]

    pipesExec "docker exec $eid.$node sh -c \'$cmds\'" "hold"
}

proc createLinkBetween { lnode1 lnode2 ifname1 ifname2 } {
    upvar 0 ::cf::[set ::curcfg]::eid eid

    set ether1 [getIfcMACaddr $lnode1 $ifname1]
    if {$ether1 == ""} {
        autoMACaddr $lnode1 $ifname1
    }
    set ether1 [getIfcMACaddr $lnode1 $ifname1]

    set ether2 [getIfcMACaddr $lnode2 $ifname2]
    if {$ether2 == ""} {
        autoMACaddr $lnode2 $ifname2
    }
    set ether2 [getIfcMACaddr $lnode2 $ifname2]

    set lname1 $lnode1
    set lname2 $lnode2

    switch -exact "[[typemodel $lnode1].virtlayer]-[[typemodel $lnode2].virtlayer]" {
	NETGRAPH-NETGRAPH {
	    if { [nodeType $lnode1] == "ext" } {
		catch "exec ovs-vsctl add-br $eid-$lnode1"
	    }
	    if { [nodeType $lnode2] == "ext" } {
		catch "exec ovs-vsctl add-br $eid-$lnode2"
	    }
	    # generate interface names
	    set hostIfc1 "$eid-$lname1-$ifname1"
	    set hostIfc2 "$eid-$lname2-$ifname2"
	    # create veth pair
	    catch {exec ip link add name "$hostIfc1" type veth peer name "$hostIfc2"}
	    # add veth interfaces to bridges
	    catch "exec ovs-vsctl add-port $eid-$lname1 $hostIfc1"
	    catch "exec ovs-vsctl add-port $eid-$lname2 $hostIfc2"
	    # set bridge interfaces up
	    exec ip link set dev $hostIfc1 up
	    exec ip link set dev $hostIfc2 up
	}
	VIMAGE-VIMAGE {
	    # prepare namespace files
	    set lnode1Ns [createNetNs $lnode1]
	    set lnode2Ns [createNetNs $lnode2]
	    # generate temporary interface names
	    set hostIfc1 "v${ifname1}pn${lnode1Ns}"
	    set hostIfc2 "v${ifname2}pn${lnode2Ns}"
	    # create veth pair
	    exec ip link add name "$hostIfc1" type veth peer name "$hostIfc2"
	    # move veth pair sides to node namespaces
	    setIfcNetNs $lnode1 $hostIfc1 $ifname1
	    setIfcNetNs $lnode2 $hostIfc2 $ifname2
	    # set mac addresses of node ifcs
	    exec nsenter -n -t $lnode1Ns ip link set dev "$ifname1" \
		address "$ether1"
	    exec nsenter -n -t $lnode2Ns ip link set dev "$ifname2" \
		address "$ether2"
	    # delete net namespace reference files
	    exec ip netns del $lnode1Ns
	    exec ip netns del $lnode2Ns
	}
	NETGRAPH-VIMAGE {
	    addNodeIfcToBridge $lname1 $ifname1 $lnode2 $ifname2 $ether2
	}
	VIMAGE-NETGRAPH {
	    addNodeIfcToBridge $lname2 $ifname2 $lnode1 $ifname1 $ether1
	}
    }
}

proc configureLinkBetween { lnode1 lnode2 ifname1 ifname2 link } {
    upvar 0 ::cf::[set ::curcfg]::eid eid

    # FIXME: merge this with execSet* commands
    execSetLinkParams $eid $link

    # if {[nodeType $lnode1] != "rj45" && [nodeType $lnode2] != "rj45"} {
    #     set qdisc [getIfcQDisc $lnode1 $ifname1]
    #     if {$qdisc ne "FIFO"} {
    #         execSetIfcQDisc $eid $lnode1 $ifname2 $qdisc
    #     }

    #     set qdisc [getIfcQDisc $lnode2 $ifname2]
    #     if {$qdisc ne "FIFO"} {
    #         execSetIfcQDisc $eid $lnode2 $ifname2 $qdisc
    #     }
    #     set qdrop [getIfcQDrop $node $ifc]
    #     if {$qdrop ne "drop-tail"} {
    #         execSetIfcQDrop $eid $node $ifc $qdrop
    #     }
    #     set qlen [getIfcQLen $node $ifc]
    #     if {$qlen ne 50} {
    #         execSetIfcQLen $eid $node $ifc $qlen
    #     }
    # }
}

#****f* linux.tcl/startIfcsNode
# NAME
#   startIfcsNode -- start interfaces on node
# SYNOPSIS
#   startIfcsNode $node
# FUNCTION
#  Starts all interfaces on the given node.
# INPUTS
#   * node -- node id
#****
proc startIfcsNode { node } {
    upvar 0 ::cf::[set ::curcfg]::eid eid

    set cmds ""
    set nodeNs [getNodeNamespace $node]
    foreach ifc [allIfcList $node] {
	set mtu [getIfcMTU $node $ifc]
	set tmpifc $ifc
	if { $ifc == "lo0" } {
	    set tmpifc lo
	}
	if {[getIfcOperState $node $ifc] == "up"} {
	    set cmds "$cmds\n nsenter -n -t $nodeNs ip link set dev $tmpifc up mtu $mtu"
	} else {
	    set cmds "$cmds\n nsenter -n -t $nodeNs ip link set dev $tmpifc mtu $mtu"
	}
    }
    exec sh << $cmds
}

proc removeExperimentContainer { eid widget } {}

proc removeNodeContainer { eid node } {
    set node_id $eid.$node

    catch "exec docker kill $node_id"
    catch "exec docker rm $node_id"
}

proc killAllNodeProcesses { eid node } {
    set node_id "$eid.$node"

    catch "exec docker exec $node_id killall5 -o 1 -9"
}

proc destroyVirtNodeIfcs { eid vimages } {}

proc runConfOnNode { node } {
    upvar 0 ::cf::[set ::curcfg]::eid eid
    global execMode

    set node_dir [getVrootDir]/$eid/$node
    set node_id "$eid.$node"

    catch {exec docker exec $node_id umount /etc/resolv.conf /etc/hosts}

    if { [getCustomEnabled $node] == true } {
        set selected [getCustomConfigSelected $node]

        set bootcmd [getCustomConfigCommand $node $selected]
        set bootcfg [getCustomConfig $node $selected]
        set confFile "custom.conf"
    } else {
        set bootcfg [[typemodel $node].cfggen $node]
        set bootcmd [[typemodel $node].bootcmd $node]
        set confFile "boot.conf"
    }

    # change all occurrences of "dev lo0" to "dev lo"
    regsub -all {dev lo0} $bootcfg {dev lo} bootcfg

    writeDataToFile $node_dir/$confFile [join "{ip a flush dev lo} $bootcfg" "\n"]
    exec docker exec -i $node_id sh -c "cat > /$confFile" < $node_dir/$confFile
    exec echo "LOG START" > $node_dir/out.log
    catch {exec docker exec --tty $node_id $bootcmd /$confFile >>& $node_dir/out.log} err
    if { $err != "" } {
	if { $execMode != "batch" } {
	    after idle {.dialog1.msg configure -wraplength 4i}
	    tk_dialog .dialog1 "IMUNES warning" \
		"There was a problem with configuring the node [getNodeName $node] ($node_id).\nCheck its /$confFile and /out.log files." \
	    info 0 Dismiss
	} else {
	    puts "IMUNES warning"
	    puts "\nThere was a problem with configuring the node [getNodeName $node] ($node_id).\nCheck its /$confFile and /out.log files."
	}
    }
    exec docker exec -i $node_id sh -c "cat > /out.log" < $node_dir/out.log

    set nodeNs [getNodeNamespace $node]
    foreach ifc [allIfcList $node] {
	if {[getIfcOperState $node $ifc] == "down"} {
	    set tmpifc $ifc
	    if { $ifc == "lo0" } {
		set ifc lo
	    }
	    exec nsenter -n -t $nodeNs ip link set dev $ifc down
	}
    }

    generateHostsFile $node
}

proc destroyLinkBetween { eid lnode1 lnode2 } {
    set ifname1 [ifcByLogicalPeer $lnode1 $lnode2]
    catch {exec ip link del dev $eid-$lnode1-$ifname1}
}

#****f* linux.tcl/removeNodeIfcIPaddrs
# NAME
#   removeNodeIfcIPaddrs -- remove node iterfaces' IP addresses
# SYNOPSIS
#   removeNodeIfcIPaddrs $eid $node
# FUNCTION
#   Remove all IPv4 and IPv6 addresses from interfaces on the given node.
# INPUTS
#   * eid -- experiment id
#   * node -- node id
#****
proc removeNodeIfcIPaddrs { eid node } {
    set node_id "$eid.$node"
    foreach ifc [allIfcList $node] {
	catch "exec docker exec $node_id ip addr flush dev $ifc"
    }
}

proc removeExperimentContainer { eid widget } {
    set VROOT_BASE [getVrootDir]
    catch "exec rm -fr $VROOT_BASE/$eid &"
}

proc createNetgraphNode { eid node } {
    catch {exec ovs-vsctl add-br $eid-$node}
}

proc destroyNetgraphNode { eid node } {
    catch {exec ovs-vsctl del-br $eid-$node}
}

proc destroyNetgraphNodes { eid switches widget } {
    global execMode

    # destroying openvswitch nodes
    if { $switches != "" } {
        statline "Shutting down netgraph nodes..."
        set i 0
        foreach node $switches {
            incr i
            # statline "Shutting down openvswitch node $node ([typemodel $node])"
            [typemodel $node].destroy $eid $node
            if {$execMode != "batch"} {
                $widget.p step -1
            }
            displayBatchProgress $i [ llength $switches ]
        }
        statline ""
    }
}

#****f* linux.tcl/getVrootDir
# NAME
#   getVrootDir -- get virtual root directory
# SYNOPSIS
#   getVrootDir
# FUNCTION
#   Helper function that returns virtual root directory.
# RESULT
#   * vroot_dir -- virtual root directory
#****
proc getVrootDir {} {
    global vroot_unionfs

    if {$vroot_unionfs} {
	return "/var/imunes"
    } else {
	return "/vroot"
    }
}

#****f* freebsd.tcl/dumpNgnodesToFile
# NAME
#   dumpNgnodesToFile -- dump ngnodemap list to file
# SYNOPSIS
#   dumpNgnodesToFile $path
# FUNCTION
#   Saves the list of all the ngnodes to $path.
# INPUTS
#   * path -- absolute path of the file
#****
proc dumpNgnodesToFile { path } {
    upvar 0 ::cf::[set ::curcfg]::ngnodemap ngnodemap

    writeDataToFile $path [array get ngnodemap]
}


#****f* freebsd.tcl/killProcess
# NAME
#   killProcess -- kill processes with the given regex
# SYNOPSIS
#   killProcess $regex
# FUNCTION
#   Executes a pkill command to kill all processes with a corresponding regex.
# INPUTS
#   * regex -- regularl expression of the processes
#****
proc killExtProcess { regex } {
    catch "exec pkill -f \"$regex\""
}

#****f* freebsd.tcl/destroyNodeVirtIfcs
# NAME
#   destroyNodeVirtIfcs -- destroy node virtual interfaces
# SYNOPSIS
#   destroyNodeVirtIfcs $eid $node
# FUNCTION
#   Destroy any virtual interfaces (tun, vlan, gif, ..) before removing the #
#   jail. This is to avoid possible kernel panics.
# INPUTS
#   * eid -- experiment id
#   * node -- node id
#****
proc destroyNodeVirtIfcs { eid node } {
    set node_id $eid.$node
    puts "destroyNodeVirtIfcs: Destroying virtual ifc for $node"

    #pipesExec "for iface in `jexec $node_id ifconfig -l`; do jexec $node_id ifconfig \$iface destroy; done" "hold"
}

#****f* freebsd.tcl/removeNodeFS
# NAME
#   removeNodeFS -- remove node filesystem
# SYNOPSIS
#   removeNodeFS $eid $node
# FUNCTION
#   Removes the filesystem of the given node.
# INPUTS
#   * eid -- experiment id
#   * node -- node id
#****
proc removeNodeFS { eid node } {
    global vroot_unionfs vroot_linprocfs

    set node_id $eid.$node

    set VROOTDIR [getVrootDir]
    set VROOT_RUNTIME $VROOTDIR/$eid/$node
    set VROOT_RUNTIME_DEV $VROOT_RUNTIME/dev
    #exec "umount -f $VROOT_RUNTIME_DEV"
    try {
        #set results [exec ls -al $VROOT_RUNTIME]
        set status 0
        #puts "$results"
    } trap CHILDSTATUS {results options} {
        set status [lindex [dict get $options -errorcode] 2]
    }
    if {$vroot_unionfs} {
        puts "UMOUNT"
	# 1st: unionfs RW overlay
	#exec "umount -f $VROOT_RUNTIME"
	# 2nd: nullfs RO loopback
	#exec "umount -f $VROOT_RUNTIME"
	exec rm -rf $VROOT_RUNTIME
    }

    if {$vroot_linprocfs} {
	exec "umount -f $VROOT_RUNTIME/compat/linux/proc"
    }
}

#****f* freebsd.tcl/timeoutPatch
# NAME
#   timeoutPatch -- timeout patch
# SYNOPSIS
#   timeoutPatch $eid $vimages
# FUNCTION
#   Timeout patch that is applied for hanging TCP connections. We need to wait
#   for TCP connections to close regularly because we can't terminate them in
#   FreeBSD 8. In FreeBSD that should be possible with the tcpdrop command.
# INPUTS
#   * eid -- experiment ID
#   * vimages -- list of current vimages
#****
proc timeoutPatch { eid vimages } {
    global execMode
    set vrti 1
    set sec 60

    if { [lindex [split [exec uname -r] "-"] 0] >= 9.0 } {
	return
    }

    set timeoutNeeded 0
    foreach vimage $vimages {
	if { [catch {exec jexec $eid.$vimage netstat -an -f inet | fgrep "WAIT"} odg] == 0} {
	    set timeoutNeeded 1
	    break
	}
    }

    if { $timeoutNeeded == 0 } {
	return
    }

    if { $execMode == "batch" } {
        puts "We must wait for TIME_WAIT expiration on virtual nodes (up to 60 sec). "
        puts "Please don't try killing the process."
    } else {
        set w .timewait
        catch {destroy $w}
        toplevel $w -takefocus 1
        wm transient $w .
        wm title $w "Please wait ..."
        message $w.msg -justify left -aspect 1200 \
         -text "We must wait for TIME_WAIT expiration on virtual nodes (up to 60 sec).
Please don't try killing the process.
(countdown on status line)"
       pack $w.msg
	ttk::progressbar $w.p -orient horizontal -length 350 \
	-mode determinate -maximum $sec -value $sec
        pack $w.p
        update
        grab $w
    }

    while { $vrti == 1 } {
        set vrti 0
        foreach vimage $vimages {
            # puts "vimage $vimage...\n"
            while { [catch {exec jexec $eid.$vimage netstat -an -f inet | fgrep "WAIT"} odg] == 0} {
                set vrti 1
                # puts "vimage $vimage: \n$odg\n"
                after 1000
                set sec [expr $sec - 1]
                if { $execMode == "batch" } {
                    puts -nonewline "."
                    flush stdout
                } else {
                    statline "~ $sec seconds ..."
		    $w.p step -1
                    update
                }
            }
        }
    }
    if { $execMode != "batch" } {
        destroy .timewait
    }
    statline ""
}

#****f* linux.tcl/getCpuCount
# NAME
#   getCpuCount -- get CPU count
# SYNOPSIS
#   getCpuCount
# FUNCTION
#   Gets a CPU count of the host machine.
# RESULT
#   * cpucount - CPU count
#****
proc getCpuCount {} {
    return [lindex [exec grep -c processor /proc/cpuinfo] 0]
}

#****f* linux.tcl/l2node.instantiate
# NAME
#   l2node.instantiate -- instantiate
# SYNOPSIS
#   l2node.instantiate $eid $node
# FUNCTION
#   Procedure l2node.instantiate creates a new netgraph node of the appropriate type.
# INPUTS
#   * eid -- experiment id
#   * node -- id of the node (type of the node is either lanswitch or hub)
#****
proc l2node.instantiate { eid node } {
    createNetgraphNode $eid $node
}

#****f* linux.tcl/l2node.destroy
# NAME
#   l2node.destroy -- destroy
# SYNOPSIS
#   l2node.destroy $eid $node
# FUNCTION
#   Destroys a l2 node.
# INPUTS
#   * eid -- experiment id
#   * node -- id of the node
#****
proc l2node.destroy { eid node } {
    destroyNetgraphNode $eid $node
}

#****f* linux.tcl/enableIPforwarding
# NAME
#   enableIPforwarding -- enable IP forwarding
# SYNOPSIS
#   enableIPforwarding $eid $node
# FUNCTION
#   Enables IPv4 and IPv6 forwarding on the given node.
# INPUTS
#   * eid -- experiment id
#   * node -- node id
#****
proc enableIPforwarding { eid node } {
    array set sysctl_ipfwd {
	net.ipv6.conf.all.forwarding	1
	net.ipv4.conf.all.forwarding	1
	net.ipv4.conf.default.rp_filter	0
	net.ipv4.conf.all.rp_filter	0
    }

    foreach {name val} [array get sysctl_ipfwd] {
	lappend cmd "sysctl $name=$val"
    }
    set cmds [join $cmd "; "]

    pipesExec "docker exec $eid.$node sh -c \'$cmds\'" "hold"
}

#****f* linux.tcl/configDefaultLoIfc
# NAME
#   configDefaultLoIfc -- configure default logical interface
# SYNOPSIS
#   configDefaultLoIfc $eid $node
# FUNCTION
#   Configures the default logical interface address for the given node.
# INPUTS
#   * eid -- experiment id
#   * node -- node id
#****
proc configDefaultLoIfc { eid node } {
    pipesExec "docker exec $eid\.$node ifconfig lo 127.0.0.1/8" "hold"
}

#****f* linux.tcl/getExtIfcs
# NAME
#   getExtIfcs -- get external interfaces
# SYNOPSIS
#   getExtIfcs
# FUNCTION
#   Returns the list of all available external interfaces except those defined
#   in the ignore loop.
# RESULT
#   * ifsc - list of interfaces
#****
proc getExtIfcs { } {
    catch { exec ls /sys/class/net } ifcs
    foreach ignore "lo* ipfw* tun*" {
        set ifcs [ lsearch -all -inline -not $ifcs $ignore ]
    }
    return "$ifcs"
}

#****f* linux.tcl/captureExtIfc
# NAME
#   captureExtIfc -- capture external interfaces
# SYNOPSIS
#   captureExtIfc $eid $node
# FUNCTION
#   Captures the external interfaces given by the given rj45 node.
# INPUTS
#   * eid -- experiment id
#   * node -- node id
#****
proc captureExtIfc { eid node } {
    set ifname [getNodeName $node]
    createNetgraphNode $eid $node
    catch {exec ovs-vsctl add-port $eid-$node $ifname}
}

#****f* linux.tcl/releaseExtIfc
# NAME
#   releaseExtIfc -- release external interfaces
# SYNOPSIS
#   releaseExtIfc $eid $node
# FUNCTION
#   Releases the external interfaces captured by the given rj45 node.
# INPUTS
#   * eid -- experiment id
#   * node -- node id
#****
proc releaseExtIfc { eid node } {
    catch "destroyNetgraphNode $eid $node"
}

proc getIPv4RouteCmd { statrte } {
    set route [lindex $statrte 0]
    set addr [lindex $statrte 1]
    set cmd "ip route add $route via $addr"
    return $cmd
}

proc getIPv6RouteCmd { statrte } {
    set route [lindex $statrte 0]
    set addr [lindex $statrte 1]
    if {$route == "::/0"} {
        set cmd "ip -6 route add $route via $addr"
    } else {
        set cmd "ip -6 route add default via $addr"
    }
    return $cmd
}

proc getIPv4IfcCmd { ifc addr primary } {
    return "ip addr add $addr dev $ifc"
}

proc getIPv6IfcCmd { ifc addr primary } {
    return "ip -6 addr add $addr dev $ifc"
}

#****f* linux.tcl/getRunningNodeIfcList
# NAME
#   getRunningNodeIfcList -- get interfaces list from the node
# SYNOPSIS
#   getRunningNodeIfcList $node
# FUNCTION
#   Returns the list of all network interfaces for the given node.
# INPUTS
#   * node -- node id
# RESULT
#   * list -- list in the form of {netgraph_node_name hook}
#****
proc getRunningNodeIfcList { node } {
    upvar 0 ::cf::[set ::curcfg]::eid eid

    catch {exec docker exec $eid.$node ifconfig} full
    set lines [split $full "\n"]

    return $lines
}

proc hub.start { eid node } {
    set node_id "$eid-$node"
    catch {exec ovs-vsctl list-ports $node_id} ports
    foreach port $ports {
        catch {exec ovs-vsctl -- add bridge $node_id mirrors @m \
        -- --id=@p get port $port \
        -- --id=@m create mirror name=$port select-all=true output-port=@p}
    }
}

proc getNodeNamespace { node } {
    upvar 0 ::cf::[set ::curcfg]::eid eid

    set node_id "$eid.$node"
    catch {exec docker inspect -f "{{.State.Pid}}" $node_id} ns
    return $ns
}

proc addNodeIfcToBridge { bridge brifc node ifc mac } {
    upvar 0 ::cf::[set ::curcfg]::eid eid

    set nodeNs [createNetNs $node]
    # create bridge
    catch "exec ovs-vsctl add-br $eid-$bridge"

    # generate interface names
    set hostIfc "$eid-$bridge-$brifc"
    set guestIfc "$eid-$node-$ifc"

    # create veth pair
    exec ip link add name "$hostIfc" type veth peer name "$guestIfc"
    # add host side of veth pair to bridge
    catch "exec ovs-vsctl add-port $eid-$bridge $hostIfc"

    exec ip link set "$hostIfc" up

    # move guest side of veth pair to node namespace
    setIfcNetNs $node $guestIfc $ifc
    # set mac address
    exec nsenter -n -t $nodeNs ip link set dev "$ifc" address "$mac"
    # delete net namespace reference file
    exec ip netns del $nodeNs
}

proc checkSysPrerequisites {} {
    set msg ""
    if { [catch {exec docker ps } err] } {
        set msg "Cannot start experiment. Is docker installed and running (check the output of 'docker ps')?\n"
    }

    if { [catch {exec pgrep ovs-vswitchd } err ] } {
        set msg "Cannot start experiment. Is ovs-vswitchd installed and running (check the output of 'pgrep ovs-vswitchd')?\n"
    }

    if { [catch {exec nsenter --version}] } {
        set msg "Cannot start experiment. Is nsenter installed (check the output of 'nsenter --version')?\n"
    }

    if { [catch {exec xterm -version}] } {
        set msg "Cannot start experiment. Is xterm installed (check the output of 'xterm -version')?\n"
    }

    if { $msg != "" } {
        return "$msg\nIMUNES needs docker and ovs-vswitchd services running and\
xterm and nsenter installed."
    }

    return ""
}

proc createNetNs { node } {
    set nodeNs [getNodeNamespace $node]
    exec rm -f "/var/run/netns/$nodeNs"
    exec ln -s "/proc/$nodeNs/ns/net" "/var/run/netns/$nodeNs"
    return $nodeNs
}

proc setIfcNetNs { node oldIfc newIfc } {
    set nodeNs [getNodeNamespace $node]
    exec ip link set "$oldIfc" netns "$nodeNs"
    exec nsenter -n -t $nodeNs ip link set "$oldIfc" name "$newIfc"
}

#****f* linux.tcl/execSetIfcQDisc
# NAME
#   execSetIfcQDisc -- in exec mode set interface queuing discipline
# SYNOPSIS
#   execSetIfcQDisc $eid $node $ifc $qdisc
# FUNCTION
#   Sets the queuing discipline during the simulation.
#   New queuing discipline is defined in qdisc parameter.
#   Queueing discipline can be set to fifo, wfq or drr.
# INPUTS
#   eid -- experiment id
#   node -- node id
#   ifc -- interface name
#   qdisc -- queuing discipline
#****
proc execSetIfcQDisc { eid node ifc qdisc } {
    set target [linkByIfc $node $ifc]
    set peers [linkPeers [lindex $target 0]]
    set dir [lindex $target 1]
    set lnode1 [lindex $peers 0]
    set lnode2 [lindex $peers 1]
    if { [nodeType $lnode2] == "pseudo" } {
        set mirror_link [getLinkMirror [lindex $target 0]]
        set lnode2 [lindex [linkPeers $mirror_link] 0]
    }
    switch -exact $qdisc {
        FIFO { set qdisc fifo_fast }
        WFQ { set qdisc wfq }
        DRR { set qdisc drr }
    }
    exec docker exec $eid.$node tc qdisc add dev $ifc root $qdisc
}

proc getNetemConfigLine { bandwidth delay loss dup } {
    array set netem {
	bandwidth "rate Xbit"
	loss      "loss random X%"
	delay     "delay Xus"
	dup       "duplicate X%"
    }
    set cmd ""

    foreach { val ctemplate } [array get netem] {
	if { [set $val] != 0 } {
	    set confline "[lindex [split $ctemplate "X"] 0][set $val][lindex [split $ctemplate "X"] 1]"
	    append cmd " $confline"
	}
    }

    return $cmd
}

proc configureIfcLinkParams { eid node ifname bandwidth delay ber dup } {
    global debug

    if {[nodeType $node] == "rj45"} {
        set lname [getNodeName $node]
    } else {
        set lname $node
    }

    # average packet size in the Internet is 576 bytes
    # XXX: maybe migrate to PER (packet error rate), on FreeBSD we calculate
    # BER with the magic number 576 and on Linux we take the value directly
    if { $ber != 0 } {
	set loss [expr (1 / double($ber)) * 576 * 8 * 100]
	if { $loss > 100 } {
	    set loss 100
	}
    } else {
	set loss 0
    }

    if { [[typemodel $node].virtlayer] == "NETGRAPH" } {
        catch {exec tc qdisc del dev $eid-$lname-$ifname root}
	# XXX: currently we have loss, but we can easily have
	# corrupt, add a tickbox to GUI, default behaviour
	# should be loss because we don't do corrupt on FreeBSD
	# set confstring "netem corrupt ${loss}%"
	# corrupt ${loss}%
	set cmd "tc qdisc add dev $eid-$lname-$ifname root netem"
	catch {
	    eval exec $cmd [getNetemConfigLine $bandwidth $delay $loss $dup]
	} err

	if { $debug && $err != "" } {
	    puts stderr "tc ERROR: $eid-$lname-$ifname, $err"
	    puts stderr "gui settings: bw $bandwidth loss $loss delay $delay dup $dup"
	    catch { exec tc qdisc show dev $eid-$lname-$ifname } status
	    puts stderr $status
	}
    }
    if { [[typemodel $node].virtlayer] == "VIMAGE" } {
        set nodeNs [getNodeNamespace $node]
        catch {exec nsenter -n -t $nodeNs tc qdisc del dev $ifname root}

	# XXX: same as the above
	set cmd "nsenter -n -t $nodeNs tc qdisc add dev $ifname root netem"
	eval exec $cmd [getNetemConfigLine $bandwidth $delay $loss $dup]
    }

    # XXX: Now on Linux we don't care about queue lengths and we don't limit
    # maximum data and burst size.
    # in the future we can use something like this: (based on the qlen
    # parameter)
    # set confstring "tbf rate ${bandwidth}bit limit 10mb burst 1540"
}

#****f* linux.tcl/execSetLinkParams
# NAME
#   execSetLinkParams -- in exec mode set link parameters
# SYNOPSIS
#   execSetLinkParams $eid $link
# FUNCTION
#   Sets the link parameters during the simulation.
#   All the parameters are set at the same time.
# INPUTS
#   eid -- experiment id
#   link -- link id
#****
proc execSetLinkParams { eid link } {
    global debug

    set lnode1 [lindex [linkPeers $link] 0]
    set lnode2 [lindex [linkPeers $link] 1]
    set ifname1 [ifcByLogicalPeer $lnode1 $lnode2]
    set ifname2 [ifcByLogicalPeer $lnode2 $lnode1]

    if { [getLinkMirror $link] != "" } {
	set mirror_link [getLinkMirror $link]
	if { [nodeType $lnode1] == "pseudo" } {
	    set p_lnode1 $lnode1
	    set lnode1 [lindex [linkPeers $mirror_link] 0]
	    set ifname1 [ifcByPeer $lnode1 [getNodeMirror $p_lnode1]]
	} else {
	    set p_lnode2 $lnode2
	    set lnode2 [lindex [linkPeers $mirror_link] 0]
	    set ifname2 [ifcByPeer $lnode2 [getNodeMirror $p_lnode2]]
	}
    }

    set bandwidth [expr [getLinkBandwidth $link] + 0]
    set delay [expr [getLinkDelay $link] + 0]
    set ber [expr [getLinkBER $link] + 0]
    set dup [expr [getLinkDup $link] + 0]

    configureIfcLinkParams $eid $lnode1 $ifname1 $bandwidth $delay $ber $dup
    configureIfcLinkParams $eid $lnode2 $ifname2 $bandwidth $delay $ber $dup
}

proc ipsecFilesToNode { node local_cert ipsecret_file } {
    global ipsecConf ipsecSecrets

    if { $local_cert != "" } {
	set trimmed_local_cert [lindex [split $local_cert /] end]
	set fileId [open $trimmed_local_cert "r"]
	set trimmed_local_cert_data [read $fileId]
	writeDataToNodeFile $node /etc/ipsec.d/certs/$trimmed_local_cert $trimmed_local_cert_data
	close $fileId
    }

    if { $ipsecret_file != "" } {
	set trimmed_local_key [lindex [split $ipsecret_file /] end]
	set fileId [open $trimmed_local_key "r"]
	set trimmed_local_key_data "# /etc/ipsec.secrets - strongSwan IPsec secrets file\n"
	set trimmed_local_key_data "$trimmed_local_key_data[read $fileId]\n"
	set trimmed_local_key_data "$trimmed_local_key_data: RSA $trimmed_local_key"
	writeDataToNodeFile $node /etc/ipsec.d/private/$trimmed_local_key $trimmed_local_key_data
	close $fileId
    }

    writeDataToNodeFile $node /etc/ipsec.conf $ipsecConf
    writeDataToNodeFile $node /etc/ipsec.secrets $ipsecSecrets
}

proc sshServiceStartCmds {} {
    lappend cmds "dpkg-reconfigure openssh-server"
    lappend cmds "service ssh start"
    return $cmds
}

proc sshServiceStopCmds {} {
    return {"service ssh stop"}
}

proc inetdServiceRestartCmds {} {
    return "service openbsd-inetd restart"
}

proc moveFileFromNode { node path ext_path } {
    upvar 0 ::cf::[set ::curcfg]::eid eid
    catch {exec hcp [getNodeName $node]@$eid:$path $ext_path}
    catch {exec docker exec $eid.$node rm -fr $path}
}

# XXX NAT64 procedures
proc createStartTunIfc { eid node } {
    # create and start tun interface and return its name
    exec docker exec -i $eid.$node ip tuntap add mode tun
    catch "exec docker exec $eid.$node ip l | grep tun | tail -n1 | cut -d: -f2" tun
    set tun [string trim $tun]
    exec docker exec -i $eid.$node ip l set $tun up

    return $tun
}

proc prepareTaygaConf { eid node data datadir } {
    exec docker exec -i $eid.$node mkdir -p $datadir
    writeDataToNodeFile $node "/etc/tayga.conf" $data
}

proc taygaShutdown { eid node } {
    catch "exec docker exec $eid.$node killall5 -9 tayga"
    exec docker exec $eid.$node rm -rf /var/db/tayga
}

proc taygaDestroy { eid node } {
    global nat64ifc_$eid.$node
    catch {exec docker exec $eid.$node ip l delete [set nat64ifc_$eid.$node]}
}

# XXX External connection procedures
proc extInstantiate { node } {
}

proc startExternalIfc { eid node } {
    set cmds ""
    set ifc [lindex [ifcList $node] 0]
    set outifc "$eid-$node"

    set ether [getIfcMACaddr $node $ifc]
    if {$ether == ""} {
       autoMACaddr $node $ifc
    }
    set ether [getIfcMACaddr $node $ifc]
    set cmds "ip l set $outifc address $ether"

    set cmds "$cmds\n ip a flush dev $outifc"

    set ipv4 [getIfcIPv4addr $node $ifc]
    if {$ipv4 == ""} {
       autoIPv4addr $node $ifc
    }
    set ipv4 [getIfcIPv4addr $node $ifc]
    set cmds "$cmds\n ip a add $ipv4 dev $outifc"

    set ipv6 [getIfcIPv6addr $node $ifc]
    if {$ipv6 == ""} {
       autoIPv6addr $node $ifc
    }
    set ipv6 [getIfcIPv6addr $node $ifc]
    set cmds "$cmds\n ip a add $ipv6 dev $outifc"

    set cmds "$cmds\n ip l set $outifc up"

    exec sh << $cmds &
}

proc  stopExternalIfc { eid node } {
    exec ip l set $eid-$node down
}

proc destroyExtInterface { eid node } {
    destroyNetgraphNode $eid $node
}
