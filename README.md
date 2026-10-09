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
3. [Syntax and options](#syntax-and-options)
4. [What you get](#what-you-get)
5. [Multiple-select questions](#multiple-select-questions)
6. [Dates and times](#dates-and-times)
7. [Examples](#examples)
8. [Troubleshooting](#troubleshooting)
9. [Author](#author)

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

That's all. The workbook comes out fully formatted, with nothing else to install.

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
| **Stata 16 or later** | Required. Nothing else: no other Stata packages, and no Python. |

> [!NOTE]
> Versions before 2.0.0 needed Python with `openpyxl` to format the workbook. From 2.0.0
> Stata formats it by itself, so you can skip all Python setup.

---

## Syntax and options

```stata
datareport using filename [, replace sheetname(string) form(filename) formlang(string) nomultiselect strmax(#)]
```

| Option | What it does |
|---|---|
| `replace` | Overwrite `filename` if it already exists. |
| `sheetname(string)` | Put a prefix on the sheet names, so several rounds can share one workbook. With `sheetname(round2)` the sheets become `round2_Summary` and `round2_Data_report`. |
| `form(filename)` | The XLSForm used to collect the data. Confirms which questions are multiple-select and supplies option labels. |
| `formlang(string)` | Which label language to read from a multi-language form, e.g. `formlang(English)`. Matches columns such as `label::English (en)` or `label:english`. Without it: a plain `label` column, then an English one, then the first found. |
| `nomultiselect` | Turn off the folding of multiple-select questions; every variable gets its own row. |
| `strmax(#)` | Text variables with at most `#` different answers have each answer listed with its share (default 50; `strmax(0)` turns it off). |

If you leave the `.xlsx` extension off `filename`, it is added for you. When the report is
written, a **click to open** link in the Results window opens it in Excel.

---

## What you get

The workbook has two sheets.

| Sheet | What's in it |
|---|---|
| **Summary** | A compact two-column table: file path and size, observations, numeric and string variables, variables entirely missing, partly missing or without a label, multiple-select questions found, the XLSForm used, and when the report was made. |
| **Data_report** | One row per variable, or one row per multiple-select question. Columns: Variable, Label, Type, Non-missing, Missing, Value labels, Summary. |

**What the Summary column shows**

| Variable type | Summary |
|---|---|
| Has value labels | Each category with its percentage, e.g. `Married = 95.41%` |
| Plain number | `Min=18.00, Max=65.00, Avg=37.82` |
| Text with at most 50 different answers (categories typed into Excel) | Each answer with its percentage, e.g. `Lack of money = 13.33%`, in natural order |
| Numbers stored as text (age, income from Excel) | `Min=18.00, Max=67.00, Avg=41.46 (numbers stored as text)` |
| Free text (more than 50 different answers, or every answer different) | Missing count and minimum/maximum length |
| Date or date-time | First, last and span (see [Dates and times](#dates-and-times)) |
| Multiple-select | Each option with % of cases and count (see below) |
| Completely empty | `All missing (0 observations)`, flagged in red |

**Formatting (built in, nothing to install):** the dataset name as a centred title, a navy
header row, a light grid, column widths fitted to the content, multi-line cells shown one
item per line with the row sized to fit, and counts stored as real numbers you can sort.
Only three colours are used: navy for titles and headers, pale blue to shade
multiple-select rows, and red for variables with no data.

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
| **The workbook is not formatted** | You are running a version before 2.0.0, which needed Python. Update with the `net install` line in [Quick start](#quick-start), then run `discard`. |
| `r(677)` during `net install` | Stata can't reach GitHub. Install from the downloaded ZIP (see [Quick start](#quick-start)). |
| A multiple-select question was not folded | The parent variable is missing, an option isn't coded 0/1, or the parent and an option disagree in some observation. To find the disagreement for, say, option 98 of `c7`: `list c7 c7_98 if (c7_98 == 1) != (strpos(" " + c7 + " ", " 98 ") > 0)`. Passing `form()` also helps. |
| File permission error | The workbook is open in Excel, or the folder is read-only. Close the file and run again. |

---

## Author

**Md. Redoan Hossain Bhuiyan**
[redoanhossain630@gmail.com](mailto:redoanhossain630@gmail.com) ·
[github.com/RanaRedoan](https://github.com/RanaRedoan)

Please cite as: Bhuiyan, M.R.H. (2026). *datareport: survey data quality reporting for
Stata* (Version 2.2.0). https://github.com/RanaRedoan/datareport

### Other packages by the author

| Package | What it does |
|---|---|
| [exporttables](https://github.com/RanaRedoan/exporttables) | Export a formatted table for every variable to Excel, one-way or by district |
| [biascheck](https://github.com/RanaRedoan/biascheck) | Identify potential enumerator bias in survey responses |
| [detectoutlier](https://github.com/RanaRedoan/detectoutlier) | Multivariate outlier detection for survey datasets |
| [optcounts](https://github.com/RanaRedoan/optcounts) | Track user-defined special values such as -99 or 99 |
| [gencodebook](https://github.com/RanaRedoan/gencodebook) | Generate professional codebooks |

## License

MIT. See [LICENSE](LICENSE).

Bug reports and suggestions: [github.com/RanaRedoan/datareport/issues](https://github.com/RanaRedoan/datareport/issues)
