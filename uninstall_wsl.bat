@echo off
echo ==== Desinstalando WSL e limpando dados ====

:: Verifica se o script está em modo administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Por favor, execute este script como administrador.
    pause
    exit /b
)

:: Encerra todas as instâncias WSL
echo Encerrando todas as instâncias do WSL...
wsl --shutdown

:: Remove a distribuição Ubuntu (se ainda estiver instalada)
echo Verificando e desinstalando distribuições Linux...
for /f "tokens=*" %%i in ('wsl --list --quiet') do (
    echo Removendo distribuiçao: %%i
    wsl --unregister "%%i"
)

:: Espera um pouco para garantir que tudo foi finalizado
timeout /t 3 >nul

:: Deleta arquivos de usuário relacionados ao WSL
echo Limpando arquivos de usuário (configurações e VHDs)...
rd /s /q "%USERPROFILE%\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu*" >nul 2>&1
rd /s /q "%USERPROFILE%\AppData\Local\Packages\TheDebianProject*" >nul 2>&1
rd /s /q "%USERPROFILE%\AppData\Local\lxss" >nul 2>&1

:: Desativa os recursos do Windows
echo Desativando o recurso WSL...
dism.exe /online /disable-feature /featurename:Microsoft-Windows-Subsystem-Linux /norestart

echo Desativando o recurso Plataforma de Máquina Virtual...
dism.exe /online /disable-feature /featurename:VirtualMachinePlatform /norestart

:: (Opcional) Desativa o Hyper-V se tiver sido ativado
:: dism.exe /online /disable-feature /featurename:Microsoft-Hyper-V-All /norestart

echo.
echo ==== Desinstalação concluída ====
echo Reinicie o computador para finalizar a remoção.
pause