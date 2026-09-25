; =====================================================================
;  Yakuza Keybinder - Fenster: Meldungen, Familie, Overlay, Sprint,
;  Extras, Einstellungen - und Laden/Uebernehmen der Werte
; =====================================================================

global g_MemRows := []

; ---------------------------------------------------------------------
;  Welches Feld gehoert zu welcher Einstellung?
;    [Steuerelement, Variable, Art]   Art: t = Text, h = Taste, n = Zahl
; ---------------------------------------------------------------------
YkGui_FieldMap() {
    return [["YkG_LocHk", "YK_LocHotkey", "h"], ["YkG_GangCmd", "YK_GangCmd", "t"], ["YkG_LocText", "YK_LocText", "t"]
        , ["YkG_FamCmd", "YK_FamCommand", "t"], ["YkG_FamHk", "YK_FamHotkey", "h"], ["YkG_FamPat", "YK_FamLoginPat", "t"], ["YkG_FamDelay", "YK_FamDelay", "n"]
        , ["YkG_OwnName", "YK_OwnName", "t"], ["YkG_KillHk", "YK_KillHotkey", "h"], ["YkG_KillText", "YK_KillText", "t"], ["YkG_DeathText", "YK_DeathText", "t"]
        , ["YkG_KillPat", "YK_KillPattern", "t"], ["YkG_DeathPat", "YK_DeathPattern", "t"]
        , ["YkG_KillWin", "YK_KillWindowMs", "n"], ["YkG_KillRiv", "YK_KillRivalMs", "n"], ["YkG_KillSame", "YK_KillSameMs", "n"]
        , ["YkG_Faction", "YK_Faction", "t"], ["YkG_GangTag", "YK_GangTag", "t"], ["YkG_FamChat", "YK_FamChat", "t"], ["YkG_MemHk", "YK_MemHotkey", "h"]
        , ["YkG_MarkMin", "YK_MarkMinutes", "n"]
        , ["YkG_OvHk", "YK_OvHotkey", "h"], ["YkG_OvWarSec", "YK_WarNoteSec", "n"]
        , ["YkG_SprintHk", "YK_SprintToggleHk", "h"], ["YkG_TapDown", "YK_SprintTapDown", "n"], ["YkG_Crouch", "YK_CrouchKey", "t"]
        , ["YkG_SprintKey", "YK_SprintKey", "t"], ["YkG_MoveKeys", "YK_SprintMoveKeys", "t"]
        , ["YkG_StatsKill", "YK_StatsKillPat", "t"], ["YkG_StatsDeath", "YK_StatsDeathPat", "t"]
        , ["YkG_WantCmd", "YK_WantedCmd", "t"], ["YkG_WantWait", "YK_WantedWaitMs", "n"], ["YkG_WantPat", "YK_WantedPat", "t"]
        , ["YkG_LottoCount", "YK_LottoCount", "n"], ["YkG_LottoGap", "YK_LottoGapMs", "n"], ["YkG_LottoCmd", "YK_LottoCmd", "t"]
        , ["YkG_LottoPat", "YK_LottoPat", "t"], ["YkG_LottoMin", "YK_LottoMin", "n"], ["YkG_LottoMax", "YK_LottoMax", "n"]
        , ["YkG_SmsCmd", "YK_SmsCmd", "t"], ["YkG_SmsPat", "YK_SmsPattern", "t"]
        , ["YkG_RecFolder", "YK_RecFolder", "t"], ["YkG_RecKey", "YK_RecKey", "t"], ["YkG_RecStopKey", "YK_RecStopKey", "t"], ["YkG_RadioUrl", "YK_RadioUrl", "t"]
        , ["YkG_ChatKey", "YK_ChatKey", "t"], ["YkG_SendDelay", "YK_SendDelay", "n"], ["YkG_LineDelay", "YK_LineDelay", "n"]
        , ["YkG_ExOrder", "YK_ExtrasOrder", "t"], ["YkG_GameExes", "YK_GameExes", "t"], ["YkG_PathGame", "YK_PathGame", "t"]
        , ["YkG_Chatlog", "YK_ChatlogPath", "t"], ["YkG_WarGang", "YK_WarGangPat", "t"], ["YkG_WarFam", "YK_WarFamPat", "t"]
        , ["YkG_WarBiz", "YK_WarBizPat", "t"], ["YkG_UpdUrl", "YK_UpdUrl", "t"]]
}

YkGui_ToggleMap() {
    return [["YkG_FamOn", "YK_FamEnabled"], ["YkG_Combat", "YK_CombatEnabled"], ["YkG_KillOn", "YK_KillEnabled"], ["YkG_DeathOn", "YK_DeathEnabled"]
        , ["YkG_KillLog", "YK_KillLogOn"], ["YkG_MarkOn", "YK_MarkEnabled"], ["YkG_MarkGps", "YK_MarkSendGps"], ["YkG_OvOn", "YK_OvEnabled"]
        , ["YkG_OvDodge", "YK_OvDodge"], ["YkG_OvStatus", "YK_OvStatus"], ["YkG_OvWar", "YK_OvWar"], ["YkG_OvMem", "YK_MemShow"]
        , ["YkG_OvKeys", "YK_OvShowKeys"], ["YkG_OvNoCap", "YK_OvHideCapture"], ["YkG_ToastOn", "YK_ToastOn"], ["YkG_Sprint", "YK_SprintEnabled"]
        , ["YkG_OnFoot", "YK_SprintOnFoot"], ["YkG_ReqMove", "YK_SprintReqMove"], ["YkG_StatsOn", "YK_StatsEnabled"], ["YkG_WantOn", "YK_WantedEnabled"]
        , ["YkG_LottoOn", "YK_LottoOn"], ["YkG_Fast", "YK_FastSend"], ["YkG_Mem", "YK_MemEnabled"], ["YkG_Kurz", "YK_KurzEnabled"]
        , ["YkG_TbOn", "YK_TbEnabled"], ["YkG_StartPaused", "YK_StartPaused"], ["YkG_StallLog", "YK_StallLog"], ["YkG_UpdOn", "YK_UpdEnabled"]
        , ["YkG_UpdAuto", "YK_UpdAuto"], ["YkG_Victim", "YK_PlrEnabled"]]
}

; =====================================================================
;  Seite: Meldungen & Kampf
; =====================================================================
YkGui_BuildAuto() {
    global
    YkUi_Page("auto")
    YkUi_Card(240, 100, 420, 176, "Standort", "E707")
    YkGui_Field(262, 142, 110, "Taste", 140, "YkG_LocHk", "", "Hotkey")
    YkUi_Text(528, 146, 60, "Kanal", 10)
    YkUi_Add("Edit", "x580 y142 w60 h24 vYkG_GangCmd gYkGui_Changed -E0x200 Border", "")
    YkGui_Field(262, 176, 110, "Text", 268, "YkG_LocText")
    YkUi_Text(262, 210, 380, "Kanal = Gang-/Mafienchat (Standard /g). Der Standort-Text geht mit Strg+G raus.", 8, "norm", YkCol.faint, "h40")

    YkUi_Card(680, 100, 420, 176, "/familymap beim Login", "E7FC")
    YkUi_Toggle(700, 140, 380, "YkG_FamOn", "Automatisch nach dem Einloggen senden")
    YkGui_Field(700, 176, 90, "Befehl", 110, "YkG_FamCmd")
    YkUi_Text(912, 180, 50, "Taste", 10)
    YkUi_Add("Hotkey", "x960 y176 w120 h24 vYkG_FamHk gYkGui_Changed", "")
    YkGui_Field(700, 208, 90, "Login-Zeile", 290, "YkG_FamPat")
    YkGui_Field(700, 240, 90, "Warten (ms)", 80, "YkG_FamDelay", "Number")

    YkUi_Card(240, 292, 860, 408, "Kills und Tode im Gang-/Mafienchat", "E7C1")
    YkUi_Toggle(262, 332, 380, "YkG_Combat", "Meldungen aktiv")
    YkGui_Field(262, 368, 110, "Dein Name", 150, "YkG_OwnName")
    YkUi_Text(530, 372, 130, "lernt der Binder selbst", 8, "norm", YkCol.faint)
    YkUi_Toggle(262, 404, 250, "YkG_KillOn", "Kills automatisch melden")
    YkUi_Text(520, 406, 50, "Taste", 10)
    YkUi_Add("Hotkey", "x570 y402 w90 h24 vYkG_KillHk gYkGui_Changed", "")
    YkGui_Field(262, 440, 110, "Kill-Text", 288, "YkG_KillText")
    YkUi_Toggle(262, 476, 398, "YkG_DeathOn", "Tode melden  (Sterbeort, im War sofort)")
    YkGui_Field(262, 512, 110, "Tod-Text", 288, "YkG_DeathText")
    YkGui_Field(262, 546, 110, "Medic-Text", 288, "YkG_RevText")
    YkUi_Text(262, 580, 398, "Medic-Text geht raus, wenn dich jemand wiederbelebt (leer = aus).`nPlatzhalter: {standort} {opfer} {mörder} {kills} {tode} {hp} ...", 8, "norm", YkCol.faint, "h40")
    YkUi_Button(262, 632, 190, 36, "Platzhalter-Liste", "YkGui_PhList")

    YkUi_Text(700, 334, 380, "Nur ändern, wenn dein Server anders schreibt:", 9, "norm", YkCol.dim)
    YkGui_Field(700, 360, 100, "Kill-Zeile", 280, "YkG_KillPat")
    YkGui_Field(700, 394, 100, "Tod-Zeile", 280, "YkG_DeathPat")
    YkUi_Text(700, 440, 380, "Zeiten der Kill-Erkennung (ms)", 10, "bold")
    YkUi_Text(700, 468, 110, "Fall", 9, "norm", YkCol.dim)
    YkUi_Text(826, 468, 110, "fremd", 9, "norm", YkCol.dim)
    YkUi_Text(952, 468, 110, "doppelt", 9, "norm", YkCol.dim)
    YkUi_Add("Edit", "x700 y488 w110 h24 vYkG_KillWin gYkGui_Changed -E0x200 Border Number", "")
    YkUi_Add("Edit", "x826 y488 w110 h24 vYkG_KillRiv gYkGui_Changed -E0x200 Border Number", "")
    YkUi_Add("Edit", "x952 y488 w110 h24 vYkG_KillSame gYkGui_Changed -E0x200 Border Number", "")
    YkUi_Text(700, 520, 380, "Hoher Ping? ""Fall"" hochsetzen (z.B. 900). Im Rudel unterwegs? ""fremd"" hochsetzen. Erklärung: Anleitung, Punkt 4.", 8, "norm", YkCol.faint, "h30")
    YkUi_Toggle(700, 566, 380, "YkG_Victim", "Gegnernamen aus SA-MP lesen ({opfer})")
    YkUi_Toggle(700, 604, 380, "YkG_KillLog", "Kill-Protokoll schreiben", "YakuzaKills.log - nur zum Nachprüfen")
    YkUi_Font()
}

YkGui_PhList() {
    t := ""
    for i, p in YkPlaceholderList()
        t .= p[1] . "   " . p[2] . "`n"
    MsgBox, 64, Platzhalter, %t%
}

; =====================================================================
;  Seite: Familie & Member
; =====================================================================
YkGui_BuildFamily() {
    global
    YkUi_Page("family")
    YkUi_Card(240, 100, 420, 330, "Familie", "E902")
    YkGui_Field(262, 142, 100, "Fraktion", 120, "YkG_Faction")
    YkUi_Text(500, 146, 70, "Chat-Tag", 10)
    YkUi_Add("Edit", "x570 y142 w70 h24 vYkG_GangTag gYkGui_Changed -E0x200 Border", "")
    YkGui_Field(262, 176, 100, "Family-Chat", 70, "YkG_FamChat")
    YkUi_Text(440, 180, 80, "{fchat}", 8, "norm", YkCol.faint)
    YkUi_Text(500, 180, 60, "Member", 10)
    YkUi_Add("Hotkey", "x570 y176 w70 h24 vYkG_MemHk gYkGui_Changed", "")
    YkUi_Toggle(262, 214, 290, "YkG_MarkOn", "Backup-Rufe als Fahne auf der Karte")
    YkUi_Add("Edit", "x560 y212 w40 h24 vYkG_MarkMin gYkGui_Changed -E0x200 Border Number", "")
    YkUi_Text(606, 216, 50, "Min", 9, "norm", YkCol.dim)
    YkUi_Toggle(262, 250, 380, "YkG_MarkGps", "Eigene Backup-Rufe mit Koordinaten senden", "(GPS x y) - damit sehen dich die anderen genau")
    YkUi_Text(262, 306, 90, "Ton Ruf", 10)
    YkUi_Add("DropDownList", "x352 y302 w220 r8 vYkG_SndCall gYkGui_SndPick", YkSound_Choices())
    YkUi_Button(580, 300, 60, 28, "▶", "YkGui_SndTestCall")
    YkUi_Text(262, 342, 90, "Ton Angriff", 10)
    YkUi_Add("DropDownList", "x352 y338 w220 r8 vYkG_SndWar gYkGui_SndPick", YkSound_Choices())
    YkUi_Button(580, 336, 60, 28, "▶", "YkGui_SndTestWar")
    YkUi_Text(262, 378, 380, "Die Fahne verschwindet bei Ankunft, Tod, Absage und spätestens nach der eingestellten Zeit.", 8, "norm", YkCol.faint, "h36")

    YkUi_Card(240, 446, 420, 254, "Kriege", "E7C1")
    g_H.wars := YkUi_Text(262, 486, 380, "kein Krieg", 9, "norm", "", "h150")
    YkUi_Text(262, 646, 380, "Stand kommt sekundengenau aus der Anzeige des Servers. Grün = ihr führt, rot = ihr liegt zurück.", 8, "norm", YkCol.faint, "h40")

    YkUi_Card(680, 100, 420, 600, "Member  ·  Ziel wählen", "E716")
    YkUi_Text(700, 136, 380, "Doppelklick auf einen Member = ""Ich bin unterwegs zu ihm"".", 9, "norm", YkCol.dim)
    Gui, Yk:Font, % "s9 norm c" . YkCol.text, Segoe UI
    YkUi_Add("ListView", "-E0x200 x696 y162 w388 h380 vYkG_LvMem gYkGui_MemLv -Multi AltSubmit NoSortHdr LV0x10000 Background" . YkCol.card . " c" . YkCol.text, "Ziel|Member|Standort|Entf.|Info|Wann")
    YkUi_Button(696, 554, 124, 34, "Als Ziel setzen", "YkGui_MemTarget", "primary")
    YkUi_Button(828, 554, 120, 34, "Ziel löschen", "YkGui_MemTargetOff")
    YkUi_Button(956, 554, 128, 34, "Liste leeren", "YkGui_MemClear")
    YkUi_Text(700, 600, 384, "Füllt sich von selbst aus /g und /f.`nIm Chat:  /ykzu Marci + Leertaste  ·  /ykzu1 bis /ykzu9  ·  /ykzuaus`n/ykpos an/aus  ·  /ykclear leeren  ·  /ykhud Overlay", 8, "norm", YkCol.faint, "h60")
    YkUi_Font()
}

; Member-Liste. Die erste Spalte zeigt mit einem Pfeil, zu wem man gerade
; unterwegs ist. Die Reihenfolge ist dieselbe wie im Overlay - dadurch
; passen die Chat-Befehle /ykzu1 bis /ykzu9 genau dazu.
YkMemLV_Fill() {
    global g_GuiBuilt, g_MemRows
    ; nicht unterbrechen: ein Listen-Ereignis dazwischen wuerde die
    ; gewaehlte Liste umstellen (die Auswahl gilt je Fenster, nicht je Thread)
    wasCrit := A_IsCritical
    Critical
    if (!g_GuiBuilt)
        return YkGui_CritEnd(wasCrit)
    Gui, Yk:Default                 ; auch aus Timern (Chatlog) aufgerufen
    Gui, Yk:ListView, YkG_LvMem
    GuiControl, Yk:-Redraw, YkG_LvMem
    LV_Delete()
    g_MemRows := []
    pos := YkCurrentPos()
    for i, o in YkMembers_Sorted(50) {
        info := YkMembers_KindText(o)
        if (o.hp != "" && !o.dead)
            info := (info != "") ? info . " (" . o.hp . ")" : o.hp . " HP"
        s := (A_TickCount - o.t) // 1000
        age := (s < 60) ? "jetzt" : (s < 3600) ? (s // 60) . " Min" : (s // 3600) . " Std"
        LV_Add("", (o.target ? "→" : ""), o.name, o.loc, Trim(YkMembers_DistText(o.loc, pos, o.gx, o.gy)), info, age)
        g_MemRows.Push(o.name)
    }
    LV_ModifyCol(1, 30), LV_ModifyCol(2, 74), LV_ModifyCol(3, 104), LV_ModifyCol(4, 54), LV_ModifyCol(5, 64), LV_ModifyCol(6, 42)
    GuiControl, Yk:+Redraw, YkG_LvMem
    YkGui_CritEnd(wasCrit)
}

YkMemLV_Selected() {
    global g_MemRows
    ; nicht unterbrechen: ein Listen-Ereignis dazwischen wuerde die
    ; gewaehlte Liste umstellen (die Auswahl gilt je Fenster, nicht je Thread)
    wasCrit := A_IsCritical
    Critical
    Gui, Yk:Default
    Gui, Yk:ListView, YkG_LvMem
    row := LV_GetNext()
    if (!row || !IsObject(g_MemRows))
        return YkGui_CritEnd(wasCrit, "")
    return YkGui_CritEnd(wasCrit, g_MemRows[row])
    YkGui_CritEnd(wasCrit)
}

YkGui_MemLv() {
    global g_MemRows
    if (A_GuiEvent != "DoubleClick")
        return
    row := A_EventInfo
    if (row && IsObject(g_MemRows) && g_MemRows[row] != "")
        YkTarget_Set(g_MemRows[row])
}

YkGui_MemTarget() {
    n := YkMemLV_Selected()
    if (n = "")
        YkGui_Toast("Bitte zuerst einen Member in der Liste anklicken.")
    else
        YkTarget_Set(n)
}

YkGui_MemTargetOff() {
    YkTarget_Clear()
}

YkGui_MemClear() {
    YkMembers_Clear()
    YkMemLV_Fill()
}

YkGui_WarsRefresh() {
    global g_H, g_GuiBuilt
    if (!g_GuiBuilt)
        return
    t := ""
    for i, w in YkWar_List()
        t .= (t = "" ? "" : "`n`n") . w.text
    YkUi_Set(g_H.wars, (t = "") ? "Gerade läuft kein Krieg." : t)
}

; Ton-Auswahl: "Eigene Datei..." fragt nach der Datei
YkGui_SndPick(hCtrl := "") {
    global g_Loading, YK_WarSoundFile, YK_CallSoundFile, YK_WarSoundType, YK_CallSoundType
    if (g_Loading)
        return
    ctl := A_GuiControl
    GuiControlGet, t, Yk:, %ctl%
    if (t = "Eigene Datei...") {
        prev := (ctl = "YkG_SndWar") ? YK_WarSoundFile : YK_CallSoundFile
        FileSelectFile, f, 3, %prev%, Ton auswählen, Töne (*.wav; *.mp3)
        if (f = "") {
            g_Loading := true
            GuiControl, Yk:Choose, %ctl%, % YkSound_Index((ctl = "YkG_SndWar") ? YK_WarSoundType : YK_CallSoundType)
            g_Loading := false
            return
        }
        if (ctl = "YkG_SndWar")
            YK_WarSoundFile := f
        else
            YK_CallSoundFile := f
    }
    YkGui_Changed()
}

YkGui_SndTestCall() {
    global YK_CallSoundFile
    GuiControlGet, t, Yk:, YkG_SndCall
    YkSound_PlayKey(YkSound_Key(t), YK_CallSoundFile)
}

YkGui_SndTestWar() {
    global YK_WarSoundFile
    GuiControlGet, t, Yk:, YkG_SndWar
    YkSound_PlayKey(YkSound_Key(t), YK_WarSoundFile)
}

; =====================================================================
;  Seite: Overlay
; =====================================================================
YkGui_BuildOverlay() {
    global
    YkUi_Page("overlay")
    YkUi_Card(240, 100, 420, 600, "Overlay im Spiel", "E7F4")
    YkUi_Toggle(262, 140, 230, "YkG_OvOn", "Overlay anzeigen")
    YkUi_Text(500, 142, 60, "Taste", 10)
    YkUi_Add("Hotkey", "x550 y138 w90 h24 vYkG_OvHk gYkGui_Changed", "")
    YkUi_Text(262, 182, 60, "Seite", 10)
    YkUi_Add("DropDownList", "x330 y178 w110 r3 vYkG_OvSide gYkGui_Changed AltSubmit", "Links|Rechts")
    YkUi_Text(462, 182, 60, "Größe", 10)
    YkUi_Add("DropDownList", "x530 y178 w110 r3 vYkG_OvSize gYkGui_Changed AltSubmit", "Klein|Normal|Groß")
    YkUi_Text(262, 220, 60, "Höhe", 10)
    YkUi_Text(330, 222, 36, "oben", 8, "norm", YkCol.faint)
    YkUi_Add("Slider", "x366 y216 w226 h28 vYkG_OvVPos gYkGui_Changed Range0-100 TickInterval25 ToolTip AltSubmit", 100)
    YkUi_Text(598, 222, 44, "unten", 8, "norm", YkCol.faint)
    YkUi_Text(262, 260, 80, "Deckkraft", 10)
    YkUi_Add("DropDownList", "x350 y256 w120 r4 vYkG_OvOpac gYkGui_Changed AltSubmit", "60 %|75 %|85 %|95 %")
    YkUi_Text(262, 298, 80, "Vollbild", 10)
    YkUi_Add("DropDownList", "x350 y294 w290 r3 vYkG_OvFull gYkGui_Changed AltSubmit", "Automatisch - im Vollbild aus (empfohlen)|Immer anzeigen|Nie anzeigen")
    YkUi_Text(262, 326, 380, "Im echten Vollbild kann ein zusätzliches Fenster das Bild einfrieren. Im randlosen Fenster geht das Overlay.", 8, "norm", YkCol.faint, "h30")
    YkUi_Toggle(262, 362, 380, "YkG_OvDodge", "Im Fahrzeug über den Tacho ausweichen")
    YkUi_Text(262, 400, 380, "Inhalt", 10, "bold")
    YkUi_Toggle(262, 426, 190, "YkG_OvStatus", "Standort + Kills")
    YkUi_Toggle(452, 426, 190, "YkG_OvWar", "Kriege")
    YkUi_Toggle(262, 460, 190, "YkG_OvMem", "Member-Positionen")
    YkUi_Toggle(452, 460, 190, "YkG_OvKeys", "Tasten (Liste rechts)")
    YkUi_Text(262, 504, 110, "Kriegsende", 10)
    YkUi_Add("Edit", "x372 y500 w60 h24 vYkG_OvWarSec gYkGui_Changed -E0x200 Border Number", "")
    YkUi_Text(440, 504, 200, "Sekunden (0 = stehen lassen)", 8, "norm", YkCol.faint)
    YkUi_Toggle(262, 544, 380, "YkG_OvNoCap", "Overlay nicht in Aufnahmen zeigen", "OBS, Spielleiste - nur einschalten, wenn du wirklich aufnimmst")
    YkUi_Text(262, 604, 380, "Das Overlay ist die kleine Anzeige am Bildschirmrand. Die Maus klickt einfach durch.", 8, "norm", YkCol.faint, "h40")

    YkUi_Card(680, 100, 420, 356, "Tasten im Overlay", "E765", "Angehakte Tasten stehen im Overlay.")
    Gui, Yk:Font, % "s9 norm c" . YkCol.text, Segoe UI
    YkUi_Add("ListView", "-E0x200 x696 y164 w388 h276 vYkG_LvOvKeys gYkGui_OvKeysLv AltSubmit Checked -Multi NoSortHdr LV0x10000 Background" . YkCol.card . " c" . YkCol.text, "Taste|Aktion|id")

    YkUi_Card(680, 472, 420, 228, "Meldungen als Karten (neu)", "E8BD", "Ergebnisse von /tode, /otime, Gegnerlisten ... - nur für dich.")
    YkUi_Toggle(700, 536, 380, "YkG_ToastOn", "Karten im Spiel anzeigen")
    YkUi_Text(700, 576, 80, "Seite", 10)
    YkUi_Add("DropDownList", "x790 y572 w290 r3 vYkG_ToastSide gYkGui_Changed AltSubmit", "Automatisch (gegenüber vom Overlay)|Links|Rechts")
    YkUi_Text(700, 612, 80, "Dauer", 10)
    YkUi_Add("Edit", "x790 y608 w60 h24 vYkG_ToastSec gYkGui_Changed -E0x200 Border Number", "")
    YkUi_Text(858, 612, 80, "Sekunden", 9, "norm", YkCol.dim)
    YkUi_Button(950, 604, 130, 32, "Testen", "YkGui_ToastTest")
    YkUi_Text(700, 650, 380, "Zum Testen muss GTA laufen (Fenster oder randlos).", 8, "norm", YkCol.faint)
    YkUi_Font()
}

YkGui_ToastTest() {
    YkMsg("So sieht eine Meldung im Spiel aus.`nKills heute: " . YkCnt_Kills("T") . "  ·  K/D " . YkCnt_KD("T"), "info")
    if (!YkToast_Allowed())
        YkGui_Toast("Karten sind aus - oder GTA läuft nicht / im echten Vollbild.")
}

YkGui_OvKeysFill() {
    global g_OvLvFillT, g_GuiBuilt
    ; nicht unterbrechen: ein Listen-Ereignis dazwischen wuerde die
    ; gewaehlte Liste umstellen (die Auswahl gilt je Fenster, nicht je Thread)
    wasCrit := A_IsCritical
    Critical
    if (!g_GuiBuilt)
        return YkGui_CritEnd(wasCrit)
    g_OvLvFillT := A_TickCount
    Gui, Yk:Default
    Gui, Yk:ListView, YkG_LvOvKeys
    GuiControl, Yk:-Redraw, YkG_LvOvKeys
    LV_Delete()
    for i, it in YkOverlay_ItemList()
        LV_Add(YkOverlay_IsHidden(it.id) ? "" : "Check", YkHotkeyName(it.key), YkShorten(it.label, 44), it.id)
    LV_ModifyCol(1, 110), LV_ModifyCol(2, 270), LV_ModifyCol(3, 0)
    GuiControl, Yk:+Redraw, YkG_LvOvKeys
    g_OvLvFillT := A_TickCount
    YkGui_CritEnd(wasCrit)
}

; Haken gesetzt/entfernt -> uebernehmen (nicht beim Fuellen)
YkGui_OvKeysLv() {
    global g_OvLvFillT
    if (A_GuiEvent = "I" && InStr(ErrorLevel, "C", true) && (A_TickCount - g_OvLvFillT) > 400)
        YkGui_Changed()
}

; alle NICHT angehakten Eintraege -> "|"-Liste
YkGui_OvHidden() {
    ; nicht unterbrechen: ein Listen-Ereignis dazwischen wuerde die
    ; gewaehlte Liste umstellen (die Auswahl gilt je Fenster, nicht je Thread)
    wasCrit := A_IsCritical
    Critical
    Gui, Yk:Default
    Gui, Yk:ListView, YkG_LvOvKeys
    checked := {}
    row := 0
    while (row := LV_GetNext(row, "Checked")) {
        LV_GetText(id, row, 3)
        checked[id] := 1
    }
    out := ""
    Loop, % LV_GetCount() {
        LV_GetText(id, A_Index, 3)
        if (!checked.HasKey(id))
            out .= (out = "" ? "" : "|") . id
    }
    return YkGui_CritEnd(wasCrit, out)
    YkGui_CritEnd(wasCrit)
}

; =====================================================================
;  Seite: Sprint (Laufscript)
; =====================================================================
YkGui_BuildSprint() {
    global
    YkUi_Page("sprint")
    YkUi_Card(240, 100, 520, 400, "Sprint-Automatik", "E805")
    YkUi_Toggle(262, 142, 480, "YkG_Sprint", "Leertaste beim Laufen halten = schneller rennen", "Deine Figur rennt dauerhaft schnell, solange du die Leertaste hältst.")
    YkGui_Field(262, 196, 170, "An/Aus-Taste", 150, "YkG_SprintHk", "", "Hotkey")
    YkGui_Field(262, 230, 170, "Tempo (ms)", 70, "YkG_TapDown", "Number")
    YkUi_Text(510, 234, 230, "Standard 30 - kleiner = schneller tippen", 8, "norm", YkCol.faint)
    YkUi_Toggle(262, 268, 480, "YkG_OnFoot", "Nur zu Fuß (nicht im Fahrzeug)")
    YkUi_Toggle(262, 302, 480, "YkG_ReqMove", "Nur solange du läufst (W/A/S/D oder Pfeile gedrückt)")
    YkGui_Field(262, 342, 170, "Ducken-Taste im Spiel", 70, "YkG_Crouch")
    YkUi_Text(510, 346, 230, "Ducken unterbricht das Sprinten", 8, "norm", YkCol.faint)
    YkGui_Field(262, 376, 170, "Sprint-Taste im Spiel", 110, "YkG_SprintKey")
    YkGui_Field(262, 410, 170, "Laufrichtungs-Tasten", 300, "YkG_MoveKeys")
    YkUi_Text(262, 446, 480, "Sprint- und Laufrichtungs-Tasten nur ändern, wenn du im Spiel andere Tasten belegt hast (Namen wie Space, w, Up).", 8, "norm", YkCol.faint, "h36")

    YkUi_Card(780, 100, 320, 400, "So funktioniert es", "E946")
    YkUi_Text(800, 142, 280, "In GTA rennt die Figur nur schnell, wenn man die Sprint-Taste immer wieder antippt.`n`nDer Binder übernimmt das Antippen: Du hältst die Leertaste einfach gedrückt, er tippt für dich im eingestellten Tempo.`n`nDuckst du dich (C), hört er auf, bis du die Leertaste neu drückst - so bleibt der C-Bug frei.`n`nWährend du im Chat tippst, ruht der Sprint.", 9, "norm", YkCol.dim, "h340")

    YkUi_Card(240, 516, 860, 184, "Hängende Tasten", "E7BA")
    YkUi_Text(262, 556, 560, "Läuft deine Figur von allein weiter, oder wirken Ducken (C) und Aktion (F) nicht mehr? Dann hier klicken - der Binder lässt alles los, was er selbst gedrückt hält.`n`nDer Binder räumt das auch selbst auf - der Knopf ist nur die Notbremse. Dasselbe gibt es im Symbol neben der Uhr.", 9, "norm", YkCol.dim, "h120")
    YkUi_Button(850, 580, 230, 44, "Hängende Tasten lösen", "YkGui_KeysPanic", "primary")
    YkUi_Font()
}

YkGui_KeysPanic() {
    YkAction_KeysPanic()
    YkGui_Toast("Alle Tasten wurden losgelassen.")
}

; =====================================================================
;  Seite: Extras
; =====================================================================
YkGui_BuildExtras() {
    global
    local list, ch
    YkUi_Page("extras")
    YkUi_Card(240, 100, 420, 198, "Kills und Tode vom Server  ·  Taste N", "E9D2")
    YkUi_Toggle(262, 140, 380, "YkG_StatsOn", "Beim Öffnen des Charaktermenüs abgleichen")
    YkGui_Field(262, 176, 100, "Kills-Zeile", 278, "YkG_StatsKill")
    YkGui_Field(262, 208, 100, "Tode-Zeile", 278, "YkG_StatsDeath")
    g_H.statsState := YkUi_Text(262, 244, 380, "-", 9, "norm", YkCol.dim, "h40")

    YkUi_Card(680, 100, 420, 198, "Wanteds  ·  {wanteds}", "E72E")
    YkUi_Toggle(700, 140, 380, "YkG_WantOn", "{wanteds} holt die Zahl beim Server")
    YkGui_Field(700, 176, 90, "Befehl", 110, "YkG_WantCmd")
    YkUi_Text(916, 180, 70, "Warten", 10)
    YkUi_Add("Edit", "x986 y176 w60 h24 vYkG_WantWait gYkGui_Changed -E0x200 Border Number", "")
    YkUi_Text(1052, 180, 30, "ms", 8, "norm", YkCol.faint)
    YkGui_Field(700, 208, 90, "Antwort", 290, "YkG_WantPat")
    YkUi_Text(700, 244, 380, "Steht {wanteds} in einem Text, fragt der Binder vorher /wanteds und schickt dann erst den Satz.", 8, "norm", YkCol.faint, "h40")

    YkUi_Card(240, 314, 420, 240, "Lotto", "E8D4")
    YkUi_Toggle(262, 354, 380, "YkG_LottoOn", "Lose automatisch kaufen", "⚠ schickt von selbst Befehle - kann als Botting gelten")
    YkGui_Field(262, 406, 70, "Anzahl", 50, "YkG_LottoCount", "Number")
    YkUi_Text(410, 410, 70, "Abstand", 10)
    YkUi_Add("Edit", "x480 y406 w70 h24 vYkG_LottoGap gYkGui_Changed -E0x200 Border Number", "")
    YkUi_Text(556, 410, 30, "ms", 8, "norm", YkCol.faint)
    YkGui_Field(262, 438, 70, "Befehl", 140, "YkG_LottoCmd")
    YkUi_Text(486, 442, 40, "Zahl", 10)
    YkUi_Add("Edit", "x530 y438 w46 h24 vYkG_LottoMin gYkGui_Changed -E0x200 Border Number", "")
    YkUi_Add("Edit", "x584 y438 w56 h24 vYkG_LottoMax gYkGui_Changed -E0x200 Border Number", "")
    YkGui_Field(262, 470, 100, "Ankündigung", 278, "YkG_LottoPat")
    g_H.lottoState := YkUi_Text(262, 506, 380, "-", 9, "norm", YkCol.dim, "h40")

    YkUi_Card(680, 314, 420, 184, "SMS beantworten  ·  /re", "E8BD")
    YkGui_Field(700, 350, 90, "Befehl", 110, "YkG_SmsCmd")
    YkGui_Field(700, 380, 90, "Erkennung", 290, "YkG_SmsPat")
    YkUi_Text(700, 412, 380, "Suchmuster: Gruppe 1 = Absender, Gruppe 2 = Nummer. Im Spiel: /re + Enter  ->  /sms <Nummer> steht im Chat.", 8, "norm", YkCol.faint, "h32")
    g_H.smsState := YkUi_Text(700, 450, 380, "", 9, "norm", YkCol.dim, "h36")

    YkUi_Card(240, 570, 420, 130, "Radio (I LOVE RADIO)", "E8D6")
    list := ""
    for i, ch in YkRadio_Channels()
        list .= (i > 1 ? "|" : "") . ch[1]
    YkUi_Add("DropDownList", "x262 y610 w230 r12 vYkG_RadioChan gYkGui_Changed AltSubmit", list)
    g_H.radioPlay := YkUi_Button(502, 606, 138, 32, "Abspielen", "YkGui_RadioToggle", "primary")
    YkUi_Text(262, 652, 80, "Lautstärke", 9, "norm", YkCol.dim)
    YkUi_Add("Slider", "x340 y646 w300 h28 vYkG_RadioVol gYkGui_RadioVol Range0-100 ToolTip AltSubmit", 60)

    YkUi_Card(680, 514, 420, 186, "Aufnahmen  ·  /rec  /recstop  /frag", "E714")
    YkGui_Field(700, 550, 80, "Start-Taste", 90, "YkG_RecKey")
    YkGui_Field(890, 550, 84, "Stopp-Taste", 100, "YkG_RecStopKey")
    YkGui_Cue("YkG_RecStopKey", "= Start-Taste")
    YkUi_Text(700, 580, 380, "Tasten deines Aufnahmeprogramms, z.B. F9, Alt+F9, Strg+Shift+R, Win+Alt+R. Stopp leer = die Start-Taste schaltet um.", 8, "norm", YkCol.faint, "h30")
    YkGui_Field(700, 614, 80, "Video-Ordner", 250, "YkG_RecFolder")
    YkUi_Button(1036, 612, 44, 28, "...", "YkGui_PickRecFolder")
    YkUi_Button(700, 652, 110, 32, "Starten", "YkGui_RecStart", "primary")
    YkUi_Button(818, 652, 110, 32, "Beenden", "YkGui_RecStop")
    g_H.recState := YkUi_Text(938, 658, 150, "", 9, "norm", YkCol.dim)
    YkUi_Font()
}

YkGui_ExtrasRefresh() {
    global g_H, g_GuiBuilt
    if (!g_GuiBuilt)
        return
    YkGui_RecRefresh()
    YkUi_Set(g_H.statsState, "Stand: " . YkStats_Text())
    YkUi_Set(g_H.lottoState, YkLotto_Text())
    n := YkCnt_Info("letztesms"), nm := YkCnt_Info("letztesmsname")
    YkUi_Set(g_H.smsState, (n != "") ? "Letzte SMS von " . nm . "  (" . n . ")" : "Noch keine SMS erkannt.")
}

YkGui_RadioVol() {
    global YK_RadioVol
    GuiControlGet, v, Yk:, YkG_RadioVol
    YkRadio_Volume(v)
    YkGui_Changed()
}

YkGui_RecRefresh() {
    global g_H, g_GuiBuilt, YK_RecKey
    if (!g_GuiBuilt || !g_H.recState)
        return
    d := YkRec_Running()
    if (!IsObject(YkRec_ParseKey(YK_RecKey)))
        YkUi_Set(g_H.recState, "⚠ Start-Taste fehlt")
    else if (!IsObject(YkRec_ParseKey(YkRec_StopKey())))
        YkUi_Set(g_H.recState, "⚠ Stopp-Taste unbekannt")
    else
        YkUi_Set(g_H.recState, (d != "") ? "● läuft  " . d : "keine Aufnahme")
}

; Knoepfe: Einstellungen vorher uebernehmen, damit die eben eingetragene
; Taste gilt
YkGui_RecStart() {
    YkGui_Apply()
    YkRec_Start()
}

YkGui_RecStop() {
    YkGui_Apply()
    YkRec_Stop()
}

YkGui_PickRecFolder() {
    global YK_RecFolder
    FileSelectFolder, d, % "*" . YK_RecFolder, 3, Ordner, in dem dein Aufnahmeprogramm die Videos speichert
    if (d = "")
        return
    GuiControl, Yk:, YkG_RecFolder, %d%
    YkGui_Changed()
}

; =====================================================================
;  Seite: Einstellungen (mit Unterseiten)
; =====================================================================
YkGui_BuildSettings() {
    global
    local i, s, x, w, subs
    YkUi_Page("settings")
    subs := ["Allgemein", "Spiel & Erkennung", "Update", "Diagnose"]
    x := 240
    for i, s in subs {
        w := StrLen(s) * 8 + 40
        g_SetSubBtns[i] := {on: YkUi_Add("Picture", "x" . x . " y100 w" . w . " h34 gYkGui_SetSubClick Hidden", "HBITMAP:" . YkUi_Bmp(w, 34, YkCol.accent, YkCol.bg, 17))
                          , off: YkUi_Add("Picture", "x" . x . " y100 w" . w . " h34 gYkGui_SetSubClick", "HBITMAP:" . YkUi_Bmp(w, 34, YkCol.card2, YkCol.bg, 17, YkCol.line))
                          , txt: YkUi_Text(x, 108, w, s, 9, "bold", YkCol.text, "Center gYkGui_SetSubClick")}
        x += w + 10
    }
    g_UiSub["settings"] := 1

    ; ---- 1: Allgemein ----
    YkUi_Page("settings.1")
    YkUi_Card(240, 150, 420, 550, "Senden & Chat", "E724")
    YkGui_Field(262, 192, 230, "Chat-Taste im Spiel", 60, "YkG_ChatKey")
    YkGui_Field(262, 226, 230, "Tipp-Tempo in ms (0 = sofort)", 60, "YkG_SendDelay", "Number")
    YkGui_Field(262, 260, 230, "Pause zwischen Zeilen (ms)", 60, "YkG_LineDelay", "Number")
    YkUi_Toggle(262, 300, 380, "YkG_Fast", "Schnell senden", "Die Figur bleibt beim Laufen nicht stehen (empfohlen)")
    YkUi_Toggle(262, 352, 380, "YkG_Kurz", "Kurzformen der Server-Befehle", "z.B. /uc -> /use cannabis")
    YkUi_Toggle(262, 404, 380, "YkG_TbOn", "Chat-Befehle (/kd, /re, /cd ...)", "Enter wird kurz geprüft - sonst geht es normal ans Spiel")
    YkUi_Toggle(262, 456, 380, "YkG_StartPaused", "Pausiert starten")
    YkGui_Field(262, 496, 150, "Reihenfolge Anhänge", 230, "YkG_ExOrder")
    YkUi_Text(262, 528, 380, "hp, armor (Rüstung), loc (Standort), veh (Fahrzeug) - mit Komma", 8, "norm", YkCol.faint)
    YkUi_Text(262, 560, 380, "Chat-Kanäle: {fchat} = Family-Chat der Organisation (/f, Seite ""Familie""), {gchat} = Gang-/Mafienchat (/g, Seite ""Meldungen"").", 8, "norm", YkCol.faint, "h40")

    YkUi_Card(680, 150, 420, 550, "Speicher & Protokolle", "E8B7")
    YkUi_Toggle(700, 192, 380, "YkG_Mem", "Spielspeicher lesen", "Standort, HP, Chat-Erkennung, Kills, Spielerliste - nur lesend")
    YkUi_Toggle(700, 244, 380, "YkG_StallLog", "Hänger-Protokoll schreiben", "YakuzaHaenger.log - zeigt, ob der Binder oder der PC hing")
    YkUi_Text(700, 310, 380, "Diese Dateien liegen neben dem Programm:", 9, "bold")
    YkUi_Text(700, 334, 380, "YakuzaKeybinder.ini`t`tdeine Einstellungen`nYakuzaStatistik.ini`t`tKills/Tode heute, Monat, gesamt`nGegnerlisten\*.txt`t`tdeine Gegnerlisten`nYakuzaHaenger.log`t`tHänger-Protokoll`nYakuzaFehler.log`t`tFehler (falls einer auftritt)", 8, "norm", YkCol.dim, "h110")
    YkUi_Button(700, 470, 180, 36, "Einstellungsdatei", "YkGui_OpenIni")
    YkUi_Button(890, 470, 190, 36, "Ordner öffnen", "YkGui_OpenDir")
    YkUi_Text(700, 530, 380, "Ganz von vorn anfangen: Binder beenden, YakuzaKeybinder.ini löschen, neu starten.", 8, "norm", YkCol.faint, "h40")

    ; ---- 2: Spiel & Erkennung ----
    YkUi_Page("settings.2")
    YkUi_Card(240, 150, 420, 550, "Spiel", "E7FC")
    YkUi_Text(262, 192, 380, "Weitere Spielprozesse (mit Komma, meist leer)", 9, "norm", YkCol.dim)
    YkUi_Add("Edit", "x262 y212 w378 h24 vYkG_GameExes gYkGui_Changed -E0x200 Border", "")
    YkUi_Text(262, 242, 380, "gta_sa.exe (normales SA-MP) wird immer erkannt. Weitere Namen nur für eigene Launcher.", 8, "norm", YkCol.faint, "h30")
    YkUi_Text(262, 286, 380, "SA-MP-Starter für ""Spiel starten"" (leer = selbst suchen)", 9, "norm", YkCol.dim)
    YkUi_Add("Edit", "x262 y306 w330 h24 vYkG_PathGame gYkGui_Changed -E0x200 Border", "")
    YkUi_Button(600, 304, 40, 28, "...", "YkGui_PickGame")
    YkUi_Text(262, 350, 380, "Chatlog (leer = automatisch finden, empfohlen)", 9, "norm", YkCol.dim)
    YkUi_Add("Edit", "x262 y370 w330 h24 vYkG_Chatlog gYkGui_Changed -E0x200 Border", "")
    YkUi_Button(600, 368, 40, 28, "...", "YkGui_PickChatlog")
    g_H.chatlogState := YkUi_Text(262, 402, 380, "", 8, "norm", YkCol.faint, "h30")

    YkUi_Card(680, 150, 420, 550, "Kriegs-Meldungen erkennen", "E7C1", "Nur ändern, wenn der Server die Meldungen anders schreibt.")
    YkGui_Field(700, 222, 100, "Gangwar", 280, "YkG_WarGang")
    YkGui_Field(700, 256, 100, "Family-War", 280, "YkG_WarFam")
    YkGui_Field(700, 290, 100, "Bizfight", 280, "YkG_WarBiz")
    YkUi_Text(700, 330, 380, "Die Muster sind reguläre Ausdrücke. Beispiel Gangwar:  ^\[\s*GANG[ _-]?WAR\s*\]", 8, "norm", YkCol.faint, "h40")

    ; ---- 3: Update ----
    YkUi_Page("settings.3")
    YkUi_Card(240, 150, 860, 550, "Update", "E895")
    YkUi_Button(262, 192, 200, 38, "Nach Update suchen", "YkGui_UpdCheck", "primary")
    YkUi_Button(472, 192, 200, 38, "Jetzt aktualisieren", "YkGui_UpdNow")
    YkUi_Button(682, 192, 260, 38, "Fassung woanders einsetzen ...", "YkGui_InstallInto")
    g_H.updState := YkUi_Text(262, 246, 820, "-", 10, "norm", YkCol.dim, "h40")
    YkUi_Toggle(262, 300, 380, "YkG_UpdOn", "Automatisch prüfen", "beim Start (nach ~40 s) und alle 6 Stunden")
    YkUi_Toggle(680, 300, 400, "YkG_UpdAuto", "Neue Fassung automatisch herunterladen", "installiert wird erst nach deinem Ja - nie mitten im Spiel")
    YkUi_Text(262, 370, 120, "Adresse", 10)
    YkUi_Add("Edit", "x360 y366 w720 h24 vYkG_UpdUrl gYkGui_Changed -E0x200 Border", "")
    YkUi_Text(262, 404, 820, "Hinter der Adresse liegt eine Textdatei (z.B. ein GitHub-Gist) mit:`n     Version=3.0.1`n     Url=https://github.com/.../raw/main/Yakuza_Keybinder_v3.0.1.zip`nDeine Einstellungen bleiben bei jedem Update unangetastet - vorher wird zusätzlich eine .bak-Kopie angelegt.", 9, "norm", YkCol.dim, "h90")
    YkUi_Text(262, 506, 820, "Umstieg von einer alten Fassung: ZIP irgendwohin entpacken, die neue YakuzaKeybinder.exe starten, ""Fassung woanders einsetzen ..."" klicken und den alten Ordner wählen. Einstellungen bleiben erhalten.", 9, "norm", YkCol.faint, "h60")

    ; ---- 4: Diagnose ----
    YkUi_Page("settings.4")
    YkUi_Card(240, 150, 860, 550, "Diagnose  ·  wie schnell arbeitet der Binder?", "E9D9")
    Gui, Yk:Font, % "s9 norm c" . YkCol.dim, Consolas
    g_H.diag := YkUi_Add("Text", "x262 y192 w816 h400 BackgroundTrans", "(wird gemessen, sobald das Spiel läuft)")
    YkUi_Font()
    YkUi_Text(262, 610, 816, "Werte in Millisekunden je Durchgang. Alles unter 5 ms ist unauffällig. Reißt ein Wert aus, hier nachsehen.`nGegenprobe: Binder pausieren - hängt das Spiel dann immer noch, liegt es nicht am Binder.", 9, "norm", YkCol.faint, "h60")
    YkUi_Font()
}

YkGui_SetSubClick() {
    global g_SetSubBtns
    MouseGetPos, , , , hw, 2
    for i, b in g_SetSubBtns
        if (hw = b.on || hw = b.off || hw = b.txt)
            return YkGui_Go("settings", i)
}

YkGui_SetSubRefresh() {
    global g_SetSubBtns, g_UiSub, YkCol
    for i, b in g_SetSubBtns {
        on := (g_UiSub["settings"] = i)
        YkUi_ShowCtrl(b.on, on), YkUi_ShowCtrl(b.off, !on)
        Gui, Yk:Font, % "s9 bold c" . (on ? "FFFFFF" : YkCol.text), Segoe UI
        GuiControl, Yk:Font, % b.txt
        YkUi_Repaint(b.txt)
    }
    YkUi_Font()
}

YkGui_DiagRefresh(force := false) {
    global g_H, g_GuiBuilt, g_UiSub, g_UiCur, g_ChatlogFile
    static t := 0
    if (!g_GuiBuilt || g_UiCur != "settings")
        return
    if (!force && (A_TickCount - t) < 1000)
        return
    t := A_TickCount
    sub := g_UiSub["settings"]
    if (sub = 4)
        YkUi_Set(g_H.diag, YkDiag_Text())
    else if (sub = 3)
        YkUi_Set(g_H.updState, YkUpd_Text())
    else if (sub = 2)
        YkUi_Set(g_H.chatlogState, (g_ChatlogFile != "" && FileExist(g_ChatlogFile)) ? "Gefunden: " . g_ChatlogFile : "Noch kein Chatlog gefunden - einmal im Spiel einloggen und etwas schreiben.")
}

YkGui_PickChatlog() {
    FileSelectFile, f, 3, , Chatlog von SA-MP auswählen, Chatlog (chatlog.txt)
    if (f = "")
        return
    GuiControl, Yk:, YkG_Chatlog, %f%
    YkGui_Changed()
}

YkGui_PickGame() {
    FileSelectFile, f, 3, , SA-MP-Starter auswählen, Programme (*.exe)
    if (f = "")
        return
    GuiControl, Yk:, YkG_PathGame, %f%
    YkGui_Changed()
}

YkGui_UpdCheck() {
    YkGui_Apply()
    YkUpd_Manual()
    YkGui_DiagRefresh(true)
}

YkGui_UpdNow() {
    YkGui_Apply()
    YkUpd_Now()
    YkGui_DiagRefresh(true)
}

YkGui_InstallInto() {
    YkUpd_InstallInto()
}

; =====================================================================
;  Werte laden und uebernehmen
; =====================================================================
YkGui_LoadValues() {
    global
    local i, f, v, t, n
    g_Loading := true
    for i, f in YkGui_FieldMap() {
        n := f[2]
        v := %n%
        if (f[3] = "h")
            GuiControl, Yk:, % f[1], % YkGui_HkForControl(v)
        else
            GuiControl, Yk:, % f[1], %v%
    }
    for i, t in YkGui_ToggleMap() {
        n := t[2]
        YkUi_TogSet(t[1], %n% ? 1 : 0)
    }
    ; Update-Adresse: immer die, die wirklich benutzt wird
    GuiControl, Yk:, YkG_UpdUrl, % (Trim(YK_UpdUrl) != "") ? YK_UpdUrl : YK_UPD_DEFAULT
    GuiControl, Yk:, YkG_RevText, % (YK_ReviveEnabled ? YK_ReviveText : "")
    GuiControl, Yk:Choose, YkG_OvSide, % YK_OvSide
    GuiControl, Yk:Choose, YkG_OvSize, % YK_OvSize
    GuiControl, Yk:, YkG_OvVPos, % YK_OvVPos
    GuiControl, Yk:Choose, YkG_OvOpac, % (YK_OvOpacity <= 170) ? 1 : (YK_OvOpacity <= 204) ? 2 : (YK_OvOpacity <= 230) ? 3 : 4
    GuiControl, Yk:Choose, YkG_OvFull, % (YK_OvFullscreen = "an") ? 2 : (YK_OvFullscreen = "aus") ? 3 : 1
    GuiControl, Yk:Choose, YkG_ToastSide, % (YK_ToastSide = "links") ? 2 : (YK_ToastSide = "rechts") ? 3 : 1
    GuiControl, Yk:, YkG_ToastSec, % Round(YK_ToastMs / 1000)
    GuiControl, Yk:Choose, YkG_SndCall, % YkSound_Index(YK_CallSoundType)
    GuiControl, Yk:Choose, YkG_SndWar, % YkSound_Index(YK_WarSoundType)
    GuiControl, Yk:Choose, YkG_RadioChan, % (YK_RadioChan >= 1 && YK_RadioChan <= YkRadio_Channels().MaxIndex()) ? YK_RadioChan : 1
    GuiControl, Yk:, YkG_RadioVol, % YK_RadioVol
    g_Loading := false
}

; Aenderung in einem Feld -> kurz nach der letzten Eingabe uebernehmen
YkGui_Changed() {
    global g_Loading
    if (g_Loading)
        return
    SetTimer, YkGui_Apply, -500
}

YkGui_Apply() {
    global
    local i, f, v, t, n, c, tap, ck, op, ws
    if (!g_GuiBuilt)
        return
    SetTimer, YkGui_Apply, Off
    Gui, Yk:Submit, NoHide
    for i, f in YkGui_FieldMap() {
        c := f[1], n := f[2]
        v := %c%
        if (f[3] = "h")
            v := YkHk_Normalize(v)
        else if (f[3] = "n")
            v := YkN(v)
        else
            v := Trim(v)
        %n% := v
    }
    for i, t in YkGui_ToggleMap() {
        n := t[2]
        %n% := YkUi_TogGet(t[1]) ? true : false
    }

    ; ---- Pruefen und Standardwerte ----
    if (YK_GangCmd = "")
        YK_GangCmd := "/g"
    if (YK_FamChat = "")
        YK_FamChat := "/f"
    if (YK_ChatKey = "")
        YK_ChatKey := "t"
    YK_ReviveText := YkG_RevText
    YK_ReviveEnabled := (Trim(YkG_RevText) != "")
    if (YK_KillWindowMs < 100 || YK_KillWindowMs > 3000)
        YK_KillWindowMs := 600
    if (YK_KillRivalMs < 0 || YK_KillRivalMs > 2000)
        YK_KillRivalMs := 150
    if (YK_KillSameMs < 100 || YK_KillSameMs > 5000)
        YK_KillSameMs := 900
    if (YK_MarkMinutes < 1 || YK_MarkMinutes > YK_MARK_MAXMIN)
        YK_MarkMinutes := YK_MARK_MAXMIN
    tap := YK_SprintTapDown
    if (tap < 10 || tap > 200)
        tap := 30
    YK_SprintTapDown := tap, YK_SprintTapUp := tap
    if (YK_CrouchKey = "" || !GetKeySC(YK_CrouchKey))
        YK_CrouchKey := "c"
    if (YK_SprintKey = "" || !GetKeySC(YK_SprintKey))
        YK_SprintKey := "Space"
    if (YK_SprintMoveKeys = "")
        YK_SprintMoveKeys := "w,a,s,d,Up,Down,Left,Right"
    if (YK_WarNoteSec < 0 || YK_WarNoteSec > 600)
        YK_WarNoteSec := 120
    if (YK_WantedWaitMs < 500 || YK_WantedWaitMs > 10000)
        YK_WantedWaitMs := 2500
    if (YK_LottoCount < 1 || YK_LottoCount > 20)
        YK_LottoCount := 1
    if (YK_LottoGapMs < 500 || YK_LottoGapMs > 20000)
        YK_LottoGapMs := 1500
    if (YK_LottoMin < 1 || YK_LottoMin > 999999)
        YK_LottoMin := 1
    if (YK_LottoMax < YK_LottoMin || YK_LottoMax > 999999)
        YK_LottoMax := (YK_LottoMin > 100) ? YK_LottoMin : 100
    if (YK_LineDelay < 0 || YK_LineDelay > 5000)
        YK_LineDelay := 250
    for i, n in ["YK_WarGangPat", "YK_WarFamPat", "YK_WarBizPat", "YK_StatsKillPat", "YK_StatsDeathPat", "YK_WantedCmd", "YK_WantedPat", "YK_LottoCmd", "YK_LottoPat", "YK_SmsCmd"]
        if (%n% = "")
            YkGui_ResetDefault(n)
    ; ---- Auswahllisten ----
    YK_OvSide := (YkG_OvSide = 1) ? 1 : 2
    YK_OvSize := YkG_OvSize + 0
    YK_OvVPos := YkG_OvVPos + 0
    op := YkG_OvOpac + 0
    YK_OvOpacity := (op = 1) ? 153 : (op = 2) ? 191 : (op = 4) ? 242 : 217
    YK_OvFullscreen := (YkG_OvFull = 2) ? "an" : (YkG_OvFull = 3) ? "aus" : "auto"
    YK_OvHidden := YkGui_OvHidden()
    YK_ToastSide := (YkG_ToastSide = 2) ? "links" : (YkG_ToastSide = 3) ? "rechts" : "auto"
    ws := YkN(YkG_ToastSec)
    YK_ToastMs := (ws >= 2 && ws <= 30) ? ws * 1000 : 5000
    YK_CallSoundType := YkSound_Key(YkG_SndCall)
    YK_WarSoundType := YkSound_Key(YkG_SndWar)
    YK_CallSound := (YK_CallSoundType != "aus" || YK_WarSoundType != "aus")
    YK_RadioChan := YkG_RadioChan + 0
    YK_RadioVol := YkG_RadioVol + 0

    YkSaveConfig()
    YkApplyConfig()
    YkGui_RefreshLists()
    YkUpdateStatus()
    if (g_HkConflicts != "")
        YkGui_Toast("Übernommen - Taste doppelt belegt:  " . Trim(StrReplace(g_HkConflicts, "`n", "   ")))
    else
        YkGui_Toast("Übernommen und gespeichert.")
}

; Leeres Musterfeld -> Werkseinstellung (ein leeres Muster wuerde alles
; oder nichts erkennen)
YkGui_ResetDefault(n) {
    global
    static d := {YK_WarGangPat: "^\[\s*GANG[ _-]?WAR\s*\]", YK_WarFamPat: "^\[\s*FAMILY[ _-]?WAR\s*\]"
        , YK_WarBizPat: "^\[\s*(BIZ[ _-]?FIGHT|BIZ|BUSINESS|BIZWAR)\s*\]", YK_StatsKillPat: "Kills?\s*[:=]\s*(\d+)"
        , YK_StatsDeathPat: "(?:Tode|Todesf(?:ä|ae)lle|Deaths?)\s*[:=]\s*(\d+)", YK_WantedCmd: "/wanteds"
        , YK_WantedPat: "(?:Aktuelle\s+)?Wanteds?\s*[:=]?\s*(\d+)", YK_LottoCmd: "/lotto {zahl}"
        , YK_LottoPat: "^\[LOTTO\] In ca\. 10 Minuten", YK_SmsCmd: "/sms"}
    if (d.HasKey(n))
        %n% := d[n]
}
