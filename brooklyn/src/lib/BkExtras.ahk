; =====================================================================
;  Brooklyn Keybinder - Extras: Radio, Aufnahmen, CPU, Programme, Timer
; =====================================================================

; ---------------------------------------------------------------------
;  Radio (I Love Music) - frueher per VLC, jetzt direkt ueber den
;  Windows Media Player, der in jedem Windows steckt. VLC ist nicht mehr
;  noetig.
; ---------------------------------------------------------------------
global g_Radio := "", g_RadioOn := false

BkRadio_Channels() {
    return [["I LOVE RADIO", "https://play.ilovemusic.de/ilm_iloveradio/"]
          , ["I LOVE 2 DANCE", "https://play.ilovemusic.de/ilm_ilove2dance/"]
          , ["I LOVE MASHUP", "https://play.ilovemusic.de/ilm_ilovemashup/"]
          , ["I LOVE HIP HOP", "https://play.ilovemusic.de/ilm_ilovehiphop/"]
          , ["I LOVE TOP 100 CHARTS", "https://play.ilovemusic.de/ilm_ilovetop100charts/"]
          , ["I LOVE DEUTSCHRAP BESTE", "https://play.ilovemusic.de/ilm_ilovedeutschrapbeste/"]
          , ["I LOVE BASS", "https://play.ilovemusic.de/ilm_ilovebass/"]
          , ["I LOVE GREATEST HITS", "https://play.ilovemusic.de/ilm_ilovegreatesthits/"]
          , ["I LOVE HARDSTYLE", "https://play.ilovemusic.de/ilm_ilovehardstyle/"]
          , ["I LOVE THE 90s", "https://play.ilovemusic.de/ilm_ilovethe90s/"]]
}

BkRadio_Url() {
    global BK_RadioChan, BK_RadioUrl
    if (Trim(BK_RadioUrl) != "")
        return Trim(BK_RadioUrl)
    ch := BkRadio_Channels()
    i := BK_RadioChan + 0
    if (i < 1 || i > ch.MaxIndex())
        i := 1
    return ch[i][2]
}

BkRadio_Name() {
    global BK_RadioChan, BK_RadioUrl
    if (Trim(BK_RadioUrl) != "")
        return "Eigener Sender"
    ch := BkRadio_Channels()
    i := BK_RadioChan + 0
    return (i >= 1 && i <= ch.MaxIndex()) ? ch[i][1] : ch[1][1]
}

BkRadio_Play() {
    global g_Radio, g_RadioOn, BK_RadioVol
    try {
        if (!IsObject(g_Radio))
            g_Radio := ComObjCreate("WMPlayer.OCX")
        g_Radio.settings.volume := BK_RadioVol + 0
        g_Radio.URL := BkRadio_Url()
        g_Radio.controls.play()
        g_RadioOn := true
        BkMsg("Radio: " . BkRadio_Name() . " wird gestartet ...", "ok")
    } catch e {
        g_RadioOn := false
        BkMsg("Radio konnte nicht gestartet werden (Windows Media Player fehlt?).", "warn")
    }
    BkGui_RadioRefresh()
}

BkRadio_Stop() {
    global g_Radio, g_RadioOn
    try {
        if (IsObject(g_Radio))
            g_Radio.controls.stop()
    }
    g_RadioOn := false
    BkMsg("Radio wird beendet ...")
    BkGui_RadioRefresh()
}

BkRadio_Volume(v) {
    global g_Radio, BK_RadioVol
    BK_RadioVol := v
    try {
        if (IsObject(g_Radio))
            g_Radio.settings.volume := v + 0
    }
}

; ---------------------------------------------------------------------
;  /frag und /beschwerde: Aufnahme stoppen, neuestes Video verschieben
; ---------------------------------------------------------------------
BkVideo_Save(kind) {
    global BK_RecKey, BK_RecFolder, BK_FragFolder, BK_ComplaintFolder, BK_Dir
    src := Trim(BK_RecFolder)
    dst := Trim(kind = "frag" ? BK_FragFolder : BK_ComplaintFolder)
    if (dst = "")
        dst := BK_Dir . "\Aufnahmen\" . (kind = "frag" ? "Frags" : "Beschwerden")
    if (src = "" || !FileExist(src)) {
        BkMsg("Bitte zuerst den Aufnahme-Ordner in den Einstellungen eintragen.", "warn")
        return
    }
    if !FileExist(dst)
        FileCreateDir, %dst%
    BkMsg("Derzeitige Aufnahme wird beendet!")
    if (Trim(BK_RecKey) != "")
        SendInput, % "{" . Trim(BK_RecKey) . "}"
    Sleep, 1500
    newest := "", newestT := ""
    for i, ext in ["avi", "mp4", "mkv", "mov", "flv"] {
        Loop, Files, % src . "\*." . ext
        {
            if (A_LoopFileTimeModified > newestT)
                newestT := A_LoopFileTimeModified, newest := A_LoopFileFullPath
        }
    }
    if (newest = "") {
        BkMsg("Keine Aufnahme im Ordner gefunden.", "warn")
        return
    }
    SplitPath, newest, fname
    ; Aufnahmeprogramm schreibt evtl. noch - bis zu 10 s versuchen
    Loop, 20 {
        FileMove, %newest%, % dst . "\" . fname, 1
        if (!ErrorLevel)
            break
        Sleep, 500
    }
    if (ErrorLevel)
        BkMsg("Video konnte nicht verschoben werden (noch in Benutzung).", "warn")
    else
        BkMsg("Video '" . fname . "' erfolgreich nach " . dst . " verschoben.", "ok")
}

; ---------------------------------------------------------------------
;  CPU-Auslastung (fuer {cpu}) - Kerne werden selbst erkannt
; ---------------------------------------------------------------------
BkCpuLoad() {
    static lastIdle := 0, lastTotal := 0, val := 0
    VarSetCapacity(idle, 8, 0), VarSetCapacity(kern, 8, 0), VarSetCapacity(user, 8, 0)
    if !DllCall("GetSystemTimes", "Ptr", &idle, "Ptr", &kern, "Ptr", &user)
        return val
    i := NumGet(idle, 0, "Int64"), t := NumGet(kern, 0, "Int64") + NumGet(user, 0, "Int64")
    if (lastTotal && t > lastTotal)
        val := 100 * (1 - (i - lastIdle) / (t - lastTotal))
    lastIdle := i, lastTotal := t
    return (val < 0) ? 0 : (val > 100) ? 100 : val
}

; ---------------------------------------------------------------------
;  Programme starten (TeamSpeak, Spiel, Aufnahme)
; ---------------------------------------------------------------------
BkRunProg(name) {
    global BK_PathTS, BK_PathGame, BK_PathRec
    p := (name = "ts") ? BK_PathTS : (name = "game") ? BK_PathGame : BK_PathRec
    p := Trim(p)
    if (p = "" && name = "game")
        p := BkFindSamp()
    if (p = "" && name = "ts")
        p := BkFindTS()
    if (p = "" || !FileExist(p)) {
        BkGui_Toast("Bitte den Pfad in den Einstellungen > Programme eintragen.")
        BkGui_Go("settings", 4)
        return
    }
    SplitPath, p, , dir
    try Run, "%p%", %dir%
    catch
        BkGui_Toast("Konnte nicht gestartet werden: " . p)
}

BkFindSamp() {
    RegRead, gp, HKEY_CURRENT_USER, Software\SAMP, gta_sa_exe
    if (gp != "") {
        SplitPath, gp, , dir
        if FileExist(dir . "\samp.exe")
            return dir . "\samp.exe"
    }
    for i, p in [A_ProgramFiles . "\Rockstar Games\GTA San Andreas\samp.exe", "C:\Program Files (x86)\Rockstar Games\GTA San Andreas\samp.exe"]
        if FileExist(p)
            return p
    return ""
}

BkFindTS() {
    EnvGet, pf86, ProgramFiles(x86)
    EnvGet, la, LOCALAPPDATA
    for i, p in [A_ProgramFiles . "\TeamSpeak 3 Client\ts3client_win64.exe", pf86 . "\TeamSpeak 3 Client\ts3client_win32.exe"
               , la . "\Programs\TeamSpeak\TeamSpeak.exe", A_ProgramFiles . "\TeamSpeak\TeamSpeak.exe"]
        if FileExist(p)
            return p
    return ""
}

; ---------------------------------------------------------------------
;  Spielzeit (Ersatz fuer den alten "Time Manager")
; ---------------------------------------------------------------------
BkPlaytime_Tick() {
    static acc := 0, last := 0
    now := A_TickCount
    if (last && BkGame_Active()) {
        acc += now - last
        if (acc >= 1000) {
            s := acc // 1000
            acc -= s * 1000
            BkStats_Add("spielzeit", s)
        }
    }
    last := now
}

; Einfacher Timer (Uebersicht > Timer): meldet sich nach x Minuten
global g_TimerEnd := 0, g_TimerLabel := ""

BkTimer_Start(min, label := "") {
    global g_TimerEnd, g_TimerLabel
    g_TimerEnd := A_TickCount + Round(min * 60000)
    g_TimerLabel := (label = "") ? min . " Minuten" : label
    SetTimer, BkTimerCheck, 1000
    BkMsg("Timer gestartet: " . g_TimerLabel, "ok")
}

BkTimer_Stop() {
    global g_TimerEnd
    g_TimerEnd := 0
    SetTimer, BkTimerCheck, Off
}

BkTimer_Left() {
    global g_TimerEnd
    return g_TimerEnd ? Max(0, (g_TimerEnd - A_TickCount) // 1000) : -1
}

BkTimer_Check() {
    global g_TimerEnd, g_TimerLabel
    if (!g_TimerEnd)
        return
    BkGui_TimerRefresh()
    if (A_TickCount >= g_TimerEnd) {
        g_TimerEnd := 0
        SetTimer, BkTimerCheck, Off
        BkMsg("Timer abgelaufen: " . g_TimerLabel, "warn", 10000)
        BkBigText("~y~Timer abgelaufen", 3000)
        SoundPlay, *48
        ; Spiel wieder nach vorne holen (wie /chillen in v4.60)
        if (h := BkGame_Hwnd()) {
            WinGet, mm, MinMax, ahk_id %h%
            if (mm = -1)
                WinRestore, ahk_id %h%
        }
        BkGui_TimerRefresh()
    }
}
