import time
import subprocess
import asyncio
from telegram import Bot
from telegram.constants import ParseMode

BOT_TOKEN = "8176698621:AAHJ-6HBFgT6BdTkd7qfHg6rECMWXd01Ik8"
CHAT_ID = "5039996137"
BOT_NAME = "OGLABS3"
bot = Bot(token=BOT_TOKEN)

def get_status():
    try:
        print("📥 Downloading logs.sh ...")
        logs_script_path = "/tmp/logs.sh"
        subprocess.run(
            ["curl", "-s", "-o", logs_script_path, "https://raw.githubusercontent.com/HustleAirdrops/0G-Storage-Node/main/logs.sh"],
            check=True
        )
        subprocess.run(["chmod", "+x", logs_script_path], check=True)

        print("▶️ Running logs.sh ...")
        block_output = subprocess.check_output(["bash", logs_script_path]).decode("utf-8").strip()
        print("🧱 logs.sh Output:\n", block_output)

        print("⏳ Waiting 5 seconds ...")
        time.sleep(5)

        print("💾 Fetching VPS Storage Info ...")
        total = subprocess.check_output("df --output=size / | tail -1", shell=True).decode().strip()
        used = subprocess.check_output("df --output=used / | tail -1", shell=True).decode().strip()
        avail = subprocess.check_output("df --output=avail / | tail -1", shell=True).decode().strip()

        total_gb = int(total) // 1024 // 1024
        used_gb = int(used) // 1024 // 1024
        avail_gb = int(avail) // 1024 // 1024

        return block_output, used_gb, avail_gb, total_gb

    except Exception as e:
        print(f"❌ Error during get_status: {e}")
        return f"❌ Error: {str(e)}", 0, 0, 0

async def send_status():
    print("🚀 Sending status to Telegram...")
    block_output, used, avail, total = get_status()

    if block_output.startswith("❌"):
        message = f"🧱 *[{BOT_NAME}]* Status Error\n{block_output}"
    else:
        message = (
            f"📡 *{BOT_NAME} Node Status*\n\n"
            f"{block_output}\n\n"
            f"💽 *VPS Storage Info:*\n"
            f"▪️ Used: `{used} GB`\n"
            f"▪️ Available: `{avail} GB`\n"
            f"▪️ Total: `{total} GB`\n\n"
            f"🕒 Update: {time.strftime('%Y-%m-%d %H:%M:%S')}"
        )

    try:
        await bot.send_message(chat_id=CHAT_ID, text=message, parse_mode=ParseMode.MARKDOWN)
        print("✅ Message sent to Telegram.")
    except Exception as e:
        print(f"❌ Telegram send error: {e}")

async def main_loop():
    while True:
        await send_status()
        await asyncio.sleep(600)

if __name__ == "__main__":
    asyncio.run(main_loop())
