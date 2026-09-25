; =====================================================================
;  KONFIGURATION LADEN / SPEICHERN
; =====================================================================
YkLoadConfig() {
    global YK_IniPath
    global YK_ChatKey, YK_GangCmd, YK_SendDelay, YK_MemEnabled, YK_StartPaused, YK_FastSend
    global YK_LocHotkey, YK_LocPrefix, YK_LocFormat
    global YK_CombatEnabled, YK_ChatlogPath, YK_KillEnabled, YK_KillPattern, YK_KillPrefix, YK_KillFormat, YK_KillHotkey
    global YK_DeathEnabled, YK_DeathPattern, YK_DeathPrefix, YK_DeathFormat, YK_DeathByHealth, YK_ReportCooldown
    global YK_FamEnabled, YK_FamCommand, YK_FamLoginPat, YK_FamConnectPat, YK_FamDelay, YK_FamHotkey, YK_FamOnce
    global YK_SprintEnabled, YK_SprintKey, YK_SprintMoveKeys, YK_SprintToggleHk, YK_SprintTapDown, YK_SprintTapUp, YK_SprintOnFoot, YK_SprintReqMove
    global YK_Binds
    global YK_CmdBinds, YK_KurzEnabled, YK_ExtrasOrder

    p := YK_IniPath

    YK_ChatKey     := YkIniRead(p, "General", "ChatKey", "t")
    YK_GangCmd     := YkIniRead(p, "General", "GangCmd", "/g")
    YK_SendDelay   := YkIniRead(p, "General", "SendDelay", 0) + 0
    YK_ExtrasOrder := YkIniRead(p, "General", "ExtrasOrder", "hp,armor,loc,veh")
    YK_MemEnabled  := (YkIniRead(p, "General", "EnableMemoryRead", 1) + 0) != 0
    YK_StartPaused := (YkIniRead(p, "General", "StartPaused", 0) + 0) != 0
    YK_FastSend    := (YkIniRead(p, "General", "FastSend", 1) + 0) != 0
    ; Haenger-Protokoll (siehe YkStall_Log). Der alte Schluessel
    ; "LowPriority" wird bewusst NICHT mehr gelesen - er hat den Binder
    ; unter die Prioritaet des Spiels gestellt und damit die Tastatur des
    ; ganzen Rechners ausgebremst.
    YK_StallLog    := (YkIniRead(p, "General", "StallLog", 1) + 0) != 0
    YK_StallMs     := YkIniRead(p, "General", "StallMs", 250) + 0
    if (YK_StallMs < 50 || YK_StallMs > 5000)
        YK_StallMs := 250
    YK_SendWaitMs  := YkIniRead(p, "General", "SendWaitMs", 400) + 0
    if (YK_SendWaitMs < 100 || YK_SendWaitMs > 1500)
        YK_SendWaitMs := 400

    YK_LocHotkey := YkHk_Normalize(YkIniRead(p, "Location", "Hotkey", "^g"))
    YK_LocPrefix := YkIniRead(p, "Location", "Prefix", "Standort:")
    YK_LocFormat := YkIniRead(p, "Location", "Format", "{zone} ({city})")
    ; neu: ein einziger Text mit Platzhaltern - alte INIs (Prefix+Format)
    ; werden dabei automatisch uebernommen
    YK_LocText := YkIniRead(p, "Location", "Text", "")
    if (YK_LocText = "")
        YK_LocText := Trim(YK_LocPrefix . " " . YkMigrateFormat(YK_LocFormat))

    YK_CombatEnabled := (YkIniRead(p, "Combat", "Enabled", 1) + 0) != 0
    YK_ChatlogPath   := YkIniRead(p, "Combat", "ChatlogPath", "")
    YK_KillEnabled   := (YkIniRead(p, "Combat", "KillEnabled", 1) + 0) != 0
    YK_KillPattern   := YkIniRead(p, "Combat", "KillPattern", "")
    YK_KillPrefix    := YkIniRead(p, "Combat", "KillPrefix", "Kill in")
    YK_KillFormat    := YkIniRead(p, "Combat", "KillFormat", "{zone} ({city})")
    YK_KillText      := YkIniRead(p, "Combat", "KillText", "")
    if (YK_KillText = "")
        YK_KillText := Trim(YK_KillPrefix . " " . YkMigrateFormat(YK_KillFormat))
    YK_KillHotkey    := YkHk_Normalize(YkIniRead(p, "Combat", "KillHotkey", "^k"))
    YK_DeathEnabled  := (YkIniRead(p, "Combat", "DeathEnabled", 1) + 0) != 0
    YK_DeathPattern  := YkIniRead(p, "Combat", "DeathPattern", "")
    YK_DeathPrefix   := YkIniRead(p, "Combat", "DeathPrefix", "Tod in")
    YK_DeathFormat   := YkIniRead(p, "Combat", "DeathFormat", "{zone} ({city})")
    YK_DeathText     := YkIniRead(p, "Combat", "DeathText", "")
    if (YK_DeathText = "")
        YK_DeathText := Trim(YK_DeathPrefix . " " . YkMigrateFormat(YK_DeathFormat))
    YK_DeathByHealth := (YkIniRead(p, "Combat", "DeathByHealth", 1) + 0) != 0
    YK_ReportCooldown := YkIniRead(p, "Combat", "ReportCooldown", 3000) + 0
    YK_KillAuto      := (YkIniRead(p, "Combat", "KillAuto", 1) + 0) != 0
    ; alle Kill-Zeiten in Millisekunden
    YK_KillWindowMs  := YkIniRead(p, "Combat", "KillWindowMs", 600) + 0
    if (YK_KillWindowMs < 100 || YK_KillWindowMs > 3000)
        YK_KillWindowMs := 600
    YK_KillRivalMs   := YkIniRead(p, "Combat", "KillRivalMs", 150) + 0
    if (YK_KillRivalMs < 0 || YK_KillRivalMs > 2000)
        YK_KillRivalMs := 150
    YK_KillSameMs    := YkIniRead(p, "Combat", "KillSameMs", 900) + 0
    if (YK_KillSameMs < 100 || YK_KillSameMs > 5000)
        YK_KillSameMs := 900
    ; Namen der Gegner aus SA-MP lesen (fuer {opfer})
    YK_PlrEnabled    := (YkIniRead(p, "Combat", "VictimNames", 1) + 0) != 0
    YK_KoPattern     := YkIniRead(p, "Combat", "KoPattern", "Du bist bewusstlos\.")
    YK_KoRejectPat   := YkIniRead(p, "Combat", "KoRejectPattern", "bewusstlos und kannst keine Befehle")
    YK_RevivePattern := YkIniRead(p, "Combat", "RevivePattern", "wiederbelebt|reanimiert|aus dem Krankenhaus|Krankenhaus entlassen|wieder bei Bewusstsein|bist wieder wach")
    YK_HospPattern   := YkIniRead(p, "Combat", "HospitalPattern", "Krankenhaus|Hospital|Klinik")
    ; eigene Meldung nach einer Wiederbelebung durch einen Medic.
    ; Leeres Feld = aus (dann geht die normale Tod-Meldung raus).
    YK_ReviveEnabled := (YkIniRead(p, "Combat", "ReviveEnabled", 1) + 0) != 0
    YK_ReviveText    := YkIniRead(p, "Combat", "ReviveText"
        , "Von einem Medic wiederbelebt | Standort: {standort} | HP: {hp}")
    YK_KoWaitSec     := YkIniRead(p, "Combat", "KoWaitSec", 62) + 0
    YK_KoRetrySec    := YkIniRead(p, "Combat", "KoRetrySec", 20) + 0
    if (YK_KoWaitSec < 3 || YK_KoWaitSec > 600)
        YK_KoWaitSec := 62
    if (YK_KoRetrySec < 3 || YK_KoRetrySec > 300)
        YK_KoRetrySec := 20
    ; Kill-Protokoll ist jetzt abschaltbar und standardmaessig AUS: es
    ; schrieb bei jedem gefallenen Gegner mitten im Gefecht auf die Platte.
    YK_KillLogOn     := (YkIniRead(p, "Combat", "KillLog", 0) + 0) != 0
    ; Moerder erkennen (Platzhalter {moerder})
    YK_KillerEnabled := (YkIniRead(p, "Combat", "KillerEnabled", 1) + 0) != 0
    YK_KillerPattern := YkIniRead(p, "Combat", "KillerPattern", "")
    ; Alter Standardtext ohne Moerder -> auf den neuen umstellen. Wer sich
    ; einen eigenen Text eingetragen hat, behaelt ihn unveraendert.
    if (Trim(YK_DeathText) = "Tod in {standort}")
        YK_DeathText := "Getötet in {standort} von {mörder}"

    YK_FamEnabled   := (YkIniRead(p, "FamilyMap", "Enabled", 1) + 0) != 0
    YK_FamCommand    := YkIniRead(p, "FamilyMap", "Command", "/familymap")
    YK_FamLoginPat   := YkIniRead(p, "FamilyMap", "LoginPattern", "Willkommen auf")
    YK_FamConnectPat := YkIniRead(p, "FamilyMap", "ConnectPattern", "Connecting to")
    YK_FamDelay      := YkIniRead(p, "FamilyMap", "DelayMs", 5000) + 0
    YK_FamHotkey     := YkHk_Normalize(YkIniRead(p, "FamilyMap", "Hotkey", "^m"))
    YK_FamOnce       := (YkIniRead(p, "FamilyMap", "OncePerConnect", 1) + 0) != 0

    YK_SprintEnabled := (YkIniRead(p, "Sprint", "Enabled", 1) + 0) != 0
    YK_SprintKey     := YkIniRead(p, "Sprint", "SprintKey", "Space")
    YK_SprintMoveKeys := YkIniRead(p, "Sprint", "MovementKeys", "w,a,s,d,Up,Down,Left,Right")
    YK_SprintToggleHk := YkHk_Normalize(YkIniRead(p, "Sprint", "ToggleHotkey", "^Space"))
    YK_SprintTapDown := YkIniRead(p, "Sprint", "TapDownMs", 30) + 0
    YK_SprintTapUp   := YkIniRead(p, "Sprint", "TapUpMs", 30) + 0
    YK_SprintOnFoot  := (YkIniRead(p, "Sprint", "OnlyOnFoot", 1) + 0) != 0
    YK_SprintReqMove := (YkIniRead(p, "Sprint", "RequireMovementKey", 1) + 0) != 0
    YK_CrouchKey     := Trim(YkIniRead(p, "Sprint", "CrouchKey", "c"))
    if (YK_CrouchKey = "" || !GetKeySC(YK_CrouchKey))
        YK_CrouchKey := "c"

    YK_OvEnabled := (YkIniRead(p, "Overlay", "Enabled", 1) + 0) != 0
    YK_OvHotkey  := YkHk_Normalize(YkIniRead(p, "Overlay", "Hotkey", "^o"))
    ; Position: Seite (1 links, 2 rechts) + Hoehe 0..100 % (oben..unten).
    ; Alte INIs hatten nur vier Ecken - die werden uebernommen.
    YK_OvSide    := YkIniRead(p, "Overlay", "Side", "")
    YK_OvVPos    := YkIniRead(p, "Overlay", "VPos", "")
    if (YK_OvSide = "" || YK_OvVPos = "") {
        corner := YkIniRead(p, "Overlay", "Corner", 4) + 0
        YK_OvSide := (corner = 1 || corner = 3) ? 1 : 2
        YK_OvVPos := (corner = 1 || corner = 2) ? 0 : 100
    }
    YK_OvSide := (YK_OvSide + 0 = 1) ? 1 : 2
    YK_OvVPos += 0
    if (YK_OvVPos < 0 || YK_OvVPos > 100)
        YK_OvVPos := 100
    YK_OvDodge   := (YkIniRead(p, "Overlay", "Dodge", 1) + 0) != 0
    YK_OvSize    := YkIniRead(p, "Overlay", "Size", 2) + 0
    YK_OvOpacity := YkIniRead(p, "Overlay", "Opacity", 215) + 0
    YK_OvHidden  := YkIniRead(p, "Overlay", "Hidden", "")
    YK_MemShow   := (YkIniRead(p, "Overlay", "ShowMembers", 1) + 0) != 0
    YK_OvShowKeys := (YkIniRead(p, "Overlay", "ShowKeys", 1) + 0) != 0
    YK_OvWar     := (YkIniRead(p, "Overlay", "ShowWar", 1) + 0) != 0
    YK_OvStatus  := (YkIniRead(p, "Overlay", "ShowStatus", 1) + 0) != 0
    YK_Faction   := YkIniRead(p, "Overlay", "Faction", "Yakuza")
    YK_CallSound := (YkIniRead(p, "Overlay", "CallSound", 1) + 0) != 0
    ; Toene je Anlass waehlbar (bis v1.7 nur gemeinsam an/aus -> "aus" bleibt aus)
    global YK_CallSoundType, YK_WarSoundType, YK_CallSoundFile, YK_WarSoundFile
    YK_CallSoundType := YkSound_Valid(YkIniRead(p, "Overlay", "CallSoundType", YK_CallSound ? "*48" : "aus"), "*48")
    YK_WarSoundType  := YkSound_Valid(YkIniRead(p, "Overlay", "WarSoundType", YK_CallSound ? "*16" : "aus"), "*16")
    YK_CallSoundFile := YkIniRead(p, "Overlay", "CallSoundFile", "")
    YK_WarSoundFile  := YkIniRead(p, "Overlay", "WarSoundFile", "")
    YK_MemHotkey := YkHk_Normalize(YkIniRead(p, "Overlay", "MemberHotkey", "^p"))
    YK_GangTag   := YkIniRead(p, "Overlay", "GangTag", "[YAK]")
    YK_OwnName   := YkIniRead(p, "Overlay", "OwnName", "")
    YK_MarkEnabled := (YkIniRead(p, "Overlay", "MarkEnabled", 1) + 0) != 0
    YK_MarkSendGps := (YkIniRead(p, "Overlay", "MarkSendGps", 1) + 0) != 0
    ; Fahnen-Dauer: Standard 10, mehr als 10 Minuten gibt es nicht mehr
    YK_MarkMinutes := YkIniRead(p, "Overlay", "MarkMinutes", 10) + 0
    if (YK_MarkMinutes < 1 || YK_MarkMinutes > YK_MARK_MAXMIN)
        YK_MarkMinutes := YK_MARK_MAXMIN
    YK_MarkSprite  := YkIniRead(p, "Overlay", "MarkSprite", 19) + 0
    if (YK_MarkSprite < 1 || YK_MarkSprite > 63)
        YK_MarkSprite := 19
    YK_MarkTgtSpr  := YkIniRead(p, "Overlay", "MarkTargetSprite", 53) + 0
    if (YK_MarkTgtSpr < 1 || YK_MarkTgtSpr > 63)
        YK_MarkTgtSpr := 53
    ; Overlay im Vollbild: auto (aus, solange GTA im echten Vollbild laeuft)
    YK_OvFullscreen := YkIniRead(p, "Overlay", "FullscreenMode", "auto")
    if (YK_OvFullscreen != "an" && YK_OvFullscreen != "aus")
        YK_OvFullscreen := "auto"
    if (YK_OvSize < 1 || YK_OvSize > 3)
        YK_OvSize := 2
    if (YK_OvOpacity < 80 || YK_OvOpacity > 255)
        YK_OvOpacity := 215
    ; Wie lange bleibt "Krieg gewonnen/verloren" stehen? 0 = bis zum naechsten
    YK_WarNoteSec := YkIniRead(p, "Overlay", "WarNoteSeconds", 120) + 0
    if (YK_WarNoteSec < 0 || YK_WarNoteSec > 600)
        YK_WarNoteSec := 120
    ; Overlay aus Aufnahmen heraushalten (OBS, Windows-Spielleiste).
    ; Standard AUS. Der Schluessel heisst bewusst anders als in v2.0.0
    ; ("HideFromCapture"): dort stand er auf 1, und genau das hat auf
    ; manchen Rechnern das Spielbild einfrieren lassen. Ein alter Wert
    ; wird deshalb nicht uebernommen - wer den Schalter will, setzt ihn
    ; einmal neu.
    YK_OvHideCapture := (YkIniRead(p, "Overlay", "HideInRecordings", 0) + 0) != 0

    ; Kills/Tode aus dem Charaktermenue (Taste N)
    YK_StatsEnabled  := (YkIniRead(p, "Stats", "Enabled", 1) + 0) != 0
    YK_StatsKillPat  := YkIniRead(p, "Stats", "KillPattern", "Kills?\s*[:=]\s*(\d+)")
    YK_StatsDeathPat := YkIniRead(p, "Stats", "DeathPattern", "(?:Tode|Todesf(?:ä|ae)lle|Deaths?)\s*[:=]\s*(\d+)")

    ; Wanteds
    YK_WantedEnabled := (YkIniRead(p, "Wanteds", "Enabled", 1) + 0) != 0
    YK_WantedCmd     := Trim(YkIniRead(p, "Wanteds", "Command", "/wanteds"))
    YK_WantedPat     := YkIniRead(p, "Wanteds", "Pattern", "(?:Aktuelle\s+)?Wanteds?\s*[:=]?\s*(\d+)")
    YK_WantedWaitMs  := YkIniRead(p, "Wanteds", "WaitMs", 2500) + 0
    if (YK_WantedWaitMs < 500 || YK_WantedWaitMs > 10000)
        YK_WantedWaitMs := 2500

    ; Lotto (ab Werk AUS - der Binder sendet sonst von selbst Befehle)
    YK_LottoOn    := (YkIniRead(p, "Lotto", "Enabled", 0) + 0) != 0
    YK_LottoCount := YkIniRead(p, "Lotto", "Count", 1) + 0
    if (YK_LottoCount < 1 || YK_LottoCount > 20)
        YK_LottoCount := 1
    YK_LottoCmd   := Trim(YkIniRead(p, "Lotto", "Command", "/lotto {zahl}"))
    YK_LottoPat   := YkIniRead(p, "Lotto", "Trigger", "^\[LOTTO\] In ca\. 10 Minuten")
    YK_LottoGapMs := YkIniRead(p, "Lotto", "GapMs", 1500) + 0
    if (YK_LottoGapMs < 500 || YK_LottoGapMs > 20000)
        YK_LottoGapMs := 1500
    YK_LottoMin   := YkIniRead(p, "Lotto", "Min", 1) + 0
    YK_LottoMax   := YkIniRead(p, "Lotto", "Max", 100) + 0
    if (YK_LottoMin < 1 || YK_LottoMin > 999999)
        YK_LottoMin := 1
    if (YK_LottoMax < YK_LottoMin || YK_LottoMax > 999999)
        YK_LottoMax := (YK_LottoMin > 100) ? YK_LottoMin : 100

    ; Update-Hinweis
    YK_UpdEnabled := (YkIniRead(p, "Update", "Enabled", 1) + 0) != 0
    YK_UpdUrl     := Trim(YkIniRead(p, "Update", "Url", ""))
    YK_UpdHours   := YkIniRead(p, "Update", "IntervalHours", 6) + 0
    if (YK_UpdHours < 1 || YK_UpdHours > 168)
        YK_UpdHours := 6
    ; neue Fassung von selbst holen (installiert wird erst nach Nachfrage)
    YK_UpdAuto    := (YkIniRead(p, "Update", "AutoDownload", 1) + 0) != 0

    ; Muster fuer die Kriegsarten (aenderbar, falls der Server anders schreibt)
    YK_WarGangPat  := YkIniRead(p, "War", "GangPattern", "^\[\s*GANG[ _-]?WAR\s*\]")
    YK_WarFamPat   := YkIniRead(p, "War", "FamilyPattern", "^\[\s*FAMILY[ _-]?WAR\s*\]")
    YK_WarBizPat   := YkIniRead(p, "War", "BizPattern", "^\[\s*(BIZ[ _-]?FIGHT|BIZ|BUSINESS|BIZWAR)\s*\]")
    YK_WarBizBoard := YkIniRead(p, "War", "BizBoardPattern", "biz|business|gesch(ä|ae)ft|laden")

    ; Binds laden
    YK_Binds := []
    cnt := YkIniRead(p, "Binds", "Count", 0) + 0
    Loop, % cnt {
        idx := A_Index
        k := YkHk_Normalize(YkIniRead(p, "Binds", "Bind" . idx . "Key", ""))
        c := YkIniRead(p, "Binds", "Bind" . idx . "Cmd", "")
        e := (YkIniRead(p, "Binds", "Bind" . idx . "Enter", 1) + 0) != 0
        exHp    := (YkIniRead(p, "Binds", "Bind" . idx . "ExHp", 0) + 0) != 0
        exArmor := (YkIniRead(p, "Binds", "Bind" . idx . "ExArmor", 0) + 0) != 0
        exLoc   := (YkIniRead(p, "Binds", "Bind" . idx . "ExLoc", 0) + 0) != 0
        exVeh   := (YkIniRead(p, "Binds", "Bind" . idx . "ExVeh", 0) + 0) != 0
        ; Server-Update: aus /family wurde /f  (/familymap bleibt)
        c := RegExReplace(c, "i)^/family(?=\s|$)", "/f")
        if (k = "" && c = "")
            continue
        ; exakt doppelte Eintraege (gleiche Taste, gleicher Text) weglassen
        dup := false
        for j, ob in YK_Binds {
            if (ob.key = k && ob.cmd == c) {
                dup := true
                break
            }
        }
        if (!dup)
            YK_Binds.Push({key: k, cmd: c, enter: e, exHp: exHp, exArmor: exArmor, exLoc: exLoc, exVeh: exVeh})
    }

    ; Zuweisungen aus der Server-Befehlsliste laden
    YK_KurzEnabled := (YkIniRead(p, "General", "KurzformAktiv", 1) + 0) != 0
    YK_CmdBinds := {}
    scnt := YkIniRead(p, "ServerBinds", "Count", 0) + 0
    Loop, % scnt {
        sidx := A_Index
        sk := YkIniRead(p, "ServerBinds", "S" . sidx . "Cmd", "")
        if (sk = "")
            continue
        sk := RegExReplace(sk, "i)^/family(?=\s|$)", "/f")
        ; Windows schneidet beim Lesen Leerzeichen am Ende ab ("/g " -> "/g") -
        ; wieder dem Befehl aus der Liste zuordnen
        if (!IsObject(YkCmd_FindByKey(sk)) && IsObject(YkCmd_FindByKey(sk . " ")))
            sk .= " "
        YK_CmdBinds[sk] := {hk:    YkHk_Normalize(YkIniRead(p, "ServerBinds", "S" . sidx . "Hotkey", ""))
                          , kurz:  YkIniRead(p, "ServerBinds", "S" . sidx . "Kurz", "")
                          , enter: (YkIniRead(p, "ServerBinds", "S" . sidx . "Enter", 1) + 0)
                          , exHp:    (YkIniRead(p, "ServerBinds", "S" . sidx . "ExHp", 0) + 0) != 0
                          , exArmor: (YkIniRead(p, "ServerBinds", "S" . sidx . "ExArmor", 0) + 0) != 0
                          , exLoc:   (YkIniRead(p, "ServerBinds", "S" . sidx . "ExLoc", 0) + 0) != 0
                          , exVeh:   (YkIniRead(p, "ServerBinds", "S" . sidx . "ExVeh", 0) + 0) != 0}
    }

    ; Neu in v3.0 (Chat-Befehle, Funktionstasten, SMS, Meldungen ...)
    YkLoadConfigV3(p)
}

; altes Format "{zone} ({city})" entspricht dem neuen Platzhalter {standort}
YkMigrateFormat(fmt) {
    return (Trim(fmt) = "{zone} ({city})") ? "{standort}" : fmt
}

YkIniRead(file, section, key, default) {
    sentinel := Chr(1) . "__YKNF__"
    IniRead, val, % file, % section, % key, % sentinel
    if (val == sentinel)
        return default
    return val
}

; Werte mit Leerzeichen am Rand in Anfuehrungszeichen schreiben - sonst
; schneidet Windows sie beim Lesen ab (aus "/g " wuerde "/g")
YkIniQuote(v) {
    return (v != Trim(v)) ? """" . v . """" : v
}

YkSaveConfig() {
    global YK_IniPath
    global YK_ChatKey, YK_GangCmd, YK_SendDelay, YK_MemEnabled, YK_StartPaused, YK_FastSend
    global YK_LocHotkey, YK_LocPrefix, YK_LocFormat
    global YK_CombatEnabled, YK_ChatlogPath, YK_KillEnabled, YK_KillPattern, YK_KillPrefix, YK_KillFormat, YK_KillHotkey
    global YK_DeathEnabled, YK_DeathPattern, YK_DeathPrefix, YK_DeathFormat, YK_DeathByHealth, YK_ReportCooldown
    global YK_FamEnabled, YK_FamCommand, YK_FamLoginPat, YK_FamConnectPat, YK_FamDelay, YK_FamHotkey, YK_FamOnce
    global YK_SprintEnabled, YK_SprintKey, YK_SprintMoveKeys, YK_SprintToggleHk, YK_SprintTapDown, YK_SprintTapUp, YK_SprintOnFoot, YK_SprintReqMove
    global YK_Binds
    global YK_CmdBinds, YK_KurzEnabled, YK_ExtrasOrder

    p := YK_IniPath

    IniWrite, % YK_ChatKey, % p, General, ChatKey
    IniWrite, % YK_GangCmd, % p, General, GangCmd
    IniWrite, % YK_SendDelay, % p, General, SendDelay
    IniWrite, % YK_ExtrasOrder, % p, General, ExtrasOrder
    IniWrite, % (YK_MemEnabled ? 1 : 0), % p, General, EnableMemoryRead
    IniWrite, % (YK_StartPaused ? 1 : 0), % p, General, StartPaused
    IniWrite, % (YK_FastSend ? 1 : 0), % p, General, FastSend
    IniWrite, % (YK_StallLog ? 1 : 0), % p, General, StallLog
    IniWrite, % YK_StallMs, % p, General, StallMs
    IniWrite, % YK_SendWaitMs, % p, General, SendWaitMs
    IniDelete, % p, General, LowPriority

    IniWrite, % YK_LocHotkey, % p, Location, Hotkey
    IniWrite, % YK_LocPrefix, % p, Location, Prefix
    IniWrite, % YK_LocFormat, % p, Location, Format
    IniWrite, % YK_LocText, % p, Location, Text

    IniWrite, % (YK_CombatEnabled ? 1 : 0), % p, Combat, Enabled
    IniWrite, % YK_ChatlogPath, % p, Combat, ChatlogPath
    IniWrite, % (YK_KillEnabled ? 1 : 0), % p, Combat, KillEnabled
    IniWrite, % YK_KillPattern, % p, Combat, KillPattern
    IniWrite, % YK_KillPrefix, % p, Combat, KillPrefix
    IniWrite, % YK_KillFormat, % p, Combat, KillFormat
    IniWrite, % YK_KillText, % p, Combat, KillText
    IniWrite, % YK_KillHotkey, % p, Combat, KillHotkey
    IniWrite, % (YK_DeathEnabled ? 1 : 0), % p, Combat, DeathEnabled
    IniWrite, % YK_DeathPattern, % p, Combat, DeathPattern
    IniWrite, % YK_DeathPrefix, % p, Combat, DeathPrefix
    IniWrite, % YK_DeathFormat, % p, Combat, DeathFormat
    IniWrite, % YK_DeathText, % p, Combat, DeathText
    IniWrite, % (YK_DeathByHealth ? 1 : 0), % p, Combat, DeathByHealth
    IniWrite, % YK_ReportCooldown, % p, Combat, ReportCooldown
    IniWrite, % (YK_KillAuto ? 1 : 0), % p, Combat, KillAuto
    IniWrite, % YK_KillWindowMs, % p, Combat, KillWindowMs
    IniWrite, % YK_KillRivalMs, % p, Combat, KillRivalMs
    IniWrite, % YK_KillSameMs, % p, Combat, KillSameMs
    IniWrite, % (YK_PlrEnabled ? 1 : 0), % p, Combat, VictimNames
    IniWrite, % YK_KoPattern, % p, Combat, KoPattern
    IniWrite, % YK_KoRejectPat, % p, Combat, KoRejectPattern
    IniWrite, % YK_RevivePattern, % p, Combat, RevivePattern
    IniWrite, % YK_HospPattern, % p, Combat, HospitalPattern
    IniWrite, % (YK_ReviveEnabled ? 1 : 0), % p, Combat, ReviveEnabled
    IniWrite, % YkIniQuote(YK_ReviveText), % p, Combat, ReviveText
    IniWrite, % YK_KoWaitSec, % p, Combat, KoWaitSec
    IniWrite, % YK_KoRetrySec, % p, Combat, KoRetrySec
    IniWrite, % (YK_KillLogOn ? 1 : 0), % p, Combat, KillLog
    IniWrite, % (YK_KillerEnabled ? 1 : 0), % p, Combat, KillerEnabled
    IniWrite, % YK_KillerPattern, % p, Combat, KillerPattern

    IniWrite, % (YK_FamEnabled ? 1 : 0), % p, FamilyMap, Enabled
    IniWrite, % YK_FamCommand, % p, FamilyMap, Command
    IniWrite, % YK_FamLoginPat, % p, FamilyMap, LoginPattern
    IniWrite, % YK_FamConnectPat, % p, FamilyMap, ConnectPattern
    IniWrite, % YK_FamDelay, % p, FamilyMap, DelayMs
    IniWrite, % YK_FamHotkey, % p, FamilyMap, Hotkey
    IniWrite, % (YK_FamOnce ? 1 : 0), % p, FamilyMap, OncePerConnect

    IniWrite, % (YK_SprintEnabled ? 1 : 0), % p, Sprint, Enabled
    IniWrite, % YK_SprintKey, % p, Sprint, SprintKey
    IniWrite, % YK_SprintMoveKeys, % p, Sprint, MovementKeys
    IniWrite, % YK_SprintToggleHk, % p, Sprint, ToggleHotkey
    IniWrite, % YK_SprintTapDown, % p, Sprint, TapDownMs
    IniWrite, % YK_SprintTapUp, % p, Sprint, TapUpMs
    IniWrite, % (YK_SprintOnFoot ? 1 : 0), % p, Sprint, OnlyOnFoot
    IniWrite, % (YK_SprintReqMove ? 1 : 0), % p, Sprint, RequireMovementKey
    IniWrite, % YK_CrouchKey, % p, Sprint, CrouchKey

    IniWrite, % (YK_OvEnabled ? 1 : 0), % p, Overlay, Enabled
    IniWrite, % YK_OvHotkey, % p, Overlay, Hotkey
    IniDelete, % p, Overlay, Corner
    IniWrite, % YK_OvSide, % p, Overlay, Side
    IniWrite, % YK_OvVPos, % p, Overlay, VPos
    IniWrite, % (YK_OvDodge ? 1 : 0), % p, Overlay, Dodge
    IniWrite, % YK_OvSize, % p, Overlay, Size
    IniWrite, % YK_OvOpacity, % p, Overlay, Opacity
    IniWrite, % YK_OvHidden, % p, Overlay, Hidden
    IniWrite, % (YK_MemShow ? 1 : 0), % p, Overlay, ShowMembers
    IniWrite, % YK_MemHotkey, % p, Overlay, MemberHotkey
    IniWrite, % YK_GangTag, % p, Overlay, GangTag
    IniWrite, % YK_OwnName, % p, Overlay, OwnName
    IniWrite, % (YK_OvShowKeys ? 1 : 0), % p, Overlay, ShowKeys
    IniWrite, % (YK_OvWar ? 1 : 0), % p, Overlay, ShowWar
    IniWrite, % (YK_OvStatus ? 1 : 0), % p, Overlay, ShowStatus
    IniWrite, % YK_Faction, % p, Overlay, Faction
    global YK_CallSoundType, YK_WarSoundType, YK_CallSoundFile, YK_WarSoundFile
    YK_CallSound := (YK_CallSoundType != "aus" || YK_WarSoundType != "aus")
    IniWrite, % (YK_CallSound ? 1 : 0), % p, Overlay, CallSound
    IniWrite, % YK_CallSoundType, % p, Overlay, CallSoundType
    IniWrite, % YK_WarSoundType, % p, Overlay, WarSoundType
    IniWrite, % YK_CallSoundFile, % p, Overlay, CallSoundFile
    IniWrite, % YK_WarSoundFile, % p, Overlay, WarSoundFile
    IniWrite, % (YK_MarkEnabled ? 1 : 0), % p, Overlay, MarkEnabled
    IniWrite, % (YK_MarkSendGps ? 1 : 0), % p, Overlay, MarkSendGps
    IniWrite, % YK_MarkMinutes, % p, Overlay, MarkMinutes
    IniWrite, % YK_MarkSprite, % p, Overlay, MarkSprite
    IniWrite, % YK_MarkTgtSpr, % p, Overlay, MarkTargetSprite
    IniWrite, % YK_OvFullscreen, % p, Overlay, FullscreenMode
    IniWrite, % YK_WarNoteSec, % p, Overlay, WarNoteSeconds
    IniWrite, % (YK_OvHideCapture ? 1 : 0), % p, Overlay, HideInRecordings
    ; alter Schluessel aus v2.0.0 - er wird nicht mehr gelesen und soll
    ; auch nicht in der Datei herumliegen
    IniDelete, % p, Overlay, HideFromCapture

    IniWrite, % (YK_StatsEnabled ? 1 : 0), % p, Stats, Enabled
    IniWrite, % YK_StatsKillPat, % p, Stats, KillPattern
    IniWrite, % YK_StatsDeathPat, % p, Stats, DeathPattern

    IniWrite, % (YK_WantedEnabled ? 1 : 0), % p, Wanteds, Enabled
    IniWrite, % YK_WantedCmd, % p, Wanteds, Command
    IniWrite, % YK_WantedPat, % p, Wanteds, Pattern
    IniWrite, % YK_WantedWaitMs, % p, Wanteds, WaitMs

    IniWrite, % (YK_LottoOn ? 1 : 0), % p, Lotto, Enabled
    IniWrite, % YK_LottoCount, % p, Lotto, Count
    IniWrite, % YK_LottoCmd, % p, Lotto, Command
    IniWrite, % YK_LottoPat, % p, Lotto, Trigger
    IniWrite, % YK_LottoGapMs, % p, Lotto, GapMs
    IniWrite, % YK_LottoMin, % p, Lotto, Min
    IniWrite, % YK_LottoMax, % p, Lotto, Max

    IniWrite, % (YK_UpdEnabled ? 1 : 0), % p, Update, Enabled
    IniWrite, % YK_UpdUrl, % p, Update, Url
    IniWrite, % YK_UpdHours, % p, Update, IntervalHours
    IniWrite, % (YK_UpdAuto ? 1 : 0), % p, Update, AutoDownload

    IniWrite, % YK_WarGangPat, % p, War, GangPattern
    IniWrite, % YK_WarFamPat, % p, War, FamilyPattern
    IniWrite, % YK_WarBizPat, % p, War, BizPattern
    IniWrite, % YK_WarBizBoard, % p, War, BizBoardPattern

    ; Binds: alte Sektion loeschen und neu schreiben
    IniDelete, % p, Binds
    IniWrite, % YK_Binds.Length(), % p, Binds, Count
    for i, b in YK_Binds {
        IniWrite, % b.key, % p, Binds, % "Bind" . i . "Key"
        IniWrite, % YkIniQuote(b.cmd), % p, Binds, % "Bind" . i . "Cmd"
        IniWrite, % (b.enter ? 1 : 0), % p, Binds, % "Bind" . i . "Enter"
        IniWrite, % (b.exHp ? 1 : 0), % p, Binds, % "Bind" . i . "ExHp"
        IniWrite, % (b.exArmor ? 1 : 0), % p, Binds, % "Bind" . i . "ExArmor"
        IniWrite, % (b.exLoc ? 1 : 0), % p, Binds, % "Bind" . i . "ExLoc"
        IniWrite, % (b.exVeh ? 1 : 0), % p, Binds, % "Bind" . i . "ExVeh"
    }

    ; Zuweisungen der Server-Befehle
    IniWrite, % (YK_KurzEnabled ? 1 : 0), % p, General, KurzformAktiv
    IniDelete, % p, ServerBinds
    sn := 0
    for ck, sb in YK_CmdBinds {
        if (sb.hk = "" && sb.kurz = "")
            continue
        sn += 1
        IniWrite, % YkIniQuote(ck), % p, ServerBinds, % "S" . sn . "Cmd"
        IniWrite, % sb.hk, % p, ServerBinds, % "S" . sn . "Hotkey"
        IniWrite, % sb.kurz, % p, ServerBinds, % "S" . sn . "Kurz"
        IniWrite, % (sb.enter ? 1 : 0), % p, ServerBinds, % "S" . sn . "Enter"
        IniWrite, % (sb.exHp ? 1 : 0), % p, ServerBinds, % "S" . sn . "ExHp"
        IniWrite, % (sb.exArmor ? 1 : 0), % p, ServerBinds, % "S" . sn . "ExArmor"
        IniWrite, % (sb.exLoc ? 1 : 0), % p, ServerBinds, % "S" . sn . "ExLoc"
        IniWrite, % (sb.exVeh ? 1 : 0), % p, ServerBinds, % "S" . sn . "ExVeh"
    }
    IniWrite, % sn, % p, ServerBinds, Count

    ; Neu in v3.0
    YkSaveConfigV3(p)
}

YkWriteDefaultIni() {
    global YK_IniPath
    p := YK_IniPath
    IniWrite, t,        % p, General, ChatKey
    IniWrite, /g,       % p, General, GangCmd
    IniWrite, 0,        % p, General, SendDelay
    IniWrite, 1,        % p, General, FastSend
    IniWrite, hp`,armor`,loc`,veh, % p, General, ExtrasOrder
    IniWrite, 1,        % p, General, EnableMemoryRead
    IniWrite, 0,        % p, General, StartPaused
    IniWrite, 1,        % p, General, KurzformAktiv
    IniWrite, 1,        % p, General, StallLog
    IniWrite, 250,      % p, General, StallMs
    IniWrite, 400,      % p, General, SendWaitMs

    IniWrite, ^g,                         % p, Location, Hotkey
    IniWrite, Standort: {standort},       % p, Location, Text

    IniWrite, 1,                % p, Combat, Enabled
    IniWrite, % "",             % p, Combat, ChatlogPath
    IniWrite, 1,                % p, Combat, KillEnabled
    IniWrite, % "",             % p, Combat, KillPattern
    IniWrite, Kill in {standort},         % p, Combat, KillText
    IniWrite, ^k,               % p, Combat, KillHotkey
    IniWrite, 1,                % p, Combat, KillAuto
    IniWrite, 600,              % p, Combat, KillWindowMs
    IniWrite, 150,              % p, Combat, KillRivalMs
    IniWrite, 900,              % p, Combat, KillSameMs
    IniWrite, 1,                % p, Combat, VictimNames
    IniWrite, 1,                % p, Combat, DeathEnabled
    IniWrite, % "",             % p, Combat, DeathPattern
    IniWrite, % "Getötet in {standort} von {mörder}", % p, Combat, DeathText
    IniWrite, 1,                % p, Combat, KillerEnabled
    IniWrite, % "",             % p, Combat, KillerPattern
    IniWrite, 1,                % p, Combat, ReviveEnabled
    IniWrite, % "Von einem Medic wiederbelebt | Standort: {standort} | HP: {hp}", % p, Combat, ReviveText
    IniWrite, % "wiederbelebt|reanimiert|aus dem Krankenhaus|Krankenhaus entlassen|wieder bei Bewusstsein|bist wieder wach", % p, Combat, RevivePattern
    IniWrite, % "Krankenhaus|Hospital|Klinik", % p, Combat, HospitalPattern
    IniWrite, 1,                % p, Combat, DeathByHealth
    IniWrite, 3000,             % p, Combat, ReportCooldown
    IniWrite, 0,                % p, Combat, KillLog

    IniWrite, 1,                % p, FamilyMap, Enabled
    IniWrite, /familymap,       % p, FamilyMap, Command
    IniWrite, Willkommen auf,   % p, FamilyMap, LoginPattern
    IniWrite, Connecting to,    % p, FamilyMap, ConnectPattern
    IniWrite, 5000,             % p, FamilyMap, DelayMs
    IniWrite, ^m,               % p, FamilyMap, Hotkey
    IniWrite, 1,                % p, FamilyMap, OncePerConnect

    IniWrite, 1,                          % p, Sprint, Enabled
    IniWrite, Space,                      % p, Sprint, SprintKey
    IniWrite, w`,a`,s`,d`,Up`,Down`,Left`,Right, % p, Sprint, MovementKeys
    IniWrite, ^Space,                     % p, Sprint, ToggleHotkey
    IniWrite, 30,                         % p, Sprint, TapDownMs
    IniWrite, 30,                         % p, Sprint, TapUpMs
    IniWrite, 1,                          % p, Sprint, OnlyOnFoot
    IniWrite, 1,                          % p, Sprint, RequireMovementKey
    IniWrite, c,                          % p, Sprint, CrouchKey

    IniWrite, 1,                          % p, Overlay, Enabled
    IniWrite, ^o,                         % p, Overlay, Hotkey
    IniWrite, 2,                          % p, Overlay, Side
    IniWrite, 100,                        % p, Overlay, VPos
    IniWrite, 1,                          % p, Overlay, Dodge
    IniWrite, 2,                          % p, Overlay, Size
    IniWrite, 215,                        % p, Overlay, Opacity
    IniWrite, 1,                          % p, Overlay, ShowMembers
    IniWrite, 1,                          % p, Overlay, ShowKeys
    IniWrite, 1,                          % p, Overlay, ShowWar
    IniWrite, 1,                          % p, Overlay, ShowStatus
    IniWrite, ^p,                         % p, Overlay, MemberHotkey
    IniWrite, [YAK],                      % p, Overlay, GangTag
    IniWrite, Yakuza,                     % p, Overlay, Faction
    IniWrite, 1,                          % p, Overlay, CallSound
    IniWrite, *48,                        % p, Overlay, CallSoundType
    IniWrite, *16,                        % p, Overlay, WarSoundType
    IniWrite, 1,                          % p, Overlay, MarkEnabled
    IniWrite, 1,                          % p, Overlay, MarkSendGps
    IniWrite, 10,                         % p, Overlay, MarkMinutes
    IniWrite, 19,                         % p, Overlay, MarkSprite
    IniWrite, 53,                         % p, Overlay, MarkTargetSprite
    IniWrite, auto,                       % p, Overlay, FullscreenMode
    IniWrite, 120,                        % p, Overlay, WarNoteSeconds
    IniWrite, 0,                          % p, Overlay, HideInRecordings

    ; Kills/Tode aus dem Charaktermenue (Taste N) uebernehmen
    IniWrite, 1,                                   % p, Stats, Enabled
    IniWrite, % "Kills?\s*[:=]\s*(\d+)",           % p, Stats, KillPattern
    IniWrite, % "(?:Tode|Todesf(?:ä|ae)lle|Deaths?)\s*[:=]\s*(\d+)", % p, Stats, DeathPattern

    ; Wanteds: wird nur geholt, wenn {wanteds} in einem Text steht
    IniWrite, 1,                          % p, Wanteds, Enabled
    IniWrite, /wanteds,                   % p, Wanteds, Command
    IniWrite, % "(?:Aktuelle\s+)?Wanteds?\s*[:=]?\s*(\d+)", % p, Wanteds, Pattern
    IniWrite, 2500,                       % p, Wanteds, WaitMs

    ; Lotto: ab Werk AUS (der Binder sendet sonst von selbst Befehle)
    IniWrite, 0,                          % p, Lotto, Enabled
    IniWrite, 1,                          % p, Lotto, Count
    IniWrite, % "/lotto {zahl}",          % p, Lotto, Command
    IniWrite, % "^\[LOTTO\] In ca\. 10 Minuten", % p, Lotto, Trigger
    IniWrite, 1500,                       % p, Lotto, GapMs
    IniWrite, 1,                          % p, Lotto, Min
    IniWrite, 100,                        % p, Lotto, Max

    ; Update-Hinweis: Adresse einer Textdatei mit "Version=..." (leer = aus)
    IniWrite, 1,                          % p, Update, Enabled
    IniWrite, % YK_UPD_DEFAULT,           % p, Update, Url
    IniWrite, 6,                          % p, Update, IntervalHours
    IniWrite, 1,                          % p, Update, AutoDownload

    ; Beispiel-Binds fuer die Family (frei aenderbar)
    IniWrite, 4,                          % p, Binds, Count
    IniWrite, ^Numpad1,                   % p, Binds, Bind1Key
    IniWrite, /g Brauche Backup in {standort} - HP {hp} / Rüstung {ruestung}, % p, Binds, Bind1Cmd
    IniWrite, 1,                          % p, Binds, Bind1Enter
    IniWrite, ^Numpad2,                   % p, Binds, Bind2Key
    IniWrite, /g Komme zu {ruf} nach {ruf_ort}!, % p, Binds, Bind2Cmd
    IniWrite, 1,                          % p, Binds, Bind2Enter
    IniWrite, ^Numpad3,                   % p, Binds, Bind3Key
    IniWrite, /g Sammeln in {standort}!,  % p, Binds, Bind3Cmd
    IniWrite, 1,                          % p, Binds, Bind3Enter
    IniWrite, ^Numpad4,                   % p, Binds, Bind4Key
    IniWrite, /g Bin unterwegs zu {ziel} nach {ziel_ort}, % p, Binds, Bind4Cmd
    IniWrite, 1,                          % p, Binds, Bind4Enter
}

YkApplyConfig() {
    YkLoadConfig()
    YkBuildMoveKeys()
    YkInitChatlog()
    YkApplyPriority()
    YkRegisterAllHotkeys()
    YkRefreshTray()
    YkWarNote_Arm()
    YkOverlay_Refresh(true)
}

; Der Binder laeuft IMMER mit normaler Prioritaet - das ist kein Versehen.
;
; Bis v2.0.1 hat er sich auf Wunsch auf "BelowNormal" heruntergestuft, damit
; er dem Spiel keine Rechenzeit wegnimmt. Gut gemeint, aber falsch: in diesem
; Programm haengt der systemweite Tastatur-Hook von Windows. Jeder Tastendruck
; auf dem ganzen Rechner laeuft durch diesen Hook, und Windows gibt ihm dafuer
; nur eine feste Frist. Saettigt GTA die Kerne, kommt ein heruntergestufter
; Prozess nicht rechtzeitig dran - dann haengt die Eingabe im GANZEN System,
; nicht nur im Binder. Genau das Gefuehl "alles steht, Alt+Tab hilft nicht".
;
; Der Binder kostet im Leerlauf ohnehin fast nichts (ein paar Zeitabfragen und
; Speicher-Lesevorgaenge je Takt). Es gibt also nichts zu sparen - und die
; Taste soll ankommen.
YkApplyPriority() {
    try Process, Priority, , Normal
}
