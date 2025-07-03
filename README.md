# prepare_server.bash

## Descrição

Este script prepara a máquina para a restauração de dados de DVDs, configurando o ambiente necessário e instalando as ferramentas adequadas.

## Pré-requisitos

Se estiver utilizando Windows com WSL (Windows Subsystem for Linux), é necessário rodar previamente o script enable_wsl.bat para garantir que o WSL esteja corretamente instalado e configurado.

### Script enable_wsl.bat
Este script realiza os seguintes passos:

Verifica se está sendo executado com permissões de administrador;

Habilita o recurso WSL no Windows;

Ativa a Plataforma de Máquina Virtual;

Define o WSL 2 como padrão;

Instala a distribuição padrão (Ubuntu).

### Como executar:

Execute o script `enable_wsl.bat`;

Clique com o botão direito e execute como Administrador:

## Uso

### Passo a Passo

#### Download e Preparação do Script

Baixe o script `prepare_server.bash` e certifique-se de que ele possui permissões de execução:

```bash
chmod +x prepare_server.bash
sudo ./prepare_server.bash
```
O script cria um arquivo de configuração `config.cfg`

LOG_FILE: Arquivo de log.

## Execução do Script copiar.bash

Com as instalações e configurações preparadas, o script `copiar.bash` pode ser executado.

### Descrição do Script copiar.bash

O script `copiar.bash` realiza uma cópia em massa de dados de DVDs para a máquina local e, em seguida, envia esses dados para um servidor remoto utilizando o `rsync`.

### Funcionalidades do Script copiar.bash

1. **Montagem de DVDs**
   - Monta automaticamente os DVDs em um ponto de montagem especificado no arquivo de configuração `config.cfg`.

2. **Cópia de Dados**
   - Copia os dados dos DVDs para um diretório de trabalho especificado no arquivo de configuração.

3. **Envio para o Servidor Remoto**
   - Utiliza o `rsync` para sincronizar os dados copiados com um servidor remoto. O endereço IP e o ponto de montagem do servidor são especificados no arquivo de configuração `config.cfg`.

### Passo a Passo para Executar o Script copiar.bash

1. **Preparação**
   - Certifique-se de que o script `prepare_server.bash` foi executado com sucesso e que todas as dependências e configurações estão corretas.

2. **Verificação do Arquivo de Configuração**
   - Verifique se o arquivo `config.cfg` contém as informações corretas sobre o dispositivo de CD/DVD, pontos de montagem, diretório de trabalho e endereço IP do servidor remoto.

3. **Execução do Script**

   - Torne o script `copiar.bash` executável:

     ```bash
     chmod +x copiar.bash
     ```

   - Execute o script com permissões de superusuário:

     ```bash
     sudo ./copiar.bash
     ```

### Estrutura do Arquivo de Configuração (config.cfg)

O arquivo `config.cfg` deve ter a seguinte estrutura(Caso o script não consiga detectar automaticamente algumas configurações, você pode editar o arquivo config.cfg manualmente para ajustar os parâmetros conforme necessário):

```plaintext
DEVICE="/dev/sr0"               # Dispositivo de CD/DVD
FS_TYPE="iso9660"               # Tipo de sistema de arquivos
MOUNT_POINT="/mnt/dvd"          # Ponto de montagem da mídia
STORAGE_MOUNT="/mnt/dados"      # Ponto de montagem da storage
STORAGE_IP="192.168.1.100"      # Endereço IP da storage
WORKING_DIRECTORY="/home/user/media-data-restore/$(hostname)"  # Diretório de trabalho
LOG_FILE="/home/user/media-data-restore/$(hostname)/log.txt"   # Arquivo de log
