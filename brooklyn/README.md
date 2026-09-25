# Keybinder von Brooklyn 5.0

Neuauflage des „Keybinder von Brooklyn“ 4.60 für SA-MP. Alle Tasten und Chat-Befehle von damals sind erhalten. Der Binder hängt aber nicht mehr an Dateien oder Servern, die es nicht mehr gibt.

| Früher (4.60)                                   | Jetzt (5.0)                                             |
|-------------------------------------------------|---------------------------------------------------------|
| `Brooklyn.dll` (SA-MP-API, nur alte Versionen)  | eigene, nur lesende Speicher-Schicht (R1/R3/R5/DL)      |
| `getGametext.dll` für Gangwar-Kills             | GameText direkt aus `gta_sa.exe`                        |
| Dropbox-Downloads, MySQL-Server des Erstellers  | nichts davon nötig                                      |
| `rgn_ac_gta.exe` (RGN-Launcher)                 | normales SA-MP (`gta_sa.exe`), weitere Namen einstellbar |
| löscht `chatlog.txt` bei jedem Treffer          | liest `chatlog.txt` nur mit                             |
| VLC fürs Radio                                  | Windows Media Player (in Windows eingebaut)             |
| ein Profil für alle                             | Zivilist / Gang / Staatsfraktion + 13 Jobs              |

**Download zum Spielen:** `Brooklyn_Keybinder_v5.0.0.zip` im Hauptordner des Repos. Darin liegen `BrooklynKeybinder.exe` und `ANLEITUNG.txt`.

## Aufbau

```
brooklyn/
  src/Brooklyn.ahk        Einstieg (AutoHotkey v1.1, Unicode 32-Bit)
  src/brooklyn.ico
  src/lib/
    BkMemory.ahk          Spiel-/SA-MP-Speicher lesen (aus dem Yakuza Keybinder)
    BkMemExtra.ahk        Ersatz für die Funktionen der Brooklyn.dll
    BkSend.ahk            Senden in den Chat (Tastensender, aus dem Yakuza Keybinder)
    BkZones.ahk           Zonen/Städte (aus dem Yakuza Keybinder)
    BkBinds.ahk           alle Tasten- und Chat-Befehle, Profile, Gruppen
    BkEngine.ahk          Hotkeys, Chat-Erkennung, Chat-Befehle, Platzhalter
    BkActions.ahk         Sonderfunktionen (/members, /aa, /atm, /map ...)
    BkChatlog.ahk         Chatlog-Auswertung, GameText-Kills, Tod
    BkStats.ahk           Statistik (gesamt/Tag/Monat)
    BkEnemies.ahk         Gegnerlisten
    BkOverlay.ahk         Meldungen/Countdown über dem Spiel
    BkExtras.ahk          Radio, Aufnahmen, Programme, Timer
    BkConfig.ahk          Einstellungen + Übernahme aus 4.x
    BkGuiKit.ahk          UI-Baukasten (GDI+-Karten, Schalter, Dark Mode)
    BkGui.ahk             Hauptfenster
    BkMaps.ahk            /map-Gebäudekomplexe
  build/build.bat         EXE bauen unter Windows
  build/build.sh          EXE bauen unter Linux (Wine)
  ANLEITUNG.txt
```

## Bauen

Windows, mit installiertem AutoHotkey v1.1:

```
brooklyn\build\build.bat
```

Linux (Wine + AutoHotkey 1.1.37):

```
AHK_DIR=/pfad/zu/AutoHotkey_1.1.37 brooklyn/build/build.sh
```

## Getestet

Unter Wine (Xvfb + openbox), mit Notepad als Ersatz-Spielfenster:

- Start, alle 8 Seiten und die 5 Einstellungs-Unterseiten
- Tasten-Binds, mehrzeilige Binds, Platzhalter
- Chat-Befehle: `/kd`, `/wp`, `/map 1.1`, `/aim 12`, `/aim` mit Nachfrage, `/ballasadd`, `/ballas`, `/dice3`, `7f` + Leertaste
- Pause an/aus, Overlay-Meldungen, Countdown
- Übernahme von Tasten, Einstellungen und Statistik aus 4.60

Die SA-MP-Adressen stammen aus dem Yakuza Keybinder (dort live geprüft mit 0.3.7-R5). Ein Test im echten Spiel steht noch aus.
