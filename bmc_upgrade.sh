#!/bin/ksh
##***********************************************************************
# $Source: /agnadmin/patrol/RCS/bmc_upgrade.sh,v $
# $Revision: 1.7 $
# $Date: 2012/01/04 15:25:37 $
# $Author: istskhu $
# $State: Exp $
##***********************************************************************
# Title         : bmc_upgrade.sh
# Author        : Kenny Hutcheson < kenny.hutcheson@kchutcheson.co.uk >
# Date          : 19/12/2011
# Requires      : 
# Category      : BMC Patrol Upgrade
##***********************************************************************
# Description
#
# Upgrade patrol to latest versions, running automated patrol install.
#
# This script assumes patrol is already installed on the system and that
# the patrol user etc is already setup.
#
#
##***********************************************************************
## Date:        Version:        Updater:                Notes:
## 19/12/2011   1.1             Kenny Hutcheson         Inital Version
##
##
##***********************************************************************
# RCS Version Control
#
# $Log: bmc_upgrade.sh,v $
# Revision 1.7  2012/01/04 15:25:37  istskhu
# Added Some more comments
#
# Revision 1.6  2012/01/04 15:20:09  istskhu
# *** empty log message ***
#
# Revision 1.5  2012/01/03 13:38:03  istskhu
# added start patrol agent function and added if statement to run the setuid script.
#
# Revision 1.4  2012/01/03 11:33:42  istskhu
# Had to change about the check_environment function because there was a chown to the patrol user
# before even checking the patrol user exists on the server.
#
# Revision 1.3  2012/01/03 11:20:44  istskhu
# missing some exit 1 after errors on some lines, this has now been updated.
# /
#
# Revision 1.2  2012/01/03 11:09:12  istskhu
# Added Temp patrol install dir, some other checks and a install package dependancy function
# /
#
# Revision 1.1  2011/12/21 14:55:05  istskhu
# Initial revision
#
#
##********************************************************************************
# Setup PATH
##********************************************************************************
export PATH=/usr/kerberos/bin:/usr/local/bin:/bin:/usr/bin:/usr/sbin:/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/bin:/bin
#
#********************************************************************************
# Setup Script environmental variables below.
##********************************************************************************
_PN=`basename $0`
_OS=`uname -s`
_DATE_TIME=`date +%d-%m-%Y-%T`
_TMP_MOUNT="/patrol_tmp_mount"
_REMOTE_NFS_SERVER="10.38.73.215"
_REMOTE_MOUNT__PNT="/nimdata/lppsource/bmc/bmc9100_automated"
_LOGFILE=/tmp/new.out
_PATROL_USER=patrol
_PATROL_GROUP=patrol
_BMC_FILESYSTEM=/opt/bmc
_TMP_SUDO_PATROL="/tmp/$$.patrol_sudoers"
_PATROL_SETUP_SCRIPT=install.sh
_OLD_BMCINSTALL_ENV=/home/$_PATROL_USER/BMCINSTALL
_LOCAL_LOGDIR=/usr/local/logs
_LOCAL_LOGFILE=${_LOCAL_LOGDIR}/patrol-upgrade.log
#********************************************************************************
# Following variables are required to unpack the package. For 
# Sometimes /tmp is too wee so we are best putting it somewhere we know it can go. 
#********************************************************************************
_UNPACK_FS=/backup
export IATEMPDIR=$_UNPACK_FS/tmp

[[ ${_OS} != "Linux" ]] && echo "ERROR: ${_PN} will not run on ${_OS} Linux Only, for now anyway." && exit_cleanup_function 1

#********************************************************************************
# This function will check the environment on the local system to make 
# sure the following are in place.
#
# 1. _PATROL_USER user is defined and setup
# 2. _BMC_FILESYSTEM is setup and is owned by patrol.
# 3. create the _LOCAL_LOGDIR if required
# 4. check _UNPACK_FS exists, add on to this should be to see enough space is there. 
# 4a. Create tmp dir if all ok for patrol install to be unpacked into.
#
# Above variables are defined at the start of the script.
#
#********************************************************************************
check_environment ()
{

if [[ ! -d ${_LOCAL_LOGDIR} ]]
then
 if mkdir -p ${_LOCAL_LOGDIR}
 then
   echo "INFO: Had to create ${_LOCAL_LOGDIR} because it didn't exist."
 else
   echo "ERROR: there was an error creating ${_LOCAL_LOGDIR}, manual intervention required."
   exit 1
 fi
fi

if id $_PATROL_USER >> /dev/null 2>&1
then
  echo "INFO: $_PATROL_USER is setup on the system, we are able to continue with the install/upgrade."
else
 echo "ERROR: User patrol doesn't exist on the system, unable to continue with upgrade."
 exit 1
fi

##*********************************************************
# Check ${_BMC_FILESYSTEM} exits
##*********************************************************
if [[ ! -d ${_BMC_FILESYSTEM} ]]
then
  echo "ERROR: ${_BMC_FILESYSTEM} doesn't exist on the system, unable to continue with upgrade."
  exit 1
else
  if [[ `ls -ld ${_BMC_FILESYSTEM} | awk '{print $3}'` != "$_PATROL_USER" ]]
  then
    echo "ERROR: ${_BMC_FILESYSTEM} is not owned by $_PATROL_USER unable to continue with install/upgrade"
    exit 1
  else
    echo "INFO: $_BMC_FILESYSTEM is setup on the system, we are able to continue with the install/upgrade."
  fi
fi

##*********************************************************
# Check  ${_UNPACK_FS} exits
##*********************************************************
if [[ ! -d $_UNPACK_FS ]]
then
  echo "ERROR: "$_UNPACK_FS" filesystem doesn't exist, unable to unpack patrol package here. Manual intervention required...."
  exit 1
elif /bin/mount | grep -i "$_UNPACK_FS " >> /dev/null 2>&1
then
 echo "INFO: $_UNPACK_FS filesystem exists, we can continue with the patrol install. for it will be unpacked here..."
 if [[ ! -d ${IATEMPDIR} ]]
 then
   mkdir -p ${IATEMPDIR}
   chown $_PATROL_USER:$_PATROL_GROUP ${IATEMPDIR}
 fi
fi

##*********************************************************
# if the ${_OLD_BMCINSTALL_ENV} exists then move it aside.
##*********************************************************
if [[ -d ${_OLD_BMCINSTALL_ENV} ]]
then
 if mv ${_OLD_BMCINSTALL_ENV} ${_OLD_BMCINSTALL_ENV}.bfupgrade.${_DATE_TIME}
 then
    echo "INFO: Old ${_OLD_BMCINSTALL_ENV} been moved to ${_OLD_BMCINSTALL_ENV}.beforeupgrade"
 else
    echo "ERROR: Unable to move ${_OLD_BMCINSTALL_ENV} to ${_OLD_BMCINSTALL_ENV}.beforeupgrade manual intervention required.. Exiting."
    exit 1
 fi
fi

#
# Call the check_install_dependancies function this will make sure that all relevant 
# are installed 
check_install_dependancies
#
}


#********************************************************************************
#
# install missing rpm required for updated version of patrol. 
# there may be others but this is all i know about.
#
# Ok this requires your system to be registered to your RHEL satellite server
# or some other form of package deployment.
#
#********************************************************************************
check_install_dependancies ()
{
_SOFTWARE_TO_BE_INSTALLED[0]="audit-libs:i386"
_SOFTWARE_TO_BE_INSTALLED[1]="compat-libstdc++:i386"
_SOFTWARE_TO_BE_INSTALLED[2]="glibc:i686"
_SOFTWARE_TO_BE_INSTALLED[3]="glibc:x86_64"
_SOFTWARE_TO_BE_INSTALLED[4]="libgcc:i386"
_SOFTWARE_TO_BE_INSTALLED[5]="libstdc++:i386"
_SOFTWARE_TO_BE_INSTALLED[6]="pam:i386"

_counter=0
_numb_elements_software=${#_SOFTWARE_TO_BE_INSTALLED[*]}
_DEFINED=1
_LETS_INSTALL_STUFF=0

## if statement needs removed, cos not needed.

if [[ $_LETS_INSTALL_STUFF -eq 0 ]]
then
 while [[ ${_counter} -lt ${_numb_elements_software} ]]
 do
  _pkg=`echo ${_SOFTWARE_TO_BE_INSTALLED[${_counter}]} | awk -F: '{print $1}'`
  _arch=`echo ${_SOFTWARE_TO_BE_INSTALLED[${_counter}]} | awk -F: '{print $2}'`
  if [[ ! -z ${_arch} ]]
  then
   if rpm -qa --qf "%{NAME} %{ARCH}\n" | grep -i "^${_pkg}"  | grep -i ${_arch} > /dev/null 2>&1
   then
    echo "INFO: dependant rpm of ${_pkg} with ${_arch}  is already installed on the system"
   else
    if [[ -f /usr/sbin/up2date ]]
    then
     if /usr/sbin/up2date -i ${_pkg} --arch=${_arch} >> ${_LOCAL_LOGFILE} 2>&1
     then
       echo "INFO: ${_pkg} was installed successfully"
     else
       echo "ERROR: ${_pkg} didn't install successfully, assume server not registered to satellite"
       exit 1
     fi
    elif [[ -f /usr/bin/yum ]]
    then
      if /usr/bin/yum -y install ${_pkg} >> ${_LOCAL_LOGFILE} 2>&1
      then
      
       echo "INFO: ${_pkg} was installed successfully"
     else
       echo "ERROR: ${_pkg} didn't install successfully, assume server not registered to satellite"
       exit 1
     fi
    else
      echo "ERROR: Unable to find up2date or yum to install ${_pkg}"
      exit 1
    fi
   fi
  else
   if rpm -qa --qf "%{NAME} %{ARCH}\n" | grep -i "^${_pkg}" > /dev/null 2>&1
   then
     echo "INFO: dependant rpm of ${_pkg} with ${_arch}  is already installed on the system"
   else
    if [[ -f /usr/sbin/up2date ]]
    then
     if /usr/sbin/up2date -i ${_pkg} >> ${_LOCAL_LOGFILE} 2>&1
     then
     	
       echo "INFO: ${_pkg} was installed successfully"
     else
       echo "ERROR: ${_pkg} didn't install successfully, assume server not registered to satellite"
       exit 1
     fi
    elif [[ -f /usr/bin/yum ]]
    then
     if /usr/bin/yum -y install ${_pkg} >> ${_LOCAL_LOGFILE} 2>&1
     then
       echo "INFO: ${_pkg} was installed successfully"
     else
       echo "ERROR: ${_pkg} didn't install successfully, assume server not registered to satellite"
       exit 1
     fi
    else
      echo "ERROR: Unable to find up2date or yum to install ${_pkg}"
      exit 1
    fi
   fi
  fi
 ((_counter=_counter+1))
 done
fi
}

#********************************************************************************
# This function is to take a cp of a file to another
#********************************************************************************
backup_files ()
{
typeset _master_file=$1
typeset _backup_master_file=$2

if cp -p ${_master_file} ${_backup_master_file}
then
 echo "INFO: cp of ${_master_file} to ${_backup_master_file} complete successfully"
else
 echo "ERROR: cp of ${_master_file} to ${_backup_master_file} failed, manual intervention required."
 exit_cleanup_function 1
fi
}

#********************************************************************************
# This function adds a rule to sudo to allow a script be run as the patrol user to complete
# the installation of the install.
#
# The rule is removed once the install completes, even if there is a failure in the script
# the rule will be removed.
#********************************************************************************
update_sudoers ()
{

typeset _counter=0
_visudoers=$(which visudo)
if [[ -z $_visudoers ]]
then
 _visudoers=/usr/local/sbin/visudo
fi

echo "#### Patrol Sudo Rules for upgrade START" >> $_TMP_SUDO_PATROL 
print -n "${_sudo_rules[@]}" >> $_TMP_SUDO_PATROL
echo "#### Patrol Sudo Rules for upgrade END" >> $_TMP_SUDO_PATROL
_glob_sudo_file=0
_sudoers_path="/etc/sudoers /opt/sudo/etc/sudoers/sudoers /usr/local/etc/sudoers /usr/local/etc/sudo/sudoers"

for sudoers in ${_sudoers_path}
do
 if [[ -f ${sudoers} ]]
 then
  typeset _config_file=${sudoers}
  typeset _backup_cf_file=${_config_file}.before-patrol_update
  _glob_sudo_config_file[$_glob_sudo_file]=${sudoers}

  #********************************************************************************
  # Update /etc/sudoers with PSERIES ACCESS
  ##*******************************************************************************
  echo "INFO: Update of /etc/sudoers to include all EDC support users"
        
  ##********************************************************************************
  # Call the backup_file function to backup config file before any changes.
  ##********************************************************************************
  backup_files "${_config_file} ${_backup_cf_file}"
  #
  if cat $_TMP_SUDO_PATROL >> ${_config_file}
  then
   if [[ -f ${_visudoers} ]]
   then
     if ${_visudoers} -cf ${_config_file} | tail -1 | egrep 'parsed OK'
     then
	_sudoers_updated=1
        echo "INFO: Patrol entries have been added to the $_config_file file"
        echo "INFO: ${_config_file} parsed fine so ready to use :)"
     else
        echo "ERROR:  ${_config_file} didn't parse correctly, manual intervention required."
        echo "CMD: ${_visudoers} -cf ${_config_file} | tail -1 | egrep 'parsed OK'"
        if cp -p ${_backup_cf_file} ${_config_file} > /dev/null 2>&1
        then
           if ${_visudoers} -cf ${_config_file} | tail -1 | egrep 'parsed OK'
           then
             echo "INFO: backout of update to ${_config_file} complete successfully"
	     _sudoers_updated=0
   	   else
      	    echo "ERROR: backout didn't work, manual intervention required."
     	    exit_cleanup_function 1
   	   fi
        else
         echo "ERROR: backout of ${_backup_cf_file} ${_config_file} didn't complete successfully, manual intervention required"
         exit_cleanup_function 1
        fi
     fi
    else
     echo "ERROR: unable to find visudo to check the sudoers is parsed OK"
     exit_cleanup_function 1
    fi
  else
   echo "ERROR: Entries were not added to $_config_file correctly"
   exit_cleanup_function 1
  fi
  ((_counter=_counter+1))
 fi
((_glob_sudo_file=_glob_sudo_file+1))
done

if [[ $_counter -eq 0 ]]
then
 echo "ERROR: no sudoers file found so canny update it... exiting...."
 exit_cleanup_function 1
fi
}
#********************************************************
# Function that is used to mount/umount a remove NFS share.
##********************************************************
umount_mount_nfs_dir ()
{
# Setup VAR that is passed when calling the function umount_mount_nfs_dir
#
VAR=$1

# Case statement that if it's a mount option will run the mount commands if umount will unmount the filesystem
#
case ${VAR} in
 mount) if [[ ! -d $_TMP_MOUNT ]]
        then
         if mkdir -p $_TMP_MOUNT 
         then
          echo "${_PN}: $_TMP_MOUNT was created...." 
         else
          echo "ERROR unable to create $_TMP_MOUNT backup can't continue..." 
          exit 1
         fi
        fi
        if /bin/mount | grep -i "${_TMP_MOUNT}" > /dev/null 2>&1
        then
         echo "ERROR: Something already mounted on ${_TMP_MOUNT} can't continue. Exiting..."
         exit 1
        else
         if mount -o soft,vers=3 -t nfs ${_REMOTE_NFS_SERVER}:${_REMOTE_MOUNT__PNT} ${_TMP_MOUNT} 
         then
          if /bin/mount | grep -i "${_TMP_MOUNT}" > /dev/null 2>&1
          then
           echo "INFO: ${_REMOTE_NFS_SERVER}:${_REMOTE_MOUNT__PNT} mounted to ${_TMP_MOUNT}"
          else
           echo "ERROR: ${_REMOTE_NFS_SERVER}:${_REMOTE_MOUNT__PNT} is not mounted to ${_TMP_MOUNT}"
           exit 1
          fi
         else
          sleep 20
          if mount -o soft,vers=3 -t nfs ${_REMOTE_NFS_SERVER}:${_REMOTE_MOUNT__PNT} ${_TMP_MOUNT} 
          then
           if /bin/mount | grep -i "${_TMP_MOUNT}" > /dev/null 2>&1
           then
            echo "INFO: ${_REMOTE_NFS_SERVER}:${_REMOTE_MOUNT__PNT} mounted to ${_TMP_MOUNT}"
           else
            echo "ERROR: ${_REMOTE_NFS_SERVER}:${_REMOTE_MOUNT__PNT} is not mounted to ${_TMP_MOUNT} tried twice... please investigate.."
            exit 1
           fi
          else
           echo "ERROR: ${_REMOTE_NFS_SERVER}:${_REMOTE_MOUNT__PNT} is not mounted to ${_TMP_MOUNT} tried twice... please investigate."
           exit 1
          fi
         fi
        fi
        ;;
 umount)if umount ${_TMP_MOUNT} 
        then
         echo "INFO: umount of ${_TMP_MOUNT} complete..." 
        else
         echo "ERROR umount of ${_TMP_MOUNT} failed..." 
         exit 1
        fi
        ;;

 *) echo "ERROR options for the case statement are either mount or umount...." 
    exit 1
esac
}

##********************************************************
#
# Function is used to run the installer for patrol. 
# and then run the rootscripts script 
#
##********************************************************
setup_patol ()
{
_sudo_counter=0
if [[ -f ${_TMP_MOUNT}/$_PATROL_SETUP_SCRIPT ]]
then
 su patrol -c "cd ${_TMP_MOUNT} ; ./$_PATROL_SETUP_SCRIPT" >> ${_LOCAL_LOGFILE} 2>&1
 #echo "kid on we are installing"
fi

if [[ -d ${_OLD_BMCINSTALL_ENV} ]]
then
 _FIND_FILES=`find ${_OLD_BMCINSTALL_ENV} -name  "*.log_rootscripts*" | egrep -v uninstall_uninstaller`
 if [[ ! -z ${_FIND_FILES} ]]
 then
  for rootscript in $_FIND_FILES
  do
    _sudo_rules[$_sudo_counter]="$_PATROL_USER	ALL = NOPASSWD: /bin/su -c sh $rootscript\n"
    ((_sudo_counter=_sudo_counter+1))
  done

 # Now call the setup sudoers function, cos now when it's done we can run the root scripts
 #
 update_sudoers  
 # END
 
 # ok sudoers is updates, we can now run the root scripts
 for rootscript in $_FIND_FILES
 do
  su patrol -c "sudo su -c 'sh $rootscript'" >> ${_LOCAL_LOGFILE} 2>&1
  if [[ -f /opt/bmc/Patrol3/agent_configure.sh ]]
  then
    /opt/bmc/Patrol3/agent_configure.sh -a >> ${_LOCAL_LOGFILE} 2>&1
  fi
 done
 else
  echo "ERROR: Unable to  run the rootscripts because i can't find them, manual intervention required...."
  exit_cleanup_function 1
 fi
else
 echo "ERROR: Unable to find the ${_OLD_BMCINSTALL_ENV} so not sure where the install scripts are i need to run, manual intervention required.."
 exit_cleanup_function 1
fi

}
##********************************************************
#
# Start Patrol Agent rite at the end.
#
##********************************************************
start_patrol ()
{
 echo "INFO: Sleeping for 2min before checking if patrol is running."
 sleep 120
 if ps -ef| grep PatrolAgent | grep -v "grep" >> /dev/null 2>&1
 then
  echo "INFO: PatrolAgent is already running no need to start it."
 else
  if su - patrol -c /opt/bmc/Patrol3/PatrolAgent -p 3181
  then
  	echo "INFO: PatrolAgent was started... "
  else
    echo "ERROR: PatrolAgent failed to start..."
  fi
 fi
}

##********************************************************
#
# Backout any sudoers updates by just copying the file
# that was copied before any changes back in place.
#
##********************************************************
backout_sudoers ()
{
_glob_sudo_counter=0
if [[ $_sudoers_updated -eq 1 ]]
then
 if [[ ! -z ${_glob_sudo_config_file[@]} ]]
 then
  if [[ ${#_glob_sudo_config_file[@]} -gt 1 ]]
  then
    for glob_s_file in ${_glob_sudo_config_file[@]}
    do
      #backup_files ${_glob_sudo_config_file[${_glob_sudo_counter}]}.before-patrol_update ${_glob_sudo_config_file[${_glob_sudo_counter}]}
      ((_glob_sudo_counter=_glob_sudo_counter+1))
    done
  else
    backup_files ${_glob_sudo_config_file[0]}.before-patrol_update ${_glob_sudo_config_file[0]}
  fi
 else
  echo "WARN: Not sure if any sudo files where updated, please check.. "
 fi
else
 echo "INFO: Sudoers wasn't updated so we don't need to back it out. "
fi
}

##********************************************************
#
# function that cleans up the environment nice and clean.
#
##********************************************************
exit_cleanup_function ()
{

case $1 in 
	1) umount_mount_nfs_dir "umount"
           exit 1
	;;
esac
}

###********************************************************
### MAIN BODY OF THE SCRIPT, 
###********************************************************

check_environment
umount_mount_nfs_dir "mount"
setup_patol
umount_mount_nfs_dir "umount"
backout_sudoers
start_patrol
rmdir /patrol_tmp_mount
rm /tmp/$$.patrol_sudoers

###********************************************************
###
### 			END
###
###********************************************************
