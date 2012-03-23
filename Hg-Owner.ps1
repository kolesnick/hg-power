Add-Type -TypeDefinition 'public enum HgOwnerAnalysisData { Commits, Content }'

function Get-HgOwner(
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)] [string[]] $Path,
    [HgOwnerAnalysisData] $Analyse = [HgOwnerAnalysisData]::Content) {

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
        switch ($Analyse) {
            Commits { DetermineHgOwnerUsingLog $Path }
            Content { DetermineHgOwnerUsingAnnotate $Path }
        }
    }

}

Set-Alias hgowner Get-HgOwner
