#NoEnv
#SingleInstance Force
#Persistent
#MaxThreadsPerHotkey 1
#KeyHistory 100
ListLines Off
SetBatchLines, -1
CoordMode, Pixel, Screen
CoordMode, Mouse, Screen
Process, Priority,, High

SendMode Event
SetKeyDelay, -1
SetMouseDelay, 10
SetWinDelay, -1
SetControlDelay, -1
SetDefaultMouseSpeed, 20 ; Makes ALL mouse movement glide instead of teleporting

Running := false
IsRecording := false
TotalRounds := 0
LastActionTime := 0
Steps := [] ; Real array of step objects
TargetWinExe := "" ; Process name of the window we recorded against
TargetWinTitle := "" ; Title of that window (fallback matching)
SettingsFile := A_ScriptDir "\macro_tool_settings.ini" ; Remembers last folder used
IniRead, LastMacroDir, %SettingsFile%, Config, LastDir, %A_ScriptDir%

; Keys that can be recorded
RecordKeys := "1,2,3,4,5,6,7,8,9,0"
. ",Numpad1,Numpad2,Numpad3,Numpad4,Numpad5,Numpad6,Numpad7,Numpad8,Numpad9,Numpad0"
. ",a,b,c,d,e,f,g,h,i,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z"
. ",Space,Enter,Escape,Tab,Backspace,Delete"
. ",Up,Down,Left,Right"
. ",F5,F6,F7,F8,F9,F10,F11,F12"

; Window Dimensions
GuiW := 280
GuiH := 340
CornerRadius := 16

; ----- RENDER BLANK WINDOW WITH ROUNDED CORNERS -----
Gui, +AlwaysOnTop -MaximizeBox -MinimizeBox -Caption +LastFound +HwndToolHwnd
Gui, Color, 0F1115 ; Nordic Slate Background
WinSet, Region, 0-0 W%GuiW% H%GuiH% R%CornerRadius%-%CornerRadius%

; ----- MODERN HEADER BAR (Allows window dragging) -----
Gui, Font, s10 Bold c8A909E q5, Segoe UI
Gui, Add, Text, x0 y0 w%GuiW% h45 +0x200 Center gWM_LBUTTONDOWN, AUTO FARM ENGINE

; ----- MINIMALIST STATUS MONITOR -----
Gui, Font, s8 Normal c5A606E q5, Segoe UI
Gui, Add, Text, x20 y55 w75, STATUS
Gui, Add, Text, x115 y55 w75, ACTION
Gui, Add, Text, x210 y55 w50, LOOPS

Gui, Font, s10 Bold cFFFFFF q5
Gui, Add, Text, x20 y72 w85 vStatus, Stopped
Gui, Font, s9 Bold cFFB86C q5
Gui, Add, Text, x115 y72 w85 vAction, Waiting...
Gui, Font, s10 Bold cFFFFFF q5
Gui, Add, Text, x210 y72 w50 vRoundCount, 0

; ----- INTERACTIVE CONTROLS -----
Gui, Font, s9 Bold cDFE2E8 q5

; Bot Controls
Gui, Add, Text, x20 y115 w115 h35 Center +Background20232A +0x200 vBtnStart gStartScript, Start (F3)
Gui, Add, Text, x145 y115 w115 h35 Center +Background20232A +0x200 vBtnStop gStopScript, Stop (F4)

; Recorder Controls
Gui, Add, Text, x20 y165 w115 h35 Center +Background20232A +0x200 vBtnRec gStartRecord, Record (F1)
Gui, Add, Text, x145 y165 w115 h35 Center +Background20232A +0x200 vBtnStopRec gStopRecord, Stop Rec (F2)

; Storage Controls
Gui, Add, Text, x20 y215 w115 h35 Center +Background20232A +0x200 vBtnSave gSaveMacro, Save Macro
Gui, Add, Text, x145 y215 w115 h35 Center +Background20232A +0x200 vBtnLoad gLoadMacro, Load Macro

; Footer Info Display
Gui, Font, s8 Normal c444B59 q5
Gui, Add, Text, x20 y270 w240 Center vRecStatus, Recorded Steps: 0
Gui, Add, Text, x20 y290 w240 Center vTargetWinText, Target Window: (none)
Gui, Add, Text, x20 y312 w240 Center, [ Press 'J' to Close Tool ]

Gui, Show, w%GuiW% h%GuiH%, MinimalistMacro

; Register Hotkey Handlers (Off by default)
OnMessage(0x200, "WM_MOUSEMOVE")
Hotkey, ~*LButton, MouseClicked, Off
Loop, Parse, RecordKeys, `,
    Hotkey, ~*%A_LoopField%, KeyPressed, Off
return

; ===== Frameless Dragging and Hover Engine =====
WM_LBUTTONDOWN() {
    PostMessage, 0xA1, 2,,, A
}

WM_MOUSEMOVE(wParam, lParam, msg, hwnd) {
    global ToolHwnd
    static HoveredHwnd := 0
    MouseGetPos,,,, CurrCtrlHwnd, 2
    if (CurrCtrlHwnd = HoveredHwnd)
        return
    if (HoveredHwnd) {
        GuiControl, +Background20232A, %HoveredHwnd%
        GuiControl, +cDFE2E8, %HoveredHwnd%
        GuiControl, Hide, %HoveredHwnd%
        GuiControl, Show, %HoveredHwnd%
    }
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

; ===== Bot Control Logic =====
StartScript:
    if (!Running and !IsRecording)
    {
        if (Steps.Length() = 0)
        {
            MsgBox, 48, Warning, Macro data not found! Please record placement steps (Record) or load an existing file (Load Macro) before starting.
            return
        }
        Running := true
        GuiControl,, Status, Running
        SetTimer, MainLoop, -1
    }
return

StopScript:
    Running := false
    GuiControl,, Status, Stopped
    GuiControl,, Action, Stopped
return

; ===== Save / Load Systems =====
SaveMacro:
    if (IsRecording or Running)
        return
    if (Steps.Length() = 0)
    {
        MsgBox, 48, Error, No macro data available. Please record your actions before saving!
        return
    }

    FileSelectFile, ChosenFile, S16, %LastMacroDir%\macro.ini, Save Macro As, Macro Files (*.ini)
    if (ChosenFile = "")
        return

    if !(SubStr(ChosenFile, -3) = ".ini")
        ChosenFile .= ".ini"

    SplitPath, ChosenFile,, LastMacroDir
    IniWrite, %LastMacroDir%, %SettingsFile%, Config, LastDir

    FileDelete, %ChosenFile%
    IniWrite, % Steps.Length(), %ChosenFile%, Config, TotalSteps
    IniWrite, %TargetWinExe%, %ChosenFile%, Config, TargetWinExe
    IniWrite, %TargetWinTitle%, %ChosenFile%, Config, TargetWinTitle

    Loop, % Steps.Length()
    {
        s := Steps[A_Index]
        IniWrite, % s.type, %ChosenFile%, Step_%A_Index%, Type
        IniWrite, % s.delay, %ChosenFile%, Step_%A_Index%, Delay

        if (s.type = "Click")
        {
            IniWrite, % s.x, %ChosenFile%, Step_%A_Index%, X
            IniWrite, % s.y, %ChosenFile%, Step_%A_Index%, Y
        }
        else if (s.type = "Key")
        {
            IniWrite, % s.key, %ChosenFile%, Step_%A_Index%, Key
        }
    }
    SplitPath, ChosenFile, ChosenFileName
    MsgBox, 64, Success, % "Macro successfully saved as """ ChosenFileName """! (" Steps.Length() " steps total)"
return

LoadMacro:
    if (IsRecording or Running)
        return

    FileSelectFile, ChosenFile, 1, %LastMacroDir%, Select Macro File to Load, Macro Files (*.ini)
    if (ChosenFile = "")
        return

    SplitPath, ChosenFile,, LastMacroDir
    IniWrite, %LastMacroDir%, %SettingsFile%, Config, LastDir

    IniRead, LoadedCount, %ChosenFile%, Config, TotalSteps, 0
    if (LoadedCount = 0)
    {
        MsgBox, 48, Error, The selected file is empty or not a valid macro file.
        return
    }

    IniRead, TargetWinExe, %ChosenFile%, Config, TargetWinExe,
    IniRead, TargetWinTitle, %ChosenFile%, Config, TargetWinTitle,
    GuiControl,, TargetWinText, % "Target Window : " (TargetWinExe = "" ? "(none)" : TargetWinExe)

    Steps := []
    Loop, %LoadedCount%
    {
        IniRead, type, %ChosenFile%, Step_%A_Index%, Type
        IniRead, delay, %ChosenFile%, Step_%A_Index%, Delay

        step := {type: type, delay: delay}

        if (type = "Click")
        {
            IniRead, x, %ChosenFile%, Step_%A_Index%, X
            IniRead, y, %ChosenFile%, Step_%A_Index%, Y
            step.x := x
            step.y := y
        }
        else if (type = "Key")
        {
            IniRead, key, %ChosenFile%, Step_%A_Index%, Key
            step.key := key
        }

        Steps.Push(step)
    }

    GuiControl,, RecStatus, % "Recorded Steps: " Steps.Length()
    SplitPath, ChosenFile, ChosenFileName
    GuiControl,, Action, % "Loaded: " ChosenFileName

    MsgBox, 64, Success, % "Macro successfully loaded! Ready to run. (" Steps.Length() " steps imported)"
return

; ===== TinyTask Recording Logic =====
StartRecord:
    if (!Running and !IsRecording)
    {
        WinGetTitle, ActiveTitle, A
        WinGet, ActiveExe, ProcessName, A
        if (ActiveExe = "" or WinActive("ahk_id " ToolHwnd))
        {
            MsgBox, 48, Warning, Click on your game window first (to give it focus)`, then press Record again.
            return
        }
        TargetWinExe := ActiveExe
        TargetWinTitle := ActiveTitle
        GuiControl,, TargetWinText, % "Target Window : " TargetWinExe

        IsRecording := true
        Steps := []
        GuiControl,, Status, RECORDING...
        GuiControl,, Action, Recording...
        GuiControl,, RecStatus, Recorded Steps: 0

        Hotkey, ~*LButton, On
        Loop, Parse, RecordKeys, `,
            Hotkey, ~*%A_LoopField%, On

        LastActionTime := A_TickCount
    }
return

StopRecord:
    if (IsRecording)
    {
        IsRecording := false
        Hotkey, ~*LButton, Off
        Loop, Parse, RecordKeys, `,
            Hotkey, ~*%A_LoopField%, Off

        GuiControl,, Status, Stopped
        GuiControl,, Action, Rec Finished!
    }
return

MouseClicked:
    if (!IsRecording)
        return

    MouseGetPos, mx, my, WinUnderMouse
    if (WinUnderMouse = ToolHwnd)
        return

    WinGetPos, winX, winY,,, ahk_exe %TargetWinExe%
    if (winX = "")
        WinGetPos, winX, winY,,, %TargetWinTitle%
    if (winX = "")
        winX := 0, winY := 0

    relX := mx - winX
    relY := my - winY

    CurrentTime := A_TickCount
    Delay := CurrentTime - LastActionTime

    Steps.Push({type: "Click", x: relX, y: relY, delay: Delay})

    LastActionTime := CurrentTime
    GuiControl,, RecStatus, % "Recorded Steps: " Steps.Length()
    GuiControl,, Action, % "Click (" relX "," relY ")"
return

KeyPressed:
    if (!IsRecording)
        return
    StringReplace, PressedKey, A_ThisHotkey, ~*
    CurrentTime := A_TickCount
    Delay := CurrentTime - LastActionTime

    Steps.Push({type: "Key", key: PressedKey, delay: Delay})

    LastActionTime := CurrentTime
    GuiControl,, RecStatus, % "Recorded Steps: " Steps.Length()
    GuiControl,, Action, % "Key (" PressedKey ")"
return

; ===== Main Execution Loop =====
MainLoop:
    while (Running)
    {
        RunStage()
        if (Running)
        {
            TotalRounds++
            GuiControl,, RoundCount, %TotalRounds%
        }
    }
    GuiControl,, Status, Stopped
return

FindImage(image, timeout := 300)
{
    start := A_TickCount
    Loop
    {
        ImageSearch, x, y, 0, 0, %A_ScreenWidth%, %A_ScreenHeight%, *30 %image%
        if (!ErrorLevel)
            return {x:x, y:y}
        if (A_TickCount - start > timeout)
            return false
        Sleep, 50
    }
}

PlayRecordedSteps()
{
    global Steps, Running, TargetWinExe, TargetWinTitle
    GuiControl,, Action, Playing...

    WinGetPos, winX, winY,,, ahk_exe %TargetWinExe%
    if (winX = "")
        WinGetPos, winX, winY,,, %TargetWinTitle%
    if (winX = "")
    {
        MsgBox, 48, Warning, % "Target window (" TargetWinExe ") not found! Using absolute fallback coordinates."
        winX := 0, winY := 0
    }

    Loop, % Steps.Length()
    {
        if (!Running)
            return

        s := Steps[A_Index]
        WaitTime := s.delay < 50 ? 50 : s.delay
        Sleep, %WaitTime%

        if (s.type = "Click")
        {
            absX := winX + s.x
            absY := winY + s.y
            MouseMove, %absX%, %absY%
            Click
        }
        else if (s.type = "Key")
        {
            Send, % s.key
        }
    }
}

RunStage()
{
if (!Running) return

GuiControl,, Action, Wait Start
Loop
{
if (!Running) return
start := FindImage("start.png", 500)
if (start)
{
    GuiControl,, Action, Click Start
    x := start.x + 80
    y := start.y
    Click, %x%, %y%
    Sleep, 500
    break
}
Sleep, 500
}

PlayRecordedSteps()

GuiControl,, Action, Wait End
WaitStart := A_TickCount
Loop
{
if (!Running) return
pos := FindImage("here.png", 500)
if (pos)
{
    GuiControl,, Action, Found Here!
    x := pos.x + 70
    y := pos.y
    Click, %x%, %y%
    Sleep, 1000
    break
}
if (A_TickCount - WaitStart > 5000)
{
    GuiControl,, Action, Timeout Here
    Click, 950, 550
    Sleep, 1000
    break
}
Sleep, 200
}

GuiControl,, Action, Wait Restage
WaitStart := A_TickCount
Loop
{
if (!Running) return
restage := FindImage("restage.png", 500)
if (restage)
{
    GuiControl,, Action, Restaging!
    x := restage.x
    y := restage.y
    Click, %x%, %y%
    Sleep, 1000
    break
}
if (A_TickCount - WaitStart > 15000)
{
    GuiControl,, Action, Timeout Restage
    Click, 950, 650
    Sleep, 1000
    break
}
Sleep, 200
}

GuiControl,, Action, Loading Stage
Loop
{
if (!Running) return
cancelBtn := FindImage("cancel.png", 500)
if (!cancelBtn)
    break
Sleep, 500
}

GuiControl,, Action, Stage Ready
Sleep, 1000
}

; ===== Hotkeys =====
F1::Gosub, StartRecord
F2::Gosub, StopRecord
F3::Gosub, StartScript
F4::Gosub, StopScript

j::
GuiClose:
ExitApp