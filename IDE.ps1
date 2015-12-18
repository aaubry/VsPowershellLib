#Add-Type -Path "Helpers.dll"

function Get-TypeAtCursor {
  $elementTypes = [EnvDTE.vsCMElement]::vsCMElementClass, [EnvDTE.vsCMElement]::vsCMElementStruct, [EnvDTE.vsCMElement]::vsCMElementInterface, [EnvDTE.vsCMElement]::vsCMElementEnum
  $elementTypes | ForEach-Object { $DTE.ActiveDocument.Selection.ActivePoint.CodeElement($_) } | Select-Object -First 1
}

function Get-Functions {
  param(
    [parameter(Mandatory = $true)]
    $Type
  )

  $Type.Members | Where { $_.Kind -eq [EnvDTE.vsCMElement]::vsCMElementFunction }
}

function Get-Constructors {
  param(
    [parameter(Mandatory = $true)]
    $Type
  )
  Get-Functions $Type | Where { $_.FunctionKind -eq [EnvDTE.vsCMFunction]::vsCMFunctionConstructor }
}

function Format-Document {
	$DTE.ActiveDocument.Activate()
	$x = $DTE.ExecuteCommand("Edit.FormatDocument")
}

function Get-SolutionConfigurations()
{
  $DTE.Solution.SolutionBuild.SolutionConfigurations | ForEach-Object {
    echo $_.Name
    $_.SolutionContexts | Format-Table -Property ProjectName,ConfigurationName,PlatformName,ShouldBuild,ShouldDeploy
  }
}

function Get-Projects()
{
  param(
    $Container = $DTE.Solution.Projects,
    [switch] $IncludeSolutionFolders
  )

  $Container | Foreach-Object {

    $project = $_
    if($project.Type -eq $null -and $project.SubProject -ne $null) {
      $project = $project.SubProject
    }

    if($IncludeSolutionFolders -or ($project.Type -ne "Unknown" -and $project.Type -ne $null))
    {
      echo $project
    }

    $_.ProjectItems | Where-Object { $_.SubProject -ne $null } | ForEach-Object { Get-Projects $_ }

  }
}

function Get-ProjectConfigurations()
{
  Get-Projects | % { $p = $_; $_.ConfigurationManager | Add-Member -MemberType NoteProperty -Name 'ProjectName' -Value $p.ProjectName -PassThru }
}

function Get-ProjectTargetFrameworkVersions()
{
  Get-Projects | select Name, @{Name='TargetFramework';Expression={$_.Properties.Item("TargetFramework").Value}}, @{Name='TargetFrameworkMoniker';Expression={$_.Properties.Item("TargetFrameworkMoniker").Value}}
}
