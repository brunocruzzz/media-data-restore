CONFIG_FILE="config.cfg"
source "$CONFIG_FILE"
source functions.sh

# Verificar se pelo menos um argumento foi passado
if [ $# -eq 0 ]; then
    echo "Uso: $0 deve conter a rodada de restauração a ser realizada..."    
    #exit 1
fi

# Configurar o diretório de trabalho
if [ -n "$1" ]; then
    RUN=$1
    echo $1
fi

if [ -n "$2" ]; then
    TAG=$2
    echo $2
fi
sleep 3
monta_storage
data_deploy $RUN
sleep 2
echo ""
echo "$TAG |-----> Upload de dados(Rodada $RUN) realizado com sucesso" | tee -a $LOG_DEPLOY
echo ""
# Ensure the script ends cleanly
exit 