#!/bin/bash
#
# Исправленный скрипт настройки безопасности SSH, UFW, Fail2ban
# Запуск: ./setup_security.sh (НЕ от root!)
#

# Подтягиваем общие функции из нашей библиотеки путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

step "=== НАСТРОЙКА БЕЗОПАСНОСТИ SSH И СИСТЕМЫ ==="
check_user "$USER"

# ---- Проверка наличия SSH-ключей ----
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
        info "Публичный ключ для копирования на целевой сервер (или в Forgejo):"
        cat "$REAL_USER_HOME/.ssh/id_ed25519.pub"
        echo ""
    else
        warn "⚠️ SSH-ключ не создан."
    fi
else
    info "ℹ️ SSH-ключ уже существует: $REAL_USER_HOME/.ssh/id_ed25519.pub"
fi

# ---- Генерация или выбор порта ----
step "2. Выбор порта для SSH"
MIN_PORT=2000
MAX_PORT=65000
DEFAULT_PORT=$(( RANDOM % (MAX_PORT - MIN_PORT + 1) + MIN_PORT ))
read -p "Введите новый порт для SSH (или Enter для случайного $DEFAULT_PORT): " SSH_PORT
SSH_PORT=${SSH_PORT:-$DEFAULT_PORT}
info "Будет использован порт: $SSH_PORT"

# ---- Настройка sshd_config ----
step "3. Настройка /etc/ssh/sshd_config"
SSHD_CONFIG="/etc/ssh/sshd_config"
sudo cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"
info "Создана резервная копия конфигурации."

# ИСПРАВЛЕНО: Безопасный метод редактирования параметров через зачистку старых вхождений
# Это предотвращает дублирование строк и корректно отрабатывает при повторных запусках скрипта
sudo sed -i '/^#\?Port /d' "$SSHD_CONFIG"
sudo sed -i '/^#\?PermitRootLogin /d' "$SSHD_CONFIG"
sudo sed -i '/^#\?PasswordAuthentication /d' "$SSHD_CONFIG"
sudo sed -i '/^#\?PermitEmptyPasswords /d' "$SSHD_CONFIG"
sudo sed -i '/^#\?MaxAuthTries /d' "$SSHD_CONFIG"
sudo sed -i '/^#\?LoginGraceTime /d' "$SSHD_CONFIG"
sudo sed -i '/^#\?AllowUsers /d' "$SSHD_CONFIG"

# Чистое добавление актуальных настроек в конец файла
sudo tee -a "$SSHD_CONFIG" > /dev/null <<EOF

# Настройки безопасности добавленные автоматическим скриптом
Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
AllowUsers $USER
EOF

info "✅ Конфигурация SSH успешно обновлена."

# ---- Настройка UFW ----
step "4. Настройка брандмауэра UFW"
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow "$SSH_PORT"/tcp comment 'SSH custom port'
sudo ufw allow 3000/tcp comment 'Forgejo web'
sudo ufw allow 2222/tcp comment 'Forgejo SSH'
echo "y" | sudo ufw enable
sudo ufw status verbose

# ---- Перезапуск SSH ----
step "5. Перезапуск SSH"
sudo systemctl restart ssh
info "✅ Служба SSH перезапущена на порту $SSH_PORT."

# ---- Установка Fail2ban ----
step "6. Установка и настройка Fail2ban"
sudo apt install -y fail2ban

# ИСПРАВЛЕНО: Перевод Fail2ban на чтение из systemd-journald (актуально для Ubuntu 24.04/26.04)
# Параметры logpath и backend заменены на backend = systemd, что решает проблему отсутствия auth.log
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
info "✅ Fail2ban успешно настроен на чтение системного журнала для порта $SSH_PORT."

# ---- Итог ----
step "✅ НАСТРОЙКА БЕЗОПАСНОСТИ ЗАВЕРШЕНА"
echo -e "${GREEN}Новый порт SSH: $SSH_PORT${NC}"
echo -e "${YELLOW}Проверьте подключение в новом окне терминала вашего основного ПК:${NC}"
echo "  ssh -p $SSH_PORT $USER@$(hostname -I | awk '{print $1}')"
echo ""
echo -e "${RED}⚠️ ВНИМАНИЕ: Не закрывайте текущую сессию, пока не убедитесь, что новый порт работает!${NC}"
echo -e "${YELLOW}Если что-то пошло не так, восстановите конфигурацию прямо в этом окне:${NC}"
echo "  sudo cp /etc/ssh/sshd_config.bak.* /etc/ssh/sshd_config && sudo systemctl restart ssh"
echo ""
