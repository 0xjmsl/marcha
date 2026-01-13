@echo off
echo Building Marcha native library...

:: Set up Visual Studio environment (try multiple versions)
if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" (
    call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
) else if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat" (
    call "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
) else (
    echo ERROR: Could not find Visual Studio. Please install Visual Studio with C++ tools.
    exit /b 1
)

:: Navigate to native directory
cd /d "%~dp0native\windows"

:: Compile the DLL
cl /LD /EHsc /std:c++17 startup_manager.cpp virtual_desktop_manager.cpp process_manager.cpp /Fe:marcha_native.dll user32.lib kernel32.lib shell32.lib advapi32.lib ole32.lib

if %ERRORLEVEL% == 0 (
    echo Build successful! marcha_native.dll created.
    echo Copying DLL to Flutter directory...
    copy marcha_native.dll ..\..\build\windows\x64\runner\Release\marcha_native.dll 2>nul
    copy marcha_native.dll ..\..\ 2>nul
    echo Done!
) else (
    echo Build failed with error %ERRORLEVEL%
)

pause