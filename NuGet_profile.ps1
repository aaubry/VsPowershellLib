function Get-ScriptDirectory {
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

$scriptDir = Get-ScriptDirectory

. "$scriptDir\Utilities.ps1"
. "$scriptDir\NuGet.ps1"
. "$scriptDir\IDE.ps1"
. "$scriptDir\Debugger.ps1"
. "$scriptDir\CodeGeneration.ps1"
