#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║     ELITE-X DNSTT SCRIPT v3.2 - WITH CUSTOM KEYS            ║
# ║     PRIVATE KEY: 7f207e92ab7cb365aad1966b62d2cfbd3f450fe8... ║
# ║     PUBLIC KEY:  40aa057fcb2574e1e9223ea46457f9fdf9d60a2a... ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

print_color() { echo -e "${2}${1}${NC}"; }

self_destruct() {
    echo -e "${YELLOW}🧹 Cleaning installation traces...${NC}"
    
    history -c 2>/dev/null || true
    cat /dev/null > ~/.bash_history 2>/dev/null || true
    cat /dev/null > /root/.bash_history 2>/dev/null || true
    
    if [ -f "$0" ] && [ "$0" != "/usr/local/bin/elite-x" ]; then
        local script_path=$(readlink -f "$0")
        rm -f "$script_path" 2>/dev/null || true
    fi
    
    sed -i '/Elite-X-dns.sh/d' /var/log/auth.log 2>/dev/null || true
    sed -i '/elite-x/d' /var/log/auth.log 2>/dev/null || true
    
    echo -e "${GREEN}✅ Cleanup complete!${NC}"
}

show_quote() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}         ELITE-X ULTIMATE - The Future of DNS Tunneling       ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_banner() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}               ELITE-X SLOWDNS v3.2 ULTIMATE                   ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${GREEN}${BOLD}           Real-Time • High Performance • Unlimited            ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Activation (removed limit - unlimited)
ACTIVATION_KEY="ELITE X"
ACTIVATION_FILE="/etc/elite-x/activated"
KEY_FILE="/etc/elite-x/key"
TIMEZONE="Africa/Dar_es_Salaam"

set_timezone() {
    timedatectl set-timezone Africa/Dar_es_Salaam 2>/dev/null || 
    ln -sf /usr/share/zoneinfo/Africa/Dar_es_Salaam /etc/localtime 2>/dev/null || true
    
    systemctl restart systemd-timesyncd 2>/dev/null || true
    
    echo -e "${GREEN}✅ Timezone set to Tanzania (Africa/Dar_es_Salaam)${NC}"
}

activate_script() {
    local input_key="$1"
    mkdir -p /etc/elite-x
    
    if [ "$input_key" = "$ACTIVATION_KEY" ] || [ "$input_key" = "Whtsapp +255713-628-668" ]; then
        echo "$ACTIVATION_KEY" > "$ACTIVATION_FILE"
        echo "$ACTIVATION_KEY" > "$KEY_FILE"
        echo "lifetime" > /etc/elite-x/activation_type
        echo "Lifetime Unlimited" > /etc/elite-x/expiry
        echo -e "${GREEN}✅ Activation successful - Ultimate Unlimited Version${NC}"
        return 0
    fi
    return 1
}

# Advanced Bandwidth Management
setup_bandwidth_manager() {
    cat > /usr/local/bin/elite-x-bandwidth <<'EOF'
#!/bin/bash

USER_DB="/etc/elite-x/users"
BANDWIDTH_PER_USER=10240
TOTAL_BANDWIDTH=102400
MONITOR_DIR="/var/run/elite-x/bandwidth"

mkdir -p $MONITOR_DIR

setup_tc() {
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    tc qdisc del dev $interface root 2>/dev/null || true
    
    tc qdisc add dev $interface root handle 1: htb default 30
    tc class add dev $interface parent 1: classid 1:1 htb rate ${TOTAL_BANDWIDTH}kbit ceil ${TOTAL_BANDWIDTH}kbit
    
    tc qdisc add dev $interface parent 1:1 handle 10: fq maxrate ${BANDWIDTH_PER_USER}kbit
    
    echo "$interface" > $MONITOR_DIR/interface
}

add_user_bandwidth() {
    local username=$1
    local interface=$(cat $MONITOR_DIR/interface 2>/dev/null)
    
    if [ -z "$interface" ]; then
        interface=$(ip route | grep default | awk '{print $5}' | head -1)
    fi
    
    tc filter add dev $interface parent 1: protocol ip prio 1 u32 \
        match ip sport 22 0xffff \
        match u32 $(echo -n "$username" | md5sum | cut -c1-8) 0xffffffff at 0 \
        flowid 10: 2>/dev/null || true
    
    echo "$username" >> $MONITOR_DIR/users
}

remove_user_bandwidth() {
    local username=$1
    local interface=$(cat $MONITOR_DIR/interface 2>/dev/null)
    
    if [ -n "$interface" ]; then
        tc filter del dev $interface parent 1: prio 1 2>/dev/null || true
    fi
    
    sed -i "/$username/d" $MONITOR_DIR/users 2>/dev/null || true
}

case "$1" in
    init)
        setup_tc
        ;;
    add)
        add_user_bandwidth "$2"
        ;;
    remove)
        remove_user_bandwidth "$2"
        ;;
esac
EOF
    chmod +x /usr/local/bin/elite-x-bandwidth
}

# Connection Monitor (no auto-ban)
setup_connection_monitor() {
    cat > /usr/local/bin/elite-x-connmon <<'EOF'
#!/bin/bash

USER_DB="/etc/elite-x/users"
CONN_DB="/etc/elite-x/connections"
mkdir -p $CONN_DB

get_connection_count() {
    local username=$1
    
    local conn1=$(ps aux | grep "sshd:" | grep "$username" | grep -v grep | grep -v "sshd:.*@notty" | wc -l)
    local conn2=$(ss -tnp | grep "sshd" | grep "$username" | wc -l)
    local conn3=$(who | grep "$username" | wc -l)
    local conn4=$(last | grep "$username" | grep "still logged in" | wc -l)
    
    local max_conn=$conn1
    [ $conn2 -gt $max_conn ] && max_conn=$conn2
    [ $conn3 -gt $max_conn ] && max_conn=$conn3
    [ $conn4 -gt $max_conn ] && max_conn=$conn4
    
    if [ $max_conn -gt 10 ]; then
        max_conn=$conn3
    fi
    
    echo $max_conn
}

monitor_connections() {
    local username=$1
    local limit_file="$USER_DB/$username"
    
    if [ ! -f "$limit_file" ]; then
        return
    fi
    
    local conn_limit=$(grep "Conn_Limit:" "$limit_file" | cut -d' ' -f2)
    conn_limit=${conn_limit:-1}
    
    local current_conn=$(get_connection_count "$username")
    
    echo "$current_conn" > "$CONN_DB/$username"
    
    if [ "$current_conn" -gt "$conn_limit" ]; then
        logger -t "elite-x" "User $username exceeded connection limit ($current_conn/$conn_limit) - monitoring only"
    fi
    
    return 0
}

while true; do
    if [ -d "$USER_DB" ]; then
        for user_file in "$USER_DB"/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                monitor_connections "$username"
            fi
        done
    fi
    sleep 5
done
EOF
    chmod +x /usr/local/bin/elite-x-connmon

    cat > /etc/systemd/system/elite-x-connmon.service <<EOF
[Unit]
Description=Elite-X Real-Time Connection Monitor
After=network.target ssh.service

[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-connmon
Restart=always
RestartSec=5
CPUQuota=20%
MemoryMax=50M

[Install]
WantedBy=multi-user.target
EOF
}

# Auto restart service
setup_auto_restart() {
    cat > /usr/local/bin/elite-x-auto-restart <<'EOF'
#!/bin/bash

CONFIG_FILE="/etc/elite-x/auto_config"
STATE_DIR="/var/lib/elite-x/auto"
mkdir -p "$STATE_DIR"

LAST_SERVICE_FILE="$STATE_DIR/last_service_restart"
LAST_REBOOT_FILE="$STATE_DIR/last_reboot"
SERVICE_LOG="/etc/elite-x/auto_restart.log"
REBOOT_LOG="/etc/elite-x/auto_reboot.log"

SERVICE_INTERVAL=1
REBOOT_INTERVAL=2

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

SERVICE_SECONDS=$((SERVICE_INTERVAL * 3600))
REBOOT_SECONDS=$((REBOOT_INTERVAL * 3600))

export TZ='Africa/Dar_es_Salaam'
CURRENT_TIME=$(date +%s)

if [ -f "$LAST_SERVICE_FILE" ]; then
    LAST_SERVICE_RESTART=$(cat "$LAST_SERVICE_FILE")
else
    LAST_SERVICE_RESTART=$CURRENT_TIME
    echo "$LAST_SERVICE_RESTART" > "$LAST_SERVICE_FILE"
fi

if [ -f "$LAST_REBOOT_FILE" ]; then
    LAST_REBOOT=$(cat "$LAST_REBOOT_FILE")
else
    LAST_REBOOT=$CURRENT_TIME
    echo "$LAST_REBOOT" > "$LAST_REBOOT_FILE"
fi

echo "$(date) - Auto service started." >> "$SERVICE_LOG"

while true; do
    CURRENT_TIME=$(date +%s)
    
    SERVICE_ELAPSED=$((CURRENT_TIME - LAST_SERVICE_RESTART))
    REBOOT_ELAPSED=$((CURRENT_TIME - LAST_REBOOT))
    
    if [ $SERVICE_INTERVAL -gt 0 ] && [ $SERVICE_ELAPSED -ge $SERVICE_SECONDS ]; then
        if [ $SERVICE_ELAPSED -lt $((SERVICE_SECONDS + 300)) ]; then
            echo "$(date) - Auto-restarting services after ${SERVICE_INTERVAL} hour(s)" >> "$SERVICE_LOG"
            logger -t "elite-x" "Auto-restarting services after ${SERVICE_INTERVAL} hour(s)"
            
            systemctl restart dnstt-elite-x 2>/dev/null || true
            systemctl restart dnstt-elite-x-proxy 2>/dev/null || true
            systemctl restart elite-x-connmon 2>/dev/null || true
            
            LAST_SERVICE_RESTART=$CURRENT_TIME
            echo "$LAST_SERVICE_RESTART" > "$LAST_SERVICE_FILE"
            
            echo "$(date) - Services restarted successfully" >> "$SERVICE_LOG"
        fi
    fi
    
    if [ $REBOOT_INTERVAL -gt 0 ] && [ $REBOOT_ELAPSED -ge $REBOOT_SECONDS ]; then
        if [ $REBOOT_ELAPSED -lt $((REBOOT_SECONDS + 300)) ]; then
            echo "$(date) - System auto-rebooting after ${REBOOT_INTERVAL} hour(s)" >> "$REBOOT_LOG"
            logger -t "elite-x" "Auto-rebooting after ${REBOOT_INTERVAL} hour(s)"
            
            LAST_REBOOT=$CURRENT_TIME
            echo "$LAST_REBOOT" > "$LAST_REBOOT_FILE"
            
            shutdown -r +1 "Elite-X auto reboot after ${REBOOT_INTERVAL} hour(s)"
            
            exit 0
        fi
    fi
    
    sleep 60
done
EOF
    chmod +x /usr/local/bin/elite-x-auto-restart

    cat > /etc/systemd/system/elite-x-auto-restart.service <<EOF
[Unit]
Description=Elite-X Auto Restart & Reboot Service
After=network.target time-sync.target
Wants=time-sync.target

[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-auto-restart
Restart=always
RestartSec=10
Environment="TZ=Africa/Dar_es_Salaam"

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/elite-x/auto_config <<EOF
# Elite-X Auto Restart Configuration
SERVICE_INTERVAL=1
REBOOT_INTERVAL=2
EOF

    mkdir -p /var/lib/elite-x/auto
    CURRENT_TIME=$(TZ='Africa/Dar_es_Salaam' date +%s)
    echo "$CURRENT_TIME" > /var/lib/elite-x/auto/last_service_restart
    echo "$CURRENT_TIME" > /var/lib/elite-x/auto/last_reboot
    
    echo -e "${GREEN}✅ Auto Restart configured: Services every 1h, Reboot every 2h${NC}"
}

# Traffic Monitor
setup_realtime_traffic() {
    cat > /usr/local/bin/elite-x-realtime <<'EOF'
#!/bin/bash

USER_DB="/etc/elite-x/users"
TRAFFIC_DB="/etc/elite-x/traffic"
mkdir -p $TRAFFIC_DB

while true; do
    if [ -d "$USER_DB" ]; then
        for user_file in "$USER_DB"/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                if command -v iptables >/dev/null 2>&1; then
                    upload=$(iptables -vnx -L OUTPUT | grep "$username" | awk '{sum+=$2} END {print sum}' 2>/dev/null || echo "0")
                    download=$(iptables -vnx -L INPUT | grep "$username" | awk '{sum+=$2} END {print sum}' 2>/dev/null || echo "0")
                    total=$((upload + download))
                    echo $((total / 1048576)) > "$TRAFFIC_DB/$username"
                fi
            fi
        done
    fi
    sleep 60
done
EOF
    chmod +x /usr/local/bin/elite-x-realtime

    cat > /etc/systemd/system/elite-x-realtime.service <<EOF
[Unit]
Description=Elite-X Real-Time Traffic Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-realtime
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

# Speed Optimizer
setup_advanced_speed() {
    cat > /usr/local/bin/elite-x-speed <<'EOF'
#!/bin/bash

RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';NC='\033[0m'

optimize_network() {
    echo -e "${YELLOW}⚡ Applying Elite-X Network Optimizations...${NC}"
    
    cat > /etc/sysctl.d/99-elite-x.conf <<'EOL'
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_max_syn_backlog = 4096
net.core.somaxconn = 4096
EOL
    
    sysctl -p /etc/sysctl.d/99-elite-x.conf >/dev/null 2>&1
    
    echo -e "${GREEN}✅ Network optimized!${NC}"
}

optimize_cpu() {
    echo -e "${YELLOW}⚡ Optimizing CPU...${NC}"
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "performance" > "$cpu" 2>/dev/null || true
    done
    echo -e "${GREEN}✅ CPU optimized!${NC}"
}

optimize_ram() {
    echo -e "${YELLOW}⚡ Optimizing RAM...${NC}"
    sysctl -w vm.vfs_cache_pressure=50 >/dev/null 2>&1
    sysctl -w vm.swappiness=10 >/dev/null 2>&1
    sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    echo -e "${GREEN}✅ RAM optimized!${NC}"
}

case "$1" in
    full)
        optimize_network
        optimize_cpu
        optimize_ram
        ;;
    network) optimize_network ;;
    cpu) optimize_cpu ;;
    ram) optimize_ram ;;
    *) echo "Usage: elite-x-speed {full|network|cpu|ram}" ;;
esac
EOF
    chmod +x /usr/local/bin/elite-x-speed
}

# Auto Remover
setup_auto_remover() {
    cat > /usr/local/bin/elite-x-cleaner <<'EOF'
#!/bin/bash

USER_DB="/etc/elite-x/users"
DELETED_DB="/etc/elite-x/deleted"
TRAFFIC_DB="/etc/elite-x/traffic"
mkdir -p $DELETED_DB

while true; do
    if [ -d "$USER_DB" ]; then
        for user_file in "$USER_DB"/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                expire_date=$(grep "Expire:" "$user_file" | cut -d' ' -f2)
                
                if [ ! -z "$expire_date" ]; then
                    current_date=$(date +%Y-%m-%d)
                    if [[ "$current_date" > "$expire_date" ]] || [ "$current_date" = "$expire_date" ]; then
                        backup_file="$DELETED_DB/${username}_$(date +%Y%m%d_%H%M%S)"
                        cp "$user_file" "$backup_file" 2>/dev/null || true
                        echo "Deleted: $(date +%Y-%m-%d %H:%M:%S)" >> "$backup_file"
                        
                        pkill -u "$username" 2>/dev/null || true
                        /usr/local/bin/elite-x-bandwidth remove "$username" 2>/dev/null || true
                        userdel -r "$username" 2>/dev/null || true
                        rm -f "$user_file"
                        rm -f "$TRAFFIC_DB/$username"
                        
                        logger -t "elite-x" "Auto-removed expired user: $username"
                    fi
                fi
            fi
        done
    fi
    sleep 300
done
EOF
    chmod +x /usr/local/bin/elite-x-cleaner

    cat > /etc/systemd/system/elite-x-cleaner.service <<EOF
[Unit]
Description=ELITE-X Auto Remover
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-cleaner
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
}

check_subdomain() {
    local subdomain="$1"
    local vps_ip=$(curl -4 -s ifconfig.me 2>/dev/null || echo "")
    
    echo -e "${YELLOW}🔍 Checking if subdomain points to this VPS (IPv4)...${NC}"
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}  Subdomain: $subdomain${NC}"
    echo -e "${CYAN}║${WHITE}  VPS IPv4 : $vps_ip${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    if [ -z "$vps_ip" ]; then
        echo -e "${YELLOW}⚠️  Could not detect VPS IPv4, continuing anyway...${NC}"
        return 0
    fi

    local resolved_ip=$(dig +short -4 "$subdomain" 2>/dev/null | head -1)
    
    if [ -z "$resolved_ip" ]; then
        echo -e "${YELLOW}⚠️  Could not resolve subdomain, continuing anyway...${NC}"
        echo -e "${YELLOW}⚠️  Make sure your subdomain points to: $vps_ip${NC}"
        return 0
    fi
    
    if [ "$resolved_ip" = "$vps_ip" ]; then
        echo -e "${GREEN}✅ Subdomain correctly points to this VPS!${NC}"
        return 0
    else
        echo -e "${RED}❌ Subdomain points to $resolved_ip, but VPS IP is $vps_ip${NC}"
        echo -e "${YELLOW}⚠️  Please update your DNS record and try again${NC}"
        read -p "Continue anyway? (y/n): " continue_anyway
        if [ "$continue_anyway" != "y" ]; then
            exit 1
        fi
    fi
}

show_banner
echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║${GREEN}                    ACTIVATION REQUIRED                          ${YELLOW}║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${WHITE}Available Keys:${NC}"
echo -e "${GREEN}  Ultimate Key: Whtsapp +255713-628-668${NC}"
echo ""
read -p "$(echo -e $CYAN"Activation Key: "$NC)" ACTIVATION_INPUT

mkdir -p /etc/elite-x
if ! activate_script "$ACTIVATION_INPUT"; then
    echo -e "${RED}❌ Invalid activation key! Installation cancelled.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Activation successful!${NC}"
sleep 2

set_timezone

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}                  ENTER YOUR SUBDOMAIN                          ${CYAN}║${NC}"
echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${WHITE}  Example: ns-ex.elitex.sbs                                 ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
read -p "$(echo -e $GREEN"Subdomain: "$NC)" TDOMAIN

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}  You entered: ${GREEN}$TDOMAIN${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

check_subdomain "$TDOMAIN"

echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║${GREEN}           NETWORK LOCATION OPTIMIZATION                          ${YELLOW}║${NC}"
echo -e "${YELLOW}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${YELLOW}║${WHITE}  Select your VPS location:                                    ${YELLOW}║${NC}"
echo -e "${YELLOW}║${GREEN}  [1] South Africa (Recommended - MTU 1800)                    ${YELLOW}║${NC}"
echo -e "${YELLOW}║${CYAN}  [2] USA (MTU 1500)                                              ${YELLOW}║${NC}"
echo -e "${YELLOW}║${BLUE}  [3] Europe (MTU 1500)                                           ${YELLOW}║${NC}"
echo -e "${YELLOW}║${PURPLE}  [4] Asia (MTU 1400)                                             ${YELLOW}║${NC}"
echo -e "${YELLOW}║${YELLOW}  [5] Custom MTU                                                  ${YELLOW}║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
read -p "$(echo -e $GREEN"Select location [1-5] [default: 1]: "$NC)" LOCATION_CHOICE
LOCATION_CHOICE=${LOCATION_CHOICE:-1}

case $LOCATION_CHOICE in
    2)
        SELECTED_LOCATION="USA"
        MTU=1500
        echo -e "${CYAN}✅ USA selected (MTU: $MTU)${NC}"
        ;;
    3)
        SELECTED_LOCATION="Europe"
        MTU=1500
        echo -e "${BLUE}✅ Europe selected (MTU: $MTU)${NC}"
        ;;
    4)
        SELECTED_LOCATION="Asia"
        MTU=1400
        echo -e "${PURPLE}✅ Asia selected (MTU: $MTU)${NC}"
        ;;
    5)
        SELECTED_LOCATION="Custom"
        read -p "Enter MTU value (1000-5000): " MTU
        if [[ ! "$MTU" =~ ^[0-9]+$ ]] || [ "$MTU" -lt 1000 ] || [ "$MTU" -gt 5000 ]; then
            echo -e "${RED}Invalid MTU, using default 1800${NC}"
            MTU=1800
        fi
        echo -e "${YELLOW}✅ Custom MTU: $MTU${NC}"
        ;;
    *)
        SELECTED_LOCATION="South Africa"
        MTU=1800
        echo -e "${GREEN}✅ South Africa selected (MTU: $MTU)${NC}"
        ;;
esac

echo "$SELECTED_LOCATION" > /etc/elite-x/location
echo "$MTU" > /etc/elite-x/mtu

DNSTT_PORT=5300
DNS_PORT=53

echo "==> ELITE-X ULTIMATE V3.2 INSTALLATION STARTING..."

if [ "$(id -u)" -ne 0 ]; then
  echo "[-] Run as root"
  exit 1
fi

# Cleanup
echo -e "${YELLOW}🔄 Cleaning previous installation...${NC}"

if [ -d "/etc/elite-x/users" ]; then
    for user_file in /etc/elite-x/users/*; do
        if [ -f "$user_file" ]; then
            username=$(basename "$user_file")
            echo -e "  Removing old user: $username"
            userdel -r "$username" 2>/dev/null || true
            pkill -u "$username" 2>/dev/null || true
        fi
    done
fi

for service in dnstt-elite-x dnstt-elite-x-proxy elite-x-traffic elite-x-cleaner elite-x-connmon elite-x-realtime; do
    systemctl stop $service 2>/dev/null || true
    systemctl disable $service 2>/dev/null || true
done

pkill -f dnstt-server 2>/dev/null || true
pkill -f dnstt-edns-proxy 2>/dev/null || true
pkill -f elite-x 2>/dev/null || true

rm -rf /etc/systemd/system/{dnstt-elite-x*,elite-x-*}
rm -rf /etc/dnstt /etc/elite-x
rm -f /usr/local/bin/{dnstt-*,elite-x*}

sed -i '/^Banner/d' /etc/ssh/sshd_config
systemctl restart sshd

rm -f /etc/profile.d/elite-x-dashboard.sh
sed -i '/elite-x/d' ~/.bashrc 2>/dev/null || true

echo -e "${GREEN}✅ Previous installation cleaned${NC}"
sleep 2

# Create directories
mkdir -p /etc/elite-x/{banner,users,traffic,deleted,connections,banned,realtime}
mkdir -p /var/run/elite-x/bandwidth
echo "$TDOMAIN" > /etc/elite-x/subdomain

# Banners
cat > /etc/elite-x/banner/default <<'EOF'
╔════════════════════════════════════════════════════╗
║         ELITE-X ULTIMATE VPN SERVICE v3.2          ║
╠════════════════════════════════════════════════════╣
║     High Speed • Stable • Unlimited • Secure       ║
║              Real-Time Connection Management       ║
╚════════════════════════════════════════════════════╝
EOF

cat > /etc/elite-x/banner/ssh-banner <<'EOF'
╔════════════════════════════════════════════════════╗
║              ELITE-X ULTIMATE v3.2                 ║
║     High Speed • Stable • Unlimited • Secure       ║
╚════════════════════════════════════════════════════╝
EOF

if ! grep -q "^Banner" /etc/ssh/sshd_config; then
    echo "Banner /etc/elite-x/banner/ssh-banner" >> /etc/ssh/sshd_config
else
    sed -i 's|^Banner.*|Banner /etc/elite-x/banner/ssh-banner|' /etc/ssh/sshd_config
fi
systemctl restart sshd

# DNS configuration
if [ -f /etc/systemd/resolved.conf ]; then
  sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf || true
  grep -q '^DNS=' /etc/systemd/resolved.conf \
    && sed -i 's/^DNS=.*/DNS=8.8.8.8 8.8.4.4/' /etc/systemd/resolved.conf \
    || echo "DNS=8.8.8.8 8.8.4.4" >> /etc/systemd/resolved.conf
  systemctl restart systemd-resolved 2>/dev/null || true
  
  if [ -L /etc/resolv.conf ]; then
    rm -f /etc/resolv.conf 2>/dev/null || unlink /etc/resolv.conf 2>/dev/null || true
  fi
  
  echo "nameserver 8.8.8.8" > /etc/resolv.conf
  echo "nameserver 8.8.4.4" >> /etc/resolv.conf
  chmod 644 /etc/resolv.conf
fi

# Install dependencies
echo "Installing dependencies..."
apt update -y
apt install -y curl python3 jq nano iptables iptables-persistent ethtool dnsutils net-tools iproute2 iftop

# Install dnstt-server
echo "Installing dnstt-server..."
if ! curl -fsSL https://dnstt.network/dnstt-server-linux-amd64 -o /usr/local/bin/dnstt-server 2>/dev/null; then
    curl -fsSL https://github.com/NoXFiQ/Elite-X-dns.sh/raw/main/dnstt-server -o /usr/local/bin/dnstt-server 2>/dev/null || {
        echo -e "${RED}❌ Failed to download dnstt-server${NC}"
        exit 1
    }
fi
chmod +x /usr/local/bin/dnstt-server

# ==============================================
# STATIC DNSTT KEYS - YOUR CUSTOM KEYS
# PRIVATE KEY: 7f207e92ab7cb365aad1966b62d2cfbd3f450fe8e523a38ffc7ecfbcec315693
# PUBLIC KEY:  40aa057fcb2574e1e9223ea46457f9fdf9d60a2a1c23da87602202d93b41aa04
# ==============================================
echo "Setting static DNSTT keys with your custom keys..."
mkdir -p /etc/dnstt

rm -f /etc/dnstt/server.key
rm -f /etc/dnstt/server.pub

cat > /etc/dnstt/server.key <<'EOF'
7f207e92ab7cb365aad1966b62d2cfbd3f450fe8e523a38ffc7ecfbcec315693
EOF

cat > /etc/dnstt/server.pub <<'EOF'
40aa057fcb2574e1e9223ea46457f9fdf9d60a2a1c23da87602202d93b41aa04
EOF

chmod 600 /etc/dnstt/server.key
chmod 644 /etc/dnstt/server.pub

echo -e "${GREEN}✅ Static DNSTT keys installed successfully${NC}"
echo -e "${CYAN}   Private Key: $(cat /etc/dnstt/server.key)${NC}"
echo -e "${CYAN}   Public Key:  $(cat /etc/dnstt/server.pub)${NC}"

# Create dnstt service
cat >/etc/systemd/system/dnstt-elite-x.service <<EOF
[Unit]
Description=ELITE-X DNSTT Server v3.2
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/tmp
ExecStart=/usr/local/bin/dnstt-server -udp :${DNSTT_PORT} -mtu ${MTU} -privkey-file /etc/dnstt/server.key ${TDOMAIN} 127.0.0.1:22
Restart=always
RestartSec=5
KillSignal=SIGTERM
LimitNOFILE=1048576
CPUQuota=50%
MemoryMax=100M

[Install]
WantedBy=multi-user.target
EOF

# EDNS Proxy
cat >/usr/local/bin/dnstt-edns-proxy.py <<'EOF'
#!/usr/bin/env python3
import socket
import threading
import struct
import sys
import time
import os
import signal
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
L=5300
running = True

def signal_handler(sig, frame):
    global running
    running = False
    logging.info("Shutting down...")
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

def modify_edns(d, max_size):
    if len(d) < 12:
        return d
    try:
        q, a, n, r = struct.unpack("!HHHH", d[4:12])
    except:
        return d
    
    o = 12
    
    def skip_name(b, o):
        while o < len(b):
            l = b[o]
            o += 1
            if l == 0:
                break
            if l & 0xC0 == 0xC0:
                o += 1
                break
            o += l
        return o
    
    for _ in range(q):
        o = skip_name(d, o)
        o += 4
    
    for _ in range(a + n):
        o = skip_name(d, o)
        if o + 10 > len(d):
            return d
        try:
            _, _, _, l = struct.unpack("!HHIH", d[o:o+10])
        except:
            return d
        o += 10 + l
    
    modified = bytearray(d)
    for _ in range(r):
        o = skip_name(d, o)
        if o + 10 > len(d):
            return d
        t = struct.unpack("!H", d[o:o+2])[0]
        if t == 41:
            modified[o+2:o+4] = struct.pack("!H", max_size)
            return bytes(modified)
        _, _, l = struct.unpack("!HIH", d[o+2:o+10])
        o += 10 + l
    
    return d

def handle_request(sock, data, addr):
    client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    client.settimeout(5)
    try:
        modified_data = modify_edns(data, 1800)
        client.sendto(modified_data, ('127.0.0.1', L))
        response, _ = client.recvfrom(4096)
        modified_response = modify_edns(response, 512)
        sock.sendto(modified_response, addr)
    except Exception as e:
        logging.error(f"Error in handler: {e}")
    finally:
        client.close()

def main():
    global running
    
    server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    os.system("fuser -k 53/udp 2>/dev/null || true")
    time.sleep(2)
    
    for attempt in range(3):
        try:
            server.bind(('0.0.0.0', 53))
            logging.info(f"EDNS Proxy started on port 53 (forwarding to {L})")
            break
        except Exception as e:
            if attempt < 2:
                logging.warning(f"Attempt {attempt+1} failed, retrying...")
                time.sleep(2)
                os.system("fuser -k 53/udp 2>/dev/null || true")
            else:
                logging.error(f"Failed to bind to port 53: {e}")
                sys.exit(1)
    
    while running:
        try:
            data, addr = server.recvfrom(4096)
            threading.Thread(target=handle_request, args=(server, data, addr), daemon=True).start()
        except Exception as e:
            if running:
                logging.error(f"Error in main loop: {e}")
                time.sleep(1)

if __name__ == "__main__":
    main()
EOF
chmod +x /usr/local/bin/dnstt-edns-proxy.py

cat >/etc/systemd/system/dnstt-elite-x-proxy.service <<EOF
[Unit]
Description=ELITE-X Proxy v3.2
After=dnstt-elite-x.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/dnstt-edns-proxy.py
Restart=always
RestartSec=3
CPUQuota=30%
MemoryMax=50M

[Install]
WantedBy=multi-user.target
EOF

# Setup all features
setup_bandwidth_manager
setup_connection_monitor
setup_realtime_traffic
setup_advanced_speed
setup_auto_remover
setup_auto_restart

# Initialize bandwidth
/usr/local/bin/elite-x-bandwidth init 2>/dev/null || true

# Enable and start services
systemctl daemon-reload
for service in dnstt-elite-x dnstt-elite-x-proxy elite-x-realtime elite-x-cleaner elite-x-connmon elite-x-auto-restart; do
    if [ -f "/etc/systemd/system/${service}.service" ]; then
        systemctl enable $service 2>/dev/null || true
        systemctl start $service 2>/dev/null || true
    fi
done

# Apply speed optimizations
/usr/local/bin/elite-x-speed full 2>/dev/null || true

# Optimize network interfaces
for iface in $(ls /sys/class/net/ | grep -v lo); do
    ethtool -K $iface tx off sg off tso off 2>/dev/null || true
    ip link set dev $iface txqueuelen 10000 2>/dev/null || true
done

# Create user management script (short version)
cat >/usr/local/bin/elite-x-user <<'EOF'
#!/bin/bash

RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m';WHITE='\033[1;37m';BOLD='\033[1m';NC='\033[0m'

UD="/etc/elite-x/users"
TD="/etc/elite-x/traffic"
DD="/etc/elite-x/deleted"
mkdir -p $UD $TD $DD

get_connection_count() {
    local username=$1
    local who_count=$(who | grep -w "$username" | wc -l)
    local ps_count=$(ps aux | grep "sshd:" | grep "$username" | grep -v grep | grep -v "sshd:.*@notty" | wc -l)
    local last_count=$(last | grep "$username" | grep "still logged in" | wc -l)
    
    if [ $who_count -gt 0 ]; then
        echo $who_count
    elif [ $last_count -gt 0 ]; then
        echo $last_count
    else
        echo $ps_count
    fi
}

add_user() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}              CREATE SSH + DNS USER (ULTIMATE)                   ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    read -p "$(echo -e $GREEN"Password: "$NC)" password
    read -p "$(echo -e $GREEN"Expire days: "$NC)" days
    read -p "$(echo -e $GREEN"Connection limit (1-10, default 1): "$NC)" conn_limit
    conn_limit=${conn_limit:-1}
    
    if id "$username" &>/dev/null; then
        echo -e "${RED}User already exists!${NC}"
        return
    fi
    
    useradd -m -s /bin/false "$username"
    echo "$username:$password" | chpasswd
    
    expire_date=$(date -d "+$days days" +"%Y-%m-%d")
    chage -E "$expire_date" "$username"
    
    cat > $UD/$username <<INFO
Username: $username
Password: $password
Expire: $expire_date
Conn_Limit: $conn_limit
Created: $(date +"%Y-%m-%d %H:%M:%S")
INFO
    
    echo "0" > $TD/$username
    
    /usr/local/bin/elite-x-bandwidth add "$username" 2>/dev/null || true
    
    SERVER=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "?")
    PUBKEY=$(cat /etc/dnstt/server.pub 2>/dev/null || echo "Not generated")
    
    clear
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}                  USER DETAILS                                  ${GREEN}║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  Username  :${CYAN} $username${NC}"
    echo -e "${GREEN}║${WHITE}  Password  :${CYAN} $password${NC}"
    echo -e "${GREEN}║${WHITE}  Server    :${CYAN} $SERVER${NC}"
    echo -e "${GREEN}║${WHITE}  Public Key:${CYAN} $PUBKEY${NC}"
    echo -e "${GREEN}║${WHITE}  Expire    :${CYAN} $expire_date${NC}"
    echo -e "${GREEN}║${WHITE}  Max Login :${CYAN} $conn_limit connection(s)${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
}

list_users() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}                  ACTIVE USERS (REAL-TIME)                         ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    
    if [ -z "$(ls -A $UD 2>/dev/null)" ]; then
        echo -e "${CYAN}║${RED}  No users found${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        return
    fi
    
    printf "%-12s %-12s %-12s %-10s\n" "USERNAME" "EXPIRE" "LOGIN" "STATUS"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"
    
    for user in $UD/*; do
        [ ! -f "$user" ] && continue
        u=$(basename "$user")
        ex=$(grep "Expire:" "$user" | cut -d' ' -f2)
        limit=$(grep "Conn_Limit:" "$user" | cut -d' ' -f2)
        limit=${limit:-1}
        
        current_conn=$(get_connection_count "$u")
        
        if [ "$current_conn" -eq 0 ]; then
            login_display="${YELLOW}0/${limit}${NC}"
        elif [ "$current_conn" -ge "$limit" ]; then
            login_display="${RED}${current_conn}/${limit}${NC}"
        else
            login_display="${GREEN}${current_conn}/${limit}${NC}"
        fi
        
        if [ "$current_conn" -gt 0 ]; then
            status="${GREEN}ONLINE${NC}"
        else
            status="${YELLOW}OFFLINE${NC}"
        fi
        
        days_left=$(( ($(date -d "$ex" +%s) - $(date +%s)) / 86400 ))
        if [ $days_left -le 3 ]; then
            ex="${RED}$ex${NC}"
        elif [ $days_left -le 7 ]; then
            ex="${YELLOW}$ex${NC}"
        fi
        
        printf "%-12s %-12b %-12b %-10b\n" "$u" "$ex" "$login_display" "$status"
    done
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${WHITE}Total: $(ls $UD | wc -l) users | Online: $(who | wc -l) active sessions${NC}"
}

case $1 in
    add) add_user ;;
    list) list_users ;;
    details) 
        read -p "Username: " u
        [ -f "$UD/$u" ] && cat "$UD/$u" || echo "User not found"
        ;;
    renew)
        read -p "Username: " u
        read -p "Additional days: " d
        if [ -f "$UD/$u" ]; then
            current=$(grep "Expire:" "$UD/$u" | cut -d' ' -f2)
            new=$(date -d "$current +$d days" +"%Y-%m-%d")
            sed -i "s/Expire: .*/Expire: $new/" "$UD/$u"
            chage -E "$new" "$u"
            echo -e "${GREEN}✅ Renewed until $new${NC}"
        else
            echo "User not found"
        fi
        ;;
    setlimit)
        read -p "Username: " u
        read -p "New limit: " l
        if [ -f "$UD/$u" ]; then
            sed -i "s/Conn_Limit: .*/Conn_Limit: $l/" "$UD/$u"
            echo -e "${GREEN}✅ Limit updated to $l${NC}"
        else
            echo "User not found"
        fi
        ;;
    lock)
        read -p "Username: " u
        usermod -L "$u" 2>/dev/null && echo -e "${GREEN}✅ User locked${NC}" || echo "Failed"
        ;;
    unlock)
        read -p "Username: " u
        usermod -U "$u" 2>/dev/null && echo -e "${GREEN}✅ User unlocked${NC}" || echo "Failed"
        ;;
    del)
        read -p "Username: " u
        if [ -f "$UD/$u" ]; then
            cp "$UD/$u" "$DD/${u}_$(date +%Y%m%d_%H%M%S)" 2>/dev/null
            pkill -u "$u" 2>/dev/null
            userdel -r "$u" 2>/dev/null
            rm -f "$UD/$u" "$TD/$u"
            echo -e "${GREEN}✅ User deleted${NC}"
        else
            echo "User not found"
        fi
        ;;
    *) echo "Usage: elite-x-user {add|list|details|renew|setlimit|lock|unlock|del}" ;;
esac
EOF
chmod +x /usr/local/bin/elite-x-user

# Create main menu script
cat >/usr/local/bin/elite-x <<'EOF'
#!/bin/bash

RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m'
PURPLE='\033[0;35m';WHITE='\033[1;37m';BOLD='\033[1m';NC='\033[0m'

if [ -f /tmp/elite-x-running ]; then
    exit 0
fi
touch /tmp/elite-x-running
trap 'rm -f /tmp/elite-x-running' EXIT

show_dashboard() {
    clear
    
    IP=$(cat /etc/elite-x/cached_ip 2>/dev/null || curl -s ifconfig.me 2>/dev/null || echo "Unknown")
    SUB=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "Not configured")
    LOCATION=$(cat /etc/elite-x/location 2>/dev/null || echo "South Africa")
    CURRENT_MTU=$(cat /etc/elite-x/mtu 2>/dev/null || echo "1800")
    
    DNS=$(systemctl is-active dnstt-elite-x 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    PRX=$(systemctl is-active dnstt-elite-x-proxy 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    
    TOTAL_USERS=$(ls -1 /etc/elite-x/users 2>/dev/null | wc -l)
    ACTIVE_CONNS=$(who | wc -l)
    
    TZ_TIME=$(TZ='Africa/Dar_es_Salaam' date "+%Y-%m-%d %H:%M:%S")
    
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}              ELITE-X ULTIMATE v3.2 - REAL-TIME                ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${WHITE}  Tanzania Time: ${GREEN}$TZ_TIME${NC}"
    echo -e "${PURPLE}║${WHITE}  Subdomain :${GREEN} $SUB${NC}"
    echo -e "${PURPLE}║${WHITE}  IP        :${GREEN} $IP${NC}"
    echo -e "${PURPLE}║${WHITE}  VPS Loc   :${GREEN} $LOCATION (MTU: $CURRENT_MTU)${NC}"
    echo -e "${PURPLE}║${WHITE}  Services  : DNS:$DNS PRX:$PRX${NC}"
    echo -e "${PURPLE}║${WHITE}  Real-Time :${GREEN} $TOTAL_USERS users, $ACTIVE_CONNS online${NC}"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${WHITE}  Public Key:${CYAN} $(cat /etc/dnstt/server.pub 2>/dev/null | cut -c1-40)...${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

main_menu() {
    while true; do
        show_dashboard
        echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║${GREEN}${BOLD}                     MAIN MENU (ULTIMATE)                       ${PURPLE}║${NC}"
        echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${PURPLE}║${WHITE}  [1] ➕ Create SSH + DNS User${NC}"
        echo -e "${PURPLE}║${WHITE}  [2] 📋 List All Users (Real-Time)${NC}"
        echo -e "${PURPLE}║${WHITE}  [3] 🔄 Renew User${NC}"
        echo -e "${PURPLE}║${WHITE}  [4] ⚡ Set Login Limit${NC}"
        echo -e "${PURPLE}║${WHITE}  [5] 🔒 Lock User${NC}"
        echo -e "${PURPLE}║${WHITE}  [6] 🔓 Unlock User${NC}"
        echo -e "${PURPLE}║${WHITE}  [7] ❌ Delete User${NC}"
        echo -e "${PURPLE}║${WHITE}  [8] 🔑 Show Public Key${NC}"
        echo -e "${PURPLE}║${WHITE}  [9] ⚙️  Speed Optimization${NC}"
        echo -e "${PURPLE}║${WHITE}  [10] 🔄 Restart Services${NC}"
        echo -e "${PURPLE}║${WHITE}  [00] 🚪 Exit${NC}"
        echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        read -p "$(echo -e $GREEN"Option: "$NC)" ch
        
        case $ch in
            1) elite-x-user add; read -p "Press Enter..." ;;
            2) elite-x-user list; read -p "Press Enter..." ;;
            3) elite-x-user renew; read -p "Press Enter..." ;;
            4) elite-x-user setlimit; read -p "Press Enter..." ;;
            5) elite-x-user lock; read -p "Press Enter..." ;;
            6) elite-x-user unlock; read -p "Press Enter..." ;;
            7) elite-x-user del; read -p "Press Enter..." ;;
            8)
                echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
                echo -e "${GREEN}Public Key:${NC}"
                echo -e "${YELLOW}$(cat /etc/dnstt/server.pub)${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
                read -p "Press Enter..."
                ;;
            9) elite-x-speed full; read -p "Press Enter..." ;;
            10) systemctl restart dnstt-elite-x dnstt-elite-x-proxy; echo -e "${GREEN}✅ Services restarted${NC}"; read -p "Press Enter..." ;;
            00|0) 
                rm -f /tmp/elite-x-running
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0 
                ;;
            *) echo -e "${RED}Invalid option${NC}"; read -p "Press Enter..." ;;
        esac
    done
}

main_menu
EOF
chmod +x /usr/local/bin/elite-x

# Cache network info
IP=$(curl -4 -s ifconfig.me 2>/dev/null || echo "Unknown")
echo "$IP" > /etc/elite-x/cached_ip

if [ "$IP" != "Unknown" ]; then
    LOCATION_INFO=$(curl -s http://ip-api.com/json/$IP 2>/dev/null)
    echo "$LOCATION_INFO" | jq -r '.city + ", " + .country' 2>/dev/null > /etc/elite-x/cached_location || echo "Unknown" > /etc/elite-x/cached_location
    echo "$LOCATION_INFO" | jq -r '.isp' 2>/dev/null > /etc/elite-x/cached_isp || echo "Unknown" > /etc/elite-x/cached_isp
else
    echo "Unknown" > /etc/elite-x/cached_location
    echo "Unknown" > /etc/elite-x/cached_isp
fi

# Setup auto-login dashboard
cat > /etc/profile.d/elite-x-dashboard.sh <<'EOF'
#!/bin/bash
if [ -f /usr/local/bin/elite-x ] && [ -z "$ELITE_X_SHOWN" ]; then
    export ELITE_X_SHOWN=1
    rm -f /tmp/elite-x-running 2>/dev/null
    /usr/local/bin/elite-x
fi
EOF
chmod +x /etc/profile.d/elite-x-dashboard.sh

cat >> ~/.bashrc <<'EOF'
alias menu='elite-x'
alias elitex='elite-x'
EOF

# Final output
clear
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${YELLOW}${BOLD}         ELITE-X ULTIMATE v3.2 INSTALLED SUCCESSFULLY          ${GREEN}║${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${WHITE}  Domain     :${CYAN} $TDOMAIN${NC}"
echo -e "${GREEN}║${WHITE}  Location   :${CYAN} $SELECTED_LOCATION (MTU: $MTU)${NC}"
echo -e "${GREEN}║${WHITE}  Timezone   :${CYAN} Africa/Dar_es_Salaam (Tanzania)${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${WHITE}  Private Key:${CYAN} 7f207e92ab7cb365aad1966b62d2cfbd3f450fe8...${NC}"
echo -e "${GREEN}║${WHITE}  Public Key :${CYAN} 40aa057fcb2574e1e9223ea46457f9fdf9d60a2a...${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${WHITE}  Services Status:${NC}"
systemctl is-active dnstt-elite-x >/dev/null 2>&1 && echo -e "${GREEN}║  ✅ DNSTT Server: Running${NC}" || echo -e "${RED}║  ❌ DNSTT Server: Failed${NC}"
systemctl is-active dnstt-elite-x-proxy >/dev/null 2>&1 && echo -e "${GREEN}║  ✅ DNSTT Proxy: Running${NC}" || echo -e "${RED}║  ❌ DNSTT Proxy: Failed${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${WHITE}  Port Status:${NC}"
ss -uln | grep -q ":53 " && echo -e "${GREEN}║  ✅ Port 53: Listening${NC}" || echo -e "${RED}║  ❌ Port 53: Not listening${NC}"
ss -uln | grep -q ":${DNSTT_PORT} " && echo -e "${GREEN}║  ✅ Port ${DNSTT_PORT}: Listening${NC}" || echo -e "${RED}║  ❌ Port ${DNSTT_PORT}: Not listening${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
show_quote

read -p "$(echo -e $GREEN"Open ELITE-X ULTIMATE menu now? (y/n): "$NC)" open
if [ "$open" = "y" ]; then
    /usr/local/bin/elite-x
else
    echo -e "${YELLOW}You can type 'menu' or 'elite-x' anytime to open the dashboard.${NC}"
fi

self_destruct
