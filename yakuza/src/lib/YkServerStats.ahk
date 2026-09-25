; =====================================================================
;  Yakuza Keybinder - Kills und Tode vom Server uebernehmen
; ---------------------------------------------------------------------
;  Der Binder zaehlt seine eigenen Kills und Tode mit. Das ist gut fuer
;  "diese Sitzung", sagt aber nichts ueber den Stand, den der SERVER
;  fuehrt - und genau der steht im Charaktermenue (Taste N).
;
;  Sobald dieses Menue offen ist, liest der Binder die beiden Zahlen ab
;  und uebernimmt sie. Danach zeigt {kills} den Gesamtstand, und jeder
;  eigene Kill zaehlt bis zum naechsten Abgleich um eins hoch. Fuer
;  "nur diese Sitzung" gibt es weiterhin {kills_sitzung} / {tode_sitzung}.
;
;  Gelesen wird NUR - nichts wird geschrieben, nichts angeklickt, kein
;  Befehl geschickt. Zwei Quellen:
;    1) der Text des offenen SA-MP-Dialogs (YkSamp_DialogText)
;    2) die Server-Anzeigen im Bild (YkSamp_TextDraws) - falls der Server
;       das Menue nicht als Dialog, sondern als Anzeige baut
;  Gesucht wird nur in einem kurzen Fenster: wenn ein Dialog aufgeht oder
;  wenn N gedrueckt wird. Sonst kostet die Statistik gar nichts.
; =====================================================================

global YK_StatsEnabled  := true
; Muster fuer die beiden Zahlen. Gruppe 1 ist die Zahl.
global YK_StatsKillPat  := "Kills?\s*[:=]\s*(\d+)"
global YK_StatsDeathPat := "(?:Tode|Todesf(?:ä|ae)lle|Deaths?)\s*[:=]\s*(\d+)"

global g_TotalKills   := ""     ; Gesamtstand vom Server ("" = noch nie gelesen)
global g_TotalDeaths  := ""
global g_TotalT       := 0      ; wann zuletzt abgeglichen
global g_KillsSince   := 0      ; eigene Kills seit dem Abgleich
global g_DeathsSince  := 0      ; eigene Tode seit dem Abgleich

global g_StatsUntil   := 0      ; bis wann wird nachgesehen
global g_StatsNext    := 0      ; naechster Blick
global g_StatsDlgWas  := 0      ; war beim letzten Blick ein Dialog offen?
global g_StatsDlgT    := 0      ; wann zuletzt nach einem Dialog gesehen
global g_StatsNDown   := false  ; war N beim letzten Blick gedrueckt?
global g_StatsTdT     := 0      ; wann zuletzt die Server-Anzeigen gelesen

; ---------------------------------------------------------------------
;  Takt (aus dem schnellen 50-ms-Timer)
; ---------------------------------------------------------------------
YkStats_Tick() {
    global YK_StatsEnabled, YK_MemEnabled, g_StatsUntil, g_StatsNext
    global g_StatsDlgWas, g_StatsDlgT, g_StatsNDown
    if (!YK_StatsEnabled || !YK_MemEnabled)
        return
    now := A_TickCount

    ; Auslöser 1: N gedrueckt (Charaktermenue). Absichtlich per GetKeyState
    ; und NICHT als Hotkey - die Kurzform-Beobachter belegen A-Z bereits mit
    ; ~*vkXX, ein zweiter Hotkey auf N wuerde sich damit beissen.
    nDown := (YkGame_Active() && GetKeyState("n", "P")) ? true : false
    if (nDown && !g_StatsNDown)
        g_StatsUntil := now + 4000
    g_StatsNDown := nDown

    ; Auslöser 2: SA-MP meldet einen neu geoeffneten Dialog.
    ; Viermal pro Sekunde genuegt - ein Dialog bleibt ja offen stehen,
    ; und das Suchfenster danach ist 4 Sekunden lang.
    if ((now - g_StatsDlgT) >= 250) {
        g_StatsDlgT := now
        dlg := YkSamp_DialogOpen()
        if (dlg = 1 && g_StatsDlgWas != 1)
            g_StatsUntil := now + 4000
        if (dlg >= 0)
            g_StatsDlgWas := dlg
    }

    if (now > g_StatsUntil)
        return
    if (now < g_StatsNext)
        return
    g_StatsNext := now + 150
    YkStats_Look()
}

; Einmal nachsehen: Dialogtext, sonst die Server-Anzeigen
YkStats_Look() {
    global g_StatsUntil, g_StatsTdT
    k := "", d := ""
    if (YkStats_Parse(YkSamp_DialogText(), k, d)) {
        YkStats_Set(k, d)
        g_StatsUntil := 0            ; gefunden - nicht weiter suchen
        return true
    }
    ; Die Server-Anzeigen sind der teure Weg (der ganze Anzeigen-Block des
    ; Spiels). Einmal pro Sekunde reicht dafuer - ein offenes Menue laeuft
    ; nicht weg, und im Gefecht soll das Lesen nicht ins Gewicht fallen.
    if ((A_TickCount - g_StatsTdT) < 1000)
        return false
    g_StatsTdT := A_TickCount
    tds := YkSamp_TextDraws()
    if (IsObject(tds)) {
        all := ""
        for i, t in tds
            all .= t . "`n"
        if (YkStats_Parse(all, k, d)) {
            YkStats_Set(k, d)
            g_StatsUntil := 0
            return true
        }
    }
    return false
}

; Farbcodes raus: ~r~ ~y~ ~n~ (Server-Anzeigen) und {FFFFFF} (Chat)
YkStats_Clean(s) {
    s := RegExReplace(s, "i)~n~", "`n")
    s := RegExReplace(s, "~[A-Za-z]~")
    return RegExReplace(s, "\{[0-9A-Fa-f]{6}\}")
}

; Beide Zahlen aus einem Text holen.
; Es zaehlt nur, wenn BEIDE darin stehen - eine einzelne "Kills: 5" kann
; auch der Zwischenstand eines Wars sein, und den soll der Gesamtstand
; nicht ueberschreiben.
YkStats_Parse(text, ByRef kills, ByRef deaths) {
    global YK_StatsKillPat, YK_StatsDeathPat
    kills := "", deaths := ""
    if (text = "")
        return false
    if (StrLen(text) > 20000)
        text := SubStr(text, 1, 20000)
    t := YkStats_Clean(text)
    k := "", d := ""
    res := ""
    try res := RegExMatch(t, "i)" . YK_StatsKillPat, m)
    if (res > 0)
        k := m1
    res := ""
    try res := RegExMatch(t, "i)" . YK_StatsDeathPat, m)
    if (res > 0)
        d := m1
    if (k = "" || d = "")
        return false
    k += 0, d += 0
    if (k < 0 || k > 999999 || d < 0 || d > 999999)
        return false
    kills := k
    deaths := d
    return true
}

YkStats_Set(k, d) {
    global g_TotalKills, g_TotalDeaths, g_TotalT, g_KillsSince, g_DeathsSince
    changed := (g_TotalKills != k || g_TotalDeaths != d || g_KillsSince || g_DeathsSince)
    g_TotalKills := k
    g_TotalDeaths := d
    g_TotalT := A_TickCount
    g_KillsSince := 0
    g_DeathsSince := 0
    if (changed)
        YkOverlay_Refresh()
}

; ---------------------------------------------------------------------
;  Mitzaehlen zwischen zwei Abgleichen
; ---------------------------------------------------------------------
; Jeder Kill/Tod zaehlt ausserdem in der Statistik (gesamt/heute/Monat,
; YkCounter.ahk) - daraus kommen /dkd, /mkd usw.
YkStats_CountKill() {
    global g_KillsSince
    g_KillsSince += 1
    YkCnt_Add("kills")
}

YkStats_CountDeath() {
    global g_DeathsSince
    g_DeathsSince += 1
    YkCnt_Add("tode")
}

; Fuer {kills} / {tode}: Gesamtstand, sobald einmal abgeglichen wurde -
; sonst alle Kills, die der Binder selbst gezaehlt hat (seit v3.0; bis
; v2.0.2 war es an dieser Stelle nur die laufende Sitzung).
YkStats_Kills() {
    global g_TotalKills, g_KillsSince
    return (g_TotalKills != "") ? (g_TotalKills + g_KillsSince) : YkCnt_Get("kills")
}

YkStats_Deaths() {
    global g_TotalDeaths, g_DeathsSince
    return (g_TotalDeaths != "") ? (g_TotalDeaths + g_DeathsSince) : YkCnt_Get("tode")
}

; Von Hand setzen (/setkills, /settode, /clearkill ...). Ist der Server-
; Stand bekannt, wird er mit angepasst - sonst passte {kills} nicht dazu.
YkStats_SetTotal(key, v) {
    global g_TotalKills, g_TotalDeaths, g_KillsSince, g_DeathsSince
    v := YkN(v)
    if (v < 0)
        v := 0
    YkCnt_SetTotal(key, v)
    if (key = "kills" && g_TotalKills != "")
        g_TotalKills := v, g_KillsSince := 0
    if (key = "tode" && g_TotalDeaths != "")
        g_TotalDeaths := v, g_DeathsSince := 0
    YkOverlay_Refresh()
}

YkStats_HasSync() {
    global g_TotalKills
    return (g_TotalKills != "")
}

; Statuszeile fuer Overlay und Einstellungsfenster
YkStats_Text() {
    global g_TotalKills, g_TotalT, YK_StatsEnabled
    if (!YK_StatsEnabled)
        return "aus"
    if (g_TotalKills = "")
        return "noch nicht abgeglichen - einmal N drücken"
    return "Stand " . YkStats_Kills() . " Kills · " . YkStats_Deaths() . " Tode   ("
        . YkAgeText(g_TotalT) . ")"
}
