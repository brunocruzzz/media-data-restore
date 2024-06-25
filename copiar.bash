#!/usr/bin/bash

clear
source functions.sh
#clear
exibir_cabecalho
#TRATAMENTO DOS PARAMETROS DE ENTRADA
handle_parameters "$@"
####################################################
echo "Preparando sistema..."
echo "Montando o dispositivo $DEVICE em $MOUNT_POINT com o sistema de arquivos $FS_TYPE..."

monta_device
check_disk_space "$MOUNT_POINT"

#PREPARAÇÃO DO AMBIENTE
mkdir -p $WORKING_DIRECTORY
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
        echo -n "Insira o número identificador do DVD: "
        read -r dvd_number
        echo "O rótulo da mídia/imagem é: $DVD_LABEL"
        echo "ID: $dvd_number - UUID: $DVD_UUID - ID da execução: $timestamp" | tee -a "$LOG_FILE"
        
        ###########################################################################################################
        #VARIÁVEIS DE CONTROLE
        ###########################################################################################################
        count=0        
        min_date=""
        max_date=""

        # Criar subdiretório com timestamp
        timestamp=$(date +"%Y%m%d_%H%M%S")
        subdir="$WORKING_DIRECTORY/$timestamp"
        subdir="$WORKING_DIRECTORY/$DVD_UUID"
        err_subdir="$WORKING_DIRECTORY/ERR_$DVD_UUID"
        mkdir -p "$subdir"

        ############################################################################################################
        #PROCESSO DE CÓPIA
        ############################################################################################################
        copy_start_time=$(date +%s)
        total_files=$(ls -1 "$MOUNT_POINT/product_raw/"*.RAW* 2>/dev/null | wc -l)
        echo "Copiando dados do DVD($total_files encontrados)..."
        # Count the number of files in the ISO
        #cp $MOUNT_POINT/product_raw/* .
        rsync -rh --info=progress2 --ignore-existing $MOUNT_POINT/product_raw/ $subdir 2>/dev/null
        # # Check the exit status of rsync
        if [ $? -eq 0 ]; then
            copy_end_time=$(date +%s)
            copy_execution_time=$((copy_end_time - copy_start_time))
            echo "Cópia do DVD realizada com sucesso"
            echo "Dados copiados com sucesso de $DEVICE($copy_execution_time s)" | tee -a "$LOG_FILE"
            echo "DVD com UUID $DVD_UUID adicionado a lista de DVD's lidos."
            echo "$DVD_UUID" >>"$READ_DVDS_FILE"
        else
            copy_end_time=$(date +%s)
            copy_execution_time=$((copy_end_time - copy_start_time))                        
            echo "A cópia $subdir foi mal-executada após $copy_execution_time s)" | tee -a "$LOG_FILE"
            mv "$subdir" "$err_subdir"
            echo "Diretório renomeado para $err_subdir devido a falha/erro durante a cópia"
            exit 1
        fi        
        sleep 3

        ############################################################################################################
        #PROCESSO DE CATALOGO E ORGANIZAÇÃO LOCAL
        ############################################################################################################
        move_start_time=$(date +%s)
        echo "Catalogando os dados copiados localmente em...$subdir"
        

        # Iterate over files in the subdir
        for fn in "$subdir"/*.RAW*; do
            #echo "Processing file: $fn"
            #OUTDATED -> Buscando o Ingest time de dentro do dado.
            #dir=20${fn:3:6} # Extrai a data do nome do arquivo e armazena na variável 'dir'

            radar=${fn:0:3} # Extrai o identificador do radar do nome do arquivo e armazena na variável 'radar'
            cidade=""
            prod=""
            # Verifica se o arquivo não está vazio
            if [[ -s $fn ]]; then
                var=$(
                    /usr/local/bin/productx "$fn" <<EOF 2>/dev/null | awk '/What parameter do you wish to display?/ {exit} {print}'

EOF
                )
                ############################################################################################################
                #Agora podemos manusear os dados de uma maneira mais prática
                #Usar um -verbose para exibir os cabeçalhos[opcional]
                #echo "$var" # aspas garantem o formato adequado para output[quebra de linhas]
                gen_time=$(echo "$var" | grep "Ingest time:")
                dir=$(echo "$gen_time" | awk '{print $6}')
                ingest_date=$(echo "$gen_time" | awk '{print $4 "-" $5 "-" $6}')
                #echo "$dir ---> $fn"
                #echo $ingest_date
                converted_date=$(date -d "$ingest_date" +"%Y-%m-%d")
                #echo "$converted_date"
                # Update the minimum and maximum dates
                if [ -z "$min_date" ] || [[ "$converted_date" < "$min_date" ]]; then
                    min_date="$converted_date"
                    #echo "Updated min_date: $min_date"
                fi

                if [ -z "$max_date" ] || [[ "$converted_date" > "$max_date" ]]; then
                    max_date="$converted_date"
                    #echo "Updated max_date: $max_date"
                fi

                ############################################################################################################
                # Verifica o produto
                folder=$(process_var "$var" "$dir" "$fn" "$LOG_FILE")
                #echo "Folder: $folder"

                #echo "MOVENDO PARA $folder/$dir/$fn" # DEBUG CONTROL

                #Move o arquivo para o respectivo diretório para armazenamento
                #mkdir -p $WORKING_DIRECTORY/$folder && mv $fn $_
                mkdir -p $WORKING_DIRECTORY/$DVD_UUID/$folder && mv $fn $_
            else
                echo "Arquivo vazio: $fn"
                ((count++))
                rm -f $fn
            fi
        done
        echo "OK"
        TAG="$min_date <--> $max_date"
        FTAG="$min_date"_"$max_date"
        echo $FTAG
        move_end_time=$(date +%s)
        move_execution_time=$((move_end_time - move_start_time))

        echo "($move_execution_time s)"
        total_dados=$(find "$subdir" -type f | wc -l)
        if [[ $total_files -gt $total_dados ]]; then
            num_error_files=$((total_files - total_dados))
            echo "Operação realizada com erro. Alguns arquivos não foram restaurados. $num_error_files arquivos faltantes/com problema."
        else
            echo "$TAG | Dados catalogados com sucesso! $timestamp: $total_dados arquivos restaurados. $count arquivos vazios." | tee -a $LOG_FILE
            ok_subdir="$WORKING_DIRECTORY/$FTAG"
            mv "$subdir" "$ok_subdir"
            ./sending_data.bash "$ok_subdir" "$FTAG" &
        fi
        # Final outputs
        echo "Fim da rodada $ok_subdir" | tee -a $LOG_FILE
        #sudo umount $MOUNT_POINT
        #ejetar_midia
        exit 1
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
