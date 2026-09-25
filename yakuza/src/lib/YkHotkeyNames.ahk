; ---------------------------------------------------------------------
;  Hotkey-Namen, Normalisierung und Doppelbelegungen
; ---------------------------------------------------------------------
; Hotkey in Umschalttasten und die eigentliche Taste zerlegen.
; Es bleibt immer mindestens ein Zeichen als Taste uebrig - "#" ist also
; die Raute-Taste und nicht "Windows-Taste ohne Taste".
YkHk_Split(hk, ByRef mods, ByRef key) {
    mods := "", key := hk
    while (StrLen(key) > 1) {
        c := SubStr(key, 1, 1)
        if (c = "^" || c = "!" || c = "+" || c = "#" || c = "*" || c = "~" || c = "$")
            mods .= c
        else
            break
        key := SubStr(key, 2)
    }
}

; Tasten, die AutoHotkey als Umschalttaste liest, in eine eindeutige Form
; bringen.
;
; Das Hotkey-Feld im Fenster liefert fuer die deutschen Tasten # und + genau
; diese Zeichen zurueck. AutoHotkey versteht "#" aber als Windows-Taste und
; "+" als Shift - eine Angabe, die NUR aus solchen Zeichen besteht, ist
; deshalb kein gueltiger Hotkey und wurde bisher stillschweigend verworfen.
; Genau daran lagen tote Keybinds (z.B. "Backup rufen" auf der #-Taste).
; Loesung: die Taste wird ueber ihren Tastencode angegeben ("sc02B").
YkHk_Normalize(hk) {
    hk := Trim(hk)
    if (hk = "")
        return ""
    YkHk_Split(hk, mods, key)
    if (StrLen(key) = 1 && InStr("^!+#*~$<>", key)) {
        sc := GetKeySC(key)
        if (sc)
            key := "sc" . Format("{:03X}", sc)
        else {
            vk := GetKeyVK(key)
            if (vk)
                key := "vk" . Format("{:02X}", vk)
        }
    }
    return mods . key
}

YkHotkeyName(hk) {
    static names := {Space: "Leertaste", Enter: "Enter", Escape: "Esc", Delete: "Entf"
        , Insert: "Einfg", Home: "Pos1", End: "Ende", PgUp: "Bild auf", PgDn: "Bild ab"
        , Up: "Pfeil hoch", Down: "Pfeil runter", Left: "Pfeil links", Right: "Pfeil rechts"
        , XButton1: "Maus 4", XButton2: "Maus 5", MButton: "Mausrad", Backspace: "Ruecktaste"
        , Tab: "Tab", CapsLock: "Feststell", AppsKey: "Menue"}
    static np := {Add: "+", Sub: "-", Mult: "*", Div: "/", Dot: ",", Enter: "Enter"}
    if (hk = "")
        return ""
    YkHk_Split(hk, ms, k)
    mods := ""
    Loop, Parse, ms
    {
        if (A_LoopField = "^")
            mods .= "Strg+"
        else if (A_LoopField = "!")
            mods .= "Alt+"
        else if (A_LoopField = "+")
            mods .= "Shift+"
        else if (A_LoopField = "#")
            mods .= "Win+"
    }
    ; ueber den Tastencode angegebene Tasten wieder lesbar machen
    if RegExMatch(k, "i)^(sc[0-9A-F]{1,3}|vk[0-9A-F]{1,2})$") {
        n := ""
        try n := GetKeyName(k)
        if (n != "")
            k := n
    }
    if (names.HasKey(k))
        k := names[k]
    else if RegExMatch(k, "i)^Numpad(.+)$", m)
        k := "Num " . (np.HasKey(m1) ? np[m1] : m1)
    else if (StrLen(k) = 1)
        StringUpper, k, k
    return mods . k
}

YkHk_Begin() {
    global g_HkSeen, g_HkConflicts
    g_HkSeen := {}
    g_HkConflicts := ""
}

; Hotkey im aktuell gesetzten Kontext anlegen. Ist die Taste schon
; vergeben, gewinnt die erste Belegung und der Konflikt wird gemerkt.
YkHk_Register(key, fn, label) {
    global YK_ActiveHotkeys, g_HkSeen, g_HkConflicts, YK_ChatKey
    if (key = "")
        return
    if (key = YK_ChatKey) {
        g_HkConflicts .= "`n" . YkHotkeyName(key) . " ist die Chat-Taste (" . label . ")"
        return
    }
    if (g_HkSeen.HasKey(key)) {
        g_HkConflicts .= "`n" . YkHotkeyName(key) . ": " . g_HkSeen[key] . "  und  " . label
        return
    }
    try {
        Hotkey, % key, % fn, On
        YK_ActiveHotkeys.Push(key)
        g_HkSeen[key] := label
    } catch {
        g_HkConflicts .= "`n" . key . ": ungueltiger Hotkey (" . label . ")"
    }
}

; Hinweis nur, wenn sich die Doppelbelegungen geaendert haben - Einstellungen
; wirken sofort beim Tippen, sonst kaeme dieselbe Meldung immer wieder
YkHk_Report() {
    global g_HkConflicts
    static last := ""
    if (g_HkConflicts != "" && !(g_HkConflicts == last))
        YkNotify("Hotkey doppelt belegt - bitte aendern:" . g_HkConflicts)
    last := g_HkConflicts
}

; Wer bekommt welche Taste? Gleiche Reihenfolge wie beim Anmelden der
; Hotkeys - die erste Belegung gewinnt. Liefert {Taste: id}
YkHk_Owners() {
    global YK_LocHotkey, YK_KillHotkey, YK_FamHotkey, YK_SprintToggleHk, YK_OvHotkey, YK_MemHotkey
    global YK_Binds, YK_CmdBinds, YK_CombatEnabled, YK_KillEnabled, YK_ChatKey, YK_FnKeys, YK_TbKeys
    list := [["SYS:loc", YK_LocHotkey]
           , ["SYS:kill", (YK_CombatEnabled && YK_KillEnabled) ? YK_KillHotkey : ""]
           , ["SYS:fam", YK_FamHotkey], ["SYS:sprint", YK_SprintToggleHk]
           , ["SYS:ov", YK_OvHotkey], ["SYS:mem", YK_MemHotkey]]
    for i, b in YK_Binds
        list.Push(["B:" . i, b.key])
    for ck, sb in YK_CmdBinds
        list.Push(["S:" . ck, sb.hk])
    for i, f in YkFnKeys()
        if (f.id != "pause")
            list.Push(["F:" . f.id, YK_FnKeys[f.id]])
    for cmd, k in YK_TbKeys
        list.Push(["T:" . cmd, k])
    list.Push(["F:pause", YK_FnKeys["pause"]])
    own := {}
    for i, e in list {
        k := e[2]
        if (k = "" || k = YK_ChatKey || own.HasKey(k))
            continue
        own[k] := e[1]
    }
    return own
}

YkHk_OwnerLabel(id) {
    global YK_Binds
    static sys := {"SYS:loc": "Standort senden", "SYS:kill": "Kill melden", "SYS:fam": "/familymap"
        , "SYS:sprint": "Sprint an/aus", "SYS:ov": "Overlay an/aus", "SYS:mem": "Member-Positionen"}
    if (sys.HasKey(id))
        return sys[id]
    if (SubStr(id, 1, 2) = "F:") {
        for i, f in YkFnKeys()
            if (f.id = SubStr(id, 3))
                return f.label
    }
    if (SubStr(id, 1, 2) = "T:")
        return "Chat-Befehl  " . SubStr(id, 3)
    if (SubStr(id, 1, 2) = "B:") {
        b := YK_Binds[SubStr(id, 3) + 0]
        return "Keybind  " . (IsObject(b) ? b.cmd : "")
    }
    return "Server-Befehl  " . SubStr(id, 3)
}

YkShorten(s, n) {
    return (StrLen(s) > n) ? SubStr(s, 1, n - 1) . "…" : s
}
