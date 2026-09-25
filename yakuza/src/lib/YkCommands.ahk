; =====================================================================
;  Yakuza Keybinder - Server-Befehle (Life of Player)
; ---------------------------------------------------------------------
;  Felder je Eintrag:
;    c = Kategorie
;    k = Befehl (wird so in den Chat geschrieben)
;    d = Beschreibung
;    s = 1 -> Favorit (nur noch Hotkey waehlen)
;    e = 1 -> sofort mit Enter senden
;        0 -> Befehl stehen lassen, damit man noch etwas dazu tippen kann
;  Stand: Server-Update September 2026 (/family -> /f, neu: /famcars,
;  /famjob, /gangcars)
; =====================================================================

YkCmdDB() {
    d := []

    ; ---------------- Allgemein ----------------
    d.Push({c: "Allgemein", k: "/stats",        d: "Bargeld, Konto, Fahrzeuge, Häuser, Geschäfte, Telefonnummer", s: 1, e: 1})
    d.Push({c: "Allgemein", k: "/help",         d: "Übersicht über die Befehle",                        s: 0, e: 1})
    d.Push({c: "Allgemein", k: "/settings",     d: "Einstellungen: Chat, HUD, Spawn, Upgrades",         s: 0, e: 1})
    d.Push({c: "Allgemein", k: "/spawnort",     d: "Spawnort nach dem Tod",                             s: 0, e: 1})
    d.Push({c: "Allgemein", k: "/spawnchange",  d: "Spawnort nach dem Relog",                           s: 0, e: 1})
    d.Push({c: "Allgemein", k: "/warten",       d: "Bewusstlos: länger durchhalten, bis ein Medic kommt", s: 0, e: 1})
    d.Push({c: "Allgemein", k: "/anim",         d: "Animation auswählen",                               s: 0, e: 1})
    d.Push({c: "Allgemein", k: "/intim",        d: "Im eigenen Auto oder Haus: +25 HP",                 s: 0, e: 1})
    d.Push({c: "Allgemein", k: "/tickets",      d: "Offene Tickets ansehen",                            s: 0, e: 1})
    d.Push({c: "Allgemein", k: "/ticketzahlen", d: "Alle Tickets bezahlen",                             s: 0, e: 1})
    d.Push({c: "Allgemein", k: "/unstuck",      d: "Befreiung, wenn man feststeckt",                    s: 0, e: 1})
    d.Push({c: "Allgemein", k: "/skills",       d: "Job-Level und Waffen-Skills ansehen",               s: 0, e: 1})
    d.Push({c: "Allgemein", k: "/upgrades",     d: "Upgradepunkte",                                     s: 0, e: 1})
    d.Push({c: "Allgemein", k: "/gps",          d: "Navi aktivieren",                                   s: 0, e: 1})
    d.Push({c: "Allgemein", k: "/gpsoff",       d: "GPS beenden",                                       s: 0, e: 1})
    d.Push({c: "Allgemein", k: "/daily",        d: "Tagesaufgaben",                                     s: 0, e: 1})
    d.Push({c: "Allgemein", k: "/s ",           d: "Schreien - große Reichweite (Text anhängen)",       s: 0, e: 0})
    d.Push({c: "Allgemein", k: "/w ",           d: "Flüstern - nur ganz nah (Text anhängen)",           s: 0, e: 0})
    d.Push({c: "Allgemein", k: "/bail ",        d: "Spieler aus dem Gefängnis holen (Name/ID)",         s: 0, e: 0})
    d.Push({c: "Allgemein", k: "/pay ",         d: "Jemandem Geld geben, max. 10k pro Zahlung",         s: 0, e: 0})
    d.Push({c: "Allgemein", k: "/loan ",        d: "Kredit aufnehmen (Betrag)",                         s: 0, e: 0})
    d.Push({c: "Allgemein", k: "/repay ",       d: "Kredit zurückzahlen (Betrag)",                      s: 0, e: 0})

    ; ---------------- Fahrzeuge ----------------
    d.Push({c: "Fahrzeuge", k: "/motor",        d: "Motor an- und ausschalten (eigenes Fahrzeug)",      s: 1, e: 1})
    d.Push({c: "Fahrzeuge", k: "/lock",         d: "Fahrzeug abschließen / öffnen",                     s: 1, e: 1})
    d.Push({c: "Fahrzeuge", k: "/engine",       d: "Motor an/aus - Alternative zu /motor",              s: 0, e: 1})
    d.Push({c: "Fahrzeuge", k: "/park",         d: "Fahrzeug parken",                                   s: 0, e: 1})
    d.Push({c: "Fahrzeuge", k: "/freikaufen",   d: "Beschlagnahmtes Auto freikaufen (SATL-Base)",       s: 0, e: 1})
    d.Push({c: "Fahrzeuge", k: "/werkstatt",    d: "GPS zur nächsten Werkstatt",                        s: 0, e: 1})
    d.Push({c: "Fahrzeuge", k: "/satl",         d: "Abschleppen, Pannenhilfe, mieten, Abo, orten",      s: 0, e: 1})

    ; ---------------- Häuser ----------------
    d.Push({c: "Häuser",    k: "/buyupgrade",   d: "Upgrades fürs Haus: Bunker, Labor, HP, Armor",      s: 0, e: 1})
    d.Push({c: "Häuser",    k: "/housename ",   d: "Hausname / Unbekannt einstellen",                   s: 0, e: 0})
    d.Push({c: "Häuser",    k: "/buyfurniture", d: "Möbel kaufen",                                      s: 0, e: 1})
    d.Push({c: "Häuser",    k: "/editfurniture",d: "Möbel verschieben",                                 s: 0, e: 1})
    d.Push({c: "Häuser",    k: "/delfurniture", d: "Möbel entfernen",                                   s: 0, e: 1})

    ; ---------------- Business ----------------
    d.Push({c: "Business",  k: "/warenlauf",    d: "Lieferung selbst durchführen (3000 Stk, 100k)",     s: 0, e: 1})

    ; ---------------- Gang / Mafia ----------------
    d.Push({c: "Gang",      k: "/gmembers",     d: "Mitgliederliste der Gang",                          s: 1, e: 1})
    d.Push({c: "Gang",      k: "/ganginfo",     d: "Member online, Geld in der Gangkasse",              s: 1, e: 1})
    d.Push({c: "Gang",      k: "/gangcars",     d: "Gangfahrzeuge orten",                               s: 1, e: 1})
    d.Push({c: "Gang",      k: "/schutzgeld",   d: "Übersicht über das Schutzgeld",                     s: 1, e: 1})
    d.Push({c: "Gang",      k: "/turfs",        d: "Übersicht Gangwars inkl. Cooldown-Zeit",            s: 1, e: 1})
    d.Push({c: "Gang",      k: "/g ",           d: "Interner Gangchat (Text anhängen)",                 s: 0, e: 0})
    d.Push({c: "Gang",      k: "/u ",           d: "Underground-Chat aller Gangs (Text anhängen)",      s: 0, e: 0})
    d.Push({c: "Gang",      k: "/gangstats",    d: "Gang-Statistik",                                    s: 0, e: 1})
    d.Push({c: "Gang",      k: "/turf",         d: "Info zum Gebiet - nur wenn man darin steht",        s: 0, e: 1})
    d.Push({c: "Gang",      k: "/gangtop",      d: "Rangliste aller Gangs und Mafien",                  s: 0, e: 1})
    d.Push({c: "Gang",      k: "/extort",       d: "Schutzgeld einkassieren",                           s: 0, e: 1})
    d.Push({c: "Gang",      k: "/attackbiz",    d: "Business angreifen",                                s: 0, e: 1})
    d.Push({c: "Gang",      k: "/war ",         d: "Kriegserklärung an andere Fraktion",                s: 0, e: 0})
    d.Push({c: "Gang",      k: "/krieg ",       d: "Kriegserklärung - Alternative zu /war",             s: 0, e: 0})

    ; ---------------- Gang-Leitung ----------------
    d.Push({c: "Gang-Leitung", k: "/carrespawn", d: "Autos tanken, reparieren und in der Base respawnen", s: 1, e: 1})
    d.Push({c: "Gang-Leitung", k: "/carspawn",   d: "Alternative zu /carrespawn",                       s: 0, e: 1})
    d.Push({c: "Gang-Leitung", k: "/basetuer",   d: "Base-Tür für Mitglieder auf/zu",                   s: 0, e: 1})
    d.Push({c: "Gang-Leitung", k: "/ginvite ",   d: "Mitglied einladen (Name/ID)",                      s: 0, e: 0})
    d.Push({c: "Gang-Leitung", k: "/gkick ",     d: "Mitglied entfernen (Name/ID)",                     s: 0, e: 0})
    d.Push({c: "Gang-Leitung", k: "/gpromote ",  d: "Rang +1 setzen (Name/ID)",                         s: 0, e: 0})
    d.Push({c: "Gang-Leitung", k: "/gdemote ",   d: "Rang -1 setzen (Name/ID)",                         s: 0, e: 0})
    d.Push({c: "Gang-Leitung", k: "/grankname ", d: "Rangnamen setzen",                                 s: 0, e: 0})
    d.Push({c: "Gang-Leitung", k: "/gangrechte", d: "Rechte je Rang setzen",                            s: 0, e: 1})
    d.Push({c: "Gang-Leitung", k: "/gangmotd ",  d: "Nachricht unter /ganginfo setzen",                 s: 0, e: 0})
    d.Push({c: "Gang-Leitung", k: "/lohn ",      d: "Bonuslohn pro Rang setzen",                        s: 0, e: 0})
    d.Push({c: "Gang-Leitung", k: "/setlohn ",   d: "Bonus pro Member setzen",                          s: 0, e: 0})
    d.Push({c: "Gang-Leitung", k: "/bonus ",     d: "Einmalzahlung",                                    s: 0, e: 0})
    d.Push({c: "Gang-Leitung", k: "/gdeposit ",  d: "Geld in die Gangkasse einzahlen",                  s: 0, e: 0})
    d.Push({c: "Gang-Leitung", k: "/gwithdraw ", d: "Geld aus der Gangkasse auszahlen",                 s: 0, e: 0})
    d.Push({c: "Gang-Leitung", k: "/buygangvehicle ", d: "Gangauto kaufen (Fahrzeug-ID nötig)",         s: 0, e: 0})

    ; ---------------- Family ----------------
    d.Push({c: "Family",    k: "/f ",           d: "Family-Chat, früher /family (Text anhängen)",       s: 0, e: 0})
    d.Push({c: "Family",    k: "/familymap",    d: "Familienmitglieder auf der Karte sehen",            s: 1, e: 1})
    d.Push({c: "Family",    k: "/famcars",      d: "Family-Fahrzeuge orten",                            s: 1, e: 1})
    d.Push({c: "Family",    k: "/famjob",       d: "Job-Auto holen",                                    s: 1, e: 1})
    d.Push({c: "Family",    k: "/familyhelp",   d: "Notruf an die Familie",                             s: 1, e: 1})
    d.Push({c: "Family",    k: "/fammembers",   d: "Mitgliederliste der Familie",                       s: 1, e: 1})
    d.Push({c: "Family",    k: "/famstorage",   d: "Family-Lager",                                      s: 0, e: 1})
    d.Push({c: "Family",    k: "/attackfamily", d: "Fremde Base angreifen (3 Member online nötig)",     s: 0, e: 1})
    d.Push({c: "Family",    k: "/setfamilyhouse", d: "Familyhaus setzen (nur Oberhaupt)",               s: 0, e: 1})
    d.Push({c: "Family",    k: "/famleave",     d: "Familie verlassen",                                 s: 0, e: 1})
    d.Push({c: "Family",    k: "/faminvite ",   d: "Zur Familie einladen (Name/ID)",                    s: 0, e: 0})
    d.Push({c: "Family",    k: "/famdeposit ",  d: "In die Famkasse einzahlen (Betrag)",                s: 0, e: 0})
    d.Push({c: "Family",    k: "/famwithdraw ", d: "Aus der Famkasse abheben (Betrag)",                 s: 0, e: 0})

    ; ---------------- Illegales ----------------
    d.Push({c: "Illegales", k: "/use cannabis", d: "Cannabis konsumieren",                              s: 1, e: 1})
    d.Push({c: "Illegales", k: "/use koka",     d: "Koka konsumieren",                                  s: 1, e: 1})
    d.Push({c: "Illegales", k: "/darkweb",      d: "Kopfgeld, Hackerdienste, anonyme Werbung",          s: 0, e: 1})
    d.Push({c: "Illegales", k: "/plantcannabis",d: "Cannabis anpflanzen",                               s: 0, e: 1})
    d.Push({c: "Illegales", k: "/harvestcannabis", d: "Cannabis ernten",                                s: 0, e: 1})
    d.Push({c: "Illegales", k: "/plantcoca",    d: "Koka anpflanzen",                                   s: 0, e: 1})
    d.Push({c: "Illegales", k: "/harvestcoca",  d: "Koka ernten",                                       s: 0, e: 1})
    d.Push({c: "Illegales", k: "/water",        d: "Pflanze gießen",                                    s: 0, e: 1})
    d.Push({c: "Illegales", k: "/camper",       d: "Koka verarbeiten",                                  s: 0, e: 1})
    d.Push({c: "Illegales", k: "/selldrug ",    d: "Drogen verkaufen",                                  s: 0, e: 0})
    d.Push({c: "Illegales", k: "/sellweapon ",  d: "Waffen verkaufen",                                  s: 0, e: 0})

    return d
}

; Befehle, die ingame über ein Menü laufen -> kein Hotkey nötig/möglich
YkMenuCmdsText() {
    t := "Diese Befehle brauchen KEINEN Hotkey - ingame öffnet sich an Ort und Stelle`r`n"
    t .= "automatisch ein Menü, über das du sie ausführst:`r`n`r`n"
    t .= "HÄUSER`r`n"
    t .= "   Kaufen, Betreten, Mieten, Öffnen/Schließen und das Besitzer-Menü`r`n"
    t .= "   laufen komplett automatisch über das Hausmenü.`r`n`r`n"
    t .= "BUSINESS`r`n"
    t .= "   /buybiz, /sellbiz      Business kaufen oder verkaufen`r`n"
    t .= "   /bizinfo               Mitarbeiter, Kasse, Lagerbestand`r`n"
    t .= "   /bizdeposit, /bizwithdraw   Kasse verwalten`r`n"
    t .= "   /restock               Lager auffüllen`r`n`r`n"
    t .= "GANG-LAGER`r`n"
    t .= "   /baseitems             Lagerbestand ansehen`r`n"
    t .= "   /basestore             Ins Lager einlagern`r`n"
    t .= "   /basetake              Aus dem Lager auslagern`r`n`r`n"
    t .= "FAHRZEUGE`r`n"
    t .= "   Taste  n  im Fahrzeug öffnet das Fahrzeug-Menü.`r`n"
    return t
}

YkCmd_Init() {
    global YK_CmdList
    if (YK_CmdList.MaxIndex())
        return
    YK_CmdList := YkCmdDB()
}

YkCmd_FindByKey(key) {
    global YK_CmdList
    YkCmd_Init()
    for i, o in YK_CmdList
        if (o.k == key)
            return o
    return ""
}
