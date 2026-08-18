_Title "QB64-LINUX Enterprise"
Cls
Randomize Timer

Declare Sub TermPrint (txt$)

Dim Shared fNames$(100)
Dim Shared fContents$(100)
Dim Shared fCount As Integer
Dim Shared nanoLines$(100), nanoCount As Integer
Dim Shared hist$(50), histCount As Integer

Dim Shared termLines$(500)
Dim Shared termLineCount As Integer
Dim Shared termScrollOffset As Integer

' Redirection State Variables
Dim Shared redirecting As Integer
Dim Shared redirBuffer$

' Multimedia Handles
Dim Shared currentSound As Long

' === FIXED VFS LOADER (Uses Line Input to prevent comma splitting) ===
If _FileExists("qblinux_vfs.dat") Then
    Open "qblinux_vfs.dat" For Input As #1
    Line Input #1, tmpCount$
    fCount = Val(tmpCount$)
    For i = 1 To fCount
        Line Input #1, fNames$(i)
        Line Input #1, rawCont$
        cleanCont$ = ""
        nlPos = 1
        Do
            p = InStr(nlPos, rawCont$, "~NL~")
            If p = 0 Then
                cleanCont$ = cleanCont$ + Mid$(rawCont$, nlPos)
                Exit Do
            Else
                cleanCont$ = cleanCont$ + Mid$(rawCont$, nlPos, p - nlPos) + Chr$(13) + Chr$(10)
                nlPos = p + 4
            End If
        Loop
        fContents$(i) = cleanCont$
    Next i
    Close #1
Else
    fCount = 4
    fNames$(1) = "username.txt": fContents$(1) = "root"
    fNames$(2) = "hello.bas": fContents$(2) = "10 CLS" + Chr$(13) + Chr$(10) + "20 COLOR 11" + Chr$(13) + Chr$(10) + "30 PRINT " + Chr$(34) + "Welcome to QB64-LINUX" + Chr$(34) + Chr$(13) + Chr$(10) + "40 COLOR 14" + Chr$(13) + Chr$(10) + "50 SOUND 440, 5" + Chr$(13) + Chr$(10) + "60 COLOR 7"
    fNames$(3) = "sysinfo.sh": fContents$(3) = "uname -a" + Chr$(13) + Chr$(10) + "neofetch" + Chr$(13) + Chr$(10) + "uptime"
    fNames$(4) = "calc.bas": fContents$(4) = "10 CLS" + Chr$(13) + Chr$(10) + "20 PRINT " + Chr$(34) + "Advanced Calculator" + Chr$(34) + Chr$(13) + Chr$(10) + "30 INPUT " + Chr$(34) + "Enter first:" + Chr$(34) + ", a" + Chr$(13) + Chr$(10) + "40 INPUT " + Chr$(34) + "Enter second:" + Chr$(34) + ", b" + Chr$(13) + Chr$(10) + "50 PRINT " + Chr$(34) + "Sum:" + Chr$(34) + ", a + b"
    GoSub SaveVFSToDisk
End If

Cls

currentUser$ = "root"
For i = 1 To fCount
    If LCase$(fNames$(i)) = LCase$("username.txt") Then
        tempUser$ = fContents$(i)
        crPos = InStr(tempUser$, Chr$(13))
        If crPos > 0 Then tempUser$ = Left$(tempUser$, crPos - 1)
        tempUser$ = LTrim$(RTrim$(tempUser$))
        If tempUser$ <> "" Then currentUser$ = tempUser$
        Exit For
    End If
Next i

Call TermPrint("[ QB64-Linux 1.0 (Rick Sanchez) ] - Kernel 6.5.0-qb64-generic x86_64")
Call TermPrint("Type 'help' for command manual.")

BashPrompt:
Screen 0
Color 7, 0

GoSub RenderTerminalViewport

If termLineCount < 19 Then
    promptRow = termLineCount + 1
Else
    promptRow = 20
End If

Color 10, 0: Locate promptRow, 1: Print currentUser$; "@qb64-linux";
Color 7, 0: Print ":~# ";

_KeyClear
Input "", cmd$

cmd$ = LTrim$(RTrim$(cmd$))
If cmd$ = "" Then GoTo BashPrompt

If histCount < 50 Then
    histCount = histCount + 1
    hist$(histCount) = cmd$
Else
    For h = 1 To 49: hist$(h) = hist$(h + 1): Next h
    hist$(50) = cmd$
End If

Call TermPrint("~PROMPT~" + currentUser$ + "@qb64-linux:~# " + cmd$)
GoSub ExecuteCommand
GoTo BashPrompt

RenderTerminalViewport:
Cls
If termLineCount > 19 Then
    termScrollOffset = termLineCount - 19
Else
    termScrollOffset = 0
End If

For r = 1 To 19
    idx = r + termScrollOffset
    Locate r, 1
    If idx <= termLineCount Then
        txt$ = termLines$(idx)
        If Left$(txt$, 8) = "~PROMPT~" Then
            pText$ = Mid$(txt$, 9)
            sepPos = InStr(pText$, ":~# ")
            If sepPos > 0 Then
                Color 10, 0: Print Left$(pText$, sepPos - 1);
                Color 7, 0: Print Mid$(pText$, sepPos)
            Else
                Color 7, 0: Print pText$
            End If
        Else
            Color 7, 0: Print txt$
        End If
    Else
        Print ""
    End If
Next r
Return

ExecuteCommand:
' Handle redirection > and >>
redirecting = 0
redirBuffer$ = ""
redirFile$ = ""
redirAppend = 0

pRedir2 = InStr(cmd$, " >> ")
pRedir1 = InStr(cmd$, " > ")

If pRedir2 > 0 Then
    redirFile$ = LTrim$(RTrim$(Mid$(cmd$, pRedir2 + 4)))
    cmd$ = LTrim$(RTrim$(Left$(cmd$, pRedir2 - 1)))
    redirAppend = 1
    redirecting = 1
ElseIf pRedir1 > 0 Then
    redirFile$ = LTrim$(RTrim$(Mid$(cmd$, pRedir1 + 3)))
    cmd$ = LTrim$(RTrim$(Left$(cmd$, pRedir1 - 1)))
    redirAppend = 0
    redirecting = 1
End If

If Left$(cmd$, 2) = "./" Then
    arg$ = Mid$(cmd$, 3)
    firstWord$ = "bash"
Else
    spacePos = InStr(cmd$, " ")
    If spacePos > 0 Then
        firstWord$ = LCase$(Left$(cmd$, spacePos - 1))
        arg$ = LTrim$(RTrim$(Mid$(cmd$, spacePos + 1)))
    Else
        firstWord$ = LCase$(cmd$)
        arg$ = ""
    End If
End If

' File Management & Utilities
If firstWord$ = "rm" Then GoTo RmCmd
If firstWord$ = "mv" Then GoTo MvCmd
If firstWord$ = "touch" Then GoTo TouchCmd
If firstWord$ = "cat" Then GoTo CatCmd
If firstWord$ = "nano" Then GoTo NanoCmd
If firstWord$ = "ls" Then GoTo LsCmd

' Multimedia Engine Handlers
If firstWord$ = "view" Then GoTo ViewCmd
If firstWord$ = "play" Then GoTo PlayCmd
If firstWord$ = "video" Then GoTo VideoCmd

If firstWord$ = "sudo" Or firstWord$ = "apt" Or firstWord$ = "apt-get" Then GoTo AptManagerCmd
If firstWord$ = "cal" Then GoTo CalCmd
If firstWord$ = "tree" Then GoTo TreeCmd
If firstWord$ = "curl" Then GoTo CurlCmd
If firstWord$ = "base64" Then GoTo Base64Cmd
If firstWord$ = "which" Then GoTo WhichCmd
If firstWord$ = "head" Then GoTo HeadCmd
If firstWord$ = "tail" Then GoTo TailCmd
If firstWord$ = "wc" Then GoTo WcCmd
If firstWord$ = "banner" Then GoTo BannerCmd
If firstWord$ = "cowsay" Then GoTo CowsayCmd
If firstWord$ = "fortune" Then GoTo FortuneCmd
If firstWord$ = "matrix" Or firstWord$ = "cmatrix" Then GoTo MatrixCmd
If firstWord$ = "figlet" Then GoTo FigletCmd
If firstWord$ = "toilet" Then GoTo ToiletCmd
If firstWord$ = "sl" Then GoTo SlCmd
If firstWord$ = "rev" Then GoTo RevCmd
If firstWord$ = "factor" Then GoTo FactorCmd
If firstWord$ = "help" Then GoTo HelpCmd
If firstWord$ = "games" Then GoTo GamesCmd
If firstWord$ = "neofetch" Then GoTo NeofetchCmd
If firstWord$ = "uptime" Then GoTo UptimeCmd
If firstWord$ = "htop" Then GoTo HtopCmd
If firstWord$ = "calc" Then GoTo CalcCmd
If firstWord$ = "date" Then GoTo DateCmd
If firstWord$ = "grep" Then GoTo GrepCmd
If firstWord$ = "su" Then GoTo SuCmd
If firstWord$ = "history" Then GoTo HistoryCmd
If firstWord$ = "df" Then GoTo DfCmd
If firstWord$ = "whoami" Then Call TermPrint(currentUser$): GoTo CheckRedirection
If firstWord$ = "pwd" Then Call TermPrint("/home/" + currentUser$): GoTo CheckRedirection
If firstWord$ = "uname" Then GoTo UnameCmd
If firstWord$ = "clear" Then termLineCount = 0: termScrollOffset = 0: Cls: GoTo CheckRedirection
If firstWord$ = "exit" Then End
If firstWord$ = "echo" Then Call TermPrint(arg$): GoTo CheckRedirection

Call TermPrint("bash: " + firstWord$ + ": command not found. Try 'sudo apt install " + firstWord$ + "'")

CheckRedirection:
If redirecting And redirFile$ <> "" Then
    fIdx = 0
    For i = 1 To fCount
        If LCase$(fNames$(i)) = LCase$(redirFile$) Then fIdx = i: Exit For
    Next i
    If fIdx = 0 Then
        fCount = fCount + 1
        fIdx = fCount
        fNames$(fIdx) = redirFile$
        fContents$(fIdx) = ""
    End If
    If redirAppend = 1 Then
        fContents$(fIdx) = fContents$(fIdx) + redirBuffer$
    Else
        fContents$(fIdx) = redirBuffer$
    End If
    GoSub SaveVFSToDisk
    redirecting = 0
End If
Return

' ======= NEW COMMAND: RM (Remove) =======
RmCmd:
If arg$ = "" Then Call TermPrint("rm: missing operand"): GoTo CheckRedirection
found = 0
For i = 1 To fCount
    If LCase$(fNames$(i)) = LCase$(arg$) Then
        found = 1
        For j = i To fCount - 1
            fNames$(j) = fNames$(j + 1)
            fContents$(j) = fContents$(j + 1)
        Next j
        fNames$(fCount) = ""
        fContents$(fCount) = ""
        fCount = fCount - 1
        GoSub SaveVFSToDisk
        Exit For
    End If
Next i
If found = 0 Then Call TermPrint("rm: cannot remove '" + arg$ + "': No such file or directory")
GoTo CheckRedirection

' ======= NEW COMMAND: MV (Rename) =======
MvCmd:
sp = InStr(arg$, " ")
If sp = 0 Then Call TermPrint("mv: missing destination file operand after '" + arg$ + "'"): GoTo CheckRedirection
src$ = LTrim$(RTrim$(Left$(arg$, sp - 1)))
dest$ = LTrim$(RTrim$(Mid$(arg$, sp + 1)))
found = 0
For i = 1 To fCount
    If LCase$(fNames$(i)) = LCase$(src$) Then
        fNames$(i) = dest$
        GoSub SaveVFSToDisk
        found = 1
        Exit For
    End If
Next i
If found = 0 Then Call TermPrint("mv: cannot stat '" + src$ + "': No such file or directory")
GoTo CheckRedirection

' ======= FIXED: Image Viewer (Supports VFS Extraction) =======
ViewCmd:
If arg$ = "" Then Call TermPrint("view: missing image file (PNG/JPG/BMP)"): GoTo CheckRedirection

' Check Virtual File System first
fIdx = 0
For i = 1 To fCount
    If LCase$(fNames$(i)) = LCase$(arg$) Then fIdx = i: Exit For
Next i

If fIdx > 0 Then
    ' Found in VFS! Dump data to a physical temporary file so QB64 can read it
    tmpImg$ = "__vfstemp.png"
    Open tmpImg$ For Binary As #2
    Put #2, 1, fContents$(fIdx)
    Close #2

    imgHandle& = _LoadImage(tmpImg$, 32)
    Kill tmpImg$ ' Clean up physical temp file

    If imgHandle& < -1 Then
        Screen imgHandle&
        _KeyClear
        Sleep
        Screen 0
        _FreeImage imgHandle&
        Call TermPrint("[Image closed]")
    Else
        Call TermPrint("view: failed to parse image format from VFS data: " + arg$)
    End If
ElseIf _FileExists(arg$) Then ' Fallback to physical disk
    imgHandle& = _LoadImage(arg$, 32)
    If imgHandle& < -1 Then
        Screen imgHandle&
        _KeyClear
        Sleep
        Screen 0
        _FreeImage imgHandle&
        Call TermPrint("[Image closed]")
    Else
        Call TermPrint("view: failed to parse image format: " + arg$)
    End If
Else
    Call TermPrint("view: " + arg$ + ": File not found in VFS or Host Drive")
End If
GoTo CheckRedirection

' Audio Player
PlayCmd:
If arg$ = "" Then Call TermPrint("play: missing audio file (MP3/WAV/OGG)"): GoTo CheckRedirection
If arg$ = "stop" Then
    If currentSound <> 0 Then
        _SndStop currentSound
        _SndClose currentSound
        currentSound = 0
        Call TermPrint("[Audio playback stopped]")
    End If
    GoTo CheckRedirection
End If

If _FileExists(arg$) Then
    If currentSound <> 0 Then _SndStop currentSound: _SndClose currentSound
    currentSound = _SndOpen(arg$)
    If currentSound <> 0 Then
        _SndPlay currentSound
        Call TermPrint("[Playing audio: " + arg$ + " | Use 'play stop' to stop]")
    Else
        Call TermPrint("play: unable to load audio file")
    End If
Else
    Call TermPrint("play: " + arg$ + ": File not found on host drive")
End If
GoTo CheckRedirection

' Video Player
VideoCmd:
If arg$ = "" Then Call TermPrint("video: missing video file (AVI/MP4)"): GoTo CheckRedirection
If _FileExists(arg$) Then
    vHandle& = _SndOpen(arg$, "sync")
    If vHandle& <> 0 Then
        Call TermPrint("[Playing video: " + arg$ + " | Press any key to stop]")
        vCanvas& = _NewImage(800, 600, 32)
        Screen vCanvas&
        _SndPlay vHandle&
        _KeyClear
        Do
            _Limit 30
            If Not _SndPlaying(vHandle&) Then Exit Do
            _PutImage (0, 0)-(799, 599), vHandle&, vCanvas&
            If _KeyHit <> 0 Then Exit Do
        Loop
        _SndStop vHandle&
        _SndClose vHandle&
        _FreeImage vCanvas&
        Screen 0
        Call TermPrint("[Video playback finished]")
    Else
        Call TermPrint("video: unable to decode video file: " + arg$)
    End If
Else
    Call TermPrint("video: " + arg$ + ": File not found on host drive")
End If
GoTo CheckRedirection

UnameCmd:
If arg$ = "-a" Then
    Call TermPrint("Linux qb64-linux 6.5.0-qb64-generic #1 SMP PREEMPT_DYNAMIC QB64-Linux 1.0 (Rick Sanchez) x86_64 GNU/Linux")
Else
    Call TermPrint("Linux")
End If
GoTo CheckRedirection

TouchCmd:
If arg$ = "" Then Call TermPrint("touch: missing file operand"): GoTo CheckRedirection
tArg$ = arg$
Do While tArg$ <> ""
    spPos = InStr(tArg$, " ")
    If spPos > 0 Then
        curF$ = LTrim$(RTrim$(Left$(tArg$, spPos - 1)))
        tArg$ = LTrim$(RTrim$(Mid$(tArg$, spPos + 1)))
    Else
        curF$ = tArg$
        tArg$ = ""
    End If
    If curF$ <> "" Then
        found = 0
        For i = 1 To fCount
            If LCase$(fNames$(i)) = LCase$(curF$) Then found = 1: Exit For
        Next i
        If found = 0 Then
            fCount = fCount + 1
            fNames$(fCount) = curF$
            fContents$(fCount) = ""
        End If
    End If
Loop
GoSub SaveVFSToDisk
GoTo CheckRedirection

CatCmd:
If arg$ = "" Then Call TermPrint("cat: missing file operand"): GoTo CheckRedirection
showNum = 0
cArg$ = arg$
If Left$(cArg$, 3) = "-n " Then
    showNum = 1
    cArg$ = LTrim$(RTrim$(Mid$(cArg$, 4)))
ElseIf cArg$ = "-n" Then
    Call TermPrint("cat: missing file operand")
    GoTo CheckRedirection
End If

globalLineNum = 1
Do While cArg$ <> ""
    spPos = InStr(cArg$, " ")
    If spPos > 0 Then
        curF$ = LTrim$(RTrim$(Left$(cArg$, spPos - 1)))
        cArg$ = LTrim$(RTrim$(Mid$(cArg$, spPos + 1)))
    Else
        curF$ = cArg$
        cArg$ = ""
    End If

    If curF$ <> "" Then
        fIdx = 0
        For i = 1 To fCount
            If LCase$(fNames$(i)) = LCase$(curF$) Then fIdx = i: Exit For
        Next i

        If fIdx = 0 Then
            Call TermPrint("cat: " + curF$ + ": No such file or directory")
        Else
            cData$ = fContents$(fIdx)
            If cData$ <> "" Then
                sPos = 1
                Do
                    p = InStr(sPos, cData$, Chr$(13) + Chr$(10))
                    If p = 0 Then
                        curL$ = Mid$(cData$, sPos)
                        If showNum = 1 Then
                            Call TermPrint(Right$("     " + Str$(globalLineNum), 6) + "  " + curL$)
                            globalLineNum = globalLineNum + 1
                        Else
                            Call TermPrint(curL$)
                        End If
                        Exit Do
                    Else
                        curL$ = Mid$(cData$, sPos, p - sPos)
                        If showNum = 1 Then
                            Call TermPrint(Right$("     " + Str$(globalLineNum), 6) + "  " + curL$)
                            globalLineNum = globalLineNum + 1
                        Else
                            Call TermPrint(curL$)
                        End If
                        sPos = p + 2
                    End If
                Loop
            End If
        End If
    End If
Loop
GoTo CheckRedirection

NanoCmd:
If arg$ = "" Then Call TermPrint("nano: missing filename"): GoTo CheckRedirection

' Check if file exists in VFS
fIdx = 0
For i = 1 To fCount
    If LCase$(fNames$(i)) = LCase$(arg$) Then fIdx = i: Exit For
Next i

' Initialize Editor Buffers
Dim nBuffer$(200)
Dim nLines As Integer
Dim curR As Integer, curC As Integer
Dim topLine As Integer
Dim isModified As Integer
Dim statusMsg$
Dim clipBuffer$

nLines = 1
curR = 1
curC = 1
topLine = 1
isModified = 0
statusMsg$ = ""
clipBuffer$ = ""

' Load file content if existing
If fIdx > 0 Then
    raw$ = fContents$(fIdx)
    sPos = 1
    nLines = 0
    Do While sPos <= Len(raw$) And nLines < 200
        p = InStr(sPos, raw$, Chr$(13) + Chr$(10))
        nLines = nLines + 1
        If p = 0 Then
            nBuffer$(nLines) = Mid$(raw$, sPos)
            Exit Do
        Else
            nBuffer$(nLines) = Mid$(raw$, sPos, p - sPos)
            sPos = p + 2
        End If
    Loop
    If nLines = 0 Then nLines = 1: nBuffer$(1) = ""
    statusMsg$ = "[ Read " + LTrim$(Str$(nLines)) + " line(s) ]"
Else
    nBuffer$(1) = ""
    statusMsg$ = "[ New File ]"
End If

_KeyClear

' === MAIN NANO EDITOR LOOP ===
Do
    ' Adjust Viewport Scrolling
    If curR < topLine Then topLine = curR
    If curR > topLine + 20 Then topLine = curR - 20
    If topLine < 1 Then topLine = 1

    Cls

    ' --- 1. Top Header Bar ---
    Color 0, 7
    Locate 1, 1
    headStr$ = "  GNU nano 7.2              File: " + arg$
    If isModified Then headStr$ = headStr$ + "  Modified"
    If Len(headStr$) < 80 Then headStr$ = headStr$ + String$(80 - Len(headStr$), " ")
    Print Left$(headStr$, 80);
    Color 7, 0

    ' --- 2. Text Workspace (Rows 2 to 22) ---
    For r = 1 To 21
        lineIdx = topLine + r - 1
        Locate r + 1, 1
        If lineIdx <= nLines Then
            tLine$ = nBuffer$(lineIdx)
            If Len(tLine$) > 80 Then tLine$ = Left$(tLine$, 80)
            Print tLine$;
        End If
    Next r

    ' --- 3. Status Line (Row 23) ---
    Locate 23, 1
    If statusMsg$ <> "" Then
        Color 7, 0
        Print statusMsg$;
    End If

    ' --- 4. Bottom Key Menu (Rows 24 & 25) ---
    Locate 24, 1
    Color 0, 7: Print "^G";: Color 7, 0: Print " Get Help  ";
    Color 0, 7: Print "^O";: Color 7, 0: Print " WriteOut  ";
    Color 0, 7: Print "^W";: Color 7, 0: Print " Where Is  ";
    Color 0, 7: Print "^K";: Color 7, 0: Print " Cut Text  ";
    Color 0, 7: Print "^T";: Color 7, 0: Print " Execute   ";
    Color 0, 7: Print "^C";: Color 7, 0: Print " Cur Pos";

    Locate 25, 1
    Color 0, 7: Print "^X";: Color 7, 0: Print " Exit      ";
    Color 0, 7: Print "^R";: Color 7, 0: Print " Read File ";
    Color 0, 7: Print "^\";: Color 7, 0: Print " Replace   ";
    Color 0, 7: Print "^U";: Color 7, 0: Print " Paste Text";
    Color 0, 7: Print "^J";: Color 7, 0: Print " Justify   ";
    Color 0, 7: Print "^_";: Color 7, 0: Print " Go To Line";

    ' --- 5. Position Screen Cursor ---
    screenRow = curR - topLine + 2
    If curC < 1 Then curC = 1
    If curC > Len(nBuffer$(curR)) + 1 Then curC = Len(nBuffer$(curR)) + 1
    Locate screenRow, curC

    ' --- 6. Wait for Input ---
    Do
        k$ = InKey$
        If k$ <> "" Then Exit Do
        _Limit 60
    Loop

    ' Clear status msg on next keystroke
    statusMsg$ = ""

    ' Process Keystrokes
    Select Case k$
        Case Chr$(24) ' Ctrl+X (Exit)
            If isModified Then
                Locate 23, 1
                Color 0, 7
                Print "Save modified buffer? (Answering 'n' will discard changes) [Y/n]: ";
                Color 7, 0
                Print String$(12, " ");
                Do
                    opt$ = LCase$(InKey$)
                    _Limit 30
                Loop Until opt$ <> ""
                If opt$ = "y" Or opt$ = Chr$(13) Then
                    GoSub NanoSaveFile
                    Exit Do
                ElseIf opt$ = "n" Then
                    Exit Do
                End If
                statusMsg$ = "[ Cancelled ]"
            Else
                Exit Do
            End If

        Case Chr$(15), Chr$(19) ' Ctrl+O or Ctrl+S (Save)
            GoSub NanoSaveFile
            isModified = 0
            statusMsg$ = "[ Wrote " + LTrim$(Str$(nLines)) + " line(s) ]"

        Case Chr$(3) ' Ctrl+C (Position Info)
            statusMsg$ = "[ line " + LTrim$(Str$(curR)) + "/" + LTrim$(Str$(nLines)) + " (" + LTrim$(Str$(Int((curR / nLines) * 100))) + "%), col " + LTrim$(Str$(curC)) + " ]"

        Case Chr$(7) ' Ctrl+G (Help)
            statusMsg$ = "[ GNU nano Help: Ctrl+O Save | Ctrl+X Exit | Ctrl+K Cut | Ctrl+U Paste ]"

        Case Chr$(11) ' Ctrl+K (Cut Line)
            clipBuffer$ = nBuffer$(curR)
            If nLines > 1 Then
                For i = curR To nLines - 1
                    nBuffer$(i) = nBuffer$(i + 1)
                Next i
                nBuffer$(nLines) = ""
                nLines = nLines - 1
                If curR > nLines Then curR = nLines
            Else
                nBuffer$(1) = ""
            End If
            curC = 1
            isModified = 1
            statusMsg$ = "[ Cut 1 line ]"

        Case Chr$(21) ' Ctrl+U (Paste Line)
            If nLines < 200 Then
                For i = nLines To curR Step -1
                    nBuffer$(i + 1) = nBuffer$(i)
                Next i
                nBuffer$(curR) = clipBuffer$
                nLines = nLines + 1
                isModified = 1
                statusMsg$ = "[ Uncut 1 line ]"
            End If

        Case Chr$(13) ' ENTER (New Line)
            If nLines < 200 Then
                rightText$ = Mid$(nBuffer$(curR), curC)
                nBuffer$(curR) = Left$(nBuffer$(curR), curC - 1)
                For i = nLines To curR + 1 Step -1
                    nBuffer$(i + 1) = nBuffer$(i)
                Next i
                nLines = nLines + 1
                curR = curR + 1
                nBuffer$(curR) = rightText$
                curC = 1
                isModified = 1
            End If

        Case Chr$(8) ' BACKSPACE
            If curC > 1 Then
                nBuffer$(curR) = Left$(nBuffer$(curR), curC - 2) + Mid$(nBuffer$(curR), curC)
                curC = curC - 1
                isModified = 1
            ElseIf curR > 1 Then
                prevLen = Len(nBuffer$(curR - 1))
                nBuffer$(curR - 1) = nBuffer$(curR - 1) + nBuffer$(curR)
                For i = curR To nLines - 1
                    nBuffer$(i) = nBuffer$(i + 1)
                Next i
                nBuffer$(nLines) = ""
                nLines = nLines - 1
                curR = curR - 1
                curC = prevLen + 1
                isModified = 1
            End If

        Case Chr$(9) ' TAB (4 Spaces)
            nBuffer$(curR) = Left$(nBuffer$(curR), curC - 1) + "    " + Mid$(nBuffer$(curR), curC)
            curC = curC + 4
            isModified = 1

        Case Chr$(0) + "S" ' DELETE Key
            If curC <= Len(nBuffer$(curR)) Then
                nBuffer$(curR) = Left$(nBuffer$(curR), curC - 1) + Mid$(nBuffer$(curR), curC + 1)
                isModified = 1
            ElseIf curR < nLines Then
                nBuffer$(curR) = nBuffer$(curR) + nBuffer$(curR + 1)
                For i = curR + 1 To nLines - 1
                    nBuffer$(i) = nBuffer$(i + 1)
                Next i
                nBuffer$(nLines) = ""
                nLines = nLines - 1
                isModified = 1
            End If

        Case Chr$(0) + "H" ' UP ARROW
            If curR > 1 Then curR = curR - 1

        Case Chr$(0) + "P" ' DOWN ARROW
            If curR < nLines Then curR = curR + 1

        Case Chr$(0) + "K" ' LEFT ARROW
            If curC > 1 Then
                curC = curC - 1
            ElseIf curR > 1 Then
                curR = curR - 1
                curC = Len(nBuffer$(curR)) + 1
            End If

        Case Chr$(0) + "M" ' RIGHT ARROW
            If curC <= Len(nBuffer$(curR)) Then
                curC = curC + 1
            ElseIf curR < nLines Then
                curR = curR + 1
                curC = 1
            End If

        Case Chr$(0) + "G" ' HOME
            curC = 1

        Case Chr$(0) + "O" ' END
            curC = Len(nBuffer$(curR)) + 1

        Case Chr$(0) + "I" ' PAGE UP
            curR = curR - 15: If curR < 1 Then curR = 1

        Case Chr$(0) + "Q" ' PAGE DOWN
            curR = curR + 15: If curR > nLines Then curR = nLines

        Case Else
            ' Standard Printable Characters
            If Len(k$) = 1 Then
                asciiVal = Asc(k$)
                If asciiVal >= 32 And asciiVal <= 126 Then
                    nBuffer$(curR) = Left$(nBuffer$(curR), curC - 1) + k$ + Mid$(nBuffer$(curR), curC)
                    curC = curC + 1
                    isModified = 1
                End If
            End If
    End Select
Loop

' Return to Linux Terminal
Cls
Call TermPrint("[ nano: Exited editor ]")
GoTo CheckRedirection

' Subroutine to Save Nano File to VFS
NanoSaveFile:
fData$ = ""
For i = 1 To nLines
    fData$ = fData$ + nBuffer$(i) + Chr$(13) + Chr$(10)
Next i

If fIdx = 0 Then
    fCount = fCount + 1
    fIdx = fCount
    fNames$(fIdx) = arg$
End If
fContents$(fIdx) = fData$
GoSub SaveVFSToDisk
Return

nanoCount = 0
If fIdx > 0 Then
    raw$ = fContents$(fIdx)
    sPos = 1
    Do While sPos <= Len(raw$) And nanoCount < 100
        p = InStr(sPos, raw$, Chr$(13) + Chr$(10))
        nanoCount = nanoCount + 1
        If p = 0 Then
            nanoLines$(nanoCount) = Mid$(raw$, sPos)
            Exit Do
        Else
            nanoLines$(nanoCount) = Mid$(raw$, sPos, p - sPos)
            sPos = p + 2
        End If
    Loop
End If

Cls
Color 0, 7: Locate 1, 1: Print "  GNU nano 7.2              File: " + arg$ + String$(35, " ")
Color 7, 0

For nl = 1 To 18
    Locate nl + 1, 1
    If nl <= nanoCount Then Print nanoLines$(nl) Else Print ""
Next nl

Color 0, 7: Locate 20, 1: Print " [^S] Save File   [^X] Exit Editor                                 "
Color 7, 0

Locate 2, 1
Input " [Edit Mode - Enter Line 1]: ", l1$
If l1$ <> "" Then
    nanoCount = 1
    nanoLines$(1) = l1$
    fData$ = l1$ + Chr$(13) + Chr$(10)
    If fIdx = 0 Then
        fCount = fCount + 1
        fIdx = fCount
        fNames$(fIdx) = arg$
    End If
    fContents$(fIdx) = fData$
    GoSub SaveVFSToDisk
    Call TermPrint("[nano: Saved file " + arg$ + "]")
End If
GoTo CheckRedirection

CalCmd:
GoSub VerifyBinaryInstalled
If binInstalled = 0 Then Call TermPrint("bash: cal: command not found. Try 'sudo apt install cal'"): GoTo CheckRedirection
Call TermPrint("     August 2026      ")
Call TermPrint("Su Mo Tu We Th Fr Sa")
Call TermPrint("                   1")
Call TermPrint(" 2  3  4  5  6  7  8")
Call TermPrint(" 9 10 11 12 13 14 15")
Call TermPrint("16 17 18 19 20 21 22")
Call TermPrint("23 24 25 26 27 28 29")
Call TermPrint("30 31")
GoTo CheckRedirection

TreeCmd:
GoSub VerifyBinaryInstalled
If binInstalled = 0 Then Call TermPrint("bash: tree: command not found. Try 'sudo apt install tree'"): GoTo CheckRedirection
Call TermPrint(".")
For i = 1 To fCount
    If fNames$(i) <> "" Then
        If i = fCount Then
            Call TermPrint("+-- " + fNames$(i))
        Else
            Call TermPrint("+-- " + fNames$(i))
        End If
    End If
Next i
Call TermPrint("")
Call TermPrint(Str$(fCount) + " files, 0 directories")
GoTo CheckRedirection

CurlCmd:
GoSub VerifyBinaryInstalled
If binInstalled = 0 Then Call TermPrint("bash: curl: command not found. Try 'sudo apt install curl'"): GoTo CheckRedirection
If arg$ = "" Then Call TermPrint("curl: try 'curl --help' or 'curl --manual' for more information"): GoTo CheckRedirection
Call TermPrint("HTTP/1.1 200 OK")
Call TermPrint("Server: QB64-Linux-HTTPd/1.0")
Call TermPrint("Content-Type: text/html; charset=UTF-8")
Call TermPrint("")
Call TermPrint("<!DOCTYPE html><html><body><h1>QB64 Remote Server</h1><p>Connected to " + arg$ + "</p></body></html>")
GoTo CheckRedirection

Base64Cmd:
GoSub VerifyBinaryInstalled
If binInstalled = 0 Then Call TermPrint("bash: base64: command not found. Try 'sudo apt install base64'"): GoTo CheckRedirection
If arg$ = "" Then Call TermPrint("base64: missing input text"): GoTo CheckRedirection
If Left$(arg$, 3) = "-d " Then
    dec$ = Mid$(arg$, 4)
    Call TermPrint("Decoded: " + dec$)
Else
    Call TermPrint("aGVsbG8gd29ybGQ=")
End If
GoTo CheckRedirection

WhichCmd:
GoSub VerifyBinaryInstalled
If binInstalled = 0 Then Call TermPrint("bash: which: command not found. Try 'sudo apt install which'"): GoTo CheckRedirection
If arg$ = "" Then Call TermPrint("which: missing command argument"): GoTo CheckRedirection
Call TermPrint("/usr/bin/" + arg$)
GoTo CheckRedirection

HeadCmd:
GoSub VerifyBinaryInstalled
If binInstalled = 0 Then Call TermPrint("bash: head: command not found. Try 'sudo apt install head'"): GoTo CheckRedirection
If arg$ = "" Then Call TermPrint("head: missing file operand"): GoTo CheckRedirection
maxL = 10
targetFile$ = arg$
For i = 1 To fCount
    If LCase$(fNames$(i)) = LCase$(targetFile$) Then
        cData$ = fContents$(i)
        lCount = 0
        sPos = 1
        Do While sPos <= Len(cData$) And lCount < maxL
            p = InStr(sPos, cData$, Chr$(13) + Chr$(10))
            If p = 0 Then
                Call TermPrint(Mid$(cData$, sPos))
                Exit Do
            Else
                Call TermPrint(Mid$(cData$, sPos, p - sPos))
                lCount = lCount + 1
                sPos = p + 2
            End If
        Loop
        GoTo CheckRedirection
    End If
Next i
Call TermPrint("head: cannot open '" + targetFile$ + "' for reading: No such file")
GoTo CheckRedirection

TailCmd:
GoSub VerifyBinaryInstalled
If binInstalled = 0 Then Call TermPrint("bash: tail: command not found. Try 'sudo apt install tail'"): GoTo CheckRedirection
If arg$ = "" Then Call TermPrint("tail: missing file operand"): GoTo CheckRedirection
maxL = 10
targetFile$ = arg$
For i = 1 To fCount
    If LCase$(fNames$(i)) = LCase$(targetFile$) Then
        cData$ = fContents$(i)
        totL = 0
        sPos = 1
        Do While sPos <= Len(cData$)
            p = InStr(sPos, cData$, Chr$(13) + Chr$(10))
            totL = totL + 1
            If p = 0 Then Exit Do Else sPos = p + 2
        Loop

        startL = totL - maxL + 1
        If startL < 1 Then startL = 1

        curL = 1
        sPos = 1
        Do While sPos <= Len(cData$)
            p = InStr(sPos, cData$, Chr$(13) + Chr$(10))
            If curL >= startL Then
                If p = 0 Then Call TermPrint(Mid$(cData$, sPos)): Exit Do Else Call TermPrint(Mid$(cData$, sPos, p - sPos))
            End If
            If p = 0 Then Exit Do
            curL = curL + 1
            sPos = p + 2
        Loop
        GoTo CheckRedirection
    End If
Next i
Call TermPrint("tail: cannot open '" + targetFile$ + "' for reading: No such file")
GoTo CheckRedirection

WcCmd:
GoSub VerifyBinaryInstalled
If binInstalled = 0 Then Call TermPrint("bash: wc: command not found. Try 'sudo apt install wc'"): GoTo CheckRedirection
If arg$ = "" Then Call TermPrint("wc: missing file operand"): GoTo CheckRedirection
For i = 1 To fCount
    If LCase$(fNames$(i)) = LCase$(arg$) Then
        cData$ = fContents$(i)
        bCount = Len(cData$)
        lCount = 0
        wCount = 0
        inWord = 0
        For cIdx = 1 To bCount
            ch$ = Mid$(cData$, cIdx, 1)
            If ch$ = Chr$(10) Then lCount = lCount + 1
            If ch$ = " " Or ch$ = Chr$(13) Or ch$ = Chr$(10) Or ch$ = Chr$(9) Then
                inWord = 0
            ElseIf inWord = 0 Then
                inWord = 1
                wCount = wCount + 1
            End If
        Next cIdx
        Call TermPrint(Str$(lCount) + " " + Str$(wCount) + " " + Str$(bCount) + " " + arg$)
        GoTo CheckRedirection
    End If
Next i
Call TermPrint("wc: " + arg$ + ": No such file or directory")
GoTo CheckRedirection

BannerCmd:
GoSub VerifyBinaryInstalled
If binInstalled = 0 Then Call TermPrint("bash: banner: command not found. Try 'sudo apt install banner'"): GoTo CheckRedirection
bTxt$ = UCase$(arg$)
If bTxt$ = "" Then bTxt$ = "QB64"
Call TermPrint("##### " + bTxt$ + " #####")
Call TermPrint("##### " + String$(Len(bTxt$), "#") + " #####")
GoTo CheckRedirection

AptManagerCmd:
pCmd$ = cmd$
If Left$(pCmd$, 5) = "sudo " Then pCmd$ = Mid$(pCmd$, 6)
If Left$(pCmd$, 8) = "apt-get " Then pCmd$ = "apt " + Mid$(pCmd$, 9)

If pCmd$ = "apt" Or pCmd$ = "apt help" Then
    Call TermPrint("Advanced Package Tool (APT) v2.4.8 (x86_64)")
    Call TermPrint("Usage: sudo apt [update | list | install <pkg> | remove <pkg>]")
    Call TermPrint("Available Packages: cal, tree, curl, base64, which, head, tail, wc, banner, cowsay, fortune, matrix, figlet, toilet, sl, rev, factor, htop, neofetch")
    GoTo CheckRedirection
End If

If pCmd$ = "apt update" Then
    Call TermPrint("Get:1 http://repo.qb64-linux.org/core stable InRelease [12.4 kB]")
    _Delay 0.3
    Call TermPrint("Get:2 http://repo.qb64-linux.org/core stable/main Packages [45.2 kB]")
    _Delay 0.2
    Call TermPrint("Reading package lists... Done")
    Call TermPrint("All packages are up to date.")
    GoTo CheckRedirection
End If

If pCmd$ = "apt list" Then
    Call TermPrint("Listing repository packages...")
    Call TermPrint("cal/stable 2.38-1 amd64 [Displays calendar]")
    Call TermPrint("tree/stable 2.0.2 amd64 [Visual file directory tree]")
    Call TermPrint("curl/stable 7.88.1 amd64 [Command line URL data fetcher]")
    Call TermPrint("base64/stable 8.32-4 amd64 [Encode/decode base64 data]")
    Call TermPrint("which/stable 2.21 amd64 [Locate command path]")
    Call TermPrint("head/stable 8.32-4 amd64 [Output first part of files]")
    Call TermPrint("tail/stable 8.32-4 amd64 [Output last part of files]")
    Call TermPrint("wc/stable 8.32-4 amd64 [Newline, word, byte counts]")
    Call TermPrint("banner/stable 1.3.4 amd64 [Large ASCII banner]")
    Call TermPrint("cowsay/stable 3.03-8 amd64 [Text cow banner]")
    Call TermPrint("fortune/stable 1.99.1 amd64 [Random epigrams]")
    Call TermPrint("matrix/stable 2.0-1 amd64 [Digital rain animation]")
    Call TermPrint("figlet/stable 2.2.5 amd64 [ASCII banner generator]")
    Call TermPrint("toilet/stable 0.3-1.1 amd64 [Colourful text renderer]")
    Call TermPrint("sl/stable 5.02-1 amd64 [Steam locomotive simulator]")
    Call TermPrint("rev/stable 2.38-1 amd64 [Reverse lines characterwise]")
    Call TermPrint("factor/stable 8.32-4 amd64 [Print prime factors]")
    Call TermPrint("htop/stable 3.2.2 amd64 [Process viewer]")
    Call TermPrint("neofetch/stable 7.1.0 amd64 [System info tool]")
    GoTo CheckRedirection
End If

If Left$(pCmd$, 12) = "apt install " Then
    targetPkg$ = LCase$(LTrim$(RTrim$(Mid$(pCmd$, 13))))
    If targetPkg$ = "" Then Call TermPrint("apt: missing package name"): GoTo CheckRedirection

    pValid = 0
    If targetPkg$ = "cal" Or targetPkg$ = "tree" Or targetPkg$ = "curl" Or targetPkg$ = "base64" Or targetPkg$ = "which" Or targetPkg$ = "head" Or targetPkg$ = "tail" Or targetPkg$ = "wc" Or targetPkg$ = "banner" Or targetPkg$ = "cowsay" Or targetPkg$ = "fortune" Or targetPkg$ = "matrix" Or targetPkg$ = "cmatrix" Or targetPkg$ = "figlet" Or targetPkg$ = "toilet" Or targetPkg$ = "sl" Or targetPkg$ = "rev" Or targetPkg$ = "factor" Or targetPkg$ = "htop" Or targetPkg$ = "neofetch" Then pValid = 1

    If pValid = 0 Then
        Call TermPrint("E: Unable to locate package " + targetPkg$)
        GoTo CheckRedirection
    End If

    Call TermPrint("Reading package lists... Done")
    Call TermPrint("Building dependency tree... Done")
    Call TermPrint("The following NEW packages will be installed: " + targetPkg$)
    Call TermPrint("0 upgraded, 1 newly installed, 0 to remove.")
    Call TermPrint("Need to get 14.2 kB of archives.")
    _Delay 0.3
    Call TermPrint("Get:1 http://repo.qb64-linux.org/core stable/main " + targetPkg$ + " [14.2 kB]")
    _Delay 0.3
    Call TermPrint("Unpacking " + targetPkg$ + "... Done")
    Call TermPrint("Setting up " + targetPkg$ + "... Done")

    pkgFileName$ = targetPkg$ + ".bin"
    For tIdx = 1 To fCount
        If LCase$(fNames$(tIdx)) = pkgFileName$ Then Call TermPrint("Package " + targetPkg$ + " reinstalled."): GoTo CheckRedirection
    Next tIdx
    fCount = fCount + 1
    fNames$(fCount) = pkgFileName$
    fContents$(fCount) = "BINARY_EXEC:" + targetPkg$
    GoSub SaveVFSToDisk
    Call TermPrint("Processing triggers for man-db... Complete.")
    GoTo CheckRedirection
End If

If Left$(pCmd$, 11) = "apt remove " Then
    targetPkg$ = LCase$(LTrim$(RTrim$(Mid$(pCmd$, 12))))
    pkgFileName$ = targetPkg$ + ".bin"
    For tIdx = 1 To fCount
        If LCase$(fNames$(tIdx)) = pkgFileName$ Then
            For delIdx = tIdx To fCount - 1
                fNames$(delIdx) = fNames$(delIdx + 1)
                fContents$(delIdx) = fContents$(delIdx + 1)
            Next delIdx
            fNames$(fCount) = ""
            fContents$(fCount) = ""
            fCount = fCount - 1
            GoSub SaveVFSToDisk
            Call TermPrint("Removing " + targetPkg$ + "... Done")
            GoTo CheckRedirection
        End If
    Next tIdx
    Call TermPrint("E: Package '" + targetPkg$ + "' is not installed")
    GoTo CheckRedirection
End If

Call TermPrint("apt: invalid operation '" + pCmd$ + "'")
GoTo CheckRedirection

CowsayCmd:
GoSub VerifyBinaryInstalled
If binInstalled = 0 Then Call TermPrint("bash: cowsay: command not found. Try 'sudo apt install cowsay'"): GoTo CheckRedirection
msg$ = arg$
If msg$ = "" Then msg$ = "QB64-Linux is fully operational!"
lLen = Len(msg$) + 2
Call TermPrint(" " + String$(lLen, "-"))
Call TermPrint("< " + msg$ + " >")
Call TermPrint(" " + String$(lLen, "-"))
Call TermPrint("        \   ^__^")
Call TermPrint("         \  (oo)\_______")
Call TermPrint("            (__)\       )\/\")
Call TermPrint("                ||----w |")
Call TermPrint("                ||     ||")
GoTo CheckRedirection

FortuneCmd:
GoSub VerifyBinaryInstalled
If binInstalled = 0 Then Call TermPrint("bash: fortune: command not found. Try 'sudo apt install fortune'"): GoTo CheckRedirection
fChoice = Int(Rnd * 4) + 1
If fChoice = 1 Then Call TermPrint("There are 10 types of people: those who understand binary, and those who don't.")
If fChoice = 2 Then Call TermPrint("Old programmers never die; they just can't locate their references.")
If fChoice = 3 Then Call TermPrint("In a world without fences, who needs Gates and Windows?")
If fChoice = 4 Then Call TermPrint("Linux is only free if your time has no value.")
GoTo CheckRedirection

MatrixCmd:
GoSub VerifyBinaryInstalled
If binInstalled = 0 Then Call TermPrint("bash: cmatrix: command not found. Try 'sudo apt install matrix'"): GoTo CheckRedirection
Cls
Color 10, 0
For m = 1 To 100
    Locate Int(Rnd * 18) + 1, Int(Rnd * 78) + 1
    Print Chr$(Int(Rnd * 93) + 33);
    _Delay 0.01
Next m
Color 7, 0
Cls
GoTo CheckRedirection

FigletCmd:
GoSub VerifyBinaryInstalled
If binInstalled = 0 Then Call TermPrint("bash: figlet: command not found. Try 'sudo apt install figlet'"): GoTo CheckRedirection
txt$ = UCase$(arg$)
If txt$ = "" Then txt$ = "QB64"
Call TermPrint(" _  _  _  " + txt$)
Call TermPrint("(_|| ||_) " + txt$)
GoTo CheckRedirection

ToiletCmd:
GoSub VerifyBinaryInstalled
If binInstalled = 0 Then Call TermPrint("bash: toilet: command not found. Try 'sudo apt install toilet'"): GoTo CheckRedirection
txt$ = UCase$(arg$)
If txt$ = "" Then txt$ = "LINUX"
Call TermPrint("+#+# " + txt$ + " #+#+")
GoTo CheckRedirection

RevCmd:
GoSub VerifyBinaryInstalled
If binInstalled = 0 Then Call TermPrint("bash: rev: command not found. Try 'sudo apt install rev'"): GoTo CheckRedirection
If arg$ = "" Then Call TermPrint("rev: missing argument"): GoTo CheckRedirection
revTxt$ = ""
For cIdx = Len(arg$) To 1 Step -1
    revTxt$ = revTxt$ + Mid$(arg$, cIdx, 1)
Next cIdx
Call TermPrint(revTxt$)
GoTo CheckRedirection

FactorCmd:
GoSub VerifyBinaryInstalled
If binInstalled = 0 Then Call TermPrint("bash: factor: command not found. Try 'sudo apt install factor'"): GoTo CheckRedirection
n = Val(arg$)
If n <= 1 Then Call TermPrint("factor: enter a number greater than 1"): GoTo CheckRedirection
outStr$ = Str$(n) + ":"
d = 2
While d * d <= n
    While (n Mod d) = 0
        outStr$ = outStr$ + " " + Str$(d)
        n = n \ d
    Wend
    d = d + 1
Wend
If n > 1 Then outStr$ = outStr$ + " " + Str$(n)
Call TermPrint(outStr$)
GoTo CheckRedirection

SlCmd:
GoSub VerifyBinaryInstalled
If binInstalled = 0 Then Call TermPrint("bash: sl: command not found. Try 'sudo apt install sl'"): GoTo CheckRedirection
Call TermPrint("      ====        ________                ________________")
Call TermPrint("  _D _|  |_______/--------\__I_I_____===__|_________|_____|")
Call TermPrint("   |   |_________  CHOO CHOO!  ___________|________________|")
Call TermPrint("   (o)___(o)---(o)____________(o)___(o)-----(o)__________(o)")
GoTo CheckRedirection

HelpCmd:
Call TermPrint("QB64-Linux Shell Interface - Core Utilities")
Call TermPrint("  ls, cat, touch, nano, rm, mv, echo, pwd, whoami, uname, clear, history, df, uptime")
Call TermPrint("Multimedia Commands:")
Call TermPrint("  view <img.png|jpg> - Display image")
Call TermPrint("  play <audio.mp3|wav> | play stop - Audio player")
Call TermPrint("  video <file.avi|mp4> - Video player")
Call TermPrint("System & Package Management:")
Call TermPrint("  apt [update|list|install|remove] - APT Package Manager")
Call TermPrint("  games - List available system games & terminal applications")
GoTo CheckRedirection

GamesCmd:
Call TermPrint("Available Games & Apps:")
Call TermPrint("  cal, tree, curl, base64, which, head, tail, wc, banner, cowsay, fortune, matrix, figlet, toilet, sl, rev, factor, htop, neofetch")
GoTo CheckRedirection

LsCmd:
For i = 1 To fCount
    If fNames$(i) <> "" Then Call TermPrint(fNames$(i))
Next i
GoTo CheckRedirection

NeofetchCmd:
GoSub VerifyBinaryInstalled
If binInstalled = 0 Then Call TermPrint("bash: neofetch: command not found. Try 'sudo apt install neofetch'"): GoTo CheckRedirection
Call TermPrint("       .---.        " + currentUser$ + "@qb64-linux")
Call TermPrint("      /     \       -----------------")
Call TermPrint("     () ()   |      OS: QB64-Linux 1.0 (Rick Sanchez) x86_64")
Call TermPrint("     (  -  ) |      Kernel: 6.5.0-qb64-generic")
Call TermPrint("      \___/ /       Uptime: 10 mins")
Call TermPrint("     /     \        Shell: bash 5.2.15")
GoTo CheckRedirection

UptimeCmd:
Call TermPrint(" 12:00:00 up 10 min,  1 user,  load average: 0.00, 0.01, 0.05")
GoTo CheckRedirection

HtopCmd:
GoSub VerifyBinaryInstalled
If binInstalled = 0 Then Call TermPrint("bash: htop: command not found. Try 'sudo apt install htop'"): GoTo CheckRedirection
Call TermPrint("CPU [||||||||||||||||||||||||||||| 100.0%] Tasks: 12 total, 1 running")
Call TermPrint("Mem [||||||||||............ 256MB/1024MB] Swp [0MB/0MB]")
GoTo CheckRedirection

CalcCmd:
Call TermPrint("Use 'echo' for basic evaluation or run calc.bas via qbasic")
GoTo CheckRedirection

DateCmd:
Call TermPrint("Tue Oct 24 12:00:00 UTC 2023")
GoTo CheckRedirection

GrepCmd:
Call TermPrint("grep: usage: grep [pattern] [filename]")
GoTo CheckRedirection

SuCmd:
Call TermPrint("su: Authentication failure")
GoTo CheckRedirection

HistoryCmd:
For h = 1 To histCount
    Call TermPrint(Str$(h) + "  " + hist$(h))
Next h
GoTo CheckRedirection

DfCmd:
Call TermPrint("Filesystem     1K-blocks  Used Available Use% Mounted on")
Call TermPrint("/dev/vda1        1048576  4096   1044480   1% /")
GoTo CheckRedirection

VerifyBinaryInstalled:
binInstalled = 0
chkName$ = firstWord$ + ".bin"
For vIdx = 1 To fCount
    If LCase$(fNames$(vIdx)) = chkName$ Then binInstalled = 1: Exit For
Next vIdx
Return

' === FIXED VFS SAVER (Cleans Up Strings for Safety) ===
SaveVFSToDisk:
Open "qblinux_vfs.dat" For Output As #1
Print #1, LTrim$(RTrim$(Str$(fCount)))
For sIdx = 1 To fCount
    Print #1, fNames$(sIdx)
    rawCont$ = fContents$(sIdx)
    encCont$ = ""
    For cPos = 1 To Len(rawCont$)
        c$ = Mid$(rawCont$, cPos, 1)
        If c$ = Chr$(13) Then
            encCont$ = encCont$ + "~NL~"
            If cPos < Len(rawCont$) And Mid$(rawCont$, cPos + 1, 1) = Chr$(10) Then cPos = cPos + 1
        ElseIf c$ = Chr$(10) Then
            encCont$ = encCont$ + "~NL~"
        Else
            encCont$ = encCont$ + c$
        End If
    Next cPos
    Print #1, encCont$
Next sIdx
Close #1
Return

End

Sub TermPrint (txt$)
    If redirecting Then
        redirBuffer$ = redirBuffer$ + txt$ + Chr$(13) + Chr$(10)
        Exit Sub
    End If
    If termLineCount < 500 Then
        termLineCount = termLineCount + 1
        termLines$(termLineCount) = txt$
    Else
        For t = 1 To 499
            termLines$(t) = termLines$(t + 1)
        Next t
        termLines$(500) = txt$
    End If
End Sub

