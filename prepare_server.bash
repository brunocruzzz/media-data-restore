#!/usr/bin/bash

# Script de Preparação para Restauração de Dados de DVDs
# Autor(es):
# Bruno da Cruz Bueno
# Jaqueline Murakami Kokitsu
# Simone Cincotto Carvalho
# Data: 23/05/2024

# Descrição: Este script prepara a máquina para restauração de dados de DVDs,
#            configurando o ambiente necessário e instalando as ferramentas adequadas.

# Verificar a arquitetura do sistema

#sudo apt install growisofs
#$DVDDRIVE
#IMAGE/FOLDER
#growisofs -Z /dev/sr0=/home/user/brunocruzz/DATADISK-1206.ISO

clear
source functions.sh
# Verificar a arquitetura do sistema
architecture=$(uname -m)
echo "Sistema: $architecture"

# Verificação de Dependências
echo "Verificando e instalando dependências..."
# Adicione aqui os comandos para instalar as dependências necessárias
sleep 2
#echo "Arquiteturas presentes:" $(dpkg --print-foreign-architectures)
file productx

# Verificar se o sistema é de 64 bits e o productx é de 32 bits
if [[ $architecture == "x86_64" && $(file productx | grep "32-bit") ]]; then
    # Sistema de 64 bits e productx de 32 bits.
    # Verificar se a arquitetura i386 já está instalada
    if ! dpkg --print-foreign-architectures | grep -q "i386"; then
        echo "Arquitetura i386 não está instalada. Adicionando..."
        # Adicionar a arquitetura i386
        sudo dpkg --add-architecture i386        
    fi
fi

# Instalação de Bibliotecas
# Adicione aqui os comandos para instalar as ferramentas necessárias para restauração de dados de DVDs
sleep 2
if ! dpkg -l | grep -q "libc6:i386" || ! dpkg -l | grep -q "zlib1g:i386" || ! dpkg -l | grep -q "libgcc-s1:i386" || ! dpkg -l | grep -q "libstdc++6:i386"; then
    echo "Algumas bibliotecas necessárias não estão instaladas. Instalando..."
    # Instalar as bibliotecas necessárias
    # Lista de pacotes a serem instalados
    PACKAGES=(        
        libz1:i386
        zlib1g:i386        
        libgcc1:i386        
        libgcc-s1:i386
        libc6:i386
        libstdc++6:i386
        growisofs
        nfs-common
        tree
        dialog
    )

    # Atualiza a lista de pacotes e instala os pacotes listados
    sudo apt-get update -qq
    sudo apt-get install -y -qq "${PACKAGES[@]}"
    #sudo apt install -y -qq libc6:i386 libz1:i386 libstdc++6:i386 libgcc1:i386 zlib1g:i386 libgcc-s1:i386 growisofs nfs-common tree dialog
    echo "Todas as bibliotecas necessárias estão instaladas."
else
    echo "Todas as bibliotecas necessárias já estão instaladas."
fi

chmod +x productx

#ldd productx
# Verificar a versão do productx
if ./productx -v >/dev/null 2>&1; then
    # Verificar se já existe uma cópia igual em /usr/local/bin
    if cmp -s "productx" "/usr/local/bin/productx"; then
        echo "O executável productx já está disponível em /usr/local/bin"
    else
        # Se não existir, mover productx para /usr/local/bin
        sudo cp -n "productx" "/usr/local/bin/"

        # Atualizar o hash table dos comandos
        hash -r
        echo "Executável productx instalado em /usr/local/bin"
        echo -e "\nPreparação concluída. A máquina está pronta para restauração de dados de DVDs.\n"
    fi
else
    echo "Houve um problema ao verificar a versão do productx. Verifique se o programa encontra-se na máquina e configurado como executável"
fi

# Conclusão

sleep 2
# Verificar se o arquivo de configuração existe
CONFIG_FILE="config.cfg"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Arquivo de configuração $CONFIG_FILE não encontrado. Criando novo arquivo de configuração..."

    # Detectar o dispositivo de CD/DVD usando blkid
    #DEVICE=$(blkid -o device | grep -m 1 "/dev/sr" || echo "/dev/sr0")
    MACHINE_NAME=$(hostname)
    #DEVICE=$(blkid | grep iso9660 | awk -F: '{print $1}')
    if is_wsl; then
        DEVICE=$(powershell.exe -Command "(Get-CimInstance -ClassName Win32_CDROMDrive).Drive"  | tr -d '\r\n')
    else
        DEVICE=$(lsblk -o KNAME,PATH,TYPE | awk '$3 == "rom" {print $2}')
    fi    
    # Solicitar ao usuário o ponto de montagem
    read -p "Por favor, insira o ponto de montagem da mídia(padrão: /mnt/dvd): " MOUNT_POINT
    MOUNT_POINT=${MOUNT_POINT:-"/mnt/dvd"}
    # Determina o diretório de trabalho
    CURRENT_DIR=$(pwd)
    WORKING_DIRECTORY="$CURRENT_DIR/$MACHINE_NAME"
    LOG_DIR="$CURRENT_DIR/logs"
    LOG_FILE="$LOG_DIR/log.txt"
    READ_DVDS_FILE="$LOG_DIR/media-log.txt"
    LOG_DEPLOY="$LOG_DIR/deploy-log.txt"
    # Determina o diretório de logs
    mkdir -p "$LOG_DIR"
    touch $LOG_DEPLOY $LOG_FILE $READ_DVDS_FILE
    mkdir -p $WORKING_DIRECTORY
    mkdir -p $WORKING_DIRECTORY/catalog
    mkdir -p $WORKING_DIRECTORY/local
    mkdir -p $WORKING_DIRECTORY/outgoing
    chmod -R +w $CURRENT_DIR
    read -p "Por favor, insira o ponto de montagem da storage(padrão: /mnt/dados): " STORAGE_MOUNT_POINT
    STORAGE_MOUNT_POINT=${STORAGE_MOUNT_POINT:-/mnt/dados}
    read -p "Por favor, insira o ip da storage: " STORAGE_IP
    STORAGE_IP=${STORAGE_IP:-""}
    read -p "Por favor, insira diretório para upload na storage(padrão: /mnt/BD-IPMet/Dados/projDir/data/bruto/MACHINES/[NOME_DA_MAQUINA]): " STORAGE_PATH
    STORAGE_PATH=${STORAGE_PATH:-"/mnt/BD-IPMet/Dados/projDir/data/bruto/MACHINES/"}

    # Criar o arquivo de configuração com as configurações fornecidas
    cat <<EOL >$CONFIG_FILE
MACHINE_NAME="$MACHINE_NAME"
DEVICE="$DEVICE"
FS_TYPE="iso9660"
MOUNT_POINT="$MOUNT_POINT"
WORKING_DIRECTORY="$WORKING_DIRECTORY"
STORAGE_MOUNT_POINT="$STORAGE_MOUNT_POINT"
STORAGE_IP="$STORAGE_IP"
STORAGE_PATH="$STORAGE_PATH"
LOG_FILE="$LOG_FILE"
READ_DVDS_FILE="$READ_DVDS_FILE"
LOG_DEPLOY="$LOG_DEPLOY"
EOL

    echo "Arquivo de configuração $CONFIG_FILE criado com sucesso."
else
    echo "ATENÇÂO: Já existe um arquivo de configuração criado anteriormente. Verifique as informações contidas nele..."
    echo "Caso esteja enfrentando problemas, execute os seguintes passos: "
    echo "1--Apague ou renomeie o arquivo $CONFIG_FILE"
    echo "2--Execute novamente este script: $0"
    echo "3--Insira as informações solicitadas.(Contate a equipe de TI, se necessário)"
fi

echo "Fim do script de preparação."

#wget do productx em um git nosso
#ldd productx
#move productx to use/local/bin
#hash -r
# sudo dpkg --add-architecture i386
# sudo apt update
# sudo apt install libc6:i386 libz1:i386 libstdc++6:i386 libgcc1:i386