function Write-HgLog {

    Set-Variable CanvasEmptyCharacter -Value ([char] '·') -Option Constant

    function GetCommits([Nullable``1[[Int32]]] $Count) {

        function ParseRevisionNumber([string] $RevisionNumberChangesetIdPair) {
            return [int] $RevisionNumberChangesetIdPair.Split(':')[0]
        }

        function ParseCommitInfo([Parameter(ValueFromPipeline=$true)] [string] $LogEntry) {

            Process {

                $logEntryParts = $LogEntry.Split([string[]] ' <- ', [StringSplitOptions]::None)

                $revision = ParseRevisionNumber $logEntryParts[0]

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
                            $parentA = ParseRevisionNumber $parents[0]
                            $parentB = $null
                        }
                        2 {
                            # two parents, both explicitly specified
                            $parentA = ParseRevisionNumber $parents[0]
                            $parentB = ParseRevisionNumber $parents[1]
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

    function CreateEmptyCanvas([int] $Width, [int] $Height) {
        return [char[][]] (@(New-Object string -ArgumentList $CanvasEmptyCharacter, $Width) * $Height)
    }

    function CharArrayToString([Parameter(ValueFromPipeline=$true)] [char[]] $CharArray) {
        Process {
            return [string]::Concat(($CharArray | %{ [string] $_ }))
        }
    }

    function CalculateLineCellForRow([double] $StartCell, [double] $FinishCell, [int] $RowCount, [int] $Row) {
        return [Math]::Round(($StartCell * ($RowCount - 1 - $Row) + $FinishCell * $Row) / ($RowCount - 1))
    }

    function DrawLine([char[][]] $Canvas, [double] $Start, [double] $Finish) {

        # adopting coords to array indexes which start from zero
        $Start--
        $Finish--

        for ($row = 0; $row -lt $Canvas.Count; $row++) {

            $cell = CalculateLineCellForRow $Start $Finish $Canvas.Count $row

            $isLastRow = $row -eq $Canvas.Count - 1

            if ($isLastRow) {

                $char = '|'

            } else {

                $nextCell = CalculateLineCellForRow $Start $Finish $Canvas.Count ($row + 1)

                if ($cell -lt $nextCell) {
                    $char = '\'
                }
                if ($cell -gt $nextCell) {
                    $char = '/'
                }
                if ($cell -eq $nextCell) {
                    $char = '|'
                }

            }

            $Canvas[$row][$cell] = $char

            if (-not $isLastRow) {
                for ($connectingCell = [Math]::Min($cell, $nextCell) + 1; $connectingCell -lt [Math]::Max($cell, $nextCell); $connectingCell++) {
                    $Canvas[$row][$connectingCell] = '_'
                }
            }
        }

        return $Canvas

    }

    # test code below (should be replaced with real output)

    GetCommits 32

    $canvas = CreateEmptyCanvas -Width 20 -Height 5
    $canvas = DrawLine $canvas -Start 4 -Finish 15
    $canvas | CharArrayToString | Write-Host 

}

Set-Alias hglog Write-HgLog
