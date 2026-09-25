; =====================================================================
;  Yakuza Keybinder - Meldungen im Spiel (Karten, grosser Text, Countdown)
; ---------------------------------------------------------------------
;  Neu in v3.0 (aus dem Keybinder von Brooklyn 5.0). Ergebnisse von
;  Chat-Befehlen wie /tode, /otime oder den Gegnerlisten erscheinen als
;  kleine Karte ueber dem Spiel - der Server bekommt davon nichts mit.
;  Die Maus klickt durch, das Spiel verliert nie den Fokus.
;
;  Im ECHTEN Vollbild ruhen die Karten genau wie das Overlay (siehe
;  YkOverlay_MayBuild) - dort stehen die Meldungen im Keybinder-Fenster.
; =====================================================================

global YK_ToastOn   := true
global YK_ToastMs   := 5000
global YK_ToastSide := "auto"    ; auto = gegenueber vom Overlay | links | rechts
global g_Toasts := []          ; [{hwnd, until, h}]
global g_ToastSeq := 0
global g_MsgLog := []          ; [{t, text, kind}]
global g_BigHwnd := 0, g_BigUntil := 0, g_BigText := 0, g_ToastPool := ""
global g_CdLeft := 0
global g_HudHwnd := 0, g_HudTextHwnd := 0

YkToast_Colors(kind) {
    static c := {info: "E04848", ok: "3DDC84", warn: "FFB547", money: "F5C542", list: "5AA9FF"}
    return c.HasKey(kind) ? c[kind] : c.info
}

; Darf das Overlay gerade ueberhaupt etwas zeigen?
YkToast_Allowed() {
    global YK_ToastOn
    if (!YK_ToastOn)
        return false
    return YkOverlay_MayBuild()
}

; Innenbereich des Spielfensters in Bildschirmkoordinaten
YkToast_GameRect(ByRef x, ByRef y, ByRef w, ByRef h) {
    hwnd := YkGame_Hwnd()
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

YkToast_Scale() {
    YkToast_GameRect(x, y, w, h)
    s := h / 1080
    return (s < 0.7) ? 0.7 : (s > 1.6) ? 1.6 : s
}

; Die Karten werden einmal angelegt und danach nur noch ein- und
; ausgeblendet - staendiges Erzeugen/Zerstoeren von Fenstern kostet Zeit.
YkToast(text, kind, ms) {
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
        slot := YkToast_Create()
    if (slot = "") {
        slot := g_Toasts[1].slot
        g_Toasts.RemoveAt(1)
    }
    p := g_ToastPool[slot]
    sc := p.sc
    col := YkToast_Colors(kind)
    name := p.name
    GuiControl, %name%:+Background%col% +c%col%, % p.bar
    Gui, %name%:Font, % "s" . Round(8 * sc) . " bold c" . col, Segoe UI
    GuiControl, %name%:Font, % p.title
    GuiControl, %name%:, % p.msg, %text%
    th := YkToast_TextHeight(p.msg, text, p.tw)
    hh := Round(10 * sc) + p.titleH + Round(3 * sc) + th + Round(14 * sc)
    GuiControl, %name%:Move, % p.msg, % "h" . th
    GuiControl, %name%:Move, % p.bar, % "h" . hh
    WinMove, % "ahk_id " . p.hwnd, , , , % p.w, %hh%
    g_Toasts.Push({slot: slot, hwnd: p.hwnd, name: name, until: A_TickCount + ms, h: hh, w: p.w})
    YkToast_Layout()
    game := YkGame_Hwnd()
    Gui, %name%:Show, NA
    WinSet, Region, % "0-0 w" . p.w . " h" . hh . " R" . Round(14 * sc) . "-" . Round(14 * sc), % "ahk_id " . p.hwnd
    ; Sicherheitsnetz: nie dem Spiel den Fokus wegnehmen
    if (game && WinActive("ahk_id " . p.hwnd))
        WinActivate, ahk_id %game%
    SetTimer, YkToast_Tick, 250
}

YkToast_Create() {
    global g_ToastPool
    sc := YkToast_Scale()
    i := g_ToastPool.MaxIndex() ? g_ToastPool.MaxIndex() + 1 : 1
    name := "YkToast" . i
    fs := Round(11 * sc), fsT := Round(8 * sc)
    w := Round(400 * sc), pad := Round(16 * sc), bar := Round(5 * sc)
    tw := w - bar - 2 * pad
    Gui, %name%:New, +AlwaysOnTop -Caption +ToolWindow +E0x08000020 -DPIScale +HwndH
    Gui, %name%:Color, 15171D
    Gui, %name%:Margin, 0, 0
    Gui, %name%:Add, Progress, % "x0 y0 w" . bar . " h400 -Theme BackgroundE04848 cE04848 HwndHBar", 100
    Gui, %name%:Font, % "s" . fsT . " bold cE04848", Segoe UI
    Gui, %name%:Add, Text, % "x" . (bar + pad) . " y" . Round(10 * sc) . " w" . tw . " BackgroundTrans HwndHTitle", YAKUZA KEYBINDER
    GuiControlGet, tp, %name%:Pos, %HTitle%
    Gui, %name%:Font, % "s" . fs . " norm cF2F3F7", Segoe UI
    Gui, %name%:Add, Text, % "x" . (bar + pad) . " y" . (Round(10 * sc) + tpH + Round(3 * sc)) . " w" . tw . " h20 BackgroundTrans +0x80 HwndHMsg", -
    Gui, %name%:Show, Hide w%w% h60
    WinSet, Transparent, 235, ahk_id %H%
    g_ToastPool.Push({name: name, hwnd: H, bar: HBar, title: HTitle, msg: HMsg, w: w, tw: tw, titleH: tpH, sc: sc})
    return i
}

; Hoehe eines umbrochenen Textes in Pixeln (mit der Schrift des Elements)
YkToast_TextHeight(hCtrl, text, w) {
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

YkToast_Close(i) {
    global g_Toasts
    t := g_Toasts[i]
    g_Toasts.RemoveAt(i)
    n := t.name
    Gui, %n%:Hide
}

; Karten untereinander anordnen (linke oder rechte Seite, ab 42 % Hoehe)
YkToast_Layout() {
    global g_Toasts, YK_ToastSide, YK_OvSide
    YkToast_GameRect(gx, gy, gw, gh)
    sc := YkToast_Scale()
    y := gy + Round(gh * 0.42)
    gap := Round(8 * sc)
    side := YK_ToastSide
    if (side != "links" && side != "rechts")
        side := (YK_OvSide = 1) ? "rechts" : "links"
    for i, t in g_Toasts {
        x := (side = "rechts") ? gx + gw - t.w - Round(24 * sc) : gx + Round(24 * sc)
        WinMove, % "ahk_id " . t.hwnd, , %x%, %y%
        y += t.h + gap
    }
}

YkToast_Tick() {
    global g_Toasts, g_BigHwnd, g_BigUntil, g_CdLeft
    static last := 0
    now := A_TickCount
    i := g_Toasts.MaxIndex()
    changed := false
    while (i >= 1) {
        if (now > g_Toasts[i].until) {
            YkToast_Close(i)
            changed := true
        }
        i -= 1
    }
    if (g_BigShown := (g_BigHwnd && DllCall("IsWindowVisible", "Ptr", g_BigHwnd))) {
        if (now > g_BigUntil && !g_CdLeft) {
            Gui, YkBig:Hide
            g_BigShown := false
        }
    }
    ; Spiel nicht mehr vorne (Alt+Tab) -> alles weg
    if (!YkGame_Active() && !WinActive("ahk_id " . YkGuiHwnd)) {
        if (g_Toasts.MaxIndex() || g_BigShown)
            YkToast_HideAll()
    } else if (changed || (now - last) > 1000) {
        last := now
        YkToast_Layout()
    }
    if (!g_Toasts.MaxIndex() && !g_BigShown)
        SetTimer, YkToast_Tick, Off
}

YkToast_HideAll() {
    global g_Toasts, g_BigHwnd, g_CdLeft
    while (g_Toasts.MaxIndex())
        YkToast_Close(1)
    if (g_BigHwnd)
        Gui, YkBig:Hide
    g_CdLeft := 0
    SetTimer, YkToast_CdTick, Off
}

; ---------------------------------------------------------------------
;  Grosser Text in der Bildmitte (Ersatz fuer ShowGameText)
; ---------------------------------------------------------------------
YkBigText(text, ms := 2000) {
    global g_BigHwnd, g_BigUntil, g_BigText
    static map := {r: "FF5C5C", g: "3DDC84", b: "5AA9FF", y: "F5C542", w: "FFFFFF", p: "C58CFF"}
    col := "FFFFFF"
    if RegExMatch(text, "i)~([rgbywp])~", m)
        col := map[m1]
    text := RegExReplace(text, "i)~n~", " ")
    text := Trim(RegExReplace(text, "~[a-zA-Z]~"))
    if (!YkToast_Allowed() || text = "")
        return
    sc := YkToast_Scale()
    YkToast_GameRect(gx, gy, gw, gh)
    if (!g_BigHwnd) {
        Gui, YkBig:New, +AlwaysOnTop -Caption +ToolWindow +E0x08000020 -DPIScale +HwndH
        Gui, YkBig:Color, 101216
        Gui, YkBig:Margin, 0, 0
        Gui, YkBig:Font, % "s" . Round(26 * sc) . " bold cFFFFFF", Segoe UI
        Gui, YkBig:Add, Text, % "x0 y" . Round(12 * sc) . " w" . Round(700 * sc) . " Center BackgroundTrans +0x80 HwndHT", -
        WinSet, Transparent, 225, ahk_id %H%
        g_BigHwnd := H, g_BigText := HT
    }
    Gui, YkBig:Font, % "s" . Round(26 * sc) . " bold c" . col, Segoe UI
    GuiControl, YkBig:Font, %g_BigText%
    GuiControl, YkBig:, %g_BigText%, %text%
    ; Breite an den Text anpassen
    tw := YkToast_TextWidth(g_BigText, text) + Round(56 * sc)
    hh := Round(26 * sc * 1.9) + Round(24 * sc)
    GuiControl, YkBig:Move, %g_BigText%, % "w" . tw
    x := gx + (gw - tw) // 2, y := gy + Round(gh * 0.66)
    Gui, YkBig:Show, x%x% y%y% w%tw% h%hh% NA
    WinSet, Region, % "0-0 w" . tw . " h" . hh . " R" . Round(18 * sc) . "-" . Round(18 * sc), ahk_id %g_BigHwnd%
    g_BigUntil := A_TickCount + ms
    SetTimer, YkToast_Tick, 250
}

YkToast_TextWidth(hCtrl, text) {
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
YkToast_Countdown(n) {
    global g_CdLeft
    g_CdLeft := n
    YkBigText("~w~" . n, 1500)
    SetTimer, YkToast_CdTick, 1000
}

YkToast_CdTick() {
    global g_CdLeft
    g_CdLeft -= 1
    if (g_CdLeft <= 0) {
        g_CdLeft := 0
        SetTimer, YkToast_CdTick, Off
        YkBigText("~g~0", 1200)
        return
    }
    YkBigText((g_CdLeft <= 3 ? "~r~" : "~w~") . g_CdLeft, 1500)
}

YkToast_CountdownStop() {
    global g_CdLeft
    g_CdLeft := 0
    SetTimer, YkToast_CdTick, Off
}
