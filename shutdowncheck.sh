#!/bin/sh

# ATXRaspi/MightyHat interrupt based shutdown/reboot script
# Script by Felix Rusu

header() {
  if [ "$#" -lt 2 ]; then
    echo 1>&2 'internal error: usage: header <padding> <line> [<line>...]'
    return 64 # EX_USAGE
  fi

  padding="${1:-0}"
  shift

  if [ "$((padding+0))" != "$padding" ]; then
    echo 1>&2 'internal error: padding must be an integer'
    return 64 # EX_USAGE
  fi

  left=''
  while [ "$padding" -gt 0 ]; do
    left="${left} "
    padding="$((padding-1))"
  done

  echo "=========================================================================================="
  for line in "$@"; do
    echo "${left}${line}"
  done
  echo "=========================================================================================="
}

#This is GPIO 7 (pin 26 on the pinout diagram).
#This is an input from ATXRaspi to the Pi.
#When button is held for ~3 seconds, this pin will become HIGH signalling to this script to poweroff the Pi.
SHUTDOWN=7
REBOOTPULSEMINIMUM=200      #reboot pulse signal should be at least this long
REBOOTPULSEMAXIMUM=600      #reboot pulse signal should be at most this long
echo "$SHUTDOWN" > /sys/class/gpio/export
echo "in" > /sys/class/gpio/gpio$SHUTDOWN/direction
#Added reboot feature (with ATXRaspi R2.6 (or ATXRaspi 2.5 with blue dot on chip)
#Hold ATXRaspi button for at least 500ms but no more than 2000ms and a reboot HIGH pulse of 500ms length will be issued
#This is GPIO 8 (pin 24 on the pinout diagram).
#This is an output from Pi to ATXRaspi and signals that the Pi has booted.
#This pin is asserted HIGH as soon as this script runs (by writing "1" to /sys/class/gpio/gpio8/value)
BOOT=8
echo "$BOOT" > /sys/class/gpio/export
echo "out" > /sys/class/gpio/gpio$BOOT/direction
echo "1" > /sys/class/gpio/gpio$BOOT/value

header 3 \
   "ATXRaspi shutdown POLLING script started: asserted pins ($SHUTDOWN=input,LOW; $BOOT=output,HIGH)" \
   "Waiting for GPIO$SHUTDOWN to become HIGH (short HIGH pulse=REBOOT, long HIGH=SHUTDOWN)..."

#This loop continuously checks if the shutdown button was pressed on ATXRaspi (GPIO7 to become HIGH), and issues a shutdown when that happens.
#It sleeps as long as that has not happened.
while true; do
  shutdownSignal=$(cat /sys/class/gpio/gpio$SHUTDOWN/value)
  if [ "$shutdownSignal" = 0 ]; then
    sleep 0.2
  else
    pulseStart=$(date +%s%N | cut -b1-13) # mark the time when Shutoff signal went HIGH (milliseconds since epoch)
    while [ "$shutdownSignal" = 1 ]; do
      sleep 0.02
      if [ $(($(date +%s%N | cut -b1-13)-pulseStart)) -gt $REBOOTPULSEMAXIMUM ]; then
        header 12 "SHUTDOWN request from GPIO${SHUTDOWN}, halting Rpi ..."
        poweroff
        exit
      fi
      shutdownSignal=$(cat /sys/class/gpio/gpio$SHUTDOWN/value)
    done
    #pulse went LOW, check if it was long enough, and trigger reboot
    if [ $(($(date +%s%N | cut -b1-13)-pulseStart)) -gt $REBOOTPULSEMINIMUM ]; then
      header 12 "REBOOT request from GPIO${SHUTDOWN}, recycling Rpi ..."
      reboot
      exit
    fi
  fi
done
