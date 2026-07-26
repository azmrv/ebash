#!/bin/bash
#
# Полностью автономный скрипт установки окружения разработки для Ubuntu 24.04 / 26.04
# Включает: Node.js, Go, VS Code, Chrome, Git (с настройкой), SSH-ключ для Forgejo

# ---- Встроенные функции (заменяют common.sh) ----
step() {
    echo -e "\n=================================================="
    echo -e "=== $1 ==="
    echo -e "=================================================="
}

info() {
    echo -e "ℹ️  $1"
}

warn() {
    echo -e "⚠️  $1"
}

check_user() {
    # Проверка, что скрипт не запущен от root (опционально)
    if [ "$EUID" -eq 0 ]; then
        warn "Запуск от root не рекомендуется. Продолжаем, но учтите, что некоторые настройки могут применяться к root."
    fi
}
# -------------------------------------------------

step "УСТАНОВКА ИНСТРУМЕНТОВ РАЗРАБОТКИ ДЛЯ UBUNTU"
check_user "$USER"

# ---- 1. Node.js LTS ----
step "1. Установка Node.js LTS"
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs

# ---- 2. Golang ----
step "2. Установка Golang"
GO_VERSION=$(curl -s "https://go.dev/VERSION?m=text" | head -n 1)
info "Установка Go версии ${GO_VERSION}..."

wget -q --show-progress "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf /tmp/go.tar.gz
rm /tmp/go.tar.gz

# Правильная запись путей в глобальный профиль (без подстановки на этапе выполнения скрипта)
sudo tee /etc/profile.d/go.sh > /dev/null << 'EOF'
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:$HOME/go/bin
EOF
sudo chmod +x /etc/profile.d/go.sh

# ---- 3. VS Code и Google Chrome ----
step "3. Установка дополнительных инструментов"
info "Установка VS Code через Snap..."
sudo snap install --classic code

info "Добавление репозитория и установка Google Chrome..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor --yes -o /etc/apt/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt update
sudo apt install -y google-chrome-stable

# ---- 4. Git и интерактивная настройка ----
step "4. Установка Git и настройка пользователя"
sudo apt install -y git

echo ""
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

# Установка Git LFS
sudo apt install -y git-lfs
git lfs install --skip-repo
info "Git LFS установлен и инициализирован глобально."



# ---- 5. Генерация SSH-ключа для Forgejo ----
step "5. Создание SSH-ключа (Ed25519) для Forgejo"
if [ ! -f ~/.ssh/id_ed25519 ]; then
    info "Генерация нового ключа Ed25519..."
    SSH_COMMENT="${GIT_EMAIL:-"local-dev-key"}"
    ssh-keygen -t ed25519 -C "$SSH_COMMENT" -f ~/.ssh/id_ed25519 -N ""
    info "✅ SSH-ключ успешно создан!"
else
    info "ℹ️ SSH-ключ уже существует, пропускаем генерацию."
fi

# ---- 6. Развёртывание Forgejo ----
step "Развёртывание Forgejo"

# Проверяем, что не root
check_user "$USER"

# Проверяем, установлен ли Docker
if ! command -v docker &> /dev/null; then
    error "Docker не найден! Сначала установите Docker через пункт 1 меню."
fi

FORGEJO_DIR="$HOME/forgejo-server"
mkdir -p "$FORGEJO_DIR"
cd "$FORGEJO_DIR"

# Создаём docker-compose.yml, если его нет
if [ ! -f "docker-compose.yml" ]; then
    info "Создание docker-compose.yml..."
    cat > docker-compose.yml << 'EOF'
# docker-compose.yml с ресурсами
networks:
  forgejo:
    external: false

services:
  server:
    image: codeberg.org/forgejo/forgejo:10
    container_name: forgejo
    restart: always
    networks:
      - forgejo
    volumes:
      - ./forgejo-data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "3000:3000"
      - "2222:22"
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4096M
EOF
else
    info "docker-compose.yml уже существует, используем его."
fi

# Запускаем контейнер
info "Запуск Forgejo в фоновом режиме..."
docker compose up -d

# Ждём несколько секунд, чтобы контейнер поднялся
sleep 3

# Получаем IP-адрес
IP=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n1)
if [ -z "$IP" ]; then
    IP="localhost"
fi




info "✅ Forgejo успешно запущен!"
echo -e "${GREEN}Откройте в браузере: http://$IP:3000${NC}"
echo -e "${YELLOW}Для первого входа создайте администратора.${NC}"
echo -e "${YELLOW}Не забудьте настроить домен / URL-адрес на реальный IP (не localhost).${NC}"
echo ""
info "Управление контейнером:"
echo "  Остановить:   docker compose down"
echo "  Логи:         docker compose logs -f"
echo "  Перезапустить: docker compose restart"





# ---- 7. Установка Rust ----
step "Установка Rust"

# Проверяем, что не root
check_user "$USER"

# Устанавливаем зависимости (build-essential уже должен быть, но на всякий случай)
sudo apt install -y build-essential

# Проверяем, установлен ли уже rustup
if command -v rustc &> /dev/null; then
    info "Rust уже установлен: $(rustc --version)"
    read -p "Переустановить / обновить? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Пропускаем установку Rust."
        exit 0
    fi
fi

info "Скачивание и запуск rustup..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Добавляем Cargo в PATH для текущей сессии
source "$HOME/.cargo/env"

# Добавляем в .bashrc, если ещё нет
if ! grep -q ".cargo/env" ~/.bashrc; then
    echo 'source "$HOME/.cargo/env"' >> ~/.bashrc
    info "Путь к Cargo добавлен в ~/.bashrc"
fi

# Устанавливаем дополнительные компоненты (опционально)
rustup component add rust-analyzer
rustup component add clippy
rustup component add rustfmt

info "✅ Rust успешно установлен:"
rustc --version
cargo --version
warn "Перезапустите терминал или выполните 'source ~/.cargo/env' для применения переменных."











# ---- 6. Создание рабочих папок ----
step "6. Настройка структуры папок"
mkdir -p ~/projects ~/workspace ~/downloads

# ---- Финальное сообщение ----
step "ГОТОВО!"
info "=========================================================="
info "🎉 УСТАНОВКА И НАСТРОЙКА ОКРУЖЕНИЯ УСПЕШНО ЗАВЕРШЕНЫ! 🎉"
info "=========================================================="
info "🔹 Чтобы применить пути Go прямо сейчас, выполните:"
info "      source /etc/profile.d/go.sh"
echo ""
info "🔑 СКОПИРУЙТЕ ЭТОТ SSH-КЛЮЧ И ДОБАВЬТЕ ЕГО В FORGEJO:"
info "   (Настройки профиля -> SSH / GPG ключи -> Добавить ключ)"
echo "----------------------------------------------------------"
cat ~/.ssh/id_ed25519.pub
echo "----------------------------------------------------------"
info "Готово! Теперь вы можете клонировать репозитории по SSH."