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

# Get-Projects | % { $_.ConfigurationManager.DeleteConfigurationRow('PreRelease') }
# Get-Projects | % { $_.Properties.Item("TargetFrameworkMoniker").Value = '.NETFramework,Version=v4.5'; $_.Properties.Item("TargetFramework").Value = 262149; }
# Get-Package | % { $p = $_; Get-Project -All | % { Get-Package -ProjectName $_.ProjectName } | ? { $_.Id -eq $p.Id -and $_.Version -eq $p.Version } | Measure-Object | select @{Name='Id';Expression={$p.Id}}, @{Name='Version';Expression={$p.Version}}, @{Name='Count';Expression={$_.Count}} }


# Get-Projects | % { $_.Properties.Item("TargetFramework").Value = 262149 }
