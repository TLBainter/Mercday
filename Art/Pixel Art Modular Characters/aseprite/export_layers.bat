:inicio
@set ASEPRITE="C:\Program Files (x86)\Steam\steamapps\common\Aseprite\aseprite.exe"
setlocal enabledelayedexpansion

rem === export the layers to temp file ===

%ASEPRITE% -b --split-layers Class_warrior.aseprite --save-as "temp/{layer}.ase" 
echo.
rem === convert the aseprites to spritesheet png ===
for %%f in (temp\*.ase) do (

rem Se o nome contém "!", pula o arquivo
echo !filename! | find "!" >nul
if not errorlevel 1 (
echo ignore file: %%~nxf
goto :continue
)

echo processing %%~nxf ...
%ASEPRITE% -b %%f --split-tags --ignore-empty --sheet "export/%%~nf.png"


)
echo.
echo  Layers exported!
echo.
echo.
choice /c RQ /m "Press [R] to export again or [Q] to finish:"

if errorlevel 2 exit /b
if errorlevel 1 goto inicio