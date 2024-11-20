#!/bin/bash

# Логотип команды
#show_logotip() {
#    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/name.sh)
#}
# Цвета для текста
TERRACOTTA='\033[38;5;208m'
LIGHT_BLUE='\033[38;5;117m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'
PURPLE='\033[0;35m'

# Функции для форматирования текста
function show() {
    echo -e "${TERRACOTTA}${BOLD}$1${NC}"
}

function show_blue() {
    echo -e "${LIGHT_BLUE}$1${NC}"
}

function show_war() {
    echo -e "${RED}$1${NC}"
}

function show_purple() {
    echo -e "${PURPLE}$1${NC}"
}

# Вывод названия узла
#show_name() {
#    echo ""
#    echo -e "\033[1;35mINK chain 11111111111node\033[0m"
#    echo ""
#}

# ASCII-арт
#echo "----------------------------------------------------------------------"
show_purple '░░░░░▀█▀░█░▄▀░█▄░░█░░░█▀▀█░█░░█░█▀▀█░▀█▀░█▄░░█░░░█▄░░█░█▀▀█░█▀▀▄░█▀▀▀░░░░░'
show_purple '░░░░░░█░░█▀▄░░█░█░█░░░█░░░░█▀▀█░█▄▄█░░█░░█░█░█░░░█░█░█░█░░█░█░░█░█▀▀▀░░░░░'
show_purple '░░░░░▄█▄░█░░█░█░░▀█░░░█▄▄█░█░░█░█░░█░▄█▄░█░░▀█░░░█░░▀█░█▄▄█░█▄▄▀░█▄▄▄░░░░░'
#echo "----------------------------------------------------------------------"

# Функция для подтверждения действия
confirm() {
    local prompt="$1"
    echo -e "$prompt [y/n, Enter = yes]: "  # Выводим вопрос с цветом
    read choice  # Читаем ввод пользователя
    case "$choice" in
        ""|y|Y|yes|Yes)  # Пустой ввод или "да"
            return 0  # Подтверждение действия
            ;;
        n|N|no|No)  # Любой вариант "нет"
            return 1  # Отказ от действия
            ;;
        *)
            echo -e "\033[1;35mПожалуйста, введите y или n.\033[0m"
            confirm "$prompt"  # Повторный запрос, если ответ не распознан
            ;;
    esac
}

ink_dir="$HOME/ink/node"

# Функция для установки зависимостей
install_dependencies() {
    if confirm "\033[1;35mУстановить необходимые пакеты и зависимости?\033[0m"; then
        bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/admin/docker.sh)
        sudo apt install jq net-tools
    else
        echo -e "\033[1;31mОтменено.\033[0m"
    fi
}

clone_rep() {
    echo "Клонирование репозитория Ink node..."
    git clone https://github.com/inkonchain/node.git "$ink_dir" || {
        echo "Ошибка при клонировании репозитория!"
        exit 1
    }
}

# Функция установки ноды
install_node() {
    if confirm "Скачать репозиторий узла?"; then
        clone_rep
    else 
        echo "Пропущено"
    fi

    echo "Переход в директорию узла..."
    cd "$ink_dir" || {
        echo "Ошибка: директория node не найдена!"
        exit 1
    }

    # Массив с необходимыми портами
    required_ports=("8525" "8526" "30313" "7301" "9535" "9232" "7300" "6060")

    # Проверка доступности портов
    for port in "${required_ports[@]}"; do
        if ss -tuln | grep -q ":$port "; then
            echo "Порт $port: ЗАНЯТ"
            exit 1
        else
            echo "Порт $port: СВОБОДЕН"
        fi
    done

    # Проверка и замена переменных в .env.ink-sepolia
    env_file="$ink_dir/.env.ink-sepolia"
    if [ -f "$env_file" ]; then
        echo "Файл $env_file найден. Замена переменных..."
        read -p "Введите URL для OP_NODE_L1_ETH_RPC [Enter = https://ethereum-sepolia-rpc.publicnode.com]: " input_rpc
        OP_NODE_L1_ETH_RPC=${input_rpc:-https://ethereum-sepolia-rpc.publicnode.com}

        read -p "Введите URL для OP_NODE_L1_BEACON [Enter = https://ethereum-sepolia-beacon-api.publicnode.com]: " input_beacon
        OP_NODE_L1_BEACON=${input_beacon:-https://ethereum-sepolia-beacon-api.publicnode.com}

        sed -i "s|^OP_NODE_L1_ETH_RPC=.*|OP_NODE_L1_ETH_RPC=$OP_NODE_L1_ETH_RPC|" "$env_file"
        sed -i "s|^OP_NODE_L1_BEACON=.*|OP_NODE_L1_BEACON=$OP_NODE_L1_BEACON|" "$env_file"
        echo "Переменные успешно обновлены"
    else
        echo "Ошибка: файл $env_file не найден!"
        exit 1
    fi

    # Проверка и замена портов в docker-compose.yml
    compose_file="$ink_dir/docker-compose.yml"
    if [ -f "$compose_file" ]; then
        echo "Файл $compose_file найден. Замена портов..."
        sed -i 's|8545:|8525:|g' "$compose_file"
        sed -i 's|8546:|8526:|g' "$compose_file"
        sed -i 's|30303:|30313:|g' "$compose_file"
        sed -i 's|9545:|9535:|g' "$compose_file"
        sed -i 's|9222:|9232:|g' "$compose_file"
        echo "Порты успешно заменены."
    else
        echo "Ошибка: файл $compose_file не найден!"
        exit 1
    fi

    # Запуск скрипта установки
    if [ -x "./setup.sh" ]; then
        echo "Запускаю скрипт установки..."
        ./setup.sh
        echo "Удаление архива снепшота"
        rm -f *.tar.gz
    else
        echo "Ошибка: setup.sh не найден или не является исполняемым!"
        exit 1
    fi

    # Фикс проблемы с правами на доступ к директории
    sudo mkdir -p "$ink_dir/geth"
    sudo chown -R 1000:1000 "$ink_dir/geth"
    sudo chmod -R 755 "$ink_dir/geth"

    # Запуск Docker Compose
    echo "Запуск ноды..."
    docker compose up -d || {
        echo "Перезапуск Docker Compose..."
        docker compose down && docker compose up -d || {
            echo "Ошибка при повторном запуске Docker Compose!"
            exit 1
        }
    }
    echo "Установка и запуск выполнены успешно!"
}

# Удаление ноды
delete() {
    echo "Остановка и удаление контейнеров"
    cd "$ink_dir" && docker compose down 
    if confirm "Удалить директорию и все данные?"; then
        cd ~ && rm -rf "$ink_dir"
        echo "Успешно удалено." 
    else
        echo "Не удалено."
    fi
}

# Меню с командами
show_menu() {
   # show_logotip
   # show_name
    echo -en "${TERRACOTTA}${BOLD}Выберите действие: ${NC}\n"
    echo -en "${TERRACOTTA}1. Установить ноду ${NC}\n"
    echo -en "${TERRACOTTA}2. Просмотр логов ноды ${NC}\n"
    echo -en "${TERRACOTTA}3. Тестовый запрос к ноде ${NC}\n"
    echo -en "${TERRACOTTA}4. Проверка контейнеров ${NC}\n"
    echo -en "${TERRACOTTA}8. Вывод приватного ключа ${NC}\n"
    echo -en "${TERRACOTTA}9. Удаление ноды ${NC}\n"
    echo -en "${TERRACOTTA}0. Выход ${NC}\n"
    echo ""
}

menu() {
    case $1 in
        1)  
            install_dependencies
            install_node 
            ;;
        2)  cd "$ink_dir" && docker compose logs -f --tail 20 ;;
        3)  curl -d '{"id":1,"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false]}' -H "Content-Type: application/json" http://localhost:8525 | jq ;;
        4)  cd ~/node && docker compose ps -a ;;
        8)  cat "$ink_dir/var/secrets/jwt.txt" && echo "" ;;
        9)  delete ;;
        0)  exit 0 ;;
        *)  echo "Неверный выбор, попробуйте снова." ;;
    esac
}

while true; do
    show_menu
    read -p "Ваш выбор: " choice
    menu "$choice"
done
