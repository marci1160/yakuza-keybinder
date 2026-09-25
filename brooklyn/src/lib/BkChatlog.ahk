; =====================================================================
;  Brooklyn Keybinder - Chatlog, GameText und automatische Meldungen
; ---------------------------------------------------------------------
;  v4.60 hat die chatlog.txt bei jedem Treffer GELOESCHT und neu
;  angelegt. Jetzt wird sie nur noch mitgelesen (nichts geht verloren).
;  Die Muster sind dieselben wie in v4.60 (German-Roleplay-Meldungen),
;  Farbcodes wie {00FF00} werden vorher entfernt.
; =====================================================================

global g_ChatFile := "", g_ChatPos := 0, g_ChatRetry := 0
global g_ChatRing := []            ; letzte Zeilen [{t, s}] (s = ohne Farbcodes)
global g_ChatSeen := []
global g_LastDeathT := 0, g_DeathPendT := 0, g_DeathPos := ""
global g_Haft := "", g_HaftT := 0
global g_GtSeen := {}, g_GtKillT := 0
global g_TrunkUntil := 0

BkChatlog_Init() {
    global BK_ChatlogPath, g_ChatFile, g_ChatPos
    p := Trim(BK_ChatlogPath)
    if (p = "")
        p := BkChatlog_Default()
    g_ChatFile := p
    g_ChatPos := 0
    if (FileExist(p)) {
        f := FileOpen(p, "r")
        if (IsObject(f)) {
            sz := f.Length
            ; die letzten ~48 KB merken (fuer /aa, /adre, /re ...), aber
            ; NICHT auswerten - sonst kaemen alte Kills/Tode doppelt
            start := (sz > 49152) ? sz - 49152 : 0
            f.Seek(start, 0)
            chunk := f.Read()
            g_ChatPos := f.Pos
            f.Close()
            Loop, Parse, chunk, `n, `r
                if (A_LoopField != "")
                    BkChat_Remember(BkChat_Clean(A_LoopField), 0)
        }
    }
}

; Chatlog finden (Dokumente-Ordner kann umgeleitet sein, z.B. OneDrive)
BkChatlog_Default() {
    bases := []
    RegRead, personal, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders, Personal
    if (!ErrorLevel && personal != "")
        bases.Push(personal)
    EnvGet, up, USERPROFILE
    if (up != "")
        for i, s in ["\Documents", "\Dokumente", "\OneDrive\Documents", "\OneDrive\Dokumente"]
            bases.Push(up . s)
    EnvGet, od, OneDrive
    if (od != "") {
        bases.Push(od . "\Documents")
        bases.Push(od . "\Dokumente")
    }
    bases.Push(A_MyDocuments)
    for i, b in bases
        for j, t in ["\GTA San Andreas User Files\SAMP\chatlog.txt", "\GTA San Andreas User Files\chatlog.txt"]
            if FileExist(b . t)
                return b . t
    return (up != "") ? up . "\Documents\GTA San Andreas User Files\SAMP\chatlog.txt" : ""
}

BkChatlog_Found() {
    global g_ChatFile
    return (g_ChatFile != "" && FileExist(g_ChatFile))
}

; Neue Zeilen lesen (Timer, alle 150 ms)
BkChatlog_Poll() {
    global g_ChatFile, g_ChatPos, g_ChatRetry
    static busy := false
    if (busy)
        return
    if (g_ChatFile = "" || !FileExist(g_ChatFile)) {
        if (A_TickCount - g_ChatRetry > 10000) {
            g_ChatRetry := A_TickCount
            BkChatlog_Init()
        }
        return
    }
    FileGetSize, fsz, % g_ChatFile
    if (fsz = "" || fsz = g_ChatPos)
        return
    busy := true
    f := FileOpen(g_ChatFile, "r")
    if (!IsObject(f)) {
        busy := false
        return
    }
    sz := f.Length
    if (sz < g_ChatPos)                     ; neu angelegt (Spielstart)
        g_ChatPos := 0
    f.Seek(g_ChatPos, 0)
    chunk := f.Read()
    g_ChatPos := f.Pos
    f.Close()
    Loop, Parse, chunk, `n, `r
    {
        if (A_LoopField = "")
            continue
        s := BkChat_Clean(A_LoopField)
        if (s = "" || BkChat_Dupe(A_LoopField))
            continue
        BkChat_Remember(s, A_TickCount)
        try BkChat_Handle(s)
    }
    busy := false
}

; Zeitstempel "[12:34:56] " und Farbcodes "{FF8200}" entfernen
BkChat_Clean(line) {
    line := RegExReplace(line, "^\[\d{1,2}:\d{2}:\d{2}\]\s?")
    line := RegExReplace(line, "\{[0-9A-Fa-f]{6}\}")
    return Trim(line)
}

BkChat_Dupe(line) {
    global g_ChatSeen
    now := A_TickCount
    while (g_ChatSeen.MaxIndex() && (now - g_ChatSeen[1].t) > 5000)
        g_ChatSeen.RemoveAt(1)
    for i, e in g_ChatSeen
        if (e.s == line)
            return true
    g_ChatSeen.Push({s: line, t: now})
    while (g_ChatSeen.MaxIndex() > 60)
        g_ChatSeen.RemoveAt(1)
    return false
}

BkChat_Remember(s, t) {
    global g_ChatRing
    g_ChatRing.Push({t: t, s: s})
    while (g_ChatRing.MaxIndex() > 400)
        g_ChatRing.RemoveAt(1)
}

; Juengste Zeile, die auf das Muster passt (maxBack = wie weit zurueck)
BkChat_FindLast(pattern, ByRef m, maxBack := 400) {
    global g_ChatRing
    BkChatlog_Poll()
    i := g_ChatRing.MaxIndex()
    n := 0
    while (i >= 1 && n < maxBack) {
        if RegExMatch(g_ChatRing[i].s, pattern, m)
            return g_ChatRing[i].s
        i -= 1, n += 1
    }
    return ""
}

; Auf eine Antwort des Servers warten (nach dem Zeitpunkt since)
BkChat_WaitFor(pattern, ByRef m, since, timeout := 2000) {
    global g_ChatRing
    t0 := A_TickCount
    Loop {
        BkChatlog_Poll()
        i := g_ChatRing.MaxIndex()
        while (i >= 1 && g_ChatRing[i].t >= since) {
            if RegExMatch(g_ChatRing[i].s, pattern, m)
                return g_ChatRing[i].s
            i -= 1
        }
        if ((A_TickCount - t0) > timeout)
            return ""
        Sleep, 60
    }
}

; Zeilen zaehlen, die nach "since" kamen und passen
BkChat_CountSince(since, pattern, wait := 1500) {
    global g_ChatRing
    t0 := A_TickCount
    while ((A_TickCount - t0) < wait) {
        BkChatlog_Poll()
        Sleep, 80
    }
    n := 0
    for i, e in g_ChatRing
        if (e.t >= since && RegExMatch(e.s, pattern))
            n += 1
    return n
}

BkMoney(s) {
    return BkN(RegExReplace(s, "[^\d\-]"))
}

; ---------------------------------------------------------------------
;  Auswertung einer Zeile (Muster aus v4.60)
; ---------------------------------------------------------------------
BkChat_Handle(s) {
    global
    local m, m1, m2, m3, m4, me, z

    ; ---- Login ----
    if InStr(s, "Connected. Joining the game") {
        BkStats_Add("logins")
        FormatTime, z, , dd.MM.yyyy HH:mm
        BkStats_SetInfo("login", z)
        BkStats_SetInfo("drogensession", 0)
        BkMsg("Daten werden erfasst ...")
        return
    }
    if RegExMatch(s, "^Connected to (.+)") {
        if (BK_Welcome) {
            FormatTime, z, , dddd HH:mm
            BkRunLater(Func("BkMsg").Bind("Willkommen " . BkMyName() . " - Es ist " . z . "."))
        }
        return
    }
    ; ---- Payday ----
    if RegExMatch(s, "Zinsen:\s*\+?\$?([\d\.,]+)\s*\(([\d\.,]+)%\)", m) {
        BkStats_Add("zinsen", BkMoney(m1))
        BkLog("finanzlog.txt", "Payday erhalten in " . BkFill("{zone}") . " - Zinsen: " . m1 . "$")
        BkMsg("Du hast beim Payday " . m1 . "$ Zinsen erhalten." . ((m2 = "0.2" || m2 = "0,2") ? " (Donatorpayday!)" : ""), "money")
        return
    }
    if RegExMatch(s, "Neuer Stand:\s*\$?([\d\.,\-]+)", m) {
        BkStats_SetInfo("kontostand", BkMoney(m1))
        return
    }
    if RegExMatch(s, "Kreditkarte:\s*-\s*\$?([\d\.,]+)", m) {
        BkStats_Add("karte", BkMoney(m1))
        return
    }
    if RegExMatch(s, "^\s*Miete:\s*-\s*\$?([\d\.,]+)", m) {
        BkStats_Add("miete", BkMoney(m1))
        return
    }
    ; ---- Wanteds gehackt / geloescht ----
    if RegExMatch(s, "(.+) hat sich in deine Polizeiakte gehackt und (\d+) Wanteds entfernt", m) {
        BkStats_Add("hacked", m2 + 0)
        BkStats_SetInfo("wantedlevel", Max(0, BkInfoOr("wantedlevel", 0) - m2))
        BkLog("finanzlog.txt", m2 . " Wanteds gehackt bekommen von " . m1)
        if (BK_HackMsg)
            BkQueueSay("Mir wurden soeben " . m2 . " Wanteds gehackt.")
        return
    }
    if RegExMatch(s, "Officer (.+) hat dir (\d+) Wanted gel\S+scht\. Grund: (.*)", m) {
        BkStats_SetInfo("wantedlevel", Max(0, BkInfoOr("wantedlevel", 0) - m2))
        BkLog("finanzlog.txt", m2 . " Wanted(s) von " . m1 . " gelöscht, Grund: " . m3)
        if (BK_ClearMsg)
            BkQueueSay("Mir wurden soeben " . m2 . " Wanted(s) von " . m1 . " gecleart!")
        return
    }
    if RegExMatch(s, "Du hast folgendes Verbrechen begangen: \[(.*)\], Zeuge: (.*)", m) {
        BkStats_SetInfo("verbrechen", m1)
        BkStats_SetInfo("zeuge", Trim(m2))
        return
    }
    if RegExMatch(s, "Aktuelles Wantedlevel:\s*(\d+)", m) {
        BkStats_SetInfo("wantedlevel", m1)
        return
    }
    ; ---- Tanken / Blitzer ----
    if RegExMatch(s, "Benzinkanister mit (.*) Einheiten Benzin f\S+r \$?([\d\.,]+) gef", m) {
        BkStats_Add("sprit", BkMoney(m2))
        BkLog("finanzlog.txt", "Benzinkanister für " . m2 . "$ gekauft in " . BkFill("{zone}"))
        return
    }
    if RegExMatch(s, "Fahrzeug f\S+r \$?([\d\.,]+) aufgetankt", m) {
        BkStats_Add("sprit", BkMoney(m1))
        BkLog("finanzlog.txt", "Fahrzeug für " . m1 . "$ aufgetankt in " . BkFill("{zone}"))
        return
    }
    if RegExMatch(s, "Sie sind schneller als (.*)\((.*)\) km/h gefahren\. Strafe: \$?([\d\.,]+)", m) {
        BkStats_Add("blitzer", BkMoney(m3))
        BkLog("finanzlog.txt", "Blitzer: " . m3 . "$ - " . m2 . " km/h in " . BkFill("{zone}"))
        return
    }
    ; ---- Missionen, Anwalt, Kofferraum ----
    me := BkMyName()
    if (InStr(s, "hat die Mission erfolgreich beendet") && InStr(s, me)) {
        BkStats_Add("missionen")
        RegExMatch(s, "Belohnung: (.*) Einflusspunkte", m)
        BkLog("finanzlog.txt", "Mission erfolgreich erfüllt - Einflusspunkte: " . m1)
        return
    }
    if RegExMatch(s, "Anwalt (.+) hat dich aus dem Gef\S+ngnis geholt", m) {
        BkLog("finanzlog.txt", "Durch " . m1 . " aus dem Knast gekommen")
        if (BK_LawyerMsg)
            BkQueueSay(BkFill("{fchat} Aus dem Knast entlassen dank " . m1))
        return
    }
    if InStr(s, "in den Kofferraum gelegt.") {
        BkStats_Add("take")
        return
    }
    if InStr(s, "aus dem Kofferraum genommen.") {
        BkStats_Add("get")
        return
    }
    if (InStr(s, "hat einen Kofferraum") && InStr(s, "aufgebrochen.")) {
        BkStats_Add("kofferraum")
        BkOv_CountdownStop()
        return
    }
    if InStr(s, "ngt an, einen Kofferraum") {
        if (BK_TimerFrage && InStr(s, me))
            BkOv_Countdown(29)
        return
    }
    if InStr(s, "Das Aufbrechen des Kofferraums w") {
        BkOv_CountdownStop()
        return
    }
    ; ---- Drogen ----
    if InStr(s, "Gramm Drogen genommen!") {
        BkStats_Add("drogen", 2)
        BkStats_SetInfo("drogensession", BkN(BkStats_Info("drogensession")) + 1)
        if (BK_Drogensage)
            SetTimer, BkDrugTimer, -19600
        return
    }
    if InStr(s, "Du warst in der Entzugsklinik und") {
        BkLog("finanzlog.txt", "Entzugsklinik erfolgreich")
        BkMsg("Du kannst jetzt wieder 26 Gramm Drogen nehmen!", "ok")
        return
    }
    ; ---- AFK, Rentcar, Robs ----
    if InStr(s, "Anwesenheit best") {
        BkStats_Add("notafk")
        FormatTime, z, , dd.MM. HH:mm
        BkStats_SetInfo("afk", z)
        return
    }
    if InStr(s, "Du hast das Fahrzeug gemietet") {
        FormatTime, z, , dd.MM. HH:mm
        BkStats_SetInfo("rentinfo", z)
        BkLog("finanzlog.txt", "Rentcar gemietet in " . BkFill("{zone}"))
        return
    }
    if InStr(s, "raubt die Bank in San Fierro aus!") {
        FormatTime, z, , dd.MM. HH:mm
        BkStats_SetInfo("robsf", z)
        return
    }
    if InStr(s, "raubt die Bank in Los Santos aus!") {
        FormatTime, z, , dd.MM. HH:mm
        BkStats_SetInfo("robls", z)
        return
    }
    if InStr(s, "am Tresor des Grand Hotel LS eine Dynamitladung angebracht") {
        FormatTime, z, , dd.MM. HH:mm
        BkStats_SetInfo("robtresor", z)
        return
    }
    ; ---- SMS ----
    if RegExMatch(s, "SMS:\s*(.*), Sender: (\S+) \((\w+)\)", m) {
        if (m2 = me) {
            BkStats_Add("sms_out")
            BkLog("smslog.txt", "SMS verfasst: " . m1)
        } else {
            BkStats_Add("sms_in")
            BkStats_SetInfo("letztesms", m3)
            BkStats_SetInfo("letztesmsname", m2)
            BkLog("smslog.txt", "SMS von " . m2 . " erhalten: " . m1)
        }
        return
    }
    if RegExMatch(s, ", Kontakt: .*Tel:\s*(\w+)", m) || RegExMatch(s, "Tel:\s*(\d+)", m) {
        BkStats_SetInfo("adnummer", m1)
        ; kein return: die Zeile kann noch mehr enthalten
    }
    ; ---- Uhrzeit / Antiflood ----
    if InStr(s, "SERVER: Es ist jetzt 0:00 Uhr") {
        BkMsg("Es wurde erfolgreich eine neue Tagesstatistik angelegt!")
        return
    }
    if InStr(s, "Antiflood: Achtung! Unterlasse das") {
        if (BK_Antispam) {
            g_FloodUntil := A_TickCount + 1600
            BkApplyHotkeyState()
            BkMsg("Antispam: alle Tasten kurz blockiert!", "warn")
            SetTimer, BkFloodEnd, -1700
        }
        return
    }
    ; ---- Knast ----
    if RegExMatch(s, "Du wurdest von (.+) f\S+r (\d+) Sekunden eingesperrt", m) {
        BkStats_Add("knast", m2 + 0)
        BkLog("finanzlog.txt", "Von " . m1 . " für " . m2 . " Sekunden eingesperrt")
        if (BK_Arrestsage)
            BkQueueSay(BkFill("{fchat} Von " . m1 . " für " . Floor(m2 / 60) . " Minuten eingesperrt"))
        else
            BkMsg("Von " . m1 . " für " . Floor(m2 / 60) . " Minuten eingesperrt.")
        return
    }
    if RegExMatch(s, "Du wurdest f\S+r (\d+) Sekunden eingesperrt und verlierst wegen Flucht und Kill durch einen Polizist \$?([\d\.,]+)", m) {
        BkStats_Add("knast", m1 + 0)
        BkStats_Add("copdm", BkMoney(m2))
        BkDeath_Count("cop", m1)
        return
    }
    ; ---- Tod ----
    if RegExMatch(s, "Du hast wegen deines Todes \$?([\d\.,]+) aus der Geldb\S+rse verloren", m) {
        BkStats_Add("todverlust", BkMoney(m1))
        BkDeath_Count("money", m1)
        return
    }
    if InStr(s, "Weil du gestorben bist, hast du die Drogen") {
        BkDeath_Count("drugs")
        return
    }
    ; ---- Kills ----
    if InStr(s, "Aufgrund deiner Tarnung wurde") {
        if (BK_AutoWantedKill)
            BkKill_Count("gw", "Tarnung")
        return
    }
}

BkDrugTimer() {
    hp := BkMem_GetHealth()
    if (hp = -1 || hp <= 150)
        BkMsg("Du kannst jetzt wieder Drogen nehmen! (HP: " . BkValOr(hp, -1) . ")", "ok")
}

BkFloodEnd() {
    BkApplyHotkeyState()
    BkBigText("Tasten wieder freigegeben", 1500)
}

; Automatische Meldung in die Warteschlange (wird gesendet, sobald der
; Chat zu ist - nie mitten ins Tippen)
BkQueueSay(line) {
    global g_PendingSends
    g_PendingSends.Push({text: line, t: A_TickCount})
}

BkQueue_Tick() {
    global g_PendingSends, g_ChatOpen, g_Sending, BK_Paused, g_LastKeyActivity
    static last := 0
    if (!g_PendingSends.MaxIndex())
        return
    while (g_PendingSends.MaxIndex() && (A_TickCount - g_PendingSends[1].t) > 120000)
        g_PendingSends.RemoveAt(1)
    if (!g_PendingSends.MaxIndex() || BK_Paused || g_ChatOpen || g_Sending || !BkGame_Active())
        return
    if (BkSampOpenNow() || (A_TickCount - g_LastKeyActivity) < 1200 || (A_TickCount - last) < 800)
        return
    if (GetKeyState("LButton", "P") || GetKeyState("RButton", "P"))
        return
    item := g_PendingSends[1]
    last := A_TickCount
    if (BkSendCmd(item.text, true))
        g_PendingSends.RemoveAt(1)
}

; ---------------------------------------------------------------------
;  Kills und Tode zaehlen und melden
; ---------------------------------------------------------------------
BkKill_Count(kind, source := "") {
    global BK_GWZ, BK_GZZ, BK_GWLoc, BK_GZLoc
    BkStats_Add("kills")
    zone := BkFill("{zone}")
    BkLog("finanzlog.txt", (kind = "gz" ? "+1 Gangzone" : "+1 Kill") . " in " . zone . (source != "" ? " (" . source . ")" : ""))
    txt := (kind = "gz") ? BK_GZZ : BK_GWZ
    loc := (kind = "gz") ? BK_GZLoc : BK_GWLoc
    line := "{fchat} " . txt . (loc ? " in " . zone : "") . " - Kill Nr. " . BkStats_Get("kills")
    if (source = "Taste")
        BkSay(BkFill(line))
    else
        BkQueueSay(BkFill(line))
    BkGui_StatsRefresh()
}

; kind: cop | money | drugs | mem
BkDeath_Count(kind, val := "") {
    global g_LastDeathT, g_DeathPendT, g_DeathPos, BK_AutoTot
    if ((A_TickCount - g_LastDeathT) < 8000) {       ; schon gezaehlt (zweite Meldung)
        g_DeathPendT := 0
        return
    }
    g_LastDeathT := A_TickCount
    g_DeathPendT := 0
    BkStats_Add("tode")
    zone := IsObject(g_DeathPos) ? BkZone_Describe(g_DeathPos, false) : BkFill("{zone}")
    if IsObject(g_DeathPos) {
        BkZone_Parts(g_DeathPos, z, c, false)
        zone := z
    }
    if (kind = "cop") {
        BkLog("finanzlog.txt", "Von Cops erschossen, " . val . " Sekunden Knast, in " . zone)
        if (BK_AutoTot)
            BkQueueSay(BkFill("{fchat} Wurde von Cops erschossen - Knastzeit: " . Floor(val / 60) . " Minuten"))
        else
            BkMsg("Du wurdest von Cops erschossen - Knastzeit: " . Floor(val / 60) . " Minuten.", "warn")
    } else {
        BkLog("finanzlog.txt", "Gestorben in " . zone . (val != "" ? " und " . val . "$ verloren" : ""))
        if (BK_AutoTot)
            BkQueueSay(BkFill("{fchat} Ich bin soeben in " . zone . " gestorben"))
        else
            BkMsg("Du bist soeben in " . zone . " gestorben (Tode heute: " . BkStats_Get("tode", "T") . ").", "warn")
    }
    BkGui_StatsRefresh()
}

; Tod ueber den Spielspeicher erkennen (fuer Server ohne Todesmeldung):
; Leben faellt auf 0 -> 3 s auf eine Server-Meldung warten, sonst selbst zaehlen
BkDeath_Tick() {
    global BK_MemDeath, g_DeathPendT, g_DeathPos, g_LastDeathT
    static wasDead := false, lastPos := ""
    if (!BK_MemEnabled || !BkMem_Active())
        return
    pos := BkMem_GetPosition()
    dead := BkMem_IsDead()
    if (!dead && IsObject(pos))
        lastPos := pos
    if (dead && !wasDead) {
        g_DeathPos := lastPos
        if (BK_MemDeath && (A_TickCount - g_LastDeathT) > 8000)
            g_DeathPendT := A_TickCount
    }
    wasDead := dead
    if (g_DeathPendT && (A_TickCount - g_DeathPendT) > 3000) {
        g_DeathPendT := 0
        BkDeath_Count("mem")
    }
}

; ---------------------------------------------------------------------
;  GameText: Gangwar-/Gangzone-Kills und Haftzeit
; ---------------------------------------------------------------------
BkGameText_Poll() {
    global g_GtSeen, g_GtKillT, BK_AutoGW, BK_AutoGZ, g_Haft, g_HaftT
    static primed := 0
    if (!BK_MemEnabled || !BkMem_Active())
        return
    for i, g in BkMem_GameTexts() {
        sig := g.style . "|" . g.start . "|" . g.text
        if (g_GtSeen[g.style] == sig)
            continue
        g_GtSeen[g.style] := sig
        ; beim ersten Blick nach dem Start nur merken, nicht zaehlen
        if (primed != BkGame_Pid())
            continue
        t := g.text
        if RegExMatch(t, "i)Restliche Haftstrafe:\s*(\d+)", m) {
            g_Haft := m1, g_HaftT := A_TickCount
            continue
        }
        if ((A_TickCount - g_GtKillT) < 1200)
            continue
        if (BK_AutoGW && RegExMatch(t, "i)gangwar\s*kill")) {
            g_GtKillT := A_TickCount
            BkKill_Count("gw", "Gangwar")
        } else if (BK_AutoGZ && RegExMatch(t, "i)gangzone\s*kill")) {
            g_GtKillT := A_TickCount
            BkKill_Count("gz", "Gangzone")
        }
    }
    primed := BkGame_Pid()
}
