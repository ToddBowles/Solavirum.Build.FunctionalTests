param
(
    $awsKey,
    $awsSecret,
    $awsRegion
)

$newEC2InstanceParams = @{
    ImageId = "[AMI ID]"
    MinCount = "1"
    MaxCount = "1"
    KeyName = "[KEY PAIR]"
    SecurityGroupId = "[SECURITY GROUP]"
    InstanceType = "[INSTANCE TYPE]"
    SubnetId = "[SUBNET ID]"
    AccessKey = $awsKey
    SecretKey = $awsSecret
    Region = $awsRegion
}

$paramsForLogging = $newEC2InstanceParams.GetEnumerator() | 
    Sort-Object Name | 
    Where-Object { ($_.Key -ne "AccessKey") -and ($_.Key -ne "SecretKey") } | 
    ForEach-Object {"[{0}:{1}]" -f $_.Name,$_.Value}

write-host "Requesting new Amazon EC2 Instance for execution of Functional Tests [$paramsForLogging]."
$instanceRequest = New-EC2Instance @newEC2InstanceParams
$instance = $instanceRequest.Instances[0]

return $instance
