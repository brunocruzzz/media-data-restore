#!/bin/bash

# Script de Preparação para Restauração de Dados de DVDs
# Autor: Bruno da Cruz Bueno
# Data: 23/05/2024

# Descrição: Este script prepara a máquina para restauração de dados de DVDs,
#            configurando o ambiente necessário e instalando as ferramentas adequadas.


# Verificar a arquitetura do sistema

#sudo apt install growisofs
#$DVDDRIVE
#IMAGE/FOLDER
#growisofs -Z /dev/sr0=/home/user/brunocruzz/DATADISK-1206.ISO


clear

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
    echo "Sistema de 64 bits e productx de 32 bits."
    
    # Verificar se a arquitetura i386 já está instalada
    if ! dpkg --print-foreign-architectures | grep -q "i386"; then
        echo "Arquitetura i386 não está instalada. Adicionando..."
        # Adicionar a arquitetura i386
        sudo dpkg --add-architecture i386
        # Atualizar a lista de pacotes
        sudo apt update
    else
        echo "Arquitetura i386 já está instalada."
    fi
fi

# Instalação de Bibliotecas
# Adicione aqui os comandos para instalar as ferramentas necessárias para restauração de dados de DVDs
sleep 2
if ! dpkg -l | grep -q "libc6:i386" || ! dpkg -l | grep -q "libz1:i386" || ! dpkg -l | grep -q "zlib1g:i386" || ! dpkg -l | grep -q "libgcc-s1:i386" || ! dpkg -l | grep -q "libstdc++6:i386" || ! dpkg -l | grep -q "libgcc1:i386"; then
    echo "Algumas bibliotecas i386 necessárias não estão instaladas. Instalando..."
    # Instalar as bibliotecas necessárias
    sudo apt install -y -qq libc6:i386 libz1:i386 libstdc++6:i386 libgcc1:i386 zlib1g:i386 libgcc-s1:i386 growisofs
    echo "Todas as bibliotecas i386 necessárias estão instaladas."
else
    echo "Todas as bibliotecas i386 necessárias já estão instaladas."
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
    fi
else
    echo "Houve um problema ao verificar a versão do productx."
fi

# Conclusão
echo -e "\nPreparação concluída. A máquina está pronta para restauração de dados de DVDs.\n"
sleep 2
# Verificar se o arquivo de configuração existe
CONFIG_FILE="config.cfg"
if [ ! -f "$CONFIG_FILE" ]; then
        echo "Arquivo de configuração $CONFIG_FILE não encontrado. Criando novo arquivo de configuração..."

    # Detectar o dispositivo de CD/DVD usando blkid
    #DEVICE=$(blkid -o device | grep -m 1 "/dev/sr" || echo "/dev/sr0")
    DEVICE=$(blkid | grep iso9660 | awk -F: '{print $1}')
    # Solicitar ao usuário o ponto de montagem
    read -p "Por favor, insira o ponto de montagem(padrão: /mnt/dvd): " MOUNT_POINT
    MOUNT_POINT=${MOUNT_POINT:-/mnt/dvd}
    # Determina o diretório de trabalho
    WORKING_DIRECTORY="$HOME/media-data-restore/$(hostname)"

    # Criar o arquivo de configuração com as configurações fornecidas
    cat <<EOL > $CONFIG_FILE
DEVICE="$DEVICE"
FS_TYPE="iso9660"
MOUNT_POINT="$MOUNT_POINT"
WORKING_DIRECTORY="$WORKING_DIRECTORY"
LOG_FILE="$WORKING_DIRECTORY/log.txt"
EOL

    echo "Arquivo de configuração $CONFIG_FILE criado com sucesso."
fi


#wget do productx em um git nosso
#ldd productx
#move productx to use/local/bin
#hash -r
# sudo dpkg --add-architecture i386
# sudo apt update
# sudo apt install libc6:i386 libz1:i386 libstdc++6:i386 libgcc1:i386