#!/bin/bash
#
#  Written by Austin Murphy, 2010 - 2012
#
#  Functions to retrieve system information from remote serversi (or localhost).
#
#
#  Note:  ROOT access via password-less SSH is required.  
#
#  Note:  Recent version of "dmidecode" required on remote server
#
#  Note:  Public DNS names for all active network interfaces 
#         on a server must be documented properly in that server's 
#         /etc/hosts file.  Also 127.0.0.1 may only refer to
#         localhost.localdomain localhost.
#
#


#
# Helpers
#

DELL_WARR_TOOL="./dell-warr-expires.py"

# This tool is specific to UPenn. 
# Regular DNS does not support "reverse" CNAME lookups
#
CNAME_TOOL="./getCNAMEs.py"

# reports a simplified list of yum repos configured on a server
YUM_REPO_TOOL="./get-yum-repos.sh"


# dmidecode
# cat /proc/meminfo
# cat /etc/redhat-release  OR  cat /etc/debian_version
# uname -a
# ifconfig -a
# dig
# df
# mount
# echo / grep / sed / awk / bc

# 
# Allow local or remote servers as root or with sudo
# 
if [[ "$SERVER" == "-l" || "$SERVER" == "localhost" ]] 
then
  if [[ "$UID" -eq 0 ]]
  then
    SSHCMD=""
  else
    echo "ERROR -- This script requires root privileges. "
    exit
  fi
else
  SSHCMD="ssh root@$SERVER "
fi

 
##############################################
#
# Retrieve info about the server in question
#
##############################################


#
# Hostname
#

SVRNAME=""
SVRDOMAIN=""

function rtrv_name_info {
  SVRNAME=$( $SSHCMD hostname -s)
  SVRDOMAIN=$( $SSHCMD hostname -d)

}


#
# Platform
#

# associative array, keyed on "'manf', 'product', 'fwver', 'serial', 'warrexp'
declare -A PLATFORM

function rtrv_platform_info {
  
  # I would like to use just this first cmd, but it is easier to parse the versions with the -s flags)
  DMIDECODE=$( $SSHCMD dmidecode )
  #
  #  NOTE: The -s switches to dmidecode do NOT work with the default RHEL 4 or 5 versions of dmidecode 
  #        updated versions of kernel-utils (rhel4) and dmidecode (rhel5) are available
  #                         
  DMI_MANF=$( $SSHCMD dmidecode -s system-manufacturer)
  DMI_PROD=$( $SSHCMD dmidecode -s system-product-name)
  DMI_BIOS=$( $SSHCMD dmidecode -s bios-version)
  DMI_SERIAL=$( $SSHCMD dmidecode -s system-serial-number)

  PLATFORM['manf']=$(echo "$DMI_MANF" | sed -e "s/ Inc.//" -e "s/ Computer Corporation//" -e "s/,//" -e "s/System Manufacturer/Generic/")
  PLATFORM['product']=$(echo "$DMI_PROD" | sed -e "s/VMware Virtual Platform/Virtual Machine/" -e "s/System Product Name/Server/" -e "s/ *$//")
  PLATFORM['fwver']=$DMI_BIOS
  PLATFORM['serial']=$(echo "$DMI_SERIAL" | sed -e "s/System Serial Number/---/" -e "s/^ *//" -e "s/ *$//")

  # Check warranty expiration for Dell
  PLATFORM['warrexp']='X'

  if [[ -x $DELL_WARR_TOOL ]]
  then
    if [ ${PLATFORM['manf']} == "Dell" ]
    then
      PLATFORM['warrexp']=$($DELL_WARR_TOOL ${PLATFORM['serial']})
    fi
  fi
  

  # TODO:  check for  /etc/debian_version

}




#
# CPUs
#

# associative array, keyed on "'manf', 'fam', 'freq', 'num', 'numfree'
declare -A CPUS

function rtrv_cpu_info {

  DMIDECODE_CPU=$( $SSHCMD dmidecode -s processor-version )
  
  # accomidate older CPU info
  echo "$DMIDECODE_CPU" | grep -q '@'
  OLDSTYLE=$?
  if  [ $OLDSTYLE == '0' ] 
  then
    # new style
    # assumes that all procs are the same
    # processor-version contains good info
    CPUS['numfree']=$(echo "$DMIDECODE_CPU" | grep -E '00000000|Not Spec' | wc -l )
    CPUS['num']=$(echo "$DMIDECODE_CPU" | grep -E -v '00000000|Not Spec' | wc -l )
    CPUINFO=$( echo "$DMIDECODE_CPU" | grep -E -v '00000000|Not Spec'  | head -n 1 | sed -e "s/(R)//g" -e "s/(TM)//g" -e "s/(tm)//g" )
    CPUS['manf']=$(echo "$CPUINFO" | sed -e "s/ .*$//" )
    CPUS['fam']=$( echo "$CPUINFO" | sed -e "s/^\S* //" -e "s/ *\@.*$//" -e "s/CPU *//" )
    CPUS['freq']=$(echo "$CPUINFO" | sed -e "s/^.*\@ //" -e "s/GHz/ GHz/" )
  else
    # old style
    # assumes that all procs are the same
    # processor-version does not include good info (VMs, old hardware)

    DMI_PROC_MANF=$( $SSHCMD dmidecode -s processor-manufacturer | sed -e "s/ *$//")
    DMI_PROC_FAM=$(  $SSHCMD dmidecode -s processor-family       | sed -e "s/ *$//")
    DMI_PROC_FREQ=$( $SSHCMD dmidecode -s processor-frequency    | sed -e "s/ *$//")
 
    CPUS['num']=$(echo "$DMI_PROC_MANF" | grep -E -v '00000000|Not Spec' | wc -l)
    NUMTOTAL=$(echo "$DMIDECODE" | grep "Socket Designation" | grep -E "CPU|PROC" | wc -l)
    CPUS['numfree']=$(echo "$NUMTOTAL-${CPUS['num']}" | bc)
    CPUS['manf']=$(echo "$DMI_PROC_MANF" | head -n 1 | sed -e "s/Genuine//" )
    CPUS['fam']=$(echo "$DMI_PROC_FAM" | head -n 1 )
    CPUS['freq']=$(echo "$DMI_PROC_FREQ" | head -n 1 )
  fi

}



#
# Memory
#

# associative array, keyed on "'totmb', 'nummods', 'modsize', 'max'
declare -A MEM

function rtrv_mem_info {

  # 
  # uses $DMIDECODE from rtrv_platform_info
  # 
  # Assumes all modules are the same size
  #
  MEM['nummods']=$(echo "$DMIDECODE" | grep "^\s*Size.*B" | wc -l )
  MEM['modsize']=$(echo "$DMIDECODE" | grep "^\s*Size.*B" | sed -e "s/^.*: //" | head -n 1)
  MEM['max']=$(echo "$DMIDECODE" | grep "Maximum Capacity" | sed -e "s/^.*: //" )
  MEMTOTKB=$( $SSHCMD cat /proc/meminfo | grep "MemTotal" | awk '{print $2}' )
  MEM['totmb']=$(echo "$MEMTOTKB/1024" | bc)
  

}

 
#
# OS 
#

# associative array, keyed on "'brand', 'product', 'ver', 'arch', 'yumrepos'
declare -A OS

function rtrv_os_info {

  # Future fun ...
  #DEBVER=$( $SSHCMD cat /etc/debian_version 2> /dev/null)
 
  RHREL=$( $SSHCMD cat /etc/redhat-release 2> /dev/null)
  LARCH=$( $SSHCMD uname -m)
  REPOS=$($YUM_REPO_TOOL $SERVER)
  

  OS['brand']="Unknown"
  echo "$RHREL" | grep -q "Red Hat Enterprise Linux" 
  if  [ $? == '0' ]
  then
    OS['brand']="RHEL"
  fi
  echo "$RHREL" | grep -q "CentOS"
  if  [ $? == '0' ]
  then
    OS['brand']="CentOS"
  fi

  OS['product']=$(echo "$RHREL" | sed -e "s/Red Hat Enterprise Linux//" -e "s/CentOS/Linux/" -e "s/release.*$//" -e "s/  / /g" -e "s/^ *//" -e "s/ *$//")

  OS['ver']=$(echo "$RHREL" | sed -e "s/[a-zA-Z()]//g" -e "s/\([0-9]\) *\([0-9]\)/\1.\2/" -e "s/^ *//" -e "s/ *$//" )

  OS['arch']=$LARCH

  OS['yumrepos']=$REPOS

}


#
# Network 
#

IFACES=""
# associative arrays (keyed on $IFACE)
declare -A DNSNAMES
declare -A PUBIPS
declare -A PRIVIPS
declare -A MACS
# used later:
DNSLIST=""

function rtrv_network_info {

  REMETCHOSTS=$( $SSHCMD cat /etc/hosts)
  REMIFCONFIG=$( $SSHCMD /sbin/ifconfig -a)

  IFACES=$(echo "$REMIFCONFIG" |  grep 'HWaddr' | awk '{print $1}' )
  
  for IFACE in $IFACES
  do

    # iface --> mac
    #
    MAC=$(echo "$REMIFCONFIG" | grep "$IFACE " | sed -e "s/^.*HWaddr //" | sed -e "s/ *$//")
    MACS[$IFACE]="$MAC"

    
    # iface --> privip  
    #
    PRIVIP=$(echo "$REMIFCONFIG" | grep -A1 "$IFACE " | tail -n1 | grep -v 'inet6' | sed -e "s/^.*addr://" -e "s/  .*$//")
    if [ "$PRIVIP" == "" ] 
    then
      PRIVIP="--"
    fi
    PRIVIPS[$IFACE]="$PRIVIP"
    #
    #  TODO:  IPv6
  

    # privip --> dnsname 
    #
    if [ "$PRIVIP" == "--" ] 
    then
       DNSNAME="--"  
    else
      DNSNAME=$(echo "$REMETCHOSTS" |  grep "^$PRIVIP" | awk '{print $2}')
      N=$(echo "$REMETCHOSTS" |  grep "^$PRIVIP" | wc -l)
      [[ "$N" -eq 0 ]] && DNSNAME=$(echo "$REMETCHOSTS" |  grep "^#*$PRIVIP" | awk '{print $2}' | head -n1 )
      DNSLIST="$DNSLIST $DNSNAME"
    fi
    DNSNAMES[$IFACE]="$DNSNAME"
    #
    #  TODO:  DHCP dnsnames will probably not be in /etc/hosts
    

  
    # dnsname --> pubip
    # 
    if [ "$DNSNAME" == "--" ]
    then
      PUBIP="--"  
    else
      PUBIP=$(dig +short ${DNSNAME})
      NUM=$(dig +short ${DNSNAME} | wc -l)
      # too many DNS names
      [[ $NUM -gt 1 ]] && PUBIP="++"
      # no DNS name
      [[ "$PUBIP" == "" ]] && PUBIP="--"
    fi
    PUBIPS[$IFACE]="$PUBIP"


    # clean up
    #
    [[ "$PUBIP" == "$PRIVIP" ]] && PRIVIPS[$IFACE]="--"
  
  done

}


#
# CNAMEs 
#

# associative array (keyed on $DNSNAME from rtrv_network_info )
declare -A CNAMES
 
function rtrv_cname_info {
  
  if [[ -x $CNAME_TOOL ]]
  then
  
    LASTD=""
    for d in $DNSLIST
    do
      # lookup CNAMEs for each DNSname
      CNAMES[$d]=$($CNAME_TOOL $d | tr [A-Z] [a-z])
    done
    
  fi
}


#
# Mounts 
#

MOUNTPTS=""
# associative arrays (keyed on MOUNTPT)
declare -A DEVICES 
declare -A SIZES 
declare -A FSTYPES 

function rtrv_mount_info {
 
  DFOUT=$( $SSHCMD df -Ph -x tmpfs -x devtmpfs -x rootfs | grep -v "Filesystem" )
  MOUNTOUT=$( $SSHCMD mount )

  MOUNTPTS=$( echo "$DFOUT" | awk '{ print $6; }' )
  for m in $MOUNTPTS
  do
    DEVICES[$m]=$( echo "$DFOUT" | grep " $m$" | awk '{print $1}' )
    SIZES[$m]=$( echo "$DFOUT" | grep " $m$" | awk '{print $2}' )
    FSTYPES[$m]=$( echo "$MOUNTOUT" | grep " $m " | awk '{ print $5 }' )
  done
  
}



#
# END
#
