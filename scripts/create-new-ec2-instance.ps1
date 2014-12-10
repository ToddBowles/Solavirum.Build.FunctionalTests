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
    KeyName = "[KEY PAIR NAME]"
    SecurityGroupId = "[SECURITY GROUP ID]"
    InstanceType = "c3.xlarge"
    SubnetId = "[SUBNET ID]"
    AccessKey = $awsKey
    SecretKey = $awsSecret
    Region = $awsRegion
}

$paramsForLogging = $newEC2InstanceParams.GetEnumerator() | Sort-Object Name | ForEach-Object {"[{0}:{1}]" -f $_.Name,$_.Value}

write-host "Requesting new Amazon EC2 Instance for execution of Functional Tests [$paramsForLogging]."
$instanceRequest = New-EC2Instance @newEC2InstanceParams
$instance = $instanceRequest.Instances[0]

return $instance