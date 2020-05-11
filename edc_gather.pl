#!/usr/bin/perl
#***********************************************************************
# Title         : EDC_gather.pl
# Author        : Kenny Hutcheson < kenny.hutcheson@kchutcheson.co.uk >
# Date          : 14/01/2011
# Requires      : Perl
# Category      : EDC Migration
#***********************************************************************
# Description
#
# This script query's a Linux system and generates XML output that can
# be imported into a database.
#
#***********************************************************************
## Date:        Version:        Updater:                Notes:
## 01/10/2010   1.0             Kenny hutcheson         Inital Version
##
##
##
#***********************************************************************

use warnings;

$smb = "no";
my $filename=`uname -n`;
chomp($filename);
#***********************************************************************
# Open file handle to print all data to the logfile.
#***********************************************************************
open(LOGFILE, ">/tmp/$filename.xml") || die("Cannot open /tmp/$filename.xml");
#***********************************************************************
# Call Main function.
#***********************************************************************
main();
#***********************************************************************
# Close file handle
#***********************************************************************
close(LOGFILE);

#***********************************************************************
# Main function, that calls all subfunctions.
#***********************************************************************
sub main {
   print LOGFILE "<Output>\n";
        &fqdn;
   print LOGFILE " <General>\n";
	&hostname;
	&oslevel;
	&hardware;
	&swap;
        &virtualmachine;
        &cron;
	&runlevel;
        &scripts;
	&kernel;
	&selinux;
        &mountpoints;
	&nfs_mounts;
	&fstab;
   print LOGFILE " </General>\n";
   print LOGFILE " <UserInfo>\n";
	&user;
   print LOGFILE " </UserInfo>\n";
   print LOGFILE " <Storage>\n";
	&volumegroups;
	&whatmpathdevices;
	&physicalvolumes;
	&logicalvolumes;
        &fc_hosts;
  print LOGFILE " </Storage>\n";
  print LOGFILE " <Network>\n";
	&network;
	&routing_table;
  print LOGFILE " </Network>\n";
  print LOGFILE " <HostFiles>\n";
	&nsswitch;
	&resolv;
	&hosts;
  print LOGFILE " </HostFiles>\n";
  print LOGFILE " <Services>\n";
        &chkconfig;
        &samba;
	&snmp;
  print LOGFILE " </Services>\n";
  print LOGFILE " <InstalledPackages>\n";
        &packageinfo;
  print LOGFILE " </InstalledPackages>\n";
  print LOGFILE " <TSM>\n";
        &tsm;
  print LOGFILE " </TSM>\n";
  print LOGFILE "</Output>\n";
}

#***********************************************************************
# Work out fully qualified domain name.
#***********************************************************************
sub fqdn {
  my $hostname= `/bin/hostname`; 
  chomp($hostname);
  my @fqdn = `/usr/bin/nslookup $hostname`;
  my $set = 0;
  foreach $lookupline (@fqdn) {
   if ( $lookupline =~ /Name:/ ) {
     (undef,$name) = split /:/, $lookupline;
     chomp($name);
     trim($name);
     print LOGFILE "<FQDN>$name</FQDN>\n";
     $set++;
   } 
  }
  if ( $set =~ /0/ ) {
   print LOGFILE "<FQDN>$hostname</FQDN>\n";
  }
}

#***********************************************************************
# Work out the hostname
#***********************************************************************
sub hostname {
   my $hostname= `/bin/hostname`;
   chomp($hostname);
   print LOGFILE "  <ServerName>$hostname</ServerName>\n";
}
#***********************************************************************
# Work out the revision of Linux that is running along Architecture
#***********************************************************************
sub oslevel {
   if ( -e "/etc/redhat-release" ) {
    my $osbaselevel= `/bin/cat /etc/redhat-release`;
    my $type = `/bin/uname -m`;
    chomp($type);
    @baselevel = split /\s+/, $osbaselevel;
    @osbase = split /\./, $baselevel[6];
    print LOGFILE "  <OSDetail>\n";
    print LOGFILE "    <OperatingSystem>$baselevel[0] $baselevel[1]</OperatingSystem>\n"; 
    print LOGFILE "    <OSVersion>$baselevel[6]</OSVersion>\n";
    print LOGFILE "    <OSArchitecture>$type</OSArchitecture>\n";
    print LOGFILE "    <OSBaseLevel>$osbase[0]</OSBaseLevel>\n";
    print LOGFILE "    <OSReleaseLevel>$osbase[1]</OSReleaseLevel>\n";
    print LOGFILE "  </OSDetail>\n";
  } else {
    my $type = `/bin/uname -m`;
    print LOGFILE "  <OSDetail>\n";
    print LOGFILE "    <OperatingSystem>Unknown</OperatingSystem>\n";
    print LOGFILE "    <OSVersion>Unknown</OSVersion>\n";
    print LOGFILE "    <OSArchitecture>$type</OSArchitecture>\n";
    print LOGFILE "    <OSBaseLevel>Unknown<</OSBaseLevel>\n";
    print LOGFILE "    <OSReleaseLevel>Unknown<</OSReleaseLevel>\n";
    print LOGFILE "  </OSDetail>\n";
  }
}

#***********************************************************************
# Display hardware information of the system in question
#***********************************************************************
sub hardware {
   my $hardware_man=`/usr/sbin/dmidecode -s system-manufacturer`;
   my $product_name=`/usr/sbin/dmidecode -s system-product-name`;
   my $serial_number=`/usr/sbin/dmidecode -s system-serial-number`;
   my @processor = `/usr/sbin/dmidecode -t processor`;
   my @memory = `/usr/sbin/dmidecode -t memory`;
   my @dim_size;
   my @core_count;
   
   my $socket_count = grep /Status: Populated/, @processor;
   my $dim_slots = grep /  Size:/, @memory;
   my $dim_line;


   if ( "$product_name" =~ /VMware Virtual Platform/ ) {
     $pattern_string = "Enabled Size";
     foreach $dimm_line (@memory) {
      if ( $dimm_line =~ /$pattern_string/ ) {
       (undef,undef,undef,$size,undef) = split /\s+/, $dimm_line;
       if ( $size !~ /No/ ) {
         push(@dim_size, $size);
       }
       push(@no_slots, $dim_line);
      }
     }
   } else {
    $pattern_string = "Size:.[0-9]";
    foreach $dimm_line (@memory) {
     if ( $dimm_line =~ /$pattern_string/ ) {
       (undef,undef,$size,undef) = split /\s+/, $dimm_line;
       if ( $size !~ /No/ ) {
         push(@dim_size, $size);
       }
       push(@no_slots, $dim_line);
     }
    }
   }

   foreach $cpu_line (@processor) {
     if ( $cpu_line =~ /Core Count:/ ) {
       (undef,undef,undef, $core_count) = split /\s+/, $cpu_line;
       push(@core_count, $core_count);
     } elsif ( $cpu_line =~ /Core Enabled:/ ) {
       (undef,undef,undef, $core_enabled) = split /\s+/, $cpu_line;
       push(@core_enabled, $core_enabled);
     } elsif ( $cpu_line =~ /Max Speed:/ ) {
       (undef,undef,undef,$mx_speed,undef ) = split /\s+/, $cpu_line;
       push(@cpu_speed, $mx_speed); 
     } elsif ( $cpu_line =~ /Current Speed:/ ) {
       (undef,undef,undef, $cn_speed,undef ) = split /\s+/, $cpu_line;
       push(@cur_speed, $cn_speed);
     }
   }
   my $tot_core_count = 0;
   my $tot_core_enabled = 0;
   my $memory_size = 0; 
   $number_dimms = scalar(@dim_size);
   $total_dim_slots = scalar(@no_slots);

   #***********************************************************************
   # Work out the number of cores/ cores enabled and the memory size of the
   # system from the dmidecode output.
   #***********************************************************************
   ($tot_core_count+=$_) for @core_count;
   ($tot_core_enabled+=$_) for @core_enabled;
   if ( scalar(@dim_size) !~ /1/ ) {
       ($memory_size+=$_) for @dim_size; 
   } else {
     $memory_size = $dim_size[0];
   }

   chomp($hardware_man);
   chomp($product_name);
   chomp($serial_number);

   #***********************************************************************
   # XML output written to LOGFILE handle.
   #***********************************************************************
   print LOGFILE "  <Hardware>$hardware_man</Hardware>\n";
   print LOGFILE "  <CPUDetail>\n";
   print LOGFILE "    <CPUSockets>$socket_count</CPUSockets>\n";
   print LOGFILE "    <CPUCores>$tot_core_count</CPUCores>\n";
   print LOGFILE "    <CPUEnabledCores>$tot_core_enabled</CPUEnabledCores>\n";
   print LOGFILE "    <CPUMaxSpeed>$cpu_speed[0] MHz</CPUMaxSpeed>\n";
   print LOGFILE "    <CPUCurrentSpeed>$cur_speed[0] MHz</CPUCurrentSpeed>\n";
   print LOGFILE "  </CPUDetail>\n";
   print LOGFILE "  <MemoryDetail>\n";
   print LOGFILE "    <MemorySlots>$total_dim_slots</MemorySlots>\n";
   print LOGFILE "    <OccupiedSlots>$number_dimms</OccupiedSlots>\n";
   print LOGFILE "    <TotalMemory>$memory_size MB</TotalMemory>\n";
   print LOGFILE "  </MemoryDetail>\n";
}
#***********************************************************************
# Get the information of swap devices that are defined on the system
#***********************************************************************
sub swap {
  @page=`/sbin/swapon -s`;
  shift(@page);
  print LOGFILE "  <PageFile>\n";
  my $counter = 0;
  foreach $swap (@page) {
   ($slv,$stype,$ssize,$sused,$sprio) = split /\s+/, $swap;
   print LOGFILE "    <Location$counter>$slv</Location$counter>\n";
   print LOGFILE "    <Size$counter>$ssize</Size$counter>\n";
   print LOGFILE "    <Type$counter>$stype</Type$counter>\n";
   print LOGFILE "    <Used$counter>$sused</Used$counter>\n";
   print LOGFILE "    <Priority$counter>$sprio</Priority$counter>\n";
   $counter++;
  }
 print LOGFILE "  </PageFile>\n";
}

  
#***********************************************************************
# Check if the system is a virtual machine, this only checks for 
# VMWare systems there could be others?
#***********************************************************************
sub virtualmachine {
   my $manufacturer = `/usr/sbin/dmidecode -s system-manufacturer`;
   if ( $manufacturer =~ /VMware, Inc./ ) {
   print LOGFILE "  <VirtualMachine>yes</VirtualMachine>\n";
   } else {
     print LOGFILE "  <VirtualMachine>no</VirtualMachine>\n";
   }
}
#***********************************************************************
# Check what volume groups exist on the system
#***********************************************************************
sub volumegroups {
 my $count = 0;
   print LOGFILE "  <VolumeGroups>\n";
   my @volumegroup= `/usr/sbin/vgs --noheadings --aligned --separator ";"`;
   my $pv;
   my $vg;
   my $lv;
   my $sn;
   my $Attr;
   my $size;
   my $free;
   while ( $volumegroup[$count] ) {
    ($vg, $pv, $lv, $sn, $Attr, $size, $free ) = split /;/, trim($volumegroup[$count]);
      chomp($vg);
      print LOGFILE "    <VolumeGroup$count>$vg</VolumeGroup$count>\n";
      $count++;
   }
   print LOGFILE "  </VolumeGroups>\n";
}
#***********************************************************************
# Check what dm-multipath devices are on the system, might need to code
# something for powerpath?
#***********************************************************************
sub whatmpathdevices {
   print LOGFILE "  <MultiPathDevice>\n";
   my @whatmpathdevice= `/sbin/multipath -l`;
   my $counter = 0;
   foreach $line (@whatmpathdevice) {
    if ( $line =~ /mpath/ ) {
     ($mpath,$symid, $dmpath, undef) = split /\s+/, $line;
     print LOGFILE "    <Path>$mpath</Path>\n";
     print LOGFILE "    <SymID>$symid</SymID>\n";
     print LOGFILE "    <DMDevice>$dmpath</DMDevice>\n";
    }
    if ( $line =~ /size/ ) {
     chomp($line);
     print LOGFILE "    <INFO$counter>$line</INFO$counter>\n";
    }
   }
   print LOGFILE "  </MultiPathDevice>\n";
}
#***********************************************************************
# check what physical volumes are defined on the systems.
#***********************************************************************
sub physicalvolumes {
   print LOGFILE "  <PhysicalVolumes>\n";
   my @physicalvolume= `/usr/sbin/pvs --noheadings --aligned --separator ";"`;
   my $pv;
   my $vg;
   my $fmt;
   my $attr;
   my $psize;
   my $pfree;
   my $count = 0;
   while ($physicalvolume[$count] ) {
   
      ($pv,$vg,$fmt,$attr,$psize,$pfree) = split /;/, trim($physicalvolume[$count]);
         print LOGFILE "    <PhysicalDrive$count>\n";
         print LOGFILE "      <PV>$pv</PV>\n";
         print LOGFILE "      <VG>$vg</VG>\n";
         print LOGFILE "      <FMT>$fmt</FMT>\n";
         print LOGFILE "      <ATTR>$attr</ATTR>\n";
         print LOGFILE "      <PSIZE>$psize</PSIZE>\n";
         print LOGFILE "      <PFREE>$pfree</PFREE>\n";
         print LOGFILE "    </PhysicalDrive$count>\n";
      $count++;
   }
   print LOGFILE "  </PhysicalVolumes>\n";
}
#***********************************************************************
# Check what logical volumes are defined on the system.
#***********************************************************************
sub logicalvolumes {
   print LOGFILE "  <LogicalVolumes>\n";
   my @logicalvolume= `/usr/sbin/lvs --noheadings --aligned --separator ";"`;
   my $lv;
   my $vg;
   my $attr;
   my $lsize;
   my $origin;
   my $move;
   my $count = 0;
   while ($logicalvolume[$count] ) {
      ($lv,$vg,$attr,$lsize,$origin,$move,undef,undef,undef) = split /;/, trim($logicalvolume[$count]);
      chomp($lv,$vg,$attr,$lsize,$origin,$move);
         print LOGFILE "    <Volume$count>\n";
         print LOGFILE "      <LV>$lv</LV>\n";
         print LOGFILE "      <VG>$vg</VG>\n";
         print LOGFILE "      <ATTR>$attr</ATTR>\n";
         print LOGFILE "      <LSIZE>$lsize</LSIZE>\n";
         print LOGFILE "      <ORIGIN_SNAP_PCT>$origin</ORIGIN_SNAP_PCT>\n";
         print LOGFILE "      <MOVE_LOG_COPY_PCT>$move</MOVE_LOG_COPY_PCT>\n";
         print LOGFILE "    </Volume$count>\n";
      $count++;
   }
   print LOGFILE "  </LogicalVolumes>\n";
}
#***********************************************************************
# Output what entries are defined in /etc/fstab all hashed out entries are
# ignored.
#***********************************************************************
sub fstab {
   $fstab = "/etc/fstab";
   print LOGFILE "     <FStab>\n";
   if ( -e $fstab ) {
    @fstab = `/bin/cat $fstab`;
    foreach $mount (@fstab) {
     if ($mount !~ /^#/ ) {
      if ($mount !~ /^$/ ) {
       chomp($mount);
        print LOGFILE "         <Entry>$mount</Entry>\n";
      }
     }
    }
   }
   print LOGFILE "     </FStab>\n";

   
}
#***********************************************************************
# Check what filesystems are mounted on the system.
#***********************************************************************
sub mountpoints {
    print LOGFILE "  <MountPoints>\n";
    my @mount_points= `/bin/mount`;
    my $lv;
    my $mountpt;
    my $fstype;
    my $opts;
    my $mount_counter = 0;
    for $mount (@mount_points) {
     ($lv,undef, $mountpt, undef, $fstype, $opts) = split /\s+/, $mount;
     print LOGFILE "    <Device$mount_counter>$lv</Device$mount_counter>\n";
     print LOGFILE "    <MountPoint$mount_counter>$mountpt</MountPoint$mount_counter>\n";
     print LOGFILE "    <FSType$mount_counter>$fstype</FSType$mount_counter>\n";
     print LOGFILE "    <MountOptions$mount_counter>$opts</MountOptions$mount_counter>\n";
     $mount_counter++;
   }
   print LOGFILE "  </MountPoints>\n";
}
#***********************************************************************
# Display the network configuration.
#***********************************************************************
sub network {
   my @iparray= `/sbin/ifconfig -a`;
   my $ipaddr;
   my $bcast;
   my $mask;
   my $counter = 0;

   foreach $line (@iparray) {
      chomp($line);
      if ( $line =~ /Link encap:/ )
      {
         $nicinfo = $line;
         $nicinfo =~ s/\s+/,/g;
         ($nic,undef,$type,undef,$hwaddr) = split /,/, $nicinfo;
         (undef,$itype) = split /:/, $type;
      }
      if ( $line =~ /inet addr:/ )
      {
	   $line =~ s/\s+/:/g;
           if ( $line =~ /Bcast:/ ) {
	    (undef,undef,undef,$ipaddr,undef,$bcast,undef,$mask) = split /:/, $line;
		print LOGFILE "    <Interface$counter>\n";
		print LOGFILE "       <Name>$nic</Name>\n";
                print LOGFILE "       <MacAddress>$hwaddr</MacAddress>\n";
                print LOGFILE "       <Type>$itype</Type>\n";
		print LOGFILE "         <IPAddresses>\n";
                print LOGFILE "           <Address>$ipaddr</Address>\n";
                print LOGFILE "           <Netmask>$mask</Netmask>\n";
                print LOGFILE "           <Broadcast>$bcast</Broadcast>\n";
		print LOGFILE "         </IPAddresses>\n";
                print LOGFILE "    </Interface$counter>\n";
	    $counter++;
           } else {
	    (undef,undef,undef,$ipaddr,undef,$mask) = split /:/, $line;
                print LOGFILE "    <Interface$counter>\n";
                print LOGFILE "       <Name>$nic</Name>\n";
                print LOGFILE "       <MacAddress>$hwaddr</MacAddress>\n";
                print LOGFILE "       <Type>$itype</Type>\n";
                print LOGFILE "         <IPAddresses>\n";
                print LOGFILE "           <Address>$ipaddr</Address>\n";
                print LOGFILE "           <Netmask>$mask</Netmask>\n";
                print LOGFILE "         </IPAddresses>\n";
                print LOGFILE "    </Interface$counter>\n";
	    $counter++;
           }
      }
   }

}
#***********************************************************************
# Display current routing table.
#***********************************************************************
sub routing_table {
    print LOGFILE "  <RoutingTable>\n";
    my @routing_table = `/bin/netstat -rn`;
    my $route_counter = 0;
    # remove first line from array, this would be the Kernel IP routing table
    shift(@routing_table);
    # remove first line from array, this would now be "Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface"
    shift(@routing_table);
    foreach $route (@routing_table) {
     ($destination, $gateway, $netmask, $flags, $mss, $window, $irtt, $Iface) = split /\s+/, $route;
     print LOGFILE "    <Route_$route_counter>\n";
     print LOGFILE "      <Destination>$destination</Destination>\n";
     print LOGFILE "      <Gateway>$gateway</Gateway>\n";
     print LOGFILE "      <Netmask>$netmask</Netmask>\n";
     print LOGFILE "      <Flags>$flags</Flags>\n";
     print LOGFILE "      <Mss>$mss</Mss>\n";
     print LOGFILE "      <Window>$window</Window>\n";
     print LOGFILE "      <Irtt>$irtt</Irtt>\n";
     print LOGFILE "      <Interface>$Iface</Interface>\n";
     print LOGFILE "    </Route_$route_counter>\n";
     $route_counter++;
   }
   print LOGFILE "  </RoutingTable>\n";
}

#***********************************************************************
# Display current runlevel and also check the /etc/inittab file.
#***********************************************************************
sub runlevel {
   print LOGFILE "  <RunLevel>\n";
   my $runlevel= `/usr/bin/who -r`;
   $runlevel =~ s/\s+/,/g;
   (undef,undef,$rlevel,$rbootdate,$rbootime,undef) = split /,/, $runlevel;
   $filerunleve = `/bin/grep "^id" /etc/inittab`;
   (undef,$flevel,undef,undef) = split /:/, $filerunleve;
   print LOGFILE "    <CurrentRunlevel>$rlevel</CurrentRunlevel>\n";
   print LOGFILE "    <DefaultRunlevel>$flevel</DefaultRunlevel>\n";
   print LOGFILE "    <LastRbootDate>$rbootdate</LastRbootDate>\n";
   print LOGFILE "    <LastRbootTime>$rbootime</LastRbootTime>\n";
   print LOGFILE "  </RunLevel>\n";
}
#***********************************************************************
# Display what scripts are used by the default runlevel.
#***********************************************************************
sub scripts {
   print LOGFILE "  <RunLevelScripts>\n";
   my @scripts;
   if ($flevel =~ /3/ )
   {
      $directory = "/etc/rc.d/rc3.d/";
      @scripts = `/bin/ls /etc/rc.d/rc3.d`;
   } elsif  ($flevel =~ /1/ ) {
      $directory = "/etc/rc.d/rc1.d/";
      @scripts = `/bin/ls /etc/rc.d/rc1.d`;
   } elsif  ($flevel =~ /2/ ) {
      $directory = "/etc/rc.d/rc2.d/";
      @scripts = `/bin/ls /etc/rc.d/rc2.d`;
   } elsif  ($flevel =~ /4/ ) {
      $directory = "/etc/rc.d/rc4.d/";
      @scripts = `/bin/ls /etc/rc.d/rc4.d`;
   } elsif  ($flevel =~ /5/ ) {
      $directory = "/etc/rc.d/rc5.d/";
      @scripts = `/bin/ls /etc/rc.d/rc5.d`;
   } elsif  ($flevel =~ /6/ ) {
      $directory = "/etc/rc.d/rc1.6/";
      @scripts = `/bin/ls /etc/rc.d/rc6.d`;
   } 

   foreach $line (@scripts)
   {
     chomp($line);
     print LOGFILE "    <Script>$directory$line</Script>\n";
   }
    print LOGFILE "  </RunLevelScripts>\n";
}
#***********************************************************************
# Display any fiberchannel card information.
#***********************************************************************
sub fc_hosts {
  print LOGFILE "  <FiberChannel>\n"; 
  my $counter = 0;
  if ( -d "/sys/class/fc_host" )
  {
    opendir(FCHOST, "/sys/class/fc_host") || die("Cannot open directory");
    @files = readdir(FCHOST);
    foreach $line (@files)
    {
     if ( $line =~ /host/ )
     {
      $port_name = `/bin/cat /sys/class/fc_host/$line/port_name`;
      chomp($port_name);
      $node_name = `/bin/cat /sys/class/fc_host/$line/node_name`;
      chomp($node_name);
      $card_speed = `/bin/cat /sys/class/fc_host/$line/speed`;
      chomp($card_speed);
      $fabric_name = `/bin/cat /sys/class/fc_host/$line/fabric_name`;
      chomp($fabric_name);
      print LOGFILE "   <FCHost$counter>\n";
      print LOGFILE "     <Name>$line</Name>\n";
      print LOGFILE "     <PortName>$port_name</PortName>\n";
      print LOGFILE "     <NodeName>$node_name</NodeName>\n";
      print LOGFILE "     <FabricName>$fabric_name</FabricName>\n";
      print LOGFILE "     <PortSpeed>$card_speed</PortSpeed>\n";
      print LOGFILE "   </FCHost$counter>\n";
      $counter++; 
     }
    }
  }
  print LOGFILE "  </FiberChannel>\n";
 closedir(FCHOST);
}
#***********************************************************************
# Display the services information using chkconfig --list
#***********************************************************************
sub chkconfig {
 print LOGFILE "   <SysServices>\n";
 @chkconfig = `/sbin/chkconfig --list`;
 foreach $line (@chkconfig) {
  if ( $line =~ /3:/ )
  {
   $chkconfig = $line;
   $chkconfig =~ s/\s+/:/g;
   ($service,undef,$rl0,undef,$rl1,undef,$rl2,undef,$rl3,undef,$rl4,undef,$rl5,undef,$rl6) = split /:/, $chkconfig;
   $service =~ s/://g;
   chomp($service);
   if ( $service =~ /smb/ )
   {
     $smb = "yes";
   } 
#   print LOGFILE "     <SERVICE>$service</SERVICE>\n";
   print LOGFILE "      <$service>\n";
   print LOGFILE "         <DisplayName>$service</DisplayName>\n";
   print LOGFILE "         <RUNLEVEL_0>$rl0</RUNLEVEL_0>\n";
   print LOGFILE "         <RUNLEVEL_1>$rl1</RUNLEVEL_1>\n";
   print LOGFILE "         <RUNLEVEL_2>$rl2</RUNLEVEL_2>\n";
   print LOGFILE "         <RUNLEVEL_3>$rl3</RUNLEVEL_3>\n";
   print LOGFILE "         <RUNLEVEL_4>$rl4</RUNLEVEL_4>\n";
   print LOGFILE "         <RUNLEVEL_5>$rl5</RUNLEVEL_5>\n";
   print LOGFILE "         <RUNLEVEL_6>$rl6</RUNLEVEL_6>\n";
   print LOGFILE "      </$service>\n";
  }
 if ( $line =~ /(w+)+(w+)/) {
   print $line;
 }
 }
 print LOGFILE "   </SysServices>\n";

}
#***********************************************************************
# Check if samba is enabled.
#***********************************************************************
sub samba {
  print LOGFILE "  <Samba>\n";
  if ( $smb =~ /yes/ )
  {
   print LOGFILE "    <AT_SYSTEM_BOOT>yes</AT_SYSTEM_BOOT>\n";
   @smbstatus = `/usr/bin/smbstatus -S | egrep -v 'Service|---'`;
    foreach $line (@smbstatus) {
	($smb_share,undef,$machine,$wday,$month,$time,$year) = split /\s+/, $line;
	print LOGFILE "    <SHARE>$smb_share</SHARE>\n";
	print LOGFILE "    <REMOTE_MACHINE>$machine</REMOTE_MACHINE>\n";
	print LOGFILE "    <CONNECTION_TIME>$wday $month $time $year</CONNECTION_TIME>\n";
    }
  }else {
   print LOGFILE "    <AT_BOOT>no</AT_BOOT>\n";
  }
  print LOGFILE "  </Samba>\n";
}
#***********************************************************************
# Display any NFS mounts on the system.
#***********************************************************************
sub nfs_mounts {
   print LOGFILE "  <NetworkFilesystem>\n";
   @nfs_mounts = `mount | grep nfs | grep "type nfs"`;
   my $counter = 0;
   foreach $line (@nfs_mounts) {
     ($remote_host,undef,$local_mp,undef,undef,$options) = split /\s+/,$line;
     print LOGFILE "    <REMOTE_SHARE$counter>$remote_host</REMOTE_SHARE$counter>\n";
     print LOGFILE "    <LOCAL_MOUNT_POINT$counter>$local_mp</LOCAL_MOUNT_POINT$counter>\n";
     print LOGFILE "    <OPTIONS$counter>$options</OPTIONS$counter>\n";
     $counter++;
   }
   print LOGFILE "  </NetworkFilesystem>\n";
}
#***********************************************************************
# Check status of SELINUX from config file and on running system.
#***********************************************************************
sub selinux {
   $selinux_file = "/etc/selinux/config";
  if ( -e $selinux_file ) {
   $selinux_stat = `/usr/sbin/getenforce`;
   $selinux_conf = `/bin/grep "^SELINUX=" /etc/selinux/config`;
   $selinux_type = `/bin/grep "^SELINUXTYPE=" /etc/selinux/config`;
   $selinux_defs = `/bin/grep "^SETLOCALDEFS=" /etc/selinux/config`;
   chomp($selinux_stat);
   chomp($selinux_conf);
   chomp($selinux_type);
   chomp($selinux_defs);

   (undef,$selinux_conf1) = split /=/, $selinux_conf;
   (undef,$selinux_type1) = split /=/, $selinux_type;
   (undef,$selinux_defs1) = split /=/, $selinux_defs;

 
   print LOGFILE "  <SELinux>\n";
   print LOGFILE "     <STATUS>$selinux_stat</STATUS>\n";
   print LOGFILE "     <CONFIG_FILE>\n";
   print LOGFILE "      <CONFIG_STATUS>$selinux_conf1</CONFIG_STATUS>\n";
   print LOGFILE "      <CONFIG_TYPE>$selinux_type1</CONFIG_TYPE>\n";
   print LOGFILE "      <CONFIG_DEFS>$selinux_defs1</CONFIG_DEFS>\n";
   print LOGFILE "     </CONFIG_FILE>\n";
   print LOGFILE "  </SELinux>\n";
  }
}
#***********************************************************************
# Get information contained in /etc/nsswitch.conf, all # and empty lines
# are ignored.
#***********************************************************************
sub nsswitch {
   $nsswitch_conf = "/etc/nsswitch.conf";
   print LOGFILE "  <NSSWITCH>\n";
   if ( -e $nsswitch_conf ) {
    @nsswitch_config = `/bin/cat $nsswitch_conf`;
    foreach $line (@nsswitch_config) {
     if ($line !~ /^#/ ) {
      if ($line !~ /^$/ ) {
        @nsserv = split /:/, $line;
        print LOGFILE "    <SERVICE>$nsserv[0]</SERVICE>\n";
        # Dropps first element in @nsserv
        shift(@nsserv);
        foreach $line (@nsserv) {
        chomp($line);
        $line = trim($line);
         print LOGFILE "    <LOOKUP>$line</LOOKUP>\n";
        }
     }
     }
    }
   }
   print LOGFILE "  </NSSWITCH>\n";
}
#***********************************************************************
# Display contents of /etc/resolv.conf
#***********************************************************************
sub resolv {
 $countNs = 0;
 #$countS = 0;
 print LOGFILE "  <RESOLV>\n";
 @resolv = `/bin/cat /etc/resolv.conf` ;
 for $line (@resolv) {
  if ($line =~ /nameserver/ ) {
   (undef, $nameserver) = split /\s+/, $line;
   print LOGFILE "     <NAMESERVER_$countNs>$nameserver</NAMESERVER_$countNs>\n";
   $countNs++;
  }elsif ( $line =~ /search/ ) {
   # @search = split /\s+/, $line;
   # foreach $line (@search) {
   #  if ($line !~ /search/ ) {
      #print LOGFILE "     <SEARCH_DOMAIN_$countS>$line<SEARCH_DOMAIN_$countS>\n";
      print LOGFILE "     <SEARCH_DOMAIN>$line</SEARCH_DOMAIN>\n";
   #   $countS++;
   #  }
    #}

  }   
 }
 print LOGFILE "  </RESOLV>\n";
}
#***********************************************************************
# Display contents of /etc/hosts
#***********************************************************************
sub hosts {
   $hosts = "/etc/hosts";
   print LOGFILE "     <hosts>\n";
   if ( -e $hosts ) {
    @hosts = `/bin/cat $hosts`;
    foreach $line (@hosts) {
     if ($line !~ /^#/ ) {
      if ($line !~ /^$/ ) {
       chomp($line);
        print LOGFILE "         <Entry>$line</Entry>\n";
      }
     }
    }
   }
   print LOGFILE "     </hosts>\n";
}
#***********************************************************************
# Display the contents of /etc/modprobe.conf and the current loaded modules.
# on the system.
#***********************************************************************
sub kernel {
   $modprobe = "/etc/modprobe.conf";
   print LOGFILE "  <Kernel>\n";
   print LOGFILE "    <ModprobeFile>\n";
   if ( -e $modprobe ) {
    @modprobe = `/bin/cat $modprobe`;
    foreach $line (@modprobe) {
     if ($line !~ /^#/ ) {
      if ($line !~ /^$/ ) {
       chomp($line);
        print LOGFILE "         <Entry>$line</Entry>\n";
      }
     }
    }
   }
   print LOGFILE "     </ModprobeFile>\n";
   print LOGFILE "     <LoadedModules>\n";
    @lsmod = `/sbin/lsmod`;
    # remove the first element in the array.
    shift(@lsmod);
    foreach $line (@lsmod) {
     chomp($line);
     print LOGFILE "      <Loaded>$line</Loaded>\n";
    }
    print LOGFILE "     </LoadedModules>\n";
   print LOGFILE "  </Kernel>\n";
}

#***********************************************************************
# Display the snmp information on the system.
#***********************************************************************
sub snmp {
  $snmpdconf = "/etc/snmp/snmpd.conf";
   print LOGFILE "  <SNMP>\n";
   if ( -e $snmpdconf ) {
    @snmpdconf = `/bin/cat $snmpdconf`;
   print LOGFILE "    <Config>\n";
    foreach $snmpline (@snmpdconf) {
     if ($snmpline !~ /^#/ ) {
      if ($snmpline !~ /^$/ ) {
        chomp($snmpline);
           $snmpline =~ s/&/\&amp;/g;
           $snmpline =~ s/>/\&gt;/g;
           $snmpline =~ s/</\&lt;/g;
        print LOGFILE "         <Entry>$snmpline</Entry>\n";
      }
     }
    }
   }
   print LOGFILE "    </Config>\n";
   print LOGFILE "  </SNMP>\n";
}
#***********************************************************************
# Display any crontab files and there contents.
#***********************************************************************
sub cron {
  $crondir = "/var/spool/cron";
  print LOGFILE "  <ScheduledTasks>\n";
  print LOGFILE "    <Crontab>\n";
  opendir(CRONDIR, "$crondir") || die("Cannot open directory");
  @files = readdir(CRONDIR);
  # remove the . from the array
  #shift(@files);
  # remove the .. from the array
  #shift(@files);
  $size = scalar(@files);
  my $Count = 1;
  my $counter = 0;
  #print LOGFILE "@files array is $size in size";
  foreach $user (@files) {
   if (( $user !~ /\./ ) && ( $user !~ /\.\./ )) {
    #print LOGFILE "        <UserFile_$Count>\n";
    print LOGFILE "        <UserFile$counter>\n";
    open(CRON, "$crondir/$user") || die("Cannot open $crondir/$user");
    @cron_entries=<CRON>;
    print LOGFILE "            <User>$user</User>\n";
    foreach $entry (@cron_entries) {
    $entry =~ s/&/\&amp;/g;
    $entry =~ s/>/\&gt;/g;
    $entry =~ s/</\&lt;/g;
      chomp($entry);
      print LOGFILE "            <Task>$entry</Task>\n";
    close(CRON);
    if ( $size !~ /$Count/ ) {
      $Count++;
    }
    }
    print LOGFILE "        </UserFile$counter>\n";
    #print LOGFILE "        </UserFile_$Count>\n";
   }
  closedir(CRONDIR);
 }
  print LOGFILE "    </Crontab>\n";
  print LOGFILE "  </ScheduledTasks>\n";
}

#***********************************************************************
# Display all installed packages on the system.
#***********************************************************************
sub packageinfo {
    my @package_list = `/usr/bin/yum list installed 2> /dev/null`;
    foreach $package (@package_list) {
     if ( $package =~ /installed/ ) {
        ($package,$version,undef) = split /\s+/, $package;
        if ( $package =~ /TIVsm-BA/ ) {
            $tsm = "installed";
            $tsm_package = $package;
	    $tsm_version = $version;
        }
        print LOGFILE "    <PackageName>$package</PackageName>\n";
        print LOGFILE "    <PackageVersion>$version</PackageVersion>\n";
     }
    }
}
     
#***********************************************************************
# Function used to trim any whitespace from a variable passed into it.
#***********************************************************************
sub trim($)
{
	my $string = shift;
        chomp($string);
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
sub tsm () {
   if ( $tsm =~ /installed/ ) {
   print LOGFILE "    <Package>$tsm_package</Package>\n";
   print LOGFILE "    <Status>installed</Status>\n";
   print LOGFILE "    <Version>$tsm_version</Version>\n";
   $tsm_ops_dir = "/opt/tivoli/tsm/client/ba/bin";
    print LOGFILE "   <ConfigFiles>\n";
    if ( -e $tsm_ops_dir ) {
      @tsm_conf = qw(dsm.opt dsm.sys inclexcl);
      foreach  $tsm_file (@tsm_conf) {
       if ( -e "$tsm_ops_dir/$tsm_file" ) {
        open(TSM, "$tsm_ops_dir/$tsm_file" ) || die("Cannot open $tsm_ops_dir/$tsm_file");
        @TSM_file=<TSM>;
        close(TSM);
         print LOGFILE "    <$tsm_file>\n";
         foreach $file_line (@TSM_file) {
          chomp($file_line);
          print LOGFILE "          <Entry>$file_line</Entry>\n";
	 }
        print LOGFILE "    </$tsm_file>\n";
 	} else {
	  print LOGFILE "      <$tsm_file>No File Found</$tsm_file>\n";
        }
      }
    }
   print LOGFILE "   </ConfigFiles>\n";
   } else {
    print LOGFILE "    <Status>Not Installed</Status>\n";
   }
}
sub user {
    @files = qw( passwd group sudoers );
    foreach $file_line (@files) {
     if ( -e "/etc/$file_line" ) {
        print LOGFILE "    <$file_line>\n";
        open(FILE, "/etc/$file_line" ) || die("Cannot open /etc/$file_line");
	@File_list=<FILE>;
	close(FILE);
	foreach $line_in_file (@File_list) {
	 chomp($line_in_file);
	 print LOGFILE "          <Entry>$line_in_file</Entry>\n";
	}
      print LOGFILE "    </$file_line>\n";
     } else {
	print LOGFILE "    <$file_line>Doesn't Exist</$file_line>\n";  
     }
    }
}
     
   
#***********************************************************************
#
#				END OF SCRIPT
#
#***********************************************************************
