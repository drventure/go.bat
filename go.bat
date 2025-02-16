@ECHO OFF
@SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

REM Setup constants
SET cr=^


REM !!!! note the above to blank lines are necessary !!!!!


GOTO :continue

SET ini=[section1]!cr!^
key11=value11!cr!^
key12=val12!cr!^
[section2]!cr!^
key21=value21!cr!^
key22=val22!cr!

CALL :ParseINI section1 key12
ECHO v=!value!
CALL :ParseINI section2 key22
ECHO v=!value!

FOR /f "delims=" %%a IN ('shortcut /f:^"go prog.lnk^" /a:q') do (
  IF DEFINED output SET output=!output!!cr!
  SET output=!output!%%a
)
ECHO !output!
SET ini=!output!

CALL :ParseINI "go prog.lnk" TargetPathExpanded
ECHO tpe=!value!

GOTO :END



:continue
REM Originally based on source found at https://github.com/DieterDePaepe/windows-scripts
REM on here https://stackoverflow.com/questions/32003/tool-for-commandline-bookmarks-on-windows
REM Please share any improvements made!

REM Use the GO_REPO env var, but if that's not set, use the UserProfile
REM The repo path is where the script creates and stores the LNK files to the various
REM bookmarked folders and files.
if [%GO_REPO%]==[] (
    set GO_REPO=%USERPROFILE%\.go
)

REM always make sure the repo exists
if not exist %GO_REPO%\NUL mkdir %GO_REPO%

REM *********************************
REM Command parsing
REM *********************************
IF /I [%1]==[/?] GOTO :help
IF /I [%1]==[-?] GOTO :help
IF /I [%1]==[-h] GOTO :help
IF /I [%1]==[--help] GOTO :help

IF /I [%1]==[/c] GOTO :create
IF /I [%1]==[-c] GOTO :create
IF /I [%1]==[/create] GOTO :create
IF /I [%1]==[-create] GOTO :create

IF /I [%1]==[/r] GOTO :remove
IF /I [%1]==[-r] GOTO :remove
IF /I [%1]==[/remove] GOTO :remove
IF /I [%1]==[-remove] GOTO :remove

IF /I [%1]==[/l] GOTO :list
IF /I [%1]==[-l] GOTO :list
IF /I [%1]==[/list] GOTO :list
IF /I [%1]==[-list] GOTO :list

IF /I [%1]==[/i] GOTO :info
IF /I [%1]==[-i] GOTO :info
IF /I [%1]==[/info] GOTO :info
IF /I [%1]==[-info] GOTO :info

IF /I [%1]==[b] GOTO :back
IF /I [%1]==[back] GOTO :back


REM *********************************
REM Fall through to goto the named bookmark
REM *********************************
:gotobookmark
  if not exist "%GO_REPO%\go %1.lnk" (
    echo Bookmark '%1' not found
    goto :end
  )
  
  REM Note that all shortcuts are prefixed with "GO "
  REM It IS a tad redundant, because the Repo folder 
  REM will be filled with "go *.lnk" files.
  REM However, this works really well with launcher apps
  REM like powertoys RUN or FlowLauncher, because you can
  REM add the go Repo folder to this list of folders to 
  REM scan for executable files, and suddenly all your
  REM shortcuts are automatically available via your favorite
  REM launcher as well!
  call :readshortcut "%GO_REPO%\go %1.lnk"
  
  REM this voodoo is required because TargetPath is defined
  REM within a SETLOCAL, and changing it within that context
  REM won't normally carry through past the endlocal
  REM using this () trick will pull the targetpath down from the 
  REM nested context
  REM and allow using pushd with it which can then set the curdir
  REM within the original contxt the bat file was started in
  (
    endlocal
    set target=%TargetPath%
  )
  REM Check if this was a folder bookmark
  if exist "%target%\*.*" (
    pushd "%target%"
    GOTO :end
  )
  REM Nope, so check if it's a file bookmark
  if exist "%target%" (
    start "" "%target%"
    GOTO :end
  )
  echo Unable to navigate to / open bookmark '%1'
  GOTO :end


REM *********************************
REM Create a new bookmark
REM *********************************
:create
  IF [%2]==[] (
    ECHO Missing bookmark name
    GOTO :end
  )
  IF [%3]==[] (
    REM no explicit target mentioned, just assume current folder
    set GO_DIR=%cd%
  ) ELSE (
    REM REM explicit target is being used
    set GO_DIR=%~3
    CALL :trim GO_DIR
    call :dequote GO_DIR
  )
  call :createshortcut "%%GO_REPO%%\go %~2" "%%GO_DIR%%"
  ECHO Created bookmark '%~2'
  goto :end


REM *********************************
REM List out all bookmarks
REM *********************************
:list
  ECHO Available Bookmarks
  for /F "delims= eol=" %%a IN ('dir /A-D /ON /B /W /S "%%GO_REPO%%\go *.lnk"') do (
    call :parsefile "%%a"
  )
  GOTO :end
:parsefile
  call :readshortcut %1
  set name=%~n1
  set name=!name:~3!
  echo   !name!  -  !TargetPath!
  goto :end


REM *********************************
REM Remove a named bookmark
REM *********************************
:remove
IF [%2]==[] (
  ECHO Missing name for bookmark
  GOTO :end
)
if exist "%GO_REPO%\go %~2.lnk" (
  del "%GO_REPO%\go %~2.lnk"
  GOTO :end
)
ECHO Bookmark '%2' does not exist.
GOTO :end


REM *********************************
REM Display info on a bookmark
REM Realistically, though, since 
REM Bookmarks are just plain ol' LNK
REM shortcuts, you can use SHORTCUT.exe
REM or just Explorer to view their
REM properties.
REM *********************************
:info
IF [%2]==[] (
  ECHO Missing name for bookmark
  GOTO :end
)
if exist "%GO_REPO%\go %~2.lnk" (
  call :readshortcut "%GO_REPO%\go %~2.lnk"
  echo Information for bookmark %~n2
  echo   LinkFile:     !Link!
  echo   Target:       !TargetPath!
  echo   Working Dir:  !WorkingDirectory!
  echo   Args:         !Arguments!
  echo   Description:  !Description!
  echo   IconNum:      !IconLocation!
  echo   WindowStyle:  !RunStyle!
  GOTO :end
)
ECHO Bookmark '%2' does not exist.
GOTO :end


REM *********************************
REM Go back to where you last came from
REM *********************************
:back
popd
goto :end


REM *********************************
REM Simple help screen
REM *********************************
:help
ECHO Create or navigate/open folder/file bookmarks.
ECHO.
ECHO Options can use either / or -
ECHO.
ECHO   go /?                    Display this help
ECHO   go [bookmark]            Navigate to or open existing bookmark
ECHO   go /c[reate] [bookmark]  Create a bookmark for the current folder
ECHO   go /l[ist]               List existing bookmarks
ECHO   go /r[emove] [bookmark]  Remove an existing bookmark
ECHO   go /i[nfo] [bookmark]    Display info on existing bookmark
ECHO.
ECHO Bookmarks are currently stored in:
ECHO     %GO_REPO%
ECHO.
goto :end


REM *********************************
REM Some utility functions
REM *********************************
REM Used to Trim a variable of spaces
:trim
Call :trimsub %%%1%%
set %1=%tempvar%
GOTO :end

:trimsub
set tempvar=%*
GOTO :end


REM *********************************
REM Read details from a LNK file
REM %1 full path of lnk shortcut
REM Returns
:readshortcut
  set ini=
  for /f "delims=" %%a in ('shortcut /f:^"%~1^" /a:q') do (
    if defined ini set ini=!ini!!cr!
    set ini=!ini!%%a
  )

  set Link=%~nx1

  call :ParseINI "%~1" TargetPath
  call :ParseINI "%~1" WorkingDirectory
  call :ParseINI "%~1" Arguments
  call :ParseINI "%~1" Description
  call :ParseINI "%~1" HotKey
  call :ParseINI "%~1" IconLocation
  call :ParseINI "%~1" RunStyle
  goto :end


REM *********************************
REM Create a shortcut
REM %1 the full path to the shortcut
REM %2 the target path
:createshortcut
  shortcut /f:"%~1.lnk" /a:c /t:%2
  goto :end


REM *********************************
REM Remove quotes from passed in parm
REM call :dequote _myvar
:dequote
for /f "delims=" %%A in ('echo %%%1%%') do set %1=%%~A
Goto :end


REM *********************************
REM Parse INI contents in variable
REM set INI to ini file content
REM pass the section name as the first parameter
REM pass the key name as the second parameter
REM The variable named the KEY name will be set to the value (or empty)
:ParseINI
set Section=%~1
set Key=%~2
set currsection=
set value=
for /f "usebackq delims=" %%a in ('!ini!') do (
    set ln=%%a
    if "x!ln:~0,1!"=="x[" (
        set currsection=!ln!
    ) else (
        for /f "usebackq tokens=1,2 delims==" %%b in ('!ln!') do (
            set currkey=%%b
            set v=%%c
            if "x[!Section!]"=="x!currsection!" if "x!Key!"=="x!currkey!" (
                set value=!v!
            )
        )
    )
)
REM use the name of the passed in key as teh variable to set the
REM value into
set %2=!value!
goto :end



:end
