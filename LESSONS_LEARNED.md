# Lessons Learned - Kekeli-HomeCloud Project

**Date**: October 2, 2025

---

## ❌ **What Didn't Work: Avahi mDNS with Macvlan**

### The Problem
Initially planned to use **Avahi mDNS** to provide easy hostname access (`nextcloud.local` or `kelib-PC.local`) alongside macvlan static IP.

### Why It Failed
1. **Technical Limitation**: Avahi can only advertise the **host machine's IP address**
2. **Macvlan Architecture**: Container has its **own separate IP** (10.182.80.100) on the network
3. **Incompatibility**: When you access `kelib-PC.local`, it resolves to the **host IP**, not the **container IP**
4. **Result**: `http://kelib-PC.local` points to wrong machine, doesn't reach Nextcloud

### What We Tried
- ✅ Installed and configured Avahi daemon
- ✅ Set up deny-interfaces for Docker networks
- ✅ Enabled address publishing
- ❌ Could not make Avahi advertise container's macvlan IP (architectural limitation)

### The Learning
**Avahi is designed for host-based services, not containerized services with their own IP addresses.**

For containers with macvlan/ipvlan networks:
- Avahi **will not work** for hostname resolution
- Static IP is the **correct solution**
- Alternative: DNS server (Pi-hole, dnsmasq) or DuckDNS

---

## ✅ **What Worked: Macvlan Static IP**

### The Solution
Using Docker **macvlan** network to give the Nextcloud container its own static IP.

### Why It Works
1. **Container Independence**: Container gets its own IP (10.182.80.100) on the Starlink network
2. **Survives Reboots**: IP is static, doesn't change when Starlink reboots or reconnects
3. **Direct Access**: Devices on the network can access directly without host interference
4. **Simple**: Just tell family to bookmark `http://10.182.80.100`

### Configuration
```yaml
networks:
  macvlan-net:
    driver: macvlan
    driver_opts:
      parent: enx1e6b5ef945c2  # Starlink interface
    ipam:
      config:
        - subnet: 10.182.80.0/24
          gateway: 10.182.80.237
          ip_range: 10.182.80.100/32

services:
  nextcloud:
    networks:
      macvlan-net:
        ipv4_address: 10.182.80.100
```

### Advantages
- ✅ **Persistent IP**: Never changes, survives all reboots
- ✅ **Simple to share**: Just one URL to remember
- ✅ **No router config needed**: Works without router access
- ✅ **Starlink-proof**: Adapts to network interface changes automatically

### Limitations
- Host machine needs macvlan shim to access container (one-time setup)
- Requires unused IP in the subnet range

---

## 🎓 **Key Takeaways**

### Network Architecture Understanding
1. **Macvlan vs Bridge Networks**:
   - Bridge: Containers share host IP with port mapping
   - Macvlan: Containers get their own IP on the network

2. **mDNS/Avahi Limitations**:
   - Only works for services on the same IP as the host
   - Cannot advertise for other IPs on the network
   - Great for: Host-based services, VMs, physical machines
   - Not for: Macvlan/ipvlan containers

3. **Host-Container Communication with Macvlan**:
   - By design, host cannot directly talk to macvlan containers
   - Solution: Macvlan shim interface (creates a bridge)

### Starlink Network Characteristics
- **Dynamic Interface Names**: `enxXXXXXXXXXXXX` format changes
- **Subnet Changes**: Network can change from 10.237.73.0/24 to 10.182.80.0/24
- **Frequent Reboots**: Starlink Mini reboots hourly
- **DHCP Gateway**: Changes between reboots (10.237.73.193 → 10.182.80.237)

### Docker Networking Best Practices
1. **For Persistent Access**:
   - Macvlan for containers needing static IPs
   - Update .env dynamically to match current network
   - Don't hardcode IPs in docker-compose.yml (use variables)

2. **For Easy Access**:
   - Static IP is simpler than hostname for macvlan
   - DNS server (Pi-hole) if you need network-wide custom names
   - DuckDNS for external access with persistent domain

---

## 📝 **Decision Log**

### Decision 1: Use Macvlan Over Bridge
**Date**: October 2, 2025
**Reason**: Need persistent IP independent of host DHCP changes
**Result**: ✅ Success - Container IP stays stable across Starlink changes

### Decision 2: Remove Avahi from Architecture
**Date**: October 2, 2025
**Reason**: Avahi cannot advertise macvlan container IPs (technical limitation)
**Alternative**: Using static IP directly - simpler and more reliable
**Result**: ✅ Cleaner architecture, easier to maintain

### Decision 3: Starlink Interface as Macvlan Parent
**Date**: October 2, 2025
**Reason**: Primary internet connection, most stable for family access
**Alternative Considered**: WiFi interface (192.168.1.x)
**Result**: ✅ Works well, survives Starlink-specific network changes

---

## 🔧 **Technical Debt Resolved**

### Issue 1: HOST_IP Format
- **Problem**: HOST_IP had port included (`192.168.1.98:8090`)
- **Fix**: Removed port, HOST_IP should be IP only
- **Impact**: Cleaner configuration, proper variable separation

### Issue 2: Hardcoded IPs in docker-compose.yml
- **Problem**: Container IPs hardcoded from old network
- **Fix**: Updated to match current Starlink network
- **Future**: Should use environment variables for all IPs

### Issue 3: Double Slash in Volume Mount
- **Problem**: `/media/kelib/DATA` mounted as `//media/kelib/DATA`
- **Fix**: Removed extra slash
- **Impact**: External storage now mounts correctly

---

## 💡 **Future Improvements**

### For Script Automation
1. **Dynamic Network Detection**:
   - Auto-detect Starlink network changes
   - Update macvlan configuration automatically
   - Regenerate docker-compose.yml with current subnet

2. **Validation Before Deployment**:
   - Check if macvlan IP is available (ping test)
   - Verify gateway is reachable
   - Test container connectivity before marking setup complete

3. **Simplified User Flow**:
   - Prompt for static IP setup BEFORE network configuration
   - Validate HOST_IP format (reject if it has port)
   - Auto-create macvlan shim for host access

### For Documentation
1. **Clear Warnings**:
   - Document Avahi limitations with macvlan upfront
   - Explain when to use each networking mode

2. **Troubleshooting**:
   - Add section on Starlink-specific network detection
   - Document how to recover from network subnet changes

---

## ✅ **Final Working Configuration**

### What's Deployed
- **Nextcloud**: http://10.182.80.100 (macvlan static IP)
- **Database**: PostgreSQL on 10.182.80.98 (internal macvlan)
- **Cache**: Redis on 10.182.80.99 (internal macvlan)
- **Storage**: External drive at `/media/kelib/DATA` mounted as `/external-data`

### Family Access
**URL**: `http://10.182.80.100`
- Works from all devices on Starlink network
- Survives reboots and network changes
- No complicated hostname setup needed
- Just 17 characters - easy to type or bookmark

### Success Metrics
- ✅ Static IP persists across reboots
- ✅ Survives Starlink network changes
- ✅ External storage accessible
- ✅ All containers healthy
- ✅ Mobile devices can connect
- ✅ Simple enough for non-technical family

---

## 🎯 **Conclusion**

**Macvlan-only approach is the right solution for this use case.**

Avahi would have been nice for "ease of use" but the technical reality is:
- It doesn't work with macvlan containers
- Static IP is actually simpler (just one URL)
- More reliable than hostname-based access
- No additional dependencies or services needed

**Recommendation for future similar projects**:
Start with the simplest solution that works. Static IPs are easier than hostnames when dealing with containerized services on their own network.
