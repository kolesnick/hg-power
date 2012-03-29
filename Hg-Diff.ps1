function Write-HgDiff([Parameter(Mandatory=$true)] [int] $Index, [string] $Branch) {

    if ($Index -gt -1) {
        throw 'Only negative commit indexes are supported.'
    }

    if ([string]::IsNullOrEmpty($Branch)) {

        $changesetId = hg log `
            --limit (-$Index) `
            --template '{node}\n' `
            2> $null `
            | select -Last 1 `

    } else {

        $changesetId = hg log `
            --limit (-$Index) `
            --branch $Branch `
            --template '{node}\n' `
            2> $null `
            | select -Last 1 `

    }

    hg diff `
        --git `
        --change $changesetId `

}

Set-Alias hgdiff Write-HgDiff
