#!/usr/bin/python
# 
# Daniel De Marco - ddm@didiemme.net - 2012-02-23 
# 
# originally published at: 
#    https://gist.github.com/1893036
#
# my fork is:  https://gist.github.com/2471779

# suds from https://fedorahosted.org/suds/
import suds
import sys


def get_warr(svctag):
        # url = "http://xserv.dell.com/services/assetservice.asmx?WSDL"
        url = "http://143.166.84.118/services/assetservice.asmx?WSDL"
        client = suds.client.Client(url)
        res=client.service.GetAssetInformation('12345678-1234-1234-1234-123456789012', 'dellwarrantycheck', svctag)

        #print client.dict(res)

        hdrdata=res['Asset'][0]['AssetHeaderData']
        ent=res['Asset'][0]['Entitlements'][0]

        shipped=hdrdata['SystemShipDate']
        warrs=[]
        for i in ent:
                if i==None:
                        continue
                warrs.append(i['EndDate'])

        warrs.sort()
        endwarranty=warrs[-1]

        return (shipped.strftime("%Y-%m-%d"), endwarranty.strftime("%Y-%m-%d"))


if __name__ == "__main__":
        if len(sys.argv) != 2:
                raise RuntimeError("usage: %s SERVICETAG" % sys.argv[0])
        (shipped, endw)=get_warr(sys.argv[1])
        #print 'shipped:      ', shipped
        #print 'end warranty: ', endw
        print endw
