; =====================================================================
;  Brooklyn Keybinder - Einstellungen laden / speichern
; ---------------------------------------------------------------------
;  Alles liegt wie frueher unter  Dokumente\Keybinder von Brooklyn
;    config.ini      Einstellungen, Tasten, eigene Texte
;    stats.ini       Statistik (gesamt, pro Tag, pro Monat)
;    Gegnerlisten\   eine Textdatei pro Liste (Format wie v4.60)
;    finanzlog.txt   Protokoll wie in v4.60
;  Beim ersten Start werden vorhandene Daten der alten Version 4.x
;  (Hotkeybelegung.ini, framework.ini, Statistiken) automatisch uebernommen.
; =====================================================================

global BK_Dir := "", BK_Ini := "", BK_StatsIni := ""

; Name, Standardwert, INI-Abschnitt
BkCfg_Defs() {
    static d := ""
    if (IsObject(d))
        return d
    d := []
    ; ---- Profil ----
    d.Push(["ProfType", "zivi", "Profil"])
    d.Push(["ProfFaction", "", "Profil"])
    d.Push(["ProfJob", "", "Profil"])
    d.Push(["FChat", "/f", "Profil"])
    d.Push(["GChat", "/g", "Profil"])
    d.Push(["Funk", "/r", "Profil"])
    d.Push(["DChat", "/d", "Profil"])
    ; ---- Allgemein ----
    d.Push(["Name", "", "Allgemein"])
    d.Push(["ChatKey", "t", "Allgemein"])
    d.Push(["FastSend", 1, "Allgemein"])
    d.Push(["SendDelay", 0, "Allgemein"])
    d.Push(["SendWaitMs", 700, "Allgemein"])
    d.Push(["LineDelay", 250, "Allgemein"])
    d.Push(["MemEnabled", 1, "Allgemein"])
    d.Push(["GameExes", "gta_sa.exe, rgn_ac_gta.exe", "Allgemein"])
    d.Push(["ChatlogPath", "", "Allgemein"])
    d.Push(["StartMin", 0, "Allgemein"])
    d.Push(["ShowAll", 0, "Allgemein"])
    d.Push(["Accent", "FF8A1F", "Allgemein"])
    d.Push(["Debug", 0, "Allgemein"])
    ; ---- Texte ----
    d.Push(["Drogenbox", "", "Texte"])
    d.Push(["MemberAD", "", "Texte"])
    d.Push(["OrgAD", "", "Texte"])
    d.Push(["SonstAD", "", "Texte"])
    Loop, 6
        d.Push(["Spruch" . A_Index, "", "Texte"])
    ; ---- Waffen ----
    for i, w in BkCfg_Weapons()
        d.Push(["Mun_" . w[1], w[2], "Waffen"])
    d.Push(["Pack1", "deagle:50|shotgun:50|m4:200", "Waffen"])
    d.Push(["Pack2", "mp5:200|rifle:50|sniper:20", "Waffen"])
    d.Push(["Pack3", "", "Waffen"])
    ; ---- Automatik ----
    d.Push(["GWZ", "+1 Kill", "Automatik"])
    d.Push(["GZZ", "+1 Gangzone", "Automatik"])
    d.Push(["GWLoc", 1, "Automatik"])
    d.Push(["GZLoc", 1, "Automatik"])
    d.Push(["AutoGW", 1, "Automatik"])
    d.Push(["AutoGZ", 1, "Automatik"])
    d.Push(["AutoWantedKill", 0, "Automatik"])
    d.Push(["AutoTot", 0, "Automatik"])
    d.Push(["Arrestsage", 0, "Automatik"])
    d.Push(["Drogensage", 1, "Automatik"])
    d.Push(["TimerFrage", 1, "Automatik"])
    d.Push(["Antispam", 1, "Automatik"])
    d.Push(["HackMsg", 1, "Automatik"])
    d.Push(["ClearMsg", 1, "Automatik"])
    d.Push(["LawyerMsg", 1, "Automatik"])
    d.Push(["MemDeath", 1, "Automatik"])
    d.Push(["Welcome", 1, "Automatik"])
    ; ---- Programme ----
    d.Push(["PathTS", "", "Programme"])
    d.Push(["PathGame", "", "Programme"])
    d.Push(["PathRec", "", "Programme"])
    d.Push(["RecKey", "F9", "Programme"])
    d.Push(["RecFolder", "", "Programme"])
    d.Push(["FragFolder", "", "Programme"])
    d.Push(["ComplaintFolder", "", "Programme"])
    d.Push(["RadioChan", 1, "Programme"])
    d.Push(["RadioUrl", "", "Programme"])
    d.Push(["RadioVol", 60, "Programme"])
    ; ---- Overlay ----
    d.Push(["OvEnabled", 1, "Overlay"])
    d.Push(["OvSide", "links", "Overlay"])
    d.Push(["OvToastMs", 5000, "Overlay"])
    d.Push(["OvHud", 0, "Overlay"])
    d.Push(["OvFullscreen", "auto", "Overlay"])
    d.Push(["OvSound", 1, "Overlay"])
    return d
}

; Waffe (Befehl), Standardmunition, Anzeigename
BkCfg_Weapons() {
    return [["deagle", 50, "Deagle"], ["shotgun", 50, "Shotgun"], ["m4", 200, "M4"], ["mp5", 200, "MP5"]
          , ["rifle", 50, "Rifle"], ["sniper", 20, "Sniper"], ["ak47", 200, "AK47"]]
}

BkCfg_PackWeapons() {
    return ["deagle", "shotgun", "m4", "mp5", "rifle", "sniper", "ak47", "9mm", "katana", "shovel", "parachute"]
}

BkCfg_Init() {
    global BK_Dir, BK_Ini, BK_StatsIni
    RegRead, personal, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders, Personal
    base := (!ErrorLevel && personal != "") ? personal : A_MyDocuments
    BK_Dir := base . "\Keybinder von Brooklyn"
    ; tragbarer Modus: liegt eine config.ini neben der EXE, wird die benutzt
    if FileExist(A_ScriptDir . "\config.ini")
        BK_Dir := A_ScriptDir
    for i, sub in ["", "\Gegnerlisten", "\Aufnahmen"]
        if !FileExist(BK_Dir . sub)
            FileCreateDir, % BK_Dir . sub
    BK_Ini := BK_Dir . "\config.ini"
    BK_StatsIni := BK_Dir . "\stats.ini"
    first := !FileExist(BK_Ini)
    ; INI-Dateien als UTF-16 anlegen - nur dann speichert Windows Umlaute
    ; (z.B. "Verstärkung") in eigenen Texten korrekt
    for i, f in [BK_Ini, BK_StatsIni]
        if !FileExist(f)
            FileAppend, % "", %f%, UTF-16
    BkCfg_Load()
    if (first) {
        BK_Keys["hk121"] := "Pause"
        BK_Keys["sys_reload"] := "!F2"
        BkCfg_ImportOld()
        BkCfg_Save()
    }
}

; Wert aus der INI lesen (Anfuehrungszeichen erhalten Leerzeichen am Rand)
BkIni_Read(sec, key, def := "") {
    global BK_Ini
    IniRead, v, %BK_Ini%, %sec%, %key%, % Chr(1)
    if (v = Chr(1))
        return def
    return BkIni_Dec(v)
}

BkIni_Write(sec, key, val) {
    global BK_Ini
    IniWrite, % """" . BkIni_Enc(val) . """", %BK_Ini%, %sec%, %key%
}

BkIni_Enc(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, "`r", "")
    return StrReplace(s, "`n", "\n")
}

BkIni_Dec(s) {
    s := StrReplace(s, "\\", Chr(2))
    s := StrReplace(s, "\n", "`n")
    return StrReplace(s, Chr(2), "\")
}

BkCfg_Load() {
    global
    local i, e, v, sec
    for i, e in BkCfg_Defs() {
        v := BkIni_Read(e[3], e[1], e[2])
        BkCfg_Set(e[1], v)
    }
    BkCfg_LoadBinds()
}

BkCfg_Set(name, v) {
    global
    BK_%name% := v
}

BkCfg_Get(name) {
    global
    return BK_%name%
}

BkCfg_Save() {
    global BK_Ini
    for i, e in BkCfg_Defs()
        BkIni_Write(e[3], e[1], BkCfg_Get(e[1]))
    BkCfg_SaveBinds()
}

; ---------------------------------------------------------------------
;  Tasten, eigene Texte, abgeschaltete Chat-Befehle, eigene Chat-Befehle
; ---------------------------------------------------------------------
global BK_Keys := {}          ; bindId -> Taste
global BK_Texts := {}         ; bindId -> eigener Text
global BK_TbOff := {}         ; Chat-Befehl -> 1 (abgeschaltet)
global BK_CustomTb := []      ; [{cmd, text}]

BkCfg_LoadBinds() {
    global BK_Ini, BK_Keys, BK_Texts, BK_TbOff, BK_CustomTb
    BK_Keys := {}, BK_Texts := {}, BK_TbOff := {}, BK_CustomTb := []
    for i, sec in ["Tasten", "Texte_Binds", "Chatbefehle_Aus"] {
        IniRead, body, %BK_Ini%, %sec%
        Loop, Parse, body, `n, `r
        {
            p := InStr(A_LoopField, "=")
            if (!p)
                continue
            k := SubStr(A_LoopField, 1, p - 1)
            v := BkIni_Dec(Trim(SubStr(A_LoopField, p + 1), """"))
            if (sec = "Tasten")
                BK_Keys[k] := v
            else if (sec = "Texte_Binds")
                BK_Texts[k] := v
            else
                BK_TbOff[k] := 1
        }
    }
    n := BkIni_Read("Eigene_Chatbefehle", "Anzahl", 0)
    Loop, % n {
        c := BkIni_Read("Eigene_Chatbefehle", "Befehl" . A_Index, "")
        t := BkIni_Read("Eigene_Chatbefehle", "Text" . A_Index, "")
        if (c != "")
            BK_CustomTb.Push({cmd: c, text: t})
    }
}

BkCfg_SaveBinds() {
    global BK_Ini, BK_Keys, BK_Texts, BK_TbOff, BK_CustomTb
    for i, sec in ["Tasten", "Texte_Binds", "Chatbefehle_Aus", "Eigene_Chatbefehle"]
        IniDelete, %BK_Ini%, %sec%
    for k, v in BK_Keys
        if (v != "")
            BkIni_Write("Tasten", k, v)
    for k, v in BK_Texts
        BkIni_Write("Texte_Binds", k, v)
    for k, v in BK_TbOff
        if (v)
            BkIni_Write("Chatbefehle_Aus", k, 1)
    BkIni_Write("Eigene_Chatbefehle", "Anzahl", BK_CustomTb.MaxIndex() ? BK_CustomTb.MaxIndex() : 0)
    for i, c in BK_CustomTb {
        BkIni_Write("Eigene_Chatbefehle", "Befehl" . i, c.cmd)
        BkIni_Write("Eigene_Chatbefehle", "Text" . i, c.text)
    }
}

; ---------------------------------------------------------------------
;  Uebernahme aus Keybinder von Brooklyn 4.x
; ---------------------------------------------------------------------
BkCfg_ImportOld() {
    global
    local cfg, fw, hk, v, n, imported, map, k, w, pack, p, i, j
    cfg := BK_Dir . "\Config"
    if !FileExist(cfg)
        return
    imported := 0
    ; --- Tastenbelegung (Hotkey1..126) ---
    hk := cfg . "\Hotkeybelegung.ini"
    if FileExist(hk) {
        Loop, 126 {
            IniRead, v, %hk%, Hotkeys, Hotkey%A_Index%, %A_Space%
            v := Trim(StrReplace(v, "~"))
            if (v != "" && v != "ERROR") {
                BK_Keys["hk" . A_Index] := v
                imported += 1
            }
        }
    }
    ; --- Optionen (framework.ini) ---
    fw := cfg . "\framework.ini"
    if FileExist(fw) {
        map := {Name: "Name", Drogenbox: "Drogenbox", MemberAD: "MemberAD", OrgmemberAD: "OrgAD", SonstigeAD: "SonstAD"
            , Gangwarzeichen: "GWZ", Gangzonezeichen: "GZZ", Teamspeak: "PathTS", Fraps: "PathRec"
            , Moviefolder: "RecFolder", Fragsende: "FragFolder", Beschwerdenende: "ComplaintFolder", Hotkey: "RecKey"
            , Standort: "GWLoc", ZoneStandort: "GZLoc", WarLese: "AutoGW", ZoneLese: "AutoGZ"
            , AutoGangwarKill: "AutoWantedKill", AutoTot: "AutoTot", arrestsage: "Arrestsage", drogensage: "Drogensage"
            , TimerFrage: "TimerFrage", Antispam: "Antispam", ilovechannel: "RadioChan"}
        for k, n in map {
            IniRead, v, %fw%, Optionen, %k%, % Chr(1)
            if (v != Chr(1) && v != "ERROR" && v != "")
                BkCfg_Set(n, v)
        }
        Loop, 6 {
            IniRead, v, %fw%, Optionen, Spruch%A_Index%, % Chr(1)
            if (v != Chr(1) && v != "ERROR")
                BK_Spruch%A_Index% := v
        }
        Loop, 12 {
            IniRead, v, %fw%, Optionen, Befehl%A_Index%, % Chr(1)
            if (v != Chr(1) && v != "ERROR" && v != "")
                BK_Texts["hk" . (84 + A_Index)] := v
        }
        for i, w in [["DeagleMunition", "deagle"], ["ShotgunMunition", "shotgun"], ["M4Munition", "m4"], ["Mp5Munition", "mp5"]
                   , ["SniperMunition", "sniper"], ["RifleMunition", "rifle"], ["Ak47Munition", "ak47"]] {
            IniRead, v, %fw%, Optionen, % w[1], % Chr(1)
            if (v != Chr(1) && v + 0 > 0)
                BkCfg_Set("Mun_" . w[2], v + 0)
        }
        ; Waffenpakete: Waffe1..10 mit Munition
        p := [[1, 2, 3], [4, 5, 6], [7, 8, 9, 10]]
        for i, pack in p {
            v := ""
            for j, n in pack {
                IniRead, w, %fw%, Optionen, Waffe%n%, % Chr(1)
                IniRead, k, %fw%, Optionen, % "Waffe" . n . "Munition" . (Mod(n - 1, 3) + 1), % Chr(1)
                if (n = 10)
                    IniRead, k, %fw%, Optionen, Waffe10Munition3, % Chr(1)
                if (w != Chr(1) && w != "ERROR" && Trim(w) != "") {
                    StringLower, w, w
                    v .= (v = "" ? "" : "|") . Trim(w) . ":" . ((k + 0 > 0) ? k + 0 : 1)
                }
            }
            if (v != "")
                BK_Pack%i% := v
        }
        IniRead, v, %fw%, Optionen, Gang, % Chr(1)
        if (v != Chr(1) && v != "ERROR" && Trim(v) != "") {
            BK_ProfType := "gang"
            BK_ProfFaction := Trim(v)
        }
        imported += 1
    }
    ; --- Statistik ---
    BkStats_ImportOld(cfg)
    ; --- Gegnerlisten liegen schon im richtigen Ordner (gleiches Format) ---
    if (imported)
        g_ImportNote := "Einstellungen und Tastenbelegung aus Version 4.x wurden übernommen."
}
