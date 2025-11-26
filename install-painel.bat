@echo off
title Instalador do Painel
echo =====================================================
echo  INSTALANDO PAINEL
echo =====================================================
echo.

:: =========================================
:: 1) Criar arquivo painel.ps1 em C:\
:: =========================================
echo Criando C:\painel.ps1 ...

(
echo Clear-Host
echo.
echo #########################################################################
echo # PAINEL.PS1 — Versao completa final
echo #########################################################################
echo.
echo $LoadingScript = {
echo     $frames = @("⠋","⠙","⠴","⠦","⠇","⠏")
echo     $i = 0
echo     while ($true^) {
echo         Write-Host "`rCarregando e configurando o computador...  $($frames[$i])" -NoNewline
echo         Start-Sleep -Milliseconds 150
echo         $i = ($i + 1^) %% $frames.Length
echo     }
echo }
echo $LoadingJob = Start-Job -ScriptBlock $LoadingScript
echo.
echo try {
echo.
echo     Write-Host "Pausando atualizacoes do Windows..."
echo     $PauseUntil = (Get-Date^).AddDays(1^).ToString("yyyy-MM-dd")
echo     reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v PauseFeatureUpdatesStartTime /t REG_SZ /d "$(Get-Date^)" /f ^| Out-Null
echo     reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v PauseFeatureUpdatesEndTime   /t REG_SZ /d $PauseUntil /f ^| Out-Null
echo.
echo     Write-Host "Pausando atualizacoes dos navegadores..."
echo     reg add "HKLM\SOFTWARE\Policies\Google\Update" /v AutoUpdateCheckPeriodMinutes /t REG_DWORD /d 720 /f ^| Out-Null
echo     reg add "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" /v AutoUpdateCheckPeriodMinutes /t REG_DWORD /d 720 /f ^| Out-Null
echo     reg add "HKLM\SOFTWARE\Policies\Mozilla\Firefox" /v AppAutoUpdate /t REG_DWORD /d 0 /f ^| Out-Null
echo.
echo     Start-Sleep -Seconds 60
echo.
echo     $Firefox = "C:\Program Files\Mozilla Firefox\firefox.exe"
echo     $URL = "http://172.16.0.11/painel"
echo     if (Test-Path $Firefox^) { Start-Process $Firefox $URL } else { Write-Error "Firefox nao encontrado."; exit }
echo     Start-Sleep 3
echo.
echo     $Sig = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
echo     Add-Type -Namespace win -Name api -MemberDefinition $Sig
echo     $fx = Get-Process firefox ^| Select-Object -First 1
echo     if ($fx^) { [win.api]::ShowWindowAsync($fx.MainWindowHandle, 3^) }
echo.
echo     $Hora = (Get-Date^).AddHours(12^).ToString("HH:mm")
echo     schtasks /Create /TN "PainelAutoShutdown" /TR "shutdown /s /f /t 0" /SC ONCE /ST $Hora /F ^| Out-Null
echo.
echo     Start-Job -ScriptBlock {
echo         while ($true^) {
echo             Start-Sleep -Seconds (30 * 60^)
echo             $ws = New-Object -ComObject wscript.shell
echo             $ws.AppActivate("Mozilla Firefox"^)
echo             Start-Sleep 1
echo             $ws.SendKeys("{F5}"^)
echo         }
echo     } ^| Out-Null
echo.
echo     reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" /v NOC_GLOBAL_SETTING_TOASTS_ENABLED /t REG_DWORD /d 0 /f ^| Out-Null
echo     reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\QuietHours" /v QuietHoursActive /t REG_DWORD /d 1 /f ^| Out-Null
echo     reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\QuietHours" /v QuietHoursType /t REG_DWORD /d 3 /f ^| Out-Null
echo.
echo } finally {
echo     Stop-Job $LoadingJob -Force ^| Out-Null
echo     Remove-Job $LoadingJob
echo     Clear-Host
echo     Write-Host "Painel carregado."
echo }
)>C:\painel.ps1

echo OK!
echo.

:: =========================================
:: 2) Criar PainelLauncher.exe
:: =========================================
echo Criando PainelLauncher.exe ...

(
echo using System;
echo using System.Diagnostics;
echo.
echo public class PainelLauncher {
echo     public static void Main() {
echo         ProcessStartInfo psi = new ProcessStartInfo();
echo         psi.FileName = "powershell.exe";
echo         psi.Arguments = "-ExecutionPolicy Bypass -File C:\\painel.ps1";
echo         psi.Verb = "runas";
echo         psi.UseShellExecute = true;
echo         try {
echo             Process.Start(psi);
echo         } catch { }
echo     }
echo }
)>C:\PainelLauncher.cs

powershell -ExecutionPolicy Bypass ^
    Add-Type -OutputAssembly C:\PainelLauncher.exe -OutputType ConsoleApplication -Path C:\PainelLauncher.cs

echo EXE criado em C:\PainelLauncher.exe
echo.

:: =========================================
:: 3) Criar atalho no Startup
:: =========================================
echo Criando atalho no Startup...

powershell -ExecutionPolicy Bypass ^
    "$W = New-Object -ComObject WScript.Shell; `
     $S = $W.CreateShortcut([Environment]::GetFolderPath('Startup') + '\Painel.lnk'); `
     $S.TargetPath = 'C:\PainelLauncher.exe'; `
     $S.IconLocation = 'C:\PainelLauncher.exe'; `
     $S.Save()"

echo Atalho criado.
echo.

echo =====================================================
echo INSTALACAO CONCLUIDA!
echo O painel sera iniciado automaticamente apos o login.
echo =====================================================
pause
exit
