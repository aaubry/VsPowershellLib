function Delete-OldPackages {
  dir packages | group {$([regex]::match($_.Name, '^(.*?)\.(\d+(\.\d+))').Groups[1].Value)} | where {$_.Count -gt 1} | foreach-object { echo $_.Group | sort-object Name -Descending | select -Skip 1 | remove-item -Recurse }
}

function Update-PtCom {
  get-package -Filter PTCom -Updates | update-package
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
