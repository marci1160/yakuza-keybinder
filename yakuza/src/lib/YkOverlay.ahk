; ---------------------------------------------------------------------
;  Overlay
; ---------------------------------------------------------------------
; Alle Hotkeys, die im Overlay auftauchen koennen: {id, key, label}
YkOverlay_ItemList() {
    global YK_LocHotkey, YK_KillHotkey, YK_FamHotkey, YK_SprintToggleHk
    global YK_OvHotkey, YK_MemHotkey, YK_Binds, YK_CmdBinds
    global YK_CombatEnabled, YK_KillEnabled
    items := []
    if (YK_LocHotkey != "")
        items.Push({id: "SYS:loc", key: YK_LocHotkey, label: "Standort senden"})
    if (YK_CombatEnabled && YK_KillEnabled && YK_KillHotkey != "")
        items.Push({id: "SYS:kill", key: YK_KillHotkey, label: "Kill melden"})
    if (YK_FamHotkey != "")
        items.Push({id: "SYS:fam", key: YK_FamHotkey, label: "/familymap"})
    if (YK_SprintToggleHk != "")
        items.Push({id: "SYS:sprint", key: YK_SprintToggleHk, label: "Sprint an/aus"})
    if (YK_OvHotkey != "")
        items.Push({id: "SYS:ov", key: YK_OvHotkey, label: "Overlay an/aus"})
    if (YK_MemHotkey != "")
        items.Push({id: "SYS:mem", key: YK_MemHotkey, label: "Member-Positionen"})
    ; nur Tasten, die wirklich wirken - bei Doppelbelegung gewinnt die erste
    own := YkHk_Owners()
    for i, b in YK_Binds
        if (b.key != "" && own[b.key] = "B:" . i)
            items.Push({id: "B:" . b.key, key: b.key, label: b.cmd})
    for ck, sb in YK_CmdBinds
        if (sb.hk != "" && own[sb.hk] = "S:" . ck)
            items.Push({id: "S:" . ck, key: sb.hk, label: ck})
    return items
}

YkOverlay_IsHidden(id) {
    global YK_OvHidden
    return InStr("|" . YK_OvHidden . "|", "|" . id . "|") > 0
}

YkOv_Head(ov, title, ByRef first, fs) {
    Gui, %ov%:Font, % "s" . (fs - 1) . " bold cE04848", Segoe UI
    if (first)
        Gui, %ov%:Add, Text, xm ym, %title%
    else
        Gui, %ov%:Add, Text, xm y+10, %title%
    first := false
}

; Darf das Overlay ueberhaupt ein Fenster erzeugen?
;
; DAS IST DIE WICHTIGSTE BREMSE IM GANZEN BINDER. Laeuft GTA im echten
; Vollbild, zwingt jedes neu erzeugte Fenster, das immer oben liegen soll,
; Direct3D zu einem Geraete-Neustart: das Bild steht dann ein paar
; Sekunden komplett still. Sichtbar wird das Overlay im Vollbild ohnehin
; nicht. Deshalb wird dort gar nichts mehr gebaut.
;   auto (Standard) = im Vollbild aus, im Fenstermodus an
;   an              = immer bauen (fuer alle, bei denen es funktioniert)
;   aus             = nie bauen
YkOverlay_MayBuild() {
    global YK_OvFullscreen
    if (YK_OvFullscreen = "aus")
        return false
    if (YK_OvFullscreen = "an")
        return YkGame_Hwnd() ? true : false
    ; Laeuft das Spiel gar nicht, wird auch nichts gebaut: sichtbar waere
    ; das Overlay ohnehin nur ueber dem Spiel.
    if (!YkGame_Hwnd())
        return false
    return !YkGame_Fullscreen()
}

; Text eines Overlay-Feldes austauschen, ohne irgendetwas neu zu bauen
YkOv_SetText(hwnd, text) {
    if (!hwnd)
        return
    prevDH := A_DetectHiddenWindows
    DetectHiddenWindows, On
    ControlSetText, , % text, % "ahk_id " . hwnd
    DetectHiddenWindows, %prevDH%
}

; Breite in Pixeln fuer n Zeichen (Segoe UI, Schriftgroesse fs)
YkOv_W(fs, chars) {
    return Round(fs * 0.62 * chars) + 6
}

; Overlay aufbauen.
;
; Frueher wurde das Fenster bei JEDER Inhaltsaenderung komplett neu
; gebaut - also beim Zonenwechsel, bei jedem "vor X Min" und bei jedem
; Standort im Gangchat, praktisch alle paar Sekunden. Jetzt haben alle
; Spalten feste Breiten; geaendert werden nur noch die Texte in den
; vorhandenen Feldern. Wirklich neu gebaut wird nur, wenn sich die
; STRUKTUR aendert (Zahl der Zeilen, Farben, Schriftgroesse) - im
; Normalbetrieb also fast nie.
YkOverlay_Refresh(force := false) {
    global YK_OvEnabled, YK_OvShowKeys, YK_MemShow, YK_OvWar, YK_OvStatus
    global YK_OvSize, YK_OvOpacity
    global g_OvSig, g_OvTextSig, g_OvBuilt, g_OvVisible, g_OvLastAge
    global g_SessKills, g_SessDeaths, g_OvZone, g_OvName, g_OvHwnd
    global g_OvWarHwnds, g_OvH

    g_OvLastAge := A_TickCount
    stat := "", statInfo := "", tgtLine := ""
    wars := []
    kCol := "", dCol := ""
    mRows := [], mLoc := "", mDist := "", mInfo := "", mNote := ""
    hasDist := false
    if (YK_OvEnabled && YkOverlay_MayBuild()) {
        if (YK_OvStatus) {
            stat := (g_OvZone != "") ? g_OvZone : "Standort unbekannt"
            ; Steht der Gesamtstand vom Server fest (Charaktermenue, Taste N),
            ; steht er vorne - die Sitzung daneben in Klammern.
            if (YkStats_HasSync())
                statInfo := "Gesamt:  " . YkStats_Kills() . " Kills  ·  " . YkStats_Deaths()
                    . " Tode      (Sitzung " . g_SessKills . " · " . g_SessDeaths . ")"
            else
                statInfo := "Diese Sitzung:  " . g_SessKills . " Kills  ·  " . g_SessDeaths . " Tode"
            if (YkDeath_Waiting())
                statInfo := "Bewusstlos  ·  Tod-Meldung folgt, sobald du schreiben kannst"
            ; kurze Meldungen (statt einer Windows-Sprechblase, die im
            ; Vollbild das Spielbild einfrieren lassen kann)
            if (g_OvNote != "" && (A_TickCount - g_OvNoteT) < 5000)
                statInfo := YkShorten(g_OvNote, 52)
        }
        if (YK_OvWar)
            wars := YkWar_List()
        if (YK_MemShow) {
            pos := YkCurrentPos()
            for i, o in YkMembers_Sorted(10) {
                col := o.hot ? "FF4A4A" : (o.dead ? "8C8C8C" : (o.target ? "5FD35F" : "FFFFFF"))
                mRows.Push({name: YkShorten((o.target ? "→ " : "") . o.name, 16), col: col})
                mLoc  .= YkShorten(o.loc, 26) . "`n"
                dt := YkMembers_DistText(o.loc, pos, o.gx, o.gy)
                if (dt != " ")
                    hasDist := true
                mDist .= dt . "`n"
                info := YkMembers_KindText(o)
                info := (info != "") ? info . "  " : ""
                if (o.hp != "" && !o.dead)
                    info .= "HP " . o.hp . "  "
                mInfo .= YkShorten(info . YkAgeText(o.t), 26) . "`n"
            }
            if (!mRows.MaxIndex())
                mNote := "Noch keine Positionen im Gangchat"
            z := IsObject(g_Target) ? g_Target : ""
            if (IsObject(z))
                tgtLine := "Unterwegs zu:  " . z.name . "   ·   " . z.loc
        }
        if (YK_OvShowKeys) {
            for i, it in YkOverlay_ItemList() {
                if YkOverlay_IsHidden(it.id)
                    continue
                kCol .= YkHotkeyName(it.key) . "`n"
                dCol .= YkShorten(it.label, 34) . "`n"
            }
        }
    }
    warTexts := "", warCols := ""
    for i, w in wars {
        warTexts .= w.text . "`n"
        warCols .= w.color . "|"
    }
    rowCols := ""
    for i, r in mRows
        rowCols .= r.col . ","

    ; STRUKTUR: nur das fuehrt zu einem Neuaufbau
    sig := (stat != "") . "|" . wars.MaxIndex() . "|" . warCols . "|" . mRows.MaxIndex() . "|" . rowCols
        . "|" . (hasDist ? "D" : "-") . "|" . (mNote != "") . "|" . (tgtLine != "") . "|" . kCol . dCol
        . "|" . YK_OvSize . "|" . YK_OvOpacity
    ; INHALT: wird ohne Neuaufbau in die vorhandenen Felder geschrieben
    names := ""
    for i, r in mRows
        names .= r.name . "`n"
    tsig := stat . "|" . statInfo . "|" . warTexts . "|" . tgtLine . "|" . names . "|" . mLoc . "|" . mDist . "|" . mInfo

    if (!force && g_OvBuilt && sig == g_OvSig) {
        if (tsig == g_OvTextSig)
            return
        g_OvTextSig := tsig
        prevDH := A_DetectHiddenWindows
        DetectHiddenWindows, On
        ControlSetText, , % stat, % "ahk_id " . g_OvH.stat
        ControlSetText, , % statInfo, % "ahk_id " . g_OvH.statInfo
        ControlSetText, , % tgtLine, % "ahk_id " . g_OvH.tgt
        for i, w in wars
            if (g_OvWarHwnds[i])
                ControlSetText, , % w.text, % "ahk_id " . g_OvWarHwnds[i]
        for i, r in mRows
            if (g_OvH.names[i])
                ControlSetText, , % r.name, % "ahk_id " . g_OvH.names[i]
        ControlSetText, , % RTrim(mLoc, "`n"), % "ahk_id " . g_OvH.loc
        ControlSetText, , % RTrim(mDist, "`n"), % "ahk_id " . g_OvH.dist
        ControlSetText, , % RTrim(mInfo, "`n"), % "ahk_id " . g_OvH.info
        DetectHiddenWindows, %prevDH%
        return
    }
    g_OvSig := sig
    g_OvTextSig := tsig
    old := g_OvName
    if (stat = "" && !wars.MaxIndex() && !mRows.MaxIndex() && mNote = "" && kCol = "") {
        ; nichts anzuzeigen (oder Vollbild) - vorhandenes Fenster weg,
        ; und danach hier nichts mehr anfassen
        if (g_OvBuilt) {
            Gui, YkOv:Destroy
            Gui, YkOv2:Destroy
        }
        g_OvBuilt := false
        g_OvVisible := false
        g_OvHwnd := 0
        return
    }

    ; Neu aufgebaut wird in einem ZWEITEN Fenster, versteckt und ausserhalb
    ; des Bildschirms. Erst wenn es an seiner Stelle steht, verschwindet das
    ; alte - keine Luecke, kein Aufblitzen in der Bildschirmmitte.
    ov := (old = "YkOv") ? "YkOv2" : "YkOv"
    fs := (YK_OvSize = 1) ? 8 : (YK_OvSize = 3) ? 11 : 9
    first := true
    ovH := 0
    h := {stat: 0, statInfo: 0, tgt: 0, loc: 0, dist: 0, info: 0, names: []}
    ; E0x20 = WS_EX_TRANSPARENT: Maus geht durch (Click-Through).
    ; Mehr wird hier bewusst NICHT gesetzt - genau so sah das Fenster in
    ; allen Fassungen bis v1.9.2 aus, und genau so lief es stoerungsfrei.
    ; Alles Zusaetzliche haengt am Schalter "Overlay in Aufnahmen
    ; verstecken" und wird erst in YkOverlay_Capture nachgetragen.
    Gui, %ov%:New, +AlwaysOnTop -Caption +ToolWindow +E0x20 +LastFound +HwndovH, YK Overlay
    Gui, %ov%:Color, 121214
    Gui, %ov%:Margin, 14, 10

    ; feste Spaltenbreiten: dadurch reicht spaeter das Austauschen der Texte
    wStat := YkOv_W(fs, 52)
    wWar  := YkOv_W(fs, 74)
    wName := YkOv_W(fs, 16)
    wLoc  := YkOv_W(fs, 26)
    wDist := YkOv_W(fs, 11)
    wInfo := YkOv_W(fs, 26)

    if (stat != "") {
        YkOv_Head(ov, "STATUS", first, fs)
        Gui, %ov%:Font, s%fs% bold cFFFFFF, Segoe UI
        Gui, %ov%:Add, Text, xm y+3 w%wStat% Hwndtmp, %stat%
        h.stat := tmp
        Gui, %ov%:Font, s%fs% norm c8C8C8C, Segoe UI
        Gui, %ov%:Add, Text, xm y+1 w%wStat% Hwndtmp, %statInfo%
        h.statInfo := tmp
    }
    warH := []
    if (wars.MaxIndex()) {
        YkOv_Head(ov, "KRIEGE", first, fs)
        for i, w in wars {
            Gui, %ov%:Font, % "s" . fs . " bold c" . w.color, Segoe UI
            Gui, %ov%:Add, Text, xm y+3 w%wWar% Hwndtmp, % w.text
            warH.Push(tmp)
        }
    }
    if (mRows.MaxIndex() || mNote != "" || tgtLine != "") {
        YkOv_Head(ov, "MEMBER  ·  LETZTER STAND", first, fs)
        if (tgtLine != "") {
            Gui, %ov%:Font, s%fs% bold c5FD35F, Segoe UI
            Gui, %ov%:Add, Text, xm y+3 w%wStat% Hwndtmp, %tgtLine%
            h.tgt := tmp
        }
        if (mRows.MaxIndex()) {
            ; ein Feld je Name, damit er einzeln eingefaerbt sein kann
            for i, r in mRows {
                Gui, %ov%:Font, % "s" . fs . " bold c" . r.col, Segoe UI
                Gui, %ov%:Add, Text, % ((i = 1) ? "xm y+3 Section" : "xs y+0") . " w" . wName . " Hwndtmp", % r.name
                h.names.Push(tmp)
            }
            Gui, %ov%:Font, s%fs% norm cD6D6D6, Segoe UI
            Gui, %ov%:Add, Text, x+10 ys w%wLoc% Hwndtmp, % RTrim(mLoc, "`n")
            h.loc := tmp
            if (hasDist) {
                Gui, %ov%:Font, s%fs% bold cE8C35A, Segoe UI
                Gui, %ov%:Add, Text, x+10 ys w%wDist% Hwndtmp, % RTrim(mDist, "`n")
                h.dist := tmp
            }
            Gui, %ov%:Font, s%fs% norm c8C8C8C, Segoe UI
            Gui, %ov%:Add, Text, x+10 ys w%wInfo% Hwndtmp, % RTrim(mInfo, "`n")
            h.info := tmp
        } else if (mNote != "") {
            Gui, %ov%:Font, s%fs% norm c8C8C8C, Segoe UI
            Gui, %ov%:Add, Text, xm y+3 w%wStat%, %mNote%
        }
    }
    if (kCol != "") {
        YkOv_Head(ov, "HOTKEYS", first, fs)
        Gui, %ov%:Font, s%fs% bold cFFFFFF, Segoe UI
        Gui, %ov%:Add, Text, xm y+3 Section, % RTrim(kCol, "`n")
        Gui, %ov%:Font, s%fs% norm cCFCFCF, Segoe UI
        Gui, %ov%:Add, Text, x+16 ys, % RTrim(dCol, "`n")
    }
    WinSet, Transparent, %YK_OvOpacity%
    ; versteckt und ausserhalb des Bildschirms vorbereiten. "Hide" muss die
    ; LETZTE Option sein: stand frueher "NoActivate" dahinter, zeigte
    ; AutoHotkey das Fenster sofort in der Bildschirmmitte an - im Spiel
    ; als kurzes Aufblitzen, auf dem Desktop dauerhaft.
    Gui, %ov%:Show, x-30000 y-30000 AutoSize Hide
    YkOverlay_Capture(ovH)
    g_OvName := ov
    g_OvHwnd := ovH
    g_OvH := h
    g_OvWarHwnds := warH
    g_OvBuilt := true
    g_OvVisible := false
    YkOverlay_Place()
    Gui, %old%:Destroy
}

; ---------------------------------------------------------------------
;  Overlay und Aufnahmeprogramme
; ---------------------------------------------------------------------
; Seit es das Overlay gibt, klagen Member ueber Aufnahmen, die nicht mehr
; starten oder mittendrin abbrechen (OBS "Spielaufnahme", Windows-
; Spielleiste). Ein zusaetzliches Fenster ueber dem Spiel ist fuer diese
; Programme genau der Fall, den sie nicht moegen.
;
; Windows hat dafuer einen eigenen Schalter: SetWindowDisplayAffinity mit
; WDA_EXCLUDEFROMCAPTURE (0x11). Das Fenster bleibt auf dem Bildschirm
; sichtbar, taucht aber in KEINER Aufnahme und keinem Bildschirmfoto mehr
; auf. Gibt es erst ab Windows 10 Version 2004; vorher gibt es nur
; WDA_MONITOR (0x01), das dasselbe bewirkt (dort wird das Fenster in der
; Aufnahme schwarz).
;
; ACHTUNG - DESHALB IST DER SCHALTER JETZT STANDARDMAESSIG AUS:
; Ein so geschuetztes Fenster ist fuer Windows "geschuetzter Inhalt". Der
; Fenstermanager muss dafuer seinen schnellen Weg verlassen, auf dem ein
; Vollbildspiel sein Bild direkt auf den Bildschirm schiebt. Bei v2.0.0
; hat genau das GTA haengen lassen - jedes Mal, wenn das Overlay neu
; aufgebaut wurde, stand das Spielbild. Bis v1.9.2 gab es den Schalter
; nicht, und da lief alles. Wer das Overlay nicht in seinen Aufnahmen
; haben will, kann ihn einschalten; wer stattdessen ein fluessiges Bild
; will, laesst ihn aus. Im ECHTEN Vollbild wird er nie angewendet.
;
; Am selben Schalter haengt WS_EX_NOACTIVATE (0x08000000): damit kann das
; Overlay dem Spiel den Fokus nicht wegnehmen - sinnvoll beim Aufnehmen,
; aber ebenfalls neu seit v2.0.0 und deshalb nicht mehr immer gesetzt.
YkOverlay_Capture(hwnd) {
    global YK_OvHideCapture
    if (!hwnd || !YK_OvHideCapture)
        return
    if (YkGame_Fullscreen())
        return
    prevDH := A_DetectHiddenWindows
    DetectHiddenWindows, On
    WinSet, ExStyle, +0x08000000, ahk_id %hwnd%      ; WS_EX_NOACTIVATE
    DetectHiddenWindows, %prevDH%
    if DllCall("SetWindowDisplayAffinity", "Ptr", hwnd, "UInt", 0x11) ; EXCLUDEFROMCAPTURE
        return
    DllCall("SetWindowDisplayAffinity", "Ptr", hwnd, "UInt", 0x01)    ; WDA_MONITOR
}

; Laufende Aktualisierung aus dem Haupt-Timer
YkOverlay_Tick() {
    global YK_OvEnabled, YK_OvStatus, g_OvLastAge, g_OvZone, g_OvZoneT
    if (YK_OvEnabled) {
        if (YK_OvStatus && (A_TickCount - g_OvZoneT) > 1000) {
            g_OvZoneT := A_TickCount
            z := YkLocationText()
            if (z != g_OvZone) {
                g_OvZone := z
                YkOverlay_Refresh()
            }
        }
        if ((A_TickCount - g_OvLastAge) > 2000)
            YkOverlay_Refresh()      ; Entfernung, "vor X Min", Countdown
    }
    YkOverlay_Place()
}

; Nur sichtbar, solange das Spiel im Vordergrund ist - an der gewaehlten
; Seite und Hoehe des Spielfensters. Verschoben wird nur, wenn noetig.
YkOverlay_Place() {
    global g_OvBuilt, g_OvVisible, g_OvName, g_OvHwnd, YK_OvSide, YK_OvVPos, YK_OvDodge, g_OvX, g_OvY
    if (!g_OvBuilt)
        return
    ov := g_OvName
    show := YkGame_Active() ? true : false
    if (show) {
        WinGetPos, gx, gy, gw, gh, A
        ; minimiert oder Groesse nicht lesbar -> nicht anzeigen
        if (gw = "" || gw < 200 || gh < 150 || gx <= -30000)
            show := false
    }
    if (!show) {
        ; wirklich verstecken - auch wenn es als unsichtbar gefuehrt wird
        if (g_OvVisible || DllCall("IsWindowVisible", "Ptr", g_OvHwnd)) {
            Gui, %ov%:Hide
            g_OvVisible := false
        }
        return
    }
    prevDH := A_DetectHiddenWindows
    DetectHiddenWindows, On
    WinGetPos, , , ow, oh, ahk_id %g_OvHwnd%
    DetectHiddenWindows, %prevDH%
    m := 18
    x := (YK_OvSide = 1) ? gx + m : gx + gw - ow - m
    top := gy + m + 20
    bottom := gy + gh - oh - m - 20
    if (bottom < top)
        bottom := top
    y := top + Round((bottom - top) * YK_OvVPos / 100)
    ; Life of Player zeigt im Fahrzeug unten rechts eine Tacho-Anzeige
    ; (Fahrzeug, km/h, Tank) - das Overlay rutscht dann darueber
    if (YK_OvDodge && YkMem_InVehicle() = true) {
        limit := gy + Round(gh * 0.77) - m
        if (y + oh > limit)
            y := (limit - oh > top) ? limit - oh : top
    }
    if (!g_OvVisible || x != g_OvX || y != g_OvY) {
        Gui, %ov%:Show, x%x% y%y% NoActivate
        g_OvVisible := true
        g_OvX := x
        g_OvY := y
    }
}

YkOverlay_Toggle() {
    global YK_OvEnabled, YK_IniPath
    YK_OvEnabled := !YK_OvEnabled
    IniWrite, % (YK_OvEnabled ? 1 : 0), %YK_IniPath%, Overlay, Enabled
    YkOverlay_Refresh(true)
    YkGui_SyncState()
}

YkAction_ToggleOverlay() {
    if (YkInputBlocked())
        return
    YkOverlay_Toggle()
}

YkAction_ToggleMembers() {
    if (YkInputBlocked())
        return
    YkMembers_Toggle()
}
