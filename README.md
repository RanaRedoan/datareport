# datareport

**An Excel data-quality report for any Stata dataset, in one command.**

`datareport` describes every variable in the dataset in memory and writes the result to a
formatted Excel workbook: type, label, how many observations are filled and missing, the
full value-label definition, and a summary that suits the variable (percentages for
categories, min/max/mean for numbers, first/last date for dates).

It is built for checking survey data while fieldwork is still running. It works on any
dataset, and it understands data exported by SurveyCTO, ODK and KoboToolbox. For example,
it folds each multiple-select question into one readable row.

> [!IMPORTANT]
> **Data collected with SurveyCTO, ODK, KoboToolbox or Ona? Pass your XLSForm with `form()`.**
>
> ```stata
> datareport using "qc.xlsx", replace form("my_survey_form.xlsx")
> ```
>
> The form says exactly which questions are multiple-select and lists every option,
> including the ones nobody picked. Without it, `datareport` has to guess from patterns in
> the data, which gets unreliable where only a few people answered. **The report is
> noticeably more accurate with the form.**

---

## Contents

1. [Quick start](#quick-start)
2. [Requirements](#requirements)
3. [Setting up Python (one time per computer)](#setting-up-python-one-time-per-computer)
4. [Syntax and options](#syntax-and-options)
5. [What you get](#what-you-get)
6. [Multiple-select questions](#multiple-select-questions)
7. [Dates and times](#dates-and-times)
8. [Examples](#examples)
9. [Troubleshooting](#troubleshooting)
10. [Author](#author)

---

## Quick start

**1. Install** (in Stata):

```stata
net install datareport, from("https://raw.githubusercontent.com/RanaRedoan/datareport/main/") replace
```

**2. Run it** on the dataset in memory:

```stata
datareport using "my_report.xlsx", replace
```

**3. Set up Python** once, so the workbook comes out formatted. See
[Setting up Python](#setting-up-python-one-time-per-computer) below.

> [!TIP]
> Stata can't reach GitHub (error `r(677)`)? On the repository page, click
> **Code → Download ZIP**, unzip it, and install from the folder that contains
> `stata.toc`:
>
> ```stata
> net install datareport, from("C:/Users/<you>/Downloads/datareport-main") replace
> ```

---

## Requirements

| What | Why |
|---|---|
| **Stata 16 or later** | Required. No other Stata packages are needed. |
| **Python 3 with `openpyxl`** | Used only to format the workbook. Python 3.13 is recommended. |

Without Python the report is still written, with all the same content, just unformatted.
**Stata does not show an error in that case**, so if your workbook comes out plain, Python
is the first thing to check.

---

## Setting up Python (one time per computer)

`datareport` uses whichever Python Stata is set to use, and that Python must have the
`openpyxl` package. These steps are for Windows.

> [!WARNING]
> **Use Python 3.13 (64-bit).** Python 3.14 removed something Stata relied on. Stata 18 and
> 19 handle it only after the 12 November 2025 update; with older Stata it can fail with
> error `r(7100)`. Python 3.13 avoids the problem, and it can sit next to 3.14 without
> conflict.

### Step 1: See what you already have (in Stata)

```stata
python search
```

This lists every Python on the computer. The version is in the folder name, for example
`Python313` or `pythoncore-3.13-64`.

| What you find | What to do |
|---|---|
| No Python at all | Install the **Python install manager** from [python.org/downloads](https://www.python.org/downloads/), then run `py install 3.13` in Command Prompt. |
| Only Python 3.14 | Run `py install 3.13` in Command Prompt to add 3.13 next to it. If `py install` gives an error, get the install manager first (row above). On Stata 18/19 you may instead run `update all` in Stata and keep 3.14. |
| Python 3.13 or an older 3.x | Nothing to install. In step 2, use your version number instead of 3.13 (for example `-3.12`). |

### Step 2: Find the exact path of that Python (in Command Prompt)

```
py -3.13 -c "import sys; print(sys.executable)"
```

Copy the line it prints; you will need it in steps 3 and 4. It usually looks like one of
these:

```
C:\Users\<you>\AppData\Local\Python\pythoncore-3.13-64\python.exe      (install manager)
C:\Users\<you>\AppData\Local\Programs\Python\Python313\python.exe      (classic installer)
```

If `py` can't find your Python, use the path that `python search` showed in step 1. Don't
use a path containing `WindowsApps`: that is only a shortcut to the Microsoft Store, not a
real Python.

### Step 3: Install openpyxl into that same Python (in Command Prompt)

```
"C:\Users\<you>\...\python.exe" -m pip install openpyxl
```

Paste your path from step 2 inside the quotes, and paste the line only once. Wait for
**Successfully installed openpyxl** (or **Requirement already satisfied**).

Always use the full path here. A plain `pip install openpyxl` can put the package into a
different Python from the one Stata uses, which is the most common reason setup "doesn't
work".

### Step 4: Point Stata to that Python (in Stata)

```stata
python set exec "C:\Users\<you>\...\python.exe", permanently
```

### Step 5: Restart Stata and confirm

**Close Stata completely and reopen it.** Stata reads its Python settings only once per
session, so changes do nothing until you restart. Then run:

```stata
python query
python which openpyxl
```

`python query` should show your version (for example 3.13.x), and `python which openpyxl`
should print `<module 'openpyxl' from '...'>`. Run `discard`, then `datareport`. The
workbook now comes out formatted.

> [!NOTE]
> On macOS the Stata commands are the same. Install openpyxl with the Python path that
> `python query` shows: `"/path/to/python3" -m pip install openpyxl`.

---

## Syntax and options

```stata
datareport using filename [, replace sheetname(string) form(filename) formlang(string) nomultiselect]
```

| Option | What it does |
|---|---|
| `replace` | Overwrite `filename` if it already exists. |
| `sheetname(string)` | Put a prefix on the sheet names, so several rounds can share one workbook. With `sheetname(round2)` the sheets become `round2_Summary`, `round2_Data_report` and `round2_Form_check`. |
| `form(filename)` | The XLSForm used to collect the data. Confirms which questions are multiple-select, supplies option labels, and adds a `Form_check` sheet. |
| `formlang(string)` | Which label language to read from a multi-language form, e.g. `formlang(English)`. Matches columns such as `label::English (en)` or `label:english`. Without it: a plain `label` column, then an English one, then the first found. |
| `nomultiselect` | Turn off the folding of multiple-select questions; every variable gets its own row. |

If you leave the `.xlsx` extension off `filename`, it is added for you.

---

## What you get

The workbook has up to three sheets.

| Sheet | What's in it |
|---|---|
| **Summary** | Dataset title, report date, observations, variables, file path and size, counts of string and numeric variables, fully missing variables, variables without a label, and how many multiple-select questions were found. With `form()`, also how many form questions are missing from the data and the other way round. |
| **Data_report** | One row per variable, or one row per multiple-select question. Columns: Variable, Label, Type, Non-missing, Missing, Value labels, Summary. |
| **Form_check** | Only with `form()`. Form questions that produced no variable in the data, and data variables that no form question accounts for. |

**What the Summary column shows**

| Variable type | Summary |
|---|---|
| Has value labels | Each category with its percentage, e.g. `Married = 95.41%` |
| Plain number | `Min=18.00, Max=65.00, Avg=37.82` |
| Text | Missing count and minimum/maximum length |
| Date or date-time | First, last and span (see [Dates and times](#dates-and-times)) |
| Multiple-select | Each option with % of cases and count (see below) |
| Completely empty | `All missing (0 observations)`, flagged in red |

**Formatting (needs Python):** a title bar naming the dataset, a styled header row that
stays in view when you scroll, filter buttons on the report sheets, banded rows, column widths that fit the
content, multi-line cells with rows sized to fit, counts stored as real numbers you can
sort, multiple-select rows tinted blue, and all-missing variables highlighted in red.

---

## Multiple-select questions

SurveyCTO, ODK and Kobo split a multiple-select question into several variables:

- a **parent**, holding the codes the respondent chose, such as `"1 3 98"`
- one **0/1 variable per option**, such as `c7_1`, `c7_2`, `c7_3`

Listed one row each, a ten-option question takes eleven rows and tells you very little.
`datareport` folds them back into a single row, with one option per line:

```
Income was decreased = 27.7% (n=88)
Did not able to go to work regularly = 17.9% (n=57)
Household expenses was increased = 22.0% (n=70)
Cases = 318 | Responses = 426 | 1.3 per case
```

- **Cases** are the respondents who answered the question. Percentages are shares of
  cases, so they can add up to more than 100%.
- **Responses** is the total number of options ticked.
- **Options nobody picked** are still listed, at 0%.

**How the options are matched to their question**

1. Variables named like the parent plus a number, `c7_1`, `c7_2` and so on, are treated
   as candidates. Inside repeat groups the pattern `Q_<option>_<repeat>` is used, e.g.
   `Sb_q8_3_5` for option 3 of loan 5.
2. Only variables coded 0/1 are kept.
3. **Every candidate is checked against the parent, observation by observation:**
   `c7_2` must equal 1 in exactly the observations whose parent contains code 2. Names
   alone are never enough. This check is what stops an ordinary repeat group, like
   loan 1 to loan 5, from being mistaken for the options of one question.

**Special cases it handles**

- **Repeat groups** are reported once per repeat (loan 1, loan 2, ...), each with its own
  denominator. Once one repeat is confirmed, the others use the same option list.
- **Numeric parents.** When everyone in a late repeat picked just one option, the export
  stores the parent as a number. These are still recognised.
- **Labelled numeric parents** look exactly like a single-choice question. They are folded
  only if the form, or another confirmed repeat of the same question, says they are
  multiple-select.
- **"Other, specify"** text fields keep their own row.

> [!NOTE]
> If the parent and an option disagree in even one observation, the question is not
> folded and its variables are listed one by one. This usually points to an edit made
> during cleaning. See [Troubleshooting](#troubleshooting).

---

## Dates and times

Stata stores a date as a count of days and a date-time as a count of milliseconds, so a
plain min/max/mean would be meaningless. Dates are reported as a range instead:

```
First date = 10 Sep 2025
Last date = 14 Sep 2026
Span = 369 days
```

Date-times such as `SubmissionDate`, `starttime` and `endtime` show **First** and **Last**
to the second, which gives you the first and last submission at a glance.

- Dates are recognised by their display format (`%td`, `%tc` and so on).
- If the format is missing, a date-time is still recognised from its value range. A plain
  date also needs a date-like name (e.g. containing `date`), so an ordinary number such
  as a duration is not mistaken for one.
- Timestamps stored as text are read as dates when the values look like dates.

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

With the XLSForm (recommended for survey data):

```stata
datareport using "qc.xlsx", replace form("survey_form.xlsx")
```

A form with more than one language:

```stata
datareport using "qc.xlsx", replace form("form.xlsx") formlang("English")
```

Several rounds in one workbook:

```stata
use "baseline.dta", clear
datareport using "monitoring.xlsx", replace sheetname(baseline)

use "endline.dta", clear
datareport using "monitoring.xlsx", sheetname(endline)
```

---

## Troubleshooting

| What you see | What to do |
|---|---|
| **The workbook is not formatted** | Python isn't set up for Stata. Run `python which openpyxl` in Stata and follow [Setting up Python](#setting-up-python-one-time-per-computer). |
| `r(7100)` when Stata uses Python | Stata can't start this Python, usually Python 3.14 on older Stata. Use Python 3.13, or on Stata 18/19 run `update all`. |
| `Python module openpyxl not found` &nbsp;`r(601)` | openpyxl went into a different Python. Repeat step 3 using the exact path that `python query` shows. |
| pip says `no such option: -m` | The command was pasted twice on one line. Clear it and paste once. |
| pip says `No module named pip` | Run `"<path>" -m ensurepip`, then repeat step 3. |
| Changes to the Python setup have no effect | Close and reopen Stata. |
| `r(677)` during `net install` | Stata can't reach GitHub. Install from the downloaded ZIP (see [Quick start](#quick-start)). |
| A multiple-select question was not folded | The parent variable is missing, an option isn't coded 0/1, or the parent and an option disagree in some observation. To find the disagreement for, say, option 98 of `c7`: `list c7 c7_98 if (c7_98 == 1) != (strpos(" " + c7 + " ", " 98 ") > 0)`. Passing `form()` also helps. |
| File permission error | The workbook is open in Excel, or the folder is read-only. Close the file and run again. |

---

## Author

**Md. Redoan Hossain Bhuiyan**
[redoanhossain630@gmail.com](mailto:redoanhossain630@gmail.com) ·
[github.com/RanaRedoan](https://github.com/RanaRedoan)

Please cite as: Bhuiyan, M.R.H. (2026). *datareport: survey data quality reporting for
Stata* (Version 1.4.0). https://github.com/RanaRedoan/datareport

### Other packages by the author

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
