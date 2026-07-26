#!/bin/bash
#
# Этот скрипт автоматически устанавливает основное ПО для разработки на Ubuntu.
# Запустите его с правами sudo или от имени root.
#
set -e

 APT_PACKAGES="build-essential git curl wget software-properties-common apt-transport-https ca-certificates python3-pip python3-venv"
 NODE_LTS_SETUP_URL="https://deb.nodesource.com/setup_lts.x"

echo "--- Шаг 1: Обновление системы ---"
sudo apt update && sudo apt upgrade -y

echo "--- Шаг 2: Установка базовых утилит ---"
sudo apt install -y $APT_PACKAGES

echo "--- Шаг 3: Установка Golang ---"
# ОБНОВЛЕНИЕ: Добавлен `head -n 1` для получения только первой строки с версией.
GO_VERSION=$(curl -s "https://go.dev/VERSION?m=text" | head -n 1)
echo "Установка Go версии ${GO_VERSION}..."
wget -q --show-progress "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf /tmp/go.tar.gz
rm /tmp/go.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/go.sh
export PATH=$PATH:/usr/local/go/bin
echo "Go ${GO_VERSION} успешно установлен в /usr/local/go."

echo "--- Шаг 4: Установка Docker и Docker Compose ---"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
echo "Docker и Docker Compose установлены."

echo "--- Шаг 5: Установка Python и Pip ---"
sudo apt install -y python3-pip python3-venv
echo "Python и Pip установлены."

echo "--- Шаг 6: Установка Node.js и npm (LTS) ---"
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs
echo "Node.js и npm установлены."

 echo -e "\n\n✅ Установка программ завершена!"
 echo -e "\n\033[1;33m[ВАЖНО] Чтобы изменения вступили в силу, выполните одно из действий:\033[0m"
 echo -e "\033[1;33m1. Перезайдите в систему (выйдите и войдите снова).\033[0m"
 echo -e "\033[1;33m2. Или выполните в терминале команду: \033[1;32msource /etc/profile\033[0m\033[0m"
 EOF

# Делаем сгенерированный скрипт исполняемым
chmod +x "$SETUP_DIR/install_software.sh"
echo "  ✅ Скрипт install_software.sh создан."

# --- ШАГ 3: Генерация скрипта для восстановления настроек (restore_configs.sh) ---

echo -e "\n[3/3] Генерируем скрипт для восстановления настроек (restore_configs.sh)..."

cat > "$SETUP_DIR/restore_configs.sh" << 'EOF'
#!/bin/bash
#
# Этот скрипт восстанавливает файлы конфигурации из папки ./configs
# в вашу домашнюю директорию (~/).
#
set -e

# Директория, где запущен этот скрипт
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
CONFIGS_DIR="$SCRIPT_DIR/configs"

echo "Восстанавливаем файлы конфигурации из $CONFIGS_DIR..."

# Рекурсивно обходим все файлы в папке configs
find "$CONFIGS_DIR" -type f | while read source_file; do
    # Определяем относительный путь файла
    relative_path="${source_file#$CONFIGS_DIR/}"
    destination_path="$HOME/$relative_path"

    echo -n "  - Восстанавливаем $relative_path..."

    # Создаем резервную копию существующего файла, если он есть
    if [ -e "$destination_path" ]; then
        mv "$destination_path" "$destination_path.bak_$(date +%F_%H-%M-%S)"
        echo -n " (создана резервная копия *.bak)..."
    fi

    # Создаем директорию назначения, если ее нет
    mkdir -p "$(dirname "$destination_path")"

    # Копируем файл
    cp "$source_file" "$destination_path"
    echo " Готово."
done

echo -e "\n✅ Восстановление настроек завершено!"
echo "Перезапустите ваш терминал, чтобы применить изменения."
