; =====================================================================
;  CHATLOG-UEBERWACHUNG (Kill/Tod-Muster + Login fuer /familymap)
; =====================================================================
YkInitChatlog() {
    global YK_ChatlogPath, g_ChatlogFile, g_ChatlogPos
    p := YK_ChatlogPath
    if (p = "")
        p := YkDefaultChatlog()
    g_ChatlogFile := p
    if (FileExist(p)) {
        f := FileOpen(p, "r")
        if (IsObject(f)) {
            g_ChatlogPos := f.Length
            f.Close()
        }
    } else {
        g_ChatlogPos := 0
    }
}

; Chatlog-Pfad selbst finden.
; SA-MP legt das Log unter "GTA San Andreas User Files\SAMP\chatlog.txt"
; ab - nur liegt "Eigene Dateien" nicht bei jedem an derselben Stelle:
; OneDrive-Umleitung, deutsches "Dokumente", verschobener Ordner. Frueher
; war hier genau EIN Pfad fest verdrahtet; wer davon abwich, bekam still
; und leise keine Kill-Meldung und kein automatisches /familymap.
; Jetzt werden mehrere Kandidaten geprueft - der erste, der wirklich
; existiert, gewinnt.
YkDefaultChatlog() {
    bases := []
    ; 1) echter "Eigene Dateien"-Ordner aus der Registry (folgt Umleitungen)
    RegRead, personal, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders, Personal
    if (!ErrorLevel && personal != "")
        bases.Push(personal)
    ; 2) uebliche Orte relativ zum Benutzerprofil
    EnvGet, up, USERPROFILE
    if (up != "") {
        bases.Push(up . "\Documents")
        bases.Push(up . "\Dokumente")
        bases.Push(up . "\OneDrive\Documents")
        bases.Push(up . "\OneDrive\Dokumente")
    }
    ; 3) OneDrive dort, wo Windows ihn gemeldet hat
    EnvGet, od, OneDrive
    if (od != "") {
        bases.Push(od . "\Documents")
        bases.Push(od . "\Dokumente")
    }

    tails := ["\GTA San Andreas User Files\SAMP\chatlog.txt"
            , "\GTA San Andreas User Files\chatlog.txt"]

    for i, b in bases {
        if (b = "")
            continue
        for j, t in tails {
            p := b . t
            if FileExist(p)
                return p
        }
    }

    ; nichts gefunden: Standardpfad zurueckgeben. Das Log entsteht ohnehin
    ; erst beim ersten Spielstart - die Ueberwachung sucht dann erneut.
    if (up != "")
        return up . "\Documents\GTA San Andreas User Files\SAMP\chatlog.txt"
    return ""
}

YkMonitorChatlog() {
    global g_ChatlogFile, g_ChatlogPos, YK_Paused, g_ChatlogRetry
    if (g_ChatlogFile = "" || !FileExist(g_ChatlogFile)) {
        ; Log noch nicht vorhanden (Spiel noch nicht gestartet) oder es
        ; liegt woanders: hoechstens alle 10 s erneut suchen. Dadurch
        ; faengt sich das von selbst, sobald zum ersten Mal gespielt wird.
        if (A_TickCount - g_ChatlogRetry > 10000) {
            g_ChatlogRetry := A_TickCount
            YkInitChatlog()
        }
        return
    }
    ; Erst nur die Groesse ansehen. Die Datei wirklich zu oeffnen (viermal
    ; pro Sekunde, waehrend SA-MP sie offen zum Schreiben haelt) lohnt sich
    ; nur, wenn ueberhaupt etwas dazugekommen ist.
    FileGetSize, fsz, % g_ChatlogFile
    if (fsz = "")
        return
    if (fsz = g_ChatlogPos)
        return
    f := FileOpen(g_ChatlogFile, "r")
    if (!IsObject(f))
        return
    sz := f.Length
    if (sz <= g_ChatlogPos) {
        g_ChatlogPos := sz
        f.Close()
        return
    }
    f.Seek(g_ChatlogPos, 0)
    chunk := f.Read()
    g_ChatlogPos := f.Pos
    f.Close()
    if (chunk = "")
        return
    Loop, Parse, chunk, `n, `r
    {
        line := A_LoopField
        if (line != "" && !YkChatSeen(line))
            YkHandleChatLine(line)
    }
}

; Haben wir genau diese Zeile eben schon verarbeitet?
;
; Normalerweise kann das nicht passieren - gelesen wird nur der Zuwachs ab
; g_ChatlogPos. Legt SA-MP das Log aber neu an oder kuerzt es (Spielstart,
; Reconnect), springt die Position zurueck, und schon gesehene Zeilen
; kaemen ein zweites Mal herein: doppelte Kills, doppelte Tod-Meldung.
; Darum die letzten 40 Zeilen merken und Wiederholungen innerhalb von
; 5 Sekunden ueberspringen.
YkChatSeen(line) {
    global g_ChatSeen
    now := A_TickCount
    while (g_ChatSeen.MaxIndex() && (now - g_ChatSeen[1].t) > 5000)
        g_ChatSeen.RemoveAt(1)
    for i, e in g_ChatSeen {
        if (e.s == line)
            return true
    }
    g_ChatSeen.Push({s: line, t: now})
    while (g_ChatSeen.MaxIndex() > 40)
        g_ChatSeen.RemoveAt(1)
    return false
}

YkHandleChatLine(line) {
    global YK_FamEnabled, YK_FamLoginPat, YK_FamConnectPat, g_FamilyDone
    global g_LastConnectTick, g_DeathPend

    ; Positionen/Hilfe-Rufe anderer Member und Kriegsstand merken
    ; (lernt dabei auch den eigenen Namen - vor der Kill-Erkennung)
    YkMembers_HandleLine(line)
    YkMembers_HandleKillLine(line)
    YkWar_HandleLine(line)

    ; Reconnect erkannt -> /familymap wieder scharf schalten, alte
    ; Tod-Meldung verwerfen
    if (YK_FamConnectPat != "" && YkMatch(line, YK_FamConnectPat)) {
        g_FamilyDone := false
        g_LastConnectTick := A_TickCount
        g_DeathPend := ""
        YkMark_ClearAll()
    }

    ; Login erkannt -> /familymap ausloesen
    if (YK_FamEnabled && YK_FamLoginPat != "" && !g_FamilyDone) {
        if (YkMatch(line, YK_FamLoginPat)) {
            g_FamilyDone := true
            YkScheduleFamilyMap()
        }
    }

    ; Kills, Bewusstlosigkeit, abgelehnte Befehle
    YkCombat_HandleLine(line)

    ; Antwort auf /wanteds und die Lotto-Ankuendigung
    YkWanted_HandleLine(line)
    YkLotto_HandleLine(line)

    ; SMS (fuer /re) und Login-Zeit (fuer /on) - neu in v3.0
    YkTb_HandleLine(line)
}

; Muster-Vergleich: als Regex versuchen, sonst einfacher Teilstring
YkMatch(line, pattern) {
    if (pattern = "")
        return false
    res := ""
    try res := RegExMatch(line, "i)" . pattern)
    if (res = "" ) {  ; ungueltige Regex -> Teilstring
        return InStr(line, pattern) > 0
    }
    return (res > 0)
}

YkScheduleFamilyMap() {
    global YK_FamDelay, g_FamilyPending
    g_FamilyPending := A_TickCount + YK_FamDelay
}

YkProcessFamilyPending() {
    global g_FamilyPending, YK_FamCommand, YK_Paused
    if (g_FamilyPending = 0)
        return
    if (A_TickCount < g_FamilyPending)
        return
    g_FamilyPending := 0
    if (YK_Paused)
        return
    if (!YkGame_Active())
        return
    YkQueue(YK_FamCommand, true)
}
