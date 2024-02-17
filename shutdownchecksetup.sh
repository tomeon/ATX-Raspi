#!/bin/sh

set -eu

SHUTDOWNCHECK_OWNER="${SHUTDOWNCHECK_OWNER:-LowPowerLab}"
SHUTDOWNCHECK_REPO="${SHUTDOWNCHECK_REPO:-ATX-Raspi}"
SHUTDOWNCHECK_REV="${SHUTDOWNCHECK_REV:-master}"
SHUTDOWNCHECK_BASEURL="${SHUTDOWNCHECK_BASEURL:-"https://githubusercontent.com/${SHUTDOWNCHECK_OWNER}/${SHUTDOWNCHECK_REPO}/${SHUTDOWNCHECK_REV}"}"

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

if command -v curl 1>/dev/null 2>&1; then
    fetch() {
        run_as_root curl -fsSLo "$2" "$1"
    }
elif command -v wget 1>/dev/null 2>&1; then
    fetch() {
        run_as_root wget -o "$2" "$1"
    }
else
    fetch() {
        echo 1>&2 "neither curl nor wget are available; cannot fetch '$1' into '$2'"
        return 127
    }
fi

install_interrupt_script() {
    fetch "${SHUTDOWNCHECK_BASEURL}/shutdownirq.py" /etc/shutdownirq.py
    run_as_root chmod +x /etc/shutdownirq.py
    run_as_root sed -i '$ i python /etc/shutdownirq.py &' /etc/rc.local
}

install_polling_script() {
    dest="${1:-/etc/shutdowncheck.sh}"
    fetch "${SHUTDOWNCHECK_BASEURL}/shutdowncheck.sh" "$dest"
    run_as_root chmod +x "$dest"
    run_as_root sed -i "\$ i ${dest} &" /etc/rc.local
}

looks_like_elec_distro() {
    # shellcheck disable=SC1091
    . /etc/os-release 1>/dev/null 2>&1 || :

    case "${NAME:-}" in
        *ELEC)
            return 0
            ;;
    esac

    case "${ID:-}" in
        *elec)
            return 0
            ;;
    esac

    # shellcheck disable=SC3028
    # *ELEC distros:
    #   1. Use `root` for shell sessions,
    #   2. Have the directory `/storage/.config`, and
    #   3. Use a `sudo` wrapper that issues a warning about not needing sudo
    #      and then exits with a non-zero status.
    [ "${EUID:-$(id -u 2>/dev/null || :)}" -eq 0 ] && [ -d /storage/.config ] && ! sudo true
}

if looks_like_elec_distro; then
    install_polling_script /storage/.config/shutdowncheck.sh
    run_as_root "${SHELL:-/bin/sh}" "-$-" -c "
echo '#!/bin/sh
(
/storage/.config/shutdowncheck.sh
)&' > /storage/.config/autostart.sh
"
    chmod 777 /storage/.config/autostart.sh
    chmod 777 /storage/.config/shutdowncheck.sh
    exit
fi

if command -v whiptail 1>/dev/null 2>&1; then
    get_script_type() {
        whiptail --title "ATXRaspi/MightyHat shutdown/reboot script setup" --menu "\nChoose your script type option below:\n\n(Note: changes require reboot to take effect)" 15 78 4 \
            "1" "Install INTERRUPT based script /etc/shutdownirq.py (recommended)" \
            "2" "Install POLLING based script /etc/shutdowncheck.sh (classic)" \
            "3" "Disable any existing shutdown script" 3>&1 1>&2 2>&3
    }
elif (help select) 1>/dev/null 2>&1; then
    # Eval this, as otherwise we're liable to get a syntax error from shells that
    # do not understand `select ...; do ...; done`
    eval '
        get_script_type() {
            echo 1>&2 "ATXRaspi/MightyHat shutdown/reboot script setup"
            echo 1>&2 "Choose your script type option below (note: changes require reboot to take effect)"

            # shellcheck disable=SC3043
            local PS3="Choose your script type option: "

            # shellcheck disable=SC3008
            select CHOICE in "Install INTERRUPT based script /etc/shutdownirq.py (recommended)" \
                "Install POLLING based script /etc/shutdowncheck.sh (classic)" \
                "Disable any existing shutdown script"; do
                if [ -n "${CHOICE:-}" ]; then
                    echo "$REPLY"
                    break
                else
                    echo 1>&2 "Not a valid choice: ${REPLY}"
                fi
            done
        }
    '
else
    get_script_type() {
        echo 1>&2 'ATXRaspi/MightyHat shutdown/reboot script setup'
        echo 1>&2 "Choose your script type option below (note: changes require reboot to take effect)"
        echo 1>&2 "\
1) Install INTERRUPT based script /etc/shutdownirq.py (recommended)
2) Install POLLING based script /etc/shutdowncheck.sh (classic)
3) Disable any existing shutdown script"


        while true; do
            echo 1>&2 'Choose your script type option: '

            if read -r REPLY; then
                case "${REPLY:-}" in
                    1|2|3)
                        echo "$REPLY"
                        return
                        ;;
                    *)
                        echo 1>&2 "Not a valid choice: ${REPLY}"
                        ;;
                esac
            fi
        done
    }
fi

if OPTION="$(get_script_type)"; then
    run_as_root sed -e '/shutdown/ s/^#*/#/' -i /etc/rc.local

    case "$OPTION" in
        1)
            install_interrupt_script
            ;;
        2)
            install_polling_script
            ;;
    esac

    echo "You chose option ${OPTION}: All done!"
else
    echo "Shutdown/Reboot script setup was aborted."
fi
