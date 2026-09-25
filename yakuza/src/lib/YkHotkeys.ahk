; =====================================================================
;  HOTKEY-REGISTRIERUNG
; =====================================================================
; Duerfen die Aktions-Hotkeys gerade ausloesen? Solange der Chat offen
; ist NICHT - sonst wuerden Tasten, die als Hotkey belegt sind, beim
; Tippen verschluckt statt als Buchstabe im Chat zu landen.
;
; Wichtig: dafuer werden die Hotkeys tatsaechlich ab- und wieder
; angemeldet. Eine Kontext-Bedingung per Funktionsobjekt
; ("Hotkey, If, % fn") wertet AutoHotkey 1.1.22 nicht aus - die Funktion
; wird nie aufgerufen und der Hotkey feuert trotzdem. Ein abgeschalteter
; Hotkey dagegen laesst die Taste garantiert unveraendert durch.
; ---------------------------------------------------------------------
;  Chat-/Dialog-Waechter
; ---------------------------------------------------------------------
; Liest alle 30 ms direkt aus samp.dll, ob Chat oder ein Dialog offen ist
; (Login-Passwort, Eingabefenster, Listen), und legt die Hotkeys still
; bzw. schaltet sie wieder scharf. Die Chat-Taste T wird zusaetzlich
; ausgewertet, damit auch die ersten Millisekunden abgedeckt sind. Ist
; samp.dll nicht lesbar, bleibt es bei der Erkennung ueber die Tasten.
YkSampWatch() {
    global YK_MemEnabled, g_SampKnown, g_SampChat, g_ChatOpen, g_ChatKeyTick
    global g_LastKeyActivity, g_Sending, g_SendEndTick, YK_CrouchKey, g_CrouchT
    ; Ducken merken - automatische Meldungen warten dann kurz (C-Bug im Gefecht)
    if (YK_CrouchKey != "" && GetKeyState(YK_CrouchKey, "P"))
        g_CrouchT := A_TickCount
    if (!YK_MemEnabled) {
        g_SampKnown := false
        g_SampChat := false
        return
    }
    ; waehrend/kurz nach eigenem Senden nicht dazwischenfunken
    if (g_Sending || (A_TickCount - g_SendEndTick) < 150)
        return
    st := YkSamp_InputState(isChat)
    if (st = -1) {
        g_SampKnown := false
        g_SampChat := false
        return
    }
    g_SampKnown := true
    g_SampChat := (isChat = 1)
    if (st = 1) {
        g_LastKeyActivity := A_TickCount
        if (!g_ChatOpen) {
            g_ChatOpen := true
            YkKurz_Reset()
            YkApplyHotkeyState()
        }
    } else if (g_ChatOpen && (A_TickCount - g_ChatKeyTick) > 400) {
        g_ChatOpen := false
        YkKurz_Reset()
        g_Prompt := ""                  ; offene Abfrage ("Kills: ...") verwerfen
        YkApplyHotkeyState()
    }
}

; Frisch nachsehen: hat SA-MP gerade die Tastatur?
YkSampOpenNow() {
    global YK_MemEnabled
    if (!YK_MemEnabled)
        return false
    return (YkSamp_InputState(isChat) = 1)
}

; Letzte Absicherung beim Ausloesen eines Hotkeys: ist Chat oder Dialog
; offen, wird der Hotkey NICHT ausgefuehrt und die Taste unveraendert an
; das Textfeld weitergereicht. Deckt den seltenen Fall ab, dass eine
; Taste in genau den Millisekunden kommt, bevor der Waechter umschaltet.
YkInputBlocked() {
    global g_ChatOpen
    if (!g_ChatOpen && !YkSampOpenNow())
        return false
    YkPassThroughKey()
    return true
}

; Den ausloesenden Tastendruck als normale Taste nachreichen - nur ohne
; Strg/Alt/Win, denn solche Kombinationen ergeben ohnehin keinen Text.
YkPassThroughKey() {
    hk := A_ThisHotkey
    if RegExMatch(hk, "[\^!#]")
        return
    k := RegExReplace(hk, "^[~*$<>+]+", "")
    if (k = "" || InStr(k, " ") || InStr(k, "&"))
        return
    SendInput, % "{Blind}{" . k . "}"
}

YkHotkeysWanted() {
    global YK_Paused, g_ChatOpen
    return (!YK_Paused && !g_ChatOpen)
}

; Alle Aktions-Hotkeys scharf schalten oder stilllegen. Muss im selben
; Kontext geschehen, in dem sie angelegt wurden.
YkSetActionHotkeys(on) {
    global YK_ActiveHotkeys, YK_HkOn
    Hotkey, IfWinActive, ahk_group YkGame
    for i, hk in YK_ActiveHotkeys {
        try Hotkey, % hk, % (on ? "On" : "Off")
    }
    Hotkey, IfWinActive
    YK_HkOn := (on ? true : false)
}

; Zustand nachziehen - wird bei jeder Chat-Aenderung sofort und
; zusaetzlich im Takt gerufen.
;
; Grundregel: Auf einer Taste darf nie mehr als EIN Hotkey gleichzeitig
; aktiv sein. Liegen zwei auf derselben Taste (z.B. die Chat-Taste ~*t
; und der Kurzform-Beobachter ~*vk54), feuert nur einer - und welcher,
; kippt, sobald Hotkeys aus- und wieder eingeschaltet werden. Genau so
; ging "Chat offen" verloren: T landete beim Kurzform-Beobachter, der
; Buchstaben-Hotkey danach feuerte mitten ins Tippen.
; Deshalb zwei getrennte Saetze, die sich nie ueberschneiden:
;   Chat zu    -> Aktions-Hotkeys + Chat-Taste an, Kurzform-Beobachter aus
;   Chat offen -> Aktions-Hotkeys + Chat-Taste aus, Kurzform-Beobachter an
; Die Reihenfolge ist wichtig: immer erst ausschalten, dann einschalten.
YkApplyHotkeyState() {
    global YK_HkOn, YK_ChatMode, g_ChatOpen
    ; Nicht unterbrechbar: Chat-Taste und 30-ms-Waechter rufen das aus
    ; verschiedenen Threads. Das An-/Abmelden vieler Hotkeys dauert ein
    ; paar Millisekunden - ohne Critical konnte ein zweiter Thread mitten
    ; hinein umschalten und einen halb umgeschalteten Zustand hinterlassen.
    Critical
    want := YkHotkeysWanted()
    open := g_ChatOpen ? true : false
    if (open) {
        if (want != YK_HkOn)
            YkSetActionHotkeys(want)
        if (YK_ChatMode != open)
            YkSetChatMode(open)
    } else {
        if (YK_ChatMode != open)
            YkSetChatMode(open)
        if (want != YK_HkOn)
            YkSetActionHotkeys(want)
    }
    Critical, Off
}

; Chat-Taste und Kurzform-Beobachter gegeneinander umschalten.
YkSetChatMode(open) {
    global YK_ChatMode, YK_ChatClosedHks, YK_KurzHkList, YK_ChatEnterHks
    YkDbg("Chat-Modus " . (open ? "OFFEN" : "zu") . " (" . YK_KurzHkList.Length() . " Beobachter, " . YK_ChatEnterHks.Length() . " Enter, " . YK_ChatClosedHks.Length() . " zu)")
    if (open) {
        Hotkey, IfWinActive, ahk_group YkGame
        for i, hk in YK_ChatClosedHks
            try Hotkey, % hk, Off
        Hotkey, IfWinActive
        for i, hk in YK_KurzHkList
            try Hotkey, % hk, On
        Hotkey, IfWinActive, ahk_group YkGame
        for i, hk in YK_ChatEnterHks
            try Hotkey, % hk, On
        Hotkey, IfWinActive
    } else {
        Hotkey, IfWinActive, ahk_group YkGame
        for i, hk in YK_ChatEnterHks
            try Hotkey, % hk, Off
        Hotkey, IfWinActive
        for i, hk in YK_KurzHkList
            try Hotkey, % hk, Off
        Hotkey, IfWinActive, ahk_group YkGame
        for i, hk in YK_ChatClosedHks
            try Hotkey, % hk, On
        Hotkey, IfWinActive
    }
    YK_ChatMode := open
}

YkRegisterAllHotkeys() {
    global YK_ActiveHotkeys, YK_ActiveChatHotkeys, YK_HkOn
    global YK_Binds, YK_LocHotkey, YK_FamHotkey, YK_KillHotkey
    global YK_SprintToggleHk, YK_ChatKey, YK_KillEnabled, YK_CombatEnabled
    global YK_CmdBinds, YK_FnKeys, YK_TbKeys, YK_PauseHkReg, YK_ChatClosedHks, g_HkSeen, g_HkConflicts

    ; bestehende Aktions-Hotkeys abmelden (im GLEICHEN Kontext, in dem
    ; sie angelegt wurden - sonst werden sie nicht gefunden)
    Hotkey, IfWinActive, ahk_group YkGame
    for i, hk in YK_ActiveHotkeys {
        try Hotkey, % hk, Off
    }
    Hotkey, IfWinActive
    YK_ActiveHotkeys := []

    ; bestehende Chat-Verfolgungs-Hotkeys abmelden
    Hotkey, IfWinActive, ahk_group YkGame
    for i, hk in YK_ActiveChatHotkeys {
        try Hotkey, % hk, Off
    }
    Hotkey, IfWinActive
    YK_ActiveChatHotkeys := []

    ; ---- Aktions-Hotkeys: wirken nur im Spiel und werden bei offenem
    ;      Chat komplett stillgelegt. Doppelt belegte Tasten werden
    ;      erkannt: die erste Belegung gewinnt, es gibt einen Hinweis. ----
    Hotkey, IfWinActive, ahk_group YkGame
    YkHk_Begin()
    YkHk_Register(YK_LocHotkey, Func("YkAction_Location"), "Standort senden")
    if (YK_CombatEnabled && YK_KillEnabled)
        YkHk_Register(YK_KillHotkey, Func("YkAction_KillManual"), "Kill melden")
    YkHk_Register(YK_FamHotkey, Func("YkAction_FamilyMap"), "/familymap")
    YkHk_Register(YK_SprintToggleHk, Func("YkSprint_Toggle"), "Sprint an/aus")
    YkHk_Register(YK_OvHotkey, Func("YkAction_ToggleOverlay"), "Overlay an/aus")
    YkHk_Register(YK_MemHotkey, Func("YkAction_ToggleMembers"), "Member-Positionen")
    for i, b in YK_Binds
        YkHk_Register(b.key, Func("YkBind_Fire").Bind(b.cmd, b.enter, b.exHp, b.exArmor, b.exLoc, b.exVeh), "Keybind " . YkShorten(b.cmd, 24))
    for ck, sb in YK_CmdBinds
        YkHk_Register(sb.hk, Func("YkBind_Fire").Bind(ck, (sb.enter ? true : false), sb.exHp, sb.exArmor, sb.exLoc, sb.exVeh), ck)
    ; Funktionstasten aus v3.0 (Fenster, Tasten loesen, Gruss, Countdown ...)
    for i, f in YkFnKeys() {
        if (f.id = "pause")
            continue
        YkHk_Register(YK_FnKeys[f.id], Func("YkFnKey_Fire").Bind(f.id), f.label)
    }
    ; Chat-Befehle, die zusaetzlich auf einer Taste liegen (z.B. /kd)
    for cmd, k in YK_TbKeys
        YkHk_Register(k, Func("YkTb_FireKey").Bind(cmd), cmd)

    ; Pause-Taste extra: muss auch im pausierten Zustand wirken, wird
    ; deshalb nie mit den anderen stillgelegt
    if (YK_PauseHkReg != "")
        try Hotkey, % YK_PauseHkReg, Off
    YK_PauseHkReg := ""
    pk := YK_FnKeys["pause"]
    if (pk != "") {
        if (g_HkSeen.HasKey(pk) || pk = YK_ChatKey) {
            g_HkConflicts .= "`n" . YkHotkeyName(pk) . ": " . (g_HkSeen.HasKey(pk) ? g_HkSeen[pk] : "Chat-Taste") . "  und  Pause"
        } else {
            try {
                Hotkey, % pk, YkPauseHotkey, On
                YK_PauseHkReg := pk
                g_HkSeen[pk] := "Pause"
            }
        }
    }

    Hotkey, IfWinActive     ; Aktions-Kontext verlassen
    YK_HkOn := true

    ; ---- Chat-Verfolgung: muss AUCH bei offenem Chat feuern, damit
    ;      das Schliessen ueberhaupt erkannt wird ----
    Hotkey, IfWinActive, ahk_group YkGame
    fnOpen := Func("YkChatKeyDown")
    fnEnter := Func("YkChatEnterOrEscape").Bind(false)
    fnEscape := Func("YkChatEnterOrEscape").Bind(true)
    ; Nur bei geschlossenem Chat: die Chat-Taste und - fuer den Fall, dass
    ; samp.dll nicht lesbar ist - das Loslassen von Enter (Enter oeffnet
    ; in SA-MP ebenfalls den Chat). Bei offenem Chat liegt auf Enter
    ; stattdessen YkChatEnter (Chat-Befehle). Nie zwei Hotkeys zugleich
    ; auf einer Taste.
    YK_ChatClosedHks := []
    for i, pair in [["~*" . YK_ChatKey, fnOpen], ["~*Enter up", fnEnter], ["~*NumpadEnter up", fnEnter]] {
        ; Funktionsobjekte nimmt der Hotkey-Befehl nur ueber eine Variable an
        lbl := pair[2]
        try {
            Hotkey, % pair[1], % lbl, On
            YK_ActiveChatHotkeys.Push(pair[1])
            YK_ChatClosedHks.Push(pair[1])
        } catch e {
            YkDbg("Hotkey " . pair[1] . " geht nicht: " . e.Message . " " . e.Extra)
        }
    }
    YK_ChatOpenHk := "~*" . YK_ChatKey
    try {
        Hotkey, ~*Escape, % fnEscape, On
        YK_ActiveChatHotkeys.Push("~*Escape")
    }

    Hotkey, IfWinActive

    YkSprint_Register()
    YkKurz_Register()
    YkBlock_Register()

    ; Die Chat-Taste wurde eben neu (eingeschaltet) angelegt - den
    ; Chat-Satz deshalb in jedem Fall neu setzen, damit Chat-Taste und
    ; Kurzform-Beobachter nie gleichzeitig aktiv sind.
    YK_ChatMode := -1
    ; Ist gerade der Chat offen oder der Binder pausiert: sofort stilllegen
    YkApplyHotkeyState()
    YkHk_Report()
}

YkChatKeyDown() {
    global g_ChatOpen, g_Sending, g_LastKeyActivity, g_ChatKeyTick
    YkDbg("Chat-Taste (offen=" . g_ChatOpen . ", sendet=" . g_Sending . ")")
    g_LastKeyActivity := A_TickCount
    g_ChatKeyTick := A_TickCount
    if (g_Sending)
        return
    if (!g_ChatOpen) {
        g_ChatOpen := true
        YkKurz_Reset()
        YkApplyHotkeyState()
    }
}

; Enter/NumpadEnter oeffnen den (leeren) Chat, wenn er noch zu war -
; genau wie in SA-MP ueblich - und schliessen ihn (Nachricht abgeschickt),
; wenn er schon offen war. Escape schliesst immer (Nachricht verworfen).
; Dadurch wird "Chat ist offen" auch dann korrekt erkannt, wenn jemand
; den Chat per Enter statt per Chat-Taste oeffnet.
YkChatEnterOrEscape(isEscape) {
    global g_ChatOpen, g_Sending, g_LastKeyActivity, g_SampKnown, g_Prompt, g_EnterPassT
    g_LastKeyActivity := A_TickCount
    if (isEscape)
        g_Prompt := ""
    if (g_Sending)
        return
    ; Loslassen genau des Enters, das der Binder eben selbst behandelt hat
    ; (Chat-Befehl, abgeschickte Zeile) - das oeffnet keinen neuen Chat
    if (!isEscape && (A_TickCount - g_EnterPassT) < 1500)
        return
    ; Ist der Zustand aus samp.dll lesbar, entscheidet allein der. Enter
    ; dient im Spiel auch zum Ein-/Aussteigen - blindes Umschalten per
    ; Enter konnte die Erkennung sonst aus dem Takt bringen.
    if (g_SampKnown)
        return
    if (isEscape) {
        g_ChatOpen := false
        YkKurz_Reset()
        YkApplyHotkeyState()
        return
    }
    g_ChatOpen := !g_ChatOpen
    YkKurz_Reset()
    YkApplyHotkeyState()
}

; Pause-Taste: wirkt auch pausiert, aber nie bei offenem Chat
YkPauseHotkey() {
    global g_ChatOpen
    if (g_ChatOpen || YkSampOpenNow()) {
        YkPassThroughKey()
        return
    }
    YkTogglePause()
}
