#!/bin/ksh93

typeset -i2 mask=255

[[ $# != 2 ]] && {
   echo "Usage: $0 ipaddress subnetmask"
   exit 1
}

SaveIFS=$IFS
IFS=.
typeset -a IParr=($1)
typeset -a NMarr=($2)
IFS=$SaveIFS

typeset -i2 ipbin1=${IParr[0]}
typeset -i2 ipbin2=${IParr[1]}
typeset -i2 ipbin3=${IParr[2]}
typeset -i2 ipbin4=${IParr[3]}

typeset -i2 nmbin1=${NMarr[0]}
typeset -i2 nmbin2=${NMarr[1]}
typeset -i2 nmbin3=${NMarr[2]}
typeset -i2 nmbin4=${NMarr[3]}

echo
echo "       IP Address: $1"
echo "      Subnet Mask: $2"
echo "  Network Address: $((ipbin1 & nmbin1)).$((ipbin2 & nmbin2)).$((ipbin3 & nmbin3)).$((ipbin4 & nmbin4))"
echo "Broadcast Address: $((ipbin1 | (mask ^ nmbin1))).$((ipbin2 | (mask ^ nmbin2))).$((ipbin3 | (mask ^ nmbin3))).$((ipbin4 | (mask ^ nmbin4)))"
echo

exit 0