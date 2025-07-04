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
# Arquivo de funções do script copiar.bash
#
# Data de Criação: 23/05/2024
# Última Atualização: 04/07/2024
#
###############################################################################

# DEFINIÇÃO DAS FUNÇÕES
CONFIG_FILE="config.cfg"

# Função para carregar o arquivo de configuração
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # Carregar o arquivo de configuração
        source "$CONFIG_FILE"
        echo "Arquivo de configuração carregado com sucesso."
        sleep 2
    else
        # Imprimir uma mensagem de erro e encerra o programa
        echo_color -e "$RED" "\n****Arquivo de configuração $CONFIG_FILE não encontrado. Por favor, execute ./prepare_server.bash para criá-lo.\n"
        exit 1
    fi
}

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
            monta_iso $2
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
is_wsl(){
     uname -r | grep -qi "microsoft"
}
# Função para exibir o cabeçalho
exibir_cabecalho() {
    clear
    echo "--------------------------------------------------------"
    echo_color -e "$BLUE" "      Sistema de restauração de dados de mídia!         "
    echo "--------------------------------------------------------"
}

check_disk_space() {
    local data_mount_point="$1"

	if is_wsl; then
		data_mount_point=$(echo "$data_mount_point" | sed -E 's|^([A-Za-z]):$|/mnt/\L\1|')
	fi

    local required_space=$(df --block-size=1 "$data_mount_point" | awk 'NR==2 {print $3}')
    local readable_required_space=$(df -h "$data_mount_point" | awk 'NR==2 {print $3}')
    sleep 2 # Verificar se isso é realmente necessário
	
	if is_wsl; then
		local windows_home_winpath=$(powershell.exe -NoProfile -Command '[Environment]::GetEnvironmentVariable("USERPROFILE")' | tr -d '\r')
		local disk="/mnt/$(echo "$windows_home_winpath" | sed -E 's|^([A-Za-z]):|\L\1|;s|\\|/|g')"
	else
		local disk="$WORKING_DIRECTORY"	
	fi
    local free_space=$(df --block-size=1 "$disk" | awk 'NR==2 {print $4}')
    local readable_free_space=$(df -h "$disk" | awk 'NR==2 {print $4}')
	echo "tamanho em $disk"
	echo "Espaço em $disk: $free_space"
	echo "Espaço a ser utilizado em $disk: $readable_required_space em $readable_free_space"

    if ((free_space < required_space)); then
        echo_color -e "$RED" "Espaço em disco insuficiente ($readable_free_space). São necessários $readable_required_space.\n Verifique se existem dados a serem catalogados e enviados e então, execute uma limpeza usando o comando:"
        echo_color -e "$YELLOW" "./clean.bash clean"
        exit 1
    else
        echo "Espaço em disco local suficiente: $readable_free_space disponível."
    fi
}

monta_device() {
    echo "Montando o dispositivo $DEVICE em $MOUNT_POINT com o sistema de arquivos $FS_TYPE..."
    if mountpoint -q "$MOUNT_POINT"; then
        sudo umount "$MOUNT_POINT"
    fi	
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
        opts=""
		echo "Dispositivo não está montado. Montando..."
		if is_wsl; then
			opts=(-t drvfs)
		fi
        # Tenta montar o dispositivo no ponto de montagem especificado	
        echo "sudo mount "${opts[@]}" "$DEVICE" "$MOUNT_POINT""
        if sudo mount "${opts[@]}" "$DEVICE" "$MOUNT_POINT" >/dev/null 2>&1; then
            echo "Dispositivo $DEVICE montado com sucesso em $MOUNT_POINT."
        else
            createlog "Falha ao montar o dispositivo $DEVICE em $MOUNT_POINT." "$LOG_FILE"
            echo_color -e "$RED" "Verifique se o DVD foi inserido corretamente..."
            ejetar_midia "$MOUNT_POINT" "$DEVICE" 
            exit 1
        fi
    fi	
}
monta_iso() {
    local iso=$1
    if mountpoint -q "$MOUNT_POINT"; then
        sudo umount "$MOUNT_POINT"
    fi
    # Verificar se o ponto de montagem existe, caso contrário, criar
    if [ ! -d "$MOUNT_POINT" ]; then
        echo "Criando ponto de montagem..."
        sudo mkdir -p "$MOUNT_POINT"
    fi
    if sudo mount "$iso" "$MOUNT_POINT" >/dev/null 2>&1; then
        echo "Dispositivo $DEVICE montado com sucesso em $MOUNT_POINT."
    else
        createlog "Falha ao montar o dispositivo $iso em $MOUNT_POINT." "$LOG_FILE"
        echo_color -e "$RED" "Verifique se o DVD foi inserido corretamente..."        
        exit 1
    fi
}
# Function to get the UUID of the DVD
get_dvd_uuid() {
    if is_wsl; then
        powershell.exe -Command "(Get-Item -Path D:\).CreationTime.ToString('yyyy-MM-dd_HH-mm-ss-ff')" | tr -d '\r'
    else
        local device="$DEVICE"
        blkid "$device" | grep -oP 'UUID="\K[^"]+'
    fi
}
# Function to get the label of the DVD
get_dvd_label() {
    if is_wsl; then
        powershell.exe "(Get-Volume -DriveLetter D).FileSystemLabel"
    else
        local device="$DEVICE"
        blkid -s LABEL -o value "$device"
    fi
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
        DVD=$(grep "$DVD_UUID" "$READ_DVDS_FILE" | tail -n 1 | awk -F'|' '{print $1}' | cut -d':' -f2)
        echo_color -e "$YELLOW" "ATENÇÃO!!! DVD $DVD com UUID $DVD_UUID já foi registrado como lido/restaurado anteriormente. Pressione q para sair ou aguarde para realizar a operação de cópia novamente..."
        echo_color -e "$YELLOW" "Pressione 'q' para sair..."
        echo_color -e "$YELLOW" "Pressione 'B' para realizar backup (ISO + cópia no DVD novo)..."
        echo_color -e "$YELLOW" "Pressione 'L' para limpar registros deste DVD nesta máquina..."
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
	if is_wsl; then
		opts=(-t drvfs)
	else
		opts=(-o rw)
	fi
    sudo mount "${opts[@]}" $DEVICE $MOUNT_POINT >/dev/null 2>&1	
    mountpoint -q "$MOUNT_POINT"

    return $?
}

copy_from() {
    rm -rf $err_local # Se há um diretório deste dvd com erro marcado, ele é apagado
    copy_start_time=$(date +%s)
    total_files=$(ls -1 "$MOUNT_POINT/product_raw/"*.RAW* 2>/dev/null | wc -l) #Busca o numero de arquivos RAW no DVD
    echo "Copiando dados do DVD($total_files encontrados)..."
    #cp $MOUNT_POINT/product_raw/* .
    RSYNC_ERROR=$(rsync -rh --info=progress2 --ignore-existing $MOUNT_POINT/product_raw/ $local 2>/dev/null) #Faz a cópia local do DVD     
    if [ $? -eq 0 ]; then
        copy_end_time=$(date +%s)
        copy_execution_time=$((copy_end_time - copy_start_time))
        createlog "Cópia local do DVD realizada com sucesso de $DEVICE($copy_execution_time s)" "$LOG_FILE"
        echo "DVD com UUID $DVD_UUID adicionado a lista de DVD's lidos."
        echo "DVD:$dvd_number|UUID:$DVD_UUID|" >>"$READ_DVDS_FILE"
    else
        copy_end_time=$(date +%s)
        copy_execution_time=$((copy_end_time - copy_start_time))
        createlog "A cópia $local foi mal-executada após $copy_execution_time s)" "$LOG_FILE"
        echo "[ERRO] rsync falhou com a seguinte mensagem:"
        echo "$RSYNC_ERROR"
        mv "$local" "$err_local" #Move a tentativa de leitura do DVD para a pasta ERR_DVD_UUID
        echo "Diretório renomeado para $err_local devido a falha/erro durante a cópia. Contate o TI para verificação."
        exit 1
    fi
}
catalog() {
    local local=$1
    move_start_time=$(date +%s)
    echo -e "\n\nCatalogando os dados copiados localmente em $local. Aguarde..."    
    count=0
    min_date=""
    max_date=""
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
            dir=$(echo "$gen_time" | awk '{print $4 $5 $6}')
            dir=$(date -d "$dir 12" +%Y%m%d)
            ingest_date=$(echo "$gen_time" | awk '{print $4 "-" $5 "-" $6}')
            #echo "$dir ---> $fn"
            #echo $ingest_date
            converted_date=$(date -d "$ingest_date 12" +"%Y-%m-%d")
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
            #echo "movendo para $WORKING_DIRECTORY/local/$DVD_UUID/$folder/$fn"
            #Move o arquivo para o respectivo diretório para armazenamento
            #mkdir -p $WORKING_DIRECTORY/$folder && mv $fn $_
            mkdir -p "$WORKING_DIRECTORY/local/$DVD_UUID/$folder" && cp -f "$fn" "$_"
            if [[ $? -ne 0 ]]; then                            
                createlog "$dvd_number | Erro: Falha ao mover '$fn' para '$WORKING_DIRECTORY/local/$DVD_UUID/$folder/'" "$LOG_FILE"
            fi
        else
            #echo "Arquivo vazio: $fn"
            ((count++))
            rm -f $fn
        fi
    done
    #Tratar mensagem de OK
    #echo "OK"
    TAG="$min_date <--> $max_date"
    FTAG="$min_date"_"$max_date"
    createlog "Este DVD ($dvd_number) compreende o período $FTAG" "$LOG_FILE"
    move_end_time=$(date +%s)
    move_execution_time=$((move_end_time - move_start_time))

    echo "($move_execution_time s)"
    total_dados=$(find "$local" -type f | wc -l)
    if [ -d "$local/indefinido" ]; then
        indefinidos=$(find "$local/indefinido" -type f | wc -l)
        echo_color -e "$RED" "Total de arquivos indefinidos neste DVD: ($indefinidos). Contate o suporte de TI e informe o identificador do DVD."
    else
        echo_color -e "$BLUE" "Todos os arquivos foram classificados com sucesso."
    fi

    if [[ $total_files -gt $total_dados ]]; then
        num_error_files=$((total_files - total_dados))
        echo "Operação realizada com erro. Alguns arquivos não foram restaurados. $num_error_files arquivos faltantes/com problema."
        createlog "$TAG | Operação realizada com erro. Alguns arquivos não foram restaurados. $num_error_files arquivos faltantes/com problema." "$LOG_FILE"
    else
        createlog "$TAG | Dados catalogados com sucesso! $timestamp: $total_dados arquivos restaurados. $count arquivos vazios." "$LOG_FILE"
        catalog="$WORKING_DIRECTORY/catalog"
        mkdir -p $catalog
        echo "Movendo de $local para $catalog"
        mv "$local" "$catalog/$FTAG"
        #tree -d "$catalog/$FTAG"
        echo "Apagando diretórios marcados com erro..."
        rm -rf "$err_local"
        echo "Enviando DVD $dvd_number para a storage..."
        ./sending_data.bash "$catalog/$FTAG" "$FTAG" > /dev/null && echo_color -e "$GREEN" "Upload DVD $dvd_number completo" &
    fi
}
# Função para ejetar o dispositivo
ejetar_midia() {
    local mount_point="$1"
    local device="$2"    
        if is_wsl; then
            powershell.exe -Command '(New-Object -ComObject Shell.Application).NameSpace(17).ParseName("D:").InvokeVerb("Eject")'
        else
            sudo umount "$mount_point"
            if [ $? -eq 0 ]; then
                sudo eject "$device"
            else
                echo "Falha ao ejetar o dispositivo $device."
            fi                        
        fi
        if [ $? -eq 0 ]; then
            echo "Dispositivo $device ejetado com sucesso."
        else
            echo "Falha ao desmontar o dispositivo $device."
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

    # Determina o tipo de produto contido do dado bruto
    case "$var" in
    *SURVEI*)
        prod="sur" # Define produto como "SURVEILLANCE"
        ;;
    *VOL_SCAN* | *VSCAN* | *PPI_VOL* | *CLUTTER*)
        prod="vol" # Define produto como "VOLUME SCAN"
        ;;
    *CLEAR* | *AIR*)
        prod="cle" # Define produto como "CLEAR"
        ;;
    *QUEIMA* | *FIRE*)
        prod="que" # Define produto como "QUEIMADA"
        ;;
    *RHI* | *FRENTE* | *SECT* | *VVP*)
        prod="dif" # Define produto como "DIF"
        ;;
    *)
        prod="indefinido" # Define produto como "indefinido" --> Serão manipulados pelo técnico para encontrar o possível erro de classificação
        createlog "$fn: Problemas ao encontrar o rótulo de identificação do dado." "$LOG_FILE"
        ;;
    esac

    # Determine city of origin
    case "$var" in
    *[Bb]auru*)
        cidade="bru" # Classifica como dados provenientes de RADAR_BAURU
        ;;
    *[Pp]aulo* | *[Pp]rudente*)
        cidade="ppr" # Classifica como dados provenientes de RADAR_PRUDENTE
        ;;
    *)
        cidade="indefinido" # Classifica como dados provenientes de local indefinido --> Serão manipulados pelo técnico para encontrar o possível erro de classificação
        createlog "$fn: Problemas ao encontrar o rótulo de origem do dado." "$LOG_FILE"
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
    echo "Confira os logs para verificação do envio."
    #sudo umount "$STORAGE_MOUNT_POINT/$MACHINE_NAME"
    #PREPARAÇÃO DO AMBIENTE
    # Verificar se o ponto de montagem existe, caso contrário, criar
        if [ ! -d "$STORAGE_MOUNT_POINT" ]; then
            echo "Criando ponto de montagem $STORAGE_MOUNT_POINT --->$STORAGE_IP:$STORAGE_PATH"
            sudo mkdir -p "$STORAGE_MOUNT_POINT/$MACHINE_NAME"
            sudo mount -t nfs -o rw,sync,hard,intr "$STORAGE_IP":"$STORAGE_PATH" "$STORAGE_MOUNT_POINT/$MACHINE_NAME"
        else
            echo "$STORAGE_MOUNT_POINT já está criado..."
            #tree -d $STORAGE_MOUNT_POINT
        fi
    echo "Montando storage localmente..."
    #echo "sudo mount -t nfs -o rw,sync,hard,intr "$STORAGE_IP":"$STORAGE_PATH" "$STORAGE_MOUNT_POINT""
    sudo mount -t nfs -o rw,sync,hard,intr "$STORAGE_IP":"$STORAGE_PATH" "$STORAGE_MOUNT_POINT"
    if [ $? -eq 0 ]; then 
        echo "Storage conectada com sucesso..."
    else
        echo "Problemas na conexão NFS com storage. Verifique se o IP e o caminho estão corretos e se o cliente foi autorizado no servidor NFS."
        createlog "Problemas na conexão NFS com storage: "$STORAGE_IP":"$STORAGE_PATH" "$STORAGE_MOUNT_POINT"" "$LOG_DEPLOY"
        exit 1
    fi
    sleep 1
}

data_deploy() {
    local from=$1
    MACHINE_FOLDER="$STORAGE_MOUNT_POINT/$MACHINE_NAME"
    echo "Verificando o diretório $MACHINE_FOLDER em $STORAGE_MOUNT_POINT na storage para receber dados da máquina local $MACHINE_NAME..."
    echo "Destino NFS: $STORAGE_IP:$STORAGE_PATH"
    sudo mkdir -p "$MACHINE_FOLDER"
    #sleep 3
    #echo "||$from --------------------------------> $MACHINE_FOLDER||"
    createlog "Iniciando a transferência de dados de '$from' para '$MACHINE_FOLDER'." "$LOG_DEPLOY"
    createlog "Diretório de destino: $MACHINE_FOLDER" "$LOG_DEPLOY"
    #echo "rsync -rh --info=progress2 $from $MACHINE_FOLDER"
    sleep 3
    rsync -rh --info=progress2 $from $MACHINE_FOLDER
    if [ $? -eq 0 ]; then        
        createlog "Transferência de dados concluída com sucesso para '$MACHINE_FOLDER'." "$LOG_DEPLOY"
        createlog "$dvd_number|$TAG |-----> Upload de dados(Rodada $RUN) realizado com sucesso" "$LOG_DEPLOY"
        FLAG_OK=$MACHINE_FOLDER/$(basename $from)/DIR_OK
        touch $FLAG_OK        
    else
        createlog "Falha na transferência de dados para '$MACHINE_FOLDER'. Verifique os logs para mais detalhes." "$LOG_DEPLOY"
        echo_color -en "$RED" "Contate o suporte de TI para permissão de upload para o servidor."
    fi
}
createlog() {
    local message="$1"
    local logfile="$2"
    echo $message
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >>"$logfile"
}
#==========================================================================================
#COLOR PALLETE
#==========================================================================================
# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
RESET='\033[0m'

echo_color() {
    local params=$1
    local color_code=$2
    local output=$3
    # Check if color code is provided
    if [ -z "$color_code" ]; then
        color_code=$RESET
    fi

    echo $params "${color_code}$output${RESET}"
}

check_user_exit() {
    read -r -s -n 1 -t 1 input
    if [[ $input = "q" ]]; then
        sudo umount "$MOUNT_POINT"
        echo -e "\nPrograma encerrado pelo usuário."
        createlog "Programa encerrado pelo usuário." "$LOG_FILE"
        createlog "-----------------------------------------------------------------------" "$LOG_FILE"
        exit 0
    fi
}

# Função para limpar recursos ao encerrar o script
cleanup() {
    echo "Encerrando script..."
    createlog "Script encerrado pelo usuário ou por um erro." "$LOG_FILE"
    createlog "-----------------------------------------------------------------------" "$LOG_FILE"
    # Finaliza processos secundários (caso existam)
    #pkill -P $$

    # Desmonta a mídia se estiver montada
    #if dispositivo_montado; then
    #    echo "Desmontando $MOUNT_POINT..."
    #    sudo umount "$MOUNT_POINT"
    #fi
    
    echo "Fim da limpeza. Saindo..."
    exit 0
}

test_folder() {
    echo ""
}