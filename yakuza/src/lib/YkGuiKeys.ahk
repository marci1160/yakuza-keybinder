; =====================================================================
;  Yakuza Keybinder - Fenster: Tasten, Server-Befehle, Chat-Befehle,
;  Gegnerlisten
; =====================================================================

global g_KeysRows := [], g_KeysSel := ""
global g_CmdRows := [], g_CmdSel := ""
global g_TbRows := [], g_TbSel := "", g_CtbSel := 0
global g_EnemySel := ""

; Tasten aus v2, die fest zu einer Funktion gehoeren
YkGui_SysKeys() {
    global YK_LocHotkey, YK_KillHotkey, YK_FamHotkey, YK_SprintToggleHk, YK_OvHotkey, YK_MemHotkey
    global YK_LocText, YK_KillText, YK_FamCommand, YK_GangCmd
    return [{id: "loc", label: "Standort in den Gang-/Mafienchat", key: YK_LocHotkey, text: YK_GangCmd . " " . YK_LocText}
          , {id: "kill", label: "Kill melden (Notfall-Taste)", key: YK_KillHotkey, text: YK_GangCmd . " " . YK_KillText}
          , {id: "fam", label: "/familymap senden", key: YK_FamHotkey, text: YK_FamCommand}
          , {id: "sprint", label: "Sprint-Automatik an/aus", key: YK_SprintToggleHk, text: ""}
          , {id: "ov", label: "Overlay an/aus", key: YK_OvHotkey, text: ""}
          , {id: "mem", label: "Member-Positionen an/aus", key: YK_MemHotkey, text: ""}]
}

YkGui_SetSysKey(id, k) {
    global YK_LocHotkey, YK_KillHotkey, YK_FamHotkey, YK_SprintToggleHk, YK_OvHotkey, YK_MemHotkey
    if (id = "loc")
        YK_LocHotkey := k
    else if (id = "kill")
        YK_KillHotkey := k
    else if (id = "fam")
        YK_FamHotkey := k
    else if (id = "sprint")
        YK_SprintToggleHk := k
    else if (id = "ov")
        YK_OvHotkey := k
    else if (id = "mem")
        YK_MemHotkey := k
}

; Taste bei ihrem bisherigen Besitzer entfernen (Kennung wie in YkHk_Owners)
YkGui_KeyClearOwner(owner) {
    global YK_FnKeys, YK_Binds, YK_CmdBinds, YK_TbKeys
    kind := SubStr(owner, 1, InStr(owner, ":") - 1), id := SubStr(owner, InStr(owner, ":") + 1)
    if (kind = "SYS")
        YkGui_SetSysKey(id, "")
    else if (kind = "F")
        YK_FnKeys[id] := ""
    else if (kind = "B" && IsObject(YK_Binds[id + 0]))
        YK_Binds[id + 0].key := ""
    else if (kind = "S" && IsObject(YK_CmdBinds[id])) {
        YK_CmdBinds[id].hk := ""
        if (Trim(YK_CmdBinds[id].kurz) = "")
            YK_CmdBinds.Delete(id)
    } else if (kind = "T")
        YK_TbKeys.Delete(id)
}

; Darf k fuer "me" gesetzt werden? Fragt bei Doppelbelegung nach.
YkGui_KeyFree(k, me) {
    global YK_ChatKey
    if (k = "")
        return true
    if (YkHk_Normalize(k) = YkHk_Normalize(YK_ChatKey)) {
        MsgBox, 48, Taste nicht möglich, % YkHotkeyName(k) . " ist deine Chat-Taste und kann keine Aktion auslösen."
        return false
    }
    own := YkHk_Owners()
    if (!own.HasKey(k) || own[k] = me)
        return true
    MsgBox, 36, Taste schon belegt, % YkHotkeyName(k) . " ist schon belegt mit:`n`n" . YkHk_OwnerLabel(own[k]) . "`n`nDort entfernen und hier verwenden?"
    IfMsgBox, Yes
    {
        YkGui_KeyClearOwner(own[k])
        return true
    }
    return false
}

; Sondertasten, die das Hotkey-Feld von Windows nicht aufnehmen kann
YkGui_SpecialMap() {
    return {"Maus 4": "XButton1", "Maus 5": "XButton2", "Mausrad-Klick": "MButton", "Pause": "Pause", "Rollen": "ScrollLock"
          , "Feststell": "CapsLock", "Einfg": "Insert", "Entf": "Delete", "Pos1": "Home", "Ende": "End", "Bild auf": "PgUp"
          , "Bild ab": "PgDn", "Num /": "NumpadDiv", "Num *": "NumpadMult", "Num -": "NumpadSub", "Num +": "NumpadAdd", "Num Enter": "NumpadEnter"
          , "Raute #": "sc02B", "Plus +": "sc01B", "Zirkumflex ^": "sc029", "Kleiner <": "sc056"}
}

YkGui_SpecialList() {
    return "Sondertaste ...||Maus 4|Maus 5|Mausrad-Klick|Pause|Rollen|Feststell|Einfg|Entf|Pos1|Ende|Bild auf|Bild ab|Num /|Num *|Num -|Num +|Num Enter|Raute #|Plus +|Zirkumflex ^|Kleiner <"
}

YkGui_SpecialName(k) {
    YkHk_Split(k, mods, key)
    for n, v in YkGui_SpecialMap()
        if (v = key)
            return n
    return ""
}

; Das Hotkey-Feld versteht keine Maus- und Sondertasten
YkGui_HkForControl(k) {
    if (k = "" || YkGui_SpecialName(k) != "" || RegExMatch(k, "i)button|wheel|sc[0-9a-f]|vk[0-9a-f]"))
        return ""
    return k
}

; Taste aus Hotkey-Feld + Sondertasten-Auswahl
YkGui_ReadKey(hkVar, spVar) {
    global
    local k, sp, map, mods, key
    GuiControlGet, k, Yk:, %hkVar%
    GuiControlGet, sp, Yk:, %spVar%
    map := YkGui_SpecialMap()
    if (map.HasKey(sp)) {
        ; Umschalttasten aus dem Hotkey-Feld behalten (z.B. Strg + Maus 4)
        YkHk_Split(k, mods, key)
        k := mods . map[sp]
    }
    return YkHk_Normalize(Trim(k))
}

YkGui_ShowKey(hkVar, spVar, k) {
    GuiControl, Yk:, %hkVar%, % YkGui_HkForControl(k)
    GuiControl, Yk:Choose, %spVar%, 1
    sp := YkGui_SpecialName(k)
    if (sp != "")
        GuiControl, Yk:ChooseString, %spVar%, %sp%
}

; =====================================================================
;  Seite: Tasten
; =====================================================================
YkGui_BuildKeys() {
    global
    YkUi_Page("keys")
    YkUi_Add("Edit", "x240 y100 w260 h26 vYkG_KeySearch gYkGui_KeysFilter -E0x200 Border", "")
    YkGui_Cue("YkG_KeySearch", "Suchen ...")
    YkUi_Add("DropDownList", "x512 y100 w220 r8 vYkG_KeyFilter gYkGui_KeysFilter AltSubmit", "Alle belegten Tasten||Eigene Tasten|Funktionen|Server-Befehle|Chat-Befehle|Auch freie Funktionen")
    g_H.keyCount := YkUi_Text(760, 104, 340, "", 9, "norm", YkCol.dim, "Right")
    Gui, Yk:Font, % "s9 norm c" . YkCol.text, Segoe UI
    YkUi_Add("ListView", "-E0x200 x240 y136 w860 h300 vYkG_LvKeys gYkGui_KeysLv -Multi AltSubmit LV0x10000 Background" . YkCol.card . " c" . YkCol.text, "Taste|Aktion|Text|Art")
    YkUi_Card(240, 452, 860, 248)
    g_H.keyLabel := YkUi_Text(262, 466, 820, "Wähle oben einen Eintrag - oder lege eine neue Taste an.", 12, "bold")
    g_H.keyInfo := YkUi_Text(262, 492, 820, "", 9, "norm", YkCol.dim)
    YkUi_Text(262, 520, 200, "Taste", 9, "norm", YkCol.dim)
    YkUi_Add("Hotkey", "x262 y540 w180 h26 vYkG_KeyHk", "")
    YkUi_Add("DropDownList", "x450 y540 w120 r14 vYkG_KeySpecial", YkGui_SpecialList())
    YkUi_Text(590, 520, 490, "Text  (Platzhalter wie {standort} {hp} {kills} ...)", 9, "norm", YkCol.dim)
    YkUi_Add("Edit", "x590 y540 w490 h26 vYkG_KeyText -E0x200 Border", "")
    YkUi_Toggle(262, 580, 180, "YkG_KeyEnter", "Sofort senden", "", "")
    YkUi_Text(460, 582, 110, "Anhängen:", 9, "norm", YkCol.dim)
    YkUi_Toggle(540, 580, 100, "YkG_KeyExHp", "HP", "", "")
    YkUi_Toggle(640, 580, 130, "YkG_KeyExArmor", "Rüstung", "", "")
    YkUi_Toggle(770, 580, 140, "YkG_KeyExLoc", "Standort", "", "")
    YkUi_Toggle(910, 580, 150, "YkG_KeyExVeh", "Fahrzeug", "", "")
    g_H.keyWarn := YkUi_Text(262, 616, 818, "", 9, "norm", YkCol.warn)
    YkUi_Button(262, 646, 150, 38, "Neue Taste", "YkGui_KeyNew")
    YkUi_Button(420, 646, 150, 38, "Übernehmen", "YkGui_KeyApply", "primary")
    YkUi_Button(578, 646, 150, 38, "Entfernen", "YkGui_KeyDelete", "danger")
    YkUi_Button(736, 646, 170, 38, "Platzhalter ...", "YkGui_PhMenuKeys")
    YkUi_Button(914, 646, 166, 38, "Vorschau", "YkGui_KeyPreview")
    YkUi_Font()
}

YkGui_KeysFilter() {
    global g_Loading
    if (g_Loading)
        return
    SetTimer, YkGui_KeysFill, -150
}

YkGui_KeysFill() {
    global
    local q, flt, own, n, i, r, rows, b, k, kn, txt, ck, sb, cmd, f, t, ex, nset, wasCrit
    ; nicht unterbrechen: ein Listen-Ereignis dazwischen wuerde die
    ; gewaehlte Liste umstellen (die Auswahl gilt je Fenster, nicht je Thread)
    wasCrit := A_IsCritical
    Critical
    if (!g_GuiBuilt)
        return YkGui_CritEnd(wasCrit)
    GuiControlGet, q, Yk:, YkG_KeySearch
    GuiControlGet, flt, Yk:, YkG_KeyFilter
    q := Trim(q), flt := flt + 0
    if (flt < 1)
        flt := 1
    own := YkHk_Owners()
    rows := []
    ; 1) feste Funktionen aus v2
    for i, r in YkGui_SysKeys()
        rows.Push({kind: "sys", id: "SYS:" . r.id, sid: r.id, key: r.key, label: r.label, text: r.text, art: "Funktion"})
    ; 2) Funktionstasten aus v3
    for i, f in YkFnKeys()
        rows.Push({kind: "fn", id: "F:" . f.id, sid: f.id, key: YK_FnKeys[f.id], label: f.label, text: "", art: "Funktion"})
    ; 3) eigene Tasten
    for i, b in YK_Binds {
        txt := b.cmd
        ex := YkExtrasSummary(b.exHp, b.exArmor, b.exLoc, b.exVeh)
        if (ex != "-")
            txt .= "   + " . ex
        if (!b.enter)
            txt .= "   (nicht senden)"
        rows.Push({kind: "bind", id: "B:" . i, sid: i, key: b.key, label: "Eigene Taste", text: txt, art: "Eigene Taste"})
    }
    ; 4) Server-Befehle mit Taste
    for ck, sb in YK_CmdBinds
        if (sb.hk != "")
            rows.Push({kind: "srv", id: "S:" . ck, sid: ck, key: sb.hk, label: "Server-Befehl " . Trim(ck), text: ck, art: "Server-Befehl"})
    ; 5) Chat-Befehle mit Taste
    for cmd, k in YK_TbKeys {
        t := YkTb_Find(cmd)
        rows.Push({kind: "tb", id: "T:" . cmd, sid: cmd, key: k, label: "Chat-Befehl " . cmd, text: IsObject(t) ? t.label : "", art: "Chat-Befehl"})
    }
    Gui, Yk:Default
    Gui, Yk:ListView, YkG_LvKeys
    GuiControl, Yk:-Redraw, YkG_LvKeys
    LV_Delete()
    g_KeysRows := []
    n := 0, nset := 0
    for i, r in rows {
        if (r.key != "")
            nset += 1
        if (flt = 1 && r.key = "")
            continue
        if (flt = 2 && r.kind != "bind")
            continue
        if (flt = 3 && r.kind != "sys" && r.kind != "fn")
            continue
        if (flt = 4 && r.kind != "srv")
            continue
        if (flt = 5 && r.kind != "tb")
            continue
        if (q != "" && !InStr(r.label, q) && !InStr(r.text, q) && !InStr(YkHotkeyName(r.key), q))
            continue
        kn := YkHotkeyName(r.key)
        if (r.key != "" && own[r.key] != r.id)
            kn := "⚠ " . kn
        LV_Add("", (kn = "") ? "–" : kn, r.label, r.text, r.art)
        g_KeysRows.Push(r)
        n += 1
    }
    LV_ModifyCol(1, 130), LV_ModifyCol(2, 250), LV_ModifyCol(3, 360), LV_ModifyCol(4, 116)
    GuiControl, Yk:+Redraw, YkG_LvKeys
    YkUi_Set(g_H.keyCount, n . " angezeigt  ·  " . nset . " belegt  ·  ⚠ = doppelt")
    YkGui_CritEnd(wasCrit)
}

YkGui_KeysLv() {
    global g_KeysRows, g_KeysSel
    ; nicht unterbrechen: ein Listen-Ereignis dazwischen wuerde die
    ; gewaehlte Liste umstellen (die Auswahl gilt je Fenster, nicht je Thread)
    wasCrit := A_IsCritical
    Critical
    if (A_GuiEvent != "Normal" && A_GuiEvent != "DoubleClick" && A_GuiEvent != "I")
        return YkGui_CritEnd(wasCrit)
    Gui, Yk:Default
    Gui, Yk:ListView, YkG_LvKeys
    r := LV_GetNext(0, "F")
    if (!r || !IsObject(g_KeysRows[r]))
        return YkGui_CritEnd(wasCrit)
    if (IsObject(g_KeysSel) && g_KeysSel.id = g_KeysRows[r].id && A_GuiEvent = "I")
        return YkGui_CritEnd(wasCrit)
    g_KeysSel := g_KeysRows[r]
    YkGui_KeyEditorLoad()
    YkGui_CritEnd(wasCrit)
}

YkGui_KeyEditorLoad() {
    global g_KeysSel, g_H, YK_Binds
    s := g_KeysSel
    if (!IsObject(s))
        return
    YkUi_Set(g_H.keyWarn, "")
    YkGui_ShowKey("YkG_KeyHk", "YkG_KeySpecial", s.key)
    isBind := (s.kind = "bind" || s.kind = "new")
    b := (s.kind = "bind") ? YK_Binds[s.sid] : ""
    if (s.kind = "new") {
        YkUi_Set(g_H.keyLabel, "Neue eigene Taste")
        YkUi_Set(g_H.keyInfo, "Taste drücken, Text eintragen, ""Übernehmen"".  Beispiel:  /g Ich bin in {standort} und habe noch {hp} HP")
    } else if (s.kind = "bind") {
        YkUi_Set(g_H.keyLabel, "Eigene Taste")
        YkUi_Set(g_H.keyInfo, "Schreibt den Text in den Chat. ""Sofort senden"" aus = der Text bleibt im Chat stehen, du kannst noch etwas dazu tippen.")
    } else if (s.kind = "srv") {
        YkUi_Set(g_H.keyLabel, s.label)
        YkUi_Set(g_H.keyInfo, "Kurzform und Anhänge dieses Befehls stellst du unter ""Server-Befehle"" ein.")
    } else if (s.kind = "tb") {
        YkUi_Set(g_H.keyLabel, s.label)
        YkUi_Set(g_H.keyInfo, "Den Text dieses Chat-Befehls änderst du unter ""Chat-Befehle"".")
    } else {
        YkUi_Set(g_H.keyLabel, s.label)
        YkUi_Set(g_H.keyInfo, (s.text != "") ? "Sendet:  " . s.text . "   (Text unter ""Meldungen & Kampf"")" : "Funktion des Keybinders - hier nur die Taste festlegen.")
    }
    GuiControl, Yk:, YkG_KeyText, % isBind ? (IsObject(b) ? b.cmd : "") : s.text
    GuiControl, % "Yk:" . (isBind ? "Enable" : "Disable"), YkG_KeyText
    YkUi_TogSet("YkG_KeyEnter", IsObject(b) ? b.enter : 1)
    YkUi_TogSet("YkG_KeyExHp", IsObject(b) ? b.exHp : 0)
    YkUi_TogSet("YkG_KeyExArmor", IsObject(b) ? b.exArmor : 0)
    YkUi_TogSet("YkG_KeyExLoc", IsObject(b) ? b.exLoc : 0)
    YkUi_TogSet("YkG_KeyExVeh", IsObject(b) ? b.exVeh : 0)
}

YkGui_KeyNew() {
    global g_KeysSel
    ; nicht unterbrechen: ein Listen-Ereignis dazwischen wuerde die
    ; gewaehlte Liste umstellen (die Auswahl gilt je Fenster, nicht je Thread)
    wasCrit := A_IsCritical
    Critical
    g_KeysSel := {kind: "new", id: "B:0", sid: 0, key: "", label: "Neue eigene Taste", text: ""}
    Gui, Yk:Default
    Gui, Yk:ListView, YkG_LvKeys
    LV_Modify(0, "-Select")
    YkGui_KeyEditorLoad()
    GuiControl, Yk:Focus, YkG_KeyHk
    YkGui_CritEnd(wasCrit)
}

YkGui_KeyApply() {
    global g_KeysSel, g_H, YK_Binds, YK_FnKeys, YK_CmdBinds, YK_TbKeys
    s := g_KeysSel
    if (!IsObject(s)) {
        YkUi_Set(g_H.keyWarn, "Bitte zuerst oben einen Eintrag wählen oder ""Neue Taste"" klicken.")
        return
    }
    k := YkGui_ReadKey("YkG_KeyHk", "YkG_KeySpecial")
    GuiControlGet, txt, Yk:, YkG_KeyText
    if (s.kind = "new" || s.kind = "bind") {
        if (k = "" || Trim(txt) = "") {
            YkUi_Set(g_H.keyWarn, "Bitte Taste und Text angeben.")
            return
        }
    }
    if (!YkGui_KeyFree(k, (s.kind = "new") ? "B:0" : s.id))
        return
    nb := {key: k, cmd: txt, enter: YkUi_TogGet("YkG_KeyEnter") ? true : false
         , exHp: YkUi_TogGet("YkG_KeyExHp") ? true : false, exArmor: YkUi_TogGet("YkG_KeyExArmor") ? true : false
         , exLoc: YkUi_TogGet("YkG_KeyExLoc") ? true : false, exVeh: YkUi_TogGet("YkG_KeyExVeh") ? true : false}
    if (s.kind = "new") {
        YK_Binds.Push(nb)
        s := {kind: "bind", id: "B:" . YK_Binds.MaxIndex(), sid: YK_Binds.MaxIndex(), key: k}
    } else if (s.kind = "bind")
        YK_Binds[s.sid] := nb
    else if (s.kind = "sys")
        YkGui_SetSysKey(s.sid, k)
    else if (s.kind = "fn")
        YK_FnKeys[s.sid] := k
    else if (s.kind = "srv") {
        if (IsObject(YK_CmdBinds[s.sid]))
            YK_CmdBinds[s.sid].hk := k
    } else if (s.kind = "tb") {
        if (k = "")
            YK_TbKeys.Delete(s.sid)
        else
            YK_TbKeys[s.sid] := k
    }
    g_KeysSel := s
    YkGui_Commit()
    YkGui_Toast((k != "") ? "Taste " . YkHotkeyName(k) . " gespeichert." : "Gespeichert.")
}

; Eintrag entfernen: eigene Taste ganz, sonst nur die Taste
YkGui_KeyDelete() {
    global g_KeysSel, YK_Binds
    s := g_KeysSel
    if (!IsObject(s) || s.kind = "new")
        return
    if (s.kind = "bind") {
        MsgBox, 36, Eigene Taste löschen, % "Diese Taste wirklich löschen?`n`n" . YkHotkeyName(s.key) . "   " . YK_Binds[s.sid].cmd
        IfMsgBox, No
            return
        YK_Binds.RemoveAt(s.sid)
    } else {
        YkGui_KeyClearOwner(s.id)
    }
    g_KeysSel := ""
    YkGui_Commit()
    YkUi_Set(g_H.keyLabel, "Entfernt.")
    YkUi_Set(g_H.keyInfo, "")
}

YkGui_KeyPreview() {
    GuiControlGet, txt, Yk:, YkG_KeyText
    if (Trim(txt) = "")
        return
    MsgBox, 64, Vorschau, % "So würde es im Moment aussehen:`n`n" . YkFill(txt)
}

; Speichern, anwenden und alle Listen im Fenster neu zeigen
YkGui_Commit() {
    YkSaveConfig()
    YkApplyConfig()
    YkGui_RefreshLists()
}

YkGui_RefreshLists() {
    global g_GuiBuilt, g_UiCur
    if (!g_GuiBuilt)
        return
    if (g_UiCur = "keys")
        YkGui_KeysFill()
    else if (g_UiCur = "server")
        YkGui_CmdFill()
    else if (g_UiCur = "chat")
        YkGui_TbFill()
    else if (g_UiCur = "overlay")
        YkGui_OvKeysFill()
}

; ---------------------------------------------------------------------
;  Platzhalter-Menue (setzt am Cursor ein)
; ---------------------------------------------------------------------
YkGui_PhMenuKeys() {
    YkGui_PhMenu("YkG_KeyText")
}

YkGui_PhMenuTb() {
    YkGui_PhMenu("YkG_TbText")
}

YkGui_PhMenu(target) {
    global g_PhTarget
    g_PhTarget := target
    try Menu, YkPhMenu, DeleteAll
    for i, p in YkPlaceholderList() {
        fn := Func("YkGui_PhInsert").Bind(p[1])
        Menu, YkPhMenu, Add, % p[1] . "`t" . p[2], % fn
    }
    Menu, YkPhMenu, Show
}

YkGui_PhInsert(token) {
    global g_PhTarget
    GuiControl, Yk:Focus, %g_PhTarget%
    h := YkGui_Hwnd(g_PhTarget)
    Control, EditPaste, %token%, , ahk_id %h%
}

; =====================================================================
;  Seite: Server-Befehle
; =====================================================================
YkGui_BuildServer() {
    global
    YkUi_Page("server")
    YkUi_Add("Edit", "x240 y100 w260 h26 vYkG_CmdSearch gYkGui_CmdFilter -E0x200 Border", "")
    YkGui_Cue("YkG_CmdSearch", "Suchen ...")
    YkUi_Text(516, 104, 584, "Kurzform: im Chat z.B. /uc tippen - wird sofort zu /use cannabis.   * = Favorit", 9, "norm", YkCol.dim)
    Gui, Yk:Font, % "s9 norm c" . YkCol.text, Segoe UI
    YkUi_Add("ListView", "-E0x200 x240 y136 w860 h318 vYkG_LvCmd gYkGui_CmdLv -Multi AltSubmit LV0x10000 Background" . YkCol.card . " c" . YkCol.text, "*|Befehl|Beschreibung|Taste|Kurzform|Anhang")
    YkUi_Card(240, 470, 860, 230)
    g_H.cmdSel := YkUi_Text(262, 484, 500, "Befehl in der Liste anklicken", 12, "bold")
    g_H.cmdDesc := YkUi_Text(262, 510, 820, "", 9, "norm", YkCol.dim)
    YkUi_Text(262, 540, 200, "Taste", 9, "norm", YkCol.dim)
    YkUi_Add("Hotkey", "x262 y560 w170 h26 vYkG_CmdHk", "")
    YkUi_Add("DropDownList", "x440 y560 w120 r14 vYkG_CmdSpecial", YkGui_SpecialList())
    YkUi_Text(580, 540, 200, "Kurzform (z.B. uc)", 9, "norm", YkCol.dim)
    YkUi_Add("Edit", "x580 y560 w130 h26 vYkG_CmdKurz -E0x200 Border", "")
    YkUi_Toggle(740, 562, 200, "YkG_CmdEnter", "Sofort senden", "", "")
    YkUi_Text(262, 604, 90, "Anhängen:", 9, "norm", YkCol.dim)
    YkUi_Toggle(340, 602, 100, "YkG_CmdExHp", "HP", "", "")
    YkUi_Toggle(440, 602, 130, "YkG_CmdExArmor", "Rüstung", "", "")
    YkUi_Toggle(570, 602, 140, "YkG_CmdExLoc", "Standort", "", "")
    YkUi_Toggle(710, 602, 150, "YkG_CmdExVeh", "Fahrzeug", "", "")
    YkUi_Button(262, 646, 150, 38, "Zuweisen", "YkGui_CmdApply", "primary")
    YkUi_Button(420, 646, 150, 38, "Entfernen", "YkGui_CmdClear", "danger")
    YkUi_Button(578, 646, 210, 38, "Befehle über Menüs ...", "YkGui_CmdMenuCmds")
    YkUi_Font()
}

YkGui_CmdFilter() {
    SetTimer, YkGui_CmdFill, -150
}

YkGui_CmdFill() {
    global YK_CmdList, YK_CmdBinds, g_CmdRows, g_GuiBuilt
    ; nicht unterbrechen: ein Listen-Ereignis dazwischen wuerde die
    ; gewaehlte Liste umstellen (die Auswahl gilt je Fenster, nicht je Thread)
    wasCrit := A_IsCritical
    Critical
    if (!g_GuiBuilt)
        return YkGui_CritEnd(wasCrit)
    YkCmd_Init()
    own := YkHk_Owners()
    GuiControlGet, flt, Yk:, YkG_CmdSearch
    flt := Trim(flt)
    Gui, Yk:Default
    Gui, Yk:ListView, YkG_LvCmd
    GuiControl, Yk:-Redraw, YkG_LvCmd
    LV_Delete()
    g_CmdRows := []
    for i, o in YK_CmdList {
        if (flt != "" && !(InStr(o.k, flt) || InStr(o.d, flt) || InStr(o.c, flt)))
            continue
        hk := "", kz := "", ex := ""
        b := YK_CmdBinds[o.k]
        if (IsObject(b)) {
            hk := YkHotkeyName(b.hk)
            if (b.hk != "" && own[b.hk] != "S:" . o.k)
                hk := "⚠ " . hk
            kz := b.kurz
            ex := YkExtrasSummary(b.exHp, b.exArmor, b.exLoc, b.exVeh)
            ex := (ex = "-") ? "" : ex
        }
        LV_Add("", (o.s ? "*" : ""), o.k, o.c . "  ·  " . o.d, hk, kz, ex)
        g_CmdRows.Push(o.k)
    }
    LV_ModifyCol(1, 22), LV_ModifyCol(2, 140), LV_ModifyCol(3, 380), LV_ModifyCol(4, 110), LV_ModifyCol(5, 70), LV_ModifyCol(6, 100)
    GuiControl, Yk:+Redraw, YkG_LvCmd
    YkGui_CritEnd(wasCrit)
}

YkGui_CmdLv() {
    global g_CmdRows, g_CmdSel, YK_CmdBinds, g_H
    ; nicht unterbrechen: ein Listen-Ereignis dazwischen wuerde die
    ; gewaehlte Liste umstellen (die Auswahl gilt je Fenster, nicht je Thread)
    wasCrit := A_IsCritical
    Critical
    if (A_GuiEvent != "Normal" && A_GuiEvent != "DoubleClick" && A_GuiEvent != "I")
        return YkGui_CritEnd(wasCrit)
    Gui, Yk:Default
    Gui, Yk:ListView, YkG_LvCmd
    r := LV_GetNext(0, "F")
    if (!r || g_CmdRows[r] = "")
        return YkGui_CritEnd(wasCrit)
    if (g_CmdSel = g_CmdRows[r] && A_GuiEvent = "I")
        return YkGui_CritEnd(wasCrit)
    g_CmdSel := g_CmdRows[r]
    o := YkCmd_FindByKey(g_CmdSel)
    b := YK_CmdBinds[g_CmdSel]
    YkUi_Set(g_H.cmdSel, Trim(g_CmdSel))
    YkUi_Set(g_H.cmdDesc, IsObject(o) ? o.c . "  ·  " . o.d . (o.e ? "" : "   (Text wird angehängt - daher ab Werk nicht sofort senden)") : "")
    YkGui_ShowKey("YkG_CmdHk", "YkG_CmdSpecial", IsObject(b) ? b.hk : "")
    GuiControl, Yk:, YkG_CmdKurz, % IsObject(b) ? b.kurz : ""
    YkUi_TogSet("YkG_CmdEnter", IsObject(b) ? b.enter : (IsObject(o) ? o.e : 1))
    YkUi_TogSet("YkG_CmdExHp", IsObject(b) ? b.exHp : 0)
    YkUi_TogSet("YkG_CmdExArmor", IsObject(b) ? b.exArmor : 0)
    YkUi_TogSet("YkG_CmdExLoc", IsObject(b) ? b.exLoc : 0)
    YkUi_TogSet("YkG_CmdExVeh", IsObject(b) ? b.exVeh : 0)
    YkGui_CritEnd(wasCrit)
}

YkGui_CmdApply() {
    global g_CmdSel, YK_CmdBinds
    if (g_CmdSel = "") {
        YkGui_Toast("Bitte zuerst einen Befehl in der Liste anklicken.")
        return
    }
    k := YkGui_ReadKey("YkG_CmdHk", "YkG_CmdSpecial")
    GuiControlGet, kz, Yk:, YkG_CmdKurz
    kz := Trim(kz)
    if (k = "" && kz = "") {
        MsgBox, 64, Server-Befehl, Bitte eine Taste oder eine Kurzform angeben.
        return
    }
    if (!YkGui_KeyFree(k, "S:" . g_CmdSel))
        return
    YK_CmdBinds[g_CmdSel] := {hk: k, kurz: kz, enter: (YkUi_TogGet("YkG_CmdEnter") ? 1 : 0)
        , exHp: YkUi_TogGet("YkG_CmdExHp") ? true : false, exArmor: YkUi_TogGet("YkG_CmdExArmor") ? true : false
        , exLoc: YkUi_TogGet("YkG_CmdExLoc") ? true : false, exVeh: YkUi_TogGet("YkG_CmdExVeh") ? true : false}
    YkGui_Commit()
    YkGui_Toast("Zugewiesen: " . Trim(g_CmdSel))
}

YkGui_CmdClear() {
    global g_CmdSel, YK_CmdBinds
    if (g_CmdSel = "")
        return
    YK_CmdBinds.Delete(g_CmdSel)
    GuiControl, Yk:, YkG_CmdHk
    GuiControl, Yk:, YkG_CmdKurz
    GuiControl, Yk:Choose, YkG_CmdSpecial, 1
    YkGui_Commit()
    YkGui_Toast("Zuweisung entfernt.")
}

YkGui_CmdMenuCmds() {
    MsgBox, 64, Befehle über Menüs (keine Taste nötig), % YkMenuCmdsText()
}

; =====================================================================
;  Seite: Chat-Befehle
; =====================================================================
YkGui_BuildChat() {
    global
    local list, g, i
    YkUi_Page("chat")
    list := "Alle Gruppen"
    for i, g in YkTbGroups()
        list .= "|" . g.name
    YkUi_Add("DropDownList", "x240 y100 w230 r8 vYkG_TbGroup gYkGui_TbFilter AltSubmit Choose1", list)
    YkUi_Add("Edit", "x482 y100 w240 h26 vYkG_TbSearch gYkGui_TbFilter -E0x200 Border", "")
    YkGui_Cue("YkG_TbSearch", "Suchen ...")
    g_H.tbCount := YkUi_Text(740, 104, 360, "", 9, "norm", YkCol.dim, "Right")
    Gui, Yk:Font, % "s9 norm c" . YkCol.text, Segoe UI
    YkUi_Add("ListView", "-E0x200 x240 y136 w860 h290 vYkG_LvTb gYkGui_TbLv -Multi AltSubmit LV0x10000 Background" . YkCol.card . " c" . YkCol.text, "Befehl|Beschreibung|Text|Taste|Aktiv")

    YkUi_Card(240, 442, 540, 258)
    g_H.tbLabel := YkUi_Text(262, 456, 380, "Befehl in der Liste anklicken", 12, "bold")
    g_H.tbInfo := YkUi_Text(262, 482, 500, "", 9, "norm", YkCol.dim)
    YkUi_Toggle(630, 456, 140, "YkG_TbActive", "Aktiv", "", "YkGui_TbActiveClick")
    YkUi_Add("Edit", "x262 y508 w496 h78 vYkG_TbText -E0x200 Border Multi WantReturn", "")
    YkUi_Text(262, 598, 90, "Taste", 9, "norm", YkCol.dim)
    YkUi_Add("Hotkey", "x312 y594 w160 h26 vYkG_TbHk", "")
    YkUi_Text(482, 598, 276, "optional - löst den Befehl auch per Taste aus", 8, "norm", YkCol.faint)
    YkUi_Button(262, 640, 150, 38, "Übernehmen", "YkGui_TbSave", "primary")
    YkUi_Button(420, 640, 150, 38, "Standardtext", "YkGui_TbDefault")
    YkUi_Button(578, 640, 180, 38, "Platzhalter ...", "YkGui_PhMenuTb")

    YkUi_Card(800, 442, 300, 258, "Eigene Chat-Befehle", "E70F")
    Gui, Yk:Font, % "s9 norm c" . YkCol.text, Segoe UI
    YkUi_Add("ListView", "-E0x200 x816 y478 w268 h86 vYkG_LvCtb gYkGui_CtbLv -Hdr -Multi AltSubmit LV0x10000 Background" . YkCol.card . " c" . YkCol.text, "Befehl|Text")
    YkUi_Add("Edit", "x816 y572 w268 h24 vYkG_CtbCmd -E0x200 Border", "")
    YkGui_Cue("YkG_CtbCmd", "/befehl")
    YkUi_Add("Edit", "x816 y600 w268 h40 vYkG_CtbText -E0x200 Border Multi WantReturn", "")
    YkUi_Button(816, 648, 130, 34, "Speichern", "YkGui_CtbSave", "primary")
    YkUi_Button(954, 648, 130, 34, "Löschen", "YkGui_CtbDelete", "danger")
    YkUi_Font()
}

YkGui_TbFilter() {
    global g_Loading
    if (g_Loading)
        return
    SetTimer, YkGui_TbFill, -150
}

YkGui_TbFill() {
    global g_TbRows, g_GuiBuilt, YK_TbOff, YK_TbKeys, YK_TbEnabled, g_H, YK_CustomTb
    ; nicht unterbrechen: ein Listen-Ereignis dazwischen wuerde die
    ; gewaehlte Liste umstellen (die Auswahl gilt je Fenster, nicht je Thread)
    wasCrit := A_IsCritical
    Critical
    if (!g_GuiBuilt)
        return YkGui_CritEnd(wasCrit)
    GuiControlGet, gi, Yk:, YkG_TbGroup
    GuiControlGet, q, Yk:, YkG_TbSearch
    q := Trim(q), gi := gi + 0
    grp := (gi > 1) ? YkTbGroups()[gi - 1].id : ""
    Gui, Yk:Default
    Gui, Yk:ListView, YkG_LvTb
    GuiControl, Yk:-Redraw, YkG_LvTb
    LV_Delete()
    g_TbRows := []
    n := 0, on := 0
    for i, t in YkTextDB() {
        if (grp != "" && t.grp != grp)
            continue
        txt := (t.type = "fn") ? "Sonderfunktion" : (t.type = "yk") ? "sofort beim Tippen (ohne Enter)" : StrReplace(YkTbText(t), "`n", "  ⏎  ")
        if (q != "" && !InStr(t.cmd, q) && !InStr(t.label, q) && !InStr(txt, q))
            continue
        act := (t.type = "yk") ? "immer" : (YK_TbOff[t.cmd] ? "aus" : "✓")
        if (act = "✓")
            on += 1
        LV_Add("", t.cmd . ((t.arg = "space") ? "  + Leertaste" : ""), t.label, txt, YkHotkeyName(YK_TbKeys[t.cmd]), act)
        g_TbRows.Push(t.cmd)
        n += 1
    }
    ; Gegnerlisten als Befehle zeigen
    if (grp = "" || grp = "gegner") {
        for i, e in YK_Enemies {
            if (q != "" && !InStr(e.key, q) && !InStr(e.title, q))
                continue
            LV_Add("", "/" . e.key . "  /" . e.key . "add  /" . e.key . "del", "Gegnerliste " . e.title, "wer ist online / hinzufügen / entfernen", "", "✓")
            g_TbRows.Push("")
        }
    }
    LV_ModifyCol(1, 150), LV_ModifyCol(2, 250), LV_ModifyCol(3, 300), LV_ModifyCol(4, 80), LV_ModifyCol(5, "54 Center")
    GuiControl, Yk:+Redraw, YkG_LvTb
    YkUi_Set(g_H.tbCount, YK_TbEnabled ? n . " Befehle  ·  " . on . " aktiv" : "⚠ Chat-Befehle sind ausgeschaltet (Einstellungen)")
    ; eigene Chat-Befehle
    Gui, Yk:ListView, YkG_LvCtb
    LV_Delete()
    for i, c in YK_CustomTb
        LV_Add("", c.cmd, StrReplace(c.text, "`n", " ⏎ "))
    LV_ModifyCol(1, 80), LV_ModifyCol(2, 180)
    YkGui_CritEnd(wasCrit)
}

YkGui_TbLv() {
    global g_TbRows, g_TbSel
    ; nicht unterbrechen: ein Listen-Ereignis dazwischen wuerde die
    ; gewaehlte Liste umstellen (die Auswahl gilt je Fenster, nicht je Thread)
    wasCrit := A_IsCritical
    Critical
    if (A_GuiEvent != "Normal" && A_GuiEvent != "DoubleClick" && A_GuiEvent != "I")
        return YkGui_CritEnd(wasCrit)
    Gui, Yk:Default
    Gui, Yk:ListView, YkG_LvTb
    r := LV_GetNext(0, "F")
    if (!r || g_TbRows[r] = "")
        return YkGui_CritEnd(wasCrit)
    if (g_TbSel = g_TbRows[r] && A_GuiEvent = "I")
        return YkGui_CritEnd(wasCrit)
    g_TbSel := g_TbRows[r]
    YkGui_TbEditorLoad()
    YkGui_CritEnd(wasCrit)
}

YkGui_TbEditorLoad() {
    global g_TbSel, g_H, YK_TbOff, YK_TbKeys
    t := YkTb_Find(g_TbSel)
    if (!IsObject(t))
        return
    YkUi_Set(g_H.tbLabel, t.cmd)
    typ := {send: "Sendet den Text (jede Zeile = eine Nachricht, {sleep 500} = Pause)", prefill: "Öffnet den Chat mit diesem Text - du tippst weiter"
          , local: "Zeigt den Text nur dir an (Karte im Spiel)", fn: "Sonderfunktion - hat keinen Text", yk: "Lokaler Befehl aus v2 - wirkt sofort beim Tippen"}
    YkUi_Set(g_H.tbInfo, t.label . "  ·  " . typ[t.type])
    ed := YkTbEditable(t)
    GuiControl, Yk:, YkG_TbText, % ed ? YkTbText(t) : ""
    GuiControl, % "Yk:" . (ed ? "Enable" : "Disable"), YkG_TbText
    YkUi_TogSet("YkG_TbActive", (t.type = "yk") ? 1 : !YK_TbOff[t.cmd])
    GuiControl, Yk:, YkG_TbHk, % YkGui_HkForControl(YK_TbKeys[t.cmd])
    GuiControl, % "Yk:" . ((t.type = "yk" || t.arg = "space") ? "Disable" : "Enable"), YkG_TbHk
}

YkGui_TbActiveClick() {
    global g_TbSel, YK_TbOff
    t := YkTb_Find(g_TbSel)
    if (!IsObject(t) || t.type = "yk") {
        YkUi_TogSet("YkG_TbActive", 1)
        return
    }
    if (YkUi_TogGet("YkG_TbActive"))
        YK_TbOff.Delete(t.cmd)
    else
        YK_TbOff[t.cmd] := 1
    YkGui_Commit()
}

YkGui_TbSave() {
    global g_TbSel, YK_TbTexts, YK_TbKeys
    t := YkTb_Find(g_TbSel)
    if (!IsObject(t) || t.type = "yk")
        return
    if (YkTbEditable(t)) {
        GuiControlGet, txt, Yk:, YkG_TbText
        txt := RTrim(StrReplace(txt, "`r"), "`n")
        if (txt == t.text || Trim(txt) = "")
            YK_TbTexts.Delete(t.cmd)
        else
            YK_TbTexts[t.cmd] := txt
    }
    GuiControlGet, k, Yk:, YkG_TbHk
    k := YkHk_Normalize(k)
    if (k != YK_TbKeys[t.cmd]) {
        if (!YkGui_KeyFree(k, "T:" . t.cmd))
            return
        if (k = "")
            YK_TbKeys.Delete(t.cmd)
        else
            YK_TbKeys[t.cmd] := k
    }
    YkGui_Commit()
    YkGui_Toast(t.cmd . " gespeichert.")
}

YkGui_TbDefault() {
    global g_TbSel, YK_TbTexts
    t := YkTb_Find(g_TbSel)
    if (!IsObject(t) || !YkTbEditable(t))
        return
    YK_TbTexts.Delete(t.cmd)
    GuiControl, Yk:, YkG_TbText, % t.text
    YkGui_Commit()
    YkGui_Toast("Standardtext wiederhergestellt.")
}

YkGui_CtbLv() {
    global g_CtbSel, YK_CustomTb
    ; nicht unterbrechen: ein Listen-Ereignis dazwischen wuerde die
    ; gewaehlte Liste umstellen (die Auswahl gilt je Fenster, nicht je Thread)
    wasCrit := A_IsCritical
    Critical
    if (A_GuiEvent != "Normal" && A_GuiEvent != "I")
        return YkGui_CritEnd(wasCrit)
    Gui, Yk:Default
    Gui, Yk:ListView, YkG_LvCtb
    r := LV_GetNext(0, "F")
    if (!r || !IsObject(YK_CustomTb[r]))
        return YkGui_CritEnd(wasCrit)
    g_CtbSel := r
    GuiControl, Yk:, YkG_CtbCmd, % YK_CustomTb[r].cmd
    GuiControl, Yk:, YkG_CtbText, % YK_CustomTb[r].text
    YkGui_CritEnd(wasCrit)
}

YkGui_CtbSave() {
    global YK_CustomTb, g_CtbSel
    GuiControlGet, c, Yk:, YkG_CtbCmd
    GuiControlGet, t, Yk:, YkG_CtbText
    c := Trim(c), t := RTrim(StrReplace(t, "`r"), "`n")
    if (c = "" || Trim(t) = "")
        return YkGui_Toast("Bitte Befehl und Text eintragen.")
    if (SubStr(c, 1, 1) != "/")
        c := "/" . c
    if (InStr(c, " "))
        return YkGui_Toast("Der Befehl darf kein Leerzeichen enthalten.")
    ; bestehenden Eintrag mit demselben Befehl ersetzen
    idx := 0
    for i, e in YK_CustomTb
        if (e.cmd = c)
            idx := i
    if (!idx && g_CtbSel && IsObject(YK_CustomTb[g_CtbSel]))
        idx := g_CtbSel
    if (idx)
        YK_CustomTb[idx] := {cmd: c, text: t}
    else
        YK_CustomTb.Push({cmd: c, text: t})
    g_CtbSel := 0
    GuiControl, Yk:, YkG_CtbCmd
    GuiControl, Yk:, YkG_CtbText
    YkGui_Commit()
    YkGui_TbFill()
    YkGui_Toast(c . " gespeichert.")
}

YkGui_CtbDelete() {
    global YK_CustomTb, g_CtbSel
    if (!g_CtbSel || !IsObject(YK_CustomTb[g_CtbSel]))
        return YkGui_Toast("Bitte zuerst einen eigenen Befehl in der Liste anklicken.")
    YK_CustomTb.RemoveAt(g_CtbSel)
    g_CtbSel := 0
    GuiControl, Yk:, YkG_CtbCmd
    GuiControl, Yk:, YkG_CtbText
    YkGui_Commit()
    YkGui_TbFill()
}

; =====================================================================
;  Seite: Gegnerlisten
; =====================================================================
YkGui_BuildEnemy() {
    global
    YkUi_Page("enemy")
    YkUi_Card(240, 100, 320, 600, "Listen", "E8FD")
    Gui, Yk:Font, % "s9 norm c" . YkCol.text, Segoe UI
    YkUi_Add("ListView", "-E0x200 x256 y140 w288 h376 vYkG_LvLists gYkGui_ListsLv -Multi AltSubmit NoSort LV0x10000 Background" . YkCol.card . " c" . YkCol.text, "Liste|Befehl|Namen")
    YkUi_Text(258, 530, 280, "Neue Liste", 9, "bold")
    YkUi_Text(258, 552, 120, "Name", 8, "norm", YkCol.dim)
    YkUi_Add("Edit", "x258 y570 w150 h24 vYkG_NewListTitle -E0x200 Border", "")
    YkUi_Text(418, 552, 126, "Kürzel (ohne /)", 8, "norm", YkCol.dim)
    YkUi_Add("Edit", "x418 y570 w126 h24 vYkG_NewListKey -E0x200 Border", "")
    YkUi_Button(258, 606, 138, 34, "Anlegen", "YkGui_ListNew", "primary")
    YkUi_Button(406, 606, 138, 34, "Liste löschen", "YkGui_ListDelete", "danger")
    g_H.listHint := YkUi_Text(258, 650, 290, "Beispiel: Name ""VLA"", Kürzel ""vla"" - dann im Spiel /vla, /vlaadd 12, /vladel 12", 8, "norm", YkCol.faint, "h40")

    YkUi_Card(580, 100, 520, 600)
    g_H.enemyTitle := YkUi_Text(600, 114, 330, "Gegner", 11, "bold")
    g_H.enemyCmds := YkUi_Text(600, 138, 480, "", 9, "norm", YkCol.dim)
    YkUi_Button(950, 112, 132, 32, "Online prüfen", "YkGui_EnemyCheck", "primary")
    YkUi_Add("ListView", "-E0x200 x596 y170 w488 h400 vYkG_LvEnemy -Multi LV0x10000 Background" . YkCol.card . " c" . YkCol.text, "Name|Status|ID|Level|Ping")
    YkUi_Add("Edit", "x596 y586 w250 h28 vYkG_EnemyName -E0x200 Border", "")
    YkGui_Cue("YkG_EnemyName", "Name oder ID ...")
    YkUi_Button(854, 584, 110, 32, "Hinzufügen", "YkGui_EnemyAdd", "primary")
    YkUi_Button(972, 584, 112, 32, "Entfernen", "YkGui_EnemyRemove")
    g_H.enemyInfo := YkUi_Text(598, 628, 486, "", 9, "norm", YkCol.dim, "h60")
    YkUi_Font()
}

YkGui_EnemyRefresh() {
    global g_GuiBuilt, YK_Enemies, g_EnemySel, g_UiCur
    ; nicht unterbrechen: ein Listen-Ereignis dazwischen wuerde die
    ; gewaehlte Liste umstellen (die Auswahl gilt je Fenster, nicht je Thread)
    wasCrit := A_IsCritical
    Critical
    if (!g_GuiBuilt || g_UiCur != "enemy")
        return YkGui_CritEnd(wasCrit)
    Gui, Yk:Default
    Gui, Yk:ListView, YkG_LvLists
    GuiControl, Yk:-Redraw, YkG_LvLists
    LV_Delete()
    sel := 0
    for i, e in YK_Enemies {
        LV_Add("", e.title, "/" . e.key, YkCnt(YkEnemy_Names(e.key)))
        if (e.key = g_EnemySel)
            sel := i
    }
    if (!sel && YK_Enemies.MaxIndex())
        sel := 1, g_EnemySel := YK_Enemies[1].key
    if (sel)
        LV_Modify(sel, "Select Focus")
    LV_ModifyCol(1, 140), LV_ModifyCol(2, 84), LV_ModifyCol(3, "60 Right")
    GuiControl, Yk:+Redraw, YkG_LvLists
    YkGui_EnemyMembers(false)
    YkGui_CritEnd(wasCrit)
}

YkGui_ListsLv() {
    global YK_Enemies, g_EnemySel
    ; nicht unterbrechen: ein Listen-Ereignis dazwischen wuerde die
    ; gewaehlte Liste umstellen (die Auswahl gilt je Fenster, nicht je Thread)
    wasCrit := A_IsCritical
    Critical
    if (A_GuiEvent != "Normal" && A_GuiEvent != "I")
        return YkGui_CritEnd(wasCrit)
    Gui, Yk:Default
    Gui, Yk:ListView, YkG_LvLists
    r := LV_GetNext(0, "F")
    if (!r || !IsObject(YK_Enemies[r]) || YK_Enemies[r].key = g_EnemySel)
        return YkGui_CritEnd(wasCrit)
    g_EnemySel := YK_Enemies[r].key
    YkGui_EnemyMembers(false)
    YkGui_CritEnd(wasCrit)
}

YkGui_EnemyMembers(online) {
    global g_EnemySel, g_H
    ; nicht unterbrechen: ein Listen-Ereignis dazwischen wuerde die
    ; gewaehlte Liste umstellen (die Auswahl gilt je Fenster, nicht je Thread)
    wasCrit := A_IsCritical
    Critical
    e := YkEnemy_Get(g_EnemySel)
    Gui, Yk:Default
    Gui, Yk:ListView, YkG_LvEnemy
    if (!IsObject(e)) {
        LV_Delete()
        YkUi_Set(g_H.enemyTitle, "Keine Liste")
        YkUi_Set(g_H.enemyCmds, "Links eine neue Liste anlegen.")
        YkUi_Set(g_H.enemyInfo, "")
        return YkGui_CritEnd(wasCrit)
    }
    YkUi_Set(g_H.enemyTitle, e.title)
    YkUi_Set(g_H.enemyCmds, "Im Spiel:  /" . e.key . "   ·   /" . e.key . "add ID   ·   /" . e.key . "del ID")
    names := YkEnemy_Names(e.key)
    on := {}
    if (online) {
        o := YkEnemy_Online(e.key)
        if (!IsObject(o))
            YkUi_Set(g_H.enemyInfo, "Online-Status nicht verfügbar - läuft das Spiel und ist ""Spielspeicher lesen"" an?")
        else {
            for i, p in o
                on[p.name] := p
            YkUi_Set(g_H.enemyInfo, YkCnt(o) . " von " . YkCnt(names) . " online.")
        }
    } else {
        YkUi_Set(g_H.enemyInfo, YkCnt(names) . " Namen gespeichert.  Liegt in: Gegnerlisten\" . e.file . ".txt")
    }
    GuiControl, Yk:-Redraw, YkG_LvEnemy
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
    GuiControl, Yk:+Redraw, YkG_LvEnemy
    YkGui_CritEnd(wasCrit)
}

YkGui_EnemyCheck() {
    YkGui_EnemyMembers(true)
}

YkGui_EnemyAdd() {
    global g_EnemySel
    GuiControlGet, v, Yk:, YkG_EnemyName
    v := Trim(v)
    if (v = "" || !IsObject(YkEnemy_Get(g_EnemySel)))
        return
    name := YkEnemy_ResolveName(v, err)
    if (name = "")
        return YkGui_Toast(err)
    if !YkEnemy_Add(g_EnemySel, name)
        return YkGui_Toast(name . " ist schon in der Liste.")
    GuiControl, Yk:, YkG_EnemyName
    YkGui_EnemyRefresh()
    YkGui_Toast(name . " hinzugefügt.")
}

YkGui_EnemyRemove() {
    global g_EnemySel
    ; nicht unterbrechen: ein Listen-Ereignis dazwischen wuerde die
    ; gewaehlte Liste umstellen (die Auswahl gilt je Fenster, nicht je Thread)
    wasCrit := A_IsCritical
    Critical
    Gui, Yk:Default
    Gui, Yk:ListView, YkG_LvEnemy
    r := LV_GetNext(0)
    if (!r)
        return YkGui_CritEnd(wasCrit, YkGui_Toast("Bitte zuerst einen Namen in der Liste markieren."))
    LV_GetText(n, r, 1)
    YkEnemy_Remove(g_EnemySel, n)
    YkGui_EnemyRefresh()
    YkGui_CritEnd(wasCrit)
}

YkGui_ListNew() {
    global g_EnemySel
    GuiControlGet, t, Yk:, YkG_NewListTitle
    GuiControlGet, k, Yk:, YkG_NewListKey
    if (!YkEnemy_NewList(k, t, err))
        return YkGui_Toast(err)
    k := Trim(k, " /")
    StringLower, k, k
    g_EnemySel := k
    GuiControl, Yk:, YkG_NewListTitle
    GuiControl, Yk:, YkG_NewListKey
    YkGui_EnemyRefresh()
    YkGui_Toast("Liste angelegt - im Spiel: /" . k)
}

YkGui_ListDelete() {
    global g_EnemySel
    e := YkEnemy_Get(g_EnemySel)
    if (!IsObject(e))
        return
    MsgBox, 36, Liste löschen, % "Die Liste """ . e.title . """ wirklich entfernen?`n`nDie Textdatei bleibt im Ordner Gegnerlisten erhalten."
    IfMsgBox, Yes
    {
        YkEnemy_DeleteList(e.key)
        g_EnemySel := ""
        YkGui_EnemyRefresh()
    }
}
