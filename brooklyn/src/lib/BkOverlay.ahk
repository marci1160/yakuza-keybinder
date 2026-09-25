; =====================================================================
;  Brooklyn Keybinder - Overlay (Meldungen, grosser Text, Countdown)
; ---------------------------------------------------------------------
;  Ersetzt AddChatMessage/ShowGameText der alten Brooklyn.dll. Ohne
;  Injection gibt es keinen Weg in den SA-MP-Chat - deshalb erscheinen
;  die "Organizer"-Meldungen als kleine Karten ueber dem Spiel. Die Maus
;  klickt durch, das Spiel verliert nie den Fokus.
;
;  Im ECHTEN Vollbild kann Windows kein Fenster ueber das Spiel legen
;  (Direct3D wuerde neu starten, das Bild friert kurz ein). Dort ruht das
;  Overlay automatisch; die Meldungen stehen dann im Keybinder-Fenster.
;  Empfehlung: GTA im Fenster oder randlosen Fenster spielen.
; =====================================================================

global g_Toasts := []          ; [{hwnd, until, h}]
global g_ToastSeq := 0
global g_MsgLog := []          ; [{t, text, kind}]
global g_BigHwnd := 0, g_BigUntil := 0, g_BigText := 0, g_ToastPool := ""
global g_CdLeft := 0
global g_HudHwnd := 0, g_HudTextHwnd := 0

BkOv_Colors(kind) {
    static c := {info: "FF8A1F", ok: "3DDC84", warn: "FF5C5C", money: "F5C542", list: "5AA9FF"}
    return c.HasKey(kind) ? c[kind] : c.info
}

; Darf das Overlay gerade ueberhaupt etwas zeigen?
BkOv_Allowed() {
    global BK_OvEnabled, BK_OvFullscreen
    if (!BK_OvEnabled)
        return false
    if (!BkGame_Hwnd())
        return false
    if (BK_OvFullscreen != "immer" && BkGame_Fullscreen())
        return false
    return true
}

; Innenbereich des Spielfensters in Bildschirmkoordinaten
BkOv_GameRect(ByRef x, ByRef y, ByRef w, ByRef h) {
    hwnd := BkGame_Hwnd()
    x := 0, y := 0, w := A_ScreenWidth, h := A_ScreenHeight
    if (!hwnd)
        return false
    VarSetCapacity(rc, 16, 0)
    if !DllCall("GetClientRect", "Ptr", hwnd, "Ptr", &rc)
        return false
    VarSetCapacity(pt, 8, 0)
    DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", &pt)
    x := NumGet(pt, 0, "Int"), y := NumGet(pt, 4, "Int")
    w := NumGet(rc, 8, "Int"), h := NumGet(rc, 12, "Int")
    if (w < 200 || h < 150)
        x := 0, y := 0, w := A_ScreenWidth, h := A_ScreenHeight
    return true
}

BkOv_Scale() {
    BkOv_GameRect(x, y, w, h)
    s := h / 1080
    return (s < 0.7) ? 0.7 : (s > 1.6) ? 1.6 : s
}

; ---------------------------------------------------------------------
;  Meldung ("Organizer: ...")
; ---------------------------------------------------------------------
BkMsg(text, kind := "info", ms := "") {
    global g_MsgLog, BK_OvToastMs
    text := RegExReplace(text, "\{[0-9A-Fa-f]{6}\}")
    BkDbg("MELDUNG " . StrReplace(text, "`n", " | "))
    FormatTime, t, , HH:mm:ss
    g_MsgLog.Push({t: t, text: text, kind: kind})
    while (g_MsgLog.MaxIndex() > 200)
        g_MsgLog.RemoveAt(1)
    BkGui_LogMsg(t, text, kind)
    if (!BkOv_Allowed())
        return
    if (ms = "")
        ms := BK_OvToastMs
    BkOv_Toast(text, kind, ms)
}

; Die Karten werden einmal angelegt und danach nur noch ein- und
; ausgeblendet - staendiges Erzeugen/Zerstoeren von Fenstern kostet Zeit.
BkOv_Toast(text, kind, ms) {
    global g_Toasts, g_ToastPool
    static maxN := 5
    if (!IsObject(g_ToastPool))
        g_ToastPool := []
    ; freien Platz suchen (sonst den aeltesten wiederverwenden)
    slot := ""
    for i, p in g_ToastPool {
        busy := false
        for j, t in g_Toasts
            if (t.slot = i)
                busy := true
        if (!busy) {
            slot := i
            break
        }
    }
    if (slot = "" && g_ToastPool.MaxIndex() < maxN)
        slot := BkOv_ToastCreate()
    if (slot = "") {
        slot := g_Toasts[1].slot
        g_Toasts.RemoveAt(1)
    }
    p := g_ToastPool[slot]
    sc := p.sc
    col := BkOv_Colors(kind)
    name := p.name
    GuiControl, %name%:+Background%col% +c%col%, % p.bar
    Gui, %name%:Font, % "s" . Round(8 * sc) . " bold c" . col, Segoe UI
    GuiControl, %name%:Font, % p.title
    GuiControl, %name%:, % p.msg, %text%
    th := BkOv_TextHeight(p.msg, text, p.tw)
    hh := Round(10 * sc) + p.titleH + Round(3 * sc) + th + Round(14 * sc)
    GuiControl, %name%:Move, % p.msg, % "h" . th
    GuiControl, %name%:Move, % p.bar, % "h" . hh
    WinMove, % "ahk_id " . p.hwnd, , , , % p.w, %hh%
    g_Toasts.Push({slot: slot, hwnd: p.hwnd, name: name, until: A_TickCount + ms, h: hh, w: p.w})
    BkOv_Layout()
    game := BkGame_Hwnd()
    Gui, %name%:Show, NA
    WinSet, Region, % "0-0 w" . p.w . " h" . hh . " R" . Round(14 * sc) . "-" . Round(14 * sc), % "ahk_id " . p.hwnd
    ; Sicherheitsnetz: nie dem Spiel den Fokus wegnehmen
    if (game && WinActive("ahk_id " . p.hwnd))
        WinActivate, ahk_id %game%
    SetTimer, BkOvTick, 250
}

BkOv_ToastCreate() {
    global g_ToastPool
    sc := BkOv_Scale()
    i := g_ToastPool.MaxIndex() ? g_ToastPool.MaxIndex() + 1 : 1
    name := "BkToast" . i
    fs := Round(11 * sc), fsT := Round(8 * sc)
    w := Round(400 * sc), pad := Round(16 * sc), bar := Round(5 * sc)
    tw := w - bar - 2 * pad
    Gui, %name%:New, +AlwaysOnTop -Caption +ToolWindow +E0x08000020 -DPIScale +HwndH
    Gui, %name%:Color, 15171D
    Gui, %name%:Margin, 0, 0
    Gui, %name%:Add, Progress, % "x0 y0 w" . bar . " h400 -Theme BackgroundFF8A1F cFF8A1F HwndHBar", 100
    Gui, %name%:Font, % "s" . fsT . " bold cFF8A1F", Segoe UI
    Gui, %name%:Add, Text, % "x" . (bar + pad) . " y" . Round(10 * sc) . " w" . tw . " BackgroundTrans HwndHTitle", BROOKLYN KEYBINDER
    GuiControlGet, tp, %name%:Pos, %HTitle%
    Gui, %name%:Font, % "s" . fs . " norm cF2F3F7", Segoe UI
    Gui, %name%:Add, Text, % "x" . (bar + pad) . " y" . (Round(10 * sc) + tpH + Round(3 * sc)) . " w" . tw . " h20 BackgroundTrans +0x80 HwndHMsg", -
    Gui, %name%:Show, Hide w%w% h60
    WinSet, Transparent, 235, ahk_id %H%
    g_ToastPool.Push({name: name, hwnd: H, bar: HBar, title: HTitle, msg: HMsg, w: w, tw: tw, titleH: tpH, sc: sc})
    return i
}

; Hoehe eines umbrochenen Textes in Pixeln (mit der Schrift des Elements)
BkOv_TextHeight(hCtrl, text, w) {
    hdc := DllCall("GetDC", "Ptr", hCtrl, "Ptr")
    hf := DllCall("SendMessage", "Ptr", hCtrl, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
    old := DllCall("SelectObject", "Ptr", hdc, "Ptr", hf, "Ptr")
    VarSetCapacity(rc, 16, 0), NumPut(w, rc, 8, "Int")
    DllCall("DrawText", "Ptr", hdc, "Str", text, "Int", -1, "Ptr", &rc, "UInt", 0x400 | 0x10 | 0x800)
    DllCall("SelectObject", "Ptr", hdc, "Ptr", old)
    DllCall("ReleaseDC", "Ptr", hCtrl, "Ptr", hdc)
    h := NumGet(rc, 12, "Int")
    return (h > 0) ? h + 2 : 20
}

BkOv_CloseToast(i) {
    global g_Toasts
    t := g_Toasts[i]
    g_Toasts.RemoveAt(i)
    n := t.name
    Gui, %n%:Hide
}

; Karten untereinander anordnen (linke oder rechte Seite, ab 42 % Hoehe)
BkOv_Layout() {
    global g_Toasts, BK_OvSide
    BkOv_GameRect(gx, gy, gw, gh)
    sc := BkOv_Scale()
    y := gy + Round(gh * 0.42)
    gap := Round(8 * sc)
    for i, t in g_Toasts {
        x := (BK_OvSide = "rechts") ? gx + gw - t.w - Round(24 * sc) : gx + Round(24 * sc)
        WinMove, % "ahk_id " . t.hwnd, , %x%, %y%
        y += t.h + gap
    }
}

BkOv_Tick() {
    global g_Toasts, g_BigHwnd, g_BigUntil, g_CdLeft
    static last := 0
    now := A_TickCount
    i := g_Toasts.MaxIndex()
    changed := false
    while (i >= 1) {
        if (now > g_Toasts[i].until) {
            BkOv_CloseToast(i)
            changed := true
        }
        i -= 1
    }
    if (g_BigShown := (g_BigHwnd && DllCall("IsWindowVisible", "Ptr", g_BigHwnd))) {
        if (now > g_BigUntil && !g_CdLeft) {
            Gui, BkBig:Hide
            g_BigShown := false
        }
    }
    ; Spiel nicht mehr vorne (Alt+Tab) -> alles weg
    if (!BkGame_Active() && !WinActive("ahk_class AutoHotkeyGUI")) {
        if (g_Toasts.MaxIndex() || g_BigShown)
            BkOv_HideAll()
    } else if (changed || (now - last) > 1000) {
        last := now
        BkOv_Layout()
    }
    if (!g_Toasts.MaxIndex() && !g_BigShown)
        SetTimer, BkOvTick, Off
}

BkOv_HideAll() {
    global g_Toasts, g_BigHwnd, g_CdLeft
    while (g_Toasts.MaxIndex())
        BkOv_CloseToast(1)
    if (g_BigHwnd)
        Gui, BkBig:Hide
    g_CdLeft := 0
    SetTimer, BkOvCdTick, Off
}

; ---------------------------------------------------------------------
;  Grosser Text in der Bildmitte (Ersatz fuer ShowGameText)
; ---------------------------------------------------------------------
BkBigText(text, ms := 2000) {
    global g_BigHwnd, g_BigUntil, g_BigText
    static map := {r: "FF5C5C", g: "3DDC84", b: "5AA9FF", y: "F5C542", w: "FFFFFF", p: "C58CFF"}
    col := "FFFFFF"
    if RegExMatch(text, "i)~([rgbywp])~", m)
        col := map[m1]
    text := RegExReplace(text, "i)~n~", " ")
    text := Trim(RegExReplace(text, "~[a-zA-Z]~"))
    if (!BkOv_Allowed() || text = "")
        return
    sc := BkOv_Scale()
    BkOv_GameRect(gx, gy, gw, gh)
    if (!g_BigHwnd) {
        Gui, BkBig:New, +AlwaysOnTop -Caption +ToolWindow +E0x08000020 -DPIScale +HwndH
        Gui, BkBig:Color, 101216
        Gui, BkBig:Margin, 0, 0
        Gui, BkBig:Font, % "s" . Round(26 * sc) . " bold cFFFFFF", Segoe UI
        Gui, BkBig:Add, Text, % "x0 y" . Round(12 * sc) . " w" . Round(700 * sc) . " Center BackgroundTrans +0x80 HwndHT", -
        WinSet, Transparent, 225, ahk_id %H%
        g_BigHwnd := H, g_BigText := HT
    }
    Gui, BkBig:Font, % "s" . Round(26 * sc) . " bold c" . col, Segoe UI
    GuiControl, BkBig:Font, %g_BigText%
    GuiControl, BkBig:, %g_BigText%, %text%
    ; Breite an den Text anpassen
    tw := BkOv_TextWidth(g_BigText, text) + Round(56 * sc)
    hh := Round(26 * sc * 1.9) + Round(24 * sc)
    GuiControl, BkBig:Move, %g_BigText%, % "w" . tw
    x := gx + (gw - tw) // 2, y := gy + Round(gh * 0.66)
    Gui, BkBig:Show, x%x% y%y% w%tw% h%hh% NA
    WinSet, Region, % "0-0 w" . tw . " h" . hh . " R" . Round(18 * sc) . "-" . Round(18 * sc), ahk_id %g_BigHwnd%
    g_BigUntil := A_TickCount + ms
    SetTimer, BkOvTick, 250
}

BkOv_TextWidth(hCtrl, text) {
    hdc := DllCall("GetDC", "Ptr", hCtrl, "Ptr")
    hf := DllCall("SendMessage", "Ptr", hCtrl, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
    old := DllCall("SelectObject", "Ptr", hdc, "Ptr", hf, "Ptr")
    VarSetCapacity(rc, 16, 0)
    DllCall("DrawText", "Ptr", hdc, "Str", text, "Int", -1, "Ptr", &rc, "UInt", 0x400 | 0x20 | 0x800)
    DllCall("SelectObject", "Ptr", hdc, "Ptr", old)
    DllCall("ReleaseDC", "Ptr", hCtrl, "Ptr", hdc)
    return NumGet(rc, 8, "Int")
}

; Countdown in der Bildmitte (Kofferraum, 15-s-Countdown)
BkOv_Countdown(n) {
    global g_CdLeft
    g_CdLeft := n
    BkBigText("~w~" . n, 1500)
    SetTimer, BkOvCdTick, 1000
}

BkOvCd_Tick() {
    global g_CdLeft
    g_CdLeft -= 1
    if (g_CdLeft <= 0) {
        g_CdLeft := 0
        SetTimer, BkOvCdTick, Off
        BkBigText("~g~0", 1200)
        return
    }
    BkBigText((g_CdLeft <= 3 ? "~r~" : "~w~") . g_CdLeft, 1500)
}

BkOv_CountdownStop() {
    global g_CdLeft
    g_CdLeft := 0
    SetTimer, BkOvCdTick, Off
}

; ---------------------------------------------------------------------
;  Kleine Info-Anzeige (optional): Standort, HP, Kills heute, K/D
; ---------------------------------------------------------------------
BkHud_Tick() {
    global BK_OvHud, g_HudHwnd, g_HudTextHwnd
    if (!BK_OvHud || !BkOv_Allowed() || !BkGame_Active()) {
        if (g_HudHwnd)
            Gui, BkHud:Hide
        return
    }
    sc := BkOv_Scale()
    BkOv_GameRect(gx, gy, gw, gh)
    txt := BkFill("{zone}  ·  HP {hp}  ·  Kills heute {dkills}  ·  K/D {dkd}")
    if (!g_HudHwnd) {
        Gui, BkHud:New, +AlwaysOnTop -Caption +ToolWindow +E0x08000020 -DPIScale +HwndH
        Gui, BkHud:Color, 101216
        Gui, BkHud:Margin, % Round(12 * sc), % Round(6 * sc)
        Gui, BkHud:Font, % "s" . Round(10 * sc) . " cE6E8EF", Segoe UI
        Gui, BkHud:Add, Text, % "w" . Round(520 * sc) . " Center HwndT", %txt%
        g_HudHwnd := H, g_HudTextHwnd := T
        Gui, BkHud:Show, Hide AutoSize
        WinSet, Transparent, 200, ahk_id %H%
    } else {
        GuiControl, BkHud:, %g_HudTextHwnd%, %txt%
    }
    WinGetPos, , , ww, hh, ahk_id %g_HudHwnd%
    WinSet, Region, % "0-0 w" . ww . " h" . hh . " R10-10", ahk_id %g_HudHwnd%
    x := gx + (gw - ww) // 2, y := gy + Round(6 * sc)
    Gui, BkHud:Show, x%x% y%y% NA
}
