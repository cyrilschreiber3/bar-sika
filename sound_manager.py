from pygame import mixer
from gpiozero import Button

class SoundManager:
    def __init__(self, gpio_pin, sound_file, name=None):
        self.button = Button(gpio_pin)
        self.sound = mixer.Sound(sound_file)
        self.name = name or sound_file.split("/")[-1]
        self.playing = False
        self.web_override = False
        self.button_disable = False
        
    def check_button(self):
        if self.button.is_pressed and not self.web_override and not self.button_disable:
            self.play()
        elif not self.button.is_pressed and not self.web_override and not self.button_disable:
            self.stop()

        self.playing = mixer.get_busy() and self.sound.get_num_channels() > 0
    
    def play(self, loop_count=-1):
        if not self.playing:
            self.sound.play(loops=loop_count)
            self.playing = True
    
    def stop(self):
        if self.playing:
            self.sound.stop()
            self.playing = False

    def close(self):
        self.stop()
        self.button.close()