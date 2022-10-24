# FHIR-Tools


### Setup FHIR Server
Install your local FHIR server, for example in docker environment as follows:
```bash
   docker volume create hapi-data-dq
   docker run -d -p 8085:8080 -v hapi-data-dq:/data/hapi --name Bapu_srv hapiproject/hapi:latest
```
### Upload FHIR Transactions 
Put the transaction files in the subfolder `./Transaction` and run the script `transactionUploader.py` to upload your data to FHIR server.
This script takes three parameters as input arguments: `IP`, `portNo`, and `orgaName`
The arguments `IP` and `portNo` define the address and port number of target FHIR server, `orgaName` specifies the organization name (resp. folder name) of FHIR data that should be imported (see test data in the subfolder `./Transaction/Bapu`).

For example, you can run `transactionUploader.py` as follows:
```bash
   python3 transactionUploader.py 127.0.0.1 8085 Bapu
```

### NOTE
Before starting `transactionUploader.py` you need to install this library: [fhirpy](https://github.com/beda-software/fhir-py)
```bash
   pip install fhirpy
```

