param
(
    $awsKey,
    $awsSecret,
    $awsRegion,
    $awsBucket,
    $buildIdentifier
)

write-host "Removing all objects in S3 that match [Region: $awsRegion, Location: $awsBucket\$buildIdentifier]."
Get-S3Object -BucketName $awsBucket -KeyPrefix $buildIdentifier -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret | ForEach-Object {
    $result = Remove-S3Object -BucketName $awsBucket -Key $_.Key -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret -Force
}