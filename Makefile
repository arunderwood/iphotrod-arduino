monitor:
	platformio device monitor -p /dev/ttyS0
	
screen-monitor:
	screen /dev/ttyS0 9600

flash:
	platformio run -t upload

flash-verbose:
	platformio run -v -t upload
