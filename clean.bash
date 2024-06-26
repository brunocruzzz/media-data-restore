CONFIG_FILE="config.cfg"
source "$CONFIG_FILE"

# Verificar se pelo menos um argumento foi passado
if [ $# -eq 0 ]; then
    echo "Uso: $0 <clean|prepare> [working_directory]:$WORKING_DIRECTORY"
    exit 1
fi

# Configurar o diretório de trabalho
if [ -n "$2" ]; then
    $WORKING_DIRECTORY="$2:-$WORKING_DIRECTORY"
fi
# Executar a função apropriada com base no argumento
case "$1" in
clean)
    echo "ATENÇÃO. TODOS OS DADOS DENTRO DA PASTA $WORKING_DIRECTORY SERÂO PERDIDOS PERMANENTEMENTE!!!"
    echo "CONFIRMA EXCLUSÃO DOS DADOS?(S/N)"
    read -r confirmation1
    if [[ $confirmation1 == "S" || $confirmation1 == "s" ]]; then
        echo "TEM CERTEZA? ISSO NÃO PODE SER DESFEITO! (S/N)"
        read -r confirmation2
        if [[ $confirmation2 == "S" || $confirmation2 == "s" ]]; then
            echo "Limpando o diretório de trabalho: $WORKING_DIRECTORY"
            rm -rf $WORKING_DIRECTORY
            echo "Diretório de trabalho limpo."
        else
            echo "Ação cancelada."
        fi
    else
        echo "Ação cancelada."
    fi
    ;;
log)
    echo "CONFIRMA EXCLUSÃO DOS DADOS?(S/N)"
    read -r confirmation1
    if [[ $confirmation1 == "S" || $confirmation1 == "s" ]]; then
        rm $LOG_FILE $READ_DVDS_FILE $LOG_DEPLOY
        touch $LOG_FILE $READ_DVDS_FILE $LOG_DEPLOY
        echo "Os logs foram apagados..."
    else
        echo "Ação cancelada."
    fi
    ;;
*)
    echo "Argumento inválido: $1"
    echo "Uso: $0 <clean|log> [working_directory]:$WORKING_DIRECTORY"
    exit 1
    ;;
esac
