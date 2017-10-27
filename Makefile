monitor:
	platformio device monitor -p /dev/ttyAMA0

flash:
	platformio run -t upload
