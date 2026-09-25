; =====================================================================
;  BEFEHLE IN DEN CHAT SENDEN (reiner Tastensender)
; =====================================================================
; Liefert true, wenn der Text abgeschickt (bzw. eingetragen) wurde.
YkSendCmd(text, sendEnter := true) {
    global YK_ChatKey, YK_SendDelay, YK_Paused, g_Sending, g_ChatOpen, g_SendEndTick, YK_FastSend, YK_MemEnabled
    global YK_SendWaitMs, g_SendDeadline
    if (YK_Paused || g_Sending)
        return false
    text := "" . text
    if (text = "")
        return false
    if (!YkGame_Active())
        return false

    ; eigene Nachricht merken - daran erkennt der Binder im Chatlog den
    ; eigenen Namen (Member-Liste, Hilfe-Rufe, Kill-Erkennung)
    YkOwnMsg_Remember(text)

    chatVk := GetKeyVK(YK_ChatKey)
    if (!chatVk)
        return false
    g_Sending := true
    ; ab hier laeuft die Uhr: alle Warteschritte zusammen duerfen nur so
    ; lange dauern (siehe YkWait_Left)
    g_SendDeadline := A_TickCount + YK_SendWaitMs
    ; 0) fuer die ~0,1 s des Sendens Buchstaben/Ziffern sperren - sonst
    ;    rutschen W/A/S/D vom Laufen in den Befehl (Loslassen geht durch)
    YkBlock(true)
    ; schneller Weg: Chat in keinem Spielbild offen - die Figur laeuft weiter
    if (sendEnter && YK_FastSend && YK_SendDelay <= 0 && YK_MemEnabled) {
        r := YkSendFast(text)
        Critical, Off
        if (r >= 0) {
            YkBlock_Pump()
            YkBlock(false)
            g_ChatOpen := false
            g_Sending := false
            g_SendEndTick := A_TickCount
            YkApplyHotkeyState()
            YkBlock_Replay()
            return (r = 1)
        }
    }
    ; 1) Chat oeffnen. Gehaltene Strg/Alt/Shift (z.B. vom Hotkey Strg+Num1)
    ;    im selben Paket loesen, sonst verfaelschen sie Chat-Taste und Text.
    YkKey_ReleaseMods()
    YkKey_Tap(chatVk, GetKeySC(YK_ChatKey))
    ; 2) warten, bis SA-MP die Eingabe wirklich offen hat (meist 1 Frame).
    ;    Geht der Chat nicht auf, wird NICHTS getippt - sonst kaemen die
    ;    Buchstaben als Spieltasten an und Enter wuerde z.B. aussteigen.
    if (!YkWaitChatOpen()) {
        YkBlock_Pump()
        YkBlock(false)
        g_Sending := false
        g_SendEndTick := A_TickCount
        YkApplyHotkeyState()
        YkBlock_Replay()
        return false
    }
    ; 3) Text und Enter in EINEM Paket. Frueher lagen zwischen Chat-Taste,
    ;    Text und Enter ueber 100 ms Pause: Wer dabei lief oder fuhr und
    ;    W/A/S/D drueckte, tippte diese Buchstaben mitten in den Befehl -
    ;    der Server kannte ihn dann nicht, und so lange stand die Figur.
    ;    Die Ruecktasten vorneweg loeschen, was bis zum Oeffnen evtl. schon
    ;    ins Feld gerutscht ist.
    if (YK_SendDelay > 0) {
        ; Kompatibilitaets-Modus: zeichenweise mit Verzoegerung
        SendInput, {BS 12}
        prevDelay := A_KeyDelay
        SetKeyDelay, % YK_SendDelay, % YK_SendDelay
        SendEvent, % YkSendEscape(text)
        SetKeyDelay, % prevDelay
        if (sendEnter)
            SendInput, {Enter}
    } else {
        ; am Stueck, ohne dass ein Timer dazwischenfunkt - jede Unterbrechung
        ; haelt den Chat laenger offen (die Figur steht so lange)
        Critical
        YkKey_ReleaseMods()              ; Strg evtl. per Tastenwiederholung wieder unten
        Loop, 12
            YkKey_Tap(0x08, 0x0E)
        YkKey_Text(text)
        if (sendEnter)
            YkKey_Tap(0x0D, 0x1C)
        Critical, Off
    }
    YkBlock_Pump()
    YkBlock(false)
    g_ChatOpen := sendEnter ? false : true
    g_Sending := false
    g_SendEndTick := A_TickCount
    YkApplyHotkeyState()
    ; waehrend des Sendens gedrueckte Tasten (z.B. C zum Ducken) nachreichen
    if (sendEnter)
        YkBlock_Replay()
    else
        g_BlockReplay := []
    return true
}

; true, sobald die Chat-Eingabe offen ist. Ohne lesbaren SA-MP-Zustand
; (andere Version, Spielspeicher aus) wird wie frueher kurz gewartet.
YkWaitChatOpen() {
    global YK_MemEnabled
    if (!YK_MemEnabled || YkSamp_InputState(ic) = -1) {
        DllCall("Sleep", "UInt", YkWait_Left(60))
        return true
    }
    limit := YkWait_Left(500)
    t0 := A_TickCount
    Loop {
        if (YkSamp_InputState(ic) = 1 && ic = 1)
            return true
        if ((A_TickCount - t0) > limit)
            return false
        DllCall("Sleep", "UInt", 1)
    }
}

; ---------------------------------------------------------------------
;  Schnell senden: Chat-Taste, Text und Enter als Fenster-Nachrichten
; ---------------------------------------------------------------------
; Solange der Chat offen ist, schaltet SA-MP die Tastatur-Abfrage von GTA
; ab (samp.dll ueberschreibt dafuer den Aufruf bei 0x541DF5). In jedem
; Spielbild mit offenem Chat "drueckt" die Figur also keine Taste: wer
; laeuft, bleibt stehen und braucht ueber eine Sekunde, um wieder
; loszulaufen (live gemessen). Per Tastenereignis war der Chat 3-6 Bilder
; offen, weil jede Taste einzeln durch alle Tastatur-Hooks laeuft.
; Fenster-Nachrichten (wie ControlSend) liegen dagegen VOR jeder echten
; Taste in der Warteschlange - das Spiel arbeitet Oeffnen, Text und Enter
; in einem Durchgang ab, ohne dazwischen ein Bild zu berechnen.
; Ob SA-MP das annimmt, wird beim ersten Mal geprueft: Chat geht auf, die
; Zeile steht danach im Verlauf. Enter wird zuerst nur als Zeichen probiert
; (das kaeme nie als Spieltaste an), sonst als Taste. Klappt es dreimal
; nicht, bleibt es bis zum naechsten Spielstart beim alten Weg.
; Rueckgabe: 1 gesendet, 0 nicht gesendet, -1 = auf dem alten Weg senden
YkSendFast(text) {
    global YK_ChatKey, YK_dwPID, g_FastMode, g_FastTries, g_FastPid, g_FastOpen
    if (g_FastPid != YK_dwPID) {
        g_FastPid := YK_dwPID
        g_FastMode := ""
        g_FastTries := 0
        g_FastOpen := ""
    }
    hwnd := YkGame_Active()
    if (!hwnd || g_FastMode = "no")
        return -1
    if (YkSamp_InputState(ic) != 0 || !YkSamp_LastInput(before, beforeSig) || YkMem_MenuActive())
        return -1
    vk := GetKeyVK(YK_ChatKey)
    sc := GetKeySC(YK_ChatKey) & 0xFF
    ch := DllCall("MapVirtualKey", "UInt", vk, "UInt", 2, "UInt") & 0xFFFF
    if (ch)
        ch := Asc(Format("{:L}", Chr(ch)))
    ; gehaltenes Strg/Alt/Shift (Hotkey Strg+G) vorher loslassen - das
    ; Spiel sieht das Loslassen erst nach einem Durchgang, der Chat ist da
    ; noch zu
    if (YkKey_ReleaseMods())
        DllCall("Sleep", "UInt", 35)
    sent := ""
    Loop, Parse, text
        if (A_LoopField != "`r" && A_LoopField != "`n")
            sent .= A_LoopField
    sent := SubStr(sent, 1, 128)
    known := (g_FastMode = "char" || g_FastMode = "key")
    ; SA-MP oeffnet den Chat beim ZEICHEN "t" (samp.dll vergleicht das
    ; Zeichen mit 'T', 't' und '`'). Deshalb kein "Druecken" der Taste - aus
    ; einem geposteten Druecken macht das Spiel selbst noch ein zweites "t",
    ; das mitten im Text landen koennte.
    if (known && g_FastOpen = "char") {
        ; bestaetigter Weg: alles in EINEM Zug - kein Timer darf dazwischen,
        ; sonst arbeitet das Spiel die Nachrichten in mehreren Durchgaengen ab
        Critical
        YkPost(hwnd, 0x102, ch, 1 | (sc << 16))
        YkPost_Text(hwnd, sent)
        YkPost_Enter(hwnd, g_FastMode)
        Critical, Off
        if YkSendFast_Confirm(sent, beforeSig, 500)
            return 1
        return YkSendFast_Failed(sent, beforeSig)
    }
    ; erstes Mal (oder Chat geht nur per Druecken auf): oeffnen und warten -
    ; geht er nicht auf, landet kein Text im Spiel
    if !YkSendFast_Open(hwnd, vk, sc, ch) {
        g_FastTries += 1
        g_FastMode := (g_FastTries >= 3) ? "no" : ""
        return -1
    }
    Critical
    YkPost_Text(hwnd, sent)
    if (known) {
        YkPost_Enter(hwnd, g_FastMode)
        Critical, Off
        if YkSendFast_Confirm(sent, beforeSig, 500)
            return 1
        return YkSendFast_Failed(sent, beforeSig)
    }
    ; Enter zuerst nur als Zeichen - das erreicht das Spiel nie als Taste
    YkPost_Enter(hwnd, "char")
    Critical, Off
    if YkSendFast_Confirm(sent, beforeSig, 250) {
        g_FastMode := "char"
        return 1
    }
    if (YkSamp_InputState(ic) = 1 && ic = 1) {
        YkPost_Enter(hwnd, "key")
        if YkSendFast_Confirm(sent, beforeSig, 400) {
            g_FastMode := "key"
            return 1
        }
    }
    g_FastTries += 1
    g_FastMode := (g_FastTries >= 3) ? "no" : ""
    return YkSendFast_Failed(sent, beforeSig)
}

; Chat per Nachricht oeffnen und warten, bis SA-MP ihn offen hat. Zuerst
; nur das Zeichen; geht er so nicht auf, Druecken und Loslassen (dann macht
; das Spiel das Zeichen selbst - die Ruecktasten vor dem Text loeschen es).
YkSendFast_Open(hwnd, vk, sc, ch) {
    global g_FastOpen
    if (g_FastOpen != "down" && ch) {
        YkPost(hwnd, 0x102, ch, 1 | (sc << 16))
        if YkSendFast_WaitOpen(300) {
            g_FastOpen := "char"
            return true
        }
        if (g_FastOpen = "char")
            return false
    }
    YkPost(hwnd, 0x100, vk, 1 | (sc << 16))
    YkPost(hwnd, 0x101, vk, 0xC0000001 | (sc << 16))
    if YkSendFast_WaitOpen(400) {
        g_FastOpen := "down"
        return true
    }
    return false
}

YkSendFast_WaitOpen(ms) {
    ms := YkWait_Left(ms)
    t0 := A_TickCount
    Loop {
        if (YkSamp_InputState(ic) = 1 && ic = 1)
            return true
        if ((A_TickCount - t0) > ms)
            return false
        DllCall("Sleep", "UInt", 1)
    }
}

; Senden nicht bestaetigt. Offener Chat: verwerfen (Escape) und schliessen.
; Steht trotzdem etwas Neues im Verlauf, wurde gesendet - dann nicht noch
; einmal (sonst kaeme die Meldung doppelt). Sonst: alter Weg.
YkSendFast_Failed(sent, beforeSig) {
    global g_FastMode
    if (g_FastMode = "char" || g_FastMode = "key")
        g_FastMode := ""                       ; beim naechsten Mal neu pruefen
    if (YkSamp_InputState(ic) = 1 && ic = 1) {
        YkKey_Tap(0x1B, 0x01)
        ; Aufraeumen darf nie am Budget scheitern: sonst bliebe der Chat
        ; offen stehen. Es bekommt ein eigenes, kurzes Limit.
        t0 := A_TickCount
        while (YkSampOpenNow() && (A_TickCount - t0) < 150)
            DllCall("Sleep", "UInt", 5)
        if YkSampOpenNow()
            return 0
    }
    if (YkSamp_LastInput(last, sig) && !(sig == beforeSig))
        return 1
    return -1
}

; zwei Ruecktasten (falls schon ein Zeichen im Chat steht), dann der Text
YkPost_Text(hwnd, sent) {
    YkPost(hwnd, 0x102, 8, 0x0E0001)
    YkPost(hwnd, 0x102, 8, 0x0E0001)
    Loop, Parse, sent
        YkPost(hwnd, 0x102, Asc(A_LoopField), 1)
}

; Chat zu, die Zeile steht vorne im Verlauf und der Verlauf hat sich
; geaendert (sonst kaeme ein zweites Senden desselben Textes falsch durch)?
YkSendFast_Confirm(sent, beforeSig,ms) {
    ms := YkWait_Left(ms)
    t0 := A_TickCount
    Loop {
        if (YkSamp_InputState(ic) = 0 && YkSamp_LastInput(last, sig) && Trim(last) == Trim(sent) && !(sig == beforeSig))
            return true
        if ((A_TickCount - t0) > ms)
            return false
        DllCall("Sleep", "UInt", 1)
    }
}

YkPost(hwnd, msg, wp, lp) {
    static fn := 0
    if (!fn)
        fn := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32", "Ptr"), "AStr", "PostMessageW", "Ptr")
    DllCall(fn, "Ptr", hwnd, "UInt", msg, "UPtr", wp, "UPtr", lp & 0xFFFFFFFF)
}

; Enter als Zeichen (erreicht das Spiel nie als Taste) oder als Taste
YkPost_Enter(hwnd, mode) {
    if (mode = "key")
        YkPost(hwnd, 0x100, 0x0D, 0x1C0001)
    YkPost(hwnd, 0x102, 13, 0x1C0001)
    if (mode = "key")
        YkPost(hwnd, 0x101, 0x0D, 0xC01C0001)
}

; ---------------------------------------------------------------------
;  Tasten ohne Pausen einspeisen (keybd_event)
; ---------------------------------------------------------------------
; AutoHotkeys SendInput weicht still auf SendEvent mit 10 ms je Taste aus,
; sobald ein anderes AutoHotkey-Programm mit Tastatur-Hook laeuft. Dann
; wird sichtbar Zeichen fuer Zeichen getippt, gedrueckte Tasten (Laufen,
; Strg vom Hotkey) mischen sich hinein - bei Strg-Hotkeys ging so das
; Enter verloren. Das reine Windows-SendInput kam im Test gar nicht an.
; Deshalb: Chat-Taste, Ruecktasten und Enter direkt per keybd_event, der
; Text ohne jede Verzoegerung, gehaltene Umschalttasten vorher gezielt los.
; Die Kennung ist dieselbe wie bei AutoHotkeys eigenem Send - so loesen
; die eigenen Hotkeys (und die anderer AutoHotkey-Programme) nicht aus.
YkKey_Tap(vk, sc, ext := 0) {
    static SEND_MARK := 0xFFC3D44D
    DllCall("keybd_event", "UChar", vk, "UChar", sc, "UInt", ext ? 1 : 0, "UPtr", SEND_MARK)
    DllCall("keybd_event", "UChar", vk, "UChar", sc, "UInt", (ext ? 1 : 0) | 2, "UPtr", SEND_MARK)
}

YkKey_Down(vk, sc) {
    DllCall("keybd_event", "UChar", vk, "UChar", sc, "UInt", 0, "UPtr", 0xFFC3D44D)
}

YkKey_Up(vk, sc) {
    DllCall("keybd_event", "UChar", vk, "UChar", sc, "UInt", 2, "UPtr", 0xFFC3D44D)
}

; gerade gedrueckte Umschalttasten loslassen - liefert die Anzahl
YkKey_ReleaseMods() {
    static SEND_MARK := 0xFFC3D44D
    static mods := [["LCtrl", 0xA2, 0x1D, 0], ["RCtrl", 0xA3, 0x1D, 1], ["LShift", 0xA0, 0x2A, 0]
                  , ["RShift", 0xA1, 0x36, 0], ["LAlt", 0xA4, 0x38, 0], ["RAlt", 0xA5, 0x38, 1]]
    n := 0
    for i, m in mods {
        if GetKeyState(m[1]) {
            DllCall("keybd_event", "UChar", m[2], "UChar", m[3], "UInt", (m[4] ? 1 : 0) | 2, "UPtr", SEND_MARK)
            n += 1
        }
    }
    return n
}

; Text Zeichen fuer Zeichen direkt per keybd_event tippen - nach dem
; Tastaturlayout des Spiels (deutsch: / = Shift+7, @ = AltGr+Q). Das ist
; in 1-2 ms durch; AutoHotkeys Send wartet dagegen nach jeder Taste auf
; den eigenen Hook, und in diesen ~70 ms mischten sich beim Laufen W/A/D
; in den Befehl. Zeichen, die das Layout nicht kennt, gehen ueber Send.
YkKey_Text(text) {
    static SEND_MARK := 0xFFC3D44D
    tid := DllCall("GetWindowThreadProcessId", "Ptr", WinExist("A"), "Ptr", 0, "UInt")
    hkl := DllCall("GetKeyboardLayout", "UInt", tid, "Ptr")
    Loop, % StrLen(text) {
        ch := NumGet(text, (A_Index - 1) * 2, "UShort")
        if (ch = 10 || ch = 13)
            continue
        vks := DllCall("VkKeyScanExW", "UShort", ch, "Ptr", hkl, "Short")
        if (vks = -1) {
            SendEvent, % "{Blind}{U+" . Format("{:04X}", ch) . "}"
            continue
        }
        vk := vks & 0xFF
        sh := (vks >> 8) & 0xFF                       ; 1 Shift, 2 Strg, 4 Alt
        sc := DllCall("MapVirtualKeyExW", "UInt", vk, "UInt", 0, "Ptr", hkl, "UInt")
        dead := DllCall("MapVirtualKeyExW", "UInt", vk, "UInt", 2, "Ptr", hkl, "UInt") & 0x80000000
        if (sh & 2)
            DllCall("keybd_event", "UChar", 0xA2, "UChar", 0x1D, "UInt", 0, "UPtr", SEND_MARK)
        if (sh & 4)
            DllCall("keybd_event", "UChar", 0xA5, "UChar", 0x38, "UInt", 1, "UPtr", SEND_MARK)
        if (sh & 1)
            DllCall("keybd_event", "UChar", 0xA0, "UChar", 0x2A, "UInt", 0, "UPtr", SEND_MARK)
        DllCall("keybd_event", "UChar", vk, "UChar", sc, "UInt", 0, "UPtr", SEND_MARK)
        DllCall("keybd_event", "UChar", vk, "UChar", sc, "UInt", 2, "UPtr", SEND_MARK)
        if (sh & 1)
            DllCall("keybd_event", "UChar", 0xA0, "UChar", 0x2A, "UInt", 2, "UPtr", SEND_MARK)
        if (sh & 4)
            DllCall("keybd_event", "UChar", 0xA5, "UChar", 0x38, "UInt", 3, "UPtr", SEND_MARK)
        if (sh & 2)
            DllCall("keybd_event", "UChar", 0xA2, "UChar", 0x1D, "UInt", 2, "UPtr", SEND_MARK)
        ; Tottaste (^ ` ´): mit Leertaste abschliessen, damit das Zeichen selbst erscheint
        if (dead)
            YkKey_Tap(0x20, 0x39)
    }
}

; ---------------------------------------------------------------------
;  Tastensperre waehrend des Sendens
; ---------------------------------------------------------------------
; Eigene, sonst ausgeschaltete Hotkeys auf Buchstaben, Ziffern, Leertaste
; und Satzzeichen. Nur waehrend des Sendens an: der physische Tastendruck
; wird verschluckt, das Loslassen geht durch (die Figur laeuft also nicht
; ungewollt weiter). Die eigenen gesendeten Zeichen tragen die Kennung von
; AutoHotkey und werden davon nicht erfasst.
; Verschluckte Tasten bekommt das Spiel nach dem Senden nachgereicht - wer
; genau in diesen ~0,1 s C (Ducken) drueckt, verliert den Druck nicht mehr.
; Ueber Scancodes angelegt (*scXXX): so kollidieren sie nicht mit den
; Kurzform-Beobachtern (~*vkXX). Tasten mit eigenem Hotkey bleiben aussen vor.
; Die Sperre der Ducken-Taste dient ausserdem beim Sprint-Tippen (YkSprint_Crouch).
YkBlock_Register() {
    global YK_BlockHks, YK_ChatKey, YK_CrouchKey, YK_CrouchHk, YK_CrouchSc, YK_MoveKeysArr
    Hotkey, IfWinActive
    for i, hk in YK_BlockHks
        try Hotkey, %hk%, Off
    YK_BlockHks := []
    YK_CrouchHk := ""
    YK_CrouchSc := GetKeySC(YK_CrouchKey)
    used := {}
    for k, id in YkHk_Owners() {
        YkHk_Split(k, ms, kk)
        vk := GetKeyVK(kk)
        if (vk)
            used[vk] := 1
    }
    used[GetKeyVK(YK_ChatKey)] := 1
    ; Frueher wurden hier ALLE Buchstaben, Ziffern und Satzzeichen gesperrt
    ; - rund 50 Hotkeys, die bei JEDEM Senden ein- und wieder ausgeschaltet
    ; wurden. Das kostete bei jedem Tastendruck spuerbar Zeit, obwohl nur
    ; die Tasten stoeren koennen, die man beim Laufen und Fahren wirklich
    ; gedrueckt haelt. Gesperrt wird deshalb nur noch:
    ;   Bewegungstasten (aus den Sprint-Einstellungen), Leertaste, Ducken,
    ;   die ueblichen Fahr-/Kampftasten und die Pfeiltasten.
    ; Nur Tasten, die im Chat auch wirklich einen Buchstaben erzeugen -
    ; Pfeiltasten z.B. bewegen dort nur den Schreibzeiger und stoeren nicht.
    want := ["Space"]
    for i, k in YK_MoveKeysArr
        want.Push(k)
    for i, k in ["w", "a", "s", "d", "q", "e", "f", "c", "x", "y", "z", "h", "n", "1", "2"]
        want.Push(k)
    want.Push(YK_CrouchKey)
    vks := [], seen := {}
    for i, k in want {
        vk := GetKeyVK(k)
        ; Pfeil-/Steuertasten (kein Zeichen) und Doppelte weglassen
        if (!vk || seen.HasKey(vk))
            continue
        if !(DllCall("MapVirtualKey", "UInt", vk, "UInt", 2, "UInt") & 0xFFFF)
            continue
        seen[vk] := 1
        vks.Push(vk)
    }
    fn := Func("YkBlock_Nop")
    for i, vk in vks {
        if used.HasKey(vk)
            continue
        sc := DllCall("MapVirtualKey", "UInt", vk, "UInt", 0, "UInt")
        if (!sc)
            continue
        hk := "*sc" . Format("{:03X}", sc)
        try {
            ; "B" = puffern: auch wenn noch ein Sperr-Thread derselben Taste
            ; laeuft, wird der naechste Druck verschluckt statt durchgelassen
            ; (sonst rutschte z.B. ein "d" vom Laufen in den Befehl)
            Hotkey, %hk%, % fn, Off B
            YK_BlockHks.Push(hk)
            if (sc = YK_CrouchSc)
                YK_CrouchHk := hk
        }
    }
}

; Tastendruck waehrend der Sperre: beim Sprint-Tippen ist es das Ducken,
; sonst wird die Taste gemerkt und nach dem Senden nachgereicht
YkBlock_Nop() {
    global g_Sending, g_BlockReplay, YK_SprintMode, YK_CrouchHk
    hk := A_ThisHotkey
    if (!g_Sending && hk = YK_CrouchHk && YK_SprintMode = "tapping") {
        YkSprint_Crouch()
        return
    }
    ; Scancode aus dem Hotkey-Namen ("*sc02E" -> 0x2E)
    sc := GetKeySC(RegExReplace(hk, "^[*~$]+"))
    if (!sc)
        return
    for i, v in g_BlockReplay
        if (v = sc)
            return
    g_BlockReplay.Push(sc)
    if (!g_Sending)
        YkBlock_Replay()
}

; Jeder verschluckte Tastendruck meldet sich als eigener Hotkey-Thread. Der
; muss laufen, SOLANGE die Sperre noch an ist - ist sie schon aus, verwirft
; AutoHotkey ihn, und der Druck (z.B. C zum Ducken) waere spurlos weg.
YkBlock_Pump() {
    Sleep, -1
    Sleep, 1
    Sleep, -1
}

; Sperre an/aus. Die Ducken-Taste bleibt gesperrt, solange der Sprint tippt.
YkBlock(on) {
    global YK_BlockHks, YK_CrouchHk, YK_SprintMode
    Hotkey, IfWinActive
    for i, hk in YK_BlockHks {
        if (!on && hk = YK_CrouchHk && YK_SprintMode = "tapping")
            continue
        try Hotkey, %hk%, % (on ? "On" : "Off")
    }
}

; Beim Senden verschluckte Tasten dem Spiel nachreichen - erst wenn der Chat
; wirklich zu ist, sonst landeten sie als Buchstaben im Chat.
YkBlock_Replay() {
    global g_BlockReplay, g_ChatOpen
    if (!g_BlockReplay.MaxIndex())
        return
    list := g_BlockReplay
    g_BlockReplay := []
    if (g_ChatOpen || !YkGame_Active())
        return
    t0 := A_TickCount
    while (YkSampOpenNow() && (A_TickCount - t0) < 300)
        Sleep, 10
    if (YkSampOpenNow() || !YkGame_Active())
        return
    down := []
    for i, sc in list {
        vk := DllCall("MapVirtualKey", "UInt", sc, "UInt", 1, "UInt")
        if (vk) {
            YkKey_Down(vk, sc)
            down.Push([vk, sc])
        }
    }
    ; Das Loslassen einer gesperrten Taste verschluckt AutoHotkey mit - also
    ; selbst loslassen, sobald die Taste wirklich los ist (mindestens 50 ms
    ; gehalten, damit das Spiel den Druck sicher mitbekommt)
    YkKey_ReleaseLater(down)
}

; Tasten [[vk, sc], ...] loslassen, sobald sie physisch los sind. Laeuft
; ueber einen Timer: frueher wartete der Hotkey selbst (bis zu 10 s) - so
; lange wirkte derselbe Hotkey nicht noch einmal, und nach 10 s kam ein
; "W los", obwohl W noch gehalten wurde (die Figur blieb stehen).
YkKey_ReleaseLater(keys) {
    global g_UpWatch
    for i, k in keys
        g_UpWatch.Push([k[1], k[2], A_TickCount])
    SetTimer, YkKeyUpWatch, 15
}

YkKeyUp_Tick() {
    global g_UpWatch
    i := g_UpWatch.MaxIndex()
    while (i >= 1) {
        k := g_UpWatch[i]
        kn := Format("sc{:03X}", k[2])
        ; mindestens 50 ms gehalten (damit das Spiel den Druck sicher sieht),
        ; dann los, sobald die Taste wirklich los ist oder GTA nicht mehr vorne
        if ((A_TickCount - k[3]) >= 50 && (!GetKeyState(kn, "P") || !YkGame_Active())) {
            YkKey_Up(k[1], k[2])
            g_UpWatch.RemoveAt(i)
        }
        i -= 1
    }
    if (!g_UpWatch.MaxIndex())
        SetTimer, YkKeyUpWatch, Off
}

; Text fuer SendEvent woertlich machen: ^ + ! # { } als Zeichen senden
YkSendEscape(s) {
    out := ""
    Loop, Parse, s
    {
        c := A_LoopField
        if (c = "`r" || c = "`n")
            continue
        out .= InStr("^+!#{}", c) ? "{" . c . "}" : c
    }
    return out
}

; Darf eine automatische Meldung jetzt raus?
; urgent = true: die Meldung ist dringend (Tod ohne Bewusstlosigkeit). Dann
; entfaellt das Warten auf Gefechtsruhe - man ist ja schon tot, und die
; Meldung soll SOFORT im /g stehen. Frueher blieb sie haengen, solange die
; Maustaste gedrueckt war oder in den letzten 2,5 s geschossen wurde - im
; War also fast immer.
YkCanAutoSend(urgent := false) {
    global YK_Paused, g_ChatOpen, g_LastKeyActivity, g_LastQueueSend, g_Sending
    if (YK_Paused || g_ChatOpen || g_Sending)
        return false
    if (!YkGame_Active())
        return false
    ; frisch nachsehen: nie in einen offenen Chat oder ein Passwortfenster
    if (YkSampOpenNow())
        return false
    ; wurde gerade getippt (Chat, Dialog), noch etwas Abstand halten
    if ((A_TickCount - g_LastKeyActivity) < (urgent ? 400 : 1500))
        return false
    if ((A_TickCount - g_LastQueueSend) < (urgent ? 300 : 800))
        return false
    ; nie mitten ins Gefecht: waehrend Zielen/Schiessen, kurz nach einem
    ; Schuss oder nach Ducken (C-Bug) wartet die Meldung
    if (!urgent && !YkCombatCalm())
        return false
    return true
}

; Ruhe im Kampf? (fuer automatische Meldungen)
YkCombatCalm() {
    global g_LastShotT, g_CrouchT
    if (GetKeyState("LButton", "P") || GetKeyState("RButton", "P"))
        return false
    return ((A_TickCount - g_LastShotT) > 2500 && (A_TickCount - g_CrouchT) > 1200)
}

; Vollstaendigen Gang-Befehl bauen:  "/g <prefix> <text>"
YkGangLine(prefix, body) {
    global YK_GangCmd
    line := YK_GangCmd
    if (prefix != "")
        line .= " " . prefix
    if (body != "")
        line .= " " . body
    return line
}

; =====================================================================
;  SENDE-WARTESCHLANGE (fuer Auto-Meldungen, wenn Chat offen ist)
; =====================================================================
; notBefore = fruehester Zeitpunkt (A_TickCount), 0 = sofort. Damit lassen
; sich mehrere Befehle mit Abstand einreihen (Lotto-Lose), ohne den Binder
; mit "Sleep" anzuhalten.
YkQueue(text, enter := true, notBefore := 0) {
    global g_PendingSends
    g_PendingSends.Push({text: text, enter: enter, t: A_TickCount, notBefore: notBefore})
}

YkProcessQueue() {
    global g_PendingSends, g_LastQueueSend
    if (g_PendingSends.MaxIndex() = "")
        return
    ; veraltete Eintraege verwerfen - nach 2 Minuten, denn im Gefecht wartet
    ; eine Kill-Meldung, bis Ruhe ist
    while (g_PendingSends.MaxIndex() != "" && (A_TickCount - g_PendingSends[1].t) > 120000)
        g_PendingSends.RemoveAt(1)
    if (g_PendingSends.MaxIndex() = "" || !YkCanAutoSend())
        return
    ; ersten Eintrag nehmen, dessen Zeit gekommen ist
    idx := 0
    for i, it in g_PendingSends {
        if (!it.notBefore || A_TickCount >= it.notBefore) {
            idx := i
            break
        }
    }
    if (!idx)
        return
    item := g_PendingSends[idx]
    g_LastQueueSend := A_TickCount
    ; ging der Chat nicht auf, bleibt die Meldung fuer den naechsten Versuch
    t0 := YkDiag_Now()
    ok := YkSendCmd(item.text, item.enter)
    YkStall_Step("Senden", YkDiag_Now() - t0)
    if (ok)
        g_PendingSends.RemoveAt(idx)
}
