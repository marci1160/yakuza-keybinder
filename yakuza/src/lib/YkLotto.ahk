; =====================================================================
;  Yakuza Keybinder - Lotto
; ---------------------------------------------------------------------
;  Kuendigt der Server das naechste Lotto an, kauft der Binder auf Wunsch
;  selbstaendig Lose mit einer zufaelligen Zahl.
;
;  WICHTIG: Das ist der einzige Teil des Binders, der von sich aus
;  Befehle an den Server schickt, ohne dass du eine Taste gedrueckt hast.
;  Je nach Serverregeln kann das als Botting gelten. Deshalb ist es ab
;  Werk AUS - einschalten musst du es selbst.
;
;  Gesendet wird ueber die normale Warteschlange des Binders, nicht mit
;  einem blind getippten "t/lotto 42{Enter}": nur so wird gewartet, bis
;  die Chat-Eingabe wirklich offen ist, nur so sind die Bewegungstasten
;  in diesem Moment gesperrt, und nur so landet nichts davon als
;  Spieltaste im Spiel. Der Abstand zwischen zwei Losen laeuft ueber die
;  Warteschlange mit - ein "Sleep, 1500" wuerde den ganzen Binder je Los
;  anderthalb Sekunden anhalten (Sprint, Kill-Erkennung, Tod-Meldung).
; =====================================================================

global YK_LottoOn    := false
global YK_LottoCount := 1                          ; Anzahl der Lose (1..20)
global YK_LottoCmd   := "/lotto {zahl}"            ; {zahl} = die Zufallszahl
global YK_LottoPat   := "^\[LOTTO\] In ca\. 10 Minuten"
global YK_LottoGapMs := 1500                       ; Abstand zwischen zwei Losen
global YK_LottoMin   := 1
global YK_LottoMax   := 100

global g_LottoT      := 0    ; letzte Auslösung (gegen Doppelmeldungen)
global g_LottoLast   := ""   ; was zuletzt gekauft wurde (fuer die Anzeige)

; Auslöser im Chat. Liefert true, wenn gekauft wird.
YkLotto_HandleLine(line) {
    global YK_LottoOn, YK_LottoPat, YK_KoRejectPat, g_LottoT
    l := YkChat_Clean(line)
    if (l = "")
        return false
    ; Bewusstlos oder sonst gesperrt -> wartende Lose verwerfen, sonst
    ; rennt der Binder gegen eine Wand aus Ablehnungen
    if (YK_KoRejectPat != "" && YkMatch(l, YK_KoRejectPat)) {
        YkLotto_Cancel()
        return false
    }
    if (!YK_LottoOn || YK_LottoPat = "")
        return false
    if (!YkMatch(l, YK_LottoPat))
        return false
    ; dieselbe Ankuendigung kommt gern mehrfach
    if (g_LottoT && (A_TickCount - g_LottoT) < 60000)
        return false
    g_LottoT := A_TickCount
    YkLotto_Buy()
    return true
}

; Lose in die Warteschlange legen. Liefert die Anzahl.
YkLotto_Buy() {
    global YK_LottoCount, YK_LottoCmd, YK_LottoGapMs, YK_LottoMin, YK_LottoMax, g_LottoLast
    n := YK_LottoCount + 0
    if (n < 1)
        n := 1
    if (n > 20)
        n := 20
    lo := YK_LottoMin + 0, hi := YK_LottoMax + 0
    if (lo < 1)
        lo := 1
    if (hi < lo)
        hi := lo
    gap := YK_LottoGapMs + 0
    if (gap < 500)
        gap := 500
    ; erstes Los mit etwas Abstand - die Ankuendigung steht gerade noch im Bild
    due := A_TickCount + 800
    zahlen := ""
    Loop, %n% {
        Random, z, %lo%, %hi%
        YkQueue(StrReplace(YK_LottoCmd, "{zahl}", z), true, due)
        zahlen .= (zahlen != "" ? ", " : "") . z
        due += gap
    }
    g_LottoLast := zahlen
    YkNotify("Lotto: " . n . ((n = 1) ? " Los" : " Lose") . " (" . YkShorten(zahlen, 40) . ")")
    return n
}

; wartende Lose wieder aus der Warteschlange nehmen
YkLotto_Cancel() {
    global g_PendingSends, YK_LottoCmd
    base := Trim(RegExReplace(YK_LottoCmd, "\{zahl\}.*$"))
    if (base = "")
        return 0
    n := 0
    i := g_PendingSends.MaxIndex()
    while (i >= 1) {
        if (InStr(g_PendingSends[i].text, base) = 1) {
            g_PendingSends.RemoveAt(i)
            n += 1
        }
        i -= 1
    }
    return n
}

; wie viele Lose warten noch? (fuer die Anzeige im Fenster)
YkLotto_Pending() {
    global g_PendingSends, YK_LottoCmd
    base := Trim(RegExReplace(YK_LottoCmd, "\{zahl\}.*$"))
    if (base = "")
        return 0
    n := 0
    for i, it in g_PendingSends
        if (InStr(it.text, base) = 1)
            n += 1
    return n
}

YkLotto_Text() {
    global YK_LottoOn, g_LottoT, g_LottoLast
    if (!YK_LottoOn)
        return "aus"
    p := YkLotto_Pending()
    if (p)
        return p . ((p = 1) ? " Los wartet" : " Lose warten")
    if (g_LottoT)
        return "zuletzt: " . YkShorten(g_LottoLast, 30) . "  (" . YkAgeText(g_LottoT) . ")"
    return "an - wartet auf die Ankündigung"
}
