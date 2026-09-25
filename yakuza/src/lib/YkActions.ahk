; =====================================================================
;  STANDORT-TEXT AUS SPEICHER BAUEN
; =====================================================================
; Aktuelle Position - faellt auf den zuletzt bekannten guten Standort
; zurueck. Wichtig beim Tod: dort ist die Position oft schon ungueltig,
; der gemerkte Wert ist dann genau der Ort, an dem man gestorben ist.
YkCurrentPos() {
    global YK_MemEnabled, g_LastPos
    if (!YK_MemEnabled)
        return ""
    pos := ""
    if (YkMem_Active())
        pos := YkMem_GetPosition()
    if (!IsObject(pos))
        pos := g_LastPos
    return IsObject(pos) ? pos : ""
}

; "Zone (Stadt)" - oder nur "Red County", wenn beides dasselbe waere.
; Die gemeinsame Logik steht in YkZone_Describe (YkPlaceholders.ahk).
YkLocationText() {
    return YkZone_Describe(YkCurrentPos())
}

YkVehText() {
    inV := YkMem_InVehicle()
    if (inV = true) {
        vn := YkMem_GetVehicleName()
        return (vn != "") ? vn : "unbekannt"
    }
    return "zu Fuß"
}

YkBuildLocation(fmt) {
    global YK_MemEnabled
    if (!YK_MemEnabled)
        return ""
    pos := YkCurrentPos()
    if (!IsObject(pos))
        return ""
    YkZone_Parts(pos, zone, city)
    intid := YkMem_GetInterior()
    out := fmt
    out := StrReplace(out, "{zone}", zone)
    out := StrReplace(out, "{city}", city)
    out := StrReplace(out, "{x}", Round(pos.x))
    out := StrReplace(out, "{y}", Round(pos.y))
    out := StrReplace(out, "{z}", Round(pos.z))
    out := StrReplace(out, "{hp}", YkMem_GetHealth())
    out := StrReplace(out, "{armor}", YkMem_GetArmor())
    out := StrReplace(out, "{veh}", YkVehText())
    out := StrReplace(out, "{int}", intid)
    return out
}

; Eingestellte Reihenfolge als Liste, z.B. ["loc","hp","armor","veh"].
; Fehlende Eintraege werden hinten ergaenzt, damit nie etwas wegfaellt.
YkExtrasOrderArr() {
    global YK_ExtrasOrder
    arr := []
    for i, t in StrSplit(YK_ExtrasOrder, ",") {
        tt := Trim(t)
        if (tt != "")
            arr.Push(tt)
    }
    for i, def in ["hp", "armor", "loc", "veh"] {
        found := false
        for j, have in arr {
            if (have = def) {
                found := true
                break
            }
        }
        if (!found)
            arr.Push(def)
    }
    return arr
}

YkExtrasLabel(k) {
    if (k = "hp")
        return "HP"
    if (k = "armor")
        return "Rüstung"
    if (k = "loc")
        return "Standort"
    if (k = "veh")
        return "Fahrzeug"
    return k
}

; Text einer einzelnen Zusatzinfo ("" wenn nicht verfuegbar)
YkExtrasValue(k) {
    if (k = "hp") {
        hp := YkMem_GetHealth()
        return (hp >= 0) ? "HP: " . hp : ""
    }
    if (k = "armor") {
        ar := YkMem_GetArmor()
        return (ar >= 0) ? "Rüstung: " . ar : ""
    }
    if (k = "loc") {
        l := YkLocationText()
        return (l != "") ? "Standort: " . l : ""
    }
    if (k = "veh") {
        inV := YkMem_InVehicle()
        if (inV = -1)
            return ""
        return "Fahrzeug: " . YkVehText()
    }
    return ""
}

; Baut den Anhaengetext mit den gewuenschten Zusatzinfos - in der
; unter "Keybinds" eingestellten Reihenfolge, z.B.
; " | Standort: Idlewood (Los Santos) | HP: 87 | Ruestung: 42"
YkBuildExtras(exHp, exArmor, exLoc, exVeh) {
    global YK_MemEnabled
    if (!exHp && !exArmor && !exLoc && !exVeh)
        return ""
    if (!YK_MemEnabled)
        return ""
    want := {hp: exHp, armor: exArmor, loc: exLoc, veh: exVeh}
    out := ""
    for i, k in YkExtrasOrderArr() {
        if (!want[k])
            continue
        v := YkExtrasValue(k)
        if (v != "")
            out .= " | " . v
    }
    return out
}

; Textzusammenfassung fuer die Listen-Spalte "Extras", z.B. "Standort,HP"
YkExtrasSummary(exHp, exArmor, exLoc, exVeh) {
    want := {hp: exHp, armor: exArmor, loc: exLoc, veh: exVeh}
    out := ""
    for i, k in YkExtrasOrderArr() {
        if (!want[k])
            continue
        if (out != "")
            out .= ","
        out .= YkExtrasLabel(k)
    }
    return (out = "") ? "-" : out
}

; =====================================================================
;  AKTIONEN
; =====================================================================
YkAction_Location() {
    global YK_LocText
    if (YkInputBlocked())
        return
    if (!IsObject(YkCurrentPos())) {
        YkNotify("Standort unbekannt - ist das Spiel aktiv und 'Spielspeicher lesen' an?")
        return
    }
    YkSendCmd(YkGangLine("", YkFillPlaceholders(YK_LocText)), true)
}

; Notnagel, falls ein Kill einmal nicht automatisch erkannt wurde
YkAction_KillManual() {
    global YK_ReportCooldown, g_LastKillReport
    if (YkInputBlocked())
        return
    if ((A_TickCount - g_LastKillReport) < YK_ReportCooldown)
        return
    g_LastKillReport := A_TickCount
    YkKill_Manual()
}

YkAction_FamilyMap() {
    global YK_FamCommand
    if (YkInputBlocked())
        return
    YkSendCmd(YK_FamCommand, true)
}

YkBind_Fire(cmd, enter, exHp := 0, exArmor := 0, exLoc := 0, exVeh := 0) {
    if (YkInputBlocked())
        return
    ; {wanteds} im Text: erst beim Server nachfragen, den Satz so lange
    ; zurueckstellen (siehe YkWanteds.ahk - ohne Warten, im Takt)
    if (YkWanted_Needed(cmd)) {
        YkWanted_Defer(cmd, enter, exHp, exArmor, exLoc, exVeh)
        YkWanted_Ask()
        return
    }
    full := YkFillPlaceholders(cmd) . YkBuildExtras(exHp, exArmor, exLoc, exVeh)
    ; Backup-Ruf in /g oder /f: Koordinaten fuer die Fahne der anderen anhaengen
    if (enter)
        full := YkMark_AddGps(full)
    t0 := YkDiag_Now()
    YkSendCmd(full, enter)
    YkStall_Step("Senden", YkDiag_Now() - t0)
}

; Kill zaehlen und melden (automatisch erkannt oder per Hotkey)
YkReport_Kill(victim := "") {
    global YK_CombatEnabled, YK_KillEnabled, YK_KillText, g_SessKills, g_KillVictim
    if (!YK_CombatEnabled || !YK_KillEnabled)
        return
    g_SessKills += 1
    YkStats_CountKill()
    g_KillVictim := victim
    ; Platzhalter JETZT fuellen (Ort des Kills), gesendet wird evtl. spaeter
    YkQueue(YkGangLine("", YkFillPlaceholders(YK_KillText)), true)
    YkOverlay_Refresh()
}
