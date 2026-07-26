#!/bin/bash
#
# Установка дополнительных полезных утилит и Git LFS
# Запуск: ./install_software.sh (не требует sudo, но использует sudo внутри)
#

source "$(dirname "$0")/scripts/common.sh"

step "УСТАНОВКА ДОПОЛНИТЕЛЬНЫХ УТИЛИТ"
check_user "$USER"

sudo apt update
sudo apt install -y far2l bat exa fzf ripgrep fd-find tmux jq httpie tldr git-lfs

# Настройка алиасов
if ! grep -q "alias bat=" ~/.bashrc; then
    cat >> ~/.bashrc << 'EOF'
# Алиасы для современных утилит
alias bat='batcat'
alias fd='fdfind'
alias ls='exa --long --header --git'
alias grep='rg'
alias find='fdfind'
EOF
    info "Алиасы добавлены в ~/.bashrc"
fi

# Настройка fzf
if [ -f /usr/share/doc/fzf/examples/completion.bash ] && ! grep -q "fzf" ~/.bashrc; then
    cat /usr/share/doc/fzf/examples/completion.bash >> ~/.bashrc
    cat /usr/share/doc/fzf/examples/key-bindings.bash >> ~/.bashrc
    info "Настройки fzf добавлены в ~/.bashrc"
fi

# Инициализация Git LFS
git lfs install --skip-repo
info "Git LFS инициализирован глобально."

info "✅ Дополнительные утилиты и Git LFS установлены."
warn "Перезапустите терминал или выполните 'source ~/.bashrc' для применения алиасов."