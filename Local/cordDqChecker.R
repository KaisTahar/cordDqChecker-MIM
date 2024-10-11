#######################################################################################################
#' @description  Data quality analysis and reporting for CORD-MI
#' @author Kais Tahar, University Medical Center Göttingen
#' Project CORD-MI, grant number FKZ-01ZZ1911R
#######################################################################################################
rm(list = ls())
setwd("./")
# install required packages
source("./R/installPackages.R")
#import dqLib and required packages
library(dqLib)
library(openxlsx)
library(stringi)
library(parallel)
library(fhircrackr)
options(warn=-1)# to suppress warnings
if(!require('dqLib')){
  source("./R/dqLibCord.R")
  source("./R/dqLibCore.R")
}
source("./R/dqFhirInterface.R")
cat("####################################***CordDqChecker***########################################### \n \n")
# check missing packages
pack <- unique(as.data.frame( (installed.packages())[,c(1,3)]))
dep <- c("openxlsx", "fhircrackr",  "stringi", "config")
depPkg <-subset(pack, pack$Package %in% dep)
diff <-setdiff(dep, depPkg$Package)
if (!is.empty(diff)) paste ("The following packages are missing:", toString (diff)) else{ 
  cat ("The following dependencies are installed:\n")
  print(depPkg, quote = TRUE, row.names = FALSE)
}
cat ("\n ####################################### Data Import ########################################## \n")
#------------------------------------------------------------------------------------------------------
# Setting path and local variables
#------------------------------------------------------------------------------------------------------
# execution time
executionTime <- base::Sys.time()
startTime <- base::Sys.time()
source("./R/config.R")
# export file name
exportFile = "DQ-Report"

#------------------------------------------------------------------------------------------------------
# Setting ref. Data
#------------------------------------------------------------------------------------------------------
# defining mandatory and optional items
cdata <- data.frame(
  basicItem= c("PatientIdentifikator","Aufnahmenummer", "Institut_ID",  "Geschlecht","PLZ", "Land","Kontakt_Klasse", "Fall_Status", "DiagnoseRolle", "ICD_Primaerkode", "Total")
)
ddata <- data.frame(
  basicItem= c ( "Geburtsdatum",  "Aufnahmedatum", "Entlassungsdatum", "Diagnosedatum", "Total"),
  engLabel = c("birthdate", "admission date" , "discharge date", "diagnosis date", NA)
)

# semantic mapping of labels and symbolic names (also called code variables)
semData <- read.table("./Data/refData/semData.csv", sep=",",  dec=",", na.strings=c("","NA"), encoding = "UTF-8",header=TRUE)

# optional items
oItem = c("Orpha_Kode")
tdata <- data.frame(
  pt_no =NA, case_no =NA
)
caseItems <- c("PatientIdentifikator","Aufnahmenummer","Kontakt_Klasse", "Fall_Status","ICD_Primaerkode", "Aufnahmedatum", "Entlassungsdatum", "Diagnosedatum","DiagnoseRolle")
refData1 <- read.table(tracerDiagnoses_ref, sep=",",  dec=",", na.strings=c("","NA"), encoding = "UTF-8",header=TRUE)
refData2 <- read.table(alphaIdSe_ref, sep="|", dec= "," , quote ="", na.strings=c("","NA"), encoding = "UTF-8")
headerRef1<- c ("IcdCode", "Complete_SE", "Unique_SE")
headerRef2<- c ("Gueltigkeit", "Alpha_ID", "ICD_Primaerkode1", "ICD_Manifestation", "ICD_Zusatz","ICD_Primaerkode2", "Orpha_Kode", "Label")
names(refData1)<-headerRef1
names(refData2)<-headerRef2
cordDiagnosisList <- read.table(diagnosisPath, sep=",",  dec=",", na.strings=c("","NA"), encoding = "UTF-8",header=TRUE)$IcdCode
# meta data for DQ report
repMeta= c("inst_id", "report_year")
bItemCl <-"basicItem"
totalRow <-"Total"
repHeader <- data.frame(
  repCol=c( "PatientIdentifikator", "Aufnahmenummer", "ICD_Primaerkode","Orpha_Kode"),
  engLabel = c("Patient ID", "Admission ID" , "ICD_Primary Code", "Orphacode")
)
repCol <-repHeader$repCol

#------------------------------------------------------------------------------------------------------
# Setting DQ dimensions , indicators and parameters
#------------------------------------------------------------------------------------------------------
############## Selection of DQ dimensions and indicators #########
# select DQ indicators for completeness dimension
compInd= c(
  "item_completeness_rate", 
  "value_completeness_rate", 
  "orphaCoding_completeness_rate"
)
# select DQ indicators for plausibility dimension
plausInd= c( 
  "range_plausibility_rate", 
  "orphaCoding_plausibility_rate"
)
# select DQ indicators for uniqueness dimension
uniqInd= c(
  "rdCase_unambiguity_rate",
  "rdCase_dissimilarity_rate"
)

############ Selection of DQ parameters ########################
# select DQ parameters for DQ report
dqParam= c(
  "case_no_py",
  "patient_no_py",
  "missing_item_no_py",
  "missing_value_no_py",
  "outlier_no_py",
  "orphaMissing_no_py",
  "implausible_codeLink_no_py",
  "ambiguous_rdCase_no_py", 
  "duplicateRdCase_no_py",
  "rdCase_no_py",
  "orphaCase_no_py",
  "tracerCase_no_py",
  "rdCase_rel_py_ipat",
  "orphaCase_rel_py_ipat",
  "tracerCase_rel_py_ipat"
  )

#------------------------------------------------------------------------------------------------------
# Import CORD data
#------------------------------------------------------------------------------------------------------
allData <- NULL
iterator=0
if (is.null(path) | path=="" | is.na(path)) stop("No path to data") else {
  inpatientCases = 0
  tracer <- cordDiagnosisList
  # Detect the number of CPU cores for parallel computing optimization
  cpuCores_no= detectCores()
  # Parallel optimization
  if (!is.null(parallelComputing) & parallelComputing) diagnosisNo <- round(length(tracer)/cpuCores_no,0)
  else diagnosisNo <- length(tracer)
  range <-reportYearStart:reportYearEnd
  for ( reportYear in range){
    iterator <- iterator+1
    if (iterator>1) startTime <- base::Sys.time()
    yearMsg <-paste (" \n \n >>> New reporting year:" , reportYear, "\n \n " )
    cat(yearMsg, sep="\n")
    instData <- NULL
    medData <- NULL
    msg <- NULL
    dataFormat =""
    dqRep <-NULL
    x <- NULL
    if (toString(reportYear)  %in%  names(ipatCasesList))inpatientCases = ipatCasesList[[toString(reportYear)]]
    if (grepl("fhir", path))
    {
      dataFormat = "FHIR"
      if (length(tracer) > diagnosisNo )
      {
        while ( length(tracer) > diagnosisNo) {
          cordTracer.vec <- tail(tracer, diagnosisNo)
          cordTracer <- paste0(cordTracer.vec, collapse=",")
          x <-append (x, cordTracer)
          tracer <- head(tracer, - diagnosisNo)
        }
        if ( length(tracer) <= diagnosisNo)
        { 
          cordTracer.vec <- tracer
          cordTracer <- paste0(cordTracer.vec, collapse=",")
          x <-append (x, cordTracer)
        }
        
        #Performance optimization for parallel computing
        y <- unlist(mclapply(x,getFhirRequest, diagnosisDate =reportYear))
        results <- mclapply(y, getFhirData, diagnosisDate_item, encounterClass_item, username, token, password, 2, max_FHIRbundles, mc.cores = cpuCores_no)
        fhirData <- Reduce(rbind, results)
        medData <-base::unique(fhirData)
      } 
      else { 
        if(is.null (cordDiagnosisList)) cordTracer= NULL else cordTracer <- paste0(tracer, collapse=",")
        searchRequest <- getFhirRequest (cordTracer, reportYear)
        medData<-getFhirData(searchRequest, diagnosisDate_item, encounterClass_item, username, token, password, 2, max_FHIRbundles)
      }
      if (!is.null(encounterClass_value) & "Kontakt_Klasse" %in% colnames(medData)) medData<- medData[medData[["Kontakt_Klasse"]]==encounterClass_value, ]
      
    }else{ 
      ext <-getFileExtension(path)
      if (!is.empty(ext))
      {
        if (ext=="csv") { 
          dataFormat = "CSV"
          medData <- read.table(path, sep=";", dec=",",  header=T, na.strings=c("","NA"), encoding = "latin1") 
        }
        else if (ext=="xlsx") { 
          dataFormat = "Excel"
          medData <- read.xlsx(path, sheet=1,skipEmptyRows = TRUE, detectDates = TRUE)
        }
        
      } else stop("No data path found, please set the data path in the config file")
      # filter for tracer diagnoses
      medData<- subset(medData, medData$ICD_Primaerkode %in% cordDiagnosisList)
      # filter for report year and inpatient cases
      if (dateRef %in% names(medData)){
        if (!all(is.na(medData[[dateRef]]))) medData<- medData[format(as.Date(medData[[dateRef]], format=dateFormat),"%Y")==reportYear, ] else stop("No date values available for data selection")
      }else stop("Reference date item is not available")
      if (!is.null(encounterClass_value)) medData<- medData[medData[["Kontakt_Klasse"]]==encounterClass_value, ]
    }
    if (is.null(medData)) {
      dqRep$inst_id <- institut_ID 
      dqRep$report_year <- reportYear
      dqRep$dataFormat <- dataFormat
      top <- paste ("\n \n ####################################***CordDqChecker***###########################################")
      noDataMsg<- paste("\n No data available for reporting year:", reportYear)
      dqRep$msg <- noDataMsg
      msg <- paste ("\n Data quality analysis for location:", dqRep$inst_id,
                    "\n Report year:", dqRep$report_year)
      warning("No data available for reporting year:", reportYear)
      pathExp<- paste ("./Data/Export/", exportFile, "_", institut_ID, "_", dataFormat, "_",  reportYear,  sep = "")
      msg <- paste(msg, noDataMsg,
                   "\n \n ########################################## Export ################################################")
      write.csv(dqRep, paste (pathExp,".csv", sep =""), row.names = FALSE)
      msg <- paste ( msg , "\n \n See the generated report \n >>> in the file path:", pathExp)
      
      bottom <- paste ("\n ####################################***CordDqChecker***###########################################\n")
      cat(paste (top,msg, bottom, sep="\n"))
      if (iterator ==length(range) & !is.null(allData) ){
        if (dim(allData)[1] > 0)
        {
          setGlobals(allData, repCol, cdata, ddata, tdata)
          out <-checkCordDQ(instID, reportYear , inpatientCases, refData1, refData2, dqRepCol,repCol, "dq_msg", "basicItem", "Total", oItem, caseItems)
          dqRep <-out$metric
          dqRep$report_year <-  paste (reportYearStart,"-",  reportYearEnd,  sep = "")
          dqRep$dataFormat <- dataFormat
          expPath<- paste ("./Data/Export/", exportFile, "_", institut_ID, "_", dataFormat,"_allData.csv",  sep = "")
          write.csv(dqRep, expPath, row.names = FALSE)
        }
        
      }
      next
  } else if (dim(medData)[1]==0 | all(is.na(medData))) {
    dqRep$inst_id <- institut_ID 
    dqRep$report_year <- reportYear
    dqRep$dataFormat <- dataFormat
    top <- paste ("\n \n ####################################***CordDqChecker***###########################################")
    noDataMsg<- paste("\n Empty data set for reporting year:", reportYear)
    dqRep$msg <- noDataMsg
    msg <- paste ("\n Data quality analysis for location:", dqRep$inst_id,
                  "\n Report year:", dqRep$report_year)
    warning("No data available for reporting year:", reportYear)

    pathExp<- paste ("./Data/Export/", exportFile, "_", institut_ID, "_", dataFormat, "_",  reportYear,  sep = "")
    msg <- paste(msg, noDataMsg,
                 "\n \n ########################################## Export ################################################")
    write.csv(dqRep, paste (pathExp,".csv", sep =""), row.names = FALSE)
    msg <- paste ( msg , "\n \n See the generated report \n >>> in the file path:", pathExp)
    
    bottom <- paste ("\n ####################################***CordDqChecker***###########################################\n")
    cat(paste (top,msg, bottom, sep="\n"))
    if (iterator ==length(range) & !is.null(allData) ){
      if (dim(allData)[1] > dim(medData)[1])
      {
        setGlobals(allData, repCol, cdata, ddata, tdata)
        out <-checkCordDQ(instID, reportYear , inpatientCases, refData1, refData2, dqRepCol,repCol, "dq_msg", "basicItem", "Total", oItem, caseItems)
        dqRep <-out$metric
        dqRep$report_year <-  paste (reportYearStart,"-",  reportYearEnd,  sep = "")
        dqRep$dataFormat <- dataFormat
        expPath<- paste ("./Data/Export/", exportFile, "_", institut_ID, "_", dataFormat,"_allData.csv",  sep = "")
        write.csv(dqRep, expPath, row.names = FALSE)
      }
    }
    next
  }
  if (!("Institut_ID" %in% names(medData))) medData$Institut_ID=institut_ID else if (all(is.na(medData$Institut_ID))) medData$Institut_ID=institut_ID
  dItem <-names(medData)
  msg <-cat("\n The following data items are loaded: \n")
  print(paste(msg, dItem))
 
  #------------------------------------------------------------------------------------------------------
  # Start DQ analysis
  #------------------------------------------------------------------------------------------------------
  setGlobals(medData, repCol, cdata, ddata, tdata)
  td <- NULL
  if (!is.empty(medData$Institut_ID)){
    inst <- levels(as.factor(medData$Institut_ID))
    for (i in 1:length (inst)) {
      instID <- as.character (inst[i]) 
      # DQ report
      dqRepCol <- c(repMeta, compInd, plausInd, uniqInd, dqParam)
      out <-checkCordDQ(instID, reportYear , inpatientCases, refData1, refData2, dqRepCol,repCol, "DQ_Violations", "basicItem", "Total", oItem, caseItems)
      dqRep$st_name <-"CORD-MI"
      dqRep <-cbind(dqRep, out$metric)
      mItem <-out$mItem
      endTime <- base::Sys.time()
      timeTaken <-  round (as.numeric (endTime - startTime, units = "mins"), 2)
      dqRep$executionTime_inMin <-timeTaken
      dqRep$parallelComputing <-parallelComputing
      dqRep$cpuCores_no <-cpuCores_no
      dqRep$dateRef <- dateRef
      dqRep$dataFormat <- dataFormat
      dqRep$diagnosesList <- diagnosisListVersion
      if (!is.null (encounterClass_value)) dqRep$encounterClass <-  encounterClass_value else dqRep$encounterClass <- NA
    }
    
    ################################################### DQ Reports ########################################################
    expPath<- paste ("./Data/Export/", exportFile, "_", institut_ID, "_", dataFormat,"_", dqRep$report_year,  sep = "")
    rep <-addSemantics (dqRep, semData)
    getReport( repHeader, "DQ_Violations", rep, expPath)
    
    top <- paste ("\n \n ####################################***CordDqChecker***###########################################")
    msg <- paste ("\n Data quality analysis for location:", dqRep$inst_id,
                  "\n Report year:", dqRep$report_year,
                  "\n Analyzed cases:", dqRep$case_no_py,
                  "\n Analyzed patients:", dqRep$patient_no_py,
                  "\n Item completeness rate:", dqRep$item_completeness_rate,
                  "\n Value completeness rate:", dqRep$value_completeness_rate,
                  "\n OrphaCoding completeness rate:", dqRep$orphaCoding_completeness_rate,
                  "\n OrphaCoding plausibility rate:", dqRep$orphaCoding_plausibility_rate,
                  "\n RdCase unambiguity rate:", dqRep$rdCase_unambiguity_rate,
                  "\n RdCase dissimilarity rate:", dqRep$rdCase_dissimilarity_rate,
                  "\n Missing Orphacodes:",  dqRep$orphaMissing_no,
                  "\n Implausible Diagnoses :",  dqRep$implausible_codeLink_no,
                  "\n Duplicated RD Cases:",  dqRep$duplicateRdCase_no,
                  "\n RD Cases rel. frequency:", dqRep$rdCase_rel_py_ipat,
                  "\n Tacer Cases rel. frequency:", dqRep$tracerCase_rel_py_ipat,
                  "\n Orpha Cases rel. frequency:", dqRep$orphaCase_rel_py_ipat
    )
    
    if (dqRep$missing_item_no_py >0)   msg <- paste (msg, "\n", toString(mItem))
    msg <- paste(msg, 
                 "\n \n ########################################## Export ################################################")
    msg <- paste (msg, "\n \n For more infos about data quality indicators see the generated report \n >>> in the file path:", expPath)
    bottom <- paste ("\n ####################################***CordDqChecker***###########################################\n")
    cat(paste (top, msg, bottom, sep="\n"))
    allData <- base::rbind(allData,medData)
  }else{
    msg <- paste ("Institut_ID fehlt")
    stop(msg)
  }
    if (iterator ==length(range) & !is.null(allData) ){
      if (dim(allData)[1] > dim(medData)[1])
      {
        setGlobals(allData, repCol, cdata, ddata, tdata)
        out <-checkCordDQ(instID, reportYear , inpatientCases, refData1, refData2, dqRepCol,repCol, "dq_msg", "basicItem", "Total", oItem, caseItems)
        dqRep$st_name <- "CORD-MI"
        dqRep <-cbind(dqRep, out$metric)
        dqRep$report_year <- paste (reportYearStart,"-",  reportYearEnd,  sep = "")
        endTime <- base::Sys.time()
        timeTaken <-  round (as.numeric (endTime - executionTime, units = "mins"), 2)
        dqRep$executionTime_inMin <-timeTaken
        dqRep$parallelComputing <-parallelComputing
        dqRep$cpuCores_no <-cpuCores_no
        dqRep$dataFormat <- dataFormat
        expPath<- paste ("./Data/Export/", exportFile, "_", institut_ID, "_", dataFormat,"_allData.csv",  sep = "")
        write.csv(tRep, expPath, row.names = FALSE)
      }
    }
  }
  
}
