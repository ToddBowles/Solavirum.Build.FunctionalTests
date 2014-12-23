param
(
    $awsKey,
    $awsSecret,
    $awsRegion,
    $awsBucket,
    $buildIdentifier,
    $remoteUser,
    $remotePassword,
    [string]$installerS3Key,
    [string]$testDefinitionsS3Key
)

$workingDirectoryPath = "C:\remote\working\"
$workingDirectory = new-object System.IO.DirectoryInfo($workingDirectoryPath)

if (!$workingDirectory.Exists)
{
    "Creating working directory at [$($workingDirectory.FullName)]."
    $workingDirectory.Create();
}

$zippedTestDefinitionsFilePath = [System.IO.Path]::Combine($workingDirectory, [System.IO.Path]::GetFileName($testDefinitionsS3Key))
$zippedTestDefinitionsFile = DownloadFileFromS3 $awsKey $awsSecret $awsRegion $awsBucket $testDefinitionsS3Key $zippedTestDefinitionsFilePath

$installerFilePath = [System.IO.Path]::Combine($workingDirectory, [System.IO.Path]::GetFileName($installerS3Key))
$installerFile = DownloadFileFromS3 $awsKey $awsSecret $awsRegion $awsBucket $installerS3Key $installerFilePath

if (!$zippedTestDefinitionsFile.Exists)
{
    throw "The Zip file was supposed to be located at [$($zippedTestDefinitionsFile.FullName)] but could not be found."
}

# The functional tests are dependent on this particular location on disk. Have to extract them there.
$functionalTestDefinitionsDirectoryPath = 'C:\Tests'

$7zip = 'C:\tools\7za920\7za.exe'

UnzipFile $7zip ($zippedTestDefinitionsFile.FullName) $functionalTestDefinitionsDirectoryPath

if (!$installerFile.Exists)
{
    throw "The Installer was supposed to be located at [$($installerFile.FullName)] but could not be found."
}

write-host "Installing Application (silently) from the installer [$($installerFile.FullName)]"
# Piping the results of the installer to the output stream forces it to wait until its done before continuing on
# with the remainder of the script. No useful output comes out of it anyway, all we really care about
# is the return code.
& "$($installerFile.FullName)" /exenoui /qn /norestart | write-host
if ($LASTEXITCODE -ne 0)
{
    throw "Failed to Install Application."
}

$testExecute = 'C:\Program Files (x86)\SmartBear\TestExecute 10\Bin\TestExecute.exe'
$testExecuteProjectFolderPath = "$functionalTestDefinitionsDirectoryPath\Application"
$testExecuteProject = "$testExecuteProjectFolderPath\ApplicationTests.pjs"
$testExecuteResultsFilePath = "$functionalTestDefinitionsDirectoryPath\TestResults.mht"

write-host "Running tests at [$testExecuteProject] using TestExecute at [$testExecute]. Results going to [$testExecuteResultsFilePath]."
# Psexec does a really annoying thing where it writes information to STDERR, which Powershell detects as an error
# and then throws an exception. The 2>&1 redirects all STDERR to STDOUT to get around this.
# Bit of a dirty hack here. The -i 2 parameter executes the application in interactive mode specifying
# a pre-existing session with ID 2. This is the session that was setup by creating a remote desktop
# session before this script was executed. Sorry.
& "C:\Tools\sysinternals\psexec.exe" -accepteula -i 2 -h -u $remoteUser -p $remotePassword "$testExecute" "$testExecuteProject" /run /SilentMode /exit /DoNotShowLog /ExportLog:$testExecuteResultsFilePath 2>&1 | write-host
[int]$testExecuteExitCode = $LASTEXITCODE

$zippedTestResultsFile = ZipFile $7zip $testExecuteResultsFilePath
$zippedTestDefinitionsAndExecutionLogFile = ZipDirectory $7zip $testExecuteProjectFolderPath "TestDefinitionsAndExecutionLog"

$testResultsS3Key = UploadFileToS3 $awsKey $awsSecret $awsRegion $awsBucket $zippedTestResultsFile "$buildIdentifier\$($zippedTestResultsFile.Name)"
$testDefinitionsAndExecutionLogS3Key = UploadFileToS3 $awsKey $awsSecret $awsRegion $awsBucket $zippedTestDefinitionsAndExecutionLogFile "$buildIdentifier\$($zippedTestDefinitionsAndExecutionLogFile.Name)"

$testResult = new-object psobject -Property @{ 
    Code = $testExecuteExitCode
    TestResultsS3Key = $testResultsS3Key 
    TestDefinitionsAndExecutionLogS3Key = $testDefinitionsAndExecutionLogS3Key 
}

return $testResult
