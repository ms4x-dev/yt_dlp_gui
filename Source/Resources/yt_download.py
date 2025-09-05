import subprocess
import sys
import os

# Created by Richard on 4/9/2025
#!/usr/bin/env python3

def debug_log(message, success=None):
    prefix = ""
    if success is True:
        prefix = "✅ "
    elif success is False:
        prefix = "❌ "
    print(f"{prefix}{message}")

# --- Read credentials from environment ---
username = os.getenv("YTDLP_USERNAME")
password = os.getenv("YTDLP_PASSWORD")
debug_log(f"Username set: {'Yes' if username else 'No'}")
debug_log(f"Password set: {'Yes' if password else 'No'}")

if len(sys.argv) < 2:
    debug_log("Usage: yt_download.py <YouTube URL>", success=False)
    sys.exit(1)

url = sys.argv[1].strip('"')  # Remove accidental quotes around URL
debug_log(f"URL to download (stripped): {url}")

# --- Project-local paths ---
project_dir = os.path.dirname(os.path.abspath(__file__))  # project root
cookies_dir = os.path.join(project_dir, "yt-cookies")
cookies_file = os.path.join(cookies_dir, "cookies.txt")
os.makedirs(cookies_dir, exist_ok=True)
debug_log(f"Cookies directory ensured at {cookies_dir}")

# Use global Downloads folder
output_dir = os.path.expanduser("~/Downloads/%(title)s.%(ext)s")
os.makedirs(os.path.dirname(output_dir), exist_ok=True)
debug_log(f"Output directory ensured at {output_dir}")

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
    debug_log("Refreshing cookies...")
    try:
        # Example command to refresh cookies - user must customize this as needed.
        # Here we just simulate the command for demonstration.
        # Replace this with actual cookie refresh logic.
        subprocess.run(["/Library/Frameworks/Python.framework/Versions/3.13/bin/yt-dlp", "--cookies-from-browser", "chrome", "--cookies", cookies_file], check=True)
        debug_log("Cookies refreshed successfully.", success=True)
    except subprocess.CalledProcessError as e:
        debug_log(f"Failed to refresh cookies: {e}", success=False)

# Build yt-dlp command
cmd = [
    "/Library/Frameworks/Python.framework/Versions/3.13/bin/yt-dlp",
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
    debug_log("Using credentials for login.")
else:
    # Use cookies as fallback if credentials not provided
    if os.path.isfile(cookies_file):
        cmd += ["--cookies", cookies_file]
        debug_log("Using cookies for login.")
    else:
        debug_log("Warning: No credentials provided and cookies file not found. Download may fail.", success=False)

# Run yt-dlp with robust error handling
try:
    debug_log(f"Executing command: {' '.join(cmd)}")
    process = subprocess.run(cmd, check=True)
    debug_log("Download completed successfully.", success=True)
    sys.exit(process.returncode)
except subprocess.CalledProcessError as e:
    debug_log(f"Download failed with exit code {e.returncode}", success=False)
    debug_log("If you are using cookies, consider refreshing them manually by calling refresh_cookies().", success=False)
    sys.exit(e.returncode)
