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