param (
    [Parameter(Mandatory=$true,Position=0)]
    [Alias("CN")]
    [string]$ComputerNameOrIp,
    [Parameter(Mandatory=$true,Position=1)]
    [Alias("U")] 
    [string]$User,
    [Parameter(Mandatory=$true,Position=2)]
    [Alias("P")] 
    [string]$Password
)

& "$($env:SystemRoot)\system32\cmdkey.exe" /generic:$ComputerNameOrIp /user:$User /pass:$Password | write-host

$ProcessInfo = new-object System.Diagnostics.ProcessStartInfo

$ProcessInfo.FileName = "$($env:SystemRoot)\system32\mstsc.exe" 
$ProcessInfo.Arguments = "/v $ComputerNameOrIp"

$Process = new-object System.Diagnostics.Process
$Process.StartInfo = $ProcessInfo
$startResult = $Process.Start()

Start-Sleep -s 15

& "$($env:SystemRoot)\system32\cmdkey.exe" /delete:$ComputerNameOrIp | write-host

return $Process.Id
