; =====================================================================
;  SPRINT-AUTOMATIK
; =====================================================================
YkBuildMoveKeys() {
    global YK_SprintMoveKeys, YK_MoveKeysArr
    YK_MoveKeysArr := []
    for i, k in StrSplit(YK_SprintMoveKeys, ",") {
        kk := Trim(k)
        if (kk != "")
            YK_MoveKeysArr.Push(kk)
    }
}

YkSprint_MovementDown() {
    global YK_MoveKeysArr, YK_SprintReqMove
    if (!YK_SprintReqMove)
        return true
    for i, k in YK_MoveKeysArr {
        if GetKeyState(k, "P")
            return true
    }
    return false
}

YkSprint_ShouldHook() {
    global YK_SprintEnabled, YK_Paused, YK_SprintOnFoot, g_OnFoot, g_ChatOpen, g_Sending
    if (!YK_SprintEnabled || YK_Paused)
        return false
    ; waehrend der Binder selbst tippt, landete die Leertaste sonst im Chat
    if (g_Sending)
        return false
    if (!YkGame_Active())
        return false
    if (g_ChatOpen)
        return false
    if (YK_SprintOnFoot && !g_OnFoot)
        return false
    if (!YkSprint_MovementDown())
        return false
    return true
}

; ---------------------------------------------------------------------
;  Zustandsmaschine: "passthrough" (Taste wirkt normal, z.B. Handbremse)
;  <-> "tapping" (Taste wird schnell angetippt statt gehalten).
;  WICHTIG: Der "gehalten"-Zustand wird in YK_SprintHeld gefuehrt und
;  NUR von den echten Down-/Up-Hotkeys gesetzt - NIEMALS per
;  GetKeyState() waehrend des Tippens abgefragt. GetKeyState wuerde
;  durch die eigenen synthetischen Tap-Ereignisse sofort verfaelscht
;  und die Schleife wuerde nach dem allerersten Tap abbrechen (genau
;  das war der Grund, warum "Laufen" bisher nicht sauber funktionierte).
; ---------------------------------------------------------------------
YkSprint_RunTapLoop() {
    global YK_SprintKey, YK_SprintTapDown, YK_SprintTapUp
    global YK_SprintHeld, YK_SprintMode, YK_SprintLoopBusy, g_SprintCrouched, g_Sending
    if (YK_SprintLoopBusy)
        return
    YK_SprintLoopBusy := true
    YK_SprintMode := "tapping"
    YkSprint_CrouchBlock(true)
    k := YK_SprintKey
    Loop {
        ; Pruefen und Druecken ohne Unterbrechung - sonst koennte genau
        ; dazwischen das Ducken kommen und die Leertaste es wieder aufheben
        Critical
        if (!YK_SprintHeld || g_SprintCrouched || !YkSprint_ShouldHook()) {
            Critical, Off
            break
        }
        Send, % "{Blind}{" . k . " down}"
        Critical, Off
        Sleep, % YK_SprintTapDown
        Send, % "{Blind}{" . k . " up}"
        Sleep, % YK_SprintTapUp
    }
    YK_SprintMode := "stop"
    YkSprint_CrouchBlock(false)
    Send, % "{Blind}{" . k . " up}"
    if (YK_SprintHeld && !g_SprintCrouched && !g_Sending && YkGame_Active()) {
        ; Taste noch gedrueckt, aber Bedingungen nicht mehr erfuellt
        ; (z.B. angehalten oder ins Auto gestiegen) -> normal durchreichen,
        ; damit z.B. die Handbremse weiter funktioniert
        YK_SprintMode := "passthrough"
        Send, % "{Blind}{" . k . " down}"
    } else if (YK_SprintHeld) {
        ; geduckt (oder Spiel nicht vorne): Leertaste bleibt los, bis sie
        ; neu gedrueckt wird - sonst stuende die Figur sofort wieder auf
        YK_SprintMode := "hold"
    } else {
        YK_SprintMode := ""
    }
    YK_SprintLoopBusy := false
}

; Ducken waehrend des Sprint-Tippens. GTA ignoriert das Ducken, solange die
; Sprint-Taste unten ist - und das war beim Tippen die halbe Zeit so. Darum
; erst die Leertaste los, dann die Ducken-Taste; bis zum naechsten Druck
; auf die Leertaste wird nicht mehr getippt.
YkSprint_Crouch() {
    global YK_SprintKey, YK_CrouchSc, g_SprintCrouched, g_CrouchT
    g_SprintCrouched := true
    g_CrouchT := A_TickCount
    Send, % "{Blind}{" . YK_SprintKey . " up}"
    vk := DllCall("MapVirtualKey", "UInt", YK_CrouchSc, "UInt", 1, "UInt")
    if (vk) {
        YkKey_Down(vk, YK_CrouchSc)
        YkKey_ReleaseLater([[vk, YK_CrouchSc]])
    }
}

; Sperre der Ducken-Taste waehrend des Tippens an/aus (nicht mitten im Senden)
YkSprint_CrouchBlock(on) {
    global YK_CrouchHk, g_Sending
    if (YK_CrouchHk = "" || g_Sending)
        return
    Hotkey, IfWinActive
    try Hotkey, %YK_CrouchHk%, % (on ? "On" : "Off")
}

YkSprint_KeyDown() {
    global YK_SprintKey, YK_SprintHeld, YK_SprintMode, g_SprintCrouched
    ; Tastenwiederholung beim Halten - schon verarbeitet
    if (YK_SprintHeld)
        return
    YK_SprintHeld := true
    g_SprintCrouched := false
    if (YkSprint_ShouldHook()) {
        YkSprint_RunTapLoop()
    } else {
        YK_SprintMode := "passthrough"
        Send, % "{Blind}{" . YK_SprintKey . " down}"
    }
}

YkSprint_KeyUp() {
    global YK_SprintKey, YK_SprintHeld, YK_SprintMode, g_SprintCrouched
    YK_SprintHeld := false
    g_SprintCrouched := false
    ; immer loslassen: ging das Druecken noch vor dem Einschalten dieses
    ; Hotkeys direkt ans Spiel, hing die Sprint-Taste dort sonst fest -
    ; dann ging z.B. Ducken (C) nicht mehr
    Send, % "{Blind}{" . YK_SprintKey . " up}"
    if (YK_SprintMode != "tapping")
        YK_SprintMode := ""
}

; ---------------------------------------------------------------------
;  Waechter (alle 80ms):
;   1) Waehrend die Taste gehalten wird: erkennt einen Bedingungswechsel
;      WAEHREND des Haltens (z.B. man haelt Leertaste schon und faengt
;      erst DANACH an sich zu bewegen) und schaltet live auf Antippen um.
;      Verpasstes Loslassen (Fenster gewechselt) wird nachgeholt.
;   2) Waehrend die Taste NICHT gehalten wird: schaltet den blockierenden
;      Hotkey nur dann EIN, wenn wirklich gesprintet werden koennte (auf
;      dem Boden, in Bewegung, Chat zu) - und sofort wieder AUS, sobald
;      das nicht mehr zutrifft. Beim Stehen/Tippen/in Dialogen/Menues
;      ist die Leertaste dadurch komplett unberuehrt und wirkt 1:1 normal.
; ---------------------------------------------------------------------
YkSprint_Watch() {
    global YK_SprintHeld, YK_SprintMode, YK_SprintKey, YK_SprintHooked, g_SprintCrouched
    if (YK_SprintHeld) {
        if (!GetKeyState(YK_SprintKey, "P")) {
            YkSprint_KeyUp()
            return
        }
        if ((YK_SprintMode = "passthrough" || (YK_SprintMode = "hold" && !g_SprintCrouched)) && YkSprint_ShouldHook()) {
            Send, % "{Blind}{" . YK_SprintKey . " up}"
            YkSprint_RunTapLoop()
        }
        return
    }
    ; Druck ging im Hotkey unter (z.B. losgelassen und sofort neu gedrueckt,
    ; waehrend die Schleife noch lief) - nur wenn gerade gesprintet werden
    ; kann, sonst koennte beim Tippen im Chat ein Leerzeichen verloren gehen.
    ; YkSprint_KeyDown ist doppelt aufgerufen harmlos.
    if (YK_SprintHooked && !YK_SprintLoopBusy && GetKeyState(YK_SprintKey, "P") && YkSprint_ShouldHook()) {
        YkSprint_KeyDown()
        return
    }
    want := YkSprint_ShouldHook()
    if (want && !YK_SprintHooked)
        YkSprint_InstallHook()
    else if (!want && YK_SprintHooked)
        YkSprint_RemoveHook()
}

YkSprint_InstallHook() {
    global YK_SprintKey, YK_SprintHkDown, YK_SprintHkUp, YK_SprintHooked, YK_SprintHeld, YK_SprintMode, g_SprintCrouched
    if (YK_SprintHkDown = "" || YK_SprintHooked)
        return
    fnD := Func("YkSprint_KeyDown")
    fnU := Func("YkSprint_KeyUp")
    Hotkey, IfWinActive, ahk_group YkGame
    try Hotkey, % YK_SprintHkDown, % fnD, On
    try Hotkey, % YK_SprintHkUp, % fnU, On
    Hotkey, IfWinActive
    YK_SprintHooked := true
    ; Leertaste schon gedrueckt (erst gestanden, dann losgelaufen): das
    ; Druecken ging direkt ans Spiel. Als "durchgereicht" fuehren - so
    ; kommt das Loslassen an, und der Waechter schaltet aufs Tippen um.
    ; Frueher verschluckte der Hotkey hier das Loslassen: die Sprint-Taste
    ; hing im Spiel fest, Ducken ging nicht mehr.
    if (!YK_SprintHeld && GetKeyState(YK_SprintKey, "P")) {
        YK_SprintHeld := true
        g_SprintCrouched := false
        YK_SprintMode := "passthrough"
    }
}
YkSprint_RemoveHook() {
    global YK_SprintHkDown, YK_SprintHkUp, YK_SprintHooked
    if (YK_SprintHkDown = "" || !YK_SprintHooked)
        return
    Hotkey, IfWinActive, ahk_group YkGame
    try Hotkey, % YK_SprintHkDown, Off
    try Hotkey, % YK_SprintHkUp, Off
    Hotkey, IfWinActive
    YK_SprintHooked := false
}

; =====================================================================
;  WAECHTER GEGEN HAENGENDE TASTEN
; ---------------------------------------------------------------------
;  Der Binder haelt in zwei Faellen selbst eine Taste unten: beim
;  Sprint-Tippen die Leertaste und beim Ducken waehrend des Tippens die
;  C-Taste. Ausserdem sperrt er waehrend des Sendens fuer etwa eine
;  Zehntelsekunde die ueblichen Spieltasten (W A S D Q E F C X Y Z H N
;  1 2, Leertaste) und reicht sie danach nach.
;
;  Bricht einer dieser Ablaeufe ab - das Spiel verliert den Fokus mitten
;  im Senden, ein Fenster kommt dazwischen, der Binder wird pausiert -,
;  dann blieb bisher der Zustand stehen:
;    * g_Sending blieb "true"  -> die Sperre blieb an -> C und F wirkten
;      im Spiel nicht mehr (genau der gemeldete Fehler),
;    * YK_SprintMode blieb "tapping" -> die Ducken-Taste blieb gesperrt,
;    * eine gedrueckte Taste blieb unten -> die Figur lief oder rannte
;      weiter, ohne dass jemand etwas druckte.
;
;  Dieser Waechter laeuft alle 80 ms mit und raeumt genau das auf.
; =====================================================================
YkKeys_Watch() {
    global g_Sending, g_SendStartT, g_BlockReplay, YK_SprintMode, YK_SprintLoopBusy, YK_Paused
    static wasOk := false

    ; 1) Senden haengt fest. Ein echter Sendevorgang ist nach hoechstens
    ;    einer halben Sekunde durch (Warten auf die Chat-Eingabe inklusive).
    ;    Drei Sekunden sind also mit Sicherheit ein Haenger.
    if (g_Sending) {
        if (!g_SendStartT)
            g_SendStartT := A_TickCount
        else if ((A_TickCount - g_SendStartT) > 3000) {
            g_SendStartT := 0
            g_Sending := false
            if (YK_SprintMode = "tapping")
                YK_SprintMode := ""
            YkBlock(false)
            g_BlockReplay := []
            YkApplyHotkeyState()
        }
    } else {
        g_SendStartT := 0
    }

    ; 2) Sprint-Zustand haengt: dann bliebe die Ducken-Sperre scharf
    if (!YK_SprintLoopBusy && YK_SprintMode = "tapping") {
        YK_SprintMode := ""
        YkSprint_CrouchBlock(false)
    }

    ; 3) Spiel nicht mehr vorne oder pausiert -> einmalig alles loslassen.
    ;    Nur, wenn der Binder ueberhaupt etwas unten haelt: sonst gingen
    ;    bei jedem Fensterwechsel "Leertaste los" und "C los" an das
    ;    Programm, zu dem gerade gewechselt wurde.
    ok := (!YK_Paused && YkGame_Active()) ? true : false
    if (wasOk && !ok && YkKeys_Pending())
        YkKeys_Release()
    wasOk := ok
}

; Haelt der Binder gerade irgendetwas gedrueckt?
YkKeys_Pending() {
    global g_UpWatch, YK_SprintHeld, YK_SprintMode, g_SprintCrouched
    if (g_UpWatch.MaxIndex())
        return true
    if (YK_SprintHeld || g_SprintCrouched)
        return true
    return (YK_SprintMode != "")
}

; Alles loslassen, was der Binder unten haelt
YkKeys_Release() {
    global g_UpWatch, YK_SprintKey, YK_CrouchKey, YK_SprintMode, YK_SprintHeld, g_SprintCrouched
    if (g_UpWatch.MaxIndex()) {
        for i, k in g_UpWatch
            YkKey_Up(k[1], k[2])
        g_UpWatch := []
        SetTimer, YkKeyUpWatch, Off
    }
    YkKeys_UpByName(YK_SprintKey)
    YkKeys_UpByName(YK_CrouchKey)
    YK_SprintMode := ""
    YK_SprintHeld := false
    g_SprintCrouched := false
}

YkKeys_UpByName(name) {
    if (name = "")
        return
    vk := GetKeyVK(name)
    if (vk)
        YkKey_Up(vk, GetKeySC(name))
}

; Notbremse von Hand (Tray-Menue) - loest alles auf einmal
YkKeys_Panic() {
    global g_Sending, g_SendStartT, g_BlockReplay
    g_Sending := false
    g_SendStartT := 0
    YkSprint_CrouchBlock(false)
    YkBlock(false)
    g_BlockReplay := []
    YkKeys_Release()
    YkKey_ReleaseMods()
    YkApplyHotkeyState()
}

YkAction_KeysPanic() {
    YkKeys_Panic()
    YkNotify("Alle Tasten wurden losgelassen.")
}

; Wird beim Start und bei Konfigurationsaenderungen (z.B. neue Sprint-
; Taste) aufgerufen. Installiert NICHT sofort den Hotkey - das macht
; der Waechter automatisch, sobald die Bedingungen passen.
YkSprint_Register() {
    global YK_SprintKey, YK_SprintHkDown, YK_SprintHkUp, YK_SprintHeld, YK_SprintMode, YK_SprintHooked, g_SprintCrouched
    if (YK_SprintHooked)
        YkSprint_RemoveHook()
    YK_SprintHeld := false
    YK_SprintMode := ""
    g_SprintCrouched := false
    YK_SprintHkDown := (YK_SprintKey != "") ? "*" . YK_SprintKey : ""
    YK_SprintHkUp   := (YK_SprintKey != "") ? "*" . YK_SprintKey . " up" : ""
}

YkSprint_Toggle() {
    global YK_SprintEnabled
    if (YkInputBlocked())
        return
    YK_SprintEnabled := !YK_SprintEnabled
    IniWrite, % (YK_SprintEnabled ? 1 : 0), % YK_IniPath, Sprint, Enabled
    YkNotify("Sprint-Automatik: " . (YK_SprintEnabled ? "AN" : "AUS"))
    YkRefreshTray()
    YkGui_SyncState()
}
