; =====================================================================
;  Brooklyn Keybinder - Speicher-Modul (NUR LESEND / READ-ONLY)
;  Ersetzt die fruehere Brooklyn.dll (SA-MP-API, die es nicht mehr gibt).
;  Technik uebernommen aus dem Yakuza Keybinder (live geprueft).
; ---------------------------------------------------------------------
;  Liest Position, Leben, Fahrzeug, Waffen und die Figuren in der Naehe
;  aus gta_sa.exe (Version 1.0 US). Dieses Modul schreibt NICHTS in den
;  Speicher und injiziert NICHTS; der Prozess wird nur mit den minimalen
;  Rechten PROCESS_VM_READ | PROCESS_QUERY_INFORMATION geoeffnet. Alle
;  Adressen sind feste gta_sa.exe-Adressen und damit unabhaengig von der
;  SA-MP / open.mp Version.
; =====================================================================

; --- feste gta_sa.exe (1.0 US) Adressen ---
global BK_ADDR_POS_X       := 0xB6F2E4
global BK_ADDR_POS_Y       := 0xB6F2E8
global BK_ADDR_POS_Z       := 0xB6F2EC
global BK_ADDR_CPED_PTR    := 0xB6F5F0
global BK_ADDR_CPED_HP     := 0x540
global BK_ADDR_CPED_ARMOR  := 0x548
global BK_ADDR_VEHICLE_PTR := 0xBA18FC
global BK_ADDR_INTERIOR    := 0xA4ACE8
global BK_ADDR_VEHICLE_MODEL := 0x22

; Fahrzeug-Modellnamen, Index = ModelID - 399 (gueltig fuer ModelID 400..610)
global BK_VehicleNames := ["Landstalker","Bravura","Buffalo","Linerunner","Perrenial","Sentinel","Dumper","Firetruck","Trashmaster","Stretch","Manana","Infernus","Voodoo","Pony","Mule","Cheetah","Ambulance","Leviathan","Moonbeam","Esperanto","Taxi","Washington","Bobcat","Whoopee","BFInjection","Hunter","Premier","Enforcer","Securicar","Banshee","Predator","Bus","Rhino","Barracks","Hotknife","Trailer","Previon","Coach","Cabbie","Stallion","Rumpo","RCBandit","Romero","Packer","Monster","Admiral","Squalo","Seasparrow","Pizzaboy","Tram","Trailer","Turismo","Speeder","Reefer","Tropic","Flatbed","Yankee","Caddy","Solair","Berkley's RC Van","Skimmer","PCJ-600","Faggio","Freeway","RC Baron","RC Raider","Glendale","Oceanic","Sanchez","Sparrow","Patriot","Quad","Coastguard","Dinghy","Hermes","Sabre","Rustler","ZR-350","Walton","Regina","Comet","BMX","Burrito","Camper","Marquis","Baggage","Dozer","Maverick","News Chopper","Rancher","FBI Rancher","Virgo","Greenwood","Jetmax","Hotring","Sandking","Blista Compact","Police Maverick","Boxville","Benson","Mesa","RC Goblin","Hotring Racer A","Hotring Racer B","Bloodring Banger","Rancher","Super GT","Elegant","Journey","Bike","Mountain Bike","Beagle","Cropduster","Stunt","Tanker","Roadtrain","Nebula","Majestic","Buccaneer","Shamal","Hydra","FCR-900","NRG-500","HPV1000","Cement Truck","Tow Truck","Fortune","Cadrona","FBI Truck","Willard","Forklift","Tractor","Combine","Feltzer","Remington","Slamvan","Blade","Freight","Streak","Vortex","Vincent","Bullet","Clover","Sadler","Firetruck","Hustler","Intruder","Primo","Cargobob","Tampa","Sunrise","Merit","Utility","Nevada","Yosemite","Windsor","Monster","Monster","Uranus","Jester","Sultan","Stratum","Elegy","Raindance","RC Tiger","Flash","Tahoma","Savanna","Bandito","Freight Flat","Streak Carriage","Kart","Mower","Dune","Sweeper","Broadway","Tornado","AT-400","DFT-30","Huntley","Stafford","BF-400","News Van","Tug","Trailer","Emperor","Wayfarer","Euros","Hotdog","Club","Freight Box","Trailer","Andromada","Dodo","RC Cam","Launch","Police Car","Police Car","Police Car","Police Ranger","Picador","S.W.A.T.","Alpha","Phoenix","Glendale (Beschaedigt)","Sadler (Beschaedigt)","Luggage","Luggage","Stairs","Boxville","Tiller","Utility Trailer"]

; --- interner Zustand ---
global BK_hProc  := 0
global BK_dwPID  := 0
global BK_memOK  := false

; ---------------------------------------------------------------------
;  Spielfenster finden - gecacht
; ---------------------------------------------------------------------
; WinActive/WinExist mit "ahk_exe ..." muss jedes Mal alle Fenster
; durchgehen und zu jedem den Programmnamen ermitteln. Das stand frueher
; in Timern, die alle 15-80 ms laufen (Sprint, Tastenwaechter, Kill-
; Erkennung) - also hunderte Male pro Sekunde. Jetzt wird das Fenster
; einmal gesucht und gemerkt; danach genuegt der Vergleich mit dem
; Vordergrundfenster.
global g_GameHwnd  := 0
global g_GamePid   := 0
global g_GameFindT := 0

BkGame_Hwnd() {
    global g_GameHwnd, g_GamePid, g_GameFindT
    if (g_GameHwnd) {
        if DllCall("IsWindow", "Ptr", g_GameHwnd)
            return g_GameHwnd
        g_GameHwnd := 0
        g_GamePid := 0
    }
    ; nicht gefunden -> hoechstens zweimal pro Sekunde neu suchen
    if ((A_TickCount - g_GameFindT) < 500)
        return 0
    g_GameFindT := A_TickCount
    h := 0
    for i, exe in BkGame_ExeList() {
        h := WinExist("ahk_exe " . exe)
        if (h)
            break
    }
    if (h) {
        WinGet, pid, PID, ahk_id %h%
        g_GameHwnd := h
        g_GamePid := pid + 0
    }
    return g_GameHwnd
}

; Spielprozesse, auf die der Binder hoert. Standard ist das normale
; SA-MP (gta_sa.exe); in den Einstellungen lassen sich weitere Namen
; eintragen (z.B. rgn_ac_gta.exe fuer den alten RGN-Launcher).
BkGame_ExeList() {
    global BK_GameExes
    static cache := "", src := "#"
    if (src == BK_GameExes && IsObject(cache))
        return cache
    src := BK_GameExes
    cache := ["gta_sa.exe"]
    for i, e in StrSplit(BK_GameExes, ",") {
        e := Trim(e)
        if (e != "" && e != "gta_sa.exe")
            cache.Push(e)
    }
    return cache
}

BkGame_Pid() {
    global g_GamePid
    BkGame_Hwnd()
    return g_GamePid
}

; Ist das Spiel das Vordergrundfenster? Liefert dessen Fenster-Kennung
; (wie frueher WinActive) oder 0 - damit ueberall einsetzbar.
BkGame_Active() {
    pid := BkGame_Pid()
    if (!pid)
        return 0
    fg := DllCall("GetForegroundWindow", "Ptr")
    if (!fg)
        return 0
    fpid := 0
    DllCall("GetWindowThreadProcessId", "Ptr", fg, "UIntP", fpid)
    return (fpid = pid) ? fg : 0
}

; Laeuft GTA im ECHTEN Vollbild (Direct3D im Vollbildmodus)?
;
; Dort darf der Binder KEIN eigenes Fenster erzeugen: jedes neue Fenster,
; das immer oben liegen soll, zwingt Direct3D zu einem Geraete-Neustart -
; das sind die Sekunden, in denen das ganze Bild steht.
;
; Wichtig ist der Unterschied zum RANDLOSEN FENSTER: das sieht genauso aus
; (bildschirmfuellend, kein Rahmen), ist aber ein ganz normales Fenster -
; dort funktioniert das Overlay einwandfrei. Nach Groesse und Rahmen kann
; man die beiden also nicht auseinanderhalten.
; Windows selbst weiss es: SHQueryUserNotificationState meldet den Wert 3
; (QUNS_RUNNING_D3D_FULL_SCREEN), solange eine Anwendung im echten
; Vollbild laeuft - dieselbe Abfrage, mit der Windows Benachrichtigungen
; unterdrueckt.
;
; Einmal erkannt, bleibt es fuer diesen Spielstart dabei: beim Wechseln
; zum Desktop meldet Windows kurz etwas anderes, und ein in dieser Luecke
; gebautes Fenster wuerde beim Zurueckwechseln denselben Aussetzer
; ausloesen.
BkGame_Fullscreen() {
    global g_GamePid
    static seenPid := 0, lastT := 0
    h := BkGame_Hwnd()
    if (!h) {
        seenPid := 0
        return false
    }
    if (seenPid && seenPid = g_GamePid)
        return true
    if (seenPid && seenPid != g_GamePid)
        seenPid := 0
    if ((A_TickCount - lastT) < 1000)
        return false
    lastT := A_TickCount
    ; nur pruefen, wenn das Spiel wirklich vorne ist
    if (!BkGame_Active())
        return false
    st := 0
    if (DllCall("shell32\SHQueryUserNotificationState", "IntP", st) != 0)
        return false
    if (st = 3) {                      ; QUNS_RUNNING_D3D_FULL_SCREEN
        seenPid := g_GamePid
        return true
    }
    return false
}

; Prozess-Handle sicherstellen (bei Bedarf oeffnen / neu oeffnen)
BkMem_Ensure() {
    global BK_hProc, BK_dwPID, BK_memOK
    pid := BkGame_Pid()
    if (!pid) {
        if (BK_hProc) {
            DllCall("CloseHandle", "Ptr", BK_hProc)
            BK_hProc := 0
        }
        BK_dwPID := 0
        BK_memOK := false
        return false
    }
    if (!BK_hProc || BK_dwPID != pid) {
        if (BK_hProc)
            DllCall("CloseHandle", "Ptr", BK_hProc)
        ; 0x0010 = PROCESS_VM_READ, 0x0400 = PROCESS_QUERY_INFORMATION
        BK_hProc := DllCall("OpenProcess", "UInt", 0x0010|0x0400, "Int", 0, "UInt", pid, "Ptr")
        if (!BK_hProc) {
            BK_dwPID := 0
            BK_memOK := false
            return false
        }
        BK_dwPID := pid
    }
    BK_memOK := true
    return true
}

BkMem_Close() {
    global BK_hProc, BK_dwPID, BK_memOK
    if (BK_hProc)
        DllCall("CloseHandle", "Ptr", BK_hProc)
    BK_hProc := 0
    BK_dwPID := 0
    BK_memOK := false
}

; liefert true wenn gerade lesbar
BkMem_Active() {
    global BK_memOK
    return BK_memOK
}

BkMem_ReadUInt(addr) {
    global BK_hProc
    if (!BK_hProc)
        return 0
    VarSetCapacity(buf, 4, 0)
    ok := DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", addr, "Ptr", &buf, "UPtr", 4, "UPtr*", read)
    if (!ok)
        return 0
    return NumGet(buf, 0, "UInt")
}

BkMem_ReadInt(addr) {
    global BK_hProc
    if (!BK_hProc)
        return 0
    VarSetCapacity(buf, 4, 0)
    ok := DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", addr, "Ptr", &buf, "UPtr", 4, "UPtr*", read)
    if (!ok)
        return 0
    return NumGet(buf, 0, "Int")
}

BkMem_ReadFloat(addr) {
    global BK_hProc
    if (!BK_hProc)
        return 0.0
    VarSetCapacity(buf, 4, 0)
    ok := DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", addr, "Ptr", &buf, "UPtr", 4, "UPtr*", read)
    if (!ok)
        return 0.0
    return NumGet(buf, 0, "Float")
}

; Position als Objekt {x,y,z} oder "" bei Fehler / ungueltig
BkMem_GetPosition() {
    global BK_ADDR_POS_X, BK_ADDR_POS_Y, BK_ADDR_POS_Z
    if (!BkMem_Active())
        return ""
    x := BkMem_ReadFloat(BK_ADDR_POS_X)
    y := BkMem_ReadFloat(BK_ADDR_POS_Y)
    z := BkMem_ReadFloat(BK_ADDR_POS_Z)
    ; Plausibilitaet: SA-Welt liegt etwa in +/-3500
    if (x = 0 && y = 0 && z = 0)
        return ""
    if (x < -4000 || x > 4000 || y < -4000 || y > 4000)
        return ""
    return {x: x, y: y, z: z}
}

; Leben (0..100+) oder -1 bei Fehler
BkMem_GetHealth() {
    global BK_ADDR_CPED_PTR, BK_ADDR_CPED_HP
    if (!BkMem_Active())
        return -1
    ped := BkMem_ReadUInt(BK_ADDR_CPED_PTR)
    if (!ped)
        return -1
    hp := BkMem_ReadFloat(ped + BK_ADDR_CPED_HP)
    return Round(hp)
}

; Ruestung (0..100+) oder -1 bei Fehler
BkMem_GetArmor() {
    global BK_ADDR_CPED_PTR, BK_ADDR_CPED_ARMOR
    if (!BkMem_Active())
        return -1
    ped := BkMem_ReadUInt(BK_ADDR_CPED_PTR)
    if (!ped)
        return -1
    ar := BkMem_ReadFloat(ped + BK_ADDR_CPED_ARMOR)
    return Round(ar)
}

; true = im Fahrzeug, false = zu Fuss, -1 unbekannt
BkMem_InVehicle() {
    global BK_ADDR_VEHICLE_PTR
    if (!BkMem_Active())
        return -1
    veh := BkMem_ReadUInt(BK_ADDR_VEHICLE_PTR)
    return (veh > 0) ? true : false
}

; Fahrzeug-ModellID (400..611) oder 0 wenn nicht im Fahrzeug/Fehler
BkMem_GetVehicleModelId() {
    global BK_ADDR_VEHICLE_PTR, BK_ADDR_VEHICLE_MODEL
    if (!BkMem_Active())
        return 0
    veh := BkMem_ReadUInt(BK_ADDR_VEHICLE_PTR)
    if (!veh)
        return 0
    VarSetCapacity(buf, 2, 0)
    global BK_hProc
    ok := DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", veh + BK_ADDR_VEHICLE_MODEL, "Ptr", &buf, "UPtr", 2, "UPtr*", read)
    if (!ok)
        return 0
    return NumGet(buf, 0, "UShort")
}

; Klarname des aktuellen Fahrzeugs oder "" wenn nicht im Fahrzeug/unbekannt
BkMem_GetVehicleName() {
    global BK_VehicleNames
    id := BkMem_GetVehicleModelId()
    if (id < 400 || id > 611)
        return ""
    idx := id - 399
    if (idx < 1 || idx > BK_VehicleNames.MaxIndex())
        return ""
    return BK_VehicleNames[idx]
}

BkMem_GetInterior() {
    global BK_ADDR_INTERIOR
    if (!BkMem_Active())
        return -1
    return BkMem_ReadInt(BK_ADDR_INTERIOR)
}

; Wie BkMem_ReadUInt, unterscheidet aber "Wert 0" von "nicht lesbar".
BkMem_TryUInt(addr, ByRef val) {
    global BK_hProc
    val := 0
    if (!BK_hProc || addr < 0x10000)
        return false
    VarSetCapacity(buf, 4, 0)
    if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", addr, "Ptr", &buf, "UPtr", 4, "Ptr", 0)
        return false
    val := NumGet(buf, 0, "UInt")
    return true
}

; Dasselbe fuer ein einzelnes Byte (Zustandsbits der Figuren)
BkMem_TryUChar(addr, ByRef val) {
    global BK_hProc
    val := 0
    if (!BK_hProc || addr < 0x10000)
        return false
    VarSetCapacity(buf, 1, 0)
    if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", addr, "Ptr", &buf, "UPtr", 1, "Ptr", 0)
        return false
    val := NumGet(buf, 0, "UChar")
    return true
}

; ---------------------------------------------------------------------
;  Fuer die Kill-Erkennung (feste gta_sa.exe-Adressen, live geprueft)
; ---------------------------------------------------------------------
; Aktive Waffe des eigenen Spielers: Typ und Gesamtmunition
BkMem_ActiveWeapon(ByRef wType, ByRef ammo) {
    global BK_hProc, BK_ADDR_CPED_PTR
    wType := -1
    ammo := -1
    if (!BkMem_Active())
        return false
    ped := BkMem_ReadUInt(BK_ADDR_CPED_PTR)
    if (!ped)
        return false
    VarSetCapacity(sb, 1, 0)
    if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", ped + 0x718, "Ptr", &sb, "UPtr", 1, "Ptr", 0)
        return false
    slot := NumGet(sb, 0, "UChar")
    if (slot > 12)
        return false
    VarSetCapacity(wb, 0x10, 0)
    if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", ped + 0x5A0 + slot * 0x1C, "Ptr", &wb, "UPtr", 0x10, "Ptr", 0)
        return false
    wType := NumGet(wb, 0, "Int")
    ammo := NumGet(wb, 0xC, "Int")
    return true
}

; Kamera: Blickrichtung (0xB6F9AC) und Position (0xB6F9CC)
BkMem_Camera() {
    global BK_hProc
    if (!BkMem_Active())
        return ""
    VarSetCapacity(cb, 0x2C, 0)
    if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", 0xB6F9AC, "Ptr", &cb, "UPtr", 0x2C, "Ptr", 0)
        return ""
    fx := NumGet(cb, 0, "Float"), fy := NumGet(cb, 4, "Float"), fz := NumGet(cb, 8, "Float")
    l := Sqrt(fx * fx + fy * fy + fz * fz)
    if (l < 0.5 || l > 1.5)
        return ""
    return {fx: fx / l, fy: fy / l, fz: fz / l
        , cx: NumGet(cb, 0x20, "Float"), cy: NumGet(cb, 0x24, "Float"), cz: NumGet(cb, 0x28, "Float")}
}

; Zeiger auf die eigene Figur und das eigene Fahrzeug (0 = keins)
BkMem_OwnPtrs(ByRef ped, ByRef veh) {
    global BK_ADDR_CPED_PTR, BK_ADDR_VEHICLE_PTR
    ped := BkMem_Active() ? BkMem_ReadUInt(BK_ADDR_CPED_PTR) : 0
    veh := BkMem_Active() ? BkMem_ReadUInt(BK_ADDR_VEHICLE_PTR) : 0
}

; Wer hat MICH zuletzt verletzt? Zeiger auf Figur oder Fahrzeug, 0 = unbekannt.
;
; Es ist genau dasselbe Feld, das BkMem_Peds fuer fremde Figuren mitliest
; (CPed + 0x764, "letzter Schadensverursacher") - nur eben an der eigenen
; Figur. Daraus wird der Name des Moerders: der Zeiger wandert durch
; BkSamp_NameForPed in die SA-MP-Spielerliste.
BkMem_LastDamager() {
    global BK_ADDR_CPED_PTR
    if (!BkMem_Active())
        return 0
    ped := BkMem_ReadUInt(BK_ADDR_CPED_PTR)
    if (!ped)
        return 0
    if !BkMem_TryUInt(ped + 0x764, v)
        return 0
    return (v > 0x10000) ? v : 0
}

; Feuert die EIGENE Figur gerade? (CPed + 0x46E, Bit 1)
;
; Genau dasselbe Feld, das BkMem_Peds fuer fremde Figuren mitliest. Es ist
; die einzige Schuss-Auskunft, die unabhaengig von der Munition ist:
; auf Servern mit unbegrenzter Munition sinkt der Munitionszaehler nie,
; und der Binder hat daraus frueher geschlossen, es sei nie geschossen
; worden - und dann auch nie einen Kill gezaehlt.
BkMem_OwnFire() {
    global BK_ADDR_CPED_PTR
    if (!BkMem_Active())
        return false
    ped := BkMem_ReadUInt(BK_ADDR_CPED_PTR)
    if (!ped)
        return false
    if !BkMem_TryUChar(ped + 0x46E, v)
        return false
    return (v & 1) ? true : false
}

; Alle anderen Figuren im Sichtbereich:
;   [{id, alive, hp, x, y, z, fx, fy, wt, ammo, fire, dmg}]
;   fx/fy = Blickrichtung, wt/ammo = aktive Waffe und Munition,
;   fire  = schiesst gerade, dmg = wer die Figur zuletzt verletzt hat
;           (Zeiger auf Figur oder Fahrzeug, 0 = niemand/unbekannt)
; Zweistufig, damit im Gefecht nicht 20 Mal pro Sekunde der komplette
; Datenblock jeder Figur der ganzen Karte gelesen wird: zuerst nur der
; Zeiger auf die Lage-Matrix (4 Byte) und daraus die Position - nur fuer
; Figuren in Reichweite folgt der grosse Block. Das spart im Schnitt ueber
; 80 % der Speicherzugriffe und damit das Ruckeln waehrend eines Wars.
BkMem_Peds(maxDist := 200) {
    global BK_hProc, BK_ADDR_CPED_PTR, BK_ADDR_POS_X
    if (!BkMem_Active())
        return ""
    pool := BkMem_ReadUInt(0xB74490)
    if (!pool)
        return ""
    VarSetCapacity(ph, 12, 0)
    if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", pool, "Ptr", &ph, "UPtr", 12, "Ptr", 0)
        return ""
    objs := NumGet(ph, 0, "UInt"), map := NumGet(ph, 4, "UInt"), size := NumGet(ph, 8, "Int")
    ; die Figuren-Liste von GTA hat 140 Plaetze - alles deutlich darueber
    ; ist ein Lesefehler und wuerde nur Zeit kosten
    if (!objs || !map || size <= 0 || size > 256)
        return ""
    VarSetCapacity(fl, size, 0)
    if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", map, "Ptr", &fl, "UPtr", size, "Ptr", 0)
        return ""
    me := BkMem_ReadUInt(BK_ADDR_CPED_PTR)
    mx := BkMem_ReadFloat(BK_ADDR_POS_X)
    my := BkMem_ReadFloat(BK_ADDR_POS_X + 4)
    far := maxDist * maxDist
    out := []
    VarSetCapacity(pb, 0x768, 0)
    VarSetCapacity(mb, 0x3C, 0)
    VarSetCapacity(mp, 4, 0)
    Loop, % size {
        if (NumGet(fl, A_Index - 1, "UChar") & 0x80)      ; freier Platz
            continue
        p := objs + (A_Index - 1) * 0x7C4
        if (p = me)
            continue
        ; 1) nur der Zeiger auf die Lage-Matrix (+0x14)
        if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", p + 0x14, "Ptr", &mp, "UPtr", 4, "Ptr", 0)
            continue
        m := NumGet(mp, 0, "UInt")
        if (m < 0x10000)
            continue
        ; 2) Lage-Matrix: Blickrichtung (+0x10) und Position (+0x30)
        if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", m, "Ptr", &mb, "UPtr", 0x3C, "Ptr", 0)
            continue
        px := NumGet(mb, 0x30, "Float"), py := NumGet(mb, 0x34, "Float")
        ; zu weit weg -> der grosse Block wird gar nicht erst gelesen
        if (mx || my) {
            dx := px - mx, dy := py - my
            if ((dx * dx + dy * dy) > far)
                continue
        }
        ; 3) erst jetzt der grosse Block: +0x46E Flags (Bit 1 = feuert),
        ;    +0x530 Zustand (54 stirbt, 55 tot), +0x540 Leben, +0x5A0 Waffen,
        ;    +0x718 aktiver Waffenplatz, +0x764 zuletzt verletzt von
        if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", p, "Ptr", &pb, "UPtr", 0x768, "Ptr", 0)
            continue
        state := NumGet(pb, 0x530, "UInt")
        hp := NumGet(pb, 0x540, "Float")
        slot := NumGet(pb, 0x718, "UChar")
        wt := -1, ammo := -1
        if (slot <= 12) {
            wt := NumGet(pb, 0x5A0 + slot * 0x1C, "Int")
            ammo := NumGet(pb, 0x5A0 + slot * 0x1C + 0xC, "Int")
        }
        out.Push({id: p, alive: (hp > 0 && state != 54 && state != 55), hp: hp
            , x: px, y: py, z: NumGet(mb, 0x38, "Float")
            , fx: NumGet(mb, 0x10, "Float"), fy: NumGet(mb, 0x14, "Float")
            , wt: wt, ammo: ammo, fire: (NumGet(pb, 0x46E, "UChar") & 1), dmg: NumGet(pb, 0x764, "UInt")})
    }
    return out
}

; =====================================================================
;  SA-MP-ZUSTAND: hat SA-MP gerade die Tastatur?  (NUR LESEND)
; ---------------------------------------------------------------------
;  Liest aus samp.dll, ob der Chat oder ein Dialog (Login-Passwort,
;  Eingabefenster, Listen) die Tastatur uebernommen hat. Ueber Tasten
;  allein laesst sich das nicht zuverlaessig erkennen: Dialoge oeffnet
;  der Server, nicht die Taste T.
;
;  Diese Adressen haengen - anders als die gta_sa.exe-Adressen oben -
;  von der samp.dll-Version ab. Welcher Satz passt, wird NICHT geraten:
;  ein Satz gilt nur, wenn die Struktur stimmt (Dialog und Eingabefeld
;  zeigen auf dasselbe Direct3D-Geraet, alle Zustandswerte liegen im
;  gueltigen Bereich). Passt keiner, meldet das Modul "unbekannt" und
;  der Keybinder faellt auf die Tasten-Erkennung zurueck.
;
;  Live geprueft mit 0.3.7-R5: Chattext im Chat-Objekt gefunden,
;  Cursor-Modus 0 -> 2 -> 0 und Eingabe 0 -> 1 -> 0 beim Oeffnen und
;  Schliessen des Chats. R1 stammt aus der SAMP-UDF, R3/DL aus der
;  sampapi - beide werden erst nach bestandenem Strukturtest benutzt.
; =====================================================================
global BK_SampBase     := 0
global BK_SampSize     := 0
global BK_SampPid      := 0
global BK_SampSet      := ""     ; bestaetigter Adress-Satz oder ""
global BK_SampNextScan := 0

BkSamp_Sets() {
    static sets := ""
    if (!IsObject(sets)) {
        sets := []
        ; net/pools: CNetGame und darin der Zeiger auf die Pools (Textdraws)
        sets.Push({n: "0.3.7-R5",  dlg: 0x26EB50, inp: 0x26EB84, game: 0x26EBAC, cur: 0x61, net: 0x26EB94, pools: 0x3DE})
        sets.Push({n: "0.3.7-R3",  dlg: 0x26E898, inp: 0x26E8CC, game: 0x26E8F4, cur: 0x61, net: 0x26E8DC, pools: 0x3DE})
        sets.Push({n: "0.3.7-R1",  dlg: 0x21A0B8, inp: 0x21A0E8, game: 0x21A10C, cur: 0x55, net: 0x21A0F8, pools: 0x3CD})
        sets.Push({n: "0.3.DL-R1", dlg: 0x2AC9E0, inp: 0x2ACA14, game: 0x2ACA3C, cur: 0x61, net: 0x2ACA24, pools: 0x3DE})
    }
    return sets
}

; samp.dll-Basisadresse im Spielprozess ermitteln (Toolhelp, nur lesend)
BkSamp_FindBase(pid) {
    global BK_SampBase, BK_SampSize
    BK_SampBase := 0
    BK_SampSize := 0
    ; 0x18 = TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32
    snap := DllCall("CreateToolhelp32Snapshot", "UInt", 0x18, "UInt", pid, "Ptr")
    if (!snap || snap = -1)
        return false
    VarSetCapacity(me, 1064, 0)          ; MODULEENTRY32W (32 Bit)
    NumPut(1064, me, 0, "UInt")
    if DllCall("Module32FirstW", "Ptr", snap, "Ptr", &me) {
        Loop {
            if (StrGet(&me + 32, 256, "UTF-16") = "samp.dll") {
                BK_SampBase := NumGet(me, 20, "UInt")
                BK_SampSize := NumGet(me, 24, "UInt")
                break
            }
            if !DllCall("Module32NextW", "Ptr", snap, "Ptr", &me)
                break
        }
    }
    DllCall("CloseHandle", "Ptr", snap)
    return (BK_SampBase != 0)
}

; Einen Adress-Satz lesen und pruefen.
; Liefert {cur, inp, dlg} oder "" wenn nicht lesbar oder Struktur falsch.
BkSamp_ReadSet(st) {
    global BK_SampBase, BK_SampSize
    if (st.game + 4 > BK_SampSize)
        return ""
    if !BkMem_TryUInt(BK_SampBase + st.dlg, pD)
        return ""
    if !BkMem_TryUInt(BK_SampBase + st.inp, pI)
        return ""
    if !BkMem_TryUInt(BK_SampBase + st.game, pG)
        return ""
    if (pD < 0x10000 || pI < 0x10000 || pG < 0x10000)
        return ""
    ; Strukturtest: beide Objekte beginnen mit demselben D3D-Geraet
    if !BkMem_TryUInt(pD, devD)
        return ""
    if !BkMem_TryUInt(pI, devI)
        return ""
    if (devD < 0x10000 || devD != devI)
        return ""
    if !BkMem_TryUInt(pG + st.cur, cur)
        return ""
    if !BkMem_TryUInt(pI + 0x14E0, inp)
        return ""
    if !BkMem_TryUInt(pD + 0x28, dlg)
        return ""
    ; Wertebereich: Cursor-Modus 0..4, die beiden anderen sind BOOL
    if (cur > 4 || inp > 1 || dlg > 1)
        return ""
    return {cur: cur, inp: inp, dlg: dlg}
}

BkSamp_Eval(s, ByRef isChat) {
    isChat := (s.inp = 1) ? 1 : 0
    ; Cursor-Modus != 0 heisst: SA-MP hat Tastatur/Maus fuer eine
    ; Oberflaeche gesperrt (Chat, Dialog, Menue) - Hotkeys gehoeren weg.
    return (s.cur != 0 || s.inp = 1 || s.dlg = 1) ? 1 : 0
}

; -1 = unbekannt (Spiel/SA-MP nicht lesbar oder Version nicht bestaetigt)
;  0 = nichts offen
;  1 = SA-MP hat die Tastatur (Chat, Dialog, Menue)
; isChat wird 1, wenn es konkret die Chat-Eingabe ist.
BkSamp_InputState(ByRef isChat) {
    global BK_dwPID, BK_SampPid, BK_SampBase, BK_SampSet, BK_SampNextScan
    isChat := 0
    if (!BkMem_Active() || !BK_dwPID)
        return -1

    ; neuer Prozess oder samp.dll noch nicht gefunden -> gedrosselt suchen
    if (BK_SampPid != BK_dwPID || !BK_SampBase) {
        if (BK_SampPid = BK_dwPID && A_TickCount < BK_SampNextScan)
            return -1
        BK_SampPid := BK_dwPID
        BK_SampSet := ""
        BK_SampNextScan := A_TickCount + 3000
        if !BkSamp_FindBase(BK_dwPID)
            return -1
        BK_SampNextScan := 0
    }

    if (IsObject(BK_SampSet)) {
        s := BkSamp_ReadSet(BK_SampSet)
        if (IsObject(s))
            return BkSamp_Eval(s, isChat)
        ; voruebergehend ungueltig (z.B. Verbindungsaufbau) -> neu pruefen
        BK_SampSet := ""
        BK_SampNextScan := A_TickCount + 1000
    }

    if (A_TickCount < BK_SampNextScan)
        return -1
    BK_SampNextScan := A_TickCount + 1000
    for i, st in BkSamp_Sets() {
        s := BkSamp_ReadSet(st)
        if (IsObject(s)) {
            BK_SampSet := st
            return BkSamp_Eval(s, isChat)
        }
    }
    return -1
}

; Name der erkannten SA-MP-Version oder ""
BkSamp_VersionName() {
    global BK_SampSet
    return IsObject(BK_SampSet) ? BK_SampSet.n : ""
}

; ---------------------------------------------------------------------
;  SA-MP-Textdraws: Server-Anzeigen auf dem Bildschirm  (NUR LESEND)
; ---------------------------------------------------------------------
;  Life of Player zeigt den Stand laufender Gang- und Family-Wars rechts
;  im Bild als Textdraw, sekundengenau, z.B.
;     ~y~[~r~YAK 24P ~y~- ~b~GuiZa 0P~y~]~n~~y~[~w~Zeit: ~g~8:41~y~]
;  Weg dorthin (live geprueft mit 0.3.7-R5): samp.dll+0x26EB94 -> CNetGame,
;  +0x3DE -> Pools, einer der Eintraege -> Textdraw-Pool: 2304 BOOL
;  "belegt", danach 2304 Zeiger auf CTextDraw (Text ab +0).
;  Der Pool wird nur ueber diese Struktur erkannt und bei jedem Lesen
;  geprueft - passt sie nicht mehr (Reconnect), wird neu gesucht.
global BK_TdPool     := 0
global BK_TdPid      := 0
global BK_TdNextFind := 0
global BK_TdHits     := ""    ; Plaetze, die zuletzt Text mit Ziffern hatten
global BK_TdFullT    := 0     ; letzter vollstaendiger Durchgang

; Texte aller Textdraws mit Ziffern (Stand, Zeit) oder "" = nicht lesbar
;
; Frueher wurden hier jede Sekunde alle 2304 Plaetze einzeln aus dem Spiel
; gelesen - bei einem Server mit vielen Anzeigen sind das hunderte
; Speicherzugriffe pro Sekunde, mitten im laufenden Spiel. Jetzt merkt sich
; der Binder, an welchen Plaetzen ueberhaupt etwas Brauchbares stand, und
; liest nur noch diese; komplett durchgesehen wird nur alle 5 Sekunden
; (und sofort, wenn die gemerkten Plaetze leer laufen).
BkSamp_TextDraws() {
    global BK_hProc, BK_SampBase, BK_SampSet, BK_dwPID, BK_TdPool, BK_TdPid, BK_TdNextFind
    global BK_TdHits, BK_TdFullT
    if (!BkMem_Active() || !BK_SampBase || !IsObject(BK_SampSet) || !BK_SampSet.net)
        return ""
    if (BK_TdPid != BK_dwPID) {
        BK_TdPid := BK_dwPID
        BK_TdPool := 0
        BK_TdNextFind := 0
        BK_TdHits := ""
    }
    VarSetCapacity(pb, 0x4800, 0)
    if (BK_TdPool && !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", BK_TdPool, "Ptr", &pb, "UPtr", 0x4800, "Ptr", 0))
        BK_TdPool := 0
    if (!BK_TdPool) {
        if (A_TickCount < BK_TdNextFind)
            return ""
        BK_TdNextFind := A_TickCount + 3000
        BK_TdHits := ""
        if (!BkMem_TryUInt(BK_SampBase + BK_SampSet.net, net) || !BkMem_TryUInt(net + BK_SampSet.pools, pools))
            return ""
        Loop, 10 {
            if (!BkMem_TryUInt(pools + (A_Index - 1) * 4, t) || t < 0x10000)
                continue
            if (DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", t, "Ptr", &pb, "UPtr", 0x4800, "Ptr", 0)
                && BkSamp_TdValid(pb)) {
                BK_TdPool := t
                break
            }
        }
        if (!BK_TdPool)
            return ""
    }
    full := (!IsObject(BK_TdHits) || !BK_TdHits.MaxIndex() || (A_TickCount - BK_TdFullT) > 5000)
    out := []
    hits := []
    VarSetCapacity(tb, 256, 0)
    list := full ? "" : BK_TdHits
    n := full ? 2304 : list.MaxIndex()
    Loop, % n {
        i := full ? A_Index : list[A_Index]
        v := NumGet(pb, (i - 1) * 4, "UInt")
        if (!v)
            continue
        p := NumGet(pb, 0x2400 + (i - 1) * 4, "UInt")
        if (v > 1 || p < 0x10000) {             ; Struktur passt nicht mehr
            BK_TdPool := 0
            BK_TdHits := ""
            return ""
        }
        if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", p, "Ptr", &tb, "UPtr", 255, "Ptr", 0)
            continue
        NumPut(0, tb, 255, "UChar")
        s := StrGet(&tb, 255, "CP1252")
        if RegExMatch(s, "\d") {
            out.Push(s)
            hits.Push(i)
        }
    }
    if (full) {
        BK_TdHits := hits
        BK_TdFullT := A_TickCount
    } else if (!hits.MaxIndex()) {
        BK_TdHits := ""          ; nichts mehr da -> beim naechsten Mal alles durchsehen
    }
    return out
}

; ---------------------------------------------------------------------
;  Text des gerade offenen SA-MP-Dialogs  (NUR LESEND)
; ---------------------------------------------------------------------
;  Life of Player zeigt das Charaktermenue (Taste N) als Dialog. Darin
;  stehen unter anderem die Gesamtzahl der Kills und Tode - genau die
;  Zahlen, mit denen der Binder seine eigenen abgleichen soll.
;
;  Wo im Dialog-Objekt der Textzeiger liegt, wird NICHT geraten. Bekannt
;  und in BkSamp_ReadSet bereits geprueft ist nur: der Zeiger auf das
;  Dialog-Objekt und darin +0x28 = "Dialog ist offen". Der Textzeiger wird
;  von dort aus durch die naechsten Felder gesucht - genommen wird das
;  erste, hinter dem wirklich lesbarer Text steht. Der gefundene Platz
;  wird gemerkt und bei jedem Lesen gegengeprueft; passt er nicht mehr
;  (Reconnect, andere samp.dll), wird neu gesucht. Findet sich nichts,
;  kommt "" zurueck - dann bleibt es bei den Server-Anzeigen.
global BK_DlgTextOff := -1
global BK_DlgPid     := 0

; Ist gerade ein SA-MP-Dialog offen?  -1 unbekannt, 0 nein, 1 ja
BkSamp_DialogOpen() {
    global BK_SampBase, BK_SampSet
    if (!BkMem_Active() || !BK_SampBase || !IsObject(BK_SampSet))
        return -1
    if (!BkMem_TryUInt(BK_SampBase + BK_SampSet.dlg, pD) || pD < 0x10000)
        return -1
    if (!BkMem_TryUInt(pD + 0x28, act) || act > 1)
        return -1
    return act
}

BkSamp_DialogText() {
    global BK_SampBase, BK_SampSet, BK_dwPID, BK_DlgTextOff, BK_DlgPid
    if (!BkMem_Active() || !BK_SampBase || !IsObject(BK_SampSet))
        return ""
    if (BK_DlgPid != BK_dwPID) {
        BK_DlgPid := BK_dwPID
        BK_DlgTextOff := -1
    }
    if (!BkMem_TryUInt(BK_SampBase + BK_SampSet.dlg, pD) || pD < 0x10000)
        return ""
    ; +0x28: liegt ueberhaupt ein Dialog offen? (derselbe Wert, ueber den
    ; BkSamp_ReadSet die Version bestaetigt)
    if (!BkMem_TryUInt(pD + 0x28, act) || act != 1)
        return ""
    if (BK_DlgTextOff >= 0) {
        s := BkSamp_DlgTextAt(pD, BK_DlgTextOff)
        if (s != "")
            return s
        BK_DlgTextOff := -1
    }
    off := 0x2C
    while (off <= 0x60) {
        s := BkSamp_DlgTextAt(pD, off)
        if (s != "") {
            BK_DlgTextOff := off
            return s
        }
        off += 4
    }
    return ""
}

; Steht an dieser Stelle des Dialogs ein Zeiger auf brauchbaren Text?
BkSamp_DlgTextAt(pD, off) {
    global BK_hProc
    if (!BkMem_TryUInt(pD + off, p) || p < 0x10000)
        return ""
    VarSetCapacity(b, 2049, 0)
    ; am Ende des Speicherbereichs schlaegt das grosse Lesen fehl - dann
    ; genuegt ein kleiner Happen (die Zahlen stehen ohnehin vorne)
    if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", p, "Ptr", &b, "UPtr", 2048, "Ptr", 0) {
        VarSetCapacity(b, 2049, 0)
        if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", p, "Ptr", &b, "UPtr", 128, "Ptr", 0)
            return ""
    }
    NumPut(0, b, 2048, "UChar")
    s := StrGet(&b, 2048, "CP1252")
    return BkSamp_TextOk(s) ? s : ""
}

; Sieht das nach echtem Text aus - und nicht nach zufaelligen Bytes?
BkSamp_TextOk(s) {
    n := StrLen(s)
    if (n < 6 || n > 2048)
        return false
    ok := 0, letters := 0
    Loop, Parse, s
    {
        c := Asc(A_LoopField)
        if (c >= 0x20 || c = 9 || c = 10 || c = 13)
            ok += 1
        if ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A))
            letters += 1
    }
    return (letters >= 3 && (ok * 10) >= (n * 9))
}

; Zuletzt an SA-MP uebergebene Chatzeile: s = neuester Eintrag im Verlauf
; der Chat-Eingabe (Pfeil hoch), sig = ganzer Verlauf. SA-MP schiebt jede
; gesendete Zeile vorne hinein, auch doppelte - aendert sich sig, wurde
; wirklich gesendet. CInput +0x1565 = Verlauf[10] zu je 129 Zeichen, live
; geprueft mit 0.3.7-R5 - fuer andere Versionen false.
BkSamp_LastInput(ByRef s, ByRef sig) {
    global BK_hProc, BK_SampBase, BK_SampSet
    s := "", sig := ""
    if (!BkMem_Active() || !BK_SampBase || !IsObject(BK_SampSet) || BK_SampSet.n != "0.3.7-R5")
        return false
    if !BkMem_TryUInt(BK_SampBase + BK_SampSet.inp, pI)
        return false
    VarSetCapacity(b, 1291, 0)
    if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", pI + 0x1565, "Ptr", &b, "UPtr", 1290, "Ptr", 0)
        return false
    s := StrGet(&b, 129, "CP1252")
    Loop, 10
        sig .= StrGet(&b + (A_Index - 1) * 129, 129, "CP1252") . "|"
    return true
}

; Pausenmenue von GTA offen? (CMenuManager +0x5C, 0xBA67A4)
BkMem_MenuActive() {
    if (!BkMem_Active() || !BkMem_TryUInt(0xBA67A4, v))
        return false
    return (v & 0xFF) != 0
}

; =====================================================================
;  SPIELERNAMEN AUS SA-MP  (NUR LESEND)
; ---------------------------------------------------------------------
;  Im Gang- oder Family-War schreibt der Server nichts in den Chat. Der
;  Binder sieht den Kill dann nur im Spiel und kannte bisher keinen Namen
;  dazu - {opfer} wurde "unbekannt". SA-MP fuehrt aber eine Liste aller
;  Mitspieler, und darin haengt an jedem Namen auch die Spielfigur.
;
;  ES WIRD KEINE ADRESSE GERATEN. Gesucht wird ueber die Struktur:
;    1) Der Spieler-Pool ist der einzige Block, in dem 1004 Zeiger und
;       direkt dahinter 1004 Ja/Nein-Werte stehen, die genau dazu passen.
;    2) Der Weg vom Listeneintrag zur Spielfigur wird GELERNT: der Binder
;       sucht nach Figuren, die er ohnehin schon kennt (aus der Figuren-
;       Liste von GTA). Der gefundene Weg gilt erst, wenn er bei mehreren
;       Spielern zu verschiedenen, bekannten Figuren fuehrt.
;    3) Der Platz des Namens wird genauso gelernt: er gilt nur, wenn an
;       dieser Stelle bei allen geprueften Spielern ein gueltiger Name
;       steht und die Namen nicht alle gleich sind.
;  Klappt etwas davon nicht, gibt es einfach keinen Namen - lieber
;  "unbekannt" als ein falscher Name im Gangchat.
; =====================================================================
global BK_PlrEnabled := true
global BK_PlrPool    := 0        ; Block mit der Spielerliste
global BK_PlrOff     := -1       ; Offset des Zeigerfeldes darin
global BK_PlrChain   := ""       ; Weg vom Eintrag zur Spielfigur, z.B. [0, 4, 44]
global BK_PlrNameOff := -1       ; Offset des Namens im Eintrag
global BK_PlrNamePtr := false    ; Name liegt als Zeiger vor
global BK_PlrPid     := 0
global BK_PlrNext    := 0        ; naechster Lernversuch
global BK_PlrTries   := 0
global BK_PlrReads   := 0        ; Lesezaehler: bremst die Suche
global BK_PlrCache   := {}       ; Figur -> {name, t}: nicht bei jedem Kill
                                 ; die ganze Liste durchgehen

BkSamp_PlrReset() {
    global BK_PlrPool, BK_PlrOff, BK_PlrChain, BK_PlrNameOff, BK_PlrNamePtr, BK_PlrTries, BK_PlrNext, BK_PlrCache
    BK_PlrCache := {}
    BK_PlrPool := 0
    BK_PlrOff := -1
    BK_PlrChain := ""
    BK_PlrNameOff := -1
    BK_PlrNamePtr := false
    BK_PlrTries := 0
    BK_PlrNext := 0
}

; "aus" | "nicht gefunden" | "erkannt"  (fuer die Anzeige im Fenster)
BkSamp_PlrState() {
    global BK_PlrEnabled, BK_PlrChain, BK_PlrNameOff, BK_PlrTries
    if (!BK_PlrEnabled)
        return "aus"
    if (IsObject(BK_PlrChain) && BK_PlrNameOff >= 0)
        return "erkannt"
    return (BK_PlrTries >= 8) ? "nicht gefunden" : "wird gesucht"
}

; Ist das ein gueltiger SA-MP-Name?
BkSamp_NickOk(s) {
    n := StrLen(s)
    if (n < 3 || n > 24)
        return false
    return RegExMatch(s, "^[A-Za-z0-9_\[\]\(\)\$@\.=]+$") > 0
}

; Name an einer Adresse lesen ("" = dort steht keiner)
BkSamp_NickAt(addr, deref) {
    global BK_hProc, BK_PlrReads
    if (deref) {
        if (!BkMem_TryUInt(addr, np) || np < 0x10000 || np > 0x7FF00000)
            return ""
        addr := np
    }
    BK_PlrReads += 1
    VarSetCapacity(nb, 32, 0)
    if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", addr, "Ptr", &nb, "UPtr", 25, "Ptr", 0)
        return ""
    NumPut(0, nb, 25, "UChar")
    s := StrGet(&nb, 25, "CP1252")
    return BkSamp_NickOk(s) ? s : ""
}

; Den Block mit der Spielerliste suchen: 1004 Zeiger, dahinter 1004
; Ja/Nein-Werte, die genau zu den Zeigern passen.
BkSamp_PlrPoolOff(ByRef pb) {
    bestOff := -1, bestCnt := 0
    o := 0
    while (o <= 0x80) {
        ; erst nur die niedrigen Spieler-Nummern ansehen - das wirft die
        ; allermeisten Stellen sofort raus und kostet fast nichts
        if (BkSamp_PlrCheck(pb, o, 128) >= 1) {
            full := BkSamp_PlrCheck(pb, o, 1004)
            ; Die Stelle mit den MEISTEN Spielern ist die richtige: eine um
            ; ein paar Byte verschobene Stelle passt zwar auch, verliert
            ; dabei aber Eintraege.
            if (full > bestCnt) {
                bestCnt := full
                bestOff := o
            }
        }
        ; 2er-Schritte: in 0.3.7-R1 liegt die Liste bei +0x2E (nicht durch 4 teilbar)
        o += 2
    }
    return bestOff
}

; Belegte Plaetze zaehlen - oder -1, wenn die Struktur nicht passt
BkSamp_PlrCheck(ByRef pb, o, n) {
    cnt := 0
    Loop, % n {
        i := A_Index - 1
        p := NumGet(pb, o + i * 4, "UInt")
        l := NumGet(pb, o + 4016 + i * 4, "UInt")
        if (l > 1)
            return -1
        if (p) {
            if (p < 0x10000 || p > 0x7FF00000 || l != 1)
                return -1
            cnt += 1
        }
    }
    return cnt
}

BkSamp_PlrFind() {
    global BK_hProc, BK_SampBase, BK_SampSet, BK_PlrPool, BK_PlrOff, BK_TdPool
    if (!BkMem_Active() || !BK_SampBase || !IsObject(BK_SampSet) || !BK_SampSet.net)
        return false
    if (!BkMem_TryUInt(BK_SampBase + BK_SampSet.net, net) || !BkMem_TryUInt(net + BK_SampSet.pools, pools))
        return false
    VarSetCapacity(pb, 0x2100, 0)
    Loop, 10 {
        if (!BkMem_TryUInt(pools + (A_Index - 1) * 4, t) || t < 0x10000)
            continue
        if (t = BK_TdPool)                       ; das ist der Textdraw-Pool
            continue
        if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", t, "Ptr", &pb, "UPtr", 0x2100, "Ptr", 0)
            continue
        o := BkSamp_PlrPoolOff(pb)
        if (o >= 0) {
            BK_PlrPool := t
            BK_PlrOff := o
            return true
        }
    }
    return false
}

; Alle belegten Listeneintraege ("" = nicht lesbar)
BkSamp_PlrList() {
    global BK_hProc, BK_PlrPool, BK_PlrOff
    if (!BK_PlrPool || BK_PlrOff < 0)
        return ""
    VarSetCapacity(ab, 4016, 0)
    if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", BK_PlrPool + BK_PlrOff, "Ptr", &ab, "UPtr", 4016, "Ptr", 0)
        return ""
    out := []
    Loop, 1004 {
        p := NumGet(ab, (A_Index - 1) * 4, "UInt")
        if (p >= 0x10000 && p < 0x7FF00000)
            out.Push(p)
    }
    return out
}

; Weg vom Listeneintrag zur Spielfigur anwenden (0 = nichts dahinter)
BkSamp_PedOf(rp, ch := "") {
    global BK_PlrChain
    if (!IsObject(ch))
        ch := BK_PlrChain
    if (!IsObject(ch))
        return 0
    v := rp
    for i, o in ch {
        if (!BkMem_TryUInt(v + o, nv) || nv < 0x10000 || nv > 0x7FF00000)
            return 0
        v := nv
    }
    return v
}

; Suche nach einer bekannten Spielfigur, hoechstens drei Ebenen tief.
; Liefert den Weg dorthin als Liste von Offsets oder "".
BkSamp_PlrWalk(base, pedSet, depth) {
    global BK_hProc, BK_PlrReads
    if (BK_PlrReads > 2000)                      ; Notbremse
        return ""
    BK_PlrReads += 1
    VarSetCapacity(bb, 0x100, 0)
    if !DllCall("ReadProcessMemory", "Ptr", BK_hProc, "Ptr", base, "Ptr", &bb, "UPtr", 0x100, "Ptr", 0)
        return ""
    n := (depth = 1) ? 0x60 : 0x100
    o := 0
    while (o < n) {
        if pedSet.HasKey(NumGet(bb, o, "UInt"))
            return [o]
        o += 4
    }
    if (depth >= 3)
        return ""
    o := 0
    cnt := 0
    while (o < n && cnt < 20) {
        v := NumGet(bb, o, "UInt")
        if (v >= 0x10000 && v < 0x7FF00000) {
            cnt += 1
            sub := BkSamp_PlrWalk(v, pedSet, depth + 1)
            if (IsObject(sub)) {
                sub.InsertAt(1, o)
                return sub
            }
        }
        o += 4
    }
    return ""
}

; Gilt der gefundene Weg auch fuer die anderen Spieler? Er muss zu
; VERSCHIEDENEN Figuren fuehren und mindestens zwei davon muessen welche
; sein, die wir gerade wirklich sehen.
BkSamp_ChainOk(ch, list, pedSet) {
    hits := 0
    seen := {}
    for i, rp in list {
        v := BkSamp_PedOf(rp, ch)
        if (!v)
            continue
        if (seen.HasKey(v))
            return false
        seen[v] := 1
        if pedSet.HasKey(v)
            hits += 1
    }
    return (hits >= 2)
}

; Platz des Namens lernen - er muss bei allen geprueften Spielern passen
; und darf nicht ueberall derselbe sein.
BkSamp_LearnName(list) {
    global BK_PlrNameOff, BK_PlrNamePtr
    sample := []
    for i, rp in list {
        sample.Push(rp)
        if (sample.MaxIndex() >= 5)
            break
    }
    if (sample.MaxIndex() < 2)
        return false
    Loop, 2 {
        deref := (A_Index = 2)
        off := 0
        step := deref ? 4 : 1
        while (off <= 0x60) {
            ok := true
            first := ""
            same := true
            for i, rp in sample {
                nm := BkSamp_NickAt(rp + off, deref)
                if (nm = "") {
                    ok := false
                    break
                }
                if (first = "")
                    first := nm
                else if (nm != first)
                    same := false
            }
            if (ok && !same) {
                BK_PlrNameOff := off
                BK_PlrNamePtr := deref
                return true
            }
            off += step
        }
    }
    return false
}

; Einmal alles lernen. peds = Figuren-Liste aus BkMem_Peds (die kennen wir
; sicher). Wird nur gelegentlich versucht und bricht selbst ab.
BkSamp_PlrLearn(peds) {
    global BK_PlrPool, BK_PlrChain, BK_PlrNameOff, BK_PlrTries, BK_PlrNext, BK_PlrReads
    if (!IsObject(peds) || peds.MaxIndex() < 2)
        return false
    if (A_TickCount < BK_PlrNext || BK_PlrTries >= 8)
        return false
    BK_PlrNext := A_TickCount + 5000
    BK_PlrTries += 1
    BK_PlrReads := 0
    if (!BK_PlrPool && !BkSamp_PlrFind())
        return false
    list := BkSamp_PlrList()
    if (!IsObject(list) || !list.MaxIndex()) {
        BK_PlrPool := 0
        return false
    }
    pedSet := {}
    for i, p in peds
        pedSet[p.id] := 1
    if (!IsObject(BK_PlrChain)) {
        for i, rp in list {
            ch := BkSamp_PlrWalk(rp, pedSet, 1)
            if (IsObject(ch) && BkSamp_ChainOk(ch, list, pedSet)) {
                BK_PlrChain := ch
                break
            }
            if (BK_PlrReads > 2000)
                break
        }
    }
    if (!IsObject(BK_PlrChain))
        return false
    if (BK_PlrNameOff < 0 && !BkSamp_LearnName(list))
        return false
    BK_PlrTries := 0
    return true
}

; Name zu einer Spielfigur - "" wenn unbekannt.
; peds = aktuelle Figuren-Liste (nur zum Lernen noetig)
BkSamp_NameForPed(ped, peds := "") {
    global BK_PlrEnabled, BK_dwPID, BK_PlrPid, BK_PlrChain, BK_PlrNameOff, BK_PlrNamePtr, BK_PlrPool, BK_PlrCache
    if (!BK_PlrEnabled || !ped || !BkMem_Active())
        return ""
    if (BK_PlrPid != BK_dwPID) {
        BK_PlrPid := BK_dwPID
        BkSamp_PlrReset()
    }
    if (!IsObject(BK_PlrChain) || BK_PlrNameOff < 0) {
        if (!BkSamp_PlrLearn(peds))
            return ""
    }
    ; kurz gemerkt: im Gefecht fallen mehrere Gegner hintereinander, und
    ; die ganze Liste durchzugehen kostet jedes Mal Speicherzugriffe
    c := BK_PlrCache[ped]
    if (IsObject(c) && (A_TickCount - c.t) < 5000)
        return c.name
    list := BkSamp_PlrList()
    if (!IsObject(list) || !list.MaxIndex()) {
        BK_PlrPool := 0                      ; z.B. nach einem Reconnect
        return ""
    }
    name := ""
    for i, rp in list {
        if (BkSamp_PedOf(rp) = ped) {
            name := BkSamp_NickAt(rp + BK_PlrNameOff, BK_PlrNamePtr)
            break
        }
    }
    if (BK_PlrCache.Count() > 64)
        BK_PlrCache := {}
    BK_PlrCache[ped] := {name: name, t: A_TickCount}
    return name
}

; Sieht der Speicherblock wie ein Textdraw-Pool aus?
BkSamp_TdValid(ByRef pb) {
    used := 0
    Loop, 2304 {
        v := NumGet(pb, (A_Index - 1) * 4, "UInt")
        if (v > 1 || (v && NumGet(pb, 0x2400 + (A_Index - 1) * 4, "UInt") < 0x10000))
            return false
        used += v
    }
    return (used > 0)
}
