function Write-LastHgCommitDiff {

    hgdiff -1

}

Set-Alias hgdifflastcommit Write-LastHgCommitDiff
