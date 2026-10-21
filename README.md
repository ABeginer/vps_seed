# Hermes Agent — Windows VPS Seed Repository

A turnkey bootstrap package to provision and launch the official **Hermes Agent** natively on any new **Windows VPS** with DeepSeek LLM inference, Discord Gateway integration, and Supabase task synchronization in a single command.

---

## 🚀 Quickstart for a New Windows VPS

### Step 1: Copy or Clone this Repository
Download or clone this repository to any folder on your new VPS (e.g. `C:\hermes_vps`):
```powershell
git clone <YOUR_REPO_URL> C:\hermes_vps
cd C:\hermes_vps
```

### Step 2: Configure Environment Variables
Copy `.env.example` to `.env`:
```powershell
Copy-Item .env.example .env
notepad .env
```
Fill in your secrets:
- `DEEPSEEK_API_KEY`: Your DeepSeek API key (`sk-...`).
- `DISCORD_BOT_TOKEN`: Your Discord Bot token (make sure **Message Content Intent** is enabled in the [Discord Developer Portal](https://discord.com/developers/applications)).
- `DISCORD_USER_ID`: Your Discord User ID (for the owner allowlist).
- `SUPABASE_SECRET_KEY`: Your Supabase Service Role / Secret Key (`sb_secret_...`).

### Step 3: Run the Seed Script
In PowerShell (Run as Administrator recommended):
```powershell
.\seed.ps1
```

The script automatically:
1. Installs the official Hermes Agent CLI if missing.
2. Permanently registers Hermes binary paths in User `$env:PATH`.
3. Configures the DeepSeek AI provider (`https://api.deepseek.com`, `deepseek-chat`).
4. Installs the Supabase Python SDK and deploys pre-packaged skills.
5. Sets persistent Windows User environment variables (`SUPABASE_URL`, `SUPABASE_SECRET_KEY`).
6. Configures the Discord gateway credentials.

### Step 4: Start the Discord Daemon
```powershell
# Interactively allowlist your user ID and verify intents (first time only)
hermes gateway setup

# Start the background daemon
hermes gateway start

# Check real-time connection status
hermes gateway status
```

---

## 📁 Repository Structure

```
hermes_vps/
├── .env.example              # Centralized secrets template
├── seed.ps1                  # 1-command Windows VPS bootstrap script
├── skills/                   # Pre-packaged custom agent skills
│   └── supabase_tasks/
│       ├── SKILL.md          # Skill manifest and CLI instructions for Hermes
│       └── tasks_client.py   # CLI bridge tool for Supabase table operations
└── README.md                 # This quickstart documentation
```

---

## 🛠️ How Hermes Interacts with Supabase

Once Hermes is online on Discord, you can mention the bot to assign or request task updates. Hermes uses its pre-installed `supabase_tasks` skill:

- **List pending tasks**:
  ```bash
  python "$HOME\.hermes\skills\supabase_tasks\tasks_client.py" --action list --status pending
  ```
- **Claim & Complete tasks**:
  ```bash
  python "$HOME\.hermes\skills\supabase_tasks\tasks_client.py" --action update --task-id <ID> --status completed --output "Task summary report"
  ```
- **Insert new task**:
  ```bash
  python "$HOME\.hermes\skills\supabase_tasks\tasks_client.py" --action insert --title "<Title>" --description "<Details>" --status pending
  ```

---

## 🔍 Useful Hermes CLI Commands

- `hermes doctor`: Runs diagnostic health checks on CLI, tools, Python, and gateway.
- `hermes gateway logs`: Streams live Discord messaging gateway logs.
- `hermes gateway stop`: Halts the background Discord bot daemon.
- `hermes config list`: Displays current provider and model configurations.
