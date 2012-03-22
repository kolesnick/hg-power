function Remove-MissingHgFiles {

    hg remove `
        --after `

}

Set-Alias hgremovemissing Remove-MissingHgFiles
