function Hg-Owner([string]$filename) {
    hg log `
        --no-merges `
        --include $filename `
        --template '{author}\n' `
        | group `
        | sort Count -Descending `
        | %{$_.Name} `
        | select -First 1 `
}
