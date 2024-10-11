# <p align="center"> cordDqChecker-BMC </p>
## <p align="center"> Data Quality Assessments on Rare Diseases Data – A Set of Metrics and Tools for BMC Journal of Medical Informatics and Decision Making </p>

`cordDqChecker-BMC` contains the code version and all instructions used for conducting the study presented in the paper submitted to BMC Journal of Medical Informatics and Decision Making. This repository provides a set of metrics and tools for data quality (DQ) assessment and reporting on rare disease (RD) data.

Acknowledgment: This work was done within the “Collaboration on Rare Diseases” of the Medical Informatics Initiative (CORD-MI) funded by the German Federal Ministry of Education and Research (BMBF), under grant number: FKZ-01ZZ1911R.

## 1. Local Execution
It should be noted that the developed tool supports HL7 FHIR as well as file formats such as CSV or Excel. To conduct local DQ assessments, please follow the following instructions. 
1. Clone repository and checkout branch bmc_dqTools
   - Run the git command: ``` git clone --branch bmc_dqTools https://github.com/KaisTahar/cordDqChecker ```

2. Go to the folder `./Local` and edit the file `config.yml` with your local variables
   - Set your custom variables (v1...v5)
     - Define your organization name (v1) and data input path (v2). This variable specifies which data set should be imported. When importing CSV or Excel data formats, please define the headers as specified in the examples stored in `Local/Data/medData`. You can, for example, define your path as follows:
	   - ```path="http://141.5.101.1:8080/fhir/" ```
	  or
	   - ``` path="./Data/medData/dqTestData.csv" ```
	  or
	   - ``` path="./Data/medData/dqTestData.xlsx" ```

     - Set proxy and access configuration (v3) if required 
     - Set the total number of inpatient cases for 2020 (v4) as follows:
  ``` inpatientCases_number: !expr list ( "2020"=997) ```
     - Set the corresponding code for filtering inpatient cases (v5) else default = NULL
   - Please change the variables v6 - v10 only if technical or legal restrictions otherwise prevent successful execution! It should be noted that the CORD-MI list of diagnoses version 1.0 (=v1) is used as a default list for required diagnoses (see diagnosisList v9). This [reference list](https://github.com/KaisTahar/cordDqChecker/blob/bmc_dqTools/Local/Data/refData/CordDiagnosisList_v1.csv) is stored in the folder for reference data `./Local/Data/refData`

3. Once the source data path and local variables are defined, start the script using this command: ```Rscript cordDqChecker.R ``` to assess the quality of your data. You can also run this script using Rstudio or Dockerfile. To avoid local dependency issues just run the command ```sudo docker-compose up``` in the folder `./Local` to get the script running

4. The script generates two files per year analyzed – the first one is a CSV file that contains the calculated DQ metrics, while the second file is an Excel file that contains a report on DQ violations. To enable users to find the DQ violations and causes of these violations, this report provides sensitive information such as Patient Identifier (ID) or case ID – it is meant for internal use only. The generated reports are saved in the folder `./Local/Data/Export`.

## 2. Synthetic Data and Exemplary Reports
Here are [exemplary reports](https://github.com/KaisTahar/cordDqChecker/tree/bmc_dqTools/Local/Data/Export) on DQ generated using synthetic data from [the FHIR server](http://141.5.101.1:8080). To facilitate testing and reusing of our methods, synthetic data on RDs is made available in both [CSV](https://github.com/KaisTahar/cordDqChecker/blob/bmc_dqTools/Local/Data/medData/syntheticData.csv) and [FHIR](https://github.com/KaisTahar/cordDqChecker/tree/methods_dataCuration/Airolo) formats. These data sets follow the nationwide consented core data set [(MII-CDS)](https://www.medizininformatik-initiative.de/en/basic-modules-mii-core-data-set) of the Medical Informatics Initiative [(MII)](https://www.medizininformatik-initiative.de/en/start) and contain randomly introduced DQ issues as described by [Tahar el al.](https://www.thieme-connect.de/products/ejournals/abstract/10.1055/a-2006-1018)
	
## 3. Data Quality Metric
- The data quality library (dqLib) has been used as an R package for generating specific reports on DQ issues and metrics. The developed software `cordDqChecker-BMC` is compatible with [`dqLib 1.5.0`](https://github.com/KaisTahar/dqLib/releases/tag/v1.5.0). To install all required packages, please use the script [`installPackages.R`](https://github.com/KaisTahar/cordDqChecker/tree/bmc_dqTools/Local/R/installPackages.R) or just run the command `sudo docker-compose up`. This command will install the necessary packages and run the DQ assessment software.

- The following DQ indicators and parameters are configured by default reports:
  | Dimension  | DQ Indicator | 
  | ------------- | ------------- |
  | completeness  | item completeness rate, value completeness rate, orphaCoding completeness rate  | 
  | plausibility  | orphaCoding plausibility rate, range plausibility rate | 
  | uniqueness | RD case unambiguity rate, RD case dissimilarity rate |

  
  |DQ Parameter               | Description |
  |-------------------------- | ------------|
  | analyzed cases |  number of analyzed inpatient cases in a given study |
  | analyzed patients |  number of analyzed inpatients in a given study |
  | RD cases | number of RD cases per year in a given data set |
  | Orpha cases |  number of Orpha cases per year in a given data set |
  | tracer cases |  number of tracer RD cases per year in a given data set |
  | RD cases rel. frequency| relative frequency of inpatient RD cases per year per 100.000 cases|
  | Orpha cases rel. frequency| relative frequency of inpatient Orpha cases per year per 100.000 cases|
  | tracer cases rel. frequency| relative frequency of inpatient tracer RD cases per year per 100.000 cases|
  | missing mandatory data items | number of missing data items per year in a given data set |
  | missing mandatory data values| number of missing data values per year in a given data set |
  | outliers | number of detected outliers per year in a given data set |
  | missing Orphacodes |  number of missing Orphacodes per year in a given data set |
  | implausible links | number of implausible code links per year in a given data set |
  | duplicated RD cases |  number of duplicated RD cases per year in a given data set |
  | ambiguous RD cases | number of ambiguous RD cases per year in a given data set |

- The following references are required to assess the quality of Orphacoding and can be easily updated with new versions: (1) The standard [Alpha-ID-SE](https://github.com/KaisTahar/cordDqChecker/blob/bmc_dqTools/Local/Data/refData/icd10gm2022_alphaidse_edvtxt.txt) terminology [1], and (2) the reference list for [standardized tracer diagnoses](https://github.com/KaisTahar/cordDqChecker/blob/bmc_dqTools/Local/Data/refData/Tracerdiagnosen_AlphaID-SE-2022.csv) provided in [2].
  
	[1]   BfArM - Alpha-ID-SE [Internet]. Available from: [BfArM](https://www.bfarm.de/EN/Code-systems/Terminologies/Alpha-ID-SE/_node.html) 
	
	[2]   Tahar K, Martin T, Mou Y, et al. Distributed Data Quality Assessment Across CORD-MI Consortia. [doi:10.3205/22gmds116](https://www.egms.de/static/en/meetings/gmds2022/22gmds116.shtml)


## 4. Note

-  You can also run `cordDqChecker-BMC` using Rstudio or Dockerfile. When using Rstudio, all required packages should be installed automatically using the script [`installPackages.R`](https://github.com/KaisTahar/cordDqChecker/tree/bmc_dqTools/Local/R/installPackages.R). It should be noted that the `fhircrackr` package is only required to run DQ assessments on FHIR data. To avoid local dependency issues go to folder `./Local` and just run the command `sudo docker-compose up` to get `cordDqChecker` running

- The missing item rate is calculated based on [FHIR implementation guidlines](https://www.medizininformatik-initiative.de/en/basic-modules-mii-core-data-set) of the MII-CDS. Hence, mandatory items of the basic modules Person, Treatment Case, and Diagnosis are required

- To cite `cordDqChecker-BMC`, please use the citation file [`CITATION.cff`](https://github.com/KaisTahar/cordDqChecker/blob/bmc_dqTools/CITATION.cff)

See also: [`CORD-MI`](https://www.medizininformatik-initiative.de/de/CORD)

