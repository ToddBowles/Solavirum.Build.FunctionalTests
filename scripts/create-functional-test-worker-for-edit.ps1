param
(
    $suppliedAWSKey,
    $suppliedAWSSecret,
    $suppliedAWSRegion
)

try
{
    $ErrorActionPreference = "Stop"

    $scriptsDirectoryPath = Split-Path $script:MyInvocation.MyCommand.Path
    write-host "Script Root Directory is [$scriptsDirectoryPath]."

    . $scriptsDirectoryPath\functions-strings.ps1
    . $scriptsDirectoryPath\variables-aws-parameter-defaults.ps1

    Import-Module "$scriptsDirectoryPath\AWSPowershell\AWSPowerShell.psd1"

    $awsKey = StringNullOrEmptyCoalesce $suppliedAWSKey $defaultAWSKey
    $awsSecret = StringNullOrEmptyCoalesce $suppliedAWSSecret $defaultAWSSecret
    $awsRegion = StringNullOrEmptyCoalesce $suppliedAWSRegion $defaultAWSRegion

    $createInstanceResult = & "$scriptsDirectoryPath\create-new-functional-test-ec2-instance.ps1" $awsKey $awsSecret $awsRegion
    $instanceId = $createInstanceResult.InstanceId

    & "$scriptsDirectoryPath\tag-and-wait-for-ec2-instance.ps1" $awsKey $awsSecret $awsRegion $instanceId "[AMI Creation Purposes]"
    $ipaddress = (Get-EC2Instance -Filter @{Name = "instance-id"; Values = $instanceId} -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret).Instances[0].PrivateIpAddress

    . $scriptsDirectoryPath\variables-functional-tests-worker-user.ps1
    $remoteUser = $functionalTestsWorkerRemoteUser
    $remotePassword = $functionalTestsWorkerRemoteUserPassword

    write-host "Starting remote desktop session to [$ipaddress]."
    $remoteProcess = & "$scriptsDirectoryPath\start-remote-session.ps1" $ipaddress $remoteUser $remotePassword

    write-host "Press Any Key to Finish. The Instance you just created will be Terminated."
    $userString = Read-Host
}
finally
{
    & "$scriptsDirectoryPath\ec2-terminate-instance.ps1" $awsKey $awsSecret $awsRegion $instanceId
}
