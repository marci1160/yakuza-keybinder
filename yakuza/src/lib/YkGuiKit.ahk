; =====================================================================
;  Yakuza Keybinder - UI-Baukasten (aus dem Keybinder von Brooklyn 5.0)
; ---------------------------------------------------------------------
;  Dunkles, modernes Design ohne Zusatzdateien:
;   - Karten und Knoepfe sind abgerundete, geglaettete Flaechen, die zur
;     Laufzeit mit GDI+ gezeichnet werden (Picture-Steuerelemente).
;   - Texte liegen durchsichtig darauf.
;   - Listen, Eingabefelder und Auswahllisten nutzen den Windows-
;     Dunkelmodus (ab Windows 10 1809).
;   - Seiten werden ohne Flackern umgeschaltet (Zeichnen kurz aus).
; =====================================================================

global YkCol := {}
global g_UiPages := {}, g_UiCur := "", g_UiSub := {}, g_UiBuilding := ""
global g_UiHwnd := 0, g_GdipToken := 0

YkUi_Theme() {
    global YkCol
    YkCol := {bg: "121216", side: "0C0C0F", card: "1A1A20", card2: "23232B", line: "2E2E38", field: "1E1E25"
          , text: "ECECF1", dim: "9A9AA6", faint: "5E5E6A", accent: "E04848", accent2: "FF6B6B", ok: "3DDC84", warn: "FFB547", gold: "F5C542"}
}

; ---------------------------------------------------------------------
;  GDI+ Flaechen
; ---------------------------------------------------------------------
YkGdip_Start() {
    global g_GdipToken
    if (g_GdipToken)
        return true
    if !DllCall("GetModuleHandle", "Str", "gdiplus", "Ptr")
        DllCall("LoadLibrary", "Str", "gdiplus")
    VarSetCapacity(si, A_PtrSize = 8 ? 24 : 16, 0), NumPut(1, si, 0, "UInt")
    DllCall("gdiplus\GdiplusStartup", "UPtr*", tok, "Ptr", &si, "Ptr", 0)
    g_GdipToken := tok
    return (tok != 0)
}

YkArgb(rgb, a := 255) {
    return (a << 24) | YkHex(rgb)
}

YkHex(s) {
    v := 0
    Loop, Parse, s
        v := v * 16 + InStr("0123456789ABCDEF", A_LoopField) - 1
    return v
}

; Abgerundetes Rechteck als HBITMAP (Groesse in logischen Pixeln).
;   fill   Flaechenfarbe, bg Farbe dahinter, border Rahmen ("" = keiner)
;   bar    Farbe eines Akzentstreifens links ("" = keiner)
YkUi_Bmp(w, h, fill, bg, r := 12, border := "", bar := "") {
    YkGdip_Start()
    s := A_ScreenDPI / 96
    W := Round(w * s), H := Round(h * s), R := r * s
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", W, "Int", H, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", pBmp)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pBmp, "Ptr*", g)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g, "Int", 4)
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", g, "Int", 4)
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", g, "UInt", YkArgb(bg))
    path := YkGdip_RoundPath(0.5, 0.5, W - 1, H - 1, R)
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", YkArgb(fill), "Ptr*", br)
    DllCall("gdiplus\GdipFillPath", "Ptr", g, "Ptr", br, "Ptr", path)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
    if (bar != "") {
        DllCall("gdiplus\GdipSetClipPath", "Ptr", g, "Ptr", path, "Int", 0)
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", YkArgb(bar), "Ptr*", br2)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", g, "Ptr", br2, "Float", 0, "Float", 0, "Float", 4 * s, "Float", H)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", br2)
        DllCall("gdiplus\GdipResetClip", "Ptr", g)
    }
    if (border != "") {
        DllCall("gdiplus\GdipCreatePen1", "UInt", YkArgb(border), "Float", s, "Int", 2, "Ptr*", pen)
        DllCall("gdiplus\GdipDrawPath", "Ptr", g, "Ptr", pen, "Ptr", path)
        DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
    }
    DllCall("gdiplus\GdipDeletePath", "Ptr", path)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g)
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", pBmp, "Ptr*", hbm, "UInt", YkArgb(bg))
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBmp)
    return hbm
}

; Bild (JPG/PNG) als abgerundete Flaeche - fuer das Yakuza-Banner.
; Das Bild fuellt die Flaeche (zugeschnitten, Seitenverhaeltnis bleibt).
YkUi_ImageBmp(file, w, h, r, bg, border := "") {
    YkGdip_Start()
    img := 0
    DllCall("gdiplus\GdipLoadImageFromFile", "WStr", file, "Ptr*", img)
    if (!img)
        return YkUi_Bmp(w, h, "16161B", bg, r, border)
    s := A_ScreenDPI / 96
    W := Round(w * s), H := Round(h * s), R := r * s
    DllCall("gdiplus\GdipGetImageWidth", "Ptr", img, "UInt*", iw)
    DllCall("gdiplus\GdipGetImageHeight", "Ptr", img, "UInt*", ih)
    ; 1) Bild in Zielgroesse zeichnen
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", W, "Int", H, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", pTmp)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pTmp, "Ptr*", gt)
    DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", gt, "Int", 7)
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", gt, "Int", 4)
    sc := (W / iw > H / ih) ? W / iw : H / ih
    dw := iw * sc, dh := ih * sc
    DllCall("gdiplus\GdipDrawImageRect", "Ptr", gt, "Ptr", img, "Float", (W - dw) / 2, "Float", (H - dh) / 2, "Float", dw, "Float", dh)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gt)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", img)
    ; 2) als Muster in eine abgerundete Flaeche fuellen (glatte Ecken)
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", W, "Int", H, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", pBmp)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pBmp, "Ptr*", g)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g, "Int", 4)
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", g, "Int", 4)
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", g, "UInt", YkArgb(bg))
    DllCall("gdiplus\GdipCreateTexture", "Ptr", pTmp, "Int", 0, "Ptr*", br)
    path := YkGdip_RoundPath(0.5, 0.5, W - 1, H - 1, R)
    DllCall("gdiplus\GdipFillPath", "Ptr", g, "Ptr", br, "Ptr", path)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
    if (border != "") {
        DllCall("gdiplus\GdipCreatePen1", "UInt", YkArgb(border), "Float", s, "Int", 2, "Ptr*", pen)
        DllCall("gdiplus\GdipDrawPath", "Ptr", g, "Ptr", pen, "Ptr", path)
        DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
    }
    DllCall("gdiplus\GdipDeletePath", "Ptr", path)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pTmp)
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", pBmp, "Ptr*", hbm, "UInt", YkArgb(bg))
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBmp)
    return hbm
}

YkGdip_RoundPath(x, y, w, h, r) {
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", p)
    if (r < 1) {
        DllCall("gdiplus\GdipAddPathRectangle", "Ptr", p, "Float", x, "Float", y, "Float", w, "Float", h)
        return p
    }
    d := r * 2
    if (d > w)
        d := w
    if (d > h)
        d := h
    DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", x, "Float", y, "Float", d, "Float", d, "Float", 180, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", x + w - d, "Float", y, "Float", d, "Float", d, "Float", 270, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", x + w - d, "Float", y + h - d, "Float", d, "Float", d, "Float", 0, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", x, "Float", y + h - d, "Float", d, "Float", d, "Float", 90, "Float", 90)
    DllCall("gdiplus\GdipClosePathFigure", "Ptr", p)
    return p
}

; ---------------------------------------------------------------------
;  Windows-Dunkelmodus (aus v2)
; ---------------------------------------------------------------------
YkDark_Init() {
    static state := -1
    if (state != -1)
        return state
    state := 0
    if !RegExMatch(A_OSVersion, "^(\d+)\.(\d+)\.(\d+)", v)
        return state
    if (v1 + 0 < 10 || v3 + 0 < 17763)
        return state
    h := DllCall("LoadLibrary", "Str", "uxtheme", "Ptr")
    if (!h)
        return state
    pSet := DllCall("GetProcAddress", "Ptr", h, "Ptr", 135, "Ptr")
    pRef := DllCall("GetProcAddress", "Ptr", h, "Ptr", 104, "Ptr")
    if (!pSet)
        return state
    DllCall(pSet, "Int", (v3 + 0 >= 18362) ? 2 : 1)
    if (pRef)
        DllCall(pRef)
    state := 1
    return state
}

YkDark_Window(hwnd) {
    VarSetCapacity(v, 4, 0), NumPut(1, v, 0, "Int")
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 20, "Ptr", &v, "Int", 4)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 19, "Ptr", &v, "Int", 4)
    ; Windows 11: Titelleiste in der Hintergrundfarbe
    VarSetCapacity(c, 4, 0), NumPut(0x161212, c, 0, "UInt")
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 35, "Ptr", &c, "Int", 4)
}

YkDark_Ctrl(hwnd, theme := "DarkMode_Explorer") {
    if (hwnd)
        try DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "WStr", theme, "Ptr", 0)
}

YkDark_Apply(guiHwnd) {
    if (!YkDark_Init() || !guiHwnd)
        return
    hUx := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
    pAllow := hUx ? DllCall("GetProcAddress", "Ptr", hUx, "Ptr", 133, "Ptr") : 0
    WinGet, list, ControlListHwnd, ahk_id %guiHwnd%
    Loop, Parse, list, `n
    {
        hc := A_LoopField + 0
        WinGetClass, cls, ahk_id %hc%
        if (cls = "Button") {
            bst := DllCall("GetWindowLong", "Ptr", hc, "Int", -16, "Int") & 0xF
            if (bst >= 2 && bst <= 9) {           ; Haekchen/Auswahl: AHK faerbt den Text
                try DllCall("uxtheme\SetWindowTheme", "Ptr", hc, "WStr", "", "WStr", "")
                continue
            }
        }
        if (cls = "Static" || cls = "msctls_progress32")
            continue
        if (pAllow)
            try DllCall(pAllow, "Ptr", hc, "Int", 1)
        if (cls = "SysListView32") {
            YkDark_Ctrl(hc, "DarkMode_Explorer")
            hdr := DllCall("SendMessage", "Ptr", hc, "UInt", 0x101F, "Ptr", 0, "Ptr", 0, "Ptr")
            if (pAllow && hdr)
                try DllCall(pAllow, "Ptr", hdr, "Int", 1)
            YkDark_Ctrl(hdr, "DarkMode_ItemsView")
        } else if (cls = "ComboBox") {
            YkDark_Ctrl(hc, "DarkMode_CFD")
        } else {
            YkDark_Ctrl(hc, "DarkMode_Explorer")
        }
    }
}

; ---------------------------------------------------------------------
;  Seiten
; ---------------------------------------------------------------------
; Alle folgenden Steuerelemente gehoeren zu dieser Seite ("dash",
; "settings.2" ...). Unterseiten "x.n" sind nur sichtbar, wenn ihre
; Hauptseite offen ist UND die Unterseite gewaehlt ist.
YkUi_Page(name) {
    global g_UiBuilding, g_UiPages
    g_UiBuilding := name
    if (!g_UiPages.HasKey(name))
        g_UiPages[name] := []
}

YkUi_Visible(page) {
    global g_UiCur, g_UiSub
    if (page = "*")
        return true
    p := StrSplit(page, ".")
    if (p[1] != g_UiCur)
        return false
    if (p.MaxIndex() > 1)
        return (g_UiSub[p[1]] = p[2])
    return true
}

; Steuerelement anlegen und der aktuellen Seite zuordnen
YkUi_Add(type, opts, text := "") {
    global                          ; Steuer-Variablen (vYkG_...) muessen global sein
    local H
    if (!YkUi_Visible(g_UiBuilding))
        opts .= " Hidden"
    Gui, Yk:Add, %type%, %opts% HwndH, %text%
    g_UiPages[g_UiBuilding].Push(H)
    return H
}

YkUi_Font(size := 10, style := "norm", color := "") {
    global YkCol
    if (color = "")
        color := YkCol.text
    Gui, Yk:Font, s%size% %style% c%color%, Segoe UI
}

; Symbolschrift von Windows 10/11 (auf aelteren Systemen keine Symbole)
YkUi_IconFont() {
    static f := "#"
    if (f != "#")
        return f
    f := ""
    for i, n in ["Segoe Fluent Icons (TrueType)", "Segoe MDL2 Assets (TrueType)"] {
        RegRead, v, HKLM, SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts, %n%
        if (!ErrorLevel && v != "") {
            f := SubStr(n, 1, InStr(n, " (") - 1)
            break
        }
    }
    return f
}

YkUi_Icon(x, y, glyph, size := 14, color := "", opts := "") {
    global YkCol
    if (color = "")
        color := YkCol.accent
    fnt := YkUi_IconFont()
    if (fnt = "")
        glyph := "", fnt := "Segoe UI"
    Gui, Yk:Font, s%size% norm c%color%, %fnt%
    h := YkUi_Add("Text", "x" . x . " y" . y . " BackgroundTrans " . opts, (glyph = "") ? "" : Chr(YkHex(glyph)))
    YkUi_Font()
    return h
}

; Text (durchsichtig). Liefert das Handle.
YkUi_Text(x, y, w, text, size := 10, style := "norm", color := "", opts := "") {
    YkUi_Font(size, style, color)
    h := YkUi_Add("Text", "x" . x . " y" . y . (w ? " w" . w : "") . " BackgroundTrans +0x80 " . opts, text)
    YkUi_Font()
    return h
}

; Karte (abgerundete Flaeche) mit optionalem Titel
YkUi_Card(x, y, w, h, title := "", icon := "", sub := "") {
    global YkCol
    hb := YkUi_Bmp(w, h, YkCol.card, YkCol.bg, 14, YkCol.line)
    YkUi_Add("Picture", "x" . x . " y" . y . " w" . w . " h" . h, "HBITMAP:" . hb)
    if (title != "") {
        tx := x + 20
        if (icon != "") {
            YkUi_Icon(x + 20, y + 17, icon, 12)
            tx := x + 44
        }
        YkUi_Text(tx, y + 14, w - (tx - x) - 20, title, 11, "bold")
        if (sub != "")
            YkUi_Text(x + 20, y + 38, w - 40, sub, 9, "norm", YkCol.dim)
    }
}

; Knopf: style = primary | ghost | danger. Liefert {pic, txt}
YkUi_Button(x, y, w, h, text, label, style := "ghost", bgc := "") {
    global YkCol
    if (bgc = "")
        bgc := YkCol.card
    fill := (style = "primary") ? YkCol.accent : (style = "danger") ? "3A1E22" : YkCol.card2
    brd := (style = "primary") ? "" : (style = "danger") ? "6B2A31" : YkCol.line
    col := (style = "primary") ? "FFFFFF" : (style = "danger") ? "FF9A9A" : YkCol.text
    hb := YkUi_Bmp(w, h, fill, bgc, 9, brd)
    p := YkUi_Add("Picture", "x" . x . " y" . y . " w" . w . " h" . h . " g" . label, "HBITMAP:" . hb)
    YkUi_Font(10, (style = "primary") ? "bold" : "norm", col)
    t := YkUi_Add("Text", "x" . x . " y" . (y + (h - 20) // 2) . " w" . w . " h20 Center BackgroundTrans +0x80 g" . label, text)
    YkUi_Font()
    return {pic: p, txt: t}
}

; Text aendern ohne Schlieren (durchsichtiger Text auf einer Karte)
YkUi_Set(hwnd, text) {
    global g_UiHwnd
    ControlGetText, old, , ahk_id %hwnd%
    if (old == text)
        return
    ControlSetText, , %text%, ahk_id %hwnd%
    YkUi_Repaint(hwnd)
}

YkUi_Repaint(hwnd) {
    global g_UiHwnd
    VarSetCapacity(rc, 16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", &rc)
    DllCall("MapWindowPoints", "Ptr", 0, "Ptr", g_UiHwnd, "Ptr", &rc, "UInt", 2)
    DllCall("RedrawWindow", "Ptr", g_UiHwnd, "Ptr", &rc, "Ptr", 0, "UInt", 0x185)
}

; Seite wechseln (ohne Flackern)
YkUi_Show(page, sub := "") {
    global g_UiPages, g_UiCur, g_UiSub, g_UiHwnd
    if (sub != "")
        g_UiSub[page] := sub
    g_UiCur := page
    DllCall("SendMessage", "Ptr", g_UiHwnd, "UInt", 0x0B, "Ptr", 0, "Ptr", 0)     ; WM_SETREDRAW aus
    for name, list in g_UiPages {
        vis := YkUi_Visible(name)
        for i, h in list
            DllCall("ShowWindow", "Ptr", h, "Int", vis ? 8 : 0)                    ; SW_SHOWNA / SW_HIDE
    }
    YkUi_TogglesSync()
    DllCall("SendMessage", "Ptr", g_UiHwnd, "UInt", 0x0B, "Ptr", 1, "Ptr", 0)
    DllCall("RedrawWindow", "Ptr", g_UiHwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x185)
}

; Einzelnes Element ein-/ausblenden (respektiert die aktuelle Seite nicht)
YkUi_ShowCtrl(hwnd, show) {
    DllCall("ShowWindow", "Ptr", hwnd, "Int", show ? 8 : 0)
}

; ---------------------------------------------------------------------
;  Schalter (statt Haekchen) - sieht modern aus und ist auf den Karten
;  sauber durchsichtig
; ---------------------------------------------------------------------
global g_Tog := {}

YkUi_ToggleBmp(on, bgc := "") {
    global YkCol
    YkGdip_Start()
    if (bgc = "")
        bgc := YkCol.card
    s := A_ScreenDPI / 96
    W := Round(40 * s), H := Round(22 * s)
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", W, "Int", H, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", pBmp)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pBmp, "Ptr*", g)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g, "Int", 4)
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", g, "Int", 4)
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", g, "UInt", YkArgb(bgc))
    path := YkGdip_RoundPath(0.5, 0.5, W - 1, H - 1, (H - 1) / 2)
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", YkArgb(on ? YkCol.accent : "3A3F4B"), "Ptr*", br)
    DllCall("gdiplus\GdipFillPath", "Ptr", g, "Ptr", br, "Ptr", path)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
    DllCall("gdiplus\GdipDeletePath", "Ptr", path)
    d := H - 6 * s
    kx := on ? W - d - 3 * s : 3 * s
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", YkArgb(on ? "FFFFFF" : "C9CDD6"), "Ptr*", br)
    DllCall("gdiplus\GdipFillEllipse", "Ptr", g, "Ptr", br, "Float", kx, "Float", 3 * s, "Float", d, "Float", d)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g)
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", pBmp, "Ptr*", hbm, "UInt", YkArgb(bgc))
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBmp)
    return hbm
}

; Schalter mit Beschriftung (und optionaler zweiter Zeile). cb = Funktion,
; die nach dem Umschalten aufgerufen wird.
YkUi_Toggle(x, y, w, var, text, sub := "", cb := "YkGui_Changed", size := 10) {
    global YkCol, g_Tog, g_UiBuilding
    hOn := YkUi_Add("Picture", "x" . x . " y" . y . " w40 h22 gYkUi_ToggleClick", "HBITMAP:" . YkUi_ToggleBmp(true))
    hOff := YkUi_Add("Picture", "x" . x . " y" . y . " w40 h22 gYkUi_ToggleClick", "HBITMAP:" . YkUi_ToggleBmp(false))
    hTxt := YkUi_Text(x + 50, y + 1, w - 50, text, size, "norm", "", "gYkUi_ToggleClick")
    if (sub != "")
        YkUi_Text(x + 50, y + 23, w - 50, sub, 8, "norm", YkCol.dim)
    g_Tog[var] := {on: hOn, off: hOff, txt: hTxt, val: 0, cb: cb, page: g_UiBuilding}
    YkUi_ToggleSync(var)
}

YkUi_ToggleSync(var) {
    global g_Tog
    t := g_Tog[var]
    if (!IsObject(t))
        return
    vis := YkUi_Visible(t.page)
    YkUi_ShowCtrl(t.on, vis && t.val)
    YkUi_ShowCtrl(t.off, vis && !t.val)
}

YkUi_TogglesSync() {
    global g_Tog
    for var, t in g_Tog
        YkUi_ToggleSync(var)
}

YkUi_TogGet(var) {
    global g_Tog
    return IsObject(g_Tog[var]) ? g_Tog[var].val : 0
}

YkUi_TogSet(var, val) {
    global g_Tog
    if (!IsObject(g_Tog[var]))
        return
    g_Tog[var].val := val ? 1 : 0
    YkUi_ToggleSync(var)
}

YkUi_ToggleClick() {
    global g_Tog
    MouseGetPos, , , , hw, 2
    for var, t in g_Tog {
        if (hw = t.on || hw = t.off || hw = t.txt) {
            t.val := !t.val
            YkUi_ToggleSync(var)
            if (t.cb != "") {
                f := Func(t.cb)
                if (IsObject(f))
                    f.Call()
            }
            return
        }
    }
}
