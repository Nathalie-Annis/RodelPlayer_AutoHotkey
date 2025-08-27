#Requires AutoHotkey v2.0
#SingleInstance Force

`::BossKey()                               ; ` 老板键
OnExit (*) => SystemCursor("Show")         ; 脚本退出时确保恢复鼠标光标显示

; ==================== 全局变量 ====================
scriptEnabled := true                      ; 脚本默认启用状态
longPressThreshold := 180                  ; 空格长按倍速触发阈值（毫秒）
minHoldTime := 600                         ; 空格长按倍速最短执行时间（毫秒）

; 以下变量通常无需更改
isExecutingSpeed := false                  ; 倍速调节互斥锁
currentSpeed := 1                          ; 当前倍速
isWindowTopMost := false                   ; 窗口置顶状态
isBossKeyActive := false                   ; 老板键激活状态
playerWindowPos := {}                      ; 播放器窗口位置信息
isWaitingForMouse := false                 ; 是否正在等待鼠标移动

; ==================== 脚本启用界面控制 ====================
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
; 基本控制
f::Send("{F11}")                           ; f 全屏
a::Send("{Left}")                          ; a 快退
d::Send("{Right}")                         ; d 快进
,::Send("{Down}")                          ; , 降低播放器音量
.::Send("{Up}")                            ; . 增加播放器音量
m::SoundSetMute(-1)                        ; m 系统静音切换
t::ToggleWindowTopMost()                   ; t 切换窗口置顶状态
v::ToggleMousePosition()                   ; v 切换控制栏显示
+q::WinClose("A")                          ; Q 关闭播放窗口

q:: {                                      ; q-q 关闭窗口
    if (A_TimeSincePriorHotkey && A_TimeSincePriorHotkey < 750 && A_PriorHotkey == "q") {
        WinClose("A")
    }
}

CapsLock & s::Send("{Down}")               ; CapsLock+S 降低播放器音量
CapsLock & w::Send("{Up}")                 ; CapsLock+W 增加播放器音量

; 播放速度控制
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
; 鼠标位置切换功能
ToggleMousePosition() {
    ; 获取当前鼠标位置和屏幕尺寸
    MouseGetPos(&currentX, &currentY)
    sw := A_ScreenWidth
    sh := A_ScreenHeight

    ; 显示上下两侧控制栏的位置
    topSixthY := sh // 14
    bottomSixthY := sh * 5 // 6
    
    ; 检测当前Y坐标位置并决定移动目标
    if (currentY < topSixthY || currentY >= bottomSixthY) {
        ; 此时已经显示控制栏，应当移动鼠标到屏幕中心，隐藏光标并设置监控
        SystemCursor("Hide")
        MouseMove(sw // 2, sh // 2, 0)
        StartMouseMonitoring()
    } else {
        ; 此时没有显示控制栏
        MouseMove(sw // 2, sh, 0)
    }
}

; 开始鼠标移动监控
StartMouseMonitoring() {
    global isWaitingForMouse
    
    ; 获取当前鼠标位置
    MouseGetPos(&currentMouseX, &currentMouseY)
    isWaitingForMouse := true
    
    ; 启动鼠标移动检测定时器 (50ms间隔检测)，传递保存的鼠标坐标
    SetTimer(() => CheckMouseMove(currentMouseX, currentMouseY), 50)
    
    ; 启动2秒超时定时器，直接调用统一的停止函数
    SetTimer(StopMouseMonitoring, -2000)
}

; 检测鼠标移动
CheckMouseMove(savedMouseX, savedMouseY) {
    global isWaitingForMouse
    
    if (!isWaitingForMouse) {
        SetTimer(() => CheckMouseMove(savedMouseX, savedMouseY), 0)  ; 停止定时器
        return
    }
    
    MouseGetPos(&currentX, &currentY)
    
    ; 检测鼠标是否移动
    if (Abs(currentX - savedMouseX) > 5 || Abs(currentY - savedMouseY) > 5) {
        ; 鼠标移动了，停止所有监控
        StopMouseMonitoring()
    }
}

; 停止鼠标监控的统一函数
StopMouseMonitoring() {
    global isWaitingForMouse
    
    ; 显示光标
    SystemCursor("Show")
    ; 停止监控状态
    isWaitingForMouse := false
    ; 停止所有相关定时器
    ; 注意：由于CheckMouseMove现在是带参数的匿名函数，需要通过设置isWaitingForMouse为false来停止
    ; CheckMouseMove会在下次调用时自动停止定时器
    SetTimer(StopMouseMonitoring, 0)    ; 停止超时定时器
}

; 老板键功能
BossKey() {
    global isBossKeyActive, playerWindowPos
    
    try {
        if (!isBossKeyActive) {
            if (!WinActive("ahk_exe RodelPlayer.UI.exe")) {
                ; 如果不在播放器窗口，发送原始的 ` 键
                SendText("``")
                return
            }
            ; 暂停播放，保存窗口位置和状态
            if (IsInPlayer()) {
                Send("{Space}")
                SoundSetMute(1)
            }
            hwnd := WinGetID("A")
            ; 验证窗口句柄有效性
            if (!hwnd || !WinExist(hwnd)) {
                ShowStatusTip("无法获取有效的播放器窗口", "top", "red")
                return
            }
            WinGetPos(&x, &y, &width, &height, hwnd)
            playerWindowPos := {x: x, y: y, width: width, height: height, hwnd: hwnd}
            Sleep(100)
            ; 隐藏窗口
            WinHide(hwnd)
            isBossKeyActive := true
        } else {
            ; 恢复窗口
            if (playerWindowPos.HasOwnProp("hwnd")) {
                hwnd := playerWindowPos.hwnd
                ; 检查保存的窗口是否仍然存在
                if (!WinExist(hwnd)) {
                    ; 窗口可能已关闭，尝试查找任何播放器窗口
                    hwnd := WinExist("ahk_exe RodelPlayer.UI.exe")
                    if (!hwnd) {
                        ; 没有找到播放器窗口，重置状态
                        isBossKeyActive := false
                        playerWindowPos := {}
                        ShowStatusTip("播放器窗口已关闭", "top", "red")
                        return
                    }
                    ; 找到了其他播放器窗口，更新句柄
                    playerWindowPos.hwnd := hwnd
                }
                ; 显示窗口
                WinShow(hwnd)
                ; 恢复窗口位置，激活窗口
                WinMove(playerWindowPos.x, playerWindowPos.y, 
                       playerWindowPos.width, playerWindowPos.height, hwnd)
                WinActivate(hwnd)
                Sleep(100)
                ; 恢复播放
                if (IsInPlayer()) {
                    Send("{Space}")
                    SoundSetMute(0)
                }
                isBossKeyActive := false
            }
        }
    } catch Error as e {
        isBossKeyActive := false
        ShowStatusTip("老板键操作失败", "top", "red")
    }
}

; 窗口置顶切换
ToggleWindowTopMost() {
    global isWindowTopMost
    try {
        hwnd := WinGetID("A")
        isWindowTopMost := !isWindowTopMost
        
        if (isWindowTopMost) {
            WinSetAlwaysOnTop(1, hwnd)
            ShowStatusTip("窗口已置顶", "top", "green")
        } else {
            WinSetAlwaysOnTop(0, hwnd)
            ShowStatusTip("窗口取消置顶", "top", "")
        }
    } catch Error as e {
        ShowStatusTip("置顶切换失败", "top", "red")
    }
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
    statusGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox +LastFound -SysMenu -Caption +ToolWindow")
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

; https://wyagd001.github.io/v2/docs/lib/DllCall.htm#ExHideCursor
SystemCursor(cmd)  ; cmd = "Show|Hide|Toggle|Reload"
{
    static visible := true, c := Map()
    static sys_cursors := [32512, 32513, 32514, 32515, 32516, 32642
                         , 32643, 32644, 32645, 32646, 32648, 32649, 32650]
    if (cmd = "Reload" or !c.Count)  ; 在请求或首次调用时进行重载.
    {
        for i, id in sys_cursors
        {
            h_cursor  := DllCall("LoadCursor", "Ptr", 0, "Ptr", id)
            h_default := DllCall("CopyImage", "Ptr", h_cursor, "UInt", 2
                , "Int", 0, "Int", 0, "UInt", 0)
            h_blank   := DllCall("CreateCursor", "Ptr", 0, "Int", 0, "Int", 0
                , "Int", 32, "Int", 32
                , "Ptr", Buffer(32*4, 0xFF)
                , "Ptr", Buffer(32*4, 0))
            c[id] := {default: h_default, blank: h_blank}
        }
    }
    switch cmd
    {
      case "Show": visible := true
      case "Hide": visible := false
      case "Toggle": visible := !visible
      default: return
    }
    for id, handles in c
    {
        h_cursor := DllCall("CopyImage"
            , "Ptr", visible ? handles.default : handles.blank
            , "UInt", 2, "Int", 0, "Int", 0, "UInt", 0)
        DllCall("SetSystemCursor", "Ptr", h_cursor, "UInt", id)
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