; =====================================================================
;  Brooklyn Keybinder - Hauptfenster
; ---------------------------------------------------------------------
;  Links die Navigation, rechts die Seite. Jede Aenderung wirkt sofort
;  und wird automatisch gespeichert - es gibt keinen "Speichern"-Knopf.
; =====================================================================

global g_GuiBuilt := false, g_GuiVisible := false, g_Loading := false
global g_Nav := [], g_NavHl := {}, g_NavTxt := {}, g_NavIco := {}
global g_KeysSel := "", g_ChatSel := "", g_EnemySel := "", g_KeysRows := [], g_ChatRows := []
global g_ProfCards := {}
global g_H := {}                    ; wichtige Handles
global g_SetSubs := [], g_SetSubBtns := {}

BkGui_Pages() {
    return [["dash", "Übersicht", "E80F"], ["profil", "Profil & Job", "E77B"], ["keys", "Tasten", "E765"]
          , ["chat", "Chat-Befehle", "E8BD"], ["enemy", "Gegnerlisten", "E716"], ["auto", "Automatik", "E945"]
          , ["settings", "Einstellungen", "E713"], ["help", "Hilfe & Info", "E946"]]
}

BkGui_Show() {
    global g_GuiBuilt, g_GuiVisible
    if (!g_GuiBuilt)
        BkGui_Build()
    BkGui_StatsRefresh()
    BkGui_StatusRefresh()
    Gui, Bk:Show
    g_GuiVisible := true
}

BkGui_Build() {
    global
    local i, p, y, h, hb, list, g, txt, x, n, w, col

    BkUi_Theme()
    BkDark_Init()
    Gui, Bk:New, -MaximizeBox +HwndBkMainHwnd, Brooklyn Keybinder
    g_UiHwnd := BkMainHwnd
    Gui, Bk:Color, % BkC.bg, % BkC.field
    Gui, Bk:Margin, 0, 0
    BkUi_Font()
    BkUi_Page("*")

    ; ---------------- Seitenleiste ----------------
    hb := BkUi_Bmp(220, 720, BkC.side, BkC.side, 0)
    BkUi_Add("Picture", "x0 y0 w220 h720", "HBITMAP:" . hb)
    BkUi_Text(26, 26, 180, "BROOKLYN", 20, "bold", BkC.accent)
    BkUi_Text(28, 60, 180, "K E Y B I N D E R", 8, "bold", BkC.dim)
    BkUi_Text(28, 78, 180, "Version " . BK_Version, 8, "norm", BkC.faint)
    for i, p in BkGui_Pages() {
        y := 116 + (i - 1) * 46
        hb := BkUi_Bmp(196, 40, BkC.card2, BkC.side, 10, "", BkC.accent)
        g_NavHl[p[1]] := BkUi_Add("Picture", "x12 y" . y . " w196 h40 gBkNav_Click Hidden", "HBITMAP:" . hb)
        g_NavIco[p[1]] := BkUi_Icon(32, y + 11, p[3], 12, BkC.dim, "gBkNav_Click")
        g_NavTxt[p[1]] := BkUi_Text(62, y + 10, 140, p[2], 10, "norm", BkC.dim, "gBkNav_Click")
        g_Nav.Push(p[1])
    }
    ; Status unten
    hb := BkUi_Bmp(196, 150, "14171D", BkC.side, 12, BkC.line)
    BkUi_Add("Picture", "x12 y556 w196 h150", "HBITMAP:" . hb)
    g_H.dot := BkUi_Text(26, 568, 20, "●", 10, "norm", BkC.faint)
    g_H.game := BkUi_Text(44, 569, 156, "Spiel nicht gestartet", 9, "bold")
    g_H.samp := BkUi_Text(26, 590, 176, "SA-MP: –", 8, "norm", BkC.dim)
    g_H.prof := BkUi_Text(26, 608, 176, "", 8, "norm", BkC.dim, "h28")
    g_H.pauseBtn := BkUi_Button(26, 652, 168, 38, "Pausieren", "BkGui_PauseClick", "ghost", "14171D")

    ; ---------------- Kopfzeile ----------------
    g_H.title := BkUi_Text(244, 22, 600, "", 20, "bold")
    g_H.subtitle := BkUi_Text(246, 60, 840, "", 10, "norm", BkC.dim)
    g_H.toast := BkUi_Text(700, 30, 396, "", 9, "norm", BkC.accent, "Right")

    BkGui_BuildDash()
    BkGui_BuildProfile()
    BkGui_BuildKeys()
    BkGui_BuildChat()
    BkGui_BuildEnemy()
    BkGui_BuildAuto()
    BkGui_BuildSettings()
    BkGui_BuildHelp()

    BkGui_LoadValues()
    BkDark_Apply(BkMainHwnd)
    BkDark_Window(BkMainHwnd)
    Gui, Bk:Show, w1120 h720 Hide
    g_GuiBuilt := true
    BkGui_Go("dash")
    OnMessage(0x200, "BkGui_MouseMove")
}

BkGui_Titles() {
    return {dash: ["Übersicht", "Deine Statistik, Finanzen und Schnellstart auf einen Blick."]
        , profil: ["Profil & Job", "Wähle Fraktion und Job - der Binder aktiviert nur die Befehle, die zu dir passen."]
        , keys: ["Tasten", "Lege für jede Aktion eine Taste fest. Doppelklick oder Auswahl öffnet den Editor unten."]
        , chat: ["Chat-Befehle", "Im Spiel in den Chat tippen und mit Enter ausführen, z.B. /kd oder /wp."]
        , enemy: ["Gegnerlisten", "Merk dir Gegner und sieh sofort, wer von ihnen online ist."]
        , auto: ["Automatik", "Was der Binder von selbst zählt und meldet."]
        , settings: ["Einstellungen", "Alles wird sofort übernommen und automatisch gespeichert."]
        , help: ["Hilfe & Info", "Kurzanleitung, Diagnose und was neu ist."]}
}

BkGui_Go(page, sub := "") {
    global g_Nav, g_NavHl, g_NavTxt, g_NavIco, g_H, BkC, g_UiCur
    for i, p in g_Nav {
        on := (p = page)
        BkUi_ShowCtrl(g_NavHl[p], on)
        Gui, Bk:Font, % "s10 " . (on ? "bold" : "norm") . " c" . (on ? BkC.text : BkC.dim), Segoe UI
        GuiControl, Bk:Font, % g_NavTxt[p]
        Gui, Bk:Font, % "s12 norm c" . (on ? BkC.accent : BkC.dim), % BkUi_IconFont()
        GuiControl, Bk:Font, % g_NavIco[p]
    }
    BkUi_Font()
    t := BkGui_Titles()[page]
    ControlSetText, , % t[1], % "ahk_id " . g_H.title
    ControlSetText, , % t[2], % "ahk_id " . g_H.subtitle
    BkUi_Show(page, sub)
    for i, p in g_Nav
        BkUi_ShowCtrl(g_NavHl[p], p = page)
    if (page = "dash")
        BkGui_StatsRefresh(true)
    else if (page = "profil")
        BkGui_ProfileRefresh()
    else if (page = "keys")
        BkGui_KeysFill()
    else if (page = "chat")
        BkGui_ChatFill()
    else if (page = "enemy")
        BkGui_EnemyRefresh()
    else if (page = "settings")
        BkGui_SetSubRefresh()
    else if (page = "help")
        BkGui_DiagRefresh()
}

BkNav_Click() {
    global g_Nav, g_NavHl, g_NavTxt, g_NavIco
    MouseGetPos, , , , hw, 2
    for i, p in g_Nav
        if (hw = g_NavHl[p] || hw = g_NavTxt[p] || hw = g_NavIco[p])
            return BkGui_Go(p)
}

; Handcursor ueber klickbaren Flaechen
BkGui_MouseMove(wParam, lParam, msg, hwnd) {
    static hand := 0
    global g_UiHwnd
    if (!hand)
        hand := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32649, "Ptr")
    if (A_Gui != "Bk")
        return
    WinGetClass, cls, ahk_id %hwnd%
    if (cls = "Static") {
        st := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -16, "Int")
        if (st & 0x100)                       ; SS_NOTIFY = klickbar
            DllCall("SetCursor", "Ptr", hand)
    }
}

BkGui_Toast(msg) {
    global g_H, g_GuiBuilt
    if (!g_GuiBuilt)
        return
    BkUi_Set(g_H.toast, msg)
    SetTimer, BkGuiToastClear, -4000
}

BkGuiToastClear() {
    global g_H
    BkUi_Set(g_H.toast, "")
}

; =====================================================================
;  Seite: Uebersicht
; =====================================================================
BkGui_BuildDash() {
    global
    local i, t, x
    BkUi_Page("dash")
    for i, t in [["kills", "Kills heute", "E7C1"], ["tode", "Tode heute", "E8BB"], ["kd", "K/D heute", "E9D2"], ["zeit", "Spielzeit heute", "E823"]] {
        x := 240 + (i - 1) * 220
        BkUi_Card(x, 100, 200, 104)
        BkUi_Icon(x + 18, 118, t[3], 11, BkC.accent)
        BkUi_Text(x + 42, 116, 150, t[2], 9, "norm", BkC.dim)
        g_H["kpi_" . t[1]] := BkUi_Text(x + 18, 138, 170, "0", 22, "bold")
        g_H["kpis_" . t[1]] := BkUi_Text(x + 18, 176, 175, "", 8, "norm", BkC.faint)
    }
    BkUi_Card(240, 224, 420, 300, "Statistik", "E9D2")
    Gui, Bk:Font, % "s9 norm c" . BkC.text, Segoe UI
    BkUi_Add("ListView", "-E0x200 x256 y262 w388 h248 vBkG_LvStats -Hdr -Multi NoSort ReadOnly LV0x10000 Background" . BkC.card . " c" . BkC.text, "Wert|Heute|Monat|Gesamt")
    BkUi_Card(680, 224, 420, 300, "Finanzen", "E8C7")
    g_H.konto := BkUi_Text(860, 238, 220, "", 9, "norm", BkC.gold, "Right")
    BkUi_Add("ListView", "-E0x200 x696 y262 w388 h248 vBkG_LvFin -Hdr -Multi NoSort ReadOnly LV0x10000 Background" . BkC.card . " c" . BkC.text, "Wert|Heute|Monat|Gesamt")
    BkUi_Card(240, 544, 420, 156, "Schnellstart", "E768")
    BkUi_Button(258, 586, 122, 40, "Spiel starten", "BkGui_RunGame", "primary")
    BkUi_Button(389, 586, 122, 40, "TeamSpeak", "BkGui_RunTS")
    BkUi_Button(520, 586, 122, 40, "Aufnahme", "BkGui_RunRec")
    g_H.radioBtn := BkUi_Button(258, 638, 122, 40, "Radio ▶", "BkGui_RadioToggle")
    BkUi_Button(389, 638, 122, 40, "Timer 5 Min", "BkGui_Timer5")
    BkUi_Button(520, 638, 122, 40, "Ordner", "BkGui_OpenDir")
    g_H.timer := BkUi_Text(260, 556, 380, "", 8, "norm", BkC.dim, "Right")
    BkUi_Card(680, 544, 420, 156, "Letzte Meldungen", "E8BD")
    BkUi_Add("ListView", "-E0x200 x696 y580 w388 h108 vBkG_LvLog -Hdr -Multi NoSort ReadOnly LV0x10000 Background" . BkC.card . " c" . BkC.dim, "Zeit|Meldung")
    Gui, Bk:ListView, BkG_LvLog
    LV_ModifyCol(1, 62), LV_ModifyCol(2, 300)
    BkUi_Font()
}

BkGui_StatsRefresh(force := false) {
    global g_GuiBuilt, g_GuiVisible, g_H, g_UiCur, g_StVer
    static last := 0, lastVer := -1, lastDay := ""
    if (!g_GuiBuilt || (!force && (!g_GuiVisible || g_UiCur != "dash")))
        return
    if (!force && ((A_TickCount - last) < 900 || (g_StVer = lastVer && A_DD = lastDay)))
        return
    last := A_TickCount, lastVer := g_StVer, lastDay := A_DD
    BkUi_Set(g_H.kpi_kills, BkNum(BkStats_Get("kills", "T")))
    BkUi_Set(g_H.kpis_kills, "Monat " . BkNum(BkStats_Get("kills", "M")) . "  ·  gesamt " . BkNum(BkStats_Get("kills")))
    BkUi_Set(g_H.kpi_tode, BkNum(BkStats_Get("tode", "T")))
    BkUi_Set(g_H.kpis_tode, "Monat " . BkNum(BkStats_Get("tode", "M")) . "  ·  gesamt " . BkNum(BkStats_Get("tode")))
    BkUi_Set(g_H.kpi_kd, Format("{:.2f}", BkStats_KD("T")))
    BkUi_Set(g_H.kpis_kd, "Monat " . Format("{:.2f}", BkStats_KD("M")) . "  ·  gesamt " . Format("{:.2f}", BkStats_KD("G")))
    BkUi_Set(g_H.kpi_zeit, BkDurShort(BkStats_Get("spielzeit", "T")))
    BkUi_Set(g_H.kpis_zeit, "gesamt " . BkDurShort(BkStats_Get("spielzeit")))
    kt := BkStats_Info("kontostand")
    BkUi_Set(g_H.konto, (kt != "") ? "Kontostand  " . BkNum(kt) . " $" : "")
    Gui, Bk:Default
    Gui, Bk:ListView, BkG_LvStats
    GuiControl, Bk:-Redraw, BkG_LvStats
    LV_Delete()
    rows := [["Kills", "kills", ""], ["Tode", "tode", ""], ["Differenz", "#diff", ""], ["K/D", "#kd", ""]
           , ["Knastzeit", "knast", "t"], ["SMS erhalten", "sms_in", ""], ["SMS geschrieben", "sms_out", ""]
           , ["Logins", "logins", ""], ["Missionen", "missionen", ""], ["Anwesenheit bestätigt", "notafk", ""]
           , ["Wanteds gehackt", "hacked", ""], ["Kofferräume geknackt", "kofferraum", ""]
           , ["Wertsachen gelegt", "take", ""], ["Wertsachen entnommen", "get", ""], ["Drogen (Gramm)", "drogen", ""]]
    for i, r in rows {
        v := []
        for j, s in ["T", "M", "G"] {
            if (r[2] = "#diff")
                v.Push(BkNum(BkStats_Diff(s)))
            else if (r[2] = "#kd")
                v.Push(Format("{:.2f}", BkStats_KD(s)))
            else if (r[3] = "t")
                v.Push(BkDurShort(BkStats_Get(r[2], s)))
            else
                v.Push(BkNum(BkStats_Get(r[2], s)))
        }
        LV_Add("", r[1], v[1], v[2], v[3])
    }
    LV_ModifyCol(1, 150), LV_ModifyCol(2, "76 Right"), LV_ModifyCol(3, "76 Right"), LV_ModifyCol(4, "82 Right")
    GuiControl, Bk:+Redraw, BkG_LvStats
    Gui, Bk:ListView, BkG_LvFin
    GuiControl, Bk:-Redraw, BkG_LvFin
    LV_Delete()
    rows := [["Einnahmen (Zinsen)", "zinsen", "+"], ["Kreditkarte", "karte", "-"], ["Miete", "miete", "-"], ["Spritgeld", "sprit", "-"]
           , ["Blitzer", "blitzer", "-"], ["Verlust durch Tode", "todverlust", "-"], ["Verlust durch Cops", "copdm", "-"]
           , ["Ausgaben gesamt", "#aus", "-"], ["Differenz", "#diff", ""]]
    for i, r in rows {
        v := []
        for j, s in ["T", "M", "G"] {
            if (r[2] = "#aus")
                n := BkStats_Ausgaben(s)
            else if (r[2] = "#diff")
                n := BkStats_Einnahmen(s) - BkStats_Ausgaben(s)
            else
                n := BkStats_Get(r[2], s)
            v.Push(BkNum(n) . " $")
        }
        LV_Add("", r[1], v[1], v[2], v[3])
    }
    LV_ModifyCol(1, 150), LV_ModifyCol(2, "76 Right"), LV_ModifyCol(3, "76 Right"), LV_ModifyCol(4, "82 Right")
    GuiControl, Bk:+Redraw, BkG_LvFin
}

BkDurShort(sec) {
    sec := Round(BkN(sec))
    h := sec // 3600, m := Mod(sec // 60, 60)
    return (h > 0) ? h . " h " . m . " min" : m . " min"
}

BkGui_LogMsg(t, text, kind) {
    global g_GuiBuilt
    if (!g_GuiBuilt)
        return
    Gui, Bk:Default
    Gui, Bk:ListView, BkG_LvLog
    LV_Insert(1, "", t, StrReplace(text, "`n", "  ·  "))
    while (LV_GetCount() > 60)
        LV_Delete(61)
}

BkGui_RunGame() {
    BkRunProg("game")
}
BkGui_RunTS() {
    BkRunProg("ts")
}
BkGui_RunRec() {
    BkRunProg("rec")
}
BkGui_OpenDir() {
    global BK_Dir
    Run, % BK_Dir
}
BkGui_RadioToggle() {
    global g_RadioOn
    if (g_RadioOn)
        BkRadio_Stop()
    else
        BkRadio_Play()
}
BkGui_RadioRefresh() {
    global g_H, g_RadioOn, g_GuiBuilt
    if (g_GuiBuilt)
        BkUi_Set(g_H.radioBtn.txt, g_RadioOn ? "Radio ■" : "Radio ▶")
}
BkGui_Timer5() {
    if (BkTimer_Left() >= 0) {
        BkTimer_Stop()
        BkGui_TimerRefresh()
        return
    }
    BkTimer_Start(5)
    BkGui_TimerRefresh()
}
BkGui_TimerRefresh() {
    global g_H, g_GuiBuilt
    if (!g_GuiBuilt)
        return
    l := BkTimer_Left()
    BkUi_Set(g_H.timer, (l >= 0) ? "Timer: noch " . (l // 60) . ":" . Format("{:02}", Mod(l, 60)) . "  (nochmal klicken = stoppen)" : "")
}

; =====================================================================
;  Seite: Profil & Job
; =====================================================================
BkGui_BuildProfile() {
    global
    local i, t, x, hb1, hb2
    BkUi_Page("profil")
    for i, t in BkProf_Types() {
        x := 240 + (i - 1) * 293
        hb1 := BkUi_Bmp(273, 150, BkC.card, BkC.bg, 14, BkC.line)
        hb2 := BkUi_Bmp(273, 150, "1E2027", BkC.bg, 14, BkC.accent)
        g_ProfCards[t.id] := {off: BkUi_Add("Picture", "x" . x . " y100 w273 h150 gBkGui_ProfClick", "HBITMAP:" . hb1)
                            , on: BkUi_Add("Picture", "x" . x . " y100 w273 h150 gBkGui_ProfClick Hidden", "HBITMAP:" . hb2)}
        g_ProfCards[t.id].ico := BkUi_Icon(x + 22, 122, (t.id = "zivi") ? "E77B" : (t.id = "gang") ? "E716" : "E83D", 18, BkC.accent, "gBkGui_ProfClick")
        g_ProfCards[t.id].name := BkUi_Text(x + 58, 122, 200, t.name, 13, "bold", "", "gBkGui_ProfClick")
        g_ProfCards[t.id].desc := BkUi_Text(x + 22, 162, 232, t.desc, 9, "norm", BkC.dim, "h60 gBkGui_ProfClick")
        g_ProfCards[t.id].chk := BkUi_Text(x + 22, 222, 230, "✓  Ausgewählt", 9, "bold", BkC.accent, "Hidden")
    }
    BkUi_Card(240, 270, 420, 214, "Fraktion & Job", "E7EE")
    BkUi_Text(260, 312, 180, "Fraktion", 9, "norm", BkC.dim)
    BkUi_Add("DropDownList", "x260 y332 w380 r12 vBkG_Faction gBkGui_ProfChanged", "")
    g_H.facHint := BkUi_Text(262, 334, 380, "Als Zivilist gehörst du keiner Fraktion an.", 9, "norm", BkC.faint, "Hidden")
    BkUi_Text(260, 368, 180, "Job", 9, "norm", BkC.dim)
    BkUi_Add("DropDownList", "x260 y388 w380 r16 vBkG_Job gBkGui_ProfChanged", "")
    BkUi_Text(260, 424, 380, "Dein Name im Spiel (leer = automatisch)", 9, "norm", BkC.dim)
    BkUi_Add("Edit", "x260 y444 w220 h24 vBkG_Name gBkGui_ProfChanged -E0x200 Border", "")
    g_H.nameAuto := BkUi_Text(490, 448, 160, "", 8, "norm", BkC.faint)

    BkUi_Card(680, 270, 420, 214, "Chat-Kanäle", "E8BD", "Diese Kürzel setzt der Binder für {fchat}, {gchat}, {funk} und {dchat} ein.")
    for i, t in [["FChat", "Fraktionschat", "{fchat}"], ["GChat", "Gang-/Gruppenchat", "{gchat}"], ["Funk", "Funk (Staat)", "{funk}"], ["DChat", "Department (Staat)", "{dchat}"]] {
        BkUi_Text(700, 356 + (i - 1) * 31, 180, t[2], 10)
        BkUi_Text(880, 358 + (i - 1) * 31, 80, t[3], 8, "norm", BkC.faint)
        BkUi_Add("Edit", "x980 y" . (352 + (i - 1) * 31) . " w100 h24 vBkG_" . t[1] . " gBkGui_ProfChanged -E0x200 Border", "")
    }

    BkUi_Card(240, 504, 860, 196, "Aktive Befehlsgruppen", "E762", "Grün = für dein Profil aktiv. Tasten aus inaktiven Gruppen bleiben gespeichert, wirken aber nicht.")
    Gui, Bk:Font, % "s9 norm c" . BkC.text, Segoe UI
    BkUi_Add("ListView", "-E0x200 x256 y568 w828 h120 vBkG_LvGroups -Multi NoSort ReadOnly LV0x10000 Background" . BkC.card . " c" . BkC.text, "Gruppe|Status|Tasten belegt|Chat-Befehle")
    BkUi_Font()
}

BkGui_ProfClick() {
    global g_ProfCards, BK_ProfType
    MouseGetPos, , , , hw, 2
    for id, c in g_ProfCards {
        if (hw = c.off || hw = c.on || hw = c.ico || hw = c.name || hw = c.desc) {
            if (BK_ProfType != id) {
                BK_ProfType := id
                BkGui_FactionList()
                BkGui_ProfApply()
            }
            return
        }
    }
}

BkGui_FactionList() {
    global BK_ProfType, BK_ProfFaction
    list := ""
    if (BK_ProfType = "gang") {
        for i, n in BkProf_Gangs()
            list .= "|" . n
    } else if (BK_ProfType = "staat") {
        for i, s in BkProf_States()
            list .= "|" . s.name
    }
    GuiControl, Bk:, BkG_Faction, % (list = "") ? "|" : list
    found := false
    if (BK_ProfFaction != "") {
        GuiControl, Bk:ChooseString, BkG_Faction, % BK_ProfFaction
        found := !ErrorLevel
    }
    if (!found && list != "") {
        GuiControl, Bk:Choose, BkG_Faction, 1
        GuiControlGet, v, Bk:, BkG_Faction
        BK_ProfFaction := v
    }
    if (list = "")
        BK_ProfFaction := ""
}

BkGui_ProfChanged() {
    global
    if (g_Loading)
        return
    Gui, Bk:Submit, NoHide
    BK_ProfFaction := BkG_Faction
    BK_ProfJob := ""
    for i, j in BkProf_Jobs()
        if (j.name = BkG_Job)
            BK_ProfJob := j.id
    BK_Name := Trim(BkG_Name)
    BK_FChat := Trim(BkG_FChat), BK_GChat := Trim(BkG_GChat), BK_Funk := Trim(BkG_Funk), BK_DChat := Trim(BkG_DChat)
    SetTimer, BkGuiProfApply, -300
}

BkGui_ProfApply() {
    BkCfg_Save()
    BkRegisterHotkeys()
    BkGui_ProfileRefresh()
    BkGui_StatusRefresh()
}

BkGui_ProfileRefresh() {
    global g_ProfCards, BK_ProfType, BK_ProfJob, g_H, BK_Keys, BK_TbOff, g_UiCur
    if (g_UiCur != "profil")
        return
    for id, c in g_ProfCards {
        on := (id = BK_ProfType)
        BkUi_ShowCtrl(c.on, on), BkUi_ShowCtrl(c.off, !on), BkUi_ShowCtrl(c.chk, on)
        BkUi_Repaint(c.name), BkUi_Repaint(c.desc), BkUi_Repaint(c.ico), BkUi_Repaint(c.chk)
    }
    zivi := (BK_ProfType = "zivi")
    GuiControl, % "Bk:" . (zivi ? "Hide" : "Show"), BkG_Faction
    BkUi_ShowCtrl(g_H.facHint, zivi)
    BkUi_Set(g_H.nameAuto, "erkannt: " . BkGui_AutoName())
    ; Gruppenliste
    Gui, Bk:Default
    Gui, Bk:ListView, BkG_LvGroups
    GuiControl, Bk:-Redraw, BkG_LvGroups
    LV_Delete()
    for i, g in BkGroups() {
        nk := 0, nt := 0
        for j, b in BkHotkeyDB()
            if (b.grp = g.id && BK_Keys[b.id] != "")
                nk += 1
        for j, t in BkTextDB()
            if (t.grp = g.id && !BK_TbOff[t.cmd])
                nt += 1
        act := BkGroupActive(g.id)
        LV_Add("", g.name, act ? "✓ aktiv" : "–", nk ? nk : "", nt ? nt : "")
    }
    LV_ModifyCol(1, 330), LV_ModifyCol(2, 150), LV_ModifyCol(3, "150 Right"), LV_ModifyCol(4, "150 Right")
    GuiControl, Bk:+Redraw, BkG_LvGroups
}

BkGui_AutoName() {
    loc := BkSamp_Local()
    if (IsObject(loc) && loc.name != "")
        return loc.name
    n := BkSamp_RegistryName()
    return (n != "") ? n : "noch unbekannt"
}

; =====================================================================
;  Seite: Tasten
; =====================================================================
BkGui_BuildKeys() {
    global
    BkUi_Page("keys")
    BkUi_Add("Edit", "x240 y100 w260 h26 vBkG_KeySearch gBkGui_KeysFilter -E0x200 Border", "")
    DllCall("SendMessage", "Ptr", BkGui_Hwnd("BkG_KeySearch"), "UInt", 0x1501, "Int", 1, "WStr", "Suchen ...")
    BkUi_Add("DropDownList", "x512 y100 w250 r20 vBkG_KeyGroup gBkGui_KeysFilter", "")
    BkUi_Toggle(776, 102, 170, "BkG_KeyAll", "Inaktive zeigen", "", "BkGui_KeysFilter", 9)
    Gui, Bk:Font, % "s9 norm c" . BkC.text, Segoe UI
    g_H.keyCount := BkUi_Text(950, 104, 150, "", 9, "norm", BkC.dim, "Right")
    BkUi_Add("ListView", "-E0x200 x240 y138 w860 h326 vBkG_LvKeys gBkGui_KeysLv -Multi AltSubmit LV0x10000 Background" . BkC.card . " c" . BkC.text, "Taste|Aktion|Text / Befehl|Gruppe")
    BkUi_Card(240, 480, 860, 220)
    g_H.keyLabel := BkUi_Text(262, 496, 560, "Wähle oben eine Aktion aus.", 12, "bold")
    g_H.keyInfo := BkUi_Text(262, 522, 560, "", 9, "norm", BkC.dim)
    BkUi_Text(262, 552, 200, "Taste", 9, "norm", BkC.dim)
    BkUi_Add("Hotkey", "x262 y572 w190 h26 vBkG_KeyHk", "")
    BkUi_Add("DropDownList", "x460 y572 w150 r12 vBkG_KeySpecial", "Sondertaste ...||Maus 4|Maus 5|Mausrad-Klick|Pause|Rollen|Feststell|Einfg|Entf|Pos1|Ende|Bild auf|Bild ab|Num /|Num *|Num -|Num +|Num Enter")
    BkUi_Button(262, 612, 140, 36, "Übernehmen", "BkGui_KeyApply", "primary")
    BkUi_Button(410, 612, 140, 36, "Taste entfernen", "BkGui_KeyClear")
    BkUi_Button(558, 612, 52, 36, "Test", "BkGui_KeyTest")
    g_H.keyWarn := BkUi_Text(262, 660, 360, "", 9, "norm", BkC.warn, "h30")
    BkUi_Text(640, 552, 440, "Text (jede Zeile = eine Nachricht)", 9, "norm", BkC.dim)
    BkUi_Add("Edit", "x640 y572 w440 h76 vBkG_KeyText -E0x200 Border Multi WantReturn", "")
    BkUi_Button(640, 656, 150, 32, "Platzhalter ...", "BkGui_PhMenuKeys")
    BkUi_Button(798, 656, 150, 32, "Standardtext", "BkGui_KeyDefault")
    BkUi_Button(956, 656, 124, 32, "Text speichern", "BkGui_KeyTextSave", "primary")
    BkUi_Font()
}

BkGui_Hwnd(var) {
    GuiControlGet, h, Bk:Hwnd, %var%
    return h
}

BkGui_GroupDDL(var, withAll := true) {
    list := "|Alle aktiven Gruppen"
    for i, g in BkGroups()
        list .= "|" . g.name
    GuiControl, Bk:, %var%, %list%
    GuiControl, Bk:Choose, %var%, 1
}

BkGui_GroupFromName(name) {
    for i, g in BkGroups()
        if (g.name = name)
            return g.id
    return ""
}

BkGui_KeysFilter() {
    global g_Loading
    if (g_Loading)
        return
    SetTimer, BkGuiKeysFill, -150
}

BkGui_KeysFill() {
    global
    local q, grp, all, n, nset, i, b, k, g, txt, row, dup, owners
    if (!g_GuiBuilt)
        return
    Gui, Bk:Submit, NoHide
    q := Trim(BkG_KeySearch), grp := BkGui_GroupFromName(BkG_KeyGroup), all := BkUi_TogGet("BkG_KeyAll")
    owners := BkGui_KeyOwners()
    Gui, Bk:Default
    Gui, Bk:ListView, BkG_LvKeys
    GuiControl, Bk:-Redraw, BkG_LvKeys
    LV_Delete()
    g_KeysRows := []
    n := 0, nset := 0
    for i, b in BkHotkeyDB() {
        act := BkGroupActive(b.grp)
        if (grp != "" && b.grp != grp)
            continue
        if (grp = "" && !act && !all)
            continue
        txt := (b.type = "fn") ? BkGui_FnDesc(b) : StrReplace(BkBindText(b), "`n", "  ⏎  ")
        if (q != "" && !InStr(b.label, q) && !InStr(txt, q) && !InStr(BkGroupName(b.grp), q))
            continue
        k := BK_Keys[b.id]
        kn := BkHotkeyName(k)
        if (k != "") {
            nset += 1
            nk := BkHk_Normalize(k)
            if (owners.HasKey(nk) && owners[nk] != b.id && act)
                kn := "⚠ " . kn
            if (!act)
                kn := kn . "  (inaktiv)"
        }
        LV_Add("", kn, b.label, txt, BkGroupName(b.grp))
        g_KeysRows.Push(b.id)
        n += 1
    }
    LV_ModifyCol(1, 130), LV_ModifyCol(2, 290), LV_ModifyCol(3, 290), LV_ModifyCol(4, 128)
    GuiControl, Bk:+Redraw, BkG_LvKeys
    BkUi_Set(g_H.keyCount, n . " Aktionen  ·  " . nset . " belegt")
}

; Wer bekommt welche Taste (erste aktive Belegung gewinnt)
BkGui_KeyOwners() {
    global BK_Keys, BK_ChatKey
    own := {}
    for i, b in BkHotkeyDB() {
        k := BK_Keys[b.id]
        if (k = "" || !BkGroupActive(b.grp))
            continue
        nk := BkHk_Normalize(k)
        if (!own.HasKey(nk))
            own[nk] := b.id
    }
    return own
}

BkGui_FnDesc(b) {
    static d := {BkFn_TogglePause: "Binder an/aus", BkFn_Reload: "Neustart", BkFn_ShowGui: "Fenster öffnen"
        , BkFn_ToggleOverlay: "Overlay an/aus", BkFn_Panic: "Tasten lösen", BkFn_EnterExit: "/enter oder /exit je nach Ort"
        , BkFn_AcceptLast: "/accept + letztes Angebot aus dem Chat", BkFn_AcceptSex: "/accept sex + /sex Name 1"
        , BkFn_Repeat: "Chat öffnen, Pfeil hoch, Enter", BkFn_Greeting: "Gruß passend zur Uhrzeit", BkFn_Fish: "/me isst einen Fisch"
        , BkFn_RandomSpruch: "/s zufälliger Spruch", BkFn_Countdown: "Countdown im Bild", BkFn_ChatToggle: "Taste F7"
        , BkFn_Kill: "Kill zählen + {fchat} Killspruch", BkFn_DeathManual: "Tode +1", BkFn_WeaponPack: "/buygun ... (Paket)"
        , BkFn_FindResult: "Ergebnis von /find weitergeben", BkFn_Members: "/members + zählen", BkFn_OrgMembers: "/orgmembers + zählen"}
    t := d.HasKey(b.fn) ? d[b.fn] : "Sonderfunktion"
    if (b.fn = "BkFn_WeaponPack")
        t := "Waffenpaket " . b.text . ": " . StrReplace(BkCfg_Get("Pack" . b.text), "|", ", ")
    if (b.fn = "BkFn_Kill")
        t := "{fchat} " . ((b.text = "gz") ? BkCfg_Get("GZZ") : BkCfg_Get("GWZ")) . " ... - Kill Nr. X"
    if (b.fn = "BkFn_FindResult")
        t := b.text . " Der gesuchte Spieler ist in ..."
    return t
}

BkGui_KeysLv() {
    global g_KeysRows, g_KeysSel
    if (A_GuiEvent != "Normal" && A_GuiEvent != "DoubleClick" && A_GuiEvent != "I")
        return
    Gui, Bk:Default
    Gui, Bk:ListView, BkG_LvKeys
    r := LV_GetNext(0, "F")
    if (!r || !g_KeysRows[r])
        return
    if (g_KeysSel = g_KeysRows[r] && A_GuiEvent = "I")
        return
    g_KeysSel := g_KeysRows[r]
    BkGui_KeyEditorLoad()
}

BkGui_KeyEditorLoad() {
    global g_KeysSel, g_H, BK_Keys
    b := BkBind(g_KeysSel)
    if (!IsObject(b))
        return
    BkUi_Set(g_H.keyLabel, b.label)
    typ := {send: "Sendet den Text", prefill: "Öffnet den Chat mit diesem Text (ohne Enter)", local: "Zeigt den Text nur dir an", fn: "Sonderfunktion: " . BkGui_FnDesc(b)}
    BkUi_Set(g_H.keyInfo, BkGroupName(b.grp) . "  ·  " . typ[b.type] . (BkGroupActive(b.grp) ? "" : "  ·  für dein Profil inaktiv"))
    k := BK_Keys[b.id]
    GuiControl, Bk:, BkG_KeyHk, % BkGui_HkForControl(k)
    GuiControl, Bk:Choose, BkG_KeySpecial, 1
    sp := BkGui_SpecialName(k)
    if (sp != "")
        GuiControl, Bk:ChooseString, BkG_KeySpecial, %sp%
    ed := BkBindEditable(b)
    GuiControl, Bk:, BkG_KeyText, % ed ? BkBindText(b) : "(Diese Aktion hat keinen Text.)"
    GuiControl, % "Bk:" . (ed ? "Enable" : "Disable"), BkG_KeyText
    BkUi_Set(g_H.keyWarn, "")
}

BkGui_SpecialMap() {
    return {"Maus 4": "XButton1", "Maus 5": "XButton2", "Mausrad-Klick": "MButton", "Pause": "Pause", "Rollen": "ScrollLock"
          , "Feststell": "CapsLock", "Einfg": "Insert", "Entf": "Delete", "Pos1": "Home", "Ende": "End", "Bild auf": "PgUp"
          , "Bild ab": "PgDn", "Num /": "NumpadDiv", "Num *": "NumpadMult", "Num -": "NumpadSub", "Num +": "NumpadAdd", "Num Enter": "NumpadEnter"}
}

BkGui_SpecialName(k) {
    for n, v in BkGui_SpecialMap()
        if (v = k)
            return n
    return ""
}

; Hotkey-Feld versteht keine Maustasten/Sondertasten
BkGui_HkForControl(k) {
    if (k = "" || BkGui_SpecialName(k) != "" || RegExMatch(k, "i)button|wheel|sc[0-9a-f]|vk[0-9a-f]"))
        return ""
    return k
}

BkGui_KeyApply() {
    global
    local b, k, sp, map, nk, owner, prev
    if (g_KeysSel = "")
        return
    Gui, Bk:Submit, NoHide
    k := BkG_KeyHk
    sp := BkG_KeySpecial
    map := BkGui_SpecialMap()
    if (map.HasKey(sp))
        k := map[sp]
    k := Trim(k)
    if (k = "") {
        BkUi_Set(g_H.keyWarn, "Bitte eine Taste drücken oder eine Sondertaste wählen.")
        return
    }
    nk := BkHk_Normalize(k)
    if (nk = BkHk_Normalize(BK_ChatKey)) {
        BkUi_Set(g_H.keyWarn, "Das ist deine Chat-Taste - bitte eine andere wählen.")
        return
    }
    owner := ""
    for i, b in BkHotkeyDB()
        if (b.id != g_KeysSel && BK_Keys[b.id] != "" && BkHk_Normalize(BK_Keys[b.id]) = nk && BkGroupActive(b.grp))
            owner := b.label
    BK_Keys[g_KeysSel] := k
    BkCfg_SaveBinds()
    BkRegisterHotkeys()
    BkGui_KeysFill()
    BkUi_Set(g_H.keyWarn, (owner != "") ? "⚠ Achtung: " . BkHotkeyName(k) . " ist auch bei """ . owner . """ belegt." : "")
    BkGui_Toast("Taste " . BkHotkeyName(k) . " gespeichert.")
}

BkGui_KeyClear() {
    global g_KeysSel, BK_Keys
    if (g_KeysSel = "")
        return
    BK_Keys.Delete(g_KeysSel)
    BkCfg_SaveBinds()
    BkRegisterHotkeys()
    GuiControl, Bk:, BkG_KeyHk
    BkGui_KeysFill()
    BkGui_Toast("Taste entfernt.")
}

BkGui_KeyTest() {
    global g_KeysSel
    b := BkBind(g_KeysSel)
    if (!IsObject(b))
        return
    Gui, Bk:Submit, NoHide
    if (b.type = "fn")
        txt := BkGui_FnDesc(b)
    else
        txt := BkFill(BkG_KeyText)
    MsgBox, 64, Vorschau, % b.label . "`n`nSo würde es im Moment aussehen:`n`n" . txt
}

BkGui_KeyDefault() {
    global g_KeysSel
    b := BkBind(g_KeysSel)
    if (!IsObject(b) || !BkBindEditable(b))
        return
    GuiControl, Bk:, BkG_KeyText, % b.text
}

BkGui_KeyTextSave() {
    global g_KeysSel, BK_Texts, BkG_KeyText
    b := BkBind(g_KeysSel)
    if (!IsObject(b) || !BkBindEditable(b))
        return
    Gui, Bk:Submit, NoHide
    t := StrReplace(BkG_KeyText, "`r")
    if (t == b.text)
        BK_Texts.Delete(b.id)
    else
        BK_Texts[b.id] := t
    BkCfg_SaveBinds()
    BkGui_KeysFill()
    BkGui_Toast("Text gespeichert.")
}

; Platzhalter-Menue (fuegt an der Schreibmarke ein)
BkGui_PhMenuKeys() {
    BkGui_PhMenu("BkG_KeyText")
}
BkGui_PhMenuChat() {
    BkGui_PhMenu("BkG_ChatText")
}
BkGui_PhMenu(target) {
    global g_PhTarget
    g_PhTarget := target
    try Menu, BkPh, DeleteAll
    for i, p in BkPlaceholders()
        Menu, BkPh, Add, % p[1] . "`t" . p[2], BkGui_PhPick
    Menu, BkPh, Show
}
BkGui_PhPick() {
    global g_PhTarget
    ph := SubStr(A_ThisMenuItem, 1, InStr(A_ThisMenuItem, "`t") - 1)
    h := BkGui_Hwnd(g_PhTarget)
    Control, EditPaste, %ph%, , ahk_id %h%
}

; =====================================================================
;  Seite: Chat-Befehle
; =====================================================================
BkGui_BuildChat() {
    global
    BkUi_Page("chat")
    BkUi_Add("Edit", "x240 y100 w260 h26 vBkG_ChatSearch gBkGui_ChatFilter -E0x200 Border", "")
    DllCall("SendMessage", "Ptr", BkGui_Hwnd("BkG_ChatSearch"), "UInt", 0x1501, "Int", 1, "WStr", "Suchen ... (z.B. /kd)")
    BkUi_Add("DropDownList", "x512 y100 w250 r20 vBkG_ChatGroup gBkGui_ChatFilter", "")
    BkUi_Toggle(776, 102, 170, "BkG_ChatAll", "Inaktive zeigen", "", "BkGui_ChatFilter", 9)
    Gui, Bk:Font, % "s9 norm c" . BkC.text, Segoe UI
    g_H.chatCount := BkUi_Text(950, 104, 150, "", 9, "norm", BkC.dim, "Right")
    BkUi_Add("ListView", "-E0x200 x240 y138 w860 h326 vBkG_LvChat gBkGui_ChatLv -Multi AltSubmit LV0x10000 Background" . BkC.card . " c" . BkC.text, "Befehl|Wirkung|Gruppe|Status")
    BkUi_Card(240, 480, 860, 220)
    g_H.chatLabel := BkUi_Text(262, 496, 380, "Wähle oben einen Befehl aus.", 12, "bold")
    g_H.chatInfo := BkUi_Text(262, 522, 380, "", 9, "norm", BkC.dim, "h40")
    BkUi_Text(262, 570, 200, "Befehl (nur eigene änderbar)", 9, "norm", BkC.dim)
    BkUi_Add("Edit", "x262 y590 w180 h26 vBkG_ChatCmd -E0x200 Border", "")
    g_H.chatToggle := BkUi_Button(452, 588, 170, 30, "Ausschalten", "BkGui_ChatToggle")
    BkUi_Button(262, 628, 176, 32, "+ Eigener Befehl", "BkGui_ChatNew")
    BkUi_Button(446, 628, 176, 32, "Eigenen löschen", "BkGui_ChatDelete", "danger")
    BkUi_Text(640, 496, 440, "Text (jede Zeile = eine Nachricht)", 9, "norm", BkC.dim)
    BkUi_Add("Edit", "x640 y516 w440 h132 vBkG_ChatText -E0x200 Border Multi WantReturn", "")
    BkUi_Button(640, 656, 150, 32, "Platzhalter ...", "BkGui_PhMenuChat")
    BkUi_Button(798, 656, 150, 32, "Standardtext", "BkGui_ChatDefault")
    BkUi_Button(956, 656, 124, 32, "Speichern", "BkGui_ChatSave", "primary")
    BkUi_Font()
}

BkGui_ChatFilter() {
    global g_Loading
    if (g_Loading)
        return
    SetTimer, BkGuiChatFill, -150
}

BkGui_ChatFill() {
    global
    local q, grp, all, n, i, t, st, txt, c
    if (!g_GuiBuilt)
        return
    Gui, Bk:Submit, NoHide
    q := Trim(BkG_ChatSearch), grp := BkGui_GroupFromName(BkG_ChatGroup), all := BkUi_TogGet("BkG_ChatAll")
    Gui, Bk:Default
    Gui, Bk:ListView, BkG_LvChat
    GuiControl, Bk:-Redraw, BkG_LvChat
    LV_Delete()
    g_ChatRows := []
    n := 0
    for i, c in BK_CustomTb {
        if (grp != "" && grp != "eigene")
            continue
        if (q != "" && !InStr(c.cmd, q) && !InStr(c.text, q))
            continue
        LV_Add("", c.cmd, StrReplace(c.text, "`n", "  ⏎  "), "Eigene Befehle", "✓ aktiv")
        g_ChatRows.Push("ctb:" . i)
        n += 1
    }
    for i, t in BkTextDB() {
        act := BkGroupActive(t.grp)
        if (grp != "" && t.grp != grp)
            continue
        if (grp = "" && !act && !all)
            continue
        if (q != "" && !InStr(t.cmd, q) && !InStr(t.label, q))
            continue
        st := BK_TbOff[t.cmd] ? "aus" : act ? "✓ aktiv" : "Profil aus"
        LV_Add("", (t.arg = "space") ? t.cmd . " + Leer" : t.cmd, t.label, BkGroupName(t.grp), st)
        g_ChatRows.Push(t.id)
        n += 1
    }
    ; Gegnerlisten als Befehle anzeigen
    if (grp = "" || grp = "gegner") {
        for i, e in BK_Enemies {
            if (q != "" && !InStr(e.key, q) && !InStr(e.title, q))
                continue
            LV_Add("", "/" . e.key . "  /" . e.key . "add  /" . e.key . "del", "Gegnerliste " . e.title . ": anzeigen / hinzufügen / entfernen", "Gegnerlisten", BkGroupActive("gegner") ? "✓ aktiv" : "Profil aus")
            g_ChatRows.Push("")
            n += 1
        }
    }
    LV_ModifyCol(1, 170), LV_ModifyCol(2, 420), LV_ModifyCol(3, 150), LV_ModifyCol(4, 96)
    GuiControl, Bk:+Redraw, BkG_LvChat
    BkUi_Set(g_H.chatCount, n . " Befehle")
}

BkGui_ChatBind(id) {
    global BK_CustomTb
    if (SubStr(id, 1, 4) = "ctb:") {
        c := BK_CustomTb[SubStr(id, 5) + 0]
        return IsObject(c) ? {id: id, cmd: c.cmd, grp: "eigene", label: "Eigener Chat-Befehl", type: "send", text: c.text, custom: 1} : ""
    }
    return BkBind(id)
}

BkGui_ChatLv() {
    global g_ChatRows, g_ChatSel
    if (A_GuiEvent != "Normal" && A_GuiEvent != "DoubleClick" && A_GuiEvent != "I")
        return
    Gui, Bk:Default
    Gui, Bk:ListView, BkG_LvChat
    r := LV_GetNext(0, "F")
    if (!r || g_ChatRows[r] = "")
        return
    if (g_ChatSel = g_ChatRows[r] && A_GuiEvent = "I")
        return
    g_ChatSel := g_ChatRows[r]
    BkGui_ChatEditorLoad()
}

BkGui_ChatEditorLoad() {
    global g_ChatSel, g_H, BK_TbOff
    t := BkGui_ChatBind(g_ChatSel)
    if (!IsObject(t))
        return
    BkUi_Set(g_H.chatLabel, t.cmd)
    info := t.label
    if (t.fn = "BkFn_Map")
        info .= "  ·  " . BkMapDB().Count() . " Gebäudekomplexe (Liste unter Hilfe & Info)"
    if (t.arg = "space")
        info .= "  ·  löst mit der Leertaste aus"
    BkUi_Set(g_H.chatInfo, info)
    GuiControl, Bk:, BkG_ChatCmd, % t.cmd
    GuiControl, % "Bk:" . (t.custom ? "Enable" : "Disable"), BkG_ChatCmd
    ed := BkBindEditable(t)
    GuiControl, Bk:, BkG_ChatText, % ed ? BkBindText(t) : "(Sonderfunktion - kein Text)"
    GuiControl, % "Bk:" . (ed ? "Enable" : "Disable"), BkG_ChatText
    BkUi_Set(g_H.chatToggle.txt, t.custom ? "–" : BK_TbOff[t.cmd] ? "Einschalten" : "Ausschalten")
}

BkGui_ChatToggle() {
    global g_ChatSel, BK_TbOff
    t := BkGui_ChatBind(g_ChatSel)
    if (!IsObject(t) || t.custom)
        return
    if (BK_TbOff[t.cmd])
        BK_TbOff.Delete(t.cmd)
    else
        BK_TbOff[t.cmd] := 1
    BkCfg_SaveBinds()
    BkGui_ChatFill()
    BkGui_ChatEditorLoad()
}

BkGui_ChatDefault() {
    global g_ChatSel
    t := BkGui_ChatBind(g_ChatSel)
    if (IsObject(t) && !t.custom && BkBindEditable(t))
        GuiControl, Bk:, BkG_ChatText, % t.text
}

BkGui_ChatSave() {
    global g_ChatSel, BK_Texts, BK_CustomTb, BkG_ChatText, BkG_ChatCmd
    t := BkGui_ChatBind(g_ChatSel)
    if (!IsObject(t))
        return
    Gui, Bk:Submit, NoHide
    txt := StrReplace(BkG_ChatText, "`r")
    if (t.custom) {
        c := Trim(BkG_ChatCmd)
        if (c = "" || InStr(c, " ")) {
            BkGui_Toast("Der Befehl darf nicht leer sein und keine Leerzeichen enthalten.")
            return
        }
        if (SubStr(c, 1, 1) != "/")
            c := "/" . c
        i := SubStr(g_ChatSel, 5) + 0
        BK_CustomTb[i] := {cmd: c, text: txt}
    } else if (BkBindEditable(t)) {
        if (txt == t.text)
            BK_Texts.Delete(t.id)
        else
            BK_Texts[t.id] := txt
    }
    BkCfg_SaveBinds()
    BkGui_ChatFill()
    BkGui_ChatEditorLoad()
    BkGui_Toast("Gespeichert.")
}

BkGui_ChatNew() {
    global BK_CustomTb, g_ChatSel
    BK_CustomTb.Push({cmd: "/neu" . (BK_CustomTb.MaxIndex() ? BK_CustomTb.MaxIndex() + 1 : 1), text: "Dein Text hier"})
    BkCfg_SaveBinds()
    g_ChatSel := "ctb:" . BK_CustomTb.MaxIndex()
    BkGui_ChatFill()
    BkGui_ChatEditorLoad()
    GuiControl, Bk:Focus, BkG_ChatCmd
}

BkGui_ChatDelete() {
    global BK_CustomTb, g_ChatSel
    if (SubStr(g_ChatSel, 1, 4) != "ctb:")
        return BkGui_Toast("Nur eigene Befehle können gelöscht werden.")
    BK_CustomTb.RemoveAt(SubStr(g_ChatSel, 5) + 0)
    BkCfg_SaveBinds()
    g_ChatSel := ""
    BkGui_ChatFill()
    GuiControl, Bk:, BkG_ChatText
    GuiControl, Bk:, BkG_ChatCmd
}

; =====================================================================
;  Seite: Gegnerlisten
; =====================================================================
BkGui_BuildEnemy() {
    global
    BkUi_Page("enemy")
    BkUi_Card(240, 100, 320, 600, "Listen", "E8FD")
    Gui, Bk:Font, % "s9 norm c" . BkC.text, Segoe UI
    BkUi_Add("ListView", "-E0x200 x256 y140 w288 h376 vBkG_LvLists gBkGui_ListsLv -Multi AltSubmit NoSort LV0x10000 Background" . BkC.card . " c" . BkC.text, "Liste|Befehl|Namen")
    BkUi_Text(258, 530, 280, "Neue Liste", 9, "bold")
    BkUi_Text(258, 552, 120, "Name", 8, "norm", BkC.dim)
    BkUi_Add("Edit", "x258 y570 w150 h24 vBkG_NewListTitle -E0x200 Border", "")
    BkUi_Text(418, 552, 120, "Befehl (ohne /)", 8, "norm", BkC.dim)
    BkUi_Add("Edit", "x418 y570 w126 h24 vBkG_NewListKey -E0x200 Border", "")
    BkUi_Button(258, 606, 138, 34, "Anlegen", "BkGui_ListNew", "primary")
    BkUi_Button(406, 606, 138, 34, "Liste löschen", "BkGui_ListDelete", "danger")
    g_H.listHint := BkUi_Text(258, 650, 290, "", 8, "norm", BkC.faint, "h40")

    BkUi_Card(580, 100, 520, 600)
    g_H.enemyTitle := BkUi_Text(600, 114, 300, "Gegner", 11, "bold")
    g_H.enemyCmds := BkUi_Text(600, 138, 480, "", 9, "norm", BkC.dim)
    BkUi_Button(950, 112, 132, 32, "Online prüfen", "BkGui_EnemyCheck", "primary")
    BkUi_Add("ListView", "-E0x200 x596 y170 w488 h400 vBkG_LvEnemy -Multi LV0x10000 Background" . BkC.card . " c" . BkC.text, "Name|Status|ID|Level|Ping")
    BkUi_Add("Edit", "x596 y586 w250 h28 vBkG_EnemyName -E0x200 Border", "")
    DllCall("SendMessage", "Ptr", BkGui_Hwnd("BkG_EnemyName"), "UInt", 0x1501, "Int", 1, "WStr", "Name oder ID ...")
    BkUi_Button(854, 584, 110, 32, "Hinzufügen", "BkGui_EnemyAdd", "primary")
    BkUi_Button(972, 584, 112, 32, "Entfernen", "BkGui_EnemyRemove")
    g_H.enemyInfo := BkUi_Text(598, 628, 486, "", 9, "norm", BkC.dim, "h60")
    BkUi_Font()
}

BkGui_EnemyRefresh() {
    global g_GuiBuilt, BK_Enemies, g_EnemySel, g_UiCur
    if (!g_GuiBuilt || g_UiCur != "enemy")
        return
    Gui, Bk:Default
    Gui, Bk:ListView, BkG_LvLists
    GuiControl, Bk:-Redraw, BkG_LvLists
    LV_Delete()
    sel := 0
    for i, e in BK_Enemies {
        LV_Add("", e.title, "/" . e.key, BkCnt(BkEnemy_Names(e.key)))
        if (e.key = g_EnemySel)
            sel := i
    }
    if (!sel && BK_Enemies.MaxIndex())
        sel := 1, g_EnemySel := BK_Enemies[1].key
    if (sel)
        LV_Modify(sel, "Select Focus")
    LV_ModifyCol(1, 140), LV_ModifyCol(2, 84), LV_ModifyCol(3, "60 Right")
    GuiControl, Bk:+Redraw, BkG_LvLists
    BkGui_EnemyMembers(false)
}

BkGui_ListsLv() {
    global BK_Enemies, g_EnemySel
    if (A_GuiEvent != "Normal" && A_GuiEvent != "I")
        return
    Gui, Bk:Default
    Gui, Bk:ListView, BkG_LvLists
    r := LV_GetNext(0, "F")
    if (!r || !IsObject(BK_Enemies[r]) || BK_Enemies[r].key = g_EnemySel)
        return
    g_EnemySel := BK_Enemies[r].key
    BkGui_EnemyMembers(false)
}

BkGui_EnemyMembers(online) {
    global g_EnemySel, g_H
    e := BkEnemy_Get(g_EnemySel)
    if (!IsObject(e))
        return
    BkUi_Set(g_H.enemyTitle, e.title)
    BkUi_Set(g_H.enemyCmds, "Im Spiel:  /" . e.key . "   ·   /" . e.key . "add ID   ·   /" . e.key . "del ID")
    names := BkEnemy_Names(e.key)
    on := {}
    if (online) {
        o := BkEnemy_Online(e.key)
        if (!IsObject(o))
            BkUi_Set(g_H.enemyInfo, "Online-Status nicht verfügbar - läuft das Spiel und ist 'Spielspeicher lesen' an?")
        else {
            for i, p in o
                on[p.name] := p
            BkUi_Set(g_H.enemyInfo, BkCnt(o) . " von " . BkCnt(names) . " online.")
        }
    } else {
        BkUi_Set(g_H.enemyInfo, BkCnt(names) . " Namen gespeichert.")
    }
    Gui, Bk:Default
    Gui, Bk:ListView, BkG_LvEnemy
    GuiControl, Bk:-Redraw, BkG_LvEnemy
    LV_Delete()
    for i, n in names {
        p := on[n]
        if (IsObject(p))
            LV_Add("", n, "● online", p.id, p.score, p.ping)
        else
            LV_Add("", n, online ? "offline" : "", "", "", "")
    }
    LV_ModifyCol(1, 190), LV_ModifyCol(2, 90), LV_ModifyCol(3, "60 Right"), LV_ModifyCol(4, "60 Right"), LV_ModifyCol(5, "60 Right")
    if (online)
        LV_ModifyCol(2, "SortDesc")
    GuiControl, Bk:+Redraw, BkG_LvEnemy
}

BkGui_EnemyCheck() {
    BkGui_EnemyMembers(true)
}

BkGui_EnemyAdd() {
    global g_EnemySel, BkG_EnemyName
    Gui, Bk:Submit, NoHide
    v := Trim(BkG_EnemyName)
    if (v = "")
        return
    name := BkEnemy_ResolveName(v, err)
    if (name = "")
        return BkGui_Toast(err)
    if !BkEnemy_Add(g_EnemySel, name)
        return BkGui_Toast(name . " ist schon in der Liste.")
    GuiControl, Bk:, BkG_EnemyName
    BkGui_EnemyRefresh()
    BkGui_Toast(name . " hinzugefügt.")
}

BkGui_EnemyRemove() {
    global g_EnemySel
    Gui, Bk:Default
    Gui, Bk:ListView, BkG_LvEnemy
    r := LV_GetNext(0)
    if (!r)
        return BkGui_Toast("Bitte zuerst einen Namen in der Liste markieren.")
    LV_GetText(n, r, 1)
    BkEnemy_Remove(g_EnemySel, n)
    BkGui_EnemyRefresh()
}

BkGui_ListNew() {
    global BK_Enemies, BkG_NewListTitle, BkG_NewListKey, g_EnemySel
    Gui, Bk:Submit, NoHide
    t := Trim(BkG_NewListTitle), k := Trim(BkG_NewListKey, " /")
    StringLower, k, k
    if (t = "" || !RegExMatch(k, "^[a-z0-9]{2,16}$"))
        return BkGui_Toast("Bitte Name und Befehl (2-16 Buchstaben/Ziffern) eingeben.")
    if (BkEnemy_FindList(k) != "")
        return BkGui_Toast("Den Befehl /" . k . " gibt es schon.")
    for i, tb in BkTextDB()
        if (tb.cmd = "/" . k)
            return BkGui_Toast("/" . k . " ist schon ein Chat-Befehl.")
    BK_Enemies.Push({key: k, title: t, file: RegExReplace(t, "[\\/:*?""<>|]", "_")})
    BkEnemy_Save()
    g_EnemySel := k
    GuiControl, Bk:, BkG_NewListTitle
    GuiControl, Bk:, BkG_NewListKey
    BkGui_EnemyRefresh()
}

BkGui_ListDelete() {
    global BK_Enemies, g_EnemySel
    for i, e in BK_Enemies {
        if (e.key = g_EnemySel) {
            MsgBox, 36, Liste löschen, % "Die Liste """ . e.title . """ wirklich entfernen?`n`nDie Textdatei bleibt im Ordner Gegnerlisten erhalten."
            IfMsgBox, Yes
            {
                BK_Enemies.RemoveAt(i)
                BkEnemy_Save()
                g_EnemySel := ""
                BkGui_EnemyRefresh()
            }
            return
        }
    }
}

; =====================================================================
;  Seite: Automatik
; =====================================================================
BkGui_Check(x, y, w, var, text, sub := "") {
    BkUi_Toggle(x, y, w, var, text, sub)
}

BkGui_BuildAuto() {
    global
    BkUi_Page("auto")
    BkUi_Card(240, 100, 420, 400, "Kills", "E7C1", "Kills werden gezählt und im Fraktionschat gemeldet.")
    BkGui_Check(262, 160, 380, "BkG_AutoGW", "Gangwar-Kills automatisch zählen", "Reagiert auf die Server-Einblendung ""Gangwarkill""")
    BkUi_Text(282, 208, 120, "Killspruch", 9, "norm", BkC.dim)
    BkUi_Add("Edit", "x372 y204 w150 h24 vBkG_GWZ gBkGui_Changed -E0x200 Border", "")
    BkUi_Toggle(532, 205, 130, "BkG_GWLoc", "+ Standort", "", "BkGui_Changed", 9)
    BkGui_Check(262, 250, 380, "BkG_AutoGZ", "Gangzone-Kills automatisch zählen", "Reagiert auf die Server-Einblendung ""Gangzonekill""")
    BkUi_Text(282, 298, 120, "Killspruch", 9, "norm", BkC.dim)
    BkUi_Add("Edit", "x372 y294 w150 h24 vBkG_GZZ gBkGui_Changed -E0x200 Border", "")
    BkUi_Toggle(532, 295, 130, "BkG_GZLoc", "+ Standort", "", "BkGui_Changed", 9)
    BkGui_Check(262, 340, 380, "BkG_AutoWantedKill", "Wanted-Kill zählen", "Bei ""Aufgrund deiner Tarnung wurde ..."" (v4.60: Autogangwarkill)")
    BkUi_Text(262, 420, 380, "Vorschau", 9, "norm", BkC.dim)
    g_H.killPrev := BkUi_Text(262, 440, 380, "", 10, "norm", BkC.accent, "h40")

    BkUi_Card(680, 100, 420, 400, "Tod & Knast", "E8BB")
    BkGui_Check(702, 146, 380, "BkG_AutoTot", "Tod im Fraktionschat melden", "Sonst nur als Meldung für dich")
    BkGui_Check(702, 196, 380, "BkG_Arrestsage", "Knast im Fraktionschat melden", "Wenn dich jemand einsperrt")
    BkGui_Check(702, 246, 380, "BkG_MemDeath", "Tod über den Spielspeicher erkennen", "Für Server ohne Todesmeldung im Chat")
    BkGui_Check(702, 296, 380, "BkG_HackMsg", "Wanted-Hack im Chat sagen", """Mir wurden soeben X Wanteds gehackt.""")
    BkGui_Check(702, 346, 380, "BkG_ClearMsg", "Wanted-Clear im Chat sagen", """Mir wurden soeben X Wanted(s) von ... gecleart!""")
    BkGui_Check(702, 396, 380, "BkG_LawyerMsg", "Freilassung durch Anwalt melden", "{fchat} Aus dem Knast entlassen dank ...")

    BkUi_Card(240, 520, 860, 180, "Sonstiges", "E945")
    BkGui_Check(262, 566, 410, "BkG_Drogensage", "Drogen-Timer", "Meldet nach 20 Sekunden, dass du wieder Drogen nehmen kannst")
    BkGui_Check(262, 624, 400, "BkG_TimerFrage", "Countdown beim Kofferraum-Aufbrechen", "29 Sekunden groß in der Bildmitte")
    BkGui_Check(680, 566, 400, "BkG_Antispam", "Antispam-Schutz", "Bei ""Antiflood: Achtung!"" kurz nichts senden")
    BkGui_Check(680, 624, 400, "BkG_Welcome", "Begrüßung beim Verbinden", """Willkommen Name - Es ist Montag 18:30.""")
    BkUi_Font()
}

; =====================================================================
;  Seite: Einstellungen (mit Unterseiten)
; =====================================================================
BkGui_BuildSettings() {
    global
    local i, s, x, w, y, p, j, list, wl
    BkUi_Page("settings")
    g_SetSubs := ["Allgemein", "Texte & Werbung", "Waffen", "Programme & Radio", "Overlay"]
    x := 240
    for i, s in g_SetSubs {
        w := StrLen(s) * 8 + 36
        g_SetSubBtns[i] := {on: BkUi_Add("Picture", "x" . x . " y100 w" . w . " h34 gBkGui_SetSubClick Hidden", "HBITMAP:" . BkUi_Bmp(w, 34, BkC.accent, BkC.bg, 17))
                          , off: BkUi_Add("Picture", "x" . x . " y100 w" . w . " h34 gBkGui_SetSubClick", "HBITMAP:" . BkUi_Bmp(w, 34, BkC.card2, BkC.bg, 17, BkC.line))
                          , txt: BkUi_Text(x, 108, w, s, 9, "bold", BkC.text, "Center gBkGui_SetSubClick")}
        x += w + 10
    }
    g_UiSub["settings"] := 1

    ; ---- 1: Allgemein ----
    BkUi_Page("settings.1")
    BkUi_Card(240, 150, 420, 330, "Senden", "E724")
    BkUi_Text(262, 196, 200, "Chat-Taste", 10)
    BkUi_Add("Edit", "x540 y192 w100 h24 vBkG_ChatKey gBkGui_Changed -E0x200 Border", "")
    BkGui_Check(262, 232, 380, "BkG_FastSend", "Schnell senden", "Die Figur bleibt beim Laufen nicht stehen (empfohlen)")
    BkUi_Text(262, 288, 260, "Pause zwischen mehreren Zeilen (ms)", 10)
    BkUi_Add("Edit", "x540 y284 w100 h24 vBkG_LineDelay gBkGui_Changed -E0x200 Border Number", "")
    BkUi_Text(262, 324, 260, "Tipp-Tempo in ms (0 = sofort)", 10)
    BkUi_Add("Edit", "x540 y320 w100 h24 vBkG_SendDelay gBkGui_Changed -E0x200 Border Number", "")
    BkGui_Check(262, 360, 380, "BkG_MemEnabled", "Spielspeicher lesen", "Standort, HP, Chat-Erkennung, Spielerliste (nur lesend)")
    BkGui_Check(262, 416, 380, "BkG_ShowAll", "Chat-Befehle aller Profile erlauben", "Auch Befehle aus inaktiven Gruppen ausführen")

    BkUi_Card(680, 150, 420, 330, "Spiel & Fenster", "E7FC")
    BkUi_Text(702, 196, 380, "Spielprozesse (mit Komma getrennt)", 9, "norm", BkC.dim)
    BkUi_Add("Edit", "x702 y216 w378 h24 vBkG_GameExes gBkGui_Changed -E0x200 Border", "")
    BkUi_Text(702, 250, 380, "gta_sa.exe = normales SA-MP. Weitere Namen nur für spezielle Launcher.", 8, "norm", BkC.faint)
    BkUi_Text(702, 290, 380, "Chatlog (leer = automatisch finden)", 9, "norm", BkC.dim)
    BkUi_Add("Edit", "x702 y310 w330 h24 vBkG_ChatlogPath gBkGui_Changed -E0x200 Border", "")
    BkUi_Button(1040, 308, 40, 28, "...", "BkGui_PickChatlog")
    BkGui_Check(702, 344, 380, "BkG_StartMin", "Beim Start nur im Infobereich (neben der Uhr)")
    BkUi_Text(702, 386, 200, "Akzentfarbe", 10)
    BkUi_Add("DropDownList", "x880 y382 w200 r6 vBkG_AccentName gBkGui_AccentChanged", "Orange|Blau|Grün|Rot|Lila|Türkis")
    BkUi_Text(702, 420, 380, "Die Farbe wird nach einem Neustart des Binders übernommen.", 8, "norm", BkC.faint)

    ; ---- 2: Texte & Werbung ----
    BkUi_Page("settings.2")
    BkUi_Card(240, 150, 420, 330, "Werbung (/ad)", "E789")
    for i, s in [["MemberAD", "Member-Suche  ·  {memberad}"], ["OrgAD", "Orgmember-Suche  ·  {orgad}"], ["SonstAD", "Sonstige Werbung  ·  {sonstad}"]] {
        BkUi_Text(262, 192 + (i - 1) * 62, 380, s[2], 9, "norm", BkC.dim)
        BkUi_Add("Edit", "x262 y" . (212 + (i - 1) * 62) . " w378 h24 vBkG_" . s[1] . " gBkGui_Changed -E0x200 Border", "")
    }
    BkUi_Text(262, 382, 380, "Drogen aus der Gangbox (Menge)  ·  {drogenbox}", 9, "norm", BkC.dim)
    BkUi_Add("Edit", "x262 y402 w120 h24 vBkG_Drogenbox gBkGui_Changed -E0x200 Border", "")
    BkUi_Card(680, 150, 420, 330, "Sprüche (/s)", "E8BD", "Spruch 1-4 nutzt auch der Zufallsspruch.")
    Loop, 6 {
        BkUi_Text(702, 204 + (A_Index - 1) * 42, 70, "Spruch " . A_Index, 9, "norm", BkC.dim)
        BkUi_Add("Edit", "x780 y" . (200 + (A_Index - 1) * 42) . " w300 h24 vBkG_Spruch" . A_Index . " gBkGui_Changed -E0x200 Border", "")
    }

    ; ---- 3: Waffen ----
    BkUi_Page("settings.3")
    BkUi_Card(240, 150, 330, 400, "Munition", "E7C1", "Für /deagle, /m4 ... und die Waffen-Tasten.")
    for i, s in BkCfg_Weapons() {
        BkUi_Text(262, 222 + (i - 1) * 42, 150, s[3], 10)
        BkUi_Add("Edit", "x430 y" . (218 + (i - 1) * 42) . " w80 h24 vBkG_Mun_" . s[1] . " gBkGui_Changed -E0x200 Border Number", "")
        BkUi_Add("UpDown", "vBkG_UdMun_" . s[1] . " Range0-9999 gBkGui_Changed", 0)
    }
    BkUi_Card(590, 150, 510, 400, "Waffenpakete", "E7B8", "/wp, /wp2, /wp3 und die Paket-Tasten kaufen alles auf einmal.")
    list := "–"
    for j, w in BkCfg_PackWeapons()
        list .= "|" . w
    Loop, 3 {
        p := A_Index
        y := 222 + (p - 1) * 104
        BkUi_Text(612, y, 300, "Paket " . p . ((p = 1) ? "  ·  /wp" : "  ·  /wp" . p), 10, "bold")
        Loop, 4 {
            x := 612 + (A_Index - 1) * 118
            BkUi_Add("DropDownList", "x" . x . " y" . (y + 28) . " w70 r12 vBkG_P" . p . "W" . A_Index . " gBkGui_Changed", list)
            BkUi_Add("Edit", "x" . (x + 74) . " y" . (y + 28) . " w36 h24 vBkG_P" . p . "M" . A_Index . " gBkGui_Changed -E0x200 Border Number", "")
        }
    }

    ; ---- 4: Programme & Radio ----
    BkUi_Page("settings.4")
    BkUi_Card(240, 150, 560, 550, "Programme", "E7AC")
    for i, s in [["PathTS", "TeamSpeak (leer = automatisch suchen)", "file"], ["PathGame", "SA-MP starten (samp.exe, leer = automatisch)", "file"]
               , ["PathRec", "Aufnahmeprogramm (Fraps, OBS ...)", "file"], ["RecFolder", "Ordner, in dem Aufnahmen landen", "dir"]
               , ["FragFolder", "Ziel für /frag (leer = Keybinder-Ordner)", "dir"], ["ComplaintFolder", "Ziel für /beschwerde (leer = Keybinder-Ordner)", "dir"]] {
        y := 192 + (i - 1) * 62
        BkUi_Text(262, y, 500, s[2], 9, "norm", BkC.dim)
        BkUi_Add("Edit", "x262 y" . (y + 20) . " w470 h24 vBkG_" . s[1] . " gBkGui_Changed -E0x200 Border", "")
        BkUi_Button(740, y + 18, 40, 28, "...", "BkGui_Pick_" . s[1])
    }
    BkUi_Text(262, 574, 300, "Taste, die die Aufnahme stoppt", 10)
    BkUi_Add("DropDownList", "x560 y570 w120 r13 vBkG_RecKey gBkGui_Changed", "F1|F2|F3|F4|F5|F6|F7|F8|F9|F10|F11|F12")
    BkUi_Text(262, 612, 520, "/frag und /beschwerde drücken diese Taste und verschieben das neueste Video (avi, mp4, mkv, mov).", 8, "norm", BkC.faint, "h32")

    BkUi_Card(820, 150, 280, 550, "Radio", "E8D6", "I Love Music - ohne VLC.")
    list := ""
    for i, r in BkRadio_Channels()
        list .= (i = 1 ? "" : "|") . r[1]
    BkUi_Text(840, 212, 240, "Sender", 9, "norm", BkC.dim)
    BkUi_Add("DropDownList", "x840 y232 w240 r12 vBkG_RadioChanName gBkGui_Changed AltSubmit", list)
    BkUi_Text(840, 272, 240, "Eigene Stream-Adresse (optional)", 9, "norm", BkC.dim)
    BkUi_Add("Edit", "x840 y292 w240 h24 vBkG_RadioUrl gBkGui_Changed -E0x200 Border", "")
    BkUi_Text(840, 332, 240, "Lautstärke", 9, "norm", BkC.dim)
    BkUi_Add("Edit", "x840 y352 w80 h24 vBkG_RadioVol gBkGui_Changed -E0x200 Border Number", "")
    BkUi_Add("UpDown", "vBkG_UdRadioVol Range0-100 gBkGui_Changed", 60)
    BkUi_Button(840, 400, 116, 36, "▶  Abspielen", "BkGui_RadioPlay", "primary")
    BkUi_Button(964, 400, 116, 36, "■  Stopp", "BkGui_RadioStopBtn")
    BkUi_Text(840, 452, 240, "Im Spiel: /iloveradio und /radiostop", 8, "norm", BkC.faint)

    ; ---- 5: Overlay ----
    BkUi_Page("settings.5")
    BkUi_Card(240, 150, 560, 400, "Overlay im Spiel", "E7F4", "Meldungen des Binders als kleine Karten über dem Spiel. Die Maus klickt durch.")
    BkGui_Check(262, 212, 500, "BkG_OvEnabled", "Overlay anzeigen")
    BkUi_Text(262, 254, 200, "Seite", 10)
    BkUi_Add("DropDownList", "x520 y250 w200 r3 vBkG_OvSide gBkGui_Changed", "links|rechts")
    BkUi_Text(262, 292, 250, "Anzeigedauer einer Meldung (Sekunden)", 10)
    BkUi_Add("Edit", "x520 y288 w80 h24 vBkG_OvToastSec gBkGui_Changed -E0x200 Border Number", "")
    BkUi_Text(262, 330, 250, "Im echten Vollbild", 10)
    BkUi_Add("DropDownList", "x520 y326 w260 r3 vBkG_OvFullscreen gBkGui_Changed AltSubmit", "Automatisch - im Vollbild aus (empfohlen)|Immer anzeigen")
    BkGui_Check(262, 370, 500, "BkG_OvHud", "Info-Leiste oben im Bild", "Zone, HP, Kills heute und K/D")
    BkUi_Button(262, 432, 170, 36, "Test-Meldung", "BkGui_OvTest", "primary")
    BkUi_Card(820, 150, 280, 400, "Vollbild?", "E7F7")
    BkUi_Text(840, 196, 240, "Im echten Vollbild kann Windows kein Fenster über GTA legen - das Bild würde kurz einfrieren. Dort ruht das Overlay automatisch, alles andere läuft normal weiter.`n`nWillst du die Meldungen sehen, starte GTA im Fenster oder im randlosen Fenster.`n`nAlle Meldungen stehen außerdem unter Übersicht > Letzte Meldungen.", 9, "norm", BkC.dim, "h320")
    BkUi_Font()
    BkUi_Page("*")
}

BkGui_SetSubClick() {
    global g_SetSubBtns
    MouseGetPos, , , , hw, 2
    for i, b in g_SetSubBtns
        if (hw = b.on || hw = b.off || hw = b.txt)
            return BkGui_Go("settings", i)
}

BkGui_SetSubRefresh() {
    global g_SetSubBtns, g_UiSub, BkC
    for i, b in g_SetSubBtns {
        on := (g_UiSub["settings"] = i)
        BkUi_ShowCtrl(b.on, on), BkUi_ShowCtrl(b.off, !on)
        Gui, Bk:Font, % "s9 bold c" . (on ? "111318" : BkC.text), Segoe UI
        GuiControl, Bk:Font, % b.txt
        BkUi_Repaint(b.txt)
    }
    BkUi_Font()
}

BkGui_AccentMap() {
    return {Orange: "FF8A1F", Blau: "4C9BFF", "Grün": "34C77B", Rot: "F0525A", Lila: "A879FF", "Türkis": "22C7C7"}
}

BkGui_AccentChanged() {
    global BK_Accent, BkG_AccentName
    Gui, Bk:Submit, NoHide
    m := BkGui_AccentMap()
    BK_Accent := m[BkG_AccentName]
    BkIni_Write("Allgemein", "Accent", BK_Accent)
    BkGui_Toast("Farbe gespeichert - wird nach einem Neustart übernommen.")
}

BkGui_PickChatlog() {
    FileSelectFile, f, 3, , Chatlog auswählen, Textdateien (*.txt)
    if (f != "")
        GuiControl, Bk:, BkG_ChatlogPath, %f%
}
BkGui_PickPath(var, dir) {
    if (dir)
        FileSelectFolder, f, , 3, Ordner auswählen
    else
        FileSelectFile, f, 3, , Programm auswählen, Programme (*.exe)
    if (f != "")
        GuiControl, Bk:, BkG_%var%, %f%
}
BkGui_Pick_PathTS() {
    BkGui_PickPath("PathTS", false)
}
BkGui_Pick_PathGame() {
    BkGui_PickPath("PathGame", false)
}
BkGui_Pick_PathRec() {
    BkGui_PickPath("PathRec", false)
}
BkGui_Pick_RecFolder() {
    BkGui_PickPath("RecFolder", true)
}
BkGui_Pick_FragFolder() {
    BkGui_PickPath("FragFolder", true)
}
BkGui_Pick_ComplaintFolder() {
    BkGui_PickPath("ComplaintFolder", true)
}
BkGui_RadioPlay() {
    BkGui_Apply()
    BkRadio_Play()
}
BkGui_RadioStopBtn() {
    BkRadio_Stop()
}
BkGui_OvTest() {
    BkGui_Apply()
    BkMsg("So sehen Meldungen im Spiel aus. Die Maus klickt einfach durch.", "info")
    if (!BkOv_Allowed())
        BkGui_Toast(BkGame_Hwnd() ? "Overlay ruht (Vollbild oder ausgeschaltet)." : "Das Overlay erscheint, sobald GTA läuft.")
}

; =====================================================================
;  Seite: Hilfe & Info
; =====================================================================
BkGui_BuildHelp() {
    global
    local txt
    BkUi_Page("help")
    BkUi_Card(240, 100, 520, 600, "So funktioniert's", "E82D")
    txt := "1.  Profil & Job einstellen: Zivilist, Gang oder Staatsfraktion - dazu dein Job.`n`n"
        . "2.  Unter ""Tasten"" jeder Aktion eine Taste geben. Tasten wirken nur im Spiel und nie, während du im Chat tippst.`n`n"
        . "3.  Chat-Befehle wie /kd, /wp, /map 1.1 einfach im Spiel tippen und Enter drücken.`n`n"
        . "4.  Texte kannst du überall anpassen. Platzhalter wie {zone}, {hp}, {id} füllt der Binder selbst aus.`n`n"
        . "5.  Pause (Taste Pause) schaltet den Binder im Spiel an und aus, Alt+F2 startet ihn neu.`n`n"
        . "Der Binder braucht keine Zusatzdateien und keinen bestimmten Launcher. Er liest nur aus dem Spiel (Standort, HP, Chat offen?) und tippt wie eine Tastatur - es wird nichts injiziert.`n`n"
        . "Unterstützt: SA-MP 0.3.7 (R1, R3, R5) und 0.3.DL mit voller Erkennung, alle anderen Versionen über die Tasten-Erkennung. Deine alten Tasten, Texte, Gegnerlisten und die Statistik aus Version 4.x werden beim ersten Start übernommen."
    BkUi_Text(262, 146, 476, txt, 10, "norm", BkC.text, "h430")
    BkUi_Button(262, 640, 150, 36, "Ordner öffnen", "BkGui_OpenDir")
    BkUi_Button(420, 640, 150, 36, "Anleitung", "BkGui_OpenManual")
    BkUi_Button(578, 640, 164, 36, "Stadtplan-Liste", "BkGui_MapList")

    BkUi_Card(780, 100, 320, 380, "Diagnose", "E9D9")
    g_H.diag := BkUi_Text(800, 144, 284, "", 9, "norm", BkC.dim, "h280")
    BkUi_Button(800, 430, 138, 34, "Aktualisieren", "BkGui_DiagRefresh")
    BkUi_Button(946, 430, 138, 34, "Chatlog", "BkGui_OpenChatlog")
    BkUi_Card(780, 500, 320, 200, "Neu in 5.0", "E735")
    BkUi_Text(800, 540, 284, "• Keine Brooklyn.dll, kein Dropbox, kein Server nötig`n• Neuere SA-MP-Versionen, jeder Server`n• Profile: Zivilist, Gang, Staat + 13 Jobs`n• Neues Design, alles sofort gespeichert`n• Radio ohne VLC, Overlay statt Chat-Einblendung", 9, "norm", BkC.dim, "h150")
    BkUi_Font()
}

BkGui_DiagRefresh() {
    global g_H, g_GuiBuilt, g_ChatFile, BK_MemEnabled, BK_Version
    if (!g_GuiBuilt)
        return
    hw := BkGame_Hwnd()
    ver := BkSamp_VersionName()
    loc := BkSamp_Local()
    cnt := BkSamp_OnlineCount()
    t := "Keybinder:  " . BK_Version . (A_IsCompiled ? "" : " (Skript)") . "`n"
    t .= "Spiel:  " . (hw ? "läuft" . (BkGame_Fullscreen() ? " (Vollbild)" : "") : "nicht gestartet") . "`n"
    t .= "Spielspeicher:  " . (!BK_MemEnabled ? "aus" : BkMem_Active() ? "lesbar" : "–") . "`n"
    t .= "SA-MP:  " . (ver != "" ? ver : hw ? "noch nicht erkannt" : "–") . "`n"
    t .= "Dein Name:  " . BkMyName() . "`n"
    t .= "Deine ID:  " . (IsObject(loc) ? loc.id : "–") . "`n"
    t .= "Spieler online:  " . (cnt != "" ? cnt : "–") . "`n"
    t .= "Chatlog:  " . (BkChatlog_Found() ? "gefunden" : "fehlt noch") . "`n"
    t .= "Overlay:  " . (BkOv_Allowed() ? "bereit" : "ruht") . "`n`n"
    t .= "Wenn SA-MP nicht erkannt wird, funktionieren Tasten trotzdem - nur Chat-Erkennung, ID und Spielerliste fehlen dann."
    BkUi_Set(g_H.diag, t)
}

BkGui_OpenChatlog() {
    global g_ChatFile
    if FileExist(g_ChatFile)
        Run, notepad.exe "%g_ChatFile%"
    else
        BkGui_Toast("Chatlog noch nicht vorhanden - einmal SA-MP starten.")
}

BkGui_OpenManual() {
    p := A_ScriptDir . "\ANLEITUNG.txt"
    if FileExist(p)
        Run, notepad.exe "%p%"
    else
        BkGui_Toast("ANLEITUNG.txt liegt nicht neben dem Programm.")
}

BkGui_MapList() {
    global BkC
    Gui, BkMap:New, +OwnerBk +ToolWindow, Stadtplan - /map <Nr>
    Gui, BkMap:Color, % BkC.bg, % BkC.card
    Gui, BkMap:Font, % "s9 c" . BkC.text, Segoe UI
    Gui, BkMap:Add, ListView, % "x10 y10 w520 h460 LV0x10000 Background" . BkC.card . " c" . BkC.text, Nr|Gebäude
    for k, v in BkMapDB()
        LV_Add("", k, v)
    LV_ModifyCol(1, "80 Logical"), LV_ModifyCol(2, 420), LV_ModifyCol(1, "Sort Logical")
    Gui, BkMap:Show, w540 h480
    Gui, BkMap:+LastFound
    BkDark_Apply(WinExist())
    BkDark_Window(WinExist())
}

; =====================================================================
;  Werte laden / Aenderungen uebernehmen
; =====================================================================
BkGui_LoadValues() {
    global
    local i, w, p, e, n, jl, names, a
    g_Loading := true
    ; Profil
    BkGui_FactionList()
    jl := ""
    for i, e in BkProf_Jobs()
        jl .= "|" . e.name
    GuiControl, Bk:, BkG_Job, %jl%
    GuiControl, Bk:ChooseString, BkG_Job, % BkProf_JobName(BK_ProfJob)
    GuiControl, Bk:, BkG_Name, %BK_Name%
    for i, n in ["FChat", "GChat", "Funk", "DChat", "ChatKey", "LineDelay", "SendDelay", "GameExes", "ChatlogPath"
               , "MemberAD", "OrgAD", "SonstAD", "Drogenbox", "GWZ", "GZZ", "PathTS", "PathGame", "PathRec", "RecFolder"
               , "FragFolder", "ComplaintFolder", "RadioUrl", "RadioVol"]
        GuiControl, Bk:, BkG_%n%, % BK_%n%
    Loop, 6
        GuiControl, Bk:, BkG_Spruch%A_Index%, % BK_Spruch%A_Index%
    for i, n in ["FastSend", "MemEnabled", "ShowAll", "StartMin", "AutoGW", "AutoGZ", "GWLoc", "GZLoc", "AutoWantedKill", "AutoTot"
               , "Arrestsage", "MemDeath", "HackMsg", "ClearMsg", "LawyerMsg", "Drogensage", "TimerFrage", "Antispam", "Welcome"
               , "OvEnabled", "OvHud"]
        BkUi_TogSet("BkG_" . n, BK_%n%)
    for i, w in BkCfg_Weapons()
        GuiControl, Bk:, % "BkG_Mun_" . w[1], % BkCfg_Get("Mun_" . w[1])
    Loop, 3 {
        p := A_Index
        names := StrSplit(BK_Pack%p%, "|")
        Loop, 4 {
            e := StrSplit(names[A_Index], ":")
            if (Trim(e[1]) != "") {
                GuiControl, Bk:ChooseString, BkG_P%p%W%A_Index%, % Trim(e[1])
                GuiControl, Bk:, BkG_P%p%M%A_Index%, % e[2]
            } else {
                GuiControl, Bk:Choose, BkG_P%p%W%A_Index%, 1
            }
        }
    }
    GuiControl, Bk:ChooseString, BkG_RecKey, % BK_RecKey
    GuiControl, Bk:Choose, BkG_RadioChanName, % (BK_RadioChan + 0 >= 1) ? BK_RadioChan : 1
    GuiControl, Bk:ChooseString, BkG_OvSide, % BK_OvSide
    GuiControl, Bk:, BkG_OvToastSec, % Round(BK_OvToastMs / 1000)
    GuiControl, Bk:Choose, BkG_OvFullscreen, % (BK_OvFullscreen = "immer") ? 2 : 1
    for n, a in BkGui_AccentMap()
        if (a = BK_Accent)
            GuiControl, Bk:ChooseString, BkG_AccentName, %n%
    BkGui_GroupDDL("BkG_KeyGroup")
    BkGui_GroupDDL("BkG_ChatGroup")
    BkGui_KillPreview()
    g_Loading := false
}

BkGui_Changed() {
    global g_Loading
    if (g_Loading)
        return
    SetTimer, BkGuiApply, -350
}

BkGui_Apply() {
    global
    local i, n, w, p, v, pk, oldKey, oldMem
    if (!g_GuiBuilt)
        return
    Gui, Bk:Submit, NoHide
    oldKey := BK_ChatKey, oldMem := BK_MemEnabled
    for i, n in ["LineDelay", "SendDelay", "GameExes", "ChatlogPath", "MemberAD", "OrgAD", "SonstAD", "Drogenbox", "GWZ", "GZZ"
               , "PathTS", "PathGame", "PathRec", "RecFolder", "FragFolder", "ComplaintFolder", "RadioUrl", "RadioVol", "RecKey", "OvSide"]
        BK_%n% := BkG_%n%
    Loop, 6
        BK_Spruch%A_Index% := BkG_Spruch%A_Index%
    for i, n in ["FastSend", "MemEnabled", "ShowAll", "StartMin", "AutoGW", "AutoGZ", "GWLoc", "GZLoc", "AutoWantedKill", "AutoTot"
               , "Arrestsage", "MemDeath", "HackMsg", "ClearMsg", "LawyerMsg", "Drogensage", "TimerFrage", "Antispam", "Welcome"
               , "OvEnabled", "OvHud"]
        BK_%n% := BkUi_TogGet("BkG_" . n)
    v := Trim(BkG_ChatKey)
    if (v != "" && GetKeyVK(v))
        BK_ChatKey := v
    for i, w in BkCfg_Weapons() {
        n := w[1]
        BkCfg_Set("Mun_" . n, BkG_Mun_%n% + 0)
    }
    Loop, 3 {
        p := A_Index, pk := ""
        Loop, 4 {
            w := BkG_P%p%W%A_Index%
            if (w != "" && w != "–")
                pk .= (pk = "" ? "" : "|") . w . ":" . ((BkG_P%p%M%A_Index% + 0 > 0) ? BkG_P%p%M%A_Index% + 0 : 1)
        }
        BK_Pack%p% := pk
    }
    BK_RadioChan := BkG_RadioChanName + 0
    BK_OvToastMs := (BkG_OvToastSec + 0 >= 1) ? BkG_OvToastSec * 1000 : 5000
    BK_OvFullscreen := (BkG_OvFullscreen = 2) ? "immer" : "auto"
    if (BK_SendWaitMs < 300)
        BK_SendWaitMs := 700
    BkRadio_Volume(BK_RadioVol)
    BkCfg_Save()
    if (oldKey != BK_ChatKey)
        BkRegisterHotkeys()
    if (oldMem != BK_MemEnabled && !BK_MemEnabled)
        BkMem_Close()
    BkGame_Groups()
    BkGui_KillPreview()
}

BkGui_KillPreview() {
    global g_H, BK_GWZ, BK_GWLoc, BK_FChat
    BkUi_Set(g_H.killPrev, BK_FChat . " " . BK_GWZ . (BK_GWLoc ? " in Idlewood" : "") . " - Kill Nr. " . (BkStats_Get("kills") + 1))
}

; =====================================================================
;  Status (Seitenleiste) und Pause
; =====================================================================
BkGui_StatusRefresh() {
    global g_GuiBuilt, g_H, BK_Paused, BkC, BK_ProfType, BK_ProfFaction, BK_ProfJob
    static lastSig := ""
    if (!g_GuiBuilt)
        return
    hw := BkGame_Hwnd()
    ver := BkSamp_VersionName()
    if (BK_Paused)
        st := "Pausiert", col := BkC.gold
    else if (hw)
        st := "Spiel läuft", col := BkC.ok
    else
        st := "Spiel nicht gestartet", col := BkC.faint
    prof := (BK_ProfType = "gang") ? "Gang" : (BK_ProfType = "staat") ? "Staat" : "Zivilist"
    if (BK_ProfType != "zivi" && BK_ProfFaction != "")
        prof .= " · " . BK_ProfFaction
    prof .= "`nJob: " . BkProf_JobName(BK_ProfJob)
    sig := st . "|" . ver . "|" . prof
    if (sig == lastSig)
        return
    lastSig := sig
    Gui, Bk:Font, s10 c%col%, Segoe UI
    GuiControl, Bk:Font, % g_H.dot
    BkUi_Font()
    BkUi_Set(g_H.game, st)
    BkUi_Set(g_H.samp, "SA-MP: " . (ver != "" ? ver : hw ? "wird gesucht ..." : "–"))
    BkUi_Set(g_H.prof, prof)
    BkUi_Set(g_H.pauseBtn.txt, BK_Paused ? "Fortsetzen" : "Pausieren")
    BkUi_Repaint(g_H.dot)
}

BkGui_PauseClick() {
    BkFn_TogglePause()
}

BkGuiClose() {
    global g_GuiVisible
    Gui, Bk:Hide
    g_GuiVisible := false
    BkCfg_Save()
    BkStats_Save()
    static told := false
    if (!told) {
        told := true
        TrayTip, Brooklyn Keybinder, Läuft im Hintergrund weiter. Doppelklick auf das Symbol öffnet das Fenster wieder., 3
    }
}
