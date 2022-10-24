# Data curation
This page describes the data sets and tools used for data curation.
## Experiment Data 
The data used in experiment settings include three synthetic data sets of different organizations namely Cynthia, Bapu, Airolo. The original data were extracted from the FHIR server of CORD-MI [1]. Each data set includes common data items that capture information about the basic modules of the MII-CDS as specified in the FHIR implementation guide of CORD-MI [2]. Next, randomly data quality issues were added in these data sets such as duplication, outliers, and implausible RD codification. Furthermore, the extracted FHIR bundles were transformed into FHIR transactions, and distributed them over all participating hospitals. 

## FHIR Tools
HAPI FHIR server [3] should be installed for storing the synthetic FHIR data sets at each hospital. The docker environment and installation guide are stored in the folder of each organization, e.g., the installation guide for Airolo is stored in `./Airolo`. The `transationUploader`scripts are also stored in the organization folders. These scripts enable an easy upload of created transactions to the FHIR server of each location. For example, you can run `transactionUploader.py` as follows:
```bash
   python3 transactionUploader.py 127.0.0.1 8085 Airolo
```
## References
[1] HAPI FHIR Server of CORD-MI. Accessed July 5, 2022. https://mii-agiop-cord.life.uni-leipzig.de/

[2] HAPI FHIR - The Open Source FHIR API for Java. Accessed June 29, 2022. https://hapifhir.io/

[3] Medical Informatics Initiative - CORD - ImplementationGuide. Accessed May 23, 2022. https://simplifier.net/guide/medicalinformaticsinitiative-cord-implementationguide?version=current

See also:  [`cordDqChecker`](https://github.com/KaisTahar/cordDqChecker-MIM)  [`CORD-MI`](https://www.medizininformatik-initiative.de/de/CORD)



