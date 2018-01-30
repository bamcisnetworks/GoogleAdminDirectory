$script:GroupBaseUrl = "https://www.googleapis.com/admin/directory/v1/groups"
$script:UserBaseUrl = "https://www.googleapis.com/admin/directory/v1/users"

#region Groups

Function New-GoogleDirectoryGroup {
	<#
		.SYNOPSIS
			Creates a new GSuite group.

		.DESCRIPTION

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable

		
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNull()]
		[System.String]$Email,

		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNull()]
		[System.String]$Name,

		[Parameter(Position = 2)]
		[ValidateNotNull()]
		[System.String]$Description,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$PassThru
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base"
		[System.Collections.Hashtable]$Group = @{"email" = $Email; "name" = $Name}

		if (-not [System.String]::IsNullOrEmpty($Description))
		{
			$Group.Add("description", $Description)
		}

		[System.String]$Body = ConvertTo-Json -InputObject $Group -Compress -Depth 3

		try
		{
			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Post -Body $Body -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell

			if ($PassThru)
			{
				[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content
			
				[System.Collections.Hashtable]$Temp = @{}
				foreach($Property in ($ParsedResponse | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name))
				{
					$Temp.Add($Property, $ParsedResponse.$Property)
				}

				Write-Output -InputObject $Temp
			}
		}
		catch [System.Net.WebException]
		{
			[System.Net.WebException]$Ex = $_.Exception
			[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
			[System.Int32]$StatusCode = $Response.StatusCode.value__
			[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
			[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
			[System.String]$Content = $Reader.ReadToEnd()
				
			[System.String]$Message = "$StatusCode : $Content"

			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
				Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $Message"
			}
		}
		catch [Exception] 
		{
			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				Write-Error -Exception $_.Exception -ErrorAction Stop
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $_.Exception.Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
			}
		}
	}

	End {
	}
}

Function Set-GoogleDirectoryGroup {
	<#
		.SYNOPSIS
			Updates a GSuite group properties.

		.DESCRIPTION

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNull()]
		[System.String]$GroupKey,

		[Parameter(Position = 1)]
		[ValidateNotNull()]
		[System.String]$Email,

		[Parameter(Position = 2)]
		[ValidateNotNull()]
		[System.String]$Name,

		[Parameter(Position = 3)]
		[System.String]$Description,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$PassThru
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$GroupKey"
		
		[System.Collections.Hashtable]$Group = @{}

		if ($PSBoundParameters.ContainsKey("GroupEmail"))
		{
			$Group.Add("email", $Email)
		}
		
		if ($PSBoundParameters.ContainsKey("GroupName"))
		{
			$Group.Add("name", $Name)
		}

		if ($PSBoundParameters.ContainsKey("Description"))
		{
			$Group.Add("description", $Description)
		}

		if ($Group -eq @{})
		{
			Write-Error -Exception (New-Object -TypeName System.ArgumentException("You must specify a property to update")) -ErrorAction Stop
		}

		[System.String]$Body = ConvertTo-Json -InputObject $Group -Compress -Depth 3

		try
		{
			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Put -Body $Body -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell

			if ($PassThru)
			{
				[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content
			
				[System.Collections.Hashtable]$Temp = @{}
				foreach($Property in ($ParsedResponse | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name))
				{
					$Temp.Add($Property, $ParsedResponse.$Property)
				}

				Write-Output -InputObject $Temp
			}
		}
		catch [System.Net.WebException]
		{
			[System.Net.WebException]$Ex = $_.Exception
			[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
			[System.Int32]$StatusCode = $Response.StatusCode.value__
			[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
			[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
			[System.String]$Content = $Reader.ReadToEnd()
				
			[System.String]$Message = "$StatusCode : $Content"

			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
				Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $Message"
			}
		}
		catch [Exception] 
		{
			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				Write-Error -Exception $_.Exception -ErrorAction Stop
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $_.Exception.Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
			}
		}
	}

	End {
	}
}

Function New-GoogleDirectoryGroupAlias {
	<#
		.SYNOPSIS
			Creates a GSuite group alias.

		.DESCRIPTION

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNull()]
		[System.String]$GroupKey,

		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNull()]
		[System.String]$Alias,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$PassThru
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$GroupKey/aliases"

		[System.String]$Body = ConvertTo-Json -InputObject @{"alias" = $Alias } -Compress -Depth 3

		try
		{
			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Post -Body $Body -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell

			if ($PassThru)
			{
				[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content
			
				[System.Collections.Hashtable]$Temp = @{}
				foreach($Property in ($ParsedResponse | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name))
				{
					$Temp.Add($Property, $ParsedResponse.$Property)
				}

				Write-Output -InputObject $Temp
			}
		}
		catch [System.Net.WebException]
		{
			[System.Net.WebException]$Ex = $_.Exception
			[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
			[System.Int32]$StatusCode = $Response.StatusCode.value__
			[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
			[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
			[System.String]$Content = $Reader.ReadToEnd()
				
			[System.String]$Message = "$StatusCode : $Content"

			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
				Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $Message"
			}
		}
		catch [Exception] 
		{
			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				Write-Error -Exception $_.Exception -ErrorAction Stop
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $_.Exception.Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
			}
		}
	}

	End {
	}
}

Function Get-GoogleDirectoryGroupAlias {
	<#
		.SYNOPSIS
			Gets all aliases for a GSuite group.

		.DESCRIPTION

		.INPUTS 
			None
		
		.OUTPUTS
			System.Collections.Hashtable[]
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNull()]
		[System.String]$GroupKey,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$GroupKey/aliases"

		try
		{
			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Get -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell

			[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content
			
			[System.Collections.Hashtable[]]$Aliases = @()

			foreach ($Alias in $ParsedResponse.aliases)
			{
				[System.Collections.Hashtable]$Temp = @{}
				foreach($Property in ($Alias | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name))
				{
					$Temp.Add($Property, $Alias.$Property)
				}

				$Aliases += $Temp
			}

			Write-Output -InputObject $Aliases
		}
		catch [System.Net.WebException]
		{
			[System.Net.WebException]$Ex = $_.Exception
			[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
			[System.Int32]$StatusCode = $Response.StatusCode.value__
			[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
			[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
			[System.String]$Content = $Reader.ReadToEnd()
				
			[System.String]$Message = "$StatusCode : $Content"

			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
				Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $Message"
			}
		}
		catch [Exception] 
		{
			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				Write-Error -Exception $_.Exception -ErrorAction Stop
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $_.Exception.Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
			}
		}
	}

	End {
	}
}

Function Remove-GoogleDirectoryGroupAlias {
	<#
		.SYNOPSIS
			Deletes a GSuite group alias.

		.DESCRIPTION

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNull()]
		[System.String]$GroupKey,

		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNull()]
		[System.String]$AliasId,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$GroupKey/aliases/$AliasId"

		try
		{
			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Delete -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell
		}
		catch [System.Net.WebException]
		{
			[System.Net.WebException]$Ex = $_.Exception
			[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
			[System.Int32]$StatusCode = $Response.StatusCode.value__
			[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
			[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
			[System.String]$Content = $Reader.ReadToEnd()
				
			[System.String]$Message = "$StatusCode : $Content"

			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
				Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $Message"
			}
		}
		catch [Exception] 
		{
			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				Write-Error -Exception $_.Exception -ErrorAction Stop
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $_.Exception.Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
			}
		}
	}

	End {
	}
}

Function Get-GoogleDirectoryGroup {
	<#
		.SYNOPSIS
			Gets a GSuite group.

		.DESCRIPTION

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNull()]
		[System.String]$GroupKey,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$GroupKey"

		try
		{
			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Get -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell

			[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content
			
			[System.Collections.Hashtable]$Temp = @{}
			foreach($Property in ($ParsedResponse | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name))
			{
				$Temp.Add($Property, $ParsedResponse.$Property)
			}

			Write-Output -InputObject $Temp
		}
		catch [System.Net.WebException]
		{
			[System.Net.WebException]$Ex = $_.Exception
			[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
			[System.Int32]$StatusCode = $Response.StatusCode.value__
			[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
			[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
			[System.String]$Content = $Reader.ReadToEnd()
				
			[System.String]$Message = "$StatusCode : $Content"

			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
				Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $Message"
			}
		}
		catch [Exception] 
		{
			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				Write-Error -Exception $_.Exception -ErrorAction Stop
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $_.Exception.Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
			}
		}
	}

	End {
	}
}

Function Get-GoogleDirectoryGroupList {
    [CmdletBinding()]
	[OutputType([System.Collections.Hashtable[]])]
    Param(
		[Parameter(Mandatory = $true, ParameterSetName = "TokenDefault")]
		[Parameter(Mandatory = $true, ParameterSetName = "TokenDomain")]
		[Parameter(Mandatory = $true, ParameterSetName = "TokenCustomerId")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "ProfileDefault")]
		[Parameter(Mandatory = $true, ParameterSetName = "ProfileDomain")]
		[Parameter(Mandatory = $true, ParameterSetName = "ProfileCustomerId")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "ProfileDefault")]
		[Parameter(ParameterSetName = "ProfileDomain")]
		[Parameter(ParameterSetName = "ProfileCustomerId")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "ProfileDefault")]
		[Parameter(ParameterSetName = "ProfileDomain")]
		[Parameter(ParameterSetName = "ProfileCustomerId")]
		[Switch]$Persist,

        [Parameter()]
        [System.UInt32]$MaxResults,

		[Parameter(Mandatory = $true, ParameterSetName = "TokenDomain")]
        [Parameter(Mandatory = $true, ParameterSetName = "ProfileDomain")]
        [ValidateNotNullOrEmpty()]
        [System.String]$Domain,

		[Parameter(Mandatory = $true, ParameterSetName = "TokenCustomerId")]
        [Parameter(Mandatory = $true, ParameterSetName = "ProfileCustomerId")]
        [ValidateNotNullOrEmpty()]
        [System.String]$CustomerId
    )

    Begin {
    }

    Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -like "Profile*")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

        switch -regex ($PSCmdlet.ParameterSetName)
        {
			"^.*Default$" {
				$Base += "?customer=my_customer"
                break
			}
            "^.*Domain$" {
                $Base += "?domain=$([System.Uri]::EscapeUriString($Domain))"
                break
            }
            "^.*CustomerId$" {
                $Base += "?customer=$([System.Uri]::EscapeUriString($CustomerId))"
                break
            }
			default {
				Write-Error -Message "Unknown parameter set $($PSCmdlet.ParameterSetName) for $($MyInvocation.MyCommand)." -ErrorAction Stop
			}
        }

        if ($PSBoundParameters.ContainsKey("MaxResults") -and $MaxResults -gt 0)
        {
            $Base += "&maxResults=$MaxResults"
        }

        $NextToken = $null
        [System.String]$Url = $Base
        [System.Collections.Hashtable[]]$Groups = @()

        do {
            try
			{
				[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Get -Headers @{"Authorization" = "Bearer $BearerToken"} -ErrorAction Stop -UserAgent PowerShell
				
				[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content
				
				foreach ($Group in $ParsedResponse.Groups)
				{
					[System.Collections.Hashtable]$Temp = @{}
					foreach ($Property in ($Group | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name))
					{
						$Temp.Add($Property, $Group.$Property)
					}

					$Groups += $Temp
				}
				
				$NextToken = $ParsedResponse.nextPageToken
				$Url = "$Base&pageToken=$NextToken"
			}
			catch [System.Net.WebException] 
			{
				$NextToken = $null

				[System.Net.WebException]$Ex = $_.Exception
				[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
				[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
				[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
				[System.String]$Content = $Reader.ReadToEnd()
				[System.Int32]$StatusCode = $Response.StatusCode.value__
				[System.String]$Message = "$StatusCode : $Content"

				if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
				{
					[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
					Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
				}
				elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
				{
					Write-Warning -Message $Message
				}
				else
				{
					Write-Verbose -Message "[ERROR] : $Message"
				}
			}
			catch [Exception] 
			{
				$NextToken = $null

				if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
				{
					Write-Error -Exception $_.Exception -ErrorAction Stop
				}
				elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
				{
					Write-Warning -Message $_.Exception.Message
				}
				else
				{
					Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
				}
			}

        } while ($NextToken -ne $null)

        Write-Output -InputObject $Groups 
    }

    End {

    }
}

Function Get-GoogleDirectoryGroupsForUser {
	<#
		.SYNOPSIS
			Gets a list of GSuite groups for a specific user.

		.DESCRIPTION

		.INPUTS 
			None
		
		.OUTPUTS
			System.Collections.Hashtable[]
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNull()]
		[System.String]$UserId,

		[Parameter()]
        [System.UInt32]$MaxResults,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Base = "$Base`?userKey=$UserId"
		$NextToken = $null
		[System.Collections.Hashtable[]]$Groups = @()

		do
		{
			try
			{
				[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Get -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell

				[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content
			
				foreach ($Group in $ParsedResponse.Groups)
				{
					[System.Collections.Hashtable]$Temp = @{}
					foreach($Property in ($Group | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name))
					{
						$Temp.Add($Property, $Group.$Property)
					}

					$Groups += $Temp
				}

				$NextToken = $ParsedResponse.nextPageToken
				$Url = "$Base&pageToken=$NextToken"
			}
			catch [System.Net.WebException]
			{
				$NextToken = $null

				[System.Net.WebException]$Ex = $_.Exception
				[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
				[System.Int32]$StatusCode = $Response.StatusCode.value__
				[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
				[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
				[System.String]$Content = $Reader.ReadToEnd()
				
				[System.String]$Message = "$StatusCode : $Content"

				if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
				{
					[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
					Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
				}
				elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
				{
					Write-Warning -Message $Message
				}
				else
				{
					Write-Verbose -Message "[ERROR] : $Message"
				}
			}
			catch [Exception] 
			{
				$NextToken = $null

				if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
				{
					Write-Error -Exception $_.Exception -ErrorAction Stop
				}
				elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
				{
					Write-Warning -Message $_.Exception.Message
				}
				else
				{
					Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
				}
			}
		} while ($NextToken -ne $null)

		Write-Output -InputObject $Groups
	}

	End {
	}
}

Function Remove-GoogleDirectoryGroup {
	<#
		.SYNOPSIS
			Deletes a GSuite group.

		.DESCRIPTION

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable
	#>
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "HIGH")]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNull()]
		[System.String]$GroupKey,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$Force
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$GroupKey"

		try
		{
			$ConfirmMessage = "You are about to delete GSuite group $GroupKey."
			$WhatIfDescription = "Deleted group $GroupKey."
			$ConfirmCaption = "Delete GSuite Group"

			if ($Force -or $PSCmdlet.ShouldProcess($WhatIfDescription, $ConfirmMessage, $ConfirmCaption))
			{
				[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Delete -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell
			}
		}
		catch [System.Net.WebException]
		{
			[System.Net.WebException]$Ex = $_.Exception
			[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
			[System.Int32]$StatusCode = $Response.StatusCode.value__
			[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
			[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
			[System.String]$Content = $Reader.ReadToEnd()
				
			[System.String]$Message = "$StatusCode : $Content"

			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
				Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $Message"
			}
		}
		catch [Exception] 
		{
			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				Write-Error -Exception $_.Exception -ErrorAction Stop
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $_.Exception.Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
			}
		}
	}

	End {
	}
}

#endregion

#region Group Membership

Function Get-GoogleDirectoryGroupMembership {
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable[]])]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

        [Parameter()]
        [System.UInt32]$MaxResults,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$GroupKey,

        [Parameter()]
        [ValidateSet("OWNER", "MANAGER", "MEMBER")]
        [System.String[]]$Roles = @("MEMBER")
    )

    Begin {
    }

    Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$RoleQuery = [System.Uri]::EscapeUriString(($Roles -join ","))
        [System.String]$Url = "$Base/$GroupKey/members?roles=$RoleQuery"

        if ($PSBoundParameters.ContainsKey("MaxResults") -and $MaxResults -gt 0)
        {
            $Url += "&maxResults=$MaxResults"
        }

        $NextToken = $null
        $Temp = $Url

        [System.Collections.Hashtable[]]$Members = @()

        do {
            try
			{
				[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Temp -Method Get -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell
				[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content

				foreach ($Member in $ParsedResponse.Members)
				{
					[System.Collections.Hashtable]$Temp = @{}
					foreach ($Property in ($Member | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name))
					{
						$Temp.Add($Property, $Member.$Property)
					}

					$Members += $Temp
				}

				$NextToken = $ParsedResponse.nextPageToken
				$Temp = "$Url&pageToken=$NextToken"
			}
			catch [System.Net.WebException]
			{
				$NextToken = $null

				[System.Net.WebException]$Ex = $_.Exception
				[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
				[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
				[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
				[System.String]$Content = $Reader.ReadToEnd()
				[System.Int32]$StatusCode = $Response.StatusCode.value__
				[System.String]$Message = "$StatusCode : $Content"

				if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
				{
					[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
					Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
				}
				elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
				{
					Write-Warning -Message $Message
				}
				else
				{
					Write-Verbose -Message "[ERROR] : $Message"
				}
			}
			catch [Exception] 
			{
				$NextToken = $null

				if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
				{
					Write-Error -Exception $_.Exception -ErrorAction Stop
				}
				elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
				{
					Write-Warning -Message $_.Exception.Message
				}
				else
				{
					Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
				}
			}
        } while ($NextToken -ne $null)

        Write-Output -InputObject $Members 
    }

    End {
    }
}

#endregion

#region Users

Function New-GoogleDirectoryUser {
	<#
		.SYNOPSIS
			Creates a new GSuite user account.

		.DESCRIPTION
			This cmdlet creates a new user account.		

			- If the Google account has purchased mail licenses, the new user account is automatically assigned a mailbox. This assignment may take a few minutes to be completed and activated.
			- Editing a read-only field in a request, such as isAdmin, is silently ignored by the API service.
			- The maximum number of domains allowed in an account is 600 (1 primary domain + 599 additional domains)
			- If a user was not assigned to a specific organizational unit when the user account was created, the account is in the top-level organizational unit. A user's organizational unit determines which G Suite services the user has access to. If the user is moved to a new organization, the user's access changes. For more information about organization structures, see the administration help center. For more infomation about moving a user to a different organization, see Update a user.
			- A password is required for new user accounts. If a hashFunction is specified, the password must be a valid hash key. For more information, see the API Reference.
			- For users on a flexible plan for G Suite, creating users using this API will have monetary impact, and will result in charges to your customer billing account. For more information, see the API billing information.
			- A G Suite account can include any of your domains. In a multiple domain account, users in one domain can share services with users in other account domains. For more information about users in multiple domains, see the API multiple domain information.

		.PARAMETER UserProperties
			For an update request, you only need to submit the updated information in your request. Even though 
			the example data listed below is verbose, you do not need to enter all of the user's properties.

			{
			"primaryEmail": "liz@example.com",
			"name": {
			 "givenName": "Elizabeth",
			 "familyName": "Smith"
			},
			"suspended": false,
			"password": "new user password",
			"hashFunction": "SHA-1",
			"changePasswordAtNextLogin": false,
			"ipWhitelisted": false,
			"ims": [
			 {
			  "type": "work",
			  "protocol": "gtalk",
			  "im": "liz_im@talk.example.com",
			  "primary": true
			 }
			],
			"emails": [
			 {
			  "address": "liz@example.com",
			  "type": "home",
			  "customType": "",
			  "primary": true
			 }
			],
			"addresses": [
			 {
			  "type": "work",
			  "customType": "",
			  "streetAddress": "1600 Amphitheatre Parkway",
			  "locality": "Mountain View",
			  "region": "CA",
			  "postalCode": "94043"
			 }
			],
			"externalIds": [
			 {
			  "value": "12345",
			  "type": "custom",
			  "customType": "employee"
			 }
			],
			"relations": [
			 {
			  "value": "Mom",
			  "type": "mother",
			  "customType": ""
			 },
			 {
			  "value": "manager",
			  "type": "referred_by",
			  "customType": ""
			 }
			],
			"organizations": [
			 {
			  "name": "Google Inc.",
			  "title": "SWE",
			  "primary": true,
			  "type": "work",
			  "description": "Software engineer"
			 }
			],
			"phones": [
			 {
			  "value": "+1 nnn nnn nnnn",
			  "type": "work"
			 }
			],
			"orgUnitPath": "/corp/engineering",
			"includeInGlobalAddressList": true
			}

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable

		
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[ValidateNotNull()]
		[System.Collections.Hashtable]$User,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$PassThru,

		[Parameter()]
		[ValidateRange(1, 5)]
		[System.Int32]$MaximumRetries = 3
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$UserId"
		[System.String]$Body = ConvertTo-Json -InputObject $UserProperties -Compress -Depth 3


		$Success = $false
		$Counter = 0

		while (-not $Success -and $Counter -le $MaximumRetries)
		{
			try
			{
				[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Post -Body $Body -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell

				if ($Response.StatusCode -eq 201)
				{
					if ($PassThru)
					{
						[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content
			
						[System.Collections.Hashtable]$Temp = @{}
						foreach($Property in ($ParsedResponse | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name))
						{
							$Temp.Add($Property, $ParsedResponse.$Property)
						}

						Write-Output -InputObject $Temp
					}
				}
				else
				{
					# Exponential backoff
					[System.Double]$MilliSeconds = [System.Math]::Pow(2,  $Counter) * 1000
					[System.Double]$RandomMilliseconds = Get-Random -Minimum 0 -Maximum 1000
					$MilliSeconds += $RandomMilliseconds

					Start-Sleep -Milliseconds $MilliSeconds

					$Counter++
				}
			}
			catch [System.Net.WebException]
			{
				[System.Net.WebException]$Ex = $_.Exception
				[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
				[System.Int32]$StatusCode = $Response.StatusCode.value__

				# A 503 is returned for creation request rate being too high, use an
				# exponential backoff and try again
				# Enter here if we didn't get a 503, or we have used up all the retries
				if ($StatusCode -ne 503)
				{
					[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
					[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
					[System.String]$Content = $Reader.ReadToEnd()
				
					[System.String]$Message = "$StatusCode : $Content"

					if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
					{
						[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
						Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
					}
					elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
					{
						Write-Warning -Message $Message
					}
					else
					{
						Write-Verbose -Message "[ERROR] : $Message"
					}

					# Break out of the while loop
					break
				}
				else
				{
					# Exponential backoff
					[System.Double]$MilliSeconds = [System.Math]::Pow(2,  $Counter) * 1000
					[System.Double]$RandomMilliseconds = Get-Random -Minimum 0 -Maximum 1000
					$MilliSeconds += $RandomMilliseconds

					Start-Sleep -Milliseconds $MilliSeconds

					$Counter++
				}
			}
			catch [Exception] 
			{
				if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
				{
					Write-Error -Exception $_.Exception -ErrorAction Stop
				}
				elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
				{
					Write-Warning -Message $_.Exception.Message
				}
				else
				{
					Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
				}

				# Break out of the while loop
				break 
			}
		}
	}

	End {
	}
}

Function Get-GoogleDirectoryUser {
	[CmdletBinding()]
	[OutputType()]
	Param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[System.String]$UserId,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$UserId"

		try
		{
			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Get -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell
			[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content
			
			Write-Output -InputObject $ParsedResponse
		}
		catch [System.Net.WebException]
		{
			[System.Net.WebException]$Ex = $_.Exception
			[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
			[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
			[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
			[System.String]$Content = $Reader.ReadToEnd()
			[System.Int32]$StatusCode = $Response.StatusCode.value__
			[System.String]$Message = "$StatusCode : $Content"

			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
				Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $Message"
			}
		}
		catch [Exception] 
		{
			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				Write-Error -Exception $_.Exception -ErrorAction Stop
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $_.Exception.Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
			}
		}
	}

	End {
	}
}

Function Set-GoogleDirectoryUser {
	<#
		.SYNOPSIS
			Updates a user account properties.

		.DESCRIPTION
			This cmdlet updates a user account properties.		

			In general, Google recommends to not use the user email address as a key for persistent data since the email address is subject to change.

			- Renaming a user account changes the user's primary email address and the domain used when retrieving this user's information. Before renaming a user, we recommend that you log out the user from all browser sessions and services. For instance, you can get the user on your support desk telephone line during the rename process to ensure they have logged out.
			- The process of renaming a user account can take up to 10 minutes to propagate across all services.
			- When a user is renamed, the old user name is retained as a alias to ensure continuous mail delivery in the case of email forwarding settings and will not be available as a new user name.
			- In general, we also recommend to not use the user email address as a key for persistent data since the email address is subject to change.

		.PARAMETER UserProperties
			For an update request, you only need to submit the updated information in your request. Even though 
			the example data listed below is verbose, you do not need to enter all of the user's properties.

			{
			"primaryEmail": "liz@example.com",
			"name": {
			 "givenName": "Liz",
			 "familyName": "Smith"
			},
			"suspended": false,
			"password": "updated password",
			"hashFunction": "SHA-1",
			"changePasswordAtNextLogin": true,
			"ipWhitelisted": false,
			"ims": [
			 {
			  "type": "work",
			  "protocol": "gtalk",
			  "im": "newim@talk.example.com",
			  "primary": true
			 },
			 {
			  "type": "home",
			  "protocol": "aim",
			  "im": "newaim@aim.example.com",
			  "primary": false
			 }
			],
			"emails": [
			 {
			  "address": "liz@example.com",
			  "type": "home",
			  "customType": "",
			  "primary": true
			 }
			],
			"addresses": [
			 {
			  "type": "work",
			  "customType": "",
			  "streetAddress": "1600 Amphitheatre Parkway",
			  "locality": "Mountain View",
			  "region": "CA",
			  "postalCode": "94043"
			 }
			],
			"externalIds": [
			 {
			  "value": "12345",
			  "type": "custom",
			  "customType": "employee"
			 }
			],
			"relations": [
			 {
			  "value": "susan",
			  "type": "friend",
			  "customType": ""
			 }
			],
			"organizations": [
			 {
			  "name": "Google Inc.",
			  "title": "SWE",
			  "primary": true,
			  "type": "work",
			  "description": "Software engineer"
			 }
			],
			"phones": [
			 {
			  "value": "+1 206 555 nnnn",
			  "type": "work"
			 },
			 {
			  "value": "+1 602 555 nnnn",
			  "type": "home"
			 }
			],
			 "orgUnitPath": "/corp/engineering",
			 "includeInGlobalAddressList": true
			}

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable

		
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[System.String]$UserId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNull()]
		[System.Collections.Hashtable]$UserProperties,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$PassThru
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$UserId"
		[System.String]$Body = ConvertTo-Json -InputObject $UserProperties -Depth 3

		try
		{
			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Put -Body $Body -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell
			
			if ($PassThru)
			{
				[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content
			
				[System.Collections.Hashtable]$Temp = @{}
				foreach($Property in ($ParsedResponse | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name))
				{
					$Temp.Add($Property, $ParsedResponse.$Property)
				}

				Write-Output -InputObject $Temp
			}
		}
		catch [System.Net.WebException]
		{
			[System.Net.WebException]$Ex = $_.Exception
			[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
			[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
			[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
			[System.String]$Content = $Reader.ReadToEnd()
			[System.Int32]$StatusCode = $Response.StatusCode.value__
			[System.String]$Message = "$StatusCode : $Content"

			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
				Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $Message"
			}
		}
		catch [Exception] 
		{
			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				Write-Error -Exception $_.Exception -ErrorAction Stop
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $_.Exception.Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
			}
		}
	}

	End {
	}
}

Function Get-GoogleDirectoryUserList {
    [CmdletBinding()]
    Param(
		[Parameter(Mandatory = $true, ParameterSetName = "TokenDefault")]
		[Parameter(Mandatory = $true, ParameterSetName = "TokenDomain")]
		[Parameter(Mandatory = $true, ParameterSetName = "TokenCustomerId")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "ProfileDefault")]
		[Parameter(Mandatory = $true, ParameterSetName = "ProfileDomain")]
		[Parameter(Mandatory = $true, ParameterSetName = "ProfileCustomerId")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "ProfileDefault")]
		[Parameter(ParameterSetName = "ProfileDomain")]
		[Parameter(ParameterSetName = "ProfileCustomerId")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "ProfileDefault")]
		[Parameter(ParameterSetName = "ProfileDomain")]
		[Parameter(ParameterSetName = "ProfileCustomerId")]
		[Switch]$Persist,

        [Parameter()]
        [System.UInt32]$MaxResults,

		[Parameter(Mandatory = $true, ParameterSetName = "TokenDomain")]
        [Parameter(Mandatory = $true, ParameterSetName = "ProfileDomain")]
        [ValidateNotNullOrEmpty()]
        [System.String]$Domain,

		[Parameter(Mandatory = $true, ParameterSetName = "TokenCustomerId")]
        [Parameter(Mandatory = $true, ParameterSetName = "ProfileCustomerId")]
        [ValidateNotNullOrEmpty()]
        [System.String]$CustomerId,

		[Parameter(ParameterSetName = "TokenDefault")]
		[Parameter(ParameterSetName = "ProfileDefault")]
		[Parameter(ParameterSetName = "TokenCustomerId")]
		[Parameter(ParameterSetName = "ProfileCustomerId")]
		[ValidateSet("email", "givenName", "familyName")]
		[System.String]$OrderBy,

		[Parameter(ParameterSetName = "TokenDefault")]
		[Parameter(ParameterSetName = "ProfileDefault")]
		[Parameter(ParameterSetName = "TokenCustomerId")]
		[Parameter(ParameterSetName = "ProfileCustomerId")]
		[ValidateSet("ascending", "descending")]
		[System.String]$SortOrder,

		[Parameter(ParameterSetName = "TokenDefault")]
		[Parameter(ParameterSetName = "ProfileDefault")]
		[Parameter(ParameterSetName = "TokenCustomerId")]
		[Parameter(ParameterSetName = "ProfileCustomerId")]
		[ValidateNotNullOrEmpty()]
		[System.String]$Query,

		[Parameter()]
		[Switch]$ShowDeleted
    )

    Begin {
    }

    Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -like "Profile*")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

        switch -regex ($PSCmdlet.ParameterSetName)
        {
			"^.*Default$" {
				$Base += "?customer=my_customer"
				break
			}
            "^.*Domain$" {
                $Base += "?domain=$([System.Uri]::EscapeUriString($Domain))"
                break
            }
            "^.*CustomerId$" {
                $Base += "?customer=$([System.Uri]::EscapeUriString($CustomerId))"
                break
            }
			default {
				Write-Error -Message "Unknown parameter set $($PSCmdlet.ParameterSetName) for $($MyInvocation.MyCommand)." -ErrorAction Stop
			}
        }

        if ($PSBoundParameters.ContainsKey("MaxResults") -and $MaxResults -gt 0)
        {
            $Base += "&maxResults=$MaxResults"
        }

		if ($PSBoundParameters.ContainsKey("OrderBy"))
		{
			$Base += "&orderBy=$OrderBy"

			if ($PSBoundParameters.ContainsKey("SortOrder"))
			{
				$Base += "&sortOrder=$SortOrder"
			}
		}

		if ($ShowDeleted)
		{
			$Base += "&showDeleted=true"
		}

        $NextToken = $null
        [System.String]$Url = $Base
        [System.Collections.Hashtable[]]$Users = @()

        do {
            try
			{
				[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Get -Headers @{"Authorization" = "Bearer $BearerToken"} -ErrorAction Stop -UserAgent PowerShell
				[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content

				foreach ($User in $ParsedResponse.Users)
				{
					[System.Collections.Hashtable]$Temp = @{}
					foreach ($Property in ($User | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name))
					{
						$Temp.Add($Property, $User.$Property)
					}

					$Users += $Temp
				}

				$NextToken = $ParsedResponse.nextPageToken
				$Url = "$Base&pageToken=$NextToken"
			}
			catch [System.Net.WebException] 
			{
				$NextToken = $null

				[System.Net.WebException]$Ex = $_.Exception
				[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
				[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
				[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
				[System.String]$Content = $Reader.ReadToEnd()
				[System.Int32]$StatusCode = $Response.StatusCode.value__
				[System.String]$Message = "$StatusCode : $Content"

				if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
				{
					[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
					Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
				}
				elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
				{
					Write-Warning -Message $Message
				}
				else
				{
					Write-Verbose -Message "[ERROR] : $Message"
				}
			}
			catch [Exception] 
			{
				$NextToken = $null

				if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
				{
					Write-Error -Exception $_.Exception -ErrorAction Stop
				}
				elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
				{
					Write-Warning -Message $_.Exception.Message
				}
				else
				{
					Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
				}
			}

        } while ($NextToken -ne $null)

        Write-Output -InputObject $Groups 
    }

    End {

    }
}

Function Remove-GoogleDirectoryUser {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "HIGH")]
	[OutputType()]
	Param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[System.String]$UserId,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$Force
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$UserId"

		try
		{
			$ConfirmMessage = "You are about to delete GSuite user $UserId."
			$WhatIfDescription = "Deleted user $UserId"
			$ConfirmCaption = "Delete GSuite User"

			if ($Force -or $PSCmdlet.ShouldProcess($WhatIfDescription, $ConfirmMessage, $ConfirmCaption))
			{
				[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Delete -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell
			}
		}
		catch [System.Net.WebException]
		{
			[System.Net.WebException]$Ex = $_.Exception
			[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
			[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
			[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
			[System.String]$Content = $Reader.ReadToEnd()
			[System.Int32]$StatusCode = $Response.StatusCode.value__
			[System.String]$Message = "$StatusCode : $Content"

			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
				Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $Message"
			}
		}
		catch [Exception] 
		{
			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				Write-Error -Exception $_.Exception -ErrorAction Stop
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $_.Exception.Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
			}
		}
	}

	End {
	}
}

Function Restore-GoogleDirectoryUser {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "HIGH")]
	[OutputType()]
	Param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[System.String]$UserId,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$Force
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$UserId/undelete"

		try
		{
			$ConfirmMessage = "You are about to restore GSuite user $UserId."
			$WhatIfDescription = "Restored user $UserId"
			$ConfirmCaption = "Restore GSuite User"

			if ($Force -or $PSCmdlet.ShouldProcess($WhatIfDescription, $ConfirmMessage, $ConfirmCaption))
			{
				[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Post -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell
			}
		}
		catch [System.Net.WebException]
		{
			[System.Net.WebException]$Ex = $_.Exception
			[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
			[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
			[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
			[System.String]$Content = $Reader.ReadToEnd()
			[System.Int32]$StatusCode = $Response.StatusCode.value__
			[System.String]$Message = "$StatusCode : $Content"

			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
				Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $Message"
			}
		}
		catch [Exception] 
		{
			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				Write-Error -Exception $_.Exception -ErrorAction Stop
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $_.Exception.Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
			}
		}
	}

	End {
	}
}

Function Invoke-GoogleDirectoryMakeAdmin {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "HIGH")]
	[OutputType([System.Boolean])]
	Param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[System.String]$UserId,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$Force
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$UserId/makeAdmin"

		try
		{
			$ConfirmMessage = "You are about to make $UserId a super administrator."
			$WhatIfDescription = "Made user $UserId a super administrator"
			$ConfirmCaption = "Make Super Administrator"

			if ($Force -or $PSCmdlet.ShouldProcess($WhatIfDescription, $ConfirmMessage, $ConfirmCaption))
			{
				[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Get -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell
				[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content
			
				if ($Response.StatusCode -eq 200)
				{
					[System.Boolean]$Success = $ParsedResponse.status

					Write-Output -InputObject $Success
				}
				else
				{
					Write-Verbose -Message "[ERROR] : Make super administrator did not return a 200 response: $(ConvertTo-Json -InputObject $ParsedResponse)"
					Write-Output -InputObject $false
				}
			}
		}
		catch [System.Net.WebException]
		{
			[System.Net.WebException]$Ex = $_.Exception
			[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
			[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
			[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
			[System.String]$Content = $Reader.ReadToEnd()
			[System.Int32]$StatusCode = $Response.StatusCode.value__
			[System.String]$Message = "$StatusCode : $Content"

			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
				Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $Message"
			}
		}
		catch [Exception] 
		{
			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				Write-Error -Exception $_.Exception -ErrorAction Stop
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $_.Exception.Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
			}
		}
	}

	End {
	}
}

#endregion

#region User Aliases

Function New-GoogleDirectoryUserAlias {
	<#
		.SYNOPSIS
			Creates a new GSuite user alias.

		.DESCRIPTION
			
		
		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable

		
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNull()]
		[System.String]$UserId,

		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNull()]
		[System.String]$UserAlias,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$PassThru
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$UserId/aliases"
		[System.String]$Body = ConvertTo-Json -InputObject @{"alias" = $UserAlias} -Compress -Depth 3

		try
		{
			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Post -Body $Body -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell

			if ($PassThru)
			{
				[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content
			
				[System.Collections.Hashtable]$Temp = @{}
				foreach($Property in ($ParsedResponse | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name))
				{
					$Temp.Add($Property, $ParsedResponse.$Property)
				}

				Write-Output -InputObject $Temp
			}
		}
		catch [System.Net.WebException]
		{
			[System.Net.WebException]$Ex = $_.Exception
			[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
			[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
			[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
			[System.String]$Content = $Reader.ReadToEnd()
			[System.Int32]$StatusCode = $Response.StatusCode.value__
				
			[System.String]$Message = "$StatusCode : $Content"

			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
				Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $Message"
			}
				
		}
		catch [Exception] 
		{
			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				Write-Error -Exception $_.Exception -ErrorAction Stop
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $_.Exception.Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
			}
		}
	}

	End {
	}
}

Function Get-GoogleDirectoryUserAlias {
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable[]])]
	Param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[System.String]$UserId,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$UserId/aliases"
		[System.Collections.Hashtable[]]$Aliases = @()

		try
		{
			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Get -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell
			[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content
			
			foreach ($Alias in $ParsedResponse.aliases)
			{
				[System.Collections.Hashtable]$Temp = @{}

				foreach ($Property in ($Alias | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name))
				{
					$Temp.Add($Property, $Alias.$Property)
				}

				$Aliases += $Temp
			}

			Write-Output -InputObject $Aliases
		}
		catch [System.Net.WebException]
		{
			[System.Net.WebException]$Ex = $_.Exception
			[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
			[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
			[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
			[System.String]$Content = $Reader.ReadToEnd()
			[System.Int32]$StatusCode = $Response.StatusCode.value__
			[System.String]$Message = "$StatusCode : $Content"

			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
				Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $Message"
			}
		}
		catch [Exception] 
		{
			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				Write-Error -Exception $_.Exception -ErrorAction Stop
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $_.Exception.Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
			}
		}
	}

	End {
	}
}

Function Remove-GoogleDirectoryUserAlias {
	[CmdletBinding()]
	[OutputType()]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[System.String]$UserId,

		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullOrEmpty()]
		[System.String]$UserAlias,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$UserId/aliases/$UserAlias"
		[System.Collections.Hashtable[]]$Aliases = @()

		try
		{
			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Delete -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell			
		}
		catch [System.Net.WebException]
		{
			[System.Net.WebException]$Ex = $_.Exception
			[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
			[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
			[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
			[System.String]$Content = $Reader.ReadToEnd()
			[System.Int32]$StatusCode = $Response.StatusCode.value__
			[System.String]$Message = "$StatusCode : $Content"

			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
				Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $Message"
			}
		}
		catch [Exception] 
		{
			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				Write-Error -Exception $_.Exception -ErrorAction Stop
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $_.Exception.Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
			}
		}
	}

	End {
	}
}

#endregion

#region User Photos

Function Get-GoogleDirectoryUserPhoto {
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[System.String]$UserId,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[System.String]$OutFile,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -like "Profile*")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$UserId/photos/thumbnail"

		try
		{
			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Get -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell
			[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content
			
			if (-not [System.String]::IsNullOrEmpty($ParsedResponse.photoData))
			{
				# Replace the padding at the end, "." is used, so needs to be replace with "="
				for ($i = $ParsedResponse.photoData.Length - 1; $i -ge 0; $i += -1)
				{
					if ($ParsedResponse.photoData[$i] -eq '.')
					{
						$ParsedResponse.photoData[$i] = '='
					}
					else
					{
						break
					}
				}

				# Remove the google web safe base64 encoding
				$ParsedResponse.photoData = $ParsedResponse.photoData.Replace("_", "/").Replace("-", "+").Replace("*", "=")

				if (-not [System.String]::IsNullOrEmpty($OutFile))
				{
					# This will create the file and folder structure if not already present
					if (-not (Test-Path -Path $OutFile))
					{
						New-Item -Path $OutFile -ItemType File -Force | Out-Null
					}

					Set-Content -Path $OutFile -Value ([System.Convert]::FromBase64String($ParsedResponse.photoData)) -Encoding Byte
				}
			}

			[System.Collections.Hashtable]$Temp = @{}
			foreach ($Property in ($ParsedResponse | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name))
			{
				$Temp.Add($Property, $ParsedResponse.$Property)
			}

			Write-Output -InputObject $Temp
		}
		catch [System.Net.WebException]
		{
			[System.Net.WebException]$Ex = $_.Exception
			[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
			[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
			[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
			[System.String]$Content = $Reader.ReadToEnd()
			[System.Int32]$StatusCode = $Response.StatusCode.value__
			[System.String]$Message = "$StatusCode : $Content"

			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
				Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $Message"
			}
		}
		catch [Exception] 
		{
			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				Write-Error -Exception $_.Exception -ErrorAction Stop
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $_.Exception.Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
			}
		}
	}

	End {
	}
}

Function Set-GoogleDirectoryUserPhoto {
	[CmdletBinding()]
	[OutputType()]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[System.String]$UserId,

		[Parameter(Mandatory = $true)]
		[ValidateScript({
			Test-Path -Path $_
		})]
		[System.String]$Path,

		[Parameter()]
		[Switch]$PassThru,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$UserId/photos/thumbnail"

		[System.String]$Data = [System.Convert]::ToBase64String((Get-Content -Path $Path -Encoding Byte -Raw))

		# Replace the padding at the end, "." is used for google, so needs to replace "="
		for ($i = $ParsedResponse.photoData.Length - 1; $i -ge 0; $i += -1)
		{
			if ($ParsedResponse.photoData[$i] -eq '=')
			{
				$ParsedResponse.photoData[$i] = '.'
			}
			else
			{
				break
			}
		}
		
		# Now replace the other characters
		$Data = $Data.Replace("/", "_").Replace("+", "-").Replace("=", "*")

		[System.String]$Body = ConvertTo-Json -InputObject (@{"photoData" = $Data}) -Compress

		try
		{
			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Put -Body $Body -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell
			
			if ($PassThru)
			{
				[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content
			
				if (-not [System.String]::IsNullOrEmpty($ParsedResponse.photoData))
				{
					# Replace the padding at the end, "." is used, so needs to be replace with "="
					for ($i = $ParsedResponse.photoData.Length - 1; $i -ge 0; $i += -1)
					{
						if ($ParsedResponse.photoData[$i] -eq '.')
						{
							$ParsedResponse.photoData[$i] = '='
						}
						else
						{
							break
						}
					}

					# Remove the google web safe base64 encoding
					$ParsedResponse.photoData = $ParsedResponse.photoData.Replace("_", "/").Replace("-", "+").Replace("*", "=")
				}

				[System.Collections.Hashtable]$Temp = @{}
				foreach ($Property in ($ParsedResponse | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name))
				{
					$Temp.Add($Property, $ParsedResponse.$Property)
				}

				Write-Output -InputObject $Temp
			}
		}
		catch [System.Net.WebException]
		{
			[System.Net.WebException]$Ex = $_.Exception
			[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
			[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
			[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
			[System.String]$Content = $Reader.ReadToEnd()
			[System.Int32]$StatusCode = $Response.StatusCode.value__
			[System.String]$Message = "$StatusCode : $Content"

			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
				Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $Message"
			}
		}
		catch [Exception] 
		{
			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				Write-Error -Exception $_.Exception -ErrorAction Stop
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $_.Exception.Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
			}
		}
	}

	End {
	}
}

Function Remove-GoogleDirectoryUserPhoto {
	[CmdletBinding()]
	[OutputType()]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[System.String]$UserId,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = "Profile")]
		[ValidateNotNullOrEmpty()]
		[System.String]$ClientId,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist
	)

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$UserId/photos/thumbnail"

		try
		{
			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Delete -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell
		}
		catch [System.Net.WebException]
		{
			[System.Net.WebException]$Ex = $_.Exception
			[System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]($Ex.Response)
			[System.IO.Stream]$Stream = $Ex.Response.GetResponseStream()
			[System.IO.StreamReader]$Reader = New-Object -TypeName System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
			[System.String]$Content = $Reader.ReadToEnd()
			[System.Int32]$StatusCode = $Response.StatusCode.value__
			[System.String]$Message = "$StatusCode : $Content"

			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				[System.Web.HttpException]$NewEx = New-Object -TypeName System.Web.HttpException($Content, $StatusCode)
				Write-Error -Exception $NewEx -Category NotSpecified -ErrorId $StatusCode
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $Message"
			}
		}
		catch [Exception] 
		{
			if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Stop)
			{
				Write-Error -Exception $_.Exception -ErrorAction Stop
			}
			elseif ($ErrorActionPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue)
			{
				Write-Warning -Message $_.Exception.Message
			}
			else
			{
				Write-Verbose -Message "[ERROR] : $($_.Exception.Message)"
			}
		}
	}

	End {
	}
}

#endregion