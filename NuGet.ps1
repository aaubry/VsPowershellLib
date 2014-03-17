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

function Get-PackageFromNugetOrg()
{
	param(
		[parameter(Mandatory = $true)]
		$Name
	)

	Get-Package -Source "https://www.nuget.org/api/v2/" -ListAvailable -Filter $Name
}

function _Increment-PackageVersion_Internal($project, $Segment, $IgnoreDependencies, $allReferences)
{
	$packageSpecItem = $project.ProjectItems.Item('_Package.cs')

	$x = $packageSpecItem.Open()
	$packageSpecDoc = $packageSpecItem.Document
	
	# Open file in editor
	$packageSpecPath = $packageSpecDoc.FullName
	$x = $DTE.ItemOperations.OpenFile($packageSpecPath)
	
	$version = $packageSpecItem.FileCodeModel.CodeElements.Item('Package').Members.Item('Version')
	
	$maj, $min, $bld = [int[]]$version.InitExpression.Trim('"').Split('.')
	
	if($Segment -eq 'Major') {
		$maj = $maj + 1
		$min = 0
		$bld = 0
	} else {
		if($Segment -eq 'Minor') {
			$min = $min + 1
			$bld = 0
		} else {
			$bld = $bld + 1
		}
	}
	
	$version.InitExpression = '"' + [string]::Join('.', @($maj, $min, $bld)) + '"'
	
	if(-not $IgnoreDependencies) {
		Get-ProjectsWithDirectReferencesTo $project $allReferences | % { _Increment-PackageVersion_Internal $_ 'Build' $false $allReferences }
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

	$allReferences = $null
	if(-not $IgnoreDependencies) {
		$allReferences = Get-AllProjectReferences
	}
	
	$project = Get-Project -Name $ProjectName.TrimStart('.', '\')
	_Increment-PackageVersion_Internal $project $Segment $IgnoreDependencies $allReferences
	
	$DTE.UndoContext.Close()
}

function Get-AllProjectReferences() {
	Write-Host 'Discovering project references...'
	Get-Project -All | % { $p = $_; $_.Object.References | ? { $_.SourceProject -ne $null } | select @{Name='From';Expression={$p}}, @{Name='To';Expression={$_}} }
}

function Get-ProjectsWithDirectReferencesTo() {
	param(
		[parameter(Mandatory = $true)]
		$project,
		
		$allReferences = (Get-AllProjectReferences)
	)

	$allReferences | ? { $_.To.Name -eq $project.Name } | Select-Object -First 1 | % { $_.From }
}

function Get-ProjectsWithIndirectReferencesTo() {
	param(
		[parameter(Mandatory = $true)]
		$project,
		
		$allReferences = (Get-AllProjectReferences)
	)

	$directRefs = Get-ProjectsWithDirectReferencesTo $project $allReferences
	$directRefs | % { Get-ProjectsWithIndirectReferencesTo $_ $allReferences }
	$directRefs
}
