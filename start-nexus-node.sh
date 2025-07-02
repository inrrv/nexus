#!/bin/bash
set -e

# --- Цвета ---
GREEN="\e[32m"
RED="\e[31m"
PINK="\e[35m"
NC="\e[0m"

# --- Анимация ---
animate_loading() {
    for ((i = 1; i <= 3; i++)); do
        printf "\r${GREEN}Загружаем меню${NC}."
        sleep 0.3
        printf "\r${GREEN}Загружаем меню${NC}.."
        sleep 0.3
        printf "\r${GREEN}Загружаем меню${NC}..."
        sleep 0.3
    done
    echo ""
}

animate_loading

# --- Проверка whiptail ---
if ! command -v whiptail &>/dev/null; then
    echo -e "${RED}whiptail не найден. Устанавливаем...${NC}"
    sudo apt update && sudo apt install -y whiptail
fi

# --- Функция: Установка Docker ---
install_docker() {
    if ! command -v docker &>/dev/null; then
        echo -e "${PINK}Docker не найден. Устанавливаем...${NC}"
        sudo apt update
        sudo apt install -y curl ca-certificates apt-transport-https gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg \
            | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

        echo \
          "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
           https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
           $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
          | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io
        echo -e "${GREEN}✔ Docker установлен${NC}"
    else
        echo -e "${GREEN}✔ Docker уже установлен (${NC}$(docker --version)${GREEN})${NC}"
    fi
}

# --- Функция: Установка Docker Compose ---
install_docker_compose() {
    if ! command -v docker-compose &>/dev/null; then
        echo -e "${PINK}Docker Compose не найден. Устанавливаем...${NC}"
        sudo apt update && sudo apt install -y wget jq

        COMPOSE_VER=$(wget -qO- https://api.github.com/repos/docker/compose/releases/latest | jq -r ".tag_name")

        sudo wget -O /usr/local/bin/docker-compose \
            "https://github.com/docker/compose/releases/download/${COMPOSE_VER}/docker-compose-$(uname -s)-$(uname -m)"
        sudo chmod +x /usr/local/bin/docker-compose

        DOCKER_CLI_PLUGINS=${DOCKER_CLI_PLUGINS:-"$HOME/.docker/cli-plugins"}
        mkdir -p "$DOCKER_CLI_PLUGINS"
        curl -fsSL \
            "https://github.com/docker/compose/releases/download/${COMPOSE_VER}/docker-compose-$(uname -s)-$(uname -m)" \
            -o "${DOCKER_CLI_PLUGINS}/docker-compose"
        chmod +x "${DOCKER_CLI_PLUGINS}/docker-compose"

        echo -e "${GREEN}✔ Docker Compose ${COMPOSE_VER} установлен${NC}"
    else
        echo -e "${GREEN}✔ Docker Compose уже установлен (${NC}$(docker-compose --version)${GREEN})${NC}"
    fi
}

# --- Функция: Установка узла ---
install_node() {
    install_docker
    install_docker_compose
    sudo apt install -y screen

    docker pull nexusxyz/nexus-cli:latest

    read -p "Введите ваш node id: " PRIVATE_KEY

    screen -S nexus -dm bash -c "docker run -it --init --name nexus nexusxyz/nexus-cli:latest start --node-id $PRIVATE_KEY"
    echo -e "${GREEN}✅ Узел установлен.${NC}"
    echo -e "${GREEN}➡ Для просмотра логов: screen -r nexus${NC}"
    echo -e "${GREEN}↩ Для выхода из логов: Ctrl+A, затем D${NC}"
}

# --- Функция: Перезапуск узла ---
restart_node() {
    echo -e "${RED}♻ Перезапуск узла...${NC}"
    screen -XS nexus quit >/dev/null 2>&1 || :
    docker stop nexus 2>/dev/null || true
    docker rm nexus 2>/dev/null || true

    read -p "Введите ваш node id: " PRIVATE_KEY

    screen -S nexus -dm bash -c "docker run -it --init --name nexus nexusxyz/nexus-cli:latest start --node-id $PRIVATE_KEY"
    echo -e "${GREEN}✅ Узел перезапущен.${NC}"
}

# --- Функция: Удаление узла ---
delete_node() {
    echo -e "${RED}🗑 Удаляем узел...${NC}"
    screen -XS nexus quit 2>/dev/null
    docker stop nexus 2>/dev/null || true
    docker rm nexus 2>/dev/null || true
    docker rmi nexusxyz/nexus-cli:latest 2>/dev/null || true
    echo -e "${GREEN}✅ Узел полностью удален.${NC}"
}

# --- Функция: Обновление узла ---
update_node() {
    echo -e "${PINK}🔄 Обновление узла...${NC}"
    screen -XS nexus quit >/dev/null 2>&1 || :
    docker stop nexus 2>/dev/null || true
    docker rm nexus 2>/dev/null || true
    docker pull nexusxyz/nexus-cli:latest

    read -p "Введите ваш node id: " PRIVATE_KEY

    screen -S nexus -dm bash -c "docker run -it --init --name nexus nexusxyz/nexus-cli:latest start --node-id $PRIVATE_KEY"
    echo -e "${GREEN}✅ Узел обновлен.${NC}"
}

# --- Главное меню ---
CHOICE=$(whiptail --title "Меню управления Nexus" \
  --menu "Выберите действие:" 20 60 10 \
  "1" "Установить ноду" \
  "2" "Просмотреть логи" \
  "3" "Перезапустить ноду" \
  "4" "Удалить ноду" \
  "5" "Обновить ноду" \
  3>&1 1>&2 2>&3)

# --- Обработка выбора ---
if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Отменено. Выход.${NC}"
  exit 1
fi

case $CHOICE in
  1) install_node ;;
  2)
    if screen -list | grep -q "nexus"; then
  screen -r nexus
else
  echo -e "${RED}❌ Сессия не найдена. Возможно узел не запущен.${NC}"
fi    ;;
  3) restart_node ;;
  4) delete_node ;;
  5) update_node ;;
  *) echo -e "${RED}Неизвестная опция.${NC}" ;;
esac