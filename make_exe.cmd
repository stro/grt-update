@for /f "usebackq tokens=*" %%a in (`perl -MConfig -e "print $Config{'sitelibexp'}"`) do @set SITELIBEXP=%%a
@for /f "usebackq tokens=*" %%a in (`grep -Eo "VERSION = '.*?'" grt-update.pl^|grep -Eo "[0-9].[0-9]+"`) do @set GRTU_VERSION=%%a
@echo Version is %GRTU_VERSION%

@call pp -S --gui      ^
  -l zlib1__.dll       ^
  -l libXpm__.dll      ^
  -l libgomp-1.dll     ^
  -l libgif-7__.dll    ^
  -l libjpeg-9__.dll   ^
  -l libtiff-5__.dll   ^
  -l liblzma-5__.dll   ^
  -l libpng16-16__.dll ^
  -a %SITELIBEXP%/Prima/sysimage.gif;Prima/sysimage.gif                     ^
  -a %SITELIBEXP%/Prima/sys/win32/sysimage.gif;Prima/sys/win32/sysimage.gif ^
  -o grt-update.exe grt-update.pl

@zip -9 grt-update-%GRTU_VERSION%.zip grt-update.exe
