# Nextcloud Apps - Complete Setup Tutorial

**For**: Kekeli-HomeCloud Users
**Difficulty**: Beginner-friendly
**Time**: 30 minutes for full setup

---

## 📋 **Table of Contents**

1. [First Time Login & Password Change](#first-time-login)
2. [Creating Family User Accounts](#creating-users)
3. [Setting Up Calendar](#calendar-setup)
4. [Setting Up Contacts](#contacts-setup)
5. [Setting Up Mobile Auto Photo Upload](#photo-upload)
6. [Using Memories for Photos](#memories-setup)
7. [Setting Up Talk for Video Calls](#talk-setup)
8. [Using Deck for Project Management](#deck-setup)
9. [Setting Up Password Manager](#password-manager)
10. [Setting Up Group Folders](#group-folders)
11. [Sharing Files & Folders](#file-sharing)
12. [Desktop Sync Client Setup](#desktop-client)

---

<a name="first-time-login"></a>
## 1️⃣ **First Time Login & Password Change**

### Access Nextcloud
1. Open any web browser (Chrome, Firefox, Safari, Edge)
2. Go to: **`http://10.182.80.100`**
3. You'll see the Nextcloud login page

### Login
- **Username**: `admin`
- **Password**: `adminpassword`
- Click "Log in"

### Change Password (IMPORTANT!)
1. Click your profile picture/icon (top right corner)
2. Click **"Settings"**
3. In left menu, click **"Security"**
4. Under "Password", enter:
   - Current password: `adminpassword`
   - New password: (choose a strong password)
   - Confirm new password
5. Click **"Change password"**

✅ **Done!** Your account is now secure.

---

<a name="creating-users"></a>
## 2️⃣ **Creating Family User Accounts**

Don't let everyone use the admin account! Create separate accounts for each family member.

### Create a New User
1. Click profile icon (top right) → **"Users"**
2. At the top, you'll see **"New user"**
3. Fill in the form:
   - **Username**: `firstname` (e.g., `sarah`, `john`)
   - **Display name**: `Full Name` (e.g., `Sarah Johnson`)
   - **Password**: Create temporary password (user will change it)
   - **Email** (optional): User's email address
   - **Groups** (optional): Add to `users` group or create custom groups
4. Click **"Add new user"** or press Enter

### Repeat for Each Family Member
Create accounts for:
- All family members
- Church leaders (if sharing with church)
- Any regular users

### Example Users
- `pastor` - Pastor John
- `sarah` - Sarah (youth leader)
- `mom` - Mom
- `dad` - Dad
- `kids` - Shared kids account

### Give Users Their Credentials
Tell each person:
1. Go to: `http://10.182.80.100`
2. Login with username and temporary password
3. **Change password immediately** (Settings → Security)

✅ **Done!** Each family member has their own account.

---

<a name="calendar-setup"></a>
## 3️⃣ **Setting Up Calendar**

### Access Calendar App
1. Top navigation bar → Click **"Calendar"**
2. You'll see a monthly calendar view

### Create a Shared Family Calendar
1. In left sidebar, click **"+ New calendar"**
2. Name it: `Family Calendar` (or `Church Events`)
3. Choose a color
4. Click Create

### Share the Calendar
1. Hover over the calendar name in left sidebar
2. Click the **three dots (⋮)** that appear
3. Click **"Share link"** or **"Share with users"**

**Option A: Share with specific users**
4. Start typing family member's name
5. Select their name from dropdown
6. Choose permissions:
   - **Can edit** - They can add/edit events
   - **Can view** - They can only see events
7. Click Share

**Option B: Share link (for external sharing)**
4. Click "Share link"
5. Copy the link
6. Send via WhatsApp/email to family
7. They can subscribe to calendar in their phone

### Add an Event
1. Click any day on the calendar
2. Enter event title (e.g., "Church Service")
3. Set time (optional)
4. Add location (optional)
5. Add description (optional)
6. Click **"Create"**

### Set Recurring Events
1. Create an event
2. Click the event to edit
3. Click **"Repeat"** dropdown
4. Choose frequency:
   - Weekly (e.g., Sunday service)
   - Monthly (e.g., Board meeting)
   - Custom pattern
5. Save

### Mobile Calendar Sync
**On iPhone/iPad:**
1. Open Nextcloud app
2. Go to Settings → Auto upload calendars
3. Enable calendar sync
4. Events appear in native Calendar app!

**On Android:**
1. Install "DAVx⁵" from Play Store (free)
2. Add account → Nextcloud
3. Server: `http://10.182.80.100`
4. Login with credentials
5. Select calendars to sync
6. Done! Events sync with Google Calendar

✅ **Done!** Shared calendar working on all devices.

---

<a name="contacts-setup"></a>
## 4️⃣ **Setting Up Contacts**

### Access Contacts App
1. Top navigation → Click **"Contacts"**

### Add a Contact Manually
1. Click **"+ New contact"** (bottom right)
2. Fill in details:
   - Name
   - Phone number(s)
   - Email
   - Address
   - Organization (e.g., church name)
   - Notes
3. Click outside to save automatically

### Create Contact Groups
Perfect for organizing church members!

1. In left sidebar, click **"+ New group"**
2. Name it (e.g., `Church Leadership`, `Youth Group`, `Family`)
3. Drag contacts into the group

### Import Existing Contacts
**From CSV/vCard file:**
1. Click the three dots (⋮) in top right
2. Click **"Import"**
3. Select your file (.vcf or .csv)
4. Map fields if needed
5. Click Import

**From Phone:**
- Export contacts from phone to vCard
- Email file to yourself
- Download and import to Nextcloud

### Share Contacts (Church Directory)
1. Right-click a contact or group
2. Click **"Share"**
3. Add users who should have access
4. Set permissions (can edit or view only)

### Mobile Contacts Sync
**On iPhone/iPad:**
1. Settings → Passwords & Accounts → Add Account
2. Select "Other" → Add CardDAV Account
3. Server: `10.182.80.100/remote.php/dav`
4. Username: your username
5. Password: your password
6. Done! Contacts sync automatically

**On Android:**
1. Use DAVx⁵ app (same as calendar setup)
2. Enable contacts sync
3. Syncs with phone contacts app

✅ **Done!** Church directory on all phones!

---

<a name="photo-upload"></a>
## 5️⃣ **Setting Up Mobile Auto Photo Upload**

Never lose photos again! Automatic backup from your phone.

### On iPhone/iPad
1. Install **"Nextcloud"** app from App Store
2. Open app → Connect to: `http://10.182.80.100`
3. Login with your credentials
4. Tap **Settings** (bottom tab)
5. Tap **"Auto upload"**
6. Enable **"Auto upload"**
7. Configure settings:
   - **Upload folder**: Select where to upload (default: `InstantUpload`)
   - **Which albums**: Camera Roll (recommended)
   - **When to upload**: WiFi only (recommended to save data)
   - **Upload videos**: Enable if you want videos backed up too
8. Done!

### On Android
1. Install **"Nextcloud"** app from Play Store
2. Open app → Server: `http://10.182.80.100`
3. Login with credentials
4. Tap menu (☰) → **Settings**
5. Tap **"Auto upload"**
6. Enable for:
   - **Camera** (photos)
   - **Screenshots** (optional)
   - **Videos** (optional)
7. Configure upload behavior:
   - **On charging only**: Recommended
   - **On WiFi only**: Recommended
8. Done!

### What Happens Now?
- Every photo you take automatically uploads
- Uploads happen when charging + WiFi (saves battery/data)
- Photos appear in `Files` → `InstantUpload` folder
- Accessible from any device!
- Original quality preserved

✅ **Done!** Photos auto-backup from phone!

---

<a name="memories-setup"></a>
## 6️⃣ **Using Memories for Photos**

Memories is like Google Photos - beautiful timeline view!

### Access Memories
1. Click grid icon (top right) → **"Memories"**
2. You'll see a beautiful timeline of all your photos

### Browse Timeline
- **Scroll** to browse photos by date
- **Click a photo** to view full size
- **Swipe left/right** to navigate
- Photos organized automatically by date taken

### Create Albums
1. Select multiple photos (click checkboxes)
2. Click **"+"** icon
3. Select **"Add to album"**
4. Choose existing album or create new
5. Name album (e.g., `Summer Vacation 2025`)
6. Done!

### Share an Album
1. Open the album
2. Click share icon
3. Options:
   - **Share with users**: Select family members
   - **Share link**: Generate link for anyone
4. Copy link and send via WhatsApp/email

### View "On This Day" Memories
- Memories automatically shows photos from same day in previous years
- Great for nostalgia!
- Appears in timeline view

### Face Recognition (Optional)
1. Settings → Administration → Memories
2. Enable face recognition
3. Nextcloud will group photos by faces
4. Name faces to organize by person

✅ **Done!** Beautiful photo browsing experience!

---

<a name="talk-setup"></a>
## 7️⃣ **Setting Up Talk for Video Calls**

Free video calls for family/church meetings!

### Access Talk
1. Grid icon → **"Talk"**

### Create a Conversation
1. Click **"+ New conversation"**
2. Choose type:
   - **Group conversation**: Multiple people
   - **One-to-one**: Private chat
   - **Public**: Anyone with link can join
3. Name the conversation (e.g., `Family Chat`, `Church Leaders`)
4. Add participants (start typing names)
5. Click **"Create conversation"**

### Start a Video Call
1. Open a conversation
2. Click the **video camera icon** (top right)
3. Allow browser to access camera/microphone
4. Wait for others to join
5. Video call starts!

### Start an Audio Call
1. Open conversation
2. Click **phone icon** (top right)
3. Audio-only call (uses less bandwidth)

### Screen Sharing
During a call:
1. Click **screen icon**
2. Choose window/screen to share
3. Great for presentations!

### Chat Messages
1. Type message at bottom
2. Press Enter to send
3. **@mention** someone: Type `@name`
4. Share files: Click **paperclip icon**

### Mobile Talk
1. Install "Nextcloud Talk" app (separate from main app)
2. Or use main Nextcloud app → Talk section
3. Make calls from phone
4. Receive notifications for new messages

### Create Public Meeting Room
Perfect for church services or meetings!

1. Create conversation
2. Choose **"Public"**
3. Copy share link
4. Send link to participants
5. Anyone with link can join (no account needed!)

✅ **Done!** Free video calling system!

---

<a name="deck-setup"></a>
## 8️⃣ **Using Deck for Project Management**

Kanban-style boards for organizing projects!

### Access Deck
1. Grid icon → **"Deck"**

### Create a Board
1. Click **"+ Add board"**
2. Name it (e.g., `Church Easter Event`, `Home Renovation`)
3. Choose color
4. Click Create

### Add Lists (Columns)
Typical setup:
1. Click **"+ Add list"** on the board
2. Create columns:
   - **To Do** - Tasks not started
   - **In Progress** - Currently working on
   - **Done** - Completed tasks
3. Name each list and save

### Add Cards (Tasks)
1. In any list, click **"+ Add card"**
2. Enter task title (e.g., `Book venue`)
3. Press Enter to create
4. Click card to edit details:
   - **Description**: Details about task
   - **Due date**: When it's due
   - **Assign to**: Who's responsible
   - **Labels**: Color-code tasks
   - **Checklist**: Sub-tasks
   - **Attachments**: Add files

### Move Cards Between Lists
1. Drag and drop cards between lists
2. Move to "In Progress" when starting
3. Move to "Done" when complete

### Share Board with Team
1. Click board settings (⋮)
2. Click **"Share"**
3. Add team members
4. They can now view/edit cards

### Example: Church Event Planning
**Board**: Easter Sunday Service

**Lists**:
- To Do
- In Progress
- Done

**Cards in "To Do"**:
- [ ] Book guest speaker
- [ ] Order flowers for decoration
- [ ] Prepare worship songs
- [ ] Print programs
- [ ] Setup sound system

**Assign tasks** to different people and track progress!

✅ **Done!** Visual project management!

---

<a name="password-manager"></a>
## 9️⃣ **Setting Up Password Manager**

Store all passwords securely!

### Access Passwords
1. Grid icon → **"Passwords"**

### Add a Password
1. Click **"+"** (bottom right)
2. Fill in details:
   - **Name**: Website/service name (e.g., `Gmail`)
   - **Username**: Your username/email
   - **Password**: The password (or click 🔄 to generate)
   - **URL**: Website URL (optional)
   - **Notes**: Any additional info
3. Click **"Save"**

### Generate Strong Password
1. When adding password, click **🔄 icon**
2. Auto-generates secure password
3. Copy and use it for the website
4. Password saved in Nextcloud

### Organize with Folders
1. Click **"+ New folder"**
2. Name it (e.g., `Banking`, `Social Media`, `Church`)
3. Drag passwords into folders

### Share Passwords (Family Accounts)
Perfect for Netflix, WiFi, etc.!

1. Click a password entry
2. Click **Share icon**
3. Add family members
4. They can now see the password
5. Great for shared accounts!

### Browser Extension (Optional)
1. Install Nextcloud Passwords extension
2. Connect to your server
3. Auto-fill passwords on websites!

### Access from Phone
1. Main Nextcloud app → Passwords section
2. Or install dedicated "Nextcloud Passwords" app
3. Copy passwords when needed

✅ **Done!** All passwords secure and accessible!

---

<a name="group-folders"></a>
## 🔟 **Setting Up Group Folders**

Shared folders for family/church teams.

### Create Group Folder (Admin Only)
1. Settings → Administration → **"Group folders"**
2. Click **"+ New folder"**
3. Name it (e.g., `Church Documents`, `Family Photos`)
4. Set quota (storage limit) if needed
5. Click Create

### Add Groups to Folder
1. Click the folder name
2. Under "Groups", click **"+ Add group"**
3. Select group (e.g., `Church Leadership`)
4. Set permissions:
   - ✅ Read
   - ✅ Write (can upload/edit)
   - ✅ Share (can share files)
   - ✅ Delete
5. Repeat for other groups with different permissions

### Example Setup
**Folder**: Church Documents
- **Church Leadership** → Full access (read, write, share, delete)
- **Church Members** → Read only

**Folder**: Family Photos
- **Family** group → Full access

### Access Group Folder
Users see group folders in their Files app automatically!

1. Files app → See folder in main view
2. Upload/download like any folder
3. Changes sync for everyone

✅ **Done!** Team collaboration folders ready!

---

<a name="file-sharing"></a>
## 1️⃣1️⃣ **Sharing Files & Folders**

### Share a File/Folder
1. In **Files** app, find the file/folder
2. Click the **share icon** (person +) next to it
3. Choose sharing method:

**Method 1: Share with Nextcloud users**
4. Start typing user's name
5. Select user from dropdown
6. Set permissions:
   - ✅ Can view
   - ✅ Can edit
   - ✅ Can reshare
7. Click Share

**Method 2: Share link (for anyone)**
4. Click **"+ Share link"**
5. Copy the link
6. Options:
   - **Password protect**: Add password for security
   - **Set expiration**: Auto-delete link after date
   - **Allow upload**: Let others upload to folder
   - **Hide download**: Prevent downloading
7. Send link via WhatsApp/email

### Share Multiple Files
1. Select multiple files (checkboxes)
2. Click **Actions** → **Share**
3. Creates a shared folder with all files

### Unshare
1. Click share icon on shared item
2. Click **"×"** next to user's name
3. Click trash icon next to share link
4. Sharing removed

### Example Uses
- **Church bulletins**: Share link for members to download
- **Family photos**: Share folder with all family
- **Documents**: Share with specific people for collaboration

✅ **Done!** Easy file sharing!

---

<a name="desktop-client"></a>
## 1️⃣2️⃣ **Desktop Sync Client Setup**

Automatically sync files between computer and Nextcloud!

### Download Desktop Client
1. Go to: https://nextcloud.com/install/#install-clients
2. Download for your OS:
   - Windows
   - macOS
   - Linux
3. Install the application

### Connect to Your Server
1. Open Nextcloud Desktop app
2. Enter server: `http://10.182.80.100`
3. Login with your credentials
4. Grant access

### Choose Sync Folders
1. Select folders to sync:
   - ✅ Sync everything (simple)
   - Or choose specific folders
2. Choose local folder location on your computer
3. Click **"Connect"**

### How It Works
- Files added to local folder → Auto-upload to Nextcloud
- Files added to Nextcloud → Auto-download to computer
- Works like Dropbox!
- Green checkmarks show synced files

### Pause Syncing
1. Click Nextcloud icon in system tray
2. Click **"Pause sync"**
3. Resume anytime

✅ **Done!** Desktop files auto-sync!

---

## 🎓 **Advanced Tips**

### Enable 2-Factor Authentication
1. Settings → Security → Two-Factor Authentication
2. Choose method (TOTP app like Google Authenticator)
3. Scan QR code
4. Enter verification code
5. Extra security for admin account!

### Setup Email Notifications
1. Settings → Personal → Activity
2. Enable email notifications for:
   - File changes
   - Calendar events
   - Shared files
3. Stay updated on activity

### Customize Theme
1. Settings → Personal → Appearance
2. Choose:
   - Light theme
   - Dark theme
   - Custom colors

### Install More Apps
1. Grid icon → **"Apps"**
2. Browse available apps
3. Click **"Enable"** on any app
4. Categories:
   - Files (more file tools)
   - Social & communication
   - Office & text
   - Games
   - Security

---

## 🆘 **Need Help?**

### Can't Login?
- Check URL: `http://10.182.80.100`
- Check username/password (case-sensitive)
- Admin can reset password in Users section

### App Not Showing?
- Click grid icon (top right)
- All apps listed there
- Scroll to find app

### Files Not Syncing?
- Check internet connection
- Verify auto-upload settings
- Try manual refresh

### Video Call Not Working?
- Allow browser camera/microphone access
- Check your firewall
- Try different browser

---

## 📖 **Documentation Reference**

- **Installed Apps**: `INSTALLED_APPS.md`
- **Quick Start**: `QUICK_START_FAMILY_GUIDE.md`
- **Setup Summary**: `SETUP_SUMMARY.md`
- **External Storage**: `EXTERNAL_STORAGE_SETUP.md`

---

**You're now a Nextcloud expert! 🎉**

Access your cloud: **http://10.182.80.100**
