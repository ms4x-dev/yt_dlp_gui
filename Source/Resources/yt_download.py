#
//
//
//
//  Created by Richard on 4/9/2025.
//


#!/usr/bin/env python3
import subprocess
import sys
import os

# --- Read credentials from environment ---
username = os.getenv("YTDLP_USERNAME")
password = os.getenv("YTDLP_PASSWORD")

if len(sys.argv) < 2:
    print("Usage: yt_download.py <YouTube URL>")
    sys.exit(1)

url = sys.argv[1]

# --- Project-local paths ---
project_dir = os.path.dirname(os.path.abspath(__file__))  # project root
cookies_dir = os.path.join(project_dir, "yt-cookies")
cookies_file = os.path.join(cookies_dir, "cookies.txt")
os.makedirs(cookies_dir, exist_ok=True)

# Use global Downloads folder
output_dir = os.path.expanduser("~/Downloads/%(title)s.%(ext)s")
os.makedirs(os.path.dirname(output_dir), exist_ok=True)

# Format chain (unchanged)
format_chain = """
bv*[height=2160][vcodec=hevc][hdr=1]+ba[acodec=aac][abr=320k][ext=m4a]/
bv*[height=2160][vcodec=hevc]+ba[acodec=aac][abr=320k][ext=m4a]/
bv*[height=1440][vcodec=hevc][hdr=1]+ba[acodec=aac][abr=320k][ext=m4a]/
bv*[height=1440][vcodec=hevc]+ba[acodec=aac][abr=320k][ext=m4a]/
bv*[height=1080][vcodec=hevc][hdr=1]+ba[acodec=aac][abr=320k][ext=m4a]/
bv*[height=2160][ext=mp4][hdr=1]+ba[acodec=aac][abr=320k][ext=m4a]/
bv*[height=2160][ext=mp4]+ba[acodec=aac][abr=320k][ext=m4a]/
bv*[vcodec=h264]+ba[acodec=aac][abr=320k][ext=m4a]/
bestvideo+bestaudio
""".strip()

def refresh_cookies():
    """
    Manual function to refresh cookies.
    This function should be called by the user to update cookies when needed.
    """
    print("Refreshing cookies...")
    try:
        # Example command to refresh cookies - user must customize this as needed.
        # Here we just simulate the command for demonstration.
        # Replace this with actual cookie refresh logic.
        subprocess.run(["yt-dlp", "--cookies-from-browser", "chrome", "--cookies", cookies_file], check=True)
        print("Cookies refreshed successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Failed to refresh cookies: {e}")

# Build yt-dlp command
cmd = [
    "yt-dlp",
    url,
    "--output", output_dir,
    "--format", format_chain,
    "--remux-video", "mp4",
    "--abort-on-error",
    "--progress-template", "{title} [{percent}%] ETA: {eta} seconds\r"
]

# Primary login via credentials if provided
if username and password:
    cmd += ["--username", username, "--password", password]
else:
    # Use cookies as fallback if credentials not provided
    if os.path.isfile(cookies_file):
        cmd += ["--cookies", cookies_file]
    else:
        print("Warning: No credentials provided and cookies file not found. Download may fail.")

# Run yt-dlp with robust error handling
try:
    process = subprocess.run(cmd, check=True)
    sys.exit(process.returncode)
except subprocess.CalledProcessError as e:
    print(f"Download failed with exit code {e.returncode}")
    print("If you are using cookies, consider refreshing them manually by calling refresh_cookies().")
    sys.exit(e.returncode)
