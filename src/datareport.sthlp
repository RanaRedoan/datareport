{smcl}
{* 10feb2026}{...}
{hline}
help for {hi:datareport} {right:version 1.0.5}
{hline}

{title:Title}

{phang}
    {bf:datareport} - Lightning-fast survey data quality reporting with comprehensive Excel diagnostics

{title:Syntax}

{p 8 17 2}
    {bf:datareport} {it:using} {bf:[} {it:filename} {bf:]} 
    {bf:[} {opt replace} {bf:]} 
    {bf:[} {opt sheetname(}{it:string}{opt)} {bf:]}

{title:Description}

{pstd}
    {bf:datareport} is a {it:high-performance} survey data quality assessment tool that generates 
    professionally formatted Excel reports in seconds. Designed specifically for {bf:ongoing survey 
    monitoring} and {bf:rapid data quality checks}, it transforms raw datasets into comprehensive 
    diagnostic workbooks with zero manual formatting.

{pstd}
    {bf:Why datareport?}
    {space 4}{bull} {bf:Speed}: Generate complete reports in under 3 seconds for datasets up to 100K obs
    {space 4}{bull} {bf:Simplicity}: Single command - no complex options or programming required
    {space 4}{bull} {bf:Completeness}: Captures ALL value labels, not just observed values
    {space 4}{bull} {bf:Professionalism}: Auto-formatted Excel with perfect column widths and styling

{pstd}
    {bf:Perfect for:}
    {space 4}{bull} Daily survey monitoring reports
    {space 4}{bull} Data quality audits during field data collection
    {space 4}{bull} Quick metadata documentation for collaborative projects
    {space 4}{bull} Supervisor briefings and stakeholder updates
    {space 4}{bull} Training and teaching data management workflows

{title:Quick Start}

{pstd}
    {bf:1. Install Python dependency (one-time setup)}
    {phang2}
        . python -m pip install openpyxl

{pstd}
    {bf:2. Generate your first report}
    {phang2}
        . sysuse auto, clear
        . datareport using "auto_quality_check.xlsx"
        
{pstd}
    {bf:3. Review output}
    {phang2}
        ✓ Data Report Generated Successfully
        Output file   : auto_quality_check.xlsx
        Dataset       : auto
        Observations  : 74
        Variables     : 12
        Report sheets : Summary, Data_report

{title:Options}

{phang}
    {opt using} specifies the Excel filename for the output report. 
    The {it:.xlsx} extension is automatically appended if omitted.

{phang}
    {opt replace} permits overwriting an existing file. Use when regenerating 
    updated reports for ongoing survey monitoring.

{phang}
    {opt sheetname(}{it:string}{opt)} assigns a custom prefix to report sheets. 
    Default: {bf:Summary} and {bf:Data_report}
    With sheetname(round2): {bf:round2_Summary}, {bf:round2_Data_report}

{title:Output Features}

{pstd}
    {bf:Summary Sheet - Dataset Health Dashboard}
    {space 4}{bf:·} Dataset identification and metadata
    {space 4}{bf:·} File characteristics (size, path, modified date)
    {space 4}{bf:·} Observation and variable inventory
    {space 4}{bf:·} {bf:Critical quality metrics}: 
    {space 8}{bull} Complete missing variables (red flag)
    {space 8}{bull} Variables missing labels
    {space 8}{bull} String vs numeric distribution
    {space 4}{bf:·} One-glance data quality assessment

{pstd}
    {bf:Data_report Sheet - Variable-Level Forensics}
    {space 4}{bf:·} Complete variable census with storage types
    {space 4}{bf:·} Label completeness check
    {space 4}{bf:·} Missing data patterns (non-missing/missing counts)
    {space 4}{bf:·} {bf:Full value label documentation} - ALL defined mappings
    {space 4}{bf:·} Intelligent statistics by variable type:
    {space 8}{bull} {it:Numeric}: Min, Max, Mean
    {space 8}{bull} {it:String}: Length distribution, missing patterns
    {space 8}{bull} {it:Categorical}: Percentage distributions with labels
    {space 8}{bull} {it:Binary}: Proportion analysis

{title:Survey Monitoring Workflow}

{pstd}
    {bf:Daily Field Data Check}
    {phang2}
        * Morning check of yesterday's collected data
        . use "survey_data_day2.dta", clear
        . datareport using "monitoring/day2_report.xlsx", replace
        . * Review missing patterns and label issues before fieldwork starts

{pstd}
    {bf:Weekly Supervisor Report}
    {phang2}
        * Aggregate weekly collection and generate supervisor brief
        . append using "week1.dta" "week2.dta"
        . label data "Health Survey - Week 2 Progress"
        . datareport using "briefings/supervisor_week2.xlsx", replace

{pstd}
    {bf:Endline Quality Audit}
    {phang2}
        * Final dataset certification before analysis
        . use "final_survey_data.dta", clear
        . datareport using "audit/final_quality_certificate.xlsx", sheetname(endline)
        . * Attach to data delivery documentation

{title:Technical Requirements}

{pstd}
    {bf:Stata}
    {space 4}Version {bf:16.0} or higher
    {space 4}No additional Stata packages required

{pstd}
    {bf:Python (for Excel formatting)}
    {space 4}Required package: {bf:openpyxl} ≥ 3.0.0
    {space 4}{bf:One-time installation command}:
    {phang2}
        . python -m pip install openpyxl
        
{pstd}
    {bf:Verify Python setup}:
    {phang2}
        . python query
        . python -c "import openpyxl; print(f'openpyxl {openpyxl.__version__}')"

{pstd}
    {bf:No Python? No problem!}
    {space 4}Report still generates successfully - only advanced Excel formatting is skipped.
    {space 4}Basic data export works on all Stata installations.


{title:Examples}

{pstd}
    {bf:Basic survey quality check}
    {phang2}
        . use "lsms_data.dta", clear
        . datareport using "lsms_qc.xlsx"

{pstd}
    {bf:Multi-round survey monitoring}
    {phang2}
        local rounds "baseline midline endline"
        foreach r in `rounds' {
            use "survey_`r'.dta", clear
            datareport using "reports/`r'_check.xlsx", replace sheetname(`r')
        }

{pstd}
    {bf:Rapid assessment for supervisors}
    {phang2}
        capture program drop quickcheck
        program define quickcheck
            syntax using/
            datareport using "`using'", replace
            di as result _n "{bf:Quick Check Complete - Review Summary sheet for red flags}"
        end
        
        . quickcheck using "field_data_today.xlsx"

{title:Developer}

{pstd}
    {bf:Md. Redoan Hossain Bhuiyan}
    {space 4}{bf:Email}: {browse "mailto:redoanhossain630@gmail.com":redoanhossain630@gmail.com}
    {space 4}{bf:GitHub}: {browse "https://github.com/RanaRedoan":github.com/RanaRedoan}
    {space 4}{bf:Published}: 10 February 2026
    {space 4}{bf:Version}: 1.0.5

{title:More Stata Packages by Author}

{pstd}
    {bf:Explore my other Stata tools on GitHub}:
    
    {space 4}{bull} {browse "https://github.com/RanaRedoan/exporttabs":{bf:exporttabs}} - Automates exporting frequency and cross-tabulation tables to Excel for all variables of any dataset   
    {space 4}{bull} {browse "https://github.com/RanaRedoan/biascheck":{bf:biascheck}} - Identifies potential enumerator bias in survey responses    
    {space 4}{bull} {browse "https://github.com/RanaRedoan/outlierdetect":{bf:outlierdetect}} - Intelligent multivariate outlier detection for any dataset    
    {space 4}{bull} {browse "https://github.com/RanaRedoan/optcounts":{bf:optcounts}} - Tracks frequency of user-defined special values (e.g., -99, 99, -999 -96)
    {space 4}{bull} {browse "https://github.com/RanaRedoan/gencodebook":{bf:gencodebookt}} -Generate professional codebook

{pstd}
    {bf:⭐ Star these repositories on GitHub to show support!}

{title:Citation}

{pstd}
    If {bf:datareport} contributes to your research or operational workflow, 
    please cite:

{pmore}
    Bhuiyan, M.R.H. (2026). datareport: Lightning-fast survey data quality 
    reporting for Stata (Version 1.0.5) [Software]. Available from 
    {browse "https://github.com/RanaRedoan/datareport":https://github.com/RanaRedoan/datareport}

{title:See Also}

{psee}
    {bf:Documentation}: {browse "https://github.com/RanaRedoan/datareport":GitHub Repository}
    {p_end}
{psee}
    {bf:Report Issues}: {browse "https://github.com/RanaRedoan/datareport/issues":Issue Tracker}
    {p_end}
{psee}
    {bf:Related Stata commands}: {help describe}, {help codebook}, {help label}, {help export excel}
    {p_end}
{psee}
    {bf:Python integration}: {help python}
    {p_end}

{title:Acknowledgments}

{pstd}
    Special thanks to the Stata community and field survey teams whose 
    feedback shaped this tool. Your daily data quality challenges inspired 
    every feature.

{hline}
{pstd}
    {bf:datareport} version 1.0.5 | {browse "https://github.com/RanaRedoan":RanaRedoan on GitHub} | {bf:10 Feb 2026}
{hline}
