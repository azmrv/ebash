#!/bin/bash
#
# Восстановление конфигураций из папки configs в домашний каталог
# Запуск: ./restore_configs.sh
#

source "$(dirname "$0")/scripts/common.sh"

step "ВОССТАНОВЛЕНИЕ КОНФИГУРАЦИЙ"
check_user "$USER"

if [ ! -d "$CONFIGS_DIR" ]; then
    error "Папка configs не найдена: $CONFIGS_DIR"
    exit 1
fi

info "Восстановление из $CONFIGS_DIR в $REAL_USER_HOME"

find "$CONFIGS_DIR" -type f -print0 | while IFS= read -r -d '' source_file; do
    relative_path="${source_file#$CONFIGS_DIR/}"
    # Добавляем точку для файлов в корне
    if [[ "$relative_path" != */* ]] && [[ "$relative_path" != .* ]]; then
        target_name=".$relative_path"
    else
        target_name="$relative_path"
    fi
    dest="$REAL_USER_HOME/$target_name"

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        backup_name="$dest.bak_$(date +%Y%m%d_%H%M%S)"
        mv "$dest" "$backup_name"
        echo "  Бэкап: $(basename "$backup_name")"
    fi

    mkdir -p "$(dirname "$dest")"
    cp "$source_file" "$dest"
    echo "  Восстановлен: $target_name"
done

info "✅ Конфигурации восстановлены."
warn "Перезапустите терминал или выполните 'source ~/.bashrc'."