param
(
    [string]$awsKey,
    [string]$awsSecret,
    [string]$awsRegion,
    [string]$instanceId
)

if ([String]::IsNullOrEmpty($instanceid))
{
    write-host "Could not Terminate EC2 Instance. No InstanceId supplied."
    return
}
    
write-host "Attempting to Terminate EC2 Instance [$instanceId]."
$terminateResult = Stop-EC2Instance -Instance $instanceId -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret -Terminate -Force
write-host "Terminated [$instanceId]."