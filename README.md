# 📊 datareport – Lightning-Fast Survey Data Quality Reporting for Stata

<div align="center">

**Generate comprehensive Excel diagnostic reports of any dataset within a few seconds**  
*Built for survey managers, data auditors, and research professionals*

[🚀 Quick Start](#quick-start) • [📋 Features](#key-features) • [💻 Installation](#installation) • [📖 Documentation](#documentation) • [🤝 Contributing](#contributing)

</div>

---

## 🎯 Why datareport?

Every day, survey teams collect thousands of observations. **datareport** transforms this raw data into actionable quality insights in seconds. No complex coding. No manual formatting. Just one command and you get a professionally formatted Excel workbook with complete dataset diagnostics.

---

## ✨ Key Features

<div align="center">

| 🚀 | 🔍 | 🏷️ | 📈 | 🎨 |
|:--:|:--:|:--:|:--:|:--:|
| **Lightning Fast** | **Complete Diagnostics** | **Full Label Documentation** | **Smart Statistics** | **Auto-Formatted** |
| < 5 seconds for 100K obs | Variable-level forensics | ALL value labels, not just observed | Type-aware summaries | Perfect Excel styling |

</div>

### 📋 Comprehensive Summary Dashboard
Get a bird's-eye view of your dataset health:
- Dataset metadata and file characteristics
- **Critical red flags**: completely missing variables, unlabeled variables
- Variable type distribution (numeric vs string)
- File size and modification tracking

### 🔬 Variable-Level Forensics
Deep-dive into each variable's quality:
- Storage types and label completeness
- Missing data patterns with exact counts
- **Full value label definitions** - every mapping documented
- Intelligent statistics based on variable type:
  - *Numeric*: Min, Max, Mean
  - *String*: Length distribution, missing patterns
  - *Categorical*: Percentage distributions with labels
  - *Binary*: Proportion analysis

---

## ⚡ Quick Start

### 1. One-Time Python Setup (30 seconds)
```bash
python -m pip install openpyxl
```

### 2. Generate Your First Report
```stata
. sysuse auto, clear
. datareport using "auto_quality_check.xlsx"
```

### 3. Review Output
```
──────────────────────────────────────────────────────
  ✓ Data Report Generated Successfully
──────────────────────────────────────────────────────
  Output file   : auto_quality_check.xlsx
  Dataset       : auto
  Observations  : 74
  Variables     : 12
  Report sheets : Summary, Data_report
──────────────────────────────────────────────────────
```

That's it! Open the Excel file and see your complete data quality report.

---

## 💻 Installation

### Option 1: Automatic (Recommended)
```stata
. net install datareport, from("https://raw.githubusercontent.com/RanaRedoan/datareport/main/") replace
```

### Option 2: Manual
```bash
# Clone the repository
git clone https://github.com/RanaRedoan/datareport.git

# Copy files to Stata's ado directory
# Windows: C:\ado\personal\d\
# macOS: ~/ado/personal/d/
# Linux: ~/ado/personal/d/
```

### Option 3: Direct Download
Download `datareport.ado` and `datareport.sthlp` from GitHub and place them in your personal ado directory.

### Verify Installation
```stata
. which datareport
. help datareport
```

---

## 📋 System Requirements

| Component | Requirement | Check Command |
|-----------|-------------|---------------|
| Stata | Version 16.0 or higher | `version` |
| Python | Version 3.6 or higher | `python query` |
| openpyxl | Version 3.0.0 or higher | `python -c "import openpyxl; print(openpyxl.__version__)"` |

⚠️ **No Python? No problem!** The report still generates successfully - only advanced Excel formatting is skipped. Basic data export works on all Stata installations.

---

## 📖 Documentation

### Syntax
```stata
datareport using filename [, replace sheetname(string)]
```

| Option | Description |
|--------|-------------|
| `using` | Excel filename for output report (.xlsx added automatically) |
| `replace` | Overwrite existing file (essential for repeated monitoring) |
| `sheetname()` | Custom prefix for report sheets |

### Real-World Survey Workflows

#### 📅 Daily Field Data Check
```stata
* Morning check of yesterday's collected data
. use "survey_data_day2.dta", clear
. datareport using "monitoring/day2_report.xlsx", replace
* Review missing patterns and label issues before fieldwork starts
```

#### 📊 Weekly Supervisor Report
```stata
* Aggregate weekly collection and generate supervisor brief
. use "week1.dta", clear
. append using "week2.dta"
. label data "Health Survey - Week 2 Progress"
. datareport using "briefings/supervisor_week2.xlsx", replace
```

#### ✅ Endline Quality Audit
```stata
* Final dataset certification before analysis
. use "final_survey_data.dta", clear
. datareport using "audit/final_quality_certificate.xlsx", sheetname(endline)
* Attach to data delivery documentation
```

#### 🔄 Multi-Round Survey Monitoring
```stata
local rounds "baseline midline endline"
foreach r in `rounds' {
    use "survey_`r'.dta", clear
    datareport using "reports/`r'_check.xlsx", replace sheetname(`r')
}
```

---

## 📊 Output Preview

### Sheet 1: Summary Dashboard

| Category | Value |
|----------|-------|
| Title of the Dataset | National Health Survey 2025 |
| Date of last modified | 10 Feb 2026 14:30:22 |
| Number of observations | 2,845 |
| Number of variables | 87 |
| ⚠️ Complete missing variables | 3 |
| String variables | 12 |
| Numeric variables | 75 |
| ⚠️ Variables with missing labels | 5 |
| File size | 2.45 MB |

### Sheet 2: Data_report (Variable Forensics)

| Variable | Label | Type | Non-miss | Miss | Value Labels | Statistics |
|----------|-------|------|----------|------|--------------|------------|
| age | Age in years | byte | 2,845 | 0 | - | Min=18, Max=95, Avg=47.3 |
| employed | Employment status | byte | 2,802 | 43 | 0 = No; 1 = Yes; 2 = Not applicable; 9 = Refused | No = 45.2%; Yes = 52.1%; NA = 2.5%; Refused = 0.2% |

---

## 🚀 Performance Benchmarks

| Dataset Size | Variables | Generation Time | File Size |
|--------------|-----------|-----------------|-----------|
| 1,000 obs | 50 | 0.8 seconds | 45 KB |
| 10,000 obs | 75 | 1.5 seconds | 98 KB |
| 100,000 obs | 100 | 3.2 seconds | 180 KB |
| 1,000,000 obs | 200 | 12.5 seconds | 520 KB |

*Tested on: Intel i7, 16GB RAM, SSD*

---

## 👨‍💻 About the Author

**Md. Redoan Hossain Bhuiyan**  
*Stata enthusiast and survey data quality specialist*

- 📧 Email: redoanhossain630@gmail.com
- 🐙 GitHub: [github.com/RanaRedoan](https://github.com/RanaRedoan)
- 📅 Published: 10 February 2026
- 🏷️ Version: 1.0.5

---

⭐ **Found these useful? Star the repositories on GitHub!**

---

## ❓ Troubleshooting

| Problem | Solution |
|---------|----------|
| "openpyxl not found" | Run `python -m pip install openpyxl` |
| File permission denied | Check write permissions or change output directory |
| Python not configured | Run `python search` in Stata to configure |
| Slow performance | Use Stata 17+ with improved memory management |
| Missing value labels | Ensure labels are defined with `label define` and applied with `label values` |

---

## 🤝 Contributing

Contributions are welcome! Whether it's:

- 🐛 Reporting a bug
- 💡 Suggesting a feature
- 📖 Improving documentation
- 🔧 Submitting a pull request

### Steps to contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.

```
MIT License

Copyright (c) 2026 Md. Redoan Hossain Bhuiyan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files...
```

---

## 📚 Citation

If **datareport** contributes to your research or operational workflow, please cite:

```bibtex
@software{bhuiyan2026datareport,
  author = {Bhuiyan, Md. Redoan Hossain},
  title = {datareport: Lightning-fast Survey Data Quality Reporting for Stata},
  year = {2026},
  version = {1.0.5},
  publisher = {GitHub},
  url = {https://github.com/RanaRedoan/datareport}
}
```

---

## 📬 Connect & Support

- **Report Bug**: [GitHub Issues](https://github.com/RanaRedoan/datareport/issues)
- **Ask Questions**: [GitHub Discussions](https://github.com/RanaRedoan/datareport/discussions)
- **Follow Updates**: Star the repository
- **Contact Author**: redoanhossain630@gmail.com

---

<div align="center">

📢 **datareport is production-ready and actively maintained**

⭐ Star this repo • 🍴 Fork it • 📢 Share with colleagues

**Made with ❤️ for the Stata community**

© 2026 Md. Redoan Hossain Bhuiyan

</div>
