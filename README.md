# Sistema de restauração de DVD's para storage

Este repositório automatiza a restauração de backups a partir de mídias físicas para o servidor de dados, como parte de um plano de contingência.

---

## Pré-requisitos

- Ambiente Linux (suporte parcial via WSL no Windows).
- Permissões de administrador (sudo).

### Dependências básicas (geralmente pré-instaladas)

- bash, awk, sed, grep, cut, df, mount, umount, mkdir, rm, mv, cp, date, clear, echo, read

### Dependências adicionais (instale conforme necessário)

| Pacote       | Função                                    | Instalação (Ubuntu/Debian)           |
|--------------|------------------------------------------|-------------------------------------|
| rsync        | Cópia eficiente de arquivos               | `sudo apt install rsync`             |
| tree         | Exibe estrutura de diretórios             | `sudo apt install tree`              |
| eject        | Ejetar mídias físicas                      | `sudo apt install eject`             |
| nfs-common   | Cliente NFS para montar diretórios remotos| `sudo apt install nfs-common`        |
| util-linux   | blkid para UUID e LABEL de dispositivos   | `sudo apt install util-linux`        |
| productx     | Leitura de metadados de arquivos RAW      | Copiar para `/usr/local/bin/` e dar permissão |
| powershell.exe | Acesso ao PowerShell (apenas WSL)        | Incluído no Windows + WSL            |

---

# setup_client.bash

## Descrição

Este script prepara a máquina para a restauração de dados de DVDs, configurando o ambiente necessário e instalando as ferramentas adequadas.

## Pré-requisitos

Se estiver utilizando Windows com WSL (Windows Subsystem for Linux), é necessário rodar previamente o script enable_wsl.bat para garantir que o WSL esteja corretamente instalado e configurado.

### Script `wsl_enable_install.bat`
Este script realiza os seguintes passos:

- Verifica se está sendo executado com permissões de administrador;
- Habilita o recurso WSL no Windows;
- Ativa a Plataforma de Máquina Virtual;
- Define o WSL 2 como padrão;
- Instala a distribuição padrão (Ubuntu).

### Como executar:

Clique com o botão direito e execute como Administrador:

Execute o script `wsl_enable_install.bat`;

## Uso

### Passo a Passo

#### Download e Preparação do Script

Baixe o script `setup_client.bash` e certifique-se de que ele possui permissões de execução:

```bash
chmod +x setup_client.bash
sudo ./setup_client.bash
```
O script cria um arquivo de configuração `config.cfg`

### Estrutura do Arquivo de Configuração (config.cfg) - Exemplo

O arquivo `config.cfg` deve ter a seguinte estrutura(Caso o script não consiga detectar automaticamente algumas configurações, você pode editar o arquivo config.cfg manualmente para ajustar os parâmetros conforme necessário):

```plaintext
DEVICE="/dev/sr0"               # Dispositivo de CD/DVD(Em ambiente WSL, por exemplo, seria "D:")
FS_TYPE="iso9660"               # Tipo de sistema de arquivos
MOUNT_POINT="/mnt/dvd"          # Ponto de montagem da mídia
STORAGE_MOUNT="/mnt/dados"      # Ponto de montagem da storage
STORAGE_IP="192.168.1.100"      # Endereço IP da storage
WORKING_DIRECTORY="/home/user/media-data-restore/$(hostname)"  # Diretório de trabalho(Cópia dos dados do DVD)
LOG_FILE="/home/user/media-data-restore/$(hostname)/log.txt"   # Arquivo de log
(...)
```

**Importante:** O cliente deve estar habilitada no servidor NFS, seja via hostname ou endereço IP, com as permissões necessárias para acesso.
Essa informação deve ser passada aos responsáveis com acesso administrativo ao servidor para que possam configurar as permissões corretamente.

## Execução do Script copiar.bash

Com as instalações e configurações preparadas, o script `copiar.bash` pode ser executado.

### Passo a Passo para Executar o Script copiar.bash

1. **Preparação**
   - Certifique-se de que o script `setup_client.bash` foi executado com sucesso e que todas as dependências e configurações estão corretas.

2. **Verificação do Arquivo de Configuração**
   - Verifique se o arquivo `config.cfg` contém as informações corretas sobre o dispositivo de CD/DVD, pontos de montagem, diretório de trabalho e endereço IP do servidor remoto.

3. **Execução do Script**

   - Torne o script `copiar.bash` executável:

     ```bash
     chmod +x copiar.bash
     ```

   - Execute o script(comandos com sudo irão pedir a senha de superusuário):

     ```bash
     ./copiar.bash
     ```



### Descrição do Script copiar.bash

O script `copiar.bash` realiza uma cópia em massa de dados de DVDs para a máquina local e, em seguida, envia esses dados para um servidor remoto utilizando o `rsync`.

### Funcionalidades do Script copiar.bash

1. **Montagem de DVDs**
   - Monta automaticamente os DVDs em um ponto de montagem especificado no arquivo de configuração `config.cfg`.

2. **Cópia de Dados**
   - Copia os dados dos DVDs para um diretório de trabalho especificado no arquivo de configuração.

3. **Catalogação dos Dados**
   - Após a cópia a catalogação é iniciada, gerando a estrutura necessária para adesão ao repositório da storage.

4. **Envio para o Servidor Remoto**
   - Utiliza o `rsync` para sincronizar os dados catalogados com o servidor remoto. O endereço IP e o ponto de montagem do servidor são especificados no arquivo de configuração `config.cfg`.

### Autores

- Bruno da Cruz Bueno
- Jaqueline Murakami Kokitsu
- Simone Cincotto Carvalho