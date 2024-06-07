#######################################################################################################
#' @description FHIR interface for data quality assessment on rare diseases data. 
#' This interface support the core data set of the Medical Informatics Initiative (MII), especially the basic modules patient, diagnoses and treatment case.
#' @author Kais Tahar, University Medical Center Göttingen
#' Project CORD-MI, grant number FKZ-01ZZ1911R
#######################################################################################################

#' @title getFhirRequest
#' @description This function defines the FHIR Request for required medical diagnoses and related data items.
#' @export
#'
getFhirRequest<- function(diagnosesList, diagnosisDate){
  searchRequest <-NULL
  #define fhir search request
  if (is.null(diagnosesList))
  {
    searchRequest <- paste0(
      path,
      'Patient?',
      '_has:Condition:patient:recorded-date=', diagnosisDate,
      '&_revinclude=Encounter:patient',
      "&_revinclude=Condition:patient"
    )
    
  }else {
    searchRequest <- paste0(
      path,
      'Condition?',
      'code=', diagnosesList,
      '&recorded-date=', diagnosisDate,
      "&_include=Condition:encounter",
      '&_include=Condition:subject:Patient'
    )
  }
  searchRequest
}

#' @title getFhirData
#' @description This function extracts the requested data from the FHIR server (see searchRequest) and converts it to tabular format using fhircrackr
#' @import fhircrackr
#' @export
#'
getFhirData<- function(searchRequest, diagnosisDate_item, encounterClass_item, username, token, password, verbose, max_FHIRbundles){
instData <-NULL
print(paste ("Search request: ", searchRequest, sep = ""))
# get fhir bundles
bundles <- fhir_search(request =searchRequest, username = username, token = token, password = password, verbose = verbose, max_bundles =max_FHIRbundles) 
#define the table_description
ConditionTab <- fhir_table_description(
  resource = "Condition",
  cols = list(
    patId = "subject/reference",
    encId= "encounter/reference",
    text= "code/text",
    display = "code/coding/display",
    code = "code/coding/code",
    system = "code/coding/system",
    recorded_date = diagnosisDate_item
  ),
  style = fhir_style(
    sep           = " / ",
    brackets      = c("[", "]"),
    rm_empty_cols = FALSE
  )
)
PatientTab <- fhir_table_description(
  resource = "Patient",
  cols = list(
    instId="meta/source",
    patId= "id",
    birthdate = "birthDate",
    gender = "gender",
    postalCode = "address/postalCode",
    country = "address/country",
    city = "address/city",
    type = "address/type"
  ),
  style = fhir_style(
    rm_empty_cols = FALSE
  )
)
EncounterTab <- fhir_table_description(
  resource = "Encounter",
  cols = list(
    patId= "subject/reference",
    enId = "id",
    start = "period/start",
    end = "period/end",
    class = encounterClass_item,
    status ="status",
    admitCode ="hospitalization/admitSource/coding/code",
    diagnosisUse ="diagnosis/use" # admission, billing or discharge
  ),
  style = fhir_style(
    rm_empty_cols = FALSE
  )
)
design <- fhir_design(ConditionTab, PatientTab, EncounterTab )
fhirRaw<- fhir_crack(bundles, design)
condRaw <- fhirRaw$ConditionTab
instData <-NULL
if (!is.empty (condRaw))
{
  #sort out codes
  condTmp1 <- fhir_melt(condRaw,
                        columns = c("code", "system", "display"),
                        brackets = c("[","]"),
                        sep = " / ",
                        all_columns = T)
  
  
  condTmp2 <- fhir_melt(condTmp1,
                        columns = c("code", "system", "display"),
                        brackets = c("[","]"),
                        sep = " / ",
                        all_columns = T)
  
  # clean up conditions
  condTmp3 <- fhir_rm_indices(condTmp2, brackets = c("[", "]"))
  
  # remove "Patient/" and Encounter
  condTmp3$patId<- sub("Patient/", "", condTmp3$patId)
  condTmp3$encId <- sub("Encounter/", "", condTmp3$encId)
  condTmp3$resource_identifier <- NULL
  
  # remove duplicate patients
  condTmp3<- unique(condTmp3)
  
  # filter conditions by code system
  condIcd <- condTmp3[condTmp3$system==icdSystem,]
  condOrpha <- condTmp3[condTmp3$system==orphaSystem,]
  
  # split icd code in pri and sec code
  condIcd$pri_code <- ifelse(nchar(condIcd$code)>6,sapply(strsplit(condIcd$code,' '), function(x) x[1]),condIcd$code)
  condIcd$sec_code <- ifelse(nchar(condIcd$code)>6,sapply(strsplit(condIcd$code,' '), function(x) x[2]),'-')
  #clean up
  condIcd$system <- NULL
  condIcd$code <- NULL
  names(condIcd) <- c("PatientIdentifikator","Aufnahmenummer", "Diagnosetext", "ICD_Text", "Diagnosedatum", "ICD_Primaerkode", "ICD_Manifestation")
  # Orpha
  condOrpha$system <- NULL
  condOrpha$display <- NULL
  names(condOrpha) <- c("PatientIdentifikator","Aufnahmenummer", "Diagnosetext", "Orpha_Kode", "Diagnosedatum")
  
  # join condition data
  if (!(is.null(condIcd)|is.null (condOrpha))) conditions <-Reduce(function(x, y) base::merge(x, y, all=T), list(condIcd,condOrpha)) else conditions <- condIcd
  
  # convert and save fhir bundles to a data frame patRaw
  patRaw <- fhirRaw$PatientTab
  patients <- fhir_rm_indices(patRaw, brackets = c("[", "]"))
  patients$instId<- gsub("#.*","\\1",patients$instId)
  ifelse (isDate(patients$birthdate), as.Date(patients$birthdate), as.Date(ISOdate(patients$birthdate, 06, 30)))
  
  names(patients) <- c("Institut_ID","PatientIdentifikator", "Geburtsdatum", "Geschlecht", "PLZ", "Land", "Wohnort", "Adressentyp")
  entRaw <- fhirRaw$EncounterTab
  encounters <- entRaw
  encounters$patId <- sub("Patient/", "", entRaw$patId)
  encounters$start <- as.Date(encounters$start)
  encounters$end <- as.Date(encounters$end)
  names(encounters) <- c("PatientIdentifikator","Aufnahmenummer","Aufnahmedatum", "Entlassungsdatum", "Kontakt_Klasse", "Fall_Status", "Aufnahmeanlass", "DiagnoseRolle")
  instData<-Reduce(function(x, y) base::merge(x, y, all=T), list(patients,encounters,conditions))

} else instData<-NULL

instData

}
