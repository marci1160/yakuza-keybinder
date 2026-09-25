; =====================================================================
;  Yakuza Keybinder - Zeitbudgets und Haenger-Protokoll
; ---------------------------------------------------------------------
;  Hier steht alles, was die Frage beantwortet "wie lange darf etwas
;  dauern" - und das Protokoll, das aufschreibt, wenn es doch laenger
;  gedauert hat.
; ---------------------------------------------------------------------
;  Bleibt das Spiel stehen, gibt es hinterher genau eine Frage:
;  War es der Binder - oder stand der ganze Rechner?
;  Raten hilft da nicht, also schreibt der Binder beides mit, in
;  YakuzaHaenger.log neben dem Programm:
;
;    1) LANGER ABSCHNITT - ein Teil des Binders hat laenger als
;       YK_StallMs gebraucht. Dann steht dort, WELCHER Teil.
;    2) SYSTEM STAND - der 50-ms-Takt kam viel zu spaet zurueck,
;       obwohl der Binder selbst nichts gemacht hat. Dann hat Windows
;       ihn nicht drangelassen: die Ursache liegt ausserhalb.
;
;  Die Messung selbst kostet zwei Zeitabfragen je Abschnitt. Das
;  Protokoll begrenzt sich auf 200 KB und wird dann einmal umbenannt.
; =====================================================================
global YK_StallLog := true      ; Protokoll schreiben?
global YK_StallMs  := 250       ; ab dieser Dauer gilt ein Abschnitt als lang
global g_StallTick := 0         ; wann lief der 50-ms-Takt zuletzt?
global g_StallSaid := {}        ; je Abschnitt: wann zuletzt gemeldet

; Wie lange darf EIN Sendevorgang insgesamt auf das Spiel warten?
global YK_SendWaitMs := 400
global g_SendDeadline := 0

; ---------------------------------------------------------------------
;  EIN Zeitbudget fuer den ganzen Sendevorgang
; ---------------------------------------------------------------------
; Im Sendeweg gibt es vier Stellen, an denen auf das Spiel gewartet wird:
; Chat geht auf, Chat ist offen, Zeile ist angekommen, Abbruch aufraeumen.
; Jede hatte bis v2.0.1 ihr eigenes Limit (500 + 400 + 500 + 400 ms). Im
; ungluecklichsten Fall stand der Binder dadurch fast anderthalb Sekunden
; am Stueck - und genau in dieser Zeit sind ueber YkBlock die Buchstaben-
; tasten gesperrt. Das ist das Ruckeln, das man beim Tippen spuert.
;
; Jetzt teilen sich alle Schritte EIN Budget je Sendevorgang. Im
; Normalfall ist der Chat nach wenigen Millisekunden offen und nichts
; davon faellt an; reisst der Faden doch einmal, bricht der Binder nach
; spaetestens YK_SendWaitMs ab. Verloren geht nichts: was ueber die
; Warteschlange kam, bleibt darin liegen und wird im naechsten Takt
; erneut versucht (siehe YkProcessQueue).
YkWait_Left(want) {
    global YK_SendWaitMs, g_SendDeadline
    if (want > YK_SendWaitMs)
        want := YK_SendWaitMs
    if (!g_SendDeadline)
        return want
    left := g_SendDeadline - A_TickCount
    if (left < 0)
        left := 0
    return (want < left) ? want : left
}

; Eine Zeile ins Protokoll. Schreibt hoechstens alle 2 s zum selben
; Stichwort - ein Haenger soll das Protokoll nicht vollschreiben.
YkStall_Log(kind, text) {
    global YK_StallLog, g_StallSaid
    static sizeT := 0
    if (!YK_StallLog)
        return
    now := A_TickCount
    last := g_StallSaid[kind]
    if (last && (now - last) < 2000)
        return
    g_StallSaid[kind] := now
    f := A_ScriptDir . "\YakuzaHaenger.log"
    if ((now - sizeT) > 60000) {
        sizeT := now
        FileGetSize, sz, %f%
        if (sz > 200000)
            FileMove, %f%, % A_ScriptDir . "\YakuzaHaenger.alt.log", 1
    }
    FormatTime, ts, , dd.MM. HH:mm:ss
    FileAppend, % ts . "   " . text . "`r`n", %f%, UTF-8
}

; Aus dem 50-ms-Takt. Misst NUR die Luecke zwischen zwei Durchlaeufen.
; Ist sie viel zu gross, hat nicht der Binder gerechnet - dann ist er
; selbst nicht drangekommen.
YkStall_Watch() {
    global g_StallTick
    now := A_TickCount
    if (!g_StallTick) {
        g_StallTick := now
        return
    }
    gap := now - g_StallTick
    g_StallTick := now
    if (gap < 1000)
        return
    YkStall_Log("system", "SYSTEM STAND " . Format("{:.1f}", gap / 1000.0)
        . " s - in dieser Zeit lief der Binder gar nicht"
        . (YkGame_Active() ? "  (Spiel war vorn)" : ""))
}

; Ein gemessener Abschnitt. ms kommt aus YkDiag_Now().
YkStall_Step(name, ms) {
    global YK_StallMs
    YkDiag_Add(name, ms)
    if (ms >= YK_StallMs)
        YkStall_Log(name, "LANGER ABSCHNITT: " . name . " hat "
            . Format("{:.0f}", ms) . " ms gebraucht")
}

; Kurzfassung fuer die Diagnose im Einstellungsfenster.
; Die Datei wird hoechstens alle 5 s angefasst - die Diagnose wird im Takt
; neu gezeichnet, und 200 KB dabei jedes Mal durchzuzaehlen waere genau die
; Art von Arbeit, die dieses Protokoll aufdecken soll.
YkStall_State() {
    global YK_StallLog, YK_StallMs
    static t := 0, txt := ""
    if (!YK_StallLog)
        return "aus"
    if (txt != "" && (A_TickCount - t) < 5000)
        return txt
    t := A_TickCount
    f := A_ScriptDir . "\YakuzaHaenger.log"
    if (!FileExist(f)) {
        txt := "an, bisher kein Eintrag (gut)"
        return txt
    }
    n := 0
    Loop, Read, %f%
        n := A_Index
    txt := n . " Einträge ab " . YK_StallMs . " ms  ·  YakuzaHaenger.log"
    return txt
}
