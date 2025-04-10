#!/bin/bash
###############################################################################
# Script de Restauração de Dados de DVDs
#
# Autor(es):
# - Bruno da Cruz Bueno
# - Jaqueline Murakami Kokitsu
# - Simone Cincotto Carvalho
#
# Descrição:
# Este script realiza a restauração de dados a partir de DVDs, ajudando na recuperação
# de informações críticas armazenadas em mídias físicas.
#
# Data de Criação: 23/05/2024
# Última Atualização: 04/07/2024
#
# Uso:
# ./script_restauracao_dados_dvd.sh [opções]
#
# Opções:
# -h, --help     Mostra esta mensagem de ajuda e sai
# -v, --version  Mostra a versão do script
#
###############################################################################

source functions.sh
load_config
clear
exibir_cabecalho
###########################################################################################################
#TRATAMENTO DOS PARAMETROS DE ENTRADA
###########################################################################################################
handle_parameters "$@"
echo "Preparando sistema..."
monta_device

###########################################################################################################
#PREPARAÇÃO DO AMBIENTE
###########################################################################################################
sleep 2
# Loop principal de leitura de dvd's
# Captura sinais comuns de encerramento e chama a função cleanup
trap cleanup SIGINT SIGTERM SIGQUIT

while true; do
    # Verifica se o dispositivo está montado(mountpoint)
    if dispositivo_montado; then
        check_disk_space "$DEVICE"
        #MOUNT_POINT="/mnt/iso"
        #MOUNT_POINT="/mnt/dvd"
        #DEVICE="/home/user/brunocruzz/DATADISK-1206.ISO"
        #DEVICE=$(blkid | grep iso9660 | awk -F: '{print $1}')
        # Obter o rótulo/UUID da mídia/imagem
        check_dvd
        echo -e "\nO rótulo da mídia/imagem é: $DVD_LABEL"
        echo_color -en "$YELLOW" "Insira o número identificador do DVD: "
        read -r dvd_number
        timestamp=$(date +"%Y%m%d_%H%M%S")
        createlog "------------------------------------------------------------------------------" "$LOG_FILE"
        createlog "ID: $dvd_number - UUID: $DVD_UUID - ID da execução: $timestamp" "$LOG_FILE"
        #echo "ID: $dvd_number - UUID: $DVD_UUID - ID da execução: $timestamp" | tee -a "$LOG_FILE"
        
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
        ejetar_midia "$MOUNT_POINT" "$DEVICE" 
        ############################################################################################################
        #PROCESSO DE CATALOGO E ORGANIZAÇÃO LOCAL
        ############################################################################################################
        catalog "$local" & disown
        # Final outputs
        #echo "Fim da rodada $ok_local" | tee -a $LOG_FILE
        createlog "Fim da rodada $ok_local" $LOG_FILE        
        #sudo umount $MOUNT_POINT
            
    else
        message="\rInsira um novo DVD de dados ou pressione q para sair... \033[K"
        echo -ne $message
    fi
    # Verificar se o usuário pressionou Enter para encerrar o programa
    check_user_exit
    # Aguardar um curto período de tempo antes de verificar novamente
    sleep 1
done
gera_log
echo "Fim do script"
exit 0
