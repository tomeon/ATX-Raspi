#!/bin/sh

# We provide a fallback in case `EUID` is not set; silence shellcheck violation
# warning that "In POSIX sh, EUID is undefined"
# shellcheck disable=SC3028
if [ "${EUID:-$(id -u 2>/dev/null || :)}" != 0 ]; then
    run_as_root() {
        sudo "$@"
    }
else
    run_as_root() {
        "$@"
    }
fi

OPTION=$(whiptail --title "ATXRaspi/MightyHat shutdown/reboot script setup" --menu "\nChoose your script type option below:\n\n(Note: changes require reboot to take effect)" 15 78 4 \
"1" "Install INTERRUPT based script /etc/shutdownirq.py (recommended)" \
"2" "Install POLLING based script /etc/shutdowncheck.sh (classic)" \
"3" "Disable any existing shutdown script" 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus = 0 ]; then
    run_as_root sed -e '/shutdown/ s/^#*/#/' -i /etc/rc.local

    case "$OPTION" in
        1)
            run_as_root curl -fsSLo /etc/shutdownirq.py https://githubusercontent.com/LowPowerLab/ATX-Raspi/master/shutdownirq.py
            run_as_root chmod +x /etc/shutdownirq.py
            run_as_root sed -i '$ i python /etc/shutdownirq.py &' /etc/rc.local
            ;;
        2)
            run_as_root -fsSLo /etc/shutdowncheck.sh https://githubusercontent.com/LowPowerLab/ATX-Raspi/master/shutdowncheck.sh
            run_as_root chmod +x /etc/shutdowncheck.sh
            run_as_root sed -i '$ i /etc/shutdowncheck.sh &' /etc/rc.local
            ;;
    esac

    echo "You chose option ${OPTION}: All done!"
else
    echo "Shutdown/Reboot script setup was aborted."
fi
