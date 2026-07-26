#!/bin/bash
#
# Системная установка: обновления, Docker, базовые утилиты, безопасность
# Запуск: sudo ./install_system.sh
#

source "$(dirname "$0")/scripts/common.sh"

step "=== СИСТЕМНАЯ УСТАНОВКА И НАСТРОЙКА БЕЗОПАСНОСТИ ==="
check_sudo

step "1. Обновление системы"
apt update && apt upgrade -y

step "2. Установка базовых системных пакетов"
APT_PACKAGES="build-essential git curl wget software-properties-common apt-transport-https ca-certificates python3 python3-dev python3-venv cmake htop tree net-tools zip unzip"
apt install -y $APT_PACKAGES

step "3. Установка Docker"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

VERSION_CODENAME=$(source /etc/os-release && echo "$VERSION_CODENAME")
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

if [ -n "$SUDO_USER" ]; then
    usermod -aG docker "$SUDO_USER"
    info "Пользователь $SUDO_USER добавлен в группу docker"
fi

step "4. Настройка базовой безопасности"

# UFW – брандмауэр
info "Настройка UFW..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp      # SSH
ufw allow 3000/tcp    # Forgejo web
ufw allow 2222/tcp    # Forgejo SSH
echo "y" | ufw enable

# Автоматические обновления безопасности
info "Настройка автоматических обновлений..."
apt install -y unattended-upgrades apt-listchanges
dpkg-reconfigure -plow unattended-upgrades

# SSH hardening – запрет root-логина
if [ -f /etc/ssh/sshd_config ]; then
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config || echo "PermitRootLogin no" | tee -a /etc/ssh/sshd_config
    systemctl restart ssh
    info "SSH настроен (PermitRootLogin no)"
fi

info "✅ Системная установка и настройка безопасности завершены."
warn "Перезагрузите систему: sudo reboot"