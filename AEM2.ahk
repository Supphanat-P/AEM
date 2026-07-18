#NoEnv
#SingleInstance Force
#Persistent
#MaxThreadsPerHotkey 1
ListLines Off
SetBatchLines, -1
CoordMode, Mouse, Screen

Running := false
IsRecording := false
TotalRounds := 0
Steps := []
TargetWinExe := ""

; Window Dimensons
GuiW := 280
GuiH := 320
CornerRadius := 16   ; Adjust this to change how rounded the window is

; ----- RENDER BLANK WINDOW -----
Gui, +AlwaysOnTop -MaximizeBox -MinimizeBox -Caption +LastFound +HwndToolHwnd
Gui, Color, 0F1115  ; Ultra-dark minimalist background (Nordic slate)

; Apply Rounded Corners (Method 1: Direct Window Clipping)
; W and H define the bounding box; R defines the curve radius.
WinSet, Region, 0-0 W%GuiW% H%GuiH% R%CornerRadius%-%CornerRadius%

; Method 2 (Optional Windows 11 Native Rounding fallback):
; DllCall("dwmapi\DwmSetWindowAttribute", "ptr", ToolHwnd, "int", 33, "int*", 2, "int", 4)

; ----- MODERN COMPACT TOP HEADER -----
Gui, Font, s10 Bold c8A909E q5, Segoe UI
Gui, Add, Text, x0 y0 w%GuiW% h45 +0x200 Center gWM_LBUTTONDOWN, MACRO ENGINE

; ----- MINIMALIST FLAT DASHBOARD STATUS -----
Gui, Font, s8 Normal c5A606E q5, Segoe UI
Gui, Add, Text, x20 y55 w75, STATUS
Gui, Add, Text, x115 y55 w75, ACTION
Gui, Add, Text, x210 y55 w50, LOOPS

Gui, Font, s10 Bold cFFFFFF q5
Gui, Add, Text, x20 y72 w85 vStatus, Idle
Gui, Font, s9 Bold c50FA7B q5
Gui, Add, Text, x115 y72 w85 vAction, Waiting...
Gui, Font, s10 Bold cFFFFFF q5
Gui, Add, Text, x210 y72 w50 vRoundCount, 0

; ----- SLIM ROUNDED BUTTON CONTROLS -----
; To achieve a clean aesthetic, we use plain flat text cells acting as buttons
Gui, Font, s9 Bold cDFE2E8 q5

; Primary Script Toggles
Gui, Add, Text, x20 y115 w115 h35 Center +Background20232A +0x200 vBtnStart gStartScript, Start (F3)
Gui, Add, Text, x145 y115 w115 h35 Center +Background20232A +0x200 vBtnStop gStopScript, Stop (F4)

; Macro Recorder Handles
Gui, Add, Text, x20 y165 w115 h35 Center +Background20232A +0x200 vBtnRec gStartRecord, Record (F1)
Gui, Add, Text, x145 y165 w115 h35 Center +Background20232A +0x200 vBtnStopRec gStopRecord, Stop Rec (F2)

; Storage Operations
Gui, Add, Text, x20 y215 w115 h35 Center +Background20232A +0x200 vBtnSave gSaveMacro, Save
Gui, Add, Text, x145 y215 w115 h35 Center +Background20232A +0x200 vBtnLoad gLoadMacro, Load

; Footer system info
Gui, Font, s8 Normal c444B59 q5
Gui, Add, Text, x20 y275 w240 Center vTargetWinText, Target: (none)
Gui, Add, Text, x20 y292 w240 Center, [ Press 'J' to Close Tool ]

Gui, Show, w%GuiW% h%GuiH%, MinimalistMacro

; Listen for mouse hover states
OnMessage(0x200, "WM_MOUSEMOVE")
return

; ===== Minimalist Window Dragging Engine =====
WM_LBUTTONDOWN() {
    PostMessage, 0xA1, 2,,, A
}

; ===== Interactive Hover Logic =====
WM_MOUSEMOVE(wParam, lParam, msg, hwnd) {
    global ToolHwnd
    static HoveredHwnd := 0
    
    MouseGetPos,,,, CurrCtrlHwnd, 2
    if (CurrCtrlHwnd = HoveredHwnd)
        return
        
    ; Reset element appearance back to default minimalist dark style on leave
    if (HoveredHwnd) {
        GuiControl, +Background20232A, %HoveredHwnd%
        GuiControl, +cDFE2E8, %HoveredHwnd%
        GuiControl, Hide, %HoveredHwnd%
        GuiControl, Show, %HoveredHwnd%
    }
    
    ; Light up elements with clean slate gray focus accents when hovered over
    WinGetClass, ctrlClass, ahk_id %CurrCtrlHwnd%
    if (ctrlClass = "Static" && CurrCtrlHwnd != "" && DllCall("GetParent", "Ptr", CurrCtrlHwnd) = ToolHwnd) {
        GuiControlGet, name, Name, %CurrCtrlHwnd%
        if (InStr(name, "Btn")) {
            GuiControl, +Background303540, %CurrCtrlHwnd%
            GuiControl, +cFFFFFF, %CurrCtrlHwnd%
            HoveredHwnd := CurrCtrlHwnd
        } else {
            HoveredHwnd := 0
        }
    } else {
        HoveredHwnd := 0
    }
}

; ===== Core Stub Controls =====
StartScript:
    GuiControl,, Status, Active
    GuiControl,, Action, Running...
return

StopScript:
    GuiControl,, Status, Idle
    GuiControl,, Action, Stopped
return

StartRecord:
    GuiControl,, Status, Rec...
    GuiControl,, Action, Tracking input
return

StopRecord:
    GuiControl,, Status, Idle
    GuiControl,, Action, Rec Saved
return

SaveMacro:
    MsgBox, 64, Minimalist UI, Save triggered!
return

LoadMacro:
    MsgBox, 64, Minimalist UI, Load triggered!
return

j::
GuiClose:
ExitApp