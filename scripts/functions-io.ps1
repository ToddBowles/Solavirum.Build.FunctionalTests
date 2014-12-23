function CreateFileInfoAndCheckExistence
{
    param
    (
        [string]$filePath
    )

    $file = new-object System.IO.FileInfo($filePath)

    if (!$file.Exists)
    {
        throw "File not present at [$($file.FullName)]. Supplied path was [$filePath]."
    }

    return $file
}

function CreateDirectoryInfoAndCheckExistence
{
    param
    (
        [string]$directoryPath
    )

    $directory = new-object System.IO.DirectoryInfo($directoryPath)

    if (!$directory.Exists)
    {
        throw "Directory not present at [$($file.FullName)]. Supplied path was [$directory]."
    }

    return $directory
}