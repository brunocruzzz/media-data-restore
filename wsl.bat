@echo off
echo ==== Instalando o WSL ====

:: Verifica se o script está em modo administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Por favor, execute este script como administrador.
    pause
    exit /b
)

:: Habilita o recurso WSL
echo Ativando o recurso WSL...
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

:: Habilita a Virtual Machine Platform (necessária para WSL 2)
echo Ativando o recurso Plataforma de Máquina Virtual...
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

:: (Opcional) Ativa o recurso de Plataforma de Máquina Virtual para Hyper-V se desejar suporte completo
:: dism.exe /online /enable-feature /featurename:Microsoft-Hyper-V-All /all /norestart

:: Define o WSL 2 como padrão
echo Definindo o WSL 2 como padrão...
wsl --set-default-version 2

:: Instala a distribuição padrão (Ubuntu)
echo Instalando a distribuição padrão (Ubuntu)...
wsl --install -d Ubuntu

echo.
echo ==== Instalação concluída ====
echo Reinicie o computador se solicitado.
pause