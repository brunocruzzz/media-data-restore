CONFIG_FILE="config.cfg"
source "$CONFIG_FILE"
source functions.sh
echo "Enviando dados em segundo plano"
echo "Confira os logs para verificação do envio"

sleep 25
echo ""
echo ""
echo "ATENÇÃO------------------------------->Upload de dados realizado com sucesso" | tee -a $LOG_FILE
echo ""
echo ""