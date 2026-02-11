*============================================================================
* DATA REPORT GENERATOR PROGRAM
*============================================================================
* Version			: 1.0.5
* Author			: Md. Redoan Hossain Bhuiyan
* Published Date 	: 10 February 2026
* Description		: Creates comprehensive Excel data report with multiple sheets
*============================================================================

cap program drop datareport
program define datareport
    version 16.0
    syntax using/, [replace] [SHEETname(string)]

    * Display preparing message
    di _n as text "{hline 70}"
    di as result "  ⧗ Data report preparing..."
    di as text "{hline 70}" _n
    
    preserve
    
    * Set default sheet name if not provided
    if "`sheetname'" == "" {
        local sheetname "datareport"
    }
    
    * Clear any existing mata objects
    qui mata: mata clear
    
    *========================================
    * 1. PREPARE SUMMARY STATISTICS
    *========================================
    
    * Get dataset title - extract filename from path
    local title: data label
    if "`title'" == "" {
        * Get filename from the current dataset path
        local filepath = c(filename)
        
        * Extract just the filename without path
        local filepath_clean = subinstr("`filepath'", "\", "/", .)
        
        * Get the last part after the final slash
        local lastslash = 0
        forvalues i = 1/`=length("`filepath_clean'")' {
            if substr("`filepath_clean'", `i', 1) == "/" {
                local lastslash = `i'
            }
        }
        
        if `lastslash' > 0 {
            local title = substr("`filepath_clean'", `lastslash' + 1, .)
        }
        else {
            local title = "`filepath_clean'"
        }
        
        * Remove .dta extension
        local title = subinstr("`title'", ".dta", "", .)
    }
    
    local obs = _N
    local vars = c(k)
    local filepath = c(filename)
    
    * Get file modification date
    local filedate = ""
    capture {
        * Use current date/time as file date
        local filedate = c(current_date) + " " + c(current_time)
    }
    
    * Count variable types and missing information
    tempname memhold
    tempfile tempresults
    qui postfile `memhold' str50 category str500 value using `tempresults', replace
    
    * Analyze each variable
    local string_count = 0
    local numeric_count = 0
    local missing_label_count = 0
    local complete_missing_count = 0
    
    foreach var of varlist _all {
        * Check variable type
        local vartype: type `var'
        
        if substr("`vartype'", 1, 3) == "str" {
            local string_count = `string_count' + 1
            
            * Check for completely missing string variables
            qui count if missing(`var')
            if r(N) == _N {
                local complete_missing_count = `complete_missing_count' + 1
            }
        }
        else {
            local numeric_count = `numeric_count' + 1
            
            * Check for completely missing numeric variables
            qui count if missing(`var')
            if r(N) == _N {
                local complete_missing_count = `complete_missing_count' + 1
            }
        }
        
        * Check for missing variable labels
        local varlabel: variable label `var'
        if "`varlabel'" == "" {
            local missing_label_count = `missing_label_count' + 1
        }
    }
    
    * Get file size
    local filesize_disp ""
    capture {
        * Try to get file size using Stata's file handling
        tempname fh
        file open `fh' using "`filepath'", read binary
        file seek `fh' eof
        local filesize = r(loc)
        file close `fh'
        
        if `filesize' > 1000000 {
            local filesize_disp = string(`filesize'/1000000, "%9.2f") + " MB"
        }
        else if `filesize' > 1000 {
            local filesize_disp = string(`filesize'/1000, "%9.2f") + " KB"
        }
        else {
            local filesize_disp = string(`filesize') + " bytes"
        }
    }
    
    *========================================
    * 2. CREATE SUMMARY SHEET
    *========================================
    
    * Write summary information to postfile
    qui post `memhold' ("Title of the Dataset:") ("`title'")
    qui post `memhold' ("Date of last modified:") ("`filedate'")
    qui post `memhold' ("Number of observations:") ("`obs'")
    qui post `memhold' ("File path:") ("`filepath'")
    qui post `memhold' ("Number of variables:") ("`vars'")
    qui post `memhold' ("Number of complete missing variables:") ("`complete_missing_count'")
    qui post `memhold' ("Number of string variables:") ("`string_count'")
    qui post `memhold' ("Number of numeric variables:") ("`numeric_count'")
    qui post `memhold' ("Number of variables with missing labels:") ("`missing_label_count'")
    qui post `memhold' ("File size of the dataset:") ("`filesize_disp'")
    
    qui postclose `memhold'
    
    *========================================
    * 3. CREATE DETAILED VARIABLE REPORT
    *========================================
    
    * Create detailed analysis for each variable (NOTE COLUMN REMOVED)
    tempname memhold2
    tempfile tempresults2
    qui postfile `memhold2' str32 variable str250 label str100 type ///
        str20 observation str20 missing str2045 value_label ///
        str2045 result using `tempresults2', replace
    
    foreach var of varlist _all {
        local varname "`var'"
        local varlabel: variable label `var'
        local vartype: type `var'
        local valuelabel: value label `var'
        
        * Count observations and missing
        qui count
        local total_obs = r(N)
        qui count if missing(`var')
        local missing_count = r(N)
        local nonmissing = `total_obs' - `missing_count'
        
        * Handle value labels - show ALL defined labels, not just values in data
        local value_label_text ""
        if "`valuelabel'" != "" {
            capture {
                * Get the complete value label definition
                qui label list `valuelabel'
                
                * Store all defined value-label pairs
                local num_values = r(k)
                
                * Extract min and max to loop through the range
                local min_val = r(min)
                local max_val = r(max)
                
                * Loop through the entire range of defined values
                forvalues val = `min_val'/`max_val' {
                    capture {
                        local lab: label `valuelabel' `val'
                        * If this value has a label defined, include it
                        if "`lab'" != "" & "`lab'" != "`val'" {
                            local value_label_text "`value_label_text'`val' = `lab'; "
                        }
                    }
                }
                
                * Also check for any non-consecutive values
                * This catches cases where labels might be like 1, 2, 99
                qui label list `valuelabel'
                local k = r(k)
                forvalues i = 1/`k' {
                    capture {
                        local val = r(value`i')
                        local lab = r(label`i')
                        if "`lab'" != "" & "`lab'" != "`val'" {
                            * Check if not already added
                            if strpos("`value_label_text'", "`val' = `lab'") == 0 {
                                local value_label_text "`value_label_text'`val' = `lab'; "
                            }
                        }
                    }
                }
            }
        }
        
        * Calculate min/max/mean for numeric variables without value labels
        local result_text ""
        
        if substr("`vartype'", 1, 3) != "str" & "`valuelabel'" == "" {
            qui sum `var' if !missing(`var')
            if r(N) > 0 {
                local min = string(r(min), "%9.2f")
                local max = string(r(max), "%9.2f")
                local mean = string(r(mean), "%9.2f")
                local result_text "Min=`min', Max=`max', Avg=`mean'"
            }
        }
        else if "`valuelabel'" != "" {
            * Calculate percentages for value-labeled variables
            qui levelsof `var', local(levels)
            foreach level in `levels' {
                if !missing(`level') {
                    qui count if `var' == `level' & !missing(`var')
                    local count = r(N)
                    if `nonmissing' > 0 {
                        local percent = (`count' / `nonmissing') * 100
                        * Format percentage to 2 decimal places
                        local percent_fmt = string(`percent', "%9.2f")
                        capture {
                            local label: label `valuelabel' `level'
                            local result_text "`result_text'`label' = `percent_fmt'%; "
                        }
                    }
                }
            }
        }
        else if substr("`vartype'", 1, 3) == "str" {
            * String variable analysis
            qui gen _length = length(`var') if !missing(`var')
            qui sum _length
            if r(N) > 0 {
                local min_length = r(min)
                local max_length = r(max)
                local result_text "Missing=`missing_count' obs, Min length=`min_length', Max length=`max_length'"
            }
            else {
                local result_text "Missing=`missing_count' obs"
            }
            qui drop _length
        }
        
        * Clean up text fields
        if "`varlabel'" == "" {
            local varlabel "(No label)"
        }
        
        if "`result_text'" == "" & substr("`vartype'", 1, 3) != "str" & "`valuelabel'" == "" {
            local result_text "Continuous variable"
        }
        
        * Post the variable information (NOTE COLUMN REMOVED)
        qui post `memhold2' ("`varname'") ("`varlabel'") ("`vartype'") ///
            ("`nonmissing'") ("`missing_count'") ("`value_label_text'") ///
            ("`result_text'")
    }
    
    qui postclose `memhold2'
    
    *========================================
    * 4. EXPORT TO EXCEL
    *========================================
    
    * Load summary data
    qui use `tempresults', clear
    
    * Export to Excel
    qui export excel using "`using'", sheet("Summary") firstrow(variables) `replace'
    
    * Load detailed report data
    qui use `tempresults2', clear
    
    * Export detailed report to second sheet
    qui export excel using "`using'", sheet("Data_report") firstrow(variables) sheetmodify
    
    * Format the Excel file - make headers bold and adjust column widths
    * Use Python for reliable formatting
    qui {
        capture {
            * Create Python script for formatting
            tempfile pyscript
            file open pyfile using "`pyscript'", write replace
            file write pyfile "import openpyxl" _n
            file write pyfile "from openpyxl.styles import Font" _n
            file write pyfile "wb = openpyxl.load_workbook('`using'')" _n
            file write pyfile "# Format Summary sheet" _n
            file write pyfile "ws = wb['Summary']" _n
            file write pyfile "for cell in ws[1]:" _n
            file write pyfile "    cell.font = Font(bold=True)" _n
            file write pyfile "ws.column_dimensions['A'].width = 35" _n
            file write pyfile "ws.column_dimensions['B'].width = 70" _n
            file write pyfile "# Format Data_report sheet" _n
            file write pyfile "ws = wb['Data_report']" _n
            file write pyfile "for cell in ws[1]:" _n
            file write pyfile "    cell.font = Font(bold=True)" _n
            file write pyfile "ws.column_dimensions['A'].width = 20" _n
            file write pyfile "ws.column_dimensions['B'].width = 50" _n
            file write pyfile "ws.column_dimensions['C'].width = 10" _n
            file write pyfile "ws.column_dimensions['D'].width = 10" _n
            file write pyfile "ws.column_dimensions['E'].width = 10" _n
            file write pyfile "ws.column_dimensions['F'].width = 50" _n
            file write pyfile "ws.column_dimensions['G'].width = 80" _n
            file write pyfile "wb.save('`using'')" _n
            file close pyfile
            
            * Run Python script quietly
            shell python "`pyscript'"
        }
    }
    
    *========================================
    * 5. DISPLAY SUMMARY INFORMATION
    *========================================
    
    restore
    
    di _n(2)
    di as text "{hline 70}"
    di as result "  ✓ Data Report Generated Successfully"
    di as text "{hline 70}"
    di as text "  Output file  : " as result "`using'"
    di as text "  Dataset      : " as result "`title'"
    di as text "  Observations : " as result "`obs'"
    di as text "  Variables    : " as result "`vars'"
    di as text "  Report sheets: " as result "Summary, Data_report"
    di as text "{hline 70}"
    di as text _n
    
end

