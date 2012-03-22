function Remove-MissingHgFiles {

    hg remove `
        --after `
        --include * `

}

Set-Alias hgremovemissing Remove-MissingHgFiles
