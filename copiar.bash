#!/usr/bin/bash

# Script de Restauração de Dados de DVDs
# Autor(es): 
# Bruno da Cruz Bueno
# Jaqueline Murakami Kokitsu
# Simone Cincotto Carvalho
# Data: 23/05/2024

clear
source functions.sh
#clear
exibir_cabecalho
###########################################################################################################
#TRATAMENTO DOS PARAMETROS DE ENTRADA
###########################################################################################################
handle_parameters "$@"
echo "Preparando sistema..."
echo "Montando o dispositivo $DEVICE em $MOUNT_POINT com o sistema de arquivos $FS_TYPE..."
monta_device
check_disk_space "$MOUNT_POINT"

###########################################################################################################
#PREPARAÇÃO DO AMBIENTE
###########################################################################################################
mkdir -p $WORKING_DIRECTORY
mkdir -p $WORKING_DIRECTORY/catalog
mkdir -p $WORKING_DIRECTORY/local
mkdir -p $WORKING_DIRECTORY/outgoing
chmod -R +w $WORKING_DIRECTORY

sleep 2
# Loop principal de leitura de dvd's
while true; do
    # Verifica se o dispositivo está montado(mountpoint)
    if dispositivo_montado; then
        #MOUNT_POINT="/mnt/iso"
        #MOUNT_POINT="/mnt/dvd"
        #DEVICE="/home/user/brunocruzz/DATADISK-1206.ISO"
        #DEVICE=$(blkid | grep iso9660 | awk -F: '{print $1}')
        # Obter o rótulo/UUID da mídia/imagem
        check_dvd
        echo "O rótulo da mídia/imagem é: $DVD_LABEL"
        echo -n "Insira o número identificador do DVD: "
        read -r dvd_number
        timestamp=$(date +"%Y%m%d_%H%M%S")
        echo "ID: $dvd_number - UUID: $DVD_UUID - ID da execução: $timestamp" | tee -a "$LOG_FILE"
        
        ###########################################################################################################
        #VARIÁVEIS DE CONTROLE
        ###########################################################################################################
        count=0        
        min_date=""
        max_date=""

        # Criar subdiretório com timestamp        
        #subdir="$WORKING_DIRECTORY/$timestamp"
        
        # Criar subdiretório local com UUID
        local="$WORKING_DIRECTORY/local/$DVD_UUID"
        err_local="$WORKING_DIRECTORY/local/ERR_$DVD_UUID"
        mkdir -p "$local"

        ############################################################################################################
        #PROCESSO DE CÓPIA
        ############################################################################################################
        copy_from     
        sleep 3

        ############################################################################################################
        #PROCESSO DE CATALOGO E ORGANIZAÇÃO LOCAL
        ############################################################################################################
        catalog
        # Final outputs
        echo "Fim da rodada $ok_local" | tee -a $LOG_FILE
        #sudo umount $MOUNT_POINT
        ejetar_midia        
    else
        message="\rInsira um novo DVD de dados ou pressione q para sair... \033[K"
        echo -ne $message
    fi
    # Verificar se o usuário pressionou Enter para encerrar o programa
    read -r -s -n 1 -t 1 input
    if [[ $input = "q" ]]; then
        sudo umount "$MOUNT_POINT"
        echo -e "\nPrograma encerrado pelo usuário."
        exit 0
    fi

    # Aguardar um curto período de tempo antes de verificar novamente
    #sleep 1
done
gera_log
echo "Fim do script"
exit 0
