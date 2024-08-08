<#
.SYNOPSIS
    Check for gaps in conditional access policies

.DESCRIPTION
    This function checks if all objects found in policy exclusions are found in policy inclusions.

.EXAMPLE
    <TO DO>

.LINK
    <TO DO>
#>
function Get-ObjectDifferences {
    param (
        [System.Collections.ArrayList]$excludedObjects,
        [System.Collections.ArrayList]$includedObjects
    )

    # Only get unique values
    $excludedObjects = $excludedObjects | Select-Object -Unique
    $includedObjects = $includedObjects | Select-Object -Unique
    # Get all the objects that are excluded somewhere but included somewhere else
    $excludedObjectsWithFallback = $excludedObjects | Where-Object {
        $includedObjects -contains $_
    }
    # Get the differences between the two Arrays, so we can find which objects did not have a fallback
    $objectDifferences = $excludedObjects | Where-Object {
        $excludedObjectsWithFallback -notcontains $_
    }
    return $objectDifferences
}

function Get-RalatedPolicies {
    param (
        [System.Collections.ArrayList]$Arr,
        [String]$ObjName
    )
    # Check each policy in the array
    foreach ($obj in $Arr) {
        # Check if the excluded object is present in the policy
        if ($obj.ExcludedObjects -contains $ObjName) {
            Write-Host "        - Excluded in policy '$($obj.PolicyName)'"
        }
    }
}

function Test-MtCaGaps {
    # Get the enabled conditional access policies
    $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }

    # Variabes related to users
    [System.Collections.ArrayList]$excludedUsers = @()
    [System.Collections.ArrayList]$includedUsers = @()
    [System.Collections.ArrayList]$differencesUsers = @()
    # Variabes related to groups
    [System.Collections.ArrayList]$excludedGroups = @()
    [System.Collections.ArrayList]$includedGroups = @()
    [System.Collections.ArrayList]$differencesGroups = @()
    # Variabes related to Roles
    [System.Collections.ArrayList]$excludedRoles = @()
    [System.Collections.ArrayList]$includedRoles = @()
    [System.Collections.ArrayList]$differencesRoles = @()
    # Variabes related to Applications
    [System.Collections.ArrayList]$excludedApplications = @()
    [System.Collections.ArrayList]$includedApplications = @()
    [System.Collections.ArrayList]$differencesApplications = @()
    # Variabes related to ServicePrincipals
    [System.Collections.ArrayList]$excludedServicePrincipals = @()
    [System.Collections.ArrayList]$includedServicePrincipals = @()
    [System.Collections.ArrayList]$differencesServicePrincipals = @()
    # Variabes related to Locations
    [System.Collections.ArrayList]$excludedLocations = @()
    [System.Collections.ArrayList]$includedLocations = @()
    [System.Collections.ArrayList]$differencesLocations = @()
    # Variabes related to Platforms
    [System.Collections.ArrayList]$excludedPlatforms = @()
    [System.Collections.ArrayList]$includedPlatforms = @()
    [System.Collections.ArrayList]$differencesPlatforms = @()
    # Mapping array
    [System.Collections.ArrayList]$mappingArray = @()

    # Get all the objects for all policies
    $policies | ForEach-Object {
        # Save all interesting objects for later use
        $excludedUsers += $_.Conditions.Users.ExcludeUsers
        $includedUsers += $_.Conditions.Users.IncludeUsers
        $excludedGroups += $_.Conditions.Users.ExcludeGroups
        $includedGroups += $_.Conditions.Users.IncludeGroups
        $excludedRoles += $_.Conditions.Users.ExcludeRoles
        $includedRoles += $_.Conditions.Users.IncludeRoles
        $excludedApplications += $_.Conditions.Applications.ExcludeApplications
        $includedApplications += $_.Conditions.Applications.IncludeApplications
        $excludedServicePrincipals += $_.Conditions.ClientApplications.ExcludeServicePrincipals
        $includedServicePrincipals += $_.Conditions.ClientApplications.IncludeServicePrincipals
        $excludedLocations += $_.Conditions.Locations.ExcludeLocations
        $includedLocations += $_.Conditions.Locations.IncludeLocations
        $excludedPlatforms += $_.Conditions.Locations.Platforms
        $includedPlatforms += $_.Conditions.Locations.Platforms

        # Create a mapping for each policy with excluded objects
        [System.Collections.ArrayList]$allExcluded = $_.Conditions.Users.ExcludeUsers + `
            $_.Conditions.Users.ExcludeGroups + `
            $_.Conditions.Users.ExcludeRoles + `
            $_.Conditions.Applications.ExcludeApplications + `
            $_.Conditions.ClientApplications.ExcludeServicePrincipals + `
            $_.Conditions.Locations.ExcludeLocations + `
            $_.Conditions.Locations.Platforms
        # Create the mapping
        $mapping = [PSCustomObject]@{
            PolicyName = $_.DisplayName
            ExcludedObjects = $allExcluded
        }
        # Add the mapping to the array and clear variable
        $mappingArray += $mapping
        Clear-Variable -Name allExcluded
    }

    # Find which objects are excluded without a fallback
    $differencesUsers = Get-ObjectDifferences -excludedObjects $excludedUsers -includedObjects $includedUsers
    $differencesGroups = Get-ObjectDifferences -excludedObjects $excludedGroups -includedObjects $includedGroups
    $differencesRoles = Get-ObjectDifferences -excludedObjects $excludedRoles -includedObjects $includedRoles
    $differencesApplications = Get-ObjectDifferences -excludedObjects $excludedApplications -includedObjects $includedApplications
    $differencesServicePrincipals = Get-ObjectDifferences -excludedObjects $excludedServicePrincipals -includedObjects $includedServicePrincipals
    $differencesLocations = Get-ObjectDifferences -excludedObjects $excludedLocations -includedObjects $includedLocations
    $differencesPlatforms = Get-ObjectDifferences -excludedObjects $excludedPlatforms -includedObjects $includedPlatforms

    Write-Host "The following user objects did not have a fallback"
    $differencesUsers | ForEach-Object {
        Write-Host "    - $_"
        Get-RalatedPolicies -Arr $mappingArray -ObjName $_
    }
    Write-Host "The following group objects did not have a fallback"
    $differencesGroups | ForEach-Object {
        Write-Host "    - $_"
        Get-RalatedPolicies -Arr $mappingArray -ObjName $_
    }
    Write-Host "The following role objects did not have a fallback"
    $differencesRoles | ForEach-Object {
        Write-Host "    - $_"
        Get-RalatedPolicies -Arr $mappingArray -ObjName $_
    }
    Write-Host "The following application objects did not have a fallback"
    $differencesApplications | ForEach-Object {
        Write-Host "    - $_"
        Get-RalatedPolicies -Arr $mappingArray -ObjName $_
    }
    Write-Host "The following service principals did not have a fallback"
    $differencesServicePrincipals | ForEach-Object {
        Write-Host "    - $_"
        Get-RalatedPolicies -Arr $mappingArray -ObjName $_
    }
    Write-Host "The following locations did not have a fallback"
    $differencesLocations | ForEach-Object {
        Write-Host "    - $_"
        Get-RalatedPolicies -Arr $mappingArray -ObjName $_
    }
    Write-Host "The following platforms did not have a fallback"
    $differencesPlatforms | ForEach-Object {
        Write-Host "    - $_"
        Get-RalatedPolicies -Arr $mappingArray -ObjName $_
    }
}
