#!/bin/bash
#
#  Get the yum repos that a system is configured to use
#
#  Condense and reformat the list to reduce redundancy and eliminate TMI
#

SERVER=$1

if [ "$SERVER" == "" ]
then
  echo "No Server specified"
  exit 1
fi

#
# Allow local or remote servers as root or with sudo
#
if [[ "$SERVER" == "-l" || "$SERVER" == "localhost" ]]
then
  if [[ "$UID" -eq 0 ]]
  then
    #SSHCMD=""
    function ssh_cmd () {
      ${1}
    }
  else
    echo "ERROR -- This script requires root privileges. "
    exit
  fi
else
  #SSHCMD="ssh root@$SERVER "
  function ssh_cmd () {
    # direct root
    ssh -o "ControlMaster auto" -o "ControlPath /tmp/%h-%p-%r.ssh" -o "ControlPersist 15"  root@$SERVER  ${1}

    # root access via normal user w/ password-less sudo
    #ssh -t -o "ControlMaster auto" -o "ControlPath /tmp/%h-%p-%r.ssh" -o "ControlPersist 15"  $USER@$SERVER "sudo ${1}"
    #ssh -q -t  $USER@$SERVER "sudo ${1}"
  }
fi


#  Full command output
#YUMREPOALL=$( $SSHCMD yum repolist all 2>/dev/null )
YUMREPOALL=$( ssh_cmd "yum repolist all 2>/dev/null" )
if [ $? -ne 0 ] 
then
    echo "not applicable"
else
  
    #  Full list of actual repos
    REPOS=$(echo "$YUMREPOALL" | \
        grep -v -E "^repo|^Load|^Updat|^This system|^Determi|^ \*" | \
        awk '{print $1}' )
    
    # Filtered list of repos
    FILTEREDREPOS=$( echo "$REPOS" | \
        grep -E -v "beta|debug|extras|source|testing" | \
        sed -e  "s/^C[[:digit:]]\.[[:digit:]]-//" \
            -e "s/-i386-server//" \
            -e "s/-x86_64-server//" \
            -e "s/_x86_64_latest//" \
            -e "s/-5$//" \
            -e "s/^rhel-6-server-rpms/base/" \
            -e "s/^rhel-6-server-//" \
            -e "s/^rhel-server-//" \
            -e "s/^local-.*/local/" \
            -e "s/-rpms$//" \
            -e "s/-indep$//" \
            -e "s/-specific//" \
            -e "s/^jpackage.*$/jpackage/" | \
        sort -u )
    
    # format the output for a single line
    for i in $FILTEREDREPOS 
    do
      echo -n "$i, "
    done  | sed -e "s/, $//"
    echo ""
    
fi
