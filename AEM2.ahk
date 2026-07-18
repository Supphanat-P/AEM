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
SetDefaultMouseSpeed, 20   ; makes ALL mouse movement (incl. plain Click) glide instead of teleporting

Running := false
IsRecording := false
TotalRounds := 0
LastActionTime := 0
Steps := []                          ; real array of step objects (fixes pseudo-array bugs)
TargetWinExe := ""                   ; process name of the window we recorded against
TargetWinTitle := ""                 ; title of that window (fallback matching)
SettingsFile := A_ScriptDir "\macro_tool_settings.ini"   ; remembers last folder used, nothing else
IniRead, LastMacroDir, %SettingsFile%, Config, LastDir, %A_ScriptDir%

; Keys that can be recorded (extend/shrink as needed).
; NOTE: F1-F4 and "j" are excluded because they are already used to control the tool itself.
RecordKeys := "1,2,3,4,5,6,7,8,9,0"
    . ",Numpad1,Numpad2,Numpad3,Numpad4,Numpad5,Numpad6,Numpad7,Numpad8,Numpad9,Numpad0"
    . ",a,b,c,d,e,f,g,h,i,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z"
    . ",Space,Enter,Escape,Tab,Backspace,Delete"
    . ",Up,Down,Left,Right"
    . ",F5,F6,F7,F8,F9,F10,F11,F12"

; ===== GUI =====
Gui, +AlwaysOnTop +ToolWindow -MaximizeBox -MinimizeBox +HwndToolHwnd
Gui, Font, s10, Segoe UI
Gui, Add, Text, w260 Center vStatus, Status : Stopped
Gui, Add, Text, w260 Center vAction, Action : Waiting...
Gui, Add, Text, w260 Center vRoundCount, Completed : 0 Rounds
Gui, Add, Text, w260 Center vRecStatus, Recorded Steps : 0
Gui, Add, Text, w260 Center vTargetWinText, Target Window : (none)

; Bot Controls
Gui, Add, Button, x10 w120 h35 gStartScript, Start (F3)
Gui, Add, Button, x+20 w120 h35 gStopScript, Stop (F4)

; Recorder Controls
Gui, Add, Button, x10 y165 w120 h30 gStartRecord, Record (F1)
Gui, Add, Button, x+20 w120 h30 gStopRecord, Stop Rec (F2)

; Storage Controls
Gui, Add, Button, x10 y200 w120 h30 gSaveMacro, Save Macro
Gui, Add, Button, x+20 w120 h30 gLoadMacro, Load Macro

Gui, Show,, Auto Farm + Macro Storage

; Register Hotkeys (Off by default)
Hotkey, ~*LButton, MouseClicked, Off
Loop, Parse, RecordKeys, `,
    Hotkey, ~*%A_LoopField%, KeyPressed, Off
return

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
        GuiControl,, Status, Status : Running
        SetTimer, MainLoop, -1
    }
return

StopScript:
    Running := false
    GuiControl,, Status, Status : Stopped
    GuiControl,, Action, Action : Stopped
return

; ===== Save / Load Systems (real arrays now) =====
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
        return  ; user cancelled

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
        return  ; user cancelled

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

    GuiControl,, RecStatus, % "Recorded Steps : " Steps.Length()
    SplitPath, ChosenFile, ChosenFileName
    GuiControl,, Action, % "Loaded: " ChosenFileName

    MsgBox, 64, Success, % "Macro successfully loaded! Ready to run. (" Steps.Length() " steps imported)"
return

; ===== TinyTask Recording Logic =====
StartRecord:
    if (!Running and !IsRecording)
    {
        ; Anchor to whatever window is currently active - this should be the game window,
        ; so click focus on the game BEFORE pressing Record.
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
        GuiControl,, Status, Status : RECORDING...
        GuiControl,, Action, Action : Perform your placement now
        GuiControl,, RecStatus, Recorded Steps : 0

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

        GuiControl,, Status, Status : Stopped
        GuiControl,, Action, Action : Record Finished!
    }
return

MouseClicked:
    if (!IsRecording)
        return

    ; Ignore clicks that land on our own tool window (e.g. clicking "Stop Rec" itself)
    MouseGetPos, mx, my, WinUnderMouse
    if (WinUnderMouse = ToolHwnd)
        return

    ; Convert to coordinates relative to the target window (so it survives the window moving)
    WinGetPos, winX, winY,,, ahk_exe %TargetWinExe%
    if (winX = "")
        WinGetPos, winX, winY,,, %TargetWinTitle%
    if (winX = "")
        winX := 0, winY := 0  ; fallback: treat as absolute if window can't be found

    relX := mx - winX
    relY := my - winY

    CurrentTime := A_TickCount
    Delay := CurrentTime - LastActionTime

    Steps.Push({type: "Click", x: relX, y: relY, delay: Delay})

    LastActionTime := CurrentTime
    GuiControl,, RecStatus, % "Recorded Steps : " Steps.Length()
    GuiControl,, Action, % "Last: Click (rel " relX ", " relY ")"
return

KeyPressed:
    if (!IsRecording)
        return
    StringReplace, PressedKey, A_ThisHotkey, ~*
    CurrentTime := A_TickCount
    Delay := CurrentTime - LastActionTime

    Steps.Push({type: "Key", key: PressedKey, delay: Delay})

    LastActionTime := CurrentTime
    GuiControl,, RecStatus, % "Recorded Steps : " Steps.Length()
    GuiControl,, Action, % "Last: Key (" PressedKey ")"
return

; ===== Main Execution Loop =====
MainLoop:
    while (Running)
    {
        RunStage()
        if (Running)
        {
            TotalRounds++
            GuiControl,, RoundCount, Completed : %TotalRounds% Rounds
        }
    }
    GuiControl,, Status, Status : Stopped
return

GuiClose:
ExitApp

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
    GuiControl,, Action, Action : Playing Recorded Macro...

    ; Resolve the target window's CURRENT position once (handles the window having moved)
    WinGetPos, winX, winY,,, ahk_exe %TargetWinExe%
    if (winX = "")
        WinGetPos, winX, winY,,, %TargetWinTitle%
    if (winX = "")
    {
        MsgBox, 48, Warning, % "Target window (" TargetWinExe ") not found! Make sure the game is open, then try again."
        winX := 0, winY := 0  ; fallback: play back as absolute coordinates
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
            MouseMove, %absX%, %absY%   ; no speed given -> uses SetDefaultMouseSpeed (smooth glide)
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

    ; --- 1. Start Handler: wait for Start button, then click it ---
    GuiControl,, Action, Action : Waiting for Start Button
    Loop
    {
        if (!Running) return
        start := FindImage("start.png", 500)
        if (start)
        {
            GuiControl,, Action, Action : Clicking Start Button
            x := start.x + 80
            y := start.y
            Click, %x%, %y%
            Sleep, 500
            break
        }
        Sleep, 500
    }
    x := "", y := ""

    ; --- 2. Play the recorded macro (every move + every idle delay, exactly as recorded) ---
    PlayRecordedSteps()

    ; --- 3. Restage Loop: Here -> Restage ---
    GuiControl,, Action, Action : Waiting for End Screen
    WaitStart := A_TickCount
    Loop
    {
        if (!Running) return
        pos := FindImage("here.png", 500)
        if (pos)
        {
            GuiControl,, Action, Action : Found Here!
            x := pos.x + 70
            y := pos.y
            Click, %x%, %y%
            Sleep, 1000
            break
        }
        if (A_TickCount - WaitStart > 5000)
        {
            GuiControl,, Action, Action : Timeout! Force Clicking Here
            Click, 950, 550
            Sleep, 1000
            break
        }
        Sleep, 200
    }

    GuiControl,, Action, Action : Checking Restage Button
    WaitStart := A_TickCount
    Loop
    {
        if (!Running) return
        restage := FindImage("restage.png", 500)
        if (restage)
        {
            GuiControl,, Action, Action : Found Restage!
            x := restage.x
            y := restage.y
            Click, %x%, %y%
            Sleep, 1000
            break
        }
        if (A_TickCount - WaitStart > 15000)
        {
            GuiControl,, Action, Action : Timeout! Force Clicking Restage Area
            Click, 950, 650
            Sleep, 1000
            break
        }
        Sleep, 200
    }

    ; --- 4. Loading Handler (Cancel Button) ---
    GuiControl,, Action, Action : Loading Stage (Waiting for Cancel)
    Loop
    {
        if (!Running) return
        cancelBtn := FindImage("cancel.png", 500)
        if (!cancelBtn)
            break
        Sleep, 500
    }

    GuiControl,, Action, Action : Stage Loaded! Ready for Next Round
    Sleep, 1000
}

; ===== Hotkeys =====
F1::Gosub, StartRecord
F2::Gosub, StopRecord
F3::Gosub, StartScript
F4::Gosub, StopScript
j::ExitApp
