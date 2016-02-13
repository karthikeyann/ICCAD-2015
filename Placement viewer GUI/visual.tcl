#!/usr/bin/tclsh
#--------------------------------------------------------
#  Build a simple GUI
#
#  Grid a canvas with scrollbars, and add a few
#  control buttons.
#  source: http://wiki.tcl.tk/4844
#--------------------------------------------------------
package require Tk
source zoom.tcl
source parser.tcl

# global variables
set argv_bak $argv
variable canvas_width 600
variable canvas_height 500
variable enabletext 0
variable cellcolor  ""
set c [canvas .c -width $canvas_width -height $canvas_height \
        -xscrollcommand ".shoriz set" \
        -yscrollcommand ".svert set"]

scrollbar .svert  -orient v -command "$c yview"
scrollbar .shoriz -orient h -command "$c xview" 
grid .c      -row 0 -column 0 -columnspan 3 -sticky news
grid .svert  -row 0 -column 3 -columnspan 1 -sticky ns
grid .shoriz -row 1 -column 0 -columnspan 3 -sticky ew
grid columnconfigure . 0 -weight 1
grid columnconfigure . 1 -weight 1
grid columnconfigure . 2 -weight 1
grid rowconfigure . 0 -weight 1
#  Add a couple of zooming buttons
button .zoomin  -text "Zoom In"  -command "zoom $c 1.25" 
button .zoomout -text "Zoom Out" -command "zoom $c 0.8"
button .zoomfit -text "Zoom Fit" -command "zoom_fit $c %x %y"
button .toggleoutline -text "Toggle Outline" -command "toggle_width $c"

grid .zoomin .zoomfit .zoomout .toggleoutline  

# Set up event bindings for canvas:
bind $c <3> "zoomMark $c %x %y"
bind $c <B3-Motion> "zoomStroke $c %x %y"
bind $c <ButtonRelease-3> "zoomArea $c %x %y"
bind . q "exit 0"
bind . Q "exit 0"

if { $::argc > 0 } {
    set i 1
    foreach arg $::argv {
        if {[string match -nocase "*.def" $arg]} {
            set def_file $arg
        } elseif {[string match -nocase "*.lef" $arg]} {
            set lef_file $arg
        } elseif {[string match -nocase "-enabletext" $arg]} {
            set ::enabletext 1
        } elseif {[string match -nocase "-cellblack" $arg]} {
            set ::cellcolor "#000000"
        } else {
            puts "unknown argument $i is $arg"
        }
        incr i
    }
} else {
    puts "no command line argument passed"
    puts "usage: $argv0 file.def file.lef \[-enabletext\] \[-cellblack\]"
    exit 1
}
plot_placement $def_file $lef_file ".c"
zoom_fit $c 0 0

#package require tclreadline
#::tclreadline::Loop

##  supply a little test data
#for {set i 10} {$i<500} {incr i 100} {
#    for {set j 10} {$j<600} {incr j 100} {
#        .c create rectangle $i $j [expr {$i+80}] [expr {$j+80}]
#        .c create text [expr $i + 40] [expr $j + 40] -text "($i,$j)" -anchor center
#    }
#}
