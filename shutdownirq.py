#!/usr/bin/env python

# ATXRaspi/MightyHat interrupt based shutdown/reboot script
# Script by Tony Pottier, Felix Rusu

import os
import sys
import time

# Reboot pulse signal should be at least this long (seconds).
REBOOTPULSEMINIMUM = 0.2

# Reboot pulse signal should be at most this long (seconds).
REBOOTPULSEMAXIMUM = 1.0

# GPIO pin used for shutdown signal.
SHUTDOWN = 7

# GPIO pin used for boot signal.
BOOT = 8

def diag(*msgs):
	linelen = max([len(msg) for msg in msgs]) + 2
	wrapper = "=" * linelen
	print(wrapper)
	for msg in msgs:
		print(" {0}".format(msg))
	print(wrapper)

def announce():
	print()
	diag(
		"ATXRaspi shutdown IRQ script started: asserted pins ({0}=input,LOW; {1}=output,HIGH)".format(SHUTDOWN, BOOT),
		"Waiting for GPIO {0} to become HIGH (short HIGH pulse=REBOOT, long HIGH pulse=SHUTDOWN)...".format(SHUTDOWN),
	)

try:
	import gpiod
	from gpiod.line import Direction, Edge, Value
	have_gpiod = True
except ImportError:
	have_gpiod = False

if have_gpiod:

	CHIP = "/dev/gpiochip0"
	CONSUMER = "atx-raspi"
	CONFIG = {
		SHUTDOWN: gpiod.LineSettings(direction=Direction.INPUT, edge_detection=Edge.BOTH),
		BOOT: gpiod.LineSettings(direction=Direction.OUTPUT, output_value=Value.ACTIVE)
	}

	pulse_start = None

	with gpiod.request_lines(CHIP, consumer=CONSUMER, config=CONFIG) as request:

		announce()

		try:
			while True:
				for event in request.read_edge_events():
					if event.event_type is event.Type.RISING_EDGE:
						pulse_start = time.time()
					elif event.event_type is event.Type.FALLING_EDGE:
						pulse_end = time.time()

						if pulse_start is None:
							pulse_start = pulse_end

						pulse_duration = pulse_end - pulse_start

						if pulse_duration >= REBOOTPULSEMAXIMUM:
							print()
							diag("SHUTDOWN request on chip {0} from GPIO{1}, halting Rpi ...".format(CHIP, SHUTDOWN))
							os.system("poweroff")
							sys.exit()
						elif pulse_duration >= REBOOTPULSEMINIMUM:
							print()
							diag("REBOOT request on chip {0} from GPIO{1}, recycling Rpi ...".format(CHIP, SHUTDOWN))
							os.system("reboot")
							sys.exit()
						else:
							pulse_start = None
							pulse_end = None
		except:
			pass
else:
	import RPi.GPIO as GPIO

	# Set up GPIO 8 and write that the PI has booted up
	GPIO.setup(BOOT, GPIO.OUT, initial=GPIO.HIGH)

	# Set up GPIO 7  as interrupt for the shutdown signal to go HIGH
	GPIO.setup(SHUTDOWN, GPIO.IN, pull_up_down=GPIO.PUD_DOWN)

	announce()

	try:
		while True:
			GPIO.wait_for_edge(SHUTDOWN, GPIO.RISING)
			shutdown_signal = GPIO.input(SHUTDOWN)
			pulse_start = time.time() # register time at which the button was pressed
			while shutdown_signal:
				time.sleep(0.2)
				if(time.time() - pulse_start >= REBOOTPULSEMAXIMUM):
					print()
					diag("SHUTDOWN request from GPIO{0}, halting Rpi ...".format(SHUTDOWN))
					os.system("poweroff")
					sys.exit()
				shutdown_signal = GPIO.input(SHUTDOWN)
			if time.time() - pulse_start >= REBOOTPULSEMINIMUM:
				print()
				diag("REBOOT request from GPIO{0}, recycling Rpi ...".format(SHUTDOWN))
				os.system("reboot")
				sys.exit()
			if GPIO.input(SHUTDOWN): # before looping we must make sure the shutdown signal went low
				GPIO.wait_for_edge(SHUTDOWN, GPIO.FALLING)
	except:
		pass
	finally:
		GPIO.cleanup()
