#!/bin/bash
# ╔══════════════════════╗
#  ELITE-X DNSTT SCRIPT v3.5
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
    echo -e "${CYAN}║${WHITE}            Always Remember ELITE-X when you see X            ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_banner() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}                   ELITE-X SLOWDNS v3.5                        ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${GREEN}${BOLD}              Advanced • Secure • Ultra Fast                    ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Advanced Configuration
ACTIVATION_KEY="ELITE X"
TEMP_KEY="ELITE-X-TEST-0208"
ACTIVATION_FILE="/etc/elite-x/activated"
ACTIVATION_TYPE_FILE="/etc/elite-x/activation_type"
ACTIVATION_DATE_FILE="/etc/elite-x/activation_date"
EXPIRY_DAYS_FILE="/etc/elite-x/expiry_days"
KEY_FILE="/etc/elite-x/key"
EXPIRY_FILE="/etc/elite-x/expiry"
TIMEZONE="Africa/Dar_es_Salaam"
BACKUP_DIR="/root/elite-x-backups"
LOG_FILE="/var/log/elite-x.log"

# Create log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

set_timezone() {
    timedatectl set-timezone $TIMEZONE 2>/dev/null || ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime 2>/dev/null || true
}

check_expiry() {
    if [ -f "$ACTIVATION_TYPE_FILE" ] && [ -f "$ACTIVATION_DATE_FILE" ] && [ -f "$EXPIRY_DAYS_FILE" ]; then
        local act_type=$(cat "$ACTIVATION_TYPE_FILE")
        if [ "$act_type" = "temporary" ]; then
            local act_date=$(cat "$ACTIVATION_DATE_FILE")
            local expiry_days=$(cat "$EXPIRY_DAYS_FILE")
            local current_date=$(date +%s)
            local expiry_date=$(date -d "$act_date + $expiry_days days" +%s)
            
            if [ $current_date -ge $expiry_date ]; then
                echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${RED}║${YELLOW}           TRIAL PERIOD EXPIRED                                  ${RED}║${NC}"
                echo -e "${RED}╠═══════════════════════════════════════════════════════════════╣${NC}"
                echo -e "${RED}║${WHITE}  Your 2-day trial has ended.                                  ${RED}║${NC}"
                echo -e "${RED}║${WHITE}  Script will now uninstall itself...                         ${RED}║${NC}"
                echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
                sleep 3
                
                # Complete uninstall
                echo -e "${YELLOW}🔄 Removing all users and data...${NC}"
                
                # Remove all SSH users created by the script
                if [ -d "/etc/elite-x/users" ]; then
                    for user_file in /etc/elite-x/users/*; do
                        if [ -f "$user_file" ]; then
                            username=$(basename "$user_file")
                            echo -e "  Removing user: $username"
                            userdel -r "$username" 2>/dev/null || true
                            pkill -u "$username" 2>/dev/null || true
                        fi
                    done
                fi
                
                # Kill any remaining processes
                pkill -f dnstt-server 2>/dev/null || true
                pkill -f dnstt-edns-proxy 2>/dev/null || true
                pkill -f elite-x-traffic 2>/dev/null || true
                pkill -f elite-x-cleaner 2>/dev/null || true
                pkill -f elite-x-bandwidth 2>/dev/null || true
                pkill -f elite-x-monitor 2>/dev/null || true
                pkill -f elite-x-speed 2>/dev/null || true
                
                # Stop and disable services
                systemctl stop dnstt-elite-x dnstt-elite-x-proxy elite-x-traffic elite-x-cleaner elite-x-bandwidth elite-x-monitor 2>/dev/null || true
                systemctl disable dnstt-elite-x dnstt-elite-x-proxy elite-x-traffic elite-x-cleaner elite-x-bandwidth elite-x-monitor 2>/dev/null || true
                
                # Remove service files
                rm -rf /etc/systemd/system/dnstt-elite-x*
                rm -rf /etc/systemd/system/elite-x-*
                
                # Remove directories and files
                rm -rf /etc/dnstt /etc/elite-x
                rm -f /usr/local/bin/dnstt-*
                rm -f /usr/local/bin/elite-x*
                
                # Remove banner from sshd_config
                sed -i '/^Banner/d' /etc/ssh/sshd_config
                systemctl restart sshd
                
                # Remove profile and bashrc entries
                rm -f /etc/profile.d/elite-x-dashboard.sh
                sed -i '/elite-x/d' ~/.bashrc
                sed -i '/ELITE_X_SHOWN/d' ~/.bashrc
                
                # Remove cron jobs
                rm -f /etc/cron.hourly/elite-x-expiry
                rm -f /etc/cron.daily/elite-x-backup
                rm -f /etc/cron.hourly/elite-x-bandwidth
                
                echo -e "${GREEN}✅ ELITE-X has been uninstalled.${NC}"
                rm -f "$0"
                exit 0
            else
                local days_left=$(( (expiry_date - current_date) / 86400 ))
                local hours_left=$(( ((expiry_date - current_date) % 86400) / 3600 ))
                echo -e "${YELLOW}⚠️  Trial: $days_left days $hours_left hours remaining${NC}"
            fi
        fi
    fi
}

activate_script() {
    local input_key="$1"
    mkdir -p /etc/elite-x
    
    if [ "$input_key" = "$ACTIVATION_KEY" ] || [ "$input_key" = "Whtsapp 0713628668" ]; then
        echo "$ACTIVATION_KEY" > "$ACTIVATION_FILE"
        echo "$ACTIVATION_KEY" > "$KEY_FILE"
        echo "lifetime" > "$ACTIVATION_TYPE_FILE"
        echo "Lifetime" > "$EXPIRY_FILE"
        log "Lifetime activation recorded"
        return 0
    elif [ "$input_key" = "$TEMP_KEY" ]; then
        echo "$TEMP_KEY" > "$ACTIVATION_FILE"
        echo "$TEMP_KEY" > "$KEY_FILE"
        echo "temporary" > "$ACTIVATION_TYPE_FILE"
        echo "$(date +%Y-%m-%d)" > "$ACTIVATION_DATE_FILE"
        echo "2" > "$EXPIRY_DAYS_FILE"
        echo "2 Days Trial" > "$EXPIRY_FILE"
        log "Trial activation recorded (2 days)"
        return 0
    fi
    return 1
}

# Function to ensure key and expiry files exist
ensure_key_files() {
    if [ ! -f /etc/elite-x/key ]; then
        if [ -f "$ACTIVATION_FILE" ]; then
            cp "$ACTIVATION_FILE" /etc/elite-x/key
        else
            echo "$ACTIVATION_KEY" > /etc/elite-x/key
        fi
    fi
    
    if [ ! -f /etc/elite-x/expiry ]; then
        if [ -f "$EXPIRY_FILE" ]; then
            cp "$EXPIRY_FILE" /etc/elite-x/expiry
        else
            echo "Lifetime" > /etc/elite-x/expiry
        fi
    fi
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

# ========== DNSTT SERVER ==========
setup_dnstt_server() {
    echo "Installing dnstt-server..."
    
    # Kill any process using port 5300
    fuser -k 5300/udp 2>/dev/null || true
    
    # Try multiple sources for dnstt-server
    if curl -fsSL https://dnstt.network/dnstt-server-linux-amd64 -o /usr/local/bin/dnstt-server 2>/dev/null; then
        echo -e "${GREEN}✅ Downloaded from dnstt.network${NC}"
    elif curl -fsSL https://github.com/NoXFiQ/Elite-X-dns.sh/raw/main/dnstt-server -o /usr/local/bin/dnstt-server 2>/dev/null; then
        echo -e "${GREEN}✅ Downloaded from GitHub${NC}"
    else
        echo -e "${RED}❌ Failed to download dnstt-server${NC}"
        exit 1
    fi
    chmod +x /usr/local/bin/dnstt-server

    echo "Generating keys..."
    mkdir -p /etc/dnstt

    if [ -f /etc/dnstt/server.key ]; then
        echo -e "${YELLOW}⚠️  Existing keys found, removing...${NC}"
        chattr -i /etc/dnstt/server.key 2>/dev/null || true
        rm -f /etc/dnstt/server.key
        rm -f /etc/dnstt/server.pub
    fi

    cd /etc/dnstt
    /usr/local/bin/dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub
    cd ~

    chmod 600 /etc/dnstt/server.key
    chmod 644 /etc/dnstt/server.pub

    echo "Creating dnstt-elite-x.service..."
    cat >/etc/systemd/system/dnstt-elite-x.service <<EOF
[Unit]
Description=ELITE-X DNSTT Server
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/dnstt-server -udp :${DNSTT_PORT} -mtu ${MTU} -privkey-file /etc/dnstt/server.key ${TDOMAIN} 127.0.0.1:22
Restart=always
RestartSec=5
KillSignal=SIGTERM
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
}

# ========== EDNS PROXY ==========
setup_edns_proxy() {
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

L=5300
running = True

def signal_handler(sig, frame):
    global running
    running = False
    sys.stderr.write("\nShutting down...\n")
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
        client.sendto(modify_edns(data, 1800), ('127.0.0.1', L))
        response, _ = client.recvfrom(4096)
        sock.sendto(modify_edns(response, 512), addr)
    except Exception as e:
        sys.stderr.write(f"Error: {e}\n")
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
            sys.stderr.write(f"✅ EDNS Proxy started on port 53 (forwarding to {L})\n")
            sys.stderr.flush()
            break
        except Exception as e:
            if attempt < 2:
                sys.stderr.write(f"Attempt {attempt+1} failed, retrying...\n")
                time.sleep(2)
                os.system("fuser -k 53/udp 2>/dev/null || true")
            else:
                sys.stderr.write(f"❌ Failed to bind to port 53 after 3 attempts: {e}\n")
                sys.exit(1)
    
    while running:
        try:
            data, addr = server.recvfrom(4096)
            threading.Thread(target=handle_request, args=(server, data, addr), daemon=True).start()
        except Exception as e:
            if running:
                sys.stderr.write(f"Error: {e}\n")
                time.sleep(1)

if __name__ == "__main__":
    main()
EOF
    chmod +x /usr/local/bin/dnstt-edns-proxy.py

    cat >/etc/systemd/system/dnstt-elite-x-proxy.service <<EOF
[Unit]
Description=ELITE-X Proxy
After=dnstt-elite-x.service
Requires=dnstt-elite-x.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/dnstt-edns-proxy.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

# ========== SIMPLE TRAFFIC MONITOR ==========
setup_traffic_monitor() {
    cat > /usr/local/bin/elite-x-traffic <<'EOF'
#!/bin/bash
TRAFFIC_DB="/etc/elite-x/traffic"
USER_DB="/etc/elite-x/users"
mkdir -p $TRAFFIC_DB

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> /var/log/elite-x-traffic.log
}

# Get traffic for a user by reading from /proc/net/dev for their processes
get_user_traffic() {
    local username="$1"
    local total=0
    
    # Get all PIDs for this user
    for pid in $(pgrep -u "$username" 2>/dev/null); do
        if [ -f /proc/$pid/net/dev ]; then
            # Read /proc/net/dev for this process
            while IFS= read -r line; do
                if echo "$line" | grep -qE "eth0|ens|venet|wlan|tun|tap"; then
                    # Extract receive and transmit bytes
                    rx=$(echo "$line" | awk '{print $2}')
                    tx=$(echo "$line" | awk '{print $10}')
                    if [[ "$rx" =~ ^[0-9]+$ ]] && [[ "$tx" =~ ^[0-9]+$ ]]; then
                        total=$((total + rx + tx))
                    fi
                fi
            done < /proc/$pid/net/dev
        fi
    done
    
    # Return in MB
    echo $((total / 1048576))
}

# Update traffic for all users
update_all_traffic() {
    if [ -d "$USER_DB" ]; then
        for user_file in "$USER_DB"/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                traffic_mb=$(get_user_traffic "$username")
                traffic_file="$TRAFFIC_DB/$username"
                
                # Save current usage
                echo "$traffic_mb" > "$traffic_file"
                
                # Save history (simple format: timestamp:mb)
                echo "$(date +%s):$traffic_mb" >> "$TRAFFIC_DB/${username}.history"
                # Keep last 24 entries
                tail -n 24 "$TRAFFIC_DB/${username}.history" > "$TRAFFIC_DB/${username}.history.tmp" 2>/dev/null && mv "$TRAFFIC_DB/${username}.history.tmp" "$TRAFFIC_DB/${username}.history" 2>/dev/null || true
                
                # Check limit
                limit=$(grep "Traffic_Limit:" "$user_file" | cut -d' ' -f2)
                if [ "$limit" -gt 0 ] && [ "$traffic_mb" -gt "$limit" ]; then
                    usermod -L "$username" 2>/dev/null
                    pkill -u "$username" 2>/dev/null || true
                    log_message "User $username locked - exceeded limit ($traffic_mb/$limit MB)"
                fi
            fi
        done
    fi
}

log_message "Traffic monitor started"
while true; do
    update_all_traffic
    sleep 60
done
EOF
    chmod +x /usr/local/bin/elite-x-traffic

    touch /var/log/elite-x-traffic.log
    chmod 644 /var/log/elite-x-traffic.log

    cat > /etc/systemd/system/elite-x-traffic.service <<EOF
[Unit]
Description=ELITE-X Traffic Monitor
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/elite-x-traffic
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
}

# ========== AUTO CLEANER ==========
setup_auto_remover() {
    cat > /usr/local/bin/elite-x-cleaner <<'EOF'
#!/bin/bash

USER_DB="/etc/elite-x/users"
TRAFFIC_DB="/etc/elite-x/traffic"
LOG_FILE="/var/log/elite-x-cleaner.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_message "Auto cleaner started"

while true; do
    if [ -d "$USER_DB" ]; then
        for user_file in "$USER_DB"/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                expire_date=$(grep "Expire:" "$user_file" | cut -d' ' -f2)
                
                if [ ! -z "$expire_date" ]; then
                    current_date=$(date +%Y-%m-%d)
                    if [[ "$current_date" > "$expire_date" ]] || [ "$current_date" = "$expire_date" ]; then
                        # Kill user processes
                        pkill -u "$username" 2>/dev/null || true
                        sleep 2
                        
                        # Remove user
                        userdel -r "$username" 2>/dev/null
                        rm -f "$user_file"
                        rm -f "$TRAFFIC_DB/$username"
                        rm -f "$TRAFFIC_DB/${username}.history"
                        
                        log_message "Removed expired user: $username (expired on $expire_date)"
                    fi
                fi
            fi
        done
    fi
    sleep 3600
done
EOF
    chmod +x /usr/local/bin/elite-x-cleaner

    touch /var/log/elite-x-cleaner.log
    chmod 644 /var/log/elite-x-cleaner.log

    cat > /etc/systemd/system/elite-x-cleaner.service <<EOF
[Unit]
Description=ELITE-X Auto Remover Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/elite-x-cleaner
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
}

# ========== BANDWIDTH MONITOR ==========
setup_bandwidth_monitor() {
    cat > /usr/local/bin/elite-x-bandwidth <<'EOF'
#!/bin/bash
LOG_FILE="/var/log/elite-x-bandwidth.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_message "Bandwidth monitor started"

while true; do
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -z "$INTERFACE" ]; then
        INTERFACE="eth0"
    fi
    
    if [ -f "/sys/class/net/$INTERFACE/statistics/rx_bytes" ]; then
        rx_bytes=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes 2>/dev/null || echo "0")
        tx_bytes=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes 2>/dev/null || echo "0")
        rx_mb=$((rx_bytes / 1048576))
        tx_mb=$((tx_bytes / 1048576))
        log_message "Total Bandwidth - RX: ${rx_mb}MB, TX: ${tx_mb}MB"
    fi
    sleep 300
done
EOF
    chmod +x /usr/local/bin/elite-x-bandwidth

    cat > /etc/systemd/system/elite-x-bandwidth.service <<EOF
[Unit]
Description=ELITE-X Bandwidth Monitor
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/elite-x-bandwidth
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
}

# ========== BANDWIDTH SPEED TEST ==========
setup_bandwidth_tester() {
    cat > /usr/local/bin/elite-x-speedtest <<'EOF'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${YELLOW}              ELITE-X BANDWIDTH SPEED TEST                      ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}Testing download speed...${NC}"
DOWNLOAD_START=$(date +%s%N)
curl -s -o /dev/null http://speedtest.tele2.net/100MB.zip &
PID=$!
sleep 5
kill $PID 2>/dev/null || true
DOWNLOAD_END=$(date +%s%N)
DOWNLOAD_TIME=$(( ($DOWNLOAD_END - $DOWNLOAD_START) / 1000000 ))
if [ $DOWNLOAD_TIME -gt 0 ]; then
    DOWNLOAD_SPEED=$(( 100 * 1000 / $DOWNLOAD_TIME ))
else
    DOWNLOAD_SPEED=0
fi

echo -e "${YELLOW}Testing upload speed...${NC}"
UPLOAD_START=$(date +%s%N)
dd if=/dev/zero bs=1M count=50 2>/dev/null | curl -s -X POST --data-binary @- https://httpbin.org/post -o /dev/null &
PID=$!
sleep 5
kill $PID 2>/dev/null || true
UPLOAD_END=$(date +%s%N)
UPLOAD_TIME=$(( ($UPLOAD_END - $UPLOAD_START) / 1000000 ))
if [ $UPLOAD_TIME -gt 0 ]; then
    UPLOAD_SPEED=$(( 50 * 1000 / $UPLOAD_TIME ))
else
    UPLOAD_SPEED=0
fi

echo -e "\n${GREEN}Results:${NC}"
echo -e "Download Speed: ${YELLOW}${DOWNLOAD_SPEED} Mbps${NC}"
echo -e "Upload Speed:   ${YELLOW}${UPLOAD_SPEED} Mbps${NC}"
echo -e "Latency:        ${CYAN}$(ping -c 1 google.com 2>/dev/null | grep time= | cut -d= -f4)${NC}"
EOF
    chmod +x /usr/local/bin/elite-x-speedtest
}

# ========== AUTO BACKUP ==========
setup_auto_backup() {
    cat > /usr/local/bin/elite-x-backup <<'EOF'
#!/bin/bash
BACKUP_DIR="/root/elite-x-backups"
DATE=$(date +%Y%m%d-%H%M%S)
mkdir -p "$BACKUP_DIR"

tar -czf "$BACKUP_DIR/elite-x-config-$DATE.tar.gz" /etc/elite-x 2>/dev/null || true
tar -czf "$BACKUP_DIR/dnstt-keys-$DATE.tar.gz" /etc/dnstt 2>/dev/null || true

if [ -d "/etc/elite-x/users" ]; then
    cp -r /etc/elite-x/users "$BACKUP_DIR/users-$DATE" 2>/dev/null || true
fi

cd "$BACKUP_DIR"
ls -t elite-x-config-* 2>/dev/null | tail -n +11 | xargs -r rm 2>/dev/null || true
ls -t dnstt-keys-* 2>/dev/null | tail -n +11 | xargs -r rm 2>/dev/null || true

echo "Backup completed: $DATE" >> /var/log/elite-x-backup.log
EOF
    chmod +x /usr/local/bin/elite-x-backup

    cat > /etc/cron.daily/elite-x-backup <<'EOF'
#!/bin/bash
/usr/local/bin/elite-x-backup
EOF
    chmod +x /etc/cron.daily/elite-x-backup
}

# ========== SYSTEM OPTIMIZER ==========
setup_system_optimizer() {
    cat > /usr/local/bin/elite-x-optimize <<'EOF'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${YELLOW}              ELITE-X SYSTEM OPTIMIZER                          ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}Optimizing network parameters...${NC}"
sysctl -w net.core.rmem_max=134217728 >/dev/null 2>&1
sysctl -w net.core.wmem_max=134217728 >/dev/null 2>&1
sysctl -w net.ipv4.tcp_rmem="4096 87380 134217728" >/dev/null 2>&1
sysctl -w net.ipv4.tcp_wmem="4096 65536 134217728" >/dev/null 2>&1
sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1
sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
sysctl -w net.ipv4.tcp_fastopen=3 >/dev/null 2>&1

echo -e "${YELLOW}Optimizing CPU performance...${NC}"
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "performance" > "$cpu" 2>/dev/null || true
done

echo -e "${YELLOW}Optimizing memory usage...${NC}"
sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
sysctl -w vm.swappiness=10 >/dev/null 2>&1

echo -e "\n${GREEN}✅ System optimization complete!${NC}"
EOF
    chmod +x /usr/local/bin/elite-x-optimize
}

# ========== CONNECTION MONITOR ==========
setup_connection_monitor() {
    cat > /usr/local/bin/elite-x-monitor <<'EOF'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

while true; do
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}              ELITE-X REAL-TIME CONNECTION MONITOR              ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${GREEN}Active SSH Connections:${NC}"
    echo "─────────────────────────────────"
    ss -tnp | grep -E ":22" | grep ESTAB | while read line; do
        IP=$(echo "$line" | awk '{print $5}' | cut -d: -f1)
        PORT=$(echo "$line" | awk '{print $5}' | cut -d: -f2)
        USER=$(ps -o user= -p $(echo "$line" | grep -o "pid=[0-9]*" | cut -d= -f2) 2>/dev/null || echo "unknown")
        echo -e "  ${GREEN}→${NC} $IP:$PORT ($USER)"
    done | head -20
    
    echo -e "\n${YELLOW}DNS Tunnel Connections (port 5300):${NC}"
    echo "─────────────────────────────────"
    ss -unp | grep ":5300" 2>/dev/null | while read line; do
        IP=$(echo "$line" | awk '{print $5}' | cut -d: -f1)
        echo -e "  ${YELLOW}→${NC} $IP"
    done | head -10
    
    SSH_COUNT=$(ss -tnp | grep -c ":22.*ESTAB" 2>/dev/null || echo "0")
    DNS_COUNT=$(ss -unp | grep -c ":5300" 2>/dev/null || echo "0")
    
    echo -e "\n${CYAN}Total Connections: $SSH_COUNT SSH, $DNS_COUNT DNS${NC}"
    echo -e "${WHITE}Press 'q' to exit, any other key to refresh${NC}"
    read -t 5 -n 1 key
    if [[ $key = q ]]; then 
        break
    fi
done
EOF
    chmod +x /usr/local/bin/elite-x-monitor

    cat > /etc/systemd/system/elite-x-monitor.service <<EOF
[Unit]
Description=ELITE-X Connection Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-monitor
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

# ========== SPEED OPTIMIZATION MENU ==========
setup_manual_speed() {
    cat > /usr/local/bin/elite-x-speed <<'EOF'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

show_menu() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}              ELITE-X SPEED OPTIMIZATION                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} Quick Optimize (Network + CPU + RAM)"
    echo -e "${GREEN}2.${NC} Network Only"
    echo -e "${GREEN}3.${NC} CPU Only"
    echo -e "${GREEN}4.${NC} RAM Only"
    echo -e "${GREEN}5.${NC} Clean Junk Files"
    echo -e "${GREEN}6.${NC} Turbo Mode (Aggressive Optimization)"
    echo -e "${GREEN}7.${NC} Show Current System Stats"
    echo -e "${GREEN}0.${NC} Back"
    echo ""
    read -p "$(echo -e $YELLOW"Choose option: "$NC)" opt
    
    case $opt in
        1) quick_optimize ;;
        2) optimize_network ;;
        3) optimize_cpu ;;
        4) optimize_ram ;;
        5) clean_junk ;;
        6) turbo_mode ;;
        7) show_stats ;;
        0) return 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 2; show_menu ;;
    esac
}

quick_optimize() {
    echo -e "${YELLOW}⚡ Quick optimizing system...${NC}"
    optimize_network
    optimize_cpu
    optimize_ram
    clean_junk
    echo -e "${GREEN}✅ Quick optimization complete!${NC}"
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

optimize_network() {
    echo -e "${YELLOW}🌐 Optimizing network...${NC}"
    sysctl -w net.core.rmem_max=134217728 >/dev/null 2>&1
    sysctl -w net.core.wmem_max=134217728 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_rmem="4096 87380 134217728" >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_wmem="4096 65536 134217728" >/dev/null 2>&1
    sysctl -w net.core.netdev_max_backlog=5000 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1
    sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
    echo -e "${GREEN}✅ Network optimized!${NC}"
    sleep 1
}

optimize_cpu() {
    echo -e "${YELLOW}⚡ Optimizing CPU...${NC}"
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "performance" > "$cpu" 2>/dev/null || true
    done
    echo -e "${GREEN}✅ CPU optimized!${NC}"
    sleep 1
}

optimize_ram() {
    echo -e "${YELLOW}💾 Optimizing RAM...${NC}"
    sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    sysctl -w vm.swappiness=10 >/dev/null 2>&1
    echo -e "${GREEN}✅ RAM optimized!${NC}"
    sleep 1
}

clean_junk() {
    echo -e "${YELLOW}🧹 Cleaning junk files...${NC}"
    apt clean 2>/dev/null
    apt autoclean 2>/dev/null
    find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null || true
    journalctl --vacuum-time=3d 2>/dev/null || true
    echo -e "${GREEN}✅ Junk files cleaned!${NC}"
    sleep 1
}

turbo_mode() {
    echo -e "${YELLOW}🚀 Activating TURBO MODE...${NC}"
    sysctl -w net.core.rmem_max=268435456 >/dev/null 2>&1
    sysctl -w net.core.wmem_max=268435456 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_rmem="8192 87380 268435456" >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_wmem="8192 65536 268435456" >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1
    sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
    sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    echo -e "${GREEN}✅ TURBO MODE activated!${NC}"
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

show_stats() {
    echo -e "${CYAN}System Statistics:${NC}"
    echo "──────────────────"
    echo -e "CPU Load: $(uptime | awk -F'load average:' '{print $2}')"
    echo -e "Memory: $(free -h | awk '/^Mem:/{print $3"/"$2}')"
    echo -e "Disk: $(df -h / | awk 'NR==2{print $3"/"$2}')"
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

while true; do
    show_menu
done
EOF
    chmod +x /usr/local/bin/elite-x-speed
}

# ========== UPDATER ==========
setup_updater() {
    cat > /usr/local/bin/elite-x-update <<'EOF'
#!/bin/bash

echo -e "\033[1;33m🔄 Checking for updates...\033[0m"

BACKUP_DIR="/root/elite-x-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r /etc/elite-x "$BACKUP_DIR/" 2>/dev/null || true
cp -r /etc/dnstt "$BACKUP_DIR/" 2>/dev/null || true

cd /tmp
rm -rf Elite-X-dns.sh
git clone https://github.com/NoXFiQ/Elite-X-dns.sh.git 2>/dev/null || {
    echo -e "\033[0;31m❌ Failed to download update\033[0m"
    exit 1
}

cd Elite-X-dns.sh
chmod +x *.sh

cp -r "$BACKUP_DIR/elite-x" /etc/ 2>/dev/null || true
cp -r "$BACKUP_DIR/dnstt" /etc/ 2>/dev/null || true

echo -e "\033[0;32m✅ Update complete!\033[0m"
echo ""
read -p "Press Enter to continue..."
EOF
    chmod +x /usr/local/bin/elite-x-update
}

# ========== USER MANAGEMENT ==========
setup_user_manager() {
    cat > /usr/local/bin/elite-x-user <<'EOF'
#!/bin/bash

RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m';WHITE='\033[1;37m';NC='\033[0m'

show_quote() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}            Always Remember ELITE-X when you see X            ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

UD="/etc/elite-x/users"
TD="/etc/elite-x/traffic"
mkdir -p $UD $TD

# Get traffic for a user
get_traffic() {
    local username="$1"
    local traffic_file="$TD/$username"
    if [ -f "$traffic_file" ]; then
        cat "$traffic_file"
    else
        echo "0"
    fi
}

# Get user's current active sessions
get_active_sessions() {
    local username="$1"
    pgrep -u "$username" | wc -l 2>/dev/null || echo "0"
}

show_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${YELLOW}              ELITE-X USER MANAGEMENT                          ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${WHITE}  [1] Add User                                                ${CYAN}║${NC}"
        echo -e "${CYAN}║${WHITE}  [2] List Users                                              ${CYAN}║${NC}"
        echo -e "${CYAN}║${WHITE}  [3] Renew User                                              ${CYAN}║${NC}"
        echo -e "${CYAN}║${WHITE}  [4] User Details                                            ${CYAN}║${NC}"
        echo -e "${CYAN}║${WHITE}  [5] Lock User                                               ${CYAN}║${NC}"
        echo -e "${CYAN}║${WHITE}  [6] Unlock User                                             ${CYAN}║${NC}"
        echo -e "${CYAN}║${WHITE}  [7] Delete User                                             ${CYAN}║${NC}"
        echo -e "${CYAN}║${WHITE}  [8] Delete Multiple Users                                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${WHITE}  [9] Export Users List                                       ${CYAN}║${NC}"
        echo -e "${CYAN}║${WHITE}  [10] Set User Login Limit                                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${WHITE}  [11] Reset User Traffic                                     ${CYAN}║${NC}"
        echo -e "${CYAN}║${WHITE}  [0] Back to Main Menu                                       ${CYAN}║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        read -p "$(echo -e $GREEN"Choose option [0-11]: "$NC)" opt
        
        case $opt in
            1) add_user ;;
            2) list_users ;;
            3) renew_user ;;
            4) user_details ;;
            5) lock_user ;;
            6) unlock_user ;;
            7) delete_user ;;
            8) delete_multiple ;;
            9) export_users ;;
            10) set_user_login_limit ;;
            11) reset_user_traffic ;;
            0) echo -e "${GREEN}Returning to main menu...${NC}"; sleep 1; return 0 ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
        esac
    done
}

add_user() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}                    ADD NEW USER                                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    read -p "$(echo -e $GREEN"Password: "$NC)" password
    read -p "$(echo -e $GREEN"Expire days: "$NC)" days
    read -p "$(echo -e $GREEN"Traffic limit (MB, 0 for unlimited): "$NC)" traffic_limit
    read -p "$(echo -e $GREEN"Max concurrent logins (0 for unlimited): "$NC)" max_logins
    
    if id "$username" &>/dev/null; then
        echo -e "${RED}User already exists!${NC}"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi
    
    useradd -m -s /bin/false "$username"
    echo "$username:$password" | chpasswd
    
    expire_date=$(date -d "+$days days" +"%Y-%m-%d")
    chage -E "$expire_date" "$username"
    
    # Set login limit
    if [ "$max_logins" -gt 0 ]; then
        sed -i "/Match User $username/,+3 d" /etc/ssh/sshd_config 2>/dev/null
        echo "Match User $username" >> /etc/ssh/sshd_config
        echo "    MaxSessions $max_logins" >> /etc/ssh/sshd_config
        systemctl restart sshd
    fi
    
    cat > $UD/$username <<INFO
Username: $username
Password: $password
Expire: $expire_date
Traffic_Limit: $traffic_limit
Max_Logins: $max_logins
Created: $(date +"%Y-%m-%d %H:%M:%S")
INFO
    
    echo "0" > $TD/$username
    
    SERVER=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "?")
    PUBKEY=$(cat /etc/dnstt/server.pub 2>/dev/null || echo "Not generated")
    
    clear
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo "User created successfully!"
    echo "Username      : $username"
    echo "Password      : $password"
    echo "Server        : $SERVER"
    echo "Public Key    : $PUBKEY"
    echo "Expire        : $expire_date"
    echo "Traffic Limit : $traffic_limit MB"
    echo "Max Logins    : $max_logins"
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

list_users() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}                    ACTIVE USERS                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    if [ -z "$(ls -A $UD 2>/dev/null)" ]; then
        echo -e "${RED}No users found${NC}"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi
    
    printf "%-12s %-10s %-10s %-10s %-12s %-8s\n" "USERNAME" "EXPIRE" "LIMIT(MB)" "USED(MB)" "USAGE%" "STATUS"
    echo "─────────────────────────────────────────────────────────────────────────"
    
    TOTAL_TRAFFIC=0
    TOTAL_USERS=0
    
    for user in $UD/*; do
        [ ! -f "$user" ] && continue
        u=$(basename "$user")
        ex=$(grep "Expire:" "$user" | cut -d' ' -f2)
        lm=$(grep "Traffic_Limit:" "$user" | cut -d' ' -f2)
        us=$(get_traffic "$u")
        
        if [ "$lm" -eq 0 ] || [ "$lm" = "0" ]; then
            usage_percent="Unlimited"
        else
            percent=$((us * 100 / lm))
            if [ $percent -ge 90 ]; then
                usage_percent="${RED}${percent}%${NC}"
            elif [ $percent -ge 70 ]; then
                usage_percent="${YELLOW}${percent}%${NC}"
            else
                usage_percent="${GREEN}${percent}%${NC}"
            fi
        fi
        
        st=$(passwd -S "$u" 2>/dev/null | grep -q "L" && echo "${RED}LOCK${NC}" || echo "${GREEN}OK${NC}")
        
        printf "%-12s %-10s %-10s %-10s %-12b %-8b\n" "$u" "$ex" "$lm" "$us" "$usage_percent" "$st"
        
        TOTAL_TRAFFIC=$((TOTAL_TRAFFIC + us))
        TOTAL_USERS=$((TOTAL_USERS + 1))
    done
    
    echo "─────────────────────────────────────────────────────────────────────────"
    echo -e "Total Users: ${GREEN}$TOTAL_USERS${NC} | Total Traffic Used: ${YELLOW}$TOTAL_TRAFFIC MB${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

reset_user_traffic() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}                 RESET USER TRAFFIC                              ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    read -p "$(echo -e $GREEN"Username: "$NC)" u
    
    if [ ! -f "$UD/$u" ]; then
        echo -e "${RED}User not found!${NC}"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi
    
    echo "0" > "$TD/$u"
    rm -f "$TD/${u}.history"
    
    echo -e "${GREEN}✅ Traffic reset for user $u${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

set_user_login_limit() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}                 SET USER LOGIN LIMIT                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    read -p "$(echo -e $GREEN"Username: "$NC)" u
    
    if [ ! -f "$UD/$u" ]; then
        echo -e "${RED}User not found!${NC}"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi
    
    current_limit=$(grep "Max_Logins:" "$UD/$u" 2>/dev/null | cut -d' ' -f2 || echo "0")
    echo "Current max logins: $current_limit"
    read -p "$(echo -e $GREEN"New max concurrent logins (0 for unlimited): "$NC)" new_limit
    
    if [ "$new_limit" -ge 0 ]; then
        if grep -q "Max_Logins:" "$UD/$u"; then
            sed -i "s/Max_Logins:.*/Max_Logins: $new_limit/" "$UD/$u"
        else
            echo "Max_Logins: $new_limit" >> "$UD/$u"
        fi
        
        if [ "$new_limit" -gt 0 ]; then
            sed -i "/Match User $u/,+3 d" /etc/ssh/sshd_config 2>/dev/null
            echo "Match User $u" >> /etc/ssh/sshd_config
            echo "    MaxSessions $new_limit" >> /etc/ssh/sshd_config
            systemctl restart sshd
        else
            sed -i "/Match User $u/,+3 d" /etc/ssh/sshd_config
            systemctl restart sshd
        fi
        
        echo -e "${GREEN}Login limit updated to $new_limit${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

renew_user() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}                    RENEW USER                                   ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    read -p "$(echo -e $GREEN"Username: "$NC)" u
    
    if [ ! -f "$UD/$u" ]; then
        echo -e "${RED}User not found!${NC}"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi
    
    current_expire=$(grep "Expire:" "$UD/$u" | cut -d' ' -f2)
    current_limit=$(grep "Traffic_Limit:" "$UD/$u" | cut -d' ' -f2)
    
    echo "Current expiry: $current_expire"
    echo "Current limit: $current_limit MB"
    echo ""
    
    read -p "$(echo -e $GREEN"Add how many days? (0 to skip): "$NC)" add_days
    read -p "$(echo -e $GREEN"New traffic limit MB (0 to keep current): "$NC)" new_limit
    read -p "$(echo -e $GREEN"Reset traffic usage? (y/n): "$NC)" reset_traffic
    
    if [ "$add_days" -gt 0 ]; then
        new_expire=$(date -d "$current_expire + $add_days days" +"%Y-%m-%d")
        chage -E "$new_expire" "$u"
        sed -i "s/Expire:.*/Expire: $new_expire/" "$UD/$u"
        echo -e "${GREEN}Expiry updated to: $new_expire${NC}"
    fi
    
    if [ "$new_limit" -gt 0 ]; then
        sed -i "s/Traffic_Limit:.*/Traffic_Limit: $new_limit/" "$UD/$u"
        echo -e "${GREEN}Traffic limit updated to: $new_limit MB${NC}"
    fi
    
    if [ "$reset_traffic" = "y" ]; then
        echo "0" > "$TD/$u"
        rm -f "$TD/${u}.history"
        echo -e "${GREEN}Traffic usage reset to 0 MB${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

user_details() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}                    USER DETAILS                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    read -p "$(echo -e $GREEN"Username: "$NC)" u
    
    if [ ! -f "$UD/$u" ]; then
        echo -e "${RED}User not found!${NC}"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi
    
    current_traffic=$(get_traffic "$u")
    
    echo -e "${YELLOW}User Information:${NC}"
    echo "──────────────────"
    cat "$UD/$u"
    echo ""
    echo -e "Current Traffic Used: ${CYAN}$current_traffic MB${NC}"
    
    # Show traffic history
    if [ -f "$TD/${u}.history" ]; then
        echo -e "\n${YELLOW}Traffic History (last 24 checks):${NC}"
        tail -n 24 "$TD/${u}.history" | while read line; do
            ts=$(echo "$line" | cut -d: -f1)
            mb=$(echo "$line" | cut -d: -f2)
            time=$(date -d @$ts +"%H:%M" 2>/dev/null || echo "??")
            echo "  $time: ${mb}MB"
        done
    fi
    
    # Show active connections
    echo -e "\n${YELLOW}Active Connections:${NC}"
    ss -tnp | grep -E ":22" | while read line; do
        pid=$(echo "$line" | grep -o "pid=[0-9]*" | cut -d= -f2)
        if [ -n "$pid" ]; then
            user=$(ps -o user= -p "$pid" 2>/dev/null)
            if [ "$user" = "$u" ]; then
                IP=$(echo "$line" | awk '{print $5}' | cut -d: -f1)
                echo "  ${GREEN}→${NC} $IP"
            fi
        fi
    done | sort -u | while read ip; do
        echo "$ip"
    done
    
    if [ -z "$(ss -tnp | grep -E ":22" | grep "$u" 2>/dev/null)" ]; then
        echo "  No active connections"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

lock_user() { 
    read -p "$(echo -e $GREEN"Username: "$NC)" u
    if [ -f "$UD/$u" ]; then
        usermod -L "$u" 2>/dev/null
        pkill -u "$u" 2>/dev/null || true
        echo -e "${GREEN}✅ User $u locked${NC}"
    else
        echo -e "${RED}User not found${NC}"
    fi
    echo ""
    read -p "Press Enter to continue..."
}

unlock_user() { 
    read -p "$(echo -e $GREEN"Username: "$NC)" u
    if [ -f "$UD/$u" ]; then
        usermod -U "$u" 2>/dev/null
        echo -e "${GREEN}✅ User $u unlocked${NC}"
    else
        echo -e "${RED}User not found${NC}"
    fi
    echo ""
    read -p "Press Enter to continue..."
}

delete_user() { 
    read -p "$(echo -e $GREEN"Username: "$NC)" u
    if [ -f "$UD/$u" ]; then
        sed -i "/Match User $u/,+3 d" /etc/ssh/sshd_config 2>/dev/null
        systemctl restart sshd
        
        userdel -r "$u" 2>/dev/null
        rm -f $UD/$u $TD/$u $TD/${u}.history
        echo -e "${GREEN}✅ User $u deleted${NC}"
    else
        echo -e "${RED}User not found${NC}"
    fi
    echo ""
    read -p "Press Enter to continue..."
}

delete_multiple() {
    echo -e "${YELLOW}Enter usernames to delete (space separated):${NC}"
    read -a users
    for u in "${users[@]}"; do
        if [ -f "$UD/$u" ]; then
            sed -i "/Match User $u/,+3 d" /etc/ssh/sshd_config 2>/dev/null
            systemctl restart sshd
            userdel -r "$u" 2>/dev/null
            rm -f $UD/$u $TD/$u $TD/${u}.history
            echo -e "${GREEN}✅ Deleted: $u${NC}"
        else
            echo -e "${RED}❌ Not found: $u${NC}"
        fi
    done
    echo ""
    read -p "Press Enter to continue..."
}

export_users() {
    local export_file="/root/elite-x-users-$(date +%Y%m%d-%H%M%S).txt"
    echo "ELITE-X Users List - $(date)" > "$export_file"
    echo "=================================" >> "$export_file"
    echo "" >> "$export_file"
    
    for user in $UD/*; do
        if [ -f "$user" ]; then
            u=$(basename "$user")
            traffic=$(get_traffic "$u")
            echo "User: $u" >> "$export_file"
            cat "$user" >> "$export_file"
            echo "Current Traffic Used: $traffic MB" >> "$export_file"
            echo "-------------------" >> "$export_file"
        fi
    done
    
    echo -e "${GREEN}✅ Users exported to: $export_file${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

show_menu
EOF
    chmod +x /usr/local/bin/elite-x-user
}

# ========== MAIN MENU ==========
setup_main_menu() {
    cat >/usr/local/bin/elite-x <<'EOF'
#!/bin/bash

RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m'
PURPLE='\033[0;35m';WHITE='\033[1;37m';BOLD='\033[1m';NC='\033[0m'

show_quote() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}            Always Remember ELITE-X when you see X            ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

if [ -f /tmp/elite-x-running ]; then
    exit 0
fi
touch /tmp/elite-x-running
trap 'rm -f /tmp/elite-x-running' EXIT

check_expiry_menu() {
    if [ -f "/etc/elite-x/activation_type" ] && [ -f "/etc/elite-x/activation_date" ] && [ -f "/etc/elite-x/expiry_days" ]; then
        local act_type=$(cat "/etc/elite-x/activation_type")
        if [ "$act_type" = "temporary" ]; then
            local act_date=$(cat "/etc/elite-x/activation_date")
            local expiry_days=$(cat "/etc/elite-x/expiry_days")
            local current_date=$(date +%s)
            local expiry_date=$(date -d "$act_date + $expiry_days days" +%s)
            
            if [ $current_date -ge $expiry_date ]; then
                echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${RED}║${YELLOW}           TRIAL PERIOD EXPIRED                                  ${RED}║${NC}"
                echo -e "${RED}╠═══════════════════════════════════════════════════════════════╣${NC}"
                echo -e "${RED}║${WHITE}  Your 2-day trial has ended.                                  ${RED}║${NC}"
                echo -e "${RED}║${WHITE}  Script will now uninstall itself...                         ${RED}║${NC}"
                echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
                sleep 3
                
                echo -e "${YELLOW}🔄 Removing all users and data...${NC}"
                
                if [ -d "/etc/elite-x/users" ]; then
                    for user_file in /etc/elite-x/users/*; do
                        if [ -f "$user_file" ]; then
                            username=$(basename "$user_file")
                            echo -e "  Removing user: $username"
                            userdel -r "$username" 2>/dev/null || true
                            pkill -u "$username" 2>/dev/null || true
                        fi
                    done
                fi
                
                pkill -f dnstt-server 2>/dev/null || true
                pkill -f dnstt-edns-proxy 2>/dev/null || true
                pkill -f elite-x-traffic 2>/dev/null || true
                pkill -f elite-x-cleaner 2>/dev/null || true
                pkill -f elite-x-bandwidth 2>/dev/null || true
                pkill -f elite-x-monitor 2>/dev/null || true
                pkill -f elite-x-speed 2>/dev/null || true
                
                systemctl stop dnstt-elite-x dnstt-elite-x-proxy elite-x-traffic elite-x-cleaner elite-x-bandwidth elite-x-monitor 2>/dev/null || true
                systemctl disable dnstt-elite-x dnstt-elite-x-proxy elite-x-traffic elite-x-cleaner elite-x-bandwidth elite-x-monitor 2>/dev/null || true
                
                rm -rf /etc/systemd/system/dnstt-elite-x*
                rm -rf /etc/systemd/system/elite-x-*
                rm -rf /etc/dnstt /etc/elite-x
                rm -f /usr/local/bin/dnstt-*
                rm -f /usr/local/bin/elite-x*
                
                sed -i '/^Banner/d' /etc/ssh/sshd_config
                systemctl restart sshd
                
                rm -f /etc/profile.d/elite-x-dashboard.sh
                sed -i '/elite-x/d' ~/.bashrc
                sed -i '/ELITE_X_SHOWN/d' ~/.bashrc
                
                rm -f /etc/cron.hourly/elite-x-expiry
                rm -f /etc/cron.daily/elite-x-backup
                rm -f /etc/cron.hourly/elite-x-bandwidth
                
                echo -e "${GREEN}✅ ELITE-X has been uninstalled.${NC}"
                rm -f /tmp/elite-x-running
                exit 0
            fi
        fi
    fi
}

check_expiry_menu

show_dashboard() {
    clear
    
    IP=$(cat /etc/elite-x/cached_ip 2>/dev/null || curl -s ifconfig.me 2>/dev/null || echo "Unknown")
    LOC=$(cat /etc/elite-x/cached_location 2>/dev/null || echo "Unknown")
    ISP=$(cat /etc/elite-x/cached_isp 2>/dev/null || echo "Unknown")
    RAM=$(free -m | awk '/^Mem:/{print $3"/"$2"MB"}')
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    UPTIME=$(uptime | awk -F'up' '{print $2}' | awk -F',' '{print $1}')
    SUB=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "Not configured")
    
    if [ -f "/etc/elite-x/key" ]; then
        ACTIVATION_KEY=$(cat /etc/elite-x/key)
    else
        ACTIVATION_KEY="ELITEX-2026-DAN-4D-08"
        echo "$ACTIVATION_KEY" > /etc/elite-x/key
    fi
    
    if [ -f "/etc/elite-x/expiry" ]; then
        EXP=$(cat /etc/elite-x/expiry)
    else
        EXP="Lifetime"
        echo "Lifetime" > /etc/elite-x/expiry
    fi
    
    LOCATION=$(cat /etc/elite-x/location 2>/dev/null || echo "South Africa")
    CURRENT_MTU=$(cat /etc/elite-x/mtu 2>/dev/null || echo "1800")
    
    SSH_CONN=$(ss -tnp | grep -c ":22.*ESTAB" 2>/dev/null || echo "0")
    DNS_CONN=$(ss -unp | grep -c ":5300" 2>/dev/null || echo "0")
    
    if systemctl is-active dnstt-elite-x >/dev/null 2>&1; then
        DNS="${GREEN}●${NC}"
    else
        DNS="${RED}●${NC}"
    fi
    
    PRX=$(systemctl is-active dnstt-elite-x-proxy 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    TRAF=$(systemctl is-active elite-x-traffic 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    CLN=$(systemctl is-active elite-x-cleaner 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    BAND=$(systemctl is-active elite-x-bandwidth 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    MON=$(systemctl is-active elite-x-monitor 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    
    TOTAL_TRAFFIC=0
    if [ -d "/etc/elite-x/traffic" ]; then
        for traffic_file in /etc/elite-x/traffic/*; do
            if [ -f "$traffic_file" ] && [[ ! "$traffic_file" =~ \.history$ ]]; then
                traffic=$(cat "$traffic_file" 2>/dev/null || echo "0")
                TOTAL_TRAFFIC=$((TOTAL_TRAFFIC + traffic))
            fi
        done
    fi
    
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}                    ELITE-X SLOWDNS v3.5                       ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${WHITE}  Subdomain :${GREEN} $SUB${NC}"
    echo -e "${PURPLE}║${WHITE}  IP        :${GREEN} $IP${NC}"
    echo -e "${PURPLE}║${WHITE}  Location  :${GREEN} $LOC${NC}"
    echo -e "${PURPLE}║${WHITE}  ISP       :${GREEN} $ISP${NC}"
    echo -e "${PURPLE}║${WHITE}  RAM       :${GREEN} $RAM | CPU: ${CPU}% | Uptime: ${UPTIME}${NC}"
    echo -e "${PURPLE}║${WHITE}  VPS Loc   :${GREEN} $LOCATION | MTU: $CURRENT_MTU${NC}"
    echo -e "${PURPLE}║${WHITE}  Services  : DNS:$DNS PRX:$PRX TRAF:$TRAF CLN:$CLN BAND:$BAND MON:$MON${NC}"
    echo -e "${PURPLE}║${WHITE}  Connections: SSH: ${GREEN}$SSH_CONN${NC} | DNS: ${YELLOW}$DNS_CONN${NC}"
    echo -e "${PURPLE}║${WHITE}  Total Traffic Used: ${YELLOW}$TOTAL_TRAFFIC MB${NC}"
    echo -e "${PURPLE}║${WHITE}  Developer :${PURPLE} ELITE-X TEAM${NC}"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${WHITE}  Act Key   :${YELLOW} $ACTIVATION_KEY${NC}"
    echo -e "${PURPLE}║${WHITE}  Expiry    :${YELLOW} $EXP${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

system_info() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}                    SYSTEM INFORMATION                           ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${GREEN}OS:${NC} $(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo -e "${GREEN}Kernel:${NC} $(uname -r)"
    echo -e "${GREEN}Architecture:${NC} $(uname -m)"
    echo -e "${GREEN}Hostname:${NC} $(hostname)"
    echo -e "${GREEN}CPU:${NC} $(nproc) cores"
    echo -e "${GREEN}Memory Total:${NC} $(free -h | awk '/^Mem:/{print $2}')"
    echo -e "${GREEN}Memory Used:${NC} $(free -h | awk '/^Mem:/{print $3}')"
    echo -e "${GREEN}Disk Total:${NC} $(df -h / | awk 'NR==2{print $2}')"
    echo -e "${GREEN}Disk Used:${NC} $(df -h / | awk 'NR==2{print $3}')"
    echo -e "${GREEN}Load Average:${NC} $(uptime | awk -F'load average:' '{print $2}')"
    
    echo ""
    read -p "Press Enter to continue..."
}

settings_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${YELLOW}${BOLD}                      SETTINGS MENU                              ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${WHITE}  [8]  🔑 View Public Key${NC}"
        echo -e "${CYAN}║${WHITE}  [9]  Change MTU Value${NC}"
        echo -e "${CYAN}║${WHITE}  [10] ⚡ Speed Optimization Menu${NC}"
        echo -e "${CYAN}║${WHITE}  [11] 🧹 Clean Junk Files${NC}"
        echo -e "${CYAN}║${WHITE}  [12] 🔄 Auto Expired Account Remover${NC}"
        echo -e "${CYAN}║${WHITE}  [13] 📦 Update Script${NC}"
        echo -e "${CYAN}║${WHITE}  [14] 🔄 Restart All Services${NC}"
        echo -e "${CYAN}║${WHITE}  [15] 📊 System Info${NC}"
        echo -e "${CYAN}║${WHITE}  [16] 💾 Backup Configuration${NC}"
        echo -e "${CYAN}║${WHITE}  [17] 📈 Speed Test${NC}"
        echo -e "${CYAN}║${WHITE}  [18] 👁️  Connection Monitor${NC}"
        echo -e "${CYAN}║${WHITE}  [19] 🚀 Turbo Optimize${NC}"
        echo -e "${CYAN}║${WHITE}  [20] 🔄 Reboot VPS${NC}"
        echo -e "${CYAN}║${WHITE}  [21] 🗑️  Uninstall Script${NC}"
        echo -e "${CYAN}║${WHITE}  [22] 🌍 Re-apply Location Optimization${NC}"
        echo -e "${CYAN}║${WHITE}  [0]  Back to Main Menu${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        read -p "$(echo -e $GREEN"Settings option: "$NC)" ch
        
        case $ch in
            8)
                echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${CYAN}║${YELLOW}                    PUBLIC KEY                                   ${CYAN}║${NC}"
                echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
                echo -e "${CYAN}║${GREEN}  $(cat /etc/dnstt/server.pub)${NC}"
                echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
                read -p "Press Enter to continue..."
                ;;
            9)
                echo "Current MTU: $(cat /etc/elite-x/mtu)"
                read -p "New MTU (1000-5000): " mtu
                [[ "$mtu" =~ ^[0-9]+$ ]] && [ $mtu -ge 1000 ] && [ $mtu -le 5000 ] && {
                    echo "$mtu" > /etc/elite-x/mtu
                    sed -i "s/-mtu [0-9]*/-mtu $mtu/" /etc/systemd/system/dnstt-elite-x.service
                    systemctl daemon-reload
                    systemctl restart dnstt-elite-x dnstt-elite-x-proxy
                    echo -e "${GREEN}✅ MTU updated to $mtu${NC}"
                } || echo -e "${RED}❌ Invalid (must be 1000-5000)${NC}"
                read -p "Press Enter to continue..."
                ;;
            10) elite-x-speed; read -p "Press Enter to continue..." ;;
            11) elite-x-speed clean; read -p "Press Enter to continue..." ;;
            12)
                systemctl enable --now elite-x-cleaner.service 2>/dev/null
                echo -e "${GREEN}✅ Auto remover started${NC}"
                read -p "Press Enter to continue..."
                ;;
            13) elite-x-update; read -p "Press Enter to continue..." ;;
            14)
                systemctl restart dnstt-elite-x dnstt-elite-x-proxy elite-x-traffic elite-x-cleaner elite-x-bandwidth elite-x-monitor sshd 2>/dev/null
                echo -e "${GREEN}✅ Services restarted${NC}"
                read -p "Press Enter to continue..."
                ;;
            15) system_info ;;
            16)
                /usr/local/bin/elite-x-backup
                echo -e "${GREEN}✅ Backup completed${NC}"
                read -p "Press Enter to continue..."
                ;;
            17) /usr/local/bin/elite-x-speedtest; read -p "Press Enter to continue..." ;;
            18) 
                echo -e "${YELLOW}Starting connection monitor (Press 'q' to exit)...${NC}"
                sleep 2
                /usr/local/bin/elite-x-monitor
                ;;
            19) /usr/local/bin/elite-x-optimize; read -p "Press Enter to continue..." ;;
            20)
                read -p "Reboot? (y/n): " c
                [ "$c" = "y" ] && reboot
                ;;
            21)
                read -p "Uninstall? (YES): " c
                [ "$c" = "YES" ] && {
                    echo -e "${YELLOW}🔄 Removing all users and data...${NC}"
                    
                    if [ -d "/etc/elite-x/users" ]; then
                        for user_file in /etc/elite-x/users/*; do
                            if [ -f "$user_file" ]; then
                                username=$(basename "$user_file")
                                echo -e "  Removing user: $username"
                                userdel -r "$username" 2>/dev/null || true
                                pkill -u "$username" 2>/dev/null || true
                            fi
                        done
                    fi
                    
                    pkill -f dnstt-server 2>/dev/null || true
                    pkill -f dnstt-edns-proxy 2>/dev/null || true
                    pkill -f elite-x-traffic 2>/dev/null || true
                    pkill -f elite-x-cleaner 2>/dev/null || true
                    pkill -f elite-x-bandwidth 2>/dev/null || true
                    pkill -f elite-x-monitor 2>/dev/null || true
                    pkill -f elite-x-speed 2>/dev/null || true
                    
                    systemctl stop dnstt-elite-x dnstt-elite-x-proxy elite-x-traffic elite-x-cleaner elite-x-bandwidth elite-x-monitor 2>/dev/null || true
                    systemctl disable dnstt-elite-x dnstt-elite-x-proxy elite-x-traffic elite-x-cleaner elite-x-bandwidth elite-x-monitor 2>/dev/null || true
                    
                    rm -rf /etc/systemd/system/dnstt-elite-x*
                    rm -rf /etc/systemd/system/elite-x-*
                    rm -rf /etc/dnstt /etc/elite-x
                    rm -f /usr/local/bin/dnstt-*
                    rm -f /usr/local/bin/elite-x*
                    
                    sed -i '/^Banner/d' /etc/ssh/sshd_config
                    systemctl restart sshd
                    
                    rm -f /etc/profile.d/elite-x-dashboard.sh
                    sed -i '/elite-x/d' ~/.bashrc
                    sed -i '/ELITE_X_SHOWN/d' ~/.bashrc
                    
                    rm -f /etc/cron.hourly/elite-x-expiry
                    rm -f /etc/cron.daily/elite-x-backup
                    rm -f /etc/cron.hourly/elite-x-bandwidth
                    
                    echo -e "${GREEN}✅ Uninstalled completely${NC}"
                    rm -f /tmp/elite-x-running
                    exit 0
                }
                read -p "Press Enter to continue..."
                ;;
            22)
                echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
                echo -e "${GREEN}           RE-APPLY LOCATION OPTIMIZATION                        ${NC}"
                echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
                echo -e "${WHITE}Select your VPS location:${NC}"
                echo -e "${GREEN}  1. South Africa (MTU 1800)${NC}"
                echo -e "${CYAN}  2. USA${NC}"
                echo -e "${BLUE}  3. Europe${NC}"
                echo -e "${PURPLE}  4. Asia${NC}"
                echo -e "${YELLOW}  5. Auto-detect${NC}"
                read -p "Choice: " opt_choice
                
                case $opt_choice in
                    1) echo "South Africa" > /etc/elite-x/location
                       echo "1800" > /etc/elite-x/mtu
                       sed -i "s/-mtu [0-9]*/-mtu 1800/" /etc/systemd/system/dnstt-elite-x.service
                       systemctl daemon-reload
                       systemctl restart dnstt-elite-x dnstt-elite-x-proxy
                       echo -e "${GREEN}✅ South Africa selected (MTU 1800)${NC}" ;;
                    2) echo "USA" > /etc/elite-x/location
                       echo -e "${GREEN}✅ USA selected${NC}" ;;
                    3) echo "Europe" > /etc/elite-x/location
                       echo -e "${GREEN}✅ Europe selected${NC}" ;;
                    4) echo "Asia" > /etc/elite-x/location
                       echo -e "${GREEN}✅ Asia selected${NC}" ;;
                    5) echo "Auto-detect" > /etc/elite-x/location
                       echo -e "${GREEN}✅ Auto-detect selected${NC}" ;;
                esac
                read -p "Press Enter to continue..."
                ;;
            0) echo -e "${GREEN}Returning to main menu...${NC}"; sleep 1; return 0 ;;
            *) echo -e "${RED}Invalid option${NC}"; read -p "Press Enter to continue..." ;;
        esac
    done
}

main_menu() {
    while true; do
        show_dashboard
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${GREEN}${BOLD}                         MAIN MENU                              ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${WHITE}  [1] 👤 User Management Menu${NC}"
        echo -e "${CYAN}║${WHITE}  [2] 📊 View All Users${NC}"
        echo -e "${CYAN}║${WHITE}  [3] 🔒 Lock User${NC}"
        echo -e "${CYAN}║${WHITE}  [4] 🔓 Unlock User${NC}"
        echo -e "${CYAN}║${WHITE}  [5] 🗑️  Delete User${NC}"
        echo -e "${CYAN}║${WHITE}  [6] 📝 Create/Edit Banner${NC}"
        echo -e "${CYAN}║${WHITE}  [7] ❌ Delete Banner${NC}"
        echo -e "${CYAN}║${WHITE}  [8] 📈 Traffic Statistics${NC}"
        echo -e "${CYAN}║${RED}  [S] ⚙️  Settings${NC}"
        echo -e "${CYAN}║${WHITE}  [0] 🚪 Exit${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        read -p "$(echo -e $GREEN"Main menu option: "$NC)" ch
        
        case $ch in
            1) elite-x-user ;;
            2) elite-x-user list ;;
            3) elite-x-user lock ;;
            4) elite-x-user unlock ;;
            5) elite-x-user del ;;
            6)
                [ -f /etc/elite-x/banner/custom ] || cp /etc/elite-x/banner/default /etc/elite-x/banner/custom
                nano /etc/elite-x/banner/custom
                cp /etc/elite-x/banner/custom /etc/elite-x/banner/ssh-banner
                systemctl restart sshd
                echo -e "${GREEN}✅ Banner saved${NC}"
                read -p "Press Enter to continue..."
                ;;
            7)
                rm -f /etc/elite-x/banner/custom
                cp /etc/elite-x/banner/default /etc/elite-x/banner/ssh-banner
                systemctl restart sshd
                echo -e "${GREEN}✅ Banner deleted${NC}"
                read -p "Press Enter to continue..."
                ;;
            8)
                clear
                echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${CYAN}║${YELLOW}                    TRAFFIC STATISTICS                            ${CYAN}║${NC}"
                echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
                echo ""
                printf "%-12s %-15s %-12s %-12s\n" "USERNAME" "LIMIT (MB)" "USED (MB)" "USAGE%"
                echo "─────────────────────────────────────────────────"
                TOTAL=0
                for user in /etc/elite-x/users/*; do
                    if [ -f "$user" ]; then
                        u=$(basename "$user")
                        limit=$(grep "Traffic_Limit:" "$user" | cut -d' ' -f2)
                        used=$(cat /etc/elite-x/traffic/$u 2>/dev/null || echo "0")
                        if [ "$limit" -eq 0 ] || [ "$limit" = "0" ]; then
                            percent="Unlimited"
                        else
                            p=$((used * 100 / limit))
                            percent="${p}%"
                        fi
                        printf "%-12s %-15s %-12s %-12s\n" "$u" "$limit" "$used" "$percent"
                        TOTAL=$((TOTAL + used))
                    fi
                done
                echo "─────────────────────────────────────────────────"
                echo -e "Total Traffic Used: ${YELLOW}$TOTAL MB${NC}"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            [Ss]) settings_menu ;;
            0) 
                rm -f /tmp/elite-x-running
                show_quote
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0 
                ;;
            *) echo -e "${RED}Invalid option${NC}"; read -p "Press Enter to continue..." ;;
        esac
    done
}

main_menu
EOF
chmod +x /usr/local/bin/elite-x
}

# ========== START ALL SERVICES ==========
start_all_services() {
    echo -e "${YELLOW}Starting all ELITE-X services...${NC}"
    
    systemctl daemon-reload
    
    fuser -k 53/udp 2>/dev/null || true
    fuser -k 5300/udp 2>/dev/null || true
    sleep 2
    
    echo -n "Starting DNSTT Server... "
    systemctl enable dnstt-elite-x.service 2>/dev/null
    systemctl start dnstt-elite-x.service 2>/dev/null
    sleep 3
    if systemctl is-active dnstt-elite-x >/dev/null 2>&1; then
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${RED}❌${NC}"
    fi
    
    echo -n "Starting DNSTT Proxy... "
    systemctl enable dnstt-elite-x-proxy.service 2>/dev/null
    systemctl start dnstt-elite-x-proxy.service 2>/dev/null
    sleep 2
    if systemctl is-active dnstt-elite-x-proxy >/dev/null 2>&1; then
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${RED}❌${NC}"
    fi
    
    echo -n "Starting Traffic Monitor... "
    systemctl enable elite-x-traffic.service 2>/dev/null
    systemctl start elite-x-traffic.service 2>/dev/null
    sleep 2
    if systemctl is-active elite-x-traffic >/dev/null 2>&1; then
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${RED}❌${NC}"
    fi
    
    echo -n "Starting Auto Cleaner... "
    systemctl enable elite-x-cleaner.service 2>/dev/null
    systemctl start elite-x-cleaner.service 2>/dev/null
    sleep 2
    if systemctl is-active elite-x-cleaner >/dev/null 2>&1; then
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${RED}❌${NC}"
    fi
    
    echo -n "Starting Bandwidth Monitor... "
    systemctl enable elite-x-bandwidth.service 2>/dev/null
    systemctl start elite-x-bandwidth.service 2>/dev/null
    sleep 2
    if systemctl is-active elite-x-bandwidth >/dev/null 2>&1; then
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${RED}❌${NC}"
    fi
    
    echo -n "Starting Connection Monitor... "
    systemctl enable elite-x-monitor.service 2>/dev/null
    systemctl start elite-x-monitor.service 2>/dev/null
    sleep 2
    if systemctl is-active elite-x-monitor >/dev/null 2>&1; then
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${YELLOW}⚠️${NC}"
    fi
}

# ========== MAIN INSTALLATION ==========
show_banner
echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║${GREEN}                    ACTIVATION REQUIRED                          ${YELLOW}║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${WHITE}Available Keys:${NC}"
echo -e "${GREEN}  Lifetime : Whtsapp 0713628668${NC}"
echo -e "${YELLOW}  Trial    : ELITE-X-TEST-0208 (2 days)${NC}"
echo ""
read -p "$(echo -e $CYAN"Activation Key: "$NC)" ACTIVATION_INPUT

mkdir -p /etc/elite-x
if ! activate_script "$ACTIVATION_INPUT"; then
    echo -e "${RED}❌ Invalid activation key! Installation cancelled.${NC}"
    exit 1
fi

ensure_key_files

echo -e "${GREEN}✅ Activation successful!${NC}"
sleep 1

if [ -f "$ACTIVATION_TYPE_FILE" ] && [ "$(cat "$ACTIVATION_TYPE_FILE")" = "temporary" ]; then
    echo -e "${YELLOW}⚠️  Trial version activated - expires in 2 days${NC}"
fi
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
echo -e "${YELLOW}║${GREEN}  [1] South Africa (Default - MTU 1800)                        ${YELLOW}║${NC}"
echo -e "${YELLOW}║${CYAN}  [2] USA                                                       ${YELLOW}║${NC}"
echo -e "${YELLOW}║${BLUE}  [3] Europe                                                    ${YELLOW}║${NC}"
echo -e "${YELLOW}║${PURPLE}  [4] Asia                                                      ${YELLOW}║${NC}"
echo -e "${YELLOW}║${YELLOW}  [5] Auto-detect                                                ${YELLOW}║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
read -p "$(echo -e $GREEN"Select location [1-5] [default: 1]: "$NC)" LOCATION_CHOICE
LOCATION_CHOICE=${LOCATION_CHOICE:-1}

MTU=1800
SELECTED_LOCATION="South Africa"

case $LOCATION_CHOICE in
    2)
        SELECTED_LOCATION="USA"
        echo -e "${CYAN}✅ USA selected${NC}"
        ;;
    3)
        SELECTED_LOCATION="Europe"
        echo -e "${BLUE}✅ Europe selected${NC}"
        ;;
    4)
        SELECTED_LOCATION="Asia"
        echo -e "${PURPLE}✅ Asia selected${NC}"
        ;;
    5)
        SELECTED_LOCATION="Auto-detect"
        echo -e "${YELLOW}✅ Auto-detect selected${NC}"
        ;;
    *)
        SELECTED_LOCATION="South Africa"
        echo -e "${GREEN}✅ Using South Africa configuration${NC}"
        ;;
esac

echo "$SELECTED_LOCATION" > /etc/elite-x/location
echo "$MTU" > /etc/elite-x/mtu

DNSTT_PORT=5300

echo "==> ELITE-X V3.5 INSTALLATION STARTING..."

if [ "$(id -u)" -ne 0 ]; then
  echo "[-] Run as root"
  exit 1
fi

# Clean previous installation
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

pkill -f dnstt-server 2>/dev/null || true
pkill -f dnstt-edns-proxy 2>/dev/null || true
pkill -f elite-x-traffic 2>/dev/null || true
pkill -f elite-x-cleaner 2>/dev/null || true
pkill -f elite-x-bandwidth 2>/dev/null || true
pkill -f elite-x-monitor 2>/dev/null || true

systemctl stop dnstt-elite-x dnstt-elite-x-proxy elite-x-traffic elite-x-cleaner elite-x-bandwidth elite-x-monitor 2>/dev/null || true
systemctl disable dnstt-elite-x dnstt-elite-x-proxy elite-x-traffic elite-x-cleaner elite-x-bandwidth elite-x-monitor 2>/dev/null || true

rm -rf /etc/systemd/system/dnstt-elite-x*
rm -rf /etc/systemd/system/elite-x-*
rm -rf /etc/dnstt /etc/elite-x
rm -f /usr/local/bin/dnstt-*
rm -f /usr/local/bin/elite-x*

sed -i '/^Banner/d' /etc/ssh/sshd_config
systemctl restart sshd

rm -f /etc/profile.d/elite-x-dashboard.sh
sed -i '/elite-x/d' ~/.bashrc 2>/dev/null || true
sed -i '/ELITE_X_SHOWN/d' ~/.bashrc 2>/dev/null || true

rm -f /etc/cron.hourly/elite-x-expiry
rm -f /etc/cron.daily/elite-x-backup
rm -f /etc/cron.hourly/elite-x-bandwidth

echo -e "${GREEN}✅ Previous installation cleaned${NC}"
sleep 2

# Create directories
mkdir -p /etc/elite-x/{banner,users,traffic}
echo "$TDOMAIN" > /etc/elite-x/subdomain

# Create banners
cat > /etc/elite-x/banner/default <<'EOF'
===============================================
      WELCOME TO ELITE-X VPN SERVICE
===============================================
     High Speed • Secure • Unlimited
===============================================
EOF

cat > /etc/elite-x/banner/ssh-banner <<'EOF'
===============================================
           ELITE-X VPN SERVICE             
    High Speed • Secure • Unlimited      
===============================================
EOF

if ! grep -q "^Banner" /etc/ssh/sshd_config; then
    echo "Banner /etc/elite-x/banner/ssh-banner" >> /etc/ssh/sshd_config
else
    sed -i 's|^Banner.*|Banner /etc/elite-x/banner/ssh-banner|' /etc/ssh/sshd_config
fi
systemctl restart sshd

echo "Stopping old services..."
for svc in dnstt dnstt-server slowdns dnstt-smart dnstt-elite-x dnstt-elite-x-proxy; do
  systemctl disable --now "$svc" 2>/dev/null || true
done

if [ -f /etc/systemd/resolved.conf ]; then
  echo "Configuring systemd-resolved..."
  sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf || true
  systemctl restart systemd-resolved 2>/dev/null || true
  
  echo "nameserver 8.8.8.8" > /etc/resolv.conf 2>/dev/null || echo "nameserver 8.8.8.8" | tee /etc/resolv.conf >/dev/null
  echo "nameserver 8.8.4.4" >> /etc/resolv.conf 2>/dev/null || echo "nameserver 8.8.4.4" | tee -a /etc/resolv.conf >/dev/null
fi

echo "Installing dependencies..."
apt update -y
apt install -y curl python3 jq nano iptables iptables-persistent ethtool dnsutils net-tools bc

# Setup all components
setup_dnstt_server
setup_edns_proxy
setup_traffic_monitor
setup_auto_remover
setup_bandwidth_monitor
setup_bandwidth_tester
setup_auto_backup
setup_system_optimizer
setup_connection_monitor
setup_manual_speed
setup_updater
setup_user_manager
setup_main_menu

command -v ufw >/dev/null && ufw allow 22/tcp && ufw allow 53/udp || true

ensure_key_files

start_all_services

# Network interface optimizations
for iface in $(ls /sys/class/net/ | grep -v lo 2>/dev/null); do
    ethtool -K $iface tx off sg off tso off 2>/dev/null || true
done

IP=$(curl -4 -s ifconfig.me 2>/dev/null || echo "Unknown")
echo "$IP" > /etc/elite-x/cached_ip

if [ "$IP" != "Unknown" ]; then
    LOCATION_INFO=$(curl -s http://ip-api.com/json/$IP 2>/dev/null)
    echo "$LOCATION_INFO" | jq -r '.city + ", " + .country' 2>/dev/null > /etc/elite-x/cached_location || echo "Unknown" > /etc/elite-x/cached_location
    echo "$LOCATION_INFO" | jq -r '.isp' 2>/dev/null > /etc/elite-x/cached_isp || echo "Unknown" > /etc/elite-x/cached_isp
fi

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
alias speed='elite-x-speed'
alias monitor='elite-x-monitor'
alias test-speed='elite-x-speedtest'
alias optimize='elite-x-optimize'
EOF

cat > /etc/cron.hourly/elite-x-expiry <<'EOF'
#!/bin/bash
if [ -f /usr/local/bin/elite-x ]; then
    /usr/local/bin/elite-x --check-expiry
fi
EOF
chmod +x /etc/cron.hourly/elite-x-expiry

/usr/local/bin/elite-x-backup 2>/dev/null || true

ensure_key_files

echo "╔════════════════════════════════════╗"
echo " ELITE-X V3.5 INSTALLED SUCCESSFULLY "
echo "╠════════════════════════════════════╣"
echo "   Advanced • Secure • Ultra Fast    "
echo "╚════════════════════════════════════╝"
EXPIRY_INFO=$(cat /etc/elite-x/expiry 2>/dev/null || echo "Lifetime")
FINAL_MTU=$(cat /etc/elite-x/mtu 2>/dev/null || echo "1800")
ACTIVATION_KEY=$(cat /etc/elite-x/key 2>/dev/null || echo "ELITEX-2026-DAN-4D-08")
echo "DOMAIN  : ${TDOMAIN}"
echo "LOCATION: ${SELECTED_LOCATION}"
echo "MTU     : ${FINAL_MTU}"
echo "KEY     : ${ACTIVATION_KEY}"
echo "EXPIRE  : ${EXPIRY_INFO}"
echo "╚════════════════════════════════════╝"
show_quote

echo -e "\n${CYAN}Final Service Status:${NC}"
sleep 2
systemctl is-active dnstt-elite-x >/dev/null 2>&1 && echo -e "${GREEN}✅ DNSTT Server: Running${NC}" || echo -e "${RED}❌ DNSTT Server: Failed${NC}"
systemctl is-active dnstt-elite-x-proxy >/dev/null 2>&1 && echo -e "${GREEN}✅ DNSTT Proxy: Running${NC}" || echo -e "${RED}❌ DNSTT Proxy: Failed${NC}"
systemctl is-active elite-x-traffic >/dev/null 2>&1 && echo -e "${GREEN}✅ Traffic Monitor: Running${NC}" || echo -e "${RED}❌ Traffic Monitor: Failed${NC}"
systemctl is-active elite-x-cleaner >/dev/null 2>&1 && echo -e "${GREEN}✅ Auto Cleaner: Running${NC}" || echo -e "${RED}❌ Auto Cleaner: Failed${NC}"
systemctl is-active elite-x-bandwidth >/dev/null 2>&1 && echo -e "${GREEN}✅ Bandwidth Monitor: Running${NC}" || echo -e "${RED}❌ Bandwidth Monitor: Failed${NC}"
systemctl is-active elite-x-monitor >/dev/null 2>&1 && echo -e "${GREEN}✅ Connection Monitor: Running${NC}" || echo -e "${YELLOW}⚠️ Connection Monitor: Optional${NC}"

echo -e "\n${CYAN}Port Status:${NC}"
ss -uln | grep -q ":53 " && echo -e "${GREEN}✅ Port 53: Listening${NC}" || echo -e "${RED}❌ Port 53: Not listening${NC}"
ss -uln | grep -q ":${DNSTT_PORT} " && echo -e "${GREEN}✅ Port ${DNSTT_PORT}: Listening${NC}" || echo -e "${RED}❌ Port ${DNSTT_PORT}: Not listening${NC}"

echo -e "\n${GREEN}ELITE-X v3.5 Features:${NC}"
echo -e "  ${YELLOW}→${NC} User Login Limit (Max concurrent connections)"
echo -e "  ${YELLOW}→${NC} Renew User Option"
echo -e "  ${YELLOW}→${NC} Advanced Traffic Monitoring with History"
echo -e "  ${YELLOW}→${NC} Bandwidth Speed Test Tool"
echo -e "  ${YELLOW}→${NC} Auto Backup System"
echo -e "  ${YELLOW}→${NC} System Optimizer (Turbo Mode)"
echo -e "  ${YELLOW}→${NC} Real-time Connection Monitor"
echo -e "  ${YELLOW}→${NC} User Details with Traffic History"
echo -e "  ${YELLOW}→${NC} Multiple User Delete"
echo -e "  ${YELLOW}→${NC} Export Users List"
echo -e "  ${YELLOW}→${NC} Complete Uninstall (removes all users & data)"

read -p "Open menu now? (y/n): " open
if [ "$open" = "y" ]; then
    echo -e "${GREEN}Opening dashboard...${NC}"
    sleep 1
    /usr/local/bin/elite-x
else
    echo -e "${YELLOW}You can type 'menu' or 'elite-x' anytime to open the dashboard.${NC}"
    echo -e "${YELLOW}Other commands: speed, monitor, test-speed, optimize${NC}"
fi

self_destruct
