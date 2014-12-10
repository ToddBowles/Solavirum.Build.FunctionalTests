param
(
    $awsKey,
    $awsSecret,
    $awsRegion,
    $awsBucket,
    $buildIdentifier,
    $fullyQualifiedPathToTestDefinitionsDirectory,
    $pathToInstaller,
    $fullyQualifiedPathTo7zip
)

if (-not ($pathToInstaller -like '*' + $buildIdentifier + '*'))
{
    write-error "The installer did not match the build identifier."
    exit 1
}

$installerFile = new-object System.IO.FileInfo($pathToInstaller)

if (!$installerFile.Exists)
{
    write-error "The Installer (supposed to be at [$($installerFile.FullName)]) does not exist."
    exit 1
}

$testDefinitionsDirectory = new-object System.IO.DirectoryInfo($fullyQualifiedPathToTestDefinitionsDirectory)

if (!$testDefinitionsDirectory.Exists)
{
    write-error "The Test Definitions (supposed to be at [$($testDefinitionsDirectory.FullName)]) do not exist."
    exit 1
}

$7zipExecutableFile = new-object System.IO.FileInfo($fullyQualifiedPathTo7zip)

if (!$7zipExecutableFile.Exists)
{
    write-error "The 7Zip executable (supposed to be at [$($7zipExecutableFile.FullName)]) does not exist."
    exit 1
}

$zippedTestsFile = new-object System.IO.FileInfo("C:\working\" + $buildIdentifier + '\Tests.7z')
if ($zippedTestsFile.Exists)
{
    write-output "Zip file containing test definitions exists at [$($zippedTestsFile.Fullname)]. Deleting."
    $zippedTestsFile.Delete();
}

write-output "Zipping Test Definitions at [$($testDefinitionsDirectory.FullName)] into file [$($zippedTestsFile.FullName)] using 7Zip at [$($7zipExecutableFile.FullName)]."
& $fullyQualifiedPathTo7zip a "$($zippedTestsFile.FullName)" "$($testDefinitionsDirectory.FullName)\*"

$remoteInstallerFileKey = $buildIdentifier + "\" + $installerFile.Name
write-output "Uploading Gateway Installer from [$($installerFile.FullName)] to [$remoteInstallerFileKey]."
Write-S3Object -BucketName $awsBucket -Key $remoteInstallerFileKey -File $installerFile.FullName -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret

$remoteFunctionalTestsDefinitionsFileKey = $buildIdentifier + "\" + $zippedTestsFile.Name
write-output "Uploading Test Definitions Zip from [$($zippedTestsFile.FullName)] to [$remoteFunctionalTestsDefinitionsFileKey]."
Write-S3Object -BucketName $awsBucket -Key $remoteFunctionalTestsDefinitionsFileKey -File $zippedTestsFile.FullName -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret

write-output "Uploads Successful"

write-output "Deleting temporary zip file [$($zippedTestsFile.FullName)]"
$zippedTestsFile.Delete();