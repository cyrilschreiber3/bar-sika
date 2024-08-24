print("Importing modules")
import time
import os
import signal
import sys

os.environ["PYGAME_HIDE_SUPPORT_PROMPT"] = "hide"
from pygame import mixer
import threading
from shared_state import shared_state
from sound_manager import SoundManager
from app import create_app, socketio

print("Initializing fan control")
fan_pin = 13  # Change this to the GPIO pin you're using for the fan
GPIO.setmode(GPIO.BCM)
GPIO.setup(fan_pin, GPIO.OUT)
fan_pwm = GPIO.PWM(fan_pin, 100000)  # 100 Hz frequency
fan_pwm.start(0)


print("Loading sounds")
mixer.init()

sound1 = SoundManager(21, "./audio/exports/sika2.wav")
sound2 = SoundManager(20, "./audio/exports/sika3.wav")
sound3 = SoundManager(16, "./audio/exports/sika4.wav")

shared_state.sounds = {"sound1": sound1, "sound2": sound2, "sound3": sound3}


def shutdown(signal, frame):
    global running
    print("Shutting down...")

    # Stop the GPIO checking loop
    running = False
    server_started.set()

    # Stop all sounds
    for sound in shared_state.sounds.values():
        sound.stop()
        sound.close()

    # Quit Pygame
    mixer.quit()

    # Stop the Flask app
    socketio.stop()

    # Exit the program
    sys.exit(0)


def check_gpio():
    global running
    while running:
        for sound in shared_state.sounds.values():
            sound.check_button()
        time.sleep(0.1)


def sync_sound_status():
    global running
    server_started.wait()
    while running:
        time.sleep(5)
        for sound_id, sound in shared_state.sounds.items():
            status = "Playing" if sound.playing else "Stopped"
            socketio.emit("sound_status", {"sound_id": sound_id, "status": status})


print("Starting buttons checking thread")
running = True
server_started = threading.Event()
gpio_thread = threading.Thread(target=check_gpio)
gpio_thread.start()
sync_thread = threading.Thread(target=sync_sound_status)
sync_thread.start()

signal.signal(signal.SIGINT, shutdown)
signal.signal(signal.SIGTERM, shutdown)

print("Starting webserver")
app = create_app(shared_state, fan_pwm)
if __name__ == "__main__":
    socketio.start_background_task(lambda: server_started.set())
    socketio.run(app, host="0.0.0.0", port=5000, allow_unsafe_werkzeug=True)
