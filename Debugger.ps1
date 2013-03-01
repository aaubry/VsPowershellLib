function Attach-WebServer {
  $DTE.Debugger.LocalProcesses | Where { $_.Name.Contains("w3wp") } | ForEach-Object { $_.Attach() }
}

function Evaluate-Expression {
	param(
		[parameter(Mandatory = $true)]
		[string] $Expression
	)

	$value = $DTE.Debugger.GetExpression($Expression, $true, 5000)
	
	if ($value.Type.Contains('[]')) {
		$value.DataMembers | % { $i = 0 } { $_ | select @{Name='Index';Expression={$i}}, Value; $i++ }
	} else {
		$value.Value
	}
}
