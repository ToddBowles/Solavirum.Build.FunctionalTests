function Get-ScriptDirectory
{
    Split-Path $script:MyInvocation.MyCommand.Path
}