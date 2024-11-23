#!/bin/bash

# Цвета для текста
TERRACOTTA='\033[38;5;208m'
LIGHT_BLUE='\033[38;5;117m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'
PURPLE='\033[0;35m'
WHITE='\033[0;37m'

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

function show_white() {
    echo -e "${WHITE}$1${NC}"
}


# Логотип команды
show_logotip() {
    bash <(curl -s https://raw.githubusercontent.com/Nodateka/Basic/refs/heads/main/logo.sh)
}

# ASCII-арт
show_name() {
    echo ""
    show_white '░░░░░░░░█▀▀█░█▀▀█░█▄░░█░█▀▀▀░▀█▀░█░░█░█▀▄▀█░░░░█▄░░█░█▀▀█░█▀▀▄░█▀▀▀░░░░░░░░'
    show_white '░░░░░░░░▀▀▄▄░█░░█░█░█░█░█▀▀▀░░█░░█░░█░█░█░█░░░░█░█░█░█░░█░█░░█░█▀▀▀░░░░░░░░'
    show_white '░░░░░░░░█▄▄█░█▄▄█░█░░▀█░█▄▄▄░▄█▄░▀▄▄▀░█░░░█░░░░█░░▀█░█▄▄█░█▄▄▀░█▄▄▄░░░░░░░░'
    echo ""
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

son_dir="$HOME/soneium-node"
SERVER_IP=$(hostname -I | awk '{print $1}')

# Функция для установки зависимостей
install_dependencies() {
    show_bold 'Установить необходимые пакеты и зависимости?'
    if confirm ''; then
        bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/admin/docker.sh)
        sudo apt-get update -y && sudo apt upgrade -y && sudo apt-get install make build-essential unzip lz4 gcc git jq -y
        sudo apt install jq net-tools
    else
        show_war 'Отменено.'
    fi
}

clone_rep() {
    show 'Клонирование репозитория Ink node..'
    if [ -d "$son_dir" ]; then
        show "Репозиторий уже скачан. Пропуск клонирования."
    else
        git clone https://github.com/Soneium/soneium-node.git "$son_dir" || {
            show_war 'Ошибка: не удалось клонировать репозиторий.'
            exit 0
        }
    fi
}

# Функция установки ноды
install_node() {
    clone_rep
    show "Переход в директорию узла..."
    cd "$son_dir/minato"
    openssl rand -hex 32 > jwt.txt
    mv sample.env .env

    # Переход в директорию узла
    if cd "$son_dir/minato"; then
        show "Успешно перешли в директорию узла."
    else
        show_war "Ошибка: директория minato не найдена!"
        exit 1
    fi

    # Проверка и замена портов в docker-compose.yml
    compose_file="$son_dir/minato/docker-compose.yml"
    if [ -f "$compose_file" ]; then
        show "Файл $compose_file найден. Проверка и настройка портов..."
        docker compose down

        # Массив с портами и их назначением
        declare -A port_mapping=(
            ["8551"]="8551"
            ["8545"]="8545"
            ["8546"]="8546"
            ["30303"]="30303"
            ["9545"]="9545"
            ["9222"]="9222"
            ["6060"]="6060"
            ["7310"]="7310"
        )

        for original_port in "${!port_mapping[@]}"; do
            new_port=${port_mapping[$original_port]}
            show "Проверка порта $new_port..."

            # Если порт занят, запрос нового значения
            while ss -tuln | grep -q ":$new_port "; do
                show_war "Порт $new_port занят."
                read -p "$(echo -e "${TERRACOTTA}${BOLD}Введите новый порт для замены $original_port (текущий: $new_port): ${NC}")" user_port
                if [[ $user_port =~ ^[0-9]+$ && $user_port -ge 1 && $user_port -le 65535 ]]; then
                    if ss -tuln | grep -q ":$user_port "; then
                        show_war "Ошибка: введённый порт $user_port тоже занят. Попробуйте снова."
                    else
                        new_port=$user_port
                        break  # Выход из цикла, если порт свободен
                    fi
                else
                    show_war "Некорректный ввод. Попробуйте снова."
                fi
            done

            # Замена порта и IP в файле docker-compose.yml
            sed -i "s|<your_node_public_ip>|$SERVER_IP|g" "$compose_file"
            sed -i "s|$original_port:|$new_port:|g" "$compose_file"
            show_bold "Настройка порта завершена."
            echo ''
        done
    fi

    # Проверка и замена переменных в .env
    env_file="$son_dir/minato/.env"
    if [ -f "$env_file" ]; then
        show "Файл $env_file найден. Замена переменных..."
        read -p "$(echo -e "${TERRACOTTA}${BOLD}Введите URL для L1_URL ${NC}[Enter = https://ethereum-sepolia-rpc.publicnode.com]: ")" input_rpc
        L1_URL=${input_rpc:-https://ethereum-sepolia-rpc.publicnode.com}

        read -p "$(echo -e "${TERRACOTTA}${BOLD}Введите URL для L1_BEACON ${NC}[Enter = https://ethereum-sepolia-beacon-api.publicnode.com]: ")" input_beacon
        L1_BEACON=${input_beacon:-https://ethereum-sepolia-beacon-api.publicnode.com}

        sed -i "s|^L1_URL=.*|L1_URL=$L1_URL|" "$env_file"
        sed -i "s|^L1_BEACON=.*|L1_BEACON=$L1_BEACON|" "$env_file"
        sed -i "s|^P2P_ADVERTISE_IP.*|P2P_ADVERTISE_IP=$SERVER_IP|" "$env_file"
        show_bold "Переменные успешно обновлены"
        echo ''
    else
        show_war "Ошибка: файл $env_file не найден!"
        exit 1
    fi

    # Запуск Docker Compose
    show "Запуск ноды..."
    docker compose up -d || {
        show "Перезапуск Docker Compose..."
        docker compose down && docker compose up -d || {
            show_war "Ошибка при повторном запуске Docker Compose!"
            exit 1
        }
    }
    show_bold "Установка и запуск выполнены успешно!"
    echo ''
}
# Удаление ноды
delete() {
    show "Остановка и удаление контейнеров"
    cd "$son_dir/minato" && docker compose down
    show_bold 'Удалить директорию и все данные?'
    if confirm ''; then
        cd ~ && rm -rf ~/soneium-node
        show_bold "Успешно удалено." 
    else
        show_war "Не удалено."
    fi
}

# Меню с командами
show_menu() {
    show_logotip
    show_name
    show_bold 'Выберите действие:'
    echo ''
    actions=(
        "1. Установить ноду"
        "2. Просмотр логов ноды"
        "3. Проверка контейнеров"
        "4. Вывод приватного ключа"
        "9. Удаление ноды"
        "0. Выход"
    )
    for action in "${actions[@]}"; do
        show "$action"
    done
}

menu() {
    case $1 in
        1)  
            install_dependencies
            install_node 
            ;;
        2)  cd "$son_dir/minato" && docker compose logs -f --tail 20 ;;
        3)  
            if [ -d "$son_dir" ]; then
                cd "$son_dir/minato" && docker compose ps -a
            else
                show_war 'Ошибка: директория $son_dir не найдена.'
            fi ;;
        4)  cat "$son_dir/minato/jwt.txt" && echo "" ;;
        9)  delete ;;
        0)  
            echo ''
            show_bold "Присоединяйся к Нодатеке, будем ставить ноды вместе!"
            echo ''

            echo -en "${TERRACOTTA}${BOLD}Telegram: ${NC}${LIGHT_BLUE}https://t.me/cryptotesemnikov/778${NC}\n"
            echo -en "${TERRACOTTA}${BOLD}Twitter: ${NC}${LIGHT_BLUE}https://x.com/nodateka${NC}\n"
            echo -e "${TERRACOTTA}${BOLD}YouTube: ${NC}${LIGHT_BLUE}https://www.youtube.com/@CryptoTesemnikov${NC}\n"
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
