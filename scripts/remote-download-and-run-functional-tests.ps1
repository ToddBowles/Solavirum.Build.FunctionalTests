param
(
    $awsKey,
    $awsSecret,
    $awsRegion,
    $awsBucket,
    $buildIdentifier
)

$workingDirectoryPath = "C:\working\"
$workingDirectory = new-object System.IO.DirectoryInfo($workingDirectoryPath)

if (!$workingDirectory.Exists)
{
    "Creating working directory at [$($workingDirectory.FullName)]."
    $workingDirectory.Create();
}

$zippedTestDefinitionsPath = ""
$installerPath = ""
write-host "Downloading files from [$awsRegion.$awsBucket\$buildIdentifier]"
Get-S3Object -BucketName $awsBucket -KeyPrefix $buildIdentifier -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret | ForEach-Object {
    if ($_.Size -ne 0)
    {
        $destinationPath = $workingDirectory.FullName + '\' + $_.Key
		# Piping to write-host prevents the pollution of the output stream by this cmdlet
        Read-S3Object -BucketName $awsBucket -Key $_.Key -File $destinationPath -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret | write-host
        if ($_.Key.EndsWith('7z'))
        {
            $zippedTestDefinitionsPath = $destinationPath
        }

        if ($_.Key.EndsWith('exe'))
        {
            $installerPath = $destinationPath
        }
    }
}

$zippedTestDefinitionsFile = new-object System.IO.FileInfo($zippedTestDefinitionsPath)
if (!$zippedTestDefinitionsFile.Exists)
{
    throw "The Zip file was supposed to be located at [$($zippedTestDefinitionsFile.FullName)] but could not be found."
}

$7zip = 'C:\tools\7za920\7za.exe'

$functionalTestDefinitionsDirectoryPath = 'C:\$buildIdentifier\TestDefinitions'

write-host "Unzipping [$($zippedTestDefinitionsFile.FullName)] to [$functionalTestDefinitionsDirectoryPath] using 7Zip at [$7zip]."
& $7zip x "$($zippedTestDefinitionsFile.FullName)" -o"$functionalTestDefinitionsDirectoryPath"

$installerFile = new-object System.IO.FileInfo($installerPath)
if (!$installerFile.Exists)
{
    throw "The Installer was supposed to be located at [$($installerPath.FullName)] but could not be found."
}

write-host "Installing Application (silently) from the installer [$($installerFile.FullName)]"
# The piping to write-host is necessary to wait for the installer to finish.
& "$($installerFile.FullName)" /exenoui /qn /norestart | write-host

$testExecute = 'C:\Program Files (x86)\SmartBear\TestExecute 10\Bin\TestExecute.exe'
$testExecuteProject = "$functionalTestDefinitionsDirectoryPath\[APPLICATION]\[APPLICATION].pjs"

write-host "Running tests at [$testExecuteProject] using TestExecute at [$testExecute]."
& "$testExecute" "$testExecuteProject" /run /SilentMode /exit /DoNotShowLog | write-host

$testResult = new-object psobject -Property @{ Code = $LASTEXITCODE }
