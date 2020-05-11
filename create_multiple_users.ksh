#!/usr/bin/ksh

_SUP_USER[0]="kennyh:1518:5004:unixsup:Kernny Hutcheson - Unix Support:bla::"

#***********************************************************************************
# integer variables for the counter and to check how many elements are in the array
#***********************************************************************************
_user_counter=0
_num_of_elements=0

_num_of_elements=${#_SUP_USER[*]}

#***********************************************************************************
# While loop will check what the counter is set to and then add to counter to allow
# the loop to go through the array of elements.
#
# One thing to watch tho is the size of the GCOS Field for this is using for loop
# in awk to get all the fields, we could delimit the array with a delimeter if this
# would be easier to understand but will leave as is at the moment.
#***********************************************************************************
while [[ ${_user_counter} -lt ${_num_of_elements} ]]
do
  _username=`echo ${_SUP_USER[$_user_counter]} | awk -F: '{print $1}'`
  _uid=`echo ${_SUP_USER[$_user_counter]} | awk -F: '{print $2}'`
  _gid=`echo ${_SUP_USER[$_user_counter]} | awk -F: '{print $3}'`
  _group=`echo ${_SUP_USER[$_user_counter]} | awk -F: '{print $4}'`
  _gcos=`echo ${_SUP_USER[$_user_counter]} | awk -F: '{print $5}'`
  _pwd=`echo ${_SUP_USER[$_user_counter]} | awk -F: '{print $6}'`
  _admgroup=`echo ${_SUP_USER[$_user_counter]} | awk -F: '{print $7}'`


  case `uname -s` in
   (Linux) MKGROUP="groupadd -g ${_gid} ${_group}"
           MKUSER="useradd -u ${_uid} -g ${_gid} -c '$_gcos' -d /home/${_username} -m -s /bin/bash ${_username}"
           PWCHANGE="eval echo "$_username:$_pwd" | /usr/sbin/chpasswd"
         ;;
   (AIX)  MKGROUP="/usr/bin/mkgroup id="$_gid" ${_group}"
          if [[ -z ${_admgroup} ]]
          then
             MKUSER="/usr/bin/mkuser id="${_uid}" pgrp="${_group}" gecos='$_gcos' home="/home/${_username}" shell="/usr/bin/ksh" ${_username}"
          else
             MKUSER="/usr/bin/mkuser id="${_uid}" pgrp="${_group}" admgroups="${_admgroup}" gecos=\"$_gcos\" home="/home/${_username}" shell="/usr/bin/ksh" ${_username}"
          fi
          PWCHANGE="eval echo "$_username:$_pwd" | /usr/bin/chpasswd"
         ;;
  esac
  #**********************************************
  # Check that GID doesn't already exist
  #**********************************************
  if grep ":${_gid}:" /etc/group > /dev/null 2>&1
  then
    echo "WARN: GID ${_gid} already exists unable to continue with creation of group ${_group}"
  else
    ${MKGROUP} > /dev/null 2>&1
    case "$?" in
          (0)  echo "INFO: ${_group} with ${_gid} been added to /etc/group"
          ;;
          (1)  echo "ERROR: Failed to add ${_group} with ${_gid} to /etc/group" && exit 1
          ;;
          (9)  echo "WARN: ${_group} group already exists"
          ;;
          (3)  echo "ERROR: Invalid Value used when adding $_group.. Exiting.." && exit 1
          ;;
          (17) echo "WARN: ${_group} group already exists"
          ;;
          (22) echo "ERROR: Invalid Value used when adding $_group.. Exiting.." && exit 1
          ;;
          (126) echo "ERROR: `/usr/bin/whoami` doesn't have permission to run groupadd." && exit 1
          ;;
    esac
  fi
  if grep ":${_uid}:" /etc/passwd  > /dev/null 2>&1
  then
    echo "WARN: UID ${_uid} already exists unable to continue with creation of user ${_username}"
  else
    if eval ${MKUSER} > /dev/null 2>&1
    case "$?" in
      (0)  echo "INFO: ${_username} with ${_uid} been added to /etc/passwd"
      ;;
      (1)  echo "ERROR: Failed to add ${_username} with ${_uid} to /etc/passwd" && exit 1
      ;;
      (9)  echo "WARN: ${_username} user already exists"
      ;;
      (3)  echo "ERROR: Invalid Value used when adding $_username.. Exiting.." && exit 1
      ;;
      (17) echo "WARN: ${_username} user already exists"
      ;;
      (22) echo "ERROR: Invalid Value used when adding $_username.. Exiting.." && exit 1
      ;;
      (126) echo "ERROR: `/usr/bin/whoami` doesn't have permission to run useradd." && exit 1
      ;;
     esac
     then
       echo "INFO: ${_username} been added to /etc/passwd"
       if [[ ! -z ${_pwd} ]]
       then
         if $PWCHANGE > /dev/null 2>&1
         then
           echo "INFO: ${_username} has had a password set"
         else
           echo "ERROR: failed to set ${_username} password"
         fi
       fi
     else
       echo "ERROR: Failed to add ${_username} to /etc/passwd"
       exit 1
     fi
  fi
  unset MKUSER
  unset MKGROUP
  ((_user_counter=_user_counter+1))
done

