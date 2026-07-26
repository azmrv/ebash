#!/bin/bash
#
# Исправленный скрипт установки системного ПО для Ubuntu 24.04 LTS / 26.04 LTS
# Запуск: sudo ./install_system_software.sh
#
# Подтягиваем общие функции из common.sh
source "$(dirname "$0")/scripts/common.sh"

step "=== УСТАНОВКА СИСТЕМНОГО ПО ДЛЯ UBUNTU ==="
# Проверяем, что скрипт запущен с правами sudo
check_sudo

step "1. Обновление индекса пакетов и системы"
apt update && apt upgrade -y

step "2. Установка базовых утилит и инструментов сборки"
# Используем python3-venv вместо python3-pip (PEP 668)
# Добавляем htop и tree через apt (не через snap)
APT_PACKAGES="git curl wget software-properties-common apt-transport-https ca-certificates python3 python3-dev python3-venv build-essential cmake htop tree"
apt install -y $APT_PACKAGES

step "3. Установка Docker и Docker Compose"
install -m 0755 -d /etc/apt/keyrings
# Флаг --yes предотвращает зависание при повторном запуске
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Определяем кодовое имя системы (noble, resolute и т.д.)
VERSION_CODENAME=$(source /etc/os-release && echo "$VERSION_CODENAME")

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $VERSION_CODENAME stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Добавляем реального пользователя (вызвавшего sudo) в группу docker
if [ -n "$SUDO_USER" ]; then
    usermod -aG docker "$SUDO_USER"
    info "✅ Docker установлен. Пользователь $SUDO_USER добавлен в группу docker."
else
    warn "⚠️ Переменная \$SUDO_USER не найдена. Добавьте пользователя в группу docker вручную."
fi

step "4. Установка утилит работы с архивами и сетью"
apt install -y net-tools zip unzip p7zip-full

info "✅ Установка системного ПО успешно завершена!"
warn "🛑 ВАЖНО: ПЕРЕЗАГРУЗИТЕ СИСТЕМУ (команда: sudo reboot) для применения прав группы Docker."