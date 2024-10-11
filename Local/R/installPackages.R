# install R packages
if(!require('devtools')) install.packages('devtools')
library(devtools)
install_github("https://github.com/KaisTahar/dqLib/tree/v1.5.0")
if(!require('fhircrackr')) install.packages('fhircrackr')
if(!require('openxlsx')) install.packages('openxlsx')
if(!require('stringi')) install.packages('stringi')
if(!require('config')) install.packages('config')
if(!require('parallel')) install.packages('(parallel')