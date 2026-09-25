; =====================================================================
;  Yakuza Keybinder - Wanteds  ({wanteds})
; ---------------------------------------------------------------------
;  Schreibst du {wanteds} in einen eigenen Text, holt der Binder die Zahl
;  beim Server: er schickt kurz vorher /wanteds, wartet auf die Antwort
;  im Chat und schickt DANN erst deinen Satz - mit der frischen Zahl.
;
;  Gefragt wird nur, wenn es wirklich gebraucht wird und die letzte
;  Antwort aelter als eine halbe Minute ist. Kein Dauerverkehr, kein
;  Befehl, den du nicht ausgeloest hast.
;
;  Gewartet wird OHNE Sleep: der Satz bleibt kurz liegen und geht im
;  normalen Takt raus, sobald die Antwort da ist - spaetestens nach der
;  eingestellten Wartezeit, dann mit dem zuletzt bekannten Wert.
;
;  Die Antwort des Servers bleibt im Chat stehen. Sie laesst sich nicht
;  ausblenden: der Binder liest den Spielspeicher ausschliesslich lesend
;  und kann SA-MP keine Zeile wegnehmen.
; =====================================================================

global YK_WantedEnabled := true
global YK_WantedCmd     := "/wanteds"
; Gruppe 1 = die Zahl
global YK_WantedPat     := "(?:Aktuelle\s+)?Wanteds?\s*[:=]?\s*(\d+)"
global YK_WantedWaitMs  := 2500    ; so lange wartet der Satz auf die Antwort
global YK_WantedFreshMs := 30000   ; so lange gilt eine Antwort als frisch

global g_Wanteds     := ""    ; zuletzt gelesene Zahl
global g_WantedsT    := 0     ; wann
global g_WantedAskT  := 0     ; wann zuletzt gefragt
global g_WantedHold  := ""    ; aufgeschobener Satz oder ""

; Zahl fuer den Platzhalter - ohne Warten. "?" wenn nie etwas kam.
YkWanted_Value() {
    global g_Wanteds
    return (g_Wanteds != "") ? g_Wanteds : "?"
}

YkWanted_Fresh() {
    global g_Wanteds, g_WantedsT, YK_WantedFreshMs
    return (g_Wanteds != "" && (A_TickCount - g_WantedsT) < YK_WantedFreshMs)
}

; Muss fuer diesen Text erst gefragt werden?
YkWanted_Needed(text) {
    global YK_WantedEnabled, YK_WantedCmd
    if (!YK_WantedEnabled || Trim(YK_WantedCmd) = "")
        return false
    if !InStr(text, "{wanteds}")
        return false
    return !YkWanted_Fresh()
}

; /wanteds abschicken - direkt, sonst ueber die Warteschlange
YkWanted_Ask() {
    global YK_WantedCmd, g_WantedAskT
    if ((A_TickCount - g_WantedAskT) < 3000)      ; nicht zweimal hintereinander
        return
    g_WantedAskT := A_TickCount
    if (!YkSendCmd(YK_WantedCmd, true))
        YkQueue(YK_WantedCmd, true)
}

; Satz zurueckstellen, bis die Antwort da ist
YkWanted_Defer(cmd, enter, exHp, exArmor, exLoc, exVeh) {
    global g_WantedHold
    g_WantedHold := {cmd: cmd, enter: enter, t: A_TickCount
        , exHp: exHp, exArmor: exArmor, exLoc: exLoc, exVeh: exVeh}
}

; Antwort im Chat mitlesen
YkWanted_HandleLine(line) {
    global YK_WantedEnabled, YK_WantedPat, g_Wanteds, g_WantedsT
    if (!YK_WantedEnabled || YK_WantedPat = "")
        return false
    l := YkChat_Clean(line)
    if (l = "")
        return false
    res := ""
    try res := RegExMatch(l, "i)" . YK_WantedPat, m)
    if (res <= 0 || m1 = "")
        return false
    g_Wanteds := m1 + 0
    g_WantedsT := A_TickCount
    return true
}

; aus dem Haupt-Takt: wartet ein Satz auf die Zahl?
YkWanted_Tick() {
    global g_WantedHold, g_WantedsT, YK_WantedWaitMs
    h := g_WantedHold
    if (!IsObject(h))
        return
    now := A_TickCount
    ready := (g_WantedsT >= h.t) || ((now - h.t) > YK_WantedWaitMs)
    if (!ready)
        return
    ; Der Chat darf nicht offen sein und das Spiel muss vorne sein - sonst
    ; noch ein wenig warten (aber hoechstens 10 s insgesamt).
    if (!YkCanAutoSend(true)) {
        if ((now - h.t) > 10000)
            g_WantedHold := ""
        return
    }
    g_WantedHold := ""
    full := YkFillPlaceholders(h.cmd) . YkBuildExtras(h.exHp, h.exArmor, h.exLoc, h.exVeh)
    if (h.enter)
        full := YkMark_AddGps(full)
    YkSendCmd(full, h.enter)
}
