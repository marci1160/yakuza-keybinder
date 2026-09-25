; =====================================================================
;  Yakuza Keybinder - Speicher-Modul (NUR LESEND / READ-ONLY)
; ---------------------------------------------------------------------
;  Liest Position, Leben, Fahrzeug, Waffen und die Figuren in der Naehe
;  aus gta_sa.exe (Version 1.0 US). Dieses Modul schreibt NICHTS in den
;  Speicher und injiziert NICHTS; der Prozess wird nur mit den minimalen
;  Rechten PROCESS_VM_READ | PROCESS_QUERY_INFORMATION geoeffnet. Alle
;  Adressen sind feste gta_sa.exe-Adressen und damit unabhaengig von der
;  SA-MP / open.mp Version.
;  (Einzige Ausnahme im ganzen Binder: die abschaltbare Backup-Fahne auf
;  der Minimap, siehe YkMarker.ahk - mit eigenem Handle.)
; =====================================================================

; --- feste gta_sa.exe (1.0 US) Adressen ---
global YK_ADDR_POS_X       := 0xB6F2E4
global YK_ADDR_POS_Y       := 0xB6F2E8
global YK_ADDR_POS_Z       := 0xB6F2EC
global YK_ADDR_CPED_PTR    := 0xB6F5F0
global YK_ADDR_CPED_HP     := 0x540
global YK_ADDR_CPED_ARMOR  := 0x548
global YK_ADDR_VEHICLE_PTR := 0xBA18FC
global YK_ADDR_INTERIOR    := 0xA4ACE8
global YK_ADDR_VEHICLE_MODEL := 0x22

; Fahrzeug-Modellnamen, Index = ModelID - 399 (gueltig fuer ModelID 400..610)
global YK_VehicleNames := ["Landstalker","Bravura","Buffalo","Linerunner","Perrenial","Sentinel","Dumper","Firetruck","Trashmaster","Stretch","Manana","Infernus","Voodoo","Pony","Mule","Cheetah","Ambulance","Leviathan","Moonbeam","Esperanto","Taxi","Washington","Bobcat","Whoopee","BFInjection","Hunter","Premier","Enforcer","Securicar","Banshee","Predator","Bus","Rhino","Barracks","Hotknife","Trailer","Previon","Coach","Cabbie","Stallion","Rumpo","RCBandit","Romero","Packer","Monster","Admiral","Squalo","Seasparrow","Pizzaboy","Tram","Trailer","Turismo","Speeder","Reefer","Tropic","Flatbed","Yankee","Caddy","Solair","Berkley's RC Van","Skimmer","PCJ-600","Faggio","Freeway","RC Baron","RC Raider","Glendale","Oceanic","Sanchez","Sparrow","Patriot","Quad","Coastguard","Dinghy","Hermes","Sabre","Rustler","ZR-350","Walton","Regina","Comet","BMX","Burrito","Camper","Marquis","Baggage","Dozer","Maverick","News Chopper","Rancher","FBI Rancher","Virgo","Greenwood","Jetmax","Hotring","Sandking","Blista Compact","Police Maverick","Boxville","Benson","Mesa","RC Goblin","Hotring Racer A","Hotring Racer B","Bloodring Banger","Rancher","Super GT","Elegant","Journey","Bike","Mountain Bike","Beagle","Cropduster","Stunt","Tanker","Roadtrain","Nebula","Majestic","Buccaneer","Shamal","Hydra","FCR-900","NRG-500","HPV1000","Cement Truck","Tow Truck","Fortune","Cadrona","FBI Truck","Willard","Forklift","Tractor","Combine","Feltzer","Remington","Slamvan","Blade","Freight","Streak","Vortex","Vincent","Bullet","Clover","Sadler","Firetruck","Hustler","Intruder","Primo","Cargobob","Tampa","Sunrise","Merit","Utility","Nevada","Yosemite","Windsor","Monster","Monster","Uranus","Jester","Sultan","Stratum","Elegy","Raindance","RC Tiger","Flash","Tahoma","Savanna","Bandito","Freight Flat","Streak Carriage","Kart","Mower","Dune","Sweeper","Broadway","Tornado","AT-400","DFT-30","Huntley","Stafford","BF-400","News Van","Tug","Trailer","Emperor","Wayfarer","Euros","Hotdog","Club","Freight Box","Trailer","Andromada","Dodo","RC Cam","Launch","Police Car","Police Car","Police Car","Police Ranger","Picador","S.W.A.T.","Alpha","Phoenix","Glendale (Beschaedigt)","Sadler (Beschaedigt)","Luggage","Luggage","Stairs","Boxville","Tiller","Utility Trailer"]

; --- interner Zustand ---
global YK_hProc  := 0
global YK_dwPID  := 0
global YK_memOK  := false

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

YkGame_Hwnd() {
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
    for i, exe in YkGame_ExeList() {
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
; eintragen (z.B. fuer einen eigenen Launcher).
YkGame_ExeList() {
    global YK_GameExes
    static cache := "", src := "#"
    if (src == YK_GameExes && IsObject(cache))
        return cache
    src := YK_GameExes
    cache := ["gta_sa.exe"]
    for i, e in StrSplit(YK_GameExes, ",") {
        e := Trim(e)
        if (e != "" && e != "gta_sa.exe")
            cache.Push(e)
    }
    return cache
}

; Fenstergruppe fuer die Hotkeys ("Hotkey, IfWinActive, ahk_group YkGame")
YkGame_Groups() {
    for i, exe in YkGame_ExeList()
        GroupAdd, YkGame, % "ahk_exe " . exe
}

YkGame_Pid() {
    global g_GamePid
    YkGame_Hwnd()
    return g_GamePid
}

; Ist das Spiel das Vordergrundfenster? Liefert dessen Fenster-Kennung
; (wie frueher WinActive) oder 0 - damit ueberall einsetzbar.
YkGame_Active() {
    pid := YkGame_Pid()
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
YkGame_Fullscreen() {
    global g_GamePid
    static seenPid := 0, lastT := 0
    h := YkGame_Hwnd()
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
    if (!YkGame_Active())
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
YkMem_Ensure() {
    global YK_hProc, YK_dwPID, YK_memOK
    pid := YkGame_Pid()
    if (!pid) {
        if (YK_hProc) {
            DllCall("CloseHandle", "Ptr", YK_hProc)
            YK_hProc := 0
        }
        YK_dwPID := 0
        YK_memOK := false
        return false
    }
    if (!YK_hProc || YK_dwPID != pid) {
        if (YK_hProc)
            DllCall("CloseHandle", "Ptr", YK_hProc)
        ; 0x0010 = PROCESS_VM_READ, 0x0400 = PROCESS_QUERY_INFORMATION
        YK_hProc := DllCall("OpenProcess", "UInt", 0x0010|0x0400, "Int", 0, "UInt", pid, "Ptr")
        if (!YK_hProc) {
            YK_dwPID := 0
            YK_memOK := false
            return false
        }
        YK_dwPID := pid
    }
    YK_memOK := true
    return true
}

YkMem_Close() {
    global YK_hProc, YK_dwPID, YK_memOK
    if (YK_hProc)
        DllCall("CloseHandle", "Ptr", YK_hProc)
    YK_hProc := 0
    YK_dwPID := 0
    YK_memOK := false
}

; liefert true wenn gerade lesbar
YkMem_Active() {
    global YK_memOK
    return YK_memOK
}

YkMem_ReadUInt(addr) {
    global YK_hProc
    if (!YK_hProc)
        return 0
    VarSetCapacity(buf, 4, 0)
    ok := DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", addr, "Ptr", &buf, "UPtr", 4, "UPtr*", read)
    if (!ok)
        return 0
    return NumGet(buf, 0, "UInt")
}

YkMem_ReadInt(addr) {
    global YK_hProc
    if (!YK_hProc)
        return 0
    VarSetCapacity(buf, 4, 0)
    ok := DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", addr, "Ptr", &buf, "UPtr", 4, "UPtr*", read)
    if (!ok)
        return 0
    return NumGet(buf, 0, "Int")
}

YkMem_ReadFloat(addr) {
    global YK_hProc
    if (!YK_hProc)
        return 0.0
    VarSetCapacity(buf, 4, 0)
    ok := DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", addr, "Ptr", &buf, "UPtr", 4, "UPtr*", read)
    if (!ok)
        return 0.0
    return NumGet(buf, 0, "Float")
}

; Position als Objekt {x,y,z} oder "" bei Fehler / ungueltig
YkMem_GetPosition() {
    global YK_ADDR_POS_X, YK_ADDR_POS_Y, YK_ADDR_POS_Z
    if (!YkMem_Active())
        return ""
    x := YkMem_ReadFloat(YK_ADDR_POS_X)
    y := YkMem_ReadFloat(YK_ADDR_POS_Y)
    z := YkMem_ReadFloat(YK_ADDR_POS_Z)
    ; Plausibilitaet: SA-Welt liegt etwa in +/-3500
    if (x = 0 && y = 0 && z = 0)
        return ""
    if (x < -4000 || x > 4000 || y < -4000 || y > 4000)
        return ""
    return {x: x, y: y, z: z}
}

; Leben (0..100+) oder -1 bei Fehler
YkMem_GetHealth() {
    global YK_ADDR_CPED_PTR, YK_ADDR_CPED_HP
    if (!YkMem_Active())
        return -1
    ped := YkMem_ReadUInt(YK_ADDR_CPED_PTR)
    if (!ped)
        return -1
    hp := YkMem_ReadFloat(ped + YK_ADDR_CPED_HP)
    return Round(hp)
}

; Ruestung (0..100+) oder -1 bei Fehler
YkMem_GetArmor() {
    global YK_ADDR_CPED_PTR, YK_ADDR_CPED_ARMOR
    if (!YkMem_Active())
        return -1
    ped := YkMem_ReadUInt(YK_ADDR_CPED_PTR)
    if (!ped)
        return -1
    ar := YkMem_ReadFloat(ped + YK_ADDR_CPED_ARMOR)
    return Round(ar)
}

; true = im Fahrzeug, false = zu Fuss, -1 unbekannt
YkMem_InVehicle() {
    global YK_ADDR_VEHICLE_PTR
    if (!YkMem_Active())
        return -1
    veh := YkMem_ReadUInt(YK_ADDR_VEHICLE_PTR)
    return (veh > 0) ? true : false
}

; Fahrzeug-ModellID (400..611) oder 0 wenn nicht im Fahrzeug/Fehler
YkMem_GetVehicleModelId() {
    global YK_ADDR_VEHICLE_PTR, YK_ADDR_VEHICLE_MODEL
    if (!YkMem_Active())
        return 0
    veh := YkMem_ReadUInt(YK_ADDR_VEHICLE_PTR)
    if (!veh)
        return 0
    VarSetCapacity(buf, 2, 0)
    global YK_hProc
    ok := DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", veh + YK_ADDR_VEHICLE_MODEL, "Ptr", &buf, "UPtr", 2, "UPtr*", read)
    if (!ok)
        return 0
    return NumGet(buf, 0, "UShort")
}

; Klarname des aktuellen Fahrzeugs oder "" wenn nicht im Fahrzeug/unbekannt
YkMem_GetVehicleName() {
    global YK_VehicleNames
    id := YkMem_GetVehicleModelId()
    if (id < 400 || id > 611)
        return ""
    idx := id - 399
    if (idx < 1 || idx > YK_VehicleNames.MaxIndex())
        return ""
    return YK_VehicleNames[idx]
}

YkMem_GetInterior() {
    global YK_ADDR_INTERIOR
    if (!YkMem_Active())
        return -1
    return YkMem_ReadInt(YK_ADDR_INTERIOR)
}

; Wie YkMem_ReadUInt, unterscheidet aber "Wert 0" von "nicht lesbar".
YkMem_TryUInt(addr, ByRef val) {
    global YK_hProc
    val := 0
    if (!YK_hProc || addr < 0x10000)
        return false
    VarSetCapacity(buf, 4, 0)
    if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", addr, "Ptr", &buf, "UPtr", 4, "Ptr", 0)
        return false
    val := NumGet(buf, 0, "UInt")
    return true
}

; Dasselbe fuer ein einzelnes Byte (Zustandsbits der Figuren)
YkMem_TryUChar(addr, ByRef val) {
    global YK_hProc
    val := 0
    if (!YK_hProc || addr < 0x10000)
        return false
    VarSetCapacity(buf, 1, 0)
    if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", addr, "Ptr", &buf, "UPtr", 1, "Ptr", 0)
        return false
    val := NumGet(buf, 0, "UChar")
    return true
}

; ---------------------------------------------------------------------
;  Fuer die Kill-Erkennung (feste gta_sa.exe-Adressen, live geprueft)
; ---------------------------------------------------------------------
; Aktive Waffe des eigenen Spielers: Typ und Gesamtmunition
YkMem_ActiveWeapon(ByRef wType, ByRef ammo) {
    global YK_hProc, YK_ADDR_CPED_PTR
    wType := -1
    ammo := -1
    if (!YkMem_Active())
        return false
    ped := YkMem_ReadUInt(YK_ADDR_CPED_PTR)
    if (!ped)
        return false
    VarSetCapacity(sb, 1, 0)
    if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", ped + 0x718, "Ptr", &sb, "UPtr", 1, "Ptr", 0)
        return false
    slot := NumGet(sb, 0, "UChar")
    if (slot > 12)
        return false
    VarSetCapacity(wb, 0x10, 0)
    if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", ped + 0x5A0 + slot * 0x1C, "Ptr", &wb, "UPtr", 0x10, "Ptr", 0)
        return false
    wType := NumGet(wb, 0, "Int")
    ammo := NumGet(wb, 0xC, "Int")
    return true
}

; Kamera: Blickrichtung (0xB6F9AC) und Position (0xB6F9CC)
YkMem_Camera() {
    global YK_hProc
    if (!YkMem_Active())
        return ""
    VarSetCapacity(cb, 0x2C, 0)
    if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", 0xB6F9AC, "Ptr", &cb, "UPtr", 0x2C, "Ptr", 0)
        return ""
    fx := NumGet(cb, 0, "Float"), fy := NumGet(cb, 4, "Float"), fz := NumGet(cb, 8, "Float")
    l := Sqrt(fx * fx + fy * fy + fz * fz)
    if (l < 0.5 || l > 1.5)
        return ""
    return {fx: fx / l, fy: fy / l, fz: fz / l
        , cx: NumGet(cb, 0x20, "Float"), cy: NumGet(cb, 0x24, "Float"), cz: NumGet(cb, 0x28, "Float")}
}

; Zeiger auf die eigene Figur und das eigene Fahrzeug (0 = keins)
YkMem_OwnPtrs(ByRef ped, ByRef veh) {
    global YK_ADDR_CPED_PTR, YK_ADDR_VEHICLE_PTR
    ped := YkMem_Active() ? YkMem_ReadUInt(YK_ADDR_CPED_PTR) : 0
    veh := YkMem_Active() ? YkMem_ReadUInt(YK_ADDR_VEHICLE_PTR) : 0
}

; Wer hat MICH zuletzt verletzt? Zeiger auf Figur oder Fahrzeug, 0 = unbekannt.
;
; Es ist genau dasselbe Feld, das YkMem_Peds fuer fremde Figuren mitliest
; (CPed + 0x764, "letzter Schadensverursacher") - nur eben an der eigenen
; Figur. Daraus wird der Name des Moerders: der Zeiger wandert durch
; YkSamp_NameForPed in die SA-MP-Spielerliste.
YkMem_LastDamager() {
    global YK_ADDR_CPED_PTR
    if (!YkMem_Active())
        return 0
    ped := YkMem_ReadUInt(YK_ADDR_CPED_PTR)
    if (!ped)
        return 0
    if !YkMem_TryUInt(ped + 0x764, v)
        return 0
    return (v > 0x10000) ? v : 0
}

; Feuert die EIGENE Figur gerade? (CPed + 0x46E, Bit 1)
;
; Genau dasselbe Feld, das YkMem_Peds fuer fremde Figuren mitliest. Es ist
; die einzige Schuss-Auskunft, die unabhaengig von der Munition ist:
; auf Servern mit unbegrenzter Munition sinkt der Munitionszaehler nie,
; und der Binder hat daraus frueher geschlossen, es sei nie geschossen
; worden - und dann auch nie einen Kill gezaehlt.
YkMem_OwnFire() {
    global YK_ADDR_CPED_PTR
    if (!YkMem_Active())
        return false
    ped := YkMem_ReadUInt(YK_ADDR_CPED_PTR)
    if (!ped)
        return false
    if !YkMem_TryUChar(ped + 0x46E, v)
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
YkMem_Peds(maxDist := 200) {
    global YK_hProc, YK_ADDR_CPED_PTR, YK_ADDR_POS_X
    if (!YkMem_Active())
        return ""
    pool := YkMem_ReadUInt(0xB74490)
    if (!pool)
        return ""
    VarSetCapacity(ph, 12, 0)
    if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", pool, "Ptr", &ph, "UPtr", 12, "Ptr", 0)
        return ""
    objs := NumGet(ph, 0, "UInt"), map := NumGet(ph, 4, "UInt"), size := NumGet(ph, 8, "Int")
    ; die Figuren-Liste von GTA hat 140 Plaetze - alles deutlich darueber
    ; ist ein Lesefehler und wuerde nur Zeit kosten
    if (!objs || !map || size <= 0 || size > 256)
        return ""
    VarSetCapacity(fl, size, 0)
    if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", map, "Ptr", &fl, "UPtr", size, "Ptr", 0)
        return ""
    me := YkMem_ReadUInt(YK_ADDR_CPED_PTR)
    mx := YkMem_ReadFloat(YK_ADDR_POS_X)
    my := YkMem_ReadFloat(YK_ADDR_POS_X + 4)
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
        if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", p + 0x14, "Ptr", &mp, "UPtr", 4, "Ptr", 0)
            continue
        m := NumGet(mp, 0, "UInt")
        if (m < 0x10000)
            continue
        ; 2) Lage-Matrix: Blickrichtung (+0x10) und Position (+0x30)
        if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", m, "Ptr", &mb, "UPtr", 0x3C, "Ptr", 0)
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
        if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", p, "Ptr", &pb, "UPtr", 0x768, "Ptr", 0)
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
global YK_SampBase     := 0
global YK_SampSize     := 0
global YK_SampPid      := 0
global YK_SampSet      := ""     ; bestaetigter Adress-Satz oder ""
global YK_SampNextScan := 0

YkSamp_Sets() {
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
YkSamp_FindBase(pid) {
    global YK_SampBase, YK_SampSize
    YK_SampBase := 0
    YK_SampSize := 0
    ; 0x18 = TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32
    snap := DllCall("CreateToolhelp32Snapshot", "UInt", 0x18, "UInt", pid, "Ptr")
    if (!snap || snap = -1)
        return false
    VarSetCapacity(me, 1064, 0)          ; MODULEENTRY32W (32 Bit)
    NumPut(1064, me, 0, "UInt")
    if DllCall("Module32FirstW", "Ptr", snap, "Ptr", &me) {
        Loop {
            if (StrGet(&me + 32, 256, "UTF-16") = "samp.dll") {
                YK_SampBase := NumGet(me, 20, "UInt")
                YK_SampSize := NumGet(me, 24, "UInt")
                break
            }
            if !DllCall("Module32NextW", "Ptr", snap, "Ptr", &me)
                break
        }
    }
    DllCall("CloseHandle", "Ptr", snap)
    return (YK_SampBase != 0)
}

; Einen Adress-Satz lesen und pruefen.
; Liefert {cur, inp, dlg} oder "" wenn nicht lesbar oder Struktur falsch.
YkSamp_ReadSet(st) {
    global YK_SampBase, YK_SampSize
    if (st.game + 4 > YK_SampSize)
        return ""
    if !YkMem_TryUInt(YK_SampBase + st.dlg, pD)
        return ""
    if !YkMem_TryUInt(YK_SampBase + st.inp, pI)
        return ""
    if !YkMem_TryUInt(YK_SampBase + st.game, pG)
        return ""
    if (pD < 0x10000 || pI < 0x10000 || pG < 0x10000)
        return ""
    ; Strukturtest: beide Objekte beginnen mit demselben D3D-Geraet
    if !YkMem_TryUInt(pD, devD)
        return ""
    if !YkMem_TryUInt(pI, devI)
        return ""
    if (devD < 0x10000 || devD != devI)
        return ""
    if !YkMem_TryUInt(pG + st.cur, cur)
        return ""
    if !YkMem_TryUInt(pI + 0x14E0, inp)
        return ""
    if !YkMem_TryUInt(pD + 0x28, dlg)
        return ""
    ; Wertebereich: Cursor-Modus 0..4, die beiden anderen sind BOOL
    if (cur > 4 || inp > 1 || dlg > 1)
        return ""
    return {cur: cur, inp: inp, dlg: dlg}
}

YkSamp_Eval(s, ByRef isChat) {
    isChat := (s.inp = 1) ? 1 : 0
    ; Cursor-Modus != 0 heisst: SA-MP hat Tastatur/Maus fuer eine
    ; Oberflaeche gesperrt (Chat, Dialog, Menue) - Hotkeys gehoeren weg.
    return (s.cur != 0 || s.inp = 1 || s.dlg = 1) ? 1 : 0
}

; -1 = unbekannt (Spiel/SA-MP nicht lesbar oder Version nicht bestaetigt)
;  0 = nichts offen
;  1 = SA-MP hat die Tastatur (Chat, Dialog, Menue)
; isChat wird 1, wenn es konkret die Chat-Eingabe ist.
YkSamp_InputState(ByRef isChat) {
    global YK_dwPID, YK_SampPid, YK_SampBase, YK_SampSet, YK_SampNextScan
    isChat := 0
    if (!YkMem_Active() || !YK_dwPID)
        return -1

    ; neuer Prozess oder samp.dll noch nicht gefunden -> gedrosselt suchen
    if (YK_SampPid != YK_dwPID || !YK_SampBase) {
        if (YK_SampPid = YK_dwPID && A_TickCount < YK_SampNextScan)
            return -1
        YK_SampPid := YK_dwPID
        YK_SampSet := ""
        YK_SampNextScan := A_TickCount + 3000
        if !YkSamp_FindBase(YK_dwPID)
            return -1
        YK_SampNextScan := 0
    }

    if (IsObject(YK_SampSet)) {
        s := YkSamp_ReadSet(YK_SampSet)
        if (IsObject(s))
            return YkSamp_Eval(s, isChat)
        ; voruebergehend ungueltig (z.B. Verbindungsaufbau) -> neu pruefen
        YK_SampSet := ""
        YK_SampNextScan := A_TickCount + 1000
    }

    if (A_TickCount < YK_SampNextScan)
        return -1
    YK_SampNextScan := A_TickCount + 1000
    for i, st in YkSamp_Sets() {
        s := YkSamp_ReadSet(st)
        if (IsObject(s)) {
            YK_SampSet := st
            return YkSamp_Eval(s, isChat)
        }
    }
    return -1
}

; Name der erkannten SA-MP-Version oder ""
YkSamp_VersionName() {
    global YK_SampSet
    return IsObject(YK_SampSet) ? YK_SampSet.n : ""
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
global YK_TdPool     := 0
global YK_TdPid      := 0
global YK_TdNextFind := 0
global YK_TdHits     := ""    ; Plaetze, die zuletzt Text mit Ziffern hatten
global YK_TdFullT    := 0     ; letzter vollstaendiger Durchgang

; Texte aller Textdraws mit Ziffern (Stand, Zeit) oder "" = nicht lesbar
;
; Frueher wurden hier jede Sekunde alle 2304 Plaetze einzeln aus dem Spiel
; gelesen - bei einem Server mit vielen Anzeigen sind das hunderte
; Speicherzugriffe pro Sekunde, mitten im laufenden Spiel. Jetzt merkt sich
; der Binder, an welchen Plaetzen ueberhaupt etwas Brauchbares stand, und
; liest nur noch diese; komplett durchgesehen wird nur alle 5 Sekunden
; (und sofort, wenn die gemerkten Plaetze leer laufen).
YkSamp_TextDraws() {
    global YK_hProc, YK_SampBase, YK_SampSet, YK_dwPID, YK_TdPool, YK_TdPid, YK_TdNextFind
    global YK_TdHits, YK_TdFullT
    if (!YkMem_Active() || !YK_SampBase || !IsObject(YK_SampSet) || !YK_SampSet.net)
        return ""
    if (YK_TdPid != YK_dwPID) {
        YK_TdPid := YK_dwPID
        YK_TdPool := 0
        YK_TdNextFind := 0
        YK_TdHits := ""
    }
    VarSetCapacity(pb, 0x4800, 0)
    if (YK_TdPool && !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", YK_TdPool, "Ptr", &pb, "UPtr", 0x4800, "Ptr", 0))
        YK_TdPool := 0
    if (!YK_TdPool) {
        if (A_TickCount < YK_TdNextFind)
            return ""
        YK_TdNextFind := A_TickCount + 3000
        YK_TdHits := ""
        if (!YkMem_TryUInt(YK_SampBase + YK_SampSet.net, net) || !YkMem_TryUInt(net + YK_SampSet.pools, pools))
            return ""
        Loop, 10 {
            if (!YkMem_TryUInt(pools + (A_Index - 1) * 4, t) || t < 0x10000)
                continue
            if (DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", t, "Ptr", &pb, "UPtr", 0x4800, "Ptr", 0)
                && YkSamp_TdValid(pb)) {
                YK_TdPool := t
                break
            }
        }
        if (!YK_TdPool)
            return ""
    }
    full := (!IsObject(YK_TdHits) || !YK_TdHits.MaxIndex() || (A_TickCount - YK_TdFullT) > 5000)
    out := []
    hits := []
    VarSetCapacity(tb, 256, 0)
    list := full ? "" : YK_TdHits
    n := full ? 2304 : list.MaxIndex()
    Loop, % n {
        i := full ? A_Index : list[A_Index]
        v := NumGet(pb, (i - 1) * 4, "UInt")
        if (!v)
            continue
        p := NumGet(pb, 0x2400 + (i - 1) * 4, "UInt")
        if (v > 1 || p < 0x10000) {             ; Struktur passt nicht mehr
            YK_TdPool := 0
            YK_TdHits := ""
            return ""
        }
        if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", p, "Ptr", &tb, "UPtr", 255, "Ptr", 0)
            continue
        NumPut(0, tb, 255, "UChar")
        s := StrGet(&tb, 255, "CP1252")
        if RegExMatch(s, "\d") {
            out.Push(s)
            hits.Push(i)
        }
    }
    if (full) {
        YK_TdHits := hits
        YK_TdFullT := A_TickCount
    } else if (!hits.MaxIndex()) {
        YK_TdHits := ""          ; nichts mehr da -> beim naechsten Mal alles durchsehen
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
;  und in YkSamp_ReadSet bereits geprueft ist nur: der Zeiger auf das
;  Dialog-Objekt und darin +0x28 = "Dialog ist offen". Der Textzeiger wird
;  von dort aus durch die naechsten Felder gesucht - genommen wird das
;  erste, hinter dem wirklich lesbarer Text steht. Der gefundene Platz
;  wird gemerkt und bei jedem Lesen gegengeprueft; passt er nicht mehr
;  (Reconnect, andere samp.dll), wird neu gesucht. Findet sich nichts,
;  kommt "" zurueck - dann bleibt es bei den Server-Anzeigen.
global YK_DlgTextOff := -1
global YK_DlgPid     := 0

; Ist gerade ein SA-MP-Dialog offen?  -1 unbekannt, 0 nein, 1 ja
YkSamp_DialogOpen() {
    global YK_SampBase, YK_SampSet
    if (!YkMem_Active() || !YK_SampBase || !IsObject(YK_SampSet))
        return -1
    if (!YkMem_TryUInt(YK_SampBase + YK_SampSet.dlg, pD) || pD < 0x10000)
        return -1
    if (!YkMem_TryUInt(pD + 0x28, act) || act > 1)
        return -1
    return act
}

YkSamp_DialogText() {
    global YK_SampBase, YK_SampSet, YK_dwPID, YK_DlgTextOff, YK_DlgPid
    if (!YkMem_Active() || !YK_SampBase || !IsObject(YK_SampSet))
        return ""
    if (YK_DlgPid != YK_dwPID) {
        YK_DlgPid := YK_dwPID
        YK_DlgTextOff := -1
    }
    if (!YkMem_TryUInt(YK_SampBase + YK_SampSet.dlg, pD) || pD < 0x10000)
        return ""
    ; +0x28: liegt ueberhaupt ein Dialog offen? (derselbe Wert, ueber den
    ; YkSamp_ReadSet die Version bestaetigt)
    if (!YkMem_TryUInt(pD + 0x28, act) || act != 1)
        return ""
    if (YK_DlgTextOff >= 0) {
        s := YkSamp_DlgTextAt(pD, YK_DlgTextOff)
        if (s != "")
            return s
        YK_DlgTextOff := -1
    }
    off := 0x2C
    while (off <= 0x60) {
        s := YkSamp_DlgTextAt(pD, off)
        if (s != "") {
            YK_DlgTextOff := off
            return s
        }
        off += 4
    }
    return ""
}

; Steht an dieser Stelle des Dialogs ein Zeiger auf brauchbaren Text?
YkSamp_DlgTextAt(pD, off) {
    global YK_hProc
    if (!YkMem_TryUInt(pD + off, p) || p < 0x10000)
        return ""
    VarSetCapacity(b, 2049, 0)
    ; am Ende des Speicherbereichs schlaegt das grosse Lesen fehl - dann
    ; genuegt ein kleiner Happen (die Zahlen stehen ohnehin vorne)
    if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", p, "Ptr", &b, "UPtr", 2048, "Ptr", 0) {
        VarSetCapacity(b, 2049, 0)
        if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", p, "Ptr", &b, "UPtr", 128, "Ptr", 0)
            return ""
    }
    NumPut(0, b, 2048, "UChar")
    s := StrGet(&b, 2048, "CP1252")
    return YkSamp_TextOk(s) ? s : ""
}

; Sieht das nach echtem Text aus - und nicht nach zufaelligen Bytes?
YkSamp_TextOk(s) {
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
YkSamp_LastInput(ByRef s, ByRef sig) {
    global YK_hProc, YK_SampBase, YK_SampSet
    s := "", sig := ""
    if (!YkMem_Active() || !YK_SampBase || !IsObject(YK_SampSet) || YK_SampSet.n != "0.3.7-R5")
        return false
    if !YkMem_TryUInt(YK_SampBase + YK_SampSet.inp, pI)
        return false
    VarSetCapacity(b, 1291, 0)
    if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", pI + 0x1565, "Ptr", &b, "UPtr", 1290, "Ptr", 0)
        return false
    s := StrGet(&b, 129, "CP1252")
    Loop, 10
        sig .= StrGet(&b + (A_Index - 1) * 129, 129, "CP1252") . "|"
    return true
}

; Pausenmenue von GTA offen? (CMenuManager +0x5C, 0xBA67A4)
YkMem_MenuActive() {
    if (!YkMem_Active() || !YkMem_TryUInt(0xBA67A4, v))
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
global YK_PlrEnabled := true
global YK_PlrPool    := 0        ; Block mit der Spielerliste
global YK_PlrOff     := -1       ; Offset des Zeigerfeldes darin
global YK_PlrChain   := ""       ; Weg vom Eintrag zur Spielfigur, z.B. [0, 4, 44]
global YK_PlrNameOff := -1       ; Offset des Namens im Eintrag
global YK_PlrNamePtr := false    ; Name liegt als Zeiger vor
global YK_PlrPid     := 0
global YK_PlrNext    := 0        ; naechster Lernversuch
global YK_PlrTries   := 0
global YK_PlrReads   := 0        ; Lesezaehler: bremst die Suche
global YK_PlrCache   := {}       ; Figur -> {name, t}: nicht bei jedem Kill
                                 ; die ganze Liste durchgehen

YkSamp_PlrReset() {
    global YK_PlrPool, YK_PlrOff, YK_PlrChain, YK_PlrNameOff, YK_PlrNamePtr, YK_PlrTries, YK_PlrNext, YK_PlrCache
    YK_PlrCache := {}
    YK_PlrPool := 0
    YK_PlrOff := -1
    YK_PlrChain := ""
    YK_PlrNameOff := -1
    YK_PlrNamePtr := false
    YK_PlrTries := 0
    YK_PlrNext := 0
}

; "aus" | "nicht gefunden" | "erkannt"  (fuer die Anzeige im Fenster)
YkSamp_PlrState() {
    global YK_PlrEnabled, YK_PlrChain, YK_PlrNameOff, YK_PlrTries
    if (!YK_PlrEnabled)
        return "aus"
    if (IsObject(YK_PlrChain) && YK_PlrNameOff >= 0)
        return "erkannt"
    return (YK_PlrTries >= 8) ? "nicht gefunden" : "wird gesucht"
}

; Ist das ein gueltiger SA-MP-Name?
YkSamp_NickOk(s) {
    n := StrLen(s)
    if (n < 3 || n > 24)
        return false
    return RegExMatch(s, "^[A-Za-z0-9_\[\]\(\)\$@\.=]+$") > 0
}

; Name an einer Adresse lesen ("" = dort steht keiner)
YkSamp_NickAt(addr, deref) {
    global YK_hProc, YK_PlrReads
    if (deref) {
        if (!YkMem_TryUInt(addr, np) || np < 0x10000 || np > 0x7FF00000)
            return ""
        addr := np
    }
    YK_PlrReads += 1
    VarSetCapacity(nb, 32, 0)
    if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", addr, "Ptr", &nb, "UPtr", 25, "Ptr", 0)
        return ""
    NumPut(0, nb, 25, "UChar")
    s := StrGet(&nb, 25, "CP1252")
    return YkSamp_NickOk(s) ? s : ""
}

; Den Block mit der Spielerliste suchen: 1004 Zeiger, dahinter 1004
; Ja/Nein-Werte, die genau zu den Zeigern passen.
YkSamp_PlrPoolOff(ByRef pb) {
    bestOff := -1, bestCnt := 0
    o := 0
    while (o <= 0x80) {
        ; erst nur die niedrigen Spieler-Nummern ansehen - das wirft die
        ; allermeisten Stellen sofort raus und kostet fast nichts
        if (YkSamp_PlrCheck(pb, o, 128) >= 1) {
            full := YkSamp_PlrCheck(pb, o, 1004)
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
YkSamp_PlrCheck(ByRef pb, o, n) {
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

YkSamp_PlrFind() {
    global YK_hProc, YK_SampBase, YK_SampSet, YK_PlrPool, YK_PlrOff, YK_TdPool
    if (!YkMem_Active() || !YK_SampBase || !IsObject(YK_SampSet) || !YK_SampSet.net)
        return false
    if (!YkMem_TryUInt(YK_SampBase + YK_SampSet.net, net) || !YkMem_TryUInt(net + YK_SampSet.pools, pools))
        return false
    VarSetCapacity(pb, 0x2100, 0)
    Loop, 10 {
        if (!YkMem_TryUInt(pools + (A_Index - 1) * 4, t) || t < 0x10000)
            continue
        if (t = YK_TdPool)                       ; das ist der Textdraw-Pool
            continue
        if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", t, "Ptr", &pb, "UPtr", 0x2100, "Ptr", 0)
            continue
        o := YkSamp_PlrPoolOff(pb)
        if (o >= 0) {
            YK_PlrPool := t
            YK_PlrOff := o
            return true
        }
    }
    return false
}

; Alle belegten Listeneintraege ("" = nicht lesbar)
YkSamp_PlrList() {
    global YK_hProc, YK_PlrPool, YK_PlrOff
    if (!YK_PlrPool || YK_PlrOff < 0)
        return ""
    VarSetCapacity(ab, 4016, 0)
    if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", YK_PlrPool + YK_PlrOff, "Ptr", &ab, "UPtr", 4016, "Ptr", 0)
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
YkSamp_PedOf(rp, ch := "") {
    global YK_PlrChain
    if (!IsObject(ch))
        ch := YK_PlrChain
    if (!IsObject(ch))
        return 0
    v := rp
    for i, o in ch {
        if (!YkMem_TryUInt(v + o, nv) || nv < 0x10000 || nv > 0x7FF00000)
            return 0
        v := nv
    }
    return v
}

; Suche nach einer bekannten Spielfigur, hoechstens drei Ebenen tief.
; Liefert den Weg dorthin als Liste von Offsets oder "".
YkSamp_PlrWalk(base, pedSet, depth) {
    global YK_hProc, YK_PlrReads
    if (YK_PlrReads > 2000)                      ; Notbremse
        return ""
    YK_PlrReads += 1
    VarSetCapacity(bb, 0x100, 0)
    if !DllCall("ReadProcessMemory", "Ptr", YK_hProc, "Ptr", base, "Ptr", &bb, "UPtr", 0x100, "Ptr", 0)
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
            sub := YkSamp_PlrWalk(v, pedSet, depth + 1)
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
YkSamp_ChainOk(ch, list, pedSet) {
    hits := 0
    seen := {}
    for i, rp in list {
        v := YkSamp_PedOf(rp, ch)
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
YkSamp_LearnName(list) {
    global YK_PlrNameOff, YK_PlrNamePtr
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
                nm := YkSamp_NickAt(rp + off, deref)
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
                YK_PlrNameOff := off
                YK_PlrNamePtr := deref
                return true
            }
            off += step
        }
    }
    return false
}

; Einmal alles lernen. peds = Figuren-Liste aus YkMem_Peds (die kennen wir
; sicher). Wird nur gelegentlich versucht und bricht selbst ab.
YkSamp_PlrLearn(peds) {
    global YK_PlrPool, YK_PlrChain, YK_PlrNameOff, YK_PlrTries, YK_PlrNext, YK_PlrReads
    if (!IsObject(peds) || peds.MaxIndex() < 2)
        return false
    if (A_TickCount < YK_PlrNext || YK_PlrTries >= 8)
        return false
    YK_PlrNext := A_TickCount + 5000
    YK_PlrTries += 1
    YK_PlrReads := 0
    if (!YK_PlrPool && !YkSamp_PlrFind())
        return false
    list := YkSamp_PlrList()
    if (!IsObject(list) || !list.MaxIndex()) {
        YK_PlrPool := 0
        return false
    }
    pedSet := {}
    for i, p in peds
        pedSet[p.id] := 1
    if (!IsObject(YK_PlrChain)) {
        for i, rp in list {
            ch := YkSamp_PlrWalk(rp, pedSet, 1)
            if (IsObject(ch) && YkSamp_ChainOk(ch, list, pedSet)) {
                YK_PlrChain := ch
                break
            }
            if (YK_PlrReads > 2000)
                break
        }
    }
    if (!IsObject(YK_PlrChain))
        return false
    if (YK_PlrNameOff < 0 && !YkSamp_LearnName(list))
        return false
    YK_PlrTries := 0
    return true
}

; Name zu einer Spielfigur - "" wenn unbekannt.
; peds = aktuelle Figuren-Liste (nur zum Lernen noetig)
YkSamp_NameForPed(ped, peds := "") {
    global YK_PlrEnabled, YK_dwPID, YK_PlrPid, YK_PlrChain, YK_PlrNameOff, YK_PlrNamePtr, YK_PlrPool, YK_PlrCache
    if (!YK_PlrEnabled || !ped || !YkMem_Active())
        return ""
    if (YK_PlrPid != YK_dwPID) {
        YK_PlrPid := YK_dwPID
        YkSamp_PlrReset()
    }
    if (!IsObject(YK_PlrChain) || YK_PlrNameOff < 0) {
        if (!YkSamp_PlrLearn(peds))
            return ""
    }
    ; kurz gemerkt: im Gefecht fallen mehrere Gegner hintereinander, und
    ; die ganze Liste durchzugehen kostet jedes Mal Speicherzugriffe
    c := YK_PlrCache[ped]
    if (IsObject(c) && (A_TickCount - c.t) < 5000)
        return c.name
    list := YkSamp_PlrList()
    if (!IsObject(list) || !list.MaxIndex()) {
        YK_PlrPool := 0                      ; z.B. nach einem Reconnect
        return ""
    }
    name := ""
    for i, rp in list {
        if (YkSamp_PedOf(rp) = ped) {
            name := YkSamp_NickAt(rp + YK_PlrNameOff, YK_PlrNamePtr)
            break
        }
    }
    if (YK_PlrCache.Count() > 64)
        YK_PlrCache := {}
    YK_PlrCache[ped] := {name: name, t: A_TickCount}
    return name
}

; Sieht der Speicherblock wie ein Textdraw-Pool aus?
YkSamp_TdValid(ByRef pb) {
    used := 0
    Loop, 2304 {
        v := NumGet(pb, (A_Index - 1) * 4, "UInt")
        if (v > 1 || (v && NumGet(pb, 0x2400 + (A_Index - 1) * 4, "UInt") < 0x10000))
            return false
        used += v
    }
    return (used > 0)
}
