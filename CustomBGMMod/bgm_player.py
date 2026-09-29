r"""
Hans Custom BGM Player (Background Process)
- Watch directory: H:\steam\steamapps\common\HANS\hwa
- Plays .ogg, .mp3, .wav, .flac files in background
- Monitors game process (Hans-Win64-Shipping.exe) and exits cleanly when game closes
- Listens for IPC commands from Lua via cmd.txt
"""

import os
import sys
import time
import glob
import random
import atexit

# Set current directory to script location
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
os.chdir(SCRIPT_DIR)

HWA_DIR = r"H:\steam\steamapps\common\HANS\hwa"
CMD_FILE = os.path.join(SCRIPT_DIR, "cmd.txt")
PID_FILE = os.path.join(SCRIPT_DIR, "player.pid")
LOG_FILE = os.path.join(SCRIPT_DIR, "bgm_player.log")

SUPPORTED_EXTS = (".ogg", ".mp3", ".wav", ".flac")

def log(msg):
    timestamp = time.strftime("[%Y-%m-%d %H:%M:%S]")
    line = f"{timestamp} {msg}\n"
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line)
    except Exception:
        pass

# Ensure single instance
try:
    if os.path.exists(PID_FILE):
        with open(PID_FILE, "r") as f:
            old_pid = int(f.read().strip())
        import psutil
        if psutil.pid_exists(old_pid):
            log(f"Another instance is already running (PID {old_pid}). Exiting.")
            sys.exit(0)
except Exception:
    pass

try:
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))
except Exception:
    pass

def cleanup():
    try:
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)
        if os.path.exists(CMD_FILE):
            os.remove(CMD_FILE)
    except Exception:
        pass

atexit.register(cleanup)

# 1. Ensure target directory exists
os.makedirs(HWA_DIR, exist_ok=True)
guide_file = os.path.join(HWA_DIR, "여기에_ogg_또는_mp3_음악을_넣으세요.txt")
if not os.path.exists(guide_file):
    try:
        with open(guide_file, "w", encoding="utf-8") as f:
            f.write("이 폴더에 .ogg, .mp3, .wav 음악 파일을 넣으면 게임 실행 시 배경음악(BGM)으로 자동 재생됩니다!\n")
    except Exception:
        pass

# Initialize pygame.mixer
import pygame
try:
    pygame.mixer.pre_init(44100, -16, 2, 2048)
    pygame.mixer.init()
    log("Pygame mixer initialized successfully.")
except Exception as e:
    log(f"Failed to init pygame mixer: {e}")
    sys.exit(1)

def is_game_running():
    import psutil
    target_names = {"hans-win64-shipping.exe", "hans.exe"}
    for p in psutil.process_iter(['name']):
        try:
            name = (p.info['name'] or '').lower()
            if name in target_names:
                return True
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    return False

def scan_tracks():
    tracks = []
    if os.path.isdir(HWA_DIR):
        for entry in os.listdir(HWA_DIR):
            full_path = os.path.join(HWA_DIR, entry)
            if os.path.isfile(full_path):
                ext = os.path.splitext(entry)[1].lower()
                if ext in SUPPORTED_EXTS:
                    tracks.append(full_path)
    tracks.sort()
    return tracks

# Main playback loop
current_tracks = []
track_index = 0
volume = 0.8
pygame.mixer.music.set_volume(volume)
is_paused = False

log(f"Custom BGM Player started. Target directory: {HWA_DIR}")

# Grace period for game startup (15 seconds)
startup_grace = time.time() + 15.0

def play_track(idx):
    global current_tracks, track_index, is_paused
    if not current_tracks:
        return
    track_index = idx % len(current_tracks)
    track_path = current_tracks[track_index]
    try:
        loops = -1 if len(current_tracks) == 1 else 0
        pygame.mixer.music.load(track_path)
        pygame.mixer.music.play(loops=loops)
        is_paused = False
        log(f"Playing track [{track_index + 1}/{len(current_tracks)}]: {os.path.basename(track_path)} (loops={loops})")
    except Exception as e:
        log(f"Failed to play {track_path}: {e}")

while True:
    # 1. Check if game is still running
    if time.time() > startup_grace:
        if not is_game_running():
            log("Game process has terminated. Exiting BGM Player.")
            break

    # 2. Check for tracks
    new_tracks = scan_tracks()
    if new_tracks != current_tracks:
        log(f"Track list updated: {len(new_tracks)} track(s) found.")
        current_tracks = new_tracks
        if current_tracks and not pygame.mixer.music.get_busy() and not is_paused:
            play_track(0)

    # 3. Check for IPC commands from Lua
    if os.path.exists(CMD_FILE):
        try:
            with open(CMD_FILE, "r", encoding="utf-8") as f:
                cmd = f.read().strip().lower()
            os.remove(CMD_FILE)
            log(f"Received command: {cmd}")

            if cmd == "toggle":
                if is_paused:
                    pygame.mixer.music.unpause()
                    is_paused = False
                    log("Music unpaused.")
                else:
                    pygame.mixer.music.pause()
                    is_paused = True
                    log("Music paused.")
            elif cmd == "next":
                if current_tracks:
                    play_track(track_index + 1)
            elif cmd == "prev":
                if current_tracks:
                    play_track(track_index - 1)
            elif cmd == "vol_up":
                volume = min(1.0, round(volume + 0.1, 2))
                pygame.mixer.music.set_volume(volume)
                log(f"Volume increased to {int(volume * 100)}%")
            elif cmd == "vol_down":
                volume = max(0.0, round(volume - 0.1, 2))
                pygame.mixer.music.set_volume(volume)
                log(f"Volume decreased to {int(volume * 100)}%")
            elif cmd == "stop":
                pygame.mixer.music.stop()
                break
        except Exception as e:
            log(f"Command processing error: {e}")

    # 4. Handle track progression when multiple tracks exist
    if not is_paused and current_tracks and len(current_tracks) > 1:
        if not pygame.mixer.music.get_busy():
            # Track finished, proceed to next track
            play_track(track_index + 1)

    time.sleep(0.1)

try:
    pygame.mixer.music.stop()
    pygame.quit()
except Exception:
    pass
