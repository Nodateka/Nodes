#!/bin/bash

# Цвета для вывода
GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

show() {
  echo -e "${GREEN}$1${RESET}"
}

error() {
  echo -e "${RED}$1${RESET}"
}

# Проверка на запуск от имени root
if [ "$EUID" -ne 0 ]; then
  error "Пожалуйста, запустите скрипт с правами root."
  exit 1
fi

# Обновление системы и установка зависимостей
show "Обновление системы и установка зависимостей..."
sudo apt update && sudo apt upgrade -y

for package in git curl; do
  if ! [ -x "$(command -v $package)" ]; then
    show "Устанавливаю $package..."
    sudo apt install -y $package
  else
    show "$package уже установлен."
  fi
done

# Проверка и установка Docker
if ! [ -x "$(command -v docker)" ]; then
  show "Установка Docker..."
  curl -fsSL https://get.docker.com | sh
  if ! [ -x "$(command -v docker)" ]; then
    error "Не удалось установить Docker."
    exit 1
  else
    show "Docker успешно установлен."
  fi
else
  show "Docker уже установлен."
fi

# Получение внешнего IP-адреса
IP=$(curl -4 -s ifconfig.me)
if [ -z "$IP" ]; then
  error "Не удалось получить внешний IP адрес."
  exit 1
fi

# Запрашиваем количество контейнеров
read -p "Сколько контейнеров хотите создать? " container_count

# Запрашиваем базовое имя контейнера
read -p "Введите базовое имя контейнера: " container_name

# Запрашиваем стартовый порт
default_port=10000
read -p "С какого порта начать? (По умолчанию $default_port): " start_port
start_port=${start_port:-$default_port}

# Проверка уникальности порта
function check_port() {
  port_in_use=$(lsof -i -P -n | grep -w "$1")
  if [ -n "$port_in_use" ]; then
    echo "Порт $1 уже занят. Выберите другой порт."
    return 1
  else
    return 0
  fi
}

# Путь к файлу с прокси
PROXY_FILE="$HOME/proxies.txt"

# Проверка наличия файла с прокси
if [ ! -f "$PROXY_FILE" ]; then
  error "Файл с прокси не найден. Пожалуйста, создайте файл $PROXY_FILE и введите список прокси."
  exit 1
fi

# Чтение прокси из файла
mapfile -t PROXIES < "$PROXY_FILE"

# Удаление файла после того, как прокси были считаны
rm -f "$PROXY_FILE"

# Проверка, что количество прокси не меньше количества контейнеров
if [ ${#PROXIES[@]} -lt "$container_count" ]; then
  error "Количество прокси меньше, чем количество контейнеров. Скрипт завершает работу."
  exit 1
fi

# Проверка и настройка прокси
proxy_http=""
proxy_https=""
proxy_socks5=""
chromium_proxy_args=""

# Запрашиваем имя пользователя
read -p "Введите имя пользователя: " USERNAME

# Запрашиваем пароль с подтверждением
while true; do
  read -s -p "Введите пароль: " PASSWORD
  echo  # Переход на новую строку
  read -s -p "Подтвердите пароль: " PASSWORD_CONFIRM
  echo
  if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    error "Пароли не совпадают. Повторите ввод."
  else
    break
  fi
done

# Сохранение учетных данных
CREDENTIALS_FILE="$HOME/vps-browser-credentials-$container_name.json"
cat <<EOL > "$CREDENTIALS_FILE"
{
  "username": "$USERNAME",
  "password": "$PASSWORD"
}
EOL

# Проверка и загрузка образа Docker с Chromium
show "Загрузка последнего образа Docker с Chromium..."
if ! docker pull linuxserver/chromium:latest; then
  error "Не удалось загрузить образ Docker с Chromium."
  exit 1
else
  show "Образ Docker с Chromium успешно загружен."
fi

# Создание контейнеров
for ((i=0; i<container_count; i++)); do
  # Используем прокси из файла для каждого контейнера
  proxy="${PROXIES[$i]}"

  # Разделяем строку на учетные данные (user:pass) и детали прокси (ip:port)
  IFS='@' read -r credentials proxy_details <<< "$proxy"

  # Разделяем учетные данные на user и pass
  IFS=':' read -r user pass <<< "$credentials"

  # Разделяем детали прокси на ip и port
  IFS=':' read -r ip port <<< "$proxy_details"

  # Прокси HTTP
  proxy_http="-e HTTP_PROXY=http://$user:$pass@$ip:$port"
  proxy_https="-e HTTPS_PROXY=http://$user:$pass@$ip:$port"
  chromium_proxy_args="--proxy-server=http://$user:$pass@$ip:$port"

  # Прокси SOCKS5
  proxy_socks5="-e ALL_PROXY=socks5://$user:$pass@$ip:$port"
  chromium_proxy_args="--proxy-server=socks5://$user:$pass@$ip:$port"

  current_port=$((start_port + i * 10))  # Каждый следующий контейнер на 10 портов дальше

  # Проверка, что порт свободен
  if ! check_port "$current_port"; then
    error "Невозможно запустить контейнер на порту $current_port, так как он занят."
    continue
  fi

  # Генерация уникального имени контейнера
  container_name_unique="${container_name}$i"

  # Создание уникальной конфигурационной папки
  config_dir="$HOME/chromium/config_$container_name_unique"
  mkdir -p "$config_dir"

  # Запуск контейнера
  show "Запуск контейнера $container_name_unique с портом $current_port..."
  docker run -d --name "$container_name_unique" \
    --privileged \
    -e TITLE="Chromium Browser" \
    -e DISPLAY=:1 \
    -e PUID=1000 \
    -e PGID=1000 \
    -e CUSTOM_USER="$USERNAME" \
    -e PASSWORD="$PASSWORD" \
    -e LANGUAGE=en_US.UTF-8 \
    $proxy_http \
    $proxy_https \
    $proxy_socks5 \
    -v "$config_dir:/config" \
    -p "$current_port:3000" \
    --shm-size="2gb" \
    --restart unless-stopped \
    lscr.io/linuxserver/chromium:latest

  if [ $? -eq 0 ]; then
    show "Контейнер $container_name_unique успешно запущен."
    show "Откройте этот адрес: http://$IP:$current_port/"
  else
    error "Не удалось запустить контейнер $container_name_unique."
  fi
done
