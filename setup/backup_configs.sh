#!/bin/bash
#
# Создание резервной копии текущих конфигураций в папку configs
# Запуск: ./backup_configs.sh (НЕ от root!)
#

source "$(dirname "$0")/scripts/common.sh"

step "СОЗДАНИЕ БЭКАПА КОНФИГУРАЦИЙ"
check_user "$USER"

CONFIGS_DIR="$REAL_USER_HOME/configs"   # если папка configs в домашней

# Список файлов/папок для бэкапа (относительно ~/)
FILES_TO_BACKUP=(
    ".bashrc"
    ".gitconfig"
    ".profile"
    ".zshrc"
    ".ssh/config"
    ".config/Code/User/settings.json"
    ".config/Code/User/keybindings.json"
    ".local/share/godot/"
)

mkdir -p "$CONFIGS_DIR"
info "Копирование конфигов в $CONFIGS_DIR"

for item in "${FILES_TO_BACKUP[@]}"; do
    source_path="$REAL_USER_HOME/$item"
    if [ -e "$source_path" ]; then
        # Убираем точку у файлов в корне (для хранения в репозитории без точки)
        if [[ "$item" != */* ]] && [[ "$item" == .* ]]; then
            target_name="${item#.}"
        else
            target_name="$item"
        fi
        dest_path="$CONFIGS_DIR/$target_name"
        mkdir -p "$(dirname "$dest_path")"
        if [ -d "$source_path" ]; then
            cp -R "$source_path" "$dest_path"
        else
            cp "$source_path" "$dest_path"
        fi
        info "  Скопировано: $item -> $target_name"
    else
        warn "  Пропущено (не найдено): $item"
    fi
done

info "✅ Бэкап конфигураций создан в $CONFIGS_DIR"
warn "Проверьте содержимое папки configs и при необходимости добавьте в Git."