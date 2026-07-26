#!/bin/bash
#
# Главное интерактивное меню установки окружения разработчика
# Запуск: ./setup.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

show_menu() {
    echo -e "${GREEN}=== ИНТЕРАКТИВНОЕ МЕНЮ УСТАНОВКИ ОКРУЖЕНИЯ ===${NC}"
    echo "1. Установка системного ПО + безопасность (требует sudo)"
    echo "2. Установка инструментов разработки (Go, Node.js, Rust, VS Code, Chrome, Git, SSH)"
    echo "3. Восстановление пользовательских конфигураций"
    echo "4. ПОЛНАЯ УСТАНОВКА (пошагово, с перезагрузкой)"
    echo "5. Установка дополнительных утилит (far2l, bat, exa, fzf, ripgrep, fd-find, tmux, jq, httpie, tldr, Git LFS)"
    echo "6. Развёртывание Forgejo (Docker Compose)"
    echo "7. Создать структуру служебных папок"
    echo "8. Настройка безопасности SSH (UFW, Fail2ban, смена порта)"
    echo "0. Выход"
    echo
    read -p "Выберите вариант [0-7]: " choice
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
            info "Запуск установки инструментов разработки..."
            "$SCRIPT_DIR/install_dev_tools.sh"
            ;;
        3)
            info "Восстановление конфигураций..."
            "$SCRIPT_DIR/restore_configs.sh"
            ;;
        4)
            warn "Полная установка в два этапа:"
            echo "Этап 1: системное ПО + безопасность (требуется перезагрузка)"
            echo "Этап 2: инструменты разработки + утилиты + Forgejo"
            read -p "Запустить Этап 1? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo "$SCRIPT_DIR/install_system.sh"
                warn "Системный этап завершён. Перезагрузитесь: sudo reboot"
                warn "После перезагрузки запустите setup.sh и выполните пункты 2, 5, 6, 3."
                exit 0
            fi
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
            create_structure
            ;;
        8)
        info "Запуск настройки безопасности SSH..."
        "$SCRIPT_DIR/setup_security.sh"
            ;;
        0)
            info "Выход. Удачной разработки!"
            exit 0
            ;;
        *)
            error "Неверный выбор. Выберите 0-7."
            ;;
    esac
    echo
    read -p "Нажмите Enter, чтобы продолжить..."
    clear
done