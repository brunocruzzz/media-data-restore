#!/bin/bash

set -e  # Para o script se qualquer comando falhar

# CONFIGURE AQUI
REPO_URL="https://github.com/brunocruzzz/media-data-restore.git"
DEST_DIR="$HOME/media-data-restore"

echo "📦 Instalando Git..."
sudo apt update
sudo apt install -y git

# Se quiser outras dependências, descomente:
# echo "🐍 Instalando Python e pip..."
# sudo apt install -y python3 python3-pip

if [ -d "$DEST_DIR" ] && [ -n "$(ls -A "$DEST_DIR")" ] && [ -d "$DEST_DIR/.git" ]; then
    echo "📂 Repositório já existe em '$DEST_DIR'. Executando git pull..."
    cd "$DEST_DIR"
    git pull
else
    echo "⬇️ Clonando repositório..."
    git clone "$REPO_URL" "$DEST_DIR"
    echo "📁 Entrando na pasta do projeto..."
    cd "$DEST_DIR"
fi

# Se tiver um setup padrão (Python, Node, etc.), execute-o:
# echo "📦 Instalando dependências do Python (exemplo)"
# pip3 install -r requirements.txt

# echo "🚀 Rodando o app (exemplo)"
# python3 app.py

echo "✅ Tudo pronto! Execute o script prepare_server.bash para configurar o ambiente, caso não tenha o arquivo de configuração."