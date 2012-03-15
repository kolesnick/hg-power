function Hg-Owner([string]$filename) {
    hg log `
        --include $filename `
        --template '{author}\n' `
        | group `
        | sort Count -Descending `
        | %{$_.Name} `
        | select -First 1 `
}
