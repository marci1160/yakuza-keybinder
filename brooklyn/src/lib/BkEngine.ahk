; =====================================================================
;  Brooklyn Keybinder - Laufzeit: Hotkeys, Chat-Befehle, Platzhalter
; ---------------------------------------------------------------------
;  Zwei Saetze Hotkeys, die sich nie ueberschneiden:
;    Chat zu    -> Tasten-Binds aktiv
;    Chat offen -> Tasten-Binds aus, dafuer werden die getippten Zeichen
;                  mitgelesen. Enter prueft, ob ein Chat-Befehl (/kd,
;                  /wp, /map 1.1 ...) getippt wurde - dann fuehrt der
;                  Binder ihn aus, sonst geht Enter ganz normal durch.
;  Ob der Chat offen ist, liest der Binder aus samp.dll (R1/R3/R5/DL);
;  sonst ueber die Tasten T / Enter / Esc wie frueher.
; =====================================================================

global BK_ActiveHotkeys := [], BK_ChatHks := [], BK_ChatModeHks := [], BK_BlockHks := []
global BK_HkOn := true, BK_ChatMode := -1, BK_Paused := false, BK_PauseHk := ""
global g_ChatOpen := false, g_SampKnown := false, g_SampChat := false, g_ChatKeyTick := 0
global g_LastKeyActivity := 0, g_Sending := false, g_SendEndTick := 0, g_SendDeadline := 0
global g_BlockReplay := [], g_UpWatch := [], g_PendingSends := []
global g_FastMode := "", g_FastTries := 0, g_FastPid := 0, g_FastOpen := ""
global g_TbBuf := "", g_TbDirty := false, g_Prompt := ""
global g_FloodUntil := 0, g_HkConflicts := "", g_HkSeen := {}
global BK_BindIndex := {}, BK_TbIndex := {}

; ---------------------------------------------------------------------
;  Nachschlagen
; ---------------------------------------------------------------------
BkIndex_Build() {
    global BK_BindIndex, BK_TbIndex
    BK_BindIndex := {}, BK_TbIndex := {}
    for i, b in BkHotkeyDB()
        BK_BindIndex[b.id] := b
    for i, t in BkTextDB()
        BK_TbIndex[t.id] := t
}

BkBind(id) {
    global BK_BindIndex, BK_TbIndex
    if BK_BindIndex.HasKey(id)
        return BK_BindIndex[id]
    return BK_TbIndex.HasKey(id) ? BK_TbIndex[id] : ""
}

; Aktueller Text eines Binds (eigener Text hat Vorrang)
BkBindText(b) {
    global BK_Texts
    return BK_Texts.HasKey(b.id) ? BK_Texts[b.id] : b.text
}

; Kann der Text dieses Binds im Fenster geaendert werden?
BkBindEditable(b) {
    return (b.type = "send" || b.type = "prefill" || b.type = "local")
}

; ---------------------------------------------------------------------
;  Hotkeys anmelden
; ---------------------------------------------------------------------
BkRegisterHotkeys() {
    global BK_ActiveHotkeys, BK_ChatHks, BK_ChatModeHks, BK_Keys, BK_ChatKey, BK_HkOn, BK_ChatMode, BK_PauseHk

    Hotkey, IfWinActive, ahk_group BkGame
    for i, hk in BK_ActiveHotkeys
        try Hotkey, % hk, Off
    for i, hk in BK_ChatHks
        try Hotkey, % hk, Off
    if (BK_PauseHk != "")
        try Hotkey, % BK_PauseHk, Off
    Hotkey, IfWinActive
    for i, hk in BK_ChatModeHks
        try Hotkey, % hk, Off
    BK_ActiveHotkeys := [], BK_ChatHks := [], BK_ChatModeHks := [], BK_PauseHk := ""

    ; ---- Tasten-Binds (nur im Spiel, nur bei geschlossenem Chat) ----
    Hotkey, IfWinActive, ahk_group BkGame
    BkHk_Begin()
    pauseKey := BK_Keys["hk121"]
    for i, b in BkHotkeyDB() {
        k := BK_Keys[b.id]
        if (k = "" || !BkGroupActive(b.grp))
            continue
        if (b.id = "hk121")
            continue
        BkHk_Register(BkHk_Normalize(k), Func("BkRun").Bind(b.id), b.label)
    }
    ; Pause-Taste extra: muss auch im pausierten Zustand wirken
    if (pauseKey != "") {
        pk := BkHk_Normalize(pauseKey)
        if (g_HkSeen.HasKey(pk)) {
            g_HkConflicts .= "`n" . BkHotkeyName(pk) . ": " . g_HkSeen[pk] . "  und  Pause"
        } else {
            try {
                Hotkey, % pk, BkPauseHotkey, On
                BK_PauseHk := pk
            }
        }
    }
    ; ---- Chat-Verfolgung: Chat-Taste nur bei geschlossenem Chat,
    ;      Escape immer. Nie zwei Hotkeys gleichzeitig auf einer Taste! ----
    for i, k in ["~*" . BK_ChatKey] {
        try {
            Hotkey, % k, BkChatKeyDown, On
            BK_ChatHks.Push(k)
        }
    }
    try Hotkey, ~*Escape, BkChatEscape, On
    Hotkey, IfWinActive

    ; ---- Chat-Modus: Enter abfangen, Zeichen mitlesen ----
    Hotkey, IfWinActive, ahk_group BkGame
    for i, hk in ["$*Enter", "$*NumpadEnter"] {
        try {
            Hotkey, % hk, BkChatEnter, Off
            BK_ChatModeHks.Push(hk)
        }
    }
    fnKey := Func("BkTb_Key")
    keys := []
    Loop, 26
        keys.Push(0x40 + A_Index)
    Loop, 10
        keys.Push(0x2F + A_Index)
    Loop, 10
        keys.Push(0x5F + A_Index)                 ; Ziffernblock 0-9
    for i, v in [0x6A, 0x6B, 0x6D, 0x6E, 0x6F, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, 0xC0, 0xDB, 0xDC, 0xDD, 0xDE, 0xE2]
        keys.Push(v)
    for i, vk in keys {
        hk := "~*vk" . Format("{:02X}", vk)
        try {
            Hotkey, % hk, % fnKey, Off
            BK_ChatModeHks.Push(hk)
        }
    }
    for i, pair in [["~*vk08", "BkTb_Back"], ["~*vk20", "BkTb_Space"], ["~*Left", "BkTb_Dirty"], ["~*Right", "BkTb_Dirty"]
                  , ["~*Up", "BkTb_Dirty"], ["~*Down", "BkTb_Dirty"], ["~*Home", "BkTb_Dirty"], ["~*End", "BkTb_Dirty"]
                  , ["~*Delete", "BkTb_Dirty"], ["~*Tab", "BkTb_Dirty"], ["~*LButton", "BkTb_Dirty"]] {
        try {
            Hotkey, % pair[1], % pair[2], Off
            BK_ChatModeHks.Push(pair[1])
        }
    }
    Hotkey, IfWinActive

    BkBlock_Register()
    BK_HkOn := true
    BK_ChatMode := -1
    BkApplyHotkeyState()
    BkHk_Report()
}

BkPauseHotkey() {
    if (g_ChatOpen || BkSampOpenNow())
        return
    BkFn_TogglePause()
}

BkHotkeysWanted() {
    global BK_Paused, g_ChatOpen, g_FloodUntil
    return (!BK_Paused && !g_ChatOpen && A_TickCount >= g_FloodUntil)
}

BkSetActionHotkeys(on) {
    global BK_ActiveHotkeys, BK_HkOn
    Hotkey, IfWinActive, ahk_group BkGame
    for i, hk in BK_ActiveHotkeys
        try Hotkey, % hk, % (on ? "On" : "Off")
    Hotkey, IfWinActive
    BK_HkOn := (on ? true : false)
}

BkSetChatMode(open) {
    global BK_ChatMode, BK_ChatModeHks, BK_ChatHks
    Hotkey, IfWinActive, ahk_group BkGame
    ; erst ausschalten, dann einschalten
    if (open) {
        for i, hk in BK_ChatHks
            try Hotkey, % hk, Off
        for i, hk in BK_ChatModeHks
            try Hotkey, % hk, % (!BK_Paused ? "On" : "Off")
    } else {
        for i, hk in BK_ChatModeHks
            try Hotkey, % hk, Off
        for i, hk in BK_ChatHks
            try Hotkey, % hk, On
    }
    Hotkey, IfWinActive
    BK_ChatMode := open
}

; Erst ausschalten, dann einschalten - nie zwei Saetze gleichzeitig aktiv
BkApplyHotkeyState() {
    global BK_HkOn, BK_ChatMode, g_ChatOpen
    Critical
    want := BkHotkeysWanted()
    open := g_ChatOpen ? true : false
    if (open) {
        if (want != BK_HkOn)
            BkSetActionHotkeys(want)
        if (BK_ChatMode != open)
            BkSetChatMode(open)
    } else {
        if (BK_ChatMode != open)
            BkSetChatMode(open)
        if (want != BK_HkOn)
            BkSetActionHotkeys(want)
    }
    Critical, Off
}

; ---------------------------------------------------------------------
;  Chat-Zustand
; ---------------------------------------------------------------------
BkSampWatch() {
    global BK_MemEnabled, g_SampKnown, g_SampChat, g_ChatOpen, g_ChatKeyTick
    global g_LastKeyActivity, g_Sending, g_SendEndTick
    if (!BK_MemEnabled) {
        g_SampKnown := false, g_SampChat := false
        return
    }
    if (g_Sending || (A_TickCount - g_SendEndTick) < 150)
        return
    st := BkSamp_InputState(isChat)
    if (st = -1) {
        g_SampKnown := false, g_SampChat := false
        return
    }
    g_SampKnown := true
    g_SampChat := (isChat = 1)
    if (st = 1) {
        g_LastKeyActivity := A_TickCount
        if (!g_ChatOpen) {
            g_ChatOpen := true
            BkTb_Reset()
            BkApplyHotkeyState()
        }
    } else if (g_ChatOpen && (A_TickCount - g_ChatKeyTick) > 400) {
        g_ChatOpen := false
        BkTb_Reset()
        g_Prompt := ""
        BkApplyHotkeyState()
    }
}

BkSampOpenNow() {
    global BK_MemEnabled
    if (!BK_MemEnabled)
        return false
    return (BkSamp_InputState(isChat) = 1)
}

BkChatKeyDown() {
    global g_ChatOpen, g_Sending, g_LastKeyActivity, g_ChatKeyTick
    g_LastKeyActivity := A_TickCount
    g_ChatKeyTick := A_TickCount
    if (g_Sending)
        return
    if (!g_ChatOpen) {
        g_ChatOpen := true
        BkTb_Reset()
        BkApplyHotkeyState()
    }
}

BkChatEscape() {
    global g_ChatOpen, g_Sending, g_SampKnown, g_Prompt
    if (g_Sending)
        return
    g_Prompt := ""
    BkTb_Reset()
    if (!g_SampKnown && g_ChatOpen) {
        g_ChatOpen := false
        BkApplyHotkeyState()
    }
}

; Ist gerade eine Eingabe im Chat moeglich? (Hotkeys pruefen das zusaetzlich)
BkInputBlocked() {
    global g_ChatOpen
    if (!g_ChatOpen && !BkSampOpenNow())
        return false
    BkPassThroughKey()
    return true
}

BkPassThroughKey() {
    hk := A_ThisHotkey
    if RegExMatch(hk, "[\^!#]")
        return
    k := RegExReplace(hk, "^[~*$<>+]+", "")
    if (k = "" || InStr(k, " ") || InStr(k, "&"))
        return
    SendInput, % "{Blind}{" . k . "}"
}

; ---------------------------------------------------------------------
;  Mitlesen, was im Chat getippt wird
; ---------------------------------------------------------------------
BkTb_Reset() {
    global g_TbBuf, g_TbDirty
    g_TbBuf := "", g_TbDirty := false
}

BkTb_Dirty() {
    global g_TbDirty
    g_TbDirty := true
}

BkTb_Key() {
    global g_TbBuf, g_LastKeyActivity
    g_LastKeyActivity := A_TickCount
    if (!g_ChatOpen)
        return
    vk := "0x" . SubStr(A_ThisHotkey, InStr(A_ThisHotkey, "vk") + 2)
    vk += 0
    ch := BkTb_VkToChar(vk)
    if (ch != "")
        g_TbBuf .= ch
}

BkTb_Back() {
    global g_TbBuf
    if (StrLen(g_TbBuf) > 0)
        g_TbBuf := SubStr(g_TbBuf, 1, StrLen(g_TbBuf) - 1)
}

BkTb_Space() {
    global g_TbBuf, g_TbDirty, BK_TbOff
    if (!g_ChatOpen)
        return
    ; Kurzformen wie "7f" -> "/f " loesen mit der Leertaste aus
    if (!g_TbDirty && StrLen(g_TbBuf) <= 5 && !IsObject(g_Prompt)) {
        for i, t in BkTextDB() {
            if (t.arg = "space" && t.cmd = g_TbBuf && !BK_TbOff[t.cmd] && BkGroupActive(t.grp)) {
                n := StrLen(g_TbBuf) + 1
                Sleep, 10
                Loop, % n
                    BkKey_Tap(0x08, 0x0E)
                txt := BkFill(BkBindText(t))
                BkKey_Text(txt)
                g_TbBuf := txt
                return
            }
        }
    }
    g_TbBuf .= " "
}

; Tastencode -> Zeichen im aktuellen Tastaturlayout (deutsch: Shift+7 = /)
BkTb_VkToChar(vk) {
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
    if GetKeyState("RAlt") {
        NumPut(0x80, kb, 0x11, "UChar")
        NumPut(0x80, kb, 0x12, "UChar")
    }
    if GetKeyState("CapsLock", "T")
        NumPut(0x01, kb, 0x14, "UChar")
    tid := DllCall("GetWindowThreadProcessId", "Ptr", WinExist("A"), "Ptr", 0, "UInt")
    hkl := DllCall("GetKeyboardLayout", "UInt", tid, "Ptr")
    sc := DllCall("MapVirtualKeyEx", "UInt", vk, "UInt", 0, "Ptr", hkl)
    VarSetCapacity(buf, 16, 0)
    n := DllCall("ToUnicodeEx", "UInt", vk, "UInt", sc, "Ptr", &kb, "Ptr", &buf, "Int", 6, "UInt", 4, "Ptr", hkl)
    if (n > 0)
        return SubStr(StrGet(&buf, n, "UTF-16"), 1, 1)
    return ""
}

; ---------------------------------------------------------------------
;  Enter bei offenem Chat
; ---------------------------------------------------------------------
BkChatEnter() {
    global g_ChatOpen, g_SampKnown, g_SampChat, g_TbBuf, g_TbDirty, g_Prompt, g_LastKeyActivity
    g_LastKeyActivity := A_TickCount
    ; Dialog offen (z.B. Login-Passwort) oder Chat gar nicht offen: durchlassen
    if (!g_ChatOpen || (g_SampKnown && !g_SampChat)) {
        BkChat_PassEnter()
        return
    }
    line := g_TbBuf
    ; laufende Abfrage ("ID eingeben: ...")
    if (IsObject(g_Prompt)) {
        p := g_Prompt
        g_Prompt := ""
        input := line
        if (SubStr(input, 1, StrLen(p.label)) = p.label)
            input := SubStr(input, StrLen(p.label) + 1)
        input := Trim(input)
        if (p.pass) {
            BkChat_PassEnter()
        } else {
            BkChat_Close()
        }
        BkRunLater(Func("BkPrompt_Done").Bind(p.kind, input, p.data))
        return
    }
    if (!g_TbDirty) {
        m := BkTb_Match(Trim(line))
        if (IsObject(m))
            BkDbg("BEFEHL " . m.bind.cmd . (m.args != "" ? " (mit Angabe)" : ""))
        if (IsObject(m)) {
            BkTb_Exec(m.bind, m.args)
            return
        }
    }
    BkChat_PassEnter()
}

BkChat_PassEnter() {
    global g_ChatOpen
    BkKey_Tap(0x0D, 0x1C)
    if (g_ChatOpen) {
        g_ChatOpen := false
        BkTb_Reset()
        BkApplyHotkeyState()
    }
}

; Chat schliessen und getippten Text verwerfen
BkChat_Close() {
    global g_ChatOpen
    BkChat_ClearLine()
    BkKey_Tap(0x1B, 0x01)
    g_ChatOpen := false
    BkTb_Reset()
    BkApplyHotkeyState()
    t0 := A_TickCount
    while (BkSampOpenNow() && (A_TickCount - t0) < 400)
        Sleep, 10
}

; Zeile im Chat leeren: Ende, Shift+Pos1, Entf
BkChat_ClearLine() {
    BkKey_Tap(0x23, 0x4F, 1)
    BkKey_Down(0xA0, 0x2A)
    BkKey_Tap(0x24, 0x47, 1)
    BkKey_Up(0xA0, 0x2A)
    BkKey_Tap(0x2E, 0x53, 1)
}

; Welcher Chat-Befehl steckt in dieser Zeile? -> {bind, args} oder ""
BkTb_Match(line) {
    global BK_TbOff, BK_CustomTb
    if (line = "")
        return ""
    ; eigene Chat-Befehle zuerst
    for i, c in BK_CustomTb {
        if (c.cmd != "" && line = c.cmd)
            return {bind: {id: "ctb:" . i, cmd: c.cmd, grp: "eigene", label: "Eigener Chat-Befehl", type: "send", text: c.text}, args: ""}
    }
    first := line, rest := ""
    if RegExMatch(line, "^(\S+)\s+(.*)$", mm)
        first := mm1, rest := Trim(mm2)
    for i, t in BkTextDB() {
        if (t.arg = "space" || BK_TbOff[t.cmd])
            continue
        if (t.cmd = line || (t.cmd = first && BkTb_TakesArgs(t))) {
            if (!BkGroupActive(t.grp) && !BkCfg_Get("ShowAll"))
                continue
            return {bind: t, args: (t.cmd = line) ? "" : rest}
        }
    }
    ; Gegnerlisten: /<liste>, /<liste>add, /<liste>del
    if RegExMatch(line, "i)^/(\w+?)(add|del)?(?:\s+(.+))?$", g) {
        lst := BkEnemy_FindList(g1)
        if (lst != "")
            return {bind: {id: "enemy", cmd: line, grp: "gegner", type: "fn", fn: "BkFn_Enemy", arg: g2, text: lst}, args: Trim(g3)}
    }
    return ""
}

BkTb_TakesArgs(t) {
    return (t.type = "fn" && InStr("|BkFn_Prompt|BkFn_Map|BkFn_IdCapture|", "|" . t.fn . "|"))
}

BkTb_Exec(b, args) {
    if (b.type = "prefill") {
        txt := BkFill(BkBindText(b))
        BkChat_ClearLine()
        BkPrefill_Type(txt)
        return
    }
    ; alle anderen: Chat schliessen, dann ausfuehren (in eigenem Thread,
    ; damit Enter sofort wieder frei ist)
    if (b.type = "fn" && (b.fn = "BkFn_IdCapture" || (b.fn = "BkFn_Prompt" && args = "") || (b.fn = "BkFn_Enemy" && b.arg != "" && args = ""))) {
        ; diese Befehle bleiben im Chat und fragen etwas ab
        BkExec(b, args, true)
        return
    }
    BkChat_Close()
    BkRunLater(Func("BkExec").Bind(b, args, false))
}

BkRunLater(fn) {
    SetTimer, % fn, -10
}

; ---------------------------------------------------------------------
;  Ausfuehren
; ---------------------------------------------------------------------
; Von einem Tasten-Bind
BkRun(id) {
    global BK_Paused
    if (BK_Paused)
        return
    if (BkInputBlocked())
        return
    b := BkBind(id)
    if (!IsObject(b))
        return
    BkExec(b, "", false)
}

BkExec(b, args := "", inChat := false) {
    BkStats_HkUse(b.id)
    if (b.type = "send")
        BkSendLines(BkBindText(b))
    else if (b.type = "prefill")
        BkPrefill(BkFill(BkBindText(b)))
    else if (b.type = "local")
        BkMsg(BkFill(BkBindText(b)))
    else if (b.type = "fn") {
        f := Func(b.fn)
        if (IsObject(f))
            f.Call(b, args, inChat)
    }
}

; Zaehler "wie oft benutzt" (Anzeige im Fenster)
BkStats_HkUse(id) {
    global g_HkUse
    if (!IsObject(g_HkUse))
        g_HkUse := {}
    g_HkUse[id] := BkN(g_HkUse[id]) + 1
}

; Mehrere Zeilen nacheinander senden. {sleep 500} = Pause.
BkSendLines(text) {
    global BK_LineDelay
    sent := 0
    for i, line in StrSplit(text, "`n", "`r") {
        if (Trim(line) = "")
            continue
        if RegExMatch(line, "i)^\s*\{sleep\s+(\d+)\}\s*$", m) {
            Sleep, % m1
            continue
        }
        if (sent)
            Sleep, % BK_LineDelay
        if (BkSay(BkFill(line)))
            sent += 1
    }
    return sent
}

; Eine Zeile sicher senden: wartet kurz, falls gerade gesendet wird, der
; Chat noch offen ist oder der Antispam-Schutz greift.
BkSay(line) {
    global g_Sending, g_FloodUntil, g_ChatOpen
    line := Trim(line)
    if (line = "")
        return false
    if (StrLen(line) > 128)
        line := SubStr(line, 1, 128)
    t0 := A_TickCount
    while ((g_Sending || A_TickCount < g_FloodUntil || BkSampOpenNow()) && (A_TickCount - t0) < 3000)
        Sleep, 20
    if (g_ChatOpen && !BkSampOpenNow() && BK_MemEnabled && g_SampKnown)
        g_ChatOpen := false
    ok := BkSendCmd(line, true)
    if (!ok) {
        Sleep, 120
        ok := BkSendCmd(line, true)
    }
    return ok
}

; Chat oeffnen und Text eintragen, ohne abzuschicken ({cursor} = Schreibmarke)
BkPrefill(txt) {
    global g_ChatOpen, g_TbBuf
    t0 := A_TickCount
    while (g_Sending && (A_TickCount - t0) < 1500)
        Sleep, 20
    if (g_ChatOpen || BkSampOpenNow()) {
        BkChat_ClearLine()
        BkPrefill_Type(txt)
        return
    }
    p := InStr(txt, "{cursor}")
    full := StrReplace(txt, "{cursor}")
    if (!BkSendCmd(full, false))
        return
    g_ChatOpen := true
    BkTb_Reset()
    g_TbBuf := full
    if (p) {
        Loop, % StrLen(full) - (p - 1)
            BkKey_Tap(0x25, 0x4B, 1)
        g_TbDirty := true
    }
    BkApplyHotkeyState()
}

BkPrefill_Type(txt) {
    global g_TbBuf, g_TbDirty
    p := InStr(txt, "{cursor}")
    full := StrReplace(txt, "{cursor}")
    BkKey_ReleaseMods()
    BkKey_Text(full)
    g_TbBuf := full
    g_TbDirty := false
    if (p) {
        Loop, % StrLen(full) - (p - 1)
            BkKey_Tap(0x25, 0x4B, 1)
        g_TbDirty := true
    }
}

; ---------------------------------------------------------------------
;  Abfragen im Chat ("ID eingeben: ...")
; ---------------------------------------------------------------------
BkPrompt_Start(kind, label, pass := false, data := "") {
    global g_Prompt, g_ChatOpen, g_TbBuf
    g_Prompt := {kind: kind, label: label, pass: pass, data: data}
    if (g_ChatOpen || BkSampOpenNow()) {
        BkChat_ClearLine()
        BkKey_Text(label)
    } else {
        if (!BkSendCmd(label, false)) {
            g_Prompt := ""
            return
        }
        g_ChatOpen := true
        BkApplyHotkeyState()
    }
    g_TbBuf := label
    g_TbDirty := false
    g_Prompt := {kind: kind, label: label, pass: pass, data: data}
}

; ---------------------------------------------------------------------
;  Platzhalter
; ---------------------------------------------------------------------
BkPlaceholders() {
    return [["{zone}", "Deine Zone, z.B. Idlewood"], ["{stadt}", "Stadt, z.B. Los Santos"], ["{standort}", "Zone (Stadt)"]
        , ["{ort}", "Zone oder ""einem Interior"""], ["{hp}", "Leben"], ["{armor}", "Rüstung"], ["{id}", "Deine Spieler-ID"]
        , ["{name}", "Dein Name"], ["{geld}", "Geld auf der Hand"], ["{ping}", "Dein Ping"], ["{level}", "Dein Level (Score)"]
        , ["{wanteds}", "Wanteds (Sterne)"], ["{wantedlevel}", "Wantedlevel laut Server"], ["{verbrechen}", "Letztes Verbrechen"]
        , ["{zeuge}", "Zeuge"], ["{fahrzeug}", "Fahrzeugname"], ["{fzhp}", "Fahrzeugzustand"], ["{kmh}", "Geschwindigkeit"]
        , ["{kills}", "Kills gesamt"], ["{tode}", "Tode gesamt"], ["{kd}", "K/D gesamt"], ["{diff}", "Differenz gesamt"]
        , ["{dkills}", "Kills heute"], ["{dtode}", "Tode heute"], ["{dkd}", "K/D heute"], ["{ddiff}", "Differenz heute"]
        , ["{mkills}", "Kills im Monat"], ["{mtode}", "Tode im Monat"], ["{mkd}", "K/D im Monat"], ["{mdiff}", "Differenz im Monat"]
        , ["{fchat}", "Fraktionschat (/f)"], ["{gchat}", "Gangchat (/g)"], ["{funk}", "Funk (/r)"], ["{dchat}", "Department (/d)"]
        , ["{partner}", "ID des Partners (/partner)"], ["{opfer}", "ID des Opfers (/kunde)"], ["{zeit}", "Uhrzeit"], ["{datum}", "Datum"]
        , ["{cursor}", "Schreibmarke (nur bei Chat vorbereiten)"], ["{sleep 500}", "Pause in ms (eigene Zeile)"]]
}

BkFill(text) {
    if !InStr(text, "{")
        return text
    out := text
    pos := 1
    seen := {}
    while (pos := RegExMatch(out, "\{([a-zA-Z0-9_]+)\}", m, pos)) {
        k := m1
        StringLower, kl, k
        if (kl = "cursor") {
            pos += StrLen(m)
            continue
        }
        if (!seen.HasKey(kl))
            seen[kl] := BkPh(kl)
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

BkPh(k) {
    global
    local pos, z, c, v, v1, loc, w
    static monate := ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
    if (k = "zone" || k = "stadt" || k = "standort" || k = "ort") {
        if (k = "ort" && BkMem_GetInterior() > 0)
            return "einem Interior"
        pos := BkMem_GetPosition()
        if (!IsObject(pos))
            return "Unbekannt"
        BkZone_Parts(pos, z, c, true)
        return (k = "zone" || k = "ort") ? z : (k = "stadt") ? c : BkZone_Describe(pos, true)
    }
    if (k = "hp")
        return BkValOr(BkMem_GetHealth(), -1)
    if (k = "armor")
        return BkValOr(BkMem_GetArmor(), -1)
    if (k = "geld")
        return BkNum(BkMem_GetMoney())
    if (k = "id" || k = "ping" || k = "level") {
        loc := BkSamp_Local()
        if (!IsObject(loc))
            return "?"
        v := (k = "id") ? loc.id : (k = "ping") ? loc.ping : loc.score
        return (v = "") ? "?" : v
    }
    if (k = "name")
        return BkMyName()
    if (k = "wanteds") {
        w := BkMem_GetWanteds()
        return (w >= 0) ? w : BkInfoOr("wantedlevel", "0")
    }
    if (k = "wantedlevel")
        return BkInfoOr("wantedlevel", "0")
    if (k = "verbrechen")
        return BkInfoOr("verbrechen", "keines")
    if (k = "zeuge")
        return BkInfoOr("zeuge", "Niemand")
    if (k = "fahrzeug") {
        v := BkMem_GetVehicleName()
        return (v = "") ? "zu Fuß" : v
    }
    if (k = "fzhp")
        return BkValOr(BkMem_VehicleHealth(), -1)
    if (k = "kmh")
        return BkValOr(BkMem_VehicleSpeed(), -1)
    if (k = "kills")
        return BkStats_Get("kills")
    if (k = "tode")
        return BkStats_Get("tode")
    if (k = "kd")
        return BkStats_KD("G")
    if (k = "diff")
        return BkStats_Diff("G")
    if (k = "dkills")
        return BkStats_Get("kills", "T")
    if (k = "dtode")
        return BkStats_Get("tode", "T")
    if (k = "dkd")
        return BkStats_KD("T")
    if (k = "ddiff")
        return BkStats_Diff("T")
    if (k = "mkills")
        return BkStats_Get("kills", "M")
    if (k = "mtode")
        return BkStats_Get("tode", "M")
    if (k = "mkd")
        return BkStats_KD("M")
    if (k = "mdiff")
        return BkStats_Diff("M")
    if (k = "monat")
        return monate[A_MM + 0]
    if (k = "monatjahr")
        return monate[A_MM + 0] . " " . A_YYYY
    if (k = "fchat")
        return BK_FChat
    if (k = "gchat")
        return BK_GChat
    if (k = "funk")
        return BK_Funk
    if (k = "dchat")
        return BK_DChat
    if (k = "zeit")
        return A_Hour . ":" . A_Min
    if (k = "datum")
        return A_DD . "." . A_MM . "." . A_YYYY
    if (k = "drogenbox")
        return BK_Drogenbox
    if (k = "memberad")
        return BK_MemberAD
    if (k = "orgad")
        return BK_OrgAD
    if (k = "sonstad")
        return BK_SonstAD
    if RegExMatch(k, "^spruch([1-6])$", v)
        return BK_Spruch%v1%
    if RegExMatch(k, "^mun_(\w+)$", v)
        return BK_Mun_%v1%
    if (k = "drogenrest")
        return 13 - BkN(BkStats_Info("drogensession"))
    if (k = "cpu")
        return Round(BkCpuLoad())
    if (k = "aimid")
        return BkInfoOr("aimid", "")
    if (k = "conpreis")
        return BkInfoOr("conpreis", "")
    if (k = "partner")
        return BkInfoOr("partner", "")
    if (k = "opfer")
        return BkInfoOr("opfer", "")
    if (k = "partnername")
        return BkInfoOr("partnername", "-")
    if (k = "opfername")
        return BkInfoOr("opfername", "-")
    if (k = "letztesms")
        return BkInfoOr("letztesms", "")
    if (k = "adnummer")
        return BkInfoOr("adnummer", "")
    if (k = "login")
        return BkInfoOr("login", "unbekannt")
    if (k = "rentinfo")
        return BkInfoOr("rentinfo", "noch nicht gemietet")
    if (k = "afkzeit")
        return BkInfoOr("afk", "noch nicht erhalten")
    if (k = "robls")
        return BkInfoOr("robls", "unbekannt")
    if (k = "robsf")
        return BkInfoOr("robsf", "unbekannt")
    if (k = "robtresor")
        return BkInfoOr("robtresor", "unbekannt")
    if (k = "spielzeit")
        return BkDur(BkStats_Get("spielzeit"))
    if (k = "spielzeitheute")
        return BkDur(BkStats_Get("spielzeit", "T"))
    if (k = "einnahmenheute")
        return BkNum(BkStats_Einnahmen("T"))
    if (k = "ausgabenheute")
        return BkNum(BkStats_Ausgaben("T"))
    if (k = "geldheute")
        return BkNum(BkStats_Einnahmen("T") - BkStats_Ausgaben("T"))
    if (k = "zinsenheute")
        return BkNum(BkStats_Get("zinsen", "T"))
    if (k = "zinsengesamt")
        return BkNum(BkStats_Get("zinsen"))
    if (k = "fraktion")
        return BK_ProfFaction
    if (k = "job")
        return BkProf_JobName(BK_ProfJob)
    return Chr(1)
}

BkValOr(v, bad) {
    return (v = bad || v = "") ? "?" : v
}

BkInfoOr(k, def) {
    v := BkStats_Info(k)
    return (v = "") ? def : v
}

; Eigener Name: Einstellung > SA-MP > Registry
BkMyName() {
    global BK_Name
    if (Trim(BK_Name) != "")
        return Trim(BK_Name)
    loc := BkSamp_Local()
    if (IsObject(loc) && loc.name != "")
        return loc.name
    n := BkSamp_RegistryName()
    return (n != "") ? n : "Unbekannt"
}
