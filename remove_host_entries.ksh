#!/bin/ksh
#***********************************************************************
# $Source:  $
# $Revision:$
# $Date:    $
# $Author:  $
# $State:   $
#***********************************************************************
# Title         : remove_hosts_entries
# Author        : Kenny Hutcheson < kenny.hutcheson@kchutcheson.co.uk >
# Date          : 27/05/2011
# Requires      : Sed to be installed.
# Category      : General Unix
#***********************************************************************
# Description
#
# Remove Server Entries from /etc/hosts.
# You need to pass the server names with a delimiter of "," comma.
#
#***********************************************************************
## Date:        Version:        Updater:                Notes:
## 27/05/2011   1.1             Kenny Hutcheson         Inital Version
##
##
#***********************************************************************
# RCS Version Control
#
# $Log:  $
#***********************************************************************

typeset _SERVERS=$(print $1| tr "," " ")
typeset _TMP_DIR=/var/tmp
typeset _HOSTS_FILE=/etc/hosts
#typeset _HOSTS_FILE=./hosts
typeset _PROGRAM_NAME=`basename $0`
typeset _sed_array
typeset -i _sed_counter=0
typeset _which_sed=$(which sed)


[[ -z ${_which_sed} ]] && echo "You need to have sed in your path i can guess but might not always be correct" && exit 1
[[ -z ${_SERVERS} ]] && echo "You need to pass what servers need updated in /etc/hosts" && exit 1
[[ ! -c /dev/null  ]] && echo "/dev/null isn't a character-special file, think there may be something wrong with it" && exit 1
[[ ! -f /etc/hosts  ]] && echo "/etc/hosts doesn't exist, unable to update something that doesn't exist." && exit 1

for _server in ${_SERVERS}
do
 if cat ${_HOSTS_FILE} | grep -v "^#" | grep -i ${_server} >> /dev/null 2>&1
 then
   _ip_add=`grep -i ${_server} /etc/hosts | awk '{print $1}'`
   for _ip in ${_ip_add}
   do
     _sed_array[${_sed_counter}]='-e 's/^${_ip}/#${_ip}/' '
    ((_sed_counter=_sed_counter+1))
   done
 fi
done

[[ -z ${_sed_array} ]] && echo "Didn't find any entries to be changed in /etc/hosts" && exit 0

if cp -p ${_HOSTS_FILE} ${_TMP_DIR}/hosts.${_PROGRAM_NAME}.$$
then
 if sed ${_sed_array[@]} ${_TMP_DIR}/hosts.${_PROGRAM_NAME}.$$ > ${_HOSTS_FILE}
 then
  echo "INFO: The following systems have been hashed out of /etc/hosts, ${_SERVERS}"
  if [[ -f ${_TMP_DIR}/hosts.${_PROGRAM_NAME}.$$ ]]
  then
   if rm -f ${_TMP_DIR}/hosts.${_PROGRAM_NAME}.$$ > /dev/null 2>&1
   then
    echo "INFO: tmp files have been removed."
   else
    echo "WARN: tmp files are still about, you will have to manually remove them."
   fi
  else
   echo "ERROR: can't find the tmp files, so unable to remove it... "
  fi
 else
  if cp -p ${_TMP_DIR}/hosts.${_PROGRAM_NAME}.$$ ${_HOSTS_FILE}
  then
   echo "INFO: Had to backout the changes for something went wrong with the sed command."
  else
   echo "ERROR: Manual interventaion required, hosts file might be corrupt because couldn't backout my change."
  fi
 fi
else
 echo "ERROR: Unable to take a backup of  ${_HOSTS_FILE} so not going to coninue with updating it, cos i can't  back it up."
fi

# Exit the script
exit 0