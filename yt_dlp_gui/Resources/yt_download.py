#
//  script.py
//  yt_dlp_gui
//
//  Created by Richard on 4/9/2025.
//


#!/usr/bin/env python3
import subprocess
import sys
import os

if len(sys.argv) < 2:
    print("Usage: yt_download.py <YouTube URL>")
    sys.exit(1)

url = sys.argv[1]

# Paths
cookies_dir = os.path.expanduser("~/.stacher")
cookies_file = os.path.join(cookies_dir, "yt-cookies/cookies.txt")
os.makedirs(os.path.dirname(cookies_file), exist_ok=True)

output_dir = os.path.expanduser("~/Downloads/%(title)s.%(ext)s")

# Format chain
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

# yt-dlp command
cmd = [
    "yt-dlp",
    url,
    "--cookies", cookies_file,
    "--output", output_dir,
    "--format", format_chain,
    "--remux-video", "mp4",
    "--abort-on-error",
    "--progress-template", "{title} [{percent}%] ETA: {eta} seconds\r"
]

# Run yt-dlp
try:
    process = subprocess.run(cmd, check=True)
    sys.exit(process.returncode)
except subprocess.CalledProcessError as e:
    print(f"Download failed with exit code {e.returncode}")
    sys.exit(e.returncode)
