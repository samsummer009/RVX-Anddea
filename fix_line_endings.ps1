# Fix line endings for shell scripts
(Get-Content utils.sh -Raw) -replace "`r`n", "`n" | Set-Content utils.sh -NoNewline
(Get-Content build.sh -Raw) -replace "`r`n", "`n" | Set-Content build.sh -NoNewline
