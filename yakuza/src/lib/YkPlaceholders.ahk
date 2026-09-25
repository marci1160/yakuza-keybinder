; =====================================================================
;  Yakuza Keybinder - Platzhalter, Overlay, Family-Funktionen (aus v2)
; ---------------------------------------------------------------------
;  - Platzhalter in jedem Text: {standort} {hp} {ruestung} {ruf} ...
;  - Hotkey-Namen lesbar machen (^g -> Strg+G), Doppelbelegungen finden
;  - Member-Positionen und Hilfe-Rufe aus dem Gangchat. Es wird nur
;    genutzt, was Member selbst in den Chat schreiben - nichts vom Server
;    und nichts aus dem Speicher anderer Spieler.
;  - Gangwar-Stand aus den Server-Meldungen
;  - Overlay: kleines, durchklickbares Fenster ueber dem Spiel
;  - lokale Chat-Befehle: /ykpos  /ykhud  /ykclear
; =====================================================================

global YK_OvEnabled    := true      ; Overlay insgesamt an/aus
global YK_OvHotkey     := "^o"
global YK_OvSide       := 2         ; 1 links, 2 rechts
global YK_OvVPos       := 100       ; Hoehe: 0 = ganz oben ... 100 = ganz unten
global YK_OvDodge      := true      ; im Fahrzeug ueber die Tacho-Anzeige ausweichen
global YK_OvSize       := 2         ; 1 klein, 2 normal, 3 gross
global YK_OvOpacity    := 215
global YK_OvHidden     := ""        ; "|"-Liste ausgeblendeter Hotkeys
global YK_OvShowKeys   := true      ; Bereich "Hotkeys"
global YK_OvStatus     := true      ; Bereich "Status" (eigene Zone, Kills/Tode)
global YK_OvFullscreen := "auto"    ; Overlay im Vollbild: auto | an | aus
; Overlay aus Aufnahmen heraushalten (OBS, Windows-Spielleiste).
; STANDARD AUS - der Schalter kann das Spielbild einfrieren lassen.
; Siehe YkOverlay_Capture weiter unten.
global YK_OvHideCapture := false
global YK_OvWar        := true      ; Bereich "Gangwar"
global YK_MemShow      := true      ; Bereich "Member"
global YK_MemHotkey    := "^p"
global YK_GangTag      := "[YAK]"
global YK_Faction      := "Yakuza"
global YK_CallSound    := true      ; (alt) Ton an/aus - jetzt ueber die beiden Auswahlen
global YK_CallSoundType := "*48"    ; Ton bei Backup-Ruf: aus | *48 | *64 | *32 | *16 | *-1 | datei
global YK_WarSoundType  := "*16"    ; Ton bei Angriff auf Yakuza
global YK_CallSoundFile := ""
global YK_WarSoundFile  := ""
global YK_OwnName      := ""

global g_Members       := {}        ; Name -> {loc, hp, kind, t}
global g_LastCall      := ""        ; {name, loc, t} des letzten Hilfe-Rufs
global g_Target        := ""        ; selbst gewaehltes Ziel {name, loc, gx, gy, t}
global g_Wars          := {}        ; Turf -> {us, them, enemy, mins, t, fam}
global g_WarNote       := ""
global g_WarNoteT      := 0
global g_WarEndT       := {}        ; "gang"/"fam" -> Ende laut Chat
global g_WarTdT        := 0         ; letztes Lesen der Server-Anzeige
global g_OvWarHwnds    := []        ; Textfelder der War-Zeilen (werden nur umbeschriftet)
global g_OvWarSig      := ""
global g_SessKills     := 0
global g_SessDeaths    := 0
global g_OvNote        := ""        ; kurze Meldung im Overlay (statt Sprechblase)
global g_OvNoteT       := 0
global g_OvSig         := ""        ; Struktur (fuehrt zum Neuaufbau)
global g_OvTextSig     := ""        ; reiner Inhalt (nur Text tauschen)
global g_OvBuilt       := false
global g_OvVisible     := false
global g_OvLastAge     := 0
global g_OvZone        := ""
global g_OvZoneT       := 0
global g_OvX           := ""
global g_OvY           := ""
global g_OvName        := "YkOv"    ; aktuell benutztes Overlay-Fenster (YkOv / YkOv2)
global g_OvHwnd        := 0
global g_OvH           := ""        ; Kennungen der Textfelder zum Austauschen
global g_HkSeen        := {}
global g_HkConflicts   := ""

; ---------------------------------------------------------------------
;  Standort in Worte fassen  (eine Stelle fuer alle)
; ---------------------------------------------------------------------
; Frueher stand diese Logik dreimal fast gleich im Code - und hatte zwei
; Fehler:
;
;  1) Die Staedte-Tabelle von GTA kennt kein "Bone County", und zwischen
;     Los Santos und Red County klafft ein schmaler Streifen, der zu
;     keiner Stadt gehoert. Herauskam dann "Bone County (San Andreas)".
;  2) Die grossen Gebiete stehen in BEIDEN Tabellen. Im offenen Land kam
;     deshalb "Red County (Red County)" heraus.
;
; Jetzt gilt: fehlt die Stadt, wird das Gebiet aus der Zonen-Tabelle
; genommen (die deckt die ganze Karte ab); sind Zone und Gebiet gleich,
; steht nur noch ein Name da.

; Die neun grossen Gebiete decken ganz San Andreas ab. Sie stehen am Ende
; der Zonen-Tabelle - von dort werden sie einmalig herausgesucht.
YkZone_Regions() {
    global YK_ZonesArr
    static regs := ""
    if (IsObject(regs))
        return regs
    YkZone_Init()
    static want := {"Los Santos": 1, "San Fierro": 1, "Las Venturas": 1, "Red County": 1
        , "Flint County": 1, "Bone County": 1, "Tierra Robada": 1, "Whetstone": 1}
    regs := []
    for i, o in YK_ZonesArr
        if (want.HasKey(o.name))
            regs.Push(o)
    return regs
}

; Grosses Gebiet an dieser Stelle ("" wenn ausserhalb, z.B. Innenraum)
YkZone_Region(x, y, z) {
    best := "", bestSz := 0
    for i, o in YkZone_Regions() {
        if (x >= o.x1 && y >= o.y1 && z >= o.z1 && x <= o.x2 && y <= o.y2 && z <= o.z2) {
            sz := (o.x2 - o.x1) * (o.y2 - o.y1)
            if (best = "" || sz < bestSz)
                best := o.name, bestSz := sz
        }
    }
    return best
}

; Zone und uebergeordnetes Gebiet zu einer Position.
; own = true: eigene Position (dann darf "Innenraum" benutzt werden)
YkZone_Parts(pos, ByRef zone, ByRef city, own := true) {
    zone := "", city := ""
    if (!IsObject(pos))
        return false
    zone := YkZone_GetZone(pos.x, pos.y, pos.z)
    city := YkZone_GetCity(pos.x, pos.y, pos.z)
    if (city = "")
        city := YkZone_Region(pos.x, pos.y, pos.z)
    if (zone = "")
        zone := (own && YkMem_GetInterior() > 0) ? "Innenraum" : city
    if (zone = "")
        zone := "Unbekannt"
    if (city = "")
        city := "San Andreas"
    return true
}

; Fertiger Text: "Idlewood (Los Santos)" - oder nur "Red County", wenn
; Zone und Gebiet dasselbe sind.
YkZone_Describe(pos, own := true) {
    if (!YkZone_Parts(pos, zone, city, own))
        return ""
    return (zone = city || zone = "") ? city : zone . " (" . city . ")"
}

; ---------------------------------------------------------------------
;  Platzhalter
; ---------------------------------------------------------------------
; Ersetzt bekannte Platzhalter (Gross/klein egal). Unbekannte {...} bleiben
; stehen. Nur was im Text vorkommt, wird auch ausgelesen.
; posOverride: feste Position statt der aktuellen (fuer die Tod-Meldung -
; dort zaehlt der Sterbeort, nicht der Spawnort).
; Alle Platzhalter: erst die aus v2 (Standort, Kampf, Familie), dann die
; Statistik-/Spieler-Platzhalter aus v3.0 (YkFill_Extra in YkChatCmds.ahk)
YkFillPlaceholders(text, posOverride := "") {
    if !InStr(text, "{")
        return text
    return YkFill_Extra(YkFillPlaceholders_V2(text, posOverride))
}

YkFillPlaceholders_V2(text, posOverride := "") {
    global g_KillVictim, g_DeathKiller
    if !InStr(text, "{")
        return text
    out := text

    if RegExMatch(out, "i)\{(standort|zone|stadt|city|x|y|z|int)\}") {
        pos := IsObject(posOverride) ? posOverride : YkCurrentPos()
        if (IsObject(pos)) {
            YkZone_Parts(pos, zone, city)
            intid := YkMem_GetInterior()
            loc := (zone = city) ? city : zone . " (" . city . ")"
            px := Round(pos.x), py := Round(pos.y), pz := Round(pos.z)
        } else {
            zone := "unbekannt", city := "unbekannt", intid := "?"
            loc := "unbekannter Gegend"
            px := "?", py := "?", pz := "?"
        }
        out := StrReplace(out, "{standort}", loc)
        out := StrReplace(out, "{zone}", zone)
        out := StrReplace(out, "{stadt}", city)
        out := StrReplace(out, "{city}", city)
        out := StrReplace(out, "{x}", px)
        out := StrReplace(out, "{y}", py)
        out := StrReplace(out, "{z}", pz)
        out := StrReplace(out, "{int}", intid)
    }
    if RegExMatch(out, "i)\{(hp|leben)\}") {
        hp := YkMem_GetHealth()
        hp := (hp >= 0) ? hp : "?"
        out := StrReplace(out, "{hp}", hp)
        out := StrReplace(out, "{leben}", hp)
    }
    if RegExMatch(out, "i)\{(ruestung|rüstung|armor)\}") {
        ar := YkMem_GetArmor()
        ar := (ar >= 0) ? ar : "?"
        out := StrReplace(out, "{ruestung}", ar)
        out := StrReplace(out, "{rüstung}", ar)
        out := StrReplace(out, "{armor}", ar)
    }
    if RegExMatch(out, "i)\{(fahrzeug|veh|unterwegs)\}") {
        inV := YkMem_InVehicle()
        ; zu Fuss liest sich "in einem {fahrzeug}" falsch -> "zu Fuß"
        if (inV = false)
            out := RegExReplace(out, "i)\b(?:in|mit|auf)\s+(?:einem|einer|meinem|meiner|dem|der)\s+\{(?:fahrzeug|veh)\}|\bim\s+\{(?:fahrzeug|veh)\}", "zu Fuß")
        vh := (inV = -1) ? "?" : YkVehText()
        out := StrReplace(out, "{fahrzeug}", vh)
        out := StrReplace(out, "{veh}", vh)
        out := StrReplace(out, "{unterwegs}", (inV = -1) ? "?" : (inV = true) ? "im " . vh : "zu Fuß")
    }
    if InStr(out, "{opfer}") {
        out :=StrReplace(out, "{opfer}", (g_KillVictim != "") ? g_KillVictim : "unbekannt")
    }
    ; Wer hat MICH umgelegt? (fuer die Tod-Meldung)
    if RegExMatch(out, "i)\{(mörder|moerder|killer)\}") {
        k := (g_DeathKiller != "") ? g_DeathKiller : "unbekannt"
        out := StrReplace(out, "{mörder}", k)
        out := StrReplace(out, "{moerder}", k)
        out := StrReplace(out, "{killer}", k)
    }
    if InStr(out, "{wanteds}")
        out := StrReplace(out, "{wanteds}", YkWanted_Value())
    if RegExMatch(out, "i)\{(ruf|ruf_ort)\}") {
        c := g_LastCall
        out := StrReplace(out, "{ruf_ort}", IsObject(c) ? c.loc : "?")
        out := StrReplace(out, "{ruf}", IsObject(c) ? c.name : "?")
    }
    ; selbst gewaehltes Ziel ("Ich bin unterwegs zu ..."). Ist keins
    ; gesetzt, gilt ersatzweise der letzte Hilfe-Ruf - so wirken die
    ; Platzhalter auch ohne Auswahl sinnvoll.
    if RegExMatch(out, "i)\{(ziel|ziel_ort)\}") {
        z := IsObject(g_Target) ? g_Target : g_LastCall
        out := StrReplace(out, "{ziel_ort}", IsObject(z) ? z.loc : "?")
        out := StrReplace(out, "{ziel}", IsObject(z) ? z.name : "?")
    }
    if InStr(out, "{gps}")
        out := StrReplace(out, "{gps}", YkMark_GpsText(pos))
    ; {kills}/{tode} zeigen den Gesamtstand des Servers, sobald er einmal
    ; aus dem Charaktermenue (Taste N) abgeglichen wurde - sonst weiter die
    ; Zahlen dieser Sitzung. Die gibt es ausserdem eigens:
    if InStr(out, "{kills_sitzung}")
        out := StrReplace(out, "{kills_sitzung}", g_SessKills)
    if InStr(out, "{tode_sitzung}")
        out := StrReplace(out, "{tode_sitzung}", g_SessDeaths)
    if InStr(out, "{kills}")
        out := StrReplace(out, "{kills}", YkStats_Kills())
    if InStr(out, "{tode}")
        out := StrReplace(out, "{tode}", YkStats_Deaths())
    if InStr(out, "{zeit}") {
        FormatTime, tm, , HH:mm
        out := StrReplace(out, "{zeit}", tm)
    }
    return out
}
