; ---------------------------------------------------------------------
;  Lokale Chat-Befehle (werden NICHT an den Server geschickt)
; ---------------------------------------------------------------------
;  /ykpos         Member-Positionen ein/aus
;  /ykhud         Overlay ein/aus
;  /ykclear       gemerkte Member-Positionen leeren
;  /ykzu1 .. /ykzu9   Ziel = Member Nr. 1..9 aus der Member-Liste
;  /ykzu0, /ykzuaus   Ziel wieder loeschen
;  /ykzu Marci + Leertaste   Ziel ueber den Namen (Namensanfang genuegt)
;
; Alles davon bleibt im Binder - der Server bekommt nichts davon zu sehen.
YkLocal_Check(buf, extraDel := 0) {
    global g_ChatOpen
    arg := ""
    if (buf = "ykpos")
        what := "pos"
    else if (buf = "ykhud")
        what := "hud"
    else if (buf = "ykclear")
        what := "clear"
    else if (buf = "ykzuaus" || buf = "ykzu0")
        what := "zielaus"
    else if RegExMatch(buf, "i)^ykzu([1-9])$", m)
        what := "zielnr", arg := m1
    ; Die Namensform wird NUR vom abschliessenden Leerzeichen ausgeloest
    ; (siehe YkLocal_Space) - sonst wuerde sie schon nach dem ersten
    ; Buchstaben des Namens zuschlagen.
    else if (extraDel > 0 && RegExMatch(buf, "i)^ykzu\s+(\S.*)$", m))
        what := "ziel", arg := Trim(m1)
    else
        return false
    ; getippten Befehl samt "/" wieder loeschen und den Chat schliessen
    Loop, % StrLen(buf) + 1 + extraDel
        YkKey_Tap(0x08, 0x0E)
    YkKey_Tap(0x1B, 0x01)
    ; Das eigene Escape sieht die Chat-Erkennung nicht (eigene Tasten
    ; werden ignoriert) - deshalb den Chat hier selbst als zu markieren,
    ; sonst blieben die Hotkeys ohne SA-MP-Speicherzugriff gesperrt.
    g_ChatOpen := false
    YkKurz_Reset()
    YkApplyHotkeyState()
    if (what = "pos")
        YkMembers_Toggle()
    else if (what = "hud")
        YkOverlay_Toggle()
    else if (what = "ziel")
        YkTarget_SetByPrefix(arg)
    else if (what = "zielnr")
        YkTarget_SetByIndex(arg + 0)
    else if (what = "zielaus")
        YkTarget_Clear()
    else
        YkMembers_Clear()
    return true
}

; Wird gerade "/ykzu " getippt? Dann darf das Leerzeichen den Puffer nicht
; beenden - der Name kommt ja erst noch.
YkLocal_Space(ByRef buf) {
    b := buf
    if (SubStr(b, 1, 1) = "/")
        b := SubStr(b, 2)
    if RegExMatch(b, "i)^ykzu$") {
        buf .= " "
        return true                       ; weiter tippen
    }
    if RegExMatch(b, "i)^ykzu\s+\S") {
        ; "/ykzu Marci " - das Leerzeichen schliesst die Eingabe ab.
        ; Es steht schon im Chatfeld, muss also mitgeloescht werden.
        YkLocal_Check(b, 1)
        return true
    }
    return false
}
