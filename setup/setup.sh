#!/bin/bash
#
# Главное интерактивное меню установки окружения разработчика
# Запуск: ./setup.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

show_menu() {
    echo -e "${GREEN}=== ГЛАВНОЕ МЕНЮ АВТОМАТИЗАЦИИ СЕРВЕРА РАЗРАБОТКИ ===${NC}"
    echo ""
    echo "--- Система и безопасность ---"
    echo " 1. Установка системного ПО + безопасность (требует sudo)"
    echo " 2. Настройка безопасности SSH (UFW, Fail2ban, смена порта)"
    echo " 3. Настройка SSH Certificate Authority (CA) — доступ по сертификатам"
    echo ""
    echo "--- Инструменты разработки ---"
    echo " 4. Установка инструментов разработки (Go, Node.js, Rust, VS Code, Chrome, Git, SSH)"
    echo " 5. Установка дополнительных утилит (far2l, bat, exa, fzf, ripgrep, tmux, jq, httpie, tldr, Git LFS)"
    echo ""
    echo "--- Git-сервер и CI/CD ---"
    echo " 6. Развёртывание Forgejo (Git-сервер через Docker Compose)"
    echo " 7. Установка Forgejo Runner (CI/CD для автоматической сборки)"
    echo ""
    echo "--- Конфигурации и бэкапы ---"
    echo " 8. Восстановление пользовательских конфигураций (из папки configs)"
    echo " 9. Создание бэкапа текущих конфигураций (в папку configs)"
    echo ""
    echo "--- Утилиты ---"
    echo "10. Создать структуру служебных папок"
    echo " 0. Выход"
    echo ""
    read -p "Выберите вариант [0-10]: " choice
}

create_structure
clear

while true; do
    show_menu
    case $choice in
        1)
            info "Запуск системной установки..."
            sudo "$SCRIPT_DIR/install_system.sh"
            ;;
        2)
            info "Настройка безопасности SSH..."
            "$SCRIPT_DIR/setup_security.sh"
            ;;
        3)
            info "Настройка SSH Certificate Authority (CA)..."
            "$SCRIPT_DIR/setup_ssh_ca.sh"
            ;;
        4)
            info "Установка инструментов разработки..."
            "$SCRIPT_DIR/install_dev_tools.sh"
            ;;
        5)
            info "Установка дополнительных утилит..."
            "$SCRIPT_DIR/install_software.sh"
            ;;
        6)
            info "Развёртывание Forgejo..."
            "$SCRIPT_DIR/deploy_forgejo.sh"
            ;;
        7)
            info "Установка Forgejo Runner..."
            "$SCRIPT_DIR/setup_forgejo_runner.sh"
            ;;
        8)
            info "Восстановление конфигураций..."
            "$SCRIPT_DIR/restore_configs.sh"
            ;;
        9)
            info "Создание бэкапа конфигураций..."
            "$SCRIPT_DIR/backup_configs.sh"
            ;;
        10)
            create_structure
            ;;
        0)
            info "Выход. Удачной разработки!"
            exit 0
            ;;
        *)
            error "Неверный выбор. Пожалуйста, выберите цифру от 0 до 10."
            ;;
    esac
    echo
    read -p "Нажмите Enter, чтобы продолжить..."
    clear
done