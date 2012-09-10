#!/bin/bash
#
#  Written by Austin Murphy, 2010 - 2012
#
#  Retrieve system information from a remote server and load it into a SQLite DB
#

#
#  This version of the script calls out to a subscript for the base info sub section and the cname list
#
#
#

SERVER=$1

if [ "$SERVER" == "" ]
then
  echo "No Server specified"
  exit 1
fi

RUNDATE=$(date +%s)


# SQLite DB file
DB="./server-info.db"


#
# retrieve info about the server
#

RTRVINFO="./rtrv-info.sh"

# just source the rtrv-info.sh script
#  sets a handful of associative arrays
. $RTRVINFO  







##############################
#
# Display the retrieved info
# 
##############################
 
 
 


#
# Base info - display
#

function load_base_info {


  echo "Retrieving name info..."
  rtrv_name_info

  echo "Retrieving platform info..."
  rtrv_platform_info

  echo "Retrieving CPU info..."
  rtrv_cpu_info

  echo "Retrieving Memory info..."
  rtrv_mem_info

  echo "Retrieving OS info..."
  rtrv_os_info



  echo "INSERT into domain
        VALUES('$SERVER','$RUNDATE','$SVRNAME','$SVRDOMAIN');" \
        | sqlite $DB 

  echo "INSERT into platform
        VALUES('$SERVER','$RUNDATE','${PLATFORM['manf']}','${PLATFORM['product']}','${PLATFORM['fwver']}','${PLATFORM['serial']}','${PLATFORM['warrexp']}');" \
        | sqlite $DB 

  echo "INSERT into cpus
        VALUES('$SERVER','$RUNDATE','${CPUS['manf']}','${CPUS['fam']}','${CPUS['freq']}','${CPUS['num']}','${CPUS['numfree']}');" \
        | sqlite $DB 

  echo "INSERT into mem
        VALUES('$SERVER','$RUNDATE','${MEM['totmb']}','${MEM['nummods']}','${MEM['modsize']}','${MEM['max']}');" \
        | sqlite $DB 

  echo "INSERT into os
        VALUES('$SERVER','$RUNDATE','${OS['brand']}','${OS['product']}','${OS['ver']}','${OS['arch']}','${OS['yumrepos']}');" \
        | sqlite $DB


}





#
# Network 
#

function load_network_info {

  echo "Retrieving network info..."
  rtrv_network_info


  LASTMAC=''
  
  for IFACE in $IFACES
  do

    echo "INSERT into ifaces
          VALUES('$SERVER','$RUNDATE','${DNSNAMES[$IFACE]}','${PUBIPS[$IFACE]}','${PRIVIPS[$IFACE]}','$IFACE','${MACS[$IFACE]}');" \
          | sqlite $DB

  done
  
  
}



#
# CNAMEs 
#

function load_cname_info {

  echo "Retrieving CNAMEs info..."
  rtrv_cname_info

  for d in $DNSLIST 
  do
    for c in ${CNAMES[$d]}
    do

      echo "INSERT into cnames
            VALUES('$SERVER','$RUNDATE','${c}','${d}');" \
            | sqlite $DB

    done
  done

}



#
# Mount info 
#

function load_mount_info {

  echo "Retrieving mount point info..."
  rtrv_mount_info

  for m in $MOUNTPTS
  do

    echo "INSERT into mountpts
          VALUES('$SERVER','$RUNDATE','${m}','${DEVICES[$m]}','${SIZES[$m]}','${FSTYPES[$m]}');" \
          | sqlite $DB

  done 
  
}

#create table mountpts (server, date, mountpt, device, size, fstype);


# Control what to display

load_base_info
load_network_info
load_cname_info
load_mount_info



#
# END
#
