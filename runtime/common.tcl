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
