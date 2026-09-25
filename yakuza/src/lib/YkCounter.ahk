; =====================================================================
;  Yakuza Keybinder - Zaehler: gesamt, heute, dieser Monat
; ---------------------------------------------------------------------
;  (aus dem Keybinder von Brooklyn 5.0 uebernommen)
;  Drei Zaehler je Wert: gesamt, heute, dieser Monat. Gespeichert wird
;  in YakuzaStatistik.ini neben dem Programm - Abschnitte [Gesamt],
;  [T_2026-09-25], [M_2026-09] - und in [Info] fuer Einzelwerte (letzte
;  SMS, letztes Login ...).
;
;  Gezaehlt werden die Kills und Tode, die der Binder ohnehin erkennt
;  (YkReport_Kill / YkDeath_...), dazu die Spielzeit. Daraus entstehen
;  die Platzhalter fuer /kd, /dkd, /mkd usw.
; =====================================================================

global YK_CntIni := A_ScriptDir . "\YakuzaStatistik.ini"
global g_Cnt := {G: {}, T: {}, M: {}}
global g_CntInfo := {}
global g_CntDay := "", g_CntMonth := ""
global g_CntDirty := false
global g_CntVer := 0                 ; zaehlt jede Aenderung (fuer die Anzeige)

; Zahl oder 0 (in AutoHotkey v1 ergibt "leer + 1" wieder leer)
YkN(v) {
    return (v + 0 = "") ? 0 : v + 0
}

YkCnt(arr) {
    return (IsObject(arr) && arr.MaxIndex()) ? arr.MaxIndex() : 0
}

YkCnt_Keys() {
    return ["kills", "tode", "spielzeit", "logins", "sms_in"]
}

YkCnt_Init() {
    global g_Cnt, g_CntInfo, YK_CntIni
    ; UTF-16 anlegen: sonst gehen Umlaute in [Info] verloren
    if !FileExist(YK_CntIni)
        FileAppend, % "[Gesamt]`r`n", %YK_CntIni%, UTF-16
    g_Cnt.G := YkCnt_ReadSec("Gesamt")
    YkCnt_Rollover(true)
    g_CntInfo := {}
    IniRead, body, %YK_CntIni%, Info
    Loop, Parse, body, `n, `r
    {
        p := InStr(A_LoopField, "=")
        if (p)
            g_CntInfo[SubStr(A_LoopField, 1, p - 1)] := Trim(SubStr(A_LoopField, p + 1), """")
    }
    if (YkCnt_Info("erststart") = "") {
        FormatTime, t, , dd.MM.yyyy HH:mm
        YkCnt_SetInfo("erststart", t)
    }
}

YkCnt_ReadSec(sec) {
    global YK_CntIni
    o := {}
    for i, k in YkCnt_Keys() {
        IniRead, v, %YK_CntIni%, %sec%, %k%, 0
        o[k] := YkN(v)
    }
    return o
}

; Tag/Monat gewechselt? Dann neue Abschnitte laden.
YkCnt_Rollover(force := false) {
    global g_Cnt, g_CntDay, g_CntMonth
    FormatTime, d, , yyyy-MM-dd
    FormatTime, m, , yyyy-MM
    if (!force && d = g_CntDay && m = g_CntMonth)
        return
    if (!force)
        YkCnt_Save()
    g_CntDay := d, g_CntMonth := m
    g_Cnt.T := YkCnt_ReadSec("T_" . d)
    g_Cnt.M := YkCnt_ReadSec("M_" . m)
}

YkCnt_Add(key, n := 1) {
    global g_Cnt, g_CntDirty, g_CntVer
    YkCnt_Rollover()
    for i, s in ["G", "T", "M"] {
        o := g_Cnt[s]
        v := YkN(o[key]) + YkN(n)
        o[key] := (v < 0) ? 0 : v
    }
    g_CntDirty := true
    g_CntVer += 1
}

; Gesamtwert setzen (/setkills). Tag und Monat bleiben unveraendert.
YkCnt_SetTotal(key, v) {
    global g_Cnt, g_CntDirty, g_CntVer
    g_Cnt.G[key] := YkN(v)
    g_CntDirty := true
    g_CntVer += 1
}

YkCnt_Get(key, scope := "G") {
    global g_Cnt
    YkCnt_Rollover()
    return YkN(g_Cnt[scope][key])
}

YkCnt_Info(k) {
    global g_CntInfo
    return g_CntInfo.HasKey(k) ? g_CntInfo[k] : ""
}

YkCnt_SetInfo(k, v) {
    global g_CntInfo, g_CntDirty, g_CntVer
    g_CntInfo[k] := v
    g_CntDirty := true
    g_CntVer += 1
}

YkCnt_Save() {
    global g_Cnt, g_CntInfo, g_CntDay, g_CntMonth, g_CntDirty, YK_CntIni
    if (g_CntDay = "")
        return
    for i, k in YkCnt_Keys() {
        IniWrite, % YkN(g_Cnt.G[k]), %YK_CntIni%, Gesamt, %k%
        IniWrite, % YkN(g_Cnt.T[k]), %YK_CntIni%, % "T_" . g_CntDay, %k%
        IniWrite, % YkN(g_Cnt.M[k]), %YK_CntIni%, % "M_" . g_CntMonth, %k%
    }
    for k, v in g_CntInfo
        IniWrite, % """" . v . """", %YK_CntIni%, Info, %k%
    g_CntDirty := false
}

; aus dem Sekunden-Takt
YkCnt_Tick() {
    global g_CntDirty
    static acc := 0, last := 0, saveT := 0
    YkCnt_Rollover()
    ; Spielzeit: zaehlt nur, solange das Spiel vorne ist
    now := A_TickCount
    if (last && YkGame_Active()) {
        acc += now - last
        if (acc >= 1000) {
            s := acc // 1000
            acc -= s * 1000
            YkCnt_Add("spielzeit", s)
        }
    }
    last := now
    ; hoechstens alle 30 s auf die Platte (Spielzeit aendert sich staendig)
    if (g_CntDirty && (now - saveT) > 30000) {
        saveT := now
        YkCnt_Save()
    }
}

; K/D und Differenz fuer gesamt (G), heute (T), Monat (M).
; Gesamt nimmt denselben Stand wie {kills}/{tode} (Server-Abgleich, falls
; einmal N gedrueckt wurde), damit /kd und {kills} immer zusammenpassen.
YkCnt_Kills(scope := "G") {
    return (scope = "G") ? YkStats_Kills() : YkCnt_Get("kills", scope)
}

YkCnt_Deaths(scope := "G") {
    return (scope = "G") ? YkStats_Deaths() : YkCnt_Get("tode", scope)
}

YkCnt_KD(scope := "G") {
    k := YkCnt_Kills(scope), d := YkCnt_Deaths(scope)
    return Round(k / (d > 0 ? d : 1), 2)
}

YkCnt_Diff(scope := "G") {
    return YkCnt_Kills(scope) - YkCnt_Deaths(scope)
}

; ---------------------------------------------------------------------
;  Zahlen und Zeiten huebsch
; ---------------------------------------------------------------------
YkNum(n) {
    n := Round(YkN(n))
    neg := (n < 0)
    s := RegExReplace(Abs(n), "\B(?=(\d{3})+(?!\d))", ".")
    return (neg ? "-" : "") . s
}

YkDur(sec) {
    sec := Round(YkN(sec))
    h := sec // 3600, m := Mod(sec // 60, 60)
    if (h > 0)
        return h . " Std " . m . " Min"
    return m . " Min " . Mod(sec, 60) . " Sek"
}
