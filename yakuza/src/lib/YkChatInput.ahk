; =====================================================================
;  Yakuza Keybinder - Mitlesen im Chat: Kurzformen und Chat-Befehle
; ---------------------------------------------------------------------
;  Laeuft nur im Spiel und nur solange der Chat offen ist. Die Tasten
;  werden ueber ihren Tastencode erfasst und ueber das aktuelle
;  Tastaturlayout in das echte Zeichen uebersetzt (wichtig fuer Y/Z
;  und Shift+7 = / auf deutschen Tastaturen).
;
;  Drei Arten, alle bleiben im Binder - der Server sieht nur, was am
;  Ende wirklich abgeschickt wird:
;
;   SOFORT (wie bis v2.0.2):
;     - Kurzformen der Server-Befehle: /uc  ->  /use cannabis
;     - lokale Befehle: /ykpos /ykhud /ykclear /ykzu1../ykzu9 /ykzuaus
;   MIT LEERTASTE:
;     - /ykzu Name + Leertaste
;     - Tippfehler-Kurzformen: 7f -> /f , 7g -> /g  ...
;   MIT ENTER (neu in v3.0, aus dem Keybinder von Brooklyn):
;     - Chat-Befehle wie /kd, /dkd, /re, /cd, /ballas, /setkills 500
;     - eigene Chat-Befehle
;     Wird nichts erkannt, geht Enter ganz normal ans Spiel.
;
;  Die Pruefung "darf ich ueberhaupt?" steht bewusst IN den Handlern.
;  Eine Kontext-Bedingung per Funktionsobjekt wertet AutoHotkey 1.1.22
;  nicht aus - der Puffer wuerde sonst bei jedem Tastendruck mitlaufen
;  und die Kurzform koennte ausserhalb des Spiels in ein beliebiges
;  Textfeld schreiben.
; =====================================================================

global g_TbDirty   := false     ; Schreibmarke bewegt -> Puffer unzuverlaessig
global g_Prompt    := ""        ; laufende Abfrage im Chat ("Kills: ...")
global g_EnterPassT := 0        ; wann der Binder zuletzt Enter selbst behandelt hat
global YK_ChatEnterHks := []    ; $*Enter / $*NumpadEnter (nur bei offenem Chat an)

YkKurz_Active() {
    global YK_Paused, g_ChatOpen, g_SampKnown, g_SampChat, g_ChatKeyTick
    ; "Kurzformen aus" wirkt erst in YkKurz_Check - die lokalen Befehle
    ; /ykpos, /ykhud, /ykclear sollen trotzdem immer funktionieren
    if (YK_Paused)
        return false
    if (!g_ChatOpen)
        return false
    ; Kurzformen nur in der Chat-Eingabe - nie in einem Dialog wie dem
    ; Login-Passwort. Direkt nach T kann samp.dll ein paar Millisekunden
    ; hinterherhinken, daher das kurze Zeitfenster.
    if (g_SampKnown && !g_SampChat && (A_TickCount - g_ChatKeyTick) > 300)
        return false
    return YkGame_Active()
}

YkKurz_Reset() {
    global g_KurzBuf, g_KurzOk, g_TbDirty
    g_KurzBuf := ""
    g_KurzOk := true
    g_TbDirty := false
}

YkKurz_VkFromHotkey(hk) {
    p := InStr(hk, "vk")
    if (!p)
        return 0
    s := "0x" . SubStr(hk, p + 2, 2)
    return s + 0
}

; Tastencode -> tatsaechliches Zeichen im aktuellen Tastaturlayout.
; Die Umschalttasten kommen aus dem Hook-Zustand (GetKeyState), NICHT aus
; GetKeyboardState: das liefert nur den Zustand des eigenen Threads, und
; der Keybinder ist nie das Vordergrundfenster. Dadurch wurde Shift+7 auf
; deutscher Tastatur zu "7" statt "/" - und "/uc" nie erkannt.
YkKurz_VkToChar(vk) {
    ; Ziffernblock direkt (haengt nicht vom Layout ab)
    if (vk >= 0x60 && vk <= 0x69)
        return Chr(0x30 + vk - 0x60)
    static np := {0x6A: "*", 0x6B: "+", 0x6D: "-", 0x6E: ",", 0x6F: "/"}
    if (np.HasKey(vk))
        return np[vk]
    VarSetCapacity(kb, 256, 0)
    if GetKeyState("Shift")
        NumPut(0x80, kb, 0x10, "UChar")
    if GetKeyState("Ctrl")
        NumPut(0x80, kb, 0x11, "UChar")
    if GetKeyState("Alt")
        NumPut(0x80, kb, 0x12, "UChar")
    if GetKeyState("RAlt") {              ; AltGr = Strg + Alt
        NumPut(0x80, kb, 0x11, "UChar")
        NumPut(0x80, kb, 0x12, "UChar")
    }
    if GetKeyState("CapsLock", "T")
        NumPut(0x01, kb, 0x14, "UChar")
    ; Layout des aktiven Fensters (Spiel), nicht das des Keybinders
    tid := DllCall("GetWindowThreadProcessId", "Ptr", WinExist("A"), "Ptr", 0, "UInt")
    hkl := DllCall("GetKeyboardLayout", "UInt", tid, "Ptr")
    sc := DllCall("MapVirtualKeyEx", "UInt", vk, "UInt", 0, "Ptr", hkl)
    VarSetCapacity(buf, 16, 0)
    ; Flag 4: Tastaturzustand nicht veraendern - sonst koennte eine
    ; offene Tottaste (^ oder ´) beim Tippen im Chat verloren gehen
    n := DllCall("ToUnicodeEx", "UInt", vk, "UInt", sc, "Ptr", &kb, "Ptr", &buf, "Int", 6, "UInt", 4, "Ptr", hkl)
    if (n > 0)
        return SubStr(StrGet(&buf, n, "UTF-16"), 1, 1)
    return ""
}

YkKurz_Key() {
    global g_KurzBuf, g_KurzOk, g_LastKeyActivity, g_ChatOpen, YK_ChatKey, g_TbDirty
    ; Tastenaktivitaet im Spiel merken (fuer das Chat-Sicherheitsnetz) -
    ; unabhaengig davon, ob Kurzformen ueberhaupt aktiv sind
    if (YkGame_Active())
        g_LastKeyActivity := A_TickCount
    ; Sicherheitsnetz: bekommt dieser Beobachter bei geschlossenem Chat
    ; doch einmal die Chat-Taste, trotzdem "Chat offen" setzen.
    if (!g_ChatOpen && YkGame_Active()) {
        if (YkKurz_VkFromHotkey(A_ThisHotkey) = GetKeyVK(YK_ChatKey)) {
            YkChatKeyDown()
            return
        }
    }
    if (!YkKurz_Active())
        return
    vk := YkKurz_VkFromHotkey(A_ThisHotkey)
    if (!vk)
        return
    ch := YkKurz_VkToChar(vk)
    if (ch = "")
        return
    g_KurzBuf .= ch
    ; Sofort-Kurzformen nur ganz am Anfang der Zeile (bis zum ersten
    ; Leerzeichen) und nur, solange der Puffer die Zeile wirklich kennt
    if (g_KurzOk && !g_TbDirty)
        YkKurz_Check()
}

YkKurz_Back() {
    global g_KurzBuf
    if (!YkKurz_Active())
        return
    if (StrLen(g_KurzBuf) > 0)
        g_KurzBuf := SubStr(g_KurzBuf, 1, StrLen(g_KurzBuf) - 1)
}

; Schreibmarke bewegt, Verlauf geholt ... - was im Feld steht, weiss der
; Puffer ab jetzt nicht mehr sicher. Dann lieber nichts erkennen.
YkKurz_Dirty() {
    global g_TbDirty
    if (!YkKurz_Active())
        return
    g_TbDirty := true
}

YkKurz_Space() {
    global g_KurzOk, g_KurzBuf, g_TbDirty
    if (!YkKurz_Active())
        return
    ; Ein Leerzeichen beendet normalerweise die Kurzform-Erkennung. Der
    ; lokale Befehl "/ykzu <Name>" braucht aber genau dieses Leerzeichen -
    ; dort wird weitergetippt bzw. der Befehl ausgefuehrt.
    if (!g_TbDirty && YkLocal_Space(g_KurzBuf))
        return
    ; Tippfehler-Kurzformen wie "7f" -> "/f " (Leertaste loest aus)
    if (!g_TbDirty && YkTb_SpaceTrigger())
        return
    g_KurzBuf .= " "
    g_KurzOk := false
}

YkKurz_Check() {
    global g_KurzBuf, YK_CmdBinds, YK_KurzEnabled
    if (g_KurzBuf = "")
        return
    ; Fuehrenden Schraegstrich ignorieren: auf deutscher Tastatur (Shift+7)
    ; landet er im Puffer, auf US-Tastatur nicht. Geloescht wird er beim
    ; Ersetzen in beiden Faellen mit (YkKurz_Expand loescht Laenge + 1).
    buf := g_KurzBuf
    if (SubStr(buf, 1, 1) = "/")
        buf := SubStr(buf, 2)
    if (buf = "")
        return
    if (YkLocal_Check(buf))
        return
    if (!YK_KurzEnabled)
        return
    for ck, b in YK_CmdBinds {
        kz := Trim(b.kurz)
        if (kz = "")
            continue
        if (SubStr(kz, 1, 1) = "/")
            kz := SubStr(kz, 2)
        if (kz = "")
            continue
        if (buf = kz) {
            YkKurz_Expand(StrLen(buf), ck, b.enter)
            return
        }
    }
}

YkKurz_Expand(typedLen, cmd, enter) {
    global YK_SendDelay, g_ChatOpen, g_KurzOk, g_KurzBuf, g_EnterPassT
    if (YK_SendDelay > 0) {
        ; getippte Kurzform inkl. fuehrendem Schraegstrich entfernen
        Send, % "{BS " . (typedLen + 1) . "}"
        Sleep, 15
        prevDelay := A_KeyDelay
        SetKeyDelay, % YK_SendDelay, % YK_SendDelay
        SendEvent, % "{Raw}" . cmd
        SetKeyDelay, % prevDelay
        if (enter) {
            Sleep, 15
            SendInput, {Enter}
        }
    } else {
        ; Kurzform loeschen, Befehl eintragen, evtl. Enter - ohne Pausen
        YkKey_ReleaseMods()
        Loop, % typedLen + 1
            YkKey_Tap(0x08, 0x0E)
        YkKey_Text(cmd)
        if (enter)
            YkKey_Tap(0x0D, 0x1C)
    }
    if (enter) {
        g_ChatOpen := false
        g_EnterPassT := A_TickCount
    }
    YkApplyHotkeyState()
    YkKurz_Reset()
    if (!enter) {
        ; der Befehl steht jetzt im Feld - fuer die Enter-Befehle merken
        g_KurzBuf := cmd
        g_KurzOk := false
    }
}

; ---------------------------------------------------------------------
;  Enter bei offenem Chat (Hotkey $*Enter, nur im Chat-Modus aktiv)
; ---------------------------------------------------------------------
YkChatEnter() {
    global g_ChatOpen, g_SampKnown, g_SampChat, g_KurzBuf, g_TbDirty, g_Prompt, g_LastKeyActivity
    global YK_Paused, YK_TbEnabled
    g_LastKeyActivity := A_TickCount
    ; Dialog offen (z.B. Login-Passwort), Chat gar nicht offen oder Binder
    ; pausiert: Enter unveraendert durchlassen
    if (YK_Paused || !g_ChatOpen || (g_SampKnown && !g_SampChat) || !YkGame_Active()) {
        YkChat_PassEnter()
        return
    }
    line := g_KurzBuf
    YkDbg("Enter: Puffer=[" . line . "] dirty=" . g_TbDirty)
    ; laufende Abfrage ("Kills: ...")
    if (IsObject(g_Prompt)) {
        p := g_Prompt
        g_Prompt := ""
        input := line
        if (SubStr(input, 1, StrLen(p.label)) = p.label)
            input := SubStr(input, StrLen(p.label) + 1)
        input := Trim(input)
        if (p.pass)
            YkChat_PassEnter()
        else
            YkChat_Close()
        YkRunLater(Func("YkPrompt_Done").Bind(p.kind, input, p.data))
        return
    }
    if (!g_TbDirty && YK_TbEnabled) {
        m := YkTb_Match(Trim(line))
        if (IsObject(m)) {
            YkTb_Exec(m.bind, m.args)
            return
        }
    }
    YkChat_PassEnter()
}

YkChat_PassEnter() {
    global g_ChatOpen, g_EnterPassT
    g_EnterPassT := A_TickCount
    YkKey_Tap(0x0D, 0x1C)
    if (g_ChatOpen) {
        g_ChatOpen := false
        YkKurz_Reset()
        YkApplyHotkeyState()
    }
}

; Chat schliessen und getippten Text verwerfen
YkChat_Close() {
    global g_ChatOpen, g_EnterPassT
    g_EnterPassT := A_TickCount
    YkChat_ClearLine()
    YkKey_Tap(0x1B, 0x01)
    g_ChatOpen := false
    YkKurz_Reset()
    YkApplyHotkeyState()
    t0 := A_TickCount
    while (YkSampOpenNow() && (A_TickCount - t0) < 400)
        Sleep, 10
}

; Zeile im Chat leeren: Ende, Shift+Pos1, Entf
YkChat_ClearLine() {
    YkKey_Tap(0x23, 0x4F, 1)
    YkKey_Down(0xA0, 0x2A)
    YkKey_Tap(0x24, 0x47, 1)
    YkKey_Up(0xA0, 0x2A)
    YkKey_Tap(0x2E, 0x53, 1)
}

YkRunLater(fn) {
    SetTimer, % fn, -10
}

; ---------------------------------------------------------------------
;  Anmelden der Beobachter (alle ausgeschaltet; an nur bei offenem Chat,
;  siehe YkSetChatMode)
; ---------------------------------------------------------------------
YkKurz_Register() {
    global YK_KurzHkOn, YK_KurzHkList, YK_ChatEnterHks
    if (YK_KurzHkOn)
        return
    fnKey := Func("YkKurz_Key")
    ; alle mit "~": sie beobachten nur mit und veraendern die Taste nie.
    ; Ob reagiert wird, entscheiden die Handler selbst (YkKurz_Active).
    ; Angelegt werden sie AUSGESCHALTET und nur bei offenem Chat aktiv
    ; (siehe YkSetChatMode). Sonst lagen sie auf denselben Tasten wie die
    ; Chat-Taste T und der Sprint (Leertaste) und nahmen ihnen die Taste weg.
    Hotkey, IfWinActive
    YK_KurzHkList := []
    keys := []
    Loop, 26
        keys.Push(0x40 + A_Index)                 ; A-Z
    Loop, 10
        keys.Push(0x2F + A_Index)                 ; 0-9
    Loop, 10
        keys.Push(0x5F + A_Index)                 ; Ziffernblock 0-9
    ; Ziffernblock-Zeichen und Satzzeichen (deutsch: ß ´ ü + ö ä # , . - <)
    for i, v in [0x6A, 0x6B, 0x6D, 0x6E, 0x6F, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, 0xC0, 0xDB, 0xDC, 0xDD, 0xDE, 0xE2]
        keys.Push(v)
    for i, vk in keys {
        hk := "~*vk" . Format("{:02X}", vk)
        try {
            Hotkey, % hk, % fnKey, Off
            YK_KurzHkList.Push(hk)
        }
    }
    for i, pair in [["~*vk08", "YkKurz_Back"], ["~*vk20", "YkKurz_Space"]
                  , ["~*Left", "YkKurz_Dirty"], ["~*Right", "YkKurz_Dirty"], ["~*Up", "YkKurz_Dirty"]
                  , ["~*Down", "YkKurz_Dirty"], ["~*Home", "YkKurz_Dirty"], ["~*End", "YkKurz_Dirty"]
                  , ["~*Delete", "YkKurz_Dirty"], ["~*Tab", "YkKurz_Dirty"]] {
        try {
            Hotkey, % pair[1], % pair[2], Off
            YK_KurzHkList.Push(pair[1])
        }
    }
    ; Enter abfangen (nur im Chat-Modus an): Chat-Befehle wie /kd.
    ; Eigene Liste, weil nur im Spiel-Kontext - an- und abgeschaltet wird
    ; ein Hotkey immer im selben Kontext, in dem er angelegt wurde.
    Hotkey, IfWinActive, ahk_group YkGame
    YK_ChatEnterHks := []
    for i, hk in ["$*Enter", "$*NumpadEnter"] {
        try {
            Hotkey, % hk, YkChatEnter, Off
            YK_ChatEnterHks.Push(hk)
        }
    }
    Hotkey, IfWinActive
    YK_KurzHkOn := true
}
