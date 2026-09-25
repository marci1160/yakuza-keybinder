; =====================================================================
;   YAKUZA KEYBINDER  v3.0
;   fuer SA-MP / open.mp  ~  optimiert fuer die Fraktion "Yakuza Family"
; ---------------------------------------------------------------------
;   Alles aus v2.0.2 bleibt, wie es war:
;   - frei belegbare Tasten und die Befehle von Life of Player
;   - Standort, Kills und Tode automatisch im /g (auch im War)
;   - Backup-Rufe als Fahne auf der Karte, Ziel waehlen (/ykzu)
;   - Kriege, Member-Positionen und Overlay
;   - Sprint-Automatik (Laufscript), Wanteds, Lotto, Update
;
;   Neu in v3.0:
;   - neues Fenster im Stil des Keybinders von Brooklyn 5.0
;   - Chat-Befehle aus Brooklyn, die nicht vom Server abhaengen:
;     /kd /dkd /mkd ..., /re (SMS beantworten), /cd, /stopuhr, 7f ...
;   - Statistik gesamt / heute / Monat, Spielzeit
;   - Gegnerlisten (/liste, /listeadd, /listedel, /gangallcheck)
;   - Meldungen als Karten im Spiel, Countdown, Radio
;
;   v3.0.1: Chat-Befehle nach den Chats von Life of Player (/f = Family-
;   Chat der Organisation, /g = Gang-/Mafienchat), Aufnahme beenden
;
;   Technik: reiner Tastensender + LESENDER Speicherzugriff auf
;   gta_sa.exe und samp.dll. Nichts wird injiziert. Einziger
;   Schreibzugriff: die abschaltbare Backup-Fahne in der
;   Kartensymbol-Liste des Spiels (siehe lib\YkMarker.ahk).
;
;   AutoHotkey v1.1 (Unicode 32-Bit). Geteilt/kompiliert als .exe.
; =====================================================================

;@Ahk2Exe-SetName Yakuza Keybinder
;@Ahk2Exe-SetDescription Yakuza Keybinder fuer SA-MP / open.mp
;@Ahk2Exe-SetVersion 3.0.1
;@Ahk2Exe-SetCopyright Yakuza Family
;@Ahk2Exe-SetMainIcon yakuza.ico

#NoEnv
#SingleInstance Force
#Persistent
#MaxThreadsPerHotkey 1
#InstallKeybdHook
#UseHook
SetWorkingDir %A_ScriptDir%
SetBatchLines, -1
; neue Threads sofort unterbrechbar - wichtig fuer YkBlock_Pump: sonst
; verwirft AutoHotkey die Sperr-Threads einer schnellen Meldung
Thread, Interrupt, 0
SetTitleMatchMode, 2
ListLines, Off

; ---- Module (nur Funktionen und globale Werte, keine Sprungmarken) ----
#Include %A_ScriptDir%\lib
#Include YkZones.ahk
#Include YkMemory.ahk
#Include YkMemExtra.ahk
#Include YkCommands.ahk
#Include YkAssets.ahk
#Include YkPlaceholders.ahk
#Include YkHotkeyNames.ahk
#Include YkMembers.ahk
#Include YkWars.ahk
#Include YkOverlay.ahk
#Include YkLocal.ahk
#Include YkCombat.ahk
#Include YkMarker.ahk
#Include YkUpdate.ahk
#Include YkServerStats.ahk
#Include YkWanteds.ahk
#Include YkLotto.ahk
#Include YkStall.ahk
#Include YkGlobals.ahk
#Include YkTick.ahk
#Include YkSend.ahk
#Include YkActions.ahk
#Include YkChatlog.ahk
#Include YkSprint.ahk
#Include YkChatInput.ahk
#Include YkHotkeys.ahk
#Include YkConfig.ahk
#Include YkConfigV3.ahk
#Include YkTray.ahk
#Include YkCounter.ahk
#Include YkChatCmds.ahk
#Include YkEnemies.ahk
#Include YkToast.ahk
#Include YkTools.ahk
#Include YkGuiKit.ahk
#Include YkGui.ahk
#Include YkGuiKeys.ahk
#Include YkGuiPages.ahk

YkMain()
return

; =====================================================================
;  Start
; =====================================================================
YkMain() {
    global YK_IniPath, YK_StartPaused, YK_Paused, YK_V3Seen, YK_Version
    OnExit(Func("YkOnExit"))
    OnError("YkOnError")

    firstRun := !FileExist(YK_IniPath)
    if (firstRun)
        YkWriteDefaultIni()

    YkLoadConfig()
    fromV2 := (!firstRun && YK_V3Seen = "")
    ; Update innerhalb von v3 (3.0.0 schrieb hier noch "3")
    fromV3 := (!firstRun && YK_V3Seen != "" && YK_V3Seen != YK_Version)
    YkZone_Init()
    YkBuildMoveKeys()
    YkApplyPriority()
    YkMark_RestoreState()
    YkCnt_Init()
    YkEnemy_Init()
    YkGame_Groups()

    if (YK_StartPaused)
        YK_Paused := true

    ; Aufruf ueber die Kommandozeile:
    ;     YakuzaKeybinder.exe /einsetzen "C:\Pfad\zum\alten\Ordner"
    ; Setzt diese Fassung dort ein (siehe YkUpd_InstallInto) und beendet
    ; sich wieder - dasselbe macht der Knopf "Fassung woanders einsetzen".
    if (A_Args.Length() >= 2 && A_Args[1] = "/einsetzen") {
        YkUpd_InstallInto(A_Args[2])
        ExitApp
    }

    YkBuildTray()
    YkRegisterAllHotkeys()
    YkInitChatlog()
    YkUpd_CleanOld()
    YkOverlay_Refresh(true)

    SetTimer, YkTick_Do, 250
    SetTimer, YkSprint_Watch, 80
    SetTimer, YkKeys_Watch, 80
    SetTimer, YkSampWatch, 30
    SetTimer, YkKillMemTimer, 50
    SetTimer, YkSecTick, 1000

    ; einmal speichern: legt die neuen Abschnitte aus v3.0 in der INI an
    ; (alle Werte aus v2 bleiben dabei unveraendert)
    YkSaveConfig()

    YkShowGui()
    if (fromV2)
        YkGui_WhatsNew()
    else if (fromV3)
        YkGui_WhatsNewPatch()
}

; Fehler: in YakuzaFehler.log festhalten. Mitten im Spiel keine
; Fehlermeldung aufpoppen lassen - sie wuerde dem Spiel den Fokus nehmen.
YkOnError(e) {
    global YK_Version
    FormatTime, t, , dd.MM.yyyy HH:mm:ss
    msg := t . "  v" . YK_Version . "  " . e.Message . "  |  " . e.What . "  |  Zeile " . e.Line . "`r`n"
    try FileAppend, %msg%, % A_ScriptDir . "\YakuzaFehler.log", UTF-8
    return YkGame_Active() ? true : false
}

; =====================================================================
;  Beenden
; =====================================================================
YkOnExit(reason := "", code := "") {
    try SetTimer, YkTick_Do, Off
    try SetTimer, YkKillMemTimer, Off
    try SetTimer, YkKeys_Watch, Off
    try SetTimer, YkSecTick, Off
    ; nichts gedrueckt zuruecklassen - sonst laeuft die Figur nach dem
    ; Beenden oder Neuladen des Binders von selbst weiter
    try YkKeys_Panic()
    try YkRadio_Stop(true)
    try YkCnt_Save()
    YkMark_ClearAll()
    YkMem_Close()
    return 0
}
