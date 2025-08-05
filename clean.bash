CONFIG_FILE="config.cfg"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Erro: Arquivo de configuração '$CONFIG_FILE' não encontrado."
    exit 1
fi
source "$CONFIG_FILE"

# Verificar se pelo menos um argumento foi passado
if [ $# -eq 0 ]; then
    echo "Uso: $0 clean [working_directory]"
    echo "  Exemplo: $0 clean /caminho/para/diretorio"
    echo "  Diretório padrão do config.cfg: $WORKING_DIRECTORY"
    exit 1
fi

# Configurar o diretório de trabalho
if [ -n "$2" ]; then
    $WORKING_DIRECTORY="${2:-$WORKING_DIRECTORY}"
fi
# Executar a função apropriada com base no argumento
case "$1" in
clean)
    if [[ -z "$WORKING_DIRECTORY" || "$WORKING_DIRECTORY" == "/" || "$WORKING_DIRECTORY" == "." ]]; then
        echo "Erro: Diretório de trabalho inválido ou perigoso: '$WORKING_DIRECTORY'"
        exit 1
    fi
    echo "⚠️ ATENÇÃO. TODOS OS DADOS DENTRO DA PASTA $WORKING_DIRECTORY SERÂO PERDIDOS PERMANENTEMENTE!!!"    
    read -r -p "CONFIRMA EXCLUSÃO DOS DADOS? (S/N): " confirmation1
    if [[ $confirmation1 == "S" || $confirmation1 == "s" ]]; then        
        read -r -p "TEM CERTEZA? ISSO NÃO PODE SER DESFEITO! (S/N)" confirmation2
        if [[ $confirmation2 == "S" || $confirmation2 == "s" ]]; then
            echo "Limpando o diretório de trabalho: $WORKING_DIRECTORY"
            rm -rf "$WORKING_DIRECTORY"
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
error)
    echo "CONFIRMA EXCLUSÃO DOS DADOS COM ERRO?(S/N)"    
    read -r confirmation1
    if [[ $confirmation1 == "S" || $confirmation1 == "s" ]]; then
        rm -rf $WORKING_DIRECTORY/local/ERR*
        echo "Os diretórios foram apagados..."
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
