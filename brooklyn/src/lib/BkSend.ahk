; =====================================================================
;  Brooklyn Keybinder - Senden in den Chat (reiner Tastensender)
; ---------------------------------------------------------------------
;  Ersetzt SendChat() der alten Brooklyn.dll. Es wird NICHTS in das Spiel
;  injiziert: der Binder oeffnet den Chat, tippt den Text und drueckt
;  Enter - so schnell, dass die Figur beim Laufen nicht stehen bleibt.
;  Technik uebernommen aus dem Yakuza Keybinder (live geprueft).
; =====================================================================

; =====================================================================
;  BEFEHLE IN DEN CHAT SENDEN (reiner Tastensender)
; =====================================================================
; Liefert true, wenn der Text abgeschickt (bzw. eingetragen) wurde.
BkSendCmd(text, sendEnter := true) {
    global BK_ChatKey, BK_SendDelay, BK_Paused, g_Sending, g_ChatOpen, g_SendEndTick, BK_FastSend, BK_MemEnabled
    global BK_SendWaitMs, g_SendDeadline
    if (BK_Paused || g_Sending)
        return false
    text := "" . text
    if (text = "")
        return false
    if (!BkGame_Active())
        return false
    BkDbg((sendEnter ? "SENDE  " : "CHAT   ") . text)

    chatVk := GetKeyVK(BK_ChatKey)
    if (!chatVk)
        return false
    g_Sending := true
    ; ab hier laeuft die Uhr: alle Warteschritte zusammen duerfen nur so
    ; lange dauern (siehe BkWait_Left)
    g_SendDeadline := A_TickCount + BK_SendWaitMs
    ; 0) fuer die ~0,1 s des Sendens Buchstaben/Ziffern sperren - sonst
    ;    rutschen W/A/S/D vom Laufen in den Befehl (Loslassen geht durch)
    BkBlock(true)
    ; schneller Weg: Chat in keinem Spielbild offen - die Figur laeuft weiter
    if (sendEnter && BK_FastSend && BK_SendDelay <= 0 && BK_MemEnabled) {
        r := BkSendFast(text)
        Critical, Off
        if (r >= 0) {
            BkBlock_Pump()
            BkBlock(false)
            g_ChatOpen := false
            g_Sending := false
            g_SendEndTick := A_TickCount
            BkApplyHotkeyState()
            BkBlock_Replay()
            return (r = 1)
        }
    }
    ; 1) Chat oeffnen. Gehaltene Strg/Alt/Shift (z.B. vom Hotkey Strg+Num1)
    ;    im selben Paket loesen, sonst verfaelschen sie Chat-Taste und Text.
    BkKey_ReleaseMods()
    BkKey_Tap(chatVk, GetKeySC(BK_ChatKey))
    ; 2) warten, bis SA-MP die Eingabe wirklich offen hat (meist 1 Frame).
    ;    Geht der Chat nicht auf, wird NICHTS getippt - sonst kaemen die
    ;    Buchstaben als Spieltasten an und Enter wuerde z.B. aussteigen.
    if (!BkWaitChatOpen()) {
        BkBlock_Pump()
        BkBlock(false)
        g_Sending := false
        g_SendEndTick := A_TickCount
        BkApplyHotkeyState()
        BkBlock_Replay()
        return false
    }
    ; 3) Text und Enter in EINEM Paket. Frueher lagen zwischen Chat-Taste,
    ;    Text und Enter ueber 100 ms Pause: Wer dabei lief oder fuhr und
    ;    W/A/S/D drueckte, tippte diese Buchstaben mitten in den Befehl -
    ;    der Server kannte ihn dann nicht, und so lange stand die Figur.
    ;    Die Ruecktasten vorneweg loeschen, was bis zum Oeffnen evtl. schon
    ;    ins Feld gerutscht ist.
    if (BK_SendDelay > 0) {
        ; Kompatibilitaets-Modus: zeichenweise mit Verzoegerung
        SendInput, {BS 12}
        prevDelay := A_KeyDelay
        SetKeyDelay, % BK_SendDelay, % BK_SendDelay
        SendEvent, % BkSendEscape(text)
        SetKeyDelay, % prevDelay
        if (sendEnter)
            SendInput, {Enter}
    } else {
        ; am Stueck, ohne dass ein Timer dazwischenfunkt - jede Unterbrechung
        ; haelt den Chat laenger offen (die Figur steht so lange)
        Critical
        BkKey_ReleaseMods()              ; Strg evtl. per Tastenwiederholung wieder unten
        Loop, 12
            BkKey_Tap(0x08, 0x0E)
        BkKey_Text(text)
        if (sendEnter)
            BkKey_Tap(0x0D, 0x1C)
        Critical, Off
    }
    BkBlock_Pump()
    BkBlock(false)
    g_ChatOpen := sendEnter ? false : true
    g_Sending := false
    g_SendEndTick := A_TickCount
    BkApplyHotkeyState()
    ; waehrend des Sendens gedrueckte Tasten (z.B. C zum Ducken) nachreichen
    if (sendEnter)
        BkBlock_Replay()
    else
        g_BlockReplay := []
    return true
}

; true, sobald die Chat-Eingabe offen ist. Ohne lesbaren SA-MP-Zustand
; (andere Version, Spielspeicher aus) wird wie frueher kurz gewartet.
BkWaitChatOpen() {
    global BK_MemEnabled
    if (!BK_MemEnabled || BkSamp_InputState(ic) = -1) {
        DllCall("Sleep", "UInt", BkWait_Left(60))
        return true
    }
    limit := BkWait_Left(500)
    t0 := A_TickCount
    Loop {
        if (BkSamp_InputState(ic) = 1 && ic = 1)
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
BkSendFast(text) {
    global BK_ChatKey, BK_dwPID, g_FastMode, g_FastTries, g_FastPid, g_FastOpen
    if (g_FastPid != BK_dwPID) {
        g_FastPid := BK_dwPID
        g_FastMode := ""
        g_FastTries := 0
        g_FastOpen := ""
    }
    hwnd := BkGame_Active()
    if (!hwnd || g_FastMode = "no")
        return -1
    if (BkSamp_InputState(ic) != 0 || !BkSamp_LastInput(before, beforeSig) || BkMem_MenuActive())
        return -1
    vk := GetKeyVK(BK_ChatKey)
    sc := GetKeySC(BK_ChatKey) & 0xFF
    ch := DllCall("MapVirtualKey", "UInt", vk, "UInt", 2, "UInt") & 0xFFFF
    if (ch)
        ch := Asc(Format("{:L}", Chr(ch)))
    ; gehaltenes Strg/Alt/Shift (Hotkey Strg+G) vorher loslassen - das
    ; Spiel sieht das Loslassen erst nach einem Durchgang, der Chat ist da
    ; noch zu
    if (BkKey_ReleaseMods())
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
        BkPost(hwnd, 0x102, ch, 1 | (sc << 16))
        BkPost_Text(hwnd, sent)
        BkPost_Enter(hwnd, g_FastMode)
        Critical, Off
        if BkSendFast_Confirm(sent, beforeSig, 500)
            return 1
        return BkSendFast_Failed(sent, beforeSig)
    }
    ; erstes Mal (oder Chat geht nur per Druecken auf): oeffnen und warten -
    ; geht er nicht auf, landet kein Text im Spiel
    if !BkSendFast_Open(hwnd, vk, sc, ch) {
        g_FastTries += 1
        g_FastMode := (g_FastTries >= 3) ? "no" : ""
        return -1
    }
    Critical
    BkPost_Text(hwnd, sent)
    if (known) {
        BkPost_Enter(hwnd, g_FastMode)
        Critical, Off
        if BkSendFast_Confirm(sent, beforeSig, 500)
            return 1
        return BkSendFast_Failed(sent, beforeSig)
    }
    ; Enter zuerst nur als Zeichen - das erreicht das Spiel nie als Taste
    BkPost_Enter(hwnd, "char")
    Critical, Off
    if BkSendFast_Confirm(sent, beforeSig, 250) {
        g_FastMode := "char"
        return 1
    }
    if (BkSamp_InputState(ic) = 1 && ic = 1) {
        BkPost_Enter(hwnd, "key")
        if BkSendFast_Confirm(sent, beforeSig, 400) {
            g_FastMode := "key"
            return 1
        }
    }
    g_FastTries += 1
    g_FastMode := (g_FastTries >= 3) ? "no" : ""
    return BkSendFast_Failed(sent, beforeSig)
}

; Chat per Nachricht oeffnen und warten, bis SA-MP ihn offen hat. Zuerst
; nur das Zeichen; geht er so nicht auf, Druecken und Loslassen (dann macht
; das Spiel das Zeichen selbst - die Ruecktasten vor dem Text loeschen es).
BkSendFast_Open(hwnd, vk, sc, ch) {
    global g_FastOpen
    if (g_FastOpen != "down" && ch) {
        BkPost(hwnd, 0x102, ch, 1 | (sc << 16))
        if BkSendFast_WaitOpen(300) {
            g_FastOpen := "char"
            return true
        }
        if (g_FastOpen = "char")
            return false
    }
    BkPost(hwnd, 0x100, vk, 1 | (sc << 16))
    BkPost(hwnd, 0x101, vk, 0xC0000001 | (sc << 16))
    if BkSendFast_WaitOpen(400) {
        g_FastOpen := "down"
        return true
    }
    return false
}

BkSendFast_WaitOpen(ms) {
    ms := BkWait_Left(ms)
    t0 := A_TickCount
    Loop {
        if (BkSamp_InputState(ic) = 1 && ic = 1)
            return true
        if ((A_TickCount - t0) > ms)
            return false
        DllCall("Sleep", "UInt", 1)
    }
}

; Senden nicht bestaetigt. Offener Chat: verwerfen (Escape) und schliessen.
; Steht trotzdem etwas Neues im Verlauf, wurde gesendet - dann nicht noch
; einmal (sonst kaeme die Meldung doppelt). Sonst: alter Weg.
BkSendFast_Failed(sent, beforeSig) {
    global g_FastMode
    if (g_FastMode = "char" || g_FastMode = "key")
        g_FastMode := ""                       ; beim naechsten Mal neu pruefen
    if (BkSamp_InputState(ic) = 1 && ic = 1) {
        BkKey_Tap(0x1B, 0x01)
        ; Aufraeumen darf nie am Budget scheitern: sonst bliebe der Chat
        ; offen stehen. Es bekommt ein eigenes, kurzes Limit.
        t0 := A_TickCount
        while (BkSampOpenNow() && (A_TickCount - t0) < 150)
            DllCall("Sleep", "UInt", 5)
        if BkSampOpenNow()
            return 0
    }
    if (BkSamp_LastInput(last, sig) && !(sig == beforeSig))
        return 1
    return -1
}

; zwei Ruecktasten (falls schon ein Zeichen im Chat steht), dann der Text
BkPost_Text(hwnd, sent) {
    BkPost(hwnd, 0x102, 8, 0x0E0001)
    BkPost(hwnd, 0x102, 8, 0x0E0001)
    Loop, Parse, sent
        BkPost(hwnd, 0x102, Asc(A_LoopField), 1)
}

; Chat zu, die Zeile steht vorne im Verlauf und der Verlauf hat sich
; geaendert (sonst kaeme ein zweites Senden desselben Textes falsch durch)?
BkSendFast_Confirm(sent, beforeSig,ms) {
    ms := BkWait_Left(ms)
    t0 := A_TickCount
    Loop {
        if (BkSamp_InputState(ic) = 0 && BkSamp_LastInput(last, sig) && Trim(last) == Trim(sent) && !(sig == beforeSig))
            return true
        if ((A_TickCount - t0) > ms)
            return false
        DllCall("Sleep", "UInt", 1)
    }
}

BkPost(hwnd, msg, wp, lp) {
    static fn := 0
    if (!fn)
        fn := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32", "Ptr"), "AStr", "PostMessageW", "Ptr")
    DllCall(fn, "Ptr", hwnd, "UInt", msg, "UPtr", wp, "UPtr", lp & 0xFFFFFFFF)
}

; Enter als Zeichen (erreicht das Spiel nie als Taste) oder als Taste
BkPost_Enter(hwnd, mode) {
    if (mode = "key")
        BkPost(hwnd, 0x100, 0x0D, 0x1C0001)
    BkPost(hwnd, 0x102, 13, 0x1C0001)
    if (mode = "key")
        BkPost(hwnd, 0x101, 0x0D, 0xC01C0001)
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
BkKey_Tap(vk, sc, ext := 0) {
    static SEND_MARK := 0xFFC3D44D
    DllCall("keybd_event", "UChar", vk, "UChar", sc, "UInt", ext ? 1 : 0, "UPtr", SEND_MARK)
    DllCall("keybd_event", "UChar", vk, "UChar", sc, "UInt", (ext ? 1 : 0) | 2, "UPtr", SEND_MARK)
}

BkKey_Down(vk, sc) {
    DllCall("keybd_event", "UChar", vk, "UChar", sc, "UInt", 0, "UPtr", 0xFFC3D44D)
}

BkKey_Up(vk, sc) {
    DllCall("keybd_event", "UChar", vk, "UChar", sc, "UInt", 2, "UPtr", 0xFFC3D44D)
}

; gerade gedrueckte Umschalttasten loslassen - liefert die Anzahl
BkKey_ReleaseMods() {
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
BkKey_Text(text) {
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
            BkKey_Tap(0x20, 0x39)
    }
}

; ---------------------------------------------------------------------
;  Hotkey-Namen, Normalisierung und Doppelbelegungen
; ---------------------------------------------------------------------
; Hotkey in Umschalttasten und die eigentliche Taste zerlegen.
; Es bleibt immer mindestens ein Zeichen als Taste uebrig - "#" ist also
; die Raute-Taste und nicht "Windows-Taste ohne Taste".
BkHk_Split(hk, ByRef mods, ByRef key) {
    mods := "", key := hk
    while (StrLen(key) > 1) {
        c := SubStr(key, 1, 1)
        if (c = "^" || c = "!" || c = "+" || c = "#" || c = "*" || c = "~" || c = "$")
            mods .= c
        else
            break
        key := SubStr(key, 2)
    }
}

; Tasten, die AutoHotkey als Umschalttaste liest, in eine eindeutige Form
; bringen.
;
; Das Hotkey-Feld im Fenster liefert fuer die deutschen Tasten # und + genau
; diese Zeichen zurueck. AutoHotkey versteht "#" aber als Windows-Taste und
; "+" als Shift - eine Angabe, die NUR aus solchen Zeichen besteht, ist
; deshalb kein gueltiger Hotkey und wurde bisher stillschweigend verworfen.
; Genau daran lagen tote Keybinds (z.B. "Backup rufen" auf der #-Taste).
; Loesung: die Taste wird ueber ihren Tastencode angegeben ("sc02B").
BkHk_Normalize(hk) {
    hk := Trim(hk)
    if (hk = "")
        return ""
    BkHk_Split(hk, mods, key)
    if (StrLen(key) = 1 && InStr("^!+#*~$<>", key)) {
        sc := GetKeySC(key)
        if (sc)
            key := "sc" . Format("{:03X}", sc)
        else {
            vk := GetKeyVK(key)
            if (vk)
                key := "vk" . Format("{:02X}", vk)
        }
    }
    return mods . key
}

BkHotkeyName(hk) {
    static names := {Space: "Leertaste", Enter: "Enter", Escape: "Esc", Delete: "Entf"
        , Insert: "Einfg", Home: "Pos1", End: "Ende", PgUp: "Bild auf", PgDn: "Bild ab"
        , Up: "Pfeil hoch", Down: "Pfeil runter", Left: "Pfeil links", Right: "Pfeil rechts"
        , XButton1: "Maus 4", XButton2: "Maus 5", MButton: "Mausrad", Backspace: "Ruecktaste"
        , Tab: "Tab", CapsLock: "Feststell", AppsKey: "Menue"}
    static np := {Add: "+", Sub: "-", Mult: "*", Div: "/", Dot: ",", Enter: "Enter"}
    if (hk = "")
        return ""
    BkHk_Split(hk, ms, k)
    mods := ""
    Loop, Parse, ms
    {
        if (A_LoopField = "^")
            mods .= "Strg+"
        else if (A_LoopField = "!")
            mods .= "Alt+"
        else if (A_LoopField = "+")
            mods .= "Shift+"
        else if (A_LoopField = "#")
            mods .= "Win+"
    }
    ; ueber den Tastencode angegebene Tasten wieder lesbar machen
    if RegExMatch(k, "i)^(sc[0-9A-F]{1,3}|vk[0-9A-F]{1,2})$") {
        n := ""
        try n := GetKeyName(k)
        if (n != "")
            k := n
    }
    if (names.HasKey(k))
        k := names[k]
    else if RegExMatch(k, "i)^Numpad(.+)$", m)
        k := "Num " . (np.HasKey(m1) ? np[m1] : m1)
    else if (StrLen(k) = 1)
        StringUpper, k, k
    return mods . k
}

BkHk_Begin() {
    global g_HkSeen, g_HkConflicts
    g_HkSeen := {}
    g_HkConflicts := ""
}

; Hotkey im aktuell gesetzten Kontext anlegen. Ist die Taste schon
; vergeben, gewinnt die erste Belegung und der Konflikt wird gemerkt.
BkHk_Register(key, fn, label) {
    global BK_ActiveHotkeys, g_HkSeen, g_HkConflicts, BK_ChatKey
    if (key = "")
        return
    if (key = BK_ChatKey) {
        g_HkConflicts .= "`n" . BkHotkeyName(key) . " ist die Chat-Taste (" . label . ")"
        return
    }
    if (g_HkSeen.HasKey(key)) {
        g_HkConflicts .= "`n" . BkHotkeyName(key) . ": " . g_HkSeen[key] . "  und  " . label
        return
    }
    try {
        Hotkey, % key, % fn, On
        BK_ActiveHotkeys.Push(key)
        g_HkSeen[key] := label
    } catch {
        g_HkConflicts .= "`n" . key . ": ungueltiger Hotkey (" . label . ")"
    }
}

; Hinweis nur, wenn sich die Doppelbelegungen geaendert haben - Einstellungen
; wirken sofort beim Tippen, sonst kaeme dieselbe Meldung immer wieder
BkHk_Report() {
    global g_HkConflicts
    static last := ""
    if (g_HkConflicts != "" && !(g_HkConflicts == last))
        BkMsg("Taste doppelt belegt - bitte im Keybinder aendern:" . g_HkConflicts, "warn", 8000)
    last := g_HkConflicts
}

BkShorten(s, n) {
    return (StrLen(s) > n) ? SubStr(s, 1, n - 1) . "…" : s
}

; Alle Warteschritte eines Sendevorgangs zusammen duerfen hoechstens
; BK_SendWaitMs dauern - reisst der Faden, bricht der Binder ab.
BkWait_Left(want) {
    global BK_SendWaitMs, g_SendDeadline
    if (want > BK_SendWaitMs)
        want := BK_SendWaitMs
    if (!g_SendDeadline)
        return want
    left := g_SendDeadline - A_TickCount
    if (left < 0)
        left := 0
    return (want < left) ? want : left
}

BkDiag_Now() {
    static freq := 0
    if (!freq)
        DllCall("QueryPerformanceFrequency", "Int64*", freq)
    DllCall("QueryPerformanceCounter", "Int64*", c)
    return c * 1000.0 / freq
}

; ---------------------------------------------------------------------
;  Tastensperre waehrend des Sendens
; ---------------------------------------------------------------------
; Waehrend der ~0,1 s des Sendens werden die Bewegungs- und Kampftasten
; kurz gesperrt: sonst rutschen W/A/S/D vom Laufen in den Befehl. Der
; physische Druck wird gemerkt und nach dem Senden nachgereicht, das
; Loslassen geht immer durch.
BkBlock_Register() {
    global BK_BlockHks, BK_ChatKey, BK_ActiveHotkeys
    Hotkey, IfWinActive
    for i, hk in BK_BlockHks
        try Hotkey, %hk%, Off
    BK_BlockHks := []
    used := {}
    for i, k in BK_ActiveHotkeys {
        BkHk_Split(k, ms, kk)
        vk := GetKeyVK(kk)
        if (vk)
            used[vk] := 1
    }
    used[GetKeyVK(BK_ChatKey)] := 1
    want := ["Space", "w", "a", "s", "d", "q", "e", "f", "c", "x", "y", "z", "h", "n", "1", "2"]
    vks := [], seen := {}
    for i, k in want {
        vk := GetKeyVK(k)
        if (!vk || seen.HasKey(vk))
            continue
        if !(DllCall("MapVirtualKey", "UInt", vk, "UInt", 2, "UInt") & 0xFFFF)
            continue
        seen[vk] := 1
        vks.Push(vk)
    }
    fn := Func("BkBlock_Nop")
    for i, vk in vks {
        if used.HasKey(vk)
            continue
        sc := DllCall("MapVirtualKey", "UInt", vk, "UInt", 0, "UInt")
        if (!sc)
            continue
        hk := "*sc" . Format("{:03X}", sc)
        try {
            Hotkey, %hk%, % fn, Off B
            BK_BlockHks.Push(hk)
        }
    }
}

BkBlock_Nop() {
    global g_Sending, g_BlockReplay
    sc := GetKeySC(RegExReplace(A_ThisHotkey, "^[*~$]+"))
    if (!sc)
        return
    for i, v in g_BlockReplay
        if (v = sc)
            return
    g_BlockReplay.Push(sc)
    if (!g_Sending)
        BkBlock_Replay()
}

; Gesperrte Tastendruecke melden sich als eigene Threads - die muessen
; laufen, solange die Sperre noch an ist.
BkBlock_Pump() {
    Sleep, -1
    Sleep, 1
    Sleep, -1
}

BkBlock(on) {
    global BK_BlockHks
    Hotkey, IfWinActive
    for i, hk in BK_BlockHks
        try Hotkey, %hk%, % (on ? "On" : "Off")
}

; Beim Senden verschluckte Tasten dem Spiel nachreichen - erst wenn der
; Chat wirklich zu ist, sonst landeten sie als Buchstaben im Chat.
BkBlock_Replay() {
    global g_BlockReplay, g_ChatOpen
    if (!g_BlockReplay.MaxIndex())
        return
    list := g_BlockReplay
    g_BlockReplay := []
    if (g_ChatOpen || !BkGame_Active())
        return
    t0 := A_TickCount
    while (BkSampOpenNow() && (A_TickCount - t0) < 300)
        Sleep, 10
    if (BkSampOpenNow() || !BkGame_Active())
        return
    down := []
    for i, sc in list {
        vk := DllCall("MapVirtualKey", "UInt", sc, "UInt", 1, "UInt")
        if (vk) {
            BkKey_Down(vk, sc)
            down.Push([vk, sc])
        }
    }
    BkKey_ReleaseLater(down)
}

; Tasten loslassen, sobald sie physisch los sind (mind. 50 ms gehalten)
BkKey_ReleaseLater(keys) {
    global g_UpWatch
    for i, k in keys
        g_UpWatch.Push([k[1], k[2], A_TickCount])
    SetTimer, BkKeyUpWatch, 15
}

BkKeyUp_Tick() {
    global g_UpWatch
    i := g_UpWatch.MaxIndex()
    while (i >= 1) {
        k := g_UpWatch[i]
        kn := Format("sc{:03X}", k[2])
        if ((A_TickCount - k[3]) >= 50 && (!GetKeyState(kn, "P") || !BkGame_Active())) {
            BkKey_Up(k[1], k[2])
            g_UpWatch.RemoveAt(i)
        }
        i -= 1
    }
    if (!g_UpWatch.MaxIndex())
        SetTimer, BkKeyUpWatch, Off
}

; Text fuer SendEvent woertlich machen: ^ + ! # { } als Zeichen senden
BkSendEscape(s) {
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

; Notbremse: alles loslassen, was der Binder evtl. unten haelt
BkKeys_Panic() {
    global g_Sending, g_BlockReplay, g_UpWatch
    g_Sending := false
    BkBlock(false)
    g_BlockReplay := []
    for i, k in g_UpWatch
        BkKey_Up(k[1], k[2])
    g_UpWatch := []
    SetTimer, BkKeyUpWatch, Off
    BkKey_ReleaseMods()
    BkApplyHotkeyState()
}

; Protokoll fuer die Fehlersuche (config.ini: [Allgemein] Debug="1")
BkDbg(text) {
    global BK_Debug, BK_Dir
    if (!BK_Debug)
        return
    FormatTime, ts, , HH:mm:ss
    FileAppend, % ts . "." . A_MSec . "  " . text . "`r`n", % BK_Dir . "\debug.log", UTF-8
}
