###############################################################################
#EXECUTAR O COMANDO ABAIXO NO POWERSHELL COM ADMINISTRADOR PARA PERMITIR A 
#EXECUÇÃO DO CÓDIGO A SEGUIR

# powershell -ExecutionPolicy Bypass -File Install-Painel.ps1
###############################################################################




###############################################################################
# INSTALL-PAINEL — Instalação completa do Painel
###############################################################################

Write-Host "`n=== Instalando Painel ===`n"

###############################################################################
# 1) Criar script C:\painel.ps1
###############################################################################

$PainelPath = "C:\painel.ps1"

$PainelConteudo = @'
#########################################################################################
# PAINEL.PS1 — Versão completa final
#########################################################################################

Clear-Host

#########################################################################################
# 1) Tela de Loading
#########################################################################################
$LoadingScript = {
    $frames = @("⠋","⠙","⠴","⠦","⠇","⠏")
    $i = 0
    while ($true) {
        Write-Host "`rCarregando e configurando o computador...  $($frames[$i])" -NoNewline
        Start-Sleep -Milliseconds 150
        $i = ($i + 1) % $frames.Length
    }
}
$LoadingJob = Start-Job -ScriptBlock $LoadingScript

try {

#########################################################################################
# 2.1) Pausar temporariamente atualizações do Windows (seguro)
#########################################################################################

Write-Host "Pausando atualizações do Windows..."
$PauseUntil = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")
reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v PauseFeatureUpdatesStartTime /t REG_SZ /d "$(Get-Date)" /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v PauseFeatureUpdatesEndTime   /t REG_SZ /d $PauseUntil /f | Out-Null

#########################################################################################
# 2.2) Navegadores — reduzir/pausar atualização temporária
#########################################################################################

Write-Host "Pausando atualizações automáticas dos navegadores..."

# Google Chrome
reg add "HKLM\SOFTWARE\Policies\Google\Update" /v AutoUpdateCheckPeriodMinutes /t REG_DWORD /d 720 /f | Out-Null

# Microsoft Edge
reg add "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" /v AutoUpdateCheckPeriodMinutes /t REG_DWORD /d 720 /f | Out-Null

# Mozilla Firefox
reg add "HKLM\SOFTWARE\Policies\Mozilla\Firefox" /v AppAutoUpdate /t REG_DWORD /d 0 /f | Out-Null

#########################################################################################
# 2.3) Aguardar carregamento total do sistema
#########################################################################################
Start-Sleep -Seconds 60

#########################################################################################
# 2.4) Abrir Firefox no painel
#########################################################################################
$Firefox = "C:\Program Files\Mozilla Firefox\firefox.exe"
$URL = "http://172.16.0.11/painel"

if (Test-Path $Firefox) {
    Start-Process $Firefox $URL
} else {
    Stop-Job $LoadingJob -Force
    Clear-Host
    Write-Error "Firefox não encontrado."
    exit
}

Start-Sleep 3

#########################################################################################
# 2.5) Maximizar Firefox
#########################################################################################
$Sig = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
Add-Type -Namespace win -Name api -MemberDefinition $Sig

$fx = Get-Process firefox | Select-Object -First 1
if ($fx) {
    [win.api]::ShowWindowAsync($fx.MainWindowHandle, 3)
}

#########################################################################################
# 2.6) Desligar automaticamente após 12 horas
#########################################################################################
$Hora = (Get-Date).AddHours(12).ToString("HH:mm")
schtasks /Create /TN "PainelAutoShutdown" /TR "shutdown /s /f /t 0" /SC ONCE /ST $Hora /F | Out-Null

#########################################################################################
# 2.7) Refresh automático a cada 30 minutos
#########################################################################################
Start-Job -ScriptBlock {
    while ($true) {
        Start-Sleep -Seconds (30 * 60)
        $ws = New-Object -ComObject wscript.shell
        $ws.AppActivate("Mozilla Firefox")
        Start-Sleep 1
        $ws.SendKeys("{F5}")
    }
} | Out-Null

#########################################################################################
# 2.11) Permitir emissão de som
#########################################################################################
# Garante que o sistema não esteja mudo (usa nircmd se disponível)
nircmd.exe mutesysvolume 0 2>$null

#########################################################################################
# 2.12) Remover notificações (Focus Assist)
#########################################################################################
Write-Host "Ativando modo silencioso de notificações..."
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" /v NOC_GLOBAL_SETTING_TOASTS_ENABLED /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\QuietHours" /v QuietHoursActive /t REG_DWORD /d 1 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\QuietHours" /v QuietHoursType /t REG_DWORD /d 3 /f | Out-Null

#########################################################################################
# VNC, teclado, mouse e desktop são mantidos automaticamente (nenhuma ação necessária)
#########################################################################################

} finally {
    Stop-Job $LoadingJob -Force | Out-Null
    Remove-Job $LoadingJob
    Clear-Host
    Write-Host "Painel carregado."
}
'@

Set-Content -Path $PainelPath -Value $PainelConteudo -Encoding UTF8 -Force
Write-Host "Arquivo criado em: $PainelPath"


###############################################################################
# 2) Criar EXE que executa painel.ps1 como administrador (PainelLauncher.exe)
###############################################################################

$LauncherCS = @"
using System;
using System.Diagnostics;

public class PainelLauncher {
    public static void Main() {
        ProcessStartInfo psi = new ProcessStartInfo();
        psi.FileName = "powershell.exe";
        psi.Arguments = "-ExecutionPolicy Bypass -File C:\\painel.ps1";
        psi.Verb = "runas";  // Executar como Administrador
        psi.UseShellExecute = true;
        try {
            Process.Start(psi);
        } catch {
        }
    }
}
"@

$CSPath = "C:\PainelLauncher.cs"
$EXEPath = "C:\PainelLauncher.exe"

Set-Content -Path $CSPath -Value $LauncherCS -Encoding UTF8
Write-Host "Arquivo C# criado: $CSPath"

Add-Type -OutputAssembly $EXEPath -OutputType ConsoleApplication -Path $CSPath
Write-Host "Executável criado: $EXEPath"


###############################################################################
# 3) Criar atalho no Startup para execução automática no login
###############################################################################

$StartupFolder = [Environment]::GetFolderPath("Startup")
$ShortcutPath = "$StartupFolder\Painel.lnk"

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = $EXEPath
$Shortcut.WorkingDirectory = "C:\"
$Shortcut.IconLocation = $EXEPath
$Shortcut.Save()

Write-Host "Atalho criado em: $ShortcutPath"


###############################################################################
# FINAL
###############################################################################
Write-Host "`nInstalação concluída!"
Write-Host "O painel será carregado automaticamente ao fazer login."
Write-Host ""
