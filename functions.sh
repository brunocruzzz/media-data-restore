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
        $0 "media" &&
            exit 1
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

    # Use df to get disk space usage for the specified mount point
    local usage=$(df "$data_mount_point" | awk 'NR==2 {print $3}')
    echo "Tamanho da restauração: $usage"
    sleep 3

    local disk="/"
    # Get the available disk space in human-readable format
    available_space=$(df "$disk" | awk 'NR==2 {print $4}')
    if [ "$available_space" -gt "$usage" ]; then
        echo "Espaço disponível em disco $disk: $available_space"
    else
        echo "Espaço em disco insuficiente."
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
            echo "Falha ao montar o dispositivo $DEVICE em $MOUNT_POINT." | tee -a "$LOG_FILE"
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
        echo "$fn: Problemas ao encontrar o rótulo de identificação do dado." | tee -a "$LOG_FILE"
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
        echo "$fn: Problemas ao encontrar o rótulo de identificação do dado." | tee -a "$LOG_FILE"
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
    echo "Iniciando a transferência de dados de '$from' para '$MACHINE_FOLDER'."
    #echo "DIRETORIO DE DEPLOY $MACHINE_FOLDER" | tee -a $LOG_DEPLOY
    echo "Diretório de destino: $MACHINE_FOLDER" | tee -a $LOG_DEPLOY
    rsync -rh --info=progress2 $from $MACHINE_FOLDER
    if [ $? -eq 0 ]; then
        echo "Transferência de dados concluída com sucesso para '$MACHINE_FOLDER'." | tee -a $LOG_DEPLOY
    else
        echo "Falha na transferência de dados para '$MACHINE_FOLDER'. Verifique os logs para mais detalhes." | tee -a $LOG_DEPLOY
    fi
}
