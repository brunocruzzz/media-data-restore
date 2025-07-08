## TODO

- DVD_NUMBER dentro do arquivo OK_DIR
- Validar quando erro ao ler arquivo RAW. Situação de "indefinido".
- Modularizar o catalog. Criar função classificar_produto e classificar_cidade.
- Enviar notificação por e-mail ao final do processo.
- Implementar barra de progresso visual no terminal

## BUGS 

- WSL tem DriveLetter hardcoded. Arrumar buscando o $DEVICE em config.cfg.
- `rsync` trava em arquivos corrompidos (tratar com timeout ou fallback)