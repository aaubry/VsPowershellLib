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