# Work Log Software Requirements Document

## Introduction

This document outlines the requirements for a work log software that enables users to track their daily tasks efficiently. The software should allow users to create logs with timestamps, track their working time, and save logs for later analysis. The application must be user-friendly and run on Ubuntu with a graphical user interface (GUI).

## Objectives

- Enable users to create timestamped log entries easily.
- Track the duration of work sessions.
- Allow users to clock in and out of tasks.
- Automatically save logs to a structured file format for analysis.
- Provide a simple and intuitive GUI for usability.

## File Format

The software should use timew (TimeWorrior) files and stay compatible with it.

```
~/.local/share/timewarrior/data$ timew start 'wiki edits'
Note: '"wiki edits"' is a new tag.
Tracking "wiki edits"
  Started 2025-02-23T12:42:28
  Current                  28
  Total               0:00:00
~/.local/share/timewarrior/data$ cat 2025-02.data
inc 20250223T094228Z # "wiki edits"
~/.local/share/timewarrior/data$ timew stop
Recorded "wiki edits"
  Started 2025-02-23T12:42:28
  Ended                 43:02
  Total               0:00:34
~/.local/share/timewarrior/data$ cat 2025-02.data
inc 20250223T094228Z - 20250223T094302Z # "wiki edits"
~/.local/share/timewarrior/data$ timew start "Proofread documentation"
Note: '"Proofread documentation"' is a new tag.
Tracking "Proofread documentation"
  Started 2025-02-23T12:46:47
  Current                  47
  Total               0:00:00
~/.local/share/timewarrior/data$ cat 2025-02.data
inc 20250223T094228Z - 20250223T094302Z # "wiki edits"
inc 20250223T094647Z # "Proofread documentation"
~/.local/share/timewarrior/data$ timew stop
Recorded "Proofread documentation"
  Started 2025-02-23T12:46:47
  Ended                 47:11
  Total               0:00:24
~/.local/share/timewarrior/data$ cat 2025-02.data
inc 20250223T094228Z - 20250223T094302Z # "wiki edits"
inc 20250223T094647Z - 20250223T094711Z # "Proofread documentation"
```

## Usage

When the application launches, it loads all tasks in the file and renders a table. The app is designed to be ready to end any time, and when started again, it knows the context by the data files, just like the timew command-line itself.

## UI Description

The app is written entirely using Tcl and uses ttk over tk.

### **Treeview Layout**

When started, it presents what is in the data file using a `ttk.Treeview`, listing:

- **Start Time**
- **End Time**
- **Task Description**

If a task is still ongoing, it has no end time, and instead of an end time, there is a button labeled **"End"**. If clicked, the task is ended with the current time written in the end location.

### **Keyboard Navigation & Editing**

- The entire UI is built with **keyboard navigation in mind**.
- **Up/Down arrows** move between tasks.
- **Left/Right arrows** move between the fields.
- The currently selected cell is highlighted.
- Pressing **Enter** allows editing of the selected cell (start time, end time, or description).
- Changes are saved instantly.
- Pressing **ESC cancels** an edit, and changes are discarded.
- The **Home** key moves to the first task, and the **End** key moves to the last task.
- **Tab at the last row creates a new row**:
  - The start time is preset to the current time.
  - The end time is replaced with an **"End"** button.
  - The description field is initially empty, allowing the user to type.
  - If a task is still being edited when the app is closed, the user is prompted to **save or discard changes**.

### **Task Creation & Continuation**

- When adding a new task via **Tab**, it starts **automatically**.
- If a user mistakenly ends a task, they **cannot modify** the stop time afterward.
- However, they can **right-click** or click a **"Continue This"** button, which creates a new row with the same task description and starts tracking again.
- If multiple tasks are open simultaneously (without an end time), the app prompts the user to close all but one before creating a new task. If the user tries to start a new task while another is still open, the existing task is ended automatically.

### **File Handling & Auto-Refresh**

- The current state is **instantly written** to the file.
- If `inotify` is available on the system, the app **auto-refreshes** the `Treeview` when the data file is externally modified.
- If `inotify` is not available, the file is only read **once on launch**.

### **Exit Behavior**

- **Ctrl+Q** quits the app.
- If the user is in the middle of editing and clicks elsewhere, the app **confirms and saves** before quitting.

### **Time Format & Localization**

- The app uses a **24-hour format** and follows **ISO8601** (`yyyy-mm-dd HH:MM`).
- It respects **system locale settings**.
- Like `timew`, time is stored in **UTC** and converted to the **user's local time** in the UI.

### **Visual Enhancements**

- **Active tasks** are **highlighted** in the UI for easy identification.
- If a task is currently being tracked, it is visually distinct.

This updated document ensures that the developer has all necessary details to implement the work log software effectively.
