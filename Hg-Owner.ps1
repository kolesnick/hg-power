function Hg-Owner([Parameter(ValueFromPipeline=$true)][string[]]$filename) {

    Process {
        hg log `
            --no-merges `
            --include $filename `
            --template '{author}\n' `
            | group `
            | sort Count -Descending `
            | %{$_.Name} `
            | select -First 1 `
    }

}
