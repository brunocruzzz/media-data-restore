clear
# Otimizador de Disco WSL - PowerShell
Write-Host "==== Otimizando o disco virtual WSL ====" -ForegroundColor Cyan
Write-Host ""

# Verifica se está em modo administrador
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[ERRO] Este script precisa ser executado como administrador." -ForegroundColor Red
    Pause
    Exit
}

# Verifica e ativa o recurso Hyper-V se necessário
Write-Host "Verificando se o recurso Hyper-V está habilitado..." -ForegroundColor Yellow
$feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All

if ($feature.State -ne 'Enabled') {
    Write-Host "[INFO] Habilitando o recurso Hyper-V..." -ForegroundColor Yellow
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart
} else {
    Write-Host "[OK] O recurso Hyper-V já está habilitado." -ForegroundColor Green
}

Write-Host ""
Write-Host "Procurando arquivos ext4.vhdx utilizados pelo WSL..." -ForegroundColor Yellow

# Localiza discos VHDX no diretório de pacotes
$vhdxList = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Directory |
    Where-Object { $_.Name -match 'Ubuntu|Debian|WSL' } |
    ForEach-Object {
        $vhdxPath = Join-Path $_.FullName 'LocalState\ext4.vhdx'
        if (Test-Path $vhdxPath) {
            Write-Host "[ENCONTRADO] $vhdxPath" -ForegroundColor Green
            return $vhdxPath  # <-- ESTA LINHA é essencial
        }
    }

Write-Host ""
Write-Host "Encerrando todas as distribuições WSL com 'wsl --shutdown'..." -ForegroundColor Yellow
wsl --shutdown
Start-Sleep -Seconds 5

# Otimiza cada VHDX encontrado
foreach ($vhdx in $vhdxList) {
    Write-Host "`n[OTIMIZANDO] $vhdx" -ForegroundColor Cyan
    try {
        Optimize-VHD -Path $vhdx -Mode Full
        Write-Host "[SUCESSO] Otimização concluída." -ForegroundColor Green
    } catch {
        Write-Host "[ERRO] Falha ao otimizar: $vhdx" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor DarkRed
    }
}

Write-Host ""
Write-Host "==== FIM ====" -ForegroundColor Cyan
Write-Host "Pressione qualquer tecla para encerrar..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
