#Requires AutoHotkey v2.0
#SingleInstance Force

; ==================== 全局变量 ====================
scriptEnabled := true                      ; 脚本初始启用状态
longPressThreshold := 180                  ; 空格长按触发阈值（毫秒）
minHoldTime := 600                         ; 长按最短按住时间（毫秒）
isExecutingSpeed := false                  ; 倍速执行锁
currentSpeed := 1                          ; 当前倍速

; ==================== 启用控制 ====================
IsInPlayer() {
    try {
        title := WinGetTitle("A")
        return title != "小幻影视"
    } catch {
        return false
    }
}

#HotIf WinActive("ahk_exe RodelPlayer.UI.exe") && IsInPlayer()

; 脚本启用/禁用开关
/:: {
    global scriptEnabled
    scriptEnabled := !scriptEnabled
    ShowStatusTip(scriptEnabled ? "脚本已启用" : "脚本已禁用", 
                  "top", 
                  scriptEnabled ? "green" : "red")
}

#HotIf WinActive("ahk_exe RodelPlayer.UI.exe") && IsInPlayer() && scriptEnabled

; ==================== 快捷键自定义 ====================
; ========== 基本控制 ==========
f::Send("{F11}")                           ; f 全屏
a::Send("{Left}")                          ; a 快退
d::Send("{Right}")                         ; d 快进
,::Send("{Down}")                          ; , 降低播放器音量
.::Send("{Up}")                            ; . 增加播放器音量
m::SoundSetMute(-1)                        ; m 系统静音切换
+q::WinClose("A")                          ; Q 关闭播放窗口

q:: {                                      ; q-q 关闭窗口
    if (A_TimeSincePriorHotkey && A_TimeSincePriorHotkey < 750 && A_PriorHotkey == "q") {
        WinClose("A")
    }
}

; ========== 音量和亮度控制 ==========
^+Up::AdjustBrightness(20)                 ; Ctrl+Shift+↑ 增加系统亮度
^+Down::AdjustBrightness(-20)              ; Ctrl+Shift+↓ 减少系统亮度

^!Up::AdjustSystemVolume(2)                ; Ctrl+Alt+↑ 增加系统音量
^!Down::AdjustSystemVolume(-2)             ; Ctrl+Alt+↓ 降低系统音量

WheelUp::SendShiftWheel("Up")              ; 鼠标滚轮向上 增加播放器音量
WheelDown::SendShiftWheel("Down")          ; 鼠标滚轮向下 降低播放器音量

; ========== 播放速度控制 ==========
; 倍速快捷键
w::ToggleSpeed(3)                          ; w 3倍速切换
s::ToggleSpeed(2)                          ; s 2倍速切换
x::AdjustSpeedStep(-1)                     ; x 降低倍速
c::AdjustSpeedStep(1)                      ; c 增加倍速
+Backspace::ResetSpeedState()              ; Shift+Backspace 重置倍速状态

$Space:: {                                 ; 长按空格3倍速
    global isExecutingSpeed
    if (isExecutingSpeed) {
        return
    }
    if (KeyWait("Space", "T" . (longPressThreshold/1000))) {
        Send("{Space}")
    } else {
        isExecutingSpeed := true
        Send("{Right down}")
        startTime := A_TickCount
        KeyWait("Space")
        elapsedTime := A_TickCount - startTime
        
        if (elapsedTime < minHoldTime) {
            Sleep(minHoldTime - elapsedTime)
        }
        Send("{Right up}")
        isExecutingSpeed := false
    }
}

; ==================== 辅助函数 ====================
; 快捷键音量调节
AdjustSystemVolume(delta) {
    try {
        SoundSetVolume(Format("{:+d}", delta))
    } catch {
        ShowStatusTip("音量调节失败", "top", "red")
    }
}

; 滚轮音量调节
SendShiftWheel(direction) {
    Send("{Shift down}{Wheel" . direction . "}{Shift up}")
}

; 倍速调节逻辑
ToggleSpeed(targetSpeed) {
    global isExecutingSpeed, currentSpeed
    if (isExecutingSpeed) {
        return
    }
    
    isExecutingSpeed := true
    
    try {
        Send("{Ctrl down}")
        Sleep(25)
        
        if (currentSpeed != targetSpeed) {
            speedDiff := targetSpeed - currentSpeed
            adjustCount := Abs(speedDiff) * 4
            key := speedDiff > 0 ? "{Up}" : "{Down}"
            
            Loop adjustCount {
                Send(key)
                Sleep(50)
            }
            currentSpeed := targetSpeed
        } else {
            ; 回到1倍速
            adjustCount := (currentSpeed - 1) * 4
            Loop adjustCount {
                Send("{Down}")
                Sleep(50)
            }
            currentSpeed := 1
        }
    } finally {
        Send("{Ctrl up}")
        isExecutingSpeed := false
    }
}

AdjustSpeedStep(direction) {
    global isExecutingSpeed
    if (isExecutingSpeed) {
        return
    }
    
    isExecutingSpeed := true
    
    try {
        Send("{Ctrl down}")
        Sleep(25)
        Send(direction > 0 ? "{Up}" : "{Down}")
        Sleep(25)
    } finally {
        Send("{Ctrl up}")
        isExecutingSpeed := false
    }
}

ResetSpeedState() {
    global currentSpeed, isExecutingSpeed
    currentSpeed := 1
    isExecutingSpeed := false
    ShowStatusTip("倍速状态已重置")
}

; 亮度调节逻辑
AdjustBrightness(delta) {
    current := GetBrightness()
    newLevel := current + delta
    if (newLevel > 100)
        newLevel := 100
    if (newLevel < 0)
        newLevel := 0
    
    if (SetBrightness(newLevel)) {
        ShowStatusTip("亮度: " . newLevel . "%")
    } else {
        ShowStatusTip("亮度调节失败", "top", "red")
    }
}

GetBrightness() {
    try {
        get_brightness_cmd := 'powershell (Get-WmiObject -Namespace root/wmi -Class WmiMonitorBrightness).CurrentBrightness'
        result := StdoutToVar(get_brightness_cmd)
        
        if (result.ExitCode == 0 && result.Output) {
            ; 去除换行符和空格
            cleanOutput := Trim(result.Output, " `t`r`n")
            
            if (cleanOutput != "") {
                brightness := Integer(cleanOutput)
                return brightness
            }
        }
    }
    catch Error as e {
        ; 静默处理错误
    }
    return 50
}

SetBrightness(level) {
    if (level < 0) 
        level := 0
    if (level > 100) 
        level := 100
        
    try {
        set_brightness_cmd := 'powershell (Get-WmiObject -Namespace root/wmi -Class WmiMonitorBrightnessMethods).WmiSetBrightness(1,' . level . ')'
        result := StdoutToVar(set_brightness_cmd)
        
        if (result.ExitCode == 0) {
            ShowStatusTip("亮度: " . level . "%")
            return true
        }
    }
    catch Error as e {
        ; 静默处理错误
    }
    
    return false
}

; ==================== 通用函数 ====================
ShowStatusTip(message, position := "top", color := "", width := 180, height := 60, offX := 32, offY := 11) {
    static guis := Map()
    
    ; 清理旧的提示窗口
    for hwnd, guiObj in guis {
        try guiObj.Destroy()
    }
    guis.Clear()
    
    ; 计算位置
    sw := A_ScreenWidth
    sh := A_ScreenHeight
    x_pos := sw//2 - width//2
    y_pos := position = "bottom" ? sh - sh//7 : sh//7
    
    ; 创建GUI
    statusGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox +LastFound -SysMenu -Caption")
    statusGui.BackColor := "0xF6F6F6"
    
    ; 设置文字颜色
    colorMap := Map("green", "0x008000", "red", "0xFF0000")
    textColor := colorMap.Has(color) ? colorMap[color] : "0x000000"
    
    statusGui.SetFont("s10 c" . textColor, "Microsoft YaHei")
    statusGui.Add("Text", 
        "x-" . offX . " y-" . offY . " w" . (width + 4) . " h" . (height + 2) . 
        " Center +0x200 BackgroundTrans", message)
    
    ; 显示并设置圆角
    statusGui.Show("x" . x_pos . " y" . y_pos . " w" . width . " h" . height . " NoActivate")
    
    hwnd := statusGui.Hwnd
    region := DllCall("Gdi32.dll\CreateRoundRectRgn", 
        "Int", 0, "Int", 0, "Int", width, "Int", height, 
        "Int", 53, "Int", 53, "Ptr")
    DllCall("User32.dll\SetWindowRgn", "Ptr", hwnd, "Ptr", region, "Int", 1)
    
    ; 保存引用并设置定时器
    guis[hwnd] := statusGui
    SetTimer(() => CleanupGui(hwnd, guis), -750)
}

CleanupGui(hwnd, guis) {
    if (guis.Has(hwnd)) {
        try guis[hwnd].Destroy()
        guis.Delete(hwnd)
    }
}

; https://www.autohotkey.com/boards/viewtopic.php?f=83&t=109148&hilit=StdoutToVar
StdoutToVar(sCmd, sDir:="", sEnc:="CP0") {
    ; Create 2 buffer-like objects to wrap the handles to take advantage of the __Delete meta-function.
    oHndStdoutRd := { Ptr: 0, __Delete: delete(this) => DllCall("CloseHandle", "Ptr", this) }
    oHndStdoutWr := { Base: oHndStdoutRd }
    
    If !DllCall( "CreatePipe"
               , "PtrP" , oHndStdoutRd
               , "PtrP" , oHndStdoutWr
               , "Ptr"  , 0
               , "UInt" , 0 )
        Throw OSError(,, "Error creating pipe.")
    If !DllCall( "SetHandleInformation"
               , "Ptr"  , oHndStdoutWr
               , "UInt" , 1
               , "UInt" , 1 )
        Throw OSError(,, "Error setting handle information.")

    PI := Buffer(A_PtrSize == 4 ? 16 : 24,  0)
    SI := Buffer(A_PtrSize == 4 ? 68 : 104, 0)
    NumPut( "UInt", SI.Size,          SI,  0 )
    NumPut( "UInt", 0x100,            SI, A_PtrSize == 4 ? 44 : 60 )
    NumPut( "Ptr",  oHndStdoutWr.Ptr, SI, A_PtrSize == 4 ? 60 : 88 )
    NumPut( "Ptr",  oHndStdoutWr.Ptr, SI, A_PtrSize == 4 ? 64 : 96 )

    If !DllCall( "CreateProcess"
               , "Ptr"  , 0
               , "Str"  , sCmd
               , "Ptr"  , 0
               , "Ptr"  , 0
               , "Int"  , True
               , "UInt" , 0x08000000
               , "Ptr"  , 0
               , "Ptr"  , sDir ? StrPtr(sDir) : 0
               , "Ptr"  , SI
               , "Ptr"  , PI )
        Throw OSError(,, "Error creating process.")

    ; The write pipe must be closed before reading the stdout so we release the object.
    ; The reading pipe will be released automatically on function return.
    oHndStdOutWr := ""

    ; Before reading, we check if the pipe has been written to, so we avoid freezings.
    nAvail := 0, nLen := 0
    While DllCall( "PeekNamedPipe"
                 , "Ptr"   , oHndStdoutRd
                 , "Ptr"   , 0
                 , "UInt"  , 0
                 , "Ptr"   , 0
                 , "UIntP" , &nAvail
                 , "Ptr"   , 0 ) != 0
    {
        ; If the pipe buffer is empty, sleep and continue checking.
        If !nAvail && Sleep(100)
            Continue
        cBuf := Buffer(nAvail+1)
        DllCall( "ReadFile"
               , "Ptr"  , oHndStdoutRd
               , "Ptr"  , cBuf
               , "UInt" , nAvail
               , "PtrP" , &nLen
               , "Ptr"  , 0 )
        sOutput .= StrGet(cBuf, nLen, sEnc)
    }
    
    ; Get the exit code, close all process handles and return the output object.
    DllCall( "GetExitCodeProcess"
           , "Ptr"   , NumGet(PI, 0, "Ptr")
           , "UIntP" , &nExitCode:=0 )
    DllCall( "CloseHandle", "Ptr", NumGet(PI, 0, "Ptr") )
    DllCall( "CloseHandle", "Ptr", NumGet(PI, A_PtrSize, "Ptr") )
    Return { Output: sOutput, ExitCode: nExitCode } 
}