; =====================================================================
;  Yakuza Keybinder - Kills und Tode
; ---------------------------------------------------------------------
;  KILLS werden auf zwei Wegen erkannt:
;   1) aus dem Spiel selbst - wichtig fuer Gang- und Family-Wars, dort
;      schreibt der Server nichts in den Chat (und der Killfeed ist leer).
;      Jede Figur fuehrt mit, WER sie zuletzt verletzt hat. Steht dort die
;      eigene Figur, zaehlt der Kill. Sagt das Spiel dazu nichts, greift
;      die Notloesung: eigene Schuesse samt Blickrichtung mitschreiben und
;      pruefen, ob der eigene Treffer hoechstens 600 ms vorher kam und
;      danach kein anderer mehr auf ihn gefeuert hat.
;      Ein Schuss wird erkannt, wenn die Munition sinkt ODER die Figur im
;      Spiel "feuert" - sonst gingen auf Servern mit unbegrenzter Munition
;      alle Kills verloren.
;   2) aus Server-Meldungen, z.B.
;      [BIZ FIGHT] +1 Kill fuer Yakuza (Marci). Stand 5 : 0.
;      Amore wurde von Marci erschossen und wandert fuer 10 Minuten in den Knast.
;      Gezaehlt wird nur, wenn der Name der eigene ist.
;  Derselbe Kill wird nie doppelt gemeldet. Strg+K bleibt als Notnagel.
;
;  TODE: Auf Life of Player ist man nach dem Tod meistens zuerst bewusstlos:
;     Du bist bewusstlos. Warte auf den Rettungsdienst oder das Krankenhaus (60s).
;  Bis zum Krankenhaus oder bis ein Medic hilft, lehnt der Server jeden
;  Befehl ab:
;     Du bist bewusstlos und kannst keine Befehle benutzen.
;  Die Tod-Meldung wird deshalb im Moment des Todes mit dem Sterbeort
;  gebaut und erst gesendet, wenn man wieder schreiben kann:
;     - Teleport ins Krankenhaus (Position springt), oder
;     - Wiederbelebung (Chatzeile oder deutliche HP-Aenderung), oder
;     - spaetestens nach der Wartezeit (60 s + Puffer).
;  Lehnt der Server trotzdem ab (z.B. /warten auf den Medic), wird es
;  alle 20 s erneut versucht.
;
;  IN GANG-, FAMILY- UND BIZ-WARS ist man NICHT bewusstlos: man spawnt
;  sofort in der Base oder an einem anderen Spawnort. Dann wartet der
;  Binder nur ein kurzes Fenster (1,2 s) ab, ob doch noch eine
;  "bewusstlos"-Zeile kommt, und schickt die Meldung sonst sofort mit dem
;  Sterbeort raus - auch mitten im Gefecht und auch, wenn die Maustaste
;  noch gedrueckt ist (man ist ja gerade gestorben).
;  Der Sterbeort kommt aus einem kleinen Positions-Gedaechtnis: gemeldet
;  wird, wo man kurz VOR dem Tod stand, nicht der Spawnort danach.
; =====================================================================

global YK_KillAuto       := true
; --- Alle Kill-Entscheidungen laufen ueber Millisekunden ---
;  KillWindowMs  So kurz nach DEINEM Treffer muss der Gegner fallen, damit
;                es dein Kill sein kann (Ping + Sync).
;  KillRivalMs   Schiessen mehrere auf denselben Gegner (3 Mann mit MP5),
;                nimmt dir ein anderer den Kill erst weg, wenn sein Schuss
;                MEHR als so viele Millisekunden NACH deinem kam. Vorher
;                genuegte ein einziger fremder Schuss nach deinem - im War
;                wurde damit fast nie etwas gezaehlt.
;  KillSameMs    Innerhalb dieser Zeit gehoeren zwei Meldungen zum selben
;                Kill (Server-Meldung und im Spiel erkannter Kill).
global YK_KillWindowMs   := 600
global YK_KillRivalMs    := 150
global YK_KillSameMs     := 900
global YK_KillLogOn      := false  ; YakuzaKills.log schreiben (zum Nachpruefen)
global YK_KoPattern      := "Du bist bewusstlos\."
global YK_KoRejectPat    := "bewusstlos und kannst keine Befehle"
global YK_RevivePattern  := "wiederbelebt|reanimiert|aus dem Krankenhaus|Krankenhaus entlassen|wieder bei Bewusstsein|bist wieder wach"
; Welche dieser Zeilen bedeutet "das Krankenhaus hat dich rausgelassen"?
; Alles andere gilt als Wiederbelebung durch einen Medic.
global YK_HospPattern    := "Krankenhaus|Hospital|Klinik"
global YK_KoWaitSec      := 62
global YK_KoRetrySec     := 20
; Eigener Text, wenn dich ein Medic wieder auf die Beine stellt. Dann ist
; "Tod in ..." falsch - du stehst ja wieder da, wo du gefallen bist.
global YK_ReviveEnabled  := true
global YK_ReviveText     := "Von einem Medic wiederbelebt | Standort: {standort} | HP: {hp}"

; Wer hat MICH umgebracht? (Platzhalter {moerder})
;  - aus dem Spiel: die eigene Figur fuehrt mit, wer sie zuletzt verletzt
;    hat (dasselbe Feld, das auch fuer die eigenen Kills gelesen wird)
;  - aus dem Chat: "Marci wurde von Amore erschossen", wenn Marci man selbst ist
global YK_KillerEnabled  := true
global YK_KillerPattern  := ""     ; eigenes Muster, Gruppe 1 = Name (leer = Standard)
global g_DeathKiller     := ""     ; Name oder ""
global g_DeathKillerT    := 0      ; wann zuletzt gesetzt
global g_DmgTrail        := []     ; [{t, ptr}] - wer hat mich in den letzten Sekunden verletzt

global g_DeathPend       := ""     ; wartende Tod-Meldung (siehe oben)
global g_LastDeathText   := ""     ; zuletzt gesendete Tod-Meldung (gegen Doppelung)
global g_LastDeathTextT  := 0
global g_LastAutoKill    := 0
global g_LastKillVictim  := ""
global g_KillVictim      := ""     ; fuer den Platzhalter {opfer}
global g_LastConnectTick := 0
global g_OwnMsgs         := []     ; zuletzt selbst gesendete Chat-Nachrichten
; Die letzten Kill-Ereignisse: {t, victim, ped, src, paired}
; src = "chat" (Server-Meldung) | "mem" (im Spiel gesehen) | "hand" (Strg+K)
global g_KillEvents      := []
global g_PedInfo         := {}     ; Figur -> {alive, wt, ammo, fireT} beim letzten Blick
global g_LastShotT       := 0      ; letzter eigener Schuss/Schlag (auch: "gerade im Kampf")
global g_ShotSamples     := []     ; eigene Schuesse der letzten 2 s mit Blickrichtung
global g_LastAmmo        := -1
global g_LastWType       := -1
global g_OwnFireT        := 0      ; seit wann meldet die eigene Figur "feuert"

; Positions-Gedaechtnis der letzten ~4 s: [{t, x, y, z}]. Im Moment des
; Todes steht in der Spielposition oft schon der Spawnort - gemeldet wird
; deshalb die Position von kurz vorher.
global g_PosTrail        := []
global g_DeathHp         := 100    ; Leben beim letzten schnellen Blick
global g_DeathWatchT     := 0

; Zeile ohne Farbcodes und Zeitstempel
YkChat_Clean(line) {
    l := RegExReplace(line, "\{[0-9A-Fa-f]{6}\}")
    return Trim(RegExReplace(l, "^\s*\[\d{1,2}:\d{2}(:\d{2})?\]\s*"))
}

YkIsOwnName(n) {
    global YK_OwnName
    return (YK_OwnName != "" && n = YK_OwnName)
}

; ---------------------------------------------------------------------
;  Eigene Nachrichten wiedererkennen
; ---------------------------------------------------------------------
; Jede ueber den Binder gesendete Chat-Nachricht (/g, /f, ...) wird kurz
; gemerkt. Taucht sie im Chatlog auf, steht davor der eigene Name - so
; lernt der Binder ihn, egal ob ueber /g oder /f geschrieben wurde.
YkOwnMsg_Remember(text) {
    global g_OwnMsgs
    if !RegExMatch(text, "^/\w+\s+(.+)$", m)
        return
    g_OwnMsgs.Push({body: Trim(m1), t: A_TickCount})
    while (g_OwnMsgs.MaxIndex() > 8)
        g_OwnMsgs.RemoveAt(1)
}

; true (und verbraucht), wenn msg eine eigene Nachricht der letzten 15 s ist
YkOwnMsg_Take(msg) {
    global g_OwnMsgs
    for i, o in g_OwnMsgs {
        if ((A_TickCount - o.t) < 15000 && o.body = msg) {
            g_OwnMsgs.RemoveAt(i)
            return true
        }
    }
    return false
}

; ---------------------------------------------------------------------
;  Chatzeilen auswerten
; ---------------------------------------------------------------------
YkCombat_HandleLine(line) {
    global YK_CombatEnabled, YK_KillEnabled, YK_KillAuto, YK_KillPattern
    global YK_DeathEnabled, YK_DeathPattern, YK_KoPattern, YK_KoRejectPat, YK_RevivePattern
    global YK_HospPattern
    global g_DeathPend
    if (!YK_CombatEnabled)
        return
    l := YkChat_Clean(line)
    if (l = "")
        return

    if (YK_KillEnabled) {
        victim := ""
        if (YK_KillAuto && YkKill_Parse(l, victim))
            YkKill_Auto(victim)
        else if (YK_KillPattern != "" && YkMatch(l, YK_KillPattern))
            YkKill_Auto("")
    }

    if (!YK_DeathEnabled)
        return
    ; Wer hat mich erwischt? Muss VOR YkDeath_Begin stehen - die Meldung
    ; wird dort mit allen Platzhaltern fertig gebaut.
    if (YkDeath_ParseKiller(l, killer))
        YkDeath_SetKiller(killer)
    if (YK_DeathPattern != "" && YkMatch(l, YK_DeathPattern)) {
        YkDeath_Begin(false)
        return
    }
    ; Server-Meldungen haben kein "Name: " - Spielerchat wird so nie als
    ; Bewusstlosigkeit oder Wiederbelebung missverstanden
    if InStr(l, ": ")
        return
    if (YK_KoRejectPat != "" && YkMatch(l, YK_KoRejectPat))
        YkDeath_Rejected()
    else if (YK_KoPattern != "" && YkMatch(l, YK_KoPattern))
        YkDeath_KnockedOut()
    else if (IsObject(g_DeathPend) && YK_RevivePattern != "" && YkMatch(l, YK_RevivePattern)) {
        ; Krankenhaus oder Medic? Danach richtet sich die Meldung im /g.
        hosp := (YK_HospPattern != "" && YkMatch(l, YK_HospPattern))
        YkDeath_Recovered(hosp ? "hosp" : "medic")
    }
}

; ---------------------------------------------------------------------
;  Kills
; ---------------------------------------------------------------------
; Alle Schreibweisen fuer "hat jemanden umgelegt" - einmal an einer Stelle,
; damit Kill-Zeilen und Tod-Zeilen dieselben Woerter kennen.
YkKill_Verbs() {
    static v := "erschossen|get(?:ö|oe)tet|umgebracht|ermordet|niedergeschossen|niedergestreckt|ausgeschaltet|bewusstlos\s+(?:geschlagen|geschossen)"
    return v
}

; true, wenn die Zeile einen eigenen Kill meldet (victim = Opfer, falls bekannt)
YkKill_Parse(l, ByRef victim) {
    verbs := YkKill_Verbs()
    victim := ""
    ; [GANG WAR] / [BIZ FIGHT] ... +1 Kill fuer Yakuza (Marci). Stand 5 : 0.
    if RegExMatch(l, "i)^\[[^\]]+\]\s*\+\d+\s+Kills?\s+f(?:ue|ü)r\s+.*\(([^()\s]+)\)", m)
        return YkIsOwnName(m1)
    ; Amore wurde von Marci erschossen und wandert ...
    ; Ein "[TAG]" oder ein "(Fraktion)" darf dabeistehen - genau daran sind
    ; frueher Kills vorbeigerutscht, weil das Muster den Namen nicht mehr
    ; gefunden hat.
    if RegExMatch(l, "i)^(?:\[[^\]]*\]\s*)?([^\s:,\.]+)(?:\s*\([^)]*\))?\s+wurde\s+von\s+(?:\[[^\]]*\]\s*)?([^\s:,\.]+)(?:\s*\([^)]*\))?\s+(?:" . verbs . ")", m) {
        victim := m1
        return YkIsOwnName(m2)
    }
    ; Du hast Amore erschossen.
    if RegExMatch(l, "i)^Du\s+hast\s+(?:\[[^\]]*\]\s*)?([^\s:,\.]+)(?:\s*\([^)]*\))?\s+(?:" . verbs . ")", m) {
        victim := m1
        return true
    }
    return false
}

; Kill zaehlen - aber jeden nur EINMAL.
;   victim = Name (falls bekannt), pedId = Figur aus dem Spielspeicher,
;   src    = "chat" | "mem" | "hand"
;
; Frueher galt: "innerhalb von 2,5 Sekunden ist alles derselbe Kill". Im
; War fallen aber oft zwei oder drei Gegner kurz hintereinander - die
; wurden dann einfach nicht mitgezaehlt. Jetzt wird paarweise abgeglichen:
;   - dieselbe Figur (Spielspeicher) zaehlt nie zweimal,
;   - derselbe Name aus dem Chat zaehlt nie zweimal,
;   - ein Chat-Ereignis und ein Spielspeicher-Ereignis dicht beieinander
;     gehoeren zusammen - aber nur EINMAL, nicht "alles, was gerade kam".
; Dadurch zaehlen mehrere Kills kurz hintereinander auch als mehrere.
YkKill_Auto(victim, pedId := 0, src := "") {
    global g_KillEvents, g_LastAutoKill, g_LastKillVictim, YK_KillSameMs
    now := A_TickCount
    if (src = "")
        src := pedId ? "mem" : "chat"
    ; alte Ereignisse vergessen
    while (g_KillEvents.MaxIndex() && (now - g_KillEvents[1].t) > 10000)
        g_KillEvents.RemoveAt(1)
    ; 1) dieselbe Figur aus dem Spielspeicher
    if (pedId) {
        for i, e in g_KillEvents
            if (e.ped = pedId && (now - e.t) < 8000)
                return
    }
    ; 2) derselbe Name - der Server meldet einen Kill gern in zwei Zeilen
    ;    ("+1 Kill fuer ..." und "X wurde von Y erschossen")
    if (victim != "") {
        for i, e in g_KillEvents
            if (e.victim != "" && e.victim = victim && (now - e.t) < 5000)
                return
    }
    ; 3) Zwei Meldungen zum selben Kill zusammenlegen - aber jede nur
    ;    einmal. Das betrifft
    ;      "+1 Kill fuer Yakuza (Marci)"  +  "Amore wurde von Marci ..."
    ;    und den im Spiel erkannten Kill  +  die Server-Meldung dazu.
    ;    Sind BEIDE eindeutig und von derselben Art (zwei Figuren, zwei
    ;    Namen), sind es zwei verschiedene Kills - genau die gingen frueher
    ;    verloren, wenn im War schnell hintereinander zwei Gegner fielen.
    idB := pedId ? "p" : (victim != "" ? "n" : "")
    for i, e in g_KillEvents {
        if (e.paired || (now - e.t) > YK_KillSameMs)
            continue
        idA := e.ped ? "p" : (e.victim != "" ? "n" : "")
        if (idA != "" && idB != "" && idA = idB)
            continue
        ; beide Namen bekannt und verschieden -> zwei verschiedene Kills
        if (victim != "" && e.victim != "" && victim != e.victim)
            continue
        e.paired := true
        if (victim != "" && e.victim = "")
            e.victim := victim
        if (pedId && !e.ped)
            e.ped := pedId
        return
    }
    g_KillEvents.Push({t: now, victim: victim, ped: pedId, src: src, paired: false})
    g_LastAutoKill := now
    g_LastKillVictim := victim
    YkReport_Kill(victim)
}

; Strg+K: der Notnagel meldet IMMER - er wird nur gemerkt, damit die
; Server-Meldung zum selben Kill danach nicht noch einmal zaehlt.
YkKill_Manual() {
    global g_KillEvents, g_LastAutoKill
    now := A_TickCount
    while (g_KillEvents.MaxIndex() && (now - g_KillEvents[1].t) > 10000)
        g_KillEvents.RemoveAt(1)
    g_KillEvents.Push({t: now, victim: "", ped: 0, src: "hand", paired: false})
    g_LastAutoKill := now
    YkReport_Kill("")
}

; ---------------------------------------------------------------------
;  Kills aus dem Spiel (Gang-/Family-Wars ohne Chatmeldung)
; ---------------------------------------------------------------------
; eigener Timer (alle 50 ms)
YkKillMem_Tick() {
    global YK_CombatEnabled, YK_KillEnabled, YK_KillAuto, YK_MemEnabled, g_PedInfo, g_ShotSamples, g_LastShotT
    global g_OwnFireT
    if (!YK_MemEnabled || !YkMem_Active()) {
        g_PedInfo := {}
        return
    }
    ; Leben und Position im schnellen Takt mitfuehren - im War kann man
    ; sterben und neu spawnen, bevor der 250-ms-Takt ueberhaupt hinsieht
    YkDeath_Watch()
    ; Charaktermenue offen? Dann Kills/Tode vom Server uebernehmen
    YkStats_Tick()
    if !YkMem_ActiveWeapon(wt, ammo) {
        wt := -1
        ammo := -1
    }
    ; "Ich feuere gerade" kommt aus ZWEI Quellen:
    ;   - die Maustaste (physisch abgefragt; das Spiel faengt die Maus ab,
    ;     der logische Zustand bleibt dabei manchmal stehen)
    ;   - die eigene Figur im Spielspeicher (unabhaengig von der Munition)
    act := YkGame_Active() ? true : false
    ownFire := act ? YkMem_OwnFire() : false
    ; Sicherung gegen ein Flag, das im Spiel haengen bleibt: steht es
    ; laenger als 8 Sekunden am Stueck, wird es nicht mehr geglaubt. Sonst
    ; wuerde der Binder dauerhaft alle Figuren lesen - genau das Ruckeln,
    ; das die zweistufige Leserei vermeiden soll.
    if (!ownFire)
        g_OwnFireT := 0
    else if (!g_OwnFireT)
        g_OwnFireT := A_TickCount
    else if ((A_TickCount - g_OwnFireT) > 8000)
        ownFire := false
    fire := (act && (GetKeyState("LButton", "P") || ownFire)) ? true : false
    ; Figuren nur beim Zielen/Schiessen lesen - ohne Schuss kein Kill. Schon
    ; ab dem Zielen, damit der Zustand VOR dem ersten Treffer bekannt ist.
    peds := ""
    myPed := 0, myVeh := 0
    if (YK_CombatEnabled && YK_KillEnabled && YK_KillAuto
        && (fire || (act && GetKeyState("RButton", "P")) || (A_TickCount - g_LastShotT) < 3000)) {
        t0 := YkDiag_Now()
        peds := YkMem_Peds()
        YkMem_OwnPtrs(myPed, myVeh)
        YkStall_Step("Figuren", YkDiag_Now() - t0)
    }
    YkKillMem_Process(A_TickCount, wt, ammo, fire, YkMem_Camera(), YkMem_GetPosition(), peds, myPed, myVeh)
}

; Kern der Erkennung - ohne Speicherzugriff, dadurch pruefbar.
;  wt/ammo = aktive Waffe, fire = Feuertaste gedrueckt, cam = Kamera,
;  me = eigene Position, peds = Figuren im Sichtbereich ("" = nicht gelesen),
;  myPed/myVeh = Zeiger auf eigene Figur/eigenes Fahrzeug
YkKillMem_Process(now, wt, ammo, fire, cam, me, peds, myPed := 0, myVeh := 0) {
    global g_PedInfo, g_ShotSamples, g_LastAmmo, g_LastWType, g_LastShotT, YK_KillWindowMs
    ; Schuss = Munition derselben Waffe sinkt; Nahkampf = Faust/Messer/... + Feuertaste
    shot := (wt >= 16 && wt = g_LastWType && ammo >= 0 && g_LastAmmo >= 0 && ammo < g_LastAmmo)
    melee := (wt >= 0 && wt <= 15 && fire)
    ; Schusswaffe in der Hand und es wird gefeuert: auch DAS ist ein Schuss.
    ; Frueher zaehlte allein die sinkende Munition - auf Servern, die
    ; unbegrenzte Munition geben (Gang- und Family-Wars), sinkt sie nie.
    ; Dort hat der Binder nie einen eigenen Schuss gesehen und folglich
    ; auch nie einen Kill gezaehlt.
    if (!shot && fire && wt >= 16)
        shot := true
    if (wt >= 0) {
        g_LastWType := wt
        g_LastAmmo := ammo
    }
    if (shot || melee)
        g_LastShotT := now
    if ((shot || melee) && IsObject(cam)) {
        g_ShotSamples.Push({t: now, wt: wt, melee: melee
            , fx: cam.fx, fy: cam.fy, fz: cam.fz, cx: cam.cx, cy: cam.cy, cz: cam.cz
            , px: (IsObject(me) ? me.x : cam.cx), py: (IsObject(me) ? me.y : cam.cy), pz: (IsObject(me) ? me.z : cam.cz)})
        while (g_ShotSamples.MaxIndex() > 16)
            g_ShotSamples.RemoveAt(1)
    }
    ; eigene Schuesse so lange behalten, wie sie fuer einen Kill zaehlen
    ; koennen (Zeitfenster + etwas Luft)
    keep := YK_KillWindowMs + 400
    if (keep < 2000)
        keep := 2000
    while (g_ShotSamples.MaxIndex() && (now - g_ShotSamples[1].t) > keep)
        g_ShotSamples.RemoveAt(1)
    if (!IsObject(peds)) {
        g_PedInfo := {}
        return
    }
    ; wer schiesst gerade? (Munition sinkt oder das Spiel meldet "feuert")
    info := {}
    for i, p in peds {
        prev := g_PedInfo[p.id]
        fireT := IsObject(prev) ? prev.fireT : 0
        if (p.fire || (IsObject(prev) && p.wt >= 16 && p.wt = prev.wt && p.ammo >= 0 && p.ammo < prev.ammo))
            fireT := now
        info[p.id] := {alive: (p.alive ? 1 : 0), wt: p.wt, ammo: p.ammo, fireT: fireT
            , dmg: p.dmg, x: p.x, y: p.y, z: p.z}
    }
    for i, p in peds {
        prev := g_PedInfo[p.id]
        if (p.alive || !IsObject(prev) || !prev.alive)
            continue
        ; lebte beim letzten Blick, jetzt nicht mehr - war es MEIN letzter Treffer?
        ; Der Hinweis des Spiels ("zuletzt verletzt von") zaehlt auch dann,
        ; wenn gar kein eigener Schuss aufgezeichnet ist.
        if (!g_ShotSamples.MaxIndex() && !YkKillMem_Mine(p.dmg, myPed, myVeh))
            continue
        why := ""
        if YkKillMem_Judge(p, now, peds, info, myPed, myVeh, why) {
            ; Namen dazu holen - im War steht er in keiner Chatzeile,
            ; sonst bliebe {opfer} fuer immer "unbekannt"
            YkKill_Auto(YkSamp_NameForPed(p.id, peds), p.id)
        }
        YkKillLog(why, p, me)
    }
    ; Figuren, die seit dem letzten Blick ganz aus der Liste verschwunden
    ; sind. SA-MP raeumt eine gefallene Figur manchmal weg, bevor der Binder
    ; sie mit 0 Leben zu sehen bekommt. Gezaehlt wird das nur, wenn BEIDES
    ; stimmt: das Spiel nannte beim letzten Blick DICH als letzten Treffer,
    ; und dein Schuss auf genau diese Stelle liegt im Kill-Zeitfenster.
    for id, prev in g_PedInfo {
        if (info.HasKey(id) || !prev.alive || !YkKillMem_Mine(prev.dmg, myPed, myVeh))
            continue
        s := YkKillMem_Aimed({x: prev.x, y: prev.y, z: prev.z})
        if (!IsObject(s) || (now - s.t) > YK_KillWindowMs)
            continue
        YkKill_Auto(YkSamp_NameForPed(id, peds), id)
        YkKillLog("GEZAEHLT - Figur verschwunden, das Spiel nannte DICH als letzten Treffer"
            , {x: prev.x, y: prev.y, z: prev.z}, me)
    }
    g_PedInfo := info
}

; Nennt das Spiel MICH als letzten Schadensverursacher?
;   dmg = Zeiger aus CPed+0x764 der gefallenen Figur
YkKillMem_Mine(dmg, myPed, myVeh) {
    if (!dmg)
        return false
    if (myPed && dmg = myPed)
        return true
    return (myVeh && dmg = myVeh) ? true : false
}

; Protokoll "war das mein Kill?" in YakuzaKills.log neben der exe - jede
; umgefallene Figur, auf die kurz vorher geschossen wurde, mit Begruendung
YkKillLog(why, p, me) {
    global YK_KillLogOn
    static sizeT := 0
    if (!YK_KillLogOn)
        return
    f := A_ScriptDir . "\YakuzaKills.log"
    ; Groesse nur einmal pro Minute pruefen - frueher stand bei jedem
    ; gefallenen Gegner ein zusaetzlicher Plattenzugriff mitten im Gefecht
    if ((A_TickCount - sizeT) > 60000) {
        sizeT := A_TickCount
        FileGetSize, sz, %f%
        if (sz > 200000)
            FileMove, %f%, % A_ScriptDir . "\YakuzaKills.alt.log", 1
    }
    FormatTime, ts, , dd.MM. HH:mm:ss
    d := IsObject(me) ? Round(Sqrt((p.x - me.x) ** 2 + (p.y - me.y) ** 2)) . " m" : "?"
    FileAppend, % ts . "   Spieler in " . d . " gefallen:  " . why . "`r`n", %f%, UTF-8
}

; War es MEIN Kill? Die Reihenfolge ist wichtig:
;  1) Sagt das SPIEL, wer zuletzt Schaden gemacht hat, gilt das - und zwar
;     ZUERST. Bist du das, zaehlt der Kill, auch wenn drei andere daneben
;     stehen und feuern und auch dann, wenn der Binder gar keinen eigenen
;     Schuss aufgezeichnet hat (unbegrenzte Munition). Nennt das Spiel
;     einen anderen, zaehlt er nicht.
;  2) Schweigt das Spiel, muss dein letzter Treffer auf genau diese Figur
;     hoechstens YK_KillWindowMs (Standard 600 ms) zurueckliegen.
;  3) Dann entscheidet die Zeit: nur wer MEHR als YK_KillRivalMs nach
;     deinem Schuss auf ihn gefeuert hat, nimmt dir den Kill weg.
; Im Zweifel zaehlt es NICHT - ein verpasster Kill laesst sich per Strg+K
; nachmelden, ein fremder Kill im Gangchat waere peinlicher.
YkKillMem_Judge(p, now, peds, info, myPed, myVeh, ByRef why) {
    global YK_KillWindowMs, YK_KillRivalMs, g_LastShotT
    ; 0) Die sicherste Auskunft zuerst: das Spiel selbst fuehrt an jeder
    ;    Figur mit, wer sie zuletzt verletzt hat. Steht dort deine Figur
    ;    (oder dein Fahrzeug), ist es dein Kill - fertig.
    ;    Frueher stand diese Pruefung HINTER der Schuss-Aufzeichnung. Wo die
    ;    Munition nicht sinkt, gab es keine Aufzeichnung, und die eindeutige
    ;    Auskunft des Spiels kam nie zum Zug. Genau daran sind die Kills in
    ;    Gang- und Family-Wars verloren gegangen.
    if (YkKillMem_Mine(p.dmg, myPed, myVeh)) {
        if ((now - g_LastShotT) > 10000) {
            why := "NICHT gezaehlt - das Spiel nennt dich, dein letzter Schuss ist aber zu lange her"
            return false
        }
        why := "GEZAEHLT - das Spiel nennt DICH als letzten Treffer"
        return true
    }
    if (p.dmg) {
        why := "NICHT gezaehlt - das Spiel nennt einen anderen als letzten Schadensverursacher"
        return false
    }
    s := YkKillMem_Aimed(p)
    if (!IsObject(s)) {
        why := "NICHT gezaehlt - dein Schuss ging nicht auf ihn"
        return false
    }
    dt := now - s.t
    if (dt > YK_KillWindowMs) {
        why := "NICHT gezaehlt - dein letzter Schuss auf ihn war " . dt . " ms vorher (erlaubt " . YK_KillWindowMs . " ms)"
        return false
    }
    for i, q in peds {
        if (q.id = p.id || !q.alive)
            continue
        qi := info[q.id]
        ; nur wer SPAETER gefeuert hat als du - und zwar deutlich (sonst
        ; war es ein gleichzeitiger Schuss, der ihn nicht mehr umgelegt hat)
        if (!IsObject(qi) || !qi.fireT || (qi.fireT - s.t) <= YK_KillRivalMs)
            continue
        dx := p.x - q.x, dy := p.y - q.y
        d := Sqrt(dx * dx + dy * dy)
        fl := Sqrt(q.fx * q.fx + q.fy * q.fy)
        if (d < 1 || d > 150 || fl < 0.1)
            continue
        if ((dx * q.fx + dy * q.fy) / (d * fl) >= 0.9) { ; schaut/schiesst in ihre Richtung
            why := "NICHT gezaehlt - ein anderer Spieler (" . Round(d) . " m entfernt) hat "
                . (qi.fireT - s.t) . " ms nach dir auf ihn gefeuert"
            return false
        }
    }
    why := "GEZAEHLT - dein Schuss " . dt . " ms vorher"
    return true
}

; Juengster eigener Schuss (letzte 2 s), der auf diese Figur zielte - sonst ""
YkKillMem_Aimed(p) {
    global g_ShotSamples
    i := g_ShotSamples.MaxIndex()
    while (i >= 1) {
        s := g_ShotSamples[i]
        i -= 1
        if (s.melee) {
            dx := p.x - s.px, dy := p.y - s.py, dz := p.z - s.pz
            if ((dx * dx + dy * dy + dz * dz) <= 9)          ; Nahkampf: bis 3 m
                return s
            continue
        }
        dx := p.x - s.cx, dy := p.y - s.cy, dz := p.z - s.cz
        d := Sqrt(dx * dx + dy * dy + dz * dz)
        if (d < 1 || d > 180)
            continue
        cosA := (dx * s.fx + dy * s.fy + dz * s.fz) / d
        ; nah ist der Kegel weiter (Fadenkreuz sitzt nicht exakt in der
        ; Bildmitte), weit weg enger; Granaten/Raketen grosszuegig
        wide := (s.wt = 16 || s.wt = 18 || s.wt = 35 || s.wt = 36 || s.wt = 39)
        lim := wide ? 0.90 : (d < 10) ? 0.87 : (d < 30) ? 0.966 : 0.985
        if (cosA >= lim)
            return s
    }
    return ""
}

; ---------------------------------------------------------------------
;  Wer hat mich umgebracht?  ({moerder})
; ---------------------------------------------------------------------
; Aus der Chatzeile. Erkannt wird nur, was eindeutig MICH als Opfer nennt:
;   Marci wurde von Amore erschossen ...     (Marci = eigener Name)
;   Du wurdest von Amore erschossen ...
; Ein eigenes Muster aus den Einstellungen geht vor; dort muss der Name in
; der ersten Klammer stehen.
YkDeath_ParseKiller(l, ByRef killer) {
    global YK_KillerEnabled, YK_KillerPattern
    killer := ""
    if (!YK_KillerEnabled)
        return false
    if (YK_KillerPattern != "") {
        res := ""
        try res := RegExMatch(l, "i)" . YK_KillerPattern, m)
        if (res > 0 && Trim(m1) != "") {
            killer := Trim(m1)
            return true
        }
        if (res != "")
            return false
    }
    verbs := YkKill_Verbs()
    ; "Du wurdest von X erschossen"
    if RegExMatch(l, "i)^Du\s+(?:wurdest|bist)\s+von\s+(?:\[[^\]]*\]\s*)?([^\s:,\.]+)(?:\s*\([^)]*\))?\s+(?:" . verbs . ")", m) {
        killer := m1
        return true
    }
    ; "<eigener Name> wurde von X erschossen"
    if RegExMatch(l, "i)^(?:\[[^\]]*\]\s*)?([^\s:,\.]+)(?:\s*\([^)]*\))?\s+wurde\s+von\s+(?:\[[^\]]*\]\s*)?([^\s:,\.]+)(?:\s*\([^)]*\))?\s+(?:" . verbs . ")", m) {
        if (YkIsOwnName(m1)) {
            killer := m2
            return true
        }
    }
    return false
}

YkDeath_SetKiller(name) {
    global g_DeathKiller, g_DeathKillerT, g_DeathPend
    name := Trim(name)
    if (name = "")
        return
    g_DeathKiller := name
    g_DeathKillerT := A_TickCount
    ; Die Meldung ist im Moment des Todes fertig gebaut worden - stand der
    ; Name damals noch nicht fest, wird er jetzt nachgetragen. Sonst stuende
    ; "von unbekannt" im Gangchat, obwohl der Server es gleich danach schreibt.
    d := g_DeathPend
    if (IsObject(d) && !d.sentT && InStr(d.text, "unbekannt") && (A_TickCount - d.t) < 6000)
        d.text := StrReplace(d.text, "unbekannt", name)
}

; Wer hat mich zuletzt verletzt? Aus dem Spielspeicher, im schnellen Takt
; mitgefuehrt: im Moment des Todes steht dort oft schon nichts mehr, der
; letzte Wert von kurz davor ist der richtige.
YkDmg_Track() {
    global g_DmgTrail
    p := YkMem_LastDamager()
    now := A_TickCount
    if (p)
        g_DmgTrail.Push({t: now, ptr: p})
    while (g_DmgTrail.MaxIndex() && (now - g_DmgTrail[1].t) > 4000)
        g_DmgTrail.RemoveAt(1)
    while (g_DmgTrail.MaxIndex() > 40)
        g_DmgTrail.RemoveAt(1)
}

; Name des letzten Schadensverursachers aus dem Spielspeicher ("" = unbekannt)
YkDmg_Name() {
    global g_DmgTrail
    i := g_DmgTrail.MaxIndex()
    if (!i)
        return ""
    peds := YkMem_Peds()
    while (i >= 1) {
        n := YkSamp_NameForPed(g_DmgTrail[i].ptr, peds)
        if (n != "")
            return n
        i -= 1
    }
    return ""
}

; ---------------------------------------------------------------------
;  Tode
; ---------------------------------------------------------------------
; Position mitschreiben (aus dem schnellen Takt). Behalten werden die
; letzten 4 Sekunden.
YkPos_Track(pos) {
    global g_PosTrail
    if (!IsObject(pos))
        return
    now := A_TickCount
    g_PosTrail.Push({t: now, x: pos.x, y: pos.y, z: pos.z})
    while (g_PosTrail.MaxIndex() && (now - g_PosTrail[1].t) > 4000)
        g_PosTrail.RemoveAt(1)
}

; Wo stand man vor "backMs" Millisekunden? Das ist der Sterbeort - die
; aktuelle Position ist beim Sofort-Respawn schon die Base.
YkPos_Before(backMs := 700) {
    global g_PosTrail
    want := A_TickCount - backMs
    best := ""
    i := g_PosTrail.MaxIndex()
    while (i >= 1) {
        p := g_PosTrail[i]
        best := p
        if (p.t <= want)
            break
        i -= 1
    }
    return IsObject(best) ? {x: best.x, y: best.y, z: best.z} : ""
}

; Schneller Takt (50 ms): Position merken und den Tod erkennen, auch wenn
; man sofort wieder spawnt.
YkDeath_Watch() {
    global YK_CombatEnabled, YK_DeathEnabled, YK_DeathByHealth, YK_MemEnabled, YK_KillerEnabled
    global g_DeathHp, g_DeathReported, g_LastConnectTick, g_LastPos
    if (!YK_MemEnabled || !YkMem_Active())
        return
    p := YkMem_GetPosition()
    if (IsObject(p)) {
        YkPos_Track(p)
        g_LastPos := p
    }
    if (!YK_CombatEnabled || !YK_DeathEnabled)
        return
    if (YK_KillerEnabled)
        YkDmg_Track()
    if (!YK_DeathByHealth)
        return
    hp := YkMem_GetHealth()
    if (hp < 0)
        return
    if (g_DeathHp > 5 && hp <= 0 && !g_DeathReported) {
        g_DeathReported := true
        ; direkt nach dem Verbinden steht HP kurz auf 0 - kein Tod
        if ((A_TickCount - g_LastConnectTick) > 30000)
            YkDeath_Begin(false)
    }
    ; Wieder scharf, sobald ueberhaupt wieder Leben da ist. Frueher standen
    ; hier 15 HP: wer von einem Medic mit weniger hochgeholt wurde und kurz
    ; darauf erneut starb, dessen Tod hat der Binder dann nie gesehen - der
    ; fehlte danach auch im Overlay. Dieselbe Schwelle wie oben (5) genuegt;
    ; gegen Doppelzaehlung schuetzt YkDeath_Begin selbst.
    if (hp > 5)
        g_DeathReported := false
    g_DeathHp := hp
}

; ko = true: Bewusstlosigkeit ist schon bekannt
YkDeath_Begin(ko) {
    global g_DeathPend, g_SessDeaths, YK_DeathText, YK_CombatEnabled, YK_DeathEnabled
    global YK_KillerEnabled, g_DeathKiller, g_DeathKillerT
    if (!YK_CombatEnabled || !YK_DeathEnabled)
        return
    d := g_DeathPend
    if (IsObject(d) && !d.sentT) {
        ; Ein und derselbe Tod meldet sich zweimal: erst geht das Leben auf
        ; 0, kurz danach kommt "Du bist bewusstlos". Das darf nicht doppelt
        ; zaehlen - alles innerhalb von 4 Sekunden ist derselbe Tod.
        if ((A_TickCount - d.t) < 4000) {
            if (ko && !d.ko) {
                d.ko := true
                d.koT := A_TickCount
            }
            return
        }
        ; Laenger her? Dann ist das ein NEUER Tod, waehrend die alte Meldung
        ; noch auf eine Gelegenheit zum Senden wartet (im War passiert genau
        ; das staendig). Frueher wurde er dadurch weder gezaehlt noch
        ; gemeldet. Jetzt zaehlt er, und die inzwischen veraltete Meldung
        ; wird durch die neue ersetzt - statt zwei Sterbeorte nachzureichen.
    }
    g_SessDeaths += 1
    YkStats_CountDeath()
    ; Moerder: was der Chat gerade gemeldet hat, gilt; sonst der letzte
    ; Schadensverursacher aus dem Spiel (im War schreibt der Server nichts).
    if (YK_KillerEnabled && (g_DeathKiller = "" || (A_TickCount - g_DeathKillerT) > 8000)) {
        n := YkDmg_Name()
        g_DeathKiller := n
        g_DeathKillerT := n != "" ? A_TickCount : 0
    }
    ; Sterbeort: wo man kurz VOR dem Tod stand (beim Sofort-Respawn im War
    ; steht in der Spielposition sonst schon die Base)
    pos := YkPos_Before(700)
    if (!IsObject(pos))
        pos := YkCurrentPos()
    ; Text JETZT bauen: Sterbeort, nicht Krankenhaus / Spawnort
    g_DeathPend := {text: YkGangLine("", YkFillPlaceholders(YK_DeathText, pos)), t: A_TickCount
        , ko: (ko ? true : false), koT: (ko ? A_TickCount : 0), koHp: "", noHp: false
        , rev: 0, revKind: "", jumpT: 0, sentT: 0, nextTry: 0, tries: 0, koAfterSend: false
        , hasPos: IsObject(pos), px: (IsObject(pos) ? pos.x : 0), py: (IsObject(pos) ? pos.y : 0)}
    YkOverlay_Refresh()
}

; "Du bist bewusstlos. Warte auf den Rettungsdienst ..."
YkDeath_KnockedOut() {
    global g_DeathPend
    d := g_DeathPend
    ; Meldung ging gerade erst raus und DANACH kam "bewusstlos" -> vermutlich
    ; abgelehnt, also noch einmal versuchen.
    ;
    ; ABER hoechstens EINMAL je Tod: Life of Player wiederholt diese Zeile,
    ; solange man liegt. Frueher wurde die Meldung bei jeder Wiederholung
    ; neu scharf gestellt - so stand sie zwei- und dreimal im Gangchat.
    ; Der verlaessliche Weg fuer einen zweiten Versuch bleibt die echte
    ; Ablehnung ("bewusstlos und kannst keine Befehle", YkDeath_Rejected).
    if (IsObject(d)) {
        if (d.sentT && !d.koAfterSend && (A_TickCount - d.sentT) < 10000) {
            d.koAfterSend := true
            d.sentT := 0
        }
        ; Solange eine Meldung zu diesem Tod gefuehrt wird, gehoert die Zeile
        ; dazu - daraus wird NIE ein neuer Tod. (Bis v1.9.3 fiel der dritte
        ; und jeder weitere "bewusstlos"-Hinweis hier durch und zaehlte als
        ; zusaetzlicher Tod mit neuer Meldung.)
        d.ko := true
        d.koT := A_TickCount
        if (!d.sentT) {
            d.rev := 0
            d.revKind := ""
            d.jumpT := 0
        }
        YkOverlay_Refresh()
        return
    }
    YkDeath_Begin(true)
}

; "Du bist bewusstlos und kannst keine Befehle benutzen."
YkDeath_Rejected() {
    global g_DeathPend, YK_KoRetrySec
    d := g_DeathPend
    if (!IsObject(d))
        return
    if (!d.ko) {
        d.ko := true
        d.koT := A_TickCount
    }
    if (d.sentT) {
        d.sentT := 0
        if (d.tries >= 15) {
            g_DeathPend := ""
            YkOverlay_Refresh()
            return
        }
        d.nextTry := A_TickCount + YK_KoRetrySec * 1000
        ; die ausloesenden Signale verbrauchen - sonst ginge es sofort wieder los
        d.rev := 0
        d.revKind := ""
        d.jumpT := 0
        d.noHp := true
        pos := YkCurrentPos()
        if (IsObject(pos)) {
            d.px := pos.x
            d.py := pos.y
            d.hasPos := true
        }
    }
    YkOverlay_Refresh()
}

; kind = "medic" (jemand hat dich wieder hochgeholt) | "hosp" (Krankenhaus)
YkDeath_Recovered(kind := "medic") {
    global g_DeathPend
    d := g_DeathPend
    if (!IsObject(d) || d.sentT)
        return
    d.rev := A_TickCount
    ; "Krankenhaus" gewinnt nie gegen ein schon erkanntes "Medic": wer
    ; wiederbelebt wurde, bekommt danach oft noch eine Zeile vom
    ; Krankenhaus zu sehen.
    if (d.revKind = "" || kind = "medic")
        d.revKind := kind
}

; true, solange man bewusstlos ist und die Meldung wartet (fuer Anzeigen)
YkDeath_Waiting() {
    global g_DeathPend
    return (IsObject(g_DeathPend) && g_DeathPend.ko && !g_DeathPend.sentT)
}

; aus dem Haupt-Timer: wartende Tod-Meldung senden, sobald es geht
YkDeath_Process() {
    global g_DeathPend, YK_KoWaitSec, g_LastQueueSend, g_LastDeathText, g_LastDeathTextT
    d := g_DeathPend
    if (!IsObject(d))
        return
    now := A_TickCount
    if (d.sentT) {
        ; 5 s ohne Ablehnung -> angekommen
        if ((now - d.sentT) > 5000) {
            g_DeathPend := ""
            YkOverlay_Refresh()
        }
        return
    }
    if ((now - d.t) > 600000) {        ; nach 10 Minuten aufgeben
        g_DeathPend := ""
        YkOverlay_Refresh()
        return
    }

    if (d.ko) {
        fast := (d.rev && (now - d.rev) > 1500)
        if (!fast && YkMem_Active()) {
            ; Krankenhaus: die Position springt weit weg
            p := YkMem_GetPosition()
            if (d.hasPos && IsObject(p) && ((p.x - d.px) ** 2 + (p.y - d.py) ** 2) > 2500) {
                if (!d.jumpT)
                    d.jumpT := now
                else if ((now - d.jumpT) > 1500) {
                    fast := true
                    if (d.revKind = "")
                        d.revKind := "hosp"
                }
            } else {
                d.jumpT := 0
            }
            ; Medic: das Leben aendert sich deutlich, ohne dass du wegteleportiert
            ; wirst - dann hat dich jemand an Ort und Stelle hochgeholt
            hp := YkMem_GetHealth()
            if (!d.noHp && hp > 0 && (now - d.koT) > 3000) {
                if (d.koHp = "")
                    d.koHp := hp
                else if (Abs(hp - d.koHp) >= 10) {
                    fast := true
                    if (d.revKind = "" && !d.jumpT)
                        d.revKind := "medic"
                }
            }
        }
        if (fast)
            due := true
        else if (d.nextTry)
            due := (now >= d.nextTry)
        else
            due := ((now - d.koT) > YK_KoWaitSec * 1000)
    } else {
        ; Tod OHNE Bewusstlosigkeit - das ist der Normalfall in Gang-,
        ; Family- und Biz-Wars: man spawnt sofort wieder.
        ;  - 1,2 s Karenz, falls doch noch "Du bist bewusstlos" kommt
        ;  - danach senden, sobald man wieder Leben hat (= gespawnt)
        ;  - spaetestens nach 6 s auf jeden Fall
        hp := YkMem_GetHealth()
        age := now - d.t
        due := (age > 1200 && hp > 0) || (age > 6000)
    }
    ; Die Tod-Meldung ist dringend: sie darf nicht daran haengen bleiben,
    ; dass gerade noch die Maustaste gedrueckt ist oder eben geschossen
    ; wurde - man ist ja bereits tot.
    if (!due || !YkCanAutoSend(!d.ko))
        return
    txt := YkDeath_Text(d)
    ; Zweites Netz gegen Doppelmeldungen: denselben Satz nicht noch einmal
    ; kurz hintereinander - egal, welcher Weg ihn ausgeloest hat.
    if (txt != "" && txt = g_LastDeathText && (now - g_LastDeathTextT) < 15000) {
        d.sentT := now                  ; als erledigt fuehren
        return
    }
    g_LastQueueSend := now
    if (YkSendCmd(txt, true)) {
        g_LastDeathText := txt
        g_LastDeathTextT := A_TickCount
        d.sentT := A_TickCount
        d.tries += 1
    }
}

; Welcher Text geht raus?
;  - Medic: "Von einem Medic wiederbelebt | Standort: ... | HP: ..."
;    Dieser Text wird ERST JETZT gebaut - Standort und Leben sollen ja den
;    Stand nach der Wiederbelebung zeigen. (Frueher stand hier "Tod in ..."
;    mit dem Sterbeort, obwohl man schon wieder auf den Beinen war.)
;  - sonst: die im Moment des Todes gebaute Meldung mit dem Sterbeort.
YkDeath_Text(d) {
    global YK_ReviveEnabled, YK_ReviveText
    if (d.ko && d.revKind = "medic" && YK_ReviveEnabled && Trim(YK_ReviveText) != "")
        return YkGangLine("", YkFillPlaceholders(YK_ReviveText))
    return d.text
}
