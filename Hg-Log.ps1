function Write-HgLog {

    Add-Type -AssemblyName System.Core

    Set-Variable CanvasEmptyCharacter -Value ([char] '·') -Option Constant
    Set-Variable CanvasHeadCharacter -Value ([char] 0x25CF) -Option Constant

    Set-Variable CenteredDagRaySplitShift -Value 2 -Option Constant
    Set-Variable CenteredDagRayNormalDistance -Value (2 * $CenteredDagRaySplitShift) -Option Constant

    function GetCommits([System.Nullable[[int]]] $Count) {

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

    function DrawLine([char[][]] $Canvas, [double] $Start, [double] $Finish, [bool] $ShouldStartWithHead) {

        # adopting coords to array indexes which start from zero
        $Start--
        $Finish--

        for ([int] $row = 0; $row -lt $Canvas.Count; $row++) {

            $cell = CalculateLineCellForRow $Start $Finish $Canvas.Count $row

            $isLastRow = $row -eq $Canvas.Count - 1

            if ($isLastRow) {

                $Canvas = DrawPixel $Canvas $row $cell '|'

            } else {

                $isFirstRow = $row -eq 0
                $isHead = $isFirstRow -and $ShouldStartWithHead

                $nextCell = CalculateLineCellForRow $Start $Finish $Canvas.Count ($row + 1)

                if ($isHead) {
                    $char = $CanvasHeadCharacter
                } elseif ($cell -lt $nextCell) {
                    $char = '\'
                } elseif ($cell -gt $nextCell) {
                    $char = '/'
                } elseif ($cell -eq $nextCell) {
                    $char = '|'
                }

                $Canvas = DrawPixel $Canvas $row $cell $char

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
                $canvas = DrawLine $canvas -Start $topEntry.Position -Finish $bottomEntry.Position -ShouldStartWithHead $topEntry.IsHead
            }

        }

        return $canvas

    }

    function GetTopEntriesForCurrentIteration([PSObject] $CurrentCommit, [PSObject[]] $PreviousBottomEntries) {

        $nextTopEntries = @()

        foreach ($bottomEntry in $PreviousBottomEntries) {

            $isCommitEntry = $bottomEntry.Id -eq $CurrentCommit.Revision

            if (-not $isCommitEntry) {

                $nextTopEntries += New-Object PSObject -Property @{ Id = $bottomEntry.Id; Position = $bottomEntry.Position; IsHead = $false }

            } else {

                if ($CurrentCommit.ParentRevisionA -ne $null) {
                    $nextTopEntries += New-Object PSObject -Property @{ Id = $CurrentCommit.ParentRevisionA; Position = $bottomEntry.Position; IsHead = $true }
                }

                if ($CurrentCommit.ParentRevisionB -ne $null) {
                    $nextTopEntries += New-Object PSObject -Property @{ Id = $CurrentCommit.ParentRevisionB; Position = $bottomEntry.Position; IsHead = $true }
                }

            }

        }

        return $nextTopEntries

    }

    function GetBottomEntriesForCurrentIteration([PSObject] $NextCommit, [PSObject[]] $TopEntries) {

        $bottomRevisions = New-Object System.Collections.Generic.HashSet[int]
        $wasCommitAddedToEntries = $false

        foreach ($topEntry in $TopEntries) {

            $isTopEntryConnectedToCommit = $topEntry.Id -eq $NextCommit.Revision

            if (-not $isTopEntryConnectedToCommit) {

                $bottomRevisions.Add($topEntry.Id) > $null
                
            } else {

                if (-not $wasCommitAddedToEntries) {
                    $bottomRevisions.Add($NextCommit.Revision) > $null
                    $wasCommitAddedToEntries = $true
                }

            }

        }

        if (-not $wasCommitAddedToEntries) {
            $bottomRevisions.Add($NextCommit.Revision) > $null
        }

        $bottomEntries = [PSObject[]] ($bottomRevisions | %{ New-Object PSObject -Property @{ Id = $_; Position = $null; IsHead = $false } })

        for ([int] $bottomEntryIndex = 0; $bottomEntryIndex -lt $bottomEntries.Count; $bottomEntryIndex++) {
            $bottomEntries[$bottomEntryIndex].Position = ($bottomEntryIndex + 1) * 4
        }

        return $bottomEntries

    }

    function WriteBasicCommitsDag([PSObject[]] $Commits) {

        $bottomEntries = GetBottomEntriesForCurrentIteration -NextCommit $Commits[0] -TopEntries @()

        for ([int] $commitIndex = 0; $commitIndex -lt $Commits.Count; $commitIndex++) {

            $topEntries = GetTopEntriesForCurrentIteration -CurrentCommit $Commits[$commitIndex] -PreviousBottomEntries $bottomEntries
            $bottomEntries = GetBottomEntriesForCurrentIteration -NextCommit $Commits[$commitIndex+1] -TopEntries $topEntries

            RenderPath `
                -TopEntries $topEntries `
                -BottomEntries $bottomEntries `
                -Width 30 `
                -MinHeight 5 `
                | CharArrayToString `
                | Write-Host `

        }

    }

    function GenerateNewRayId {
        return [Guid]::NewGuid().ToString()
    }

    function HasSingleParent([PSObject] $Commit) {
         return $Commit.ParentRevisionB -eq $null
    }

    function GetExpectedRayPointRevision([PSObject] $Commit) {
        if (HasSingleParent $Commit) {
            return $Commit.ParentRevisionA
        } else {
            return $null
        }
    }

    function IsExpectedPointOnRay([PSObject] $Ray, [PSObject] $Commit) {
        return $Ray.ExpectedPointRevision -eq $Commit.Revision
    }

    function ShouldRayBeSplitted([PSObject] $Ray) {
        return $Ray.IsHead -and $Ray.LastCommit.ParentRevisionB -ne $null
    }

    function PutCommitOnRay([PSObject] $Ray, [PSObject] $Commit) {

        $Ray.IsHead = $true
        $Ray.ExpectedPointRevision = GetExpectedRayPointRevision $Commit
        $Ray.LastCommit = $Commit

        return $Ray
    }

    function PutCommitOnRayIfExpected([PSObject] $Ray, [PSObject] $Commit) {
        
        if (IsExpectedPointOnRay -Ray $Ray -Commit $Commit) {
            return PutCommitOnRay -Ray $Ray -Commit $Commit
        } else {
            return $Ray
        }
    }
    
    function DeterminePositionForNewRay([PSObject[]] $AvailableRays, [int] $CanvasWidth) {

        $measuredPositions = $AvailableRays | %{ $_.Position } | Measure-Object -Minimum -Maximum

        $emptyPixelsBeforeDag = $measuredPositions.Minimum - 1
        $emptyPixelsAfterDag = $CanvasWidth - $measuredPositions.Maximum

        if ($emptyPixelsBeforeDag -gt $emptyPixelsAfterDag) {
            return $measuredPositions.Minimum - $CenteredDagRayNormalDistance
        } else {
            return $measuredPositions.Maximum + $CenteredDagRayNormalDistance
        }

    }

    function UpdateRays([PSObject[]] $Rays, [PSObject] $NewCommit, [int] $CanvasWidth) {

        $resultRays = @()

        foreach ($ray in $Rays) {

            if (ShouldRayBeSplitted $ray) {
                
                $leftRay = New-Object PSObject -Property @{ `
                    Id = GenerateNewRayId; `
                    ParentId = $ray.Id; `
                    Position = $ray.Position - $CenteredDagRaySplitShift; `
                    IsHead = $false; `
                    ExpectedPointRevision = $ray.LastCommit.ParentRevisionA; `
                    LastCommit = $null `
                }

                $rightRay = New-Object PSObject -Property @{ `
                    Id = GenerateNewRayId; `
                    ParentId = $ray.Id; `
                    Position = $ray.Position + $CenteredDagRaySplitShift; `
                    IsHead = $false; `
                    ExpectedPointRevision = $ray.LastCommit.ParentRevisionB; `
                    LastCommit = $null `
                }

                $leftRay = PutCommitOnRayIfExpected -Ray $leftRay -Commit $NewCommit
                $rightRay = PutCommitOnRayIfExpected -Ray $rightRay -Commit $NewCommit

                $resultRays += $leftRay
                $resultRays += $rightRay

            } else {

                $extendedRay = New-Object PSObject -Property @{ `
                    Id = $ray.Id; `
                    ParentId = $ray.ParentId; `
                    Position = $ray.Position; `
                    IsHead = $false; `
                    ExpectedPointRevision = $ray.ExpectedPointRevision; `
                    LastCommit = $ray.LastCommit `
                }

                $extendedRay = PutCommitOnRayIfExpected -Ray $extendedRay -Commit $NewCommit

                $resultRays += $extendedRay

            }

        }

        $isCommitPlacedOnSomeRay = ($resultRays | where {$_.IsHead}) -ne $null
        if (-not $isCommitPlacedOnSomeRay) {

            $position = DeterminePositionForNewRay -AvailableRays $resultRays -CanvasWidth $CanvasWidth

            $newRay = New-Object PSObject -Property @{ `
                Id = GenerateNewRayId; `
                ParentId = $null; `
                Position = $position; `
                IsHead = $true; `
                ExpectedPointRevision = GetExpectedRayPointRevision $NewCommit; `
                LastCommit = $NewCommit `
            }

            $resultRays += $newRay

        }

        return $resultRays
    }

    function GetBottomRaysCorrespondingToTopRay ([PSObject] $TopRay, [PSObject] $BottomRays) {
        return $BottomRays | where {$_.Id -eq $TopRay.Id -or $_.ParentId -eq $TopRay.Id}
    }

    function DrawRays([PSObject[]] $TopRays, [PSObject[]] $BottomRays, [int] $CanvasWidth) {
        #Write-Host 'Top Rays (', $TopRays.Count, ')'
        #$TopRays | %{ '' + $_.Id + ' ' + $_.Position + ' ' + $_.LastCommit.Revision + ':' + $_.LastCommit.ParentRevisionA + ':' + $_.LastCommit.ParentRevisionB + ' ' + $_.IsHead + ' ' + $_.ExpectedPointRevision } | Write-Host
        #Write-Host 'Bottom Rays (', $BottomRays.Count, ')'
        #$BottomRays | %{ '' + $_.Id + ' ' + $_.Position + ' ' + $_.LastCommit.Revision + ':' + $_.LastCommit.ParentRevisionA + ':' + $_.LastCommit.ParentRevisionB + ' ' + $_.IsHead + ' ' + $_.ExpectedPointRevision } | Write-Host
        #Write-Host "Canvas Width: $CanvasWidth"

        $topEntries = @()
        $bottomEntries = @()

        foreach ($topRay in $TopRays) {
            foreach ($bottomRay in GetBottomRaysCorrespondingToTopRay -TopRay $topRay -BottomRays $BottomRays) {

                $topEntries += New-Object PSObject -Property @{ `
                    Id = $topRay.Id + ':' + $bottomRay.Id; `
                    Position = $topRay.Position; `
                    IsHead = $topRay.IsHead
                }

                $bottomEntries += New-Object PSObject -Property @{ `
                    Id = $topRay.Id + ':' + $bottomRay.Id; `
                    Position = $bottomRay.Position; `
                    IsHead = $bottomRay.IsHead
                }

            }
        }

        RenderPath `
            -TopEntries $topEntries `
            -BottomEntries $bottomEntries `
            -Width $CanvasWidth `
            -MinHeight 4 `
            | CharArrayToString `
            | Write-Host `
    }

    function WriteCenteredCommitsDag([PSObject[]] $Commits) {

        $canvasWidth = 29
        
        $firstCommit = $Commits[0]
        $currentRays = @(New-Object PSObject -Property @{ `
            Id = GenerateNewRayId; `
            ParentId = $null; `
            Position = [Math]::Round($canvasWidth / 2, [MidpointRounding]::AwayFromZero); `
            IsHead = $true; `
            ExpectedPointRevision = GetExpectedRayPointRevision $firstCommit; `
            LastCommit = $firstCommit `
        })

        for ([int] $commitIndex = 0; $commitIndex -lt $Commits.Count - 1; $commitIndex++) {
            $currentCommit = $Commits[$commitIndex]
            $nextCommit = $Commits[$commitIndex+1]
 
            $bottomRays = UpdateRays -Rays $currentRays -NewCommit $nextCommit -CanvasWidth $canvasWidth

            DrawRays -Top $currentRays -Bottom $bottomRays -CanvasWidth $canvasWidth

            $currentRays = $bottomRays
        }
    
    }

    # test code below (should be replaced with real output)

    $commits = GetCommits 6 # last commit is not printed out
    WriteCenteredCommitsDag $commits

}

Set-Alias hglog Write-HgLog
