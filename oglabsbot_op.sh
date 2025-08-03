#!/bin/bash

echo "===== OG Labs Telegram Bot Setup ====="

# ১. ইউজার থেকে BOT NAME নিবে
read -p "Enter your BOT NAME (e.g. OGLABS2(GCP1)): " BOT_NAME

# ২. BOT TOKEN নিবে
read -p "Enter your BOT TOKEN: " BOT_TOKEN

# ৩. CHAT ID নিবে
read -p "Enter your CHAT ID: " CHAT_ID

echo ""
echo "Updating system & installing dependencies..."
sudo apt update -y
sudo apt install -y python3 python3-pip python3-venv jq curl

VENV_DIR="$HOME/oglabs-venv"

if [ ! -d "$VENV_DIR" ]; then
  echo "Creating Python virtual environment..."
  python3 -m venv "$VENV_DIR"
fi

echo "Activating virtual environment..."
source "$VENV_DIR/bin/activate"

echo "Upgrading pip and installing required Python packages..."
pip install --upgrade pip
pip install python-telegram-bot

SCRIPT_PATH="$HOME/oglabs2_status_bot.py"
echo "Writing bot script to $SCRIPT_PATH..."

cat > "$SCRIPT_PATH" << EOF
import time
import subprocess
import asyncio
from telegram import Bot
from telegram.constants import ParseMode

BOT_TOKEN = "${BOT_TOKEN}"
CHAT_ID = "${CHAT_ID}"
BOT_NAME = "${BOT_NAME}"
bot = Bot(token=BOT_TOKEN)

def get_status():
    try:
        response = subprocess.check_output([
            "curl", "-s", "-X", "POST", "http://localhost:5678",
            "-H", "Content-Type: application/json",
            "-d", '{"jsonrpc":"2.0","method":"zgs_getStatus","params":[],"id":1}'
        ]).decode("utf-8")

        logSyncHeight = subprocess.check_output(
            f"echo '{response}' | jq '.result.logSyncHeight'", shell=True
        ).decode("utf-8").strip()

        connectedPeers = subprocess.check_output(
            f"echo '{response}' | jq '.result.connectedPeers'", shell=True
        ).decode("utf-8").strip()

        total = subprocess.check_output("df --output=size / | tail -1", shell=True).decode().strip()
        used = subprocess.check_output("df --output=used / | tail -1", shell=True).decode().strip()
        avail = subprocess.check_output("df --output=avail / | tail -1", shell=True).decode().strip()

        total_gb = int(total) // 1024 // 1024
        used_gb = int(used) // 1024 // 1024
        avail_gb = int(avail) // 1024 // 1024

        return logSyncHeight, connectedPeers, used_gb, avail_gb, total_gb

    except Exception as e:
        return None, f"❌ Error: {str(e)}", 0, 0, 0

async def send_status():
    logSyncHeight, connectedPeers, used, avail, total = get_status()

    if logSyncHeight is None:
        message = f"🧱 *[{BOT_NAME}]* Status Fetch Error\\n{connectedPeers}"
    else:
        message = (
            f"📡 *{BOT_NAME} Node Status*\\n\\n"
            f"🔸 `logSyncHeight:` {logSyncHeight}\\n"
            f"🔸 `connectedPeers:` {connectedPeers}\\n\\n"
            f"💽 *VPS Storage Info:*\\n"
            f"▪️ Used: `{used} GB`\\n"
            f"▪️ Available: `{avail} GB`\\n"
            f"▪️ Total: `{total} GB`\\n\\n"
            f"🕒 Update: {time.strftime('%Y-%m-%d %H:%M:%S')}"
        )

    try:
        await bot.send_message(chat_id=CHAT_ID, text=message, parse_mode=ParseMode.MARKDOWN)
        print("✅ Message sent.")
    except Exception as e:
        print(f"❌ Telegram error: {e}")

async def main_loop():
    while True:
        await send_status()
        await asyncio.sleep(600)

if __name__ == "__main__":
    asyncio.run(main_loop())
EOF

echo "Starting your Telegram bot..."
python3 "$SCRIPT_PATH"

