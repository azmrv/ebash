#!/bin/bash
#
# Установка и настройка Forgejo Runner (Docker-версия)
# Запуск: ./setup_forgejo_runner.sh (НЕ от root!)
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

step "=== УСТАНОВКА FORGEJO RUNNER (DOCKER) ==="
check_user "$USER"

# ---- Проверка Docker ----
step "1. Проверка Docker"
if ! command -v docker &> /dev/null; then
    error "❌ Docker не найден. Сначала установите Docker через пункт 1 меню."
    exit 1
fi
if ! docker compose version &> /dev/null; then
    error "❌ Docker Compose не найден. Проверьте установку Docker."
    exit 1
fi
info "✅ Docker и Docker Compose найдены."

# ---- Запрос параметров ----
step "2. Параметры подключения к Forgejo"
read -p "Введите URL Forgejo (например, http://192.168.0.103:3000): " FORGEJO_URL
FORGEJO_URL=${FORGEJO_URL:-http://192.168.0.103:3000}

read -p "Введите токен регистрации раннера (из админки → Действия → Раннеры): " RUNNER_TOKEN
if [ -z "$RUNNER_TOKEN" ]; then
    error "❌ Токен обязателен для регистрации раннера!"
    exit 1
fi

read -p "Введите имя раннера (по умолчанию: local-runner): " RUNNER_NAME
RUNNER_NAME=${RUNNER_NAME:-local-runner}

info "Параметры:"
echo "  Forgejo URL: $FORGEJO_URL"
echo "  Имя раннера: $RUNNER_NAME"

# ---- Создание структуры каталогов ----
step "3. Создание конфигурации раннера"
RUNNER_DIR="$HOME/forgejo-runner"
mkdir -p "$RUNNER_DIR/data"
cd "$RUNNER_DIR" || error "Не удалось перейти в $RUNNER_DIR"

if [ -f "docker-compose.yml" ]; then
    warn "⚠️ Файл docker-compose.yml уже существует."
    read -p "Перезаписать конфигурацию? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "ℹ️ Установка отменена пользователем."
        exit 0
    fi
fi

# ---- Генерация config.yaml (обязательно для официального образа) ----
info "Генерация системного config.yaml..."
cat > config.yaml <<EOF
runner:
  capacity: 2
  timeout: 2h
  shutdown_timeout: 30s

container:
  network: "bridge"
  privileged: true
  valid_volumes: []

host:
  workdir: "/workspace"
EOF

# ---- Генерация docker-compose.yml (официальный образ + двухэтапная регистрация) ----
info "Генерация docker-compose.yml..."
cat > docker-compose.yml <<EOF
services:
  runner:
    image: codeberg.org/forgejo/forgejo-runner:4
    container_name: forgejo-runner
    restart: unless-stopped
    depends_on:
      - register
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./config.yaml:/config.yaml:ro
      - ./data:/data
    command: forgejo-runner daemon --config /config.yaml

  register:
    image: codeberg.org/forgejo/forgejo-runner:4
    container_name: forgejo-runner-register
    volumes:
      - ./data:/data
    environment:
      - FORGEJO_INSTANCE_URL=$FORGEJO_URL
      - FORGEJO_RUNNER_REGISTRATION_TOKEN=$RUNNER_TOKEN
      - FORGEJO_RUNNER_NAME=$RUNNER_NAME
      - FORGEJO_RUNNER_LABELS=ubuntu-latest:docker://node:20-bullseye,docker:docker://docker:stable
    command: sh -c "[ -f /data/.runner ] || forgejo-runner register --no-interactive"
EOF

info "✅ Конфигурационные файлы созданы в $RUNNER_DIR"

# ---- Запуск раннера ----
step "4. Запуск контейнеров CI/CD"
docker compose up -d

info "Ожидание инициализации и регистрации раннера..."
sleep 5

# ---- Проверка статуса с выводом логов при ошибке (исправлено на docker inspect) ----
info "Проверка статуса демона раннера..."
if [ "$(docker inspect -f '{{.State.Running}}' forgejo-runner 2>/dev/null)" = "true" ]; then
    info "✅ Контейнер Forgejo Runner успешно запущен и работает."
else
    error "❌ Контейнер не смог запуститься! Вывод последних логов для диагностики:"
    echo -e "${RED}----------------------------------------------------------${NC}"
    docker compose logs --tail=20
    echo -e "${RED}----------------------------------------------------------${NC}"
    error "Проверьте правильность введенного URL и регистрационного токена."
    exit 1
fi

# ---- Вывод информации ----
step "✅ НАСТРОЙКА FORGEJO RUNNER ЗАВЕРШЕНА"
echo -e "${GREEN}Раннер успешно развёрнут и привязан к серверу: $FORGEJO_URL${NC}"
echo -e "${YELLOW}Зарегистрированные метки (labels) для сборки:${NC}"
echo "  - ubuntu-latest (контейнер node:20-bullseye)"
echo "  - docker (контейнер docker:stable для сборки собственных образов)"
echo ""
echo "Управление раннером:"
echo "  Перейти в папку: cd $RUNNER_DIR"
echo "  Просмотр логов: docker compose logs -f"
echo "  Остановка:      docker compose down"
echo "  Перезапуск:     docker compose restart"
echo ""
echo "Проверьте статус 'Idle' в панели управления: Админка → Действия → Раннеры"
warn "Если раннер не отображается, проверьте логи: docker compose logs register"