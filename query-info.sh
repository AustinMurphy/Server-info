#!/bin/bash
#
#  Written by Austin Murphy, 2010 - 2012
#
#  Functions to query system information about servers from the servers database.
#
#



##############################################
#
# Retrieve info about the server in question
#
##############################################


# SQLite DB file
DB="./server-info.db"

DBCMD="sqlite $DB"

#
QDATE=$(echo "SELECT max(date) from cpus where server='$SERVER' ;" | $DBCMD )



 
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
  SVRNAME=$( echo "SELECT name from domain where server='$SERVER' and date='$QDATE';" | $DBCMD )
  SVRDOMAIN=$( echo "SELECT domain from domain where server='$SERVER' and date='$QDATE';" | $DBCMD )

}


#
# Platform
#

# associative array, keyed on "'manf', 'product', 'fwver', 'serial', 'warrexp'
declare -A PLATFORM

function rtrv_platform_info {
  
  PLATFORM['manf']=$( echo "SELECT manf FROM platform  where server='$SERVER' and date='$QDATE';" | $DBCMD )
  PLATFORM['product']=$(echo "SELECT product FROM platform  where server='$SERVER' and date='$QDATE';" | $DBCMD )
  PLATFORM['fwver']=$(echo "SELECT fwver FROM platform  where server='$SERVER' and date='$QDATE';" | $DBCMD )
  PLATFORM['serial']=$(echo "SELECT serial FROM platform  where server='$SERVER' and date='$QDATE';" | $DBCMD )
  PLATFORM['warrexp']=$(echo "SELECT warrexp FROM platform  where server='$SERVER' and date='$QDATE';" | $DBCMD )

}




#
# CPUs
#

# associative array, keyed on "'manf', 'fam', 'freq', 'num', 'numfree'
declare -A CPUS

function rtrv_cpu_info {

  CPUS['manf']=$(echo "SELECT manf FROM cpus  where server='$SERVER' and date='$QDATE';" | $DBCMD )
  CPUS['fam']=$(echo "SELECT fam FROM cpus  where server='$SERVER' and date='$QDATE';" | $DBCMD )
  CPUS['freq']=$(echo "SELECT freq FROM cpus  where server='$SERVER' and date='$QDATE';" | $DBCMD )
  CPUS['num']=$(echo "SELECT num FROM cpus  where server='$SERVER' and date='$QDATE';" | $DBCMD )
  CPUS['numfree']=$(echo "SELECT numfree FROM cpus  where server='$SERVER' and date='$QDATE';" | $DBCMD )

}



#
# Memory
#

# associative array, keyed on "'totmb', 'nummods', 'modsize', 'max'
declare -A MEM

function rtrv_mem_info {

  MEM['nummods']=$(echo "SELECT nummods FROM mem  where server='$SERVER' and date='$QDATE';" | $DBCMD )
  MEM['modsize']=$(echo "SELECT modsize FROM mem  where server='$SERVER' and date='$QDATE';" | $DBCMD )
  MEM['max']=$(echo "SELECT max FROM mem  where server='$SERVER' and date='$QDATE';" | $DBCMD )
  MEM['totmb']=$(echo "SELECT totmb FROM mem  where server='$SERVER' and date='$QDATE';" | $DBCMD )

}

 
#
# OS 
#

# associative array, keyed on "'brand', 'product', 'ver', 'arch', 'yumrepos'
declare -A OS

function rtrv_os_info {

  OS['brand']=$(echo "SELECT brand FROM os where server='$SERVER' and date='$QDATE';" | $DBCMD )
  OS['product']=$(echo "SELECT product FROM os where server='$SERVER' and date='$QDATE';" | $DBCMD )
  OS['ver']=$(echo "SELECT ver FROM os where server='$SERVER' and date='$QDATE';" | $DBCMD )
  OS['arch']=$(echo "SELECT arch FROM os where server='$SERVER' and date='$QDATE';" | $DBCMD )
  OS['yumrepos']=$(echo "SELECT yumrepos FROM os where server='$SERVER' and date='$QDATE';" | $DBCMD )

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

  IFACES=$(echo "SELECT DISTINCT iface FROM ifaces WHERE server='$SERVER' and date='$QDATE' ORDER BY iface ;" | $DBCMD )
  DNSLIST=$(echo "SELECT DISTINCT dnsname FROM ifaces WHERE server='$SERVER' and date='$QDATE' ORDER BY dnsname ;" | $DBCMD )
  
  for IFACE in $IFACES
  do

    DNSNAMES[$IFACE]=$(echo "SELECT dnsname FROM ifaces WHERE server='$SERVER' and date='$QDATE' and iface='$IFACE' ;" | $DBCMD )

    PUBIPS[$IFACE]=$(echo "SELECT pubip FROM ifaces WHERE server='$SERVER' and date='$QDATE' and iface='$IFACE' ;" | $DBCMD )

    PRIVIPS[$IFACE]=$(echo "SELECT privip FROM ifaces WHERE server='$SERVER' and date='$QDATE' and iface='$IFACE' ;" | $DBCMD )

    MACS[$IFACE]=$(echo "SELECT mac FROM ifaces WHERE server='$SERVER' and date='$QDATE' and iface='$IFACE' ;" | $DBCMD )
  
  done

}


#
# CNAMEs 
#

# associative array (keyed on $DNSNAME from rtrv_network_info )
declare -A CNAMES
 
function rtrv_cname_info {
  
  for d in $DNSLIST
  do
    # lookup CNAMEs for each DNSname
    CNAMES[$d]=$(echo "SELECT cname FROM cnames WHERE server='$SERVER' and date='$QDATE' and dnsname='$d' ;" | $DBCMD )
   done
    
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
 
  MOUNTPTS=$(echo "SELECT DISTINCT mountpt FROM mountpts WHERE server='$SERVER' and date='$QDATE' ORDER BY mountpt ;" | $DBCMD )
  for m in $MOUNTPTS
  do
    DEVICES[$m]=$(echo "SELECT device FROM mountpts WHERE server='$SERVER' and date='$QDATE' and mountpt='$m' ;" | $DBCMD )
    SIZES[$m]=$(echo "SELECT size FROM mountpts WHERE server='$SERVER' and date='$QDATE' and mountpt='$m' ;" | $DBCMD )
    FSTYPES[$m]=$(echo "SELECT fstype FROM mountpts WHERE server='$SERVER' and date='$QDATE' and mountpt='$m' ;" | $DBCMD )
  done
  
}




#
# END
#
