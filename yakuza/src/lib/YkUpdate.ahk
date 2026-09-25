; =====================================================================
;  Yakuza Keybinder - Update
; ---------------------------------------------------------------------
;  Der Binder schaut ab und zu bei einer frei waehlbaren Adresse nach, ob
;  es eine neuere Fassung gibt - und holt sie auf Wunsch auch gleich.
;
;  Die Datei hinter der Adresse ist eine einfache Textdatei:
;
;      Version=2.0.0
;      Info=Mörder-Anzeige, Statistik vom Server, echtes Update
;      Url=https://.../Yakuza_Keybinder_v2.0.0.zip
;
;  "Info" ist freiwillig. OHNE "Url" gibt es nur den Hinweis - dann kann
;  der Binder nichts holen, und genau das sagt er dann auch.
;
;  ABLAUF MIT "Url" (Standard):
;    1. Die Textdatei wird abgeholt und die Version verglichen.
;    2. Ist sie neuer, laedt der Binder die ZIP NEBENHER herunter.
;       Das Spiel merkt davon nichts - es wird nichts gewartet.
;    3. Erst wenn GTA NICHT im Vordergrund ist, fragt er EINMAL, ob
;       installiert werden soll. Nie mitten im Spiel.
;    4. Nach dem Ja: die ZIP wird ausgepackt, die neue Datei geprueft,
;       die alte zur Seite gelegt (YakuzaKeybinder.alt.exe), die neue an
;       ihren Platz kopiert und der Binder neu gestartet.
;       Geht dabei etwas schief, kommt die alte Fassung zurueck.
;
;  WAS GEPRUEFT WIRD, BEVOR ETWAS INSTALLIERT WIRD:
;    - die Download-Adresse muss https sein (nicht http),
;    - die Datei muss wirklich eine ZIP sein (Kennung "PK" am Anfang),
;    - sie muss zwischen 100 KB und 40 MB gross sein,
;    - darin muss eine YakuzaKeybinder.exe liegen, groesser als 500 KB
;      und mit gueltiger Programm-Kennung ("MZ").
;  Passt eines davon nicht, wird NICHTS angefasst.
;
;  Abschalten laesst sich beides getrennt: die Pruefung ("Automatisch
;  prüfen") und das Herunterladen ("Neue Fassung automatisch holen").
; =====================================================================

; Ab Werk eingetragene Adresse: ALLE, die die .exe bekommen, bekommen
; damit den Hinweis automatisch. Ein Eintrag in der YakuzaKeybinder.ini
; (Abschnitt [Update], Url=...) geht davor.
; Dahinter liegt eine Textdatei der Yakuza Family mit einer Zeile
; "Version=...". Zum Verteilen einer neuen Fassung wird dort nur die
; Versionsnummer geaendert.
global YK_UPD_DEFAULT := "https://gist.github.com/marci1160/a08df2cbef9bd6968dd74c9e0b016503/raw"

global YK_UpdEnabled := true
global YK_UpdUrl     := ""
global YK_UpdHours   := 6
global YK_UpdAuto    := true    ; neue Fassung von selbst herunterladen

global g_UpdState    := ""      ; "" | "laeuft" | "aktuell" | "neu" | "fehler" | "aus"
global g_UpdVer      := ""      ; gefundene Version
global g_UpdInfo     := ""      ; kurzer Hinweistext vom Server
global g_UpdLink     := ""      ; Download-Adresse (nur http/https)
global g_UpdErr      := ""      ; Grund, falls es nicht geklappt hat
global g_UpdNextT    := 0       ; naechste Abfrage
global g_UpdReq      := ""      ; laufende Abfrage
global g_UpdReqT     := 0
global g_UpdManual   := false   ; von Hand angestossen?
global g_UpdTold     := ""      ; fuer welche Version wurde schon gemeldet?

; --- Herunterladen und Installieren ---
global g_UpdDl       := ""      ; laufender Download
global g_UpdDlT      := 0
global g_UpdDlState  := ""      ; "" | "laeuft" | "fertig" | "fehler"
global g_UpdDlErr    := ""
global g_UpdDlVer    := ""      ; welche Version liegt fertig da
global g_UpdFile     := ""      ; Pfad der heruntergeladenen ZIP
global g_UpdAsked    := ""      ; fuer welche Version wurde schon gefragt
global g_UpdBusy     := false   ; gerade beim Installieren

; Aus dem Haupttakt (alle 250 ms). Kostet nichts, solange nichts laeuft.
YkUpd_Tick() {
    global YK_UpdEnabled, YK_UpdHours, g_UpdNextT, g_UpdReq, g_UpdDl
    if (IsObject(g_UpdDl))
        YkUpd_DlPoll()
    if (IsObject(g_UpdReq)) {
        YkUpd_Poll()
        return
    }
    ; fertig geladen? Dann im richtigen Moment fragen.
    YkUpd_Offer()
    if (!YK_UpdEnabled || YkUpd_Url() = "")
        return
    if (!g_UpdNextT)                       ; erster Blick ~40 s nach dem Start
        g_UpdNextT := A_TickCount + 40000
    if (A_TickCount < g_UpdNextT)
        return
    h := YK_UpdHours
    if (h < 1)
        h := 1
    g_UpdNextT := A_TickCount + h * 3600000
    YkUpd_Start(false)
}

; Reste eines Updates aufraeumen (die zur Seite gelegte alte Fassung).
; Beim ersten Versuch laeuft sie manchmal noch - dann eben beim naechsten
; Start.
YkUpd_CleanOld() {
    old := A_ScriptDir . "\YakuzaKeybinder.alt.exe"
    if FileExist(old)
        FileDelete, %old%
}

; Gueltige Adresse: aus der INI, sonst die eingebaute
YkUpd_Url() {
    global YK_UpdUrl, YK_UPD_DEFAULT
    u := Trim(YK_UpdUrl)
    if (u = "")
        u := Trim(YK_UPD_DEFAULT)
    u := YkUpd_Fix(u)
    return RegExMatch(u, "i)^https?://[^\s]+$") ? u : ""
}

; Haeufiger Fehler: die Anzeigeseite von GitHub statt der Datei selbst.
; Dahinter steckt HTML, keine Versionsangabe - also still geradebiegen.
YkUpd_Fix(u) {
    ; ohne "https://" davor eingetippt
    if (u != "" && !RegExMatch(u, "i)^[a-z]+://") && RegExMatch(u, "i)^[a-z0-9.\-]+\.[a-z]{2,}/"))
        u := "https://" . u
    if RegExMatch(u, "i)^https?://github\.com/([^/]+)/([^/]+)/blob/(.+)$", m)
        return "https://raw.githubusercontent.com/" . m1 . "/" . m2 . "/" . m3
    if RegExMatch(u, "i)^https?://gist\.github\.com/[^/]+/[0-9a-f]+$") && !InStr(u, "/raw")
        return RTrim(u, "/") . "/raw"
    return u
}

; Abfrage starten (manual = true: von Hand, dann gibt es auch eine
; Rueckmeldung, wenn alles aktuell ist)
YkUpd_Start(manual) {
    global g_UpdReq, g_UpdReqT, g_UpdState, g_UpdManual, g_UpdErr
    if (IsObject(g_UpdReq))
        return false
    u := YkUpd_Url()
    if (u = "") {
        g_UpdState := "aus"
        g_UpdErr := "keine Adresse eingetragen"
        if (manual)
            YkNotify("Update: keine Adresse eingetragen (Einstellungen -> Update-Adresse).")
        return false
    }
    req := ""
    try {
        req := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", u . (InStr(u, "?") ? "&" : "?") . "t=" . A_TickCount, true)
        req.SetRequestHeader("User-Agent", "YakuzaKeybinder/" . YkUpd_Me())
        req.SetTimeouts(4000, 4000, 4000, 8000)
        req.Send()
    } catch e {
        g_UpdState := "fehler"
        g_UpdErr := "Abfrage nicht moeglich"
        if (manual)
            YkNotify("Update: die Abfrage hat nicht funktioniert.")
        return false
    }
    g_UpdReq := req
    g_UpdReqT := A_TickCount
    g_UpdManual := manual
    g_UpdState := "laeuft"
    g_UpdErr := ""
    return true
}

YkUpd_Me() {
    global YK_Version
    return YK_Version
}

; Von Hand angestossen (Tray-Menue oder Knopf im Fenster). Ist gerade
; schon eine Abfrage unterwegs, wird nur der Stand gemeldet.
YkUpd_Manual() {
    global g_UpdReq, g_UpdState
    if (IsObject(g_UpdReq)) {
        YkNotify("Update wird gerade geprüft ...")
        return
    }
    ; ein "neu" von vorhin gleich noch einmal zeigen
    if (g_UpdState = "neu") {
        YkUpd_Show()
        return
    }
    if YkUpd_Start(true)
        YkNotify("Suche nach Updates ...")
}

; Hinweis auf eine gefundene Version - und gleich etwas damit anfangen.
YkUpd_Show() {
    global g_UpdVer, g_UpdInfo, g_UpdLink, g_UpdDlState, g_UpdDlVer, YK_Version
    ; schon fertig geladen -> direkt das Installieren anbieten
    if (g_UpdDlState = "fertig" && g_UpdDlVer = g_UpdVer) {
        YkUpd_Offer()
        return
    }
    ; keine Download-Adresse -> sagen, woran es liegt
    if (Trim(g_UpdLink) = "") {
        YkUpd_NoLink()
        return
    }
    msg := "Neue Version v" . g_UpdVer . " verfügbar (du hast v" . YK_Version . ")."
    if (g_UpdInfo != "")
        msg .= "`n`n" . g_UpdInfo
    ; Waehrend das Spiel vorne ist, KEIN Fenster aufmachen - im Vollbild
    ; kann das Spiel darueber sekundenlang stehen bleiben.
    if (YkGame_Active()) {
        YkNotify(StrReplace(msg, "`n", " "))
        YkUpd_DlStart(false)
        return
    }
    if (g_UpdDlState = "laeuft") {
        YkNotify("Die neue Fassung wird gerade geladen ...")
        return
    }
    msg .= "`n`nJetzt herunterladen? Installiert wird erst nach einer weiteren Nachfrage."
    MsgBox, 0x40024, Yakuza Keybinder, % msg
    IfMsgBox, Yes
        YkUpd_DlStart(true)
}

; Ist die Antwort da? (wartet nicht - fragt nur nach)
YkUpd_Poll() {
    global g_UpdReq, g_UpdReqT, g_UpdState, g_UpdErr, g_UpdManual
    req := g_UpdReq
    if (!IsObject(req))
        return
    done := false
    bad := ""
    try done := req.WaitForResponse(0)
    catch e
        bad := "keine Verbindung"
    if (!done && bad = "") {
        if ((A_TickCount - g_UpdReqT) > 20000) {
            bad := "keine Antwort"
            try req.Abort()
        } else
            return
    }
    txt := ""
    if (bad = "") {
        try {
            if (req.Status != 200)
                bad := "Adresse antwortet mit " . req.Status
            else
                txt := req.ResponseText
        } catch e
            bad := "Antwort nicht lesbar"
    }
    g_UpdReq := ""
    if (bad != "") {
        g_UpdState := "fehler"
        g_UpdErr := bad
        if (g_UpdManual)
            YkNotify("Update: " . bad . ".")
        return
    }
    YkUpd_Handle(txt)
}

; Antworttext auswerten
YkUpd_Handle(txt) {
    global g_UpdState, g_UpdVer, g_UpdInfo, g_UpdLink, g_UpdErr, g_UpdManual, g_UpdTold, YK_Version
    ver := "", info := "", url := ""
    if (!YkUpd_Parse(txt, ver, info, url)) {
        g_UpdState := "fehler"
        g_UpdErr := "keine Versionsangabe gefunden"
        if (g_UpdManual)
            YkNotify("Update: in der Datei steht keine Version.")
        return
    }
    g_UpdVer := ver
    g_UpdInfo := info
    url := YkUpd_RepoZip(url, ver)
    g_UpdLink := RegExMatch(url, "i)^https?://[^\s]+$") ? url : ""
    if (YkUpd_Cmp(ver, YK_Version) <= 0) {
        g_UpdState := "aktuell"
        g_UpdErr := ""
        if (g_UpdManual)
            YkNotify("Du hast die neueste Fassung (v" . YK_Version . ").")
        return
    }
    g_UpdState := "neu"
    g_UpdErr := ""
    ; je Version nur einmal von selbst melden - sonst kaeme der Hinweis
    ; alle paar Stunden wieder
    if (g_UpdManual || g_UpdTold != ver) {
        g_UpdTold := ver
        msg := "Neue Version v" . ver . " verfügbar"
        if (info != "")
            msg .= " - " . YkShorten(info, 60)
        YkNotify(msg)
    }
    ; und gleich im Hintergrund holen (wenn erlaubt und eine Adresse da ist)
    YkUpd_DlStart(false)
    YkGui_SyncState()
}

; =====================================================================
;  NEUE FASSUNG HERUNTERLADEN
; =====================================================================
; Laeuft wie die Versionsabfrage NEBENHER: gestartet und danach nur noch
; abgefragt, ob sie fertig ist. Das Spiel steht dabei keine Millisekunde.
; manual = true: auch starten, wenn "automatisch holen" aus ist.
YkUpd_DlStart(manual) {
    global g_UpdLink, g_UpdVer, g_UpdDl, g_UpdDlT, g_UpdDlState, g_UpdDlErr
    global g_UpdDlVer, g_UpdFile, YK_UpdAuto, YK_Version
    if (IsObject(g_UpdDl))
        return false
    if (!manual && !YK_UpdAuto)
        return false
    if (YkUpd_Cmp(g_UpdVer, YK_Version) <= 0)
        return false
    ; schon geholt?
    if (g_UpdDlVer = g_UpdVer && g_UpdFile != "" && FileExist(g_UpdFile))
        return true
    u := Trim(g_UpdLink)
    if (!YkUpd_DlUrlOk(u)) {
        g_UpdDlState := "fehler"
        g_UpdDlErr := (u = "") ? "keine Download-Adresse hinterlegt" : "Download-Adresse ist nicht https"
        if (manual)
            YkNotify("Update: " . g_UpdDlErr . ".")
        return false
    }
    req := ""
    try {
        req := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", u, true)
        req.SetRequestHeader("User-Agent", "YakuzaKeybinder/" . YkUpd_Me())
        req.SetTimeouts(5000, 5000, 15000, 120000)
        req.Send()
    } catch e {
        g_UpdDlState := "fehler"
        g_UpdDlErr := "Download nicht möglich"
        if (manual)
            YkNotify("Update: der Download hat nicht funktioniert.")
        return false
    }
    g_UpdDl := req
    g_UpdDlT := A_TickCount
    g_UpdDlState := "laeuft"
    g_UpdDlErr := ""
    if (manual)
        YkNotify("Neue Fassung wird geladen ...")
    return true
}

; Ist der Download fertig? (wartet nicht - fragt nur nach)
YkUpd_DlPoll() {
    global g_UpdDl, g_UpdDlT, g_UpdDlState, g_UpdDlErr, g_UpdDlVer, g_UpdFile, g_UpdVer
    req := g_UpdDl
    if (!IsObject(req))
        return
    done := false
    bad := ""
    try done := req.WaitForResponse(0)
    catch e
        bad := "keine Verbindung"
    if (!done && bad = "") {
        if ((A_TickCount - g_UpdDlT) > 180000) {
            bad := "Download dauert zu lange"
            try req.Abort()
        } else
            return
    }
    file := ""
    if (bad = "") {
        try {
            if (req.Status != 200)
                bad := "Download antwortet mit " . req.Status
            else
                file := YkUpd_Save(req)
        } catch e
            bad := "Download nicht lesbar (" . YkUpd_Clean(e.what) . ")"
        if (bad = "" && file = "")
            bad := "Datei konnte nicht gespeichert werden"
    }
    g_UpdDl := ""
    if (bad = "" && !YkUpd_ZipOk(file)) {
        bad := "die geladene Datei ist keine gültige ZIP"
        FileDelete, %file%
        file := ""
    }
    if (bad != "") {
        g_UpdDlState := "fehler"
        g_UpdDlErr := bad
        YkNotify("Update: " . bad . ".")
        YkGui_SyncState()
        return
    }
    g_UpdDlState := "fertig"
    g_UpdDlErr := ""
    g_UpdFile := file
    g_UpdDlVer := g_UpdVer
    YkGui_SyncState()
}

; Taugt diese Adresse zum Herunterladen des Programms?
;
; Fuer die kleine Textdatei mit der Versionsnummer genuegt http - dort
; kann hoechstens eine falsche Zahl stehen. Fuer das PROGRAMM nicht:
; ueber http koennte unterwegs jemand etwas anderes unterschieben.
; Deshalb ausschliesslich https.
;
; Einzige Ausnahme ist der eigene Rechner (127.0.0.1 / localhost). Dorthin
; fuehrt kein Weg durchs Netz, da ist nichts zu unterschieben - und nur so
; laesst sich der ganze Ablauf ueberhaupt durchtesten.
; Steht als "Url" nur das GitHub-Repo da (z.B. .../yakuza-keybinder.git),
; baut v3.0 den Link zur ZIP selbst:
;   https://github.com/NAME/REPO/raw/main/Yakuza_Keybinder_v<Version>.zip
; Mit ".../tree/ZWEIG" wird dieser Zweig genommen. Ein direkter Link zu
; einer .zip bleibt unveraendert.
YkUpd_RepoZip(url, ver) {
    u := Trim(url)
    if (u = "" || RegExMatch(u, "i)\.zip(\?.*)?$"))
        return u
    if !RegExMatch(u, "i)^https?://(?:www\.)?github\.com/([^/\s]+)/([^/\s#?]+?)(?:\.git)?/?(?:tree/([^\s#?]+?))?/?$", m)
        return u
    branch := (m3 != "") ? m3 : "main"
    return "https://github.com/" . m1 . "/" . m2 . "/raw/" . branch . "/Yakuza_Keybinder_v" . ver . ".zip"
}

YkUpd_DlUrlOk(u) {
    u := Trim(u)
    if (u = "")
        return false
    if RegExMatch(u, "i)^https://[^\s]+$")
        return true
    return RegExMatch(u, "i)^http://(127\.0\.0\.1|localhost)(:\d+)?/[^\s]*$") ? true : false
}

; Antwort als Datei ablegen. Liefert den Pfad oder "".
YkUpd_Save(req) {
    dir := YkUpd_TempDir()
    if (dir = "")
        return ""
    file := dir . "\update.zip"
    ; ACHTUNG: FileDelete auf eine nicht vorhandene Datei setzt ErrorLevel,
    ; und innerhalb eines try-Blocks wird daraus eine Ausnahme. Genau daran
    ; ist der erste Download abgebrochen. Also vorher nachsehen.
    if FileExist(file)
        FileDelete, %file%
    st := ""
    try {
        st := ComObjCreate("ADODB.Stream")
        st.Type := 1                 ; binaer
        st.Open()
        st.Write(req.ResponseBody)
        st.SaveToFile(file, 2)       ; 2 = vorhandene ersetzen
        st.Close()
    } catch e
        return ""
    return FileExist(file) ? file : ""
}

YkUpd_TempDir() {
    dir := A_Temp . "\YakuzaKeybinder"
    if !FileExist(dir)
        FileCreateDir, %dir%
    return FileExist(dir) ? dir : ""
}

; Ist das wirklich eine ZIP in plausibler Groesse?
YkUpd_ZipOk(file) {
    if (file = "" || !FileExist(file))
        return false
    FileGetSize, sz, %file%
    if (sz < 102400 || sz > 41943040)          ; 100 KB bis 40 MB
        return false
    f := FileOpen(file, "r")
    if (!IsObject(f))
        return false
    VarSetCapacity(b, 4, 0)
    n := f.RawRead(b, 4)
    f.Close()
    if (n < 4)
        return false
    ; "PK" + 03 04  - die Kennung jeder ZIP
    return (NumGet(b, 0, "UChar") = 0x50 && NumGet(b, 1, "UChar") = 0x4B
        && NumGet(b, 2, "UChar") = 0x03 && NumGet(b, 3, "UChar") = 0x04)
}

; Sieht die entpackte Datei nach unserem Programm aus?
YkUpd_ExeOk(file) {
    if (file = "" || !FileExist(file))
        return false
    FileGetSize, sz, %file%
    if (sz < 512000 || sz > 41943040)
        return false
    f := FileOpen(file, "r")
    if (!IsObject(f))
        return false
    VarSetCapacity(b, 2, 0)
    n := f.RawRead(b, 2)
    f.Close()
    ; "MZ" - die Kennung jedes Windows-Programms
    return (n = 2 && NumGet(b, 0, "UChar") = 0x4D && NumGet(b, 1, "UChar") = 0x5A)
}

; ZIP auspacken.
;
; Zuerst ueber den Explorer (Shell.Application) - das steckt in Windows
; selbst, braucht kein zweites Programm und war im Test nach rund vier
; Sekunden durch. PowerShells "Expand-Archive" kann dasselbe, braucht
; dafuer aber ueber zwanzig Sekunden (es laedt erst sein Modul) - deshalb
; nur als Rueckfallweg, falls der Explorer nichts liefert.
;
; Liefert true, wenn danach eine YakuzaKeybinder.exe im Ordner liegt.
YkUpd_Unzip(zip, dir) {
    if FileExist(dir)
        FileRemoveDir, %dir%, 1
    FileCreateDir, %dir%
    if (!FileExist(dir))
        return false
    ziel := dir . "\YakuzaKeybinder.exe"
    los := false
    try {
        sh := ComObjCreate("Shell.Application")
        src := sh.NameSpace(zip)
        dst := sh.NameSpace(dir)
        if (IsObject(src) && IsObject(dst)) {
            ; 4 = kein Fortschrittsfenster, 16 = alles ueberschreiben,
            ; 512 = keine Rueckfragen, 1024 = keine Fehlerfenster
            dst.CopyHere(src.Items(), 4 | 16 | 512 | 1024)
            los := true
        }
    }
    ; Das Warten steht BEWUSST ausserhalb des try-Blocks: dort wuerde ein
    ; fehlschlagendes FileGetSize zur Ausnahme und die Schleife abbrechen.
    if (los) {
        ; CopyHere arbeitet im Hintergrund weiter - warten, bis die Datei
        ; wirklich vollstaendig da ist (die Groesse steht still)
        last := -1, same := 0, t0 := A_TickCount
        while ((A_TickCount - t0) < 60000) {
            Sleep, 100
            if !FileExist(ziel)
                continue
            FileGetSize, sz, %ziel%
            same := (sz = last) ? same + 1 : 0
            last := sz
            if (same >= 3 && sz > 0)
                break
        }
    }
    if (YkUpd_ExeOk(ziel))
        return true
    ; Rueckfallweg: PowerShell.
    ;
    ; ACHTUNG - hier stand bis v2.0.1 ein RunWait. PowerShell braucht fuer
    ; "Expand-Archive" ueber zwanzig Sekunden (es laedt erst sein Modul),
    ; und RunWait haelt den Binder diese ganze Zeit an: keine Takte, keine
    ; Tastenfreigabe, nichts. Jetzt wird der Vorgang nur GESTARTET und im
    ; Sekundentakt nachgesehen, ob er fertig ist - mit Sleep, das andere
    ; Takte weiterlaufen laesst.
    cmd := "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "
        . """Expand-Archive -LiteralPath '" . zip . "' -DestinationPath '" . dir . "' -Force"""
    pid := 0
    try Run, %cmd%, , Hide, pid
    if (!pid)
        return false
    t0 := A_TickCount
    while ((A_TickCount - t0) < 90000) {
        Sleep, 250
        Process, Exist, %pid%
        if (!ErrorLevel)
            break
    }
    Process, Exist, %pid%
    if (ErrorLevel) {                      ; haengt - nicht weiter warten
        Process, Close, %pid%
        return false
    }
    return YkUpd_ExeOk(ziel) ? true : false
}

; Fragen und - nach einem Ja - installieren.
; Gefragt wird NIE, solange GTA im Vordergrund ist: ein Fenster ueber dem
; Vollbild kann das Spielbild sekundenlang anhalten.
YkUpd_Offer() {
    global g_UpdDlState, g_UpdDlVer, g_UpdAsked, g_UpdBusy, g_UpdInfo, YK_Version
    if (g_UpdBusy || g_UpdDlState != "fertig" || g_UpdDlVer = "")
        return
    if (g_UpdAsked = g_UpdDlVer)
        return
    if (YkGame_Active())
        return
    g_UpdAsked := g_UpdDlVer
    msg := "Version v" . g_UpdDlVer . " ist fertig geladen (du hast v" . YK_Version . ")."
    if (g_UpdInfo != "")
        msg .= "`n`n" . g_UpdInfo
    msg .= "`n`nJetzt installieren? Der Keybinder startet dabei kurz neu."
    MsgBox, 0x40024, Yakuza Keybinder, % msg
    IfMsgBox, Yes
        YkUpd_Install()
}

; Die neue Fassung an ihren Platz bringen.
;
; Eine laufende .exe laesst sich nicht ueberschreiben - umbenennen aber
; schon. Also: alte zur Seite legen, neue an ihren Platz kopieren, neu
; starten. Klappt das Kopieren nicht, kommt die alte sofort zurueck.
YkUpd_Install() {
    global g_UpdFile, g_UpdDlVer, g_UpdBusy, g_UpdDlState, g_UpdDlErr
    if (g_UpdBusy)
        return false
    if (!A_IsCompiled) {
        YkNotify("Update: geht nur mit der fertigen .exe, nicht mit dem Skript.")
        return false
    }
    if (g_UpdFile = "" || !FileExist(g_UpdFile)) {
        YkNotify("Update: die geladene Datei ist nicht mehr da.")
        return false
    }
    ; Nicht waehrend des Spielens. Auspacken heisst: Explorer-Dienst,
    ; Platte, evtl. PowerShell - das kostet Zeit, und die soll dem Spiel
    ; gehoeren. Das Paket liegt fertig da und laeuft nicht weg.
    if (YkGame_Active()) {
        YkNotify("Update: wird eingespielt, sobald du aus dem Spiel bist.")
        return false
    }
    g_UpdBusy := true
    dir := YkUpd_TempDir() . "\neu"
    if (!YkUpd_Unzip(g_UpdFile, dir)) {
        g_UpdBusy := false
        g_UpdDlState := "fehler"
        g_UpdDlErr := "ZIP ließ sich nicht auspacken"
        YkNotify("Update: die ZIP ließ sich nicht auspacken.")
        return false
    }
    neu := dir . "\YakuzaKeybinder.exe"
    if (!YkUpd_ExeOk(neu)) {
        g_UpdBusy := false
        g_UpdDlState := "fehler"
        g_UpdDlErr := "in der ZIP steckt keine gültige YakuzaKeybinder.exe"
        YkNotify("Update: in der ZIP steckt kein gültiges Programm.")
        return false
    }
    ; DEINE EINSTELLUNGEN WERDEN NICHT ANGEFASST.
    ; Ausgetauscht wird ausschliesslich die .exe (und die Anleitung, falls
    ; sie im Paket liegt). Eine YakuzaKeybinder.ini aus dem Paket wird
    ; ABSICHTLICH ignoriert - sonst waeren beim Update alle eigenen Tasten,
    ; Texte und Hotkeys weg. Zur Sicherheit kommt vorher trotzdem eine
    ; Kopie daneben: YakuzaKeybinder.ini.bak
    ini := A_ScriptDir . "\YakuzaKeybinder.ini"
    if FileExist(ini)
        FileCopy, %ini%, % ini . ".bak", 1

    cur := A_ScriptFullPath
    alt := A_ScriptDir . "\YakuzaKeybinder.alt.exe"
    if FileExist(alt)
        FileDelete, %alt%
    FileMove, %cur%, %alt%, 1
    if (ErrorLevel) {
        g_UpdBusy := false
        YkNotify("Update: die alte Datei ließ sich nicht ersetzen (Schreibschutz?).")
        return false
    }
    FileCopy, %neu%, %cur%, 1
    if (ErrorLevel) {
        FileMove, %alt%, %cur%, 1        ; alles zurueck wie vorher
        g_UpdBusy := false
        YkNotify("Update: das Kopieren ist fehlgeschlagen - alte Fassung bleibt.")
        return false
    }
    ; Anleitung mitnehmen, wenn sie dabei ist
    if FileExist(dir . "\ANLEITUNG.txt")
        FileCopy, % dir . "\ANLEITUNG.txt", % A_ScriptDir . "\ANLEITUNG.txt", 1
    ; die eigene INI bleibt unangetastet - Einstellungen gehen nie verloren
    Run, %cur%, %A_ScriptDir%
    Sleep, 800
    ExitApp
}

; =====================================================================
;  DIESE FASSUNG IN EINEN VORHANDENEN ORDNER EINSETZEN
; ---------------------------------------------------------------------
;  Fuer den EINMALIGEN Umstieg von einer alten Fassung. Eine Fassung vor
;  v2.0.0 kann sich nicht selbst austauschen - und wer die ZIP einfach
;  ueber seinen Ordner entpackt, waehrend der Keybinder dort LAEUFT,
;  bekommt von Windows stillschweigend die alte .exe behalten. Man klickt
;  dann weiter auf "Nach Update suchen" und wundert sich.
;
;  Ablauf fuer den Member:
;    1. ZIP irgendwohin entpacken (Desktop, Downloads - egal)
;    2. die entpackte YakuzaKeybinder.exe starten
;    3. Rechtsklick auf das Symbol neben der Uhr ->
;       "Diese Fassung woanders einsetzen ..."
;    4. den bisherigen Keybinder-Ordner auswaehlen
;
;  Getauscht wird nur das Programm (und die Anleitung). Die
;  YakuzaKeybinder.ini im Zielordner bleibt unangetastet, die alte .exe
;  liegt danach als YakuzaKeybinder.vorher.exe daneben.
YkUpd_InstallInto(dir := "") {
    if (!A_IsCompiled) {
        YkNotify("Geht nur mit der fertigen .exe, nicht mit dem Skript.")
        return false
    }
    if (dir = "") {
        FileSelectFolder, dir, , 3, Ordner des bisherigen Keybinders auswählen
        if (dir = "")
            return false
    }
    dir := RTrim(dir, "\")
    ziel := dir . "\YakuzaKeybinder.exe"
    if (dir = RTrim(A_ScriptDir, "\")) {
        MsgBox, 0x40030, Yakuza Keybinder
            , Das ist der Ordner, aus dem diese Fassung gerade läuft.`n`nWähle den Ordner deines BISHERIGEN Keybinders.
        return false
    }
    if (!FileExist(ziel)) {
        MsgBox, 0x40030, Yakuza Keybinder
            , % "In diesem Ordner liegt keine YakuzaKeybinder.exe:`n`n" . dir
            . "`n`nWähle den Ordner, in dem dein bisheriger Keybinder liegt."
        return false
    }
    ; Die alte Fassung zur Seite legen. Laeuft sie noch, ist die Datei
    ; gesperrt - dann sagen wir das, statt irgendetwas zu erzwingen.
    alt := dir . "\YakuzaKeybinder.vorher.exe"
    if FileExist(alt)
        FileDelete, %alt%
    FileMove, %ziel%, %alt%, 1
    if (ErrorLevel) {
        MsgBox, 0x40030, Yakuza Keybinder
            , % "Der Keybinder in diesem Ordner läuft noch:`n`n" . dir
            . "`n`nBitte ihn dort erst beenden (Rechtsklick auf das Symbol neben der Uhr -> Beenden) und es dann noch einmal versuchen."
        return false
    }
    FileCopy, % A_ScriptFullPath, %ziel%, 1
    if (ErrorLevel) {
        FileMove, %alt%, %ziel%, 1            ; alles zurueck wie vorher
        MsgBox, 0x40030, Yakuza Keybinder, Das Kopieren hat nicht geklappt. Es bleibt alles, wie es war.
        return false
    }
    if FileExist(A_ScriptDir . "\ANLEITUNG.txt")
        FileCopy, % A_ScriptDir . "\ANLEITUNG.txt", % dir . "\ANLEITUNG.txt", 1
    ; Die YakuzaKeybinder.ini im Zielordner wird NICHT angefasst.
    MsgBox, 0x40024, Yakuza Keybinder
        , % "Fertig - v" . YkUpd_Me() . " liegt jetzt in:`n`n" . dir
        . "`n`nDeine Einstellungen dort sind unverändert. Die alte Fassung liegt als YakuzaKeybinder.vorher.exe daneben."
        . "`n`nJetzt von dort starten und diese Fassung hier beenden?"
    IfMsgBox Yes
    {
        Run, %ziel%, %dir%
        Sleep, 800
        ExitApp
    }
    return true
}

; "Jetzt aktualisieren" aus dem Fenster oder dem Symbol neben der Uhr
YkUpd_Now() {
    global g_UpdState, g_UpdDlState, g_UpdDlVer, g_UpdVer, g_UpdLink, g_UpdReq
    if (IsObject(g_UpdReq)) {
        YkNotify("Update wird gerade geprüft ...")
        return
    }
    ; noch gar nicht nachgesehen -> erst einmal nachsehen
    if (g_UpdState != "neu" && g_UpdState != "aktuell") {
        YkUpd_Manual()
        return
    }
    if (g_UpdState = "aktuell") {
        YkNotify("Du hast schon die neueste Fassung.")
        return
    }
    if (g_UpdDlState = "fertig" && g_UpdDlVer = g_UpdVer) {
        YkUpd_Install()
        return
    }
    if (g_UpdDlState = "laeuft") {
        YkNotify("Die neue Fassung wird gerade geladen ...")
        return
    }
    if (Trim(g_UpdLink) = "") {
        YkUpd_NoLink()
        return
    }
    YkUpd_DlStart(true)
}

; Es gibt eine neue Fassung, aber keine Download-Adresse. Frueher endete
; der Hinweis hier einfach - man sah "Update verfuegbar" und konnte nichts
; damit anfangen. Jetzt steht wenigstens da, woran es liegt, und die
; Update-Adresse laesst sich oeffnen.
YkUpd_NoLink() {
    global g_UpdVer
    if (YkGame_Active()) {
        YkNotify("Update v" . g_UpdVer . ": keine Download-Adresse hinterlegt (Zeile Url= fehlt).")
        return
    }
    MsgBox, 0x40024, Yakuza Keybinder
        , % "Es gibt die neue Version v" . g_UpdVer . ", aber keine Download-Adresse."
        . "`n`nIn der Update-Datei fehlt die Zeile"
        . "`n     Url=https://.../Yakuza_Keybinder_v" . g_UpdVer . ".zip"
        . "`n`nDie Update-Datei jetzt im Browser öffnen?"
    IfMsgBox, Yes
        YkUpd_Open()
}

; Textdatei auswerten. Erlaubt sind "Version=1.9.2", "Version: 1.9.2"
; oder einfach nur "1.9.2" in der ersten Zeile.
YkUpd_Parse(txt, ByRef ver, ByRef info, ByRef url) {
    ver := "", info := "", url := ""
    if (StrLen(txt) > 4000)
        txt := SubStr(txt, 1, 4000)
    Loop, Parse, txt, `n, `r
    {
        l := Trim(A_LoopField)
        if (l = "" || SubStr(l, 1, 1) = ";" || SubStr(l, 1, 1) = "#" || SubStr(l, 1, 1) = "[")
            continue
        if (ver = "" && RegExMatch(l, "i)^vers(?:ion)?\s*[=:]\s*(.+)$", m))
            ver := YkUpd_Clean(m1)
        else if (info = "" && RegExMatch(l, "i)^(?:info|text|neu|was)\s*[=:]\s*(.+)$", m))
            info := YkUpd_Clean(m1)
        else if (url = "" && RegExMatch(l, "i)^(?:url|link|download)\s*[=:]\s*(.+)$", m))
            url := YkUpd_Clean(m1)
        else if (ver = "" && RegExMatch(l, "^[vV]?(\d+(?:\.\d+){0,3})$", m))
            ver := m1
    }
    ver := RegExMatch(ver, "^[vV]?(\d+(?:\.\d+){0,3})", m) ? m1 : ""
    return (ver != "")
}

; alles Ungewoehnliche raus (Steuerzeichen, zu lang)
YkUpd_Clean(s) {
    s := RegExReplace(Trim(s), "[\x00-\x1F]")
    return SubStr(s, 1, 200)
}

; Versionsvergleich: >0 wenn a neuer als b
YkUpd_Cmp(a, b) {
    pa := StrSplit(Trim(a, " vV"), ".")
    pb := StrSplit(Trim(b, " vV"), ".")
    n := (pa.MaxIndex() > pb.MaxIndex()) ? pa.MaxIndex() : pb.MaxIndex()
    Loop, % n {
        x := (pa[A_Index] != "") ? pa[A_Index] + 0 : 0
        y := (pb[A_Index] != "") ? pb[A_Index] + 0 : 0
        if (x > y)
            return 1
        if (x < y)
            return -1
    }
    return 0
}

; Downloadseite im Browser oeffnen (nur http/https, nichts Lokales)
YkUpd_Open() {
    global g_UpdLink
    u := g_UpdLink
    if (u = "")
        u := YkUpd_Url()
    if !RegExMatch(u, "i)^https?://[^\s]+$") {
        YkNotify("Update: keine Adresse zum Öffnen.")
        return
    }
    try Run, %u%
}

; Ein Satz fuer das Fenster
YkUpd_Text() {
    global g_UpdState, g_UpdVer, g_UpdInfo, g_UpdErr, YK_UpdEnabled
    global g_UpdDlState, g_UpdDlVer, g_UpdDlErr, g_UpdLink
    if (YkUpd_Url() = "")
        return "keine Adresse eingetragen"
    if (g_UpdState = "neu") {
        if (g_UpdDlState = "fertig" && g_UpdDlVer = g_UpdVer)
            return "v" . g_UpdVer . " liegt bereit - auf 'Jetzt aktualisieren' klicken"
        if (g_UpdDlState = "laeuft")
            return "v" . g_UpdVer . " wird geladen ..."
        if (g_UpdDlState = "fehler")
            return "v" . g_UpdVer . ": " . g_UpdDlErr
        if (Trim(g_UpdLink) = "")
            return "v" . g_UpdVer . " da, aber keine Download-Adresse (Url= fehlt)"
        return "v" . g_UpdVer . " verfügbar" . ((g_UpdInfo != "") ? "  ·  " . YkShorten(g_UpdInfo, 30) : "")
    }
    if (g_UpdState = "aktuell")
        return "aktuell"
    if (g_UpdState = "laeuft")
        return "wird geprüft ..."
    if (g_UpdState = "fehler")
        return "nicht erreichbar (" . g_UpdErr . ")"
    return YK_UpdEnabled ? "noch nicht geprüft" : "automatische Prüfung aus"
}

; Kurzfassung fuer die Statuszeile ("" = nichts zu melden)
YkUpd_Badge() {
    global g_UpdState, g_UpdVer, g_UpdDlState, g_UpdDlVer
    if (g_UpdState != "neu")
        return ""
    if (g_UpdDlState = "fertig" && g_UpdDlVer = g_UpdVer)
        return "Update v" . g_UpdVer . " bereit"
    if (g_UpdDlState = "laeuft")
        return "Update v" . g_UpdVer . " wird geladen"
    return "Update v" . g_UpdVer . " verfügbar"
}
