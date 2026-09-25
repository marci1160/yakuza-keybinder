; =====================================================================
;  Brooklyn Keybinder - Gegnerlisten
; ---------------------------------------------------------------------
;  Wie in v4.60: eine Textdatei pro Liste in "Gegnerlisten\", jede Zeile
;  "Name=Spielername". Im Chat:
;     /ballasadd 12   (oder Name)  -> hinzufuegen
;     /ballasdel 12                -> entfernen
;     /ballas                      -> wer davon ist online (ID, Level, Ping)
;     /gangallcheck                -> alle Listen zusammen
;  Online-Status, ID, Level und Ping liest der Binder direkt aus SA-MP.
; =====================================================================

global BK_Enemies := []      ; [{key, title, file}]

BkEnemy_Defaults() {
    return [["all", "Alle Gegner", "Allegegner"], ["ck", "Cali Kartell", "Cali Kartell"], ["ballas", "Ballas", "Ballas"]
          , ["brigada", "Brigada", "Brigada"], ["fbi", "FBI", "FBI"], ["grove", "Grove Street", "Grove Street"]
          , ["icf", "Irish Crime Family", "Irish Crime Family"], ["vagos", "Los Santos Vagos", "Los Santos Vagos"]
          , ["triaden", "Triaden", "Triaden"], ["atzen", "Aztecas", "Aztecas"], ["wheelmen", "Wheelmen", "Wheelmen"]
          , ["cops", "Cops", "Cops"]]
}

BkEnemy_Init() {
    global BK_Enemies, BK_Ini
    BK_Enemies := []
    n := BkIni_Read("Gegnerlisten", "Anzahl", "")
    if (n = "") {
        for i, d in BkEnemy_Defaults()
            BK_Enemies.Push({key: d[1], title: d[2], file: d[3]})
        BkEnemy_Save()
    } else {
        Loop, % n {
            v := BkIni_Read("Gegnerlisten", "Liste" . A_Index, "")
            p := StrSplit(v, "|")
            if (p[1] != "")
                BK_Enemies.Push({key: p[1], title: p[2], file: p[3]})
        }
    }
}

BkEnemy_Save() {
    global BK_Enemies, BK_Ini
    IniDelete, %BK_Ini%, Gegnerlisten
    BkIni_Write("Gegnerlisten", "Anzahl", BK_Enemies.MaxIndex() ? BK_Enemies.MaxIndex() : 0)
    for i, e in BK_Enemies
        BkIni_Write("Gegnerlisten", "Liste" . i, e.key . "|" . e.title . "|" . e.file)
}

BkEnemy_FindList(word) {
    global BK_Enemies
    for i, e in BK_Enemies
        if (e.key = word)
            return e.key
    return ""
}

BkEnemy_Get(key) {
    global BK_Enemies
    for i, e in BK_Enemies
        if (e.key = key)
            return e
    return ""
}

BkEnemy_Path(e) {
    global BK_Dir
    return BK_Dir . "\Gegnerlisten\" . e.file . ".txt"
}

; Namen einer Liste
BkEnemy_Names(key) {
    e := BkEnemy_Get(key)
    out := []
    if (!IsObject(e))
        return out
    p := BkEnemy_Path(e)
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

BkEnemy_Write(key, names) {
    e := BkEnemy_Get(key)
    if (!IsObject(e))
        return
    p := BkEnemy_Path(e)
    body := ""
    for i, n in names
        body .= "Name=" . n . "`r`n"
    FileDelete, %p%
    FileAppend, %body%, %p%, UTF-8
}

BkEnemy_Add(key, name) {
    names := BkEnemy_Names(key)
    for i, n in names
        if (n = name)
            return false
    names.Push(name)
    BkEnemy_Write(key, names)
    return true
}

BkEnemy_Remove(key, name) {
    names := BkEnemy_Names(key)
    out := [], found := false
    for i, n in names {
        if (n = name) {
            found := true
            continue
        }
        out.Push(n)
    }
    if (found)
        BkEnemy_Write(key, out)
    return found
}

; ID oder Name aus dem Chat -> Spielername
BkEnemy_ResolveName(input, ByRef err) {
    err := ""
    input := Trim(input)
    if input is integer
    {
        n := BkSamp_NameById(input + 0)
        if (n = "") {
            err := "Dieser Spieler ist nicht online (oder die Spielerliste ist nicht lesbar)."
            return ""
        }
        return n
    }
    if !BkSamp_NickOk(input) {
        err := "Bitte eine gültige ID oder einen Namen eingeben!"
        return ""
    }
    return input
}

BkEnemy_AddInput(key, input) {
    e := BkEnemy_Get(key)
    name := BkEnemy_ResolveName(input, err)
    if (name = "")
        return BkMsg(err, "warn")
    if (name = BkMyName())
        return BkMsg("Du kannst dich nicht selbst hinzufügen!", "warn")
    if (BkEnemy_Add(key, name))
        BkMsg(name . " wurde erfolgreich zu " . e.title . " hinzugefügt!", "ok")
    else
        BkMsg(name . " ist bereits in " . e.title . " vorhanden!", "warn")
    BkGui_EnemyRefresh()
}

BkEnemy_DelInput(key, input) {
    e := BkEnemy_Get(key)
    name := BkEnemy_ResolveName(input, err)
    if (name = "")
        return BkMsg(err, "warn")
    if (BkEnemy_Remove(key, name))
        BkMsg(name . " wurde erfolgreich aus " . e.title . " gelöscht!", "ok")
    else
        BkMsg(name . " ist nicht in " . e.title . " vorhanden!", "warn")
    BkGui_EnemyRefresh()
}

; Wer ist online? key = Liste oder "*" fuer alle Listen
BkEnemy_Online(key) {
    global BK_Enemies
    tbl := BkSamp_PlayerTable()
    if (!IsObject(tbl))
        return ""
    byName := {}
    for i, p in tbl
        byName[p.name] := p
    out := []
    seen := {}
    keys := []
    if (key = "*") {
        for i, e in BK_Enemies
            keys.Push(e.key)
    } else {
        keys.Push(key)
    }
    for i, k in keys {
        for j, n in BkEnemy_Names(k) {
            if (seen.HasKey(n))
                continue
            seen[n] := 1
            if (byName.HasKey(n)) {
                p := byName[n]
                out.Push({name: n, id: p.id, score: p.score, ping: p.ping, list: BkEnemy_Get(k).title})
            }
        }
    }
    return out
}

BkEnemy_ShowOnline(key) {
    title := (key = "*") ? "Alle Gegner" : BkEnemy_Get(key).title
    on := BkEnemy_Online(key)
    if (!IsObject(on)) {
        BkMsg("Die Spielerliste von SA-MP ist gerade nicht lesbar (Spiel aktiv? Einstellungen > Spielspeicher lesen).", "warn")
        return
    }
    if (!on.MaxIndex()) {
        BkMsg(title . ": niemand online.")
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
    BkMsg(txt, "list", 9000)
}
