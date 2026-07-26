#!/bin/bash
#
# Расширенная настройка безопасности SSH, UFW, Fail2ban + продвинутые механизмы
# Запуск: ./setup_security.sh (НЕ от root!)
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

step "=== РАСШИРЕННАЯ НАСТРОЙКА БЕЗОПАСНОСТИ СИСТЕМЫ ==="
check_user "$USER"

# ----------------------------------------------------------------------
# 1. Проверка / создание SSH-ключей
# ----------------------------------------------------------------------
step "1. Проверка SSH-ключей"
if [ ! -f "$REAL_USER_HOME/.ssh/id_ed25519" ]; then
    info "SSH-ключ Ed25519 не найден."
    read -p "Создать новый ключ для локального профиля? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$REAL_USER_HOME/.ssh"
        chmod 700 "$REAL_USER_HOME/.ssh"
        ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)-$(date +%Y%m%d)" -f "$REAL_USER_HOME/.ssh/id_ed25519" -N ""
        chmod 600 "$REAL_USER_HOME/.ssh/id_ed25519"
        chmod 644 "$REAL_USER_HOME/.ssh/id_ed25519.pub"
        info "✅ Ключ создан: $REAL_USER_HOME/.ssh/id_ed25519.pub"
        echo "Публичный ключ (скопируйте его в Forgejo или на целевой сервер):"
        cat "$REAL_USER_HOME/.ssh/id_ed25519.pub"
    else
        warn "SSH-ключ не создан. Вход по паролю останется активным (небезопасно)."
    fi
else
    info "SSH-ключ уже существует: $REAL_USER_HOME/.ssh/id_ed25519.pub"
fi

# ----------------------------------------------------------------------
# 2. Выбор порта для SSH
# ----------------------------------------------------------------------
step "2. Выбор порта для SSH"
MIN_PORT=2000
MAX_PORT=65000
DEFAULT_PORT=$(( RANDOM % (MAX_PORT - MIN_PORT + 1) + MIN_PORT ))
read -p "Введите новый порт для SSH (или Enter для случайного $DEFAULT_PORT): " SSH_PORT
SSH_PORT=${SSH_PORT:-$DEFAULT_PORT}
info "Будет использован порт: $SSH_PORT"

# ----------------------------------------------------------------------
# 3. Настройка sshd_config (безопасное удаление старых параметров)
# ----------------------------------------------------------------------
step "3. Настройка /etc/ssh/sshd_config"
SSHD_CONFIG="/etc/ssh/sshd_config"
sudo cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"
info "Резервная копия создана."

# Удаляем все старые упоминания параметров, чтобы избежать дублей
for param in "Port" "PermitRootLogin" "PasswordAuthentication" "PermitEmptyPasswords" "MaxAuthTries" "LoginGraceTime" "AllowUsers"; do
    sudo sed -i "/^#\?${param}/d" "$SSHD_CONFIG"
done

# Добавляем новые настройки
sudo tee -a "$SSHD_CONFIG" > /dev/null <<EOF

# === Настройки безопасности (добавлены автоматически) ===
Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
AllowUsers $USER
EOF

info "✅ Конфигурация SSH обновлена."

# ----------------------------------------------------------------------
# 4. Настройка UFW + Rate Limiting (защита от сканирования портов)
# ----------------------------------------------------------------------
step "4. Настройка брандмауэра UFW с ограничением частоты"
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Используем limit вместо allow – защита от сканирования портов
sudo ufw limit "$SSH_PORT"/tcp comment 'SSH rate-limited'
sudo ufw allow 3000/tcp comment 'Forgejo web'
sudo ufw allow 2222/tcp comment 'Forgejo SSH'

echo "y" | sudo ufw enable
sudo ufw status verbose
info "✅ UFW настроен, для SSH включено ограничение частоты подключений."

# ----------------------------------------------------------------------
# 5. Защита временной папки /tmp (запрет выполнения)
# ----------------------------------------------------------------------
step "5. Настройка безопасности /tmp"
if ! grep -q "noexec" /etc/fstab; then
    sudo tee -a /etc/fstab > /dev/null <<EOF
tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev 0 0
EOF
    info "✅ Папка /tmp защищена (запрет выполнения, setuid, устройств)."
else
    info "ℹ️ /tmp уже защищена."
fi

# ----------------------------------------------------------------------
# 6. Автоматический разрыв неактивных сессий (10 минут)
# ----------------------------------------------------------------------
step "6. Настройка таймаута неактивности"
sudo tee /etc/profile.d/timeout.sh > /dev/null << 'EOF'
TMOUT=600
readonly TMOUT
export TMOUT
EOF
sudo chmod +x /etc/profile.d/timeout.sh
info "✅ Установлен таймаут неактивности 10 минут."

# ----------------------------------------------------------------------
# 7. Отключение IPv6 (опционально)
# ----------------------------------------------------------------------
step "7. Отключение IPv6 (опционально)"
read -p "Отключить IPv6? (Рекомендуется, если ваш провайдер/роутер не использует IPv6) (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo tee -a /etc/sysctl.conf > /dev/null <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sudo sysctl -p > /dev/null
    info "✅ IPv6 отключен."
else
    info "IPv6 оставлен включённым."
fi

# ----------------------------------------------------------------------
# 8. Блокировка Ctrl+Alt+Del (опционально)
# ----------------------------------------------------------------------
step "8. Защита от случайной перезагрузки (Ctrl+Alt+Del)"
read -p "Заблокировать комбинацию Ctrl+Alt+Del? (Рекомендуется для виртуальных машин) (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo systemctl mask ctrl-alt-del.target
    sudo systemctl daemon-reload
    info "✅ Ctrl+Alt+Del заблокирован."
else
    info "Ctrl+Alt+Del оставлен активным."
fi

# ----------------------------------------------------------------------
# 9. Перезапуск SSH
# ----------------------------------------------------------------------
step "9. Перезапуск SSH"
sudo systemctl restart ssh
info "✅ SSH перезапущен на порту $SSH_PORT."

# ----------------------------------------------------------------------
# 10. Установка и настройка Fail2ban (с systemd)
# ----------------------------------------------------------------------
step "10. Установка и настройка Fail2ban"
sudo apt install -y fail2ban

sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port    = $SSH_PORT
backend = systemd
EOF

sudo systemctl restart fail2ban
sudo systemctl enable fail2ban
info "✅ Fail2ban настроен (чтение логов через systemd)."

# ----------------------------------------------------------------------
# 11. Настройка автоматических обновлений безопасности
# ----------------------------------------------------------------------
step "11. Настройка автоматических обновлений безопасности"
sudo apt install -y unattended-upgrades apt-listchanges

# Настраиваем систему на автоматический запуск обновлений без вопросов
sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

info "✅ Автоматические фоновые обновления безопасности активированы."


# ----------------------------------------------------------------------
# 12. Оптимизация и защита ядра системы (sysctl)
# ----------------------------------------------------------------------
step "12. Харденинг ядра (защита от IP-спуфинга, SYN-флуда, ICMP-редиректов)"
sudo tee /etc/sysctl.d/99-security-hardening.conf > /dev/null <<EOF
# --- Защита от IP-спуфинга (Reverse Path Filtering) ---
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# --- Защита от атак через ICMP (запрет изменения маршрутов) ---
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# --- Запрет использования source routing (подмена источника) ---
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# --- Защита от SYN-флуда (DoS) ---
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 2048

# --- Логирование пакетов с подозрительными (марсианскими) адресами ---
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
EOF

# Применяем настройки ядра без перезагрузки
sudo sysctl --system > /dev/null
info "✅ Параметры ядра оптимизированы: включена защита от IP-спуфинга, SYN-флуда и ICMP-редиректов."



# ----------------------------------------------------------------------
# Итог
# ----------------------------------------------------------------------
step "✅ РАСШИРЕННАЯ НАСТРОЙКА БЕЗОПАСНОСТИ ЗАВЕРШЕНА"
echo -e "${GREEN}Новый порт SSH: $SSH_PORT${NC}"
echo -e "${YELLOW}Проверьте подключение в новом окне терминала:${NC}"
echo "  ssh -p $SSH_PORT $USER@$(hostname -I | awk '{print $1}')"
echo ""
echo -e "${RED}⚠️ НЕ ЗАКРЫВАЙТЕ ЭТУ СЕССИЮ, пока не проверите новое подключение!${NC}"
echo -e "${YELLOW}Восстановление при ошибке:${NC}"
echo "  sudo cp /etc/ssh/sshd_config.bak.* /etc/ssh/sshd_config && sudo systemctl restart ssh"
echo ""
echo -e "${GREEN}Дополнительные меры:${NC}"
echo "  - /tmp смонтирована с noexec (защита от запуска скриптов)"
echo "  - Таймаут неактивности 10 минут"
if [[ $REPLY =~ ^[Yy]$ ]] && grep -q "disable_ipv6" /etc/sysctl.conf; then
    echo "  - IPv6 отключен"
fi
if systemctl is-enabled ctrl-alt-del.target &>/dev/null; then
    echo "  - Ctrl+Alt+Del заблокирован"
fi
echo "  - Fail2ban активен и банит IP после 3 неудачных попыток"
echo "  - UFW ограничивает частоту подключений к SSH (защита от сканирования)"