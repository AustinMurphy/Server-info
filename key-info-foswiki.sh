#!/bin/bash
#
#  Written by Austin Murphy, 2010 - 2012
#
#  Retrieve system information from a remote server and format it for FOSwiki
#

#
#  This version of the script calls out to a subscript to retrieve the data
#
#
#


# do we want the data to come from the sqlite DB or from the remote server?
DATASOURCE="SQLITE"


SERVER=$1

if [ "$SERVER" == "" ]
then
  echo "No Server specified"
  exit 1
fi

RUNDATE=$(date +%s)


#
# retrieve info about the server
#

if [[ $DATASOURCE -eq "SQLITE" ]] 
then
  RTRVINFO="./query-info.sh"
else
  RTRVINFO="./rtrv-info.sh"
fi

# source the rtrv-info.sh script
. $RTRVINFO  

#  the rtrv_* functions set a handful of associative arrays





##############################
#
# Display the retrieved info
# 
##############################
 
 
 
#
# Base info - display
#

function display_base_info {

  rtrv_name_info

  # Name
  echo "   * Name: $SVRNAME, Domain: $SVRDOMAIN"

  rtrv_platform_info

  # format for FOSwiki
  # FOSwiki makes wikilinks out of CamelCase.  DO NOT WANT

  # platform
  MANF=${PLATFORM['manf']}
  PRODF=$(   echo "${PLATFORM['product']}" | sed -e "s/PowerEdge/!PowerEdge/")
  # use fixed width font for numbers
  FWVER=${PLATFORM['fwver']}
  SERIALF=$( echo "${PLATFORM['serial']}"  | sed -e "s/^/=/" -e "s/$/=/")
  
  echo -n "   * Platform: $MANF $PRODF, BIOS: v${FWVER}, Serial: $SERIALF"
  if [ ${PLATFORM['warrexp']} != 'X' ]
  then
    echo  ", Warr. Exp: ${PLATFORM['warrexp']}"
  else
    echo  ""
  fi


  rtrv_cpu_info

  # CPU
  echo "   * CPU(s): ${CPUS['num']} x ${CPUS['manf']} ${CPUS['fam']} @ ${CPUS['freq']} CPU(s) Installed,  ${CPUS['numfree']} CPU socket(s) open"


  rtrv_mem_info

  # memory
  echo "   * Memory: ${MEM['totmb']} MB Available, ${MEM['nummods']} x ${MEM['modsize']} Modules Installed, ${MEM['max']} Max "


  rtrv_os_info

  # OS
  echo "   * OS: ${OS['brand']} ${OS['product']} ${OS['ver']} (${OS['arch']}), Repos: ${OS['yumrepos']}"

  echo ""
  
}



#
# Network 
#

function display_network_info {

  rtrv_network_info

  echo "---+++ Network interfaces"

  LASTMAC=''
  
  for IFACE in $IFACES
  do
    # format MAC...
    MAC=${MACS[$IFACE]}
    #echo "MAC: $MAC -- LASTMAC: $LASTMAC"
    [[ "$MAC" == "$LASTMAC" ]] && MACF='^' || MACF=$MAC
    echo "| =${DNSNAMES[$IFACE]}=  | =${PUBIPS[$IFACE]}=  | =${PRIVIPS[$IFACE]}=  | =$IFACE=  |  $MACF  |"
    LASTMAC=$MAC
  done
  
  
}



#
# CNAMEs 
#

function display_cname_info {

  rtrv_cname_info

  echo ""
  echo "---++++ CNAMEs "
  for d in $DNSLIST 
  do
    for c in ${CNAMES[$d]}
    do
      [[ "$d" == "$LASTD" ]]  &&  d='^'  ||  LASTD=$d 
      [[ "$d" == '^' ]]       &&  D='^'  ||  D="=${d}="
      echo "|  =${c}= |  ${D} |"
    done
  done
  echo ""

}



#
# Mount info 
#

function display_mount_info {

  rtrv_mount_info

  echo "---+++ Mounts "
  for m in $MOUNTPTS
  do
    echo "| =$m=  | =${DEVICES[$m]}=  |  =${SIZES[$m]}= |  =${FSTYPES[$m]}=  |" 
  done 
  echo ""
  
}



#
# Control what to display
#

echo "---++ Key info"

display_base_info
display_network_info
display_cname_info
display_mount_info



#
# END
#
