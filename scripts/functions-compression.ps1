function ZipFile
{
    param
    (
        [string]$fullyQualifiedPathTo7zip,
        [string]$filePath
    )

    $file = new-object System.IO.FileInfo($filePath)
    if (!$file.Exists)
    {
        throw "File to be zipped [$($file.FullName)] does not exist."
    }

    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)

    $zippedFilePath = [System.IO.Path]::Combine($file.Directory, $fileName + ".7z")

    $zippedFile = new-object System.IO.FileInfo($zippedFilePath)
    if ($zippedFile.Exists)
    {
        write-host "Zip File already exists at [$($zippedFile.FullName)]. Deleting."
        $zippedFile.Delete()
    }

    write-host "Zipping File [$($file.FullName)] into file [$($zippedFile.FullName)] using 7Zip at [$fullyQualifiedPathTo7zip]."
    # Redirecting output from 7Zip to null because its kind of spammy.
    & "$fullyQualifiedPathTo7zip" a "$($zippedFile.FullName)" "$($file.FullName)" | out-null

    $7ZipExitCode = $LASTEXITCODE
    if ($7ZipExitCode -ne 0)
    {
        throw "An error occurred while zipping [$filePath]. 7Zip Exit Code was [$7ZipExitCode]."
    }

    return $zippedFile
}

function ZipDirectory
{
    param
    (
        [string]$fullyQualifiedPathTo7zip,
        [string]$directoryPath,
        [string]$zippedFileName
    )

    $directory = new-object System.IO.DirectoryInfo($directoryPath)
    if (!$directory.Exists)
    {
        throw "Directory to be zipped [$($directory.FullName)] does not exist."
    }

    $zippedDirectoryPath = [System.IO.Path]::Combine($directory.Parent.FullName, $zippedFileName + ".7z")

    $zippedDirectoryFile = new-object System.IO.FileInfo($zippedDirectoryPath)
    if ($zippedDirectoryFile.Exists)
    {
        write-host "Zip File already exists at [$($zippedDirectoryFile.FullName)]. Deleting."
        $zippedDirectoryFile.Delete()
    }

    write-host "Zipping Directory [$($directory.FullName)] into file [$($zippedDirectoryFile.FullName)] using 7Zip at [$fullyQualifiedPathTo7zip]."
    # Redirecting output from 7Zip to null because its kind of spammy.
    & "$fullyQualifiedPathTo7zip" a "$($zippedDirectoryFile.FullName)" "$($directory.FullName)\*" | out-null

    $7ZipExitCode = $LASTEXITCODE
    if ($7ZipExitCode -ne 0)
    {
        throw "An error occurred while zipping [$directoryPath]. 7Zip Exit Code was [$7ZipExitCode]."
    }

    return $zippedDirectoryFile
}

function UnzipFile
{
    param
    (
        [string]$fullyQualifiedPathTo7zip,
        [string]$fullyQualifiedPathToZipFile,
        [string]$destinationDirectoryPath
    )

    write-host "Unzipping [$fullyQualifiedPathToZipFile] to [$destinationDirectoryPath] using 7Zip at [$fullyQualifiedPathTo7zip]."
    & $fullyQualifiedPathTo7zip x "$fullyQualifiedPathToZipFile" -o"$destinationDirectoryPath" -aoa | out-null

    $7ZipExitCode = $LASTEXITCODE
    if ($7ZipExitCode -ne 0)
    {
        throw "An error occurred while unzipping [$fullyQualifiedPathToZipFile] to [$destinationDirectoryPath]. 7Zip Exit Code was [$7ZipExitCode]."
    }
}