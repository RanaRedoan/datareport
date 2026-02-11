******************************************************
* Example do-file: Generate Codebook with gencodebook
* Author: Md. Redoan Hossain Bhuiyan
* Date:   28 Aug 2025
******************************************************

* Clear environment
clear all
set more off

* Load sample dataset (you can replace with your own dataset)
sysuse auto, clear

* Inspect dataset (optional)
describe
summarize

* Generate codebook for ALL variables
gencodebook using "auto_codebook.xlsx", replace

* Done
di as text "Codebook(s) generated successfully!"
******************************************************
