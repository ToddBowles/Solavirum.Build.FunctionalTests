param
(
    $suppliedAWSKey,
    $suppliedAWSSecret,
    $suppliedAWSRegion,
    $suppliedAWSBucket,
    $buildIdentifier="0.0.0.0",
    $fullyQualifiedPathToInstaller
)

function SearchUpForMatchingDirectoryName
{
	param
	(
        [string]$fullyQualifiedPathToSearchStartDirectory,
		[string]$directoryNameToFind
	)
	
	$possibleDirectoryPath = [System.IO.Path]::Combine($fullyQualifiedPathToSearchStartDirectory, $directoryNameToFind)
    $possibleDirectory = new-object System.IO.DirectoryInfo($possibleDirectoryPath)
    if ($possibleDirectory.Exists)
    {
        return $possibleDirectory.FullName
    }

    $searchDirectory = new-object System.IO.DirectoryInfo($fullyQualifiedPathToSearchStartDirectory)
    $parentDirectoryOfSearchDirectory = $searchDirectory.Parent

    if ($parentDirectoryOfSearchDirectory -eq $null)
    {
        throw "Directory with name [$directoryNameToFind] was not found."
    }

    $recursiveSearchResult = SearchUpForMatchingDirectoryName $parentDirectoryOfSearchDirectory.FullName $directoryNameToFind
    return $recursiveSearchResult
}

try
{
	$error.Clear()

    $ErrorActionPreference = "Stop"

    $teamCityFunctionalTestsId = "Functional Tests"
    write-host "##teamcity[testStarted name='$teamCityFunctionalTestsId']"

    $overallTimer = new-object System.Diagnostics.Stopwatch
    $overallTimer.Start()

    $scriptsDirectoryPath = Split-Path $script:MyInvocation.MyCommand.Path
    write-host "Script Root Directory is [$scriptsDirectoryPath]."

    . "$scriptsDirectoryPath\functions-strings.ps1"
    . "$scriptsDirectoryPath\variables-aws-parameter-defaults.ps1"

    $awsKey = StringNullOrEmptyCoalesce $suppliedAWSKey $defaultAWSKey
    $awsSecret = StringNullOrEmptyCoalesce $suppliedAWSSecret $defaultAWSSecret
    $awsRegion = StringNullOrEmptyCoalesce $suppliedAWSRegion $defaultAWSRegion
    $awsBucket = StringNullOrEmptyCoalesce $suppliedAWSBucket $defaultAWSBucket

    . "$scriptsDirectoryPath\functions-io.ps1"
    . "$scriptsDirectoryPath\functions-s3.ps1"
    . "$scriptsDirectoryPath\functions-compression.ps1"

    $toolsDirectoryPath = SearchUpForMatchingDirectoryName $scriptsDirectoryPath "tools"

    $7zipExecutableFile = CreateFileInfoAndCheckExistence "$toolsDirectoryPath\7za920\7za.exe"

    $testDefinitionsDirectory = CreateDirectoryInfoAndCheckExistence (SearchUpForMatchingDirectoryName $scriptsDirectoryPath "tests")

    # Some stuff up ahead uses the Amazon Powershell Cmdlets, so we load it here.
    if ((get-module | where-object { $_.Name -eq "AWSPowershell" }) -eq $null)
    {
        write-host "AWSPowershell Module not found. Importing"
		if (-not(Test-Path "$toolsDirectoryPath\AWSPowershell"))
        {
            UnzipFile $7zipExecutableFile.FullName ([System.IO.Path]::Combine($toolsDirectoryPath, "AWSPowershell.7z")) $toolsDirectoryPath
        }
        
	    Import-Module "$toolsDirectoryPath\AWSPowershell\AWSPowerShell.psd1"
    }

    $uploadResults = & "$scriptsDirectoryPath\upload-files-for-functional-tests.ps1" $awsKey $awsSecret $awsRegion $awsBucket $buildIdentifier "$($testDefinitionsDirectory.FullName)" "$fullyQualifiedPathToInstaller" "$($7zipExecutableFile.FullName)"

    $createInstanceResult = & "$scriptsDirectoryPath\create-new-functional-test-ec2-instance.ps1" $awsKey $awsSecret $awsRegion
    $instanceid = $createInstanceResult.InstanceId

    & "$scriptsDirectoryPath\tag-and-wait-for-ec2-instance.ps1" $awsKey $awsSecret $awsRegion $instanceid $buildIdentifier
    $ipaddress = (Get-EC2Instance -Filter @{Name = "instance-id"; Values = $instanceid} -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret).Instances[0].PrivateIpAddress

    $remoteUser = "remote"
    $remotePassword = "H2HE4bUttlGDP7kc5acJ"
    $securePassword = ConvertTo-SecureString $remotePassword -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($remoteUser, $securePassword)

    $winrmService = get-service WinRM
    if ($winrmService.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running)
    {
        throw "WinRM Service not running."
        # The following two commands need to be run as Administrator. I haven't done that yet.
        #$winrmService.Start()
        #& winrm s winrm/config/client '@{ TrustedHosts="*" }' # This adds all computers to your TrustedHosts, meaning you can remote to all of them.
    }

    $session = New-PSSession -ComputerName $ipaddress -Credential $cred

    write-host "Starting remote desktop session to [$ipaddress] in order to workaround TestExecute needing a valid desktop."
    $remoteProcess = & "$scriptsDirectoryPath\start-remote-session.ps1" $ipaddress $remoteUser $remotePassword

    write-host "Beginning remote execution on [$ipaddress]."
    # Invoking a command using a file with just functions/variables just includes those functions and variables into the session, so they
    # can be used by the next script that actually does things.
    Invoke-Command -Session $session -FilePath "$scriptsDirectoryPath\functions-io.ps1"
    Invoke-Command -Session $session -FilePath "$scriptsDirectoryPath\functions-s3.ps1"
    Invoke-Command -Session $session -FilePath "$scriptsDirectoryPath\functions-compression.ps1"
    $testResult = Invoke-Command -Session $session -FilePath "$scriptsDirectoryPath\remote-download-files-and-run-functional-tests.ps1" -ArgumentList $awsKey, $awsSecret, $awsRegion, $awsBucket, $buildIdentifier, $remoteUser, $remotePassword, $uploadResults.InstallerS3Key, $uploadResults.TestDefinitionsS3Key
    
    if ((get-process -Id $remoteProcess -ErrorAction SilentlyContinue) -ne $null)
    {
        write-host "Attempting to terminate remote desktop session [PID $remoteProcess]."
        Stop-Process $remoteProcess -Force -ErrorAction SilentlyContinue
    }

    $testResultsDirectory = [System.IO.Path]::Combine($scriptsDirectoryPath, "TestResults")

    $testResultsFilePath = [System.IO.Path]::Combine($testResultsDirectory, [System.IO.Path]::GetFileName($testResult.TestResultsS3Key))
    $testResultsFile = DownloadFileFromS3 $awsKey $awsSecret $awsRegion $awsBucket $testResult.TestResultsS3Key $testResultsFilePath

    UnzipFile $7zipExecutableFile.FullName $testResultsFile $testResultsDirectory

    $testResultsFile.Delete()

    $testDefinitionsAndExecutionLogFilePath = [System.IO.Path]::Combine($testResultsDirectory, [System.IO.Path]::GetFileName($testResult.TestDefinitionsAndExecutionLogS3Key))
    $testDefinitionsAndExecutionLogFile = DownloadFileFromS3 $awsKey $awsSecret $awsRegion $awsBucket $testResult.TestDefinitionsAndExecutionLogS3Key $testDefinitionsAndExecutionLogFilePath

    write-host "##teamcity[publishArtifacts '$testResultsDirectory']"

    if ($testResult -eq $null)
    {
        throw "No result returned from remote execution."
    }

    if ($testResult.Code -ne 0)
    {
        write-host "##teamcity[testFailed name='$teamCityFunctionalTestsId' message='TestExecute returned error code $($testResult.Code).' details='See artifacts for TestExecute result files']"
    }
    else
    {
        write-host "##teamcity[testFinished name='$teamCityFunctionalTestsId'"
    }
}
catch
{
	write-host "##teamcity[testFailed name='$teamCityFunctionalTestsId' message='Unhandled error during test execution.' details='Check build log for error details.']"
	throw $Error
}
finally
{
    write-host "Time to clean."

    & "$scriptsDirectoryPath\clean-build-in-bucket.ps1" $awsKey $awsSecret $awsRegion $awsBucket $buildIdentifier
    & "$scriptsDirectoryPath\ec2-terminate-instance.ps1" $awsKey $awsSecret $awsRegion $instanceId

    $overallTimer.Stop()
    write-host "Executing functional tests script (including setup) took [$($overallTimer.Elapsed.TotalSeconds)] seconds."
}