; =====================================================================
;  Brooklyn Keybinder - Statistik (Kills, Tode, Finanzen, Aktivitaet)
; ---------------------------------------------------------------------
;  Drei Zaehler je Wert: gesamt, heute, dieser Monat. Gespeichert wird
;  in stats.ini (Abschnitte [Gesamt], [T_2026-09-25], [M_2026-09]) und
;  in [Info] fuer Einzelwerte (Kontostand, letztes Login, Partner ...).
; =====================================================================

global g_St := {G: {}, T: {}, M: {}}
global g_StInfo := {}
global g_StDay := "", g_StMonth := ""
global g_StDirty := false
global g_StVer := 0                ; zaehlt jede Aenderung (fuer die Anzeige)

; Zahl oder 0 (in AutoHotkey v1 ergibt "leer + 1" wieder leer)
BkN(v) {
    return (v + 0 = "") ? 0 : v + 0
}

BkCnt(arr) {
    return (IsObject(arr) && arr.MaxIndex()) ? arr.MaxIndex() : 0
}

BkStats_Keys() {
    return ["kills", "tode", "knast", "copdm", "todverlust", "sprit", "karte", "miete", "zinsen", "blitzer"
          , "drogen", "sms_in", "sms_out", "logins", "missionen", "notafk", "hacked", "kofferraum"
          , "take", "get", "spielzeit"]
}

BkStats_Init() {
    global g_St, g_StInfo, BK_StatsIni
    g_St.G := BkStats_ReadSec("Gesamt")
    BkStats_Rollover(true)
    g_StInfo := {}
    IniRead, body, %BK_StatsIni%, Info
    Loop, Parse, body, `n, `r
    {
        p := InStr(A_LoopField, "=")
        if (p)
            g_StInfo[SubStr(A_LoopField, 1, p - 1)] := BkIni_Dec(Trim(SubStr(A_LoopField, p + 1), """"))
    }
    if (BkStats_Info("erststart") = "") {
        FormatTime, t, , dd.MM.yyyy HH:mm
        BkStats_SetInfo("erststart", t)
    }
}

BkStats_ReadSec(sec) {
    global BK_StatsIni
    o := {}
    for i, k in BkStats_Keys() {
        IniRead, v, %BK_StatsIni%, %sec%, %k%, 0
        o[k] := (v + 0 = "") ? 0 : v + 0
    }
    return o
}

; Tag/Monat gewechselt? Dann neue Abschnitte laden.
BkStats_Rollover(force := false) {
    global g_St, g_StDay, g_StMonth
    FormatTime, d, , yyyy-MM-dd
    FormatTime, m, , yyyy-MM
    if (!force && d = g_StDay && m = g_StMonth)
        return
    if (!force)
        BkStats_Save()
    g_StDay := d, g_StMonth := m
    g_St.T := BkStats_ReadSec("T_" . d)
    g_St.M := BkStats_ReadSec("M_" . m)
}

BkStats_Add(key, n := 1) {
    global g_St, g_StDirty
    BkStats_Rollover()
    for i, s in ["G", "T", "M"] {
        o := g_St[s]
        o[key] := BkN(o[key]) + BkN(n)
    }
    g_StDirty := true
    g_StVer += 1
}

; Gesamtwert setzen (z.B. /setkills). Tag/Monat bleiben unveraendert.
BkStats_SetTotal(key, v) {
    global g_St, g_StDirty
    g_St.G[key] := BkN(v)
    g_StDirty := true
    g_StVer += 1
}

BkStats_Get(key, scope := "G") {
    global g_St
    BkStats_Rollover()
    return BkN(g_St[scope][key])
}

BkStats_Info(k) {
    global g_StInfo
    return g_StInfo.HasKey(k) ? g_StInfo[k] : ""
}

BkStats_SetInfo(k, v) {
    global g_StInfo, g_StDirty
    g_StInfo[k] := v
    g_StDirty := true
    g_StVer += 1
}

BkStats_Save() {
    global g_St, g_StInfo, g_StDay, g_StMonth, g_StDirty, BK_StatsIni
    if (g_StDay = "")
        return
    for i, k in BkStats_Keys() {
        IniWrite, % BkN(g_St.G[k]), %BK_StatsIni%, Gesamt, %k%
        IniWrite, % BkN(g_St.T[k]), %BK_StatsIni%, % "T_" . g_StDay, %k%
        IniWrite, % BkN(g_St.M[k]), %BK_StatsIni%, % "M_" . g_StMonth, %k%
    }
    for k, v in g_StInfo
        IniWrite, % """" . BkIni_Enc(v) . """", %BK_StatsIni%, Info, %k%
    g_StDirty := false
}

BkStats_Tick() {
    global g_StDirty
    BkStats_Rollover()
    if (g_StDirty)
        BkStats_Save()
}

; K/D und Differenz fuer gesamt (G), heute (T), Monat (M)
BkStats_KD(scope := "G") {
    k := BkStats_Get("kills", scope), d := BkStats_Get("tode", scope)
    return Round(k / (d > 0 ? d : 1), 2)
}

BkStats_Diff(scope := "G") {
    return BkStats_Get("kills", scope) - BkStats_Get("tode", scope)
}

BkStats_Einnahmen(scope := "G") {
    return BkStats_Get("zinsen", scope)
}

BkStats_Ausgaben(scope := "G") {
    s := 0
    for i, k in ["karte", "sprit", "miete", "copdm", "todverlust", "blitzer"]
        s += BkStats_Get(k, scope)
    return s
}

; Eine Zeile ins Finanz-Protokoll (wie finanzlog.txt in v4.60)
BkLog(file, text) {
    global BK_Dir
    FormatTime, t, , dd.MM.yyyy HH:mm:ss
    FileAppend, % "[" . t . "] " . text . "`r`n", % BK_Dir . "\" . file, UTF-8
}

; ---------------------------------------------------------------------
;  Zahlen und Zeiten huebsch
; ---------------------------------------------------------------------
BkNum(n) {
    n := Round(BkN(n))
    neg := (n < 0)
    s := RegExReplace(Abs(n), "\B(?=(\d{3})+(?!\d))", ".")
    return (neg ? "-" : "") . s
}

BkDur(sec) {
    sec := Round(BkN(sec))
    h := sec // 3600, m := Mod(sec // 60, 60)
    if (h > 0)
        return h . " Std " . m . " Min"
    return m . " Min " . Mod(sec, 60) . " Sek"
}

; ---------------------------------------------------------------------
;  Uebernahme der Statistik aus v4.x
; ---------------------------------------------------------------------
BkStats_ImportOld(cfg) {
    global g_St, BK_Dir
    so := cfg . "\sonstiges.ini", ms := cfg . "\mehrsonstiges.ini", fin := cfg . "\finanzlog.ini"
    if (!FileExist(so) && !FileExist(fin))
        return
    BkStats_Init()
    pairs := [[so, "Optionen", "Kills", "kills"], [so, "Optionen", "Tode", "tode"], [so, "Optionen", "Drogentotal", "drogen"]
        , [fin, "Finanzen", "Zinsen", "zinsen"], [fin, "Finanzen", "Karte", "karte"], [fin, "Finanzen", "Spritgeld", "sprit"]
        , [fin, "Finanzen", "Blitzer", "blitzer"], [fin, "Finanzen", "Miete", "miete"], [fin, "Finanzen", "Knastzeit", "knast"]
        , [fin, "Finanzen", "CopDM", "copdm"], [fin, "Finanzen", "Todverlust", "todverlust"]
        , [ms, "Optionen", "Wantedshack", "hacked"], [ms, "Optionen", "ErhalteneSMS", "sms_in"], [ms, "Optionen", "EigeneSMS", "sms_out"]
        , [ms, "Optionen", "Alllogins", "logins"], [ms, "Optionen", "Anwesenheit", "notafk"], [ms, "Optionen", "Missionen", "missionen"]
        , [ms, "Optionen", "Kofferraum", "kofferraum"], [ms, "Optionen", "Take", "take"], [ms, "Optionen", "Get", "get"]]
    for i, p in pairs {
        f := p[1]
        IniRead, v, %f%, % p[2], % p[3], 0
        if (v + 0 != "" && v + 0 > 0)
            g_St.G[p[4]] := v + 0
    }
    IniRead, v, %fin%, Finanzen, Kontostand, % A_Space
    if (Trim(v) != "" && Trim(v) != "ERROR")
        BkStats_SetInfo("kontostand", Trim(v))
    ; Tages- und Monatsstatistik von heute
    FormatTime, dd, , dd.MM.yyyy
    FormatTime, mm, , MMMM yyyy
    tf := BK_Dir . "\Statistiken\Tagesstatistik vom " . dd . ".ini"
    mf := BK_Dir . "\Statistiken\Monatsstatistik im " . mm . ".ini"
    for i, p in [["DKills", "kills"], ["DTode", "tode"], ["DKnastzeit", "knast"], ["DCopDM", "copdm"], ["DTodverlust", "todverlust"]
               , ["DSpritgeld", "sprit"], ["DKarte", "karte"], ["DZinsen", "zinsen"], ["DDrogen", "drogen"], ["DMiete", "miete"]] {
        IniRead, v, %tf%, Tag, % p[1], 0
        if (v + 0 > 0)
            g_St.T[p[2]] := v + 0
    }
    for i, p in [["MonatKills", "kills"], ["MonatTode", "tode"], ["MKnastzeit", "knast"], ["MCopDM", "copdm"], ["MTodverlust", "todverlust"]
               , ["MSpritgeld", "sprit"], ["MKarte", "karte"], ["MZinsen", "zinsen"], ["MDrogen", "drogen"], ["MMiete", "miete"]] {
        IniRead, v, %mf%, Monat, % p[1], 0
        if (v + 0 > 0)
            g_St.M[p[2]] := v + 0
    }
    BkStats_Save()
}
