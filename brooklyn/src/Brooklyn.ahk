; =====================================================================
;   KEYBINDER VON BROOKLYN  -  Version 5
;   fuer SA-MP 0.3.7 (R1-R5), 0.3.DL und open.mp  ·  jeder Server
; ---------------------------------------------------------------------
;   Neuauflage des "Keybinder von Brooklyn" 4.60. Alle Befehle und
;   Funktionen bleiben, aber:
;     - keine Brooklyn.dll, keine getGametext.dll, keine Downloads,
;       kein Server des Erstellers mehr noetig
;     - laeuft mit normalem SA-MP (gta_sa.exe), kein RGN-Launcher noetig
;     - neuere SA-MP-Versionen (0.3.7-R3/R5, 0.3.DL)
;     - Profile: Zivilist / Gang / Staatsfraktion + Job
;     - neues, modernes Fenster
;
;   Technik: reiner Tastensender + LESENDER Zugriff auf gta_sa.exe und
;   samp.dll. Nichts wird injiziert.
;   AutoHotkey v1.1 (Unicode 32-Bit), kompiliert als BrooklynKeybinder.exe
; =====================================================================

;@Ahk2Exe-SetName Brooklyn Keybinder
;@Ahk2Exe-SetDescription Keybinder von Brooklyn fuer SA-MP
;@Ahk2Exe-SetVersion 5.0.0
;@Ahk2Exe-SetCopyright Keybinder von Brooklyn
;@Ahk2Exe-SetMainIcon brooklyn.ico

#NoEnv
#SingleInstance Force
#Persistent
#MaxThreadsPerHotkey 1
#MaxHotkeysPerInterval 1000
#HotkeyInterval 2000
#InstallKeybdHook
#UseHook
SetWorkingDir %A_ScriptDir%
SetBatchLines, -1
Thread, Interrupt, 0
SetTitleMatchMode, 2
ListLines, Off
SetKeyDelay, -1, -1
FileEncoding, UTF-8

global BK_Version := "5.0.0"
global g_ImportNote := ""

#Include %A_ScriptDir%\lib
#Include BkGlobals.ahk
#Include BkZones.ahk
#Include BkMemory.ahk
#Include BkMemExtra.ahk
#Include BkSend.ahk
#Include BkMaps.ahk
#Include BkBinds.ahk
#Include BkConfig.ahk
#Include BkStats.ahk
#Include BkEngine.ahk
#Include BkActions.ahk
#Include BkChatlog.ahk
#Include BkEnemies.ahk
#Include BkOverlay.ahk
#Include BkExtras.ahk
#Include BkGuiKit.ahk
#Include BkGui.ahk

BkMain()
return

; =====================================================================
;  Start
; =====================================================================
BkMain() {
    global BK_StartMin, g_ImportNote, BK_Keys, BK_Debug
    OnError("BkOnError")
    BkCfg_Init()
    BkStats_Init()
    BkIndex_Build()
    BkEnemy_Init()
    BkGame_Groups()
    BkChatlog_Init()
    BkTray_Build()
    BkRegisterHotkeys()
    BkGui_Build()
    OnExit("BkOnExit")

    SetTimer, BkT_Watch, 30
    SetTimer, BkT_Fast, 150
    SetTimer, BkT_Slow, 250
    SetTimer, BkT_Sec, 1000

    if (!BK_StartMin)
        BkGui_Show()
    if (g_ImportNote != "")
        TrayTip, Brooklyn Keybinder, %g_ImportNote%, 5
    else if (!BK_StartMin)
        TrayTip, Brooklyn Keybinder, Bereit. Die Tasten wirken nur im Spiel., 3
}

; Fenstergruppe mit allen Spielprozessen (normal: gta_sa.exe)
BkGame_Groups() {
    for i, exe in BkGame_ExeList()
        GroupAdd, BkGame, % "ahk_exe " . exe
}

; Laufzeitfehler protokollieren (fuer Fehlermeldungen an den Entwickler)
BkOnError(e) {
    global BK_Dir, BK_Version
    FormatTime, ts, , dd.MM.yyyy HH:mm:ss
    f := (BK_Dir != "" ? BK_Dir : A_ScriptDir) . "\Fehler.log"
    FileAppend, % ts . "  v" . BK_Version . "  " . e.Message . "  |  " . e.What . "  |  " . e.Extra . "  |  " . e.File . ":" . e.Line . "`r`n", %f%, UTF-8
    return false
}

BkOnExit() {
    BkShutdown()
    return 0
}

BkShutdown() {
    global g_GuiBuilt
    static done := false
    if (done)
        return
    done := true
    try BkStats_Save()
    try BkRadio_Stop()
    try BkKeys_Panic()
    try BkMem_Close()
}

; =====================================================================
;  Takt
; =====================================================================
; 30 ms: Chat/Dialog offen? (Hotkeys still legen)
BkT_Watch() {
    global BK_MemEnabled
    if (BK_MemEnabled)
        BkMem_Ensure()
    BkSampWatch()
}

; 150 ms: Chatlog, Warteschlange
BkT_Fast() {
    BkChatlog_Poll()
    BkQueue_Tick()
}

; 250 ms: GameText (Gangwar-Kills), Tod
BkT_Slow() {
    BkGameText_Poll()
    BkDeath_Tick()
}

; 1 s: Spielzeit, Speichern, Anzeigen
BkT_Sec() {
    static n := 0
    n += 1
    BkPlaytime_Tick()
    BkCpuLoad()
    BkHud_Tick()
    BkGui_StatusRefresh()
    BkGui_StatsRefresh()
    if (Mod(n, 10) = 0)
        BkStats_Tick()
    BkTray_Update()
}

; =====================================================================
;  Infobereich (Tray)
; =====================================================================
BkTray_Build() {
    Menu, Tray, NoStandard
    Menu, Tray, Tip, Brooklyn Keybinder
    Menu, Tray, Add, Öffnen, BkTray_Open
    Menu, Tray, Add, Pausieren, BkTray_Pause
    Menu, Tray, Add
    Menu, Tray, Add, Hängende Tasten lösen, BkTray_Panic
    Menu, Tray, Add, Neu starten, BkTray_Reload
    Menu, Tray, Add
    Menu, Tray, Add, Beenden, BkTray_Exit
    Menu, Tray, Default, Öffnen
    Menu, Tray, Click, 2
    if (!A_IsCompiled && FileExist(A_ScriptDir . "\brooklyn.ico"))
        Menu, Tray, Icon, % A_ScriptDir . "\brooklyn.ico"
}

BkTray_Update() {
    global BK_Paused
    static last := -1
    if (last = BK_Paused)
        return
    last := BK_Paused
    try Menu, Tray, Rename, % (BK_Paused ? "Pausieren" : "Fortsetzen"), % (BK_Paused ? "Fortsetzen" : "Pausieren")
    Menu, Tray, Tip, % "Brooklyn Keybinder" . (BK_Paused ? " (pausiert)" : "")
}

BkTray_Open() {
    BkGui_Show()
}
BkTray_Pause() {
    BkFn_TogglePause()
}
BkTray_Panic() {
    BkFn_Panic()
}
BkTray_Reload() {
    BkShutdown()
    Reload
}
BkTray_Exit() {
    ExitApp
}

; =====================================================================
;  Timer-Sprungmarken
; =====================================================================
BkGuiProfApply:
    BkGui_ProfApply()
return
BkGuiKeysFill:
    BkGui_KeysFill()
return
BkGuiChatFill:
    BkGui_ChatFill()
return
BkGuiApply:
    BkGui_Apply()
return
BkOvTick:
    BkOv_Tick()
return
BkOvCdTick:
    BkOvCd_Tick()
return
BkKeyUpWatch:
    BkKeyUp_Tick()
return
BkTimerCheck:
    BkTimer_Check()
return
