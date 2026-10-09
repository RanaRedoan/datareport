*============================================================================
* DATA REPORT GENERATOR PROGRAM
*============================================================================
* Version			: 2.2.0
* Author			: Md. Redoan Hossain Bhuiyan
* Published Date 	: 10 October 2026
* Description		: Creates comprehensive Excel data report with multiple
*                     sheets.  Multiple-select (select_multiple) questions are
*                     collapsed into a single mrtab-style row instead of one
*                     row per option dummy.  An optional XLSForm (SurveyCTO,
*                     ODK or Kobo) can be supplied to sharpen detection and
*                     to supply option labels.
*                     The workbook is formatted by Stata itself (Mata xl()),
*                     so Python is no longer needed.
*============================================================================

cap program drop datareport
program define datareport
    version 16.0
    syntax using/ , [replace SHEETname(string) FORM(string) ///
                     FORMLANG(string) noMULTIselect STRmax(integer 50)]

    if `strmax' < 0 {
        di as error "strmax() must be 0 or more"
        exit 198
    }

    di _n as text "{hline 70}"
    di as result "  Data report preparing..."
    di as text "{hline 70}" _n

    *========================================
    * 0. OPTIONS AND FILE NAMES
    *========================================

    local docollapse = ("`multiselect'" != "nomultiselect")

    if "`form'" != "" {
        capture confirm file "`form'"
        if _rc {
            di as error "form() file not found: `form'"
            exit 601
        }
    }

    * Resolve the workbook name the way export excel will write it, so the
    * formatting step opens the file that was actually created.
    local xlfile "`using'"
    if strpos(lower("`xlfile'"), ".xlsx") == 0 & ///
       strpos(lower("`xlfile'"), ".xlsm") == 0 & ///
       strpos(lower("`xlfile'"), ".xls")  == 0 {
        local xlfile "`using'.xlsx"
    }

    * sheetname() is a prefix.  Excel caps sheet names at 31 characters.
    if "`sheetname'" == "" {
        local s_sum "Summary"
        local s_dat "Data_report"
    }
    else {
        local s_sum = substr("`sheetname'_Summary",     1, 31)
        local s_dat = substr("`sheetname'_Data_report", 1, 31)
    }

    preserve

    *========================================
    * 1. READ THE XLSFORM (OPTIONAL)
    *========================================

    local formmulti ""      /* names the form calls select_multiple  */
    local formnames ""      /* every question expected to yield data */
    local nformq    = 0
    local formok    = 0

    local formlists ""      /* choice list of each select_multiple  */

    if "`form'" != "" {
        capture noisily _dr_readform, form("`form'") formlang("`formlang'")
        if _rc == 0 {
            local sok0 "`s(ok)'"
            if "`sok0'" == "" local sok0 "0"
            local formok    = `sok0'
            local formmulti "`s(multi)'"
            local formlists "`s(multilist)'"
            local formnames "`s(names)'"
            local nformq    = `s(nq)'
        }
        if `formok' == 0 {
            di as text "  (note: could not read the survey sheet of form(); " ///
                       "continuing without it)"
        }
        else {
            local nmulti : word count `formmulti'
            di as text "  Form read: " as result "`nformq'" as text ///
               " questions, " as result "`nmulti'" as text " select_multiple"
        }
    }

    *========================================
    * 2. BASIC DATASET FACTS
    *========================================

    local title: data label
    if "`title'" == "" {
        local filepath = c(filename)
        local filepath_clean = subinstr("`filepath'", "\", "/", .)
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
        local title = subinstr("`title'", ".dta", "", .)
    }
    if `"`title'"' == "" local title "Untitled dataset"

    local obs      = _N
    local vars     = c(k)
    local filepath = c(filename)
    local rundate  = trim(c(current_date)) + " " + c(current_time)

    qui ds
    local allvars `r(varlist)'

    local string_count           = 0
    local numeric_count          = 0
    local missing_label_count    = 0
    local complete_missing_count = 0
    local partial_missing_count  = 0

    foreach var of local allvars {
        local vartype: type `var'
        if substr("`vartype'", 1, 3) == "str" {
            local string_count = `string_count' + 1
        }
        else {
            local numeric_count = `numeric_count' + 1
        }
        qui count if missing(`var')
        if r(N) == _N {
            local complete_missing_count = `complete_missing_count' + 1
        }
        else if r(N) > 0 {
            local partial_missing_count = `partial_missing_count' + 1
        }
        local varlabel: variable label `var'
        if "`varlabel'" == "" {
            local missing_label_count = `missing_label_count' + 1
        }
    }

    local filesize_disp ""
    capture {
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
        local filesize_disp = trim("`filesize_disp'")
    }
    if `"`filepath'"' == "" local filepath      "(dataset not saved to disk)"
    if "`filesize_disp'" == "" local filesize_disp "-"

    *========================================
    * 3. DETECT MULTIPLE-SELECT BLOCKS
    *========================================
    *
    * A select_multiple exports as a "parent" holding the codes the
    * respondent chose, plus one 0/1 variable per option.  Two layouts occur:
    *
    *   plain            parent  P        options  P_<code>
    *   inside a repeat  parent  Q_<k>    options  Q_<code>_<k>
    *
    * Those two namings collide: for parent Q_<k>, the name Q_<k>_<c> reads
    * as "option c of Q_<k>", but Q_<c>_<k> reads as "option c of repeat k",
    * and when c equals k they are the same variable.  The scheme is
    * therefore chosen ONCE per question by counting how many option
    * variables each naming yields, never option by option from whatever
    * happens to verify - in a repeat instance with two respondents almost
    * anything verifies, and a per-option vote ties and falls the wrong way.
    *
    * The chosen set is then checked against the parent: an option is kept
    * only if it is 0/1 and equals 1 in exactly the observations whose parent
    * holds that code.  Every option in the set is checked, not just the
    * codes someone happened to pick, so even a two-respondent instance gets
    * a dozen confirmations.

    local nblk        = 0
    local consumed    ""
    local parentlist  ""
    local confirmedqn ""

    if `docollapse' {

        foreach v of local allvars {

            if strpos(" `consumed' ", " `v' ") continue

            local vtype: type `v'
            local visstr = (substr("`vtype'", 1, 3) == "str")

            if `visstr' == 0 {
                capture confirm numeric variable `v'
                if _rc continue
                qui count if !missing(`v') & (`v' != int(`v') | `v' < 0)
                if r(N) > 0 continue
            }

            qui count if !missing(`v')
            if r(N) == 0 continue

            local qn ""
            local rk ""
            if regexm("`v'", "^(.+)_([0-9]+)$") {
                local qn = regexs(1)
                local rk = regexs(2)
            }

            *---- build both option sets from the names alone ----
            local dset ""
            capture unab cnd : `v'_*
            if _rc == 0 {
                foreach cd of local cnd {
                    local code = substr("`cd'", length("`v'") + 2, .)
                    if !regexm("`code'", "^[0-9]+$") continue
                    local tp : type `cd'
                    if substr("`tp'", 1, 3) == "str" continue
                    qui count if !missing(`cd')
                    if r(N) == 0 continue
                    qui count if !inlist(`cd', 0, 1) & !missing(`cd')
                    if r(N) > 0 continue
                    local dset "`dset' `cd'"
                }
            }

            local nset ""
            if "`qn'" != "" {
                capture unab cnn : `qn'_*_`rk'
                if _rc == 0 {
                    foreach cd of local cnn {
                        local code = substr("`cd'", length("`qn'") + 2, ///
                            length("`cd'") - length("`qn'") - length("`rk'") - 2)
                        if !regexm("`code'", "^[0-9]+$") continue
                        local tp : type `cd'
                        if substr("`tp'", 1, 3) == "str" continue
                        qui count if !missing(`cd')
                        if r(N) == 0 continue
                        qui count if !inlist(`cd', 0, 1) & !missing(`cd')
                        if r(N) > 0 continue
                        local nset "`nset' `cd'"
                    }
                }
            }

            local nd : word count `dset'
            local nn : word count `nset'
            if `nd' < 2 & `nn' < 2 continue

            *---- what do the form and the earlier instances already say? ----
            local evid = 0
            if strpos(" `formmulti' ", " `v' ") local evid = 1
            if "`qn'" != "" {
                if strpos(" `formmulti' ", " `qn' ")   local evid = 1
                if strpos(" `confirmedqn' ", " `qn' ") local evid = 1
            }

            *---- A labelled numeric parent looks exactly like a select_one,
            *     because every respondent picked one code.  That happens in
            *     the thin repeat instances, and labelling them is a normal
            *     cleaning step, so the form or a confirmed sibling instance
            *     is what tells the two apart.  Without either, leave it. ----
            if `visstr' == 0 {
                local vvlab : value label `v'
                if "`vvlab'" != "" & `evid' == 0 continue
            }

            *---- choose the naming scheme once, for the whole question ----
            if `nn' > `nd'                     local pattern "nested"
            else if `nd' > `nn'                local pattern "direct"
            else if "`qn'" != "" & `evid'      local pattern "nested"
            else                               local pattern "direct"

            if "`pattern'" == "direct" local oset "`dset'"
            else                       local oset "`nset'"

            *---- when the form declares the choice list, keep only its codes ----
            local qbase = cond("`pattern'" == "nested", "`qn'", "`v'")
            local fcodes ""
            if `formok' {
                local mi  = 0
                local nmi : word count `formmulti'
                forvalues j = 1/`nmi' {
                    local wj : word `j' of `formmulti'
                    if "`wj'" == "`qbase'" local mi = `j'
                }
                if `mi' > 0 {
                    local qlist : word `mi' of `formlists'
                    if "`qlist'" != "" & "`qlist'" != "." {
                        capture _dr_codes, list("`qlist'")
                        if _rc == 0 local fcodes "`s(codes)'"
                    }
                }
            }

            *---- verify every option in the chosen set against the parent ----
            local keep = ""
            local nok  = 0
            local nbad = 0
            foreach cd of local oset {
                if "`pattern'" == "direct" {
                    local code = substr("`cd'", length("`v'") + 2, .)
                }
                else {
                    local code = substr("`cd'", length("`qn'") + 2, ///
                        length("`cd'") - length("`qn'") - length("`rk'") - 2)
                }
                if "`fcodes'" != "" {
                    if strpos(" `fcodes' ", " `code' ") == 0 continue
                }
                if `visstr' {
                    local sel `"(strpos(" " + `v' + " ", " `code' ") > 0)"'
                }
                else {
                    local sel "(`v' == `code')"
                }
                qui count if (`cd' == 1) != `sel' & !missing(`v')
                if r(N) == 0 {
                    local nok  = `nok' + 1
                    local keep "`keep' `cd'"
                }
                else {
                    local nbad = `nbad' + 1
                }
            }

            if `nbad' > 0 continue
            if `nok' < 2  continue

            local ordered ""
            foreach av of local allvars {
                if strpos(" `keep' ", " `av' ") local ordered "`ordered' `av'"
            }
            local ordered = trim(itrim("`ordered'"))

            local nblk = `nblk' + 1
            local blk`nblk'_dums    "`ordered'"
            local blk`nblk'_pattern "`pattern'"
            local blk`nblk'_qn      "`qn'"
            local blk`nblk'_rk      "`rk'"
            local blk`nblk'_parent  "`v'"
            local parentlist = trim(itrim("`parentlist' `v'"))
            local consumed   = trim(itrim("`consumed' `v' `ordered'"))
            if "`pattern'" == "nested" {
                if strpos(" `confirmedqn' ", " `qn' ") == 0 {
                    local confirmedqn = trim(itrim("`confirmedqn' `qn'"))
                }
            }
        }

        *----------------------------------------------------------------
        * Backstop: carry a confirmed repeat question across any instance
        * the pass above could not settle on its own.
        *----------------------------------------------------------------
        local nb0 = `nblk'
        forvalues b = 1/`nb0' {

            if "`blk`b'_pattern'" != "nested" continue
            local bqn "`blk`b'_qn'"
            local brk "`blk`b'_rk'"

            local bcodes ""
            foreach d of local blk`b'_dums {
                local cc = substr("`d'", length("`bqn'") + 2, ///
                    length("`d'") - length("`bqn'") - length("`brk'") - 2)
                local bcodes "`bcodes' `cc'"
            }
            local bcodes = trim(itrim("`bcodes'"))
            if "`bcodes'" == "" continue

            capture unab sibs : `bqn'_*
            if _rc continue
            local kk ""
            foreach s of local sibs {
                if regexm("`s'", "^`bqn'_(.+)_([0-9]+)$") {
                    local k2 = regexs(2)
                    if "`k2'" != "`brk'" & strpos(" `kk' ", " `k2' ") == 0 {
                        local kk "`kk' `k2'"
                    }
                }
            }

            foreach k2 of local kk {

                capture confirm variable `bqn'_`k2'
                if _rc continue
                if strpos(" `consumed' ", " `bqn'_`k2' ") continue

                local dl ""
                foreach cc of local bcodes {
                    capture confirm variable `bqn'_`cc'_`k2'
                    if _rc continue
                    if strpos(" `consumed' ", " `bqn'_`cc'_`k2' ") continue
                    local ctype : type `bqn'_`cc'_`k2'
                    if substr("`ctype'", 1, 3) == "str" continue
                    qui count if !inlist(`bqn'_`cc'_`k2', 0, 1) & ///
                        !missing(`bqn'_`cc'_`k2')
                    if r(N) > 0 continue
                    local dl "`dl' `bqn'_`cc'_`k2'"
                }

                local nd2 : word count `dl'
                if `nd2' < 2 continue

                local ordered ""
                foreach av of local allvars {
                    if strpos(" `dl' ", " `av' ") local ordered "`ordered' `av'"
                }
                local ordered = trim(itrim("`ordered'"))

                local nblk = `nblk' + 1
                local blk`nblk'_dums    "`ordered'"
                local blk`nblk'_pattern "nested"
                local blk`nblk'_qn      "`bqn'"
                local blk`nblk'_rk      "`k2'"
                local blk`nblk'_parent  "`bqn'_`k2'"
                local parentlist = trim(itrim("`parentlist' `bqn'_`k2'"))
                local consumed   = trim(itrim("`consumed' `bqn'_`k2' `ordered'"))
            }
        }
    }

    local ncons : word count `consumed'
    local nfolded = `ncons' - `nblk'

    *========================================
    * 4. BUILD THE SUMMARY SHEET
    *========================================

    * Each row carries a kind that drives its formatting:
    *   txt   plain text value        num   count
    *   bad   count, red when above zero

    capture frame drop __dr_sum
    frame create __dr_sum
    frame __dr_sum {
        qui set obs 40
        qui gen strL category = ""
        qui gen strL value    = ""
        qui gen str8 kind     = ""
    }

    local sr = 0
    _dr_sumrow `++sr' txt "File path"                          `"`filepath'"'
    _dr_sumrow `++sr' txt "File size"                          "`filesize_disp'"
    _dr_sumrow `++sr' num "Observations"                       "`obs'"
    _dr_sumrow `++sr' num "Variables"                          "`vars'"
    _dr_sumrow `++sr' num "Numeric variables"                  "`numeric_count'"
    _dr_sumrow `++sr' num "String variables"                   "`string_count'"
    _dr_sumrow `++sr' bad "Variables with every value missing" "`complete_missing_count'"
    _dr_sumrow `++sr' num "Variables with some values missing" "`partial_missing_count'"
    _dr_sumrow `++sr' num "Variables without a label"          "`missing_label_count'"
    if `docollapse' {
        _dr_sumrow `++sr' num "Multiple-select questions"         "`nblk'"
        _dr_sumrow `++sr' num "Option variables folded into them" "`nfolded'"
    }
    if `formok' {
        local formshort = subinstr(`"`form'"', "\", "/", .)
        local formshort = substr(`"`formshort'"', strrpos(`"`formshort'"', "/") + 1, .)
        _dr_sumrow `++sr' txt "XLSForm used"                   `"`formshort'"'
    }
    _dr_sumrow `++sr' txt "Report generated on"                "`rundate'"

    *========================================
    * 5. BUILD THE DETAILED VARIABLE REPORT
    *========================================

    capture frame drop __dr_rows
    frame create __dr_rows
    frame __dr_rows {
        qui set obs `=`vars' + 5'
        qui gen strL variable    = ""
        qui gen strL label       = ""
        qui gen strL type        = ""
        qui gen strL observation = ""
        qui gen strL missing     = ""
        qui gen strL value_label = ""
        qui gen strL result      = ""
    }

    local rw = 0

    foreach var of local allvars {

        * option dummies that have been folded away are skipped entirely
        if strpos(" `consumed' ", " `var' ") & ///
           strpos(" `parentlist' ", " `var' ") == 0 continue

        local blkno = 0
        if strpos(" `parentlist' ", " `var' ") {
            forvalues b = 1/`nblk' {
                if "`blk`b'_parent'" == "`var'" local blkno = `b'
            }
        }

        local varlabel:   variable label `var'
        local vartype:    type `var'
        local valuelabel: value label `var'

        *------------------------------------------------
        * 5a. MULTIPLE-SELECT QUESTION -> one mrtab row
        *------------------------------------------------
        if `blkno' > 0 {

            local dums    "`blk`blkno'_dums'"
            local pattern "`blk`blkno'_pattern'"
            local bqn     "`blk`blkno'_qn'"
            local brk     "`blk`blkno'_rk'"
            local qbase = cond("`pattern'" == "nested", "`bqn'", "`var'")

            * which choice list does the form give this question?
            local qlist ""
            if `formok' {
                local mi  = 0
                local nmi : word count `formmulti'
                forvalues j = 1/`nmi' {
                    local wj : word `j' of `formmulti'
                    if "`wj'" == "`qbase'" local mi = `j'
                }
                if `mi' > 0 {
                    local qlist : word `mi' of `formlists'
                }
            }

            qui count if !missing(`var')
            local cases = r(N)
            local miss  = _N - `cases'

            local vl_text ""
            local rs_text ""
            local resp = 0

            foreach d of local dums {

                if "`pattern'" == "direct" {
                    local code = substr("`d'", length("`var'") + 2, .)
                }
                else {
                    local code = substr("`d'", length("`bqn'") + 2, ///
                        length("`d'") - length("`bqn'") - length("`brk'") - 2)
                }

                * option label: the dummy's own variable label first, then
                * the choices sheet of the form, then the bare code
                local olab: variable label `d'
                if `"`olab'"' == "" & "`qlist'" != "" {
                    capture _dr_choice, list("`qlist'") code("`code'")
                    if _rc == 0 local olab `"`s(lab)'"'
                }
                if `"`olab'"' == "" local olab "`code'"

                qui count if `d' == 1 & !missing(`var')
                local n1   = r(N)
                local resp = `resp' + `n1'

                local pct = 0
                if `cases' > 0 local pct = 100 * `n1' / `cases'
                local pctf = trim(string(`pct', "%9.1f"))
                local n1f  = trim(string(`n1',  "%15.0fc"))

                if `"`vl_text'"' != "" local vl_text `"`vl_text'@@"'
                local vl_text `"`vl_text'`code' = `olab'"'

                if `"`rs_text'"' != "" local rs_text `"`rs_text'@@"'
                local rs_text `"`rs_text'`olab' = `pctf'% (n=`n1f')"'
            }

            local casesf = trim(string(`cases', "%15.0fc"))
            local respf  = trim(string(`resp',  "%15.0fc"))
            local perc   = "0.0"
            if `cases' > 0 local perc = trim(string(`resp'/`cases', "%9.1f"))
            local rs_text `"`rs_text'@@Cases = `casesf' | Responses = `respf' | `perc' per case"'

            local nopt : word count `dums'
            if `"`varlabel'"' == "" local varlabel "(No label)"

            local ++rw
            frame __dr_rows {
                qui replace variable    = "`var'"                         in `rw'
                qui replace label       = `"`varlabel'"'                  in `rw'
                qui replace type        = "select_multiple (`nopt' opts)" in `rw'
                qui replace observation = "`cases'"                       in `rw'
                qui replace missing     = "`miss'"                        in `rw'
                qui replace value_label = subinstr(`"`vl_text'"', "@@", char(10), .) in `rw'
                qui replace result      = subinstr(`"`rs_text'"', "@@", char(10), .) in `rw'
            }
            continue
        }

        *------------------------------------------------
        * 5b. ORDINARY VARIABLE
        *------------------------------------------------

        qui count if missing(`var')
        local missing_count = r(N)
        local nonmissing    = _N - `missing_count'

        * ---- every defined value label, in the order it was defined ----
        local vl_text ""
        if "`valuelabel'" != "" {
            capture mata: _dr_vlload("`valuelabel'")
            if _rc {
                capture {
                    qui label list `valuelabel'
                    local minv = r(min)
                    local maxv = r(max)
                    if `maxv' - `minv' <= 1000 {
                        forvalues val = `minv'/`maxv' {
                            local lb: label `valuelabel' `val'
                            if `"`lb'"' != "`val'" {
                                if `"`vl_text'"' != "" local vl_text `"`vl_text'@@"'
                                local vl_text `"`vl_text'`val' = `lb'"'
                            }
                        }
                    }
                }
            }
        }

        * ---- type aware statistics ----
        local rs_text ""
        local dfmt : format `var'

        if `nonmissing' == 0 {
            local rs_text "All missing (0 observations)"
        }
        else if "`valuelabel'" != "" {
            capture qui levelsof `var', local(levels)
            if _rc {
                local rs_text "Too many distinct values to summarise"
            }
            else if `r(r)' > 500 {
                local rs_text "`r(r)' distinct values (too many to list)"
            }
            else {
                foreach level of local levels {
                    qui count if `var' == `level'
                    local cnt  = r(N)
                    local pctf = trim(string(100 * `cnt' / `nonmissing', "%9.2f"))
                    local lb ""
                    capture mata: st_local("lb", st_vlmap("`valuelabel'", `level'))
                    if `"`lb'"' == "" local lb "`level'"
                    if `"`rs_text'"' != "" local rs_text `"`rs_text'@@"'
                    local rs_text `"`rs_text'`lb' = `pctf'%"'
                }
            }
        }
        else if substr("`vartype'", 1, 3) == "str" {

            * SurveyCTO and Kobo write SubmissionDate, starttime and endtime
            * as text, so try to read the column as a date before falling
            * back to counting characters.
            local parsed = 0
            qui count if !missing(`var') & ///
                (regexm(`var', "^[A-Za-z][A-Za-z][A-Za-z] +[0-9]") | ///
                 regexm(`var', "^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]") | ///
                 regexm(`var', "^[0-9]+/[0-9]+/[0-9][0-9][0-9][0-9]") | ///
                 regexm(`var', "^[0-9][0-9]?[A-Za-z][A-Za-z][A-Za-z][0-9][0-9][0-9][0-9]"))
            if r(N) >= 0.8 * `nonmissing' {
                tempvar dtv
                qui gen double `dtv' = .
                local dkind ""

                foreach msk in MDYhms YMDhms {
                    if `parsed' continue
                    qui replace `dtv' = clock(subinstr(`var', "T", " ", .), "`msk'")
                    qui count if !missing(`dtv')
                    if r(N) >= 0.8 * `nonmissing' {
                        local parsed = 1
                        local dkind "c"
                    }
                }
                foreach msk in MDY DMY YMD {
                    if `parsed' continue
                    qui replace `dtv' = date(`var', "`msk'")
                    qui count if !missing(`dtv')
                    if r(N) >= 0.8 * `nonmissing' {
                        local parsed = 1
                        local dkind "d"
                    }
                }

                if `parsed' {
                    _dr_span `dtv', kind(`dkind')
                    local rs_text "`s(txt)'"
                }
                qui drop `dtv'
            }

            * Text with only a few different answers is a set of categories
            * (data typed into Excel keeps them as text): list each answer
            * with its share, as for a labelled variable.  Numbers stored as
            * text get Min / Max / Avg.  Free text keeps the length summary.
            local strdone = 0
            if `parsed' == 0 {
                mata: _dr_strsum("`var'", `strmax')
            }

            if `parsed' == 0 & `strdone' == 0 {
                tempvar slen
                qui gen long `slen' = length(`var') if !missing(`var')
                qui sum `slen', meanonly
                local lmin = r(min)
                local lmax = r(max)
                qui drop `slen'
                local rs_text "Missing=`missing_count' obs, Min length=`lmin', Max length=`lmax'"
            }
        }
        else {

            * Is this a Stata date or date-time?  The display format is the
            * reliable signal; where it is missing we fall back on the value
            * range, which for %tc milliseconds is distinctive enough to be
            * safe, and for %td days needs the variable name to agree.
            local dkind ""
            if regexm("`dfmt'", "^%-?t[cC]")        local dkind "c"
            else if regexm("`dfmt'", "^%-?t[dD]")   local dkind "d"
            else if regexm("`dfmt'", "^%-?d")       local dkind "d"
            else if regexm("`dfmt'", "^%-?t[wmqh]") local dkind "p"

            if "`dkind'" == "" {
                qui count if !missing(`var') & ///
                    (`var' < 631152000000 | `var' > 2840227200000)
                if r(N) == 0 local dkind "c"
            }
            if "`dkind'" == "" {
                if regexm(lower("`var'"), "date|^day$|_day$") {
                    qui count if !missing(`var') & ///
                        (`var' != int(`var') | `var' < 7305 | `var' > 32873)
                    if r(N) == 0 local dkind "d"
                }
            }

            if "`dkind'" != "" {
                _dr_span `var', kind(`dkind') fmt("`dfmt'")
                local rs_text "`s(txt)'"
            }
            else {
                qui sum `var'
                local mn = trim(string(r(min),  "%9.2f"))
                local mx = trim(string(r(max),  "%9.2f"))
                local av = trim(string(r(mean), "%9.2f"))
                local rs_text "Min=`mn', Max=`mx', Avg=`av'"
            }
        }

        if `"`varlabel'"' == "" local varlabel "(No label)"

        * Excel tops out at 32,767 characters in a cell
        if length(`"`vl_text'"') > 30000 {
            local vl_text = substr(`"`vl_text'"', 1, 30000) + " ...(truncated)"
        }
        if length(`"`rs_text'"') > 30000 {
            local rs_text = substr(`"`rs_text'"', 1, 30000) + " ...(truncated)"
        }

        local ++rw
        frame __dr_rows {
            qui replace variable    = "`var'"           in `rw'
            qui replace label       = `"`varlabel'"'    in `rw'
            qui replace type        = "`vartype'"       in `rw'
            qui replace observation = "`nonmissing'"    in `rw'
            qui replace missing     = "`missing_count'" in `rw'
            qui replace value_label = subinstr(`"`vl_text'"', "@@", char(10), .) in `rw'
            qui replace result      = subinstr(`"`rs_text'"', "@@", char(10), .) in `rw'
        }
    }

    frame __dr_rows: qui drop if variable == ""

    frame __dr_sum: qui drop if category == ""

    *========================================
    * 6. EXPORT TO EXCEL
    *========================================
    *
    * Every sheet starts its table at row 4: rows 1-3 are left free for the
    * title bar, the subtitle and a spacer that step 7 fills in.

    * Writing a second round into an existing workbook with sheetname() must
    * not need replace, which would wipe the first round.
    local sumopt "`replace'"
    capture confirm file "`xlfile'"
    if _rc == 0 & "`replace'" == "" local sumopt "sheetreplace"

    frame __dr_sum: qui export excel category value using "`using'", ///
        sheet("`s_sum'") cell(A4) `sumopt'

    local datcols "variable label type observation missing value_label result"

    capture frame __dr_rows: qui export excel `datcols' using "`using'", ///
        sheet("`s_dat'") firstrow(variables) cell(A4) sheetreplace

    if _rc {
        * Older Stata builds refuse strL on export; fall back to str2045.
        di as text "  (note: long text shortened to 2045 characters on export)"
        frame __dr_rows {
            foreach cvar of local datcols {
                qui replace `cvar' = substr(`cvar', 1, 2045)
                qui recast str2045 `cvar', force
            }
            qui export excel `datcols' using "`using'", ///
                sheet("`s_dat'") firstrow(variables) cell(A4) sheetreplace
        }
    }

    *========================================
    * 7. FORMAT THE WORKBOOK
    *========================================
    *
    * Done by Stata's own Excel writer (Mata xl()), so it needs nothing
    * installed.  Wrapping is switched on wherever a cell holds several
    * lines, which is what makes the line breaks show, and every row is
    * sized to fit its tallest cell.  The text reaches Mata through globals,
    * so quotes and backslashes in a title or path cannot break anything.
    * If anything here fails the report is still complete, only plainer.

    local obsf  = trim(string(`obs',  "%15.0fc"))
    local varsf = trim(string(`vars', "%15.0fc"))

    global DR__file `"`xlfile'"'
    global DR__sum  `"`s_sum'"'
    global DR__dat  `"`s_dat'"'

    * Both sheets carry the dataset name as their title
    global DR__title `"`title'"'
    global DR__sumt2 "Data quality report  ·  `obsf' observations  ·  `varsf' variables"
    local  dsub "`obsf' observations  ·  `varsf' variables  ·  one row per variable"
    if `docollapse' & `nblk' > 0 {
        local dsub "`dsub'; each multiple-select question is one shaded row"
    }
    global DR__datt2 `"`dsub'"'

    * Each sheet is formatted in one go and only saved at the end, so a
    * failed attempt leaves the file untouched.  The workbook was written a
    * moment ago and Windows (an antivirus scan, a sync client) can still
    * be holding it, so a failure gets one more try after a short pause.
    local fmtok = 1
    foreach s in sum dat {
        local frm = cond("`s'" == "sum", "__dr_sum", "__dr_rows")
        capture frame `frm': mata: _dr_fmt_`s'()
        if _rc {
            sleep 1500
            capture noisily frame `frm': mata: _dr_fmt_`s'()
            if _rc local fmtok = 0
        }
    }
    if `fmtok' == 0 {
        di as text "  (note: the workbook could not be fully formatted; " ///
                   "all of its content is there)"
    }
    macro drop DR__*


    capture frame drop __dr_sum
    capture frame drop __dr_rows
    capture frame drop __dr_survey
    capture frame drop __dr_choices

    *========================================
    * 8. DISPLAY SUMMARY INFORMATION
    *========================================

    restore

    local sheetlist "`s_sum', `s_dat'"

    di _n(2)
    di as text "{hline 70}"
    di as result "  Data Report Generated Successfully"
    di as text "{hline 70}"
    di as text "  Output file  : " as result "`xlfile'"
    di as text "  Dataset      : " as result "`title'"
    di as text "  Observations : " as result "`obs'"
    di as text "  Variables    : " as result "`vars'"
    di as text "  Report rows  : " as result "`rw'"
    if `docollapse' {
        di as text "  Multi-select : " as result ///
           "`nblk' question(s), `nfolded' option variable(s) folded in"
    }
    di as text "  Report sheets: " as result "`sheetlist'"

    * a full path, so the link opens the file wherever Stata's folder is
    local xlfull `"`xlfile'"'
    if !(substr(`"`xlfile'"', 2, 1) == ":" | inlist(substr(`"`xlfile'"', 1, 1), "/", "\", "~")) {
        local xlfull `"`c(pwd)'`c(dirsep)'`xlfile'"'
    }
    di as text `"  Open         : {browse `"`xlfull'"':click to open}"'
    di as text "{hline 70}"
    di as text _n

end


*============================================================================
* HELPERS
*============================================================================

* Write one row of the Summary sheet.  kind is sec, txt, num, warn or bad
* (see section 4); the formatting step reads it.
cap program drop _dr_sumrow
program define _dr_sumrow
    args row kind cat val
    frame __dr_sum {
        qui replace kind     = "`kind'"  in `row'
        qui replace category = `"`cat'"' in `row'
        qui replace value    = `"`val'"' in `row'
    }
end

* Report the first and last value of a date or date-time variable, and the
* span between them, in place of a meaningless Min/Max/Avg of day or
* millisecond counts.
cap program drop _dr_span
program define _dr_span, sclass
    syntax varname , kind(string) [fmt(string)]

    sreturn clear
    qui sum `varlist', meanonly
    if r(N) == 0 {
        sreturn local txt "All missing (0 observations)"
        exit
    }

    * Values are read straight out of r() inside each expression: passing a
    * %tc millisecond count through a macro would round it to %10.0g and
    * throw the time away.
    if "`kind'" == "c" {
        local f1 = trim(string(r(min), "%tcDD_Mon_CCYY_HH:MM:SS"))
        local f2 = trim(string(r(max), "%tcDD_Mon_CCYY_HH:MM:SS"))
        local sp = trim(string((r(max) - r(min)) / 86400000, "%9.1f"))
        sreturn local txt "First = `f1'@@Last = `f2'@@Span = `sp' days"
    }
    else if "`kind'" == "d" {
        local f1 = trim(string(r(min), "%tdDD_Mon_CCYY"))
        local f2 = trim(string(r(max), "%tdDD_Mon_CCYY"))
        local sp = trim(string(r(max) - r(min), "%9.0f"))
        sreturn local txt "First date = `f1'@@Last date = `f2'@@Span = `sp' days"
    }
    else {
        if "`fmt'" == "" local fmt "%9.0g"
        local f1 = trim(string(r(min), "`fmt'"))
        local f2 = trim(string(r(max), "`fmt'"))
        sreturn local txt "First = `f1'@@Last = `f2'"
    }
end

* Read an XLSForm (SurveyCTO / ODK / Kobo) and report back what it says
* about the survey.  Leaves the choices sheet behind in frame __dr_choices
* so that option labels can be looked up while the report is built.
cap program drop _dr_readform
program define _dr_readform, sclass
    syntax , form(string) [formlang(string)]

    sreturn clear
    sreturn local ok 0

    capture qui import excel using "`form'", describe
    if _rc exit
    local nsheets = r(N_worksheet)
    local survsheet ""
    local choisheet ""
    forvalues s = 1/`nsheets' {
        local sn = r(worksheet_`s')
        if lower(trim("`sn'")) == "survey"  local survsheet "`sn'"
        if lower(trim("`sn'")) == "choices" local choisheet "`sn'"
    }
    if "`survsheet'" == "" exit

    *---------------- survey sheet ----------------
    capture frame drop __dr_survey
    frame create __dr_survey

    local multi     ""
    local multilist ""
    local names     ""
    local nq        = 0
    local sok       = 0

    frame __dr_survey {
        capture qui import excel using "`form'", sheet("`survsheet'") ///
            allstring clear
        if _rc == 0 & _N >= 2 {
            qui ds
            local cols `r(varlist)'
            local ctype ""
            local cname ""
            foreach c of local cols {
                local h = lower(trim(`c'[1]))
                if "`h'" == "type" local ctype "`c'"
                if "`h'" == "name" local cname "`c'"
            }
            if "`ctype'" != "" & "`cname'" != "" {
                local sok = 1
                qui drop in 1
                qui drop if trim(`cname') == "" | trim(`ctype') == ""
                local nrow = _N
                forvalues i = 1/`nrow' {
                    local tp = lower(trim(`ctype'[`i']))
                    local nm = trim(`cname'[`i'])
                    if "`nm'" == "" continue
                    if substr("`tp'", 1, 5) == "begin" continue
                    if substr("`tp'", 1, 3) == "end"   continue
                    if "`tp'" == "note" continue
                    local ++nq
                    local names "`names' `nm'"
                    if substr("`tp'", 1, 15) == "select_multiple" {
                        local ln = trim(subinstr("`tp'", "select_multiple", "", 1))
                        local ln : word 1 of `ln'
                        if "`ln'" == "" local ln "."
                        local multi     "`multi' `nm'"
                        local multilist "`multilist' `ln'"
                    }
                }
            }
        }
    }
    if `sok' == 0 exit

    *---------------- choices sheet ----------------
    capture frame drop __dr_choices
    if "`choisheet'" != "" {
        frame create __dr_choices
        frame __dr_choices {
            capture qui import excel using "`form'", sheet("`choisheet'") ///
                allstring clear
            local cok = 0
            if _rc == 0 & _N >= 2 {
                qui ds
                local ccols `r(varlist)'
                local clist ""
                local ccode ""
                local clab  ""
                * The code column is headed "name" in the ODK/Kobo template
                * and "value" in SurveyCTO's own; accept either.  Labels may
                * be "label", "label::English (en)" or "label:english".
                local clabx ""
                foreach c of local ccols {
                    local h = lower(trim(`c'[1]))
                    if "`h'" == "list_name" | "`h'" == "list name" local clist "`c'"
                    if "`h'" == "name" | "`h'" == "value" local ccode "`c'"
                    if substr("`h'", 1, 5) == "label" {
                        if "`clab'" == "" local clab "`c'"
                        if "`h'" == "label" local clab "`c'"
                        if strpos("`h'", "english") local clabx "`c'"
                        if "`formlang'" != "" {
                            if strpos("`h'", lower("`formlang'")) local clab "`c'"
                        }
                    }
                }
                * with no language asked for and no plain "label" column,
                * an English one beats whichever happened to come first
                if "`formlang'" == "" & "`clabx'" != "" {
                    local hh = lower(trim(`clab'[1]))
                    if "`hh'" != "label" local clab "`clabx'"
                }
                if "`clist'" != "" & "`ccode'" != "" & "`clab'" != "" {
                    local cok = 1
                    qui keep `clist' `ccode' `clab'
                    qui rename `clist' _dr_list
                    qui rename `ccode' _dr_code
                    qui rename `clab'  _dr_lab
                    qui drop in 1
                    qui replace _dr_list = lower(trim(_dr_list))
                    qui replace _dr_code = trim(_dr_code)
                    qui drop if _dr_list == "" | _dr_code == ""
                    qui gen long _dr_row = _n
                }
            }
            if `cok' == 0 qui clear
        }
    }

    local multi     = trim(itrim("`multi'"))
    local multilist = trim(itrim("`multilist'"))
    local names     = trim(itrim("`names'"))

    sreturn local ok        1
    sreturn local nq        `nq'
    sreturn local multi     "`multi'"
    sreturn local multilist "`multilist'"
    sreturn local names     "`names'"
end


* Return the codes a choice list declares, so that option variables whose
* code the form does not know can be discarded.
cap program drop _dr_codes
program define _dr_codes, sclass
    syntax , list(string)
    sreturn clear
    sreturn local codes ""
    if "`list'" == "" | "`list'" == "." exit
    local list = lower("`list'")
    capture frame __dr_choices {
        capture confirm variable _dr_row
        if _rc == 0 {
            capture qui levelsof _dr_code if _dr_list == "`list'", ///
                local(cc) clean
            if _rc == 0 sreturn local codes "`cc'"
        }
    }
end


* Look up one choice label.  Used only when the exported option dummy has
* no variable label of its own.
cap program drop _dr_choice
program define _dr_choice, sclass
    syntax , list(string) code(string)
    sreturn clear
    sreturn local lab ""
    if "`list'" == "" | "`list'" == "." exit
    local list = lower("`list'")
    capture frame __dr_choices {
        capture confirm variable _dr_row
        if _rc == 0 {
            qui count if _dr_list == "`list'" & _dr_code == "`code'"
            if r(N) > 0 {
                qui sum _dr_row if _dr_list == "`list'" & ///
                    _dr_code == "`code'", meanonly
                local i  = r(min)
                local lb = _dr_lab[`i']
                sreturn local lab `"`lb'"'
            }
        }
    }
end


*============================================================================
* MATA
*============================================================================

capture mata: mata drop _dr_vlload()
capture mata: mata drop _dr_rgb()
capture mata: mata drop _dr_longest()
capture mata: mata drop _dr_lines()
capture mata: mata drop _dr_height()
capture mata: mata drop _dr_fit()
capture mata: mata drop _dr_banner()
capture mata: mata drop _dr_head()
capture mata: mata drop _dr_body()
capture mata: mata drop _dr_fmt_sum()
capture mata: mata drop _dr_fmt_dat()
capture mata: mata drop _dr_natkey()
capture mata: mata drop _dr_strsum()

mata:
mata set matastrict off

// Sort key for natural order: case ignored and every run of digits padded,
// so "Type 2" comes before "Type 10"
string scalar _dr_natkey(string scalar s)
{
    string scalar out, run, c
    real scalar   i

    out = ""
    run = ""
    for (i = 1; i <= strlen(s); i++) {
        c = substr(s, i, 1)
        if (c >= "0" & c <= "9") {
            run = run + c
            continue
        }
        if (run != "") out = out + substr("000000000000", 1, max((0, 12 - strlen(run)))) + run
        run = ""
        out = out + c
    }
    if (run != "") out = out + substr("000000000000", 1, max((0, 12 - strlen(run)))) + run
    return(strlower(out))
}

// Summary of a text variable, written to the caller's rs_text with
// strdone set to 1; strdone stays 0 when the variable is free text
// (more than smax different answers, or every answer different), which
// keeps the length summary.
//   - every answer a number, more than 10 values: Min / Max / Avg
//   - otherwise at most smax answers: each answer with its share, one per
//     line, in natural order (numeric order when they are numbers)
void _dr_strsum(string scalar vn, real scalar smax)
{
    string colvector s, u, key
    real colvector   x, n
    real scalar      i, k, nnm
    string scalar    out
    transmorphic     A

    st_local("strdone", "0")
    s = st_sdata(., vn)
    s = select(s, s :!= "")
    nnm = rows(s)
    if (nnm == 0) return

    u = uniqrows(s)
    x = strtoreal(u)
    if (!hasmissing(x) & rows(u) > 10) {
        x = strtoreal(s)
        st_local("rs_text", "Min=" + strtrim(strofreal(min(x), "%12.2f")) +
                 ", Max=" + strtrim(strofreal(max(x), "%12.2f")) +
                 ", Avg=" + strtrim(strofreal(mean(x), "%12.2f")) +
                 " (numbers stored as text)")
        st_local("strdone", "1")
        return
    }
    if (rows(u) > smax) return
    if (rows(u) == nnm & nnm >= 10) return

    if (rows(u) > 1 & !hasmissing(x)) u = u[order(x, 1)]
    else if (rows(u) > 1) {
        key = J(rows(u), 1, "")
        for (k = 1; k <= rows(u); k++) key[k] = _dr_natkey(u[k])
        u = u[order((key, u), (1, 2))]
    }

    A = asarray_create()
    for (k = 1; k <= rows(u); k++) asarray(A, u[k], k)
    n = J(rows(u), 1, 0)
    for (i = 1; i <= nnm; i++) {
        k = asarray(A, s[i])
        n[k] = n[k] + 1
    }

    out = ""
    for (k = 1; k <= rows(u); k++) {
        if (k > 1) out = out + "@@"
        out = out + u[k] + " = " + strtrim(strofreal(100 * n[k] / nnm, "%9.2f")) + "%"
    }
    st_local("rs_text", out)
    st_local("strdone", "1")
}

void _dr_vlload(string scalar lname)
{
    real colvector    vv
    string colvector  tt
    string scalar     s
    real scalar       i

    vv = J(0, 1, .)
    tt = J(0, 1, "")
    st_vlload(lname, vv, tt)

    s = ""
    for (i = 1; i <= rows(vv); i++) {
        if (i > 1) s = s + "@@"
        s = s + strofreal(vv[i]) + " = " + tt[i]
    }
    st_local("vl_text", s)
}


//---------------------------------------------------------------------------
// Workbook formatting.  Everything below uses only Stata's own xl() class.
//
// Three colours only: navy for the title, the header and the variable
// names; a pale blue to shade multiple-select rows and the Summary labels;
// and red for variables that hold no data.  The rest is black, white and
// grey.
//---------------------------------------------------------------------------

// Palette, as the "R G B" strings xl() takes
string scalar _dr_rgb(string scalar k)
{
    if (k == "navy")  return("31 56 100")
    if (k == "shade") return("221 235 247")
    if (k == "red")   return("192 0 0")
    if (k == "grid")  return("191 191 191")
    if (k == "grey")  return("89 89 89")
    if (k == "white") return("255 255 255")
    return("0 0 0")
}

// Length of the longest line in a cell
real scalar _dr_longest(string scalar s)
{
    real scalar   m, p
    string scalar t, ln

    m = 0
    t = s
    while (1) {
        p  = strpos(t, char(10))
        ln = (p == 0 ? t : substr(t, 1, p - 1))
        if (ustrlen(ln) > m) m = ustrlen(ln)
        if (p == 0) break
        t = substr(t, p + 1, .)
    }
    return(m)
}

// Lines a cell takes once wrapped in a column w characters wide.  A line
// that fits the column (which _dr_fit sized with 3 characters to spare)
// is one line; a longer one wraps at word boundaries, so its estimate
// leaves a little slack.
real scalar _dr_lines(string scalar s, real scalar w)
{
    real scalar   n, p, cpl, L
    string scalar t, ln

    cpl = max((8, floor((w - 2) * 0.92)))
    n   = 0
    t   = s
    while (1) {
        p  = strpos(t, char(10))
        ln = (p == 0 ? t : substr(t, 1, p - 1))
        L  = ustrlen(ln)
        n  = n + (L <= w - 3 ? 1 : ceil(L / cpl))
        if (p == 0) break
        t = substr(t, p + 1, .)
    }
    return(n)
}

// Row height, in points, for a row whose tallest cell has n lines.  A line
// of 10-point Calibri takes 12.75 to 14.5 points depending on the screen's
// display scaling, so the larger figure is used: a little spare room is
// better than a clipped last line.  Excel caps a row at 409 points.
real scalar _dr_height(real scalar n)
{
    if (n <= 1) return(18)
    return(min((409, n * 14.5 + 5)))
}

// A column width that fits the longest line, kept within lo..hi
real scalar _dr_fit(string colvector s, real scalar lo, real scalar hi)
{
    real scalar i, m, L

    m = 0
    for (i = 1; i <= rows(s); i++) {
        L = _dr_longest(s[i])
        if (L > m) m = L
    }
    return(min((hi, max((lo, m + 3)))))
}

// Title bar (row 1) and subtitle (row 2), each merged and centred across
// the table, then a thin spacer (row 3)
void _dr_banner(class xl scalar b, string scalar sheet, real scalar nc,
                string scalar t1, string scalar t2)
{
    b.set_sheet(sheet)
    b.set_sheet_gridlines(sheet, "off")

    b.put_string(1, 1, t1)
    b.set_sheet_merge(sheet, (1, 1), (1, nc))
    b.set_fill_pattern(1, (1, nc), "solid", _dr_rgb("navy"))
    b.set_font(1, (1, nc), "Calibri", 14, _dr_rgb("white"))
    b.set_font_bold(1, (1, nc), "on")
    b.set_horizontal_align(1, (1, nc), "center")
    b.set_vertical_align(1, (1, nc), "center")
    b.set_row_height(1, 1, 30)

    b.put_string(2, 1, t2)
    b.set_sheet_merge(sheet, (2, 2), (1, nc))
    b.set_font(2, (1, nc), "Calibri", 10, _dr_rgb("grey"))
    b.set_font_italic(2, (1, nc), "on")
    b.set_horizontal_align(2, (1, nc), "center")
    b.set_vertical_align(2, (1, nc), "center")
    b.set_row_height(2, 2, 20)

    b.set_row_height(3, 3, 6)
}

// Column header row.  ctr flags the columns that are centred.
void _dr_head(class xl scalar b, real scalar r, string rowvector h,
              real rowvector ctr)
{
    real scalar nc, k

    nc = cols(h)
    b.put_string(r, 1, h)
    b.set_fill_pattern(r, (1, nc), "solid", _dr_rgb("navy"))
    b.set_font(r, (1, nc), "Calibri", 10, _dr_rgb("white"))
    b.set_font_bold(r, (1, nc), "on")
    b.set_vertical_align(r, (1, nc), "center")
    b.set_text_wrap(r, (1, nc), "on")
    for (k = 1; k <= nc; k++) {
        if (ctr[k]) {
            b.set_horizontal_align(r, k, "center")
        }
        else {
            b.set_horizontal_align(r, k, "left")
            b.set_text_indent(r, k, 1)
        }
    }
    b.set_border(r, (1, nc), "thin", _dr_rgb("grid"))
    b.set_row_height(r, r, 22)
}

// Base style for the body rows r1..r2: font, alignment, wrapping and a
// light grid around every cell.  wrap flags the columns that wrap.
void _dr_body(class xl scalar b, real scalar r1, real scalar r2,
              real scalar nc, real rowvector ctr, real rowvector wrap)
{
    real scalar    k
    real rowvector rr

    rr = (r1, r2)
    b.set_font(rr, (1, nc), "Calibri", 10, "0 0 0")
    b.set_vertical_align(rr, (1, nc), "top")
    for (k = 1; k <= nc; k++) {
        if (ctr[k]) {
            b.set_horizontal_align(rr, k, "center")
        }
        else {
            b.set_horizontal_align(rr, k, "left")
            b.set_text_indent(rr, k, 1)
        }
        if (wrap[k]) b.set_text_wrap(rr, k, "on")
    }
    b.set_border(rr, (1, nc), "thin", _dr_rgb("grid"))
}

// Summary sheet: a compact two-column table, labels shaded on the left,
// counts as real numbers on the right
void _dr_fmt_sum()
{
    class xl scalar b
    string matrix   S
    string scalar   k
    real scalar     n, r0, r1, i, x, v, wB

    S  = st_sdata(., ("category", "value", "kind"))
    n  = rows(S)
    r0 = 4
    r1 = r0 + n - 1
    wB = _dr_fit(S[., 2], 26, 70)

    b.load_book(st_global("DR__file"))
    b.set_mode("open")
    _dr_banner(b, st_global("DR__sum"), 2, st_global("DR__title"), st_global("DR__sumt2"))
    b.set_column_width(1, 1, 36)
    b.set_column_width(2, 2, wB)

    if (n > 0) {
        // counts go in as real numbers first: put_number() resets a cell's
        // style, so it has to come before any formatting
        for (i = 1; i <= n; i++) {
            k = S[i, 3]
            v = strtoreal(S[i, 2])
            if ((k == "num" | k == "bad") & v < .) {
                b.put_number(r0 + i - 1, 2, v)
            }
        }

        _dr_body(b, r0, r1, 2, (0, 0), (0, 1))
        b.set_fill_pattern((r0, r1), 1, "solid", _dr_rgb("shade"))
        b.set_font((r0, r1), 1, "Calibri", 10, _dr_rgb("navy"))
        b.set_font_bold((r0, r1), 1, "on")

        for (i = 1; i <= n; i++) {
            x = r0 + i - 1
            k = S[i, 3]
            v = strtoreal(S[i, 2])
            if ((k == "num" | k == "bad") & v < .) {
                b.set_number_format(x, 2, "#,##0")
                if (k == "bad" & v > 0) {
                    b.set_font(x, 2, "Calibri", 10, _dr_rgb("red"))
                    b.set_font_bold(x, 2, "on")
                }
            }
            b.set_row_height(x, x, _dr_height(_dr_lines(S[i, 2], wB)))
        }
    }
    b.close_book()
}

// Data_report sheet
void _dr_fmt_dat()
{
    class xl scalar b
    string matrix   S
    real rowvector  w, ctr, wrap
    real scalar     n, nc, r0, r1, i, x, k, lines

    S  = st_sdata(., ("variable", "label", "type", "observation", "missing", "value_label", "result"))
    n  = rows(S)
    nc = 7
    r0 = 5
    r1 = r0 + n - 1

    ctr  = (0, 0, 0, 1, 1, 0, 0)
    wrap = (0, 1, 0, 0, 0, 1, 1)
    w    = (_dr_fit(S[., 1], 14, 36), _dr_fit(S[., 2], 22, 45), _dr_fit(S[., 3], 10, 26), 12, 10, _dr_fit(S[., 6], 24, 45), _dr_fit(S[., 7], 30, 55))

    b.load_book(st_global("DR__file"))
    b.set_mode("open")
    _dr_banner(b, st_global("DR__dat"), nc, st_global("DR__title"), st_global("DR__datt2"))
    _dr_head(b, 4, ("Variable", "Label", "Type", "Non-missing", "Missing", "Value labels", "Summary"), ctr)
    for (k = 1; k <= nc; k++) b.set_column_width(k, k, w[k])

    if (n > 0) {
        // counts go in as real numbers, so they sort and filter
        b.put_number(r0, 4, strtoreal(S[., (4, 5)]))

        _dr_body(b, r0, r1, nc, ctr, wrap)
        b.set_number_format((r0, r1), (4, 5), "#,##0")
        b.set_font((r0, r1), 1, "Calibri", 10, _dr_rgb("navy"))
        b.set_font_bold((r0, r1), 1, "on")

        for (i = 1; i <= n; i++) {
            x = r0 + i - 1

            if (substr(S[i, 3], 1, 15) == "select_multiple") {
                b.set_fill_pattern(x, (1, nc), "solid", _dr_rgb("shade"))
                b.set_font(x, 3, "Calibri", 10, _dr_rgb("navy"))
                b.set_font_bold(x, 3, "on")
            }
            if (S[i, 2] == "(No label)") {
                b.set_font(x, 2, "Calibri", 10, _dr_rgb("grey"))
                b.set_font_italic(x, 2, "on")
            }
            if (substr(S[i, 7], 1, 11) == "All missing") {
                b.set_font(x, 7, "Calibri", 10, _dr_rgb("red"))
                b.set_font_italic(x, 7, "on")
            }

            lines = 1
            for (k = 1; k <= nc; k++) {
                if (wrap[k]) lines = max((lines, _dr_lines(S[i, k], w[k])))
            }
            b.set_row_height(x, x, _dr_height(lines))
        }
    }
    b.close_book()
}
end
