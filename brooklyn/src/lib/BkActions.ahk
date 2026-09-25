; =====================================================================
;  Brooklyn Keybinder - Sonderfunktionen der Binds
;  Signatur immer: BkFn_Name(bind, args, inChat)
; =====================================================================

; ---------------------------------------------------------------------
;  Keybinder
; ---------------------------------------------------------------------
BkFn_TogglePause(b := "", args := "", inChat := false) {
    global BK_Paused
    BK_Paused := !BK_Paused
    if (BK_Paused) {
        BkMsg("Keybinder deaktiviert.", "warn")
        BkBigText("~r~Keybinder deaktiviert", 2000)
    } else {
        BkMsg("Keybinder aktiviert.", "ok")
        BkBigText("~g~Keybinder aktiviert", 2000)
    }
    BkApplyHotkeyState()
    BkSetChatMode(g_ChatOpen)
    BkTray_Update()
    BkGui_StatusRefresh()
}

BkFn_Reload(b := "", args := "", inChat := false) {
    BkMsg("Keybinder wird neu gestartet!")
    BkBigText("~g~Keybinder wird neu gestartet", 1500)
    BkShutdown()
    Sleep, 400
    Reload
}

BkFn_ShowGui(b := "", args := "", inChat := false) {
    BkGui_Show()
}

BkFn_ToggleOverlay(b := "", args := "", inChat := false) {
    global BK_OvEnabled
    BK_OvEnabled := !BK_OvEnabled
    BkIni_Write("Overlay", "OvEnabled", BK_OvEnabled)
    if (!BK_OvEnabled)
        BkOv_HideAll()
    else
        BkMsg("Overlay eingeschaltet.")
}

BkFn_Panic(b := "", args := "", inChat := false) {
    BkKeys_Panic()
    BkMsg("Alle Tasten wurden losgelassen.")
}

; ---------------------------------------------------------------------
;  Allgemein
; ---------------------------------------------------------------------
BkFn_EnterExit(b, args, inChat) {
    t := StrSplit(BkBindText(b), "|")
    BkSay(BkMem_GetInterior() > 0 ? (t[2] != "" ? t[2] : "/exit") : (t[1] != "" ? t[1] : "/enter"))
}

; Zeile wiederholen: Chat oeffnen, Pfeil hoch, Enter
BkFn_Repeat(b, args, inChat) {
    global BK_ChatKey, g_Sending
    if (g_Sending || !BkGame_Active())
        return
    g_Sending := true
    BkKey_ReleaseMods()
    BkKey_Tap(GetKeyVK(BK_ChatKey), GetKeySC(BK_ChatKey))
    BkWaitChatOpen()
    BkKey_Tap(0x26, 0x48, 1)
    Sleep, 30
    BkKey_Tap(0x0D, 0x1C)
    g_Sending := false
    g_SendEndTick := A_TickCount
}

BkFn_Greeting(b, args, inChat) {
    h := A_Hour + 0
    if (h >= 6 && h < 12)
        t := "Ich wünsche Ihnen noch einen schönen Morgen."
    else if (h >= 12 && h < 18)
        t := "Ich wünsche Ihnen noch einen schönen Tag."
    else if (h >= 18)
        t := "Ich wünsche Ihnen noch einen schönen Abend."
    else
        t := "Ich wünsche Ihnen noch eine schöne Nacht."
    BkSay(t)
}

BkFn_Fish(b, args, inChat) {
    static fish := ["Einen gekochten Bachneunauge.", "Einen gekochten See Bass.", "Einen gekochten Hai.", "Einen gekochten Thunfisch.", "Einen gekochten Lachs."]
    Random, r, 1, % fish.MaxIndex()
    BkSay("/me isst " . fish[r])
}

BkFn_RandomSpruch(b, args, inChat) {
    list := []
    Loop, 4 {
        s := Trim(BkCfg_Get("Spruch" . A_Index))
        if (s != "")
            list.Push(s)
    }
    if (!list.MaxIndex()) {
        BkMsg("Du hast noch keine Sprüche eingetragen (Einstellungen > Texte).", "warn")
        return
    }
    Random, r, 1, % list.MaxIndex()
    BkSay("/s " . list[r])
}

BkFn_Countdown(b, args, inChat) {
    n := (b.text + 0 > 0) ? b.text + 0 : 15
    BkOv_Countdown(n)
}

; /chillen: kurz AFK - nach x Minuten erinnert der Binder dich
BkFn_Chillen(b, args, inChat) {
    m := (b.text + 0 > 0) ? b.text + 0 : 10
    BkMsg("Bleib nicht zu lange AFK! In " . m . " Minuten erinnere ich dich.")
    BkTimer_Start(m, "AFK - zurück ins Spiel!")
}

BkFn_ChatToggle(b, args, inChat) {
    SendInput, {F7}
}

; Letztes Angebot aus dem Chat annehmen ("... gib /accept drugs ein ...")
BkFn_AcceptLast(b, args, inChat) {
    line := BkChat_FindLast("i)/accept\s+(\w+)", m, 300)
    if (line = "") {
        BkMsg("Kein offenes Angebot im Chat gefunden.", "warn")
        return
    }
    BkSay("/accept " . m1)
}

BkFn_AcceptSex(b, args, inChat) {
    BkSay("/accept sex")
    line := BkChat_FindLast("i)Hure (\S+) hat dir f", m, 300)
    if (line != "") {
        Sleep, % BK_LineDelay
        BkSay("/sex " . m1 . " 1")
    }
}

; Ergebnis von /find ("Der Spieler ist in ...") in einen Kanal geben
BkFn_FindResult(b, args, inChat) {
    line := BkChat_FindLast("i)Der Spieler ist in (.+)", m, 500)
    if (line = "") {
        BkMsg("Noch kein Suchergebnis (/find) im Chat.", "warn")
        return
    }
    ch := BkFill(BkBindText(b))
    BkSay(Trim(ch . " Der gesuchte Spieler ist in " . Trim(m1)))
}

; /members bzw. /orgmembers senden und die Antwortzeilen zaehlen
BkFn_Members(b, args, inChat) {
    t0 := A_TickCount
    BkSay("/members")
    n := BkChat_CountSince(t0, "i)(, Rank:|, Leader|Rang:)", 1600)
    BkMsg("Es sind " . n . " Members online.")
}

BkFn_OrgMembers(b, args, inChat) {
    t0 := A_TickCount
    BkSay("/orgmembers")
    n := BkChat_CountSince(t0, "i)\(Tel\.", 1600)
    BkMsg("Es sind " . n . " Orgmember online.")
}

BkFn_WeaponPack(b, args, inChat) {
    n := (b.text + 0 > 0) ? b.text + 0 : 1
    p := BkCfg_Get("Pack" . n)
    if (Trim(p) = "") {
        BkMsg("Waffenpaket " . n . " ist leer (Einstellungen > Waffen).", "warn")
        return
    }
    lines := ""
    for i, e in StrSplit(p, "|") {
        w := StrSplit(e, ":")
        if (Trim(w[1]) = "")
            continue
        lines .= "/buygun " . Trim(w[1]) . " " . ((w[2] + 0 > 0) ? w[2] + 0 : 1) . "`n"
    }
    BkSendLines(lines)
}

BkFn_Kill(b, args, inChat) {
    BkKill_Count(b.text, "Taste")
}

BkFn_DeathManual(b, args, inChat) {
    BkStats_Add("tode")
    BkMsg("1 Tod wurde hinzugezählt - aktuell " . BkStats_Get("tode") . " Tode.")
}

; ---------------------------------------------------------------------
;  Statistik von Hand
; ---------------------------------------------------------------------
BkFn_StatAdjust(b, args, inChat) {
    key := b.arg, d := (b.text = "-") ? -1 : 1
    BkStats_Add(key, d)
    w := (key = "kills") ? "Kill" : "Tod"
    BkMsg("1 " . w . (d > 0 ? " hinzugezählt" : " abgezogen") . " - aktuell " . BkStats_Get(key) . ".")
}

BkFn_DrugReset(b, args, inChat) {
    BkStats_SetInfo("drogensession", 0)
    BkMsg("Drogenzähler erfolgreich zurückgesetzt!", "ok")
}

BkFn_PrisonTime(b, args, inChat) {
    t0 := A_TickCount
    BkSay("/time")
    while ((A_TickCount - t0) < 1500) {
        BkGameText_Poll()
        if (g_HaftT >= t0)
            break
        Sleep, 50
    }
    h := g_Haft
    if (g_HaftT < t0 || h = "")
        BkMsg("Keine Haftzeit gefunden.", "warn")
    else
        BkMsg("Restliche Haftstrafe: " . h . " Sekunden (" . Floor(h / 60) . " Min " . Mod(h, 60) . " Sek).")
}

; /kstand: /finances NAME senden und Gesamtvermoegen + Level sagen
BkFn_Kontostand(b, args, inChat) {
    t0 := A_TickCount
    BkSay("/finances " . BkMyName())
    line := BkChat_WaitFor("i)Level:\[(\d+)\]\s*Respekt:\[(\d+)\]\s*Geld:\[\$?([\d\.,\-]+)\]\s*Bank:\[\$?([\d\.,\-]+)\]\s*Gesamtverm\S*:\[\$?([\d\.,\-]+)\]", m, t0, 2500)
    if (line = "") {
        BkMsg("Keine Antwort auf /finances erhalten.", "warn")
        return
    }
    BkStats_SetInfo("kontostand", RegExReplace(m4, "[^\d\-]"))
    Sleep, % BK_LineDelay
    BkSay("Aktuelles Gesamtvermögen:[$" . BkNum(RegExReplace(m5, "[^\d\-]")) . "] Level:[" . m1 . " (RP:" . m2 . ")]")
}

; ---------------------------------------------------------------------
;  Dialoge: /service, /cancel, /atm
; ---------------------------------------------------------------------
BkDlg_Wait(open, ms := 1500) {
    t0 := A_TickCount
    Loop {
        d := BkSamp_DialogOpen()
        if (d = -1) {                     ; nicht lesbar -> wie frueher kurz warten
            Sleep, 250
            return true
        }
        if (d = open)
            return true
        if ((A_TickCount - t0) > ms)
            return false
        Sleep, 20
    }
}

BkDlg_Keys(keys) {
    for i, k in StrSplit(keys, ",") {
        k := Trim(k)
        if (k = "down")
            BkKey_Tap(0x28, 0x50, 1)
        else if (k = "up")
            BkKey_Tap(0x26, 0x48, 1)
        else if (k = "enter")
            BkKey_Tap(0x0D, 0x1C)
        else if (k = "esc")
            BkKey_Tap(0x1B, 0x01)
        else
            BkKey_Text(k)
        Sleep, 40
    }
}

; arg "befehl|n": n = 0 -> nur Dialog bestaetigen, n >= 1 -> n-ten Eintrag waehlen
BkFn_Service(b, args, inChat) {
    p := StrSplit(b.text, "|")
    BkSay(p[1])
    if !BkDlg_Wait(1, 1500)
        return
    n := p[2] + 0
    keys := ""
    Loop, % (n > 1 ? n - 1 : 0)
        keys .= "down,"
    BkDlg_Keys(keys . "enter")
}

BkFn_Atm(b, args, inChat) {
    amount := b.text
    BkSay("/atm")
    if !BkDlg_Wait(1, 1500)
        return
    BkDlg_Keys("down,enter")
    Sleep, 150
    BkDlg_Wait(1, 1000)
    BkDlg_Keys(amount . ",enter")
    Sleep, 200
    if (BkSamp_DialogOpen() != 0)
        BkDlg_Keys("esc")
}

; ---------------------------------------------------------------------
;  Countdown / Stoppuhr (mit der Taste < abbrechen)
; ---------------------------------------------------------------------
BkFn_CopCountdown(b, args, inChat) {
    BkSay("Das ist Ihre Chance, sobald der Countdown abgelaufen ist, wenden wir Gewalt an!")
    Sleep, 1000
    for i, n in [3, 2, 1] {
        BkSay("--" . n . "--")
        KeyWait, <, D T1
        if (!ErrorLevel) {
            BkSay("Vielen Dank für Ihre Kooperation.")
            return
        }
    }
    BkSay("Letzte Chance!")
}

BkFn_Stopwatch(b, args, inChat) {
    BkSay("/me startet die Stoppuhr")
    for i, s in ["- 3 -", "- 2 -", "- 1 -", "- Go -"] {
        Sleep, 2100
        BkSay("/l " . s)
    }
    t0 := A_TickCount
    BkMsg("Stoppuhr läuft - mit der Taste < anhalten.")
    KeyWait, <, D T3600
    sec := Round((A_TickCount - t0) / 1000)
    BkSay("/b Stoppuhr wieder beendet")
    Sleep, 2000
    BkSay("/b Zeit: " . (sec // 60) . " Minuten und " . Mod(sec, 60) . " Sekunden")
}

; ---------------------------------------------------------------------
;  Abfragen (Prompt) und /partner /kunde
; ---------------------------------------------------------------------
BkPromptLabels() {
    return {aim: "ID eingeben: ", zeit: "Gib die Zeit in Sekunden ein: ", conpreis: "Contractpreis festlegen: "
          , mms: "ID: ", setkills: "Kills: ", settode: "Tode: "}
}

BkFn_Prompt(b, args, inChat) {
    kind := b.text
    if (Trim(args) != "") {
        BkPrompt_Done(kind, Trim(args))
        return
    }
    BkPrompt_Start(kind, BkPromptLabels()[kind])
}

BkPrompt_Done(kind, input, data := "") {
    if (input = "")
        return
    if (kind = "aim") {
        BkStats_SetInfo("aimid", input)
        BkMsg("ID " . input . " für den Aimbottest eingetragen!", "ok")
    } else if (kind = "zeit") {
        s := input + 0
        BkSay(s . " Sekunden sind " . Floor(s / 60) . " Minuten und " . Mod(s, 60) . " Sekunden")
    } else if (kind = "conpreis") {
        BkStats_SetInfo("conpreis", input)
        BkMsg("Neuer Contractpreis liegt jetzt bei: $" . input, "ok")
    } else if (kind = "setkills" || kind = "settode") {
        if input is not integer
            return BkMsg("Bitte eine Zahl eingeben.", "warn")
        BkStats_SetTotal(kind = "setkills" ? "kills" : "tode", input)
        BkMsg((kind = "setkills" ? "Kills" : "Tode") . " auf " . input . " gesetzt.", "ok")
    } else if (kind = "mms") {
        t0 := A_TickCount
        BkSay("/number " . input)
        line := BkChat_WaitFor("i)Ph:\s*(\w+)", m, t0, 2500)
        if (line = "")
            return BkMsg("Keine Telefonnummer gefunden.", "warn")
        BkPrefill("/sms " . m1 . " ")
    } else if (SubStr(kind, 1, 6) = "idcap:") {
        BkIdCapture_Done(SubStr(kind, 7), data)
    } else if (SubStr(kind, 1, 9) = "enemyadd:") {
        BkEnemy_AddInput(SubStr(kind, 10), input)
    } else if (SubStr(kind, 1, 9) = "enemydel:") {
        BkEnemy_DelInput(SubStr(kind, 10), input)
    }
}

; /partner bzw. /kunde: "/id " vorbereiten, Name tippen, Enter -> der
; Server antwortet mit "ID: (12) Name, Level 5" - daraus wird gemerkt.
BkFn_IdCapture(b, args, inChat) {
    who := b.text
    if (Trim(args) != "") {
        t0 := A_TickCount
        if (inChat)
            BkChat_Close()
        BkRunLater(Func("BkIdCapture_Send").Bind(who, Trim(args)))
        return
    }
    BkPrompt_Start("idcap:" . who, "/id ", true, A_TickCount)
}

BkIdCapture_Send(who, name) {
    t0 := A_TickCount
    BkSay("/id " . name)
    BkIdCapture_Done(who, t0)
}

BkIdCapture_Done(who, since) {
    if (since = "")
        since := A_TickCount - 500
    line := BkChat_WaitFor("i)ID:\s*\((\d+)\)\s*([^,\s]+)", m, since - 300, 3000)
    if (line = "") {
        BkMsg("Spieler nicht gefunden.", "warn")
        return
    }
    BkStats_SetInfo(who, m1)
    BkStats_SetInfo(who . "name", m2)
    if (who = "partner")
        BkSay(BkFill("{fchat} Ich bin nun mit " . m2 . " unterwegs"))
    else
        BkSay(BkFill("{fchat} Kidnap-Opfer: " . m2))
}

; ---------------------------------------------------------------------
;  /map <Nr>
; ---------------------------------------------------------------------
BkFn_Map(b, args, inChat) {
    code := Trim(args)
    maps := BkMapDB()
    if (code = "" || !maps.HasKey(code)) {
        BkMsg("Unbekannter Gebäudekomplex. Beispiel: /map 1.1  (Liste im Keybinder unter Chat-Befehle)", "warn")
        return
    }
    BkSay("/me schaut auf seinen Stadtplan: Gebäudekomplex " . code)
    Sleep, % BK_LineDelay
    BkSay("- " . maps[code])
}

; ---------------------------------------------------------------------
;  Gegnerlisten im Chat: /<liste>, /<liste>add, /<liste>del
; ---------------------------------------------------------------------
BkFn_Enemy(b, args, inChat) {
    lst := b.text, mode := b.arg
    if (mode = "") {
        if (inChat)
            BkChat_Close()
        BkEnemy_ShowOnline(lst)
        return
    }
    if (Trim(args) != "") {
        if (inChat)
            BkChat_Close()
        if (mode = "add")
            BkEnemy_AddInput(lst, args)
        else
            BkEnemy_DelInput(lst, args)
        return
    }
    BkPrompt_Start("enemy" . mode . ":" . lst, (mode = "add") ? "/add " : "/del ")
}

BkFn_EnemyCheck(b, args, inChat) {
    BkEnemy_ShowOnline("*")
}

; ---------------------------------------------------------------------
;  Aufnahmen und Radio
; ---------------------------------------------------------------------
BkFn_SaveVideo(b, args, inChat) {
    BkVideo_Save(b.text)
}

BkFn_RadioStart(b, args, inChat) {
    BkRadio_Play()
}

BkFn_RadioStop(b, args, inChat) {
    BkRadio_Stop()
}
