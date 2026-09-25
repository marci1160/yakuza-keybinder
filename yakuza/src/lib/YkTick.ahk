; =====================================================================
;  TIMER (Speicher aktualisieren, Tode erkennen, Chatlog lesen, Queue)
;  Seit v3.0 als Funktionen statt Sprungmarken (SetTimer, Funktion, ms)
; =====================================================================

; Schuesse und Kills im Spiel (Wars schreiben nichts in den Chat).
; Derselbe Takt ist auch die Stoppuhr fuer das Haenger-Protokoll: er misst
; als Erstes, wie lange er selbst nicht drangekommen ist.
YkKillMemTimer() {
    YkStall_Watch()
    YkKillMem_Tick()
}

; nachgereichte Tasten loslassen (YkKey_ReleaseLater)
YkKeyUpWatch() {
    YkKeyUp_Tick()
}

; Sekunden-Takt (neu in v3.0): Statistik, Spielzeit, Fenster
YkSecTick() {
    YkCnt_Tick()
    YkGui_SecTick()
}

; =====================================================================
;  DIAGNOSE: wie lange braucht welcher Teil?
; ---------------------------------------------------------------------
;  Wird im Einstellungsfenster angezeigt. Bleibt das Spiel doch einmal
;  stehen, laesst sich damit sofort sehen, ob der Binder daran beteiligt
;  ist - und wenn ja, welcher Teil. Die Messung selbst kostet nichts
;  (zwei Zeitabfragen je Abschnitt).
; =====================================================================
global g_Diag  := {}
global g_DiagT := 0

YkDiag_Now() {
    static freq := 0
    if (!freq)
        DllCall("QueryPerformanceFrequency", "Int64*", freq)
    DllCall("QueryPerformanceCounter", "Int64*", c)
    return c * 1000.0 / freq
}

YkDiag_Add(name, ms) {
    global g_Diag
    d := g_Diag[name]
    if (!IsObject(d)) {
        g_Diag[name] := {avg: ms, max: ms, t: A_TickCount}
        return
    }
    d.avg := d.avg * 0.9 + ms * 0.1
    if (ms > d.max || (A_TickCount - d.t) > 60000) {
        d.max := ms
        d.t := A_TickCount
    }
}

YkDiag_Text() {
    global g_Diag, YK_MemEnabled
    static order := ["Takt gesamt", "Spielspeicher", "Chatlog", "Figuren", "Server-Anzeigen", "Overlay", "Senden"]
    if (!YkGame_Hwnd())
        return "Spiel läuft nicht - es wird nichts gemessen."
    out := "                     Schnitt     Spitze`n"
    any := false
    for i, k in order {
        d := g_Diag[k]
        if (!IsObject(d))
            continue
        any := true
        out .= SubStr(k . "                    ", 1, 18)
            . SubStr("      " . Format("{:.2f}", d.avg), -6) . " ms"
            . SubStr("      " . Format("{:.2f}", d.max), -6) . " ms`n"
    }
    if (!any)
        return "Noch keine Messwerte."
    out .= "`nSpitze wird jede Minute neu gemessen."
    if (!YK_MemEnabled)
        out .= "`nSpielspeicher lesen ist aus."
    out .= "`nGegnernamen aus SA-MP: " . YkSamp_PlrState()
    out .= "`nKills/Tode vom Server:  " . YkStats_Text()
    out .= "`nHänger-Protokoll: " . YkStall_State()
    return out
}

YkTick_Do() {
    global YK_MemEnabled, YK_SprintOnFoot, g_OnFoot, YK_DeathByHealth, YK_DeathEnabled
    global YK_CombatEnabled, g_PrevHp, g_DeathReported
    tAll := YkDiag_Now()

    ; Sicherheitsnetz: sollte ein "Chat zu"-Ereignis einmal verpasst
    ; worden sein, nach laengerer Ruhe wieder freigeben - sonst blieben
    ; die Hotkeys dauerhaft gesperrt.
    ; Nur ohne lesbaren SA-MP-Zustand: sonst bliebe ein Dialog, in dem
    ; man laenger als 30 s nichts tippt, nicht mehr geschuetzt.
    if (!g_SampKnown && g_ChatOpen && (A_TickCount - g_LastKeyActivity) > 30000)
        g_ChatOpen := false

    ; Aktions-Hotkeys je nach Chat-/Pause-Zustand scharf schalten oder
    ; stilllegen (faengt auch verpasste Umschaltungen wieder ein)
    YkApplyHotkeyState()
    YkUpdateStatus()

    ; Speicher-Handle sicherstellen
    if (YK_MemEnabled) {
        t0 := YkDiag_Now()
        YkMem_Ensure()
        ; Zu-Fuss-Status cachen (fuer Sprint-Bedingung)
        inVeh := YkMem_InVehicle()
        if (inVeh = -1)
            g_OnFoot := true
        else
            g_OnFoot := (inVeh = false)
        YkStall_Step("Spielspeicher", YkDiag_Now() - t0)
        ; Position merken und den Tod erkennen macht jetzt der SCHNELLE
        ; Takt (50 ms, YkDeath_Watch in YkCombat.ahk). Grund: im War
        ; spawnt man sofort neu - Leben ging 100 -> 0 -> 100 haeufig
        ; innerhalb eines einzigen 250-ms-Takts, und der Binder hat den
        ; Tod dann nie gesehen. Ausserdem stand im Text der Spawnort statt
        ; des Sterbeorts.
    } else {
        g_OnFoot := true
    }

    t0 := YkDiag_Now()
    YkMonitorChatlog()
    YkStall_Step("Chatlog", YkDiag_Now() - t0)

    YkDeath_Process()
    YkProcessQueue()
    YkProcessFamilyPending()
    YkMembers_Age()

    t0 := YkDiag_Now()
    YkWarTd_Tick()
    YkStall_Step("Server-Anzeigen", YkDiag_Now() - t0)

    t0 := YkDiag_Now()
    YkOverlay_Tick()
    YkStall_Step("Overlay", YkDiag_Now() - t0)

    YkMark_Tick()
    YkUpd_Tick()
    YkWanted_Tick()
    YkStall_Step("Takt gesamt", YkDiag_Now() - tAll)
}
