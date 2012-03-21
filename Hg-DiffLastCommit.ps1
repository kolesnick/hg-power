function Write-LastHgCommitDiff {

    $lastChangesetId = hg log `
        --limit 1 `
        --template '{node}' `
        2> $null `

    hg diff `
        --change $lastChangesetId `

}

Set-Alias hgdifflastcommit Write-LastHgCommitDiff
