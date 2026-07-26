# Перейдите в папку setup
cd /home/newdevru/Yandex.Disk/nix/setup

# Удалите старый скрипт (если есть)
rm -f install_software.sh

# Создайте исправленный скрипт
cat > install_software.sh << 'EOF'
[вставьте содержимое исправленного скрипта выше]
EOF

# Сделайте исполняемым
chmod +x install_software.sh

# Или обновите раздельные скрипты
# [вставьте содержимое исправленных install_system.sh и install_dev_tools.sh]
