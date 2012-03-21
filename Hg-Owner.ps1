function Get-HgOwner([Parameter(Mandatory=$true, ValueFromPipeline=$true)] [string[]] $Path) {

    Begin {

        function DetermineHgOwnerUsingLog([string] $Path) {
            hg log `
                --no-merges `
                --template '{author}\n' `
                $Path `
                2> $null `
                | group `
                | sort Count -Descending `
                | %{$_.Name} `
                | select -First 1 `
        }

        function DetermineHgOwnerUsingAnnotate([string] $Path) {
            hg annotate `
                --user -v `
                $Path `
                2> $null `
                | %{$_.split(':')[0].trim()} `
                | group `
                | sort Count -Descending `
                | %{$_.Name} `
                | select -First 1        
        }

    }

    Process {
        DetermineHgOwnerUsingLog $Path
    }

}

Set-Alias hgowner Get-HgOwner
