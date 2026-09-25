; =====================================================================
;  Yakuza Keybinder - Gegnerlisten (neu in v3.0, aus Brooklyn 5.0)
; ---------------------------------------------------------------------
;  Eine Textdatei pro Liste im Ordner "Gegnerlisten" neben dem Programm,
;  jede Zeile "Name=Spielername". Im Chat (Kuerzel der Liste, z.B. vla):
;     /vlaadd 12   (oder Name)  -> hinzufuegen
;     /vladel 12                -> entfernen
;     /vla                      -> wer davon ist online (ID, Level, Ping)
;     /gangallcheck             -> alle Listen zusammen
;  Online-Status, ID, Level und Ping liest der Binder direkt aus der
;  Spielerliste von SA-MP (nur lesend) - der Server bekommt nichts davon
;  mit, es wird kein Befehl geschickt.
; =====================================================================

global YK_Enemies := []      ; [{key, title, file}]

YkEnemy_Defaults() {
    return [["gegner", "Gegner", "Gegner"]]
}

YkEnemy_Dir() {
    return A_ScriptDir . "\Gegnerlisten"
}

YkEnemy_Init() {
    global YK_Enemies, YK_IniPath
    YK_Enemies := []
    IniRead, n, %YK_IniPath%, Gegnerlisten, Anzahl, %A_Space%
    n := Trim(n)
    if (n = "") {
        for i, d in YkEnemy_Defaults()
            YK_Enemies.Push({key: d[1], title: d[2], file: d[3]})
        YkEnemy_Save()
    } else {
        Loop, % n {
            IniRead, v, %YK_IniPath%, Gegnerlisten, % "Liste" . A_Index, %A_Space%
            p := StrSplit(v, "|")
            if (Trim(p[1]) != "")
                YK_Enemies.Push({key: Trim(p[1]), title: Trim(p[2]), file: Trim(p[3])})
        }
    }
}

YkEnemy_Save() {
    global YK_Enemies, YK_IniPath
    IniDelete, %YK_IniPath%, Gegnerlisten
    IniWrite, % YkCnt(YK_Enemies), %YK_IniPath%, Gegnerlisten, Anzahl
    for i, e in YK_Enemies
        IniWrite, % e.key . "|" . e.title . "|" . e.file, %YK_IniPath%, Gegnerlisten, % "Liste" . i
}

; Neue Liste anlegen. Kuerzel = das, was man im Chat tippt (/kuerzel).
YkEnemy_NewList(key, title, ByRef err) {
    global YK_Enemies
    err := ""
    key := Trim(key)
    StringLower, key, key
    key := RegExReplace(key, "^/")
    title := Trim(title)
    if !RegExMatch(key, "^[a-z0-9]{2,12}$") {
        err := "Kürzel: 2 bis 12 Buchstaben oder Ziffern, z.B. vla"
        return false
    }
    if (RegExMatch(key, "(add|del)$")) {
        err := "Das Kürzel darf nicht auf add oder del enden."
        return false
    }
    if (IsObject(YkEnemy_Get(key)) || IsObject(YkTb_Find("/" . key)) || YkCmd_Taken("/" . key)) {
        err := "/" . key . " ist schon vergeben."
        return false
    }
    if (title = "")
        title := key
    file := RegExReplace(title, "[\\/:*?""<>|]", "_")
    YK_Enemies.Push({key: key, title: title, file: file})
    YkEnemy_Save()
    return true
}

YkEnemy_DeleteList(key) {
    global YK_Enemies
    for i, e in YK_Enemies {
        if (e.key = key) {
            YK_Enemies.RemoveAt(i)
            YkEnemy_Save()
            return true
        }
    }
    return false
}

; Belegt ein Server-Befehl oder eine Kurzform schon dieses Wort?
YkCmd_Taken(cmd) {
    global YK_CmdBinds
    for ck, b in YK_CmdBinds {
        kz := Trim(b.kurz)
        if (kz != "" && ("/" . RegExReplace(kz, "^/")) = cmd)
            return true
    }
    return false
}

YkEnemy_FindList(word) {
    global YK_Enemies
    for i, e in YK_Enemies
        if (e.key = word)
            return e.key
    return ""
}

YkEnemy_Get(key) {
    global YK_Enemies
    for i, e in YK_Enemies
        if (e.key = key)
            return e
    return ""
}

YkEnemy_Path(e) {
    return YkEnemy_Dir() . "\" . e.file . ".txt"
}

; Namen einer Liste
YkEnemy_Names(key) {
    e := YkEnemy_Get(key)
    out := []
    if (!IsObject(e))
        return out
    p := YkEnemy_Path(e)
    if !FileExist(p)
        return out
    FileRead, body, %p%
    seen := {}
    Loop, Parse, body, `n, `r
    {
        l := Trim(A_LoopField)
        if (l = "")
            continue
        if RegExMatch(l, "i)^name\s*=\s*(.+)$", m)
            l := Trim(m1)
        if (l != "" && !seen.HasKey(l)) {
            seen[l] := 1
            out.Push(l)
        }
    }
    return out
}

YkEnemy_Write(key, names) {
    e := YkEnemy_Get(key)
    if (!IsObject(e))
        return
    dir := YkEnemy_Dir()
    if !FileExist(dir)
        FileCreateDir, %dir%
    p := YkEnemy_Path(e)
    body := ""
    for i, n in names
        body .= "Name=" . n . "`r`n"
    FileDelete, %p%
    FileAppend, %body%, %p%, UTF-8
}

YkEnemy_Add(key, name) {
    names := YkEnemy_Names(key)
    for i, n in names
        if (n = name)
            return false
    names.Push(name)
    YkEnemy_Write(key, names)
    return true
}

YkEnemy_Remove(key, name) {
    names := YkEnemy_Names(key)
    out := [], found := false
    for i, n in names {
        if (n = name) {
            found := true
            continue
        }
        out.Push(n)
    }
    if (found)
        YkEnemy_Write(key, out)
    return found
}

; ID oder Name aus dem Chat -> Spielername
YkEnemy_ResolveName(input, ByRef err) {
    err := ""
    input := Trim(input)
    if input is integer
    {
        n := YkSamp_NameById(input + 0)
        if (n = "") {
            err := "Spieler " . input . " ist nicht online (oder die Spielerliste ist nicht lesbar)."
            return ""
        }
        return n
    }
    if !YkSamp_NickOk(input) {
        err := "Bitte eine gültige ID oder einen Namen eingeben!"
        return ""
    }
    return input
}

YkEnemy_AddInput(key, input) {
    e := YkEnemy_Get(key)
    name := YkEnemy_ResolveName(input, err)
    if (name = "")
        return YkMsg(err, "warn")
    if (name = YkMyName())
        return YkMsg("Du kannst dich nicht selbst hinzufügen!", "warn")
    if (YkEnemy_Add(key, name))
        YkMsg(name . " steht jetzt in " . e.title . ".", "ok")
    else
        YkMsg(name . " steht schon in " . e.title . ".", "warn")
    YkGui_EnemyRefresh()
}

YkEnemy_DelInput(key, input) {
    e := YkEnemy_Get(key)
    name := YkEnemy_ResolveName(input, err)
    if (name = "")
        return YkMsg(err, "warn")
    if (YkEnemy_Remove(key, name))
        YkMsg(name . " wurde aus " . e.title . " entfernt.", "ok")
    else
        YkMsg(name . " steht nicht in " . e.title . ".", "warn")
    YkGui_EnemyRefresh()
}

; Wer ist online? key = Liste oder "*" fuer alle Listen
YkEnemy_Online(key) {
    global YK_Enemies
    tbl := YkSamp_PlayerTable()
    if (!IsObject(tbl))
        return ""
    byName := {}
    for i, p in tbl
        byName[p.name] := p
    out := []
    seen := {}
    keys := []
    if (key = "*") {
        for i, e in YK_Enemies
            keys.Push(e.key)
    } else {
        keys.Push(key)
    }
    for i, k in keys {
        for j, n in YkEnemy_Names(k) {
            if (seen.HasKey(n))
                continue
            seen[n] := 1
            if (byName.HasKey(n)) {
                p := byName[n]
                out.Push({name: n, id: p.id, score: p.score, ping: p.ping, list: YkEnemy_Get(k).title})
            }
        }
    }
    return out
}

YkEnemy_ShowOnline(key) {
    title := (key = "*") ? "Alle Gegner" : YkEnemy_Get(key).title
    on := YkEnemy_Online(key)
    if (!IsObject(on)) {
        YkMsg("Die Spielerliste von SA-MP ist gerade nicht lesbar (Spiel aktiv? Einstellungen > Spielspeicher lesen).", "warn")
        return
    }
    if (!on.MaxIndex()) {
        YkMsg(title . ": niemand online.")
        return
    }
    txt := title . ": " . on.MaxIndex() . " online"
    for i, p in on {
        if (i > 12) {
            txt .= "`n... und " . (on.MaxIndex() - 12) . " weitere"
            break
        }
        txt .= "`n" . p.name . "   ID " . p.id . "   Level " . p.score . "   Ping " . p.ping
    }
    YkMsg(txt, "list", 9000)
}
