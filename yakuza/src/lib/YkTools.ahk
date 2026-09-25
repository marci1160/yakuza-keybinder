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
global YK_RecKey := "F9", YK_RecStopKey := "", YK_RecFolder := "", YK_FragFolder := "", YK_ComplaintFolder := ""
global g_RecOn := false, g_RecT0 := 0
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
;  Aufnahmen: /rec startet, /recstop beendet, /frag und /beschwerde
;  beenden und legen das neueste Video ab.
;  Der Binder drueckt dafuer die Taste deines Aufnahmeprogramms (OBS,
;  NVIDIA, AMD, Xbox-Spielleiste ...). Bis v3.0.0 wurde sie nur ganz kurz
;  angetippt - OBS fragt seine Tasten aber nur alle paar Millisekunden ab
;  und hat das Antippen verpasst: die Aufnahme lief einfach weiter. Jetzt
;  wird die Taste wie von Hand ~0,15 s gehalten, auch mit Alt/Strg/Shift/Win.
; ---------------------------------------------------------------------

; "F9", "Alt+F9", "Strg+Shift+R", "Win+Alt+R" oder AutoHotkey-Schreibweise
; ("!F9", "^+r", "#!r") -> {mods: [...], vk, sc, ext, name} oder ""
YkRec_ParseKey(s) {
    static modNames := {strg: "ctrl", ctrl: "ctrl", control: "ctrl", alt: "alt", shift: "shift", umschalt: "shift", umsch: "shift"
                      , win: "win", windows: "win", lwin: "win"}
    static modKeys := {ctrl: [0xA2, 0x1D, 0], alt: [0xA4, 0x38, 0], shift: [0xA0, 0x2A, 0], win: [0x5B, 0x5B, 1]}
    static symMods := ["ctrl", "alt", "shift", "win"]
    static modShow := {ctrl: "Strg", alt: "Alt", shift: "Shift", win: "Win"}
    static deNames := {druck: "PrintScreen", rollen: "ScrollLock", pos1: "Home", ende: "End", einfg: "Insert", entf: "Delete"
                     , leertaste: "Space", bildauf: "PgUp", bildab: "PgDn"}
    s := Trim(s)
    if (s = "")
        return ""
    want := []
    ; AutoHotkey-Schreibweise vorn: ^ Strg, ! Alt, + Shift, # Win
    while (StrLen(s) > 1 && (p := InStr("^!+#", SubStr(s, 1, 1)))) {
        want.Push(symMods[p])
        s := SubStr(s, 2)
    }
    parts := StrSplit(s, "+", " `t")
    key := parts.Pop()
    for i, w in parts {
        if (w = "")
            continue
        if (w = "altgr") {
            want.Push("ctrl"), want.Push("alt")
            continue
        }
        if !modNames.HasKey(w)
            return ""
        want.Push(modNames[w])
    }
    if deNames.HasKey(key)
        key := deNames[key]
    vk := GetKeyVK(key), sc := GetKeySC(key)
    if (!vk || key = "")
        return ""
    k := {mods: [], vk: vk, sc: sc & 0xFF, ext: (sc > 0xFF) ? 1 : 0, name: ""}
    seen := {}
    for i, m in want {
        if seen.HasKey(m)
            continue
        seen[m] := 1
        mk := modKeys[m]
        k.mods.Push({vk: mk[1], sc: mk[2], ext: mk[3]})
        k.name .= modShow[m] . "+"
    }
    k.name .= (StrLen(key) = 1) ? Format("{:U}", key) : key
    return k
}

YkRec_KeyEvt(k, up) {
    DllCall("keybd_event", "UChar", k.vk, "UChar", k.sc, "UInt", (k.ext ? 1 : 0) | (up ? 2 : 0), "UPtr", 0xFFC3D44D)
}

; Taste(nkombination) druecken und kurz halten
YkRec_Press(s) {
    k := YkRec_ParseKey(s)
    if (!IsObject(k))
        return ""
    YkKey_ReleaseMods()
    for i, m in k.mods {
        YkRec_KeyEvt(m, false)
        Sleep, 30
    }
    YkDbg("Aufnahme-Taste: " . k.name)
    YkRec_KeyEvt(k, false)
    Sleep, 150
    YkRec_KeyEvt(k, true)
    i := k.mods.MaxIndex()
    while (i >= 1) {
        Sleep, 30
        YkRec_KeyEvt(k.mods[i], true)
        i -= 1
    }
    return k.name
}

YkRec_StopKey() {
    global YK_RecKey, YK_RecStopKey
    return (Trim(YK_RecStopKey) != "") ? YK_RecStopKey : YK_RecKey
}

YkRec_Running() {
    global g_RecOn, g_RecT0
    if (!g_RecOn)
        return ""
    s := (A_TickCount - g_RecT0) // 1000
    return Format("{:02}:{:02}", s // 60, Mod(s, 60))
}

YkRec_Start() {
    global YK_RecKey, YK_RecStopKey, g_RecOn, g_RecT0
    if (!IsObject(YkRec_ParseKey(YK_RecKey)))
        return YkMsg("Bitte zuerst die Start-Taste deines Aufnahmeprogramms eintragen (Extras > Aufnahmen).", "warn")
    ; eine Taste zum Starten UND Beenden: nicht aus Versehen wieder ausschalten
    if (g_RecOn && Trim(YK_RecStopKey) = "")
        return YkMsg("Die Aufnahme läuft schon (" . YkRec_Running() . "). Beenden mit /recstop.", "warn")
    name := YkRec_Press(YK_RecKey)
    g_RecOn := true, g_RecT0 := A_TickCount
    YkMsg("● Aufnahme gestartet (" . name . ")", "ok")
    YkGui_RecRefresh()
}

; Beendet die Aufnahme - auch, wenn du sie selbst gestartet hast
YkRec_Stop(quiet := false) {
    global g_RecOn
    key := YkRec_StopKey()
    if (!IsObject(YkRec_ParseKey(key))) {
        YkMsg("Bitte zuerst die Taste deines Aufnahmeprogramms eintragen (Extras > Aufnahmen).", "warn")
        return false
    }
    dur := YkRec_Running()
    name := YkRec_Press(key)
    g_RecOn := false
    if (!quiet)
        YkMsg("■ Aufnahme beendet (" . name . ")" . (dur != "" ? " - Länge " . dur : ""), "ok")
    YkGui_RecRefresh()
    return true
}

YkVideo_Exts() {
    return ["mp4", "mkv", "avi", "mov", "flv", "webm", "ts"]
}

; neuestes Video im Ordner (auch in Unterordnern - NVIDIA legt je Spiel
; einen an), ohne die Ablage-Ordner selbst
YkVideo_Newest(src, skip) {
    newest := "", newestT := ""
    for i, ext in YkVideo_Exts() {
        Loop, Files, % src . "\*." . ext, R
        {
            f := A_LoopFileFullPath, bad := false
            for j, s in skip
                if (s != "" && InStr(f, s . "\") = 1)
                    bad := true
            if (!bad && A_LoopFileTimeModified > newestT)
                newestT := A_LoopFileTimeModified, newest := f
        }
    }
    return newest
}

YkVideo_Save(kind) {
    global YK_RecFolder, YK_FragFolder, YK_ComplaintFolder
    what := (kind = "frag") ? "Frag" : "Beschwerde"
    ; erst beenden - das klappt auch ohne eingetragenen Ordner
    if (!YkRec_Stop(true))
        return
    src := RTrim(Trim(YK_RecFolder), "\")
    if (src = "" || !FileExist(src)) {
        YkMsg("■ Aufnahme beendet. Zum Ablegen als " . what . " bitte den Video-Ordner eintragen (Extras > Aufnahmen).", "warn")
        return
    }
    fragDir := RTrim(Trim(YK_FragFolder), "\"), compDir := RTrim(Trim(YK_ComplaintFolder), "\")
    if (fragDir = "")
        fragDir := A_ScriptDir . "\Aufnahmen\Frags"
    if (compDir = "")
        compDir := A_ScriptDir . "\Aufnahmen\Beschwerden"
    dst := (kind = "frag") ? fragDir : compDir
    YkMsg("■ Aufnahme beendet - Video wird als " . what . " abgelegt ...")
    if !FileExist(dst)
        FileCreateDir, %dst%
    ; das Programm braucht nach dem Beenden oft ein paar Sekunden, bis die
    ; Datei fertig ist - bis zu 20 s warten
    t0 := A_TickCount, moved := false, newest := ""
    Sleep, 1500
    while ((A_TickCount - t0) < 20000) {
        newest := YkVideo_Newest(src, [fragDir, compDir])
        if (newest != "") {
            SplitPath, newest, fname
            FileMove, %newest%, % dst . "\" . fname, 1
            if (!ErrorLevel) {
                moved := true
                break
            }
        }
        Sleep, 500
    }
    if (moved)
        YkMsg("Video '" . fname . "' nach " . dst . " verschoben.", "ok")
    else if (newest = "")
        YkMsg("Keine Aufnahme im Video-Ordner gefunden.", "warn")
    else
        YkMsg("Video konnte nicht verschoben werden (noch in Benutzung).", "warn")
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
