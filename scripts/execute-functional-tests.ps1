param
(
    $awsKey,
    $awsSecret,
    $awsRegion,
    $awsBucket,
    $buildIdentifier,
    $pathToInstaller,
    $scriptDirectory
)

try
{
    $root = $scriptDirectory -replace '"', ""
    write-host "Script Root Directory is [$root]."

    $relativePathTo7zipExecutable = "$root\tools\7za920\7za.exe"
    $7zipExecutableFile = new-object System.IO.FileInfo($relativePathTo7zipExecutable)

    if (!$7zipExecutableFile.Exists)
    {
        throw "7Zip executable not present at [$($7zipExecutableFile.FullName)]"
    }

    $pathToFolderWithFunctionalTestDefinitions = "$root\Tests"
    $testDefinitionsDirectory = new-object System.IO.DirectoryInfo($pathToFolderWithFunctionalTestDefinitions)

    if (!$testDefinitionsDirectory.Exists)
    {
        throw "Test Definitions directory not present at [$($testDefinitionsDirectory.FullName)]"
    }

    & "$root\upload-files-for-functional-tests.ps1" $awsKey $awsSecret $awsRegion $awsBucket $buildIdentifier "$($testDefinitionsDirectory.FullName)" "$pathToInstaller" "$($7zipExecutableFile.FullName)"

    $createInstanceResult = & "$root\create-new-functional-test-ec2-instance.ps1" $awsKey $awsSecret $awsRegion
    $instanceid = $createInstanceResult.InstanceId

    & "$root\tag-and-wait-for-ec2-instance.ps1" $awsKey $awsSecret $awsRegion $instanceid $buildIdentifier
    $ipaddress = (Get-EC2Instance -Filter @{Name = "instance-id"; Values = $instanceid} -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret).Instances[0].PrivateIpAddress

    $pw = ConvertTo-SecureString '[REMOTE USER PASSWORD' -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential('[REMOTE USERNAME]', $pw)
    $session = New-PSSession -ComputerName $ipaddress -Credential $cred 

    write-host "Beginning remote execution on [$ipaddress]."

    $teamCityFunctionalTestsId = "Functional Tests"
    write-host "##teamcity[testStarted name='$teamCityFunctionalTestsId']"
    $testResult = Invoke-Command -Session $session -FilePath "$root\remote-download-files-and-run-functional-tests.ps1" -ArgumentList $awsKey, $awsSecret, $awsRegion, $awsBucket, $buildIdentifier

    # Download test results from S3.
    # Attach to TeamCity artifacts

    if ($testResult.Code -ne 0)
    {
        write-host "##teamcity[testFailed name='$teamCityFunctionalTestsId' message='TestExecute returned error code [$($testResult.Code)].' details='See artifacts for TestExecute result files.']"
    }
    else
    {
        write-host "##teamcity[testFinished name='$teamCityFunctionalTestsId'"
    }
}
catch
{
    throw $Error
    exit 1
}
finally
{
    write-host "Time to clean."
    & "$root\clean-build-in-bucket.ps1" $awsKey $awsSecret $awsRegion $awsBucket $buildIdentifier

    if ($instanceid -ne $null)
    {
        write-host "Attempting to Terminate instance [$instanceid]."
        $terminateResult = Stop-EC2Instance -Instance $instanceid -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret -Terminate -Force
        write-host "Terminated"
    }
}
