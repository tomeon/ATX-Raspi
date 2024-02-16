#!/bin/sh

curl -fsSlo /storage/.config/shutdowncheck.sh /etc/shutdownirq.py https://githubusercontent.com/LowPowerLab/ATX-Raspi/master/shutdowncheckOpenElec.sh
echo '#!/bin/bash
(
/storage/.config/shutdowncheck.sh
)&' > /storage/.config/autostart.sh
chmod 777 /storage/.config/autostart.sh
chmod 777 /storage/.config/shutdowncheck.sh
