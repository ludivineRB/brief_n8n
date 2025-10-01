#!/usr/bin/env bash
set -e

# Couleurs
msg()  { echo -e "\e[1;34m[INFO]\e[0m $*"; }
warn() { echo -e "\e[1;33m[WARN]\e[0m $*"; }
err()  { echo -e "\e[1;31m[ERROR]\e[0m $*" >&2; exit 1; }

# 1) Détection OS
OS="$(uname -s)"
case "$OS" in
  Linux)
    if [ -r /etc/os-release ]; then
      . /etc/os-release
      DISTRO="$ID"
    else
      warn "/etc/os-release introuvable, tentative par lsb_release..."
      DISTRO="$(lsb_release -si | tr '[:upper:]' '[:lower:]')"
    fi
    ;;
  Darwin)
    DISTRO="macos"
    ;;
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    echo "⚠️ Ce script bash n'est pas compatible avec Windows."
    echo "👉 Rendez-vous ici pour installer Docker Desktop : https://www.docker.com/get-started/"
    exit 0
    ;;
  *)
    err "OS '$OS' non supporté. Installe Docker manuellement."
    ;;
esac

# 2) Installation Docker
install_docker_linux() {
  case "$DISTRO" in
    ubuntu|debian)
      sudo apt-get update
      sudo apt-get install -y \
        ca-certificates curl gnupg \
        docker.io docker-compose-plugin
      ;;
    fedora|centos)
      sudo dnf -y install dnf-plugins-core
      sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
      sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
      ;;
    arch)
      sudo pacman -Sy --noconfirm docker docker-compose
      ;;
    *)
      warn "Distribution '$DISTRO' non gérée automatiquement."
      echo "→ Installe Docker manuellement : https://docs.docker.com/engine/install/"
      exit 1
      ;;
  esac
}

install_docker_macos() {
  if ! command -v brew &>/dev/null; then
    warn "Homebrew non trouvé. Installation..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
    msg "Homebrew installé."
  fi

  brew install --cask docker
  brew install docker docker-compose
  msg "✅ Docker installé via Homebrew. Lance Docker Desktop manuellement si nécessaire."
}

# 3) Vérifier Docker
if ! command -v docker &>/dev/null; then
  msg "Docker non trouvé, installation pour $DISTRO..."
  if [ "$OS" = "Linux" ]; then
    install_docker_linux
  else
    install_docker_macos
  fi
  if [ "$OS" = "Linux" ]; then
    sudo usermod -aG docker "$USER"
    warn "Déconnecte-toi puis reconnecte-toi pour activer l'accès Docker sans sudo."
  fi
else
  msg "Docker déjà installé."
fi

# 4) Vérifier Docker Compose plugin
if ! docker compose version &>/dev/null; then
  err "Plugin 'docker compose' manquant. Assure-toi d'utiliser le plugin et non l'ancien binaire."
fi

# 5) Génération du .env
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
  msg "$ENV_FILE déjà présent."
else
  msg "Création de $ENV_FILE..."
  RAND() { head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32; }
  cat > "$ENV_FILE" <<EOF
POSTGRES_USER=admin_user_db
POSTGRES_PASSWORD=$(RAND)
POSTGRES_DB=n8n_database

DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=db
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n_database
DB_POSTGRESDB_USER=\${POSTGRES_USER}
DB_POSTGRESDB_PASSWORD=\${POSTGRES_PASSWORD}

N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=n8n_admin_user
N8N_BASIC_AUTH_PASSWORD=$(RAND)

N8N_HOST=localhost
N8N_PORT=5678
N8N_PROTOCOL=http

N8N_RUNNERS_ENABLED=true
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
EOF
  msg "$ENV_FILE généré."
fi

# 6) Démarrage
msg "Pull des images Docker..."
docker compose pull

msg "Lancement du stack..."
docker compose up -d --build

# 7) Rappel des ports
msg "✅ PostgreSQL : port 5432"
msg "✅ Ollama     : port 11434"
msg "✅ N8N        : port 5678"
echo "👉 👉 👉 Accès à l'interface N8N : http://localhost:5678"

# 8) Téléchargement des modèles Ollama
if command -v ollama &>/dev/null; then
  msg "Téléchargement du modèle Ollama 'llama3.2:1b'…"
  ollama pull llama3.2:1b
  
  msg "Téléchargement du modèle Ollama 'mistral:instruct'…"
  ollama pull mistral:instruct
else
  warn "Commande 'ollama' non trouvée ; saisis manuellement si besoin."
fi
