@echo off

rem requirements:
rem - install git and choose the git-bash option
rem - install imagemagick windows version and make sure it's in the path

set git-bash="C:\Program Files\git\git-bash.exe"

rem convert file args to linux style
set _args=%*
set _args=%_args:\=/%
set _args=%_args:"=""%
rem set args=%args:D:/=//server/data/%

rem convert windows path to linux style
set _path=%path::=%
set _path=%_path:;;=;%
set _path=/%_path:;=:/%
set _path=%_path:\=/%

rem debug
rem echo %git-bash% -c "export PATH="$PATH:%_path%"; image-concat %_args%"
rem %git-bash% -c "export PATH=""$PATH:%_path%""; echo ""$PATH""; read; echo image-concat %_args%; read"

rem run
%git-bash% -c "export PATH=""$PATH:%_path%""; echo ""$PATH""; image-concat %_args%"

pause
