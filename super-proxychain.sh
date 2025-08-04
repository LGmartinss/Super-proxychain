#!/bin/bash

# Cores melhoradas
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Configurações
PROXY_PORT="9050"
TORRC_PATH="/tmp/super_torrc"
LOCK_FILE="/tmp/super_proxychain.lock"
ROTATE_INTERVAL=60 # 1 minuto
VERSION="1.0"

# Verifica se é Termux
is_termux() {
    [ -d "/data/data/com.termux/files/usr" ]
}

# Instala dependências
install_deps() {
    echo -e "${YELLOW}[*] Installing dependencies...${NC}"
    
    if is_termux; then
        pkg update -y && pkg install -y tor proxychains-ng curl
    else
        if command -v apt-get >/dev/null; then
            sudo apt-get update && sudo apt-get install -y tor proxychains curl
        elif command -v yum >/dev/null; then
            sudo yum install -y tor proxychains curl
        elif command -v dnf >/dev/null; then
            sudo dnf install -y tor proxychains curl
        else
            echo -e "${RED}[!] Package manager not supported. Install tor and proxychains manually.${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}[+] Dependencies installed!${NC}"
}

# Inicia serviço Tor
start_tor() {
    echo -e "${CYAN}[*] Starting Tor service...${NC}"
    
    # Configuração mínima do Tor
    echo "SocksPort $PROXY_PORT" > "$TORRC_PATH"
    echo "ControlPort 9051" >> "$TORRC_PATH"
    echo "RunAsDaemon 1" >> "$TORRC_PATH"
    echo "NewCircuitPeriod $ROTATE_INTERVAL" >> "$TORRC_PATH"
    echo "MaxCircuitDirtiness $ROTATE_INTERVAL" >> "$TORRC_PATH"
    
    # Inicia Tor em background
    tor -f "$TORRC_PATH" >/dev/null 2>&1 &
    
    # Configura proxychains
    if is_termux; then
        PROXYCHAIN_CONF="$PREFIX/etc/proxychains.conf"
    else
        PROXYCHAIN_CONF="/etc/proxychains.conf"
    fi
    
    if [ -f "$PROXYCHAIN_CONF" ]; then
        cp "$PROXYCHAIN_CONF" "${PROXYCHAIN_CONF}.bak"
        echo "strict_chain" > "$PROXYCHAIN_CONF"
        echo "quiet_mode" >> "$PROXYCHAIN_CONF"
        echo "proxy_dns" >> "$PROXYCHAIN_CONF"
        echo "tcp_read_time_out 15000" >> "$PROXYCHAIN_CONF"
        echo "tcp_connect_time_out 8000" >> "$PROXYCHAIN_CONF"
        echo "socks5 127.0.0.1 $PROXY_PORT" >> "$PROXYCHAIN_CONF"
    fi
    
    echo -e "${GREEN}[+] Tor service started on port $PROXY_PORT${NC}"
    echo -e "${YELLOW}[!] IP will rotate every $ROTATE_INTERVAL seconds${NC}"
}

# Para o serviço Tor
stop_tor() {
    echo -e "${RED}[*] Stopping Tor service...${NC}"
    pkill -f "tor -f $TORRC_PATH" >/dev/null 2>&1
    rm -f "$TORRC_PATH" "$LOCK_FILE"
    echo -e "${GREEN}[+] Tor service stopped${NC}"
}

# Testa anonimato
test_anonymity() {
    echo -e "${CYAN}[*] Testing anonymity...${NC}"
    
    if ! pgrep -f "tor -f $TORRC_PATH" >/dev/null; then
        echo -e "${RED}[!] Tor service not running${NC}"
        return
    fi
    
    echo -e "${YELLOW}[+] Getting real IP...${NC}"
    real_ip=$(curl -s --connect-timeout 10 ifconfig.me)
    
    echo -e "${YELLOW}[+] Getting proxy IP...${NC}"
    proxy_ip=$(proxychains curl -s --connect-timeout 10 ifconfig.me)
    
    echo -e "${WHITE}=======================${NC}"
    echo -e "${GREEN}Real IP: $real_ip${NC}"
    echo -e "${GREEN}Proxy IP: $proxy_ip${NC}"
    echo -e "${WHITE}=======================${NC}"
    
    if [ -z "$proxy_ip" ]; then
        echo -e "${RED}[!] Proxy test failed${NC}"
    elif [ "$real_ip" != "$proxy_ip" ]; then
        echo -e "${GREEN}[✓] Anonymity active!${NC}"
    else
        echo -e "${RED}[!] Proxy failed! IPs match!${NC}"
    fi
}

# Rotaciona IP manualmente
rotate_ip() {
    echo -e "${CYAN}[*] Rotating IP...${NC}"
    
    if ! pgrep -f "tor -f $TORRC_PATH" >/dev/null; then
        echo -e "${RED}[!] Tor service not running${NC}"
        return
    fi
    
    echo -e "AUTHENTICATE \"\"\r\nSIGNAL NEWNYM\r\nQUIT\r\n" | nc 127.0.0.1 9051 >/dev/null
    
    echo -e "${GREEN}[+] IP rotated! New circuit created.${NC}"
    test_anonymity
}

# Mostra status
show_status() {
    if pgrep -f "tor -f $TORRC_PATH" >/dev/null; then
        echo -e "${GREEN}[✓] Super ProxyChain: ACTIVE${NC}"
        echo -e "${YELLOW}[*] Port: $PROXY_PORT${NC}"
        echo -e "${YELLOW}[*] IP Rotation: Every $ROTATE_INTERVAL seconds${NC}"
        
        # Mostrar IP atual
        current_ip=$(proxychains curl -s --connect-timeout 10 ifconfig.me)
        if [ -n "$current_ip" ]; then
            echo -e "${YELLOW}[*] Current IP: $current_ip${NC}"
        fi
    else
        echo -e "${RED}[✗] Super ProxyChain: INACTIVE${NC}"
    fi
}

# Menu principal
show_menu() {
    clear
    echo -e "${PURPLE}"
    echo "   _____ __   __ _____  ____   ____ _   _ "
    echo "  / ____|  \ /  |  __ \|  _ \ / __ \ | | |"
    echo " | (___ | \ V / | |__) | |_) | |  | | |_| |"
    echo "  \___ \| |> <  |  ___/|  _ <| |  | |  _  |"
    echo "  ____) | / . \ | |    | |_) | |__| | | | |"
    echo " |_____/|_/_ \_\|_|    |____/ \____/|_| |_|"
    echo -e "${NC}"
    echo -e "${BLUE}       SUPER PROXYCHAIN ${VERSION}${NC}"
    echo -e "${CYAN}===============================${NC}"
    show_status
    echo -e "${CYAN}===============================${NC}"
    echo -e "${GREEN}[1]${NC} Start Anonymous Proxy"
    echo -e "${GREEN}[2]${NC} Test Anonymity"
    echo -e "${GREEN}[3]${NC} Rotate IP Now"
    echo -e "${GREEN}[0]${NC} Exit"
    echo -e "${CYAN}===============================${NC}"
}

# Main
if [ "$(id -u)" -eq 0 ]; then
    echo -e "${RED}[!] Don't run as root!${NC}"
    exit 1
fi

# Verificar e instalar dependências
if ! command -v tor >/dev/null || ! command -v proxychains >/dev/null; then
    install_deps
fi

# Limpar em caso de saída abrupta
trap stop_tor EXIT

while true; do
    show_menu
    read -p "Select option: " opt
    
    case $opt in
        1) 
            if pgrep -f "tor -f $TORRC_PATH" >/dev/null; then
                echo -e "${YELLOW}[!] Service already running${NC}"
            else
                start_tor
            fi
            ;;
        2) test_anonymity ;;
        3) rotate_ip ;;
        0) 
            stop_tor
            echo -e "${RED}[*] Exiting...${NC}"
            exit 0
            ;;
        *) echo -e "${RED}[!] Invalid option${NC}";;
    esac
    
    echo -e "\n${YELLOW}Press ENTER to continue...${NC}"
    read -n 1 -s
done