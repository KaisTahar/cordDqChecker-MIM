import os
import sys
import json
from fhirpy import SyncFHIRClient

"""
A script for uploading FHIR transactions to a target FHIR server.
This script takes three parameters as input arguments: IP, portNo, and orgaName

"""

if (len(sys.argv) !=4):
    print ("Please set the required arguments: IP, portNo and orgaName")
    sys.exit()
else:
    # Link to FHIR server
    ip =sys.argv[1]
    portNo= sys.argv[2]
    fhirAddr = 'http://{}:{}/fhir'.format(ip,portNo )
    # Organization name
    orgaName = sys.argv[3]
    
# Client connection to fhir server
fhirClient = SyncFHIRClient(fhirAddr)

print( "Client connecting to FHIR server: " + fhirAddr)
print( " Organization name: " +orgaName)
        
filePath = "./Transaction/{}".format(orgaName)
# Sort transation files
transFiles = [pos for pos in os.listdir(filePath) if pos.endswith('.json')]
sortedTrans = sorted(transFiles, key=lambda x: int(x.split(".")[0].split("_")[-1]))

#Upload transations
for trans in sortedTrans:
    print(">>>Uploading file: "+ trans)
    with open('{}/{}'.format(filePath,trans)) as f:
        data = json.load(f)
    p = fhirClient.resource("Bundle", **data)
    p.save()    
             
print( orgaName, "transations are done!")
