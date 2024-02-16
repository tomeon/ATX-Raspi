#!/bin/sh

set -eu

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

run_as_root curl -fsSlo /storage/.config/shutdowncheck.sh /etc/shutdownirq.py https://githubusercontent.com/LowPowerLab/ATX-Raspi/master/shutdowncheckOpenElec.sh
run_as_root "${SHELL:-/bin/sh}" "-$-" -c "
echo '#!/bin/sh
(
/storage/.config/shutdowncheck.sh
)&' > /storage/.config/autostart.sh
"
chmod 777 /storage/.config/autostart.sh
chmod 777 /storage/.config/shutdowncheck.sh
