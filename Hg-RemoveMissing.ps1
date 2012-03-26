function Remove-MissingHgFiles {

    hg status `
        2> $null `
        | where {$_.StartsWith('! ')} `
        | %{$_.Remove(0, 2)} `
        | %{

            hg remove `
                --after `
                $_ `

            write $_

        }

}

Set-Alias hgremovemissing Remove-MissingHgFiles
