:inicio
@set ASEPRITE="C:\Program Files (x86)\Steam\steamapps\common\Aseprite\aseprite.exe"
setlocal enabledelayedexpansion

rem === Divide as camadas e cria spritesheets ===

%ASEPRITE% -b --split-layers hair_all_options.aseprite --save-as "temp/{layer}.ase" 

rem === Converte todos os arquivos .aseprite da pasta temp em PNG ===
for %%f in (temp\*.ase) do (

rem Se o nome contém "!", pula o arquivo
echo !filename! | find "!" >nul
if not errorlevel 1 (
echo Ignorando arquivo: %%~nxf
goto :continue
)

echo Processando %%~nxf ...
%ASEPRITE% -b %%f --split-tags --ignore-empty --sheet "export/%%~nf.png"


)
echo.
echo  Conversão concluída!
echo.
echo.
choice /c RQ /m "Pressione [R] para reiniciar ou [Q] para sair:"

if errorlevel 2 exit /b
if errorlevel 1 goto inicio


