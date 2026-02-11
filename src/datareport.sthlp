{smcl}
{* *! version 1.0.5  10feb2026}{...}
{viewerjumpto "Syntax" "datareport##syntax"}{...}
{viewerjumpto "Description" "datareport##description"}{...}
{viewerjumpto "Options" "datareport##options"}{...}
{viewerjumpto "Examples" "datareport##examples"}{...}
{viewerjumpto "Stored results" "datareport##results"}{...}
{viewerjumpto "Author" "datareport##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col :{cmd:datareport} {hline 2}}Generate comprehensive Excel data report with summary statistics and variable analysis{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:datareport}
{cmd:using} {it:{help filename}}
[{cmd:,} {it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Main}
{synopt:{opt replace}}overwrite existing file{p_end}
{synopt:{opt sheet:name(string)}}custom sheet name (default: "datareport"){p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:datareport} creates a comprehensive Excel report containing detailed information about 
the current dataset. The command generates two worksheets:

{phang}1. {bf:Summary Sheet} - Contains dataset-level information including:{p_end}
{phang2}- Dataset title (extracted from data label or filename){p_end}
{phang2}- Date of last modification{p_end}
{phang2}- Number of observations and variables{p_end}
{phang2}- File path and size{p_end}
{phang2}- Count of string vs numeric variables{p_end}
{phang2}- Count of variables with missing labels{p_end}
{phang2}- Count of completely missing variables{p_end}

{phang}2. {bf:Data_report Sheet} - Contains variable-level analysis including:{p_end}
{phang2}- Variable name and label{p_end}
{phang2}- Variable type (byte, int, float, str, etc.){p_end}
{phang2}- Variable notes (if defined){p_end}
{phang2}- Count of non-missing and missing observations{p_end}
{phang2}- Complete value label definitions (all defined labels, not just those in data){p_end}
{phang2}- Statistical summary:{p_end}
{phang3}* For continuous numeric variables: Min, Max, and Average (formatted to 2 decimals){p_end}
{phang3}* For categorical variables: Percentage distribution of observed values{p_end}
{phang3}* For string variables: Length statistics{p_end}


{marker options}{...}
{title:Options}

{dlgtab:Main}

{phang}
{opt replace} permits {cmd:datareport} to overwrite an existing file.

{phang}
{opt sheetname(string)} specifies a custom name for the data report sheet. 
Default is "datareport".


{marker examples}{...}
{title:Examples}

{pstd}Basic usage:{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. datareport using "auto_report.xlsx", replace}{p_end}

{pstd}With custom dataset label:{p_end}
{phang2}{cmd:. use "mysurvey.dta", clear}{p_end}
{phang2}{cmd:. label data "Household Survey 2024"}{p_end}
{phang2}{cmd:. datareport using "survey_report.xlsx", replace}{p_end}

{pstd}With custom sheet name:{p_end}
{phang2}{cmd:. use "mydata.dta", clear}{p_end}
{phang2}{cmd:. datareport using "report.xlsx", replace sheetname("analysis")}{p_end}

{pstd}Documenting dataset before sharing:{p_end}
{phang2}{cmd:. use "research_data.dta", clear}{p_end}
{phang2}{cmd:. label data "Clinical Trial Data - Phase 2"}{p_end}
{phang2}{cmd:. datareport using "data_documentation.xlsx", replace}{p_end}


{marker results}{...}
{title:Output}

{pstd}
The command creates an Excel file with two sheets:

{phang}
{bf:Summary} - Dataset-level summary with properly formatted categories and values in bold headers

{phang}
{bf:Data_report} - Detailed variable analysis with 8 columns:
{p_end}
{phang2}1. {bf:variable} - Variable name{p_end}
{phang2}2. {bf:label} - Variable label (or "(No label)" if undefined){p_end}
{phang2}3. {bf:type} - Variable storage type{p_end}
{phang2}4. {bf:note} - Variable notes (if defined using {cmd:char} or {cmd:notes}){p_end}
{phang2}5. {bf:observation} - Count of non-missing observations{p_end}
{phang2}6. {bf:missing} - Count of missing observations{p_end}
{phang2}7. {bf:value_label} - Complete value label definition (blank if no label){p_end}
{phang2}8. {bf:result} - Statistical summary based on variable type{p_end}


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Key Features:}

{phang}1. {bf:Complete Value Labels}: Unlike standard summary commands, {cmd:datareport} 
displays ALL defined value labels, not just those present in the data. For example, 
if a Likert scale defines 1-5 but respondents only selected 3-5, all five label 
definitions will be shown.{p_end}

{phang}2. {bf:Formatted Decimals}: Continuous variables show min/max/avg with exactly 
2 decimal places for clean, readable output.{p_end}

{phang}3. {bf:Professional Formatting}: The Excel output includes bold headers and 
optimized column widths for immediate use in reports and documentation.{p_end}

{phang}4. {bf:Quiet Execution}: The command runs quietly, displaying only an elegant 
progress message and completion summary.{p_end}

{pstd}
{bf:Requirements:}

{phang}- Stata version 16.0 or higher{p_end}
{phang}- Python with {cmd:openpyxl} package (for Excel formatting){p_end}
{phang}- Write permissions in the target directory{p_end}

{pstd}
{bf:Installation of Python dependencies:}

{phang}If you encounter formatting issues, install openpyxl:{p_end}
{phang2}{cmd:. shell pip install openpyxl}{p_end}


{marker technical}{...}
{title:Technical Notes}

{pstd}
The command uses temporary files to construct the report and executes a Python 
script to apply Excel formatting (bold headers and column widths). All intermediate 
files are automatically cleaned up.

{pstd}
Value labels are extracted using {cmd:label list} to ensure complete definitions 
are captured, including non-consecutive values (e.g., 1, 2, 99).

{pstd}
File size is calculated using Stata's file handling commands and displayed in 
appropriate units (bytes, KB, or MB).


{marker author}{...}
{title:Author}

{pstd}
Md Redoan Hossain Bhuiyan
Email: redoanhossain630@gmail.com

{pstd}
For bug reports, feature requests, or contributions, please visit the GitHub repository.


{marker acknowledgments}{...}
{title:Acknowledgments}

{pstd}
This program was developed to streamline data documentation workflows in research 
and survey projects.


{title:Also see}

{psee}
Online: {helpb describe}, {helpb codebook}, {helpb labelbook}, {helpb export excel}
{p_end}
