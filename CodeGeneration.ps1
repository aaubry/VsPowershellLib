function Name-ToPascalCase {
	param(
		[parameter(Mandatory = $true)]
		[string] $Name
	)
	
	$Name = $Name.TrimStart('_')
	$Name = [System.Text.RegularExpressions.Regex]::Replace($Name, "^([A-Z])", { param($m) $m.Value.ToLower() })
	$Name = [System.Text.RegularExpressions.Regex]::Replace($Name, "[^\w]", "")
	return $Name
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
  
  $Name = Name-ToPascalCase $Name
  
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

function Move-TypeToOwnFile() {
	$type = Get-TypeAtCursor
	$ns = $type.Namespace
	
	$fileName = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($DTE.ActiveDocument.ProjectItem.Document.FullName), $type.Name + ".cs")
	if ([System.IO.File]::Exists($fileName)) {
		throw "File '$fileName' already exists"
	}
	
	if ($DTE.UndoContext.IsOpen) {
		$DTE.UndoContext.Close()
	}
	$DTE.UndoContext.Open("Move type to own file")

	$startPoint = $type.StartPoint.CreateEditPoint()
	$typeText = $startPoint.GetText($type.EndPoint)
	$startPoint.Delete($type.EndPoint)

	$startPoint.MoveToAbsoluteOffset(1)
	$importsText = $startPoint.GetText($ns.StartPoint)

	$output = [System.IO.File]::CreateText($fileName)
	$output.Write($importsText)
	$output.WriteLine("namespace {0} {{", $ns.FullName)
	$output.WriteLine($typeText)
	$output.Write("}")
	$output.Close()

	$x = $DTE.ExecuteCommand("Edit.RemoveAndSort")

	$DTE.ActiveDocument.ProjectItem.ContainingProject.ProjectItems.AddFromFile($fileName)
	$DTE.ItemOperations.OpenFile($fileName)
	$x = $DTE.ExecuteCommand("Edit.RemoveAndSort")

	$DTE.UndoContext.Close()
	
	Format-Document
}

function Add-ConstructorFromPropertiesAndFields() {
	$type = Get-TypeAtCursor

	if ($DTE.UndoContext.IsOpen) {
		$DTE.UndoContext.Close()
	}
	$DTE.UndoContext.Open("Move type to own file")

	$InsertionIndex = ($type.Members | Take-While { $_.Kind -eq [EnvDTE.vsCMElement]::vsCMElementVariable -or $_.Kind -eq [EnvDTE.vsCMElement]::vsCMElementProperty } | Measure-Object).Count
	$Constructor = $type.AddFunction($type.Name, [EnvDTE.vsCMFunction]::vsCMFunctionConstructor, [EnvDTE.vsCMTypeRef]::vsCMTypeRefVoid, $InsertionIndex, [EnvDTE.vsCMAccess]::vsCMAccessPublic)
	
	(Get-TypeAtCursor).Members |
	? {
		($_.Kind -eq [EnvDTE.vsCMElement]::vsCMElementProperty -and $_.Setter.Access -eq [EnvDTE.vsCMAccess]::vsCMAccessPrivate) -or
		($_.Kind -eq [EnvDTE.vsCMElement]::vsCMElementVariable -and $_.IsConstant)
	} | ? { $_.IsShared -eq $false } | % {
	
		$paramName = Name-ToPascalCase $_.Name
		$Param = $Constructor.AddParameter($paramName, $_.Type, $Constructor.Parameters.Count)
		#echo (Name-ToPascalCase $_.Name)
		
		$Pos = $Constructor.EndPoint.CreateEditPoint()
		$Pos.LineUp()
		$Pos.EndOfLine()
		$Pos.Insert([Environment]::NewLine)
		$Pos.Insert([String]::Format("			{0} = {1};", $_.Name, $paramName))
	}
	
	$DTE.UndoContext.Close()

	#Format-Document
}
