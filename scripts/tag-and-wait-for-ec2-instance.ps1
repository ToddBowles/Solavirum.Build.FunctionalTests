param
(
    $awsKey,
    $awsSecret,
    $awsRegion,
    $instanceid,
    $buildIdentifier
)

function WaitForEC2InstanceToReachState
{
    param
    (
        $awsKey,
        $awsSecret,
        $awsRegion,
        $instanceid,
        $desiredstate
    )

    write-host "Waiting for the EC2 Instance with Id [$($instanceid)] to reach [$desiredstate] state."
    $increment = 5
    $totalWaitTime = 0
    $timeout = 360
    while ($true)
    {
        $a = Get-EC2Instance -Filter @{Name = "instance-id"; Values = $instanceid} -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret
        $state = $a.Instances[0].State.Name

        if ($state -eq $desiredstate)
        {
            write-host "The EC2 Instance with Id [$($instanceid)] took [$totalWaitTime] seconds to reach the [$desiredstate] state."
            break
        }

        write-host "$(Get-Date) Current State is [$state], Waiting for [$desiredstate]."

        Sleep -Seconds $increment
        $totalWaitTime = $totalWaitTime + $increment
        if ($totalWaitTime -gt $timeout)
        {
            throw "The EC2 Instance with Id [$($instanceid)] did not reach the [$desiredstate] state in [$timeout] seconds."
        }
    }
}

import-module "C:\Program Files (x86)\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1"

function All 
{
    [CmdletBinding()]
    param
    (
        $EvaluateCondition,
        [Parameter(ValueFromPipeline = $true)] $toTest
    )
    begin 
    {
        $all = $true
    }
    process 
    {
        $all = ($all -and (& $EvaluateCondition $toTest))
    }
    end 
    {
        return $all
    }
}

function WaitForEC2InstanceToBeReady
{
    param
    (
        $awsKey,
        $awsSecret,
        $awsRegion,
        $instanceid
    )

    write-host "Waiting for the EC2 Instance with Id [$($instanceid)] to be ready."
    $increment = 5
    $totalWaitTime = 0
    $timeout = 600

    $ec2Config = new-object Amazon.EC2.AmazonEC2Config
    $ec2Config.RegionEndpoint = [Amazon.RegionEndpoint]::GetBySystemName($awsRegion)
    $client = [Amazon.AWSClientFactory]::CreateAmazonEC2Client($awsKey, $awsSecret,$ec2Config)

    while ($true)
    {
        $describeRequest = New-Object Amazon.EC2.Model.DescribeInstanceStatusRequest
        $describeRequest.InstanceIds.Add($instanceid)
        $describeResponse = $client.DescribeInstanceStatus($describeRequest)

        # Ready means that all of the instance status checks come back as "passed". Thats pretty much
        # the instance reachability check, but I check all just in case.
        $instanceStatus = $describeResponse.DescribeInstanceStatusResult.InstanceStatuses[0]
        if ($instanceStatus.Status.Details | All { $_.Status -eq "passed" })
        {
            write-host "The EC2 Instance with Id [$($instanceid)] took [$totalWaitTime] seconds to be ready."
            break
        }

        write-host "$(Get-Date) Waiting for the EC2 Instance with Id [$($instanceid)] to be ready."

        Sleep -Seconds $increment
        $totalWaitTime = $totalWaitTime + $increment
        if ($totalWaitTime -gt $timeout)
        {
            throw "The EC2 Instance with Id [$($instanceid)] was not ready in [$timeout] seconds."
        }
    }
}

$tags = @()
$nameTag = new-object Amazon.EC2.Model.Tag
$nameTag.Key = "Name"
$nameTag.Value = "[SCRIPT] $buildIdentifier Functional Tests"
$tags += $nameTag
$expireTag = new-object Amazon.EC2.Model.Tag
$expireTag.Key = "expire"
$expireTag.Value = "true"
$tags += $expireTag

write-host "Tagging Instance."
New-EC2Tag -Resource $instanceid -Tag $tags -AccessKey $awsKey -SecretKey $awsSecret -Region $awsRegion

$running = WaitForEC2InstanceToReachState $awskey $awsSecret $awsRegion $instanceid "running"
$ready = WaitForEC2InstanceToBeReady $awskey $awsSecret $awsRegion $instanceid
