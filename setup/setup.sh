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
    echo "4. ПОЛНАЯ УСТАНОВКА (выбор этапа 1 или 2)"
    echo "5. Установка дополнительных утилит (far2l, bat, exa, fzf, ripgrep, fd-find, tmux, jq, httpie, tldr, Git LFS)"
    echo "6. Развёртывание Forgejo (Docker Compose)"
    echo "7. Создать структуру служебных папок"
    echo "8. Настройка безопасности SSH (UFW, Fail2ban, смена порта)"
    echo "0. Выход"
    echo
    read -p "Выберите вариант [0-8]: " choice
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
            warn "Полная установка разбита на два этапа:"
            echo "  Этап 1: системное ПО + безопасность (Docker, UFW, автообновления) — требует перезагрузки"
            echo "  Этап 2: инструменты разработки (Go, Rust, Node.js, VS Code, Chrome, Git, SSH),"
            echo "          дополнительные утилиты (far2l, bat, exa, fzf, ripgrep, tmux, jq, httpie, tldr, Git LFS),"
            echo "          развёртывание Forgejo, восстановление конфигов."
            echo ""
            read -p "Выберите этап [1 или 2]: " stage
            echo
            case $stage in
                1)
                    info "Запуск Этапа 1 (системное ПО + безопасность)..."
                    sudo "$SCRIPT_DIR/install_system.sh"
                    warn "✅ Системный этап завершён!"
                    warn "ОБЯЗАТЕЛЬНО ПЕРЕЗАГРУЗИТЕСЬ: sudo reboot"
                    warn "После перезагрузки снова запустите setup.sh и выберите пункт 4, затем этап 2."
                    ;;
                2)
                    info "Запуск Этапа 2 (инструменты, утилиты, Forgejo, конфиги)..."
                    "$SCRIPT_DIR/install_dev_tools.sh"
                    "$SCRIPT_DIR/install_software.sh"
                    "$SCRIPT_DIR/deploy_forgejo.sh"
                    "$SCRIPT_DIR/restore_configs.sh"
                    info "✅ Все компоненты этапа 2 установлены и настроены!"
                    ;;
                *)
                    error "Неверный выбор. Введите 1 или 2."
                    ;;
            esac
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
            info "Настройка безопасности SSH..."
            "$SCRIPT_DIR/setup_security.sh"
            ;;
        0)
            info "Выход. Удачной разработки!"
            exit 0
            ;;
        *)
            error "Неверный выбор. Выберите 0-8."
            ;;
    esac
    echo
    read -p "Нажмите Enter, чтобы продолжить..."
    clear
done