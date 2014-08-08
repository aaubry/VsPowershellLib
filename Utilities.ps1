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

function Get-ClipboardText()
{
    $command =
    {
        add-type -an system.windows.forms
        [System.Windows.Forms.Clipboard]::GetText()
    }
    powershell -sta -noprofile -command $command
}