#DEFINIÇÃO DAS FUNÇÕES
# Verificar se o arquivo de configuração existe
CONFIG_FILE="config.cfg"
source "$CONFIG_FILE"
#LOG_FILE="log.txt"
#Tratamento de parametros
handle_parameters() {
    # Verifica se pelo menos um argumento foi passado
    if [ $# -eq 0 ]; then
        echo "Nenhum parâmetro enviado, comportamento padrão... (ler drive de mídia)"
        #handle_media_operation
        exec $0 "media"
    fi

    # Verifica se exatamente um argumento foi passado
    if [ $# -eq 1 ]; then
        case "$1" in
        "iso")
            echo "Restauração de dados de arquivo ISO. Desenvolvimento futuro..."
            exit 0
            ;;
        "media")
            #handle_media_operation
            ;;
        "folder")
            echo "Operação de integração de dados em um diretório. Desenvolvimento futuro..."
            exit 0
            ;;
        *)
            echo "Uso: $0 <media|iso|diretório> [localização]:$WORKING_DIRECTORY"
            exit 1
            ;;
        esac
    fi

    # Configurar o diretório de trabalho se o segundo argumento foi fornecido
    if [ -n "$2" ]; then
        WORKING_DIRECTORY="${2:-$WORKING_DIRECTORY}"
    fi
}

# Função para exibir o cabeçalho
exibir_cabecalho() {
    clear
    echo "--------------------------------------------------------"
    echo "      Sistema de restauração de dados de mídia!         "
    echo "--------------------------------------------------------"
}

check_disk_space() {
    local data_mount_point="$1"
    local usage=$(df "$data_mount_point" | awk 'NR==2 {print $3}')
    local readable_usage=$(df -h "$data_mount_point" | awk 'NR==2 {print $3}')
    sleep 2

    local disk="/"
    # Get the available disk space in human-readable format
    available_space=$(df "$disk" | awk 'NR==2 {print $4}')
    echo $available_space
    echo $usage
    if [ "$available_space" -lt "$usage" ]; then
        echo "Espaço em disco insuficiente($readable_usage). Verifique se existem dados a serem catalogados e enviados e então, execute uma limpeza usando o comando:"
        echo "./clean.bash clean"
        exit 1
    fi
}

monta_device() {
    sudo umount $MOUNT_POINT
    # Verificar se o ponto de montagem existe, caso contrário, criar
    if [ ! -d "$MOUNT_POINT" ]; then
        echo "Criando ponto de montagem..."
        sudo mkdir -p "$MOUNT_POINT"
    fi
    # Verifica se o dispositivo já está montado
    if mount | grep -q "$DEVICE"; then
        echo "Dispositivo $DEVICE já está montado."
        if mount | grep -q "$MOUNT_POINT"; then
            echo "$MOUNT_POINT já está montado."
        fi
    else
        # Tenta montar o dispositivo no ponto de montagem especificado
        if sudo mount "$DEVICE" "$MOUNT_POINT" >/dev/null 2>&1; then
            echo "Dispositivo $DEVICE montado com sucesso em $MOUNT_POINT."
        else
            createlog "Falha ao montar o dispositivo $DEVICE em $MOUNT_POINT." "$LOG_FILE"
            echo "Verifique se o DVD foi inserido corretamente..."
            exit 1
        fi
    fi
}

# Function to get the UUID of the DVD
get_dvd_uuid() {
    local device="$DEVICE"
    blkid "$device" | grep -oP 'UUID="\K[^"]+'
}
# Function to get the label of the DVD
get_dvd_label() {
    local device="$DEVICE"
    blkid -s LABEL -o value "$device"
}

check_dvd() {
    # Get the UUID of the DVD
    local device="$DEVICE"
    DVD_UUID=$(get_dvd_uuid "$device")
    DVD_LABEL=$(get_dvd_label "$device")
    if [ -z "$DVD_UUID" ]; then
        echo "Não foi possível ler o UUID do DVD. Terminando..."
        exit 1
    fi

    if [ ! -f "$READ_DVDS_FILE" ]; then
        touch "$READ_DVDS_FILE"
    fi
    # Check if the UUID is already in the read list
    if grep -q "$DVD_UUID" "$READ_DVDS_FILE"; then
        echo "ATENÇÃO!!! DVD com UUID $DVD_UUID foi registrado como lido/restaurado. Pressione q para sair ou espere para realizar a operação de cópia novamente..."
        # Verificar se o usuário pressionou Enter para encerrar o programa
        read -r -s -n 1 -t 5 input
        if [[ $input = "q" ]]; then
            echo -e "\nPrograma encerrado pelo usuário."
            exit 0
        fi
    fi
}
# Função para verificar se o dispositivo está montado
dispositivo_montado() {
    sudo mount -o rw $DEVICE $MOUNT_POINT >/dev/null 2>&1
    mountpoint -q "$MOUNT_POINT"

    return $?
}

copy_from() {
    rm -rf $err_local
    copy_start_time=$(date +%s)
    total_files=$(ls -1 "$MOUNT_POINT/product_raw/"*.RAW* 2>/dev/null | wc -l)
    echo "Copiando dados do DVD($total_files encontrados)..."
    #cp $MOUNT_POINT/product_raw/* .
    rsync -rh --info=progress2 --ignore-existing $MOUNT_POINT/product_raw/ $local 2>/dev/null
    # # Check the exit status of rsync
    if [ $? -eq 0 ]; then
        copy_end_time=$(date +%s)
        copy_execution_time=$((copy_end_time - copy_start_time))
        createlog "Cópia do DVD realizada com sucesso de $DEVICE($copy_execution_time s)" "$LOG_FILE"
        echo "DVD com UUID $DVD_UUID adicionado a lista de DVD's lidos."
        echo "$DVD_UUID" >>"$READ_DVDS_FILE"
    else
        copy_end_time=$(date +%s)
        copy_execution_time=$((copy_end_time - copy_start_time))
        createlog "A cópia $local foi mal-executada após $copy_execution_time s)" "$LOG_FILE"
        mv "$local" "$err_local"
        echo "Diretório renomeado para $err_local devido a falha/erro durante a cópia"
        exit 1
    fi
}
catalog() {
    move_start_time=$(date +%s)
    echo "Catalogando os dados copiados localmente em...$local"
    count_indefinido=0
    # Iterate over files in the subdir
    for fn in "$local"/*.RAW*; do
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
            echo "movendo para $WORKING_DIRECTORY/local/$DVD_UUID/$folder/$fn"
            #Move o arquivo para o respectivo diretório para armazenamento
            #mkdir -p $WORKING_DIRECTORY/$folder && mv $fn $_
            mkdir -p $WORKING_DIRECTORY/local/$DVD_UUID/$folder && mv $fn $_
        else
            echo "Arquivo vazio: $fn"
            ((count++))
            rm -f $fn
        fi
    done
    echo "OK"
    TAG="$min_date <--> $max_date"
    FTAG="$min_date"_"$max_date"
    createlog "Este DVD ($dvd_number) compreende o período $FTAG" "$LOG_FILE"
    move_end_time=$(date +%s)
    move_execution_time=$((move_end_time - move_start_time))

    echo "($move_execution_time s)"
    total_dados=$(find "$local" -type f | wc -l)
    indefinidos=$(find "$local/indefinido" -type f | wc -l)
    echo "Total de arquivos indefinidos neste dvd: ($indefinidos). Contate o suporte de TI."
    if [[ $total_files -gt $total_dados ]]; then
        num_error_files=$((total_files - total_dados))
        echo "Operação realizada com erro. Alguns arquivos não foram restaurados. $num_error_files arquivos faltantes/com problema."
    else
        createlog "$TAG | Dados catalogados com sucesso! $timestamp: $total_dados arquivos restaurados. $count arquivos vazios." "$LOG_FILE"
        catalog="$WORKING_DIRECTORY/catalog/$FTAG"
        mv "$local" "$catalog"
        echo "Apagando diretórios marcados com erro..."
        rm -rf $err_local
        ./sending_data.bash "$catalog" "$FTAG" &
    fi
}
# Função para ejetar o dispositivo
ejetar_midia() {
    sudo umount "$MOUNT_POINT"
    if [ $? -eq 0 ]; then
        sudo eject "$DEVICE"
        if [ $? -eq 0 ]; then
            echo "Dispositivo $DEVICE ejetado com sucesso."
        else
            echo "Falha ao ejetar o dispositivo $DEVICE."
        fi
    else
        echo "Falha ao desmontar o dispositivo $DEVICE."
    fi
}

gera_log() {
    echo "Gerando logs...(teste)"
}

process_var() {
    local var="$1"
    local dir="$2"
    local fn="$3"
    local LOG_FILE="$4"
    local prod
    local cidade
    local folder

    # Determine product type
    case "$var" in
    *SURVEI*)
        prod="sur"
        ;;
    *VOL_SCAN* | *VSCAN* | *PPI_VOL* | *CLUTTER*)
        prod="vol"
        ;;
    *CLEAR* | *AIR*)
        prod="cle"
        ;;
    *QUEIMA* | *FIRE*)
        prod="que"
        ;;
    *RHI* | *FRENTE* | *SECT* | *VVP*)
        prod="dif"
        ;;
    *)
        prod="indefinido"
        createlog "$fn: Problemas ao encontrar o rótulo de identificação do dado." "$LOG_FILE"
        ;;
    esac

    # Determine city of origin
    case "$var" in
    *[Bb]auru*)
        cidade="bru"
        ;;
    *[Pp]aulo* | *[Pp]rudente*)
        cidade="ppr"
        ;;
    *)
        cidade="indefinido"
        createlog "$fn: Problemas ao encontrar o rótulo de identificação do dado." "$LOG_FILE"
        #mv "$fn" "../indefinido"
        ;;
    esac

    # Determine the folder
    if [[ "$cidade" == "indefinido" || "$prod" == "indefinido" ]]; then
        folder="indefinido"
    else
        folder="$prod$cidade/$dir"
    fi

    echo "$folder"
}

monta_storage() {
    echo "Um processo de upload foi iniciado em segundo plano."
    echo "Confira os logs para verificação do envio"

    #PREPARAÇÃO DO AMBIENTE
    # Verificar se o ponto de montagem existe, caso contrário, criar
    if [ ! -d "$STORAGE_MOUNT_POINT" ]; then
        echo "Criando ponto de montagem $STORAGE_MOUNT_POINT"
        sudo mkdir -p "$STORAGE_MOUNT_POINT"
        sudo mount -t nfs -o rw,sync,hard,intr "$STORAGE_IP":/mnt/BD-IPMet/Dados /mnt/BD-IPMet
    else
        echo "$STORAGE_MOUNT_POINT já está montado..."
    fi
}

data_deploy() {
    local from=$1
    echo "Verificando o diretório $MACHINE_NAME em $STORAGE_MOUNT_POINT na storage para receber dados da máquina local..."
    mkdir -p "$STORAGE_MOUNT_POINT/MACHINES/$MACHINE_NAME"
    MACHINE_FOLDER="$STORAGE_MOUNT_POINT/MACHINES/$MACHINE_NAME"
    #echo "||$from --------------------------------> $MACHINE_FOLDER||"
    createlog "Iniciando a transferência de dados de '$from' para '$MACHINE_FOLDER'." "$LOG_DEPLOY"
    createlog "Diretório de destino: $MACHINE_FOLDER" "$LOG_DEPLOY"
    rsync -rh --info=progress2 $from $MACHINE_FOLDER
    if [ $? -eq 0 ]; then
        createlog "Transferência de dados concluída com sucesso para '$MACHINE_FOLDER'." "$LOG_DEPLOY"
    else
        createlog "Falha na transferência de dados para '$MACHINE_FOLDER'. Verifique os logs para mais detalhes." "$LOG_DEPLOY"
        echo "Contate o suporte de TI."
    fi
}
createlog() {
    local message="$1"
    local logfile="$2"
    echo $message
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$logfile"    
}