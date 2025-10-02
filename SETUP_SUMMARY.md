# Kekeli-HomeCloud Setup Summary

**Date Configured**: October 2, 2025
**Status**: ✅ Production Ready

---

## 🎯 Your Nextcloud Access Information

### Primary Access Method

**Static IP Access** (Direct and Reliable)
   - URL: `http://10.182.80.100`
   - ✅ Works from: Any device on your Starlink network
   - ✅ Survives: Reboots, Starlink network changes
   - ✅ Never changes: Same URL always works
   - 📱 Tell family to bookmark this URL!

### Login Credentials
- **Username**: `admin` (from .env: ADMIN_USER)
- **Password**: `adminpassword` (from .env: ADMIN_PASSWORD)
- ⚠️ **Important**: Change password after first login!

---

## 📁 External Storage

Your external drive is mounted and accessible:
- **Host Path**: `/media/kelib/DATA`
- **Container Path**: `/external-data`
- **Contains**: BlackMythWukong, Fortnite, church files, admin folder, etc.

**To access in Nextcloud**:
1. Login to Nextcloud web interface
2. Go to: Apps → Files → External Storage app (enable if needed)
3. Add external storage pointing to `/external-data`
4. Your files will now be accessible from any device!

---

## 🐳 Docker Container Status

```bash
# Check if containers are running
docker ps

# Expected output:
# kekeli-nextcloud-app     (healthy)
# kekeli-nextcloud-db      (healthy)
# kekeli-nextcloud-redis   (healthy)
```

### Manage Containers

```bash
# Start containers
docker compose up -d

# Stop containers
docker compose down

# View logs
docker logs kekeli-nextcloud-app
docker logs kekeli-nextcloud-db

# Restart if needed
docker compose restart
```

---

## 🌐 Network Configuration

### Current Starlink Network
- **Interface**: `enx1e6b5ef945c2`
- **Subnet**: `10.182.80.0/24`
- **Gateway**: `10.182.80.237`
- **Your Host IP**: `10.182.80.231` (DHCP)

### Container IPs (Macvlan - Static)
- **Nextcloud**: `10.182.80.100` ⭐ Main access point
- **PostgreSQL**: `10.182.80.98` (internal)
- **Redis**: `10.182.80.99` (internal)

### Accessing from Host Machine

⚠️ **Macvlan Limitation**: Your host PC cannot directly access the macvlan IP without a shim interface.

**To enable host → container access**, run these commands:

```bash
sudo ip link add macvlan-shim link enx1e6b5ef945c2 type macvlan mode bridge
sudo ip addr add 10.182.80.101/32 dev macvlan-shim
sudo ip link set macvlan-shim up
sudo ip route add 10.182.80.100/32 dev macvlan-shim
```

**Then access via**: `http://10.182.80.100` from your host machine

**Alternative**: Use WiFi or another device on the network (works without shim)

---

## 📱 Mobile Device Setup

### For Family Members

**iPhone/iPad:**
1. Download "Nextcloud" app from App Store
2. Enter server: `http://10.182.80.100`
3. Login with username and password
4. Done! Files sync automatically

**Android:**
1. Download "Nextcloud" from Google Play
2. Enter server: `http://10.182.80.100`
3. Login with username and password
4. Enable auto-upload for photos if desired

**Web Browser (Any Device):**
1. Bookmark: `http://10.182.80.100`
2. This IP won't change even after Starlink reboots
3. Easy to access from any browser

---

## 🔧 Configuration Files

### Key Files
- **Docker Compose**: `/home/kelib/Desktop/projects/kekeli-homelab/docker-compose.yml`
- **Environment**: `/home/kelib/Desktop/projects/kekeli-homelab/.env`
- **Activity Log**: `/home/kelib/Desktop/projects/kekeli-homelab/plan/ACTIVITIES.md`

### Important .env Settings
```bash
HOST_IP=10.182.80.100
NEXTCLOUD_HTTP_PORT=80
PRIMARY_DOMAIN=10.182.80.100
MOBILE_URL=http://10.182.80.100

MACVLAN_ENABLED=true
MACVLAN_PARENT_INTERFACE=enx1e6b5ef945c2
MACVLAN_CONTAINER_IP=10.182.80.100

AVAHI_ENABLED=false  # Removed - incompatible with macvlan
AVAHI_HOSTNAME=
```

---

## ⚡ What Happens During Starlink Reboots?

### Container IPs (Macvlan) ✅ STAY THE SAME
- `10.182.80.100` → Nextcloud (static, won't change)
- `10.182.80.98` → PostgreSQL (static)
- `10.182.80.99` → Redis (static)

### Host IP (DHCP) ⚠️ MAY CHANGE
- Your PC's IP: `10.182.80.231` (currently)
- This is assigned by Starlink DHCP
- Not a problem - containers use their own static IPs!

### What Your Family Notices
- **Nothing!** They keep using `http://10.182.80.100` or `http://kelib-PC.local`
- Access continues to work seamlessly

---

## 🛠️ Troubleshooting

### Containers not starting
```bash
# Check logs
docker compose logs

# Restart Docker daemon
sudo systemctl restart docker

# Recreate containers
docker compose down
docker compose up -d
```

### Cannot access from other devices
1. Check firewall: `sudo ufw status`
2. Verify Starlink interface: `ip addr show enx1e6b5ef945c2`
3. Ping container: `ping 10.182.80.100` (from another device)
4. Check container is running: `docker ps`

### External storage not showing
```bash
# Verify mount inside container
docker exec kekeli-nextcloud-app ls -la /external-data

# Check host mount
ls -la /media/kelib/DATA
```

### Need hostname access?
**Note**: Avahi was removed as it's incompatible with macvlan containers.

**Options**:
1. **Use the static IP**: `http://10.182.80.100` (recommended - simple and reliable)
2. **Set up DNS server**: Pi-hole or dnsmasq for network-wide custom hostnames
3. **Add hosts file entry**: On individual devices for custom names

---

## 📦 Installed Apps

Your Nextcloud comes with **14 essential apps** pre-installed and configured!

### Productivity Suite
- **Calendar** 📅 - Events, appointments, sync with phones
- **Contacts** 👥 - Address book, sync with phones
- **Tasks** ✅ - To-do lists and project management
- **Mail** ✉️ - Email client

### Collaboration Tools
- **Deck** 🎯 - Kanban project boards
- **Notes** 📝 - Simple note-taking
- **Talk** 💬 - Video/voice calls and chat

### Media Apps
- **Photos** 🖼️ - Photo gallery
- **Memories** 🎞️ - Beautiful timeline photo browser
- **Music** 🎵 - Music player and library

### File Management
- **Group Folders** 👨‍👩‍👧‍👦 - Shared team/family folders
- **External Storage** 📁 - Already configured with your external drive!

### Office & Security
- **Collabora** 📄 - Edit Word/Excel/PowerPoint files
- **Text** 📋 - Markdown editor
- **Passwords** 🔑 - Password manager
- **End-to-End Encryption** 🔐 - Encrypt sensitive files

**Documentation**: See `INSTALLED_APPS.md` and `QUICK_START_FAMILY_GUIDE.md` for detailed guides!

---

## 🎯 Next Steps

1. **✅ Access Nextcloud**
   - Open browser: `http://10.182.80.100`
   - Login: admin / adminpassword
   - **Change password immediately!**
   - Click grid icon (top right) to see all apps

2. **✅ External Storage Already Configured**
   - Folder: "External Drive"
   - Contains: All files from `/media/kelib/DATA`
   - Accessible to all users

3. **👥 Set Up Family Users**
   - Click profile → Users → "+ New user"
   - Create account for each family member
   - Give them login credentials
   - They should change password on first login

4. **📱 Mobile Apps Setup**
   - Download "Nextcloud" from App Store/Play Store
   - Server: `http://10.182.80.100`
   - Enable auto photo upload:
     - Settings → Auto upload → Enable
     - Never lose photos again!

5. **📅 Setup Shared Calendar**
   - Open Calendar app
   - Create "Family Calendar" or "Church Events"
   - Click share icon → Add family members
   - Everyone can add events!
   - Auto-syncs with phone calendars!

6. **👥 Import Church Contacts**
   - Open Contacts app
   - Import church directory (vCard format)
   - Create groups: Leadership, Youth, Members
   - Auto-syncs with phone contacts!

7. **📸 Browse Your Photos**
   - Open "Memories" app
   - Beautiful timeline view of all photos
   - Create albums for vacations, events
   - Share albums with family

8. **🔗 Share Files**
   - Right-click any file → Share
   - Generate link or share with users
   - Perfect for sharing church documents!

9. **🧪 Test Everything**
   - Try uploading a file
   - Create a calendar event
   - Make a test video call (Talk app)
   - Add a contact
   - Create a note

10. **🔄 Test Reboot Resilience**
    - Note: `http://10.182.80.100`
    - Reboot your Starlink
    - Same URL still works! ✅

---

## 📞 Support

**Project**: Kekeli-HomeCloud Easy Installer
**Documentation**: `/home/kelib/Desktop/projects/kekeli-homelab/plan/`
**Logs**: `docker logs kekeli-nextcloud-app`
**Status**: `docker ps`

---

**Your Nextcloud is ready for your family! 🎉**
