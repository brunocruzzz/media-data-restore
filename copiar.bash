#!/usr/bin/bash

clear
#DEFINIÇÃO DOS PARÂMETROS#############################
############################################################################################################

local_montagem="/mnt/iso"
local_montagem="/mnt/dvd"
local_origem="/home/user/brunocruzz/DATADISK-1206.ISO"
local_origem=$(blkid | grep iso9660 | awk -F: '{print $1}')
diretorio="/home/user/brunocruzz/$(hostname)" #É Possivel colocarmos aqui o nome da maquina (hostname), para ser mais reconhecivel a origem dos dados para a storage.


log_file="log.txt"
echo $diretorio
###########################################################################################################
#VARIÁVEIS DE CONTROLE
############################################################################################################
############################################################################################################

#PREPARAÇÃO DO AMBIENTE

sudo mkdir -p $local_montagem
mkdir -p $diretorio
sudo mount $local_origem $local_montagem

# Obter o rótulo da imagem
label=$(blkid -s LABEL -o value "$local_origem")

echo "O rótulo da imagem é: $label"

cd $diretorio
############################################################################################################

#PROCESSO DE COPIA DOS DADOS
copy_start_time=$(date +%s)
num_files=$(ls -1 "$local_montagem/product_raw/"*.RAW* | wc -l)
echo "Copiando dados do DVD...$num_files encontrados"
# Count the number of files in the ISO
cp $local_montagem/product_raw/* .
copy_end_time=$(date +%s)
copy_execution_time=$((copy_end_time - copy_start_time))
echo "Dados copiados com sucesso de $local_origem($copy_execution_time s)"
############################################################################################################
sleep 3

#CATALOGANDO DADOS RESTAURADOS
move_start_time=$(date +%s)
echo -n "Catalogando os dados copiados..."
# Lista todos os arquivos que correspondem ao padrão *.RAW* e os lê linha a linha.
ls *.RAW* -1 | while read fn; do
    dir=20${fn:3:6} # Extrai a data do nome do arquivo e armazena na variável 'dir'
    radar=${fn:0:3} # Extrai o identificador do radar do nome do arquivo e armazena na variável 'radar'
    cidade=""
    prod=""
    # Verifica se o arquivo não está vazio
    if [[ -s $fn ]]; then
        var=$(/usr/local/bin/productx "$fn" <<EOF 2>/dev/null | awk '/What parameter do you wish to display?/ {exit} {print}'

EOF
)
        ############################################################################################################
        #Agora podemos manusear os dados de uma maneira mais prática
        #Usar um -verbose para exibir os cabeçalhos[opcional]
        #echo "$var" # aspas garantem o formato adequado para output[quebra de linhas]
        ############################################################################################################
        # Verifica o produto
        case "$var" in
        *SURVEI*)
            prod="sur"
            ;;
        *VOL_SCAN* | *VSCAN* | *PPI_VOL* | *CLUTTER*)
            prod="vol"
            ;;
        *CLEAR* | *AIR*)
            prod=cle
            ;;
        *QUEIMA* | *FIRE*)
            prod="que"
            ;;
        *RHI* | *FRENTE* | *SECT* | *VVP*)
            prod="dif"
            ;;
        *)
            prod="indefinido"
            echo "Problemas ao encontrar o rótulo de identificação do dado. $fn"
            echo "$fn: Problemas ao encontrar o rótulo de identificação do dado." >> $log_file
            ;;
        esac
        # Verifica o radar de origem
        case "$var" in
        *[Bb]auru*)
            cidade="bru"
            ;;
        *[Pp]aulo* | *[Pp]rudente*)
            cidade="ppr"
            ;;
        *)
            cidade="indefinido"
            echo " Problemas ao encontrar a identificação do Radar. $fn"
            echo "$fn: Problemas ao encontrar o rótulo de identificação do dado." >> $log_file
            #mv "$fn" "../indefinido"
            ;;
        esac        
        #echo "MOVENDO PARA $prod$cidade/$dir/$fn" # DEBUG CONTROL

        #Move o arquivo para o respectivo diretório para armazenamento
        mkdir -p $prod$cidade/$dir && mv $fn $_
    else
        echo "Arquivo vazio: $fn"
        ((count++))
        rm -f $fn
    fi
done
echo -n "OK"
move_end_time=$(date +%s)
move_execution_time=$((move_end_time - move_start_time))

echo "($move_execution_time s)"
total_dados=$(find "$diretorio" -type f | wc -l)
echo "Dados catalogados com sucesso! $total_dados arquivos restaurados."

sudo umount $local_montagem

echo " "
echo "Transferencia finalizada, favor inserir outro DVD."
echo " "
cd ~
exit