; =====================================================================
;  Brooklyn Keybinder - Bind-Datenbank
; ---------------------------------------------------------------------
;  Jeder Eintrag:
;    id    feste Kennung (hk1..hk126 = Tastennummern aus v4.60, damit
;          alte Belegungen 1:1 uebernommen werden koennen)
;    grp   Gruppe (bestimmt, fuer welches Profil der Bind aktiv ist)
;    label Anzeige im Fenster
;    type  send    = Zeilen senden (mehrere Zeilen mit `n getrennt)
;          prefill = Chat oeffnen und Text eintragen (ohne Enter)
;          local   = nur fuer dich im Overlay anzeigen
;          fn      = Sonderfunktion (fn = Funktionsname, arg = Parameter)
;    text  Standardtext (Platzhalter in {...}, im Fenster aenderbar)
;
;  Chat-Befehle (Textbinds) haben zusaetzlich "cmd" (das, was man im
;  Chat tippt, z.B. /kd) statt einer Taste.
; =====================================================================

; ---------------------------------------------------------------------
;  Profile: Fraktionstyp, Fraktionen und Jobs
; ---------------------------------------------------------------------
BkProf_Types() {
    return [{id: "zivi",  name: "Zivilist",        desc: "Keine Fraktion. Allgemeine Binds, Fahrzeug, Waffen, Drogen und Wanted."}
          , {id: "gang",  name: "Gang / Mafia",    desc: "Fraktionschat, Gangchat, Gangwar- und Gangzonekills, Gegnerlisten, Cargo, Kidnap."}
          , {id: "staat", name: "Staatsfraktion",  desc: "Funk, Department, Megafon und die Befehle deiner Behörde (Polizei, Medic, Presse ...)."}]
}

BkProf_Gangs() {
    return ["Grove Street", "Ballas", "Vagos", "Aztecas", "Rifa", "Triaden", "Yakuza", "Cali Kartell"
          , "La Cosa Nostra", "Brigada (Russen-Mafia)", "Hells Angels", "Wheelman", "ICF", "Atzen", "Andere"]
}

; Staatsfraktionen mit Unterart (bestimmt die Behoerden-Binds)
BkProf_States() {
    return [{name: "LSPD (Polizei)", sub: "polizei"}, {name: "SFPD (Polizei)", sub: "polizei"}
          , {name: "LVPD (Polizei)", sub: "polizei"}, {name: "FBI", sub: "polizei"}
          , {name: "Army / Militär", sub: "polizei"}, {name: "Rettungsdienst (Medic)", sub: "medic"}
          , {name: "Feuerwehr", sub: "medic"}, {name: "Presse / San News", sub: "news"}
          , {name: "Regierung", sub: "regierung"}, {name: "Andere Behörde", sub: "polizei"}]
}

BkProf_Jobs() {
    return [{id: "",          name: "Kein Job"}
          , {id: "anwalt",    name: "Anwalt"}
          , {id: "detektiv",  name: "Detektiv"}
          , {id: "dealer",    name: "Drogendealer"}
          , {id: "waffen",    name: "Waffendealer"}
          , {id: "mechaniker",name: "Mechaniker"}
          , {id: "pizza",     name: "Pizzalieferant"}
          , {id: "taxi",      name: "Taxifahrer"}
          , {id: "bus",       name: "Busfahrer"}
          , {id: "trucker",   name: "Trucker"}
          , {id: "hure",      name: "Hure / Escort"}
          , {id: "bodyguard", name: "Bodyguard"}
          , {id: "fischer",   name: "Fischer"}
          , {id: "hitman",    name: "Auftragskiller"}]
}

BkProf_JobName(id) {
    for i, j in BkProf_Jobs()
        if (j.id = id)
            return j.name
    return "Kein Job"
}

BkProf_StateSub(name) {
    for i, s in BkProf_States()
        if (s.name = name)
            return s.sub
    return "polizei"
}

; ---------------------------------------------------------------------
;  Gruppen. vis: wer die Gruppe bekommt
;    all | zivi | gang | staat | staat:<unterart> | job:<id>
; ---------------------------------------------------------------------
BkGroups() {
    static g := ""
    if (IsObject(g))
        return g
    g := []
    g.Push({id: "system",   name: "Keybinder",               vis: "all",        icon: "E713"})
    g.Push({id: "allg",     name: "Allgemein",               vis: "all",        icon: "E80F"})
    g.Push({id: "fahrzeug", name: "Fahrzeug",                vis: "all",        icon: "E804"})
    g.Push({id: "sprueche", name: "Sprüche & RP",           vis: "all",        icon: "E8BD"})
    g.Push({id: "werbung",  name: "Werbung (/ad)",           vis: "all",        icon: "E789"})
    g.Push({id: "info",     name: "Infos (nur für dich)",   vis: "all",        icon: "E946"})
    g.Push({id: "eigene",   name: "Eigene Befehle",          vis: "all",        icon: "E70F"})
    g.Push({id: "stats",    name: "Kills & Statistik",       vis: "all",        icon: "E9D2"})
    g.Push({id: "waffen",   name: "Waffen kaufen",           vis: "zivi,gang",  icon: "E7C1"})
    g.Push({id: "drogen",   name: "Drogen",                  vis: "zivi,gang",  icon: "E95E"})
    g.Push({id: "wanted",   name: "Wanted & Knast",          vis: "zivi,gang",  icon: "E72E"})
    g.Push({id: "fraktion", name: "Fraktionschat (/f)",      vis: "gang,staat", icon: "E716"})
    g.Push({id: "gang",     name: "Gang",                    vis: "gang",       icon: "E7EE"})
    g.Push({id: "gangchat", name: "Gangchat (/g)",           vis: "gang",       icon: "E8F2"})
    g.Push({id: "gegner",   name: "Gegnerlisten",            vis: "gang",       icon: "E8B7"})
    g.Push({id: "staat",    name: "Staat: Funk & Einsatz",   vis: "staat",      icon: "E7E8"})
    g.Push({id: "polizei",  name: "Staat: Polizei",          vis: "staat:polizei", icon: "E72E"})
    g.Push({id: "medic",    name: "Staat: Rettungsdienst",   vis: "staat:medic",   icon: "E95E"})
    g.Push({id: "news",     name: "Staat: Presse",           vis: "staat:news",    icon: "E789"})
    g.Push({id: "regierung",name: "Staat: Regierung",        vis: "staat:regierung", icon: "E80F"})
    g.Push({id: "stadtplan",name: "Stadtplan (/map)",        vis: "all",        icon: "E707"})
    for i, j in BkProf_Jobs() {
        if (j.id != "")
            g.Push({id: "job_" . j.id, name: "Job: " . j.name, vis: "job:" . j.id, icon: "E821"})
    }
    return g
}

BkGroup(id) {
    for i, g in BkGroups()
        if (g.id = id)
            return g
    return ""
}

BkGroupName(id) {
    g := BkGroup(id)
    return IsObject(g) ? g.name : id
}

; Ist die Gruppe fuer das aktuelle Profil aktiv?
BkGroupActive(id) {
    global BK_ProfType, BK_ProfFaction, BK_ProfJob
    g := BkGroup(id)
    if (!IsObject(g))
        return true
    sub := (BK_ProfType = "staat") ? BkProf_StateSub(BK_ProfFaction) : ""
    for i, t in StrSplit(g.vis, ",") {
        t := Trim(t)
        if (t = "all")
            return true
        if (t = BK_ProfType)
            return true
        if (BK_ProfType = "staat" && t = "staat:" . sub)
            return true
        if (BK_ProfJob != "" && t = "job:" . BK_ProfJob)
            return true
    }
    return false
}

; ---------------------------------------------------------------------
;  TASTEN-BINDS
; ---------------------------------------------------------------------
BkB(id, grp, label, type, text := "", fn := "", arg := "") {
    return {id: id, grp: grp, label: label, type: type, text: text, fn: fn, arg: arg}
}

BkHotkeyDB() {
    static d := ""
    if (IsObject(d))
        return d
    d := []
    ; ---- Keybinder ----
    d.Push(BkB("hk121", "system", "Keybinder pausieren / fortsetzen", "fn", "", "BkFn_TogglePause"))
    d.Push(BkB("sys_reload", "system", "Keybinder neu starten", "fn", "", "BkFn_Reload"))
    d.Push(BkB("sys_gui", "system", "Keybinder-Fenster öffnen", "fn", "", "BkFn_ShowGui"))
    d.Push(BkB("sys_ov", "system", "Overlay ein-/ausblenden", "fn", "", "BkFn_ToggleOverlay"))
    d.Push(BkB("sys_panic", "system", "Hängende Tasten lösen", "fn", "", "BkFn_Panic"))
    ; ---- Allgemein ----
    d.Push(BkB("hk1",  "allg", "Login-/Logout-Meldungen an/aus", "send", "/togloginlogout"))
    d.Push(BkB("hk9",  "allg", "Statistik anzeigen", "send", "/stats"))
    d.Push(BkB("hk10", "allg", "Heilen und Gebäude verlassen", "send", "/heal`n/exit"))
    d.Push(BkB("hk12", "allg", "Heilen", "send", "/heal"))
    d.Push(BkB("hk11", "allg", "Spawn wechseln", "send", "/spawnchange"))
    d.Push(BkB("hk15", "allg", "Betreten / Verlassen (automatisch)", "fn", "/enter|/exit", "BkFn_EnterExit"))
    d.Push(BkB("hk18", "allg", "Eigene Finanzen", "send", "/finances {id}"))
    d.Push(BkB("hk115","allg", "Finanzen von ... (ID eintippen)", "prefill", "/finances "))
    d.Push(BkB("hk19", "allg", "Uhrzeit", "send", "/time"))
    d.Push(BkB("hk24", "allg", "Zahlungsart wechseln", "send", "/changepayment"))
    d.Push(BkB("hk25", "allg", "Letztes Angebot annehmen (/accept ...)", "fn", "", "BkFn_AcceptLast"))
    d.Push(BkB("hk6",  "allg", "Donut essen", "send", "/eatdonut"))
    d.Push(BkB("hk26", "allg", "Pizza essen", "send", "/eatpizza"))
    d.Push(BkB("hk31", "allg", "Zimmer mieten", "send", "/rentroom"))
    d.Push(BkB("hk106","allg", "Bezahlen (/pay)", "prefill", "/pay "))
    d.Push(BkB("hk112","allg", "99.999 $ bezahlen (/pay ID 99999)", "prefill", "/pay {cursor} 99999"))
    d.Push(BkB("hk107","allg", "Telefonnummer suchen (/number)", "prefill", "/number "))
    d.Push(BkB("hk108","allg", "Anwesenheit bestätigen (/notafk)", "prefill", "/notafk "))
    d.Push(BkB("hk110","allg", "Spieler-ID suchen (/id)", "prefill", "/id "))
    d.Push(BkB("hk113","allg", "Scheck geben (/givecheck)", "prefill", "/givecheck "))
    d.Push(BkB("hk114","allg", "Aimbottest (ID mit /aim festlegen)", "send", "/aimbottest {aimid}"))
    d.Push(BkB("hk81", "allg", "Letzte Chatzeile wiederholen", "fn", "", "BkFn_Repeat"))
    d.Push(BkB("hk33", "allg", "FPS-Limit 20", "send", "/fpslimit 20"))
    d.Push(BkB("hk34", "allg", "FPS-Limit 48", "send", "/fpslimit 48"))
    d.Push(BkB("hk117","allg", "FPS-Limit 60", "send", "/fpslimit 60"))
    d.Push(BkB("hk35", "allg", "FPS-Limit 90", "send", "/fpslimit 90"))
    d.Push(BkB("hk36", "allg", "Hure: Angebot annehmen und /sex", "fn", "", "BkFn_AcceptSex"))
    ; ---- Fahrzeug ----
    d.Push(BkB("hk2",  "fahrzeug", "Motor an/aus", "send", "/engine"))
    d.Push(BkB("hk3",  "fahrzeug", "Abschließen (/lock)", "send", "/lock"))
    d.Push(BkB("hk5",  "fahrzeug", "Auto abschließen (/carlock)", "send", "/carlock"))
    d.Push(BkB("hk4",  "fahrzeug", "Licht an/aus", "send", "/lights"))
    d.Push(BkB("hk20", "fahrzeug", "Fahrzeug-Tür / DL (/dl)", "send", "/dl"))
    d.Push(BkB("hk21", "fahrzeug", "Auto betanken (/fillcar)", "send", "/fillcar"))
    d.Push(BkB("hk22", "fahrzeug", "Benzinkanister holen", "send", "/get fuel"))
    d.Push(BkB("hk23", "fahrzeug", "Tanken (/fill)", "send", "/fill"))
    d.Push(BkB("hk29", "fahrzeug", "Fahrzeug reparieren (/fixcar)", "send", "/fixcar"))
    d.Push(BkB("hk109","fahrzeug", "Mitfahrer rauswerfen (/eject)", "prefill", "/eject "))
    d.Push(BkB("hk77", "fahrzeug", "Fahrzeugzustand anzeigen", "local", "Zustand des Fahrzeugs: {fzhp}  ·  {fahrzeug}"))
    ; ---- Sprueche & RP ----
    d.Push(BkB("hk67", "sprueche", "Vielen Dank!", "send", "Vielen Dank!"))
    d.Push(BkB("hk69", "sprueche", "Alles klar.", "send", "Alles klar."))
    d.Push(BkB("hk70", "sprueche", "Kein Problem.", "send", "Kein Problem."))
    d.Push(BkB("hk71", "sprueche", "Schönen Morgen/Tag/Abend/Nacht (nach Uhrzeit)", "fn", "", "BkFn_Greeting"))
    d.Push(BkB("hk76", "sprueche", "Guten Tag, was kann ich für Sie tun?", "send", "Guten Tag, was kann ich für Sie tun?"))
    d.Push(BkB("hk83", "sprueche", "Um Heilung bitten", "send", "Erbitte um eine Heilung, Herr Doktor."))
    d.Push(BkB("hk72", "sprueche", "Eigene HP ansagen", "send", "Ich habe derzeit {hp} HP"))
    d.Push(BkB("hk118","sprueche", "Geld dabei ansagen", "send", "Ich habe derzeit {geld} $ dabei."))
    d.Push(BkB("hk74", "sprueche", "Fisch essen (/me, zufällig)", "fn", "", "BkFn_Fish"))
    d.Push(BkB("hk97", "sprueche", "Spruch 1 (/s)", "send", "/s {spruch1}"))
    d.Push(BkB("hk98", "sprueche", "Spruch 2 (/s)", "send", "/s {spruch2}"))
    d.Push(BkB("hk99", "sprueche", "Spruch 3 (/s)", "send", "/s {spruch3}"))
    d.Push(BkB("hk100","sprueche", "Spruch 4 (/s)", "send", "/s {spruch4}"))
    d.Push(BkB("hk101","sprueche", "Spruch 5 (/s)", "send", "/s {spruch5}"))
    d.Push(BkB("hk102","sprueche", "Spruch 6 (/s)", "send", "/s {spruch6}"))
    d.Push(BkB("hk78", "sprueche", "Zufälliger Spruch (1-4)", "fn", "", "BkFn_RandomSpruch"))
    d.Push(BkB("hk119","sprueche", "CPU-Auslastung ansagen (/b)", "send", "/b Aktuelle CPU-Auslastung: {cpu} Prozent"))
    ; ---- Werbung ----
    d.Push(BkB("hk104","werbung", "Member-Werbung", "send", "/ad {memberad}"))
    d.Push(BkB("hk103","werbung", "Orgmember-Werbung", "send", "/ad {orgad}"))
    d.Push(BkB("hk105","werbung", "Sonstige Werbung", "send", "/ad {sonstad}"))
    ; ---- Infos nur fuer dich ----
    d.Push(BkB("hk79", "info", "Aktuelle HP anzeigen", "local", "Aktuelle HP: {hp}  ·  Rüstung: {armor}"))
    d.Push(BkB("hk82", "info", "HP, ID, Geld und Wanteds anzeigen", "local", "HP: {hp}  ·  ID: {id}  ·  Geld: {geld} $  ·  Wanteds: {wanteds}"))
    d.Push(BkB("hk75", "info", "15 Sekunden Countdown", "fn", "15", "BkFn_Countdown"))
    d.Push(BkB("hk73", "info", "Chat ein-/ausblenden (F7)", "fn", "", "BkFn_ChatToggle"))
    ; ---- Eigene Befehle ----
    Loop, 12
        d.Push(BkB("hk" . (84 + A_Index), "eigene", "Eigener Befehl " . A_Index, "send", ""))
    ; ---- Kills & Statistik ----
    d.Push(BkB("hk37", "stats", "Gangwar-Kill zählen und melden", "fn", "gw", "BkFn_Kill"))
    d.Push(BkB("hk38", "stats", "Gangzone-Kill zählen und melden", "fn", "gz", "BkFn_Kill"))
    d.Push(BkB("st_death", "stats", "Tod von Hand zählen", "fn", "", "BkFn_DeathManual"))
    ; ---- Waffen ----
    d.Push(BkB("hk62", "waffen", "Deagle kaufen", "send", "/buygun deagle {mun_deagle}"))
    d.Push(BkB("hk61", "waffen", "Shotgun kaufen", "send", "/buygun shotgun {mun_shotgun}"))
    d.Push(BkB("hk63", "waffen", "M4 kaufen", "send", "/buygun m4 {mun_m4}"))
    d.Push(BkB("hk64", "waffen", "MP5 kaufen", "send", "/buygun mp5 {mun_mp5}"))
    d.Push(BkB("hk65", "waffen", "Sniper kaufen", "send", "/buygun sniper {mun_sniper}"))
    d.Push(BkB("hk66", "waffen", "Rifle kaufen", "send", "/buygun rifle {mun_rifle}"))
    d.Push(BkB("hk122","waffen", "Waffenpaket 1 kaufen", "fn", "1", "BkFn_WeaponPack"))
    d.Push(BkB("hk123","waffen", "Waffenpaket 2 kaufen", "fn", "2", "BkFn_WeaponPack"))
    d.Push(BkB("hk16", "waffen", "Waffenpaket 3 kaufen", "fn", "3", "BkFn_WeaponPack"))
    ; ---- Drogen ----
    d.Push(BkB("hk7",  "drogen", "Drogen annehmen", "send", "/accept drugs"))
    d.Push(BkB("hk13", "drogen", "Drogen nehmen", "send", "/usedrugs"))
    d.Push(BkB("hk116","drogen", "Drogen nehmen (zweite Taste)", "send", "/usedrugs"))
    d.Push(BkB("hk84", "drogen", "Drogenzähler ansagen", "send", "Maximal noch {drogenrest}x Drogen nehmen!"))
    ; ---- Wanted & Knast ----
    d.Push(BkB("hk80", "wanted", "Letztes Verbrechen + Wantedlevel sagen", "send", "Letztes Verbrechen wegen: [{verbrechen}] Zeuge: [{zeuge}]`nNeues Wantedlevel: {wantedlevel}"))
    d.Push(BkB("hk59", "wanted", "Anwalt suchen (/s)", "send", "/s Suche Anwalt - zahle am ATM - Meine ID: {id}"))
    d.Push(BkB("hk60", "wanted", "Ort des Gesuchten (/b)", "fn", "/b", "BkFn_FindResult"))
    ; ---- Fraktionschat ----
    d.Push(BkB("hk50", "fraktion", "Fraktionschat öffnen", "prefill", "{fchat} "))
    d.Push(BkB("hk44", "fraktion", "Mein Standort", "send", "{fchat} Ich befinde mich derzeit in {zone}"))
    d.Push(BkB("hk45", "fraktion", "Brauche dringend Verstärkung", "send", "{fchat} Brauche dringend Verstärkung in {zone}"))
    d.Push(BkB("hk43", "fraktion", "Verstärkung ist unterwegs", "send", "{fchat} Verstärkung ist unterwegs! - Mein Standort: {zone}"))
    d.Push(BkB("hk48", "fraktion", "Verstärkung ist angekommen", "send", "{fchat} Verstärkung ist soeben in {zone} angekommen"))
    d.Push(BkB("hk46", "fraktion", "Keine Verstärkung mehr nötig", "send", "{fchat} Keine Verstärkung mehr in {zone} notwendig"))
    d.Push(BkB("hk47", "fraktion", "Wo wird Unterstützung gebraucht?", "send", "{fchat} Wo wird Unterstützung benötigt? Mein Standort: {zone}"))
    d.Push(BkB("hk39", "fraktion", "Stehe unter Beschuss (+ HP)", "send", "{fchat} Ich stehe unter Beschuss in {zone} - Meine HP: {hp}"))
    d.Push(BkB("hk41", "fraktion", "HP und Ort", "send", "{fchat} Ich habe noch {hp} HP in {ort}"))
    d.Push(BkB("hk42", "fraktion", "INCOMING!", "send", "{fchat} > ACHTUNG!! || INCOMING INCOMING INCOMING || ACHTUNG!! <"))
    d.Push(BkB("hk40", "fraktion", "Verbrechen + Wantedlevel melden", "send", "{fchat} Letztes Verbrechen wegen: [{verbrechen}] Zeuge: [{zeuge}]`n{fchat} Neues Wantedlevel: {wantedlevel}"))
    d.Push(BkB("hk49", "fraktion", "Ort des Gesuchten melden", "fn", "{fchat}", "BkFn_FindResult"))
    d.Push(BkB("hk17", "fraktion", "Members online zählen", "fn", "", "BkFn_Members"))
    ; ---- Gang ----
    d.Push(BkB("hk8",  "gang", "Drogen aus der Gangbox nehmen", "send", "/gtake drugs {drogenbox}"))
    d.Push(BkB("hk30", "gang", "Orgmember online zählen", "fn", "", "BkFn_OrgMembers"))
    d.Push(BkB("hk32", "gang", "Gebietsinfo", "send", "/gebietinfo"))
    d.Push(BkB("hk124","gang", "Cargo", "send", "/cargo"))
    d.Push(BkB("hk125","gang", "Cargo öffnen", "send", "/opencargo"))
    d.Push(BkB("hk126","gang", "Cargo aufbrechen", "send", "/breakcargo"))
    d.Push(BkB("hk27", "gang", "Kidnap (Opfer + Partner, 0)", "send", "/kidnap {opfer} {partner} 0"))
    d.Push(BkB("hk28", "gang", "Kidnap (Opfer + Partner, 1)", "send", "/kidnap {opfer} {partner} 1"))
    ; ---- Gangchat ----
    d.Push(BkB("hk58", "gangchat", "Gangchat öffnen", "prefill", "{gchat} "))
    d.Push(BkB("hk54", "gangchat", "Mein Standort", "send", "{gchat} Ich befinde mich derzeit in {zone}"))
    d.Push(BkB("hk55", "gangchat", "Brauche dringend Verstärkung", "send", "{gchat} Brauche dringend Verstärkung in {zone}"))
    d.Push(BkB("hk53", "gangchat", "Verstärkung ist unterwegs", "send", "{gchat} Verstärkung ist unterwegs! - Mein Standort: {zone}"))
    d.Push(BkB("hk57", "gangchat", "Verstärkung ist angekommen", "send", "{gchat} Verstärkung ist soeben in {zone} angekommen"))
    d.Push(BkB("hk56", "gangchat", "Keine Verstärkung mehr nötig", "send", "{gchat} Keine Verstärkung mehr in {zone} notwendig"))
    d.Push(BkB("hk51", "gangchat", "Anwalt suchen", "send", "{gchat} Suche Anwalt im LSPD - Meine ID: {id}"))
    d.Push(BkB("hk52", "gangchat", "Ort des Gesuchten melden", "fn", "{gchat}", "BkFn_FindResult"))
    d.Push(BkB("hk120","gangchat", "Jemanden suchen lassen (Find:)", "prefill", "{gchat} Find: "))
    ; ---- Staat: Funk & Einsatz ----
    d.Push(BkB("st1",  "staat", "Dienst an/aus", "send", "/duty"))
    d.Push(BkB("st2",  "staat", "Funk öffnen", "prefill", "{funk} "))
    d.Push(BkB("st3",  "staat", "Department-Funk öffnen", "prefill", "{dchat} "))
    d.Push(BkB("st4",  "staat", "Funk: Mein Standort", "send", "{funk} Mein Standort: {zone}"))
    d.Push(BkB("st5",  "staat", "Funk: Brauche Verstärkung", "send", "{funk} Benötige dringend Verstärkung in {zone}! HP: {hp}"))
    d.Push(BkB("st6",  "staat", "Funk: Bin unterwegs", "send", "{funk} Verstärkung ist unterwegs - Standort: {zone}"))
    d.Push(BkB("st7",  "staat", "Funk: Vor Ort angekommen", "send", "{funk} Bin vor Ort in {zone} angekommen."))
    d.Push(BkB("st8",  "staat", "Funk: Lage unter Kontrolle (Code 4)", "send", "{funk} Code 4 - Lage in {zone} unter Kontrolle."))
    d.Push(BkB("st9",  "staat", "Funk: Stehe unter Beschuss", "send", "{funk} Stehe unter Beschuss in {zone}! HP: {hp}"))
    d.Push(BkB("st10", "staat", "Department: Verstärkung angefordert", "send", "{dchat} Verstärkung angefordert in {zone}."))
    d.Push(BkB("st11", "staat", "Mitglieder im Dienst", "send", "/members"))
    ; ---- Staat: Polizei ----
    d.Push(BkB("po1",  "polizei", "Megafon: Anhalten!", "send", "/m Hier spricht die Polizei! Halten Sie sofort an!"))
    d.Push(BkB("po2",  "polizei", "Megafon: Rechts ranfahren", "send", "/m Fahren Sie rechts ran und stellen Sie den Motor ab!"))
    d.Push(BkB("po3",  "polizei", "Megafon: Aussteigen, Hände hoch", "send", "/m Steigen Sie aus dem Fahrzeug und nehmen Sie die Hände hoch!"))
    d.Push(BkB("po4",  "polizei", "Megafon: Letzte Warnung", "send", "/m Letzte Warnung! Andernfalls wenden wir Gewalt an!"))
    d.Push(BkB("po5",  "polizei", "Fahndung ausschreiben (/su)", "prefill", "/su "))
    d.Push(BkB("po6",  "polizei", "Handschellen anlegen (/cuff)", "prefill", "/cuff "))
    d.Push(BkB("po7",  "polizei", "Handschellen abnehmen (/uncuff)", "prefill", "/uncuff "))
    d.Push(BkB("po8",  "polizei", "Durchsuchen (/frisk)", "prefill", "/frisk "))
    d.Push(BkB("po9",  "polizei", "Abnehmen (/take)", "prefill", "/take "))
    d.Push(BkB("po10", "polizei", "Strafzettel (/ticket)", "prefill", "/ticket "))
    d.Push(BkB("po11", "polizei", "Einsperren (/arrest)", "prefill", "/arrest "))
    d.Push(BkB("po12", "polizei", "Wantedliste (/wanteds)", "send", "/wanteds"))
    d.Push(BkB("po13", "polizei", "Ausweis zeigen lassen", "send", "Guten Tag, allgemeine Verkehrskontrolle. Ihren Ausweis und Führerschein bitte."))
    ; ---- Staat: Rettungsdienst ----
    d.Push(BkB("me1",  "medic", "Patient heilen (/heal ID Preis)", "prefill", "/heal "))
    d.Push(BkB("me2",  "medic", "Begrüßung Patient", "send", "Guten Tag, Rettungsdienst. Wo haben Sie Schmerzen?"))
    d.Push(BkB("me3",  "medic", "Behandlung beendet", "send", "Die Behandlung ist abgeschlossen. Gute Besserung!"))
    d.Push(BkB("me4",  "medic", "Funk: Einsatz übernommen", "send", "{funk} Übernehme den Einsatz - Standort: {zone}"))
    ; ---- Staat: Presse ----
    d.Push(BkB("ne1",  "news", "Nachricht senden (/news)", "prefill", "/news "))
    d.Push(BkB("ne2",  "news", "Live-Sendung ankündigen", "send", "/news Gleich live: Interview bei San News - bleiben Sie dran!"))
    ; ---- Staat: Regierung ----
    d.Push(BkB("re1",  "regierung", "Regierungsansage (/gov)", "prefill", "/gov "))
    ; ---- Jobs ----
    d.Push(BkB("hk14", "job_pizza", "Pizzen aufnehmen (3x /takepizza)", "send", "/takepizza`n/takepizza`n/takepizza"))
    d.Push(BkB("hk111","job_pizza", "Pizza verkaufen (/sellpizza)", "prefill", "/sellpizza "))
    d.Push(BkB("jp1",  "job_pizza", "Pizza an Partner verkaufen", "send", "/sellpizza {partner}"))
    d.Push(BkB("hk68", "job_taxi",  "Wo soll ich dich absetzen?", "send", "Wo soll ich dich absetzen?"))
    d.Push(BkB("jt1",  "job_taxi",  "Fahrpreis festlegen (/fare)", "prefill", "/fare "))
    d.Push(BkB("jt2",  "job_taxi",  "Begrüßung Fahrgast", "send", "Guten Tag, willkommen im Taxi! Wohin darf es gehen?"))
    d.Push(BkB("jt3",  "job_taxi",  "Angekommen", "send", "Wir sind da. Vielen Dank für die Fahrt und einen schönen Tag!"))
    d.Push(BkB("jb1",  "job_bus",   "Busfahrt starten", "send", "/startbus"))
    d.Push(BkB("jb2",  "job_bus",   "Durchsage nächster Halt", "send", "Nächster Halt: {zone}. Bitte festhalten!"))
    d.Push(BkB("jm1",  "job_mechaniker", "Reparatur anbieten (/repair)", "prefill", "/repair "))
    d.Push(BkB("jm2",  "job_mechaniker", "Tanken anbieten (/refill)", "prefill", "/refill "))
    d.Push(BkB("jm3",  "job_mechaniker", "Werbung Mechaniker", "send", "/ad Mechaniker unterwegs - Reparatur & Tanken zum fairen Preis! Anruf genügt."))
    d.Push(BkB("ja1",  "job_anwalt","Freilassen (/free)", "prefill", "/free "))
    d.Push(BkB("ja2",  "job_anwalt","Anwalt anbieten", "send", "/s Anwalt verfügbar - Freilassung zum fairen Preis!"))
    d.Push(BkB("jd1",  "job_detektiv","Spieler suchen (/find)", "prefill", "/find "))
    d.Push(BkB("jd2",  "job_detektiv","Suchergebnis im Fraktionschat", "fn", "{fchat}", "BkFn_FindResult"))
    d.Push(BkB("jr1",  "job_dealer","Drogen verkaufen (/selldrugs)", "prefill", "/selldrugs "))
    d.Push(BkB("jr2",  "job_dealer","Drogen einlagern (/put drugs)", "prefill", "/put drugs "))
    d.Push(BkB("jw1",  "job_waffen","Waffe verkaufen (/sellgun)", "prefill", "/sellgun "))
    d.Push(BkB("jw2",  "job_waffen","Werbung Waffendealer", "send", "/ad Verkaufe Waffen - Anruf oder SMS genügt!"))
    d.Push(BkB("jk1",  "job_trucker","Ladung holen (/load)", "send", "/load"))
    d.Push(BkB("jk2",  "job_trucker","Ladung abliefern (/unload)", "send", "/unload"))
    d.Push(BkB("jh1",  "job_hure",  "Sex anbieten (/sex ID Preis)", "prefill", "/sex {cursor} 1"))
    d.Push(BkB("jg1",  "job_bodyguard","Schutz anbieten (/guard)", "prefill", "/guard "))
    d.Push(BkB("jf1",  "job_fischer","Angeln (/fish)", "send", "/fish"))
    d.Push(BkB("jf2",  "job_fischer","Fische verkaufen (/sellfish)", "send", "/sellfish"))
    d.Push(BkB("jx1",  "job_hitman","Auftrag annehmen (/contract)", "prefill", "/contract {cursor} {conpreis}"))
    return d
}

; ---------------------------------------------------------------------
;  CHAT-BEFEHLE (Textbinds) - im Chat tippen, mit Enter ausfuehren
; ---------------------------------------------------------------------
BkT(cmd, grp, label, type, text := "", fn := "", arg := "") {
    return {id: "tb:" . cmd, cmd: cmd, grp: grp, label: label, type: type, text: text, fn: fn, arg: arg}
}

BkTextDB() {
    static d := ""
    if (IsObject(d))
        return d
    d := []
    ; ---- Keybinder / Infos ----
    d.Push(BkT("/bkhilfe", "system", "Befehlsübersicht im Keybinder öffnen", "fn", "", "BkFn_ShowGui"))
    d.Push(BkT("/otime", "info", "Deine Spielzeit anzeigen", "local", "Du hast schon {spielzeit} gespielt (heute {spielzeitheute})."))
    d.Push(BkT("/rentinfo", "info", "Seit wann du das Rentcar hast", "local", "Rentcar gemietet seit: {rentinfo}"))
    d.Push(BkT("/afk", "info", "Letzte AFK-Meldung", "local", "Letzte Anwesenheits-Bestätigung: {afkzeit}"))
    d.Push(BkT("/adinfo", "info", "Deine Werbetexte anzeigen", "local", "Member-AD: {memberad}`nOrgmember-AD: {orgad}`nSonstige AD: {sonstad}"))
    d.Push(BkT("/napinfo", "info", "Kidnap-Partner und Opfer anzeigen", "local", "Opfer: {opfername} ({opfer})  ·  Partner: {partnername} ({partner})"))
    d.Push(BkT("/ptime", "info", "Restliche Haftzeit anzeigen", "fn", "", "BkFn_PrisonTime"))
    d.Push(BkT("/chillen", "info", "AFK-Erinnerung nach 10 Minuten", "fn", "10", "BkFn_Chillen"))
    d.Push(BkT("/dd", "drogen", "Drogenzähler zurücksetzen", "fn", "", "BkFn_DrugReset"))
    d.Push(BkT("/aim", "allg", "ID für den Aimbottest festlegen", "fn", "aim", "BkFn_Prompt"))
    d.Push(BkT("/zeit", "allg", "Sekunden in Minuten umrechnen", "fn", "zeit", "BkFn_Prompt"))
    d.Push(BkT("/conpreis", "job_hitman", "Contract-Preis festlegen", "fn", "conpreis", "BkFn_Prompt"))
    ; ---- Statistik ----
    d.Push(BkT("/infokill", "stats", "Kills/Tode gesamt, heute, Monat (sagen)", "send", "Gesamt: Kills: {kills} - Tode: {tode} - Differenz: {diff} - KD: {kd}`nHeute: Kills: {dkills} - Tode: {dtode} - Differenz: {ddiff} - KD: {dkd}`n{monat}: Kills: {mkills} - Tode: {mtode} - Differenz: {mdiff} - KD: {mkd}"))
    d.Push(BkT("/kd", "stats", "KD im Fraktionschat", "send", "{fchat} » Kills: {kills} - Differenz: {diff} Kills - KD: {kd} «"))
    d.Push(BkT("/bkd", "stats", "KD sagen", "send", "» Kills: {kills} - Differenz: {diff} Kills - KD: {kd} «"))
    d.Push(BkT("/gkd", "stats", "KD im Gangchat", "send", "{gchat} » Kills: {kills} - Differenz: {diff} Kills - KD: {kd} «"))
    d.Push(BkT("/kills", "stats", "Kills im Fraktionschat", "send", "{fchat} Aktuelle Kills: {kills}"))
    d.Push(BkT("/tode", "stats", "Tode anzeigen", "local", "Aktuelle Todesanzahl: {tode}"))
    d.Push(BkT("/dkills", "stats", "Kills von heute (/f)", "send", "{fchat} Meine Kills von heute: {dkills} Kills"))
    d.Push(BkT("/dkd", "stats", "KD von heute (/f)", "send", "{fchat} » Kills heute: {dkills} - Differenz: {ddiff} Kills - KD: {dkd} «"))
    d.Push(BkT("/gdkd", "stats", "KD von heute (/g)", "send", "{gchat} » Kills heute: {dkills} - Differenz: {ddiff} Kills - KD: {dkd} «"))
    d.Push(BkT("/bdkd", "stats", "KD von heute sagen", "send", "» Kills heute: {dkills} - Differenz: {ddiff} Kills - KD: {dkd} «"))
    d.Push(BkT("/mkills", "stats", "Kills im Monat (/f)", "send", "{fchat} Gesamte Kills im {monatjahr}: {mkills} Kills"))
    d.Push(BkT("/mkd", "stats", "KD vom Monat (/f)", "send", "{fchat} » Kills im {monat}: {mkills} - Differenz: {mdiff} Kills - KD: {mkd} «"))
    d.Push(BkT("/bmkd", "stats", "KD vom Monat sagen", "send", "» Kills im {monat}: {mkills} - Differenz: {mdiff} Kills - KD: {mkd} «"))
    d.Push(BkT("/gmkd", "stats", "KD vom Monat (/g)", "send", "{gchat} » Kills im {monat}: {mkills} - Differenz: {mdiff} Kills - KD: {mkd} «"))
    d.Push(BkT("/down", "stats", "1 Tod hinzuzählen", "fn", "+", "BkFn_StatAdjust", "tode"))
    d.Push(BkT("/cleartod", "stats", "1 Tod abziehen", "fn", "-", "BkFn_StatAdjust", "tode"))
    d.Push(BkT("/clearkill", "stats", "1 Kill abziehen", "fn", "-", "BkFn_StatAdjust", "kills"))
    d.Push(BkT("/setkills", "stats", "Kills gesamt festlegen", "fn", "setkills", "BkFn_Prompt"))
    d.Push(BkT("/settode", "stats", "Tode gesamt festlegen", "fn", "settode", "BkFn_Prompt"))
    d.Push(BkT("/payinfo", "stats", "Einnahmen/Ausgaben heute sagen", "send", "Einnahmen heute: {einnahmenheute}$`nAusgaben heute: {ausgabenheute}$`nDifferenz heute: {geldheute}$"))
    d.Push(BkT("/zinsinfo", "stats", "Zinsen heute/gesamt sagen", "send", "Zinsen heute: {zinsenheute}$`nZinsen gesamt: {zinsengesamt}$"))
    d.Push(BkT("/kstand", "stats", "Gesamtvermögen und Level sagen", "fn", "", "BkFn_Kontostand"))
    d.Push(BkT("/on", "stats", "Letztes Login sagen", "send", "Letztes Login: {login}"))
    d.Push(BkT("/gon", "stats", "Letztes Login (/g)", "send", "{gchat} Letztes Login: {login}"))
    d.Push(BkT("/fon", "stats", "Letztes Login (/f)", "send", "{fchat} Letztes Login: {login}"))
    ; ---- Allgemein ----
    d.Push(BkT("/cp", "allg", "/changepayment", "send", "/changepayment"))
    d.Push(BkT("/cr", "allg", "/creditinfo", "send", "/creditinfo"))
    d.Push(BkT("/ping", "allg", "Aktuellen Ping sagen", "send", "Aktueller Ping: {ping}"))
    d.Push(BkT("/aa", "allg", "Letztes Angebot annehmen", "fn", "", "BkFn_AcceptLast"))
    d.Push(BkT("/ar", "allg", "Tanken + Reparatur annehmen", "send", "/accept refill`n/accept repair"))
    d.Push(BkT("/as", "allg", "Sex-Angebot annehmen", "send", "/accept sex"))
    d.Push(BkT("/sex", "allg", "/sex ID 1 vorbereiten", "prefill", "/sex {cursor} 1"))
    d.Push(BkT("/handy", "allg", "Handy an/aus", "send", "/togphone"))
    d.Push(BkT("/sc", "allg", "/spawnchange", "send", "/spawnchange"))
    d.Push(BkT("/e1", "allg", "/eat 1", "send", "/eat 1"))
    d.Push(BkT("/e2", "allg", "/eat 2", "send", "/eat 2"))
    d.Push(BkT("/e3", "allg", "/eat 3", "send", "/eat 3"))
    d.Push(BkT("/e4", "allg", "/eat 4", "send", "/eat 4"))
    d.Push(BkT("/e5", "allg", "/eat 5", "send", "/eat 5"))
    d.Push(BkT("/ed", "allg", "/eatdonut", "send", "/eatdonut"))
    d.Push(BkT("/gd", "allg", "/givedonut vorbereiten", "prefill", "/givedonut "))
    d.Push(BkT("/ep", "allg", "/eatpizza", "send", "/eatpizza"))
    d.Push(BkT("/dice3", "allg", "Dreimal würfeln", "send", "/dice`n/dice`n/dice"))
    d.Push(BkT("/mi", "allg", "/mission info", "send", "/mission info"))
    d.Push(BkT("/mb", "allg", "/mission begin", "send", "/mission begin"))
    d.Push(BkT("/ms", "allg", "/mission start", "send", "/mission start"))
    d.Push(BkT("/mend", "allg", "/mission end", "send", "/mission end"))
    d.Push(BkT("/mms", "allg", "SMS an Spieler-ID (Nummer wird gesucht)", "fn", "mms", "BkFn_Prompt"))
    d.Push(BkT("/re", "allg", "Auf letzte SMS antworten", "prefill", "/sms {letztesms} "))
    d.Push(BkT("/n", "allg", "SMS an letzte Nummer", "prefill", "/sms {letztesms} "))
    d.Push(BkT("/adre", "allg", "SMS an die letzte Werbung", "prefill", "/sms {adnummer} "))
    d.Push(BkT("/ab", "allg", "Anrufbeantworter", "send", "/p`nHallo. Hier ist die Mailbox von {name}.`nZurzeit hab ich leider keine Zeit für Sie.`n{sleep 1100}`nBitte versuchen Sie es später nochmal oder schreiben Sie mir eine SMS.`nWir riechen uns später, bis dann.`n/h"))
    d.Push(BkT("/null", "allg", "Wer hat die 0 gewählt?", "send", "Hat hier jemand die 0 gewaehlt oder warum meldest du dich zu Wort?"))
    d.Push(BkT("/bja", "allg", "Positiv", "send", "Positiv"))
    d.Push(BkT("/bnein", "allg", "Negativ", "send", "Negativ"))
    d.Push(BkT("/neg", "allg", "Negativ Sir", "send", "Negativ Sir"))
    d.Push(BkT("/wa", "allg", "Nach Wantedlevel fragen", "send", "Nennen Sie mir bitte Ihr aktuelles Wantedlevel."))
    d.Push(BkT("/aw", "allg", "Nach Kosten fragen", "send", "Bitte nennen Sie die Kosten dieser Aktion."))
    d.Push(BkT("/cd", "allg", "Countdown mit Warnung (mit < abbrechen)", "fn", "", "BkFn_CopCountdown"))
    d.Push(BkT("/stopuhr", "allg", "Stoppuhr (mit < stoppen)", "fn", "", "BkFn_Stopwatch"))
    d.Push(BkT("/abholung", "allg", "Abholung anfordern (/f)", "send", "{fchat} Brauche Abholung in {ort}"))
    d.Push(BkT("/exe", "allg", "Fake-Absturz (5 Zeilen)", "send", "Warning(opcode): Exception 0xC0000005 at 0x7F0C37`nWarning(opcode): Exception 0xC0000005 at 0x7F0C37`nWarning(opcode): Exception 0xC0000005 at 0x7F0C37`nWarning(opcode): Exception 0xC0000005 at 0x7F0C37`nWarning(opcode): Exception 0xC0000005 at 0x7F0C37"))
    d.Push(BkT("/exe2", "allg", "Fake-Absturz (10 Zeilen)", "send", "Warning(opcode): Exception 0xC0000005 at 0x7F0C37`nWarning(opcode): Exception 0xC0000005 at 0x7F0C37`nWarning(opcode): Exception 0xC0000005 at 0x7F0C37`nWarning(opcode): Exception 0xC0000005 at 0x7F0C37`nWarning(opcode): Exception 0xC0000005 at 0x7F0C37`n{sleep 1100}`nWarning(opcode): Exception 0xC0000005 at 0x7F0C37`nWarning(opcode): Exception 0xC0000005 at 0x7F0C37`nWarning(opcode): Exception 0xC0000005 at 0x7F0C37`nWarning(opcode): Exception 0xC0000005 at 0x7F0C37`nWarning(opcode): Exception 0xC0000005 at 0x7F0C37"))
    ; Kurzformen fuer Chat-Kanaele ("7" = "/" ohne Shift) - loesen mit Leertaste aus
    for i, k in ["f", "g", "w", "s", "a", "ad", "sup", "help", "b"]
        d.Push(BkT("7" . k, "allg", "Tippfehler 7" . k . " -> /" . k, "prefill", "/" . k . " ", "", "space"))
    ; ---- Service / Dialoge ----
    d.Push(BkT("/staxi", "allg", "Taxi rufen (/service)", "fn", "/service|1", "BkFn_Service"))
    d.Push(BkT("/smedic", "allg", "Medic rufen (/service)", "fn", "/service|2", "BkFn_Service"))
    d.Push(BkT("/smecha", "allg", "Mechaniker rufen (/service)", "fn", "/service|3", "BkFn_Service"))
    d.Push(BkT("/spizza", "allg", "Pizzalieferant rufen (/service)", "fn", "/service|4", "BkFn_Service"))
    d.Push(BkT("/soamt", "allg", "Ordnungsamt rufen (/service)", "fn", "/service|5", "BkFn_Service"))
    d.Push(BkT("/wh", "allg", "Wheelman rufen (/service)", "fn", "/service|6", "BkFn_Service"))
    d.Push(BkT("/ctaxi", "allg", "Taxi-Ruf abbrechen", "fn", "/cancel taxi|0", "BkFn_Service"))
    d.Push(BkT("/cmedic", "allg", "Medic-Ruf abbrechen", "fn", "/cancel medic|0", "BkFn_Service"))
    d.Push(BkT("/cmecha", "allg", "Mechaniker-Ruf abbrechen", "fn", "/cancel mecha|0", "BkFn_Service"))
    d.Push(BkT("/cpizza", "allg", "Pizza-Ruf abbrechen", "fn", "/cancel pizza|0", "BkFn_Service"))
    d.Push(BkT("/coamt", "allg", "Ordnungsamt-Ruf abbrechen", "fn", "/cancel oamt|0", "BkFn_Service"))
    d.Push(BkT("/cwh", "allg", "Wheelman-Ruf abbrechen", "fn", "/cancel wheelman|0", "BkFn_Service"))
    for i, v in [25, 50, 75, 99, 150, 200, 300, 500, 999]
        d.Push(BkT("/" . v . "k", "allg", v . ".000 $ am ATM abheben", "fn", (v = 999 ? 999999 : v * 1000), "BkFn_Atm"))
    ; ---- Fahrzeug ----
    d.Push(BkT("/gw", "fahrzeug", "/get wheel", "send", "/get wheel"))
    d.Push(BkT("/cw", "fahrzeug", "/changewheel", "send", "/changewheel"))
    d.Push(BkT("/ci", "fahrzeug", "/carinfo", "send", "/carinfo"))
    d.Push(BkT("/rc", "fahrzeug", "/rentcar", "send", "/rentcar"))
    d.Push(BkT("/unc", "fahrzeug", "/unrentcar", "send", "/unrentcar"))
    ; ---- Werbung ----
    d.Push(BkT("/memberad", "werbung", "Member-Werbung senden", "send", "/ad {memberad}"))
    d.Push(BkT("/orgad", "werbung", "Orgmember-Werbung senden", "send", "/ad {orgad}"))
    d.Push(BkT("/sonad", "werbung", "Sonstige Werbung senden", "send", "/ad {sonstad}"))
    ; ---- Waffen ----
    d.Push(BkT("/wp", "waffen", "Waffenpaket 1", "fn", "1", "BkFn_WeaponPack"))
    d.Push(BkT("/wp2", "waffen", "Waffenpaket 2", "fn", "2", "BkFn_WeaponPack"))
    d.Push(BkT("/wp3", "waffen", "Waffenpaket 3", "fn", "3", "BkFn_WeaponPack"))
    d.Push(BkT("/deagle", "waffen", "Deagle kaufen", "send", "/buygun deagle {mun_deagle}"))
    d.Push(BkT("/shotgun", "waffen", "Shotgun kaufen", "send", "/buygun shotgun {mun_shotgun}"))
    d.Push(BkT("/m4", "waffen", "M4 kaufen", "send", "/buygun m4 {mun_m4}"))
    d.Push(BkT("/ak47", "waffen", "AK47 kaufen", "send", "/buygun ak47 {mun_ak47}"))
    d.Push(BkT("/mp5", "waffen", "MP5 kaufen", "send", "/buygun mp5 {mun_mp5}"))
    d.Push(BkT("/sniper", "waffen", "Sniper kaufen", "send", "/buygun sniper {mun_sniper}"))
    d.Push(BkT("/rifle", "waffen", "Rifle kaufen", "send", "/buygun rifle {mun_rifle}"))
    d.Push(BkT("/schaufel", "waffen", "Schaufel kaufen", "send", "/buygun shovel 1"))
    d.Push(BkT("/katana", "waffen", "Katana kaufen", "send", "/buygun katana 1"))
    d.Push(BkT("/fall", "waffen", "Fallschirm kaufen", "send", "/buygun parachute 1"))
    ; ---- Drogen ----
    d.Push(BkT("/ud", "drogen", "Drogen nehmen", "send", "/usedrugs"))
    d.Push(BkT("/td", "drogen", "Drogen aus Box nehmen (Menge tippen)", "prefill", "/gtake drugs "))
    d.Push(BkT("/pd", "drogen", "Drogen einlagern (Menge tippen)", "prefill", "/put drugs "))
    d.Push(BkT("/sd", "drogen", "Drogen verkaufen", "prefill", "/selldrugs "))
    ; ---- Wanted ----
    d.Push(BkT("/stellenLS", "wanted", "Stellen am LSPD (/call 911)", "send", "/call 911`n{sleep 200}`nStellen an den Zellen des Los Santos Police Department!`n{sleep 200}`n/h"))
    d.Push(BkT("/stellenSF", "wanted", "Stellen am SFPD (/call 911)", "send", "/call 911`n{sleep 200}`nStellen an den Zellen des San Fierro Police Department!`n{sleep 200}`n/h"))
    d.Push(BkT("/stellenLV", "wanted", "Stellen am LVPD (/call 911)", "send", "/call 911`n{sleep 200}`nStellen an den Zellen des Las Venturas Police Department!`n{sleep 200}`n/h"))
    d.Push(BkT("/PrisonLS", "wanted", "Stellen am Prison LS", "send", "/call 911`n{sleep 200}`nIch ergebe mich am Eingang des Los Santos Prisons!`n{sleep 200}`n/h"))
    d.Push(BkT("/PrisonSF", "wanted", "Stellen am Prison SF", "send", "/call 911`n{sleep 200}`nIch ergebe mich am Eingang des San Fierro Prisons!`n{sleep 200}`n/h"))
    d.Push(BkT("/gwanted", "wanted", "Verbrechen + Wantedlevel (/g)", "send", "{gchat} Letztes Verbrechen wegen: [{verbrechen}] Zeuge: [{zeuge}]`n{gchat} Neues Wantedlevel: {wantedlevel}"))
    d.Push(BkT("/cops", "wanted", "Was tun bei Cops? (Umfrage)", "send", "Was sollen wir tun wenn Cops uns warnen?`n{sleep 500}`n1. Flüchten, und ne geile Action starten.`n{sleep 200}`n2. Stehen bleiben und stellen."))
    ; ---- Fraktion ----
    d.Push(BkT("/ja", "fraktion", "/f Positiv", "send", "{fchat} Positiv"))
    d.Push(BkT("/nein", "fraktion", "/f Negativ", "send", "{fchat} Negativ"))
    d.Push(BkT("/wo", "fraktion", "/f Wo befinden Sie sich?", "send", "{fchat} Wo befinden Sie sich?"))
    d.Push(BkT("/ok", "fraktion", "/f Verstanden", "send", "{fchat} Verstanden & bestätigt!"))
    d.Push(BkT("/robinfo", "fraktion", "Letzte Robs sagen", "send", "Letzter LS Bankrob: {robls}`nLetzter SF Bankrob: {robsf}`nLetzter Tresorrob: {robtresor}"))
    d.Push(BkT("/frobinfo", "fraktion", "Letzte Robs (/f)", "send", "{fchat} Letzter LS Bankrob: {robls}`n{fchat} Letzter SF Bankrob: {robsf}`n{fchat} Letzter Tresorrob: {robtresor}"))
    ; ---- Gang ----
    d.Push(BkT("/gja", "gangchat", "/g Positiv", "send", "{gchat} Positiv"))
    d.Push(BkT("/gnein", "gangchat", "/g Negativ", "send", "{gchat} Negativ"))
    d.Push(BkT("/gok", "gangchat", "/g Verstanden", "send", "{gchat} Verstanden & bestätigt!"))
    d.Push(BkT("/gwo", "gangchat", "/g Wo befinden Sie sich?", "send", "{gchat} Wo befinden Sie sich?"))
    d.Push(BkT("/gexe", "gangchat", "Fake-Absturz im /g", "send", "{gchat} Warning(opcode): Exception 0xC0000005 at 0x7F0C37`n{gchat} Warning(opcode): Exception 0xC0000005 at 0x7F0C37`n{gchat} Warning(opcode): Exception 0xC0000005 at 0x7F0C37`n{gchat} Warning(opcode): Exception 0xC0000005 at 0x7F0C37`n{gchat} Warning(opcode): Exception 0xC0000005 at 0x7F0C37"))
    d.Push(BkT("/grobinfo", "gangchat", "Letzte Robs (/g)", "send", "{gchat} Letzter LS Bankrob: {robls}`n{gchat} Letzter SF Bankrob: {robsf}`n{gchat} Letzter Tresorrob: {robtresor}"))
    d.Push(BkT("/gu", "gang", "/gangupgrade", "send", "/gangupgrade"))
    d.Push(BkT("/buyp", "gang", "Produkte kaufen (150 + 75)", "send", "/buyprods 150`n/buyprods 75"))
    d.Push(BkT("/list", "gang", "/listgangcars", "send", "/listgangcars"))
    d.Push(BkT("/fix", "gang", "/fixgangcar", "send", "/fixgangcar"))
    d.Push(BkT("/fgc", "gang", "/freegangcar", "send", "/freegangcar"))
    d.Push(BkT("/wi", "gang", "/warinfo", "send", "/warinfo"))
    d.Push(BkT("/cg", "gang", "/cargo", "send", "/cargo"))
    d.Push(BkT("/oc", "gang", "/opencargo", "send", "/opencargo"))
    d.Push(BkT("/bcar", "gang", "/breakcargo", "send", "/breakcargo"))
    d.Push(BkT("/oi", "gang", "/orginvite vorbereiten", "prefill", "/orginvite "))
    d.Push(BkT("/ou", "gang", "/orguninvite vorbereiten", "prefill", "/orguninvite "))
    d.Push(BkT("/partner", "gang", "Kidnap-/Pizza-Partner festlegen (/id Name)", "fn", "partner", "BkFn_IdCapture"))
    d.Push(BkT("/kunde", "gang", "Kidnap-Opfer festlegen (/id Name)", "fn", "opfer", "BkFn_IdCapture"))
    d.Push(BkT("/pp", "job_pizza", "Pizza an Partner verkaufen", "send", "/sellpizza {partner}"))
    d.Push(BkT("/pp2", "job_pizza", "2 Pizzen an Partner verkaufen", "send", "/sellpizza {partner}`n/sellpizza {partner}"))
    d.Push(BkT("/sp", "job_pizza", "/sellpizza vorbereiten", "prefill", "/sellpizza "))
    d.Push(BkT("/con", "job_hitman", "/contract ID Preis vorbereiten", "prefill", "/contract {cursor} {conpreis}"))
    ; ---- Gegnerlisten (Uebersicht) ----
    d.Push(BkT("/gangallcheck", "gegner", "Alle Gegner online prüfen", "fn", "all", "BkFn_EnemyCheck"))
    ; ---- Aufnahme ----
    d.Push(BkT("/frag", "allg", "Aufnahme stoppen und als Frag ablegen", "fn", "frag", "BkFn_SaveVideo"))
    d.Push(BkT("/beschwerde", "allg", "Aufnahme stoppen und als Beschwerde ablegen", "fn", "beschwerde", "BkFn_SaveVideo"))
    ; ---- Radio ----
    d.Push(BkT("/iloveradio", "allg", "Radio starten", "fn", "", "BkFn_RadioStart"))
    d.Push(BkT("/radiostop", "allg", "Radio stoppen", "fn", "", "BkFn_RadioStop"))
    ; ---- Stadtplan ----
    d.Push(BkT("/map", "stadtplan", "Gebäudekomplex zeigen: /map <Nr> (z.B. /map 1.1)", "fn", "", "BkFn_Map"))
    return d
}
