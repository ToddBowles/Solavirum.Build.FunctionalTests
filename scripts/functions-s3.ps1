function UploadFileToS3
{
    param
    (
        [string]$awsKey,
        [string]$awsSecret,
        [string]$awsRegion,
        [string]$awsBucket,
        [System.IO.FileInfo]$file,
        [string]$S3FileKey
    )

    write-host "Uploading [$($file.FullName)] to [$($awsRegion):$($awsBucket):$S3FileKey]."
    Write-S3Object -BucketName $awsBucket -Key $S3FileKey -File "$($file.FullName)" -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret

    return $S3FileKey
}

function DownloadFileFromS3
{
    param
    (
        [string]$awsKey,
        [string]$awsSecret,
        [string]$awsRegion,
        [string]$awsBucket,
        [string]$S3FileKey,
        [string]$destinationPath
    )

    $destinationFile = new-object System.IO.FileInfo($destinationPath)
    if ($destinationFile.Exists)
    {
        write-host "Destination for S3 download of [$S3FileKey] ([$($destinationFile.FullName)]) already exists. Deleting."
        $destinationFile.Delete()
    }

    write-host "Downloading [$($awsRegion):$($awsBucket):$S3FileKey] to [$($destinationFile.FullName)]."
    Read-S3Object -BucketName $awsBucket -Key $S3FileKey -File "$($destinationFile.FullName)" -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret | write-host

    $destinationFile.Refresh()

    return $destinationFile
}