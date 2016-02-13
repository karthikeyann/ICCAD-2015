#--------------------------------------------------------
#  A simple zoom canvas API
#
#  source: http://wiki.tcl.tk/4844
#--------------------------------------------------------
package require Tk

#--------------------------------------------------------
#
#  zoomMark
#
#  Mark the first (x,y) coordinate for zooming.
#
#--------------------------------------------------------
proc zoomMark {c x y} {
    global zoomArea
    set zoomArea(x0) [$c canvasx $x]
    set zoomArea(y0) [$c canvasy $y]
    $c create rectangle $x $y $x $y -outline black -tag zoomArea
}

#--------------------------------------------------------
#
#  zoomStroke
#
#  Zoom in to the area selected by itemMark and
#  itemStroke.
#
#--------------------------------------------------------
proc zoomStroke {c x y} {
    global zoomArea
    set zoomArea(x1) [$c canvasx $x]
    set zoomArea(y1) [$c canvasy $y]
    $c coords zoomArea $zoomArea(x0) $zoomArea(y0) $zoomArea(x1) $zoomArea(y1)
}

#--------------------------------------------------------
#
#  zoomArea
#
#  Zoom in to the area selected by itemMark and
#  itemStroke.
#
#--------------------------------------------------------
proc zoomArea {c x y} {
    global zoomArea

    #--------------------------------------------------------
    #  Get the final coordinates.
    #  Remove area selection rectangle
    #--------------------------------------------------------
    set zoomArea(x1) [$c canvasx $x]
    set zoomArea(y1) [$c canvasy $y]
    $c delete zoomArea
    wrapped_zoomArea $c $x $y
}
proc wrapped_zoomArea { c x y } {
    global zoomArea

    #--------------------------------------------------------
    #  Check for zero-size area
    #--------------------------------------------------------
    if {($zoomArea(x0)==$zoomArea(x1)) || ($zoomArea(y0)==$zoomArea(y1))} {
        return
    }

    #--------------------------------------------------------
    #  Determine size and center of selected area
    #--------------------------------------------------------
    set areaxlength [expr {abs($zoomArea(x1)-$zoomArea(x0))}]
    set areaylength [expr {abs($zoomArea(y1)-$zoomArea(y0))}]
    set xcenter [expr {($zoomArea(x0)+$zoomArea(x1))/2.0}]
    set ycenter [expr {($zoomArea(y0)+$zoomArea(y1))/2.0}]

    #--------------------------------------------------------
    #  Determine size of current window view
    #  Note that canvas scaling always changes the coordinates
    #  into pixel coordinates, so the size of the current
    #  viewport is always the canvas size in pixels.
    #  Since the canvas may have been resized, ask the
    #  window manager for the canvas dimensions.
    #--------------------------------------------------------
    set winxlength [winfo width $c]
    set winylength [winfo height $c]

    #--------------------------------------------------------
    #  Calculate scale factors, and choose smaller
    #--------------------------------------------------------
    set xscale [expr {double($winxlength)/$areaxlength}]
    set yscale [expr {double($winylength)/$areaylength}]
    if { $xscale > $yscale } {
        set factor $yscale
    } else {
        set factor $xscale
    }

    #--------------------------------------------------------
    #  Perform zoom operation
    #--------------------------------------------------------
    zoom $c $factor $xcenter $ycenter $winxlength $winylength
}


#--------------------------------------------------------
#
#  zoom
#
#  Zoom the canvas view, based on scale factor 
#  and centerpoint and size of new viewport.  
#  If the center point is not provided, zoom 
#  in/out on the current window center point.
#
#  This procedure uses the canvas scale function to
#  change coordinates of all objects in the canvas.
#
#--------------------------------------------------------
proc zoom { canvas factor \
        {xcenter ""} {ycenter ""} \
        {winxlength ""} {winylength ""} } {

    #--------------------------------------------------------
    #  If (xcenter,ycenter) were not supplied,
    #  get the canvas coordinates of the center
    #  of the current view.  Note that canvas
    #  size may have changed, so ask the window 
    #  manager for its size
    #--------------------------------------------------------
    set winxlength [winfo width $canvas]; # Always calculate [ljl]
    set winylength [winfo height $canvas]
    if { [string equal $xcenter ""] } {
        set xcenter [$canvas canvasx [expr {$winxlength/2.0}]]
        set ycenter [$canvas canvasy [expr {$winylength/2.0}]]
    }

    #--------------------------------------------------------
    #  Scale all objects in the canvas
    #  Adjust our viewport center point
    #--------------------------------------------------------
    $canvas scale all 0 0 $factor $factor
    set xcenter [expr {$xcenter * $factor}]
    set ycenter [expr {$ycenter * $factor}]

    #--------------------------------------------------------
    #  Get the size of all the items on the canvas.
    #
    #  This is *really easy* using 
    #      $canvas bbox all
    #  but it is also wrong.  Non-scalable canvas
    #  items like text and windows now have a different
    #  relative size when compared to all the lines and
    #  rectangles that were uniformly scaled with the 
    #  [$canvas scale] command.  
    #
    #  It would be better to tag all scalable items,
    #  and make a single call to [bbox].
    #  Instead, we iterate through all canvas items and
    #  their coordinates to compute our own bbox.
    #--------------------------------------------------------
    set x0 1.0e30; set x1 -1.0e30 ;
    set y0 1.0e30; set y1 -1.0e30 ;
    foreach item [$canvas find all] {
        switch -exact [$canvas type $item] {
            "arc" -
            "line" -
            "oval" -
            "polygon" -
            "rectangle" {
                set coords [$canvas coords $item]
                foreach {x y} $coords {
                    if { $x < $x0 } {set x0 $x}
                    if { $x > $x1 } {set x1 $x}
                    if { $y < $y0 } {set y0 $y}
                    if { $y > $y0 } {set y1 $y}
                }
            }
        }
    }

    #--------------------------------------------------------
    #  Now figure the size of the bounding box
    #--------------------------------------------------------
    set xlength [expr {$x1-$x0}]
    set ylength [expr {$y1-$y0}]

    #--------------------------------------------------------
    #  But ... if we set the scrollregion and xview/yview 
    #  based on only the scalable items, then it is not 
    #  possible to zoom in on one of the non-scalable items
    #  that is outside of the boundary of the scalable items.
    #
    #  So expand the [bbox] of scaled items until it is
    #  larger than [bbox all], but do so uniformly.
    #--------------------------------------------------------
    foreach {ax0 ay0 ax1 ay1} [$canvas bbox all] {break}

    while { ($ax0<$x0) || ($ay0<$y0) || ($ax1>$x1) || ($ay1>$y1) } {
        # triple the scalable area size
        set x0 [expr {$x0-$xlength}]
        set x1 [expr {$x1+$xlength}]
        set y0 [expr {$y0-$ylength}]
        set y1 [expr {$y1+$ylength}]
        set xlength [expr {$xlength*3.0}]
        set ylength [expr {$ylength*3.0}]
    }

    #--------------------------------------------------------
    #  Now that we've finally got a region defined with
    #  the proper aspect ratio (of only the scalable items)
    #  but large enough to include all items, we can compute
    #  the xview/yview fractions and set our new viewport
    #  correctly.
    #--------------------------------------------------------
    set newxleft [expr {($xcenter-$x0-($winxlength/2.0))/$xlength}]
    set newytop  [expr {($ycenter-$y0-($winylength/2.0))/$ylength}]
    $canvas configure -scrollregion [list $x0 $y0 $x1 $y1]
    $canvas xview moveto $newxleft 
    $canvas yview moveto $newytop 

    #--------------------------------------------------------
    #  Change the scroll region one last time, to fit the
    #  items on the canvas.
    #--------------------------------------------------------
    $canvas configure -scrollregion [$canvas bbox all]
}

#zooms all components in the canvas
proc zoom_fit { c x y } {
    global zoomArea
    update
    $c addtag blah all
    set bbox [$c bbox blah]
    set zoomArea(x0) [lindex $bbox 0]
    set zoomArea(y0) [lindex $bbox 1]
    set zoomArea(x1) [lindex $bbox 2]
    set zoomArea(y1) [lindex $bbox 3]
    wrapped_zoomArea $c $x $y
}
