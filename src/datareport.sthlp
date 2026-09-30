{smcl}
{* *! version 1.4.0 10feb2026}{...}
{viewerjumpto "Syntax" "datareport##syntax"}{...}
{viewerjumpto "Description" "datareport##description"}{...}
{viewerjumpto "Options" "datareport##options"}{...}
{viewerjumpto "Multiple-select questions" "datareport##multi"}{...}
{viewerjumpto "Dates and times" "datareport##dates"}{...}
{viewerjumpto "Output" "datareport##output"}{...}
{viewerjumpto "Examples" "datareport##examples"}{...}
{viewerjumpto "Requirements" "datareport##req"}{...}
{viewerjumpto "Author" "datareport##author"}{...}
{hline}
help for {hi:datareport}{right:version 1.4.0}
{hline}

{title:Title}

{p 4 4 2}
{bf:datareport} {hline 2} Excel data quality report for any Stata dataset
{p_end}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:datareport} {cmd:using} {it:filename} [{cmd:,} {it:options}]
{p_end}

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt replace}}overwrite {it:filename} if it already exists{p_end}
{synopt:{opt sheetname(string)}}prefix for the sheet names{p_end}
{synopt:{opt form(filename)}}XLSForm used to collect the data{p_end}
{synopt:{opt formlang(string)}}label language to read from the form{p_end}
{synopt:{opt nomultiselect}}report one row per variable; do not fold{p_end}
{synoptline}
{p2colreset}{...}

{p 4 6 2}
The {cmd:.xlsx} extension is added to {it:filename} if you omit it.
{p_end}


{marker description}{...}
{title:Description}

{p 4 4 2}
{cmd:datareport} writes a formatted Excel workbook describing every variable in
the dataset in memory: storage type, label, how many observations are present
and missing, the full value-label definition, and a statistic chosen to suit
the variable type.
{p_end}

{p 4 4 2}
It is built for checking survey data while collection is still running, so it
takes one command and no setup. It runs on any dataset, but it understands the
shape of data exported by SurveyCTO, ODK and KoboToolbox, and reports
multiple-select questions the way you would actually want to read them.
{p_end}

{hline}
{p 4 4 2}
{bf:If your data was collected with SurveyCTO, ODK, KoboToolbox or Ona, pass
your XLSForm with} {opt form()}{bf:.}
{p_end}

{phang2}
{cmd:. datareport using "qc.xlsx", replace form("my_survey_form.xlsx")}
{p_end}

{p 4 4 2}
Without the form, {cmd:datareport} has to work out which questions are
multiple-select by reading patterns in the data itself. That works well on a
full dataset, but it gets thin where a question was answered by only a handful
of people, such as a late repeat instance or a question behind a narrow skip.
The form states it outright: which questions are {bf:select_multiple}, which
choice list each one uses, and every option code in that list, including the
ones nobody picked. {bf:The report is materially more accurate with it than
without it.}
{p_end}
{hline}


{marker options}{...}
{title:Options}

{phang}
{opt replace} permits overwriting an existing file.
{p_end}

{phang}
{opt sheetname(string)} puts a prefix on the sheet names. The default sheets
are {bf:Summary} and {bf:Data_report}; with {cmd:sheetname(round2)} they become
{bf:round2_Summary} and {bf:round2_Data_report}. Use it to keep several survey
rounds in one workbook without overwriting each other.
{p_end}

{phang}
{opt form(filename)} supplies the XLSForm that collected the data. Its
{bf:survey} and {bf:choices} sheets are used to confirm which questions are
{bf:select_multiple}, to supply option labels when an exported variable carries
none, and to add a {bf:Form_check} sheet. The command works without it.
{p_end}

{phang}
{opt formlang(string)} chooses the label column of a multi-language form.
{cmd:formlang(English)} matches a column headed {bf:label::English (en)} or
{bf:label:english}. Without it, a plain {bf:label} column is used, then an
English one, then whichever comes first. The code column may be headed
{bf:name} or {bf:value}; both templates are read.
{p_end}

{phang}
{opt nomultiselect} turns off the folding described below, so every variable
gets its own row.
{p_end}


{marker multi}{...}
{title:Multiple-select questions}

{p 4 4 2}
A {bf:select_multiple} question does not export as one variable. It arrives as
a string parent holding the codes the respondent chose, such as {bf:"1 3 98"},
plus one 0/1 variable per option. Listed one row each, a twelve-option question
takes thirteen rows and tells you very little.
{p_end}

{p 4 4 2}
{cmd:datareport} folds the whole block back into one row, in the style of
{bf:mrtab}. The option list goes in the value-label column and each option's
share of cases goes in the statistics column, one option per line:
{p_end}

{p 8 8 2}
{bf:Land = 23.1% (n=237)}
{p_end}
{p 8 8 2}
{bf:House or flat = 13.0% (n=133)}
{p_end}
{p 8 8 2}
{bf:Livestock = 16.0% (n=164)}
{p_end}
{p 8 8 2}
{bf:Cases = 1,024 | Responses = 2,191 | 2.1 per case}
{p_end}

{p 4 4 2}
{bf:Cases} are the respondents who answered the question, that is those whose
parent variable is not missing. Percentages are shares of cases, so they add up
to more than 100 when people choose more than one option. {bf:Responses} is the
total number of options ticked. Options that nobody selected are still listed,
at 0%, because a choice the field team never used is worth seeing.
{p_end}

{p 4 4 2}
Detection does not go by variable names. An option variable is attached to a
question only when it is 0/1 {it:and} equals 1 in exactly the observations whose
parent holds that code. That test is what keeps an ordinary repeat group, such
as loan 1 to loan 5, from being mistaken for the options of one question.
{p_end}

{p 4 4 2}
The naming scheme is settled once per question, by counting how many option
variables each reading produces, never option by option. The two namings
collide: for a parent {bf:Q_k}, the name {bf:Q_k_c} reads as "option c of Q_k"
while {bf:Q_c_k} reads as "option c of repeat k", and when c equals k they are
the same variable. Deciding option by option lets a two-respondent instance tie
and fall the wrong way.
{p_end}

{p 4 4 2}
The parent is usually a string, but when every respondent happens to tick
exactly one option the exporter types that column as a plain integer instead.
That is common in the later instances of a repeat group, where only a handful
of cases remain. Numeric parents are read the same way, so those instances are
not skipped.
{p_end}

{p 4 4 2}
A {it:labelled} numeric parent looks exactly like a {bf:select_one}, because
every respondent picked one code, and applying value labels during cleaning
creates precisely that situation. Nothing in the data can tell the two apart,
so {cmd:datareport} needs either the form or an already-confirmed instance of
the same repeat question before it will fold one. This is the clearest case
where {opt form()} changes the answer.
{p_end}

{p 4 4 2}
A question asked inside a {bf:repeat} group is reported once per repeat
instance, because each instance has its own denominator. Once one instance is
confirmed, the rest inherit its option list, so an instance with two respondents
is still reported against the full option list. Any {it:other, specify} text
field keeps a row of its own.
{p_end}


{marker dates}{...}
{title:Dates and times}

{p 4 4 2}
A Stata date is a count of days since 1960, and a date-time is a count of
milliseconds, so {bf:Min}, {bf:Max} and {bf:Avg} of one reads as nonsense.
These variables report their range instead:
{p_end}

{p 8 8 2}
{bf:First date = 10 Sep 2025}
{p_end}
{p 8 8 2}
{bf:Last date = 14 Sep 2026}
{p_end}
{p 8 8 2}
{bf:Span = 369 days}
{p_end}

{p 4 4 2}
A date-time such as {bf:SubmissionDate}, {bf:starttime} or {bf:endtime} reports
{bf:First} and {bf:Last} to the second, which gives you the first and last
submission of the round at a glance.
{p_end}

{p 4 4 2}
The display format is the signal used. Where the export left the format off,
a date-time is still recognised from its value range, which is distinctive; a
plain date additionally needs a date-like variable name before it is treated as
one, since a bare day count is easy to confuse with an ordinary number. A
duration in seconds or a count of days is therefore left as {bf:Min}, {bf:Max}
and {bf:Avg}, which is what you want for it.
{p_end}

{p 4 4 2}
SurveyCTO and Kobo write some timestamps as text. Those columns are parsed
where the values look like dates, and reported the same way; anything that does
not parse falls back to the character-length summary.
{p_end}


{marker output}{...}
{title:Output}

{p 4 4 2}
{bf:Summary} {hline 2} dataset title, observations, variables, file path and
size, counts of string and numeric variables, completely missing variables,
variables with no label, and how many multiple-select questions were found.
{p_end}

{p 4 4 2}
{bf:Data_report} {hline 2} one row per variable, or per question for
multiple-select. Columns are variable, label, type, observation, missing,
value_label and result.
{p_end}

{p 4 4 2}
{bf:Form_check} {hline 2} written only when {opt form()} is given. Lists
questions in the form that produced no variable in the data, and variables in
the data that no form question accounts for.
{p_end}


{marker examples}{...}
{title:Examples}

{p 4 4 2}
{bf:A quick look at any dataset}
{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. datareport using "auto_report.xlsx", replace}{p_end}

{p 4 4 2}
{bf:Daily check during fieldwork}
{p_end}

{phang2}{cmd:. use "survey_day2.dta", clear}{p_end}
{phang2}{cmd:. datareport using "monitoring/day2.xlsx", replace}{p_end}

{p 4 4 2}
{bf:With the XLSForm, to cross-check form against data}
{p_end}

{phang2}{cmd:. datareport using "qc.xlsx", replace form("survey_form.xlsx")}{p_end}

{p 4 4 2}
{bf:A form with more than one language}
{p_end}

{phang2}{cmd:. datareport using "qc.xlsx", replace form("form.xlsx") formlang("English")}{p_end}

{p 4 4 2}
{bf:Two rounds in one workbook}
{p_end}

{phang2}{cmd:. use "baseline.dta", clear}{p_end}
{phang2}{cmd:. datareport using "monitoring.xlsx", replace sheetname(baseline)}{p_end}
{phang2}{cmd:. use "endline.dta", clear}{p_end}
{phang2}{cmd:. datareport using "monitoring.xlsx", sheetname(endline)}{p_end}


{marker req}{...}
{title:Requirements}

{p 4 4 2}
Stata 16.0 or later. No other Stata packages are needed.
{p_end}

{p 4 4 2}
Python with {bf:openpyxl} is used for the Excel styling: a title bar naming the
dataset, a frozen and filterable header row, banded rows, tuned column widths,
counts written as real numbers you can sort and filter, option cells wrapped one
option per line with the row sized to fit, multiple-select rows tinted so they
stand out, and all-missing variables flagged in red. Install it once with:
{p_end}

{phang2}{cmd:. python -m pip install openpyxl}{p_end}

{p 4 4 2}
Without it the workbook is still written, but it is left unformatted.
{p_end}


{title:Troubleshooting}

{p 4 4 2}
{bf:The workbook is not formatted.} {bf:openpyxl} is missing, or Stata cannot
find Python. Check with {cmd:python query}.
{p_end}

{p 4 4 2}
{bf:A multiple-select question was not folded.} Its parent string variable is
probably missing from the export, or the option variables are not coded 0/1.
Pass {opt form()} to help, or use {opt nomultiselect} to see every variable.
{p_end}

{p 4 4 2}
{bf:A file permission error.} The workbook is open in Excel, or the folder is
not writable.
{p_end}


{marker author}{...}
{title:Author}

{p 4 4 2}
Md. Redoan Hossain Bhuiyan
{p_end}

{p 4 4 2}
{browse "mailto:redoanhossain630@gmail.com":redoanhossain630@gmail.com}
{break}
{browse "https://github.com/RanaRedoan":github.com/RanaRedoan}
{p_end}

{p 4 4 2}
Please cite as: Bhuiyan, M.R.H. (2026). {it:datareport: survey data quality
reporting for Stata} (Version 1.4.0).
{browse "https://github.com/RanaRedoan/datareport":github.com/RanaRedoan/datareport}
{p_end}


{title:Other packages by the author}

{p 4 8 2}
{browse "https://github.com/RanaRedoan/exporttabs":{bf:exporttabs}} {hline 2}
export frequency and cross-tabulation tables to Excel
{p_end}
{p 4 8 2}
{browse "https://github.com/RanaRedoan/biascheck":{bf:biascheck}} {hline 2}
identify potential enumerator bias in survey responses
{p_end}
{p 4 8 2}
{browse "https://github.com/RanaRedoan/outlierdetect":{bf:outlierdetect}} {hline 2}
multivariate outlier detection for survey datasets
{p_end}
{p 4 8 2}
{browse "https://github.com/RanaRedoan/optcounts":{bf:optcounts}} {hline 2}
track user-defined special values such as -99 or 99
{p_end}
{p 4 8 2}
{browse "https://github.com/RanaRedoan/gencodebook":{bf:gencodebook}} {hline 2}
generate professional codebooks
{p_end}


{title:Also see}

{p 4 8 2}
Help: {help describe}, {help codebook}, {help label}, {help export excel},
{help python}
{p_end}
{p 4 8 2}
Issues: {browse "https://github.com/RanaRedoan/datareport/issues":github.com/RanaRedoan/datareport/issues}
{p_end}
