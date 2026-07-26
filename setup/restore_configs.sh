#!/bin/bash
#
# Исправленный скрипт восстановления конфигураций из папки configs
# Запуск: ./restore_configs.sh
#
# Подтягиваем общие функции
source "$(dirname "$0")/scripts/common.sh"

step "=== ВОССТАНОВЛЕНИЕ КОНФИГУРАЦИЙ ==="
check_user "$USER"

if [ ! -d "$CONFIGS_DIR" ]; then
    error "Папка с конфигами не найдена: $CONFIGS_DIR"
    info "Создайте папку configs и поместите туда ваши конфиги"
    exit 1
fi

info "Восстановление файлов из $CONFIGS_DIR в реальный домашний каталог: $REAL_USER_HOME"

# Безопасная обработка файлов с пробелами в именах
find "$CONFIGS_DIR" -type f -print0 | while IFS= read -r -d '' source_file; do
    # Получаем относительный путь
    relative_path="${source_file#$CONFIGS_DIR/}"
    
    # Автоматическое добавление точки к файлам в корне (dotfiles)
    if [[ "$relative_path" != */* ]] && [[ "$relative_path" != .* ]]; then
        target_name=".$relative_path"
    else
        target_name="$relative_path"
    fi
    
    destination_path="$REAL_USER_HOME/$target_name"
    backup_info=""
    
    # Создание бэкапа существующего файла или ссылки
    if [ -e "$destination_path" ] || [ -L "$destination_path" ]; then
        backup_name="$destination_path.bak_$(date +%Y%m%d_%H%M%S)"
        if mv "$destination_path" "$backup_name" 2>/dev/null; then
            backup_info=" (бэкап: $(basename "$backup_name"))"
        else
            backup_info=" (⚠️ ошибка создания бэкапа)"
        fi
    fi
    
    # Создание папки назначения (например, ~/.config/Code/User/)
    mkdir -p "$(dirname "$destination_path")"
    
    # Копирование файла
    if cp "$source_file" "$destination_path"; then
        echo -e "  [+] $target_name... готово${backup_info}"
    else
        error "  [X] Ошибка копирования $relative_path"
    fi
done

info "✅ Восстановление конфигураций успешно завершено!"
warn "🛑 Перезапустите терминал или выполните: source ~/.bashrc"