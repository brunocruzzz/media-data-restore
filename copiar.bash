#!/usr/bin/bash

clear
# Verificar se o arquivo de configuração existe
CONFIG_FILE="config.cfg"
source "$CONFIG_FILE"
source functions.sh
#DEFINIÇÃO DOS PARÂMETROS#############################
############################################################################################################
echo "Preparando sistema..."

# Loop principal
while true; do
    # Verificar se o dispositivo está montado
    if dispositivo_montado; then
        clear
        exibir_cabecalho
        echo "Montando o dispositivo $DEVICE em $MOUNT_POINT com o sistema de arquivos $FS_TYPE..."

        #MOUNT_POINT="/mnt/iso"
        #MOUNT_POINT="/mnt/dvd"
        #DEVICE="/home/user/brunocruzz/DATADISK-1206.ISO"
        #DEVICE=$(blkid | grep iso9660 | awk -F: '{print $1}')
        #WORKING_DIRECTORY="$HOME/media-data-restore/$(hostname)" #É Possivel colocarmos aqui o nome da maquina (hostname), para ser mais reconhecivel a origem dos dados para a storage.


        LOG_FILE="log.txt"
        ###########################################################################################################
        #VARIÁVEIS DE CONTROLE
        ############################################################################################################
        ############################################################################################################

        #PREPARAÇÃO DO AMBIENTE
        # Verificar se o ponto de montagem existe, caso contrário, criar
        if [ ! -d "$MOUNT_POINT" ]; then
            echo "Criando ponto de montagem..."
            sudo mkdir -p "$MOUNT_POINT"
        fi
        #sudo mkdir -p $MOUNT_POINT
        mkdir -p $WORKING_DIRECTORY

        if mount | grep "$DEVICE" > /dev/null; then
            echo "Dispositivo $DEVICE já está montado."
        else
            sudo mount $DEVICE $MOUNT_POINT
            if [ $? -eq 0 ]; then
                echo "Dispositivo $DEVICE montado com sucesso em $MOUNT_POINT."
            else
                echo "Falha ao montar o dispositivo $DEVICE." | tee -a $LOG_FILE
            fi
        fi

        # Obter o rótulo da imagem
        label=$(blkid -s LABEL -o value "$DEVICE")

        echo "O rótulo da imagem é: $label"
        #cd $WORKING_DIRECTORY
        ############################################################################################################

        #PROCESSO DE COPIA DOS DADOS
        count=0
        # Criar subdiretório com timestamp
        timestamp=$(date +"%Y%m%d_%H%M%S")
        subdir="$WORKING_DIRECTORY/$timestamp"
        mkdir -p "$subdir"

        copy_start_time=$(date +%s)
        num_files=$(ls -1 "$MOUNT_POINT/product_raw/"*.RAW* | wc -l)
        echo "ID da execução: $timestamp"
        echo -n "Copiando dados do DVD($num_files encontrados)..."
        # Count the number of files in the ISO
        #cp $MOUNT_POINT/product_raw/* .
        rsync -rh --info=progress2 $MOUNT_POINT/product_raw/ $subdir
        copy_end_time=$(date +%s)
        copy_execution_time=$((copy_end_time - copy_start_time))
        echo "Dados copiados com sucesso de $DEVICE($copy_execution_time s)"
        ############################################################################################################
        sleep 3

        #CATALOGANDO DADOS RESTAURADOS
        move_start_time=$(date +%s)
        echo -n "Catalogando os dados copiados..."
        # Lista todos os arquivos que correspondem ao padrão *.RAW* e os lê linha a linha.
        ls $MOUNT_POINT/product_raw/*.RAW* -1 | while read fn; do
            dir=20${fn:3:6} # Extrai a data do nome do arquivo e armazena na variável 'dir'
            radar=${fn:0:3} # Extrai o identificador do radar do nome do arquivo e armazena na variável 'radar'
            cidade=""
            prod=""
            # Verifica se o arquivo não está vazio
            if [[ -s $fn ]]; then
                var=$(/usr/local/bin/productx "$fn" <<EOF 2>/dev/null | awk '/What parameter do you wish to display?/ {exit} {print}'

EOF
)
                ############################################################################################################
                #Agora podemos manusear os dados de uma maneira mais prática
                #Usar um -verbose para exibir os cabeçalhos[opcional]
                #echo "$var" # aspas garantem o formato adequado para output[quebra de linhas]
                ############################################################################################################
                # Verifica o produto
                case "$var" in
                *SURVEI*)
                    prod="sur"
                    ;;
                *VOL_SCAN* | *VSCAN* | *PPI_VOL* | *CLUTTER*)
                    prod="vol"
                    ;;
                *CLEAR* | *AIR*)
                    prod=cle
                    ;;
                *QUEIMA* | *FIRE*)
                    prod="que"
                    ;;
                *RHI* | *FRENTE* | *SECT* | *VVP*)
                    prod="dif"
                    ;;
                *)
                    prod="indefinido"
                    echo "$fn: Problemas ao encontrar o rótulo de identificação do dado." | tee -a $LOG_FILE
                    ;;
                esac
                # Verifica o radar de origem
                case "$var" in
                *[Bb]auru*)
                    cidade="bru"
                    ;;
                *[Pp]aulo* | *[Pp]rudente*)
                    cidade="ppr"
                    ;;
                *)
                    cidade="indefinido"            
                    echo "$fn: Problemas ao encontrar o rótulo de identificação do dado." | tee -a $LOG_FILE
                    #mv "$fn" "../indefinido"
                    ;;
                esac

                if [[ "$cidade" == "indefinido" || "$prod" == "indefinido" ]]; then
                    folder="indefinido"
                else
                    folder=$prod$cidade/$dir
                fi

                #echo "MOVENDO PARA $folder/$dir/$fn" # DEBUG CONTROL
                #Move o arquivo para o respectivo diretório para armazenamento
                mkdir -p $WORKING_DIRECTORY/$folder && mv $fn $_
            else
                echo "Arquivo vazio: $fn"
                ((count++))
                rm -f $fn
            fi
        done
        echo -n "OK"
        move_end_time=$(date +%s)
        move_execution_time=$((move_end_time - move_start_time))

        echo "($move_execution_time s)"
        total_dados=$(find "$subdir" -type f | wc -l)
        echo "Dados catalogados com sucesso! $timestamp: $total_dados arquivos restaurados. $count arquivos vazios." | tee -a $LOG_FILE

        ./sending_data.bash &
        #sudo umount $MOUNT_POINT
        ejetar_midia        
    else
        message="Insira um novo DVD de dados ou pressione q para sair..."
        echo -n $message
    fi
    #limpar_buffer
    # Verificar se o usuário pressionou Enter para encerrar o programa
    read -r -s -n 1 -t 1 input
    if [[ $input = "q" ]]; then
        echo "Programa encerrado pelo usuário."
        break
    fi

    # Aguardar um curto período de tempo antes de verificar novamente
    sleep 1
done

echo "Fim do script"
exit