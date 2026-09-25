; =====================================================================
;  Yakuza Keybinder - Einstellungen, die mit v3.0 dazugekommen sind
; ---------------------------------------------------------------------
;  Alles bleibt in derselben YakuzaKeybinder.ini neben dem Programm. Die
;  Abschnitte aus v2 werden nicht angefasst - wer von v2.0.2 kommt,
;  behaelt Tasten, Texte, Server-Befehle und Kurzformen 1:1. Neue
;  Abschnitte haben einfach Werkseinstellungen, solange sie fehlen.
;
;    [General]            GameExes, LineDelay, FamChat, ChatCmds
;    [Keys]               Funktionstasten (Pause, Fenster, Gruss ...)
;    [ChatBefehle]        Aus = ausgeschaltete Chat-Befehle
;    [ChatTexte]          eigene Texte fuer Chat-Befehle
;    [ChatTasten]         Chat-Befehle auf einer Taste
;    [EigeneChatbefehle]  eigene Chat-Befehle
;    [SMS]                Befehl und Erkennung fuer /re
;    [Meldungen]          Karten im Spiel
;    [Extras]             Radio, Aufnahmen, Pfad zum Spiel
;    [Gegnerlisten]       siehe YkEnemies.ahk
; =====================================================================

; Mehrzeilige Texte: Zeilenumbruch als \n (und \ als \\)
YkIni_Enc(v) {
    v := StrReplace(v, "\", "\\")
    v := StrReplace(v, "`r`n", "\n")
    v := StrReplace(v, "`n", "\n")
    return v
}

YkIni_Dec(v) {
    out := "", i := 1, n := StrLen(v)
    while (i <= n) {
        c := SubStr(v, i, 1)
        if (c = "\" && i < n) {
            d := SubStr(v, i + 1, 1)
            if (d = "n") {
                out .= "`n", i += 2
                continue
            }
            if (d = "\") {
                out .= "\", i += 2
                continue
            }
        }
        out .= c, i += 1
    }
    return out
}

; Wert mit Leerzeichen am Rand bleibt erhalten (Anfuehrungszeichen)
YkIni_Put(v, file, sec, key) {
    IniWrite, % """" . YkIni_Enc(v) . """", %file%, %sec%, %key%
}

YkIni_Get(file, sec, key, def) {
    v := YkIniRead(file, sec, key, Chr(1))
    if (v == Chr(1))
        return def
    return YkIni_Dec(v)
}

; Alle Schluessel eines Abschnitts als {key: value}
YkIni_Section(file, sec) {
    out := {}
    IniRead, body, %file%, %sec%
    if (body = "ERROR")
        return out
    Loop, Parse, body, `n, `r
    {
        p := InStr(A_LoopField, "=")
        if (!p)
            continue
        k := Trim(SubStr(A_LoopField, 1, p - 1))
        v := Trim(SubStr(A_LoopField, p + 1))
        if (StrLen(v) >= 2 && SubStr(v, 1, 1) = """" && SubStr(v, 0) = """")
            v := SubStr(v, 2, StrLen(v) - 2)
        if (k != "")
            out[k] := YkIni_Dec(v)
    }
    return out
}

YkLoadConfigV3(p) {
    global YK_GameExes, YK_LineDelay, YK_FamChat, YK_TbEnabled, YK_FnKeys, YK_TbOff, YK_TbTexts, YK_TbKeys, YK_CustomTb
    global YK_SmsCmd, YK_SmsPattern, YK_ToastOn, YK_ToastMs, YK_ToastSide
    global YK_RadioChan, YK_RadioUrl, YK_RadioVol, YK_RecKey, YK_RecFolder, YK_FragFolder, YK_ComplaintFolder, YK_PathGame
    global YK_V3Seen

    YK_GameExes  := Trim(YkIniRead(p, "General", "GameExes", ""))
    YK_Debug     := (YkIniRead(p, "General", "Debug", 0) + 0) != 0
    YK_LineDelay := YkIniRead(p, "General", "LineDelay", 250) + 0
    if (YK_LineDelay < 0 || YK_LineDelay > 5000)
        YK_LineDelay := 250
    YK_FamChat   := Trim(YkIniRead(p, "General", "FamChat", "/f"))
    if (YK_FamChat = "")
        YK_FamChat := "/f"
    YK_TbEnabled := (YkIniRead(p, "General", "ChatCmds", 1) + 0) != 0
    ; war diese INI schon einmal unter v3 in Benutzung? (fuer den Hinweis
    ; "Das ist neu" beim ersten Start nach dem Update)
    YK_V3Seen := YkIniRead(p, "General", "V3Seen", "")

    YK_FnKeys := {}
    for i, f in YkFnKeys()
        YK_FnKeys[f.id] := YkHk_Normalize(YkIniRead(p, "Keys", f.id, f.def))

    YK_TbOff := {}
    for i, c in StrSplit(YkIniRead(p, "ChatBefehle", "Aus", ""), ",") {
        c := Trim(c)
        if (c != "")
            YK_TbOff[c] := 1
    }
    YK_TbTexts := YkIni_Section(p, "ChatTexte")
    YK_TbKeys := {}
    for cmd, k in YkIni_Section(p, "ChatTasten") {
        k := YkHk_Normalize(k)
        if (k != "")
            YK_TbKeys[cmd] := k
    }
    YK_CustomTb := []
    n := YkIniRead(p, "EigeneChatbefehle", "Anzahl", 0) + 0
    Loop, % n {
        c := Trim(YkIni_Get(p, "EigeneChatbefehle", "C" . A_Index . "Cmd", ""))
        t := YkIni_Get(p, "EigeneChatbefehle", "C" . A_Index . "Text", "")
        if (c != "")
            YK_CustomTb.Push({cmd: c, text: t})
    }

    YK_SmsCmd     := Trim(YkIniRead(p, "SMS", "Command", "/sms"))
    YK_SmsPattern := YkIni_Get(p, "SMS", "Pattern", YK_SmsPattern)

    YK_ToastOn   := (YkIniRead(p, "Meldungen", "Enabled", 1) + 0) != 0
    YK_ToastMs   := YkIniRead(p, "Meldungen", "Ms", 5000) + 0
    if (YK_ToastMs < 1500 || YK_ToastMs > 30000)
        YK_ToastMs := 5000
    YK_ToastSide := YkIniRead(p, "Meldungen", "Side", "auto")
    if (YK_ToastSide != "links" && YK_ToastSide != "rechts")
        YK_ToastSide := "auto"

    YK_RadioChan := YkIniRead(p, "Extras", "RadioChan", 1) + 0
    YK_RadioUrl  := Trim(YkIniRead(p, "Extras", "RadioUrl", ""))
    YK_RadioVol  := YkIniRead(p, "Extras", "RadioVol", 60) + 0
    YK_RecKey    := Trim(YkIniRead(p, "Extras", "RecKey", "F9"))
    YK_RecFolder := Trim(YkIniRead(p, "Extras", "RecFolder", ""))
    YK_FragFolder := Trim(YkIniRead(p, "Extras", "FragFolder", ""))
    YK_ComplaintFolder := Trim(YkIniRead(p, "Extras", "ComplaintFolder", ""))
    YK_PathGame  := Trim(YkIniRead(p, "Extras", "PathGame", ""))
}

YkSaveConfigV3(p) {
    global YK_GameExes, YK_LineDelay, YK_FamChat, YK_TbEnabled, YK_FnKeys, YK_TbOff, YK_TbTexts, YK_TbKeys, YK_CustomTb
    global YK_SmsCmd, YK_SmsPattern, YK_ToastOn, YK_ToastMs, YK_ToastSide
    global YK_RadioChan, YK_RadioUrl, YK_RadioVol, YK_RecKey, YK_RecFolder, YK_FragFolder, YK_ComplaintFolder, YK_PathGame

    IniWrite, % YK_GameExes, % p, General, GameExes
    IniWrite, % YK_LineDelay, % p, General, LineDelay
    IniWrite, % YK_FamChat, % p, General, FamChat
    IniWrite, % (YK_TbEnabled ? 1 : 0), % p, General, ChatCmds
    IniWrite, 3, % p, General, V3Seen

    for i, f in YkFnKeys()
        IniWrite, % YK_FnKeys[f.id], % p, Keys, % f.id

    off := ""
    for c, v in YK_TbOff
        if (v)
            off .= (off = "" ? "" : ",") . c
    IniWrite, % off, % p, ChatBefehle, Aus

    IniDelete, % p, ChatTexte
    for c, t in YK_TbTexts
        YkIni_Put(t, p, "ChatTexte", c)
    IniDelete, % p, ChatTasten
    for c, k in YK_TbKeys
        if (k != "")
            IniWrite, % k, % p, ChatTasten, % c

    IniDelete, % p, EigeneChatbefehle
    IniWrite, % YkCnt(YK_CustomTb), % p, EigeneChatbefehle, Anzahl
    for i, c in YK_CustomTb {
        YkIni_Put(c.cmd, p, "EigeneChatbefehle", "C" . i . "Cmd")
        YkIni_Put(c.text, p, "EigeneChatbefehle", "C" . i . "Text")
    }

    IniWrite, % YK_SmsCmd, % p, SMS, Command
    YkIni_Put(YK_SmsPattern, p, "SMS", "Pattern")

    IniWrite, % (YK_ToastOn ? 1 : 0), % p, Meldungen, Enabled
    IniWrite, % YK_ToastMs, % p, Meldungen, Ms
    IniWrite, % YK_ToastSide, % p, Meldungen, Side

    IniWrite, % YK_RadioChan, % p, Extras, RadioChan
    IniWrite, % YK_RadioUrl, % p, Extras, RadioUrl
    IniWrite, % YK_RadioVol, % p, Extras, RadioVol
    IniWrite, % YK_RecKey, % p, Extras, RecKey
    IniWrite, % YK_RecFolder, % p, Extras, RecFolder
    IniWrite, % YK_FragFolder, % p, Extras, FragFolder
    IniWrite, % YK_ComplaintFolder, % p, Extras, ComplaintFolder
    IniWrite, % YK_PathGame, % p, Extras, PathGame
}
