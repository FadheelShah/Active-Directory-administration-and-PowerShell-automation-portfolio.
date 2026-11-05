function Search-Employee {
    
    [Cmdletbinding()]
    param(
        [Parameter (Mandatory=$true)]
        [ValidateScript({
            # Block Empty Space
            if ([string]::ISNullOrWhiteSpace($_))  {
                throw "SearchTerm cannot be empty or consist entirely of spaces. please type a valid name or ID."
                }
            

            # Block wildcards completely
            if ($_.Contains('*') -or $_.Contains('?')) {
            throw "⚠️ Wildcard characters (* or ?) are not allowed. Please enter a specific name or ID."
            
            }
            return $true
         })]

        [string]$SearchTerm
    )

    $FilterString = "Name -like '*{0}*' -or sAMAccountName -like '*{0}*' -or EmployeeID -like '*{0}*'" -f $SearchTerm

    Get-ADUser -Filter $FilterString -Properties EmployeeID, Department | 
    Select-Object EmployeeID, GivenName, Surname, sAMAccountName, Department, ObjectGUID, Enabled
}


Search-Employee 


