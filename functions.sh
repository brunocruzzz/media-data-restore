#!/bin/bash
###############################################################################
# Script: funções_utilitárias.sh
# Descrição: Funções auxiliares para copiar.bash no processo de restauração.
#
# Uso: Importado por outros scripts. Não deve ser executado diretamente.
# Dependências: rsync, sudo, sistema de arquivos NFS montável.
#
# Exemplo de uso (em copiar.bash):
#   source ./functions.sh
#
# Segurança: Certifique-se de que o usuário tenha permissões adequadas.
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
        echo_color -e "$RED" "\n****Arquivo de configuração $CONFIG_FILE não encontrado. Por favor, execute ./setup_client.bash para criá-lo.\n"
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
    echo_color -e "$BLUE" "$(cat <<'EOF'
 ___       _          __  __        _ _        ___        _               
|   \ __ _| |_ __ _  |  \/  |___ __| (_)__ _  | _ \___ __| |_ ___ _ _ ___ 
| |) / _` |  _/ _` | | |\/| / -_) _` | / _` | |   / -_|_-<  _/ _ \ '_/ -_)
|___/\__,_|\__\__,_| |_|  |_\___\__,_|_\__,_| |_|_\___/__/\__\___/_| \___|
--------------------------------------------------------------------------
                Sistema de restauração de dados de mídia!          
--------------------------------------------------------------------------
EOF
)"   
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

    sudo mkdir -p "$disk"
    #Calcula espaço disponível no disco
    local free_space=$(df --block-size=1 "$disk" | awk 'NR==2 {print $4}')
    local readable_free_space=$(df -h "$disk" | awk 'NR==2 {print $4}')
	
    #echo "tamanho em $disk"	
    echo "Espaço disponível: $readable_free_space | Necessário: $readable_required_space"


    if ((free_space < required_space)); then
        createlog "[ERROR] Espaço em disco insuficiente: $readable_free_space disponível. São necessários $readable_required_space." "$LOG_FILE"
        echo_color -e "$RED" "Espaço em disco insuficiente ($readable_free_space). São necessários $readable_required_space.\n Verifique se existem dados a serem catalogados e enviados e então, execute uma limpeza usando o comando:"
        echo_color -e "$YELLOW" "./clean.bash clean"
        exit 1
    else
        createlog "[INFO] Espaço em disco local suficiente: $readable_free_space disponível." "$LOG_FILE"        
    fi
}

monta_device() {

    createlog "[INFO] Montando o dispositivo $DEVICE em $MOUNT_POINT com o sistema de arquivos $FS_TYPE..." "$LOG_FILE"

    # Desmonta o ponto de montagem se já estiver montado
    if mountpoint -q "$MOUNT_POINT"; then
        sudo umount "$MOUNT_POINT"
    fi	
    # Cria o ponto de montagem, se não existir
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
        # Dispositivo não está montado. Montando...
        
        opts=""
		if is_wsl; then
			opts=(-t drvfs)
		fi  
        
        # Monta o dispositivo no ponto de montagem
        cmd="sudo mount ${opts[*]} \"$DEVICE\" \"$MOUNT_POINT\""
        createlog "[DEBUG] Executando: $cmd" "$LOG_FILE"

        if sudo mount "${opts[@]}" "$DEVICE" "$MOUNT_POINT" >/dev/null 2>&1; then
            echo "Dispositivo $DEVICE montado com sucesso em $MOUNT_POINT."
        else
            # Loga e exibe erro em caso de falha no processo de montagem
            createlog "[ERROR] Falha ao montar o dispositivo $DEVICE em $MOUNT_POINT." "$LOG_FILE"
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
        createlog "[ERROR] Falha ao montar o dispositivo $iso em $MOUNT_POINT." "$LOG_FILE"
        echo_color -e "$RED" "Verifique se o DVD foi inserido corretamente..."        
        exit 1
    fi
}

# Obtém o UUID do DVD
get_dvd_uuid() {
    local device="$DEVICE"
    if is_wsl; then
        powershell.exe -Command "(Get-Item -Path "$device"\).CreationTime.ToString('yyyy-MM-dd_HH-mm-ss-ff')" | tr -d '\r'
    else        
        blkid "$device" | grep -oP 'UUID="\K[^"]+'
    fi
}

# Obtém o rótulo (label) do DVD
get_dvd_label() {
    if is_wsl; then
        powershell.exe "(Get-Volume -DriveLetter D).FileSystemLabel"
    else
        local device="$DEVICE"
        blkid -s LABEL -o value "$device"
    fi
}


#Objetivo geral:
#Evitar processar DVDs duplicados e permitir ao usuário decidir como proceder quando um DVD já conhecido for detectado.
check_dvd() {    
    local device="$DEVICE"

    DVD_UUID=$(get_dvd_uuid "$device")
    DVD_LABEL=$(get_dvd_label "$device")
    
    echo -e "\nO rótulo da mídia/imagem é: $DVD_LABEL"
    
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

        echo_color -e "$YELLOW" "ATENÇÃO!!! DVD $DVD com UUID $DVD_UUID já foi registrado como lido/restaurado anteriormente neste cliente. Pressione q para sair ou aguarde para realizar a operação de cópia novamente..."
        echo_color -e "$YELLOW" "Pressione 'q' para sair do programa..."
        #echo_color -e "$YELLOW" "Pressione 'F' para enviar novamente[Force]..."
        echo_color -e "$YELLOW" "Pressione 'B' para realizar backup (ISO + cópia no DVD novo)..."
        #echo_color -e "$YELLOW" "Pressione 'L' para limpar registros deste DVD nesta máquina..."

        # Verificar se o usuário pressionou Enter para encerrar o programa
        read -r -s -n 1 -t 5 input
        case "$input" in
            q|Q) echo -e "\nPrograma encerrado pelo usuário."; exit 0 ;;
            # 'B' e 'L' serão tratados depois, se necessário
        esac
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
    #no inicio da rodada, se há um diretório deste dvd(uuid) com erro marcado, ele é apagado
    # No início da rodada, remove o diretório de erro anterior associado a este DVD (UUID), se existir
    if [ -n "$err_local" ] && [ -d "$err_local" ]; then
        echo "Removendo diretório com erro anterior: $err_local"
        rm -rf -- "$err_local"
    fi


    copy_start_time=$(date +%s)


    # Conta arquivos .RAW no DVD
    find "$MOUNT_POINT/product_raw/" -type f -iname '*.RAW*' | sort > /tmp/total_dvd.txt
    total_files=$(wc -l < /tmp/total_dvd.txt)    

    echo "Copiando dados do DVD($total_files encontrados)..."
    #cp $MOUNT_POINT/product_raw/* .    
    createlog "[DEBUG] Executando: rsync -rh --info=progress2 --ignore-existing \"$MOUNT_POINT/product_raw/\" \"$local\"" "$LOG_FILE"

    # Executa cópia com rsync, captura erro (se houver)
    if rsync -rh --info=progress2 --ignore-existing "$MOUNT_POINT/product_raw/" "$local" 2> /tmp/rsync_error.log; then
        copy_end_time=$(date +%s)
        copy_execution_time=$((copy_end_time - copy_start_time))

        createlog "[INFO] Cópia local do DVD realizada com sucesso de $DEVICE após $copy_execution_time s" "$LOG_FILE"
        echo "DVD com UUID $DVD_UUID adicionado à lista de DVDs lidos."
        echo "DVD:$dvd_number|UUID:$DVD_UUID|" >>"$READ_DVDS_FILE"
    else
        copy_end_time=$(date +%s)
        copy_execution_time=$((copy_end_time - copy_start_time))
        rsync_error=$(< /tmp/rsync_error.log)

        # Conta quantos arquivos chegaram a ser copiados
        total_copiados=$(find "$local" -type f 2>/dev/null | wc -l)

        createlog "[ERROR] Cópia mal-executada após $copy_execution_time s. $total_copiados de $total_files foram copiados do DVD para o disco." "$LOG_FILE"
        createlog "[ERROR] rsync falhou com a seguinte mensagem:"
        createlog "[DEBUG] $rsync_error"
        
        # Move diretório para área de erro
        mv "$local" "$err_local" #Move a tentativa de leitura do DVD para a pasta ERR_DVD_UUID
        echo "Diretório renomeado para $err_local devido a falha/erro durante a cópia." 

        echo_color -e "$RED" "Talvez a mídia ou o leitor estejam com problemas. Verifique se o erro persiste. Contate o TI."
        
        exit 1
    fi
}
catalog() {
    local local=$1
    move_start_time=$(date +%s)
    echo -e "\n\nCatalogando os dados copiados localmente em $local. Aguarde..."    
    count=0
    arquivos_vazios=0
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
            #busca o cabeçalho no arquivo usando productx
            var=$(
                /usr/local/bin/productx "$fn" <<EOF 2>/dev/null | awk '/What parameter do you wish to display?/ {exit} {print}'

EOF
            )
            ############################################################################################################
            #Agora podemos manusear os dados de uma maneira mais prática
            #Usar um -verbose para exibir os cabeçalhos[opcional]
            #echo "$var" # aspas garantem o formato adequado para output[quebra de linhas]
            if [[ -z "$var" ]]; then
                createlog "[ERROR] Não foi possível ler cabeçalho de dados do arquivo $fn." "$LOG_FILE"
                createlog "[ERROR] $dvd_number | Arquivo '$fn' não tem cabeçalho válido." "$LOG_DVD_FILES"
                ((count++))
                rm -f "$fn"
                continue
            fi
            gen_time=$(echo "$var" | grep "Ingest time:")
            echo "Ingest time: $gen_time"
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
            # Verifica o produto e cataloga de acordo com o produto e a cidade associada.
            #Por exemplo: 
            #surveillances de Bauru são armazenados em surbru
            #volumescan de Prudente são armazenados em volppr
            
            #logo a estrutura fica como por exemplo, volppr/YYYMMDD/
            folder=$(process_var "$var" "$dir" "$fn" "$LOG_FILE")
            #Na pasta definida o arquivo RAW é movido.

            #echo "MOVENDO PARA $folder/$dir/$fn" # DEBUG CONTROL
            #echo "movendo para $WORKING_DIRECTORY/local/$DVD_UUID/$folder/$fn"

            #Move o arquivo para o respectivo diretório para armazenamento
            #mkdir -p $WORKING_DIRECTORY/$folder && mv $fn $_
            mkdir -p "$WORKING_DIRECTORY/local/$DVD_UUID/$folder" && mv -f "$fn" "$_"
            if [[ $? -ne 0 ]]; then                            
                createlog "[ERROR] $dvd_number | Erro: Falha ao mover '$fn' para '$WORKING_DIRECTORY/local/$DVD_UUID/$folder/'" "$LOG_FILE"
            fi
        else
            #echo "Arquivo vazio: $fn"
            ((arquivos_vazios++))
            rm -f $fn
        fi
    done
        
    TAG="$min_date <--> $max_date"
    FTAG="$min_date"_"$max_date"
    createlog "[INFO] Este DVD ($dvd_number) compreende o período $FTAG" "$LOG_FILE"

    move_end_time=$(date +%s)
    move_execution_time=$((move_end_time - move_start_time))
    createlog "[INFO] Tempo de catalogação ($move_execution_time s)" "$LOG_FILE"
    echo "Tempo de catalogação ($move_execution_time s)"

    #Busca o numero total de arquivos copiados(catalogados)
    total_catalogados=$(find "$local" -type f | wc -l)
    find "$local" -type f -name "*.RAW*" | sort > /tmp/total_local.txt

    createlog "[INFO] Total de arquivos no DVD: $total_files" "$LOG_FILE"
    createlog "[INFO] Total de arquivos catalogados: $total_catalogados. $arquivos_vazios arquivos vazios(descarte)." "$LOG_FILE"
    #Busca o número de arquivos classificados como indefinidos
    if [ -d "$local/indefinido" ]; then
        indefinidos=$(find "$local/indefinido" -type f | wc -l)
        echo_color -e "$RED" "Total de arquivos indefinidos neste DVD: ($indefinidos). Contate o suporte de TI e informe o identificador $dvd_number do DVD."
        createlog "[WARNING] DVD $dvd_number teve falhas para catalogar um ou mais arquivos. Todos foram enviados para pasta indefinido e serão transmitidos." "$LOG_FILE"
    else
        echo_color -e "$BLUE" "Todos os arquivos foram classificados com sucesso."
    fi    
    # Verifica se o número de arquivos copiados é menor que o número total de arquivos no DVD
    total_copiados=$((total_catalogados + $arquivos_vazios))

    if [[ $total_files -gt $total_copiados ]]; then
        num_error_files=$((total_files - total_copiados))
        # Verifica diferenças: arquivos que estão no DVD mas não foram copiados
        createlog "[DEBUG] Executando comando: 'comm -23   <(sort /tmp/total_dvd.txt | xargs -n1 basename | sort)   <(sort /tmp/total_local.txt | xargs -n1 basename | sort)'" "$LOG_FILE"
        missing_files=$(comm -23   <(sort /tmp/total_dvd.txt | xargs -n1 basename | sort)   <(sort /tmp/total_local.txt | xargs -n1 basename | sort))
        if [[ -n "$missing_files" ]]; then
            echo "❌ Arquivos faltando na cópia:"
            echo "$missing_files"
            # Para cada linha (arquivo) em missing_files
            while IFS= read -r missing_file; do
                createlog "[ERROR] $TAG | Arquivo faltando na cópia: $missing_file" "$LOG_DVD_FILES"
                createlog "[ERROR] Cabeçalho do arquivo: $var" "$LOG_DVD_FILES"
            done <<< "$missing_files"
        else
            echo "✅ Todos os arquivos do DVD foram copiados com sucesso."
        fi
        echo "Operação realizada com erro. Alguns arquivos não foram restaurados. $num_error_files arquivos faltantes/com problema."
        createlog "[ERROR] $TAG | Operação realizada com erro. Alguns arquivos não foram restaurados. $num_error_files arquivos faltantes/com problema. Confira o arquivo de log $LOG_DVD_FILES" "$LOG_FILE"
        catalog="$WORKING_DIRECTORY/catalog"
        mkdir -p $catalog
        echo "Movendo de $local para $catalog"
        mv "$local" "$catalog/$FTAG"        
        if [ -n "$err_local" ] && [ -d "$err_local" ]; then
            echo "Removendo diretório com erro anterior: $err_local"
            rm -rf -- "$err_local"
        fi
        echo "Enviando DVD $dvd_number para a storage..."
        ./sending_data.bash "$catalog/$FTAG" "$FTAG" "$dvd_number" > /dev/null && echo "" && echo_color -e "$YELLOW" "Upload DVD $dvd_number completo(com RESTRIÇÕES, confira $LOG_DVD_FILES. Execute a restauração da mídia backup.)" && echo "" &
    else
        createlog "[INFO] $TAG | Dados catalogados com sucesso! $timestamp: $total_copiados arquivos restaurados. $count arquivos com erro de leitura. $arquivos_vazios arquivos vazios." "$LOG_FILE"
        catalog="$WORKING_DIRECTORY/catalog"
        mkdir -p $catalog
        echo "Movendo de $local para $catalog"
        mv "$local" "$catalog/$FTAG"
        #tree -d "$catalog/$FTAG"
        if [ -n "$err_local" ] && [ -d "$err_local" ]; then
            echo "Removendo diretório com erro anterior: $err_local"
            rm -rf -- "$err_local"
        fi
        echo "Enviando DVD $dvd_number para a storage..."
        ./sending_data.bash "$catalog/$FTAG" "$FTAG" "$dvd_number" > /dev/null && echo "" && echo_color -e "$GREEN" "Upload DVD $dvd_number completo" && echo "" &
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
    #echo "Gerando logs...(teste)"
    echo ""
}

process_var() {
    local var="$1"
    local dir="$2"
    local fn="$3"
    local LOG_FILE="$4"
    
    local prod cidade folder


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
        createlog "[WARNING] $fn: Problemas ao encontrar o rótulo de identificação do dado." "$LOG_FILE"
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
        createlog "[WARNING] $fn: Problemas ao encontrar o rótulo de origem do dado." "$LOG_FILE"
        #mv "$fn" "../indefinido"
        ;;
    esac

    # Determine the folder
    if [[ "$cidade" == "indefinido" || "$prod" == "indefinido" ]]; then
        folder="indefinido"
        echo "Classificação indefinida para o arquivo $fn. Verifique o cabeçalho do dado." >&2
        #echo somente no terminal
        echo "$var" >&2
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
        createlog "[ERROR] Problemas na conexão NFS com storage: "$STORAGE_IP":"$STORAGE_PATH" "$STORAGE_MOUNT_POINT"" "$LOG_DEPLOY"
        exit 1
    fi
    sleep 1
}

data_deploy() {
    local from=$1
    local dvd_number=$2    
    MACHINE_FOLDER="$STORAGE_MOUNT_POINT/$MACHINE_NAME"
    echo "Verificando o diretório $MACHINE_FOLDER em $STORAGE_MOUNT_POINT na storage para receber dados da máquina local $MACHINE_NAME..."
    echo "Destino NFS: $STORAGE_IP:$STORAGE_PATH"
    sudo mkdir -p "$MACHINE_FOLDER"
    #sleep 3
    #echo "||$from --------------------------------> $MACHINE_FOLDER||"
    createlog "[INFO] Iniciando a transferência de dados de '$from' para '$MACHINE_FOLDER'." "$LOG_DEPLOY"
    createlog "[INFO] Diretório de destino: $MACHINE_FOLDER" "$LOG_DEPLOY"
    #echo "rsync -rh --info=progress2 $from $MACHINE_FOLDER"
    sleep 3
    createlog "[DEBUG] Executando: rsync -rh --info=progress2 \"$from\" \"$MACHINE_FOLDER\"" "$LOG_FILE"
    rsync -rh --info=progress2 "$from" "$MACHINE_FOLDER"
    if [ $? -eq 0 ]; then        
        createlog "[INFO] Transferência de dados concluída com sucesso para '$MACHINE_FOLDER'." "$LOG_DEPLOY"
        createlog "[INFO] |$dvd_number|$TAG|-----> Upload de dados(Rodada $RUN) realizado com sucesso." "$LOG_DEPLOY"
        #Esta flag é usada para indicar que o upload foi bem-sucedido, e no servidor,será verificado se o diretório contém esta flag para poder mover para a remessa(diretório) para o repositório final.
        FLAG_OK=$MACHINE_FOLDER/$(basename $from)/DIR_OK
        echo "$dvd_number" > "$FLAG_OK"
        echo_color -e "$GREEN" "Dados do DVD $dvd_number enviados com sucesso para o servidor NFS."
    else
        createlog "[ERROR] Falha na transferência de dados para '$MACHINE_FOLDER'. Verifique os logs para mais detalhes." "$LOG_DEPLOY"
        echo_color -en "$RED" "Contate o suporte de TI para permissão de upload para o servidor."
    fi
}
createlog() {
    local message="$1"
    local logfile="$2"
    echo $message >&2
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
        createlog "[DEBUG] Programa encerrado pelo usuário." "$LOG_FILE"
        createlog "-----------------------------------------------------------------------" "$LOG_FILE"
        exit 0
    fi
}

# Função para limpar recursos ao encerrar o script
cleanup() {
    echo "Encerrando script..."
    createlog "[DEBUG] Script encerrado pelo usuário ou por um erro." "$LOG_FILE"
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