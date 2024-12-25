#!/bin/bash


# Проверка наличия curl и установка, если не установлен
if ! command -v curl &> /dev/null; then
    sudo apt update
    sudo apt install curl -y
fi
sleep 1

#!/bin/bash

# Цвета для текста
TERRACOTTA='\033[38;5;208m'
LIGHT_BLUE='\033[38;5;117m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'
PURPLE='\033[0;35m'
GRAY='\033[38;5;245m'

# Функции для форматирования текста
function show() {
    echo -e "${TERRACOTTA}$1${NC}"
}

function show_bold() {
    echo -en "${TERRACOTTA}${BOLD}$1${NC}"
}

function show_blue() {
    echo -e "${LIGHT_BLUE}$1${NC}"
}

function show_war() {
    echo -e "${RED}${BOLD}$1${NC}"
}

function show_purple() {
    echo -e "${PURPLE}$1${NC}"
}

function show_gray() {
    echo -e "${GRAY}$1${NC}"
}

# Логотип команды
show_logotip() {
    bash <(curl -s https://raw.githubusercontent.com/Nodateka/Basic/refs/heads/main/logo.sh)
}

# ASCII-арт
show_name() {
    echo ""
    show_gray '░░░░░░█▀▄▀█░█░░█░█░░░▀▀█▀▀░▀█▀░█▀▀█░█░░░░█▀▀▀░░░░░█▄░░█░█▀▀█░█▀▀▄░█▀▀▀░░░░░'
    show_gray '░░░░░░█░█░█░█░░█░█░░░░░█░░░░█░░█▄▄█░█░░░░█▀▀▀░░░░░█░█░█░█░░█░█░░█░█▀▀▀░░░░░'
    show_gray '░░░░░░█░░░█░▀▄▄▀░█▄▄█░░█░░░▄█▄░█░░░░█▄▄█░█▄▄▄░░░░░█░░▀█░█▄▄█░█▄▄▀░█▄▄▄░░░░░'
    echo ""
}

#Завершающее сообщение
gb_message() {
    echo ''
    show_bold "Спасибо что Вы с нами! Присоединяйся к Нодатеке, будем ставить ноды вместе!"
    echo ''
    echo -en "${TERRACOTTA}${BOLD}Telegram: ${NC}${LIGHT_BLUE}https://t.me/cryptotesemnikov/778${NC}\n"
    echo -en "${TERRACOTTA}${BOLD}Twitter: ${NC}${LIGHT_BLUE}https://x.com/nodateka${NC}\n"
    echo -e "${TERRACOTTA}${BOLD}YouTube: ${NC}${LIGHT_BLUE}https://www.youtube.com/@CryptoTesemnikov${NC}\n"
}

# Функция для подтверждения действия
confirm() {
    local prompt="$1"
    echo -en "$prompt [y/n, Enter = yes]: "  # Выводим вопрос с цветом
    read choice  # Читаем ввод пользователя
    case "$choice" in
        ""|y|Y|yes|Yes)  # Пустой ввод или "да"
            return 0  # Подтверждение действия
            ;;
        n|N|no|No)  # Любой вариант "нет"
            return 1  # Отказ от действия
            ;;
        *)
            show_war 'Пожалуйста, введите y или n.'
            confirm "$prompt"  # Повторный запрос, если ответ не распознан
            ;;
    esac
}

#Меню
show_menu() {
    show_logotip
    show_name
    show_bold 'Выберите действие:'
    echo ''
    actions=(
        "1. Установить ноду"
        "2. Проверка статуса ноды"
        "9. Удаление ноды"
        "0. Выход"
    )
    for action in "${actions[@]}"; do
        show "$action"
    done
}
#Установка зависимостей
install_dependencies() {
    show_bold 'Установка необходимых пакетов и зависимостей...'
    sudo apt update && sudo apt upgrade -y
}

#Проверрка архитектуры
arch_check() {
    show_bold 'Проверяем архитектуру системы...'
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        CLIENT_URL="https://cdn.app.multiple.cc/client/linux/x64/multipleforlinux.tar"
    elif [[ "$ARCH" == "aarch64" ]]; then
        CLIENT_URL="https://cdn.app.multiple.cc/client/linux/arm64/multipleforlinux.tar"
    else
        show_war 'Неподдерживаемая архитектура системы!'
        exit 1
    fi
}

#Установка ноды
install_node () {
    show "Скачиваем клиент с $CLIENT_URL..."
    wget $CLIENT_URL -O multipleforlinux.tar
    # Распаковываем архив
    show "Распаковка архива и выдача разрешений..."
    tar -xvf multipleforlinux.tar
    rm -f multipleforlinux.tar
    cd multipleforlinux
    chmod +x ./multiple-cli
    chmod +x ./multiple-node
    echo "PATH=\$PATH:$(pwd)" >> ~/.bash_profile
    source ~/.bash_profile
    # Запуск ноды
    show "Запускаем ноду multiple..."
    nohup ./multiple-node > output.log 2>&1 &    
    # Ввод Account ID и PIN
    read -p "$(show_bold 'Введите ваш Account ID: ') " IDENTIFIER
    read -p "$(show_bold 'Установите ваш PIN: ') " PIN
    # Привязка аккаунта    
    show "Привязываем аккаунт с ID: $IDENTIFIER и PIN: $PIN..."
    ./multiple-cli bind --bandwidth-download 100 --identifier $IDENTIFIER --pin $PIN --storage 200 --bandwidth-upload 100
}
# Проверка логов
check_logs () {    
    show "Проверяем статус ноды..."
    cd ~/multipleforlinux && ./multiple-cli status
}
# Удаление ноды
delete() {
    show "Остановка и удаление ноды..."
    show_bold 'Удалить директорию и все данные?'
    if confirm ''; then
        pkill -f multiple-node
        cd ~
        sudo rm -rf multipleforlinux
        show_bold "Нода успешно удалена" 
    else
        show_war "Не удалено."
    fi
}



menu() {
    case $1 in
        1)  install_dependencies
            arch_check
            install_node 
            ;;
            
        2)  check_logs;;

        9)  delete ;;
        0)  gb_message
            exit 0 ;;
        *)  show_war "Неверный выбор, попробуйте снова." ;;
    esac
}

while true; do
    show_menu
    show_bold 'Ваш выбор:'
    read choice
    menu "$choice"
done
