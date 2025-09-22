#Requires AutoHotkey v2.0
#SingleInstance Force
SetTitleMatchMode 3
OnExit (*) => SystemCursor("Show")          ; 脚本退出时确保恢复鼠标光标显示

`:: BossKey()                               ; ` 老板键

; ==================== 全局变量 ====================
scriptEnabled := true                       ; 脚本默认启用状态
longPressThreshold := 180                   ; 空格长按倍速触发阈值（毫秒）
minHoldTime := 600                          ; 空格长按倍速最短执行时间（毫秒）

; 自绘脚本提示条默认参数 如果显示存在异常请调整以下参数
statusTipPosition := "top"                  ; 状态提示位置 ("top" 或 "bottom")
statusTipWidth := 184                       ; 状态提示窗口宽度
statusTipHeight := 65                       ; 状态提示窗口高度
statusTipOffsetX := 32                      ; 状态提示X轴偏移量 数值越大 文字位置越靠左
statusTipOffsetY := 11                      ; 状态提示Y轴偏移量 数值越大 文字位置越靠上
statusTipDuration := 750                    ; 状态提示显示时长（毫秒）

; 以下变量通常无需更改
isExecutingSpeed := false                   ; 倍速调节互斥锁
currentSpeed := 1                           ; 当前倍速
isWindowTopMost := false                    ; 窗口置顶状态
isBossKeyActive := false                    ; 老板键激活状态
playerWindowPos := {}                       ; 播放器窗口位置信息
isWaitingForMouse := false                  ; 是否正在等待鼠标移动
isInformationMenuActive := false            ; 信息菜单激活状态
isDanmakuActive := true                     ; 弹幕激活状态

; 全局屏幕尺寸变量
sw := A_ScreenWidth                         ; 屏幕宽度
sh := A_ScreenHeight                        ; 屏幕高度

; ==================== 启用控制 ====================
; 主界面启用的快捷键
#HotIf WinActive("小幻影视 ahk_exe RodelPlayer.UI.exe")
/:: {
    Send "{Ctrl down}"
    Sleep 100
    Send "f"
    Sleep 100
    Send "{Ctrl up}"
}

; 播放界面启用的快捷键
#HotIf WinActive("ahk_exe RodelPlayer.UI.exe", , "小幻影视")

; 脚本启用/禁用开关
/:: {
    global scriptEnabled
    scriptEnabled := !scriptEnabled
    ShowStatusTip(scriptEnabled ? "脚本已启用" : "脚本已禁用", , scriptEnabled ? "green" : "red")
}

#HotIf WinActive("ahk_exe RodelPlayer.UI.exe", , "小幻影视") && scriptEnabled

; ==================== 快捷键自定义 ====================
; 基本控制
f:: Send("{F11}")                           ; f 全屏
Enter:: Send("{F11}")                       ; Enter 全屏
a:: SendSeekCommand("{Left}")               ; a 快退
d:: SendSeekCommand("{Right}")              ; d 快进
,:: Send("{Down}")                          ; , 降低播放器音量
.:: Send("{Up}")                            ; . 增加播放器音量
m:: SoundSetMute(-1)                        ; m 系统静音切换
t:: ToggleWindowTopMost()                   ; t 切换窗口置顶状态
v:: ToggleControlBar()                      ; v 控制栏显示/隐藏
u:: OpenPlaylistMenu()                      ; u 打开播放列表
o:: OpenInformationMenu()                   ; i 打开视频信息菜单
p:: OpenVersionMenu()                       ; p 打开版本切换菜单
k:: OpenSubtitleMenu()                      ; k 打开字幕调节菜单
l:: OpenAudioTrackMenu()                    ; l 打开音轨调节菜单
`;:: OpenDanmakuMenu()                      ; ` 打开弹幕调节菜单
+q:: WinClose("A")                          ; Q 关闭播放窗口

q:: {                                       ; q-q 关闭窗口
    if (A_TimeSincePriorHotkey && A_TimeSincePriorHotkey < 750 && A_PriorHotkey == "q") {
        WinClose("A")
    }
}

; 播放速度控制
w:: ToggleSpeed(3)                          ; w 3倍速切换
s:: ToggleSpeed(2)                          ; s 2倍速切换
x:: AdjustSpeedStep(-1)                     ; x 降低倍速
c:: AdjustSpeedStep(1)                      ; c 增加倍速
+Backspace:: ResetSpeedState()              ; Shift+Backspace 重置倍速状态

$Space:: {                                  ; 长按空格3倍速
    global isExecutingSpeed
    if (isExecutingSpeed) {
        return
    }
    if (KeyWait("Space", "T" . (longPressThreshold / 1000))) {
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
; 打开字幕菜单
OpenSubtitleMenu() {
    ; 获取当前活动窗口的工作区位置和大小
    WinGetClientPos(&clientX, &clientY, &clientWidth, &clientHeight, "A")

    ; 基于屏幕尺寸计算固定偏移量（不随窗口大小变化）
    ; 距离右边 269px，距离底部 130px（基于2560x1440的原始坐标）
    rightOffsetRatio := 269 / 2560    ; 距离右边的比例
    bottomOffsetRatio := 130 / 1440   ; 距离底部的比例

    ; 根据屏幕实际大小计算偏移距离
    rightOffset := Round(sw * rightOffsetRatio)
    bottomOffset := Round(sh * bottomOffsetRatio)

    ; 计算目标位置
    targetX := clientWidth - rightOffset
    targetY := clientHeight - bottomOffset

    SystemCursor("Hide")
    ; 移动到目标位置，判断是否存在弹幕占位
    MouseMove(targetX, targetY, 0)
    SystemCursor("Hide")
    Sleep(50)
    if (HasDanmaku()) {
        targetX := targetX - Round(sw * 153 / 2560)
    }

    ; 获取到字幕应在的位置后，判断该位置是否是字幕
    pixelColor := PixelGetColor(targetX, targetY)
    ; 此位置是白色的话说明是倍速按钮，无字幕
    if (pixelColor == 0xFFFFFF) {
        ShowStatusTip("当前视频无字幕", 1000)
    } else {
        MouseMove(targetX, targetY, 0)
        Click()
        ; 按下Tab键
        Send("{Tab}")
    }

    if (IsWindowFullScreen()) {
        ; 移动鼠标到窗口右侧中央
        MouseMove(clientWidth, clientHeight / 2, 0)
    }
    SystemCursor("Show")
}

; 打开音轨菜单
OpenAudioTrackMenu() {
    ; 获取当前活动窗口的工作区位置和大小
    WinGetClientPos(&clientX, &clientY, &clientWidth, &clientHeight, "A")

    ; 基于屏幕尺寸计算固定偏移量（不随窗口大小变化）
    ; 距离右边 200px，距离底部 130px（基于2560x1440的原始坐标）
    rightOffsetRatio := 200 / 2560    ; 距离右边的比例
    bottomOffsetRatio := 130 / 1440   ; 距离底部的比例

    ; 根据屏幕实际大小计算偏移距离
    rightOffset := Round(sw * rightOffsetRatio)
    bottomOffset := Round(sh * bottomOffsetRatio)

    ; 计算目标位置
    targetX := clientWidth - rightOffset
    targetY := clientHeight - bottomOffset

    SystemCursor("Hide")
    ; 移动到目标位置并点击
    MouseMove(targetX, targetY, 0)
    SystemCursor("Hide")
    Sleep(50)
    if (HasDanmaku()) {
        MouseMove(targetX - Round(sw * 153 / 2560), targetY, 0)
    }
    Click()

    ; 按下Tab键
    Send("{Tab}")
    if (IsWindowFullScreen()) {
        ; 移动鼠标到窗口右侧中央
        MouseMove(clientWidth, clientHeight / 2, 0)
    }
    SystemCursor("Show")
}

OpenDanmakuMenu() {
    global isDanmakuActive
    ; 获取当前活动窗口的工作区位置和大小
    WinGetClientPos(&clientX, &clientY, &clientWidth, &clientHeight, "A")

    rightOffsetRatio := 277 / 2560    ; 距离右边的比例
    bottomOffsetRatio := 134 / 1440   ; 距离底部的比例

    ; 根据屏幕实际大小计算偏移距离
    rightOffset := Round(sw * rightOffsetRatio)
    bottomOffset := Round(sh * bottomOffsetRatio)

    ; 计算目标位置
    targetX := clientWidth - rightOffset
    targetY := clientHeight - bottomOffset

    SystemCursor("Hide")
    ; 移动到目标位置并点击
    MouseMove(targetX, targetY, 0)
    SystemCursor("Hide")
    Sleep(50)
    if (HasDanmaku()) {
        Click()
        isDanmakuActive := !isDanmakuActive
        ShowStatusTip(isDanmakuActive ? "已启用弹幕" : "已禁用弹幕", 1000, isDanmakuActive ? "green" : "red")
    } else {
        ShowStatusTip("未匹配弹幕", 1000)
    }

    if (IsWindowFullScreen()) {
        ; 移动鼠标到窗口右侧中央
        MouseMove(clientWidth, clientHeight / 2, 0)
    }
    SystemCursor("Show")
}

OpenPlaylistMenu() {
    ; 检测当前窗口是否全屏
    if (!IsWindowFullScreen()) {
        ShowStatusTip("全屏播放时解锁此功能", 1000, "red", 250, 65, 43, 11, "top")
        return
    }

    SystemCursor("Hide")
    ; 计算目标位置（按比例计算）
    targetX := Round(sw * (1700 / 2560))
    targetY := Round(sh * (36 / 1440))

    ; 移动到目标位置并点击
    MouseMove(targetX, targetY, 0)
    Click()

    ; 按下Tab键
    Send("{Tab}")
    MouseMove(sw, sh / 2, 0)
    SystemCursor("Show")
}

OpenVersionMenu() {
    ; 检测当前窗口是否全屏
    if (!IsWindowFullScreen()) {
        ShowStatusTip("全屏播放时解锁此功能", 1000, "red", 250, 65, 43, 11, "top")
        return
    }

    SystemCursor("Hide")
    ; 计算目标位置（按比例计算）
    targetX := Round(sw * (2070 / 2560))
    targetY := Round(sh * (36 / 1440))

    ; 移动到目标位置并点击
    MouseMove(targetX, targetY, 0)
    Click()

    ; 按下Tab键
    Send("{Tab}")
    MouseMove(sw, sh / 2, 0)
    SystemCursor("Show")
}

OpenInformationMenu() {
    global isInformationMenuActive
    ; 检测当前窗口是否全屏
    if (!IsWindowFullScreen()) {
        ShowStatusTip("全屏播放时解锁此功能", 1000, "red", 250, 65, 43, 11, "top")
        return
    }

    SystemCursor("Hide")
    if (isInformationMenuActive) {
        MouseMove(sw, sh / 2, 0)
        Click()
    } else {
        ; 计算目标位置（按比例计算）
        targetX := Round(sw * (300 / 2560))
        targetY := Round(sh * (1300 / 1440))

        ; 移动到目标位置并点击
        MouseMove(targetX, targetY, 0)
        Click()

        ; 按下Tab键
        Send("{Tab}")
        MouseMove(0, sh, 0)
    }
    SystemCursor("Show")

    isInformationMenuActive := !isInformationMenuActive
}

; 控制栏显示/隐藏切换功能
ToggleControlBar() {
    ; 统一使用屏幕坐标
    CoordMode("Mouse", "Screen")
    MouseGetPos(&sx, &sy)

    ; 取该窗口客户区的屏幕位置与尺寸
    WinGetClientPos(&cx, &cy, &cw, &ch, "A")

    ; 把鼠标从相对坐标系换算到绝对坐标系
    mx := sx - cx
    my := sy - cy

    topBand := sh / 13.7
    bottomBand := sh / 6

    ; 判断控制栏显示状态
    isShowingControlBar :=
        (mx >= 0 && mx <= cw) &&
        ((my >= 0 && my < topBand)
        || (my >= ch - bottomBand && my <= ch))

    if (isShowingControlBar) {
        SystemCursor("Hide")
        centerX := cx + cw / 2
        centerY := cy + 3 * ch / 8
        MouseMove(centerX, centerY, 0)
        StartMouseMonitoring()
    } else {
        if (IsWindowFullScreen()) {
            MouseMove(cx + cw / 2, cy + ch, 0)
        } else {
            MouseMove(cx + cw / 2, cy + ch - sh / 10, 0)
        }
    }
}

; 开始鼠标移动监控
StartMouseMonitoring() {
    global isWaitingForMouse

    isWaitingForMouse := true

    ; 启动鼠标移动检测定时器 (50ms间隔检测)
    SetTimer(CheckMouseMove, 50)

    ; 启动2秒超时定时器
    SetTimer(StopMouseMonitoring, -2000)
}

; 检测鼠标移动
CheckMouseMove() {
    global isWaitingForMouse

    if (!isWaitingForMouse) {
        SetTimer(CheckMouseMove, 0)  ; 停止定时器
        return
    }

    ; 获取当前鼠标位置
    MouseGetPos(&currentX, &currentY)

    ; 获取当前窗口的中心位置
    try {
        WinGetClientPos(&clientX, &clientY, &clientWidth, &clientHeight, "A")
        centerX := clientWidth / 2
        centerY := 3 * clientHeight / 8

        ; 检测鼠标是否离开窗口中心区域（允许一定的容差范围）
        tolerance := 5  ; 容差像素
        if (Abs(currentX - centerX) > tolerance || Abs(currentY - centerY) > tolerance) {
            ; 鼠标移动了，停止所有监控
            StopMouseMonitoring()
        }
    } catch {
        ; 如果获取窗口信息失败，停止监控
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
            ; 如果不在小幻影视App，发送原始的 ` 键
            if (!WinActive("ahk_exe RodelPlayer.UI.exe")) {
                SendText("``")
                return
            }
            ; 如果在播放界面，暂停播放并静音
            if (WinActive("ahk_exe RodelPlayer.UI.exe", , "小幻影视")) {
                Send("{Space}")
                SoundSetMute(1)
            }
            ; 保存窗口位置和状态
            hwnd := WinGetID("A")
            if (!hwnd || !WinExist(hwnd)) {
                ShowStatusTip("无法获取有效的播放器窗口", , "red")
                return
            }
            WinGetPos(&x, &y, &width, &height, hwnd)
            playerWindowPos := { x: x, y: y, width: width, height: height, hwnd: hwnd }
            ; 隐藏窗口
            Sleep(100)
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
                        ShowStatusTip("应用窗口已关闭", , "red")
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
                if (WinActive("ahk_exe RodelPlayer.UI.exe", , "小幻影视")) {
                    Send("{Space}")
                    SoundSetMute(0)
                }
                isBossKeyActive := false
            }
        }
    } catch Error as e {
        isBossKeyActive := false
        ShowStatusTip("老板键操作失败", , "red")
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
            ShowStatusTip("窗口已置顶", , "green")
        } else {
            WinSetAlwaysOnTop(0, hwnd)
            ShowStatusTip("窗口取消置顶", , "")
        }
    } catch Error as e {
        ShowStatusTip("置顶切换失败", , "red")
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
        if (currentSpeed != targetSpeed) {
            speedDiff := targetSpeed - currentSpeed
            adjustCount := Abs(speedDiff) * 4
            key := speedDiff > 0 ? "{Up}" : "{Down}"

            loop adjustCount {
                Sleep(50)
                Send(key)
            }
            currentSpeed := targetSpeed
        } else {
            ; 回到1倍速
            adjustCount := (currentSpeed - 1) * 4
            loop adjustCount {
                Sleep(50)
                Send("{Down}")
            }
            currentSpeed := 1
        }
    } finally {
        Sleep(50)
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
; 检测当前窗口是否存在弹幕
HasDanmaku() {
    try {
        ; 获取当前活动窗口的工作区位置和大小
        WinGetClientPos(&clientX, &clientY, &clientWidth, &clientHeight, "A")

        ; 计算检测位置 2283 1306
        ; 基于屏幕尺寸计算偏移量（277/2560和134/1440的比例）
        offsetXRatio := 277 / 2560
        offsetYRatio1 := 134 / 1440
        offsetYRatio2 := 154 / 1440

        ; 计算实际检测位置
        detectX := clientWidth - Round(sw * offsetXRatio)
        detectY1 := clientHeight - Round(sh * offsetYRatio1)
        detectY2 := clientHeight - Round(sh * offsetYRatio2)

        ; 获取指定位置的颜色
        danColor := PixelGetColor(detectX, detectY1)
        buttonBgColor := PixelGetColor(detectX, detectY2)

        ; 检测是否为文字背景色（白色或黑色，标识“弹”字，黑色的“弹”字要考虑到可能是视频黑边的情况，需要对弹幕按钮阴影颜色做检测）
        return (danColor == 0xFFFFFF || danColor == 0x000000 && buttonBgColor != 0x000000)
    } catch {
        return false
    }
}

; 检测当前窗口是否全屏
IsWindowFullScreen() {
    try {
        WinGetClientPos(&clientX, &clientY, &clientWidth, &clientHeight, "A")

        ; 判断窗口是否全屏（工作区大小等于或接近屏幕大小）
        return (clientWidth >= sw && clientHeight >= sh)
    } catch {
        return false
    }
}

; 检测系统是否为深色模式
IsDarkMode() {
    try {
        ; 读取注册表中的深色模式设置
        regValue := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
            "AppsUseLightTheme")
        return regValue == 0  ; 0表示深色模式，1表示浅色模式
    } catch {
        return false  ; 默认返回浅色模式
    }
}

ShowStatusTip(message, duration := statusTipDuration, color := "", width := statusTipWidth, height := statusTipHeight,
    offX := statusTipOffsetX, offY := statusTipOffsetY, position := statusTipPosition) {
    static guis := Map()

    ; 清理旧的提示窗口
    for hwnd, guiObj in guis {
        try guiObj.Destroy()
    }
    guis.Clear()

    ; 获取当前活动窗口的工作区位置和大小
    WinGetClientPos(&clientX, &clientY, &clientWidth, &clientHeight, "A")

    ; 在窗口工作区内计算提示位置
    x_pos := clientX + (clientWidth - width) / 2

    if (position = "bottom") {
        y_pos := clientY + clientHeight - height - sh / 13.3
    } else {
        ; top position
        y_pos := clientY + sh / 13.3
    }

    ; 确保提示不会超出屏幕边界
    ; 水平边界检查
    if (x_pos < 0) {
        x_pos := 10
    } else if (x_pos + width > sw) {
        x_pos := sw - width - 10
    }

    ; 垂直边界检查
    if (y_pos < 0) {
        y_pos := 10
    } else if (y_pos + height > sh) {
        y_pos := sh - height - 10
    }

    ; 检测深色模式
    isDark := IsDarkMode()

    ; 创建GUI
    statusGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox +LastFound -SysMenu -Caption +ToolWindow")

    ; 根据深色模式设置背景色
    statusGui.BackColor := isDark ? "0x2D2D30" : "0xF6F6F6"

    ; 设置文字颜色
    colorMap := Map("green", "0x008000", "red", "0xFF0000")
    if (color != "" && colorMap.Has(color)) {
        textColor := colorMap[color]
    } else {
        ; 根据深色模式设置默认文字颜色
        textColor := isDark ? "0xFFFFFF" : "0x000000"
    }

    statusGui.SetFont("s10 c" . textColor, "Microsoft YaHei")
    statusGui.Add("Text",
        "x-" . offX . " y-" . offY . " w" . (width + 4) . " h" . (height + 2) .
        " Center +0x200 BackgroundTrans", message)

    ; 显示并设置圆角
    statusGui.Show("x" . x_pos . " y" . y_pos . " w" . width . " h" . height . " NoActivate")

    hwnd := statusGui.Hwnd
    region := DllCall("Gdi32.dll\CreateRoundRectRgn",
        "Int", 0, "Int", 0, "Int", width, "Int", height,
        "Int", 60, "Int", 60, "Ptr")
    DllCall("User32.dll\SetWindowRgn", "Ptr", hwnd, "Ptr", region, "Int", 1)

    ; 保存引用并设置定时器，使用自定义显示时长
    guis[hwnd] := statusGui
    SetTimer(() => CleanupGui(hwnd, guis), -duration)
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
    static sys_cursors := [32512, 32513, 32514, 32515, 32516, 32642, 32643, 32644, 32645, 32646, 32648, 32649, 32650]
    if (cmd = "Reload" or !c.Count)  ; 在请求或首次调用时进行重载.
    {
        for i, id in sys_cursors {
            h_cursor := DllCall("LoadCursor", "Ptr", 0, "Ptr", id)
            h_default := DllCall("CopyImage", "Ptr", h_cursor, "UInt", 2
                , "Int", 0, "Int", 0, "UInt", 0)
            h_blank := DllCall("CreateCursor", "Ptr", 0, "Int", 0, "Int", 0
                , "Int", 32, "Int", 32
                , "Ptr", Buffer(32 * 4, 0xFF)
                , "Ptr", Buffer(32 * 4, 0))
            c[id] := { default: h_default, blank: h_blank }
        }
    }
    switch cmd {
        case "Show": visible := true
        case "Hide": visible := false
        case "Toggle": visible := !visible
        default: return
    }
    for id, handles in c {
        h_cursor := DllCall("CopyImage"
            , "Ptr", visible ? handles.default : handles.blank
            , "UInt", 2, "Int", 0, "Int", 0, "UInt", 0)
        DllCall("SetSystemCursor", "Ptr", h_cursor, "UInt", id)
    }
}

; https://www.autohotkey.com/boards/viewtopic.php?f=83&t=109148&hilit=StdoutToVar
StdoutToVar(sCmd, sDir := "", sEnc := "CP0") {
    ; Create 2 buffer-like objects to wrap the handles to take advantage of the __Delete meta-function.
    oHndStdoutRd := { Ptr: 0, __Delete: delete(this) => DllCall("CloseHandle", "Ptr", this) }
    oHndStdoutWr := { Base: oHndStdoutRd }

    if !DllCall("CreatePipe"
        , "PtrP", oHndStdoutRd
        , "PtrP", oHndStdoutWr
        , "Ptr", 0
        , "UInt", 0)
        throw OSError(, , "Error creating pipe.")
    if !DllCall("SetHandleInformation"
        , "Ptr", oHndStdoutWr
        , "UInt", 1
        , "UInt", 1)
        throw OSError(, , "Error setting handle information.")

    PI := Buffer(A_PtrSize == 4 ? 16 : 24, 0)
    SI := Buffer(A_PtrSize == 4 ? 68 : 104, 0)
    NumPut("UInt", SI.Size, SI, 0)
    NumPut("UInt", 0x100, SI, A_PtrSize == 4 ? 44 : 60)
    NumPut("Ptr", oHndStdoutWr.Ptr, SI, A_PtrSize == 4 ? 60 : 88)
    NumPut("Ptr", oHndStdoutWr.Ptr, SI, A_PtrSize == 4 ? 64 : 96)

    if !DllCall("CreateProcess"
        , "Ptr", 0
        , "Str", sCmd
        , "Ptr", 0
        , "Ptr", 0
        , "Int", True
        , "UInt", 0x08000000
        , "Ptr", 0
        , "Ptr", sDir ? StrPtr(sDir) : 0
        , "Ptr", SI
        , "Ptr", PI)
        throw OSError(, , "Error creating process.")

    ; The write pipe must be closed before reading the stdout so we release the object.
    ; The reading pipe will be released automatically on function return.
    oHndStdOutWr := ""

    ; Before reading, we check if the pipe has been written to, so we avoid freezings.
    nAvail := 0, nLen := 0
    while DllCall("PeekNamedPipe"
        , "Ptr", oHndStdoutRd
        , "Ptr", 0
        , "UInt", 0
        , "Ptr", 0
        , "UIntP", &nAvail
        , "Ptr", 0) != 0 {
        ; If the pipe buffer is empty, sleep and continue checking.
        if !nAvail && Sleep(100)
            continue
        cBuf := Buffer(nAvail + 1)
        DllCall("ReadFile"
            , "Ptr", oHndStdoutRd
            , "Ptr", cBuf
            , "UInt", nAvail
            , "PtrP", &nLen
            , "Ptr", 0)
        sOutput .= StrGet(cBuf, nLen, sEnc)
    }

    ; Get the exit code, close all process handles and return the output object.
    DllCall("GetExitCodeProcess"
        , "Ptr", NumGet(PI, 0, "Ptr")
        , "UIntP", &nExitCode := 0)
    DllCall("CloseHandle", "Ptr", NumGet(PI, 0, "Ptr"))
    DllCall("CloseHandle", "Ptr", NumGet(PI, A_PtrSize, "Ptr"))
    return { Output: sOutput, ExitCode: nExitCode }
}

; ==================== 辅助函数 ====================
; 发送快退快进命令，隐藏控制栏后执行
SendSeekCommand(key) {
    ; 统一使用屏幕坐标
    CoordMode("Mouse", "Screen")
    MouseGetPos(&sx, &sy)

    ; 取该窗口客户区的屏幕位置与尺寸
    WinGetClientPos(&cx, &cy, &cw, &ch, "A")

    ; 把鼠标从相对坐标系换算到绝对坐标系
    mx := sx - cx
    my := sy - cy

    topBand := sh / 13.7
    bottomBand := sh / 6

    ; 判断控制栏显示状态
    isShowingControlBar :=
        (mx >= 0 && mx <= cw) &&
        ((my >= 0 && my < topBand)
        || (my >= ch - bottomBand && my <= ch))

    if (isShowingControlBar) {
        ; 控制栏显示时，先隐藏控制栏
        SystemCursor("Hide")
        centerX := cx + cw / 2
        centerY := cy + 3 * ch / 8
        MouseMove(centerX, centerY, 0)

        ; 等待控制栏隐藏
        Sleep(100)

        ; 发送快退快进命令
        Send(key)

        ; 启动监控等待鼠标移动
        StartMouseMonitoring()
    } else {
        ; 控制栏未显示时，直接发送命令
        Send(key)
    }
}
