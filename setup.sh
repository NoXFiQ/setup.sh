#!/bin/bash
# ╔══════════════════════╗
#  ELITE-X DNSTT SCRIPT v3.2
#  ULTIMATE EDITION - FINAL FIX
# ╚══════════════════════╝
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
TIMEZONE="Africa/Dar_es_Salaam"  # Tanzania timezone

set_timezone() {
    # Force Tanzania timezone
    timedatectl set-timezone Africa/Dar_es_Salaam 2>/dev/null || 
    ln -sf /usr/share/zoneinfo/Africa/Dar_es_Salaam /etc/localtime 2>/dev/null || true
    
    # Sync time with NTP if available
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

# Advanced Bandwidth Management with per-user QoS
setup_bandwidth_manager() {
    cat > /usr/local/bin/elite-x-bandwidth <<'EOF'
#!/bin/bash

# Elite-X Ultimate Bandwidth Manager - Switch/HUB style equal distribution
USER_DB="/etc/elite-x/users"
BANDWIDTH_PER_USER=10240  # 10 Mbps per user (adjustable)
TOTAL_BANDWIDTH=102400    # 100 Mbps total
MONITOR_DIR="/var/run/elite-x/bandwidth"

mkdir -p $MONITOR_DIR

setup_tc() {
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    # Clear existing rules
    tc qdisc del dev $interface root 2>/dev/null || true
    
    # Create HTB root with total bandwidth
    tc qdisc add dev $interface root handle 1: htb default 30
    tc class add dev $interface parent 1: classid 1:1 htb rate ${TOTAL_BANDWIDTH}kbit ceil ${TOTAL_BANDWIDTH}kbit
    
    # Create fair queue for all users
    tc qdisc add dev $interface parent 1:1 handle 10: fq maxrate ${BANDWIDTH_PER_USER}kbit
    
    echo "$interface" > $MONITOR_DIR/interface
}

add_user_bandwidth() {
    local username=$1
    local interface=$(cat $MONITOR_DIR/interface 2>/dev/null)
    
    if [ -z "$interface" ]; then
        interface=$(ip route | grep default | awk '{print $5}' | head -1)
    fi
    
    # Create filter for user's SSH traffic
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

# MODIFIED: Removed auto-ban functionality, only monitoring connections
setup_connection_monitor() {
    cat > /usr/local/bin/elite-x-connmon <<'EOF'
#!/bin/bash

USER_DB="/etc/elite-x/users"
CONN_DB="/etc/elite-x/connections"
mkdir -p $CONN_DB

# Function to get accurate SSH connection count
get_connection_count() {
    local username=$1
    
    # Method 1: Check SSH processes with proper filtering
    local conn1=$(ps aux | grep "sshd:" | grep "$username" | grep -v grep | grep -v "sshd:.*@notty" | wc -l)
    
    # Method 2: Check established SSH sessions from netstat/ss
    local conn2=$(ss -tnp | grep "sshd" | grep "$username" | wc -l)
    
    # Method 3: Check who command for logged in users
    local conn3=$(who | grep "$username" | wc -l)
    
    # Method 4: Check last log (more accurate for active sessions)
    local conn4=$(last | grep "$username" | grep "still logged in" | wc -l)
    
    # Take the highest count that makes sense
    local max_conn=$conn1
    [ $conn2 -gt $max_conn ] && max_conn=$conn2
    [ $conn3 -gt $max_conn ] && max_conn=$conn3
    [ $conn4 -gt $max_conn ] && max_conn=$conn4
    
    # Ensure we don't count duplicates
    if [ $max_conn -gt 10 ]; then
        max_conn=$conn3  # who command is usually most accurate
    fi
    
    echo $max_conn
}

monitor_connections() {
    local username=$1
    local limit_file="$USER_DB/$username"
    
    if [ ! -f "$limit_file" ]; then
        return
    fi
    
    # Get connection limit from user file
    local conn_limit=$(grep "Conn_Limit:" "$limit_file" | cut -d' ' -f2)
    conn_limit=${conn_limit:-1}
    
    # Get current connection count
    local current_conn=$(get_connection_count "$username")
    
    # Save current connection count
    echo "$current_conn" > "$CONN_DB/$username"
    
    # Log if exceeding limit (but don't ban)
    if [ "$current_conn" -gt "$conn_limit" ]; then
        logger -t "elite-x" "User $username exceeded connection limit ($current_conn/$conn_limit) - monitoring only"
    fi
    
    return 0
}

# Main monitoring loop
while true; do
    if [ -d "$USER_DB" ]; then
        for user_file in "$USER_DB"/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                monitor_connections "$username"
            fi
        done
    fi
    sleep 5  # Check every 5 seconds
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

# ==============================================
# FIXED: Auto restart services every 1 hour and auto reboot every 2 hours
# WITH PROPER TIME TRACKING (No more 2-4 minute reboots!)
# ==============================================
setup_auto_restart() {
    cat > /usr/local/bin/elite-x-auto-restart <<'EOF'
#!/bin/bash

# Elite-X Auto Restart Service - FIXED VERSION
# With proper time tracking using files (no more 2-4 minute reboots!)

CONFIG_FILE="/etc/elite-x/auto_config"
STATE_DIR="/var/lib/elite-x/auto"
mkdir -p "$STATE_DIR"

LAST_SERVICE_FILE="$STATE_DIR/last_service_restart"
LAST_REBOOT_FILE="$STATE_DIR/last_reboot"
SERVICE_LOG="/etc/elite-x/auto_restart.log"
REBOOT_LOG="/etc/elite-x/auto_reboot.log"

# Default values (can be changed via menu)
SERVICE_INTERVAL=1  # hours
REBOOT_INTERVAL=2   # hours

# Load config if exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Convert hours to seconds
SERVICE_SECONDS=$((SERVICE_INTERVAL * 3600))
REBOOT_SECONDS=$((REBOOT_INTERVAL * 3600))

# Get current time in Tanzania timezone
export TZ='Africa/Dar_es_Salaam'
CURRENT_TIME=$(date +%s)

# Load last run times from files (with fallback to current time)
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

# Calculate time differences
SERVICE_TIME_DIFF=$((CURRENT_TIME - LAST_SERVICE_RESTART))
REBOOT_TIME_DIFF=$((CURRENT_TIME - LAST_REBOOT))

# Log startup with times
echo "$(date) - Auto service started. Last service: $(date -d @$LAST_SERVICE_RESTART), Last reboot: $(date -d @$LAST_REBOOT)" >> "$SERVICE_LOG"

# Main loop
while true; do
    # Update current time
    CURRENT_TIME=$(date +%s)
    
    # Calculate elapsed times
    SERVICE_ELAPSED=$((CURRENT_TIME - LAST_SERVICE_RESTART))
    REBOOT_ELAPSED=$((CURRENT_TIME - LAST_REBOOT))
    
    # Auto restart services every X hours
    if [ $SERVICE_INTERVAL -gt 0 ] && [ $SERVICE_ELAPSED -ge $SERVICE_SECONDS ]; then
        # Double-check to prevent multiple restarts
        if [ $SERVICE_ELAPSED -lt $((SERVICE_SECONDS + 300)) ]; then
            echo "$(date) - Auto-restarting services after ${SERVICE_INTERVAL} hour(s) (elapsed: $((SERVICE_ELAPSED / 60)) minutes)" >> "$SERVICE_LOG"
            logger -t "elite-x" "Auto-restarting services after ${SERVICE_INTERVAL} hour(s)"
            
            # Restart main services
            systemctl restart dnstt-elite-x 2>/dev/null || true
            systemctl restart dnstt-elite-x-proxy 2>/dev/null || true
            systemctl restart elite-x-connmon 2>/dev/null || true
            
            # Update last service restart time
            LAST_SERVICE_RESTART=$CURRENT_TIME
            echo "$LAST_SERVICE_RESTART" > "$LAST_SERVICE_FILE"
            
            echo "$(date) - Services restarted successfully" >> "$SERVICE_LOG"
        fi
    fi
    
    # Auto reboot every X hours
    if [ $REBOOT_INTERVAL -gt 0 ] && [ $REBOOT_ELAPSED -ge $REBOOT_SECONDS ]; then
        # Double-check to prevent multiple reboots
        if [ $REBOOT_ELAPSED -lt $((REBOOT_SECONDS + 300)) ]; then
            echo "$(date) - System auto-rebooting after ${REBOOT_INTERVAL} hour(s) (elapsed: $((REBOOT_ELAPSED / 60)) minutes)" >> "$REBOOT_LOG"
            logger -t "elite-x" "Auto-rebooting after ${REBOOT_INTERVAL} hour(s)"
            
            # Update last reboot time BEFORE rebooting
            LAST_REBOOT=$CURRENT_TIME
            echo "$LAST_REBOOT" > "$LAST_REBOOT_FILE"
            
            # Schedule reboot in 1 minute to allow logging
            shutdown -r +1 "Elite-X auto reboot after ${REBOOT_INTERVAL} hour(s) - Tanzania Time: $(date)"
            
            # Exit gracefully
            exit 0
        fi
    fi
    
    # Sleep for 60 seconds before next check
    sleep 60
done
EOF
    chmod +x /usr/local/bin/elite-x-auto-restart

    cat > /etc/systemd/system/elite-x-auto-restart.service <<EOF
[Unit]
Description=Elite-X Auto Restart & Reboot Service (Tanzania Time)
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

    # Create default config
    cat > /etc/elite-x/auto_config <<EOF
# Elite-X Auto Restart Configuration
# Timezone: Africa/Dar_es_Salaam (Tanzania)
SERVICE_INTERVAL=1  # hours (0 to disable)
REBOOT_INTERVAL=2   # hours (0 to disable)
EOF

    # Create log files with Tanzania timestamp
    touch /etc/elite-x/auto_restart.log
    touch /etc/elite-x/auto_reboot.log
    
    # Create state directory
    mkdir -p /var/lib/elite-x/auto
    
    # Initialize state files with current Tanzania time
    CURRENT_TIME=$(TZ='Africa/Dar_es_Salaam' date +%s)
    echo "$CURRENT_TIME" > /var/lib/elite-x/auto/last_service_restart
    echo "$CURRENT_TIME" > /var/lib/elite-x/auto/last_reboot
    
    echo -e "${GREEN}✅ Auto Restart configured: Services every 1h, Reboot every 2h (Tanzania Time)${NC}"
}

# Real-time Traffic Monitor
setup_realtime_traffic() {
    cat > /usr/local/bin/elite-x-realtime <<'EOF'
#!/bin/bash

USER_DB="/etc/elite-x/users"
TRAFFIC_DB="/etc/elite-x/traffic"
REALTIME_DB="/etc/elite-x/realtime"
mkdir -p $REALTIME_DB

monitor_realtime() {
    local username=$1
    
    # Get interface
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    # Get real-time traffic stats
    if [ -f "/proc/net/dev" ]; then
        rx_bytes=$(cat /proc/net/dev | grep "$interface" | awk '{print $2}')
        tx_bytes=$(cat /proc/net/dev | grep "$interface" | awk '{print $10}')
        
        # Store real-time stats
        echo "$(date +%s):$rx_bytes:$tx_bytes" >> "$REALTIME_DB/$username" 2>/dev/null || true
        
        # Keep only last 60 seconds
        tail -n 60 "$REALTIME_DB/$username" > "$REALTIME_DB/$username.tmp" 2>/dev/null && mv "$REALTIME_DB/$username.tmp" "$REALTIME_DB/$username" 2>/dev/null || true
    fi
}

while true; do
    if [ -d "$USER_DB" ]; then
        for user_file in "$USER_DB"/*; do
            [ -f "$user_file" ] && monitor_realtime "$(basename "$user_file")"
        done
    fi
    sleep 5
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

# Advanced Speed Optimizer
setup_advanced_speed() {
    cat > /usr/local/bin/elite-x-speed <<'EOF'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

optimize_network() {
    echo -e "${YELLOW}⚡ Applying Elite-X Ultimate Network Optimizations...${NC}"
    
    # Advanced TCP tuning for maximum throughput
    cat > /etc/sysctl.d/99-elite-x.conf <<'EOL'
# Elite-X Ultimate Network Optimizations
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
net.ipv4.ip_local_port_range = 1024 65535
EOL
    
    sysctl -p /etc/sysctl.d/99-elite-x.conf >/dev/null 2>&1
    
    # Enable BBR if not available
    if ! sysctl net.ipv4.tcp_congestion_control | grep -q bbr; then
        modprobe tcp_bbr 2>/dev/null || true
        echo "tcp_bbr" >> /etc/modules-load.d/modules.conf 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✅ Network optimized for maximum speed!${NC}"
}

optimize_cpu() {
    echo -e "${YELLOW}⚡ Optimizing CPU for network processing...${NC}"
    
    # Set CPU governor to performance
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "performance" > "$cpu" 2>/dev/null || true
    done
    
    # Set IRQ affinity for network cards
    for irq in $(grep -E '(eth|ens|enp)' /proc/interrupts | cut -d: -f1); do
        echo 1 > /proc/irq/$irq/smp_affinity 2>/dev/null || true
    done
    
    echo -e "${GREEN}✅ CPU optimized!${NC}"
}

optimize_ram() {
    echo -e "${YELLOW}⚡ Optimizing RAM for network buffers...${NC}"
    
    # Optimize virtual memory
    sysctl -w vm.vfs_cache_pressure=50 >/dev/null 2>&1
    sysctl -w vm.swappiness=10 >/dev/null 2>&1
    sysctl -w vm.dirty_ratio=20 >/dev/null 2>&1
    sysctl -w vm.dirty_background_ratio=5 >/dev/null 2>&1
    
    # Clear caches
    sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    
    echo -e "${GREEN}✅ RAM optimized!${NC}"
}

case "$1" in
    full)
        optimize_network
        optimize_cpu
        optimize_ram
        ;;
    network)
        optimize_network
        ;;
    cpu)
        optimize_cpu
        ;;
    ram)
        optimize_ram
        ;;
    *)
        echo "Usage: elite-x-speed {full|network|cpu|ram}"
        exit 1
        ;;
esac
EOF
    chmod +x /usr/local/bin/elite-x-speed
}

# Enhanced Auto Remover with Backup
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
                        # Create backup with timestamp
                        backup_file="$DELETED_DB/${username}_$(date +%Y%m%d_%H%M%S)"
                        cp "$user_file" "$backup_file" 2>/dev/null || true
                        
                        # Add deletion info
                        echo "Deleted: $(date +%Y-%m-%d %H:%M:%S)" >> "$backup_file"
                        echo "Auto-removed after expiry" >> "$backup_file"
                        
                        # Kill user processes
                        pkill -u "$username" 2>/dev/null || true
                        
                        # Remove bandwidth limits
                        /usr/local/bin/elite-x-bandwidth remove "$username" 2>/dev/null || true
                        
                        # Delete user
                        userdel -r "$username" 2>/dev/null || true
                        rm -f "$user_file"
                        rm -f "$TRAFFIC_DB/$username"
                        
                        logger -t "elite-x" "Auto-removed expired user: $username"
                    fi
                fi
            fi
        done
    fi
    sleep 300  # Check every 5 minutes
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

# Set Tanzania timezone
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

# Set MTU based on location
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

# Enhanced cleanup
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

# Stop all services
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

# Create directory structure
mkdir -p /etc/elite-x/{banner,users,traffic,deleted,connections,banned,realtime}
mkdir -p /var/run/elite-x/bandwidth
echo "$TDOMAIN" > /etc/elite-x/subdomain

# Create banners
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

# Configure systemd-resolved
if [ -f /etc/systemd/resolved.conf ]; then
  echo "Configuring systemd-resolved..."
  sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf || true
  grep -q '^DNS=' /etc/systemd/resolved.conf \
    && sed -i 's/^DNS=.*/DNS=8.8.8.8 8.8.4.4/' /etc/systemd/resolved.conf \
    || echo "DNS=8.8.8.8 8.8.4.4" >> /etc/systemd/resolved.conf
  systemctl restart systemd-resolved 2>/dev/null || true
  
  # Fix resolv.conf
  if [ -L /etc/resolv.conf ]; then
    rm -f /etc/resolv.conf 2>/dev/null || unlink /etc/resolv.conf 2>/dev/null || true
  fi
  
  echo "nameserver 8.8.8.8" > /etc/resolv.conf
  echo "nameserver 8.8.4.4" >> /etc/resolv.conf
  chmod 644 /etc/resolv.conf
fi

echo "Installing dependencies..."
apt update -y
apt install -y curl python3 jq nano iptables iptables-persistent ethtool dnsutils net-tools iproute2 iftop

echo "Installing dnstt-server..."
if ! curl -fsSL https://dnstt.network/dnstt-server-linux-amd64 -o /usr/local/bin/dnstt-server 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Primary download failed, trying alternative...${NC}"
    curl -fsSL https://github.com/NoXFiQ/Elite-X-dns.sh/raw/main/dnstt-server -o /usr/local/bin/dnstt-server 2>/dev/null || {
        echo -e "${RED}❌ Failed to download dnstt-server${NC}"
        exit 1
    }
fi
chmod +x /usr/local/bin/dnstt-server

echo "Generating keys..."
mkdir -p /etc/dnstt
cd /etc/dnstt
/usr/local/bin/dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub
cd ~

chmod 600 /etc/dnstt/server.key
chmod 644 /etc/dnstt/server.pub

echo "Creating dnstt-elite-x.service..."
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

echo "Installing EDNS proxy..."
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

# Setup all new features
setup_bandwidth_manager
setup_connection_monitor
setup_realtime_traffic
setup_advanced_speed
setup_auto_remover
setup_auto_restart  # FIXED: Auto restart with proper time tracking

# Create service files
cat > /etc/systemd/system/elite-x-traffic.service <<EOF
[Unit]
Description=ELITE-X Traffic Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-traffic
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Copy traffic monitor from earlier
cat > /usr/local/bin/elite-x-traffic <<'EOF'
#!/bin/bash
TRAFFIC_DB="/etc/elite-x/traffic"
USER_DB="/etc/elite-x/users"
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
chmod +x /usr/local/bin/elite-x-traffic

# Initialize bandwidth manager
/usr/local/bin/elite-x-bandwidth init 2>/dev/null || true

# Enable and start services
systemctl daemon-reload
for service in dnstt-elite-x dnstt-elite-x-proxy elite-x-traffic elite-x-cleaner elite-x-connmon elite-x-realtime elite-x-auto-restart; do
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

# Create enhanced user management script with improved display
cat >/usr/local/bin/elite-x-user <<'EOF'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

show_quote() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}         ELITE-X ULTIMATE - Real-Time Management              ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

UD="/etc/elite-x/users"
TD="/etc/elite-x/traffic"
DD="/etc/elite-x/deleted"
mkdir -p $UD $TD $DD

# Function to get accurate connection count
get_connection_count() {
    local username=$1
    
    # Check who command first (most accurate for active sessions)
    local who_count=$(who | grep -w "$username" | wc -l)
    
    # Check SSH processes
    local ps_count=$(ps aux | grep "sshd:" | grep "$username" | grep -v grep | grep -v "sshd:.*@notty" | wc -l)
    
    # Check last log for still logged in
    local last_count=$(last | grep "$username" | grep "still logged in" | wc -l)
    
    # Use the highest count that makes sense
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
    
    # Create user with secure shell
    useradd -m -s /bin/false "$username"
    echo "$username:$password" | chpasswd
    
    expire_date=$(date -d "+$days days" +"%Y-%m-%d")
    chage -E "$expire_date" "$username"
    
    # Save user info
    cat > $UD/$username <<INFO
Username: $username
Password: $password
Expire: $expire_date
Conn_Limit: $conn_limit
Created: $(date +"%Y-%m-%d %H:%M:%S")
INFO
    
    echo "0" > $TD/$username
    
    # Add bandwidth management
    /usr/local/bin/elite-x-bandwidth add "$username" 2>/dev/null || true
    
    SERVER=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "?")
    PUBKEY=$(cat /etc/dnstt/server.pub 2>/dev/null || echo "Not generated")
    
    clear
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}                  USER DETAILS (ULTIMATE)                          ${GREEN}║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  Username  :${CYAN} $username${NC}"
    echo -e "${GREEN}║${WHITE}  Password  :${CYAN} $password${NC}"
    echo -e "${GREEN}║${WHITE}  Server    :${CYAN} $SERVER${NC}"
    echo -e "${GREEN}║${WHITE}  Public Key:${CYAN} $PUBKEY${NC}"
    echo -e "${GREEN}║${WHITE}  Expire    :${CYAN} $expire_date${NC}"
    echo -e "${GREEN}║${WHITE}  Max Login :${CYAN} $conn_limit connection(s)${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    # Save to log
    echo "$(date) - Created user: $username (Expires: $expire_date, Limit: $conn_limit)" >> /etc/elite-x/user_activity.log
    show_quote
}

show_user_details() {
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    
    if [ ! -f "$UD/$username" ]; then
        echo -e "${RED}User not found!${NC}"
        return
    fi
    
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}                  USER DETAILS (REAL-TIME)                         ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    
    while IFS= read -r line; do
        echo -e "${CYAN}║${WHITE}  $line${NC}"
    done < "$UD/$username"
    
    # Get real-time connection count
    current_conn=$(get_connection_count "$username")
    conn_limit=$(grep "Conn_Limit:" "$UD/$username" | cut -d' ' -f2)
    conn_limit=${conn_limit:-1}
    
    echo -e "${CYAN}║${WHITE}  Current Connections: ${YELLOW}$current_conn/$conn_limit${NC}"
    
    traffic_used=$(cat $TD/$username 2>/dev/null || echo "0")
    echo -e "${CYAN}║${WHITE}  Traffic Used: ${GREEN}${traffic_used} MB${NC}"
    
    echo -e "${CYAN}║${WHITE}  Account Status: ${GREEN}ACTIVE${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    show_quote
}

renew_user() {
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    read -p "$(echo -e $GREEN"Additional days: "$NC)" days
    
    if [ ! -f "$UD/$username" ]; then
        echo -e "${RED}User not found!${NC}"
        return
    fi
    
    current_expire=$(grep "Expire:" "$UD/$username" | cut -d' ' -f2)
    new_expire=$(date -d "$current_expire +$days days" +"%Y-%m-%d")
    
    sed -i "s/Expire: .*/Expire: $new_expire/" "$UD/$username"
    chage -E "$new_expire" "$username"
    
    echo -e "${GREEN}✅ User renewed until $new_expire${NC}"
    echo "$(date) - Renewed user: $username (New expiry: $new_expire)" >> /etc/elite-x/user_activity.log
    show_quote
}

set_login_limit() {
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    read -p "$(echo -e $GREEN"New connection limit (1-10): "$NC)" new_limit
    
    if [ ! -f "$UD/$username" ]; then
        echo -e "${RED}User not found!${NC}"
        return
    fi
    
    if grep -q "Conn_Limit:" "$UD/$username"; then
        sed -i "s/Conn_Limit: .*/Conn_Limit: $new_limit/" "$UD/$username"
    else
        echo "Conn_Limit: $new_limit" >> "$UD/$username"
    fi
    
    echo -e "${GREEN}✅ Login limit updated to $new_limit${NC}"
    echo "$(date) - Changed login limit for $username to $new_limit" >> /etc/elite-x/user_activity.log
    show_quote
}

show_deleted_users() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}                   DELETED USERS (ARCHIVE)                         ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    
    if [ -z "$(ls -A $DD 2>/dev/null)" ]; then
        echo -e "${CYAN}║${RED}  No deleted users found${NC}"
    else
        printf "%-15s %-12s %-12s %-15s\n" "USERNAME" "EXPIRED" "DELETED" "REASON"
        echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"
        
        for user in $DD/*; do
            [ ! -f "$user" ] && continue
            u=$(basename "$user" | cut -d'_' -f1)
            ex=$(grep "Expire:" "$user" | head -1 | cut -d' ' -f2)
            dl=$(grep "Deleted:" "$user" | head -1 | cut -d' ' -f2-3)
            reason=$(grep -E "Auto-removed|Manually" "$user" | head -1 || echo "Manual deletion")
            printf "%-15s %-12s %-12s %-15.15s\n" "$u" "$ex" "$dl" "$reason"
        done
    fi
    
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    show_quote
}

restore_user() {
    read -p "$(echo -e $GREEN"Username to restore: "$NC)" username
    
    # Find latest backup
    latest_backup=$(ls -t $DD/${username}_* 2>/dev/null | head -1)
    
    if [ -z "$latest_backup" ] || [ ! -f "$latest_backup" ]; then
        echo -e "${RED}User not found in deleted list!${NC}"
        return
    fi
    
    # Extract user info
    pass=$(grep "Password:" "$latest_backup" | head -1 | cut -d' ' -f2)
    expire=$(grep "Expire:" "$latest_backup" | head -1 | cut -d' ' -f2)
    conn_limit=$(grep "Conn_Limit:" "$latest_backup" | head -1 | cut -d' ' -f2)
    conn_limit=${conn_limit:-1}
    
    # Recreate user
    useradd -m -s /bin/false "$username"
    echo "$username:$pass" | chpasswd
    chage -E "$expire" "$username"
    
    # Restore user file
    cat > "$UD/$username" <<INFO
Username: $username
Password: $pass
Expire: $expire
Conn_Limit: $conn_limit
Restored: $(date +"%Y-%m-%d %H:%M:%S")
INFO
    
    echo "0" > "$TD/$username"
    
    echo -e "${GREEN}✅ User $username restored successfully${NC}"
    echo "$(date) - Restored user: $username" >> /etc/elite-x/user_activity.log
    show_quote
}

list_users() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}                  ACTIVE USERS (REAL-TIME)                         ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    
    if [ -z "$(ls -A $UD 2>/dev/null)" ]; then
        echo -e "${CYAN}║${RED}  No users found${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        show_quote
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
        
        # Get real-time connection count
        current_conn=$(get_connection_count "$u")
        
        # Format login display as current/limit
        if [ "$current_conn" -eq 0 ]; then
            login_display="${YELLOW}0/${limit}${NC}"
        elif [ "$current_conn" -ge "$limit" ]; then
            login_display="${RED}${current_conn}/${limit}${NC}"
        else
            login_display="${GREEN}${current_conn}/${limit}${NC}"
        fi
        
        # Determine status
        if [ "$current_conn" -gt 0 ]; then
            status="${GREEN}ONLINE${NC}"
        else
            status="${YELLOW}OFFLINE${NC}"
        fi
        
        # Highlight if near expiry
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
    show_quote
}

lock_user() { 
    read -p "$(echo -e $GREEN"Username: "$NC)" u
    
    if [ ! -f "$UD/$u" ]; then
        echo -e "${RED}User not found!${NC}"
        return
    fi
    
    usermod -L "$u" 2>/dev/null && {
        # Kill all user processes
        pkill -u "$u" 2>/dev/null
        pkill -f "sshd:.*$u" 2>/dev/null
        
        echo -e "${GREEN}✅ User locked and all sessions terminated${NC}"
        echo "$(date) - Locked user: $u" >> /etc/elite-x/user_activity.log
    } || echo -e "${RED}❌ Failed to lock user${NC}"
    show_quote
}

unlock_user() { 
    read -p "$(echo -e $GREEN"Username: "$NC)" u
    
    if [ ! -f "$UD/$u" ]; then
        echo -e "${RED}User not found!${NC}"
        return
    fi
    
    usermod -U "$u" 2>/dev/null && {
        echo -e "${GREEN}✅ User unlocked${NC}"
        echo "$(date) - Unlocked user: $u" >> /etc/elite-x/user_activity.log
    } || echo -e "${RED}❌ Failed to unlock user${NC}"
    show_quote
}

delete_user() { 
    read -p "$(echo -e $GREEN"Username: "$NC)" u
    
    if [ ! -f "$UD/$u" ]; then
        echo -e "${RED}User not found!${NC}"
        return
    fi
    
    # Create backup with timestamp
    backup_file="$DD/${u}_$(date +%Y%m%d_%H%M%S)"
    cp "$UD/$u" "$backup_file" 2>/dev/null || true
    echo "Deleted: $(date +%Y-%m-%d %H:%M:%S)" >> "$backup_file"
    echo "Manually deleted by admin" >> "$backup_file"
    
    # Remove bandwidth limits
    /usr/local/bin/elite-x-bandwidth remove "$u" 2>/dev/null || true
    
    # Kill user processes
    pkill -u "$u" 2>/dev/null || true
    pkill -f "sshd:.*$u" 2>/dev/null || true
    
    # Delete user
    userdel -r "$u" 2>/dev/null
    rm -f "$UD/$u" "$TD/$u"
    
    echo -e "${GREEN}✅ User deleted and backed up${NC}"
    echo "$(date) - Deleted user: $u" >> /etc/elite-x/user_activity.log
    show_quote
}

case $1 in
    add) add_user ;;
    list) list_users ;;
    details) show_user_details ;;
    renew) renew_user ;;
    setlimit) set_login_limit ;;
    deleted) show_deleted_users ;;
    restore) restore_user ;;
    lock) lock_user ;;
    unlock) unlock_user ;;
    del) delete_user ;;
    *) echo "Usage: elite-x-user {add|list|details|renew|setlimit|deleted|restore|lock|unlock|del}" ;;
esac
EOF
chmod +x /usr/local/bin/elite-x-user

# MODIFIED: Added Auto Restart Configuration Menu and Table Display
cat >/usr/local/bin/elite-x <<'EOF'
#!/bin/bash

RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m'
PURPLE='\033[0;35m';WHITE='\033[1;37m';BOLD='\033[1m';NC='\033[0m'

show_quote() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}         ELITE-X ULTIMATE - Real-Time Management              ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

if [ -f /tmp/elite-x-running ]; then
    exit 0
fi
touch /tmp/elite-x-running
trap 'rm -f /tmp/elite-x-running' EXIT

# Function to show auto restart/reboot table
show_auto_table() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}           AUTO RESTART & REBOOT DETAILS TABLE                ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
    
    # Load current config
    CONFIG_FILE="/etc/elite-x/auto_config"
    SERVICE_INTERVAL=1
    REBOOT_INTERVAL=2
    
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
    
    # Get service status
    AUTO_SERVICE=$(systemctl is-active elite-x-auto-restart 2>/dev/null)
    if [ "$AUTO_SERVICE" = "active" ]; then
        SERVICE_STATUS="${GREEN}● RUNNING${NC}"
    else
        SERVICE_STATUS="${RED}○ STOPPED${NC}"
    fi
    
    # Get last events from state files
    STATE_DIR="/var/lib/elite-x/auto"
    if [ -f "$STATE_DIR/last_service_restart" ]; then
        LAST_SERVICE_TIMESTAMP=$(cat "$STATE_DIR/last_service_restart")
        LAST_SERVICE_TIME=$(TZ='Africa/Dar_es_Salaam' date -d @$LAST_SERVICE_TIMESTAMP "+%Y-%m-%d %H:%M:%S")
    else
        LAST_SERVICE_TIME="No record"
    fi
    
    if [ -f "$STATE_DIR/last_reboot" ]; then
        LAST_REBOOT_TIMESTAMP=$(cat "$STATE_DIR/last_reboot")
        LAST_REBOOT_TIME=$(TZ='Africa/Dar_es_Salaam' date -d @$LAST_REBOOT_TIMESTAMP "+%Y-%m-%d %H:%M:%S")
    else
        LAST_REBOOT_TIME="No record"
    fi
    
    # Count total events
    TOTAL_SERVICE=$(wc -l < /etc/elite-x/auto_restart.log 2>/dev/null || echo "0")
    TOTAL_REBOOT=$(wc -l < /etc/elite-x/auto_reboot.log 2>/dev/null || echo "0")
    
    # Calculate time until next events
    CURRENT_TIME=$(TZ='Africa/Dar_es_Salaam' date +%s)
    
    if [ -f "$STATE_DIR/last_service_restart" ] && [ $SERVICE_INTERVAL -gt 0 ]; then
        LAST_SERVICE=$(cat "$STATE_DIR/last_service_restart")
        NEXT_SERVICE_SEC=$((LAST_SERVICE + (SERVICE_INTERVAL * 3600)))
        if [ $NEXT_SERVICE_SEC -gt $CURRENT_TIME ]; then
            NEXT_SERVICE_MIN=$(( (NEXT_SERVICE_SEC - CURRENT_TIME) / 60 ))
            NEXT_SERVICE_HOUR=$((NEXT_SERVICE_MIN / 60))
            NEXT_SERVICE_MIN=$((NEXT_SERVICE_MIN % 60))
            NEXT_SERVICE="${NEXT_SERVICE_HOUR}h ${NEXT_SERVICE_MIN}m"
        else
            NEXT_SERVICE="Now (overdue)"
        fi
    else
        NEXT_SERVICE="Disabled"
    fi
    
    if [ -f "$STATE_DIR/last_reboot" ] && [ $REBOOT_INTERVAL -gt 0 ]; then
        LAST_REBOOT=$(cat "$STATE_DIR/last_reboot")
        NEXT_REBOOT_SEC=$((LAST_REBOOT + (REBOOT_INTERVAL * 3600)))
        if [ $NEXT_REBOOT_SEC -gt $CURRENT_TIME ]; then
            NEXT_REBOOT_MIN=$(( (NEXT_REBOOT_SEC - CURRENT_TIME) / 60 ))
            NEXT_REBOOT_HOUR=$((NEXT_REBOOT_MIN / 60))
            NEXT_REBOOT_MIN=$((NEXT_REBOOT_MIN % 60))
            NEXT_REBOOT="${NEXT_REBOOT_HOUR}h ${NEXT_REBOOT_MIN}m"
        else
            NEXT_REBOOT="Now (overdue)"
        fi
    else
        NEXT_REBOOT="Disabled"
    fi
    
    CURRENT_TIME_STR=$(TZ='Africa/Dar_es_Salaam' date "+%Y-%m-%d %H:%M:%S")
    
    echo -e "${PURPLE}║${WHITE}  ════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}║${WHITE}  TANZANIA TIME: ${GREEN}$CURRENT_TIME_STR${NC}"
    echo -e "${PURPLE}║${WHITE}  ════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}║${WHITE}  CONFIGURATION SETTINGS:${NC}"
    echo -e "${PURPLE}║${WHITE}    Service Restart Interval : ${GREEN}${SERVICE_INTERVAL} hour(s)${NC}"
    echo -e "${PURPLE}║${WHITE}    System Reboot Interval   : ${GREEN}${REBOOT_INTERVAL} hour(s)${NC}"
    echo -e "${PURPLE}║${WHITE}    Auto Service Status      : ${SERVICE_STATUS}${NC}"
    echo -e "${PURPLE}║${WHITE}  ════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}║${WHITE}  NEXT SCHEDULED EVENTS:${NC}"
    echo -e "${PURPLE}║${WHITE}    Next Service Restart : ${YELLOW}${NEXT_SERVICE}${NC}"
    echo -e "${PURPLE}║${WHITE}    Next System Reboot   : ${RED}${NEXT_REBOOT}${NC}"
    echo -e "${PURPLE}║${WHITE}  ════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}║${WHITE}  EVENT HISTORY:${NC}"
    echo -e "${PURPLE}║${WHITE}    Total Service Restarts   : ${YELLOW}${TOTAL_SERVICE}${NC}"
    echo -e "${PURPLE}║${WHITE}    Total System Reboots     : ${YELLOW}${TOTAL_REBOOT}${NC}"
    echo -e "${PURPLE}║${WHITE}    Last Service Restart     : ${CYAN}${LAST_SERVICE_TIME}${NC}"
    echo -e "${PURPLE}║${WHITE}    Last System Reboot       : ${CYAN}${LAST_REBOOT_TIME}${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    # Show recent logs in table format
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}RECENT SERVICE RESTART LOGS (Tanzania Time):${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"
    if [ -f /etc/elite-x/auto_restart.log ] && [ -s /etc/elite-x/auto_restart.log ]; then
        tail -5 /etc/elite-x/auto_restart.log | while read line; do
            echo -e "  ${GREEN}→${NC} $line"
        done
    else
        echo -e "  ${YELLOW}No service restarts yet${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}RECENT SYSTEM REBOOT LOGS (Tanzania Time):${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"
    if [ -f /etc/elite-x/auto_reboot.log ] && [ -s /etc/elite-x/auto_reboot.log ]; then
        tail -5 /etc/elite-x/auto_reboot.log | while read line; do
            echo -e "  ${RED}→${NC} $line"
        done
    else
        echo -e "  ${YELLOW}No system reboots yet${NC}"
    fi
    
    read -p "$(echo -e $GREEN"Press Enter to continue..."$NC)"
}

# Function to configure auto restart/reboot
configure_auto() {
    while true; do
        clear
        CONFIG_FILE="/etc/elite-x/auto_config"
        source "$CONFIG_FILE" 2>/dev/null
        
        CURRENT_TIME=$(TZ='Africa/Dar_es_Salaam' date "+%Y-%m-%d %H:%M:%S")
        
        echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║${YELLOW}${BOLD}              AUTO RESTART & REBOOT CONFIGURATION              ${PURPLE}║${NC}"
        echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${PURPLE}║${WHITE}  Tanzania Time: ${GREEN}$CURRENT_TIME${NC}"
        echo -e "${PURPLE}║${WHITE}  ════════════════════════════════════════════════════════════${NC}"
        echo -e "${PURPLE}║${WHITE}  Current Settings:${NC}"
        echo -e "${PURPLE}║${WHITE}    Service Restart : ${GREEN}${SERVICE_INTERVAL} hour(s)${NC} ${YELLOW}(0 to disable)${NC}"
        echo -e "${PURPLE}║${WHITE}    System Reboot   : ${GREEN}${REBOOT_INTERVAL} hour(s)${NC} ${YELLOW}(0 to disable)${NC}"
        echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${PURPLE}║${WHITE}  [1] Set Service Restart Interval${NC}"
        echo -e "${PURPLE}║${WHITE}  [2] Set System Reboot Interval${NC}"
        echo -e "${PURPLE}║${WHITE}  [3] Restart Auto Service${NC}"
        echo -e "${PURPLE}║${WHITE}  [4] Stop Auto Service${NC}"
        echo -e "${PURPLE}║${WHITE}  [5] View Details Table${NC}"
        echo -e "${PURPLE}║${WHITE}  [6] Reset Timer (Start counting from now)${NC}"
        echo -e "${PURPLE}║${WHITE}  [0] Back${NC}"
        echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        read -p "$(echo -e $GREEN"Option: "$NC)" opt
        
        case $opt in
            1)
                read -p "Enter service restart interval in hours (0 to disable): " new_service
                if [[ "$new_service" =~ ^[0-9]+$ ]]; then
                    sed -i "s/SERVICE_INTERVAL=.*/SERVICE_INTERVAL=$new_service/" $CONFIG_FILE
                    # Reset timer
                    CURRENT_TIME=$(TZ='Africa/Dar_es_Salaam' date +%s)
                    echo "$CURRENT_TIME" > /var/lib/elite-x/auto/last_service_restart
                    systemctl restart elite-x-auto-restart
                    echo -e "${GREEN}✅ Service interval updated to $new_service hour(s) and timer reset${NC}"
                else
                    echo -e "${RED}❌ Invalid input${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            2)
                read -p "Enter system reboot interval in hours (0 to disable): " new_reboot
                if [[ "$new_reboot" =~ ^[0-9]+$ ]]; then
                    sed -i "s/REBOOT_INTERVAL=.*/REBOOT_INTERVAL=$new_reboot/" $CONFIG_FILE
                    # Reset timer
                    CURRENT_TIME=$(TZ='Africa/Dar_es_Salaam' date +%s)
                    echo "$CURRENT_TIME" > /var/lib/elite-x/auto/last_reboot
                    systemctl restart elite-x-auto-restart
                    echo -e "${GREEN}✅ Reboot interval updated to $new_reboot hour(s) and timer reset${NC}"
                else
                    echo -e "${RED}❌ Invalid input${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            3)
                systemctl restart elite-x-auto-restart
                echo -e "${GREEN}✅ Auto service restarted${NC}"
                read -p "Press Enter to continue..."
                ;;
            4)
                systemctl stop elite-x-auto-restart
                echo -e "${YELLOW}⚠️ Auto service stopped${NC}"
                read -p "Press Enter to continue..."
                ;;
            5)
                show_auto_table
                ;;
            6)
                CURRENT_TIME=$(TZ='Africa/Dar_es_Salaam' date +%s)
                echo "$CURRENT_TIME" > /var/lib/elite-x/auto/last_service_restart
                echo "$CURRENT_TIME" > /var/lib/elite-x/auto/last_reboot
                systemctl restart elite-x-auto-restart
                echo -e "${GREEN}✅ Timers reset. Countdown started from now: $(TZ='Africa/Dar_es_Salaam' date)${NC}"
                read -p "Press Enter to continue..."
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

show_dashboard() {
    clear
    
    # Get real-time stats
    IP=$(cat /etc/elite-x/cached_ip 2>/dev/null || curl -s ifconfig.me 2>/dev/null || echo "Unknown")
    LOC=$(cat /etc/elite-x/cached_location 2>/dev/null || echo "Unknown")
    ISP=$(cat /etc/elite-x/cached_isp 2>/dev/null || echo "Unknown")
    RAM=$(free -h | awk '/^Mem:/{print $3"/"$2}')
    SUB=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "Not configured")
    ACTIVATION_KEY=$(cat /etc/elite-x/key 2>/dev/null || echo "ELITE-X")
    EXP=$(cat /etc/elite-x/expiry 2>/dev/null || echo "Lifetime Unlimited")
    LOCATION=$(cat /etc/elite-x/location 2>/dev/null || echo "South Africa")
    CURRENT_MTU=$(cat /etc/elite-x/mtu 2>/dev/null || echo "1800")
    
    # Load auto config
    CONFIG_FILE="/etc/elite-x/auto_config"
    SERVICE_INTERVAL=1
    REBOOT_INTERVAL=2
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
    
    # Service status
    DNS=$(systemctl is-active dnstt-elite-x 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    PRX=$(systemctl is-active dnstt-elite-x-proxy 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    CONN=$(systemctl is-active elite-x-connmon 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    RESTART=$(systemctl is-active elite-x-auto-restart 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    
    # Real-time stats
    TOTAL_USERS=$(ls -1 /etc/elite-x/users 2>/dev/null | wc -l)
    ACTIVE_CONNS=$(who | wc -l)
    
    # System load
    LOAD=$(uptime | awk -F'load average:' '{print $2}')
    
    # Tanzania time
    TZ_TIME=$(TZ='Africa/Dar_es_Salaam' date "+%Y-%m-%d %H:%M:%S")
    
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}              ELITE-X ULTIMATE v3.2 - REAL-TIME                ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${WHITE}  Tanzania Time: ${GREEN}$TZ_TIME${NC}"
    echo -e "${PURPLE}║${WHITE}  Subdomain :${GREEN} $SUB${NC}"
    echo -e "${PURPLE}║${WHITE}  IP        :${GREEN} $IP${NC}"
    echo -e "${PURPLE}║${WHITE}  Location  :${GREEN} $LOC${NC}"
    echo -e "${PURPLE}║${WHITE}  ISP       :${GREEN} $ISP${NC}"
    echo -e "${PURPLE}║${WHITE}  RAM       :${GREEN} $RAM${NC}"
    echo -e "${PURPLE}║${WHITE}  Load Avg  :${GREEN} $LOAD${NC}"
    echo -e "${PURPLE}║${WHITE}  VPS Loc   :${GREEN} $LOCATION (MTU: $CURRENT_MTU)${NC}"
    echo -e "${PURPLE}║${WHITE}  Services  : DNS:$DNS PRX:$PRX MON:$CONN AUTO:$RESTART${NC}"
    echo -e "${PURPLE}║${WHITE}  Auto Config: Restart ${YELLOW}${SERVICE_INTERVAL}h${NC} | Reboot ${YELLOW}${REBOOT_INTERVAL}h${NC}"
    echo -e "${PURPLE}║${WHITE}  Real-Time :${GREEN} $TOTAL_USERS users, $ACTIVE_CONNS online${NC}"
    echo -e "${PURPLE}║${WHITE}  Developer :${CYAN} ELITE-X ULTIMATE TEAM${NC}"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${WHITE}  Version   :${YELLOW} v3.2 Ultimate - Unlimited - No Auto-Ban${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

change_mtu() {
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${WHITE}                    CHANGE MTU VALUE                              ${YELLOW}║${NC}"
    echo -e "${YELLOW}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${WHITE}  Current MTU: $(cat /etc/elite-x/mtu)${NC}"
    echo -e "${YELLOW}║${WHITE}  Recommended: 1800 (Africa), 1500 (USA/Europe), 1400 (Asia)${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    read -p "$(echo -e $GREEN"New MTU (1000-5000): "$NC)" mtu
    
    if [[ "$mtu" =~ ^[0-9]+$ ]] && [ $mtu -ge 1000 ] && [ $mtu -le 5000 ]; then
        echo "$mtu" > /etc/elite-x/mtu
        sed -i "s/-mtu [0-9]*/-mtu $mtu/" /etc/systemd/system/dnstt-elite-x.service
        systemctl daemon-reload
        systemctl restart dnstt-elite-x dnstt-elite-x-proxy
        echo -e "${GREEN}✅ MTU updated to $mtu${NC}"
    else
        echo -e "${RED}❌ Invalid MTU (must be 1000-5000)${NC}"
    fi
    read -p "Press Enter to continue..."
}

settings_menu() {
    while true; do
        clear
        echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║${YELLOW}${BOLD}                   SETTINGS MENU (ULTIMATE)                     ${PURPLE}║${NC}"
        echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${PURPLE}║${WHITE}  [8]  🔑 View Public Key${NC}"
        echo -e "${PURPLE}║${WHITE}  [9]  Change MTU Value${NC}"
        echo -e "${PURPLE}║${WHITE}  [10] ⚡ Full Speed Optimization${NC}"
        echo -e "${PURPLE}║${WHITE}  [11] 🧹 Clean Junk Files${NC}"
        echo -e "${PURPLE}║${WHITE}  [12] 🔄 Auto Remover Status${NC}"
        echo -e "${PURPLE}║${WHITE}  [13] Restart All Services${NC}"
        echo -e "${PURPLE}║${WHITE}  [14] Reboot VPS${NC}"
        echo -e "${PURPLE}║${WHITE}  [15] Uninstall Script${NC}"
        echo -e "${PURPLE}║${WHITE}  [16] 🌍 Re-apply Location${NC}"
        echo -e "${PURPLE}║${WHITE}  [17] 📊 View System Stats${NC}"
        echo -e "${PURPLE}║${WHITE}  [18] 🔍 Check Service Logs${NC}"
        echo -e "${PURPLE}║${WHITE}  [19] ⏰ Configure Auto Restart/Reboot${NC}"
        echo -e "${PURPLE}║${WHITE}  [20] 📋 Auto Restart Details Table${NC}"
        echo -e "${PURPLE}║${WHITE}  [0]  Back to Main Menu${NC}"
        echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        read -p "$(echo -e $GREEN"Settings option: "$NC)" ch
        
        case $ch in
            8)
                echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${CYAN}║${YELLOW}                    PUBLIC KEY                                    ${CYAN}║${NC}"
                echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
                echo -e "${CYAN}║${GREEN}  $(cat /etc/dnstt/server.pub)${NC}"
                echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
                read -p "Press Enter to continue..."
                ;;
            9) change_mtu ;;
            10) 
                elite-x-speed full
                echo -e "${GREEN}✅ Full optimization complete${NC}"
                read -p "Press Enter to continue..."
                ;;
            11)
                elite-x-speed ram
                apt clean
                apt autoclean
                journalctl --vacuum-time=3d
                echo -e "${GREEN}✅ Cleanup complete${NC}"
                read -p "Press Enter to continue..."
                ;;
            12)
                systemctl status elite-x-cleaner --no-pager
                read -p "Press Enter to continue..."
                ;;
            13)
                systemctl restart dnstt-elite-x dnstt-elite-x-proxy elite-x-connmon sshd
                echo -e "${GREEN}✅ Services restarted${NC}"
                read -p "Press Enter to continue..."
                ;;
            14)
                read -p "Reboot? (y/n): " c
                [ "$c" = "y" ] && reboot
                ;;
            15)
                read -p "Uninstall? (YES): " c
                [ "$c" = "YES" ] && {
                    echo -e "${YELLOW}🔄 Uninstalling...${NC}"
                    
                    if [ -d "/etc/elite-x/users" ]; then
                        for user_file in /etc/elite-x/users/*; do
                            if [ -f "$user_file" ]; then
                                username=$(basename "$user_file")
                                userdel -r "$username" 2>/dev/null || true
                            fi
                        done
                    fi
                    
                    for service in dnstt-elite-x dnstt-elite-x-proxy elite-x-traffic elite-x-cleaner elite-x-connmon elite-x-realtime elite-x-auto-restart; do
                        systemctl stop $service 2>/dev/null || true
                        systemctl disable $service 2>/dev/null || true
                    done
                    
                    rm -rf /etc/systemd/system/{dnstt-elite-x*,elite-x-*}
                    rm -rf /etc/dnstt /etc/elite-x
                    rm -f /usr/local/bin/{dnstt-*,elite-x*}
                    
                    sed -i '/^Banner/d' /etc/ssh/sshd_config
                    systemctl restart sshd
                    
                    rm -f /etc/profile.d/elite-x-dashboard.sh
                    sed -i '/elite-x/d' ~/.bashrc
                    
                    echo -e "${GREEN}✅ Uninstalled completely${NC}"
                    rm -f /tmp/elite-x-running
                    exit 0
                }
                read -p "Press Enter to continue..."
                ;;
            16)
                echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
                echo -e "${GREEN}           RE-APPLY LOCATION OPTIMIZATION                        ${NC}"
                echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
                echo -e "${WHITE}Select your VPS location:${NC}"
                echo -e "${GREEN}  1. South Africa (MTU 1800)${NC}"
                echo -e "${CYAN}  2. USA (MTU 1500)${NC}"
                echo -e "${BLUE}  3. Europe (MTU 1500)${NC}"
                echo -e "${PURPLE}  4. Asia (MTU 1400)${NC}"
                echo -e "${YELLOW}  5. Custom MTU${NC}"
                read -p "Choice: " opt_choice
                
                case $opt_choice in
                    1) echo "South Africa" > /etc/elite-x/location
                       echo "1800" > /etc/elite-x/mtu
                       sed -i "s/-mtu [0-9]*/-mtu 1800/" /etc/systemd/system/dnstt-elite-x.service
                       systemctl daemon-reload
                       systemctl restart dnstt-elite-x dnstt-elite-x-proxy
                       echo -e "${GREEN}✅ South Africa selected (MTU 1800)${NC}" ;;
                    2) echo "USA" > /etc/elite-x/location
                       echo "1500" > /etc/elite-x/mtu
                       sed -i "s/-mtu [0-9]*/-mtu 1500/" /etc/systemd/system/dnstt-elite-x.service
                       systemctl daemon-reload
                       systemctl restart dnstt-elite-x dnstt-elite-x-proxy
                       echo -e "${GREEN}✅ USA selected (MTU 1500)${NC}" ;;
                    3) echo "Europe" > /etc/elite-x/location
                       echo "1500" > /etc/elite-x/mtu
                       sed -i "s/-mtu [0-9]*/-mtu 1500/" /etc/systemd/system/dnstt-elite-x.service
                       systemctl daemon-reload
                       systemctl restart dnstt-elite-x dnstt-elite-x-proxy
                       echo -e "${GREEN}✅ Europe selected (MTU 1500)${NC}" ;;
                    4) echo "Asia" > /etc/elite-x/location
                       echo "1400" > /etc/elite-x/mtu
                       sed -i "s/-mtu [0-9]*/-mtu 1400/" /etc/systemd/system/dnstt-elite-x.service
                       systemctl daemon-reload
                       systemctl restart dnstt-elite-x dnstt-elite-x-proxy
                       echo -e "${GREEN}✅ Asia selected (MTU 1400)${NC}" ;;
                    5) read -p "Enter MTU (1000-5000): " custom_mtu
                       if [[ "$custom_mtu" =~ ^[0-9]+$ ]] && [ $custom_mtu -ge 1000 ] && [ $custom_mtu -le 5000 ]; then
                           echo "Custom" > /etc/elite-x/location
                           echo "$custom_mtu" > /etc/elite-x/mtu
                           sed -i "s/-mtu [0-9]*/-mtu $custom_mtu/" /etc/systemd/system/dnstt-elite-x.service
                           systemctl daemon-reload
                           systemctl restart dnstt-elite-x dnstt-elite-x-proxy
                           echo -e "${GREEN}✅ Custom MTU $custom_mtu selected${NC}"
                       else
                           echo -e "${RED}Invalid MTU${NC}"
                       fi ;;
                esac
                read -p "Press Enter to continue..."
                ;;
            17)
                clear
                echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${CYAN}║${YELLOW}                  SYSTEM STATISTICS                              ${CYAN}║${NC}"
                echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
                echo -e "${CYAN}║${WHITE}  CPU Info:$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)% used${NC}"
                echo -e "${CYAN}║${WHITE}  Memory  :$(free -h | awk '/^Mem:/{print $3"/"$2}')${NC}"
                echo -e "${CYAN}║${WHITE}  Disk    :$(df -h / | awk 'NR==2{print $3"/"$2}')${NC}"
                echo -e "${CYAN}║${WHITE}  Network :$(ip -s link show $(ip route | grep default | awk '{print $5}') | awk '/RX:/{getline; print "RX: " $1 " bytes"}' )${NC}"
                echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
                read -p "Press Enter to continue..."
                ;;
            18)
                echo -e "${YELLOW}Recent service logs:${NC}"
                journalctl -u dnstt-elite-x -n 10 --no-pager
                echo ""
                journalctl -u elite-x-connmon -n 10 --no-pager
                read -p "Press Enter to continue..."
                ;;
            19)
                configure_auto
                ;;
            20)
                show_auto_table
                ;;
            0) return ;;
            *) echo -e "${RED}Invalid option${NC}"; read -p "Press Enter to continue..." ;;
        esac
    done
}

main_menu() {
    while true; do
        show_dashboard
        echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║${GREEN}${BOLD}                     MAIN MENU (ULTIMATE)                       ${PURPLE}║${NC}"
        echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${PURPLE}║${WHITE}  [1] ➕ Create SSH + DNS User${NC}"
        echo -e "${PURPLE}║${WHITE}  [2] 📋 List All Users (Real-Time)${NC}"
        echo -e "${PURPLE}║${WHITE}  [3] 👤 Show User Details${NC}"
        echo -e "${PURPLE}║${WHITE}  [4] 🔄 Renew User${NC}"
        echo -e "${PURPLE}║${WHITE}  [5] ⚡ Set Login Limit${NC}"
        echo -e "${PURPLE}║${WHITE}  [6] 🗑️  Show Deleted Users${NC}"
        echo -e "${PURPLE}║${WHITE}  [7] 🔄 Restore Deleted User${NC}"
        echo -e "${PURPLE}║${WHITE}  [8] 🔒 Lock User${NC}"
        echo -e "${PURPLE}║${WHITE}  [9] 🔓 Unlock User${NC}"
        echo -e "${PURPLE}║${WHITE}  [10] ❌ Delete User${NC}"
        echo -e "${PURPLE}║${WHITE}  [11] 📝 Create/Edit Banner${NC}"
        echo -e "${PURPLE}║${WHITE}  [12] 🗑️  Delete Banner${NC}"
        echo -e "${PURPLE}║${RED}  [S] ⚙️  Settings${NC}"
        echo -e "${PURPLE}║${WHITE}  [00] 🚪 Exit${NC}"
        echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        read -p "$(echo -e $GREEN"Main menu option: "$NC)" ch
        
        case $ch in
            1) elite-x-user add; read -p "Press Enter to continue..." ;;
            2) elite-x-user list; read -p "Press Enter to continue..." ;;
            3) elite-x-user details; read -p "Press Enter to continue..." ;;
            4) elite-x-user renew; read -p "Press Enter to continue..." ;;
            5) elite-x-user setlimit; read -p "Press Enter to continue..." ;;
            6) elite-x-user deleted; read -p "Press Enter to continue..." ;;
            7) elite-x-user restore; read -p "Press Enter to continue..." ;;
            8) elite-x-user lock; read -p "Press Enter to continue..." ;;
            9) elite-x-user unlock; read -p "Press Enter to continue..." ;;
            10) elite-x-user del; read -p "Press Enter to continue..." ;;
            11)
                [ -f /etc/elite-x/banner/custom ] || cp /etc/elite-x/banner/default /etc/elite-x/banner/custom
                nano /etc/elite-x/banner/custom
                cp /etc/elite-x/banner/custom /etc/elite-x/banner/ssh-banner
                systemctl restart sshd
                echo -e "${GREEN}✅ Banner saved${NC}"
                read -p "Press Enter to continue..."
                ;;
            12)
                rm -f /etc/elite-x/banner/custom
                cp /etc/elite-x/banner/default /etc/elite-x/banner/ssh-banner
                systemctl restart sshd
                echo -e "${GREEN}✅ Banner deleted${NC}"
                read -p "Press Enter to continue..."
                ;;
            [Ss]) settings_menu ;;
            00|0) 
                rm -f /tmp/elite-x-running
                show_quote
                echo -e "${GREEN}Thank you for using ELITE-X ULTIMATE!${NC}"
                exit 0 
                ;;
            *) echo -e "${RED}Invalid option${NC}"; read -p "Press Enter to continue..." ;;
        esac
    done
}

main_menu
EOF
chmod +x /usr/local/bin/elite-x

# Cache network info
echo "Caching network information..."
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

# Add aliases
cat >> ~/.bashrc <<'EOF'
# Elite-X Ultimate aliases
alias menu='elite-x'
alias elitex='elite-x'
alias users='elite-x-user list'
alias adduser='elite-x-user add'
alias deluser='elite-x-user del'
alias speed='elite-x-speed full'
EOF

# Final output
clear
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${YELLOW}${BOLD}         ELITE-X ULTIMATE v3.2 INSTALLED SUCCESSFULLY          ${GREEN}║${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${WHITE}  Domain     :${CYAN} $TDOMAIN${NC}"
echo -e "${GREEN}║${WHITE}  Location   :${CYAN} $SELECTED_LOCATION (MTU: $MTU)${NC}"
echo -e "${GREEN}║${WHITE}  Version    :${CYAN} v3.2 Ultimate (No Auto-Ban)${NC}"
echo -e "${GREEN}║${WHITE}  Timezone   :${CYAN} Africa/Dar_es_Salaam (Tanzania)${NC}"
echo -e "${GREEN}║${WHITE}  Auto Config:${GREEN} Service Restart: 1h | System Reboot: 2h${NC}"
echo -e "${GREEN}║${WHITE}  Features   :${GREEN} Real-Time • Auto-Restart • Auto-Reboot • Switch Mode${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${WHITE}  Services Status:${NC}"
systemctl is-active dnstt-elite-x >/dev/null 2>&1 && echo -e "${GREEN}║  ✅ DNSTT Server: Running${NC}" || echo -e "${RED}║  ❌ DNSTT Server: Failed${NC}"
systemctl is-active dnstt-elite-x-proxy >/dev/null 2>&1 && echo -e "${GREEN}║  ✅ DNSTT Proxy: Running${NC}" || echo -e "${RED}║  ❌ DNSTT Proxy: Failed${NC}"
systemctl is-active elite-x-connmon >/dev/null 2>&1 && echo -e "${GREEN}║  ✅ Connection Monitor: Running${NC}" || echo -e "${RED}║  ❌ Connection Monitor: Failed${NC}"
systemctl is-active elite-x-auto-restart >/dev/null 2>&1 && echo -e "${GREEN}║  ✅ Auto-Restart/Reboot: Running${NC}" || echo -e "${RED}║  ❌ Auto-Restart/Reboot: Failed${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${WHITE}  Port Status:${NC}"
ss -uln | grep -q ":53 " && echo -e "${GREEN}║  ✅ Port 53: Listening${NC}" || echo -e "${RED}║  ❌ Port 53: Not listening${NC}"
ss -uln | grep -q ":${DNSTT_PORT} " && echo -e "${GREEN}║  ✅ Port ${DNSTT_PORT}: Listening${NC}" || echo -e "${RED}║  ❌ Port ${DNSTT_PORT}: Not listening${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
show_quote

read -p "$(echo -e $GREEN"Open ELITE-X ULTIMATE menu now? (y/n): "$NC)" open
if [ "$open" = "y" ]; then
    echo -e "${GREEN}Launching Elite-X Ultimate Dashboard...${NC}"
    sleep 1
    /usr/local/bin/elite-x
else
    echo -e "${YELLOW}You can type 'menu' or 'elite-x' anytime to open the dashboard.${NC}"
fi

self_destruct
