function Write-HgLog {

    function GetCommits([System.Nullable``1[[System.Int32]]] $Count) {

        function ParseRevisionNumber([string] $RevisionNumberChangesetIdPair) {
            return [int] $RevisionNumberChangesetIdPair.Split(':')[0]
        }

        function ParseCommitInfo([Parameter(ValueFromPipeline=$true)] [string] $LogEntry) {

            Process {

                $logEntryParts = $logEntry.Split([string[]] ' <- ', [StringSplitOptions]::None)

                $revision = ParseRevisionNumber($logEntryParts[0])

                $parents = $logEntryParts[1].Split(' ', [StringSplitOptions]::RemoveEmptyEntries)

                if ($revision -eq 0) {

                    # initial commit: has no parents
                    $parentA = $null
                    $parentB = $null

                } else {

                    switch ($parents.Count) {
                        0 {
                            # trivial commit: previous revision is also parent one
                            $parentA = $revision - 1
                            $parentB = $null
                        }
                        1 {
                            # parent is only one and it is explicitly specified
                            $parentA = ParseRevisionNumber($parents[0])
                            $parentB = $null
                        }
                        2 {
                            # two parents, both explicitly specified
                            $parentA = ParseRevisionNumber($parents[0])
                            $parentB = ParseRevisionNumber($parents[1])
                        }
                    }

                }

                return New-Object PSObject -Property @{ Revision = $revision; ParentRevisionA = $parentA; ParentRevisionB = $parentB }

            }

        }

        if ($Count -ne $null) {

            return hg log `
                --limit $Count `
                --template '{rev}:{node|short} <- {parents}\n' `
                2> $null `
                | ParseCommitInfo `

        } else {

            return hg log `
                --template '{rev}:{node|short} <- {parents}\n' `
                2> $null `
                | ParseCommitInfo `

        }

    }

    GetCommits(32)

}

Set-Alias hglog Write-HgLog
