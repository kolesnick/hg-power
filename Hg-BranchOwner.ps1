function Get-HgBranchOwner([Parameter(Mandatory=$true, ValueFromPipeline=$true)] [string[]] $Branch) {

    Process {
        hg log `
            --no-merges `
            --branch $Branch `
            --template '{author}\n' `
            | group `
            | sort Count -Descending `
            | %{$_.Name} `
            | select -First 1 `
    }

}

Set-Alias hgbranchowner Get-HgBranchOwner
