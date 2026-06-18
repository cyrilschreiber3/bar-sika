import os
from flask import Flask, render_template
from flask_socketio import SocketIO

socketio = SocketIO()


def create_app(shared_state):
    # Get data directory from environment variable (set by wrapper) or use project root for development
    data_dir = os.environ.get('BAR_SIKA_DATA_DIR', os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))))
    template_dir = os.path.join(data_dir, 'templates')
    static_dir = os.path.join(data_dir, 'static')
    app = Flask(__name__, template_folder=template_dir, static_folder=static_dir)
    # app = Flask(__name__)
    socketio.init_app(app)

    @app.route("/")
    def index():
        sound_info = [
            {"id": sound_id, "name": sound.name}
            for sound_id, sound in shared_state.sounds.items()
        ]
        return render_template("index.html", sounds=sound_info)

    @socketio.on("connect")
    def handle_connect():
        # Send initial status of all sounds when a client connects
        for sound_id, sound in shared_state.sounds.items():
            status = "Playing" if sound.playing else "Stopped"
            socketio.emit("sound_status", {"sound_id": sound_id, "status": status})

    @socketio.on("play_sound")
    def handle_play_sound(data):
        sound_id = data["sound_id"]
        loops = int(data["loops"]) or -1
        if sound_id in shared_state.sounds:
            shared_state.sounds[sound_id].play(loop_count=loops)
            shared_state.sounds[sound_id].web_override = True
            socketio.emit("sound_status", {"sound_id": sound_id, "status": "Playing"})

    @socketio.on("stop_sound")
    def handle_stop_sound(data):
        sound_id = data["sound_id"]
        if sound_id in shared_state.sounds:
            shared_state.sounds[sound_id].stop()
            shared_state.sounds[sound_id].web_override = False
            socketio.emit("sound_status", {"sound_id": sound_id, "status": "Stopped"})

    @socketio.on("enable_buttons")
    def handle_enable_buttons():
        for sound in shared_state.sounds.values():
            sound.button_disable = False
        socketio.emit("button_lock_status", {"status": "Enabled"})

    @socketio.on("disable_buttons")
    def handle_disable_buttons():
        for sound in shared_state.sounds.values():
            sound.button_disable = True
        socketio.emit("button_lock_status", {"status": "Disabled"})

    return app
