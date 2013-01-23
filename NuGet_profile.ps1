function AttachWs {
  $DTE.Debugger.LocalProcesses | Where { $_.Name.Contains("w3wp") } | ForEach-Object { $_.Attach() }
}

function DeleteOldPackages {
  dir packages | group {$([regex]::match($_.Name, '^(.*?)\.(\d+(\.\d+))').Groups[1].Value)} | where {$_.Count -gt 1} | foreach-object { echo $_.Group | sort-object Name -Descending | select -Skip 1 | remove-item -Recurse }
}

function UpdatePtCom {
  get-package -Filter PTCom -Updates | update-package
}

function Take-While {
  param(
    #[parameter(Mandatory = $true)]
    [scriptblock] $Predicate
  )
  
  begin {
    $Take = $true
  }
  
  process {
    if ($Take) {
      $Take = & $Predicate $_
      if ($Take) {
        $_
      }
    }
  }
}

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
  $DTE.ExecuteCommand("Edit.FormatDocument")
}

function Add-Dependency {
  param(
    [parameter(Mandatory = $true)]
    [string] $Type,
    
    [string] $Name = $null
  )

  if ([String]::IsNullOrEmpty($Name)) {
    $Name = [System.Text.RegularExpressions.Regex]::Match($Type, "^I?(\w+)").Groups[1].Value
  }
  
  $Name = $Name.TrimStart('_')
  $Name = [System.Text.RegularExpressions.Regex]::Replace($Name, "^([A-Z])", { param($m) $m.Value.ToLower() })
  $Name = [System.Text.RegularExpressions.Regex]::Replace($Name, "[^\w]", "")
  
  if ($DTE.UndoContext.IsOpen) {
    $DTE.UndoContext.Close()
  }
  $DTE.UndoContext.Open("Add dependency")
  
  $CodeElement = Get-TypeAtCursor | Select -First 1
  
  $InsertionIndex = ($CodeElement.Members | Take-While { $_.Kind -eq [EnvDTE.vsCMElement]::vsCMElementVariable } | Measure-Object).Count
  
  $Constructor = Get-Constructors($CodeElement) | Select -First 1
  if ($Constructor -eq $null) {
    $Constructor = $CodeElement.AddFunction($CodeElement.Name, [EnvDTE.vsCMFunction]::vsCMFunctionConstructor, [EnvDTE.vsCMTypeRef]::vsCMTypeRefVoid, $InsertionIndex, [EnvDTE.vsCMAccess]::vsCMAccessPublic)
  }
  
  $Field = $CodeElement.AddVariable("_" + $Name, $Type, $InsertionIndex, [EnvDTE.vsCMAccess]::vsCMAccessPrivate)
  $Pos = $Field.StartPoint.CreateEditPoint()
  $Pos.CharRight("private".Length)
  $Pos.Insert(" readonly")
  
  $Param = $Constructor.AddParameter($Name, $Type, $Constructor.Parameters.Count)
  
  $Pos = $Constructor.EndPoint.CreateEditPoint()
  $Pos.LineUp()
  $Pos.EndOfLine()
  $Pos.Insert([Environment]::NewLine)
  $Pos.Insert([String]::Format("			_{0} = {0};", $Name))
  
  #Format-Document
  
  $DTE.UndoContext.Close()
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
    $Container = $DTE.Solution.Projects
  )
  
  $Container | Foreach-Object {
    
    $project = $_
    if($project.Type -eq $null -and $project.SubProject -ne $null) {
      $project = $project.SubProject
    }
    
    if($project.Type -ne "Unknown" -and $project.Type -ne $null)
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

function Get-DuplicatePackages()
{
  Get-Package | Group-Object -Property Id | ? { $_.Count -gt 1 }
}

function Update-DuplicatePackages()
{
  Get-DuplicatePackages | % { Update-Package $_.Name }
}

# Get-Projects | % { $_.ConfigurationManager.DeleteConfigurationRow('PreRelease') }
# Get-Projects | % { $_.Properties.Item("TargetFrameworkMoniker").Value = '.NETFramework,Version=v4.5'; $_.Properties.Item("TargetFramework").Value = 262149; }
# Get-Package | % { $p = $_; Get-Project -All | % { Get-Package -ProjectName $_.ProjectName } | ? { $_.Id -eq $p.Id -and $_.Version -eq $p.Version } | Measure-Object | select @{Name='Id';Expression={$p.Id}}, @{Name='Version';Expression={$p.Version}}, @{Name='Count';Expression={$_.Count}} }
