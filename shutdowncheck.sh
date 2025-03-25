#!/bin/sh

# ATXRaspi/MightyHat interrupt based shutdown/reboot script
# Script by Felix Rusu

set -eu

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

f2nsec() {
  case "${1?}" in
    *.*.*)
      echo 1>&2 "Not a valid decimal number: ${1}"
      return 1
      ;;
    *.*)
      __f2nsec_whole="${1%%.*}"
      __f2nsec_fractional="${1#*.}"

      __f2nsec_exp="${#__f2nsec_fractional}"
      __f2nsec_scale=1

      while [ "$__f2nsec_exp" -gt 0 ]; do
        __f2nsec_scale="$(( __f2nsec_scale * 10 ))"
        __f2nsec_exp="$(( __f2nsec_exp - 1 ))"
      done

      echo "$(( (__f2nsec_whole * 1000000000) + ((__f2nsec_fractional * 1000000000) / __f2nsec_scale) ))"
      ;;
    *)
      echo "$(( "$1" * 1000000000 ))"
      ;;
  esac
}

ATX_RASPI_PULSE_MIN="${ATX_RASPI_PULSE_MIN:-0.2}"
ATX_RASPI_PULSE_MAX="${ATX_RASPI_PULSE_MAX:-0.6}"

REBOOTPULSEMINIMUM="$(f2nsec "$ATX_RASPI_PULSE_MIN")" #reboot pulse signal should be at least this long
REBOOTPULSEMAXIMUM="$(f2nsec "$ATX_RASPI_PULSE_MAX")" #reboot pulse signal should be at most this long

#This is GPIO 7 (pin 26 on the pinout diagram).
#This is an input from ATXRaspi to the Pi.
#When button is held for ~3 seconds, this pin will become HIGH signaling to this script to poweroff the Pi.
SHUTDOWN="${ATX_RASPI_SHUTDOWN_PIN:-7}"

#Added reboot feature (with ATXRaspi R2.6 (or ATXRaspi 2.5 with blue dot on chip)
#Hold ATXRaspi button for at least 500ms but no more than 2000ms and a reboot HIGH pulse of 500ms length will be issued
#This is GPIO 8 (pin 24 on the pinout diagram).
#This is an output from Pi to ATXRaspi and signals that the Pi has booted.
#This pin is asserted HIGH as soon as this script runs (by writing "1" to /sys/class/gpio/gpio8/value)
BOOT="${ATX_RASPI_BOOT_PIN:-8}"

CHIP="${ATX_RASPI_CHIP:-/dev/gpiochip0}"

failed=''

if [ "$REBOOTPULSEMINIMUM" -le 0 ]; then
  failed="${failed:+"${failed}, "}ATX_RASPI_PULSE_MIN (${ATX_RASPI_PULSE_MIN}) must be greater than 0"
fi

if [ "$REBOOTPULSEMAXIMUM" -le "$REBOOTPULSEMINIMUM" ]; then
  failed="${failed:+"${failed}, "}ATX_RASPI_PULSE_MAX (${ATX_RASPI_PULSE_MAX}) must be greater than ATX_RASPI_PULSE_MIN (${ATX_RASPI_PULSE_MIN})"
fi

if [ "$SHUTDOWN" -lt 0 ]; then
  failed="${failed:+"${failed}, "}ATX_RASPI_SHUTDOWN_PIN (${SHUTDOWN}) must be greater than 0"
fi

if [ "$BOOT" -lt 0 ]; then
  failed="${failed:+"${failed}, "}ATX_RASPI_BOOT_PIN (${BOOT}) must be greater than 0"
fi

if [ "$SHUTDOWN" -eq "$BOOT" ]; then
  failed="${failed:+"${failed}, "}ATX_RASPI_SHUTDOWN_PIN (${SHUTDOWN}) must be distinct from ATX_RASPI_BOOT_PIN (${BOOT})"
fi

if [ -n "${failed:-}" ]; then
  echo 1>&2 "ERROR: $failed"
  exit 1
fi

if [ -n "${ATX_RASPI_DRY_RUN:-}" ]; then
  handle_press() {
    echo "[dry-run] $*"
  }
else
  handle_press() {
    "$@"
  }
fi

if { command -v gpioset && command -v gpiomon ; } 1>/dev/null 2>&1; then
  init_shutdown_pin() {
    # NOP
    :
  }

  init_boot_pin() {
    gpioset -z -b pull-up -t 0 -c "${CHIP?}" "${BOOT?}=1"
  }

  watch_shutdown_pin() {
    gpiomon -c "${CHIP?}" -F '%e %S' "${SHUTDOWN?}" | while read -r event seconds; do
      case "$event" in
        # Rising
        1)
          pulseStart="$(f2nsec "$seconds")"
          ;;
        # Falling
        2)
          pulseEnd="$(f2nsec "$seconds")"
          pulseStart="${pulseStart:-"$pulseEnd"}"
          pulseDuration="$(( pulseEnd - pulseStart ))"

          if [ "$pulseDuration" -gt "$REBOOTPULSEMAXIMUM" ]; then
            header 12 "SHUTDOWN request on chip ${CHIP?} from GPIO${SHUTDOWN}, halting Rpi ..."
            handle_press poweroff
            return
          elif [ "$pulseDuration" -gt "$REBOOTPULSEMINIMUM" ]; then
            header 12 "REBOOT request on chip ${CHIP?} from GPIO${SHUTDOWN?}, recycling Rpi ..."
            handle_press reboot
            return
          else
            unset pulseStart pulseEnd
          fi
          ;;
        *)
          echo 1>&2 "WARNING: unrecognized event '${event}' on chip ${CHIP?} for GPIO${SHUTDOWN?}; ignoring."
          ;;
      esac
    done
  }
elif [ -e /sys/class/gpio/export ]; then
  init_shutdown_pin() {
    echo "${SHUTDOWN?}" > /sys/class/gpio/export
    echo in > "/sys/class/gpio/gpio${SHUTDOWN?}/direction"
  }

  init_boot_pin() {
    echo "${BOOT?}" > /sys/class/gpio/export
    echo out > "/sys/class/gpio/gpio${BOOT?}/direction"
    echo 1 > "/sys/class/gpio/gpio${BOOT?}/value"
  }

  watch_shutdown_pin() {
    #This loop continuously checks if the shutdown button was pressed on
    #ATXRaspi (GPIO7 to become HIGH), and issues a shutdown when that happens.
    #It sleeps as long as that has not happened.
    while true; do
      shutdownSignal=$(cat /sys/class/gpio/gpio$SHUTDOWN/value)
      if [ "$shutdownSignal" = 0 ]; then
        sleep 0.2
      else
        pulseStart="$(date +%s%N)" # mark the time when Shutoff signal went HIGH (milliseconds since epoch)
        while [ "$shutdownSignal" = 1 ]; do
          sleep 0.02
          if [ "$(( "$(date +%s%N)" - pulseStart ))" -gt "$REBOOTPULSEMAXIMUM" ]; then
            header 12 "SHUTDOWN request from GPIO${SHUTDOWN}, halting Rpi ..."
            handle_press poweroff
            return
          fi
          shutdownSignal=$(cat /sys/class/gpio/gpio$SHUTDOWN/value)
        done
        #pulse went LOW, check if it was long enough, and trigger reboot
        if [ "$(( "$(date +%s%N)" - pulseStart ))" -gt "$REBOOTPULSEMINIMUM" ]; then
          header 12 "REBOOT request from GPIO${SHUTDOWN}, recycling Rpi ..."
          handle_press reboot
          return
        fi
      fi
    done
  }
else
  # shellcheck disable=SC2016
  echo 1>&2 'FATAL: missing `libgpiod` tools (`gpioset`, `gpiomon`), and legacy sysfs GPIO interface is unavailable; terminating.'
  exit 1
fi

init_shutdown_pin
init_boot_pin

header 3 \
   "ATXRaspi shutdown POLLING script started: asserted pins ($SHUTDOWN=input,LOW; $BOOT=output,HIGH)" \
   "Waiting for GPIO$SHUTDOWN to become HIGH (short HIGH pulse=REBOOT, long pulse HIGH=SHUTDOWN)..."

watch_shutdown_pin
