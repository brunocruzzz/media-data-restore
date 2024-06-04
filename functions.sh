#DEFINIÇÃO DS FUNÇÕES

# Função para exibir o cabeçalho
exibir_cabecalho() {
    clear
    echo "--------------------------------------------------------"
    echo "      Sistema de restauração de dados de mídia!         "
    echo "--------------------------------------------------------"
}


# Função para verificar se o dispositivo está montado
dispositivo_montado() {
    sudo mount $DEVICE $MOUNT_POINT > /dev/null
    mountpoint -q "$MOUNT_POINT"

    return $?
}

# Função para ejetar o dispositivo
ejetar_midia() {
    sudo umount "$DEVICE"
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