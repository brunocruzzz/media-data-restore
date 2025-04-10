#!/usr/bin/bash

# Script de Preparação para Restauração de Dados de DVDs
# Autor(es):
# Bruno da Cruz Bueno
# Jaqueline Murakami Kokitsu
# Simone Cincotto Carvalho
# Data: 23/05/2024

CONFIG_FILE="config.cfg"
source functions.sh
load_config
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
if [ $? -eq 0 ]; then 
    data_deploy $RUN
else
    echo "Erro na montagem. Dados não enviados..."
    createlog "Erro na montagem. Dados $TAG não enviados..." "$LOG_DEPLOY"
fi
echo ""
# Ensure the script ends cleanly
exit 