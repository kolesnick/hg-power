function Write-LastHgCommitDiff {

    $lastChangesetID = hg log `
        --limit 1 `
        --template '{node}' `
        2> $null `

    hg diff `
        --change $lastChangesetID `

}

Set-Alias hgdifflastcommit Write-LastHgCommitDiff
