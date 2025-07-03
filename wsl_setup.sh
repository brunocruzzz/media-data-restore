#!/bin/bash

set -e  # Para o script se qualquer comando falhar

# CONFIGURE AQUI
REPO_URL="https://github.com/brunocruzzz/media-data-restore.git"
DEST_DIR="$HOME/meu_projeto"

echo "📦 Instalando Git..."
sudo apt update
sudo apt install -y git

# Se quiser outras dependências, descomente:
# echo "🐍 Instalando Python e pip..."
# sudo apt install -y python3 python3-pip

echo "⬇️ Clonando repositório..."
git clone "$REPO_URL" "$DEST_DIR"

echo "📁 Entrando na pasta do projeto..."
cd "$DEST_DIR"

# Se tiver um setup padrão (Python, Node, etc.), execute-o:
# echo "📦 Instalando dependências do Python (exemplo)"
# pip3 install -r requirements.txt

# echo "🚀 Rodando o app (exemplo)"
# python3 app.py

echo "✅ Tudo pronto!"
prepare_server.bash