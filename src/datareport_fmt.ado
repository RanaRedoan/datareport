*============================================================================
* datareport_fmt -- workbook styling for datareport
*============================================================================
* Version			: 1.5.2
* Author			: Md. Redoan Hossain Bhuiyan
* Description		: Called by datareport after the report is written; not
*                     meant to be run on its own.  Kept in a file of its own
*                     so that nothing here can stop datareport from loading.
*                     Uses only xl() functions present in Stata 16 and later.
*============================================================================

cap program drop datareport_fmt
program define datareport_fmt
    version 16.0
    syntax , file(string) sum(string) dat(string) [frm(string) formok(integer 0)]
    mata: _dr_style()
end


capture mata: mata drop _dr_nlines()
capture mata: mata drop _dr_height()
capture mata: mata drop _dr_sheet()
capture mata: mata drop _dr_style()

mata:
mata set matastrict off
// ---------------------------------------------------------------------------
// Workbook styling with Stata's own Excel engine (xl() class).
// Row heights are computed from the content, the way Excel would size them,
// so multi-line cells are never clipped whatever the size of the report.
// ---------------------------------------------------------------------------

// lines a wrapped cell needs, given the column width in characters
real scalar _dr_nlines(string scalar s, real scalar w)
{
    real scalar   n, p, seg, cw
    string scalar rest, piece

    if (s == "") return(1)
    cw = w - 1
    if (cw < 8) cw = 8
    n    = 0
    rest = s
    while (1) {
        p = strpos(rest, char(10))
        if (p == 0) piece = rest
        else        piece = substr(rest, 1, p - 1)
        seg = ceil(ustrlen(piece) / cw)
        if (seg < 1) seg = 1
        n = n + seg
        if (p == 0) break
        rest = substr(rest, p + 1, .)
    }
    return(n)
}

// row height in points for a given number of lines
real scalar _dr_height(real scalar n)
{
    if (n < 2) return(16.5)
    if (n * 14.4 + 4 > 409.5) return(409.5)
    return(n * 14.4 + 4)
}

// title bar, header row and body of one sheet
void _dr_sheet(class xl scalar B, string scalar title, string rowvector heads, real rowvector widths, real rowvector wrap, real rowvector nums, real scalar keycol, real scalar nrow, real colvector hts, real scalar band)
{
    real scalar   nc, last, j, r, r0
    string scalar NAVY, MID, BANDC, LINE, WHITE, INK

    NAVY  = "31 56 100"
    MID   = "46 92 138"
    BANDC = "244 247 251"
    LINE  = "214 220 228"
    WHITE = "255 255 255"
    INK   = "26 26 26"

    nc   = cols(heads)
    last = nrow + 2

    for (j = 1; j <= nc; j++) {
        B.set_column_width(j, j, widths[j])
    }

    // title bar
    B.put_string(1, 1, title)
    B.set_fill_pattern(1, (1, nc), "solid", NAVY)
    B.set_font(1, (1, nc), "Calibri", 13, WHITE)
    B.set_font_bold(1, (1, nc), "on")
    B.set_vertical_align(1, (1, nc), "center")
    B.set_row_height(1, 1, 28)

    // header row, renamed from variable names to words
    B.put_string(2, 1, heads)
    B.set_fill_pattern(2, (1, nc), "solid", MID)
    B.set_font(2, (1, nc), "Calibri", 10, WHITE)
    B.set_font_bold(2, (1, nc), "on")
    B.set_vertical_align(2, (1, nc), "center")
    B.set_text_wrap(2, (1, nc), "on")
    B.set_bottom_border(2, (1, nc), "medium", NAVY)
    B.set_row_height(2, 2, 26)

    if (nrow < 1) return

    // body: one call per range, so the cost does not grow with the data
    B.set_font((3, last), (1, nc), "Calibri", 10, INK)
    B.set_vertical_align((3, last), (1, nc), "top")
    B.set_bottom_border((3, last), (1, nc), "thin", LINE)
    for (j = 1; j <= cols(wrap); j++) {
        B.set_text_wrap((3, last), wrap[j], "on")
    }
    for (j = 1; j <= cols(nums); j++) {
        B.set_horizontal_align((3, last), nums[j], "center")
        B.set_number_format((3, last), nums[j], "number_sep")
    }
    if (keycol > 0) {
        B.set_font((3, last), keycol, "Calibri", 10, NAVY)
        B.set_font_bold((3, last), keycol, "on")
    }

    // banded rows
    if (band) {
        for (r = 4; r <= last; r = r + 2) {
            B.set_fill_pattern(r, (1, nc), "solid", BANDC)
        }
    }

    // row heights, one call per run of rows sharing a height
    r0 = 3
    for (r = 4; r <= last; r++) {
        if (hts[r - 2] != hts[r0 - 2]) {
            B.set_row_height(r0, r - 1, hts[r0 - 2])
            r0 = r
        }
    }
    B.set_row_height(r0, last, hts[r0 - 2])
}

// entry point: reads the report frames, then styles every sheet in one pass
void _dr_style()
{
    class xl scalar  B
    string scalar    fn, ssum, sdat, sfrm, ttl, cur
    string colvector sheets, a, tp, vl, rs
    string rowvector hsum, hdat, hfrm
    real scalar      nsum, ndat, nfrm, i, n
    real colvector   hs, hd, hf

    fn   = st_local("file")
    ssum = st_local("sum")
    sdat = st_local("dat")
    sfrm = st_local("frm")

    hsum = ("Item", "Value")
    hdat = ("Variable", "Label", "Type", "Non-missing", "Missing", "Value labels", "Summary")
    hfrm = ("Issue", "Name", "Note")

    cur = st_framecurrent()

    // summary sheet content
    st_framecurrent("__dr_sum")
    nsum = st_nobs()
    a    = st_sdata(., "value")
    ttl  = ""
    if (nsum > 0) ttl = a[1]
    if (ttl != "") ttl = "  |  " + ttl
    hs   = J(nsum, 1, 16.5)
    for (i = 1; i <= nsum; i++) {
        hs[i] = _dr_height(_dr_nlines(a[i], 72))
    }

    // variable-level report content
    st_framecurrent("__dr_rows")
    ndat = st_nobs()
    a    = st_sdata(., "label")
    tp   = st_sdata(., "type")
    vl   = st_sdata(., "value_label")
    rs   = st_sdata(., "result")
    hd   = J(ndat, 1, 16.5)
    for (i = 1; i <= ndat; i++) {
        n = max((_dr_nlines(a[i], 44), _dr_nlines(vl[i], 42), _dr_nlines(rs[i], 50)))
        hd[i] = _dr_height(n)
    }

    // form check content
    nfrm = 0
    hf   = J(0, 1, .)
    if (st_local("formok") == "1") {
        st_framecurrent("__dr_chk")
        nfrm = st_nobs()
        a    = st_sdata(., "note")
        hf   = J(nfrm, 1, 16.5)
        for (i = 1; i <= nfrm; i++) {
            hf[i] = _dr_height(_dr_nlines(a[i], 46))
        }
    }

    st_framecurrent(cur)

    // open once, style everything, save once
    B = xl()
    B.load_book(fn)
    B.set_mode("open")
    sheets = B.get_sheets()

    if (anyof(sheets, ssum)) {
        B.set_sheet(ssum)
        _dr_sheet(B, "Dataset summary" + ttl, hsum, (40, 72), (2), J(1, 0, .), 1, nsum, hs, 1)
    }

    if (anyof(sheets, sdat)) {
        B.set_sheet(sdat)
        // banding is one call per row, so it is left off very wide reports
        _dr_sheet(B, "Variable-level report" + ttl, hdat, (24, 44, 20, 13, 11, 42, 50), (2, 6, 7), (4, 5), 1, ndat, hd, ndat <= 3000)
        for (i = 1; i <= ndat; i++) {
            if (substr(tp[i], 1, 15) == "select_multiple") {
                B.set_fill_pattern(i + 2, (1, 3), "solid", "221 235 247")
                B.set_font(i + 2, 3, "Calibri", 10, "31 56 100")
                B.set_font_bold(i + 2, 3, "on")
            }
            if (substr(rs[i], 1, 11) == "All missing") {
                B.set_fill_pattern(i + 2, 7, "solid", "252 228 228")
                B.set_font(i + 2, 7, "Calibri", 10, "156 0 6")
                B.set_font_italic(i + 2, 7, "on")
            }
        }
    }

    if (nfrm > 0 & anyof(sheets, sfrm)) {
        B.set_sheet(sfrm)
        _dr_sheet(B, "Form versus data check" + ttl, hfrm, (26, 32, 46), (3), J(1, 0, .), 2, nfrm, hf, 1)
    }

    B.close_book()
}

end
