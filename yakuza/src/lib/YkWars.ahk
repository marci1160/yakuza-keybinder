; ---------------------------------------------------------------------
;  Kriege: Gangwar, Family-War und Bizfight
; ---------------------------------------------------------------------
;   [GANG WAR] Yakuza 3 : 0 Varrios Los Aztecas - noch 10 Minuten (Turf 'Gangwar Gebiet 4').
;   [GANG WAR] Yakuza greift Varrios Los Aztecas an - Turf 'Gangwar Gebiet 1'!
;   [GANG WAR] Yakuza hat den Turf 'Gangwar Gebiet 4' erobert!
;   [FAMILY-WAR] Federal Investigation Bureau greift die Zone Unity Station an! (40 Min)
;   [FAMILY-WAR] Yakuza Family kontrolliert jetzt die Zone LS Friedhof! (+$25000 in den Fund)
;   [BIZ FIGHT] +1 Kill fuer Yakuza (Marci). Stand 5 : 0.
;
; Ein angegriffenes Business (/attackbiz) ist WEDER Gangwar NOCH Family-War.
; Frueher gab es nur diese zwei Arten, und alles ohne "Flagge:" in der
; Server-Anzeige wurde automatisch zum Family-War erklaert - ein Bizfight
; stand deshalb immer falsch da. Jetzt gibt es vier Arten:
;   gang | fam | biz | war   ("war" = noch nicht sicher zuzuordnen)
; Die Zuordnung laeuft ueber die Muster unten, die in den Einstellungen
; geaendert werden koennen - passt nichts, steht neutral "War" da statt
; einer falschen Behauptung.
;
; UNSER KRIEG ODER NICHT?  (Feld "own")
; Family-Wars meldet der Server an ALLE, auch wenn Yakuza gar nicht dabei
; ist. Frueher hat der Binder daraus immer einen eigenen Krieg gemacht und
; am Ende "gewonnen" oder "verloren" behauptet, obwohl niemand von uns dort
; war. Jetzt gilt ein Krieg nur dann als unserer, wenn
;   - die eigene Fraktion in der Chatzeile steht, ODER
;   - der eigene Chat-Tag in der Server-Anzeige rechts im Bild auftaucht
;     (genau das passiert, sobald wir eingreifen).
; Bei fremden Kriegen steht im Overlay nur, WER GERADE FUEHRT - man kann ja
; jederzeit eingreifen und die Zone selbst holen. Sieg/Niederlage steht dort
; nie.
global YK_WarGangPat  := "^\[\s*GANG[ _-]?WAR\s*\]"
global YK_WarFamPat   := "^\[\s*FAMILY[ _-]?WAR\s*\]"
global YK_WarBizPat   := "^\[\s*(BIZ[ _-]?FIGHT|BIZ|BUSINESS|BIZWAR)\s*\]"
global YK_WarBizBoard := "biz|business|gesch(ä|ae)ft|laden"
global g_WarKindHint  := ""        ; {kind, t} - zuletzt im Chat gesehene Art
global g_WarNoteCol   := "E8C35A"  ; Farbe der Schlusszeile (gewonnen/verloren/neutral)
; Wie lange bleibt "Gangwar gewonnen: ..." nach dem Ende im Overlay stehen?
; 0 = stehen lassen, bis der naechste Krieg kommt.
global YK_WarNoteSec  := 120
; Gebiete, die Yakuza in dieser Sitzung erobert oder verteidigt hat. Der
; Server nennt beim Angriff auf eine Zone nur den Angreifer ("FIB greift die
; Zone Unity Station an!") - woher soll der Binder sonst wissen, ob uns das
; angeht? Was wir gewonnen haben, merkt er sich hier; wird so ein Gebiet
; angegriffen, ist es unser Krieg (mit Warnton).
global g_OwnZones     := {}

YkWar_KindLabel(kind) {
    if (kind = "gang")
        return "Gangwar"
    if (kind = "fam")
        return "Family-War"
    if (kind = "biz")
        return "Bizfight"
    return "War"
}

; Welche Art meldet diese Chatzeile? "" = keine Kriegsmeldung
YkWar_KindOfLine(l) {
    global YK_WarGangPat, YK_WarFamPat, YK_WarBizPat
    if (YK_WarBizPat != "" && YkMatch(l, YK_WarBizPat))
        return "biz"
    if (YK_WarGangPat != "" && YkMatch(l, YK_WarGangPat))
        return "gang"
    if (YK_WarFamPat != "" && YkMatch(l, YK_WarFamPat))
        return "fam"
    return ""
}

; Der Teil hinter "[...]" - der eigentliche Meldungstext
YkWar_Body(l) {
    return Trim(RegExReplace(l, "^\[[^\]]*\]\s*"))
}

YkWar_HandleLine(line) {
    global YK_Faction, g_Wars, g_WarNote, g_WarNoteT, g_WarNoteCol, g_WarEndT, g_WarKindHint
    if (YK_Faction = "")
        return
    l := RegExReplace(line, "\{[0-9A-Fa-f]{6}\}")
    l := Trim(RegExReplace(l, "^\s*\[\d{1,2}:\d{2}(:\d{2})?\]\s*"))
    if (SubStr(l, 1, 1) != "[")
        return
    kind := YkWar_KindOfLine(l)
    if (kind = "")
        return
    ; Art fuer die Server-Anzeige merken (die nennt sich selbst nicht)
    g_WarKindHint := {kind: kind, t: A_TickCount}
    f := YK_Faction
    b := YkWar_Body(l)
    changed := false

    ; --- Stand mit Restzeit:  A 3 : 0 B - noch 10 Minuten (Turf '...')
    if RegExMatch(b, "i)^(.+?)\s+(\d+)\s*:\s*(\d+)\s+(.+?)\s+-\s+noch\s+(\d+)\s+Minuten?(?:\s*[\(\[]\s*(?:Turf|Zone|Business|Biz)?\s*'?([^'\)\]]+)'?\s*[\)\]])?", m) {
        area := Trim(m6)
        if (area = "")
            area := YkWar_KindLabel(kind)
        if InStr(m1, f)
            YkWar_Set(area, {us: m2 + 0, them: m3 + 0, enemy: Trim(m4), mins: m5 + 0, t: A_TickCount, kind: kind, own: true})
        else if InStr(m4, f)
            YkWar_Set(area, {us: m3 + 0, them: m2 + 0, enemy: Trim(m1), mins: m5 + 0, t: A_TickCount, kind: kind, own: true})
        else {
            ; fremder Krieg (z.B. Family-War zweier anderer Fraktionen):
            ; merken, wer fuehrt - eingreifen kann man immer noch
            YkWar_SetFree(area, Trim(m1), m2 + 0, Trim(m4), m3 + 0, m5 + 0, kind)
        }
        changed := true
    }
    ; --- Zwischenstand aus einer Kill-Meldung:  ... Stand 5 : 0.
    else if RegExMatch(b, "i)\bStand\s+(\d+)\s*:\s*(\d+)", m) {
        w := YkWar_Newest(kind, true)
        if (w = "")
            return
        e := g_Wars[w]
        ; "+1 Kill fuer <Fraktion>" sagt, wessen Punkt es war
        if RegExMatch(b, "i)f(?:ue|ü)r\s+([^\(\.]+)", n) && !InStr(n1, f) {
            e.us := m2 + 0, e.them := m1 + 0
        } else {
            e.us := m1 + 0, e.them := m2 + 0
        }
        e.t := A_TickCount
        changed := true
    }
    ; --- Angriff:  A greift B an - Turf '...'  /  A greift die Zone X an! (40 Min)
    else if RegExMatch(b, "i)^(.+?)\s+greift\s+(?:die\s+Zone\s+|das\s+Business\s+|den\s+Turf\s+)?(.+?)\s+an\b[^\r\n]*", m) {
        atk := Trim(m1), rest := Trim(m2)
        ; Gebietsname: aus 'xyz' hinter dem Satz oder aus dem Rest
        area := ""
        if RegExMatch(b, "i)(?:Turf|Zone|Business|Biz)\s+'([^']+)'", a)
            area := Trim(a1)
        else if RegExMatch(b, "i)^.+?\s+greift\s+(?:die\s+Zone|das\s+Business|den\s+Turf)\s+(.+?)\s+an\b", a)
            area := Trim(a1)
        mins := RegExMatch(b, "i)\((\d+)\s*Min", a) ? a1 + 0 : ((kind = "gang") ? 30 : 40)
        own := true
        if InStr(atk, f) {
            ; beim Family-War steht hinter "greift" die ZONE, nicht der
            ; Gegner - dann waere "gegen LS Friedhof" Unsinn
            enemy := (rest != "" && rest != area && !InStr(rest, f)) ? rest : "unser Angriff"
        } else if (InStr(rest, f) || InStr(b, f)) {
            enemy := atk
            YkSound_Play("war")
        } else if (kind = "gang") {
            ; Beim Gangwar nennt der Server immer beide Fraktionen. Steht
            ; die eigene nicht dabei, geht uns dieser Krieg nichts an.
            return
        } else if (YkWar_IsOurArea(area) || YkWar_IsOurArea(rest)) {
            ; unser Gebiet (in dieser Sitzung selbst erobert) wird angegriffen
            enemy := atk
            YkSound_Play("war")
        } else {
            ; Family-War und Bizfight gehen an alle - auch an Fraktionen,
            ; die gar nichts damit zu tun haben ("Federal Investigation
            ; Bureau greift die Zone Unity Station an!"). Frueher hat der
            ; Binder daraus IMMER einen eigenen Krieg gemacht und am Ende
            ; Sieg oder Niederlage behauptet. Jetzt bleibt so eine Zeile
            ; neutral: sie zeigt nur, dass dort gekaempft wird. Sobald wir
            ; eingreifen, taucht unser Tag in der Server-Anzeige auf - dann
            ; wird daraus von selbst unser Krieg (YkWarTd_Apply).
            own := false
            enemy := atk
        }
        if (area = "")
            area := (rest != "" ? rest : YkWar_KindLabel(kind))
        ; Einmal unser Krieg, immer unser Krieg: eine zweite Meldung zur
        ; selben Zone darf ihn nicht neutral machen.
        prev := g_Wars[area]
        if (IsObject(prev) && prev.own)
            own := true
        ; Den namenlosen Eintrag (nur aus der Server-Anzeige) nur dann
        ; wegraeumen, wenn er zu diesem Krieg gehoeren kann - sonst wuerde
        ; ein fremder Angriff unseren laufenden Krieg aus dem Overlay werfen.
        ph := YkWar_KindLabel(kind)
        if (g_Wars.HasKey(ph) && (own || !g_Wars[ph].own))
            g_Wars.Delete(ph)
        if (own)
            g_WarEndT.Delete(kind)
        g_Wars[area] := {us: (own ? 0 : ""), them: (own ? 0 : ""), enemy: enemy
            , mins: mins, t: A_TickCount, kind: kind, own: own
            , lead: "", leadP: "", rival: "", rivalP: ""}
        changed := true
    }
    ; --- Ende:  A hat den Turf '...' erobert / kontrolliert jetzt die Zone X
    else if RegExMatch(b, "i)^(.+?)\s+(?:hat\s+(?:den|das|die)\s+(?:Turf|Zone|Business)\s+'?([^'!\.]+)'?\s+(?:erfolgreich\s+)?(?:erobert|verteidigt|gehalten|(?:ue|ü)bernommen)"
        . "|kontrolliert\s+jetzt\s+(?:die\s+Zone|das\s+Business|den\s+Turf)\s+'?([^'!\.\(]+)'?)", m) {
        area := Trim(m2 != "" ? m2 : m3)
        winner := Trim(m1)
        ; Welchen Eintrag betrifft die Meldung? (Name, "Zone <Name>" oder
        ; der namenlose Eintrag, der nur aus der Server-Anzeige stammt)
        key := ""
        for i, k in [area, "Zone " . area, YkWar_KindLabel(kind)] {
            if (!g_Wars.HasKey(k))
                continue
            ; Der namenlose Eintrag (nur aus der Server-Anzeige) passt nur
            ; dann zu dieser Meldung, wenn der Gewinner auch wirklich einer
            ; der beiden Beteiligten ist - sonst wuerde ein fremder
            ; Family-War unseren laufenden Krieg fuer beendet erklaeren.
            o := g_Wars[k]
            if (k = YkWar_KindLabel(kind) && o.own
                && !InStr(winner, f) && !(o.enemy != "" && InStr(winner, o.enemy)))
                continue
            key := k
            break
        }
        e := (key != "") ? g_Wars[key] : ""
        weWon := InStr(winner, f) ? true : false
        ; Unser Krieg war es nur, wenn unsere Fraktion mitgekaempft hat -
        ; sonst gibt es weder "gewonnen" noch "verloren", egal wer gewinnt.
        mine := weWon || (IsObject(e) && e.own) || YkWar_IsOurArea(area)
        if (key = "" && !mine)
            return                               ; nie verfolgt und geht uns nichts an
        if (key != "")
            g_Wars.Delete(key)
        g_Wars.Delete(area)
        g_Wars.Delete("Zone " . area)
        ; Die kurz stehenbleibende Server-Anzeige nur dann sperren, wenn es
        ; auch der Krieg war, der dort stand - sonst wuerde ein fremdes Ende
        ; unsere eigene Anzeige 20 Sekunden lang ausblenden.
        if (key != "")
            g_WarEndT[kind] := A_TickCount
        ; Wem gehoert das Gebiet ab jetzt? (fuer den naechsten Angriff)
        YkWar_SetOwner(area, weWon)
        if (mine) {
            g_WarNote := YkWar_KindLabel(kind) . " " . (weWon ? "gewonnen: " : "verloren: ") . area
            g_WarNoteCol := weWon ? "5FD35F" : "FF6060"
        } else {
            ; fremder Krieg: nur die nuechterne Tatsache
            g_WarNote := YkWar_KindLabel(kind) . " beendet:  " . area . "  →  " . YkShorten(winner, 24)
            g_WarNoteCol := "9BB0C8"
        }
        g_WarNoteT := A_TickCount
        YkWarNote_Arm()
        changed := true
    }
    if (changed)
        YkOverlay_Refresh()
}

; Gehoert dieses Gebiet uns? (nur was in dieser Sitzung selbst gewonnen
; wurde - der Binder fragt den Server nichts ab)
YkWar_IsOurArea(area) {
    global g_OwnZones
    area := Trim(area, " '!.")
    if (area = "")
        return false
    return g_OwnZones.HasKey(area)
}

; Gebiet uns zuschreiben oder wieder abschreiben
YkWar_SetOwner(area, ours) {
    global g_OwnZones
    area := Trim(area, " '!.")
    if (area = "")
        return
    if (ours)
        g_OwnZones[area] := A_TickCount
    else
        g_OwnZones.Delete(area)
}

; Schluessel des juengsten laufenden Kriegs dieser Art ("" = keiner).
; ownOnly = true: nur Kriege, an denen die eigene Fraktion beteiligt ist.
YkWar_Newest(kind, ownOnly := false) {
    global g_Wars
    key := "", best := 0
    for k, e in g_Wars {
        if (e.kind != kind)
            continue
        if (ownOnly && !e.own)
            continue
        if (key = "" || e.t > best)
            key := k, best := e.t
    }
    return key
}

; Stand aus einer Chatzeile uebernehmen. Ein Eintrag, der bisher nur aus
; der Server-Anzeige kam ("Gangwar"/"Bizfight"), bekommt jetzt den Namen.
YkWar_Set(turf, o) {
    global g_Wars
    if (IsObject(g_Wars[turf])) {
        e := g_Wars[turf]
        for k, v in o {
            ; einmal als unser Krieg erkannt, bleibt er unserer
            if (k = "own" && e.own && !v)
                continue
            e[k] := v
        }
        return
    }
    ph := g_Wars[YkWar_KindLabel(o.kind)]
    if (IsObject(ph) && ph.kind = o.kind) {
        o.tdT := ph.tdT, o.secs := ph.secs, o.flag := ph.flag
        if (ph.own)
            o.own := true
        g_Wars.Delete(YkWar_KindLabel(o.kind))
    }
    g_Wars[turf] := o
}

; Fremder Krieg (ohne uns): nur festhalten, wer dort gerade fuehrt.
; Greifen wir spaeter ein, taucht unser Tag in der Server-Anzeige auf und
; YkWarTd_Apply macht daraus unseren Krieg.
YkWar_SetFree(turf, a, ap, bb, bp, mins, kind) {
    global g_Wars
    if (turf = "")
        turf := YkWar_KindLabel(kind)
    lead := (ap >= bp) ? a : bb
    leadP := (ap >= bp) ? ap : bp
    rival := (ap >= bp) ? bb : a
    rivalP := (ap >= bp) ? bp : ap
    o := g_Wars[turf]
    if (IsObject(o) && o.own)
        return                                  ; unser Krieg - nicht neutralisieren
    if (!IsObject(o)) {
        o := {us: "", them: "", enemy: lead, kind: kind, own: false, td: false}
        g_Wars[turf] := o
    }
    o.lead := lead, o.leadP := leadP
    o.rival := rival, o.rivalP := rivalP
    o.enemy := lead
    o.mins := mins
    o.t := A_TickCount
    o.kind := kind
    o.own := false
}

; laufende Kriege als Zeilen {text, color}; abgelaufene werden entfernt
YkWar_List() {
    global g_Wars, g_WarNote, g_WarNoteT, g_WarNoteCol
    out := []
    seen := {}
    now := A_TickCount
    ; Erst die Kriege MIT Namen, dann die namenlosen (die nur aus der
    ; Server-Anzeige stammen). So gewinnt bei einer Dopplung die Zeile,
    ; die mehr verraet.
    rows := [], rest := []
    for turf, w in g_Wars.Clone() {
        if (turf = YkWar_KindLabel(w.kind))
            rest.Push({turf: turf, w: w})
        else
            rows.Push({turf: turf, w: w})
    }
    for i, r in rest
        rows.Push(r)
    for ri, r in rows {
        turf := r.turf, w := r.w
        live := (w.tdT && (now - w.tdT) < 5000)
        left := w.mins - (now - w.t) // 60000
        if (left < -3 && !live) {
            g_Wars.Delete(turf)
            continue
        }
        left := (left < 0) ? 0 : left
        if (live && w.secs != "") {
            s := w.secs - (now - w.tdT) // 1000
            s := (s < 0) ? 0 : s
            tt := "noch " . (s // 60) . ":" . Format("{:02d}", Mod(s, 60))
        } else {
            tt := w.td ? "" : "noch " . left . " Min"
        }
        ; Art immer davorschreiben - dann ist sofort klar, worum es geht
        head := YkWar_KindLabel(w.kind) . "  ·  "
        name := (turf = YkWar_KindLabel(w.kind)) ? "" : YkShorten(turf, 28) . "   "
        fl := (live && w.flag != "") ? "   Flagge: " . w.flag : ""
        if (w.own && w.us != "") {
            col := (w.us > w.them) ? "5FD35F" : (w.us < w.them) ? "FF6060" : "FFFFFF"
            line := head . name . w.us . " : " . w.them . "   gegen " . YkShorten(w.enemy, 20) . "    " . tt . fl
        } else if (!w.own && w.lead != "") {
            ; fremder Krieg: nur wer fuehrt - eingreifen kann man immer noch
            line := head . name . "führt: " . YkShorten(w.lead, 16) . " " . w.leadP
                . ((w.rival != "") ? " : " . w.rivalP . " " . YkShorten(w.rival, 16) : "")
                . "    " . tt . fl
            col := "9BB0C8"
        } else if (!w.own) {
            line := head . name . "Angriff: " . YkShorten(w.enemy, 22) . "   " . tt
            col := "9BB0C8"
        } else {
            line := head . name . "gegen " . YkShorten(w.enemy, 22) . "   " . tt
            col := "E8C35A"
        }
        ; Sicherheitsnetz gegen doppelte Zeilen: manche Server zeichnen
        ; dieselbe Tafel mehrfach ins Bild (Schatten, Kopie je Spieler).
        ; Dabei konnte derselbe Krieg zweimal im Overlay landen.
        sig := w.kind . "|" . (w.own ? "1" : "0") . "|" . w.us . "|" . w.them
            . "|" . w.lead . "|" . w.leadP . "|" . w.enemy
        if (seen.HasKey(sig))
            continue
        seen[sig] := 1
        out.Push({text: line, color: col})
    }
    if (g_WarNote != "" && YkWarNote_Visible(now))
        out.Push({text: g_WarNote, color: (g_WarNoteCol != "" ? g_WarNoteCol : "E8C35A")})
    return out
}

; Steht die Schlusszeile ("Gangwar gewonnen: ...") noch?
; YK_WarNoteSec = 0 heisst: stehen lassen, bis der naechste Krieg kommt.
YkWarNote_Visible(now := 0) {
    global g_WarNoteT, YK_WarNoteSec
    if (!now)
        now := A_TickCount
    if (YK_WarNoteSec <= 0)
        return true
    return ((now - g_WarNoteT) < YK_WarNoteSec * 1000)
}

; Einmal-Timer stellen, damit die Zeile auf die Sekunde genau verschwindet
; und nicht erst beim naechsten Durchgang des Overlays (bis zu 2 s spaeter).
; Das Overlay wird dabei nur neu beschriftet - der Rest bleibt stehen.
YkWarNote_Arm() {
    global YK_WarNoteSec
    fn := Func("YkWarNote_Expire")
    SetTimer, % fn, Off
    if (YK_WarNoteSec <= 0)
        return
    ms := YK_WarNoteSec * 1000 + 250
    SetTimer, % fn, % -ms
}

YkWarNote_Expire() {
    global g_WarNote
    if (g_WarNote = "")
        return
    if (YkWarNote_Visible())          ; inzwischen neu gesetzt
        return
    g_WarNote := ""
    YkOverlay_Refresh()
}

; ---------------------------------------------------------------------
;  Live-Stand aus der Server-Anzeige rechts im Bild (Textdraw)
; ---------------------------------------------------------------------
;   ~y~[~r~YAK 24P ~y~- ~b~GuiZa 0P~y~]~n~~y~[~w~Zeit: ~g~8:41~y~]      Family-War
;   TMF 15P - YAK 0P   Zeit: 04:33   Flagge: Frei                      Gangwar
; Liefert {own, us, them, enemy, lead, leadP, rival, rivalP, secs, flag, kind}
; - oder "", wenn es keine War-Anzeige ist.
;
; Steht der eigene Chat-Tag (ohne Klammern) NICHT in der Anzeige, wird sie
; nicht mehr verworfen: dann liefert sie, WER GERADE FUEHRT. Genau danach
; entscheidet man, ob sich das Eingreifen lohnt.
YkWarTd_Parse(text, tag) {
    global YK_WarBizBoard
    t := RegExReplace(RegExReplace(text, "i)~n~", "`n"), "~[A-Za-z]~")
    ; So streng wie bisher: es muss wirklich "A 12P - B 3P" dastehen. Sonst
    ; wuerde jede beliebige Zahlen-Anzeige des Servers zum Krieg erklaert.
    if !RegExMatch(t, "i)([^\s\[\]]+)\s+(\d{1,4})\s*P\s*-\s*([^\s\[\]]+)\s+(\d{1,4})\s*P(?![A-Za-z])", m)
        return ""
    parts := YkWarTd_Parts(t)
    if (parts.MaxIndex() < 2)
        parts := [{name: m1, pts: m2 + 0}, {name: m3, pts: m4 + 0}]
    ; nach Punkten sortieren (absteigend) - der erste fuehrt
    ord := []
    for i, p in parts
        ord.Push(p)
    Loop, % ord.MaxIndex() {
        j := A_Index
        while (j > 1 && ord[j].pts > ord[j - 1].pts) {
            tmp := ord[j], ord[j] := ord[j - 1], ord[j - 1] := tmp
            j--
        }
    }
    tg := Trim(tag, "[] ")
    me := ""
    if (tg != "") {
        for i, p in parts
            if (p.name = tg)
                me := p
    }
    if (IsObject(me)) {
        best := ""
        for i, p in ord
            if (p.name != tg && (best = "" || p.pts > best.pts))
                best := p
        w := {own: true, us: me.pts, them: (IsObject(best) ? best.pts : 0)
            , enemy: (IsObject(best) ? best.name : ""), lead: "", leadP: "", rival: "", rivalP: ""}
    } else {
        w := {own: false, us: "", them: "", enemy: ord[1].name
            , lead: ord[1].name, leadP: ord[1].pts
            , rival: ord[2].name, rivalP: ord[2].pts}
    }
    w.secs := RegExMatch(t, "i)Zeit\s*:?\s*(\d{1,3}):(\d{2})", z) ? z1 * 60 + z2 : ""
    w.flag := RegExMatch(t, "i)Flagge\s*:?\s*([^\]\r\n/|]+)", fl) ? Trim(fl1) : ""
    ; Art direkt aus der Anzeige, soweit sie es verraet:
    ;   "Flagge: ..." gibt es nur beim Gangwar,
    ;   ein Wort wie "Biz"/"Business" nur beim Bizfight.
    w.kind := ""
    if (w.flag != "")
        w.kind := "gang"
    else if (YK_WarBizBoard != "" && YkMatch(t, YK_WarBizBoard))
        w.kind := "biz"
    return w
}

; Alle "FRAKTION 12P"-Teile einer Anzeige, in der Reihenfolge des Textes.
; Auf dem Server steht dort z.B. "[YAK 24P - GuiZa 0P]" - bei einem
; Family-War, an dem wir nicht beteiligt sind, eben zwei fremde Namen.
YkWarTd_Parts(t) {
    parts := []
    pos := 1
    while (pos := RegExMatch(t, "i)([^\s\[\]~:,]+)\s+(\d{1,4})\s*P(?![A-Za-z])", m, pos)) {
        parts.Push({name: m1, pts: m2 + 0})
        pos += StrLen(m)
    }
    return parts
}

; Kennung einer Anzeige - gleiche Kennung = dieselbe Tafel
YkWarTd_Sig(w) {
    return (w.own ? "1" : "0") . "|" . w.us . "|" . w.them . "|" . w.enemy
        . "|" . w.lead . "|" . w.leadP . "|" . w.rival . "|" . w.rivalP
}

; Alle Anzeigen (Liste von Texten) in die Kriegsliste uebernehmen.
; Nur ein Gangwar zeigt "Flagge", ein Bizfight nennt sich meist selbst so.
; Laesst sich die Art nicht sicher bestimmen, steht neutral "War" da -
; frueher wurde in diesem Fall einfach "Family-War" behauptet, weshalb ein
; Bizfight IMMER falsch angezeigt wurde.
; Kommt die Anzeige ohne Chatzeile (Binder mitten im War gestartet),
; entsteht ein Eintrag, der mit der Anzeige wieder verschwindet.
; true = Inhalt hat sich geaendert
YkWarTd_Apply(tds, now) {
    global g_Wars, g_WarEndT, YK_GangTag, g_WarKindHint
    boards := [], flags := [], times := []
    sigs := {}
    for i, s in tds {
        w := YkWarTd_Parse(s, YK_GangTag)
        if (IsObject(w)) {
            ; Dieselbe Tafel kommt oft mehrfach im Bild vor (Schatten,
            ; Rahmen, eine Kopie je Spieler). Frueher wurde daraus ein
            ; ZWEITER Krieg-Eintrag - der Gangwar stand dann doppelt im
            ; Overlay. Gleiche Kennung = dieselbe Tafel, also zusammenlegen.
            sg := YkWarTd_Sig(w)
            if (sigs.HasKey(sg)) {
                o := boards[sigs[sg]]
                if (o.secs = "" && w.secs != "")
                    o.secs := w.secs
                if (o.flag = "" && w.flag != "") {
                    o.flag := w.flag
                    o.kind := "gang"
                }
                continue
            }
            boards.Push(w)
            sigs[sg] := boards.MaxIndex()
            continue
        }
        c := RegExReplace(RegExReplace(s, "i)~n~", "`n"), "~[A-Za-z]~")
        if RegExMatch(c, "i)Flagge\s*:?\s*([^\]\r\n/|]+)", fl)
            flags.Push(Trim(fl1))
        else if RegExMatch(c, "i)^[\s\[]*Zeit\s*:?\s*(\d{1,3}):(\d{2})[\s\]]*$", z)
            times.Push(z1 * 60 + z2)
    }
    ; Zeit oder Flagge als eigene Anzeige - nur wenn eindeutig zuzuordnen
    if (boards.MaxIndex() = 1) {
        if (boards[1].secs = "" && times.MaxIndex() = 1)
            boards[1].secs := times[1]
        if (boards[1].flag = "" && flags.MaxIndex() = 1)
            boards[1].flag := flags[1], boards[1].kind := "gang"
    }
    ; Welche Arten laufen laut Chat gerade? Nur wenn genau EINE in Frage
    ; kommt, wird eine Anzeige ohne eigenes Kennzeichen ihr zugeordnet.
    kinds := {}, nKinds := 0
    for k, e in g_Wars {
        if (e.kind != "" && !kinds.HasKey(e.kind)) {
            kinds[e.kind] := 1
            nKinds += 1
        }
    }
    changed := false
    seen := {}
    seenKind := {}
    for i, w in boards {
        kind := w.kind
        if (kind = "") {
            ; kein Kennzeichen in der Anzeige -> nur uebernehmen, was
            ; sicher ist: genau ein laufender Krieg, oder eine gerade
            ; gesehene Chatzeile. Sonst bleibt es neutral "War" - lieber
            ; unbestimmt als falsch beschriftet.
            if (nKinds = 1) {
                for k, v in kinds
                    kind := k
            } else if (IsObject(g_WarKindHint) && (now - g_WarKindHint.t) < 60000) {
                kind := g_WarKindHint.kind
            } else {
                kind := "war"
            }
        }
        ; War laut Chat gerade vorbei - eine kurz stehenbleibende Anzeige ignorieren
        if (g_WarEndT.HasKey(kind) && (now - g_WarEndT[kind]) < 20000)
            continue
        ; Je Kriegsart und Seite gibt es genau EINEN Eintrag: einen eigenen
        ; Gangwar kann man nicht zweimal haben. Genau daraus entstanden die
        ; doppelten Zeilen im Overlay. Ein fremder Krieg derselben Art darf
        ; daneben stehen - deshalb zaehlt "unser/fremd" mit.
        kk := kind . (w.own ? "|1" : "|0")
        if (seenKind.HasKey(kk))
            continue
        seenKind[kk] := 1
        ; passenden Eintrag suchen: zuerst einen mit derselben Seite
        key := ""
        for k, e in g_Wars
            if (e.kind = kind && (e.own ? true : false) = w.own && (key = "" || e.t > g_Wars[key].t))
                key := k
        if (key = "") {
            for k, e in g_Wars
                if (e.kind = kind && !seen.HasKey(k) && (key = "" || e.t > g_Wars[key].t))
                    key := k
        }
        if (key = "") {
            key := YkWar_KindLabel(kind)
            g_Wars[key] := {us: "", them: "", enemy: w.enemy, mins: 0, t: now, kind: kind, td: true
                , own: w.own, lead: "", leadP: "", rival: "", rivalP: ""}
            changed := true
        }
        e := g_Wars[key]
        if (e.flag != w.flag || (w.secs != "" && e.secs != w.secs))
            changed := true
        e.flag := w.flag, e.tdT := now
        if (w.own) {
            ; Unser Tag steht in der Anzeige - wir sind also dabei. Genau
            ; das passiert auch, wenn wir in einen fremden Family-War
            ; eingreifen: aus dem neutralen Eintrag wird unser Krieg.
            if (e.us != w.us || e.them != w.them || !e.own)
                changed := true
            e.own := true
            e.us := w.us, e.them := w.them
            e.lead := "", e.leadP := "", e.rival := "", e.rivalP := ""
            if (e.td || e.enemy = "" || e.enemy = "unser Angriff")
                e.enemy := w.enemy
        } else if (!e.own) {
            ; fremder Krieg: nur festhalten, wer gerade fuehrt
            if (e.lead != w.lead || e.leadP != w.leadP || e.rivalP != w.rivalP)
                changed := true
            e.us := "", e.them := ""
            e.lead := w.lead, e.leadP := w.leadP
            e.rival := w.rival, e.rivalP := w.rivalP
            if (e.td || e.enemy = "")
                e.enemy := w.lead
        }
        ; hat sich die Art nachtraeglich geklaert (Flagge/Biz erkannt),
        ; wird sie korrigiert
        if (w.kind != "" && e.kind != w.kind) {
            e.kind := w.kind
            changed := true
        }
        if (w.secs != "") {
            e.secs := w.secs
            e.mins := Ceil(w.secs / 60)
            e.t := now
        }
        seen[key] := 1
    }
    for k, e in g_Wars.Clone() {
        if (e.td && !seen.HasKey(k) && (now - e.tdT) > 5000) {
            g_Wars.Delete(k)
            changed := true
        }
    }
    return changed
}

; aus dem Haupt-Timer, hoechstens alle 1,5 Sekunden (jedes Lesen kostet
; Speicherzugriffe im laufenden Spiel)
YkWarTd_Tick() {
    global YK_MemEnabled, YK_OvEnabled, YK_OvWar, g_WarTdT
    if (!YK_MemEnabled || !YK_OvEnabled || !YK_OvWar || (A_TickCount - g_WarTdT) < 1500)
        return
    g_WarTdT := A_TickCount
    tds := YkSamp_TextDraws()
    if YkWarTd_Apply(IsObject(tds) ? tds : [], A_TickCount)
        YkOverlay_Refresh()
}
