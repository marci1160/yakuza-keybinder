; =====================================================================
;  Yakuza Keybinder - Backup-Fahne auf der Minimap
; ---------------------------------------------------------------------
;  Ruft ein Member ueber den Binder Backup, haengt sein Binder die
;  Koordinaten an:
;     /g Brauche Backup in Idlewood (Los Santos) (GPS 2066 -1703)
;  Die Binder der anderen Member setzen daraus eine rote Fahne auf die
;  Minimap und die grosse Karte. Kommt ein Ruf ohne Koordinaten (aelterer
;  Binder, von Hand getippt), wird die Mitte der genannten Zone markiert.
;
;  Technik - und warum das kein Cheat ist:
;  Das ist der EINZIGE Schreibzugriff des Binders. Er traegt ein Symbol in
;  die Kartensymbol-Liste von gta_sa.exe ein (175 Plaetze ab 0xBA86F0) -
;  dieselbe Liste, in die SA-MP die Kartensymbole des Servers legt.
;  Es wird nichts an den Server geschickt, kein Code eingeschleust, kein
;  Spielwert (Leben, Waffen, Position, Tempo) veraendert, und angezeigt
;  wird nur, was der Member selbst in den Chat geschrieben hat - keine
;  Gegner, keine fremden Positionen. Abschaltbar unter Overlay -> Familie.
;
;  Belegt werden nur freie Plaetze ganz hinten (Spiel und SA-MP vergeben
;  von vorne). Die Fahne verschwindet
;     - nach der eingestellten Zeit, spaetestens aber nach 10 Minuten
;       (gerechnet ab dem ERSTEN Ruf, nicht ab dem letzten),
;     - sobald der Rufende stirbt (eigene Meldung im /g oder Server-Zeile),
;     - wenn man angekommen ist (30 m),
;     - wenn der Member absagt ("erledigt", "kein Backup mehr", "danke"),
;     - beim Reconnect und beim Beenden des Binders.
;  Zusaetzlich gibt es eine zweite, andersfarbige Fahne fuer das selbst
;  gewaehlte Ziel ("Ich bin unterwegs zu ..."), siehe YkPlaceholders.ahk.
; =====================================================================

global YK_MarkEnabled := true      ; Backup-Rufe anderer auf der Karte markieren
global YK_MarkSendGps := true      ; eigene Backup-Rufe mit Koordinaten senden
global YK_MarkMinutes := 10        ; so lange bleibt eine Fahne stehen (max. 10)
global YK_MarkSprite  := 19        ; 19 = rote Fahne (radar_enemyAttack)
global YK_MarkTgtSpr  := 53        ; Fahne zum selbst gewaehlten Ziel (gruen)

; Harte Obergrenze: laenger als 10 Minuten steht keine Fahne, egal was
; eingestellt ist und egal wie oft der Member seinen Ruf wiederholt.
global YK_MARK_MAXMIN := 10

global g_Marks        := {}        ; Name -> {slot, x, y, z, t, t0, spr, kind}
global YK_MarkH       := 0         ; Handle mit Schreibrecht - nur fuer die Fahnen
global YK_MarkPid     := 0
global g_MarkSaveT    := 0         ; letztes Schreiben in die INI
global g_MarkSaveDue  := false
global g_MarkUsed     := {}        ; Platz -> wann zuletzt von uns beschrieben

global YK_RADAR_TRACE := 0xBA86F0  ; CRadar::ms_RadarTrace (gta_sa.exe 1.0 US)
global YK_RADAR_COUNT := 175       ; Eintraege zu je 0x28 Bytes

; ---------------------------------------------------------------------
;  Zugriff
; ---------------------------------------------------------------------
; Handle auf das laufende Spiel (lesen + schreiben). Wurde das Spiel neu
; gestartet, gibt es die alten Fahnen dort nicht mehr.
YkMark_Handle() {
    global YK_MarkH, YK_MarkPid, g_Marks, g_MarkUsed
    pid := YkGame_Pid()
    if (!pid) {
        YkMark_CloseHandle()
        if (YK_MarkPid) {
            g_Marks := {}
            g_MarkUsed := {}
        }
        YK_MarkPid := 0
        return 0
    }
    if (YK_MarkH && YK_MarkPid = pid)
        return YK_MarkH
    YkMark_CloseHandle()
    if (YK_MarkPid && YK_MarkPid != pid) {
        g_Marks := {}
        g_MarkUsed := {}
    }
    ; 0x10 VM_READ | 0x20 VM_WRITE | 0x08 VM_OPERATION | 0x400 QUERY_INFORMATION
    h := DllCall("OpenProcess", "UInt", 0x0438, "Int", 0, "UInt", pid, "Ptr")
    if (!h)
        return 0
    YK_MarkH := h
    YK_MarkPid := pid
    return h
}

YkMark_CloseHandle() {
    global YK_MarkH
    if (YK_MarkH)
        DllCall("CloseHandle", "Ptr", YK_MarkH)
    YK_MarkH := 0
}

YkMark_Read(h, addr, ByRef buf, n) {
    VarSetCapacity(buf, n, 0)
    return DllCall("ReadProcessMemory", "Ptr", h, "Ptr", addr, "Ptr", &buf, "UPtr", n, "Ptr", 0)
}

YkMark_Write(h, addr, ByRef buf, n) {
    return DllCall("WriteProcessMemory", "Ptr", h, "Ptr", addr, "Ptr", &buf, "UPtr", n, "Ptr", 0)
}

; freier Platz - von hinten gesucht, nur in den letzten 40; -1 = keiner
YkMark_FreeSlot(h) {
    global YK_RADAR_TRACE, YK_RADAR_COUNT, g_Marks
    if !YkMark_Read(h, YK_RADAR_TRACE, arr, YK_RADAR_COUNT * 0x28)
        return -1
    mine := {}
    for nm, mk in g_Marks
        mine[mk.slot] := 1
    for sl, t in g_MarkUsed          ; von uns belegte Plaetze nie doppelt vergeben
        mine[sl] := 1
    i := YK_RADAR_COUNT
    while (--i >= YK_RADAR_COUNT - 40) {
        if (mine.HasKey(i))
            continue
        o := i * 0x28
        ; +0x25 Bit 2 = in Benutzung, +0x26 = Typ/Anzeige
        if (!(NumGet(arr, o + 0x25, "UChar") & 2) && NumGet(arr, o + 0x26, "UChar") = 0)
            return i
    }
    return -1
}

; Kartensymbol in Platz "slot" eintragen - aufgebaut wie die Symbole, die
; SA-MP fuer den Server setzt (live verglichen: Typ 4, Anzeige 3, Flags 0x03)
YkMark_Put(h, slot, x, y, z, spr) {
    global YK_RADAR_TRACE, g_MarkUsed
    g_MarkUsed[slot] := A_TickCount       ; merken, auch wenn das Schreiben scheitert
    addr := YK_RADAR_TRACE + slot * 0x28
    if !YkMark_Read(h, addr, old, 0x28)
        return false
    cnt := NumGet(old, 0x14, "UShort")
    cnt := (cnt >= 0xFFFE) ? 1 : cnt + 1
    VarSetCapacity(t, 0x28, 0)
    NumPut(8, t, 0x00, "UInt")            ; Farbe (bei Symbolen ohne Wirkung)
    NumPut(0, t, 0x04, "UInt")            ; an keinem Objekt - fester Punkt
    NumPut(x, t, 0x08, "Float")
    NumPut(y, t, 0x0C, "Float")
    NumPut(z, t, 0x10, "Float")
    NumPut(cnt, t, 0x14, "UShort")        ; Zaehler wie beim Spiel hochzaehlen
    NumPut(1.0, t, 0x18, "Float")
    NumPut(1, t, 0x1C, "UShort")
    NumPut(0, t, 0x20, "UInt")
    NumPut(spr, t, 0x24, "UChar")
    NumPut(0x13, t, 0x26, "UChar")        ; Typ 4 = Koordinate, Anzeige 3 = Radar + Karte
    ; erst alles schreiben, dann "in Benutzung" setzen
    if !YkMark_Write(h, addr, t, 0x28)
        return false
    VarSetCapacity(f, 1, 0)
    NumPut(0x03, f, 0, "UChar")           ; hell + in Benutzung, auch aus der Ferne sichtbar
    return YkMark_Write(h, addr + 0x25, f, 1)
}

; steht in dem Platz noch unsere Fahne?
;
; Frueher wurde hier zusaetzlich die Position auf 0,5 Einheiten genau
; verglichen. Stimmte irgendetwas davon nicht mehr (das Spiel schreibt in
; der Liste durchaus herum), galt die Fahne als "nicht unsere": sie wurde
; aus der internen Liste geloescht, blieb im Spiel aber fuer immer stehen
; und war danach nicht mehr erreichbar. Genau das war der Grund, warum
; Backup-Fahnen nicht verschwanden. Jetzt zaehlt nur noch, ob in dem Platz
; ueberhaupt ein Koordinaten-Symbol unserer Bauart steht.
YkMark_IsOurs(h, mk) {
    global YK_RADAR_TRACE
    if !YkMark_Read(h, YK_RADAR_TRACE + mk.slot * 0x28, t, 0x28)
        return false
    return ((NumGet(t, 0x25, "UChar") & 2) && NumGet(t, 0x26, "UChar") = 0x13
        && NumGet(t, 0x24, "UChar") = mk.spr)
}

; Platz bedingungslos leeren. Wird benutzt, wenn der Eintrag nicht mehr
; wiederzuerkennen ist - besser ein fremdes Symbol weniger als eine Fahne,
; die bis zum Spielende auf der Karte klebt. Es werden ausschliesslich
; Plaetze angefasst, die der Binder selbst beschrieben hat.
YkMark_ForceFree(h, slot) {
    global YK_RADAR_TRACE, g_MarkUsed
    if (!h || slot < 0)
        return false
    addr := YK_RADAR_TRACE + slot * 0x28
    VarSetCapacity(f, 1, 0)
    YkMark_Write(h, addr + 0x25, f, 1)          ; zuerst "frei" ...
    VarSetCapacity(z, 3, 0)
    ok := YkMark_Write(h, addr + 0x24, z, 3)    ; ... dann Symbol, Flags, Typ/Anzeige
    if (ok)
        g_MarkUsed.Delete(slot)
    return ok
}

; ---------------------------------------------------------------------
;  Fahnen setzen / entfernen
; ---------------------------------------------------------------------
; Fahne fuer den Ruf eines Members setzen (oder verschieben).
; kind: "call" = Backup-Ruf (rot), "target" = selbst gewaehltes Ziel
YkMark_Set(name, x, y, z := 20, kind := "call") {
    global g_Marks, YK_MarkEnabled, YK_MemEnabled, YK_MarkSprite, YK_MarkTgtSpr
    if (!YK_MarkEnabled || !YK_MemEnabled)
        return false
    x += 0, y += 0, z += 0
    if (x < -3000 || x > 3000 || y < -3000 || y > 3000)
        return false
    h := YkMark_Handle()
    if (!h)
        return false
    slot := -1
    t0 := A_TickCount
    if (g_Marks.HasKey(name)) {
        old := g_Marks[name]
        ; Zeitpunkt des ERSTEN Rufs behalten - sonst verlaengert jeder
        ; weitere Ruf desselben Members die Fahne endlos
        if (old.t0)
            t0 := old.t0
        if (old.kind = kind && YkMark_IsOurs(h, old))
            slot := old.slot
        else
            YkMark_Remove(name)
        g_Marks.Delete(name)
    }
    ; hoechstens 5 Fahnen gleichzeitig - die aelteste macht Platz.
    ; Reste eines harten Abbruchs (?alt...) zaehlen nicht mit, die raeumt
    ; der naechste Takt ohnehin weg.
    n := 0, oldest := "", oldT := 0
    for nm, mk in g_Marks {
        if (SubStr(nm, 1, 4) = "?alt")
            continue
        n++
        if (oldest = "" || mk.t < oldT)
            oldest := nm, oldT := mk.t
    }
    if (n >= 5 && oldest != "")
        YkMark_Remove(oldest)
    if (slot < 0)
        slot := YkMark_FreeSlot(h)
    if (slot < 0)
        return false
    spr := (kind = "target") ? YK_MarkTgtSpr : YK_MarkSprite
    if (spr < 1 || spr > 63)
        spr := (kind = "target") ? 53 : 19
    if !YkMark_Put(h, slot, x, y, z, spr)
        return false
    g_Marks[name] := {slot: slot, x: x, y: y, z: z, t: A_TickCount, t0: t0, spr: spr, kind: kind}
    YkMark_SaveState()
    return true
}

YkMark_Remove(name) {
    global g_Marks
    if (!g_Marks.HasKey(name))
        return
    mk := g_Marks[name]
    g_Marks.Delete(name)
    h := YkMark_Handle()
    if (h)
        YkMark_ForceFree(h, mk.slot)
    YkMark_SaveState()
}

; Fahne eines Members entfernen, aber nur wenn sie von dieser Art ist
YkMark_RemoveKind(name, kind) {
    global g_Marks
    if (g_Marks.HasKey(name) && g_Marks[name].kind = kind)
        YkMark_Remove(name)
}

YkMark_ClearAll() {
    global g_Marks, g_MarkUsed
    names := []
    for nm, mk in g_Marks
        names.Push(nm)
    for i, nm in names
        YkMark_Remove(nm)
    g_Marks := {}
    ; auch Plaetze leeren, deren Eintrag verloren ging
    h := YkMark_Handle()
    if (h) {
        slots := []
        for sl, t in g_MarkUsed
            slots.Push(sl)
        for i, sl in slots
            YkMark_ForceFree(h, sl)
    }
    g_MarkUsed := {}
    YkMark_SaveState(true)
    YkMark_CloseHandle()
}

YkMark_Count() {
    global g_Marks
    n := 0
    for nm, mk in g_Marks
        n++
    return n
}

; Hat dieser Member gerade eine Backup-Fahne? (fuer Overlay/Member-Liste)
YkMark_HasCall(name) {
    global g_Marks
    return (g_Marks.HasKey(name) && g_Marks[name].kind = "call")
}

; aus dem Haupt-Timer: abgelaufene Fahnen weg, bei Ankunft weg,
; und vergessene Plaetze aufraeumen
YkMark_Tick() {
    global g_Marks, g_MarkUsed, YK_MarkMinutes, YK_MarkEnabled, YK_MemEnabled, YK_MARK_MAXMIN
    static last := 0
    if ((A_TickCount - last) < 1000)
        return
    last := A_TickCount
    YkMark_SaveState()                           ; wartendes Speichern nachholen
    used := false
    for sl, t in g_MarkUsed
        used := true
    if (!YkMark_Count() && !used)
        return
    if (!YK_MarkEnabled || !YK_MemEnabled) {
        YkMark_ClearAll()
        return
    }
    h := YkMark_Handle()
    if (!h)                                      ; Spiel zu -> Fahnen sind mit weg
        return
    mins := (YK_MarkMinutes >= 1) ? YK_MarkMinutes : 5
    if (mins > YK_MARK_MAXMIN)
        mins := YK_MARK_MAXMIN
    life := mins * 60000
    hard := YK_MARK_MAXMIN * 60000
    pos := YkMem_Active() ? YkMem_GetPosition() : ""
    drop := []
    for nm, mk in g_Marks {
        t0 := mk.t0 ? mk.t0 : mk.t
        if ((A_TickCount - mk.t) > life || (A_TickCount - t0) > hard)
            drop.Push(nm)
        else if (IsObject(pos) && ((pos.x - mk.x) ** 2 + (pos.y - mk.y) ** 2) < 900)
            drop.Push(nm)                        ; angekommen (30 m)
    }
    for i, nm in drop
        YkMark_Remove(nm)
    ; Sicherheitsnetz: Plaetze, die wir einmal beschrieben haben, zu denen
    ; es aber keinen Eintrag mehr gibt (z.B. nach einem Fehler), nach der
    ; Hoechstdauer bedingungslos leeren.
    live := {}
    for nm, mk in g_Marks
        live[mk.slot] := 1
    stale := []
    for sl, t in g_MarkUsed
        if (!live.HasKey(sl) && (A_TickCount - t) > 5000)
            stale.Push(sl)
    for i, sl in stale
        YkMark_ForceFree(h, sl)
}

; Ruf eines Members: mit Koordinaten genau dort, sonst Mitte der Zone
YkMark_OnCall(name, loc, gx, gy, kind := "call") {
    global YK_MarkEnabled
    if (!YK_MarkEnabled)
        return false
    me := YkCurrentPos()
    if (gx = "" || gy = "") {
        zone := RegExReplace(loc, "\s*\(.*$")
        if (zone = "" || zone = "Innenraum" || zone = "Unbekannt")
            return false
        c := YkZone_NearestCenter(zone, IsObject(me) ? me.x : 0, IsObject(me) ? me.y : 0)
        if (!IsObject(c))
            return false
        gx := c.x, gy := c.y
    }
    ; schon vor Ort -> keine Fahne noetig
    if (IsObject(me) && ((me.x - gx) ** 2 + (me.y - gy) ** 2) < 900)
        return false
    return YkMark_Set(name, gx, gy, 20, kind)
}

; ---------------------------------------------------------------------
;  Koordinaten im Chat
; ---------------------------------------------------------------------
; "(GPS 2066 -1703)" fuer den eigenen Standort - "" wenn unbekannt oder in
; einem Innenraum (dort sind die Koordinaten fuer die Karte wertlos)
YkMark_GpsText(pos := "") {
    if (!IsObject(pos))
        pos := YkCurrentPos()
    if (!IsObject(pos) || YkMem_GetInterior() > 0)
        return ""
    return "(GPS " . Round(pos.x) . " " . Round(pos.y) . ")"
}

; An einen Backup-Ruf in /g oder /f die Koordinaten haengen
YkMark_AddGps(text) {
    global YK_MarkSendGps, YK_MemEnabled, YK_GangCmd
    if (!YK_MarkSendGps || !YK_MemEnabled)
        return text
    sp := InStr(text, " ")
    if (!sp)
        return text
    cmd := SubStr(text, 1, sp - 1)
    body := SubStr(text, sp + 1)
    if (cmd != "/g" && cmd != "/f" && cmd != Trim(YK_GangCmd))
        return text
    if (!YkIsCallText(body) || YkIsCallCancel(body) || RegExMatch(body, "i)\bGPS\b"))
        return text
    gps := YkMark_GpsText()
    if (gps = "")
        return text
    out := RTrim(text) . " " . gps
    ; laenger als die SA-MP-Chatzeile -> lieber ohne Koordinaten
    return (StrLen(out) <= 128) ? out : text
}

; Koordinaten aus einer Chatzeile lesen
YkMark_ParseGps(msg, ByRef x, ByRef y) {
    x := "", y := ""
    if !RegExMatch(msg, "i)\bGPS\s*:?\s*(-?\d{1,4})\s*[ ,|/]\s*(-?\d{1,4})", m)
        return false
    if (Abs(m1) > 3000 || Abs(m2) > 3000)
        return false
    x := m1 + 0, y := m2 + 0
    return true
}

; ---------------------------------------------------------------------
;  Absicherung, falls der Binder hart beendet wird
; ---------------------------------------------------------------------
; Die belegten Plaetze stehen in der INI. Startet der Binder neu, waehrend
; dasselbe Spiel noch laeuft, werden sie beim ersten Takt aufgeraeumt.
; Wird bei jeder Fahnen-Aenderung gerufen. IniWrite schreibt sofort auf die
; Platte - im Gefecht waren das schnell mehrere Schreibvorgaenge pro Sekunde.
; Deshalb wird nur noch vorgemerkt und hoechstens alle 5 Sekunden (bzw.
; beim Beenden) wirklich geschrieben.
YkMark_SaveState(force := false) {
    global g_Marks, g_MarkUsed, YK_MarkPid, YK_IniPath, g_MarkSaveT, g_MarkSaveDue
    g_MarkSaveDue := true
    if (!force && (A_TickCount - g_MarkSaveT) < 5000)
        return
    g_MarkSaveDue := false
    g_MarkSaveT := A_TickCount
    s := ""
    done := {}
    for nm, mk in g_Marks {
        done[mk.slot] := 1
        s .= (s = "" ? "" : "|") . mk.slot . ":" . Round(mk.x, 1) . ":" . Round(mk.y, 1) . ":" . mk.spr
    }
    ; auch Plaetze sichern, zu denen kein Eintrag mehr gehoert - sonst
    ; bliebe so eine Fahne nach einem harten Abbruch fuer immer stehen
    for sl, t in g_MarkUsed {
        if (done.HasKey(sl))
            continue
        s .= (s = "" ? "" : "|") . sl . ":0:0:0"
    }
    IniWrite, % (s = "" ? 0 : YK_MarkPid), %YK_IniPath%, MarkerState, Pid
    IniWrite, % s, %YK_IniPath%, MarkerState, Slots
}

YkMark_RestoreState() {
    global g_Marks, g_MarkUsed, YK_IniPath
    IniRead, pid, %YK_IniPath%, MarkerState, Pid, 0
    IniRead, s, %YK_IniPath%, MarkerState, Slots, %A_Space%
    s := Trim(s)
    if (s = "" || !pid)
        return
    gp := YkGame_Pid()
    if (gp != pid) {
        IniWrite, 0, %YK_IniPath%, MarkerState, Pid
        IniWrite, % "", %YK_IniPath%, MarkerState, Slots
        return
    }
    for i, e in StrSplit(s, "|") {
        a := StrSplit(e, ":")
        if (a.MaxIndex() = 4) {     ; laengst abgelaufen -> der erste Takt raeumt sie weg
            g_Marks["?alt" . i] := {slot: a[1] + 0, x: a[2] + 0, y: a[3] + 0, z: 20
                , t: -99999999, t0: -99999999, spr: a[4] + 0, kind: "call"}
            g_MarkUsed[a[1] + 0] := -99999999
        }
    }
}
