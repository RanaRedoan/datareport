# datareport: Comprehensive Excel Data Report Generator for Stata

A Stata command that generates comprehensive, professional Excel reports documenting your dataset structure, variables, and statistical summaries.

## Features

✨ **Comprehensive Documentation**
- Dataset-level summary with file information and variable counts
- Variable-level analysis with types, labels, and statistics
- Automatic extraction of dataset title from filename

📊 **Complete Value Label Display**
- Shows **ALL** defined value labels, not just those present in data
- Perfect for survey data where not all response options were selected
- Example: Displays 1-5 Likert scale definitions even if only 3-5 were chosen

🎯 **Smart Statistical Summaries**
- **Continuous variables**: Min, Max, Average (formatted to 2 decimals)
- **Categorical variables**: Percentage distribution with labels
- **String variables**: Length statistics and missing counts

💼 **Professional Excel Output**
- Bold headers for easy reading
- Optimized column widths
- Two worksheets: Summary and Data_report
- Ready for reports and documentation

🔇 **Clean Execution**
- Runs quietly with elegant progress indicators
- No intermediate output clutter
- Beautiful completion message

## Installation

### Option 1: Direct Download
1. Download `datareport.ado` and `datareport.sthlp`
2. Place files in your Stata ado directory:
   - Windows: `C:\ado\plus\d\`
   - Mac/Linux: `~/ado/plus/d/`
3. Restart Stata or run `discard`

### Option 2: From GitHub
```stata
net install datareport, from("https://raw.githubusercontent.com/RanaRedoan/datareport/main/")
```

### Requirements
- Stata 16.0 or higher
- Python with `openpyxl` package (for Excel formatting)

Install Python dependency:
```bash
pip install openpyxl
```

## Usage

### Basic Syntax
```stata
datareport using filename.xlsx [, replace sheetname(string)]
```

### Quick Start Examples

**Example 1: Basic Report**
```stata
sysuse auto, clear
datareport using "auto_report.xlsx", replace
```

**Example 2: Survey Data with Custom Label**
```stata
use "household_survey.dta", clear
label data "Household Survey 2024"
datareport using "survey_documentation.xlsx", replace
```

**Example 3: Custom Sheet Name**
```stata
use "mydata.dta", clear
datareport using "report.xlsx", replace sheetname("analysis")
```

## Output Structure

### Sheet 1: Summary
Contains dataset-level information:
- Title of the Dataset
- Date of last modified
- Number of observations
- File path
- Number of variables
- Number of complete missing variables
- Number of string/numeric variables
- Number of variables with missing labels
- File size

### Sheet 2: Data_report
Contains detailed variable analysis with columns:

| Column | Description |
|--------|-------------|
| **variable** | Variable name |
| **label** | Variable label |
| **type** | Storage type (byte, int, float, str, etc.) |
| **note** | Variable notes (if defined) |
| **observation** | Count of non-missing observations |
| **missing** | Count of missing observations |
| **value_label** | Complete value label definitions |
| **result** | Statistical summary based on variable type |

## Key Advantages

### 1. Complete Value Label Documentation
Unlike `codebook` or `describe`, `datareport` shows **all defined labels**, not just those in your data:

```
For variable with labels:
1 = Strongly Dissatisfied
2 = Dissatisfied  
3 = Somewhat Satisfied
4 = Satisfied
5 = Strongly Satisfied

Even if data only contains responses 3-5, ALL five labels are displayed!
```

### 2. Clean Decimal Formatting
```
Before: Min=22.58581924438477, Max=25.7788143157959
After:  Min=    22.59, Max=    25.78, Avg=    24.69
```

### 3. Professional Excel Format
- Headers automatically bolded
- Columns auto-sized for readability
- No manual formatting needed

## Screenshots

**Execution:**
```
----------------------------------------------------------------------
  ⧗ Data report preparing...
----------------------------------------------------------------------

----------------------------------------------------------------------
  ✓ Data Report Generated Successfully
----------------------------------------------------------------------
  Output file  : survey_report.xlsx
  Dataset      : Clean_Dataset
  Observations : 50
  Variables    : 80
  Report sheets: Summary, Data_report
----------------------------------------------------------------------
```

## Options

### `replace`
Overwrites existing Excel file if it exists.

### `sheetname(string)`
Customizes the name of the data report sheet (default: "datareport").

## Use Cases

📋 **Research Documentation**
- Document dataset structure before analysis
- Create data dictionaries for collaborators
- Archive variable definitions and coding

📊 **Survey Data**
- Show complete questionnaire response options
- Document which options were actually selected
- Share data structure with stakeholders

🎓 **Teaching & Training**
- Generate quick dataset overviews for students
- Create reference materials from example datasets
- Document practice datasets

📝 **Quality Control**
- Identify variables with missing labels
- Find completely missing variables
- Review data types and ranges

## Technical Details

### How It Works
1. Collects dataset-level statistics
2. Iterates through all variables
3. Extracts complete value label definitions
4. Computes appropriate statistics by variable type
5. Exports to Excel using Stata's `export excel`
6. Applies formatting using Python's `openpyxl`

### Value Label Extraction
The command uses `label list` to retrieve complete value label definitions, then loops through:
- Consecutive values (min to max range)
- Non-consecutive values (e.g., 1, 2, 99)

This ensures all defined labels are captured, regardless of data content.

### File Processing
- Uses temporary files for intermediate steps
- All temp files automatically cleaned up
- Original dataset preserved (uses `preserve`/`restore`)

## Troubleshooting

**Problem:** Headers not bold in Excel
**Solution:** Install openpyxl: `pip install openpyxl`

**Problem:** Python not found
**Solution:** Ensure Python is in system PATH or specify full path in code

**Problem:** Permission denied
**Solution:** Check write permissions in target directory or choose different location

**Problem:** File already exists
**Solution:** Use `replace` option: `datareport using "file.xlsx", replace`

## Changelog

### Version 2.0 (Current)
- ✅ Extracts dataset filename as title
- ✅ Shows all defined value labels (not just selected responses)
- ✅ Merged minmaxavg column into result column
- ✅ Separate type and note columns
- ✅ Formatted decimals to 2 places
- ✅ Bold headers in both sheets
- ✅ Quiet execution with elegant messages
- ✅ Removed unnecessary text ("No value label", "All missing")

### Version 1.0
- Initial release
- Basic summary and variable reporting

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Areas for Contribution
- Additional statistical measures
- Custom formatting options
- Support for multiple datasets comparison
- Integration with specific data types (panel, time-series)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Citation

If you use this command in your research, please cite:

```
datareport: Comprehensive Excel Data Report Generator for Stata
Version 2.0
URL: https://github.com/RanaRedoan/datareport
```

## Author

Md. Redoan Hossain Bhuiyan


## Acknowledgments

- Developed to streamline data documentation workflows
- Inspired by common pain points in survey data analysis
- Thanks to the Stata community for feedback and testing

## Support

- 🐛 Report bugs: [GitHub Issues](https://github.com/RanaRedoan/datareport/issues)
- 💬 Ask questions: [GitHub Discussions](https://github.com/RanaRedoan/datareport/discussions)
- 📧 Email: redoanhossain630@gmail.com

## See Also

Stata commands:
- `describe` - Basic variable information
- `codebook` - Detailed codebook
- `labelbook` - Value label documentation
- `export excel` - Excel export

---

**Star ⭐ this repository if you find it helpful!**
