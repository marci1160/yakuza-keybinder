; =====================================================================
;  Yakuza Keybinder - Werkzeuge: Radio, Aufnahmen, Timer (neu in v3.0)
;  (aus dem Keybinder von Brooklyn 5.0 uebernommen)
; =====================================================================

; ---------------------------------------------------------------------
;  Radio (I Love Music) - frueher per VLC, jetzt direkt ueber den
;  Windows Media Player, der in jedem Windows steckt. VLC ist nicht mehr
;  noetig.
; ---------------------------------------------------------------------
global g_Radio := "", g_RadioOn := false
global YK_RadioChan := 1, YK_RadioUrl := "", YK_RadioVol := 60
global YK_RecKey := "F9", YK_RecFolder := "", YK_FragFolder := "", YK_ComplaintFolder := ""
global YK_PathGame := ""

YkRadio_Channels() {
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

YkRadio_Url() {
    global YK_RadioChan, YK_RadioUrl
    if (Trim(YK_RadioUrl) != "")
        return Trim(YK_RadioUrl)
    ch := YkRadio_Channels()
    i := YK_RadioChan + 0
    if (i < 1 || i > ch.MaxIndex())
        i := 1
    return ch[i][2]
}

YkRadio_Name() {
    global YK_RadioChan, YK_RadioUrl
    if (Trim(YK_RadioUrl) != "")
        return "Eigener Sender"
    ch := YkRadio_Channels()
    i := YK_RadioChan + 0
    return (i >= 1 && i <= ch.MaxIndex()) ? ch[i][1] : ch[1][1]
}

YkRadio_Play() {
    global g_Radio, g_RadioOn, YK_RadioVol
    try {
        if (!IsObject(g_Radio))
            g_Radio := ComObjCreate("WMPlayer.OCX")
        g_Radio.settings.volume := YK_RadioVol + 0
        g_Radio.URL := YkRadio_Url()
        g_Radio.controls.play()
        g_RadioOn := true
        YkMsg("Radio: " . YkRadio_Name() . " wird gestartet ...", "ok")
    } catch e {
        g_RadioOn := false
        YkMsg("Radio konnte nicht gestartet werden (Windows Media Player fehlt?).", "warn")
    }
    YkGui_RadioRefresh()
}

YkRadio_Stop(quiet := false) {
    global g_Radio, g_RadioOn
    try {
        if (IsObject(g_Radio))
            g_Radio.controls.stop()
    }
    g_RadioOn := false
    if (quiet)
        return
    YkMsg("Radio wird beendet ...")
    YkGui_RadioRefresh()
}

YkRadio_Volume(v) {
    global g_Radio, YK_RadioVol
    YK_RadioVol := v
    try {
        if (IsObject(g_Radio))
            g_Radio.settings.volume := v + 0
    }
}

; ---------------------------------------------------------------------
;  /frag und /beschwerde: Aufnahme stoppen, neuestes Video verschieben
; ---------------------------------------------------------------------
YkVideo_Save(kind) {
    global YK_RecKey, YK_RecFolder, YK_FragFolder, YK_ComplaintFolder
    src := Trim(YK_RecFolder)
    dst := Trim(kind = "frag" ? YK_FragFolder : YK_ComplaintFolder)
    if (dst = "")
        dst := A_ScriptDir . "\Aufnahmen\" . (kind = "frag" ? "Frags" : "Beschwerden")
    if (src = "" || !FileExist(src)) {
        YkMsg("Bitte zuerst den Aufnahme-Ordner eintragen (Extras > Aufnahmen).", "warn")
        return
    }
    if !FileExist(dst)
        FileCreateDir, %dst%
    YkMsg("Derzeitige Aufnahme wird beendet!")
    if (Trim(YK_RecKey) != "")
        SendInput, % "{" . Trim(YK_RecKey) . "}"
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
        YkMsg("Keine Aufnahme im Ordner gefunden.", "warn")
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
        YkMsg("Video konnte nicht verschoben werden (noch in Benutzung).", "warn")
    else
        YkMsg("Video '" . fname . "' erfolgreich nach " . dst . " verschoben.", "ok")
}

; ---------------------------------------------------------------------
;  CPU-Auslastung (fuer {cpu}) - Kerne werden selbst erkannt
; ---------------------------------------------------------------------
YkCpuLoad() {
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
;  SA-MP starten (Knopf "Spiel starten" in der Uebersicht)
; ---------------------------------------------------------------------
YkRunGame() {
    global YK_PathGame
    p := Trim(YK_PathGame)
    if (p = "")
        p := YkFindSamp()
    if (p = "" || !FileExist(p)) {
        YkMsg("SA-MP nicht gefunden - bitte den Pfad unter Einstellungen > Programme eintragen.", "warn")
        return
    }
    SplitPath, p, , dir
    try Run, "%p%", %dir%
    catch
        YkMsg("Konnte nicht gestartet werden: " . p, "warn")
}

YkFindSamp() {
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

; Einfacher Timer (Uebersicht > Timer): meldet sich nach x Minuten
global g_TimerEnd := 0, g_TimerLabel := ""

YkTimer_Start(min, label := "") {
    global g_TimerEnd, g_TimerLabel
    g_TimerEnd := A_TickCount + Round(min * 60000)
    g_TimerLabel := (label = "") ? min . " Minuten" : label
    SetTimer, YkTimer_Check, 1000
    YkMsg("Timer gestartet: " . g_TimerLabel, "ok")
}

YkTimer_Stop() {
    global g_TimerEnd
    g_TimerEnd := 0
    SetTimer, YkTimer_Check, Off
}

YkTimer_Left() {
    global g_TimerEnd
    return g_TimerEnd ? Max(0, (g_TimerEnd - A_TickCount) // 1000) : -1
}

YkTimer_Check() {
    global g_TimerEnd, g_TimerLabel
    if (!g_TimerEnd)
        return
    YkGui_TimerRefresh()
    if (A_TickCount >= g_TimerEnd) {
        g_TimerEnd := 0
        SetTimer, YkTimer_Check, Off
        YkMsg("Timer abgelaufen: " . g_TimerLabel, "warn", 10000)
        YkBigText("~y~Timer abgelaufen", 3000)
        SoundPlay, *48
        ; Spiel wieder nach vorne holen (wie /chillen in v4.60)
        if (h := YkGame_Hwnd()) {
            WinGet, mm, MinMax, ahk_id %h%
            if (mm = -1)
                WinRestore, ahk_id %h%
        }
        YkGui_TimerRefresh()
    }
}
