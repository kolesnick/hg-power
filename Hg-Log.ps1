function Write-HgLog {

    hg log `
        --limit 32 `
        --template '{rev}:{node|short} <- {parents}\n' `

}

Set-Alias hglog Write-HgLog
