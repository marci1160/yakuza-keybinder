# Yakuza Keybinder 3.0.2

Neue Fassung des Yakuza Keybinders (Yakuza Family, Life of Player). Alles aus v2.0.2 ist geblieben:

- Befehle, Kurzformen und eigene Tasten
- Kill- und Tod-Meldungen
- Backup-Fahnen, Kriege und Member
- Overlay und Laufscript (Sprint)
- Wanteds, Lotto und Update

Neu sind das Fenster im Stil des Keybinders von Brooklyn 5.0 und die Brooklyn-Funktionen, die **nicht** von einem bestimmten Server abhängen. Jobs gibt es keine.

| Bereich | v2.0.2 | v3.0 |
|---|---|---|
| Fenster | 6 Registerkarten, „Speichern“-Knopf | Seitenleiste, 12 Seiten, alles wirkt sofort; Yakuza-Banner und -Gesicht |
| Tasten | Keybinds + Tasten in drei Tabs verteilt | alle Tasten in einer Liste, ⚠ bei Doppelbelegung, Pause- und weitere Funktionstasten |
| Chat | Kurzformen (`/uc`), `/yk…` | zusätzlich Chat-Befehle mit Enter, nach den Chats von Life of Player: `/f…` = Family-Chat, `/g…` = Gang-/Mafienchat, ohne Buchstaben = normaler Chat (`/fkd` `/gkd` `/kd`, `/fja` `/gok`, `/fpos`, `/gcd` …), dazu `/re` `/stopuhr` `/zeit` `/chillen` `7f` … und eigene |
| Statistik | Sitzung + Stand vom Server (Taste N) | zusätzlich heute / Monat / gesamt, Spielzeit, Logins, SMS |
| Gegner | – | Gegnerlisten mit Online-Prüfung über die SA-MP-Spielerliste |
| Meldungen | Overlay-Zeile | zusätzlich Karten im Spiel, großer Countdown, Radio |
| Aufnahmen | – | `/rec` `/recstop` `/frag` `/beschwerde`, Start-/Stopp-Taste des Aufnahmeprogramms (z.B. `F9`, `Alt+F9`) |
| Update | Gist mit direktem ZIP-Link | wie bisher; zusätzlich reicht ein Link zum GitHub-Repo |

**Download:** `Yakuza_Keybinder_v3.0.2.zip` im Hauptordner des Repos (`YakuzaKeybinder.exe` + `ANLEITUNG.txt`). Der Aufbau der ZIP ist derselbe wie bisher, deshalb kann v2 sich selbst auf v3.0 aktualisieren.

## Update an alle Member verteilen

Im Update-Gist (`https://gist.github.com/marci1160/a08df2cbef9bd6968dd74c9e0b016503`) muss stehen:

```
Version=3.0.2
Info=Gegnerlisten erkennen Online-Spieler zuverlässiger
Url=https://github.com/marci1160/yakuza-keybinder/raw/main/Yakuza_Keybinder_v3.0.2.zip
```

Die `Url` muss direkt auf die ZIP zeigen, sonst kann v2 nichts herunterladen. Der Link auf `main` funktioniert erst, wenn die ZIP im Zweig `main` liegt.

## Aufbau

```
yakuza/
  src/YakuzaKeybinder.ahk   Einstieg (AutoHotkey v1.1, Unicode 32-Bit)
  src/yakuza.ico
  src/lib/
    -- aus v2.0.2, fast unverändert --
    YkMemory.ahk            Spiel- und SA-MP-Speicher (nur lesend)
    YkZones.ahk             Zonen/Städte
    YkCombat.ahk            Kill-/Tod-Erkennung
    YkMarker.ahk            Backup-Fahne auf der Karte
    YkWars.ahk              Gangwar, Family-War, Bizfight
    YkMembers.ahk           Member-Positionen, Hilfe-Rufe, Ziel
    YkOverlay.ahk           Overlay im Spiel
    YkLocal.ahk             /ykpos /ykhud /ykclear /ykzu
    YkSend.ahk              Senden, Tastensperre, Warteschlange
    YkSprint.ahk            Sprint-Automatik (Laufscript), Tastenwächter
    YkUpdate.ahk            Update (+ Repo-Link)
    YkServerStats.ahk       Kills/Tode aus dem Charaktermenü (Taste N)
    YkWanteds.ahk YkLotto.ahk YkStall.ahk YkCommands.ahk
    YkPlaceholders.ahk YkHotkeyNames.ahk YkActions.ahk YkChatlog.ahk
    YkTick.ahk YkGlobals.ahk YkConfig.ahk YkTray.ahk YkAssets.ahk
    -- neu in v3.0 --
    YkChatInput.ahk         Mitlesen im Chat: Kurzformen + Chat-Befehle (Enter)
    YkChatCmds.ahk          Chat-Befehle, Funktionstasten, Platzhalter
    YkCounter.ahk           Statistik heute/Monat/gesamt
    YkEnemies.ahk           Gegnerlisten
    YkMemExtra.ahk          Spielerliste, ID, Ping, Geld (nur lesend)
    YkToast.ahk             Meldungs-Karten, großer Text, Countdown
    YkTools.ahk             Radio, Aufnahmen, Timer
    YkConfigV3.ahk          neue Abschnitte der INI
    YkGuiKit.ahk            UI-Baukasten (GDI+-Karten, Schalter, Dark Mode)
    YkGui.ahk YkGuiKeys.ahk YkGuiPages.ahk   Fenster
  build/build.bat           EXE bauen unter Windows
  build/build.sh            EXE + ZIP bauen unter Linux (Wine)
  ANLEITUNG.txt
```

## Bauen

Windows, mit installiertem AutoHotkey v1.1:

```
yakuza\build\build.bat
```

Linux (Wine + AutoHotkey 1.1.37) – baut die EXE und legt `Yakuza_Keybinder_v3.0.2.zip` in den Hauptordner:

```
AHK_DIR=/pfad/zu/AutoHotkey_1.1.37 yakuza/build/build.sh
```

## Neu in 3.0.2

- **Gegnerlisten:** Ein Gegner galt nur als online, wenn der Name Zeichen für Zeichen stimmte. Jetzt wird ein Teilname beim Hinzufügen gegen die Online-Spieler aufgelöst (`/gegneradd kenji` → `Kenji_Sato`), Groß/klein ist egal, und der Binder meldet, ob der Spieler online ist. Namen werden zusätzlich über den gelernten Weg der Kill-Namen gelesen, falls der SA-MP-Aufbau abweicht. Statt „niemand online“ kommt eine klare Meldung, wenn die Spielerliste leer oder nicht lesbar ist; die Diagnose zeigt „Spielerliste: N Spieler, M Namen lesbar“.
- Getestet mit einer nachgebauten SA-MP-Spielerliste im Speicher (Standardaufbau, abweichender Aufbau, keine Namen, leere Liste).

## Neu in 3.0.1

- **Chat-Befehle nach Life of Player:** Bei Brooklyn (RGN) war `/f` der Fraktionschat und „b“ der normale Chat. Jetzt gilt: `/f…` = Family-Chat der Organisation, `/g…` = Gang-/Mafienchat, ohne Buchstaben = normaler Chat. `/kd`, `/ja`, `/ok` … gehen damit in den normalen Chat. Neu sind `/fpos`, `/gpos` und `/fcd`, `/gcd`, `/cd` (3 - 2 - 1 - LOS). Die Polizei-Sprüche aus Brooklyn (`/neg`, `/null`, der alte `/cd`) sind entfernt.
- **Aufnahme beenden:** Die Taste des Aufnahmeprogramms wurde nur angetippt (Drücken und Loslassen im selben Augenblick). Programme wie OBS fragen die Tasten alle paar Millisekunden ab und haben das verpasst. Im Test mit einer Abfrage alle 25 ms wurden 10 von 10 Tipps nicht erkannt. Jetzt wird die Taste ~0,15 s gehalten, Kombinationen mit Alt/Strg/Shift/Win gehen auch. Neu sind `/rec` und `/recstop`, eine eigene Stopp-Taste, die Knöpfe „Starten“/„Beenden“ unter Extras und zwei Funktionstasten. `/frag` beendet auch ohne Video-Ordner und findet Videos in Unterordnern.
- Beim ersten Start nach dem Update von 3.0.0 zeigt der Binder einmal, was neu ist.

## Getestet

Unter Wine (Xvfb + openbox), mit Notepad als Ersatz-Spielfenster (`[General] GameExes=notepad.exe`):

- Start, alle 12 Seiten, Tasten-Editor (Ändern, Speichern)
- Tasten-Binds mit Platzhaltern
- Chat-Befehle: `/kd`, `/setkills 12` und `/setkills` mit Abfrage, `/infokill`, `/tode`, `/otime`, `/countdown`, `/gegneradd`, `/gegner`
- Kurzform `/uc` → `/use cannabis`, `7f` + Leertaste
- normaler Text geht unverändert durch
- Pause-Taste, Overlay, Meldungs-Karten
- 3.0.1: alle neuen Chat-Befehle (Debug-Log zeigt die gesendeten Zeilen: `/fkd` → `/f » Kills …`, `/gkd` → `/g …`, `/kd` → ohne Präfix, `/cd` → 3/2/1/LOS), `/wo` und `/bkd` gehen unverändert ans Spiel; `/rec`, `/recstop`, `/frag` und die Funktionstasten gegen ein Testprogramm, das wie OBS alle 25 ms per `GetAsyncKeyState` abfragt (F9, Alt+F9, Strg+Shift+F10), Video aus Unterordner verschoben; „Was ist neu?“ nach 3.0.0
- Umstieg von v2.0.2: v3.0 startet mit der alten `YakuzaKeybinder.ini`, eigene Tasten und Kurzformen bleiben, die neuen Abschnitte werden ergänzt, „Was ist neu?“ erscheint einmal

Die ZIP erfüllt alle Prüfungen des v2-Updaters: ZIP-Kennung, 100 KB bis 40 MB, `YakuzaKeybinder.exe` über 500 KB mit „MZ“ im Hauptverzeichnis. Das Auspacken selbst ließ sich unter Wine nicht nachstellen (dort fehlt die ZIP-Unterstützung von Windows). Ein Test im echten Spiel steht noch aus. Die Teile aus v2 sind unverändert und wurden dort bereits live geprüft.
