#!/bin/bash

# Diretório onde os arquivos estão armazenados
DIRECTORY="./"

# Arquivo de saída
OUTPUT_FILE="dates.txt"

# Padrão de regex para extrair datas no formato YYYY-MM-DD
DATE_PATTERN="[0-9]{4}-[0-9]{2}-[0-9]{2}"

# Encontra as datas nos nomes dos arquivos, remove duplicatas, e ordena
find "$DIRECTORY" -type f -printf "%f\n" | grep -oE "$DATE_PATTERN" | sort | uniq > "$OUTPUT_FILE"


#
#find ./ -type f -printf "%f\n" | grep -oE "[A-Z]{3}[0-9]{2}[0-9]{2}[0-9]{2}" | grep -oE "[0-9]{2}[0-9]{2}[0-9]{2}" | sort | uniq > /home/user/media-data-restore/datas.txt