
proc randomColor {} {format #%06x [expr {int(rand() * 0xFFFFFF)}]}
proc invertColor c  {format "#%06x" [expr { 0xFFFFFF - "0x[string map {"#" ""} $c]" }]}
#proc raise_widget { w myObjId myTextId} 
proc raise_widget { w mytag} {
    $w raise $mytag
    #puts "raised $mytag"
}

proc toggle_width { c  } {
    set width [expr {1 - [$c itemcget all -width]}]
    $c itemconfigure all -width $width
}

proc parse_lef { file_name } {
    set hasErr 0
    array set CELLS [list]
    if { [catch {set fp [open $file_name r]} err] } {
        puts "ERROR: file $file_name open error $err"
        exit 1
    }
    set file_data [read $fp]
    close $fp
    set data [split $file_data "\n"]
    set data_length [llength $data]
    set microns 0
    set cell_name ""
    for { set i 0 } { $i < $data_length } { incr i } {
        # do some line processing here
        set line [lindex $data $i]
        if {[regexp {DATABASE\s+MICRONS\s+([0-9]+)} $line m1 m2]} {
            set microns $m2
        }
        if {[regexp {(SITE|MACRO)\s+([a-zA-Z0-9_/]+)} $line m1 m2 m3]} {
            set cell_name $m3
        }
        if {[regexp {SIZE\s+([0-9.]+)\s+BY\s+([0-9.]+)} $line m1 m2 m3]} {
            if { $cell_name ne "" } {
                set x_dim [expr { $m2 * $microns }]
                set y_dim [expr { $m3 * $microns }]
                set CELLS($cell_name) [list $x_dim $y_dim [randomColor]]
            } else {
                puts "ERROR: SIZE without MACRO in line $i\n$line"
                set hasErr 1
            }
        }
        if { $cell_name ne "" && [regexp "END\\s\+$cell_name" $line]} {
            set cell_name ""
        }
    }
    return [array get CELLS]
}

# returns #components #x_max #y_max #components_text_list
proc parse_def { file_name } {
    if { [catch {set fp [open $file_name r]} err] } {
        puts "ERROR: file $file_name open error"
        exit 1
    }
    set file_data [read $fp]
    close $fp
    set data [split $file_data "\n"]
    set data_length [llength $data]
    # default return values
    set x_max 0
    set y_max 0
    set beg_comps 0
    set end_comps 0
    set title $::argv0
    for { set i 0 } { $i < $data_length } { incr i } {
        # do some line processing here
        set line [lindex $data $i]
        if { [regexp "^COMPONENTS" $line] } {
            set ncomps [regexp -inline {[0-9]+} $line]
            set beg_comps [expr { $i + 1 }]
            set end_comps [expr { $i + 1 + $ncomps * 2 }]
            if { ![regexp {END\s+COMPONENTS} [lindex $data $end_comps]] } {
                puts "ERROR: mismatch COMPONENTS $ncomps, line $end_comps does end with END COMPONENTS"
                exit 1
            }
            set end_comps [expr { $i + $ncomps * 2 }]
        }
        if { [regexp {^\s+\+\s+PLACED} $line] } {
            set pos [regexp -all -inline {[0-9]+} $line]
            set x_max [expr { max ( $x_max , [lindex $pos 0] ) } ]
            set y_max [expr { max ( $y_max , [lindex $pos 1] ) } ]
        }
        if {[regexp {\s*DESIGN\s+([^\s]+)} $line m1 m2]} {
            set title $m2
        }
    }
    return [list $ncomps $x_max $y_max [lrange $data $beg_comps $end_comps] $title] 
}

proc plot_components { canvas_n CELLS_ref component_text } {
    upvar $CELLS_ref CELLS
    set hasErr 0
    foreach {nameline posline} $component_text {
        set thisErr 0
        if {[regexp {\s+-\s+([a-zA-Z0-9_/]+)\s+([a-zA-Z0-9_/]+)} $nameline m1 m2 m3]} {
            set inst_name $m2
            set cell_name $m3
        } else {
            puts "ERROR: name error line mismatch \n$nameline\n$posline"
            set hasErr 1
            set thisErr 1
        }
        if { [regexp {^\s+\+\s+(PLACED|FIXED)} $posline] } {
            set pos [regexp -all -inline {[0-9]+} $posline]
            set x_pos [lindex $pos 0]
            set y_pos [lindex $pos 1]
        } else {
            puts "ERROR: PLACED line mismatch \n$nameline\n$posline"
            set hasErr 1
            set thisErr 1
        }
        if {$thisErr==0} {
            set cell_x [lindex $CELLS($cell_name) 0]
            set cell_y [lindex $CELLS($cell_name) 1]
            if { [set cell_c $::cellcolor] eq "" } {
                set cell_c [lindex $CELLS($cell_name) 2]
            }
            set myObjId [$canvas_n create rectangle $x_pos $y_pos [expr {$x_pos+$cell_x}] [expr {$y_pos+$cell_y}] -fill $cell_c -activedash _ -activeoutline #ff0000 -tag $inst_name]
            if { $::enabletext } {
                set myTextId [$canvas_n create text [expr {$x_pos + $cell_x/2}] [expr {$y_pos + $cell_y/2}] -text "$cell_name" -anchor center -tag $inst_name]
            }
            $canvas_n bind $inst_name <1> "raise_widget %W ${inst_name}"
        }
    }
    if {$hasErr} {
        exit 1
    }
}

proc plot_placement { def_file lef_file canvas_n } {
    array set CELLS [parse_lef $lef_file]
    set def_res [parse_def $def_file]
    set ncomps [lindex $def_res 0]
    set x_max  [lindex $def_res 1]
    set y_max  [lindex $def_res 2]
    set component_text_list [lindex $def_res 3]
    set title  [lindex $def_res 4]
    plot_components $canvas_n CELLS $component_text_list
    wm title . "DESIGN: $title"
}
