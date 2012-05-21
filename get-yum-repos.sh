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


#  Full command output
YUMREPOALL=$(ssh root@$SERVER yum repolist all 2>/dev/null )
if [ $? -ne 0 ] 
then
    echo "not applicable"
else
  
    #  Full list of actual repos
    REPOS=$(echo "$YUMREPOALL" | \
        grep -v -E "^repo|^Loaded|^Updat" | \
        awk '{print $1}' )
    
    # Filtered list of repos
    FILTEREDREPOS=$( echo "$REPOS" | \
        grep -E -v "debug|source|testing|extras" | \
        sed -e "s/-i386-server//" \
            -e "s/-x86_64-server//" \
            -e "s/-5$//" \
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
