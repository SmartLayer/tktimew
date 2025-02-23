#!/usr/bin/env wish8.6
# Work Log Tracker – Tcl/Tk (wish 8.6) version
# This sample implements a work log GUI using Ttk::treeview.
# It loads tasks from a data file (formatted like timew files),
# allows keyboard navigation and editing, and writes changes instantly.

package require Tk
package require Ttk

#------------------------------------------------------------
# Global Variables & File Paths
#------------------------------------------------------------
set dataDir "$env(HOME)/.local/share/timewarrior/data"
set dataFile "$dataDir/2025-02.data"
# tasksList is a list of dictionaries; each dict has keys:
#   start: UTC time string in format YYYYMMDDTHHMMSSZ
#   end:   UTC time string or empty if ongoing
#   desc:  Task description
set tasksList {}

#------------------------------------------------------------
# Utility Procedures
#------------------------------------------------------------
# Convert a UTC string from file to a local display string (ISO8601: yyyy-mm-dd HH:MM)
proc format_time {utc} {
    # remove trailing "Z"
    set utc [string trimright $utc "Z"]
    set year [string range $utc 0 3]
    set month [string range $utc 4 5]
    set day [string range $utc 6 7]
    set hour [string range $utc 9 10]
    set minute [string range $utc 11 12]
    return "$year-$month-$day $hour:$minute"
}

# Get current UTC time in the same format as the file (e.g. 20250223T094228Z)
proc now_utc {} {
    return [clock format [clock seconds] -format "%Y%m%dT%H%M%SZ" -gmt 1]
}

#------------------------------------------------------------
# File I/O: Loading & Saving Tasks
#------------------------------------------------------------
proc load_tasks {} {
    global dataFile tasksList
    set tasksList {}
    if {[file exists $dataFile]} {
        set fh [open $dataFile r]
        while {[gets $fh line] >= 0} {
            # Expect lines like:
            #   inc 20250223T094228Z - 20250223T094302Z # "wiki edits"
            #   inc 20250223T094647Z # "Proofread documentation"
            if {[regexp {inc\s+(\d{8}T\d{6}Z)(?:\s*-\s*(\d{8}T\d{6}Z))?\s+#\s+"(.*)"} $line -> start end desc]} {
                set task [dict create start $start end $end desc $desc]
                lappend tasksList $task
            }
        }
        close $fh
    }
}

proc save_tasks {} {
    global dataFile tasksList
    # Ensure data directory exists
    if {![file isdirectory [file dirname $dataFile]]} {
        file mkdir [file dirname $dataFile]
    }
    set fh [open $dataFile w]
    foreach task $tasksList {
        dict with task {
            if {$end eq ""} {
                puts $fh "inc $start # \"$desc\""
            } else {
                puts $fh "inc $start - $end # \"$desc\""
            }
        }
    }
    close $fh
}

#------------------------------------------------------------
# Main Window & Treeview Setup
#------------------------------------------------------------
wm title . "Work Log Tracker"

# Increase row height to ensure full visibility of text
ttk::style configure Treeview -rowheight 30

# Create the treeview with three columns.
ttk::treeview .tv -columns {start end desc} -show headings -selectmode browse
.tv heading start -text "Start Time"
.tv heading end -text "End Time"
.tv heading desc -text "Task Description"
.tv column start -width 120 -anchor center
.tv column end   -width 120 -anchor center
.tv column desc  -width 300 -anchor w

pack .tv -fill both -expand 1

#------------------------------------------------------------
# Refreshing the Treeview from tasksList
#------------------------------------------------------------
proc refresh_treeview {} {
    global tasksList .tv
    # Remove existing items
    foreach child [.tv children {}] {
        .tv delete $child
    }
    # Insert each task; if end time is empty, show "Ongoing"
    foreach task $tasksList {
        dict with task {
            set start_disp [format_time $start]
            if {$end eq ""} {
                set end_disp "Ongoing"
            } else {
                set end_disp [format_time $end]
            }
            .tv insert "" end -values [list $start_disp $end_disp $desc]
        }
    }
}

#------------------------------------------------------------
# Task Editing & Updates
#------------------------------------------------------------
# When a user double-clicks the description cell, start editing.
proc edit_cell {} {
    global .tv tasksList
    set sel [.tv selection]
    if {[llength $sel] == 0} return
    set item [lindex $sel 0]
    # For simplicity, we only allow editing the "Task Description" (third column).
    set bbox [.tv bbox $item 2]
    if {[llength $bbox] != 4} return
    set x [lindex $bbox 0]
    set y [lindex $bbox 1]
    set w [lindex $bbox 2]
    set h [lindex $bbox 3]
    # Create an entry widget over the cell.
    ttk::entry .edit -width 30
    place .edit -x $x -y $y -width $w -height $h
    .edit focus
    set current_val [lindex [.tv item $item -values] 2]
    .edit insert 0 $current_val
    bind .edit <Return> [list finish_edit $item]
    bind .edit <Escape> {destroy .edit}
}

proc finish_edit {item} {
    global .tv tasksList
    set newval [.edit get]
    destroy .edit
    # Determine which task in tasksList corresponds to the item.
    set idx [.tv index $item]
    set task [lindex $tasksList $idx]
    dict with task {
        set desc $newval
    }
    set tasksList [lreplace $tasksList $idx $idx $task]
    save_tasks
    refresh_treeview
}

bind .tv <Double-1> edit_cell

# End an ongoing task when the End Time cell is clicked.
proc end_task {item} {
    global tasksList .tv
    set idx [.tv index $item]
    set task [lindex $tasksList $idx]
    dict with task {
        if {$end eq ""} {
            set end [now_utc]
        }
    }
    set tasksList [lreplace $tasksList $idx $idx $task]
    save_tasks
    refresh_treeview
}

# Handle single-click events: if the click is in the End Time column and the task is ongoing, end it.
# Now the procedure accepts variable arguments and uses both x and y coordinates.
proc treeview_click {args} {
    global .tv
    set x [expr {[winfo pointerx .] - [winfo rootx .tv]}]
    set y [expr {[winfo pointery .] - [winfo rooty .tv]}]
    set item [.tv identify row $x $y]
    set col  [.tv identify column $x $y]
    # In our treeview the columns are numbered "#1" (Start), "#2" (End), "#3" (Description).
    if {$item ne "" && $col eq "#2"} {
        set vals [.tv item $item -values]
        if {[lindex $vals 1] eq "Ongoing"} {
            end_task $item
        }
    }
}
bind .tv <Button-1> treeview_click

#------------------------------------------------------------
# Keyboard Navigation & New Task Creation
#------------------------------------------------------------
# Up/Down arrow: change selection.
bind .tv <Up> {
    set sel [.tv selection]
    if {[llength $sel] > 0} {
        set item [lindex $sel 0]
        set prev [.tv prev $item]
        if {$prev ne ""} {
            .tv selection clear
            .tv selection add $prev
            .tv see $prev
        }
    }
}
bind .tv <Down> {
    set sel [.tv selection]
    if {[llength $sel] > 0} {
        set item [lindex $sel 0]
        set next [.tv next $item]
        if {$next ne ""} {
            .tv selection clear
            .tv selection add $next
            .tv see $next
        }
    }
}
# Home and End keys jump to first and last items.
bind .tv <Home> {
    set children [.tv children {}]
    if {[llength $children] > 0} {
        .tv selection clear
        .tv selection add [lindex $children 0]
        .tv see [lindex $children 0]
    }
}
bind .tv <End> {
    set children [.tv children {}]
    if {[llength $children] > 0} {
        set last [lindex $children end]
        .tv selection clear
        .tv selection add $last
        .tv see $last
    }
}
# When Tab is pressed on the last row, create a new task.
proc on_tab {} {
    global tasksList .tv
    set children [.tv children {}]
    if {[llength $children] > 0} {
        set sel [.tv selection]
        if {[lindex $sel 0] eq [lindex $children end]} {
            # End any open task if necessary (here we assume only one open task is allowed).
            foreach task $tasksList {
                dict with task {
                    if {$end eq ""} {
                        set end [now_utc]
                    }
                }
            }
            # Create a new task with the current time as start and an empty description.
            set newTask [dict create start [now_utc] end "" desc ""]
            lappend tasksList $newTask
            save_tasks
            refresh_treeview
            # Select the new row and initiate editing of description.
            set items [.tv children {}]
            .tv selection clear
            .tv selection add [lindex $items end]
            edit_cell
        }
    }
}
bind .tv <Tab> on_tab

#------------------------------------------------------------
# Context Menu: Continue a Task
#------------------------------------------------------------
proc show_context_menu {x y} {
    set item [.tv identify row $x $y]
    if {$item eq ""} return
    menu .popup -tearoff 0
    .popup add command -label "Continue This" -command [list continue_task $item]
    .popup post $x $y
}

proc continue_task {item} {
    global tasksList .tv
    set idx [.tv index $item]
    set task [lindex $tasksList $idx]
    dict with task {
        # Create a new task with the same description.
        set newTask [dict create start [now_utc] end "" desc $desc]
        lappend tasksList $newTask
    }
    save_tasks
    refresh_treeview
}
bind .tv <Button-3> {
    set x %X; set y %Y; show_context_menu $x $y
}

#------------------------------------------------------------
# Exit Behavior: Ctrl+Q quits (with a check for active edits)
#------------------------------------------------------------
bind . <Control-q> {
    if {[winfo exists .edit]} {
        if {[tk_messageBox -message "You are editing a task. Save changes?" -type yesno -icon question] eq "yes"} {
            focus .tv
        } else {
            destroy .edit
        }
    }
    exit
}

#------------------------------------------------------------
# Initialization: Load tasks and refresh the UI
#------------------------------------------------------------
load_tasks
refresh_treeview

# Start the Tk event loop.
tkwait window .
