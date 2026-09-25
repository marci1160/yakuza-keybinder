
; ---------------------------------------------------------------------
;  Globale Zustandsvariablen
; ---------------------------------------------------------------------
global YK_IniPath        := A_ScriptDir . "\YakuzaKeybinder.ini"
global YK_Version        := "3.0.1"
global YK_GameExes       := ""      ; weitere Spielprozesse neben gta_sa.exe (Komma)
global YK_V3Seen         := ""      ; "" = diese INI kommt noch von v2

global YK_Paused         := false
global YK_ActiveHotkeys  := []      ; Aktions-Hotkeys (pausieren bei offenem Chat)
global YK_ActiveChatHotkeys := []   ; Chat-Verfolgung (muessen immer feuern)
global YK_HkOn           := true    ; sind die Aktions-Hotkeys gerade scharf?
global YK_ChatMode       := -1      ; ist der Hotkey-Satz "Chat offen" aktiv? (-1 = neu setzen)
global YK_ChatOpenHk     := ""      ; Hotkey der Chat-Taste, z.B. ~*t
global YK_ChatClosedHks  := []      ; nur bei geschlossenem Chat: Chat-Taste, Enter-Loslassen
global YK_KurzHkList     := []      ; Kurzform-Beobachter (Buchstaben, Ziffern, Leer, Rueck)
global YK_BlockHks       := []      ; Tastensperre waehrend des Sendens
global YK_Binds          := []
global YK_ExtrasOrder    := "hp,armor,loc,veh"   ; Reihenfolge der Zusatzinfos

; Allgemein
global YK_ChatKey        := "t"
global YK_GangCmd        := "/g"
global YK_SendDelay      := 12
global YK_MemEnabled     := true
global YK_StartPaused    := false

; Standort
global YK_LocHotkey      := "^g"
global YK_LocPrefix      := "Standort:"
global YK_LocFormat      := "{zone} ({city})"
global YK_LocText        := "Standort: {standort}"   ; ein Text mit Platzhaltern

; Kampf (Kill/Tod)
global YK_CombatEnabled  := true
global YK_ChatlogPath    := ""
global YK_KillEnabled    := true
global YK_KillPattern    := ""
global YK_KillPrefix     := "Kill in"
global YK_KillFormat     := "{zone} ({city})"
global YK_KillText       := "Kill in {standort}"
global YK_KillHotkey     := "^k"
global YK_DeathEnabled   := true
global YK_DeathPattern   := ""
global YK_DeathPrefix    := "Tod in"
global YK_DeathFormat    := "{zone} ({city})"
global YK_DeathText      := "Tod in {standort}"
global YK_DeathByHealth  := true
global YK_ReportCooldown := 3000

; FamilyMap
global YK_FamEnabled     := true
global YK_FamCommand     := "/familymap"
global YK_FamLoginPat    := "Willkommen auf"
global YK_FamConnectPat  := "Connecting to"
global YK_FamDelay       := 5000
global YK_FamHotkey      := "^m"
global YK_FamOnce        := true

; Sprint
global YK_SprintEnabled  := true
global YK_SprintKey      := "Space"
global YK_SprintMoveKeys := "w,a,s,d,Up,Down,Left,Right"
global YK_SprintToggleHk := "^Space"
global YK_SprintTapDown  := 30
global YK_SprintTapUp    := 30
global YK_SprintOnFoot   := true
global YK_SprintReqMove  := true
global YK_CrouchKey      := "c"     ; Ducken-Taste im Spiel
global YK_CrouchHk       := ""      ; Sperr-Hotkey dieser Taste (*scXXX) oder ""
global YK_CrouchSc       := 0
global g_SprintCrouched  := false   ; beim Sprint-Tippen geduckt -> bis zum naechsten Leertasten-Druck ruhen
global g_CrouchT         := 0       ; letzter Druck auf die Ducken-Taste
global g_BlockReplay     := []      ; beim Senden verschluckte Tasten (Scancodes) zum Nachreichen
global g_UpWatch         := []      ; nachgereichte Tasten, die noch losgelassen werden muessen [vk, sc, seit]

; interne Laufzeit-Variablen
global g_ChatOpen        := false
global g_LastKeyActivity := 0
global g_Sending         := false
global g_LastPos         := ""      ; zuletzt bekannter guter Standort
global g_OnFoot          := true
global g_PrevHp          := 100
global g_DeathReported   := false
global g_FamilyDone      := false
global g_FamilyPending   := 0
global g_LastKillReport  := 0
global g_LastDeathReport := 0
global g_ChatlogPos      := 0
global g_ChatlogFile     := ""
global g_ChatSeen        := []      ; zuletzt verarbeitete Zeilen [{s, t}] gegen Wiederholungen
global g_SendStartT      := 0       ; wann das Senden begonnen hat (Waechter)
global g_HeldByUs        := []      ; Tasten, die der Binder selbst unten haelt [[vk, sc]]
global g_SampKnown       := false   ; Chat-/Dialog-Zustand direkt aus samp.dll lesbar?
global g_SampChat        := false   ; konkret die Chat-Eingabe offen (fuer Kurzformen)
global g_ChatKeyTick     := 0       ; letzter Druck auf die Chat-Taste
global g_SendEndTick     := 0       ; Ende des letzten eigenen Sendens
global g_PendingSends    := []
global g_LastQueueSend   := 0
global YK_SprintHeld     := false   ; physischer Zustand (nur von Down/Up-Hotkey gesetzt)
global YK_SprintMode     := ""      ; "" | "passthrough" | "tapping"
global YK_SprintLoopBusy := false
global YK_SprintHooked   := false   ; ist der blockierende Hotkey aktuell installiert?
global YK_SprintHkDown   := ""
global YK_SprintHkUp     := ""
global YK_MoveKeysArr     := []

; Schnell senden (siehe YkSendFast)
global YK_FastSend       := true    ; Chat per Fenster-Nachricht: Figur bleibt beim Laufen nicht stehen
global g_FastMode        := ""      ; "" ungeprueft | "char"/"key" bestaetigt | "no" geht nicht
global g_FastTries       := 0
global g_FastPid         := 0
global g_FastOpen        := ""      ; "" ungeprueft | "down" Chat-Taste mit Druecken | "up" nur Zeichen + Loslassen

; GUI-Handles
global YkGuiOpen         := false
global YkGuiHwnd         := 0
global g_GuiLoadT        := 0       ; GUI-Werte gerade von aussen gesetzt (Aenderungen dann ignorieren)
global g_OvLvFillT       := 0       ; Hotkey-Auswahl im Overlay-Tab gerade neu gefuellt
global g_GuiMsg          := ""      ; kurze Meldung in der Statuszeile
global g_GuiMsgT         := 0
global g_MemLvT          := 0
global g_MemRows         := []      ; Namen in der Member-Liste, Zeile fuer Zeile

; Server-Befehle
global YK_CmdList        := []     ; eingebaute Befehls-Datenbank
global YK_CmdBinds       := {}     ; Befehl -> {hk, kurz, enter}
global YK_CmdRows        := []     ; aktuell angezeigte Zeilen
global YK_KurzEnabled    := true
global YK_KurzHkOn       := false
global g_KurzBuf         := ""
global g_KurzOk          := true
