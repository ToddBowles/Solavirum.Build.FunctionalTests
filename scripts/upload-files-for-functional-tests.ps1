param
(
    [string]$awsKey,
    [string]$awsSecret,
    [string]$awsRegion,
    [string]$awsBucket,
    [string]$buildIdentifier,
    [string]$fullyQualifiedPathToTestDefinitionsDirectory,
    [string]$fullyQualifiedPathToInstaller,
    [string]$fullyQualifiedPathTo7Zip
)

try
{
    $scriptDirectoryPath = Split-Path $script:MyInvocation.MyCommand.Path

    . "$scriptDirectoryPath\functions-io.ps1"
    . "$scriptDirectoryPath\functions-s3.ps1"
    . "$scriptDirectoryPath\functions-compression.ps1"

    $installerFile = CreateFileInfoAndCheckExistence $fullyQualifiedPathToInstaller
    $testDefinitionsDirectory = CreateDirectoryInfoAndCheckExistence $fullyQualifiedPathToTestDefinitionsDirectory
    $7ZipExecutableFile = CreateFileInfoAndCheckExistence $fullyQualifiedPathTo7Zip

    $zippedTestsFile = ZipDirectory $fullyQualifiedPathTo7Zip $($testDefinitionsDirectory.FullName) "TestDefinitions"

    $installerS3Key = UploadFileToS3 $awsKey $awsSecret $awsRegion $awsBucket $installerFile "$buildIdentifier\$($installerFile.Name)"
    $testDefinitionsS3Key = UploadFileToS3 $awsKey $awsSecret $awsRegion $awsBucket $zippedTestsFile "$buildIdentifier\$($zippedTestsFile.Name)"

    write-host "Uploads Successful"

    $uploadResult = new-object psobject -Property @{ 
        InstallerS3Key = $installerS3Key 
        TestDefinitionsS3Key = $testDefinitionsS3Key
    }

    return $uploadResult
}

finally
{
    if ($zippedTestsFile -ne $null -and $zippedTestsFile.Exists)
    {
        write-host "Deleting temporary zip file [$($zippedTestsFile.FullName)]"
        $zippedTestsFile.Delete();
    }
}