#!/bin/bash
#
# Исправленный скрипт настройки OpenSSH Certificate Authority (CA)
# Запуск: ./setup_ssh_ca.sh (НЕ от root! Скрипт сам вызовет sudo внутри)
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

step "=== НАСТРОЙКА SSH CERTIFICATE AUTHORITY (CA) ==="
# Защита: проверяем, что скрипт запущен от обычного пользователя
check_user "$USER"

CA_DIR="/etc/ssh/ca"
CA_KEY="$CA_DIR/ca_key"
CA_PUB="$CA_DIR/ca_key.pub"
SSHD_CONFIG="/etc/ssh/sshd_config"
USER_KEY="$REAL_USER_HOME/.ssh/id_ed25519"
USER_CERT="$USER_KEY-cert.pub"

# ---- 1. Создание CA-ключей ----
step "1. Создание CA-ключей (если отсутствуют)"
if [ ! -f "$CA_KEY" ]; then
    sudo mkdir -p "$CA_DIR"
    sudo ssh-keygen -t ed25519 -f "$CA_KEY" -C "SSH CA for $(hostname)" -N ""
    sudo chmod 600 "$CA_KEY"
    sudo chmod 644 "$CA_PUB"
    info "✅ Системные CA-ключи успешно созданы в $CA_DIR/"
else
    info "ℹ️ Системные CA-ключи уже существуют."
fi

# ---- 2. Настройка sshd_config для доверия к CA ----
step "2. Настройка SSH-сервера для доверия к CA"
# Добавляем TrustedUserCAKeys, если ещё нет
if ! grep -q "^TrustedUserCAKeys" "$SSHD_CONFIG"; then
    echo "TrustedUserCAKeys $CA_PUB" | sudo tee -a "$SSHD_CONFIG" > /dev/null
else
    sudo sed -i "s|^TrustedUserCAKeys.*|TrustedUserCAKeys $CA_PUB|" "$SSHD_CONFIG"
fi

# Перезапускаем SSH для применения настроек
sudo systemctl restart ssh
info "✅ SSH-сервер успешно настроен на приём сертификатов, подписанных этим CA."

# ---- 3. Подпись пользовательского ключа ----
step "3. Подпись пользовательского SSH-ключа"
if [ ! -f "$USER_KEY" ]; then
    error "❌ Пользовательский ключ не найден по пути: $USER_KEY."
    error "Пожалуйста, сначала запустите скрипт №7 (setup_security.sh) для его генерации."
    exit 1
fi

# Проверяем, есть ли уже сертификат
if [ -f "$USER_CERT" ]; then
    read -p "Сертификат уже существует. Переподписать и обновить? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "ℹ️ Переподписание отменено пользователем."
        exit 0
    fi
fi

# Запрашиваем срок действия (по умолчанию 30 дней)
read -p "Введите срок действия сертификата в днях (по умолчанию 30): " VALIDITY_DAYS
VALIDITY_DAYS=${VALIDITY_DAYS:-30}

info "Генерация и подпись сертификата..."
# ИСПРАВЛЕНО: Один чистый вызов подписи. Используем формат времени +Nd (например +30d).
# Флаг --yes убирает интерактивные вопросы о перезаписи.
sudo ssh-keygen -s "$CA_KEY" -I "$(whoami)@$(hostname)-$(date +%Y%m%d)" -n "$USER" -V "+${VALIDITY_DAYS}d" "$USER_KEY"

# ИСПРАВЛЕНО: Корректно выставляем права владельца И группы пользователя-разработчика
sudo chown "$USER:$USER" "$USER_CERT"
chmod 644 "$USER_CERT"

info "✅ Сертификат успешно создан: $USER_CERT"
info "Срок действия: $VALIDITY_DAYS дней."



# ---- 4. Настройка клиента ----
step "4. Настройка клиента для автоматического использования сертификата"
CLIENT_CONFIG="$REAL_USER_HOME/.ssh/config"
mkdir -p "$(dirname "$CLIENT_CONFIG")"
touch "$CLIENT_CONFIG"


# Избегаем дублирования записей в ~/.ssh/config с помощью блочной проверки
if ! grep -q "IdentityFile $USER_KEY" "$CLIENT_CONFIG"; then
    cat >> "$CLIENT_CONFIG" <<EOF

# Настройки SSH CA для локальной машины
IdentityFile $USER_KEY
CertificateFile $USER_CERT
EOF
    info "✅ Клиентский файл конфигурации ~/.ssh/config успешно обновлён."
else
    info "ℹ️ Клиентский конфиг уже содержит необходимые инструкции для сертификата."
fi


# Перезапускаем SSH (определяем имя службы)
if systemctl list-units --full --all | grep -q "sshd.service"; then
    sudo systemctl restart sshd
elif systemctl list-units --full --all | grep -q "ssh.service"; then
    sudo systemctl restart ssh
else
    warn "Служба SSH не найдена. Убедитесь, что openssh-server установлен."
    warn "Установите: sudo apt install -y openssh-server"
fi

# ---- Итог ----
step "✅ НАСТРОЙКА SSH CA ЗАВЕРШЕНА"
echo -e "${GREEN}Теперь вы можете мгновенно подключаться к любым вашим серверам, доверяющим этому CA!${NC}"
# ИСПРАВЛЕНО: Использование переносимого синтаксиса вывода даты окончания действия
echo -e "${YELLOW}Ваш сертификат действителен в течение следующих $VALIDITY_DAYS дней.${NC}"
echo ""
echo "Чтобы дать доступ другому разработчику, выполните команду подписи его ключа:"
echo "  sudo ssh-keygen -s $CA_KEY -I 'user@host' -n 'имя_пользователя' -V +30d /путь/к/его/id_ed25519"
echo ""
