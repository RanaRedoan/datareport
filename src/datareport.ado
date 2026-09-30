*============================================================================
* DATA REPORT GENERATOR PROGRAM
*============================================================================
* Version			: 1.4.0
* Author			: Md. Redoan Hossain Bhuiyan
* Published Date 	: 10 February 2026
* Description		: Creates comprehensive Excel data report with multiple
*                     sheets.  Multiple-select (select_multiple) questions are
*                     collapsed into a single mrtab-style row instead of one
*                     row per option dummy.  An optional XLSForm (SurveyCTO,
*                     ODK or Kobo) can be supplied to sharpen detection, to
*                     supply option labels and to cross-check form vs data.
*============================================================================

cap program drop datareport
program define datareport
    version 16.0
    syntax using/ , [replace SHEETname(string) FORM(string) ///
                     FORMLANG(string) noMULTIselect]

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
    * Python formatting step opens the file that was actually created.
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
        local s_frm "Form_check"
    }
    else {
        local s_sum = substr("`sheetname'_Summary",     1, 31)
        local s_dat = substr("`sheetname'_Data_report", 1, 31)
        local s_frm = substr("`sheetname'_Form_check",  1, 31)
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

    local obs      = _N
    local vars     = c(k)
    local filepath = c(filename)
    local rundate  = c(current_date) + " " + c(current_time)

    qui ds
    local allvars `r(varlist)'

    local string_count           = 0
    local numeric_count          = 0
    local missing_label_count    = 0
    local complete_missing_count = 0

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

    capture frame drop __dr_sum
    frame create __dr_sum
    frame __dr_sum {
        qui set obs 40
        qui gen strL category = ""
        qui gen strL value    = ""
    }

    frame __dr_sum {
        qui replace category = "Title of the Dataset:"                    in 1
        qui replace value    = `"`title'"'                                in 1
        qui replace category = "Report generated on:"                     in 2
        qui replace value    = "`rundate'"                                in 2
        qui replace category = "Number of observations:"                  in 3
        qui replace value    = "`obs'"                                    in 3
        qui replace category = "File path:"                               in 4
        qui replace value    = `"`filepath'"'                             in 4
        qui replace category = "Number of variables:"                     in 5
        qui replace value    = "`vars'"                                   in 5
        qui replace category = "Number of complete missing variables:"    in 6
        qui replace value    = "`complete_missing_count'"                 in 6
        qui replace category = "Number of string variables:"              in 7
        qui replace value    = "`string_count'"                           in 7
        qui replace category = "Number of numeric variables:"             in 8
        qui replace value    = "`numeric_count'"                          in 8
        qui replace category = "Number of variables with missing labels:" in 9
        qui replace value    = "`missing_label_count'"                    in 9
        qui replace category = "File size of the dataset:"                in 10
        qui replace value    = "`filesize_disp'"                          in 10
        qui replace category = "Multiple-select questions detected:"      in 11
        qui replace value    = "`nblk'"                                   in 11
        qui replace category = "Option variables folded into them:"       in 12
        qui replace value    = "`nfolded'"                                in 12
    }
    local sr = 12

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

            if `parsed' == 0 {
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

    *========================================
    * 6. FORM VS DATA COVERAGE CHECK
    *========================================

    local n_notindata = 0
    local n_notinform = 0

    if `formok' {
        capture frame drop __dr_chk
        frame create __dr_chk
        frame __dr_chk {
            qui set obs `=`nformq' + `vars' + 5'
            qui gen strL issue = ""
            qui gen strL name  = ""
            qui gen strL note  = ""
        }
        local cr = 0

        * (a) form questions that produced no variable in the data
        foreach q of local formnames {
            local found = 0
            capture confirm variable `q'
            if _rc == 0 local found = 1
            if `found' == 0 {
                capture unab tst : `q'_*
                if _rc == 0 local found = 1
            }
            if `found' == 0 {
                local ++cr
                local ++n_notindata
                frame __dr_chk {
                    qui replace issue = "In form, not in data" in `cr'
                    qui replace name  = "`q'"                  in `cr'
                    qui replace note  = "No variable `q' or `q'_*" in `cr'
                }
            }
        }

        * (b) data variables no form question accounts for
        if `nformq' <= 2000 {
            foreach av of local allvars {
                if strpos(" `formnames' ", " `av' ") continue
                local matched = 0
                foreach q of local formnames {
                    if strpos("`av'", "`q'_") == 1 {
                        local matched = 1
                        continue, break
                    }
                }
                if `matched' == 0 {
                    local ++cr
                    local ++n_notinform
                    frame __dr_chk {
                        qui replace issue = "In data, not in form" in `cr'
                        qui replace name  = "`av'"                 in `cr'
                        qui replace note  = "Metadata, constructed or renamed" in `cr'
                    }
                }
            }
        }

        frame __dr_chk: qui drop if issue == ""

        frame __dr_sum {
            qui replace category = "Form questions not found in data:" in `=`sr'+1'
            qui replace value    = "`n_notindata'"                     in `=`sr'+1'
            qui replace category = "Data variables not found in form:" in `=`sr'+2'
            qui replace value    = "`n_notinform'"                     in `=`sr'+2'
        }
        local sr = `sr' + 2
    }

    frame __dr_sum: qui drop if category == ""

    *========================================
    * 7. EXPORT TO EXCEL
    *========================================

    * Writing a second round into an existing workbook with sheetname() must
    * not need replace, which would wipe the first round.
    local sumopt "`replace'"
    capture confirm file "`xlfile'"
    if _rc == 0 & "`replace'" == "" local sumopt "sheetreplace"

    frame __dr_sum: qui export excel category value using "`using'", ///
        sheet("`s_sum'") firstrow(variables) `sumopt'

    capture frame __dr_rows: qui export excel variable label type ///
        observation missing value_label result using "`using'", ///
        sheet("`s_dat'") firstrow(variables) sheetreplace

    if _rc {
        * Older Stata builds refuse strL on export; fall back to str2045.
        di as text "  (note: long text shortened to 2045 characters on export)"
        frame __dr_rows {
            foreach cvar of varlist variable label type observation ///
                                    missing value_label result {
                qui replace `cvar' = substr(`cvar', 1, 2045)
                qui recast str2045 `cvar', force
            }
            qui export excel variable label type observation missing ///
                value_label result using "`using'", ///
                sheet("`s_dat'") firstrow(variables) sheetreplace
        }
    }

    if `formok' {
        capture frame __dr_chk: qui export excel issue name note ///
            using "`using'", sheet("`s_frm'") firstrow(variables) sheetreplace
    }

    *========================================
    * 8. FORMAT THE WORKBOOK WITH PYTHON
    *========================================

    * The title is dropped into a single-quoted Python string, so strip the
    * quote characters and backslashes that would break it.
    local pyfilepath = subinstr("`xlfile'", "\", "/", .)
    local pytitle    = subinstr(`"`title'"',   char(39), "", .)
    local pytitle    = subinstr(`"`pytitle'"', char(34), "", .)
    local pytitle    = subinstr(`"`pytitle'"', "\", "/", .)

    qui {
        capture {
            tempfile pytmp
            local pyscript "`pytmp'.py"
            file open pyfile using "`pyscript'", write replace text
            file write pyfile "import openpyxl" _n
            file write pyfile "from openpyxl.styles import Font, Alignment, PatternFill, Border, Side" _n
            file write pyfile "from openpyxl.utils import get_column_letter" _n
            file write pyfile "P = '`pyfilepath''" _n
            file write pyfile "DS = '`pytitle''" _n
            file write pyfile "HD1 = '1F3864'" _n
            file write pyfile "HD2 = '2E5C8A'" _n
            file write pyfile "BAND = 'F4F7FB'" _n
            file write pyfile "LINE = 'D6DCE4'" _n
            file write pyfile "ACC = 'DDEBF7'" _n
            file write pyfile "WARN = 'FCE4E4'" _n
            file write pyfile "GREY = '595959'" _n
            file write pyfile "wb = openpyxl.load_workbook(P)" _n
            file write pyfile "thin = Side(style='thin', color=LINE)" _n
            file write pyfile "def style(nm, title, heads, widths, wrap, nums, filt, keycol):" _n
            file write pyfile "    if nm not in wb.sheetnames:" _n
            file write pyfile "        return" _n
            file write pyfile "    ws = wb[nm]" _n
            file write pyfile "    nc = ws.max_column" _n
            file write pyfile "    ws.insert_rows(1)" _n
            file write pyfile "    t = ws.cell(row=1, column=1)" _n
            file write pyfile "    t.value = title if not DS else title + '  |  ' + DS" _n
            file write pyfile "    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=nc)" _n
            file write pyfile "    t.font = Font(bold=True, size=13, color='FFFFFF')" _n
            file write pyfile "    t.fill = PatternFill('solid', fgColor=HD1)" _n
            file write pyfile "    t.alignment = Alignment(vertical='center', horizontal='left', indent=1)" _n
            file write pyfile "    ws.row_dimensions[1].height = 28" _n
            file write pyfile "    for i, c in enumerate(ws[2]):" _n
            file write pyfile "        if i < len(heads):" _n
            file write pyfile "            c.value = heads[i]" _n
            file write pyfile "        c.font = Font(bold=True, size=10, color='FFFFFF')" _n
            file write pyfile "        c.fill = PatternFill('solid', fgColor=HD2)" _n
            file write pyfile "        c.alignment = Alignment(vertical='center', horizontal='left', indent=1, wrap_text=True)" _n
            file write pyfile "        c.border = Border(bottom=Side(style='medium', color=HD1))" _n
            file write pyfile "    ws.row_dimensions[2].height = 26" _n
            file write pyfile "    ws.freeze_panes = 'A3'" _n
            file write pyfile "    if filt:" _n
            file write pyfile "        ws.auto_filter.ref = 'A2:' + get_column_letter(nc) + str(ws.max_row)" _n
            file write pyfile "    for k in widths:" _n
            file write pyfile "        ws.column_dimensions[k].width = widths[k]" _n
            file write pyfile "    for row in ws.iter_rows(min_row=3):" _n
            file write pyfile "        band = (row[0].row % 2 == 0)" _n
            file write pyfile "        n = 1" _n
            file write pyfile "        for c in row:" _n
            file write pyfile "            L = c.column_letter" _n
            file write pyfile "            w = L in wrap" _n
            file write pyfile "            isnum = L in nums" _n
            file write pyfile "            c.font = Font(size=10, bold=(L == keycol), color=(HD1 if L == keycol else '000000'))" _n
            file write pyfile "            c.alignment = Alignment(wrap_text=w, vertical='top'," _n
            file write pyfile "                                    horizontal=('center' if isnum else 'left')," _n
            file write pyfile "                                    indent=(0 if isnum else 1))" _n
            file write pyfile "            c.border = Border(bottom=thin)" _n
            file write pyfile "            if band:" _n
            file write pyfile "                c.fill = PatternFill('solid', fgColor=BAND)" _n
            file write pyfile "            if isnum and isinstance(c.value, str) and c.value.isdigit():" _n
            file write pyfile "                c.value = int(c.value)" _n
            file write pyfile "                c.number_format = '#,##0'" _n
            file write pyfile "            if w and isinstance(c.value, str):" _n
            file write pyfile "                cw = widths.get(L, 10)" _n
            file write pyfile "                k = 0" _n
            file write pyfile "                for ln in c.value.split(chr(10)):" _n
            file write pyfile "                    k += max(1, -(-len(ln) // max(8, int(cw) - 1)))" _n
            file write pyfile "                n = max(n, k)" _n
            file write pyfile "        ws.row_dimensions[row[0].row].height = min(409.5, 16.5 if n < 2 else n * 14.4 + 4)" _n
            file write pyfile "    return ws" _n
            file write pyfile "style('`s_sum'', 'Dataset summary', ['Item', 'Value']," _n
            file write pyfile "      {'A': 40, 'B': 72}, ['B'], [], 0, 'A')" _n
            file write pyfile "ws = style('`s_dat'', 'Variable-level report'," _n
            file write pyfile "           ['Variable', 'Label', 'Type', 'Non-missing', 'Missing', 'Value labels', 'Summary']," _n
            file write pyfile "           {'A': 24, 'B': 44, 'C': 20, 'D': 13, 'E': 11, 'F': 42, 'G': 50}," _n
            file write pyfile "           ['B', 'F', 'G'], ['D', 'E'], 1, 'A')" _n
            file write pyfile "if ws is not None:" _n
            file write pyfile "    for row in ws.iter_rows(min_row=3):" _n
            file write pyfile "        tv = row[2].value" _n
            file write pyfile "        rv = row[6].value" _n
            file write pyfile "        if isinstance(tv, str) and tv[:15] == 'select_multiple':" _n
            file write pyfile "            for c in row[:3]:" _n
            file write pyfile "                c.fill = PatternFill('solid', fgColor=ACC)" _n
            file write pyfile "            row[0].font = Font(size=10, bold=True, color=HD1)" _n
            file write pyfile "            row[2].font = Font(size=10, bold=True, color=HD1)" _n
            file write pyfile "        if isinstance(rv, str) and rv[:11] == 'All missing':" _n
            file write pyfile "            row[6].fill = PatternFill('solid', fgColor=WARN)" _n
            file write pyfile "            row[6].font = Font(size=10, color='9C0006', italic=True)" _n
            file write pyfile "        if not row[5].value:" _n
            file write pyfile "            row[5].font = Font(size=10, color=GREY)" _n
            file write pyfile "ws = wb['`s_sum''] if '`s_sum'' in wb.sheetnames else None" _n
            file write pyfile "if ws is not None:" _n
            file write pyfile "    for row in ws.iter_rows(min_row=3):" _n
            file write pyfile "        a = row[0]" _n
            file write pyfile "        if isinstance(a.value, str) and a.value[-1:] == ':':" _n
            file write pyfile "            a.value = a.value[:-1]" _n
            file write pyfile "        b = row[1]" _n
            file write pyfile "        if isinstance(b.value, str) and b.value.isdigit():" _n
            file write pyfile "            b.value = int(b.value)" _n
            file write pyfile "            b.number_format = '#,##0'" _n
            file write pyfile "style('`s_frm'', 'Form versus data check', ['Issue', 'Name', 'Note']," _n
            file write pyfile "      {'A': 26, 'B': 32, 'C': 46}, ['C'], [], 1, 'B')" _n
            file write pyfile "wb.save(P)" _n
            file close pyfile

            capture python script "`pyscript'"
            if _rc {
                capture shell python "`pyscript'"
                if _rc {
                    shell python3 "`pyscript'"
                }
            }
        }
    }


    capture frame drop __dr_sum
    capture frame drop __dr_rows
    capture frame drop __dr_chk
    capture frame drop __dr_survey
    capture frame drop __dr_choices

    *========================================
    * 9. DISPLAY SUMMARY INFORMATION
    *========================================

    restore

    local sheetlist "`s_sum', `s_dat'"
    if `formok' local sheetlist "`sheetlist', `s_frm'"

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
    if `formok' {
        di as text "  Form check   : " as result ///
           "`n_notindata' not in data, `n_notinform' not in form"
    }
    di as text "  Report sheets: " as result "`sheetlist'"
    di as text "{hline 70}"
    di as text _n

end


*============================================================================
* HELPERS
*============================================================================

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

mata:
mata set matastrict off

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
end
