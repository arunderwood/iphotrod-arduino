monitor:
	platformio device monitor -p /dev/serial0

flash:
	platformio run -t upload

flash-verbose:
	platformio run -v -t upload
