; ---------------------------------------------------------------------
;  Member-Positionen und Hilfe-Rufe aus dem Gangchat
; ---------------------------------------------------------------------
; Ist das ein Hilfe-/Backup-Ruf?
YkIsCallText(msg) {
    return RegExMatch(msg, "i)unterst|backup|hilfe|\bhelp\b|verst(ä|ae|a)rkung|\bsos\b") > 0
}

; Sagt der Member den Ruf ab? ("Backup erledigt", "kein Backup mehr", "danke")
YkIsCallCancel(msg) {
    return RegExMatch(msg, "i)erledigt|\bkein(e|en)?\s+(backup|hilfe|unterst|verst)|nicht\s+mehr\s+(n(ö|oe)tig|gebraucht)|abgebrochen|\bcancel|\bdanke\b|\bthx\b") > 0
}

; Beispielzeilen, die erkannt werden:
;   [23:15:29] [YAK] Oyabun Marci: Aktueller Standort: Verona Beach (Los Santos)
;   [23:16:01] [YAK] Oyabun Marci: Brauche Hilfe | Standort: Vinewood (Los Santos) | HP: 34
;   [23:16:20] [YAK] Oyabun Marci: Brauche Backup in Idlewood (Los Santos) (GPS 2066 -1703)
;   [23:16:54] [YAK] Oyabun Marci: +1 Kill in Temple (Los Santos)
YkMembers_HandleLine(line) {
    global YK_GangTag, g_Members, YK_OwnName, YK_IniPath
    global g_LastCall, YK_CallSound, YkGuiOpen, g_GuiLoadT
    if (YK_GangTag = "")
        return
    l := RegExReplace(line, "\{[0-9A-Fa-f]{6}\}")
    l := RegExReplace(l, "^\s*\[\d{1,2}:\d{2}(:\d{2})?\]\s*")
    if (SubStr(l, 1, StrLen(YK_GangTag)) != YK_GangTag)
        return
    rest := LTrim(SubStr(l, StrLen(YK_GangTag) + 1))
    p := InStr(rest, ": ")
    if (!p)
        return
    head := Trim(SubStr(rest, 1, p - 1))
    msg  := Trim(SubStr(rest, p + 2))
    if (head = "" || msg = "")
        return
    name := RegExMatch(head, "(\S+)$", m) ? m1 : head

    ; eigenen Namen automatisch lernen: eine eben ueber den Binder gesendete
    ; Nachricht (/g oder /f) taucht hier mit dem eigenen Namen davor auf
    own := YkOwnMsg_Take(msg)
    if (own && YK_OwnName != name) {
        YK_OwnName := name
        IniWrite, %name%, %YK_IniPath%, Overlay, OwnName
        if (YkGuiOpen) {
            g_GuiLoadT := A_TickCount      ; schon gespeichert - kein erneutes Uebernehmen
            YkGui_SyncState()
        }
    }
    other := (!own && name != YK_OwnName)

    ; Absage ("Backup erledigt", "danke") -> Fahne weg, Name nicht mehr rot
    cancel := YkIsCallCancel(msg)
    if (cancel && other) {
        YkMark_RemoveKind(name, "call")
        if (IsObject(g_Members[name]) && g_Members[name].kind = "Hilfe") {
            g_Members[name].kind := ""
            YkOverlay_Refresh()
            if (YkGuiOpen)
                YkMemLV_Fill()
        }
    }

    ; Tod des Members - auch dann, wenn die Meldung keinen Ort enthaelt:
    ; die Fahne kommt sofort weg, im Overlay steht der letzte Stand mit
    ; einem Kreuz statt "braucht Hilfe".
    isDead := (other && RegExMatch(msg, "i)\btod\b|\btot\b|gestorben|\bbewusstlos\b|\bgekillt\b|\bdead\b") > 0)
    if (isDead)
        YkMembers_MarkDead(name)

    hasGps := YkMark_ParseGps(msg, gx, gy)
    loc := YkMembers_FindZone(msg)
    if (loc = "" && hasGps)
        loc := YkZone_Describe({x: gx, y: gy, z: 20}, false)
    ; von Hand getippt, ohne "(Stadt)": "Standort Idlewood", "bin in Idlewood"
    if (loc = "")
        loc := YkMembers_FindZoneLoose(msg)
    if (loc = "")
        return
    prev := g_Members.HasKey(name) ? g_Members[name] : ""
    info := {loc: loc, hp: "", kind: "", t: A_TickCount, gx: gx, gy: gy}
    if RegExMatch(msg, "i)\bHP\s*[:=]?\s*(\d{1,3})\b", m)
        info.hp := m1
    else if RegExMatch(msg, "i)\b(\d{1,3})\s*HP\b", m)
        info.hp := m1
    isCall := (YkIsCallText(msg) && !cancel && !isDead)
    if (!isCall && RegExMatch(msg, "i)^\s*komme\b|\bunterwegs\b|\bauf dem weg\b")) {
        ; "Komme zu Marci nach Vinewood" nennt das ZIEL, nicht, wo er ist -
        ; sonst stuende er im Overlay faelschlich "in der Naehe". Sein letzter
        ; echter Standort bleibt (Entfernung nur von dort), ohne einen gibt
        ; es keine Entfernung.
        toMe := (YK_OwnName != "" && RegExMatch(msg, "i)\bzu\s+\Q" . YK_OwnName . "\E\b"))
        if (IsObject(prev) && !InStr(prev.loc, "unterwegs nach "))
            info := {loc: prev.loc, hp: prev.hp, gx: prev.gx, gy: prev.gy}
        else
            info := {loc: "unterwegs nach " . loc, hp: "", gx: "", gy: ""}
        info.kind := toMe ? "kommt zu dir" : "unterwegs"
        info.t := A_TickCount
    } else if (isDead)
        info.kind := "Tod"
    else if (isCall)
        info.kind := "Hilfe"
    else if RegExMatch(msg, "i)\bsammeln\b|\btreffpunkt\b")
        info.kind := "Sammeln"
    else if RegExMatch(msg, "i)\bkill")
        info.kind := "Kill"
    info.dead := isDead ? true : false
    g_Members[name] := info

    if (isCall && other) {
        ; derselbe Member ruft oft mehrmals kurz hintereinander - nur einmal piepen
        fresh := !(IsObject(prev) && prev.kind = "Hilfe" && (A_TickCount - prev.t) < 20000)
        g_LastCall := {name: name, loc: loc, t: A_TickCount}
        if (fresh)
            YkSound_Play("call")
        ; rote Fahne auf der Minimap - genau (GPS) oder Mitte der Zone
        YkMark_OnCall(name, loc, gx, gy)
    }
    ; Ziel mitfuehren: hat der Member, zu dem man unterwegs ist, einen
    ; neuen Standort gemeldet, wandert auch die Ziel-Fahne mit
    if (other && IsObject(g_Target) && g_Target.name = name && !isDead)
        YkTarget_Set(name, false)
    YkOverlay_Refresh()
    if (YkGuiOpen)
        YkMemLV_Fill()
}

; ---------------------------------------------------------------------
;  Tod eines Members, Altern der Eintraege
; ---------------------------------------------------------------------
; Der Member ist tot: Fahne weg, Hilfe-Ruf beendet, im Overlay steht ab
; jetzt sein letzter Standort mit Kreuz statt "braucht Hilfe".
YkMembers_MarkDead(name) {
    global g_Members, g_LastCall, g_Target, YkGuiOpen
    YkMark_Remove(name)
    if (IsObject(g_Members[name])) {
        o := g_Members[name]
        o.dead := true
        if (o.kind = "Hilfe" || o.kind = "")
            o.kind := "Tod"
    }
    if (IsObject(g_LastCall) && g_LastCall.name = name)
        g_LastCall := ""
    if (IsObject(g_Target) && g_Target.name = name)
        g_Target := ""
    YkOverlay_Refresh()
    if (YkGuiOpen)
        YkMemLV_Fill()
}

; Server-Zeile "<Name> wurde von <Name> erschossen ..." - betrifft sie
; einen Member aus der Liste, gilt er als tot.
YkMembers_HandleKillLine(line) {
    global g_Members
    static verbs := "erschossen|get(?:ö|oe)tet|umgebracht|ermordet|niedergeschossen|niedergestreckt|ausgeschaltet|bewusstlos\s+(?:geschlagen|geschossen)"
    l := YkChat_Clean(line)
    if (l = "" || InStr(l, ": "))            ; Spielerchat nicht auswerten
        return
    ; Ein "[TAG]" davor darf stehen, muss aber vollstaendig sein - sonst
    ; frisst das Muster den Anfang des Namens ("Ken" wurde zu "n").
    if !RegExMatch(l, "i)^(?:\[[^\]]*\]\s*)?([^\s:,\.]+)\s+wurde\s+von\s+[^\s:,\.]+\s+(?:" . verbs . ")", m)
        return
    v := m1
    if (g_Members.HasKey(v))
        YkMembers_MarkDead(v)
}

; Aus dem Haupt-Timer: Eintraege altern lassen.
;  - "braucht Hilfe" endet mit der Fahne (Tod oder Hoechstdauer)
;  - ganz alte Eintraege verschwinden
YkMembers_Age() {
    global g_Members, YK_MarkMinutes, YK_MARK_MAXMIN, YkGuiOpen
    static last := 0
    if ((A_TickCount - last) < 2000)
        return
    last := A_TickCount
    mins := (YK_MarkMinutes >= 1) ? YK_MarkMinutes : 5
    if (mins > YK_MARK_MAXMIN)
        mins := YK_MARK_MAXMIN
    life := mins * 60000
    changed := false
    drop := []
    for name, o in g_Members {
        if ((A_TickCount - o.t) > 1800000) {       ; 30 Minuten -> weg
            drop.Push(name)
            continue
        }
        if (o.kind = "Hilfe" && (A_TickCount - o.t) > life) {
            o.kind := "alt"                        ; Ruf abgelaufen
            changed := true
        }
    }
    for i, n in drop {
        g_Members.Delete(n)
        changed := true
    }
    if (changed) {
        YkOverlay_Refresh()
        if (YkGuiOpen)
            YkMemLV_Fill()
    }
}

; ---------------------------------------------------------------------
;  Ziel: "Ich bin unterwegs zu ..."
; ---------------------------------------------------------------------
; Waehlt den Member, zu dem man unterwegs ist - unabhaengig davon, ob er
; Backup gerufen hat. Setzt (wenn eingeschaltet) eine andersfarbige Fahne
; auf seine Position und fuellt die Platzhalter {ziel} und {ziel_ort}.
YkTarget_Set(name, notify := true) {
    global g_Members, g_Target, YkGuiOpen
    name := Trim(name)
    if (name = "" || !g_Members.HasKey(name))
        return false
    o := g_Members[name]
    ; alte Ziel-Fahne weg
    if (IsObject(g_Target) && g_Target.name != name)
        YkMark_RemoveKind(g_Target.name, "target")
    g_Target := {name: name, loc: o.loc, gx: o.gx, gy: o.gy, t: A_TickCount}
    ; Fahne zum Ziel (nicht ueberschreiben, wenn dort schon ein Hilferuf steht)
    if (!YkMark_HasCall(name))
        YkMark_OnCall(name, o.loc, o.gx, o.gy, "target")
    ; bewusst KEIN erzwungener Neuaufbau: die Funktion laeuft auch jedes
    ; Mal mit, wenn das Ziel einen neuen Standort meldet
    YkOverlay_Refresh()
    if (YkGuiOpen)
        YkMemLV_Fill()
    if (notify)
        YkNotify("Ziel: " . name . " - " . o.loc)
    return true
}

YkTarget_Clear(notify := true) {
    global g_Target, YkGuiOpen
    if (IsObject(g_Target))
        YkMark_RemoveKind(g_Target.name, "target")
    g_Target := ""
    YkOverlay_Refresh()
    if (YkGuiOpen)
        YkMemLV_Fill()
    if (notify)
        YkNotify("Ziel gelöscht.")
}

; Ziel ueber einen (Teil-)Namen setzen - fuer /ykzu im Chat
YkTarget_SetByPrefix(part) {
    global g_Members
    part := Trim(part)
    if (part = "") {
        YkTarget_Clear()
        return true
    }
    ; erst genau, dann Namensanfang, dann irgendwo enthalten
    for name, o in g_Members
        if (name = part)
            return YkTarget_Set(name)
    best := "", bestT := 0
    for name, o in g_Members
        if (SubStr(name, 1, StrLen(part)) = part && (best = "" || o.t > bestT))
            best := name, bestT := o.t
    if (best = "") {
        for name, o in g_Members
            if (InStr(name, part) && (best = "" || o.t > bestT))
                best := name, bestT := o.t
    }
    if (best = "") {
        YkNotify("Kein Member mit " . part . " in der Liste.")
        return false
    }
    return YkTarget_Set(best)
}

; Ziel ueber die Position in der Member-Liste (1 = oberster Eintrag)
YkTarget_SetByIndex(n) {
    arr := YkMembers_Sorted(9)
    if (n < 1 || n > arr.MaxIndex()) {
        YkNotify("Kein Member Nr. " . n . " in der Liste.")
        return false
    }
    return YkTarget_Set(arr[n].name)
}

YkTarget_Name() {
    global g_Target
    return IsObject(g_Target) ? g_Target.name : ""
}

; Sucht "Zone (Stadt)" in einem freien Text und prueft die Zone gegen die
; echte Zonenliste - so wird aus "+1 Kill in Temple (Los Santos)" sauber
; "Temple (Los Santos)".
YkMembers_FindZone(msg) {
    global YK_ZonesArr, YK_CitiesArr
    static zones := "", cities := ""
    if (!IsObject(zones)) {
        YkZone_Init()
        zones := {}
        cities := []
        for i, o in YK_ZonesArr
            zones[o.name] := o.name
        zones["Innenraum"] := "Innenraum"
        for i, o in YK_CitiesArr {
            dup := false
            for j, c in cities
                if (c = o.name)
                    dup := true
            if (!dup)
                cities.Push(o.name)
        }
        cities.Push("San Andreas")
    }
    for i, city in cities {
        needle := "(" . city . ")"
        start := 1
        while (p := InStr(msg, needle, false, start)) {
            words := StrSplit(Trim(SubStr(msg, 1, p - 1)), " ")
            n := words.MaxIndex()
            k := (n > 5) ? 5 : n
            while (k >= 1) {
                cand := ""
                Loop, % k
                    cand .= (A_Index > 1 ? " " : "") . words[n - k + A_Index]
                cand := Trim(cand, " :|-,;.!")
                if (cand != "" && zones.HasKey(cand))
                    return zones[cand] . " (" . city . ")"
                k--
            }
            start := p + 1
        }
    }
    return ""
}

; Ort ohne "(Stadt)" - nur bei klarer Ortsangabe ("Standort: Idlewood",
; "bin in Idlewood"), sonst passten Woerter wie "Market" zu oft. Die Stadt
; kommt von der naechstgelegenen Zone dieses Namens.
YkMembers_FindZoneLoose(msg) {
    global YK_ZonesArr
    static names := ""
    if !RegExMatch(msg, "i)\b(standort|position|pos|bin|sind|stehe|hier)\b")
        return ""
    if (!IsObject(names)) {
        YkZone_Init()
        names := []
        seen := {}
        for i, o in YK_ZonesArr {
            if (StrLen(o.name) >= 4 && !seen.HasKey(o.name)) {
                seen[o.name] := 1
                names.Push(o.name)
            }
        }
    }
    best := ""
    for i, n in names
        if (StrLen(n) > StrLen(best) && RegExMatch(msg, "i)(?<!\w)\Q" . n . "\E(?!\w)"))
            best := n
    if (best = "")
        return ""
    pos := YkCurrentPos()
    c := YkZone_NearestCenter(best, IsObject(pos) ? pos.x : 0, IsObject(pos) ? pos.y : 0)
    city := IsObject(c) ? YkZone_GetCity(c.x, c.y, 20) : ""
    return best . " (" . ((city != "") ? city : "San Andreas") . ")"
}

; ---------------------------------------------------------------------
;  Toene: Backup-Ruf ("call") und Angriff auf Yakuza ("war")
; ---------------------------------------------------------------------
; Auswahl im Fenster -> gespeicherter Wert: "aus", Windows-Toene (*48 ...)
; oder "datei" (eigene WAV-/MP3-Datei)
YkSound_Names() {
    static n := ["Aus", "Ausrufezeichen", "Stern", "Frage", "Fehler", "Standard-Piep", "Eigene Datei..."]
    return n
}
YkSound_Keys() {
    static k := ["aus", "*48", "*64", "*32", "*16", "*-1", "datei"]
    return k
}
YkSound_Choices() {
    s := ""
    for i, n in YkSound_Names()
        s .= (i > 1 ? "|" : "") . n
    return s
}
; Nummer in der Auswahl (1 = Aus) fuer einen gespeicherten Wert
YkSound_Index(key) {
    for i, k in YkSound_Keys()
        if (k = key)
            return i
    return 1
}
YkSound_Key(name) {
    for i, n in YkSound_Names()
        if (n = name)
            return YkSound_Keys()[i]
    return "aus"
}
; gespeicherten Wert pruefen - Unbekanntes wird zum Standard
YkSound_Valid(key, def) {
    for i, k in YkSound_Keys()
        if (k = key)
            return k
    return def
}

YkSound_PlayKey(key, file) {
    if (key = "" || key = "aus")
        return
    if (key = "datei") {
        if (file != "" && FileExist(file))
            try SoundPlay, %file%
        return
    }
    SoundPlay, %key%
}

YkSound_Play(kind) {
    global YK_CallSoundType, YK_WarSoundType, YK_CallSoundFile, YK_WarSoundFile
    if (kind = "war")
        YkSound_PlayKey(YK_WarSoundType, YK_WarSoundFile)
    else
        YkSound_PlayKey(YK_CallSoundType, YK_CallSoundFile)
}

; Braucht der Member gerade Backup? (so lange, wie seine Fahne steht -
; also nicht mehr, wenn er gestorben ist oder die Zeit abgelaufen ist)
YkMembers_IsHot(o) {
    global YK_MarkMinutes, YK_MARK_MAXMIN
    if (o.kind != "Hilfe" || o.dead)
        return false
    mins := (YK_MarkMinutes >= 1) ? YK_MarkMinutes : 5
    if (mins > YK_MARK_MAXMIN)
        mins := YK_MARK_MAXMIN
    return ((A_TickCount - o.t) < mins * 60000)
}

; Text fuer die Info-Spalte: "braucht Hilfe", "† tot", "Ruf abgelaufen" ...
YkMembers_KindText(o) {
    if (o.dead)
        return "† tot"
    if (o.kind = "Hilfe")
        return YkMembers_IsHot(o) ? "braucht Hilfe" : "Ruf abgelaufen"
    if (o.kind = "alt")
        return "Ruf abgelaufen"
    return o.kind
}

; Mittelpunkt der Zone mit diesem Namen, der der Position am naechsten
; liegt (manche Zonen bestehen aus mehreren Rechtecken)
YkZone_NearestCenter(name, px, py) {
    global YK_ZonesArr
    static centers := ""
    if (!IsObject(centers)) {
        YkZone_Init()
        centers := {}
        for i, o in YK_ZonesArr {
            if (!centers.HasKey(o.name))
                centers[o.name] := []
            centers[o.name].Push({x: (o.x1 + o.x2) / 2, y: (o.y1 + o.y2) / 2})
        }
    }
    if (!centers.HasKey(name))
        return ""
    best := "", bestD := -1
    for i, c in centers[name] {
        d := (c.x - px) ** 2 + (c.y - py) ** 2
        if (bestD < 0 || d < bestD)
            bestD := d, best := c
    }
    return best
}

; Himmelsrichtung von der eigenen Position zum Ziel (GTA: +x Ost, +y Nord)
YkCompass(dx, dy) {
    static dirs := ["N", "NO", "O", "SO", "S", "SW", "W", "NW"]
    if (dx = 0 && dy = 0)
        return ""
    if (dx > 0)
        a := ATan(dy / dx)
    else if (dx < 0)
        a := ATan(dy / dx) + ((dy >= 0) ? 3.14159265 : -3.14159265)
    else
        a := (dy > 0) ? 1.5707963 : -1.5707963
    bearing := 90 - a * 57.2957795
    while (bearing < 0)
        bearing += 360
    while (bearing >= 360)
        bearing -= 360
    return dirs[Mod(Round(bearing / 45), 8) + 1]
}

; "850 m NO" / "2,4 km SW" / "in der Nähe" / " " (unbekannt)
; Mit GPS-Koordinaten genau, sonst bis zur Mitte der Zone
YkMembers_DistText(loc, pos, gx := "", gy := "") {
    if (!IsObject(pos))
        return " "
    if (gx != "" && gy != "") {
        c := {x: gx, y: gy}
    } else {
        zone := RegExReplace(loc, "\s*\(.*$")
        c := YkZone_NearestCenter(zone, pos.x, pos.y)
    }
    if (!IsObject(c))
        return " "
    dx := c.x - pos.x, dy := c.y - pos.y
    d := Sqrt(dx * dx + dy * dy)
    if (d < 150)
        return "in der Nähe"
    dir := YkCompass(dx, dy)
    if (d < 1000)
        return (Round(d / 50) * 50) . " m " . dir
    return StrReplace(Round(d / 1000, 1), ".", ",") . " km " . dir
}

YkMembers_Clear() {
    global g_Members, g_LastCall, g_Target
    g_Members := {}
    g_LastCall := ""
    g_Target := ""
    YkMark_ClearAll()
    YkOverlay_Refresh(true)
}

YkMembers_Toggle() {
    global YK_MemShow, YK_OvEnabled, YK_IniPath
    YK_MemShow := !YK_MemShow
    if (YK_MemShow && !YK_OvEnabled) {
        YK_OvEnabled := true
        IniWrite, 1, %YK_IniPath%, Overlay, Enabled
    }
    IniWrite, % (YK_MemShow ? 1 : 0), %YK_IniPath%, Overlay, ShowMembers
    YkOverlay_Refresh(true)
    YkGui_SyncState()
}

YkAgeText(t) {
    s := (A_TickCount - t) // 1000
    if (s < 60)
        return "gerade"
    m := s // 60
    if (m < 60)
        return "vor " . m . " Min"
    return "vor " . (m // 60) . " Std"
}

; Member nach Aktualitaet sortiert (neueste zuerst), ohne eigenen Namen.
; Wer Backup braucht, steht immer ganz oben, dann das gewaehlte Ziel.
YkMembers_Sorted(max := 10) {
    global g_Members, YK_OwnName, g_Target
    tgt := IsObject(g_Target) ? g_Target.name : ""
    arr := []
    for name, o in g_Members {
        if (YK_OwnName != "" && name = YK_OwnName)
            continue
        arr.Push({name: name, loc: o.loc, hp: o.hp, kind: o.kind, t: o.t, gx: o.gx, gy: o.gy
            , dead: (o.dead ? true : false), hot: YkMembers_IsHot(o), target: (name = tgt)})
    }
    ; Rang: 3 = braucht Backup, 2 = gewaehltes Ziel, 1 = normal, 0 = tot.
    ; Innerhalb desselben Rangs zaehlt, wer zuletzt etwas gesagt hat.
    for i, o in arr
        o.rank := o.hot ? 3 : (o.target ? 2 : (o.dead ? 0 : 1))
    Loop, % arr.MaxIndex() {
        j := A_Index
        while (j > 1 && (arr[j].rank > arr[j - 1].rank
                || (arr[j].rank = arr[j - 1].rank && arr[j].t > arr[j - 1].t))) {
            tmp := arr[j], arr[j] := arr[j - 1], arr[j - 1] := tmp
            j--
        }
    }
    while (arr.MaxIndex() > max)
        arr.Pop()
    return arr
}
