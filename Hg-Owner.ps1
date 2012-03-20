function Get-HgOwner([Parameter(Mandatory=$true, ValueFromPipeline=$true)] [string[]] $Path) {

    Process {
        hg log `
            --no-merges `
            --include $Path `
            --template '{author}\n' `
            2> $null `
            | group `
            | sort Count -Descending `
            | %{$_.Name} `
            | select -First 1 `
    }

}

Set-Alias hgowner Get-HgOwner
