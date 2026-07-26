#!/bin/bash
#
# ПОЛНОСТЬЮ АВТОМАТИЧЕСКАЯ УСТАНОВКА ОКРУЖЕНИЯ РАЗРАБОТЧИКА
# Для Ubuntu 24.04 LTS / 26.04 LTS
# Запуск: ./setup_dev_env.sh (НЕ от root!)
#

# ---- Встроенные функции (без внешнего common.sh) ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Запрещаем запуск от root
if [ "$EUID" -eq 0 ]; then
    error "НЕ ЗАПУСКАЙТЕ ЭТОТ СКРИПТ ЧЕРЕЗ sudo! Запустите как обычный пользователь: ./setup_dev_env.sh"
fi

# Определяем реальную домашнюю папку (даже если используется sudo внутри)
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")
# ----------------------------------------------------

step "ОБНОВЛЕНИЕ СИСТЕМЫ И УСТАНОВКА БАЗОВЫХ ПАКЕТОВ"
sudo apt update && sudo apt upgrade -y

step "УСТАНОВКА БАЗОВЫХ УТИЛИТ И ИНСТРУМЕНТОВ"
# Современный набор пакетов для Ubuntu 24.04/26.04
sudo apt install -y \
    build-essential \
    git \
    curl \
    wget \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    python3 \
    python3-dev \
    python3-venv \
    cmake \
    htop \
    tree \
    net-tools \
    zip \
    unzip


step "Установка дополнительных утилит"
sudo apt install -y far2l bat fzf ripgrep fd-find tmux jq httpie

step "УСТАНОВКА DOCKER"
# Установка Docker по официальному репозиторию
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Добавляем пользователя в группу docker (чтобы не вводить sudo для docker команд)
sudo usermod -aG docker "$REAL_USER"
info "Пользователь $REAL_USER добавлен в группу docker (перезагрузка необходима для применения)"

step "УСТАНОВКА GOLANG"
GO_VERSION=$(curl -s "https://go.dev/VERSION?m=text" | head -n 1)
info "Установка Go версии ${GO_VERSION}..."
wget -q --show-progress "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf /tmp/go.tar.gz
rm /tmp/go.tar.gz

# Правильная запись путей в /etc/profile.d/go.sh (без подстановки)
sudo tee /etc/profile.d/go.sh > /dev/null << 'EOF'
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:$HOME/go/bin
EOF
sudo chmod +x /etc/profile.d/go.sh

# Временно добавляем в PATH для текущей сессии
export PATH=$PATH:/usr/local/go/bin

step "УСТАНОВКА NODE.JS LTS"
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs

step "УСТАНОВКА VS CODE (через Snap)"
sudo snap install --classic code

step "УСТАНОВКА GOOGLE CHROME"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor --yes -o /etc/apt/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | \
    sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt update
sudo apt install -y google-chrome-stable

step "НАСТРОЙКА GIT (интерактивная)"
read -p "📝 Введите ваше Имя и Фамилию для Git (например, Ivan Petrov): " GIT_NAME
read -p "📧 Введите ваш Email для Git (например, ivan@example.com): " GIT_EMAIL
echo ""
if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
    git config --global init.defaultBranch main
    git config --global core.editor "code --wait"
    info "✅ Глобальные настройки Git применены!"
else
    warn "⚠️ Данные не введены — Git оставлен с настройками по умолчанию."
fi

step "ГЕНЕРАЦИЯ SSH-КЛЮЧА ДЛЯ FORGEJO (Ed25519)"
if [ ! -f "$REAL_HOME/.ssh/id_ed25519" ]; then
    info "Генерация нового ключа Ed25519..."
    SSH_COMMENT="${GIT_EMAIL:-"local-dev-key"}"
    ssh-keygen -t ed25519 -C "$SSH_COMMENT" -f "$REAL_HOME/.ssh/id_ed25519" -N ""
    info "✅ SSH-ключ создан!"
else
    info "ℹ️ SSH-ключ уже существует, пропускаем."
fi

step "СОЗДАНИЕ РАБОЧИХ ПАПОК"
mkdir -p "$REAL_HOME/projects" "$REAL_HOME/workspace" "$REAL_HOME/downloads"

step "Установка Rust (через rustup)"
# Устанавливаем необходимые зависимости
sudo apt install -y build-essential

# Скачиваем и запускаем установщик rustup
# Флаг -y нужен для автоматического соглашения с условиями установки
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Добавляем Cargo в PATH для текущей сессии
source "$HOME/.cargo/env"

# Проверяем установку
rustc --version
cargo --version

info "✅ Rust успешно установлен!"

step "ГОТОВО!"
echo -e "${GREEN}==========================================================${NC}"
echo -e "${GREEN}🎉 УСТАНОВКА И НАСТРОЙКА ОКРУЖЕНИЯ УСПЕШНО ЗАВЕРШЕНЫ! 🎉${NC}"
echo -e "${GREEN}==========================================================${NC}"
echo ""
echo -e "${YELLOW}🔹 Чтобы применить пути Go прямо сейчас, выполните:${NC}"
echo "      source /etc/profile.d/go.sh"
echo ""
echo -e "${YELLOW}🔑 СКОПИРУЙТЕ ЭТОТ SSH-КЛЮЧ И ДОБАВЬТЕ ЕГО В FORGEJO:${NC}"
echo "   (Настройки профиля -> SSH / GPG ключи -> Добавить ключ)"
echo "----------------------------------------------------------"
cat "$REAL_HOME/.ssh/id_ed25519.pub"
echo "----------------------------------------------------------"
echo ""
echo -e "${YELLOW}⚠️  Для применения Docker без sudo перезагрузите систему:${NC}"
echo "      sudo reboot"
echo ""
info "Готово! Теперь вы можете клонировать репозитории по SSH и работать с Docker."