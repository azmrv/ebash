#!/bin/bash
#
# Развёртывание Forgejo через Docker Compose с ограничениями ресурсов
# Запуск: ./deploy_forgejo.sh (НЕ от root!)
#

source "$(dirname "$0")/scripts/common.sh"

step "РАЗВЁРТЫВАНИЕ FORGEJO"
check_user "$USER"

if ! command -v docker &> /dev/null; then
    error "Docker не найден! Сначала установите Docker через пункт 1 меню."
fi

FORGEJO_DIR="$HOME/forgejo-server"
mkdir -p "$FORGEJO_DIR"
cd "$FORGEJO_DIR"

if [ ! -f "docker-compose.yml" ]; then
    info "Создание docker-compose.yml с ограничениями CPU/памяти..."
    cat > docker-compose.yml << 'EOF'
networks:
  forgejo:
    external: false

services:
  server:
    image: codeberg.org/forgejo/forgejo:10
    container_name: forgejo
    restart: always
    networks:
      - forgejo
    volumes:
      - ./forgejo-data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "3000:3000"
      - "2222:22"
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4096M
EOF
else
    info "docker-compose.yml уже существует."
fi

info "Запуск Forgejo..."
docker compose up -d

# Принудительно применяем ограничения (на случай, если deploy не сработал)
docker update --cpus=2 --memory=4096M forgejo 2>/dev/null || true

sleep 3
IP=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n1)
[ -z "$IP" ] && IP="localhost"

info "✅ Forgejo запущен!"
echo -e "${GREEN}Откройте в браузере: http://$IP:3000${NC}"
echo -e "${YELLOW}При первом входе создайте администратора и укажите реальный IP в настройках домена.${NC}"
echo ""
info "Управление:"
echo "  Остановить: docker compose down"
echo "  Логи:       docker compose logs -f"