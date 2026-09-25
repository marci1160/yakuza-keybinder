; =====================================================================
;  Yakuza Keybinder - Chat-Befehle und Funktionstasten (neu in v3.0)
; ---------------------------------------------------------------------
;  Aus dem Keybinder von Brooklyn 5.0 uebernommen - aber nur, was NICHT
;  von einem bestimmten Server abhaengt: Statistik (/kd, /dkd, /mkd ...),
;  Antworten (/ja, /gok ...), SMS beantworten (/re), Countdown, Stoppuhr,
;  Gegnerlisten, Radio, Aufnahmen. Die Befehle von Life of Player stehen
;  weiter unter "Server-Befehle" (YkCommands.ahk). Jobs gibt es keine.
;  Seit v3.0.1 nach den Chats von Life of Player geordnet: /f = Family-
;  Chat der Organisation, /g = Gang-/Mafienchat (bei Brooklyn/RGN war /f
;  der Fraktionschat und "b" der normale Chat).
;
;  Jeder Eintrag:
;    cmd   das, was man im Chat tippt (mit Enter ausgefuehrt)
;    grp   Gruppe im Fenster
;    type  send    = Zeilen senden (mehrere Zeilen mit `n getrennt)
;          prefill = Chat oeffnen und Text eintragen (ohne Enter)
;          local   = nur fuer dich als Meldung im Spiel
;          fn      = Sonderfunktion (fn = Funktionsname)
;          yk      = lokaler Befehl von v2 (nur zur Anzeige, siehe YkLocal)
;    text  Standardtext (Platzhalter in {...}, im Fenster aenderbar)
;    arg   "space" = loest mit der Leertaste aus statt mit Enter
; =====================================================================

global YK_TbEnabled := true      ; Chat-Befehle ueberhaupt an?
global YK_TbOff     := {}        ; ausgeschaltete Befehle  cmd -> 1
global YK_TbTexts   := {}        ; eigene Texte            cmd -> Text
global YK_TbKeys    := {}        ; Befehle auf einer Taste cmd -> Hotkey
global YK_CustomTb  := []        ; eigene Chat-Befehle [{cmd, text}]
global YK_FnKeys    := {}        ; Funktionstasten         id  -> Hotkey
global YK_FamChat   := "/f"      ; Family-Chat fuer {fchat}
global YK_LineDelay := 250       ; Pause zwischen mehreren Zeilen (ms)
global YK_SmsCmd    := "/sms"
global YK_SmsPattern := "i)SMS.*?(?:Sender|Absender|von|from)\s*:?\s*([A-Za-z0-9_\[\]\.\$@=]{3,24})\s*\((\d+)\)"
global g_MsgLog     := []        ; [{t, text, kind}] fuer das Fenster
global YK_PauseHkReg := ""
global YK_Debug     := false     ; [General] Debug=1 -> YakuzaDebug.log

; Nur zur Fehlersuche: [General] Debug=1 in der INI
YkDbg(text) {
    global YK_Debug
    if (!YK_Debug)
        return
    FormatTime, t, , HH:mm:ss
    FileAppend, % t . "." . A_MSec . "  " . text . "`r`n", % A_ScriptDir . "\YakuzaDebug.log", UTF-8
}

YkTbGroups() {
    return [{id: "fchat", name: "Family-Chat /f (Organisation)", icon: "E902"}
          , {id: "gchat", name: "Gang-/Mafienchat /g", icon: "E8F2"}
          , {id: "chat",  name: "Normaler Chat & SMS", icon: "E8BD"}
          , {id: "stats", name: "Statistik (nur für dich)", icon: "E9D2"}
          , {id: "tools", name: "Werkzeuge & Radio", icon: "E90F"}
          , {id: "rec",   name: "Aufnahmen", icon: "E714"}
          , {id: "gegner", name: "Gegnerlisten", icon: "E8B7"}
          , {id: "yk",    name: "Binder (lokal, ab v1.x)", icon: "E713"}]
}

YkT(cmd, grp, label, type, text := "", fn := "", arg := "") {
    return {id: "tb:" . cmd, cmd: cmd, grp: grp, label: label, type: type, text: text, fn: fn, arg: arg}
}

; Life of Player: der Buchstabe vor dem Befehl sagt, in welchen Chat er geht
;   /f...  Family-Chat der Organisation   ({fchat}, Standard /f)
;   /g...  Gang-/Mafienchat                ({gchat}, Standard /g)
;   ohne   normaler Chat (in der Naehe)
YkTbChats() {
    return [{p: "f", grp: "fchat", pre: "{fchat} ", name: "Family-Chat"}
          , {p: "g", grp: "gchat", pre: "{gchat} ", name: "Gang-/Mafienchat"}
          , {p: "",  grp: "chat",  pre: "",         name: "normaler Chat"}]
}

YkTextDB() {
    static d := ""
    if (IsObject(d))
        return d
    d := []
    crash := "Warning(opcode): Exception 0xC0000005 at 0x7F0C37"
    ; ---- dieselben Saetze in allen drei Chats ----
    ; [Befehl ohne Buchstaben, Beschreibung, Text (jede Zeile bekommt den Chat davor), nur in /f und /g]
    msgs := [["/kd", "K/D gesamt", "» Kills: {kills} - Differenz: {diff} Kills - KD: {kd} «"]
          , ["/dkd", "K/D von heute", "» Kills heute: {dkills} - Differenz: {ddiff} Kills - KD: {dkd} «"]
          , ["/mkd", "K/D vom Monat", "» Kills im {monat}: {mkills} - Differenz: {mdiff} Kills - KD: {mkd} «"]
          , ["/kills", "Kills gesamt", "Aktuelle Kills: {kills}"]
          , ["/dkills", "Kills von heute", "Meine Kills von heute: {dkills} Kills"]
          , ["/mkills", "Kills im Monat", "Gesamte Kills im {monatjahr}: {mkills} Kills"]
          , ["/infokill", "Kills/Tode gesamt, heute und Monat (3 Zeilen)", "Gesamt: Kills: {kills} - Tode: {tode} - Differenz: {diff} - KD: {kd}`nHeute: Kills: {dkills} - Tode: {dtode} - Differenz: {ddiff} - KD: {dkd}`n{monat}: Kills: {mkills} - Tode: {mtode} - Differenz: {mdiff} - KD: {mkd}"]
          , ["/ja", "Positiv", "Positiv"]
          , ["/nein", "Negativ", "Negativ"]
          , ["/ok", "Verstanden", "Verstanden & bestätigt!"]
          , ["/wo", "Wo befindest du dich?", "Wo befindest du dich?", 1]
          , ["/pos", "Mein Standort", "Ich bin gerade in {standort}", 1]
          , ["/on", "Letztes Login sagen", "Letztes Login: {login}"]
          , ["/cd", "Countdown 3 - 2 - 1 - LOS", "3`n{sleep 750}`n2`n{sleep 750}`n1`n{sleep 750}`nLOS!"]
          , ["/exe", "Fake-Absturz (5 Zeilen)", crash . "`n" . crash . "`n" . crash . "`n" . crash . "`n" . crash]]
    for i, ch in YkTbChats() {
        for j, m in msgs {
            if (ch.p = "" && m[4])
                continue
            cmd := "/" . ch.p . SubStr(m[1], 2)
            txt := ""
            for k, line in StrSplit(m[3], "`n")
                txt .= (k > 1 ? "`n" : "") . (InStr(line, "{sleep") ? line : ch.pre . line)
            d.Push(YkT(cmd, ch.grp, m[2] . "  ·  " . ch.name, "send", txt))
        }
    }
    ; ---- nur im normalen Chat ----
    d.Push(YkT("/exe2", "chat", "Fake-Absturz (10 Zeilen)  ·  normaler Chat", "send", crash . "`n" . crash . "`n" . crash . "`n" . crash . "`n" . crash . "`n{sleep 1100}`n" . crash . "`n" . crash . "`n" . crash . "`n" . crash . "`n" . crash))
    d.Push(YkT("/ping", "chat", "Aktuellen Ping sagen  ·  normaler Chat", "send", "Aktueller Ping: {ping}"))
    d.Push(YkT("/re", "chat", "Auf die letzte SMS antworten", "prefill", "{smsbefehl} {letztesms} "))
    d.Push(YkT("/n", "chat", "SMS an die letzte Nummer", "prefill", "{smsbefehl} {letztesms} "))
    ; Tippfehler-Kurzformen ("7" = "/" ohne Shift) - loesen mit Leertaste aus
    for i, k in [["f", "Family-Chat"], ["g", "Gang-/Mafienchat"], ["u", "Underground-Chat"], ["w", "Flüstern"], ["s", "Schreien"]]
        d.Push(YkT("7" . k[1], "chat", "Tippfehler 7" . k[1] . "  ->  /" . k[1] . "  (" . k[2] . ")", "prefill", "/" . k[1] . " ", "", "space"))
    ; ---- Statistik: nur fuer dich / von Hand korrigieren ----
    d.Push(YkT("/tode", "stats", "Tode anzeigen (nur für dich)", "local", "Aktuelle Todesanzahl: {tode}"))
    d.Push(YkT("/otime", "stats", "Deine Spielzeit anzeigen (nur für dich)", "local", "Du hast schon {spielzeit} gespielt (heute {spielzeitheute})."))
    d.Push(YkT("/addkill", "stats", "1 Kill dazuzählen", "fn", "+", "YkFn_StatAdjust", "kills"))
    d.Push(YkT("/clearkill", "stats", "1 Kill abziehen", "fn", "-", "YkFn_StatAdjust", "kills"))
    d.Push(YkT("/down", "stats", "1 Tod dazuzählen", "fn", "+", "YkFn_StatAdjust", "tode"))
    d.Push(YkT("/cleartod", "stats", "1 Tod abziehen", "fn", "-", "YkFn_StatAdjust", "tode"))
    d.Push(YkT("/setkills", "stats", "Kills gesamt festlegen (/setkills 500)", "fn", "setkills", "YkFn_Prompt"))
    d.Push(YkT("/settode", "stats", "Tode gesamt festlegen (/settode 200)", "fn", "settode", "YkFn_Prompt"))
    ; ---- Werkzeuge ----
    d.Push(YkT("/stopuhr", "tools", "Stoppuhr im Chat (mit < anhalten)", "fn", "", "YkFn_Stopwatch"))
    d.Push(YkT("/countdown", "tools", "15-Sekunden-Countdown (nur für dich)", "fn", "15", "YkFn_Countdown"))
    d.Push(YkT("/zeit", "tools", "Sekunden in Minuten umrechnen (/zeit 245)", "fn", "zeit", "YkFn_Prompt"))
    d.Push(YkT("/chillen", "tools", "Kurz AFK: Erinnerung nach 10 Minuten", "fn", "10", "YkFn_Chillen"))
    d.Push(YkT("/iloveradio", "tools", "Radio starten", "fn", "", "YkFn_RadioStart"))
    d.Push(YkT("/radiostop", "tools", "Radio stoppen", "fn", "", "YkFn_RadioStop"))
    ; ---- Aufnahmen ----
    d.Push(YkT("/rec", "rec", "Aufnahme starten", "fn", "", "YkFn_RecStart"))
    d.Push(YkT("/recstop", "rec", "Aufnahme beenden", "fn", "", "YkFn_RecStop"))
    d.Push(YkT("/frag", "rec", "Aufnahme beenden und als Frag ablegen", "fn", "frag", "YkFn_SaveVideo"))
    d.Push(YkT("/beschwerde", "rec", "Aufnahme beenden und als Beschwerde ablegen", "fn", "beschwerde", "YkFn_SaveVideo"))
    ; ---- Gegnerlisten ----
    d.Push(YkT("/gangallcheck", "gegner", "Alle Gegnerlisten: wer ist online?", "fn", "", "YkFn_EnemyCheck"))
    ; ---- Lokale Befehle aus v1/v2 (sofort, ohne Enter - nur Anzeige) ----
    d.Push(YkT("/ykpos", "yk", "Member-Positionen ein/aus", "yk"))
    d.Push(YkT("/ykhud", "yk", "Overlay ein/aus", "yk"))
    d.Push(YkT("/ykclear", "yk", "Gemerkte Positionen und Fahnen löschen", "yk"))
    d.Push(YkT("/ykzu Name", "yk", "Ziel setzen - danach LEERTASTE", "yk"))
    d.Push(YkT("/ykzu1 ... /ykzu9", "yk", "Ziel über die Nummer in der Member-Liste", "yk"))
    d.Push(YkT("/ykzuaus", "yk", "Ziel löschen", "yk"))
    return d
}

; Funktionstasten (neu in v3.0). Die sechs Tasten aus v2 (Standort, Kill,
; /familymap, Sprint, Overlay, Member) stehen weiter in ihren Bereichen.
YkFnKeys() {
    static d := ""
    if (IsObject(d))
        return d
    d := [{id: "pause",   label: "Keybinder pausieren / fortsetzen", fn: "YkFn_Pause",      def: "Pause"}
        , {id: "gui",     label: "Keybinder-Fenster öffnen",          fn: "YkFn_ShowGui",    def: ""}
        , {id: "panic",   label: "Hängende Tasten lösen",             fn: "YkFn_Panic",      def: ""}
        , {id: "repeat",  label: "Letzte Chatzeile wiederholen",      fn: "YkFn_Repeat",     def: ""}
        , {id: "greet",   label: "Gruß nach Uhrzeit (Morgen/Tag/Abend/Nacht)", fn: "YkFn_Greeting", def: ""}
        , {id: "cd15",    label: "15-Sekunden-Countdown (nur für dich)", fn: "YkFn_Countdown", def: ""}
        , {id: "enemies", label: "Gegner online prüfen (alle Listen)", fn: "YkFn_EnemyCheck", def: ""}
        , {id: "radio",   label: "Radio an/aus",                      fn: "YkFn_RadioToggle", def: ""}
        , {id: "rec",     label: "Aufnahme starten / beenden",        fn: "YkFn_RecToggle",  def: ""}
        , {id: "recfrag", label: "Aufnahme beenden und als Frag ablegen", fn: "YkFn_RecFrag", def: ""}]
    return d
}

YkFnKey_Fire(id) {
    if (YkInputBlocked())
        return
    for i, f in YkFnKeys() {
        if (f.id = id) {
            fn := Func(f.fn)
            if (IsObject(fn))
                fn.Call({text: (id = "cd15") ? 15 : ""}, "", false)
            return
        }
    }
}

; Chat-Befehl, der auf einer Taste liegt
YkTb_FireKey(cmd) {
    global YK_Paused
    if (YK_Paused || YkInputBlocked())
        return
    b := YkTb_Find(cmd)
    if (IsObject(b))
        YkExec(b, "", false)
}

YkTb_Find(cmd) {
    for i, t in YkTextDB()
        if (t.cmd = cmd)
            return t
    return ""
}

; Aktueller Text eines Chat-Befehls (eigener Text hat Vorrang)
YkTbText(b) {
    global YK_TbTexts
    return YK_TbTexts.HasKey(b.cmd) ? YK_TbTexts[b.cmd] : b.text
}

YkTbEditable(b) {
    return (b.type = "send" || b.type = "prefill" || b.type = "local")
}

; ---------------------------------------------------------------------
;  Erkennen
; ---------------------------------------------------------------------
; Welcher Chat-Befehl steckt in dieser Zeile? -> {bind, args} oder ""
YkTb_Match(line) {
    global YK_TbOff, YK_CustomTb
    if (line = "")
        return ""
    ; eigene Chat-Befehle zuerst
    for i, c in YK_CustomTb {
        if (c.cmd != "" && line = c.cmd)
            return {bind: {id: "ctb:" . i, cmd: c.cmd, grp: "eigene", label: "Eigener Chat-Befehl", type: "send", text: c.text}, args: ""}
    }
    first := line, rest := ""
    if RegExMatch(line, "^(\S+)\s+(.*)$", mm)
        first := mm1, rest := Trim(mm2)
    for i, t in YkTextDB() {
        if (t.arg = "space" || t.type = "yk" || YK_TbOff[t.cmd])
            continue
        if (t.cmd = line || (t.cmd = first && YkTb_TakesArgs(t)))
            return {bind: t, args: (t.cmd = line) ? "" : rest}
    }
    ; Gegnerlisten: /<liste>, /<liste>add, /<liste>del
    if RegExMatch(line, "i)^/(\w+?)(add|del)?(?:\s+(.+))?$", g) {
        lst := YkEnemy_FindList(g1)
        if (lst != "")
            return {bind: {id: "enemy", cmd: line, grp: "gegner", type: "fn", fn: "YkFn_Enemy", arg: g2, text: lst}, args: Trim(g3)}
    }
    return ""
}

YkTb_TakesArgs(t) {
    return (t.type = "fn" && InStr("|YkFn_Prompt|", "|" . t.fn . "|"))
}

; "7f" + Leertaste -> "/f "
YkTb_SpaceTrigger() {
    global g_KurzBuf, YK_TbOff, YK_TbEnabled, g_Prompt
    if (!YK_TbEnabled || StrLen(g_KurzBuf) > 5 || IsObject(g_Prompt))
        return false
    for i, t in YkTextDB() {
        if (t.arg = "space" && t.cmd = g_KurzBuf && !YK_TbOff[t.cmd]) {
            n := StrLen(g_KurzBuf) + 1
            Sleep, 10
            Loop, % n
                YkKey_Tap(0x08, 0x0E)
            txt := YkFill(YkTbText(t))
            YkKey_Text(txt)
            g_KurzBuf := txt
            g_KurzOk := false
            return true
        }
    }
    return false
}

YkTb_Exec(b, args) {
    if (b.type = "prefill") {
        txt := YkFill(YkTbText(b))
        YkChat_ClearLine()
        YkPrefill_Type(txt)
        return
    }
    ; Befehle, die im Chat bleiben und etwas abfragen
    if (b.type = "fn" && ((b.fn = "YkFn_Prompt" && args = "") || (b.fn = "YkFn_Enemy" && b.arg != "" && args = ""))) {
        YkExec(b, args, true)
        return
    }
    ; alle anderen: Chat schliessen, dann ausfuehren (eigener Thread, damit
    ; Enter sofort wieder frei ist)
    YkChat_Close()
    YkRunLater(Func("YkExec").Bind(b, args, false))
}

; ---------------------------------------------------------------------
;  Ausfuehren
; ---------------------------------------------------------------------
YkExec(b, args := "", inChat := false) {
    if (b.type = "send")
        YkSendLines(YkTbText(b))
    else if (b.type = "prefill")
        YkPrefill(YkFill(YkTbText(b)))
    else if (b.type = "local")
        YkMsg(YkFill(YkTbText(b)))
    else if (b.type = "fn") {
        f := Func(b.fn)
        if (IsObject(f))
            f.Call(b, args, inChat)
    }
}

; Mehrere Zeilen nacheinander senden. {sleep 500} = Pause.
YkSendLines(text) {
    global YK_LineDelay
    sent := 0
    for i, line in StrSplit(text, "`n", "`r") {
        if (Trim(line) = "")
            continue
        if RegExMatch(line, "i)^\s*\{sleep\s+(\d+)\}\s*$", m) {
            Sleep, % m1
            continue
        }
        if (sent)
            Sleep, % YK_LineDelay
        if (YkSay(YkFill(line)))
            sent += 1
    }
    return sent
}

; Eine Zeile sicher senden: wartet kurz, falls gerade gesendet wird oder
; der Chat noch offen ist.
YkSay(line) {
    global g_Sending, g_ChatOpen, g_SampKnown, YK_MemEnabled
    line := Trim(line)
    if (line = "")
        return false
    if (StrLen(line) > 128)
        line := SubStr(line, 1, 128)
    YkDbg("Sende: " . line)
    t0 := A_TickCount
    while ((g_Sending || YkSampOpenNow()) && (A_TickCount - t0) < 3000)
        Sleep, 20
    if (g_ChatOpen && !YkSampOpenNow() && YK_MemEnabled && g_SampKnown)
        g_ChatOpen := false
    ok := YkSendCmd(line, true)
    if (!ok) {
        Sleep, 120
        ok := YkSendCmd(line, true)
    }
    return ok
}

; Chat oeffnen und Text eintragen, ohne abzuschicken ({cursor} = Schreibmarke)
YkPrefill(txt) {
    global g_ChatOpen, g_KurzBuf, g_KurzOk, g_TbDirty, g_Sending
    t0 := A_TickCount
    while (g_Sending && (A_TickCount - t0) < 1500)
        Sleep, 20
    if (g_ChatOpen || YkSampOpenNow()) {
        YkChat_ClearLine()
        YkPrefill_Type(txt)
        return
    }
    p := InStr(txt, "{cursor}")
    full := StrReplace(txt, "{cursor}")
    if (!YkSendCmd(full, false))
        return
    g_ChatOpen := true
    YkKurz_Reset()
    g_KurzBuf := full
    g_KurzOk := false
    if (p) {
        Loop, % StrLen(full) - (p - 1)
            YkKey_Tap(0x25, 0x4B, 1)
        g_TbDirty := true
    }
    YkApplyHotkeyState()
}

YkPrefill_Type(txt) {
    global g_KurzBuf, g_KurzOk, g_TbDirty
    p := InStr(txt, "{cursor}")
    full := StrReplace(txt, "{cursor}")
    YkKey_ReleaseMods()
    YkKey_Text(full)
    g_KurzBuf := full
    g_KurzOk := false
    g_TbDirty := false
    if (p) {
        Loop, % StrLen(full) - (p - 1)
            YkKey_Tap(0x25, 0x4B, 1)
        g_TbDirty := true
    }
}

; ---------------------------------------------------------------------
;  Abfragen im Chat ("Kills: ...")
; ---------------------------------------------------------------------
YkPrompt_Start(kind, label, pass := false, data := "") {
    global g_Prompt, g_ChatOpen, g_KurzBuf, g_KurzOk, g_TbDirty
    g_Prompt := {kind: kind, label: label, pass: pass, data: data}
    if (g_ChatOpen || YkSampOpenNow()) {
        YkChat_ClearLine()
        YkKey_Text(label)
    } else {
        if (!YkSendCmd(label, false)) {
            g_Prompt := ""
            return
        }
        g_ChatOpen := true
        YkApplyHotkeyState()
    }
    g_KurzBuf := label
    g_KurzOk := false
    g_TbDirty := false
    g_Prompt := {kind: kind, label: label, pass: pass, data: data}
}

YkPromptLabels() {
    return {zeit: "Gib die Zeit in Sekunden ein: ", setkills: "Kills: ", settode: "Tode: "}
}

YkPrompt_Done(kind, input, data := "") {
    if (input = "")
        return
    if (kind = "zeit") {
        s := YkN(input)
        YkSay(s . " Sekunden sind " . Floor(s / 60) . " Minuten und " . Mod(s, 60) . " Sekunden")
    } else if (kind = "setkills" || kind = "settode") {
        if input is not integer
            return YkMsg("Bitte eine Zahl eingeben.", "warn")
        YkStats_SetTotal(kind = "setkills" ? "kills" : "tode", input)
        YkMsg((kind = "setkills" ? "Kills" : "Tode") . " auf " . input . " gesetzt.", "ok")
    } else if (SubStr(kind, 1, 9) = "enemyadd:") {
        YkEnemy_AddInput(SubStr(kind, 10), input)
    } else if (SubStr(kind, 1, 9) = "enemydel:") {
        YkEnemy_DelInput(SubStr(kind, 10), input)
    }
}

; ---------------------------------------------------------------------
;  Platzhalter aus dem Keybinder von Brooklyn (zusaetzlich zu denen aus
;  v2, siehe YkPlaceholders.ahk). Unbekannte {...} bleiben stehen.
; ---------------------------------------------------------------------
YkPlaceholderList() {
    return [["{standort}", "Zone (Stadt), z.B. Idlewood (Los Santos)"], ["{zone}", "Zone"], ["{stadt}", "Stadt"]
        , ["{ort}", "Zone oder ""einem Interior"""], ["{hp}", "dein Leben"], ["{ruestung}", "deine Rüstung"]
        , ["{fahrzeug}", "Fahrzeug oder ""zu Fuß"""], ["{unterwegs}", """im Sultan"" oder ""zu Fuß"""], ["{zeit}", "Uhrzeit"], ["{datum}", "Datum"]
        , ["{ruf}", "letzter Hilfe-Ruf: wer"], ["{ruf_ort}", "letzter Hilfe-Ruf: wo"], ["{ziel}", "gewähltes Ziel"], ["{ziel_ort}", "wo dein Ziel ist"]
        , ["{opfer}", "wen du zuletzt erwischt hast"], ["{mörder}", "wer dich zuletzt umgelegt hat"], ["{wanteds}", "aktuelle Wanteds (fragt /wanteds)"]
        , ["{gps}", "deine Koordinaten"], ["{kills}", "Kills (Server-Stand nach N, sonst vom Binder gezählt)"], ["{tode}", "Tode (ebenso)"]
        , ["{kd}", "K/D gesamt"], ["{diff}", "Kills minus Tode"], ["{kills_sitzung}", "Kills dieser Sitzung"], ["{tode_sitzung}", "Tode dieser Sitzung"]
        , ["{dkills}", "Kills heute"], ["{dtode}", "Tode heute"], ["{dkd}", "K/D heute"], ["{ddiff}", "Differenz heute"]
        , ["{mkills}", "Kills im Monat"], ["{mtode}", "Tode im Monat"], ["{mkd}", "K/D im Monat"], ["{mdiff}", "Differenz im Monat"]
        , ["{monat}", "Monatsname"], ["{id}", "deine Spieler-ID"], ["{name}", "dein Name"], ["{ping}", "dein Ping"], ["{level}", "dein Level (Score)"]
        , ["{geld}", "Geld auf der Hand"], ["{fzhp}", "Fahrzeugzustand"], ["{kmh}", "Geschwindigkeit"], ["{online}", "Spieler online"]
        , ["{fchat}", "Family-Chat der Organisation (/f)"], ["{gchat}", "Gang-/Mafienchat (/g)"], ["{letztesms}", "Nummer der letzten SMS"], ["{login}", "letztes Login"]
        , ["{spielzeit}", "Spielzeit gesamt"], ["{spielzeitheute}", "Spielzeit heute"]
        , ["{cursor}", "Schreibmarke (nur bei ""Chat vorbereiten"")"], ["{sleep 500}", "Pause in ms (eigene Zeile)"]]
}

YkFill(text) {
    return YkFillPlaceholders(text)
}

; Zweiter Durchgang fuer alles, was YkFillPlaceholders_V2 nicht kennt
YkFill_Extra(text) {
    if !InStr(text, "{")
        return text
    out := text
    pos := 1
    seen := {}
    while (pos := RegExMatch(out, "\{([a-zA-Z0-9_]+)\}", m, pos)) {
        StringLower, kl, m1
        if (kl = "cursor" || kl = "sleep") {
            pos += StrLen(m)
            continue
        }
        if (!seen.HasKey(kl))
            seen[kl] := YkPh(kl)
        v := seen[kl]
        if (v == Chr(1)) {                 ; unbekannt -> stehen lassen
            pos += StrLen(m)
            continue
        }
        out := SubStr(out, 1, pos - 1) . v . SubStr(out, pos + StrLen(m))
        pos += StrLen(v)
    }
    return out
}

YkPh(k) {
    global YK_GangCmd, YK_FamChat, YK_SmsCmd
    static monate := ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
    if (k = "ort") {
        if (YkMem_GetInterior() > 0)
            return "einem Interior"
        pos := YkCurrentPos()
        if (!IsObject(pos))
            return "unbekannt"
        YkZone_Parts(pos, z, c)
        return z
    }
    if (k = "kd")
        return YkCnt_KD("G")
    if (k = "diff")
        return YkCnt_Diff("G")
    if (k = "dkills")
        return YkCnt_Kills("T")
    if (k = "dtode")
        return YkCnt_Deaths("T")
    if (k = "dkd")
        return YkCnt_KD("T")
    if (k = "ddiff")
        return YkCnt_Diff("T")
    if (k = "mkills")
        return YkCnt_Kills("M")
    if (k = "mtode")
        return YkCnt_Deaths("M")
    if (k = "mkd")
        return YkCnt_KD("M")
    if (k = "mdiff")
        return YkCnt_Diff("M")
    if (k = "monat")
        return monate[A_MM + 0]
    if (k = "monatjahr")
        return monate[A_MM + 0] . " " . A_YYYY
    if (k = "datum")
        return A_DD . "." . A_MM . "." . A_YYYY
    if (k = "id" || k = "ping" || k = "level") {
        loc := YkSamp_Local()
        if (!IsObject(loc))
            return "?"
        v := (k = "id") ? loc.id : (k = "ping") ? loc.ping : loc.score
        return (v = "") ? "?" : v
    }
    if (k = "name")
        return YkMyName()
    if (k = "geld") {
        v := YkMem_GetMoney()
        return (v = "") ? "?" : YkNum(v)
    }
    if (k = "fzhp") {
        v := YkMem_VehicleHealth()
        return (v < 0) ? "?" : v
    }
    if (k = "kmh") {
        v := YkMem_VehicleSpeed()
        return (v < 0) ? "?" : v
    }
    if (k = "online") {
        v := YkSamp_OnlineCount()
        return (v = "") ? "?" : v
    }
    if (k = "fchat")
        return YK_FamChat
    if (k = "gchat")
        return YK_GangCmd
    if (k = "smsbefehl")
        return YK_SmsCmd
    if (k = "letztesms")
        return YkCnt_Info("letztesms")
    if (k = "login") {
        v := YkCnt_Info("login")
        return (v = "") ? "unbekannt" : v
    }
    if (k = "spielzeit")
        return YkDur(YkCnt_Get("spielzeit"))
    if (k = "spielzeitheute")
        return YkDur(YkCnt_Get("spielzeit", "T"))
    if (k = "cpu")
        return Round(YkCpuLoad())
    return Chr(1)
}

; Eigener Name: Einstellung > gelernt > SA-MP > Registry
YkMyName() {
    global YK_OwnName
    if (Trim(YK_OwnName) != "")
        return Trim(YK_OwnName)
    loc := YkSamp_Local()
    if (IsObject(loc) && loc.name != "")
        return loc.name
    n := YkSamp_RegistryName()
    return (n != "") ? n : "Unbekannt"
}

; ---------------------------------------------------------------------
;  Chatzeilen: SMS (fuer /re) und Login (fuer /on)
; ---------------------------------------------------------------------
YkTb_HandleLine(line) {
    global YK_SmsPattern, YK_FamLoginPat
    l := YkChat_Clean(line)
    if (l = "")
        return
    if (YK_SmsPattern != "") {
        res := ""
        try res := RegExMatch(l, YK_SmsPattern, m)
        if (res > 0 && !YkIsOwnName(m1)) {
            YkCnt_SetInfo("letztesms", (m2 != "") ? m2 : m1)
            YkCnt_SetInfo("letztesmsname", m1)
            YkCnt_Add("sms_in")
        }
    }
    if (YK_FamLoginPat != "" && YkMatch(l, YK_FamLoginPat)) {
        FormatTime, t, , dd.MM.yyyy HH:mm
        YkCnt_SetInfo("login", t)
        YkCnt_Add("logins")
    }
}

; ---------------------------------------------------------------------
;  Meldungen nur fuer dich (Karte im Spiel + Liste im Fenster)
; ---------------------------------------------------------------------
YkMsg(text, kind := "info", ms := "") {
    global g_MsgLog, YK_ToastMs, g_GuiMsg, g_GuiMsgT
    text := RegExReplace(text, "\{[0-9A-Fa-f]{6}\}")
    YkDbg("Meldung: " . text)
    FormatTime, t, , HH:mm:ss
    g_MsgLog.Push({t: t, text: text, kind: kind})
    while (g_MsgLog.MaxIndex() > 200)
        g_MsgLog.RemoveAt(1)
    g_GuiMsg := StrReplace(text, "`n", "  ·  ")
    g_GuiMsgT := A_TickCount
    YkGui_LogMsg(t, text, kind)
    if (!YkToast_Allowed())
        return
    if (ms = "")
        ms := YK_ToastMs
    YkToast(text, kind, ms)
}

; =====================================================================
;  Sonderfunktionen. Signatur immer: YkFn_Name(bind, args, inChat)
; =====================================================================
YkFn_Pause(b := "", args := "", inChat := false) {
    YkTogglePause()
}

YkFn_ShowGui(b := "", args := "", inChat := false) {
    YkShowGui()
}

YkFn_Panic(b := "", args := "", inChat := false) {
    YkAction_KeysPanic()
}

; Letzte Zeile wiederholen: Chat oeffnen, Pfeil hoch, Enter
YkFn_Repeat(b := "", args := "", inChat := false) {
    global YK_ChatKey, g_Sending, g_SendEndTick
    if (g_Sending || !YkGame_Active())
        return
    g_Sending := true
    YkKey_ReleaseMods()
    YkKey_Tap(GetKeyVK(YK_ChatKey), GetKeySC(YK_ChatKey))
    YkWaitChatOpen()
    YkKey_Tap(0x26, 0x48, 1)
    Sleep, 30
    YkKey_Tap(0x0D, 0x1C)
    g_Sending := false
    g_SendEndTick := A_TickCount
}

YkFn_Greeting(b := "", args := "", inChat := false) {
    h := A_Hour + 0
    if (h >= 6 && h < 12)
        t := "Ich wünsche dir noch einen schönen Morgen."
    else if (h >= 12 && h < 18)
        t := "Ich wünsche dir noch einen schönen Tag."
    else if (h >= 18)
        t := "Ich wünsche dir noch einen schönen Abend."
    else
        t := "Ich wünsche dir noch eine schöne Nacht."
    YkSay(t)
}

YkFn_Countdown(b := "", args := "", inChat := false) {
    n := (IsObject(b) && b.text + 0 > 0) ? b.text + 0 : 15
    YkToast_Countdown(n)
}

; /chillen: kurz AFK - nach x Minuten erinnert der Binder dich
YkFn_Chillen(b := "", args := "", inChat := false) {
    m := (IsObject(b) && b.text + 0 > 0) ? b.text + 0 : 10
    YkMsg("Bleib nicht zu lange AFK! In " . m . " Minuten erinnere ich dich.")
    YkTimer_Start(m, "AFK - zurück ins Spiel!")
}

; /down, /cleartod, /addkill, /clearkill
YkFn_StatAdjust(b, args := "", inChat := false) {
    global g_TotalKills, g_TotalDeaths, g_KillsSince, g_DeathsSince
    key := b.arg, d := (b.text = "-") ? -1 : 1
    YkCnt_Add(key, d)
    ; Server-Stand bekannt? Dann zaehlt die Korrektur auch dort
    if (key = "kills" && g_TotalKills != "")
        g_KillsSince += d
    if (key = "tode" && g_TotalDeaths != "")
        g_DeathsSince += d
    w := (key = "kills") ? "Kill" : "Tod"
    YkMsg("1 " . w . (d > 0 ? " dazugezählt" : " abgezogen") . " - aktuell " . ((key = "kills") ? YkStats_Kills() : YkStats_Deaths()) . ".")
    YkOverlay_Refresh()
}

YkFn_Prompt(b, args := "", inChat := false) {
    kind := b.text
    if (Trim(args) != "") {
        YkPrompt_Done(kind, Trim(args))
        return
    }
    YkPrompt_Start(kind, YkPromptLabels()[kind])
}

; Stoppuhr im Chat, mit der Taste < anhalten
YkFn_Stopwatch(b := "", args := "", inChat := false) {
    YkSay("Ich starte die Stoppuhr.")
    for i, s in ["- 3 -", "- 2 -", "- 1 -", "- Go -"] {
        Sleep, 2100
        YkSay(s)
    }
    t0 := A_TickCount
    YkMsg("Stoppuhr läuft - mit der Taste < anhalten.")
    KeyWait, <, D T3600
    sec := Round((A_TickCount - t0) / 1000)
    YkSay("Stoppuhr beendet.")
    Sleep, 2000
    YkSay("Zeit: " . (sec // 60) . " Minuten und " . Mod(sec, 60) . " Sekunden")
}

; Gegnerlisten im Chat: /<liste>, /<liste>add, /<liste>del
YkFn_Enemy(b, args := "", inChat := false) {
    lst := b.text, mode := b.arg
    if (mode = "") {
        if (inChat)
            YkChat_Close()
        YkEnemy_ShowOnline(lst)
        return
    }
    if (Trim(args) != "") {
        if (inChat)
            YkChat_Close()
        if (mode = "add")
            YkEnemy_AddInput(lst, args)
        else
            YkEnemy_DelInput(lst, args)
        return
    }
    YkPrompt_Start("enemy" . mode . ":" . lst, (mode = "add") ? "Hinzufügen (ID oder Name): " : "Entfernen (ID oder Name): ")
}

YkFn_EnemyCheck(b := "", args := "", inChat := false) {
    YkEnemy_ShowOnline("*")
}

YkFn_SaveVideo(b, args := "", inChat := false) {
    YkVideo_Save(b.text)
}

YkFn_RecStart(b := "", args := "", inChat := false) {
    YkRec_Start()
}

YkFn_RecStop(b := "", args := "", inChat := false) {
    YkRec_Stop()
}

YkFn_RecToggle(b := "", args := "", inChat := false) {
    global g_RecOn
    if (g_RecOn)
        YkRec_Stop()
    else
        YkRec_Start()
}

YkFn_RecFrag(b := "", args := "", inChat := false) {
    YkVideo_Save("frag")
}

YkFn_RadioStart(b := "", args := "", inChat := false) {
    YkRadio_Play()
}

YkFn_RadioStop(b := "", args := "", inChat := false) {
    YkRadio_Stop()
}

YkFn_RadioToggle(b := "", args := "", inChat := false) {
    global g_RadioOn
    if (g_RadioOn)
        YkRadio_Stop()
    else
        YkRadio_Play()
}
