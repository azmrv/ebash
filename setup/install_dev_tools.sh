#!/bin/bash
#
# Установка инструментов разработки: Go, Node.js, Rust, VS Code, Chrome, Git настройка, SSH
# Запуск: ./install_dev_tools.sh (НЕ от root!)
#

source "$(dirname "$0")/scripts/common.sh"

step "УСТАНОВКА ИНСТРУМЕНТОВ РАЗРАБОТКИ"
check_user "$USER"

# === Фикс: переходим в домашнюю директорию, чтобы избежать ошибок getcwd ===
cd "$HOME" || error "Не удалось перейти в $HOME"

# ---- Go ----
step "Установка Golang"
GO_VERSION=$(curl -s "https://go.dev/VERSION?m=text" | head -n 1)
info "Установка Go ${GO_VERSION}..."
wget -q --show-progress "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf /tmp/go.tar.gz
rm /tmp/go.tar.gz

sudo tee /etc/profile.d/go.sh > /dev/null << 'EOF'
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:$HOME/go/bin
EOF
sudo chmod +x /etc/profile.d/go.sh
export PATH=$PATH:/usr/local/go/bin
info "Go установлен: $(go version)"

# ---- Node.js ----
step "Установка Node.js LTS"
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs
info "Node.js установлен: $(node --version)"

# ---- VS Code ----
step "Установка VS Code (Snap)"
sudo snap install --classic code || info "VS Code уже установлен"

# ---- Google Chrome ----
step "Установка Google Chrome"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor --yes -o /etc/apt/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null
sudo apt update
sudo apt install -y google-chrome-stable

# ---- Git настройка ----
step "Настройка Git"
# Убеждаемся, что мы в домашней директории
cd "$HOME"
read -p "Введите ваше Имя и Фамилию для Git: " GIT_NAME
read -p "Введите ваш Email для Git: " GIT_EMAIL
if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
    git config --global init.defaultBranch main
    git config --global core.editor "code --wait"
    info "Git настроен: $GIT_NAME <$GIT_EMAIL>"
else
    warn "Данные не введены – Git настроен по умолчанию."
fi

# ---- SSH-ключ ----
step "Генерация SSH-ключа (Ed25519) для Forgejo"
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    ssh-keygen -t ed25519 -C "${GIT_EMAIL:-"local-dev"}" -f "$HOME/.ssh/id_ed25519" -N ""
    info "SSH-ключ создан: $HOME/.ssh/id_ed25519.pub"
else
    info "SSH-ключ уже существует."
fi

# ---- Rust ----
step "Установка Rust (через rustup)"
if ! command -v rustc &> /dev/null; then
    # Временно переходим в /tmp, чтобы избежать проблем с pwd
    cd /tmp
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    cd "$HOME"
    source "$HOME/.cargo/env"
    echo 'source "$HOME/.cargo/env"' >> ~/.bashrc
    rustup component add rust-analyzer clippy rustfmt
    info "Rust установлен: $(rustc --version)"
else
    info "Rust уже установлен: $(rustc --version)"
fi

# ---- Рабочие папки ----
step "Создание рабочих папок"
mkdir -p ~/projects ~/workspace ~/downloads

info "✅ Инструменты разработки установлены и настроены."
warn "Для применения переменных Go/Rust выполните 'source ~/.bashrc' или перезапустите терминал."