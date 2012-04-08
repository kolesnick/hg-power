function Write-HgLog {

    Set-Variable CanvasEmptyCharacter -Value ([char] '·') -Option Constant

    function GetCommits([System.Nullable``1[[System.Int32]]] $Count) {

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

    function DrawPixel([char[][]] $Canvas, [int] $Row, [int] $Cell, [char] $Character) {

        $currentCharacter = $Canvas[$Row][$Cell]

        $isOverlap = $currentCharacter -ne $CanvasEmptyCharacter

        if (-not $isOverlap) {

            $Canvas[$Row][$Cell] = $Character

        } else {

            $isIdenticOverlap = $Character -eq $currentCharacter
            $isXCrossOverlap = ($Character -eq '\' -and $currentCharacter -eq '/') -or ($Character -eq '/' -and $currentCharacter -eq '\')

            if ($isXCrossOverlap) {
                $Canvas[$Row][$Cell] = 'X'
            } elseif ($isIdenticOverlap) {
                # character is already the same
            } else {
                $Canvas[$Row][$Cell] = '#'
            }

        }

        return $Canvas
    }

    function DrawLine([char[][]] $Canvas, [double] $Start, [double] $Finish) {

        # adopting coords to array indexes which start from zero
        $Start--
        $Finish--

        for ([int] $row = 0; $row -lt $Canvas.Count; $row++) {

            $cell = CalculateLineCellForRow $Start $Finish $Canvas.Count $row

            $isLastRow = $row -eq $Canvas.Count - 1

            if ($isLastRow) {

                $char = '|'

            } else {

                $nextCell = CalculateLineCellForRow $Start $Finish $Canvas.Count ($row + 1)

                if ($cell -lt $nextCell) {
                    $char = '\'
                } elseif ($cell -gt $nextCell) {
                    $char = '/'
                } elseif ($cell -eq $nextCell) {
                    $char = '|'
                }

            }

            $Canvas = DrawPixel $Canvas $row $cell $char

            if (-not $isLastRow) {
                for ($connectingCell = [Math]::Min($cell, $nextCell) + 1; $connectingCell -lt [Math]::Max($cell, $nextCell); $connectingCell++) {
                    $Canvas = DrawPixel $Canvas $row $connectingCell '_'
                }
            }
        }

        return $Canvas

    }

    function RenderPath([PSObject[]] $TopEntries, [PSObject[]] $BottomEntries, [int] $Width, [int] $MinHeight) {

        $canvas = CreateEmptyCanvas -Width $Width -Height $MinHeight

        foreach ($topEntry in $TopEntries) {

            foreach ($bottomEntry in ($BottomEntries | where { $_.Id -eq $topEntry.Id })) {
                $canvas = DrawLine $canvas -Start $topEntry.Position -Finish $bottomEntry.Position
            }

            # TODO foreachelse $canvas = DrawHead $canvas $topEntry.Position

        }

        return $canvas

    }

    function GetBottomEntriesForCurrentIteration([PSObject] $Commit, [PSObject[]] $TopEntries) {

        $bottomEntries = @()
        $wasCommitAddedToEntries = $false

        foreach ($topEntry in $TopEntries) {

            $shouldTopEntryPointToCommit = $topEntry.Id -eq $Commit.Revision

            if (-not $shouldTopEntryPointToCommit) {

                $bottomEntries += New-Object PSObject -Property @{ Id = $topEntry.Id; Position = $null }
                
            } else {

                if (-not $wasCommitAddedToEntries) {
                    $bottomEntries += New-Object PSObject -Property @{ Id = $Commit.Revision; Position = $null }
                    $wasCommitAddedToEntries = $true
                }

            }

        }

        if (-not $wasCommitAddedToEntries) {
            $bottomEntries += New-Object PSObject -Property @{ Id = $Commit.Revision; Position = $null }
        }

        for ([int] $bottomEntryIndex = 0; $bottomEntryIndex -lt $bottomEntries.Count; $bottomEntryIndex++) {
            $bottomEntries[$bottomEntryIndex].Position = ($bottomEntryIndex + 1) * 4
        }

        return $bottomEntries

    }

    function GetTopEntriesForNextIteration([PSObject] $Commit, [PSObject[]] $BottomEntries) {

        $nextTopEntries = @()

        foreach ($bottomEntry in $BottomEntries) {
    
            $isCommitEntry = $bottomEntry.Id -eq $Commit.Revision

            if (-not $isCommitEntry) {

                $nextTopEntries += $bottomEntry

            } else {

                if ($Commit.ParentRevisionA -ne $null) {
                    $nextTopEntries += New-Object PSObject -Property @{ Id = $Commit.ParentRevisionA; Position = $bottomEntry.Position }
                }

                if ($Commit.ParentRevisionB -ne $null) {
                    $nextTopEntries += New-Object PSObject -Property @{ Id = $Commit.ParentRevisionB; Position = $bottomEntry.Position }
                }

            }

        }
        
        return $nextTopEntries

    }

    function WriteCommitsDag([PSObject[]] $Commits) {

        $topEntries = @()

        foreach ($commit in $Commits) {

            $bottomEntries = GetBottomEntriesForCurrentIteration $commit $topEntries

            RenderPath `
                -TopEntries $topEntries `
                -BottomEntries $bottomEntries `
                -Width 30 `
                -MinHeight 5 `
                | CharArrayToString `
                | Write-Host `

            $topEntries = GetTopEntriesForNextIteration $commit $bottomEntries

        }

    }

    # test code below (should be replaced with real output)

    $commits = GetCommits 32
    WriteCommitsDag $commits

}

Set-Alias hglog Write-HgLog
