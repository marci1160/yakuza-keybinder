; =====================================================================
;  Brooklyn Keybinder - Ersatz fuer die Funktionen der alten Brooklyn.dll
; ---------------------------------------------------------------------
;  Alles NUR LESEND. Was die DLL frueher per Injection geliefert hat
;  (GetPlayerId, GetPlayerNameById, GetPlayerScoreById, GetPlayerPing,
;  GetPlayerMoney, GetPlayerWanteds, GetVehicleHealth, Gametext ...),
;  wird hier direkt aus dem Speicher von gta_sa.exe bzw. samp.dll gelesen.
;
;  SA-MP-Spielerliste: Der Pool wird ueber seine Struktur gefunden
;  (BkSamp_PlrFind aus BkMemory.ahk) - es wird keine Adresse geraten.
;  Aus der Lage des Zeigerfeldes ergibt sich der Aufbau:
;    Zeigerfeld bei +0x2E -> 0.3.7-R1 (Eigene Daten VOR der Liste)
;    Zeigerfeld bei +0x04 -> 0.3.7-R2..R5 / 0.3.DL (Eigene Daten DAHINTER)
;  Jeder Wert wird auf Plausibilitaet geprueft. Passt etwas nicht, kommt
;  "unbekannt" zurueck - nie ein falscher Wert.
; =====================================================================

global g_PlrListT   := 0
global g_PlrListC   := ""     ; letzte Liste [{id, p}]
global g_PingOff    := -1     ; Ping-Feld im Spielereintrag (+0x04 oder +0x28)

; ---------------------------------------------------------------------
;  GTA-Werte (feste Adressen gta_sa.exe 1.0 US)
; ---------------------------------------------------------------------
BkMem_GetMoney() {
    if (!BkMem_Active())
        return ""
    return BkMem_ReadInt(0xB7CE50)
}

; Wantedlevel der Spielfigur (Sterne) oder -1
BkMem_GetWanteds() {
    global BK_ADDR_CPED_PTR
    if (!BkMem_Active())
        return -1
    ped := BkMem_ReadUInt(BK_ADDR_CPED_PTR)
    if (!ped || !BkMem_TryUInt(ped + 0x480, pd) || pd < 0x10000)
        return -1
    if (!BkMem_TryUInt(pd, pw) || pw < 0x10000)
        return -1
    if (!BkMem_TryUInt(pw + 0x2C, w) || w > 6)
        return -1
    return w
}

; Zustand der eigenen Figur: 54 = stirbt, 55 = tot
BkMem_PedState() {
    global BK_ADDR_CPED_PTR
    if (!BkMem_Active())
        return -1
    ped := BkMem_ReadUInt(BK_ADDR_CPED_PTR)
    if (!ped || !BkMem_TryUInt(ped + 0x530, st))
        return -1
    return st
}

BkMem_IsDead() {
    st := BkMem_PedState()
    if (st = 54 || st = 55)
        return true
    hp := BkMem_GetHealth()
    return (hp = 0)
}

; Fahrzeugzustand (0..1000) oder -1
BkMem_VehicleHealth() {
    global BK_ADDR_VEHICLE_PTR
    if (!BkMem_Active())
        return -1
    veh := BkMem_ReadUInt(BK_ADDR_VEHICLE_PTR)
    if (!veh)
        return -1
    v := BkMem_ReadFloat(veh + 0x4C0)
    if (v < -2000 || v > 100000)
        return -1
    return Round(v)
}

; Geschwindigkeit in km/h oder -1
BkMem_VehicleSpeed() {
    global BK_ADDR_VEHICLE_PTR
    if (!BkMem_Active())
        return -1
    veh := BkMem_ReadUInt(BK_ADDR_VEHICLE_PTR)
    if (!veh)
        return -1
    x := BkMem_ReadFloat(veh + 0x44), y := BkMem_ReadFloat(veh + 0x48), z := BkMem_ReadFloat(veh + 0x4C)
    s := Sqrt(x * x + y * y + z * z) * 180
    return (s >= 0 && s < 1000) ? Round(s) : -1
}

; ---------------------------------------------------------------------
;  GameText (grosse Bildschirmtexte, z.B. "~g~Gangwarkill")
; ---------------------------------------------------------------------
; Frueher lieferte die Zusatzdatei getGametext.dll diese Texte. GTA
; speichert sie in CMessages::BIGMessages (7 Stile, je 4 Eintraege a
; 0x2C Byte): +0 Zeiger auf den Text, +0xC Startzeit. Gelesen wird nur
; der oberste Eintrag je Stil. Liefert [{style, text, start}].
BkMem_GameTexts() {
    global BK_hProc
    out := []
    if (!BkMem_Active())
        return out
    VarSetCapacity(b, 0xB0 * 7, 0)
    if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", 0xC1A970, "Ptr", &b, "UPtr", 0xB0 * 7, "Ptr", 0)
        return out
    VarSetCapacity(tb, 260, 0)
    Loop, 7 {
        o := (A_Index - 1) * 0xB0
        p := NumGet(b, o, "UInt")
        if (p < 0x10000 || p > 0x7FF00000)
            continue
        if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", p, "Ptr", &tb, "UPtr", 255, "Ptr", 0)
            continue
        NumPut(0, tb, 255, "UChar")
        s := StrGet(&tb, 255, "CP1252")
        if (StrLen(s) < 2 || !BkSamp_TextPrintable(s))
            continue
        out.Push({style: A_Index - 1, text: s, start: NumGet(b, o + 0xC, "UInt")})
    }
    return out
}

BkSamp_TextPrintable(s) {
    Loop, Parse, s
    {
        c := Asc(A_LoopField)
        if (c < 0x20 && c != 9 && c != 10 && c != 13)
            return false
    }
    return true
}

; ---------------------------------------------------------------------
;  std::string aus dem Spiel lesen (MSVC: 16 Byte Puffer / Zeiger,
;  danach Laenge und Kapazitaet)
; ---------------------------------------------------------------------
BkSamp_StdString(addr) {
    global BK_hProc
    VarSetCapacity(sb, 24, 0)
    if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", addr, "Ptr", &sb, "UPtr", 24, "Ptr", 0)
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
        if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", p, "Ptr", &nb, "UPtr", len, "Ptr", 0)
            return ""
        s := StrGet(&nb, len, "CP1252")
    }
    return BkSamp_NickOk(s) ? s : ""
}

; ---------------------------------------------------------------------
;  Spielerliste mit IDs
; ---------------------------------------------------------------------
; Stellt sicher, dass der Spieler-Pool bekannt ist.
BkSamp_PoolReady() {
    global BK_PlrPool, BK_PlrOff, BK_dwPID, BK_PlrPid, BK_SampSet
    if (!BkMem_Active())
        return false
    BkSamp_InputState(ic)              ; Version bestaetigen (falls noch nicht)
    if (!IsObject(BK_SampSet))
        return false
    if (BK_PlrPid != BK_dwPID) {
        BK_PlrPid := BK_dwPID
        BkSamp_PlrReset()
    }
    if (BK_PlrPool && BK_PlrOff >= 0)
        return true
    return BkSamp_PlrFind()
}

; Alle belegten Plaetze als [{id, p}] - hoechstens einmal pro Sekunde
; neu gelesen. "" = nicht lesbar.
BkSamp_Players(force := false) {
    global BK_hProc, BK_PlrPool, BK_PlrOff, g_PlrListT, g_PlrListC
    if (!force && IsObject(g_PlrListC) && (A_TickCount - g_PlrListT) < 1000)
        return g_PlrListC
    if (!BkSamp_PoolReady())
        return ""
    VarSetCapacity(ab, 4016, 0)
    if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", BK_PlrPool + BK_PlrOff, "Ptr", &ab, "UPtr", 4016, "Ptr", 0) {
        BK_PlrPool := 0
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

BkSamp_PlayerNameAt(p) {
    return BkSamp_StdString(p + 0xC)
}

; Ping-Feld lernen: in 0.3.7-R1 steht er bei +0x28 (+0x04 ist "NPC ja/nein"),
; ab R2 genau umgekehrt. Entschieden wird an echten Werten: das Feld mit
; Werten > 1 ist der Ping.
BkSamp_PingOff() {
    global g_PingOff, BK_SampSet, BK_dwPID
    static pid := 0
    if (pid != BK_dwPID) {
        pid := BK_dwPID
        g_PingOff := -1
    }
    if (g_PingOff >= 0)
        return g_PingOff
    list := BkSamp_Players()
    if (!IsObject(list) || list.MaxIndex() < 3)
        return (IsObject(BK_SampSet) && BK_SampSet.n = "0.3.7-R1") ? 0x28 : 0x04
    a := 0, b := 0, n := 0
    for i, e in list {
        if (BkMem_TryUInt(e.p + 0x04, v1) && v1 > 1 && v1 < 10000)
            a += 1
        if (BkMem_TryUInt(e.p + 0x28, v2) && v2 > 1 && v2 < 10000)
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

BkSamp_PlayerPingAt(p) {
    if !BkMem_TryUInt(p + BkSamp_PingOff(), v)
        return ""
    return (v < 100000) ? v : ""
}

BkSamp_PlayerScoreAt(p) {
    if !BkMem_TryUInt(p + 0x24, v)
        return ""
    v := (v > 0x7FFFFFFF) ? v - 0x100000000 : v
    return v
}

BkSamp_EntryById(id) {
    list := BkSamp_Players()
    if (!IsObject(list))
        return ""
    for i, e in list
        if (e.id = id)
            return e
    return ""
}

; Name zu ID - "" wenn nicht online / nicht lesbar
BkSamp_NameById(id) {
    if id is not integer
        return ""
    loc := BkSamp_Local()
    if (IsObject(loc) && loc.id = id && loc.name != "")
        return loc.name
    e := BkSamp_EntryById(id)
    return IsObject(e) ? BkSamp_PlayerNameAt(e.p) : ""
}

; ID zu Name (Gross/klein egal) - -1 wenn nicht online
BkSamp_IdByName(name) {
    name := Trim(name)
    if (name = "")
        return -1
    loc := BkSamp_Local()
    if (IsObject(loc) && loc.name = name)
        return loc.id
    list := BkSamp_Players()
    if (!IsObject(list))
        return -1
    for i, e in list
        if (BkSamp_PlayerNameAt(e.p) = name)
            return e.id
    return -1
}

; Alle Spieler als [{id, name, score, ping}] (fuer Gegnerlisten)
BkSamp_PlayerTable() {
    out := []
    list := BkSamp_Players()
    if (!IsObject(list))
        return ""
    for i, e in list {
        nm := BkSamp_PlayerNameAt(e.p)
        if (nm = "")
            continue
        out.Push({id: e.id, name: nm, score: BkSamp_PlayerScoreAt(e.p), ping: BkSamp_PlayerPingAt(e.p)})
    }
    return out
}

BkSamp_OnlineCount() {
    list := BkSamp_Players()
    return IsObject(list) ? BkCnt(list) + 1 : ""
}

; ---------------------------------------------------------------------
;  Eigene Daten: ID, Name, Ping, Level
; ---------------------------------------------------------------------
; Liefert {id, name, ping, score} oder "" (nicht lesbar)
BkSamp_Local() {
    global BK_PlrPool, BK_PlrOff, BK_hProc
    static cache := "", cacheT := 0
    if (IsObject(cache) && (A_TickCount - cacheT) < 1000)
        return cache
    cache := ""
    cacheT := A_TickCount
    if (!BkSamp_PoolReady())
        return ""
    if (BK_PlrOff = 0x2E) {             ; 0.3.7-R1
        oId := 0x4, oName := 0xA, oPing := 0x26, oScore := 0x2A
    } else if (BK_PlrOff = 0x4) {       ; 0.3.7-R2 .. R5, 0.3.DL
        base := 0x4 + 3 * 4016
        oPing := base, oScore := base + 4, oId := base + 8, oName := base + 0xE
    } else {
        return ""
    }
    VarSetCapacity(b, 4, 0)
    if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", BK_PlrPool + oId, "Ptr", &b, "UPtr", 2, "Ptr", 0)
        return ""
    id := NumGet(b, 0, "UShort")
    if (id > 1003)
        return ""
    name := BkSamp_StdString(BK_PlrPool + oName)
    if (name = "")
        name := BkSamp_RegistryName()
    ping := "", score := ""
    if (BkMem_TryUInt(BK_PlrPool + oPing, v) && v < 100000)
        ping := v
    if (BkMem_TryUInt(BK_PlrPool + oScore, v2) && v2 < 0x7FFFFFFF)
        score := v2
    cache := {id: id, name: name, ping: ping, score: score}
    return cache
}

; Name, mit dem sich SA-MP zuletzt verbunden hat (vom normalen SA-MP-
; Starter in der Registry abgelegt)
BkSamp_RegistryName() {
    RegRead, n, HKEY_CURRENT_USER, Software\SAMP, PlayerName
    n := Trim(n)
    return BkSamp_NickOk(n) ? n : ""
}
