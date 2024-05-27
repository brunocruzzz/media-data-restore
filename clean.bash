# Verificar se pelo menos um argumento foi passado
if [ $# -eq 0 ]; then
    echo "Uso: $0 <clean|prepare> [working_directory]"
    exit 1
fi

# Configurar o diretório de trabalho
if [ -n "$2" ]; then
    working_directory="$2"
else
    working_directory=$(pwd)
fi

# Executar a função apropriada com base no argumento
case "$1" in
clean)
    echo "ATENÇÃO. TODOS OS DADOS DENTRO DA PASTA DE TRABALHO SERÂO PERDIDOS PERMANENTEMENTE!!!"
    echo "CONFIRMA EXCLUSÃO DOS DADOS?(S/N)"
    read -r confirmation1
    if [[ $confirmation1 == "S" || $confirmation1 == "s" ]]; then
        echo "TEM CERTEZA? ISSO NÃO PODE SER DESFEITO! (S/N)"
        read -r confirmation2
        if [[ $confirmation2 == "S" || $confirmation2 == "s" ]]; then
            echo "Limpando o diretório de trabalho: $working_directory"
            rm -rf /home/user/brunocruzz/maqbruno
            touch /home/user/brunocruzz/CLEANED
            echo "Diretório de trabalho limpo."
        else
            echo "Ação cancelada."
        fi
    else
        echo "Ação cancelada."
    fi
    ;;
prepare)
    prepare
    ;;
*)
    echo "Argumento inválido: $1"
    echo "Uso: $0 <clean|prepare> [working_directory]"
    exit 1
    ;;
esac
