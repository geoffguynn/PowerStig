# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module .\..\Common\Common.psm1
using module .\..\Rule\Rule.psm1

$exclude = @($MyInvocation.MyCommand.Name,'Template.*.txt')
$supportFileList = Get-ChildItem -Path $PSScriptRoot -Exclude $exclude
Foreach ($supportFile in $supportFileList)
{
    Write-Verbose "Loading $($supportFile.FullName)"
    . $supportFile.FullName
}
# Header

<#
    .SYNOPSIS
        Convert the contents of an xccdf check-content element into a user right object
    .DESCRIPTION
        The UserRightRule class is used to extract the {} settings from the
        check-content of the xccdf. Once a STIG rule is identified a
        user right rule, it is passed to the UserRightRule class for parsing
        and validation.
    .PARAMETER DisplayName
        The user right display name
    .PARAMETER Constant
        The user right constant
    .PARAMETER Identity
        The identitys that should have the user right
    .PARAMETER Force
        A flag that replaces the identities vs append
#>
Class UserRightRule : Rule
{
    [ValidateNotNullOrEmpty()] [string] $DisplayName
    [ValidateNotNullOrEmpty()] [string] $Constant
    [ValidateNotNullOrEmpty()] [string] $Identity
    [bool] $Force = $false

    <#
        .SYNOPSIS
            Default constructor
        .DESCRIPTION
            Converts a xccdf STIG rule element into a UserRightRule
        .PARAMETER StigRule
            The STIG rule to convert
    #>
    UserRightRule ( [xml.xmlelement] $StigRule )
    {
        $this.InvokeClass( $StigRule )
    }

    #region Methods

    <#
        .SYNOPSIS
            Extracts the display name from the check-content and sets the value
        .DESCRIPTION
            Gets the display name from the xccdf content and sets the value. If
            the name that is returned is not valid, the parser status is set to fail.
    #>
    [void] SetDisplayName ()
    {
        $thisDisplayName = Get-UserRightDisplayName -CheckContent $this.SplitCheckContent

        if ( -not $this.SetStatus( $thisDisplayName ) )
        {
            $this.set_DisplayName( $thisDisplayName )
        }
    }

    <#
        .SYNOPSIS
            Extracts the user right constant from the check-content and sets the value
        .DESCRIPTION
            Gets the user right constant from the xccdf content and sets the
            value. If the constant that is returned is not valid, the parser
            status is set to fail.
    #>
    [void] SetConstant ()
    {
        $thisConstant = Get-UserRightConstant -UserRightDisplayName $this.DisplayName

        if ( -not $this.SetStatus( $thisConstant ) )
        {
            $this.set_Constant( $thisConstant )
        }
    }

    <#
        .SYNOPSIS
            Extracts the user right identity from the check-content and sets the value
        .DESCRIPTION
            Gets the user right identity from the xccdf content and sets the
            value. If the identity that is returned is not valid, the parser
            status is set to fail.
    #>
    [void] SetIdentity ()
    {
        $thisIdentity = Get-UserRightIdentity -CheckContent $this.SplitCheckContent
        $return = $true
        if ( [String]::IsNullOrEmpty( $thisIdentity ) )
        {
            $return = $false
        }
        elseif ( $thisIdentity -ne 'NULL' )
        {
            if ($thisIdentity -join "," -match "{Hyper-V}")
            {
                $this.SetOrganizationValueRequired()
                $HyperVIdentity = $thisIdentity -join "," -replace "{Hyper-V}", "NT Virtual Machine\\Virtual Machines"
                $NoHyperVIdentity = $thisIdentity.Where( {$PSItem -ne "{Hyper-V}"}) -join ","
                $this.set_OrganizationValueTestString("'{0}' -match '^($HyperVIdentity|$NoHyperVIdentity)$'")
            }
        }

        # add the results reguardless so they are easier to update
        $this.Identity = $thisIdentity -Join ","
        #return $return
    }

    <#
        .SYNOPSIS
            Extracts the force flag from the check-content and sets the value
        .DESCRIPTION
            Gets the force flag from the xccdf content and sets the value
    #>
    [void] SetForce ()
    {
        if ( Test-SetForceFlag -CheckContent $this.SplitCheckContent )
        {
            $this.set_Force( $true )
        }
        else
        {
            $this.set_Force( $false )
        }
    }

    <#
        .SYNOPSIS
            Tests if a rule contains multiple checks
        .DESCRIPTION
            Search the rule text to determine if multiple user rights are defined
        .PARAMETER CheckContent
            The rule text from the check-content element in the xccdf
    #>

    static [bool] HasMultipleRules ( [string] $CheckContent )
    {
        if ( Test-MultipleUserRightsAssignment -CheckContent ( [Rule]::SplitCheckContent( $CheckContent ) ) )
        {
            return $true
        }

        return $false
    }

    <#
        .SYNOPSIS
            Splits a rule into multiple checks
        .DESCRIPTION
            Once a rule has been found to have multiple checks, the rule needs
            to be split. This method splits a user right into multiple rules. Each
            split rule id is appended with a dot and letter to keep reporting
            per the ID consistent. An example would be is V-1000 contained 2
            checks, then SplitMultipleRules would return 2 objects with rule ids
            V-1000.a and V-1000.b
        .PARAMETER CheckContent
            The rule text from the check-content element in the xccdf
    #>
    static [string[]] SplitMultipleRules ( [string] $CheckContent )
    {
        return ( Split-MultipleUserRightsAssignment -CheckContent ( [Rule]::SplitCheckContent( $CheckContent ) ) )
    }

    #endregion
}
