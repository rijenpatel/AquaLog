@echo off
echo =====================================================================
echo  Installing Visual Studio Desktop C++ Workload for Flutter Windows
echo =====================================================================
echo.
echo Launching Visual Studio Installer with NativeDesktop C++ components...
echo Please approve the UAC Administrator prompt when asked.
echo.

powershell -Command "Start-Process 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe' -ArgumentList 'modify --installPath \"\"\"C:\Program Files\Microsoft Visual Studio\18\Community\"\"\" --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended' -Verb RunAs"

echo.
echo Visual Studio Installer window is now open.
echo Click 'Modify' or 'Install' to complete the setup.
pause
