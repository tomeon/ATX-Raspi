#!/bin/bash

OPTION=$(whiptail --title "ATXRaspi/MightyHat shutdown/reboot script setup" --menu "\nChoose your script type option below:\n\n(Note: changes require reboot to take effect)" 15 78 4 \
"1" "Install INTERRUPT based script /etc/shutdownirq.py (recommended)" \
"2" "Install POLLING based script /etc/shutdowncheck.sh (classic)" \
"3" "Disable any existing shutdown script" 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus = 0 ]; then
    sudo sed -e '/shutdown/ s/^#*/#/' -i /etc/rc.local

    if [ $OPTION = 1 ]; then
      curl -fsSLo /etc/shutdownirq.py https://githubusercontent.com/LowPowerLab/ATX-Raspi/master/shutdownirq.py
      sudo chmod +x /etc/shutdownirq.py
      sudo sed -i '$ i python /etc/shutdownirq.py &' /etc/rc.local
    elif [ $OPTION = 2 ]; then
      curl -fsSLo /etc/shutdowncheck.sh https://githubusercontent.com/LowPowerLab/ATX-Raspi/master/shutdowncheck.sh
      sudo chmod +x /etc/shutdowncheck.sh
      sudo sed -i '$ i /etc/shutdowncheck.sh &' /etc/rc.local
    fi

    echo "You chose option" $OPTION ": All done!"
else
    echo "Shutdown/Reboot script setup was aborted."
fi
