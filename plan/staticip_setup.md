# Static IP Setup - Macvlan Approach (No Router Access)

**Context:** Starlink Mini (no router access), frequent reboots (hourly), need persistent IP for mobile users

**Current State:** ✅ **SOLVED** - Macvlan configured with static IP `10.182.80.100`

**Decision:** Using **Macvlan only** - Avahi removed due to incompatibility with macvlan containers

---

## **Approach 1: Docker Macvlan Network (RECOMMENDED)**
**Complexity:** ⭐⭐ Moderate | **Persistent:** YES | **No Router Access Needed**

### How it works
- Container gets its own IP on Starlink's network (e.g., 10.237.73.150)
- Appears as a separate device on the network, like a phone or laptop
- IP doesn't change when host IP changes
- Bypasses host networking entirely

### Implementation

```yaml
# docker-compose.yml
networks:
  macvlan-net:
    driver: macvlan
    driver_opts:
      parent: enx26baeba75e55  # Your network interface
    ipam:
      config:
        - subnet: 10.237.73.0/24
          gateway: 10.237.73.193
          ip_range: 10.237.73.150/32  # Pick unused IP in your range

services:
  nextcloud:
    networks:
      macvlan-net:
        ipv4_address: 10.237.73.150
    ports:
      - "8090:80"  # Remove this - macvlan doesn't need port mapping
```

### Steps
1. Test unused IP: `ping 10.237.73.150` (should fail/timeout = good)
2. Backup current docker-compose.yml
3. Update docker-compose.yml with macvlan network config
4. Update TRUSTED_DOMAINS in .env to include new IP
5. Run `docker compose down && docker compose up -d`
6. Test access: `curl http://10.237.73.150:8090`
7. Share IP with mobile users: `http://10.237.73.150:8090`

### Workaround for Host Access
Since macvlan prevents host → container communication, create a bridge:
```bash
sudo ip link add macvlan-shim link enx26baeba75e55 type macvlan mode bridge
sudo ip addr add 10.237.73.151/32 dev macvlan-shim
sudo ip link set macvlan-shim up
sudo ip route add 10.237.73.150/32 dev macvlan-shim
```

### Pros
- ✅ True static IP independent of host
- ✅ Survives reboots
- ✅ No router configuration needed
- ✅ Container appears as separate device

### Cons
- ❌ Host cannot directly access container (needs bridge workaround)
- ❌ Requires unused IP in subnet
- ❌ May not work on all cloud/VM environments

### Source
- Official docs: https://docs.docker.com/engine/network/drivers/macvlan/
- Tutorial: https://www.danielketel.com/the-ultimate-2024-docker-vlan-guide-and-tutorial-youll-ever-need/

---

## **~~Approach 2: Avahi mDNS + Hostname~~** ❌ **REMOVED**

**Status:** ❌ **Not Compatible with Macvlan**

### Why Removed
- **Technical Limitation**: Avahi can only advertise the **host machine's** IP address
- **Macvlan Conflict**: Nextcloud container has its **own IP** (10.182.80.100) separate from host
- **Result**: `hostname.local` would resolve to host IP, not container IP → doesn't work
- **Alternative**: Using static IP `10.182.80.100` directly is simpler and more reliable

### What We Learned
- Avahi is great for **host-based services** (services running directly on the host)
- Avahi **does not work** for containers with their own IP addresses (macvlan, ipvlan)
- For macvlan containers, **static IP is the best solution**

### If You Need Hostnames
For hostname-based access with macvlan, you would need:
1. **DNS Server** (Pi-hole, dnsmasq) - network-wide custom DNS entries, OR
2. **DuckDNS** - external dynamic DNS service, OR
3. **Hosts file** - manual entry on each device (`/etc/hosts`)

**Recommendation**: Just use the static IP - it's only 17 characters and never changes!

---

## **Approach 3: Dynamic DNS (DuckDNS/No-IP) + Auto-Update**
**Complexity:** ⭐⭐⭐ Moderate | **Persistent:** YES (domain name)

### How it works
- Free subdomain (e.g., `mycloud.duckdns.org`)
- Container automatically updates DNS when IP changes
- Access via persistent domain name
- Works from anywhere (local network + internet)

### Implementation

```yaml
# docker-compose.yml
services:
  duckdns:
    image: lscr.io/linuxserver/duckdns:latest
    container_name: duckdns
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Africa/Abidjan
      - SUBDOMAINS=mycloud  # Your chosen subdomain
      - TOKEN=your-duckdns-token-here
      - UPDATE_IP=auto
      - LOG_FILE=false
    restart: unless-stopped

  nextcloud:
    # existing config
    environment:
      - NEXTCLOUD_TRUSTED_DOMAINS=mycloud.duckdns.org,mycloud.duckdns.org:8090
```

### Steps
1. Register at https://www.duckdns.org (free, no credit card)
2. Login with Google/GitHub/etc
3. Create subdomain (e.g., `mycloud`)
4. Copy your token
5. Add DuckDNS container to docker-compose.yml
6. Update TRUSTED_DOMAINS in .env
7. Deploy: `docker compose up -d`
8. Test: `curl http://mycloud.duckdns.org:8090`
9. Share with users: `http://mycloud.duckdns.org:8090`

### Monitoring
```bash
# Check DuckDNS container logs
docker logs duckdns

# Verify DNS resolution
nslookup mycloud.duckdns.org
dig mycloud.duckdns.org
```

### Pros
- ✅ Works from anywhere (not just local network)
- ✅ Free forever
- ✅ Automatic IP updates (every 5 minutes)
- ✅ Easy to remember domain name
- ✅ No router configuration needed

### Cons
- ❌ Requires internet to resolve DNS
- ❌ 5-minute delay on IP updates
- ❌ External dependency (DuckDNS service)
- ❌ Public DNS record (anyone can resolve)

### Alternatives
- No-IP: https://www.noip.com (free tier available)
- FreeDNS: https://freedns.afraid.org

### Source
- DuckDNS: https://www.duckdns.org
- Container: https://hub.docker.com/r/linuxserver/duckdns

---

## **Approach 4: Pi-hole DNS Server + Auto-Update Script**
**Complexity:** ⭐⭐⭐⭐ Advanced | **Persistent:** YES (custom domain)

### How it works
- Run Pi-hole DNS server in Docker
- Maps custom domain (e.g., `nextcloud.home`) to current IP
- Script automatically updates DNS when IP changes
- Mobile devices manually configured to use Pi-hole DNS
- Bonus: Ad-blocking for entire network

### Implementation

```yaml
# docker-compose.yml
services:
  pihole:
    image: pihole/pihole:latest
    container_name: pihole
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "8080:80"  # Pi-hole admin interface
    environment:
      - TZ=Africa/Abidjan
      - WEBPASSWORD=admin123
      - ServerIP=10.237.73.37  # Your current host IP
    volumes:
      - ./pihole/config:/etc/pihole
      - ./pihole/dnsmasq:/etc/dnsmasq.d
    restart: unless-stopped

  dns-updater:
    image: alpine:latest
    container_name: dns-updater
    volumes:
      - ./scripts:/scripts
      - ./pihole/config:/pihole-config
    command: sh -c "apk add --no-cache bash curl && while true; do /scripts/update-pihole-dns.sh; sleep 300; done"
    restart: unless-stopped
```

```bash
# scripts/update-pihole-dns.sh
#!/bin/bash

# Get current IP
CURRENT_IP=$(ip addr show enx26baeba75e55 | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

# Pi-hole API (or edit /etc/pihole/custom.list)
echo "$CURRENT_IP nextcloud.home" > /pihole-config/custom.list

# Restart Pi-hole DNS
docker exec pihole pihole restartdns
```

### Steps
1. Deploy Pi-hole container
2. Access admin: `http://10.237.73.37:8080/admin`
3. Add local DNS record: `nextcloud.home` → auto-detected IP
4. Deploy DNS updater script
5. Configure mobile devices:
   - iOS: Settings → WiFi → DNS → Manual → Add 10.237.73.37
   - Android: Settings → Network → DNS → Custom DNS → 10.237.73.37
6. Test: `nslookup nextcloud.home 10.237.73.37`
7. Access: `http://nextcloud.home:8090`

### Pros
- ✅ Full control over DNS
- ✅ Custom domain names (.home, .local, etc)
- ✅ Ad-blocking for all devices
- ✅ Query logging and analytics
- ✅ No external dependencies

### Cons
- ❌ Complex setup
- ❌ Requires manual DNS configuration on each device
- ❌ Single point of failure (if Pi-hole down, no DNS)
- ❌ Host IP must be relatively stable for DNS server access
- ❌ Doesn't work on cellular (only WiFi configured with Pi-hole DNS)

### Source
- Pi-hole: https://pi-hole.net
- Docker Hub: https://hub.docker.com/r/pihole/pihole

---

## **Approach 5: Tailscale VPN (Zero-Trust Mesh Network)**
**Complexity:** ⭐⭐⭐⭐ Advanced | **Persistent:** YES (VPN)

### How it works
- Install Tailscale on host and mobile devices
- Creates encrypted private mesh VPN
- Each device gets persistent Tailscale IP (100.x.x.x)
- Access from anywhere (home, cellular, other WiFi)
- Zero configuration, NAT traversal automatic

### Implementation

```bash
# 1. Install Tailscale on host
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# 2. Enable subnet routing (expose Docker network)
sudo tailscale up --advertise-routes=172.20.0.0/16

# 3. Or expose specific port
sudo tailscale serve --bg http://localhost:8090

# 4. Get Tailscale IP
tailscale ip -4  # e.g., 100.101.102.103
```

```yaml
# docker-compose.yml - Update TRUSTED_DOMAINS
services:
  nextcloud:
    environment:
      - NEXTCLOUD_TRUSTED_DOMAINS=100.101.102.103,100.101.102.103:8090
```

### Steps
1. Create Tailscale account at https://tailscale.com (free tier: 1 user, 20 devices)
2. Install Tailscale on host server
3. Run `sudo tailscale up`
4. Note your Tailscale IP (100.x.x.x)
5. Install Tailscale app on mobile devices
6. Login to same account
7. Update TRUSTED_DOMAINS with Tailscale IP
8. Access from anywhere: `http://100.101.102.103:8090`

### Mobile Setup
**iOS:**
1. Install Tailscale from App Store
2. Login with same account
3. Connect to Tailscale network
4. Access: `http://100.x.x.x:8090`

**Android:**
1. Install Tailscale from Play Store
2. Login with same account
3. Connect to Tailscale network
4. Access: `http://100.x.x.x:8090`

### Pros
- ✅ Works anywhere (cellular, any WiFi, roaming)
- ✅ Encrypted end-to-end
- ✅ Persistent Tailscale IP (never changes)
- ✅ No port forwarding needed
- ✅ Automatic NAT traversal
- ✅ Works with Starlink CGNAT
- ✅ Free tier available

### Cons
- ❌ Learning curve
- ❌ Requires Tailscale app on all devices
- ❌ External service dependency
- ❌ Free tier limited (1 user, 20 devices)
- ❌ Requires Tailscale account

### Advanced Features
- MagicDNS: Use hostnames instead of IPs
- Exit nodes: Route all traffic through server
- ACLs: Fine-grained access control

### Source
- Tailscale: https://tailscale.com
- Docs: https://tailscale.com/kb/1247/funnel-serve-use-cases

---

## **Comparison Matrix**

| Approach | Persistent | Internet Access | Setup Time | Router Access | Learning Curve | Recommended For |
|----------|-----------|----------------|------------|---------------|----------------|-----------------|
| 1. Macvlan | ✅ Yes | ❌ No | 15 min | ❌ Not needed | Medium | Best for local network static IP |
| 2. Avahi mDNS | ✅ Yes (hostname) | ❌ No | 20 min | ❌ Not needed | Medium | Best for easy-to-remember hostnames |
| 3. DuckDNS | ✅ Yes | ✅ Yes | 10 min | ❌ Not needed | Low | Best for simplicity + internet access |
| 4. Pi-hole | ✅ Yes | ❌ No | 45 min | ❌ Not needed | High | Best for advanced users + ad-blocking |
| 5. Tailscale | ✅ Yes | ✅ Yes | 30 min | ❌ Not needed | Medium-High | Best for remote access + security |

---

## **Recommended Implementation Strategy**

### **Phase 1: Quick Win (Choose One)**
**Option A: Macvlan (Local Network)**
- Best if users only access from same network
- Provides true static IP
- 15 minutes to implement

**Option B: DuckDNS (Internet + Local)**
- Best if users might access remotely
- Works from anywhere
- 10 minutes to implement

### **Phase 2: Enhancement (Optional)**
**Add Avahi mDNS on top**
- Provides friendly hostname alongside IP/domain
- Users can choose: IP, domain, or hostname
- 20 minutes additional

### **Phase 3: Advanced (Future)**
**Tailscale for Remote Access**
- Add when users need secure remote access
- Keeps existing local setup
- 30 minutes to add

---

## **Implementation Priority for Your Use Case**

Given your constraints:
- ✅ No router access (Starlink Mini)
- ✅ Frequent reboots (hourly)
- ✅ Mobile users need consistent access

### **Best Combo: Macvlan + Avahi mDNS**

**Why this combo:**
1. **Macvlan** provides true static IP (10.237.73.150) that never changes
2. **Avahi** provides friendly hostname (nextcloud.local) for easier access
3. Users can choose either method
4. Both survive reboots
5. No router configuration required
6. Total setup time: ~30 minutes

**User Access Options:**
- `http://10.237.73.150:8090` (static IP)
- `http://nextcloud.local:8090` (hostname)

**Fallback: DuckDNS**
If Macvlan has issues with Starlink's CGNAT:
- Provides persistent domain name
- Automatically updates on IP changes
- Works from internet too (bonus)

---

## **Next Steps**

1. Choose approach based on requirements
2. Test in development first (if possible)
3. Backup current configuration
4. Implement chosen solution
5. Update mobile setup documentation
6. Test from mobile devices
7. Document access URLs for users

---

**Created:** 2025-10-01
**Author:** Claude Code
**Status:** Planning Phase
