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
        # logs.sh ফাইল ডাউনলোড করে রান করছে
        logs_script_path = "/tmp/logs.sh"
        subprocess.run(
            ["curl", "-s", "-o", logs_script_path, "https://raw.githubusercontent.com/HustleAirdrops/0G-Storage-Node/main/logs.sh"],
            check=True
        )
        subprocess.run(["chmod", "+x", logs_script_path], check=True)

        # আউটপুট নিচ্ছে
        block_output = subprocess.check_output(["bash", logs_script_path]).decode("utf-8").strip()

        time.sleep(5)

        # VPS Storage info
        total = subprocess.check_output("df --output=size / | tail -1", shell=True).decode().strip()
        used = subprocess.check_output("df --output=used / | tail -1", shell=True).decode().strip()
        avail = subprocess.check_output("df --output=avail / | tail -1", shell=True).decode().strip()

        total_gb = int(total) // 1024 // 1024
        used_gb = int(used) // 1024 // 1024
        avail_gb = int(avail) // 1024 // 1024

        return block_output, used_gb, avail_gb, total_gb

    except Exception as e:
        return f"❌ Error: {str(e)}", 0, 0, 0

async def send_status():
    block_output, used, avail, total = get_status()

    if block_output.startswith("❌"):
        message = f"🧱 *[{BOT_NAME}]* Status Error\\n{block_output}"
    else:
        message = (
            f"📡 *{BOT_NAME} Node Status*\\n\\n"
            f"{block_output}\\n\\n"
            f"💽 *VPS Storage Info:*\\n"
            f"▪️ Used: \`{used} GB\`\\n"
            f"▪️ Available: \`{avail} GB\`\\n"
            f"▪️ Total: \`{total} GB\`\\n\\n"
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
