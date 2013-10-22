#!/bin/bash
#
#  Written by Austin Murphy, 2010 - 2012
#
#  Functions to retrieve system information from remote servers (or localhost).
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
# cat /etc/redhat-release  OR  cat /etc/debian_version  (oracle, gentoo)
# uname -a
# ifconfig -a
# dig
# df
# mount
# echo / grep / sed / awk / bc


#echo "USER: $USER"

# 
# Allow local or remote servers as root or with sudo
# 
if [[ "$SERVER" == "-l" || "$SERVER" == "localhost" ]] 
then
  if [[ "$UID" -eq 0 ]]
  then
    function ssh_cmd () {
      ${1}
    }
  else
    echo "ERROR -- This script requires root privileges. "
    exit
  fi
else
  # old syntax - couldn't deal with spaces in ssh command - bash advice is to use a function
  #SSHCMD="ssh root@$SERVER "

  function ssh_cmd () {
    # direct root
    ssh -o "ControlMaster auto" -o "ControlPath /tmp/%h-%p-%r.ssh" -o "ControlPersist 15"  root@$SERVER  ${1}

    # root via normal user with password-less sudo 
    #ssh -o "ControlMaster auto" -o "ControlPath /tmp/%h-%p-%r.ssh" -o "ControlPersist 15" -t $USER@$SERVER \'sudo ${1}\'
    #ssh -t $USER@$SERVER sudo ${1}
  }
fi

# user + NOPASSWD: sudo on remote system  style
# ssh -t $SERVER sudo ${1}



# example usage:
#SVRNAME=$( ssh_cmd "hostname -s" )
#SVRDOM=$( ssh_cmd "hostname -d" )


#exit


 
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

  SVRNAME=$( ssh_cmd "hostname -s" )
  SVRDOMAIN=$( ssh_cmd "hostname -d" )
 
}


#
# Platform
#

# associative array, keyed on "'manf', 'product', 'fwver', 'serial', 'warrexp'
declare -A PLATFORM

function rtrv_platform_info {
  
  # I would like to use just this first cmd, but it is easier to parse the versions with the -s flags)
  DMIDECODE=$( ssh_cmd "dmidecode" )
  #
  #  NOTE: The -s switches to dmidecode do NOT work with the default RHEL 4 or 5 versions of dmidecode 
  #        updated versions of kernel-utils (rhel4) and dmidecode (rhel5) are available
  #                         
  DMI_MANF=$( ssh_cmd "dmidecode -s system-manufacturer")
  DMI_PROD=$( ssh_cmd "dmidecode -s system-product-name")
  DMI_BIOS=$( ssh_cmd "dmidecode -s bios-version")
  DMI_SERIAL=$( ssh_cmd "dmidecode -s system-serial-number")

  PLATFORM['manf']=$(echo "$DMI_MANF" | sed -e "s/ Inc.//" -e "s/ Computer Corporation//" -e "s/,//" -e "s/System Manufacturer/Generic/" -e "s/ Corporation//" )
  PLATFORM['product']=$(echo "$DMI_PROD" | sed -e "s/VMware Virtual Platform/Virtual Machine/" \
                          -e "s/System Product Name/Server/" \
                          -e "s/ *$//" \
                          -e "s/^ *IBM *//" \
                          -e "s/System //" \
                          -e "s/-\[/(/" -e "s/\]-/)/" )
  PLATFORM['fwver']=$(echo "$DMI_BIOS" | sed -e "s/-\[//" -e "s/\]-//" -e "s/ *$//")
  PLATFORM['serial']=$(echo "$DMI_SERIAL" | \
      sed -e "s/System Serial Number/---/" \
          -e "s/^ *//" \
          -e "s/ *$//" \
          -e "s/-\[//" \
          -e "s/\]-//")

  # Check warranty expiration for Dell
  PLATFORM['warrexp']='X'

  if [[ -x $DELL_WARR_TOOL ]]
  then
    if [ ${PLATFORM['manf']} == "Dell" ]
    then
      PLATFORM['warrexp']=$($DELL_WARR_TOOL ${PLATFORM['serial']})
    fi
  fi
  


}




#
# CPUs
#

# associative array, keyed on "'manf', 'fam', 'freq', 'num', 'numfree'
declare -A CPUS

function rtrv_cpu_info {

  DMIDECODE_CPU=$( ssh_cmd "dmidecode -s processor-version" )
  
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
    CPUINFO=$( echo "$DMIDECODE_CPU" | grep -E -v '00000000|Not Spec'  | head -n 1 | \
        sed -e "s/(R)//g" \
            -e "s/(TM)//g" \
            -e "s/(tm)//g" \
            -e "s/ 0 \@/ @/" )
    CPUS['manf']=$(echo "$CPUINFO" | sed -e "s/ .*$//" )
    CPUS['fam']=$( echo "$CPUINFO" | sed -e "s/^\S* //" -e "s/ *\@.*$//" -e "s/CPU *//" )
    CPUS['freq']=$(echo "$CPUINFO" | sed -e "s/^.*\@ //" -e "s/GHz/ GHz/" )
  else
    # old style
    # assumes that all procs are the same
    # processor-version does not include good info (VMs, old hardware)

    DMI_PROC_MANF=$( ssh_cmd "dmidecode -s processor-manufacturer | sed -e \"s/ *$//\"")
    DMI_PROC_FAM=$(  ssh_cmd "dmidecode -s processor-family       | sed -e \"s/ *$//\"")
    DMI_PROC_VER=$(  ssh_cmd "dmidecode -s processor-version      | sed -e \"s/ *$//\"")
    DMI_PROC_FREQ=$( ssh_cmd "dmidecode -s processor-frequency    | sed -e \"s/ *$//\"")
 
    CPUS['num']=$(echo "$DMI_PROC_MANF" | grep -E -v '00000000|Not Spec' | wc -l)
    NUMTOTAL=$(echo "$DMIDECODE" | grep "Socket Designation" | grep -E "CPU|PROC" | wc -l)
    CPUS['numfree']=$(echo "$NUMTOTAL-${CPUS['num']}" | bc)
    CPUS['manf']=$(echo "$DMI_PROC_MANF" | head -n 1 | sed -e "s/Genuine//" )

    if [ ${CPUS['manf']} == "AMD" ] 
    then
      CPUS['fam']=$(echo "$DMI_PROC_VER" | head -n 1 | sed -e "s/AMD //" -e "s/(TM)//" -e "s/Processor //")
    else
      CPUS['fam']=$(echo "$DMI_PROC_FAM" | head -n 1 )
    fi
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
  MEM['max']=$(echo "$DMIDECODE" | grep "Maximum Capacity" | sed -e "s/^.*: //" | tr '\n' '+' | sed -e 's/+$//' -e 's/+/ + /' )
  MEMTOTKB=$( ssh_cmd "cat /proc/meminfo | grep 'MemTotal' | awk '{print \$2}' " )
  MEM['totmb']=$(echo "$MEMTOTKB/1024" | bc)
  

}

 
#
# OS 
#

# associative array, keyed on "'brand', 'product', 'ver', 'arch', 'yumrepos'
declare -A OS

function rtrv_os_info {

  DEBVER=$( ssh_cmd "cat /etc/debian_version 2> /dev/null")
  GENREL=$( ssh_cmd "cat /etc/gentoo-release 2> /dev/null")
  ORAREL=$( ssh_cmd "cat /etc/oracle-release 2> /dev/null")
  RHREL=$( ssh_cmd "cat /etc/redhat-release 2> /dev/null")
  LARCH=$( ssh_cmd "uname -m")
  REPOS=$($YUM_REPO_TOOL $SERVER)
  

  OS['brand']="Unknown"

  # RHEL & Clones
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
  # Oracle Enterpise Linux has both a redhat-relase file and an oracle-release file
  echo "$ORAREL" | grep -q "Oracle Linux Server" 
  if  [ $? == '0' ]
  then
    OS['brand']="OEL"
  fi

  OS['product']=$(echo "$RHREL" | sed -e "s/Red Hat Enterprise Linux//" -e "s/CentOS/Linux/" -e "s/release.*$//" -e "s/  / /g" -e "s/^ *//" -e "s/ *$//")
  OS['ver']=$(echo "$RHREL" | sed -e "s/[a-zA-Z()]//g" -e "s/\([0-9]\) *\([0-9][0-9]?\)/\1.\2/" -e "s/^ *//" -e "s/ *$//" )


  # Gentoo
  echo "$GENREL" | grep -q "Gentoo" 
  if  [ $? == '0' ]
  then
    OS['brand']="Gentoo"
    OS['product']=$(echo "$GENREL" | sed -e "s/Gentoo//" -e "s/release.*$//" -e "s/  / /g" -e "s/^ *//" -e "s/ *$//")
    OS['ver']=$(echo "$GENREL" | sed -e "s/[a-zA-Z()]//g" -e "s/\([0-9]\) *\([0-9][0-9]?\)/\1.\2/" -e "s/^ *//" -e "s/ *$//" )
  fi


  # Debian
  echo "$DEBVER" | grep -q -E "wheezy|jessie|sid" 
  if  [ $? == '0' ]
  then
    OS['brand']="Debian"
    OS['product']=""
    OS['ver']="$DEBVER"
  fi


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

  REMETCHOSTS=$( ssh_cmd "cat /etc/hosts")
  REMIFCONFIG=$( ssh_cmd "/sbin/ifconfig -a")

  IFACES=$(echo "$REMIFCONFIG" |  grep 'HWaddr' | awk '{print $1}' )
  
  for IFACE in $IFACES
  do

    # iface --> mac
    #
    MAC=$(echo "$REMIFCONFIG" | grep "^$IFACE " | sed -e "s/^.*HWaddr //" | sed -e "s/ *$//")
    MACS[$IFACE]="$MAC"

    
    # iface --> privip  
    #
    PRIVIP=$(echo "$REMIFCONFIG" | grep -A1 "^$IFACE " | tail -n1 | grep -v 'inet6' | sed -e "s/^.*addr://" -e "s/  .*$//")
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
      DNSNAME=$(echo "$REMETCHOSTS" |  grep "^$PRIVIP" | head -n 1 | awk '{print $2}')
      N=$(echo "$REMETCHOSTS" |  grep "^$PRIVIP" | wc -l)
      #  maybe the IP is commented out
      [[ "$N" -eq 0 ]] && DNSNAME=$(echo "$REMETCHOSTS" |  grep "^#*$PRIVIP" | head -n 1 | awk '{print $2}' )
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
 
  DFOUT=$( ssh_cmd "df -Ph -x tmpfs -x devtmpfs -x rootfs | grep -v \"Filesystem\" ")
  MOUNTOUT=$( ssh_cmd "mount" )

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
