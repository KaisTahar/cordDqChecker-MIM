#######################################################################################################
#' @description Data quality analysis and reporting for CORD-MI
#' @author Kais Tahar, University Medical Center Göttingen
#' Project CORD-MI, grant number FKZ-01ZZ1911R
#######################################################################################################
rm(list = ls())
setwd("./")
library(dqLib)
library(openxlsx)
#library(stringi)
options(warn=-1)# to suppress warnings
cat("####################################***CordDqChecker***########################################### \n \n")
# check missing packages
pack <- unique(as.data.frame( (installed.packages())[,c(1,3)]))
dep <- c("dqLib", "fhircrackr", "openxlsx", "stringi")
depPkg <-subset(pack, pack$Package %in% dep)
diff <-setdiff(dep, depPkg$Package)
if (!is.empty(diff)) paste ("The following packages are missing:", toString (diff)) else{ 
  cat ("The following dependencies are installed:\n")
  print(depPkg, quote = TRUE, row.names = FALSE)
}
cat ("\n ####################################### Data Import ########################################## \n")
#------------------------------------------------------------------------------------------------------
# Setting path and variables
#------------------------------------------------------------------------------------------------------
# Export file name
exportFile = "DQ-Results_PHT"
# report year
reportYear <-2020
# inpatient case number
#Sys.setenv(INPATIENT_CASE_NO=997)
# path to fhir server
#Sys.setenv(FHIR_SERVER="http://141.5.101.1:8080/fhir/")
path <- Sys.getenv("FHIR_SERVER")
max_FHIRbundles <- Inf # Inf
inpatientCases <- as.numeric(Sys.getenv("INPATIENT_CASE_NO"))

bItemCl <-"basicItem"
totalRow <-"Total"
#defining mandatory and optional items
cdata <- data.frame(
  basicItem= c("PatientIdentifikator","Aufnahmenummer", "Institut_ID",  "Geschlecht","PLZ", "Land","Kontakt_Klasse", "Fall_Status", "DiagnoseRolle", "ICD_Primaerkode","Orpha_Kode", "Total")
)
ddata <- data.frame(
  basicItem= c ( "Geburtsdatum",  "Aufnahmedatum", "Entlassungsdatum", "Diagnosedatum", "Total")
)
# optional items
oItem = c("Orpha_Kode")
tdata <- data.frame(
  pt_no =NA, case_no =NA
)
repCol=c( "PatientIdentifikator", "Aufnahmenummer", "ICD_Primaerkode","Orpha_Kode")

#------------------------------------------------------------------------------------------------------
# Import ref. Data
#------------------------------------------------------------------------------------------------------
refData1 <- read.table("./Data/refData/Tracerdiagnosen_AlphaID-SE-2022.csv", sep=",",  dec=",", na.strings=c("","NA"), encoding = "UTF-8",header=TRUE)
refData2 <- read.table("./Data/refData/icd10gm2022_alphaidse_edvtxt.txt", sep="|", dec= "," , quote ="", na.strings=c("","NA"), encoding = "UTF-8")
headerRef1<- c ("IcdCode", "Complete_SE", "Unique_SE")
headerRef2<- c ("Gueltigkeit", "Alpha_ID", "ICD_Primaerkode1", "ICD_Manifestation", "ICD_Zusatz","ICD_Primaerkode2", "Orpha_Kode", "Label")
names(refData1)<-headerRef1
names(refData2)<-headerRef2

#------------------------------------------------------------------------------------------------------
# Import CORD data
#------------------------------------------------------------------------------------------------------
medData <- NULL
if (is.null(path) | path=="")  stop("No path to data") else {
  if (grepl("fhir", path))
  {
    source("../Local/R/dqFhirInterface.R")
    medData<- instData[ format(as.Date(instData$Entlassungsdatum, format="%Y-%m-%d"),"%Y")==reportYear, ]
  }else{ ext <-getFileExtension (path)
  if (ext=="csv") medData <- read.table(path, sep=";", dec=",",  header=T, na.strings=c("","NA"), encoding = "latin1")
  if (ext=="xlsx") medData <- read.xlsx(path, sheet=1,skipEmptyRows = TRUE)
  }
  if (is.null (medData)) stop("No data available")
}
#filter for report year
medData<- medData[format(as.Date(medData$Entlassungsdatum, format="%Y-%m-%d"),"%Y")==reportYear, ]
if (is.empty(medData)) stop("No data available for reporting year:", reportYear)
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
    # select meta data for DQ report
    repMeta= c("inst_id", "report_year")
    
    #------------------------------------------------------------------------------------------------------
    # Setting DQ dimensions , indicators and key numbers
    #------------------------------------------------------------------------------------------------------
    ############## Selection of DQ dimensions and indicators #########
    # select DQ indicators for completeness dimension
    compInd= c(
      "item_completeness_rate", 
      "value_completeness_rate", 
      "case_completeness_rate",
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
    # select DQ indicators for concordance
    concInd= c(
      "conc_with_refValues",
      "rdCase_rel_py_ipat",
      "orphaCase_rel_py_ipat",
      "tracerCase_rel_py_ipat"
    )
    
    ############ Selection of DQ key numbers ########################
    # select  key numbers for DQ report
    dqKeyNo= c(
      "case_no_py_ipat",
      "patient_no_py", 
      "orphaCoding_no_py",
      "rdCase_no_py",
      "orphaCase_no_py",
      "tracerCase_no_py",
      "missing_item_no_py",
      "missing_value_no_py",
      "orphaMissing_no_py",
      "implausible_codeLink_no_py",
      "outlier_no_py",
      "ambiguous_rdCase_no_py", 
      "duplicateRdCase_no_py"
    )
    dqRepCol <- c(repMeta, compInd, plausInd, uniqInd, concInd, dqKeyNo)
    # DQ report
    caseItems <- c("PatientIdentifikator","Aufnahmenummer","Kontakt_Klasse", "Fall_Status","ICD_Primaerkode", "Aufnahmedatum", "Entlassungsdatum", "Diagnosedatum","DiagnoseRolle")
    concRef <- list (min=593, max=1851)
    out <-checkCordDQ(instID, reportYear , inpatientCases, refData1, refData2, dqRepCol,repCol, "dq_msg", "basicItem", "Total", oItem, caseItems, concRef)
    dqRep <-out$metric
    mItem <-out$mItem
  }
  
  ################################################### DQ Reports ########################################################
  path<- paste ("./Data/Export/", exportFile, "_", dqRep$report_year, ".csv",  sep = "")
  if (file.exists (path)){
    cat("previous file exists.")
    prev_df <- read.csv(path)
    dqRep<- rbind(dqRep, prev_df)
  } else {
    cat("previous file not exists.")
  }
  write.csv(dqRep, path, row.names = FALSE)
  top <- paste ("\n \n ####################################***CordDqChecker***###########################################")
  msg <- paste ("\n Data quality analysis for location:", dqRep$inst_id,
                "\n Report year:", dqRep$report_year,
                "\n Inpatient case:", dqRep$case_no_py_ipat,
                "\n Patient number:", dqRep$patient_no_py,
                "\n Coded rdCases:", dqRep$rdCase_no_py,
                "\n Orpha Cases:", dqRep$orphaCase_no_py,
                "\n Tracer Cases:", dqRep$tracerCase_no_py,
                "\n Item completeness rate:", dqRep$item_completeness_rate,
                "\n Value completeness rate:", dqRep$value_completeness_rate,
                "\n Case completeness rate:",  dqRep$case_completeness_rate,
                "\n OrphaCoding completeness rate:", dqRep$orphaCoding_completeness_rate,
                "\n OrphaCoding plausibility rate:", dqRep$orphaCoding_plausibility_rate,
                "\n RdCase unambiguity rate:", dqRep$rdCase_unambiguity_rate,
                "\n RdCase dissimilarity rate:", dqRep$rdCase_dissimilarity_rate,
                "\n RdCase relative frequency:", dqRep$rdCase_rel_py_ipat,
                "\n Tacer Cases rel. frequency:", dqRep$tracerCase_rel_py_ipat,
                "\n Orpha Cases rel. frequency:", dqRep$orphaCase_rel_py_ipat,
                "\n Concordance with reference values:", dqRep$conc_with_refValues
                )
  if (dqRep$missing_item_no_py>0)   msg <- paste (msg, "\n" , toString(mItem))
  msg <- paste(msg, 
               "\n \n ########################################## Export ################################################")
  msg <- paste (msg, "\n \n For more infos about data quality indicators see the generated report \n >>> in the file path:", path)
  bottom <- paste ("\n ####################################***CordDqChecker***###########################################")
  cat(paste (top, msg, bottom, sep="\n"))
}else{
  msg <- paste ("Institut_ID fehlt")
  stop(msg)
}
