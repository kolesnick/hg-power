function Get-HgOwner([Parameter(Mandatory=$true, ValueFromPipeline=$true)] [string[]] $Path) {

    Begin {

        function DetermineHgOwnerUsingLog([string] $Path) {
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

    Process {
        DetermineHgOwnerUsingLog $Path
    }

}

Set-Alias hgowner Get-HgOwner
