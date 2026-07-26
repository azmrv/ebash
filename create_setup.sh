#!/bin/bash
#
# Скрипт для создания пакета восстановления рабочего окружения
# Запуск: ./create_setup_package.sh
# Результат: папка ~/system_setup с конфигами и скриптами установки
#

# Подключаем общие функции (если есть)
if [ -f "$(dirname "$0")/scripts/common.sh" ]; then
    source "$(dirname "$0")/scripts/common.sh"
else
    # Определяем минимальные функции, если common.sh недоступен
    info() { echo -e "\033[0;32m[INFO]\033[0m $1"; }
    warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
    error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; exit 1; }
    step() { echo -e "\033[0;34m[STEP]\033[0m $1"; }
fi

set -e  # Прерывать при любой ошибке

# --- НАСТРОЙКИ ---
SETUP_DIR=~/system_setup
CONFIGS_DIR="$SETUP_DIR/configs"

# Список файлов и папок для бэкапа (относительно ~/)
FILES_TO_BACKUP=(
    ".bashrc"
    ".gitconfig"
    ".profile"
    ".zshrc"               # если используете Zsh
    ".ssh/config"          # только конфиг SSH, не ключи!
    ".config/Code/User/settings.json"
    ".config/Code/User/keybindings.json"
    ".local/share/godot/"  # настройки Godot (если нужны)
)

step "Создание пакета восстановления в $SETUP_DIR"

# --- ШАГ 1: Копирование конфигураций ---
info "[1/3] Копирование файлов конфигурации..."
mkdir -p "$CONFIGS_DIR"

for item_path in "${FILES_TO_BACKUP[@]}"; do
    source_path="$HOME/$item_path"
    dest_path="$CONFIGS_DIR/$item_path"

    if [ -e "$source_path" ]; then
        mkdir -p "$(dirname "$dest_path")"
        if [ -d "$source_path" ]; then
            cp -R "$source_path" "$dest_path"
        else
            cp "$source_path" "$dest_path"
        fi
        info "  Скопировано: $item_path"
    else
        warn "  Пропущено (не найдено): $item_path"
    fi
done

# --- ШАГ 2: Генерация скрипта установки ПО ---
info "[2/3] Генерация install_software.sh..."

cat > "$SETUP_DIR/install_software.sh" << 'EOF'
#!/bin/bash
#
# Скрипт установки ПО для свежей Ubuntu
# Запуск: sudo ./install_software.sh
#
set -e

# Цвета (опционально)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== УСТАНОВКА ПО ДЛЯ РАЗРАБОТКИ ===${NC}"

# --- Обновление системы ---
echo -e "${GREEN}--- Шаг 1: Обновление системы ---${NC}"
sudo apt update && sudo apt upgrade -y

# --- Базовые пакеты (без python3-pip, используем venv) ---
echo -e "${GREEN}--- Шаг 2: Базовые утилиты ---${NC}"
APT_PACKAGES="build-essential git curl wget software-properties-common apt-transport-https ca-certificates python3 python3-dev python3-venv cmake htop tree net-tools zip unzip"
sudo apt install -y $APT_PACKAGES

# --- Golang ---
echo -e "${GREEN}--- Шаг 3: Установка Golang ---${NC}"
GO_VERSION=$(curl -s "https://go.dev/VERSION?m=text" | head -n 1)
echo "Установка Go ${GO_VERSION}..."
wget -q --show-progress "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf /tmp/go.tar.gz
rm /tmp/go.tar.gz

# Правильная запись путей (без подстановки)
sudo tee /etc/profile.d/go.sh > /dev/null << 'GEOF'
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:$HOME/go/bin
GEOF
sudo chmod +x /etc/profile.d/go.sh

export PATH=$PATH:/usr/local/go/bin
echo "Go установлен: $(go version)"

# --- Docker ---
echo -e "${GREEN}--- Шаг 4: Установка Docker ---${NC}"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

VERSION_CODENAME=$(source /etc/os-release && echo "$VERSION_CODENAME")
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Добавление пользователя в группу docker
if [ -n "$SUDO_USER" ]; then
    sudo usermod -aG docker "$SUDO_USER"
    echo -e "${YELLOW}Пользователь $SUDO_USER добавлен в группу docker.${NC}"
else
    echo -e "${YELLOW}Не удалось определить пользователя. Добавьте себя в группу docker вручную.${NC}"
fi

# --- Node.js LTS ---
echo -e "${GREEN}--- Шаг 5: Установка Node.js LTS ---${NC}"
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs
echo "Node.js установлен: $(node --version)"

# --- Google Chrome (опционально) ---
echo -e "${GREEN}--- Шаг 6: Установка Google Chrome ---${NC}"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor --yes -o /etc/apt/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null
sudo apt update
sudo apt install -y google-chrome-stable

# --- Финал ---
echo -e "\n${GREEN}✅ УСТАНОВКА ПО УСПЕШНО ЗАВЕРШЕНА!${NC}"
echo -e "${YELLOW}ВАЖНО:${NC}"
echo "1. Перезагрузите систему, чтобы применить права группы Docker: sudo reboot"
echo "2. После перезагрузки запустите ./restore_configs.sh для восстановления ваших настроек."
EOF

chmod +x "$SETUP_DIR/install_software.sh"
info "  Скрипт install_software.sh создан"

# --- ШАГ 3: Генерация скрипта восстановления конфигов ---
info "[3/3] Генерация restore_configs.sh..."

cat > "$SETUP_DIR/restore_configs.sh" << 'EOF'
#!/bin/bash
#
# Восстановление конфигураций из папки configs в домашний каталог
# Запуск: ./restore_configs.sh
#
set -e

# Определяем директорию скрипта и папку с конфигами
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="$SCRIPT_DIR/configs"

if [ ! -d "$CONFIGS_DIR" ]; then
    echo "Ошибка: папка configs не найдена в $SCRIPT_DIR"
    exit 1
fi

echo "Восстановление конфигураций из $CONFIGS_DIR в $HOME"

# Обработка файлов с пробелами (используем -print0)
find "$CONFIGS_DIR" -type f -print0 | while IFS= read -r -d '' source_file; do
    relative_path="${source_file#$CONFIGS_DIR/}"
    destination_path="$HOME/$relative_path"

    # Создаём бэкап, если файл уже существует
    if [ -e "$destination_path" ] || [ -L "$destination_path" ]; then
        backup_name="$destination_path.bak_$(date +%Y%m%d_%H%M%S)"
        mv "$destination_path" "$backup_name"
        echo "  Бэкап: $backup_name"
    fi

    # Создаём папку назначения и копируем файл
    mkdir -p "$(dirname "$destination_path")"
    cp "$source_file" "$destination_path"
    echo "  Восстановлен: $relative_path"
done

echo -e "\n✅ Все конфигурации восстановлены!"
echo "Перезапустите терминал или выполните source ~/.bashrc"
EOF

chmod +x "$SETUP_DIR/restore_configs.sh"
info "  Скрипт restore_configs.sh создан"

# --- Финальное сообщение ---
echo -e "\n🎉 Пакет восстановления успешно создан в: $SETUP_DIR"
echo "Содержимое:"
ls -la "$SETUP_DIR"
echo ""
echo "Чтобы развернуть окружение на новой системе:"
echo "1. Скопируйте эту папку на целевую машину."
echo "2. Запустите: sudo ./install_software.sh"
echo "3. Перезагрузитесь."
echo "4. Запустите: ./restore_configs.sh"