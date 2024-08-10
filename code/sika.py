#! /usr/bin/python3

import pygame
from gpiozero import Button
import time
import os

button = Button(26)
pygame.mixer.init()
pygame.mixer.music.load("/home/cyril/sika/sika4.wav")
pygame.mixer.music.set_volume(1)
os.system("amixer sset Headphone 100%")


while True:
	if button.is_pressed:
		if not pygame.mixer.music.get_busy():
			pygame.mixer.music.play(loops=-1)
	else:
		if pygame.mixer.music.get_busy():
			pygame.mixer.music.stop()

	time.sleep(0.1)
