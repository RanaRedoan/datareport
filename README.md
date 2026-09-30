# datareport

**Excel data quality report for any Stata dataset — in one command.**

`datareport` writes a formatted Excel workbook describing every variable in the
dataset in memory: storage type, label, how many observations are present and
missing, the full value-label definition, and a statistic chosen to suit the
variable type.

It is built for checking survey data while collection is still running, so it
takes one command and no setup. It runs on any dataset, but it understands the
shape of data exported by SurveyCTO, ODK and KoboToolbox — and reports
multiple-select questions the way you would actually want to read them.

> [!IMPORTANT]
> **Working with data collected by SurveyCTO, ODK, KoboToolbox or Ona? Pass your
> XLSForm with `form()`.**
>
> ```stata
> datareport using "qc.xlsx", replace form("my_survey_form.xlsx")
> ```
>
> Without the form, `datareport` has to work out which questions are
> multiple-select by reading patterns in the data itself. That works well on a
> full dataset, but it gets thin where a question was answered by only a handful
> of people — a late repeat instance, or a question behind a narrow skip. The
> form states it outright: which questions are `select_multiple`, which choice
> list each uses, and every option code in that list, including the ones nobody
> picked. **You get a materially more accurate report with it than without it.**

---

## Install

```stata
net install datareport, from("https://raw.githubusercontent.com/RanaRedoan/datareport/main/") replace
```

Then check it is there:

```stata
which datareport
help datareport
```

## Requirements

| | |
|---|---|
| Stata | 16.0 or later. No other Stata packages needed. |
| Python + `openpyxl` | Used for the Excel styling. Install once: `python -m pip install openpyxl` |

Without `openpyxl` the workbook is still written, but it is left unformatted.

---

## Syntax

```stata
datareport using filename [, replace sheetname(string) form(filename) formlang(string) nomultiselect]
```

| Option | Description |
|---|---|
| `replace` | Overwrite `filename` if it already exists |
| `sheetname()` | Prefix for the sheet names, so several rounds can share one workbook |
| `form()` | XLSForm used to collect the data (SurveyCTO / ODK / Kobo) |
| `formlang()` | Label language to read from the form, e.g. `formlang(English)`. Matches `label::English (en)` and `label:english`. Without it: a plain `label` column, then an English one, then the first found |
| `nomultiselect` | Report one row per variable; do not fold |

The `.xlsx` extension is added to `filename` if you omit it.

---

## Multiple-select questions

A `select_multiple` question does not export as one variable. It arrives as a
string parent holding the codes the respondent chose, such as `"1 3 98"`, plus
one 0/1 variable per option. Listed one row each, a twelve-option question takes
thirteen rows and tells you very little.

`datareport` folds the whole block back into one row, in the style of `mrtab`.
The option list goes in the value-label column and each option's share of cases
goes in the statistics column, one option per line with wrap text on, so the
cell reads like a small table:

```
Land = 23.1% (n=237)
House or flat = 13.0% (n=133)
Livestock = 16.0% (n=164)
Agricultural equipment = 2.0% (n=20)
Savings or bank account = 72.0% (n=737)
Other = 1.0% (n=10)
Cases = 1,024 | Responses = 2,191 | 2.1 per case
```

- **Cases** are the respondents who answered the question. Percentages are
  shares of cases, so they add up to more than 100% when people choose more than
  one option.
- **Responses** is the total number of options ticked.
- **Options nobody selected** are still listed, at 0% — a choice the field team
  never used is worth seeing.
- **Detection does not go by variable names.** An option variable is attached to
  a question only when it is 0/1 *and* equals 1 in exactly the observations whose
  parent holds that code. That test is what keeps an ordinary repeat group, such
  as loan 1 to loan 5, from being mistaken for the options of one question.
- **The naming scheme is decided once per question**, by counting how many option
  variables each reading produces — never option by option. This matters because
  the two namings collide: for a parent `Q_k`, the name `Q_k_c` reads as "option
  c of `Q_k`", while `Q_c_k` reads as "option c of repeat k", and when `c` equals
  `k` they are the same variable. Deciding per option lets a two-respondent
  instance tie and fall the wrong way.
- **The parent is not always a string.** When every respondent happens to tick
  exactly one option, the exporter types that column as a plain integer — common
  in the later instances of a repeat group, where only a handful of cases remain.
  Numeric parents are read the same way, so those instances are not skipped.
- **A labelled numeric parent looks exactly like a `select_one`**, since every
  respondent picked one code. Applying value labels during cleaning creates
  precisely this situation. Nothing in the data can tell the two apart, so
  `datareport` needs either the form or an already-confirmed instance of the same
  repeat question before it will fold one. **This is the clearest case where
  passing `form()` changes the answer.**
- **Questions inside a repeat group** are reported once per repeat instance,
  because each instance has its own denominator. Once one instance is confirmed,
  the rest inherit its option list, so an instance with two respondents is still
  reported against the full option list. *Other, specify* text fields keep a row
  of their own.

---

## Dates and times

A Stata date is a count of days since 1960 and a date-time is a count of
milliseconds, so `Min`, `Max` and `Avg` of one reads as nonsense
(`Min=23994.00`). These variables report their range instead:

```
First date = 10 Sep 2025
Last date = 14 Sep 2026
Span = 369 days
```

A date-time such as `SubmissionDate`, `starttime` or `endtime` reports `First`
and `Last` to the second, which gives you the first and last submission of the
round at a glance.

The display format is the signal used. Where the export left the format off, a
date-time is still recognised from its value range, which is distinctive; a plain
date additionally needs a date-like variable name before it is treated as one,
since a bare day count is easy to confuse with an ordinary number. A `duration`
in seconds is therefore left as `Min`, `Max` and `Avg` — which is what you want
for it.

SurveyCTO and Kobo write some timestamps as text. Those columns are parsed where
the values look like dates and reported the same way; anything that does not
parse falls back to the character-length summary.

---

## What you get

**Summary** — dataset title, observations, variables, file path and size, counts
of string and numeric variables, completely missing variables, variables with no
label, and how many multiple-select questions were found.

**Data_report** — one row per variable, or per question for multiple-select:

| variable | label | type | observation | missing | value_label | result |
|---|---|---|---|---|---|---|
| age | Age in years | byte | 1,024 | 0 | | Min=18.00, Max=65.00, Avg=37.82 |
| Sa_q2 | Marital status | byte | 1,024 | 0 | 1 = Married<br>2 = Widowed<br>3 = Divorced | Married = 95.41%<br>Widowed = 2.93%<br>Divorced = 0.88% |
| Sa_q13 | Assets owned | select_multiple (10 opts) | 1,024 | 0 | 1 = Land<br>2 = House or flat<br>… | Land = 23.1% (n=237)<br>House or flat = 13.0% (n=133)<br>… |

**Form_check** — written only when `form()` is given. Lists questions in the form
that produced no variable in the data, and variables in the data that no form
question accounts for.

---

## Examples

A quick look at any dataset:

```stata
sysuse auto, clear
datareport using "auto_report.xlsx", replace
```

Daily check during fieldwork:

```stata
use "survey_day2.dta", clear
datareport using "monitoring/day2.xlsx", replace
```

With the XLSForm, to cross-check form against data:

```stata
datareport using "qc.xlsx", replace form("survey_form.xlsx")
```

A form with more than one language:

```stata
datareport using "qc.xlsx", replace form("form.xlsx") formlang("English")
```

Several rounds in one workbook:

```stata
foreach r in baseline midline endline {
    use "survey_`r'.dta", clear
    datareport using "monitoring.xlsx", sheetname(`r')
}
```

---

## Troubleshooting

| Problem | Cause |
|---|---|
| Workbook is not formatted | `openpyxl` missing, or Stata cannot find Python. Check with `python query`. |
| A multiple-select question was not folded | Its parent string variable is missing from the export, or the option variables are not coded 0/1. Pass `form()` to help, or use `nomultiselect` to see every variable. |
| File permission error | The workbook is open in Excel, or the folder is not writable. |

---

## Author

**Md. Redoan Hossain Bhuiyan**
[redoanhossain630@gmail.com](mailto:redoanhossain630@gmail.com) ·
[github.com/RanaRedoan](https://github.com/RanaRedoan)

Please cite as: Bhuiyan, M.R.H. (2026). *datareport: survey data quality
reporting for Stata* (Version 1.3.0).
https://github.com/RanaRedoan/datareport

## Other packages by the author

| Package | What it does |
|---|---|
| [exporttabs](https://github.com/RanaRedoan/exporttabs) | Export frequency and cross-tabulation tables to Excel |
| [biascheck](https://github.com/RanaRedoan/biascheck) | Identify potential enumerator bias in survey responses |
| [outlierdetect](https://github.com/RanaRedoan/outlierdetect) | Multivariate outlier detection for survey datasets |
| [optcounts](https://github.com/RanaRedoan/optcounts) | Track user-defined special values such as -99 or 99 |
| [gencodebook](https://github.com/RanaRedoan/gencodebook) | Generate professional codebooks |

## License

MIT. See [LICENSE](LICENSE).

Bug reports and suggestions: [github.com/RanaRedoan/datareport/issues](https://github.com/RanaRedoan/datareport/issues)
