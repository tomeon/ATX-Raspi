## services\.atx-raspi-shutdown\.enable



Whether to enable the ATX-Raspi shutdown daemon\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [flake\.nix](/flake.nix)



## services\.atx-raspi-shutdown\.package



Package providing the ATX-Raspi daemon\.



*Type:*
package



*Default:*
` <derivation atx-raspi-shutdownirq> `

*Declared by:*
 - [flake\.nix](/flake.nix)



## services\.atx-raspi-shutdown\.chip

The path to the GPIO chip\.



*Type:*
null or absolute path



*Default:*
` null `



*Example:*
` "/dev/gpiochip42" `

*Declared by:*
 - [flake\.nix](/flake.nix)



## services\.atx-raspi-shutdown\.implementation



GPIO daemon implementation\.  “irq” selects the
edge-triggered Python implementation\.  “check” selects
the polling-based shell implementation\.



*Type:*
one of “check”, “irq”



*Default:*
` "irq" `



*Example:*
` "check" `

*Declared by:*
 - [flake\.nix](/flake.nix)



## services\.atx-raspi-shutdown\.pins\.boot



Pin on ` chip ` to set high upon ATX-Raspi
service startup\.



*Type:*
null or (unsigned integer, meaning >=0)



*Default:*
` null `



*Example:*
` 8 `

*Declared by:*
 - [flake\.nix](/flake.nix)



## services\.atx-raspi-shutdown\.pins\.shutdown



Pin on ` chip ` to watch for the shutdown or
reboot button press\.



*Type:*
null or (unsigned integer, meaning >=0)



*Default:*
` null `



*Example:*
` 7 `

*Declared by:*
 - [flake\.nix](/flake.nix)



## services\.atx-raspi-shutdown\.pulses\.reboot



Minimum duration of high state on
` pins.shutdown ` to trigger reboot\.



*Type:*
null or floating point number



*Default:*
` null `



*Example:*
` 0.2 `

*Declared by:*
 - [flake\.nix](/flake.nix)



## services\.atx-raspi-shutdown\.pulses\.shutdown



Minimum duration of high state on
` pins.shutdown ` to trigger shutdown\.



*Type:*
null or floating point number



*Default:*
` null `



*Example:*
` 0.6 `

*Declared by:*
 - [flake\.nix](/flake.nix)


