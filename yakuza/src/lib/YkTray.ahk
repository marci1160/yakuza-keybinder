; =====================================================================
;  TRAY-MENUE
; =====================================================================
YkBuildTray() {
    global YK_Version
    Menu, Tray, NoStandard
    Menu, Tray, Add, Keybinder öffnen, YkTray_Dashboard
    Menu, Tray, Add, Pause (an/aus), YkTray_Pause
    Menu, Tray, Add, Overlay an/aus, YkTray_Overlay
    Menu, Tray, Add, Member-Positionen an/aus, YkTray_Members
    Menu, Tray, Add, Hängende Tasten lösen, YkTray_Keys
    Menu, Tray, Add
    Menu, Tray, Add, Nach Update suchen, YkTray_Update
    Menu, Tray, Add, Jetzt aktualisieren, YkTray_UpdateNow
    Menu, Tray, Add, Diese Fassung woanders einsetzen ..., YkTray_InstallInto
    Menu, Tray, Add, Konfiguration neu laden, YkTray_Reload
    Menu, Tray, Add, INI-Datei öffnen, YkTray_OpenIni
    Menu, Tray, Add
    Menu, Tray, Add, Beenden, YkTray_Exit
    Menu, Tray, Default, Keybinder öffnen
    Menu, Tray, Tip, % "Yakuza Keybinder v" . YK_Version
    ; kompiliert steckt das Icon ohnehin in der .exe; als .ahk kommt es
    ; aus den eingebetteten Grafiken
    if (!A_IsCompiled) {
        ico := YkAssets_File("yakuza.ico")
        if (ico != "")
            try Menu, Tray, Icon, % ico
    }
    YkRefreshTray()
}

YkRefreshTray() {
    global YK_Paused, YK_SprintEnabled
    if (YK_Paused)
        Menu, Tray, Check, Pause (an/aus)
    else
        Menu, Tray, Uncheck, Pause (an/aus)
}

YkTray_Dashboard() {
    YkShowGui()
}

YkTray_Pause() {
    YkTogglePause()
}

YkTray_Overlay() {
    YkOverlay_Toggle()
}

YkTray_Members() {
    YkMembers_Toggle()
}

YkTray_Keys() {
    YkAction_KeysPanic()
}

YkTray_Update() {
    YkUpd_Manual()
}

YkTray_UpdateNow() {
    YkUpd_Now()
}

; Einmaliger Umstieg: diese Fassung in den Ordner einer alten einsetzen
YkTray_InstallInto() {
    YkUpd_InstallInto()
}

YkTray_Reload() {
    YkApplyConfig()
    YkGui_LoadValues()
    YkNotify("Konfiguration neu geladen.")
}

YkTray_OpenIni() {
    global YK_IniPath
    Run, % "notepad.exe """ . YK_IniPath . """"
}

YkTray_Exit() {
    ExitApp
}

YkTogglePause() {
    global YK_Paused
    YK_Paused := !YK_Paused
    ; beim Pausieren nichts gedrueckt zuruecklassen
    if (YK_Paused)
        YkKeys_Release()
    YkApplyHotkeyState()
    YkRefreshTray()
    YkNotify("Keybinder " . (YK_Paused ? "PAUSIERT" : "AKTIV"))
    if (YkToast_Allowed() && YkGame_Active())
        YkBigText(YK_Paused ? "~r~Keybinder pausiert" : "~g~Keybinder aktiv", 1500)
    YkGui_SyncState()
}

; Kurze Rueckmeldung.
;
; Laeuft GTA gerade im Vordergrund, wird KEINE Windows-Sprechblase
; angezeigt: ueber einem Vollbildspiel kann die dazu fuehren, dass das
; Spiel kurz die Anzeige verliert (schwarzes Bild, Sekunden Stillstand).
; Stattdessen steht die Meldung im Overlay und in der Statuszeile des
; Einstellungsfensters.
YkNotify(msg) {
    global g_GuiMsg, g_GuiMsgT, g_OvNote, g_OvNoteT, g_MsgLog
    g_GuiMsg := msg
    g_GuiMsgT := A_TickCount
    ; auch in die Liste "Letzte Meldungen" im Fenster
    FormatTime, t, , HH:mm:ss
    g_MsgLog.Push({t: t, text: msg, kind: "info"})
    while (g_MsgLog.MaxIndex() > 200)
        g_MsgLog.RemoveAt(1)
    YkGui_LogMsg(t, msg, "info")
    g_OvNote := msg
    g_OvNoteT := A_TickCount
    YkUpdateStatus()
    YkOverlay_Refresh()
    if (YkGame_Active())
        return
    TrayTip, Yakuza Keybinder, % msg, 3, 1
}
