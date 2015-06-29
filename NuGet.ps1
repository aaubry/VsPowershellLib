function Delete-OldPackages(
  [switch]$WhatIf,
  [switch]$Confirm = $true
) {
  if($WhatIf) {
    Get-OldPackages | % { "Deleting $($_.Id) $($_.Version)" }
  } else {
    Get-OldPackages | % { $_.File } | Remove-Item -Confirm:$Confirm -Recurse
  }
}

function Get-OldPackages() {
  Get-ChildItem packages |
    ? { $_.Name -match '^(.*?)\.(\d+(\.\d+)*(-.*)?)' } |
    % {
      @{
        File = $_
        Id = $Matches[1]
        Version = $Matches[2]
        SortableVersion = (Normalize-SemVer $Matches[2])
      }
    } |
    Group-Object { $_.Id } |
    ? { $_.Count -gt 1 } |
    % {
      $_.Group |
        Sort-Object -Property @{Expression={$_.SortableVersion}} -Descending |
        Select-Object -Skip 1 |
        % {
          New-Object PSObject -Property @{
            Id = $_.Id
            Version = $_.Version
            File = $_.File
          }
        }
    }
}

function Normalize-SemVer($Version) {
  $isMatch = $Version -match '(?<num>\d+(?:\.\d+)*)(?:\-(?<pre>.*))?'
  if(-not $isMatch) {
    throw "Invalid version"
  }

  $numericParts = $Matches['num'].Split('.')

  $normalized = ''
  for($i = 0; $i -lt 6; $i++) {
    $normalized = $normalized + ([int]('0' + $numericParts[$i])).ToString('0000000000')
  }

  if($Matches['pre']) {
    $normalized = $normalized + $Matches['pre']
  } else {
    $normalized = $normalized + 'zzzzzzzzzz'
  }

  return $normalized
}

function Get-DuplicatePackages()
{
  Get-Package | Group-Object -Property Id | ? { $_.Count -gt 1 }
}

function Update-DuplicatePackages()
{
  Get-DuplicatePackages | % { Update-Package $_.Name }
}

function Downgrade-Package {
  param(
    [parameter(Mandatory = $true)]
    $Name,
    [parameter(Mandatory = $true)]
    $Version
  )

  $projects = Get-Project -All |
	select @{Name="ProjectName";Expression={$_.ProjectName}}, @{Name="Has";Expression={Get-Package $Name -Project $_.Name | ? { $_.Id -eq $Name -and $_.Version -ne $Version } }} |
	? { $_.Has -ne $null } |
	% {
		Uninstall-Package $Name -ProjectName $_.ProjectName -Force
		Install-Package $Name -Version $Version -ProjectName $_.ProjectName
	}
}

function Reinstall-Package {
  param(
    [parameter(Mandatory = $true)]
    $Name,
    [parameter(Mandatory = $true)]
    $Version
  )

  $projects = Get-Project -All |
	select @{Name="ProjectName";Expression={$_.ProjectName}}, @{Name="Has";Expression={Get-Package $Name -Project $_.Name | ? { $_.Id -eq $Name -and $_.Version -eq $Version } }} |
	? { $_.Has -ne $null } |
	% {
		Uninstall-Package $Name -ProjectName $_.ProjectName -Force
		Install-Package $Name -Version $Version -ProjectName $_.ProjectName
	}
}

function Get-PackageFromNugetOrg()
{
	param(
		[parameter(Mandatory = $true)]
		$Name
	)

	Get-Package -Source "https://www.nuget.org/api/v2/" -ListAvailable -Filter $Name
}

function _Increment-PackageVersion_Internal($project, $Segment)
{
	$packageSpecItem = $project.ProjectItems | ? { $_.Name -eq '_Package.cs' }
	if($packageSpecItem -eq $null) {
		Write-Host "Skipping project '$($project.Name)' because it does not seem to be a NuGet package."
		return;
	}

	$x = $packageSpecItem.Open()
	$packageSpecDoc = $packageSpecItem.Document

	# Open file in editor
	$packageSpecPath = $packageSpecDoc.FullName
	$x = $DTE.ItemOperations.OpenFile($packageSpecPath)

	$members = $packageSpecItem.FileCodeModel.CodeElements.Item('Package').Members
	$maj = $members.Item('Version_Major')
	$min = $members.Item('Version_Minor')
	$bld = $members.Item('Version_Build')

	if($Segment -eq 'Major') {
		$maj.InitExpression = '"' + ([int]$maj.InitExpression.Trim('"') + 1) + '"'
		$min.InitExpression = '"0"'
		$bld.InitExpression = '"0"'
	} else {
		if($Segment -eq 'Minor') {
			$min.InitExpression = '"' + ([int]$min.InitExpression.Trim('"') + 1) + '"'
			$bld.InitExpression = '"0"'
		} else {
			$bld.InitExpression = '"' + ([int]$bld.InitExpression.Trim('"') + 1) + '"'
		}
	}
}

function Increment-AllPackageVersions()
{
	param(
		[parameter()]
		[ValidateSet('Major', 'Minor', 'Build')]
		[string]
		$Segment = 'Build'
	)

	Get-Projects | % { Increment-PackageVersion $_.ProjectName -Segment $Segment -IgnoreDependencies }
}

function Increment-PackageVersion()
{
	param(
		[parameter(Mandatory = $true)]
		[string]
		$ProjectName,

		[parameter()]
		[ValidateSet('Major', 'Minor', 'Build')]
		[string]
		$Segment = 'Build',

		[switch]
		$IgnoreDependencies
	)

	if ($DTE.UndoContext.IsOpen) {
		$DTE.UndoContext.Close()
	}
	$DTE.UndoContext.Open("Increment package version")

	$project = Get-Project -Name $ProjectName.TrimStart('.', '\')
	_Increment-PackageVersion_Internal $project $Segment $IgnoreDependencies $allReferences

	if(-not $IgnoreDependencies) {
		Get-ProjectsWithIndirectReferencesTo $project | % { _Increment-PackageVersion_Internal $_ 'Build' }
	}

	$DTE.UndoContext.Close()
}

function Get-AllProjectReferences() {
	Write-Host 'Discovering project references...'
	Get-Project -All | % { $p = $_; $_.Object.References | ? { $_.SourceProject -ne $null } | select @{Name='From';Expression={$p}}, @{Name='To';Expression={$_}}, @{Name='ToName';Expression={$_.Name}} }
}

function Get-ProjectsWithDirectReferencesTo() {
	param(
		[parameter(Mandatory = $true)]
		$project,

		$allReferences = (Get-AllProjectReferences)
	)

	$allReferences | ? { $_.ToName -eq $project.Name } | % { $_.From }
}

function Get-ProjectsWithIndirectReferencesTo() {
	param(
		[parameter(Mandatory = $true)]
		$project,

		$allReferences = (Get-AllProjectReferences)
	)

	$directRefs = Get-ProjectsWithDirectReferencesTo $project $allReferences
	$indirectRefs = $directRefs | % { Get-ProjectsWithIndirectReferencesTo $_ $allReferences }
	$indirectRefs, $directRefs | % { $_ } | Group-Object Name | % { $_.Group | Select-Object -First 1 }
}
