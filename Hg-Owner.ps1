function Get-HgOwner([Parameter(ValueFromPipeline=$true)][string[]]$Path) {

    Process {
        hg log `
            --no-merges `
            --include $Path `
            --template '{author}\n' `
            | group `
            | sort Count -Descending `
            | %{$_.Name} `
            | select -First 1 `
    }

}

Set-Alias hgowner Get-HgOwner
