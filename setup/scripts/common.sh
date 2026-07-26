#!/bin/bash
#
# Общие функции и настройки для всех скриптов
#

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Проверка, что скрипт НЕ запущен от root
check_user() {
    if [ "$EUID" -eq 0 ]; then
        error "НЕ запускайте этот скрипт через 'sudo $0'!"
        error "Запустите его как обычный пользователь: ./setup_dev_env.sh"
        error "Скрипт сам запросит sudo там, где это необходимо."
        exit 1
    fi
}

# Проверка наличия sudo
check_sudo() {
    if ! [ -x "$(command -v sudo)" ]; then
        error "В системе не установлена утилита sudo."
        exit 1
    fi
}

# Определение домашней директории реального пользователя
# (даже если сработает sudo, пути не сломаются)
REAL_USER_HOME=$(eval echo "~${SUDO_USER:-$USER}")
SETUP_DIR="$REAL_USER_HOME/setup"
CONFIGS_DIR="$SETUP_DIR/configs"
SCRIPTS_DIR="$SETUP_DIR/scripts"

# Создание структуры папок
create_structure() {
    mkdir -p "$SETUP_DIR" "$CONFIGS_DIR" "$SCRIPTS_DIR"
    info "Структура папок создана в $SETUP_DIR"
}