{smcl}
{* *! version 1.0.5 10feb2026}{...}
{hline}
help for {hi:datareport} {right:version 1.0.5}
{hline}

{title:Title}

{p 4 4 2}
{bf:datareport} - Lightning-fast survey data quality reporting with comprehensive Excel diagnostics
{p_end}

{title:Syntax}

{p 8 17 2}
{cmd:datareport} {cmd:using} {it:filename}
[{cmd:,} {opt replace} {opt sheetname(string)}]
{p_end}

{title:Description}

{p 4 4 2}
{bf:datareport} is a high-performance survey data quality assessment tool that generates professionally formatted Excel reports in seconds. It is designed for ongoing survey monitoring and rapid data quality checks.
{p_end}

{p 4 4 2}
It transforms raw datasets into comprehensive diagnostic workbooks with minimal setup and no manual Excel formatting.
{p_end}

{p 4 4 2}
{bf:Why datareport?}
{p_end}

{p 8 8 2}
{bull} {bf:Speed}: Generate complete reports in under 3 seconds for datasets up to 100K observations.
{p_end}

{p 8 8 2}
{bull} {bf:Simplicity}: Single command with no complex programming workflow.
{p_end}

{p 8 8 2}
{bull} {bf:Completeness}: Captures all defined value labels, not only observed values.
{p_end}

{p 8 8 2}
{bull} {bf:Professionalism}: Produces auto-formatted Excel output with styled worksheets.
{p_end}

{p 4 4 2}
{bf:Perfect for}
{p_end}

{p 8 8 2}
{bull} Daily survey monitoring reports.
{p_end}

{p 8 8 2}
{bull} Data quality audits during field data collection.
{p_end}

{p 8 8 2}
{bull} Quick metadata documentation for collaborative projects.
{p_end}

{p 8 8 2}
{bull} Supervisor briefings and stakeholder updates.
{p_end}

{p 8 8 2}
{bull} Training and teaching data management workflows.
{p_end}

{title:Quick Start}

{p 4 4 2}
{bf:1. Install Python dependency (one-time setup)}
{p_end}

{phang2}
{cmd:. python -m pip install openpyxl}
{p_end}

{p 4 4 2}
{bf:2. Generate your first report}
{p_end}

{phang2}
{cmd:. sysuse auto, clear}
{p_end}

{phang2}
{cmd:. datareport using "auto_quality_check.xlsx"}
{p_end}

{p 4 4 2}
{bf:3. Review output}
{p_end}

{phang2}
Data Report Generated Successfully
{p_end}

{phang2}
Output file   : auto_quality_check.xlsx
{p_end}

{phang2}
Dataset       : auto
{p_end}

{phang2}
Observations  : 74
{p_end}

{phang2}
Variables     : 12
{p_end}

{phang2}
Report sheets : Summary, Data_report
{p_end}

{title:Options}

{phang}
{opt using} specifies the Excel filename for the output report. The {it:.xlsx} extension is appended if omitted.
{p_end}

{phang}
{opt replace} permits overwriting an existing file.
{p_end}

{phang}
{opt sheetname(}{it:string}{opt)} assigns a custom prefix to report sheet names. The default output uses {bf:Summary} and {bf:Data_report}. With {cmd:sheetname(round2)}, the sheets become {bf:round2_Summary} and {bf:round2_Data_report}.
{p_end}

{title:Output Features}

{p 4 4 2}
{bf:Summary sheet}
{p_end}

{p 8 8 2}
{bull} Dataset identification and metadata.
{p_end}

{p 8 8 2}
{bull} File characteristics such as size, path, and modified date.
{p_end}

{p 8 8 2}
{bull} Observation and variable inventory.
{p_end}

{p 8 8 2}
{bull} Critical quality metrics, including completely missing variables, missing labels, and numeric-versus-string distribution.
{p_end}

{p 4 4 2}
{bf:Data_report sheet}
{p_end}

{p 8 8 2}
{bull} Variable census with storage types.
{p_end}

{p 8 8 2}
{bull} Label completeness check.
{p_end}

{p 8 8 2}
{bull} Missing data patterns with nonmissing and missing counts.
{p_end}

{p 8 8 2}
{bull} Full value label documentation for all defined mappings.
{p_end}

{p 8 8 2}
{bull} Type-aware statistics for numeric, string, categorical, and binary variables.
{p_end}

{title:Survey Monitoring Workflow}

{p 4 4 2}
{bf:Daily field data check}
{p_end}

{phang2}
{cmd:. use "survey_data_day2.dta", clear}
{p_end}

{phang2}
{cmd:. datareport using "monitoring/day2_report.xlsx", replace}
{p_end}

{p 4 4 2}
{bf:Weekly supervisor report}
{p_end}

{phang2}
{cmd:. append using "week1.dta" "week2.dta"}
{p_end}

{phang2}
{cmd:. label data "Health Survey - Week 2 Progress"}
{p_end}

{phang2}
{cmd:. datareport using "briefings/supervisor_week2.xlsx", replace}
{p_end}

{p 4 4 2}
{bf:Endline quality audit}
{p_end}

{phang2}
{cmd:. use "final_survey_data.dta", clear}
{p_end}

{phang2}
{cmd:. datareport using "audit/final_quality_certificate.xlsx", sheetname(endline)}
{p_end}

{title:Technical Requirements}

{p 4 4 2}
{bf:Stata}
{p_end}

{p 8 8 2}
Version 16.0 or higher.
{p_end}

{p 8 8 2}
No additional Stata packages required.
{p_end}

{p 4 4 2}
{bf:Python}
{p_end}

{p 8 8 2}
Recommended package: {bf:openpyxl} 3.0.0 or higher.
{p_end}

{phang2}
{cmd:. python -m pip install openpyxl}
{p_end}

{p 4 4 2}
{bf:Verify Python setup}
{p_end}

{phang2}
{cmd:. python query}
{p_end}

{phang2}
{cmd:. python -c "import openpyxl; print(openpyxl.__version__)"}
{p_end}

{p 4 4 2}
If Python or {bf:openpyxl} is not available, the report still exports, but advanced Excel formatting may be skipped.
{p_end}

{title:Examples}

{p 4 4 2}
{bf:Basic survey quality check}
{p_end}

{phang2}
{cmd:. use "lsms_data.dta", clear}
{p_end}

{phang2}
{cmd:. datareport using "lsms_qc.xlsx"}
{p_end}

{p 4 4 2}
{bf:Multi-round survey monitoring}
{p_end}

{phang2}
{cmd:. local rounds "baseline midline endline"}
{p_end}

{phang2}
{cmd:. foreach r in `rounds' \{}
{p_end}

{phang2}
{cmd:> use "survey_`r'.dta", clear}
{p_end}

{phang2}
{cmd:> datareport using "reports/`r'_check.xlsx", replace sheetname(`r')}
{p_end}

{phang2}
{cmd:> \}}
{p_end}

{p 4 4 2}
{bf:Rapid assessment for supervisors}
{p_end}

{phang2}
{cmd:. capture program drop quickcheck}
{p_end}

{phang2}
{cmd:. program define quickcheck}
{p_end}

{phang2}
{cmd:> syntax using/}
{p_end}

{phang2}
{cmd:> datareport using "`using'", replace}
{p_end}

{phang2}
{cmd:> di as result _n "Quick Check Complete - Review Summary sheet for red flags"}
{p_end}

{phang2}
{cmd:> end}
{p_end}

{phang2}
{cmd:. quickcheck using "field_data_today.xlsx"}
{p_end}

{title:Developer}

{p 4 4 2}
{bf:Md. Redoan Hossain Bhuiyan}
{p_end}

{p 8 8 2}
{bf:Email}: {browse "mailto:redoanhossain630@gmail.com":redoanhossain630@gmail.com}
{p_end}

{p 8 8 2}
{bf:GitHub}: {browse "https://github.com/RanaRedoan":github.com/RanaRedoan}
{p_end}

{p 8 8 2}
{bf:Published}: 10 February 2026
{p_end}

{p 8 8 2}
{bf:Version}: 1.0.5
{p_end}

{title:More Stata Packages by Author}

{p 8 8 2}
{bull} {browse "https://github.com/RanaRedoan/exporttabs":{bf:exporttabs}} - Export frequency and cross-tabulation tables to Excel.
{p_end}

{p 8 8 2}
{bull} {browse "https://github.com/RanaRedoan/biascheck":{bf:biascheck}} - Identify potential enumerator bias in survey responses.
{p_end}

{p 8 8 2}
{bull} {browse "https://github.com/RanaRedoan/outlierdetect":{bf:outlierdetect}} - Multivariate outlier detection for survey datasets.
{p_end}

{p 8 8 2}
{bull} {browse "https://github.com/RanaRedoan/optcounts":{bf:optcounts}} - Track user-defined special values such as -99 or 99.
{p_end}

{p 8 8 2}
{bull} {browse "https://github.com/RanaRedoan/gencodebook":{bf:gencodebook}} - Generate professional codebooks.
{p_end}

{title:Citation}

{p 4 4 2}
If {bf:datareport} contributes to your research or operational workflow, please cite:
{p_end}

{pmore}
Bhuiyan, M.R.H. (2026). datareport: Lightning-fast survey data quality reporting for Stata (Version 1.0.5) [Software]. Available from {browse "https://github.com/RanaRedoan/datareport":https://github.com/RanaRedoan/datareport}
{p_end}

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

{p 4 4 2}
Special thanks to the Stata community and field survey teams whose feedback shaped this tool.
{p_end}

{hline}

{p 4 4 2}
{bf:datareport} version 1.0.5 | {browse "https://github.com/RanaRedoan":RanaRedoan on GitHub} | 10 Feb 2026
{p_end}

{hline}
