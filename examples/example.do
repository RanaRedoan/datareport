******************************************************
* Example do-file: Generate a data report with datareport
* Author: Md. Redoan Hossain Bhuiyan
* Date:   10 Feb 2026
******************************************************

* Clear environment
clear all
set more off

*-----------------------------------------------------
* 1. Basic use on any dataset
*-----------------------------------------------------
sysuse auto, clear

describe
summarize

datareport using "auto_report.xlsx", replace

*-----------------------------------------------------
* 2. Survey data with multiple-select questions
*-----------------------------------------------------
* select_multiple questions exported by SurveyCTO, ODK or Kobo arrive as a
* string parent variable plus one 0/1 dummy per option.  datareport folds
* them back into a single mrtab-style row automatically - no option needed.

* use "survey_data.dta", clear
* datareport using "survey_report.xlsx", replace

*-----------------------------------------------------
* 3. Supplying the XLSForm
*-----------------------------------------------------
* Passing the form lets datareport confirm which questions really are
* select_multiple, read option labels straight from the choices sheet, and
* add a Form_check sheet listing questions that never reached the data.

* use "survey_data.dta", clear
* datareport using "survey_report.xlsx", replace form("survey_form.xlsx")

* For a multi-language form, name the label column you want:
* datareport using "report.xlsx", replace form("form.xlsx") formlang("English")

*-----------------------------------------------------
* 4. Turning the folding off
*-----------------------------------------------------
* nomultiselect restores the old behaviour: one row per variable.

* datareport using "flat_report.xlsx", replace nomultiselect

*-----------------------------------------------------
* 5. Several rounds in one workbook
*-----------------------------------------------------
* sheetname() prefixes the sheet names so rounds do not overwrite each other.

* local rounds "baseline midline endline"
* foreach r of local rounds {
*     use "survey_`r'.dta", clear
*     datareport using "reports/monitoring.xlsx", sheetname(`r')
* }

di as text "Data report(s) generated successfully!"
******************************************************
