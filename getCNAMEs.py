#!/usr/bin/python
#
#                          13 December 2010 - Austin Murphy
#  
#  Usage:  getCNAMES.py  fully.qualified.domain.name
#
#  simple python script to lookup CNAME records in Assignments 
#
#                           based on testclient.py from ISC 
#
#

import sys
import AsgsProtocol 


if len(sys.argv) != 2:
    print "Usage:  getCNAMES.py  fully.qualified.domain.name"
    sys.exit()



def fault(faultCode, faultString, **keywords):
    if faultCode < 0:
        name = "Warning (#%d)" % -faultCode
        print "%s:\n\n%s\n\nDo you want to continue?" % (name, faultString),
        return sys.stdin.readline()[0] == 'y'
    else:
        name = "Error (#%d)" % faultCode
        print "%s:\n\n%s\n\nCannot finish request." % (name, faultString)
        return 0

# debug_level=2 dumps generated XML-RPC to stderr
asgs = AsgsProtocol.Server(fault_handler=fault, debug_level=0)


asgs.set_user_agent('client/getCNAMEs')


# 3 params for searchResourceRecords
#      from:  http://www.upenn.edu/computing/assignments/draft-protocol23.html#asgs230.searchResourceRecords
#
# param1 - 	struct 	A structure describing the criteria to search for.
#    The struct describing the criteria contains one or more of these members:
#    Name 	Type 	Description
#    CanonicalName 	string 	A fully qualified domain name of a CNAME record.
#    Hostname 		string 	A fully qualified domain name. Wildcard "*" permitted.
#    IPv4Address 	string 	An IPv4 dotted decimal IP address.
#    IPv4End 		string 	An IPv4 dotted decimal end-of-range address.
#    IPv4Start 		string 	An IPv4 dotted decimal start-of-range address.
#    MailExchanger 	string 	A fully qualified domain name of an MX record.
#    Target 		string 	A fully qualified domain name of an SRV record.
#    Remarks 		string 	Remarks
#    HostContact 	string 	HostContact
#    DNSContact 	string 	DNSContact 
# param2 - 	string 	Either the literal string "AND" or "OR", describing how to logically treat the search criteria.
# param3 - 	array 	An array containing zero or more sorting criteria. 
#
# Params expected like this:
#  "struct" - python dictionary
#  "string" - python string
#  "array"  - python list
#
# Uses xmlrpclib.dumps to convert python datastructs to XML-RPC



param1 = {
 'CanonicalName' : sys.argv[1]
 # could have many more lines like the preceeding
}
param2 = 'AND'
param3 = list()


output = asgs.searchResourceRecords(param1, param2, param3)


i = 0
L = len(output[4])

# Just print out the hostnames 
while ( i < L ):
    print output[4][i][0]
    i += 1



