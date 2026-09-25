; =====================================================================
;  Yakuza Keybinder - Spielerliste, eigene ID, Ping, Geld, Fahrzeug
; ---------------------------------------------------------------------
;  Alles NUR LESEND (aus dem Keybinder von Brooklyn 5.0 uebernommen).
;  Gebraucht fuer die Gegnerlisten (/<liste> = wer ist online) und fuer
;  die Platzhalter {id} {name} {ping} {level} {geld} {fzhp} {kmh}.
;
;  SA-MP-Spielerliste: Der Pool wird ueber seine Struktur gefunden
;  (YkSamp_PlrFind aus YkMemory.ahk) - es wird keine Adresse geraten.
;  Aus der Lage des Zeigerfeldes ergibt sich der Aufbau:
;    Zeigerfeld bei +0x2E -> 0.3.7-R1 (Eigene Daten VOR der Liste)
;    Zeigerfeld bei +0x04 -> 0.3.7-R2..R5 / 0.3.DL (Eigene Daten DAHINTER)
;  Jeder Wert wird auf Plausibilitaet geprueft. Passt etwas nicht, kommt
;  "unbekannt" zurueck - nie ein falscher Wert.
; =====================================================================

global g_PlrListT   := 0
global g_PlrListC   := ""     ; letzte Liste [{id, p}]
global g_PingOff    := -1     ; Ping-Feld im Spielereintrag (+0x04 oder +0x28)
global g_PlrStat    := ""     ; letzte Spielerliste: {total, named} (Diagnose)

; ---------------------------------------------------------------------
;  GTA-Werte (feste Adressen gta_sa.exe 1.0 US)
; ---------------------------------------------------------------------
YkMem_GetMoney() {
    if (!YkMem_Active())
        return ""
    return YkMem_ReadInt(0xB7CE50)
}

; Fahrzeugzustand (0..1000) oder -1
YkMem_VehicleHealth() {
    global YK_ADDR_VEHICLE_PTR
    if (!YkMem_Active())
        return -1
    veh := YkMem_ReadUInt(YK_ADDR_VEHICLE_PTR)
    if (!veh)
        return -1
    v := YkMem_ReadFloat(veh + 0x4C0)
    if (v < -2000 || v > 100000)
        return -1
    return Round(v)
}

; Geschwindigkeit in km/h oder -1
YkMem_VehicleSpeed() {
    global YK_ADDR_VEHICLE_PTR
    if (!YkMem_Active())
        return -1
    veh := YkMem_ReadUInt(YK_ADDR_VEHICLE_PTR)
    if (!veh)
        return -1
    x := YkMem_ReadFloat(veh + 0x44), y := YkMem_ReadFloat(veh + 0x48), z := YkMem_ReadFloat(veh + 0x4C)
    s := Sqrt(x * x + y * y + z * z) * 180
    return (s >= 0 && s < 1000) ? Round(s) : -1
}

; ---------------------------------------------------------------------
;  std::string aus dem Spiel lesen (MSVC: 16 Byte Puffer / Zeiger,
;  danach Laenge und Kapazitaet)
; ---------------------------------------------------------------------
YkSamp_StdString(addr) {
    global YK_hProc
    VarSetCapacity(sb, 24, 0)
    if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", addr, "Ptr", &sb, "UPtr", 24, "Ptr", 0)
        return ""
    len := NumGet(sb, 0x10, "UInt"), cap := NumGet(sb, 0x14, "UInt")
    if (len < 1 || len > 24 || cap < len || cap > 0x1000)
        return ""
    if (cap < 16) {
        s := StrGet(&sb, len, "CP1252")
    } else {
        p := NumGet(sb, 0, "UInt")
        if (p < 0x10000 || p > 0x7FF00000)
            return ""
        VarSetCapacity(nb, 32, 0)
        if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", p, "Ptr", &nb, "UPtr", len, "Ptr", 0)
            return ""
        s := StrGet(&nb, len, "CP1252")
    }
    return YkSamp_NickOk(s) ? s : ""
}

; ---------------------------------------------------------------------
;  Spielerliste mit IDs
; ---------------------------------------------------------------------
; Stellt sicher, dass der Spieler-Pool bekannt ist.
YkSamp_PoolReady() {
    global YK_PlrPool, YK_PlrOff, YK_dwPID, YK_PlrPid, YK_SampSet
    if (!YkMem_Active())
        return false
    YkSamp_InputState(ic)              ; Version bestaetigen (falls noch nicht)
    if (!IsObject(YK_SampSet))
        return false
    if (YK_PlrPid != YK_dwPID) {
        YK_PlrPid := YK_dwPID
        YkSamp_PlrReset()
    }
    if (YK_PlrPool && YK_PlrOff >= 0)
        return true
    return YkSamp_PlrFind()
}

; Alle belegten Plaetze als [{id, p}] - hoechstens einmal pro Sekunde
; neu gelesen. "" = nicht lesbar.
YkSamp_Players(force := false) {
    global YK_hProc, YK_PlrPool, YK_PlrOff, g_PlrListT, g_PlrListC
    if (!force && IsObject(g_PlrListC) && (A_TickCount - g_PlrListT) < 1000)
        return g_PlrListC
    if (!YkSamp_PoolReady())
        return ""
    VarSetCapacity(ab, 4016, 0)
    if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", YK_PlrPool + YK_PlrOff, "Ptr", &ab, "UPtr", 4016, "Ptr", 0) {
        YK_PlrPool := 0
        return ""
    }
    out := []
    Loop, 1004 {
        p := NumGet(ab, (A_Index - 1) * 4, "UInt")
        if (p >= 0x10000 && p < 0x7FF00000)
            out.Push({id: A_Index - 1, p: p})
    }
    g_PlrListC := out
    g_PlrListT := A_TickCount
    return out
}

; Name eines Listeneintrags. Erster Weg: der Aufbau aus SA-MP (Name als
; std::string bei +0x0C). Klappt der nicht, der Weg, den der Binder fuer
; die Kill-Namen selbst gelernt hat (YkSamp_LearnName in YkMemory.ahk) -
; der ist im Spiel erprobt. Beides liefert nur gueltige SA-MP-Namen.
YkSamp_PlayerNameAt(p) {
    global YK_PlrNameOff, YK_PlrNamePtr
    s := YkSamp_StdString(p + 0xC)
    if (s != "")
        return s
    if (YK_PlrNameOff >= 0)
        return YkSamp_NickAt(p + YK_PlrNameOff, YK_PlrNamePtr)
    return ""
}

; Platz des Namens nachlernen, wenn der erste Weg nicht passt (hoechstens
; alle 10 s, damit eine leere Liste nicht dauernd sucht)
YkSamp_NameLearnNow(list) {
    global YK_PlrNameOff
    static t := 0
    if (YK_PlrNameOff >= 0 || (A_TickCount - t) < 10000)
        return false
    t := A_TickCount
    ps := []
    for i, e in list
        ps.Push(e.p)
    return YkSamp_LearnName(ps)
}

; Ping-Feld lernen: in 0.3.7-R1 steht er bei +0x28 (+0x04 ist "NPC ja/nein"),
; ab R2 genau umgekehrt. Entschieden wird an echten Werten: das Feld mit
; Werten > 1 ist der Ping.
YkSamp_PingOff() {
    global g_PingOff, YK_SampSet, YK_dwPID
    static pid := 0
    if (pid != YK_dwPID) {
        pid := YK_dwPID
        g_PingOff := -1
    }
    if (g_PingOff >= 0)
        return g_PingOff
    list := YkSamp_Players()
    if (!IsObject(list) || list.MaxIndex() < 3)
        return (IsObject(YK_SampSet) && YK_SampSet.n = "0.3.7-R1") ? 0x28 : 0x04
    a := 0, b := 0, n := 0
    for i, e in list {
        if (YkMem_TryUInt(e.p + 0x04, v1) && v1 > 1 && v1 < 10000)
            a += 1
        if (YkMem_TryUInt(e.p + 0x28, v2) && v2 > 1 && v2 < 10000)
            b += 1
        n += 1
        if (n >= 30)
            break
    }
    if (a = 0 && b = 0)
        return 0x04
    g_PingOff := (a >= b) ? 0x04 : 0x28
    return g_PingOff
}

YkSamp_PlayerPingAt(p) {
    if !YkMem_TryUInt(p + YkSamp_PingOff(), v)
        return ""
    return (v < 100000) ? v : ""
}

YkSamp_PlayerScoreAt(p) {
    if !YkMem_TryUInt(p + 0x24, v)
        return ""
    v := (v > 0x7FFFFFFF) ? v - 0x100000000 : v
    return v
}

YkSamp_EntryById(id) {
    list := YkSamp_Players()
    if (!IsObject(list))
        return ""
    for i, e in list
        if (e.id = id)
            return e
    return ""
}

; Name zu ID - "" wenn nicht online / nicht lesbar
YkSamp_NameById(id) {
    if id is not integer
        return ""
    loc := YkSamp_Local()
    if (IsObject(loc) && loc.id = id && loc.name != "")
        return loc.name
    e := YkSamp_EntryById(id)
    return IsObject(e) ? YkSamp_PlayerNameAt(e.p) : ""
}

; ID zu Name (Gross/klein egal) - -1 wenn nicht online
YkSamp_IdByName(name) {
    name := Trim(name)
    if (name = "")
        return -1
    loc := YkSamp_Local()
    if (IsObject(loc) && loc.name = name)
        return loc.id
    list := YkSamp_Players()
    if (!IsObject(list))
        return -1
    for i, e in list
        if (YkSamp_PlayerNameAt(e.p) = name)
            return e.id
    return -1
}

; Alle Spieler als [{id, name, score, ping}] (fuer Gegnerlisten).
; g_PlrStat haelt fest, wie viele Eintraege es gab und wie viele Namen
; lesbar waren - so meldet der Binder "Namen nicht lesbar" statt
; "niemand online".
YkSamp_PlayerTable() {
    global g_PlrStat
    list := YkSamp_Players()
    if (!IsObject(list)) {
        g_PlrStat := ""
        return ""
    }
    out := YkSamp_PlayerTableOf(list)
    ; mehr als die Haelfte ohne Namen: anderen Weg lernen und neu lesen
    if (list.MaxIndex() >= 2 && YkCnt(out) * 2 < list.MaxIndex() && YkSamp_NameLearnNow(list))
        out := YkSamp_PlayerTableOf(list)
    g_PlrStat := {total: YkCnt(list), named: YkCnt(out), t: A_TickCount}
    YkDbg("Spielerliste: " . g_PlrStat.total . " Eintraege, " . g_PlrStat.named . " Namen lesbar")
    return out
}

; fuer die Diagnose-Seite
YkSamp_PlrStatText() {
    global g_PlrStat
    if (!IsObject(g_PlrStat))
        return "noch nicht gelesen (einmal Online prüfen)"
    return g_PlrStat.total . " Spieler, " . g_PlrStat.named . " Namen lesbar"
}

YkSamp_PlayerTableOf(list) {
    out := []
    for i, e in list {
        nm := YkSamp_PlayerNameAt(e.p)
        if (nm = "")
            continue
        out.Push({id: e.id, name: nm, score: YkSamp_PlayerScoreAt(e.p), ping: YkSamp_PlayerPingAt(e.p)})
    }
    return out
}

; Spieler zu einem eingegebenen Namen (Gross/klein egal):
;   {name, id} bei genau einem Treffer - erst ganzer Name, sonst Teil
;   des Namens ("Kenji" -> Kenji_Sato)
;   {many: [Namen]} wenn mehrere passen
;   {none: 1}   wenn keiner online passt
;   ""          wenn die Liste nicht lesbar ist
YkSamp_FindPlayer(input) {
    input := Trim(input)
    tbl := YkSamp_PlayerTable()
    if (!IsObject(tbl))
        return ""
    loc := YkSamp_Local()
    if (IsObject(loc) && loc.name != "")
        tbl.Push({id: loc.id, name: loc.name, self: true})
    part := []
    for i, p in tbl {
        if (p.name = input)
            return p
        if InStr(p.name, input)
            part.Push(p)
    }
    if (part.MaxIndex() = 1)
        return part[1]
    if (part.MaxIndex() > 1) {
        names := []
        for i, p in part
            names.Push(p.name)
        return {many: names}
    }
    return {none: 1}
}

YkSamp_OnlineCount() {
    list := YkSamp_Players()
    return IsObject(list) ? YkCnt(list) + 1 : ""
}

; ---------------------------------------------------------------------
;  Eigene Daten: ID, Name, Ping, Level
; ---------------------------------------------------------------------
; Liefert {id, name, ping, score} oder "" (nicht lesbar)
YkSamp_Local() {
    global YK_PlrPool, YK_PlrOff, YK_hProc
    static cache := "", cacheT := 0
    if (IsObject(cache) && (A_TickCount - cacheT) < 1000)
        return cache
    cache := ""
    cacheT := A_TickCount
    if (!YkSamp_PoolReady())
        return ""
    if (YK_PlrOff = 0x2E) {             ; 0.3.7-R1
        oId := 0x4, oName := 0xA, oPing := 0x26, oScore := 0x2A
    } else if (YK_PlrOff = 0x4) {       ; 0.3.7-R2 .. R5, 0.3.DL
        base := 0x4 + 3 * 4016
        oPing := base, oScore := base + 4, oId := base + 8, oName := base + 0xE
    } else {
        return ""
    }
    VarSetCapacity(b, 4, 0)
    if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", YK_PlrPool + oId, "Ptr", &b, "UPtr", 2, "Ptr", 0)
        return ""
    id := NumGet(b, 0, "UShort")
    if (id > 1003)
        return ""
    name := YkSamp_StdString(YK_PlrPool + oName)
    if (name = "")
        name := YkSamp_RegistryName()
    ping := "", score := ""
    if (YkMem_TryUInt(YK_PlrPool + oPing, v) && v < 100000)
        ping := v
    if (YkMem_TryUInt(YK_PlrPool + oScore, v2) && v2 < 0x7FFFFFFF)
        score := v2
    cache := {id: id, name: name, ping: ping, score: score}
    return cache
}

; Name, mit dem sich SA-MP zuletzt verbunden hat (vom normalen SA-MP-
; Starter in der Registry abgelegt)
YkSamp_RegistryName() {
    RegRead, n, HKEY_CURRENT_USER, Software\SAMP, PlayerName
    n := Trim(n)
    return YkSamp_NickOk(n) ? n : ""
}
