; =====================================================================
;  Yakuza Keybinder - Hauptfenster (neu in v3.0)
; ---------------------------------------------------------------------
;  Aufbau wie im Keybinder von Brooklyn 5.0: links die Navigation mit dem
;  Yakuza-Gesicht, rechts die Seite. Die Uebersicht zeigt das Yakuza-
;  Banner aus v2. Jede Aenderung wirkt sofort und wird automatisch
;  gespeichert - einen "Speichern"-Knopf gibt es nicht mehr.
;
;  Die Seiten stehen in drei Dateien:
;    YkGui.ahk        Rahmen, Navigation, Uebersicht, Hilfe, Status
;    YkGuiKeys.ahk    Tasten, Server-Befehle, Chat-Befehle, Gegnerlisten
;    YkGuiPages.ahk   Meldungen, Familie, Overlay, Sprint, Extras,
;                     Einstellungen - und Laden/Uebernehmen der Werte
; =====================================================================

global g_GuiBuilt := false, g_GuiVisible := false, g_Loading := false
global g_Nav := [], g_NavHl := {}, g_NavTxt := {}, g_NavIco := {}
global g_H := {}                    ; wichtige Handles
global g_SetSubBtns := {}
global YkMainHwnd := 0

YkGui_Pages() {
    return [["dash", "Übersicht", "E80F"], ["keys", "Tasten", "E765"], ["server", "Server-Befehle", "E8FD"]
          , ["chat", "Chat-Befehle", "E8BD"], ["enemy", "Gegnerlisten", "E716"], ["auto", "Meldungen & Kampf", "E945"]
          , ["family", "Familie & Member", "E902"], ["overlay", "Overlay", "E7F4"], ["sprint", "Sprint (Laufscript)", "E805"]
          , ["extras", "Extras", "E90F"], ["settings", "Einstellungen", "E713"], ["help", "Hilfe & Info", "E897"]]
}

YkGui_Titles() {
    return {dash: ["", ""]
        , keys: ["Tasten", "Alle belegten Tasten auf einen Blick. Eintrag anklicken, unten ändern - wirkt sofort."]
        , server: ["Server-Befehle", "Die Befehle von Life of Player. Befehl anklicken, dann Taste und/oder Kurzform vergeben."]
        , chat: ["Chat-Befehle", "Tippen + Enter. Der Buchstabe davor ist der Chat: /fkd = Family-Chat (/f), /gkd = Gang-/Mafienchat (/g), /kd = normaler Chat."]
        , enemy: ["Gegnerlisten", "Merk dir Gegner und sieh sofort, wer von ihnen online ist - ohne Befehl an den Server."]
        , auto: ["Meldungen & Kampf", "Standort, Kills und Tode im Gang-/Mafienchat (/g) - was der Binder von selbst meldet."]
        , family: ["Familie & Member", "Backup-Rufe, Fahnen auf der Karte, Ziel wählen und laufende Kriege."]
        , overlay: ["Overlay", "Die Anzeige über dem Spiel und die Meldungs-Karten."]
        , sprint: ["Sprint (Laufscript)", "Leertaste beim Laufen halten = deine Figur rennt dauerhaft schnell."]
        , extras: ["Extras", "Server-Stand (Taste N), Wanteds, Lotto, SMS, Radio und Aufnahmen."]
        , settings: ["Einstellungen", "Alles wird sofort übernommen und automatisch gespeichert."]
        , help: ["Hilfe & Info", "Kurzanleitung, was neu ist, Update und Dateien."]}
}

; Fenster zeigen (wird beim Start und per Tray/Taste aufgerufen)
YkShowGui() {
    global g_GuiBuilt, g_GuiVisible, YkGuiOpen, g_UiCur
    if (!g_GuiBuilt)
        YkGui_Build()
    Gui, Yk:Show
    g_GuiVisible := true
    YkGuiOpen := true
    YkGui_Go((g_UiCur != "") ? g_UiCur : "dash")
    YkUpdateStatus()
}

YkGui_Build() {
    global
    local i, p, y, hb, ico, icoSrc, hdr

    YkUi_Theme()
    YkDark_Init()
    Gui, Yk:New, -MaximizeBox +HwndYkMainHwnd, % "Yakuza Keybinder v" . YK_Version
    YkGuiHwnd := YkMainHwnd
    g_UiHwnd := YkMainHwnd
    Gui, Yk:Color, % YkCol.bg, % YkCol.field
    Gui, Yk:Margin, 0, 0
    YkUi_Font()
    YkUi_Page("*")

    ; ---------------- Seitenleiste mit dem Yakuza-Gesicht ----------------
    hb := YkUi_Bmp(220, 720, YkCol.side, YkCol.side, 0)
    YkUi_Add("Picture", "x0 y0 w220 h720", "HBITMAP:" . hb)
    icoSrc := A_IsCompiled ? A_ScriptFullPath : YkAssets_File("yakuza.ico")
    if (icoSrc != "")
        YkUi_Add("Picture", "x20 y22 w48 h48 Icon1 BackgroundTrans", icoSrc)
    YkUi_Text(78, 20, 140, "YAKUZA", 20, "bold", YkCol.accent)
    YkUi_Text(80, 54, 140, "K E Y B I N D E R", 7, "bold", YkCol.dim)
    YkUi_Text(80, 70, 140, "Version " . YK_Version, 8, "norm", YkCol.faint)
    for i, p in YkGui_Pages() {
        y := 104 + (i - 1) * 38
        hb := YkUi_Bmp(196, 34, YkCol.card2, YkCol.side, 9, "", YkCol.accent)
        g_NavHl[p[1]] := YkUi_Add("Picture", "x12 y" . y . " w196 h34 gYkNav_Click Hidden", "HBITMAP:" . hb)
        g_NavIco[p[1]] := YkUi_Icon(30, y + 9, p[3], 11, YkCol.dim, "gYkNav_Click")
        g_NavTxt[p[1]] := YkUi_Text(58, y + 8, 146, p[2], 10, "norm", YkCol.dim, "gYkNav_Click")
        g_Nav.Push(p[1])
    }
    ; Status unten
    hb := YkUi_Bmp(196, 124, "15151A", YkCol.side, 12, YkCol.line)
    YkUi_Add("Picture", "x12 y582 w196 h124", "HBITMAP:" . hb)
    g_H.dot := YkUi_Text(24, 592, 18, "●", 10, "norm", YkCol.faint)
    g_H.state := YkUi_Text(42, 593, 160, "Startet ...", 9, "bold")
    g_H.game := YkUi_Text(24, 614, 180, "Spiel nicht gestartet", 8, "norm", YkCol.dim)
    g_H.log := YkUi_Text(24, 630, 180, "", 8, "norm", YkCol.dim)
    g_H.pauseBtn := YkUi_Button(24, 656, 172, 36, "Pausieren", "YkGui_PauseClick", "ghost", "15151A")

    ; ---------------- Kopfzeile ----------------
    g_H.title := YkUi_Text(244, 22, 600, "", 20, "bold")
    g_H.subtitle := YkUi_Text(246, 60, 850, "", 10, "norm", YkCol.dim)
    g_H.toast := YkUi_Text(640, 30, 460, "", 9, "norm", YkCol.accent2, "Right")

    YkGui_BuildDash()
    YkGui_BuildKeys()
    YkGui_BuildServer()
    YkGui_BuildChat()
    YkGui_BuildEnemy()
    YkGui_BuildAuto()
    YkGui_BuildFamily()
    YkGui_BuildOverlay()
    YkGui_BuildSprint()
    YkGui_BuildExtras()
    YkGui_BuildSettings()
    YkGui_BuildHelp()

    YkGui_LoadValues()
    YkDark_Apply(YkMainHwnd)
    YkDark_Window(YkMainHwnd)
    Gui, Yk:Show, w1120 h720 Hide
    g_GuiBuilt := true
    OnMessage(0x200, "YkGui_MouseMove")
}

YkGui_Go(page, sub := "") {
    global g_Nav, g_NavHl, g_NavTxt, g_NavIco, g_H, YkCol, g_UiCur
    for i, p in g_Nav {
        on := (p = page)
        YkUi_ShowCtrl(g_NavHl[p], on)
        Gui, Yk:Font, % "s10 " . (on ? "bold" : "norm") . " c" . (on ? YkCol.text : YkCol.dim), Segoe UI
        GuiControl, Yk:Font, % g_NavTxt[p]
        Gui, Yk:Font, % "s11 norm c" . (on ? YkCol.accent : YkCol.dim), % YkUi_IconFont()
        GuiControl, Yk:Font, % g_NavIco[p]
    }
    YkUi_Font()
    t := YkGui_Titles()[page]
    ControlSetText, , % t[1], % "ahk_id " . g_H.title
    ControlSetText, , % t[2], % "ahk_id " . g_H.subtitle
    YkUi_Show(page, sub)
    for i, p in g_Nav
        YkUi_ShowCtrl(g_NavHl[p], p = page)
    if (page = "dash")
        YkGui_DashRefresh(true)
    else if (page = "keys")
        YkGui_KeysFill()
    else if (page = "server")
        YkGui_CmdFill()
    else if (page = "chat")
        YkGui_TbFill()
    else if (page = "enemy")
        YkGui_EnemyRefresh()
    else if (page = "family") {
        YkMemLV_Fill()
        YkGui_WarsRefresh()
    } else if (page = "overlay")
        YkGui_OvKeysFill()
    else if (page = "extras")
        YkGui_ExtrasRefresh()
    else if (page = "settings") {
        YkGui_SetSubRefresh()
        YkGui_DiagRefresh(true)
    }
}

YkNav_Click() {
    global g_Nav, g_NavHl, g_NavTxt, g_NavIco
    MouseGetPos, , , , hw, 2
    for i, p in g_Nav
        if (hw = g_NavHl[p] || hw = g_NavTxt[p] || hw = g_NavIco[p])
            return YkGui_Go(p)
}

; Handcursor ueber klickbaren Flaechen
YkGui_MouseMove(wParam, lParam, msg, hwnd) {
    static hand := 0
    if (!hand)
        hand := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32649, "Ptr")
    if (A_Gui != "Yk")
        return
    WinGetClass, cls, ahk_id %hwnd%
    if (cls = "Static") {
        st := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -16, "Int")
        if (st & 0x100)                       ; SS_NOTIFY = klickbar
            DllCall("SetCursor", "Ptr", hand)
    }
}

; Kurze Rueckmeldung oben rechts im Fenster
YkGui_Toast(msg) {
    global g_H, g_GuiBuilt
    if (!g_GuiBuilt)
        return
    YkUi_Set(g_H.toast, msg)
    SetTimer, YkGui_ToastClear, -4000
}

YkGui_ToastClear() {
    global g_H
    YkUi_Set(g_H.toast, "")
}

YkGui_Hwnd(var) {
    GuiControlGet, h, Yk:Hwnd, %var%
    return h
}

; Eingabefeld mit grauem Hinweistext
YkGui_Cue(var, text) {
    DllCall("SendMessage", "Ptr", YkGui_Hwnd(var), "UInt", 0x1501, "Int", 1, "WStr", text)
}

; Beschriftung + Eingabefeld in einer Zeile
YkGui_Field(x, y, labelW, label, fieldW, var, opts := "", ctrl := "Edit", items := "") {
    global YkCol
    YkUi_Text(x, y + 4, labelW, label, 10)
    if (ctrl = "Edit")
        return YkUi_Add("Edit", "x" . (x + labelW) . " y" . y . " w" . fieldW . " h24 v" . var . " gYkGui_Changed -E0x200 Border " . opts, items)
    if (ctrl = "Hotkey")
        return YkUi_Add("Hotkey", "x" . (x + labelW) . " y" . y . " w" . fieldW . " h24 v" . var . " gYkGui_Changed " . opts, items)
    return YkUi_Add(ctrl, "x" . (x + labelW) . " y" . y . " w" . fieldW . " v" . var . " gYkGui_Changed " . opts, items)
}

YkGuiClose() {
    global g_GuiVisible
    Gui, Yk:Hide
    g_GuiVisible := false
}

YkGuiEscape() {
    YkGuiClose()
}

; =====================================================================
;  Seite: Uebersicht
; =====================================================================
YkGui_BuildDash() {
    global
    local i, t, x, hb, hdr
    YkUi_Page("dash")
    ; ---- Yakuza-Banner aus v2, abgerundet ----
    hdr := YkAssets_File("yakuza_header.jpg")
    hb := (hdr != "") ? YkUi_ImageBmp(hdr, 860, 108, 14, YkCol.bg) : YkUi_Bmp(860, 108, "16161B", YkCol.bg, 14)
    YkUi_Add("Picture", "x240 y18 w860 h108", "HBITMAP:" . hb)
    YkUi_Text(268, 36, 520, "YAKUZA KEYBINDER", 22, "bold", "FFFFFF")
    YkUi_Text(270, 80, 520, "Yakuza Family  ·  Life of Player  ·  v" . YK_Version, 10, "norm", "C9C9D2")
    g_H.bannerState := YkUi_Text(270, 100, 480, "", 8, "norm", YkCol.accent2)

    for i, t in [["kills", "Kills heute", "E7C1"], ["tode", "Tode heute", "E8BB"], ["kd", "K/D heute", "E9D2"], ["zeit", "Spielzeit heute", "E823"]] {
        x := 240 + (i - 1) * 220
        YkUi_Card(x, 142, 200, 92)
        YkUi_Icon(x + 18, 157, t[3], 11, YkCol.accent)
        YkUi_Text(x + 42, 155, 150, t[2], 9, "norm", YkCol.dim)
        g_H["kpi_" . t[1]] := YkUi_Text(x + 18, 175, 170, "0", 20, "bold")
        g_H["kpis_" . t[1]] := YkUi_Text(x + 18, 210, 176, "", 8, "norm", YkCol.faint)
    }

    YkUi_Card(240, 250, 420, 276, "Statistik", "E9D2")
    Gui, Yk:Font, % "s9 norm c" . YkCol.text, Segoe UI
    YkUi_Add("ListView", "-E0x200 x256 y288 w388 h176 vYkG_LvStats -Multi NoSort NoSortHdr ReadOnly LV0x10000 Background" . YkCol.card . " c" . YkCol.text, "Wert|Sitzung|Heute|Monat|Gesamt")
    g_H.srvStat := YkUi_Text(258, 472, 390, "", 8, "norm", YkCol.dim, "h44")

    YkUi_Card(680, 250, 420, 276, "Im Spiel", "E7FC")
    for i, t in [["loc", "Standort"], ["hp", "Leben / Rüstung"], ["veh", "Unterwegs"], ["ziel", "Ziel"], ["ruf", "Letzter Ruf"], ["mem", "Member"], ["war", "Kriege"]] {
        YkUi_Text(700, 290 + (i - 1) * 30, 120, t[2], 9, "norm", YkCol.dim)
        g_H["live_" . t[1]] := YkUi_Text(820, 290 + (i - 1) * 30, 262, "–", 9, "norm", "", (t[1] = "war") ? "h34" : "")
    }

    YkUi_Card(240, 542, 420, 158, "Schnellzugriff", "E768")
    YkUi_Button(258, 582, 122, 40, "Spiel starten", "YkGui_RunGame", "primary")
    g_H.ovBtn := YkUi_Button(389, 582, 122, 40, "Overlay", "YkGui_QuickOverlay")
    g_H.memBtn := YkUi_Button(520, 582, 122, 40, "Member", "YkGui_QuickMembers")
    g_H.sprintBtn := YkUi_Button(258, 634, 122, 40, "Sprint", "YkGui_QuickSprint")
    g_H.radioBtn := YkUi_Button(389, 634, 122, 40, "Radio ▶", "YkGui_RadioToggle")
    g_H.timerBtn := YkUi_Button(520, 634, 122, 40, "Timer 5 Min", "YkGui_Timer5")
    g_H.timer := YkUi_Text(420, 556, 222, "", 8, "norm", YkCol.dim, "Right")

    YkUi_Card(680, 542, 420, 158, "Letzte Meldungen", "E8BD")
    YkUi_Add("ListView", "-E0x200 x696 y578 w388 h110 vYkG_LvLog -Hdr -Multi NoSort ReadOnly LV0x10000 Background" . YkCol.card . " c" . YkCol.dim, "Zeit|Meldung")
    Gui, Yk:ListView, YkG_LvLog
    LV_ModifyCol(1, 62), LV_ModifyCol(2, 306)
    YkUi_Font()
}

; Werte der Uebersicht (hoechstens einmal pro Sekunde, nur wenn sichtbar)
YkGui_DashRefresh(force := false) {
    global g_GuiBuilt, g_GuiVisible, g_H, g_UiCur, g_CntVer, g_SessKills, g_SessDeaths
    global g_Target, g_LastCall, g_Members, YK_OvEnabled, YK_MemShow, YK_SprintEnabled
    static lastVer := -1, lastDay := "", lastStat := ""
    ; nicht unterbrechen: ein Listen-Ereignis dazwischen wuerde die
    ; gewaehlte Liste umstellen (die Auswahl gilt je Fenster, nicht je Thread)
    wasCrit := A_IsCritical
    Critical
    if (!g_GuiBuilt || (!force && (!g_GuiVisible || g_UiCur != "dash")))
        return YkGui_CritEnd(wasCrit)
    YkUi_Set(g_H.kpi_kills, YkNum(YkCnt_Kills("T")))
    YkUi_Set(g_H.kpis_kills, "Monat " . YkNum(YkCnt_Kills("M")) . "  ·  gesamt " . YkNum(YkStats_Kills()))
    YkUi_Set(g_H.kpi_tode, YkNum(YkCnt_Deaths("T")))
    YkUi_Set(g_H.kpis_tode, "Monat " . YkNum(YkCnt_Deaths("M")) . "  ·  gesamt " . YkNum(YkStats_Deaths()))
    YkUi_Set(g_H.kpi_kd, Format("{:.2f}", YkCnt_KD("T")))
    YkUi_Set(g_H.kpis_kd, "Monat " . Format("{:.2f}", YkCnt_KD("M")) . "  ·  gesamt " . Format("{:.2f}", YkCnt_KD("G")))
    YkUi_Set(g_H.kpi_zeit, YkDurShort(YkCnt_Get("spielzeit", "T")))
    YkUi_Set(g_H.kpis_zeit, "gesamt " . YkDurShort(YkCnt_Get("spielzeit")))
    YkUi_Set(g_H.srvStat, "Server-Stand (Taste N): " . YkStats_Text())

    sig := g_CntVer . "|" . g_SessKills . "|" . g_SessDeaths . "|" . A_DD . "|" . YkStats_Kills() . "|" . YkStats_Deaths()
    if (force || sig != lastStat) {
        lastStat := sig
        Gui, Yk:Default
        Gui, Yk:ListView, YkG_LvStats
        GuiControl, Yk:-Redraw, YkG_LvStats
        LV_Delete()
        sk := g_SessKills + 0, sd := g_SessDeaths + 0
        LV_Add("", "Kills", YkNum(sk), YkNum(YkCnt_Kills("T")), YkNum(YkCnt_Kills("M")), YkNum(YkStats_Kills()))
        LV_Add("", "Tode", YkNum(sd), YkNum(YkCnt_Deaths("T")), YkNum(YkCnt_Deaths("M")), YkNum(YkStats_Deaths()))
        LV_Add("", "Differenz", YkNum(sk - sd), YkNum(YkCnt_Diff("T")), YkNum(YkCnt_Diff("M")), YkNum(YkCnt_Diff("G")))
        LV_Add("", "K/D", Format("{:.2f}", sk / (sd > 0 ? sd : 1)), Format("{:.2f}", YkCnt_KD("T")), Format("{:.2f}", YkCnt_KD("M")), Format("{:.2f}", YkCnt_KD("G")))
        LV_Add("", "Spielzeit", "", YkDurShort(YkCnt_Get("spielzeit", "T")), YkDurShort(YkCnt_Get("spielzeit", "M")), YkDurShort(YkCnt_Get("spielzeit")))
        LV_Add("", "Logins", "", YkNum(YkCnt_Get("logins", "T")), YkNum(YkCnt_Get("logins", "M")), YkNum(YkCnt_Get("logins")))
        LV_Add("", "SMS erhalten", "", YkNum(YkCnt_Get("sms_in", "T")), YkNum(YkCnt_Get("sms_in", "M")), YkNum(YkCnt_Get("sms_in")))
        LV_ModifyCol(1, 104), LV_ModifyCol(2, "64 Right"), LV_ModifyCol(3, "64 Right"), LV_ModifyCol(4, "72 Right"), LV_ModifyCol(5, "80 Right")
        GuiControl, Yk:+Redraw, YkG_LvStats
    }

    ; ---- Im Spiel ----
    if (YkGame_Hwnd()) {
        pos := YkCurrentPos()
        YkUi_Set(g_H.live_loc, IsObject(pos) ? YkZone_Describe(pos) : "unbekannt")
        hp := YkMem_GetHealth(), ar := YkMem_GetArmor()
        YkUi_Set(g_H.live_hp, (hp >= 0) ? hp . " HP  ·  " . ((ar >= 0) ? ar : "?") . " Rüstung" : "–")
        inV := YkMem_InVehicle()
        YkUi_Set(g_H.live_veh, (inV = -1) ? "–" : (inV = true) ? "im " . YkVehText() : "zu Fuß")
    } else {
        YkUi_Set(g_H.live_loc, "Spiel nicht gestartet")
        YkUi_Set(g_H.live_hp, "–")
        YkUi_Set(g_H.live_veh, "–")
    }
    YkUi_Set(g_H.live_ziel, IsObject(g_Target) ? g_Target.name . "  ·  " . g_Target.loc : "keins gewählt")
    YkUi_Set(g_H.live_ruf, IsObject(g_LastCall) ? g_LastCall.name . "  ·  " . g_LastCall.loc . "  (" . YkAgeText(g_LastCall.t) . ")" : "–")
    n := 0
    for name, o in g_Members
        n += 1
    YkUi_Set(g_H.live_mem, n ? n . " in der Liste" . (YK_MemShow ? "" : "  (Anzeige aus)") : "noch keine Positionen")
    wl := YkWar_List()
    wt := ""
    for i, w in wl {
        if (i > 2)
            break
        wt .= (wt = "" ? "" : "`n") . w.text
    }
    YkUi_Set(g_H.live_war, (wt = "") ? "kein Krieg" : wt)

    ; Knoepfe zeigen den Zustand
    YkUi_Set(g_H.ovBtn.txt, "Overlay " . (YK_OvEnabled ? "an" : "aus"))
    YkUi_Set(g_H.memBtn.txt, "Member " . (YK_MemShow ? "an" : "aus"))
    YkUi_Set(g_H.sprintBtn.txt, "Sprint " . (YK_SprintEnabled ? "an" : "aus"))
    YkGui_CritEnd(wasCrit)
}

YkDurShort(sec) {
    sec := Round(YkN(sec))
    h := sec // 3600, m := Mod(sec // 60, 60)
    return (h > 0) ? h . " h " . m . " min" : m . " min"
}

; Neue Meldung in der Liste "Letzte Meldungen"
YkGui_LogMsg(t, text, kind) {
    global g_GuiBuilt
    ; nicht unterbrechen: ein Listen-Ereignis dazwischen wuerde die
    ; gewaehlte Liste umstellen (die Auswahl gilt je Fenster, nicht je Thread)
    wasCrit := A_IsCritical
    Critical
    if (!g_GuiBuilt)
        return YkGui_CritEnd(wasCrit)
    Gui, Yk:Default
    Gui, Yk:ListView, YkG_LvLog
    LV_Insert(1, "", t, StrReplace(text, "`n", "  ·  "))
    while (LV_GetCount() > 60)
        LV_Delete(LV_GetCount())
    YkGui_CritEnd(wasCrit)
}

YkGui_RunGame() {
    YkRunGame()
}

YkGui_QuickOverlay() {
    YkOverlay_Toggle()
    YkGui_DashRefresh(true)
}

YkGui_QuickMembers() {
    YkMembers_Toggle()
    YkGui_DashRefresh(true)
}

YkGui_QuickSprint() {
    global YK_SprintEnabled, YK_IniPath
    YK_SprintEnabled := !YK_SprintEnabled
    IniWrite, % (YK_SprintEnabled ? 1 : 0), % YK_IniPath, Sprint, Enabled
    YkNotify("Sprint-Automatik: " . (YK_SprintEnabled ? "AN" : "AUS"))
    YkGui_SyncState()
    YkGui_DashRefresh(true)
}

YkGui_RadioToggle() {
    YkFn_RadioToggle()
}

YkGui_RadioRefresh() {
    global g_H, g_RadioOn, g_GuiBuilt
    if (g_GuiBuilt) {
        YkUi_Set(g_H.radioBtn.txt, g_RadioOn ? "Radio ■" : "Radio ▶")
        YkUi_Set(g_H.radioPlay.txt, g_RadioOn ? "Stopp" : "Abspielen")
    }
}

YkGui_Timer5() {
    if (YkTimer_Left() >= 0) {
        YkTimer_Stop()
        YkGui_TimerRefresh()
        return
    }
    YkTimer_Start(5)
    YkGui_TimerRefresh()
}

YkGui_TimerRefresh() {
    global g_H, g_GuiBuilt
    if (!g_GuiBuilt)
        return
    l := YkTimer_Left()
    YkUi_Set(g_H.timer, (l >= 0) ? "Timer: noch " . (l // 60) . ":" . Format("{:02}", Mod(l, 60)) : "")
    YkUi_Set(g_H.timerBtn.txt, (l >= 0) ? "Timer stoppen" : "Timer 5 Min")
}

; =====================================================================
;  Seite: Hilfe & Info
; =====================================================================
YkGui_BuildHelp() {
    global
    local icoSrc, t
    YkUi_Page("help")
    YkUi_Card(240, 100, 540, 600, "Kurzanleitung", "E897")
    t := "1.  Keybinder starten, GTA starten, einloggen - fertig. Unten links steht, ob das Spiel erkannt wurde.`n`n"
       . "2.  TASTEN: Strg+G Standort · Strg+K Kill melden · Strg+M /familymap · Strg+O Overlay · Strg+P Member · Strg+Leertaste Sprint · Strg+Num1-4 Backup, Komme, Sammeln, Unterwegs.`n`n"
       . "3.  SPRINT: Leertaste beim Laufen halten - die Figur rennt dauerhaft. Ducken (C) unterbricht, bis du die Leertaste neu drückst.`n`n"
       . "4.  KURZFORMEN: /uc wird sofort zu /use cannabis (Server-Befehle). /ykzu Name + Leertaste setzt ein Ziel.`n`n"
       . "5.  CHAT-BEFEHLE: im Chat tippen und Enter drücken. Der Buchstabe davor ist der Chat: /fkd = Family-Chat (/f), /gkd = Gang-/Mafienchat (/g), /kd = normaler Chat. Dazu /re, /stopuhr, /rec ... Wird nichts erkannt, geht Enter ganz normal ans Spiel.`n`n"
       . "6.  GEGNERLISTEN (neu): Liste anlegen (z.B. Kürzel vla), dann im Spiel /vlaadd 12, /vla = wer ist online.`n`n"
       . "7.  Während du tippst, ruhen alle Tasten. Die Pause-Taste schaltet den ganzen Binder aus und wieder an.`n`n"
       . "8.  Im echten Vollbild zeigt Windows kein Fenster über dem Spiel - Overlay und Karten ruhen dann. Randloses Fenster funktioniert."
    YkUi_Text(262, 142, 500, t, 10, "norm", "", "h500")
    YkUi_Card(800, 100, 300, 300, "Über", "E946")
    icoSrc := A_IsCompiled ? A_ScriptFullPath : YkAssets_File("yakuza.ico")
    if (icoSrc != "")
        YkUi_Add("Picture", "x890 y144 w120 h120 Icon1 BackgroundTrans", icoSrc)
    YkUi_Text(820, 276, 260, "Yakuza Keybinder " . YK_Version, 11, "bold", "", "Center")
    YkUi_Text(820, 302, 260, "Yakuza Family  ·  Life of Player`nSA-MP 0.3.7 R1 / R3 / R5 und 0.3.DL", 9, "norm", YkCol.dim, "Center h40")
    YkUi_Text(820, 352, 260, "Nur lesend - nichts wird ins Spiel eingeschleust.", 8, "norm", YkCol.faint, "Center")
    YkUi_Card(800, 416, 300, 284, "Dateien", "E8B7")
    YkUi_Button(820, 456, 260, 36, "Anleitung öffnen", "YkGui_Manual", "primary")
    YkUi_Button(820, 500, 260, 36, "Was ist neu?", "YkGui_WhatsNew")
    YkUi_Button(820, 544, 260, 36, "Einstellungsdatei öffnen", "YkGui_OpenIni")
    YkUi_Button(820, 588, 260, 36, "Ordner öffnen", "YkGui_OpenDir")
    YkUi_Button(820, 632, 260, 36, "Nach Update suchen", "YkGui_UpdCheck")
    YkUi_Font()
}

YkGui_Manual() {
    doc := A_ScriptDir . "\ANLEITUNG.txt"
    if FileExist(doc)
        Run, % "notepad.exe """ . doc . """"
    else
        MsgBox, 48, Anleitung fehlt, Die Datei ANLEITUNG.txt liegt nicht neben dem Keybinder.`nSie gehört mit in den Ordner.
}

YkGui_OpenIni() {
    global YK_IniPath
    Run, % "notepad.exe """ . YK_IniPath . """"
}

YkGui_OpenDir() {
    Run, % "explorer.exe """ . A_ScriptDir . """"
}

; Beim ersten Start nach dem Update von v2 (und ueber "Hilfe")
YkGui_WhatsNew() {
    global YK_Version
    t := "Yakuza Keybinder " . YK_Version . " - was ist neu?`n`n"
       . YkGui_PatchNotes() . "`n`n"
       . "NEU IN v3.0:`n"
       . "Alles aus v2 ist geblieben: deine Tasten, Texte, Server-Befehle, Kurzformen, Kill- und Tod-Meldungen, Backup-Fahnen, Kriege, Member-Positionen, Overlay, Sprint, Wanteds, Lotto und das automatische Update.`n`n"
       . "·  Neues Fenster - links die Seiten, rechts die Einstellungen. Alles wirkt sofort.`n"
       . "·  Chat-Befehle: /fkd /gkd /kd, /fja /gok ..., /infokill, /tode, /otime, /re (SMS beantworten), /stopuhr, /zeit, /chillen, 7f + Leertaste = /f.`n"
       . "·  Statistik heute / Monat / gesamt und Spielzeit (Übersicht).`n"
       . "·  Gegnerlisten mit Online-Prüfung (Seite Gegnerlisten).`n"
       . "·  Meldungen als kleine Karten im Spiel, 15-s-Countdown, Radio.`n"
       . "·  Neue Funktionstasten: Pause (Taste Pause), Fenster, Tasten lösen, Zeile wiederholen ...`n`n"
       . "Deine Einstellungen aus v2 wurden übernommen. Alles Weitere steht in der ANLEITUNG.txt."
    MsgBox, 64, Was ist neu?, %t%
}

YkGui_PatchNotes() {
    return "NEU IN v3.0.1:`n"
       . "·  Chat-Befehle nach den Chats von Life of Player: der Buchstabe davor ist der Chat.`n"
       . "      /f... = Family-Chat der Organisation (/fkd, /fja, /fok, /fwo, /fpos ...)`n"
       . "      /g... = Gang-/Mafienchat (/gkd, /gja, /gok, /gwo, /gpos ...)`n"
       . "      ohne Buchstaben = normaler Chat (/kd, /ja, /ok ...)`n"
       . "   ACHTUNG: /kd, /ja, /ok ... gehen jetzt in den normalen Chat, nicht mehr in /f.`n"
       . "·  /cd, /fcd, /gcd: Countdown 3 - 2 - 1 - LOS (Text änderbar).`n"
       . "·  Aufnahmen lassen sich jetzt auch beenden: /rec startet, /recstop beendet, /frag und /beschwerde beenden und legen das Video ab. Start- und Stopp-Taste unter Extras > Aufnahmen (z.B. F9 oder Alt+F9)."
}

; Nach einem Update innerhalb von v3 (z.B. 3.0.0 -> 3.0.1) einmal zeigen
YkGui_WhatsNewPatch() {
    global YK_Version
    t := "Yakuza Keybinder " . YK_Version . " - was ist neu?`n`n" . YkGui_PatchNotes()
    MsgBox, 64, Was ist neu?, %t%
}

; =====================================================================
;  Statuszeile (Seitenleiste unten) - aus dem 250-ms-Takt
; =====================================================================
YkUpdateStatus() {
    global g_GuiBuilt, g_GuiVisible, g_H, YK_Paused, g_ChatOpen, g_ChatlogFile, g_SampKnown, g_GuiMsg, g_GuiMsgT, YkCol
    static lastDot := ""
    if (!g_GuiBuilt || !g_GuiVisible)
        return
    if (YK_Paused)
        st := "PAUSIERT", col := YkCol.warn
    else if (YkDeath_Waiting())
        st := "Bewusstlos - Meldung wartet", col := YkCol.warn
    else if (g_ChatOpen)
        st := "Chat offen - Tasten ruhen", col := YkCol.gold
    else if (YkGame_Hwnd())
        st := "AKTIV", col := YkCol.ok
    else
        st := "Bereit", col := YkCol.faint
    YkUi_Set(g_H.state, st)
    if (col != lastDot) {
        lastDot := col
        Gui, Yk:Font, % "s10 norm c" . col, Segoe UI
        GuiControl, Yk:Font, % g_H.dot
        YkUi_Font()
        YkUi_Repaint(g_H.dot)
    }
    if (g_SampKnown)
        game := "SA-MP " . YkSamp_VersionName() . " erkannt"
    else if YkGame_Hwnd()
        game := "Spiel erkannt (Tasten-Erkennung)"
    else
        game := "Spiel nicht gestartet"
    YkUi_Set(g_H.game, game)
    log := (g_ChatlogFile != "" && FileExist(g_ChatlogFile)) ? "Chatlog gefunden" : "Chatlog fehlt"
    ov := YkOverlay_MayBuild() ? "" : (YkGame_Hwnd() ? "  ·  Overlay ruht" : "")
    YkUi_Set(g_H.log, log . ov)
    YkUi_Set(g_H.pauseBtn.txt, YK_Paused ? "Fortsetzen" : "Pausieren")
    ; Meldung im Kopf des Fensters
    if (g_GuiMsg != "" && (A_TickCount - g_GuiMsgT) < 5000)
        YkUi_Set(g_H.toast, YkShorten(g_GuiMsg, 90))
    else {
        upd := YkUpd_Badge()
        YkUi_Set(g_H.toast, (upd != "") ? "● " . upd : "")
    }
}

; Was ausserhalb des Fensters umgeschaltet wurde (Strg+O, Strg+P, Sprint,
; Pause, gelernter Name), sofort auch im Fenster zeigen
YkGui_SyncState() {
    global g_GuiBuilt, g_Loading, YK_OvEnabled, YK_MemShow, YK_SprintEnabled, YK_OwnName
    if (!g_GuiBuilt)
        return
    g_Loading := true
    YkUi_TogSet("YkG_OvOn", YK_OvEnabled)
    YkUi_TogSet("YkG_OvMem", YK_MemShow)
    YkUi_TogSet("YkG_Sprint", YK_SprintEnabled)
    GuiControlGet, cur, Yk:, YkG_OwnName
    if (Trim(cur) != YK_OwnName)
        GuiControl, Yk:, YkG_OwnName, % YK_OwnName
    g_Loading := false
    YkUpdateStatus()
    YkGui_DashRefresh()
}

YkGui_PauseClick() {
    YkTogglePause()
    YkUpdateStatus()
}

; Sekunden-Takt: nur die sichtbare Seite nachziehen
YkGui_SecTick() {
    global g_GuiBuilt, g_GuiVisible, g_UiCur, YkMainHwnd
    static memT := 0
    if (!g_GuiBuilt || !g_GuiVisible)
        return
    if (!DllCall("IsWindowVisible", "Ptr", YkMainHwnd)) {
        g_GuiVisible := false
        return
    }
    if (g_UiCur = "dash") {
        YkGui_DashRefresh()
        YkGui_TimerRefresh()
    } else if (g_UiCur = "family") {
        if ((A_TickCount - memT) > 5000) {
            memT := A_TickCount
            YkMemLV_Fill()
        }
        YkGui_WarsRefresh()
    } else if (g_UiCur = "extras") {
        YkGui_ExtrasRefresh()
    } else if (g_UiCur = "settings") {
        YkGui_DiagRefresh()
    }
}

; Ende eines nicht unterbrechbaren Abschnitts (siehe oben). Gibt v zurueck,
; damit "return YkGui_CritEnd(wasCrit, wert)" moeglich ist.
YkGui_CritEnd(wasCrit, v := "") {
    if (!wasCrit)
        Critical, Off
    return v
}
