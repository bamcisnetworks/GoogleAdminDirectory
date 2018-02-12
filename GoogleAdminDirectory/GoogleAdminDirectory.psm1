$script:GroupBaseUrl = "https://www.googleapis.com/admin/directory/v1/groups"
$script:UserBaseUrl = "https://www.googleapis.com/admin/directory/v1/users"
$script:OUBaseUrl = "https://www.googleapis.com/admin/directory/v1/customer"
$script:UserAgent = "PowerShell"
$script:UserAgentGzip = "PowerShell (gzip)"

#region Groups

Function New-GoogleDirectoryGroup {
	<#
		.SYNOPSIS
			Creates a new GSuite group.

		.DESCRIPTION
			This cmdlet creates a new GSuite group.

		.PARAMETER Email
			The group's email address.

		.PARAMETER Name
			The group's display name.

		.PARAMETER Description
			An optional description for the group.

		.PARAMETER PassThru
			If specified, the newly created group is passed to the pipeline.

		.PARAMETER UseCompression
			If specified, the returned data is compressed using gzip.

		.PARAMETER BearerToken
			The bearer token to use to authenticate the request.

		.PARAMETER ClientId
			The client Id of the stored profile that contains the bearer token used to authenticate
			the request. The cmdlet will automatically update or refresh the access token if necessary (and is
			possible based on the other data stored in the profile).

		.PARAMETER ProfileLocation
			The location where stored credentials are located. If this is not specified, the default location will be used.

		.PARAMETER Persist
			Indicates that the newly retrieved token(s) or refreshed token and associated client data like client secret
			are persisted to disk.

		.EXAMPLE
			$NewGroup = New-GoogleDirectoryGroup -Email examplegroup@google.com -Name "Example Group" -Description "A new group" -ClientId $Id -PassThru -Persist

			This example creates a new group and returns the newly created group details to the pipeline. The call is authenticated with
			an access token stored in a client profile, which is refreshed if necessary. Any updated tokens are persisted to disk.

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/6/2018
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

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$PassThru,

		[Parameter()]
		[Switch]$UseCompression
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
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
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Post -Body $Body -Headers $Headers -UserAgent $UserAgent

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
			This cmdlet updates a GSuite group.

		.PARAMETER GroupKey
			The unique Id of the group.

		.PARAMETER Email
			The group's new email address.

		.PARAMETER Name
			The group's new display name.

		.PARAMETER Description
			An updated description for the group.

		.PARAMETER PassThru
			If specified, the updated group is passed to the pipeline.

		.PARAMETER UseCompression
			If specified, the returned data is compressed using gzip.

		.PARAMETER BearerToken
			The bearer token to use to authenticate the request.

		.PARAMETER ClientId
			The client Id of the stored profile that contains the bearer token used to authenticate
			the request. The cmdlet will automatically update or refresh the access token if necessary (and is
			possible based on the other data stored in the profile).

		.PARAMETER ProfileLocation
			The location where stored credentials are located. If this is not specified, the default location will be used.

		.PARAMETER Persist
			Indicates that the newly retrieved token(s) or refreshed token and associated client data like client secret
			are persisted to disk.

		.EXAMPLE
			Set-GoogleDirectoryGroup -GroupKey NNN -Email updatedemail@google.com -ClientId $Id -Persist

			Updates the group uniquely identified by NNN with a new email, updatedemail@google.com. The call is authenticated with
			an access token stored in a client profile, which is refreshed if necessary. Any updated tokens are persisted to disk.

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/6/2018
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

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$PassThru,

		[Parameter()]
		[Switch]$UseCompression
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
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
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Put -Body $Body -Headers $Headers -UserAgent $UserAgent

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
			This cmdlet creates a new alias for a GSuite group.

		.PARAMETER GroupKey
			The unique Id of the group.

		.PARAMETER Alias
			The alias to create.

		.PARAMETER PassThru
			If specified, the updated group information is passed to the pipeline.

		.PARAMETER UseCompression
			If specified, the returned data is compressed using gzip.

		.PARAMETER BearerToken
			The bearer token to use to authenticate the request.

		.PARAMETER ClientId
			The client Id of the stored profile that contains the bearer token used to authenticate
			the request. The cmdlet will automatically update or refresh the access token if necessary (and is
			possible based on the other data stored in the profile).

		.PARAMETER ProfileLocation
			The location where stored credentials are located. If this is not specified, the default location will be used.

		.PARAMETER Persist
			Indicates that the newly retrieved token(s) or refreshed token and associated client data like client secret
			are persisted to disk.

		.EXAMPLE
			New-GoogleDirectoryGroupAlias -GroupKey NNN -Alias bestgroupalias@google.com -ClientId $Id -Persist

			Creates a new alias for the group identified by the unique id NNN.

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/6/2018
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

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$PassThru,

		[Parameter()]
		[Switch]$UseCompression
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$GroupKey/aliases"

		[System.String]$Body = ConvertTo-Json -InputObject @{"alias" = $Alias } -Compress -Depth 3

		try
		{
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Post -Body $Body -Headers $Headers -UserAgent $UserAgent

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
			Gets all GSuite group aliases for a specified group.

		.DESCRIPTION
			This cmdlet gets all of the aliases assigned to the specified group.

		.PARAMETER GroupKey
			The unique Id of the group.

		.PARAMETER UseCompression
			If specified, the returned data is compressed using gzip.

		.PARAMETER BearerToken
			The bearer token to use to authenticate the request.

		.PARAMETER ClientId
			The client Id of the stored profile that contains the bearer token used to authenticate
			the request. The cmdlet will automatically update or refresh the access token if necessary (and is
			possible based on the other data stored in the profile).

		.PARAMETER ProfileLocation
			The location where stored credentials are located. If this is not specified, the default location will be used.

		.PARAMETER Persist
			Indicates that the newly retrieved token(s) or refreshed token and associated client data like client secret
			are persisted to disk.

		.EXAMPLE
			$Aliases = Get-GoogleDirectoryGroupAlias -GroupKey NNN -ClientId $Id -Persist

			Gets a list of all group aliases for the group identified by NNN.

		.INPUTS 
			None
		
		.OUTPUTS
			System.Collection.Hashtable[]

			Each hashtable will follow this format:

			{
			  "kind": "admin#directory#alias",
			  "id": string,
			  "etag": etag,
			  "primaryEmail": string,
			  "alias": string
			}

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/6/2018
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

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$UseCompression
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$GroupKey/aliases"

		try
		{
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Get -Headers $Headers -UserAgent $UserAgent

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
			This cmdlet deletes a specified alias from the GSuite group.

		.PARAMETER GroupKey
			The unique Id of the group.

		.PARAMETER AliasId
			The id of the alias to delete.

		.PARAMETER BearerToken
			The bearer token to use to authenticate the request.

		.PARAMETER ClientId
			The client Id of the stored profile that contains the bearer token used to authenticate
			the request. The cmdlet will automatically update or refresh the access token if necessary (and is
			possible based on the other data stored in the profile).

		.PARAMETER ProfileLocation
			The location where stored credentials are located. If this is not specified, the default location will be used.

		.PARAMETER Persist
			Indicates that the newly retrieved token(s) or refreshed token and associated client data like client secret
			are persisted to disk.

		.EXAMPLE
			Remove-GoogleDirectoryGroupAlias -GroupKey NNN -AliasId "mygroupalias@google.com" -ClientId $Id -Persist

			Removes the specified alias from the group.

		.INPUTS 
			None
		
		.OUTPUTS
			None

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/6/2018
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

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
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
			This cmdlet retrieves details about a specified GSuite group.

		.PARAMETER GroupKey
			The unique Id of the group.

		.PARAMETER UseCompression
			If specified, the returned data is compressed using gzip.

		.PARAMETER BearerToken
			The bearer token to use to authenticate the request.

		.PARAMETER ClientId
			The client Id of the stored profile that contains the bearer token used to authenticate
			the request. The cmdlet will automatically update or refresh the access token if necessary (and is
			possible based on the other data stored in the profile).

		.PARAMETER ProfileLocation
			The location where stored credentials are located. If this is not specified, the default location will be used.

		.PARAMETER Persist
			Indicates that the newly retrieved token(s) or refreshed token and associated client data like client secret
			are persisted to disk.

		.EXAMPLE
			$Group = Get-GoogleDirectoryGroup -GroupKey NNN -ClientId $Id -Persist

			Gets details about the group specified by key NNN.

		.INPUTS 
			None
		
		.OUTPUTS
			System.Collections.Hashtable

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/6/2018
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

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$UseCompression
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$GroupKey"

		try
		{
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Get -Headers $Headers -UserAgent $UserAgent

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
	<#
		.SYNOPSIS
			Gets a list of GSuite groups.

		.DESCRIPTION
			This cmdlet retrieves details about GSuite groups based on a customer id or domain id. The cmdlet defaults to using
			my_customer as the customer id, which uses the customer id of the user making the API call.

		.PARAMETER MaxResults
			The maximum number of results returned in a single call. Specifying a non-zero value for this parameter will page
			the results so that multiple HTTP calls are made to retrieve all of the results.

		.PARAMETER Domain
			Retrieves all groups for this sub-domain.

		.PARAMETER CustomerId
			Retrieves all groups in the account for this customer. This is the default and uses the value my_customer, which
			represents the customer id of the administrator making the API call.
		
		.PARAMETER UseCompression
			If specified, the returned data is compressed using gzip.

		.PARAMETER BearerToken
			The bearer token to use to authenticate the request.

		.PARAMETER ClientId
			The client Id of the stored profile that contains the bearer token used to authenticate
			the request. The cmdlet will automatically update or refresh the access token if necessary (and is
			possible based on the other data stored in the profile).

		.PARAMETER ProfileLocation
			The location where stored credentials are located. If this is not specified, the default location will be used.

		.PARAMETER Persist
			Indicates that the newly retrieved token(s) or refreshed token and associated client data like client secret
			are persisted to disk.

		.EXAMPLE
			$Groups = Get-GoogleDirectoryGroupList -ClientId $Id -Persist -UseCompression

			Gets a listing of all of the groups for the admin using the cmdlet. The results are returned using gzip to minimize
			bandwidth utilization.

		.INPUTS 
			None
		
		.OUTPUTS
			System.Collections.Hashtable[]

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/6/2018
	#>
    [CmdletBinding()]
	[OutputType([System.Collections.Hashtable[]])]
    Param(
		[Parameter(Mandatory = $true, ParameterSetName = "TokenDefault")]
		[Parameter(Mandatory = $true, ParameterSetName = "TokenDomain")]
		[Parameter(Mandatory = $true, ParameterSetName = "TokenCustomerId")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

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

		[Parameter()]
		[Switch]$UseCompression
    )

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("ProfileDomain", "ProfileDefault", "ProfileCustomerId") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

    Begin {
    }

    Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -like "Profile*")
		{
			$ClientId = $PSBoundParameters["ClientId"]
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

		$Headers = @{"Authorization" = "Bearer $BearerToken"}
		$UserAgent = $script:UserAgent

		if ($UseCompression)
		{
			$UserAgent = $script:UserAgentGzip
			$Headers.Add("Accept-Encoding", "gzip")
		}

        do {
            try
			{
				[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Get -Headers $Headers -ErrorAction Stop -UserAgent $UserAgent
				
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
			Gets a list of GSuite groups assigned to a specified user.

		.DESCRIPTION
			This cmdlet retrieves details about GSuite groups assigned to a specified user.

		.PARAMETER MaxResults
			The maximum number of results returned in a single call. Specifying a non-zero value for this parameter will page
			the results so that multiple HTTP calls are made to retrieve all of the results.

		.PARAMETER UserId
			The id of the member to retrieve groups for. A member can either be a user or a group. The userKey can be the user's primary email address, 
			the user's alias email address, a group's primary email address, a group's email alias, or the user's unique id.
		
		.PARAMETER UseCompression
			If specified, the returned data is compressed using gzip.

		.PARAMETER BearerToken
			The bearer token to use to authenticate the request.

		.PARAMETER ClientId
			The client Id of the stored profile that contains the bearer token used to authenticate
			the request. The cmdlet will automatically update or refresh the access token if necessary (and is
			possible based on the other data stored in the profile).

		.PARAMETER ProfileLocation
			The location where stored credentials are located. If this is not specified, the default location will be used.

		.PARAMETER Persist
			Indicates that the newly retrieved token(s) or refreshed token and associated client data like client secret
			are persisted to disk.

		.EXAMPLE
			$Groups = Get-GoogleDirectoryGroupList -ClientId $Id -Persist -UseCompression

			Gets a listing of all of the groups for the admin using the cmdlet. The results are returned using gzip to minimize
			bandwidth utilization.

		.INPUTS 
			None
		
		.OUTPUTS
			System.Collections.Hashtable[]

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/6/2018
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

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$UseCompression
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Base = "$Base`?userKey=$UserId"
		$NextToken = $null
		[System.Collections.Hashtable[]]$Groups = @()

		$Headers = @{"Authorization" = "Bearer $BearerToken"}
		$UserAgent = $script:UserAgent

		if ($UseCompression)
		{
			$UserAgent = $script:UserAgentGzip
			$Headers.Add("Accept-Encoding", "gzip")
		}

		do
		{
			try
			{
				[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Get -Headers $Headers -UserAgent $UserAgent

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
			This cmdlet deletes a GSuite group.

		.PARAMETER GroupKey
			The unique Id of the group to delete.

		.PARAMETER BearerToken
			The bearer token to use to authenticate the request.

		.PARAMETER ClientId
			The client Id of the stored profile that contains the bearer token used to authenticate
			the request. The cmdlet will automatically update or refresh the access token if necessary (and is
			possible based on the other data stored in the profile).

		.PARAMETER ProfileLocation
			The location where stored credentials are located. If this is not specified, the default location will be used.

		.PARAMETER Persist
			Indicates that the newly retrieved token(s) or refreshed token and associated client data like client secret
			are persisted to disk.

		.EXAMPLE
			Remove-GoogleDirectoryGroup -GroupKey NNN -ClientId $Id -Persist

			Deletes the specified group.

		.INPUTS 
			None
		
		.OUTPUTS
			None

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/6/2018
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

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$Force
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
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

Function Add-GoogleDirectoryGroupMember {
	<#
		.SYNOPSIS
			Adds a member GSuite group.

		.DESCRIPTION
			This cmdlet adds a member to a GSuite group.

		.PARAMETER GroupKey
			The unique Id of the group.

		.PARAMETER Role
			The role to add the member as, either MEMBER, OWNER, or MANAGER. The default is MEMBER.

		.PARAMETER UserId
			The Id of the user to add to the group.

		.PARAMETER PassThru
			If specified, the member's membership information is passed to the pipeline.

		.PARAMETER UseCompression
			If specified, the returned data is compressed using gzip.

		.PARAMETER BearerToken
			The bearer token to use to authenticate the request.

		.PARAMETER ClientId
			The client Id of the stored profile that contains the bearer token used to authenticate
			the request. The cmdlet will automatically update or refresh the access token if necessary (and is
			possible based on the other data stored in the profile).

		.PARAMETER ProfileLocation
			The location where stored credentials are located. If this is not specified, the default location will be used.

		.PARAMETER Persist
			Indicates that the newly retrieved token(s) or refreshed token and associated client data like client secret
			are persisted to disk.

		.EXAMPLE
			$MembershipInfo = Add-GoogleDirectoryGroupMember -GroupKey NNN -UserId user@google.com -ClientId $Id -Persist -PassThru

			This example adds user@google.com to the group identified by NNN and returns the user's membership info for the group to 
			the pipeline. The call is authenticated with an access token stored in a client profile, which is refreshed if necessary. 
			Any updated tokens are persisted to disk.

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable

			This is an example of the member's membership information output:
			{
			   "kind": "directory#member",
			   "id": "group member's unique ID",
			   "email": "liz@example.com",
			   "role": "MEMBER",
			   "type": "GROUP"
			}

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/12/2018
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$GroupKey,

        [Parameter()]
        [ValidateSet("OWNER", "MANAGER", "MEMBER")]
        [System.String]$Role = "MEMBER",

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[System.String]$UserId,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$UseCompression
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$GroupKey/members"

		[System.String]$Body = ConvertTo-Json -InputObject @{"email" = $UserId; "role" = $Role } -Compress -Depth 3

		try
		{
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Post -Body $Body -Headers $Headers -UserAgent $UserAgent
			
			if ($PassThru)
			{
				[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content

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

Function Set-GoogleDirectoryGroupMemberRole {
	<#
		.SYNOPSIS
			Sets the role of a group member.

		.DESCRIPTION
			This cmdlet sets the role of an existing GSuite group member.

		.PARAMETER GroupKey
			The unique Id of the group.

		.PARAMETER Role
			The role the member will be set to, either MEMBER, OWNER, or MANAGER.

		.PARAMETER UserId
			The Id of the user whose role will be modified.

		.PARAMETER PassThru
			If specified, the member's membership information is passed to the pipeline.

		.PARAMETER UseCompression
			If specified, the returned data is compressed using gzip.

		.PARAMETER BearerToken
			The bearer token to use to authenticate the request.

		.PARAMETER ClientId
			The client Id of the stored profile that contains the bearer token used to authenticate
			the request. The cmdlet will automatically update or refresh the access token if necessary (and is
			possible based on the other data stored in the profile).

		.PARAMETER ProfileLocation
			The location where stored credentials are located. If this is not specified, the default location will be used.

		.PARAMETER Persist
			Indicates that the newly retrieved token(s) or refreshed token and associated client data like client secret
			are persisted to disk.

		.EXAMPLE
			$MembershipInfo = Set-GoogleDirectoryGroupMemberRole -GroupKey NNN -UserId user@google.com -Role MANAGER -ClientId $Id -Persist -PassThru

			This example changes the member user@google.com from MEMBER to MANAGER in the group identified by NNN and returns the user's membership info for the group to 
			the pipeline. The call is authenticated with an access token stored in a client profile, which is refreshed if necessary. 
			Any updated tokens are persisted to disk.

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable

			This is an example of the member's membership information output:
			{
			   "kind": "directory#member",
			   "id": "group member's unique ID",
			   "email": "liz@example.com",
			   "role": "MEMBER",
			   "type": "GROUP"
			}

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/12/2018
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$GroupKey,

        [Parameter(Mandatory = $true)]
        [ValidateSet("OWNER", "MANAGER", "MEMBER")]
        [System.String]$Role,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[System.String]$UserId,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$UseCompression,

		[Parameter()]
		[Switch]$PassThru
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$GroupKey/members/$UserId"

		[System.String]$Body = ConvertTo-Json -InputObject @{"email" = $UserId; "role" = $Role } -Compress -Depth 3

		try
		{
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Put -Body $Body -Headers $Headers -UserAgent $UserAgent
			[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content

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

Function Get-GoogleDirectoryGroupMembership {
	<#
		.SYNOPSIS
			Gets the membership of a GSuite group.

		.DESCRIPTION
			This cmdlet gets the membership of a GSuite group.

		.PARAMETER GroupKey
			The unique Id of the group.

		.PARAMETER Roles
			Filter the results to members with the specified roles. If this is not specified, no filter is applied.

		.PARAMETER MaxResults
			The maximum number of results returned in a single call. Specifying a non-zero value for this parameter will page
			the results so that multiple HTTP calls are made to retrieve all of the results.
			
		.PARAMETER UseCompression
			If specified, the returned data is compressed using gzip.

		.PARAMETER BearerToken
			The bearer token to use to authenticate the request.

		.PARAMETER ClientId
			The client Id of the stored profile that contains the bearer token used to authenticate
			the request. The cmdlet will automatically update or refresh the access token if necessary (and is
			possible based on the other data stored in the profile).

		.PARAMETER ProfileLocation
			The location where stored credentials are located. If this is not specified, the default location will be used.

		.PARAMETER Persist
			Indicates that the newly retrieved token(s) or refreshed token and associated client data like client secret
			are persisted to disk.

		.EXAMPLE
			$Membership = Get-GoogleDirectoryGroupMembership -GroupKey NNN -ClientId $Id -Persist -UseCompression

			This example gets the membership of the group specified by NNN and compresses the returned results. The call 
			is authenticated with an access token stored in a client profile, which is refreshed if necessary. Any updated tokens are persisted to disk.

		.INPUTS 
			System.String
		
		.OUTPUTS
			System.Collections.Hashtable[]

			This is an example of the membership information output:
			{
				"kind": "directory#member",
				"id": "group member's unique ID",
				"email": "liz@example.com",
				"role": "MANAGER",
				"type": "GROUP"
			},
			{
				"kind": "directory#member",
				"id": "group member's unique ID",
				"email": "radhe@example.com",
				"role": "MANAGER",
				"type": "MEMBER"
			}

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/12/2018
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable[]])]
    Param(
		[Parameter()]
        [System.UInt32]$MaxResults,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$GroupKey,

        [Parameter()]
        [ValidateSet("OWNER", "MANAGER", "MEMBER")]
        [System.String[]]$Roles = @("MEMBER"),

        [Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$UseCompression
    )

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

    Begin {
    }

    Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
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

		$Headers = @{"Authorization" = "Bearer $BearerToken"}
		$UserAgent = $script:UserAgent

		if ($UseCompression)
		{
			$UserAgent = $script:UserAgentGzip
			$Headers.Add("Accept-Encoding", "gzip")
		}

        do {
            try
			{
				[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Temp -Method Get -Headers $Headers -UserAgent $UserAgent
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

Function Remove-GoogleDirectoryGroupMember {
	<#
		.SYNOPSIS
			Removes a member from a GSuite group.

		.DESCRIPTION
			This cmdlet removes a member from a GSuite group.

		.PARAMETER GroupKey
			The unique Id of the group.

		.PARAMETER UserId
			The Id of the user to remove from the group.

		.PARAMETER BearerToken
			The bearer token to use to authenticate the request.

		.PARAMETER ClientId
			The client Id of the stored profile that contains the bearer token used to authenticate
			the request. The cmdlet will automatically update or refresh the access token if necessary (and is
			possible based on the other data stored in the profile).

		.PARAMETER ProfileLocation
			The location where stored credentials are located. If this is not specified, the default location will be used.

		.PARAMETER Persist
			Indicates that the newly retrieved token(s) or refreshed token and associated client data like client secret
			are persisted to disk.

		.EXAMPLE
			Remove-GoogleDirectoryGroupMember -GroupKey NNN -UserId user@google.com -ClientId $Id -Persist -UseCompression

			This example removes user@google.com from the group specified by NNN. The call is authenticated with an access 
			token stored in a client profile, which is refreshed if necessary. Any updated tokens are persisted to disk.

		.INPUTS 
			None
		
		.OUTPUTS
			None

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/12/2018
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$GroupKey,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[System.String]$UserId,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:GroupBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$GroupKey/members/$UserId"

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

		.PARAMETER User
			The properties of the user account to create. Only the required properties need to be specified.

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

		.PARAMETER MaximumRetries
			If the query rate for creation requests is too high, you might receive HTTP 503 responses from the API server 
			indicating that your quota has been exceeded. This value is the number of times the request will be retried
			using an exponential backoff.

		.PARAMETER PassThru
			If specified, the new user account properties are returned to the pipeline.
		
		.PARAMETER UseCompression
			If specified, the returned data is compressed using gzip.

		.PARAMETER BearerToken
			The bearer token to use to authenticate the request.

		.PARAMETER ClientId
			The client Id of the stored profile that contains the bearer token used to authenticate
			the request. The cmdlet will automatically update or refresh the access token if necessary (and is
			possible based on the other data stored in the profile).

		.PARAMETER ProfileLocation
			The location where stored credentials are located. If this is not specified, the default location will be used.

		.PARAMETER Persist
			Indicates that the newly retrieved token(s) or refreshed token and associated client data like client secret
			are persisted to disk.

		.EXAMPLE
			$NewUser = New-GoogleDirectoryUser -User $User -ClientId $Id -Persist -UseCompression -PassThru

			Creates a new GSuite user with the properties specified in the $User variable.

		.INPUTS 
			System.Collections.Hashtable
		
		.OUTPUTS
			None or System.Collections.Hashtable

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/12/2018
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[ValidateNotNull()]
		[System.Collections.Hashtable]$User,

		[Parameter()]
		[ValidateRange(1, 5)]
		[System.Int32]$MaximumRetries = 3,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$PassThru,

		[Parameter()]
		[Switch]$UseCompression
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$UserId"
		[System.String]$Body = ConvertTo-Json -InputObject $UserProperties -Compress -Depth 3

		$Success = $false
		$Counter = 0

		$Headers = @{"Authorization" = "Bearer $BearerToken"}
		$UserAgent = $script:UserAgent

		if ($UseCompression)
		{
			$UserAgent = $script:UserAgentGzip
			$Headers.Add("Accept-Encoding", "gzip")
		}

		while (-not $Success -and $Counter -le $MaximumRetries)
		{
			try
			{
				[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Post -Body $Body -Headers $Headers -UserAgent $UserAgent

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
	<#
		.SYNOPSIS
			Gets the properties of a GSuite user account.

		.DESCRIPTION
			This gets a GSuite user account.

		.PARAMETER UserId
			The id of the user to retrieve.			

		.PARAMETER UseCompression
			If specified, the returned data is compressed using gzip.

		.PARAMETER BearerToken
			The bearer token to use to authenticate the request.

		.PARAMETER ClientId
			The client Id of the stored profile that contains the bearer token used to authenticate
			the request. The cmdlet will automatically update or refresh the access token if necessary (and is
			possible based on the other data stored in the profile).

		.PARAMETER ProfileLocation
			The location where stored credentials are located. If this is not specified, the default location will be used.

		.PARAMETER Persist
			Indicates that the newly retrieved token(s) or refreshed token and associated client data like client secret
			are persisted to disk.

		.INPUTS 
			System.String
		
		.OUTPUTS
			System.Collections.Hashtable

			This is an example of the user output:
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

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/12/2018
	#>
	[CmdletBinding()]
	[OutputType()]
	Param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[System.String]$UserId,

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$UseCompression
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$UserId"

		try
		{
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Get -Headers $Headers -UserAgent $UserAgent
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

		.PARAMETER UserId
			The Id of the user to be updated.

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

		.PARAMETER UseCompression
			If specified, the returned data is compressed using gzip.

		.PARAMETER BearerToken
			The bearer token to use to authenticate the request.

		.PARAMETER ClientId
			The client Id of the stored profile that contains the bearer token used to authenticate
			the request. The cmdlet will automatically update or refresh the access token if necessary (and is
			possible based on the other data stored in the profile).

		.PARAMETER ProfileLocation
			The location where stored credentials are located. If this is not specified, the default location will be used.

		.PARAMETER Persist
			Indicates that the newly retrieved token(s) or refreshed token and associated client data like client secret
			are persisted to disk.

		.PARAMETER PassThru
			If specified, the updated user properties are returned to the pipeline.

		.EXAMPLE
			Set-GoogleDirectoryUser -UserId liz@example.com -UserProperties @{"name" = @{ "givenName" = "Elizabeth"; "familyName" = "Smith"} } -ClientId $Id -Persist

			Updates the name for the user liz@example.com.

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/12/2018
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

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$PassThru,

		[Parameter()]
		[Switch]$UseCompression
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$UserId"
		[System.String]$Body = ConvertTo-Json -InputObject $UserProperties -Depth 3

		try
		{
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Put -Body $Body -Headers $Headers -UserAgent $UserAgent
			
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
	<#
		.SYNOPSIS
			Gets a list of user account details. 

		.DESCRIPTION
			This cmdlet retrieves all users in a domain or for a specific customer Id. By default, the customer Id for the 
			current administrator is used and 100 results are returned per API call in alphabetical order of the user's email address.
		
			The cmdlet will continue to make API calls on your behalf until all user accounts are retrieved. This can be a lot of data
			and the use of the -UseCompression parameter is highly suggested.

		.PARAMETER MaxResults
			The maximum number of results returned in a single call. Specifying a non-zero value for this parameter will page
			the results so that multiple HTTP calls are made to retrieve all of the results. This defaults to 100.

		.PARAMETER Domain
			Retrieves all users for this sub-domain.

		.PARAMETER CustomerId
			Retrieves all users in the account for this customer. This is the default and uses the value my_customer, which
			represents the customer id of the administrator making the API call.

		.PARAMETER OrderBy
			Specifies the property used to order the results. This defaults to email.

		.PARAMETER SortOrder
			If an OrderBy property is specified, then this specifies the order the results are sorted in. If an OrderBy property
			is not specified, this property is ignored.

		.PARAMETER Query
			The optional query query string allows searching over many fields in a user profile, including both core and custom fields. 
			See https://developers.google.com/admin-sdk/directory/v1/guides/search-users for examples.

		.PARAMETER ShowDeleted
			If this is specified, users deleted within the last 5 days are shown instead of non-deleted users.

		.PARAMETER UseCompression
			If specified, the returned data is compressed using gzip.

		.PARAMETER BearerToken
			The bearer token to use to authenticate the request.

		.PARAMETER ClientId
			The client Id of the stored profile that contains the bearer token used to authenticate
			the request. The cmdlet will automatically update or refresh the access token if necessary (and is
			possible based on the other data stored in the profile).

		.PARAMETER ProfileLocation
			The location where stored credentials are located. If this is not specified, the default location will be used.

		.PARAMETER Persist
			Indicates that the newly retrieved token(s) or refreshed token and associated client data like client secret
			are persisted to disk.

		.PARAMETER PassThru
			If specified, the updated user properties are returned to the pipeline.

		.EXAMPLE
			$Users = Get-GoogleDirectoryUserList -ClientId $Id -Persist -UseCompression

			Gets all users in the same account as the administrator making the call. The results are compressed in flight.

		.INPUTS 
			None
		
		.OUTPUTS
			System.Collections.Hashtable[]

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/12/2018
	#>
    [CmdletBinding()]
    Param(
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
		[Switch]$ShowDeleted,

		[Parameter(Mandatory = $true, ParameterSetName = "TokenDefault")]
		[Parameter(Mandatory = $true, ParameterSetName = "TokenDomain")]
		[Parameter(Mandatory = $true, ParameterSetName = "TokenCustomerId")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(ParameterSetName = "ProfileDefault")]
		[Parameter(ParameterSetName = "ProfileDomain")]
		[Parameter(ParameterSetName = "ProfileCustomerId")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "ProfileDefault")]
		[Parameter(ParameterSetName = "ProfileDomain")]
		[Parameter(ParameterSetName = "ProfileCustomerId")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$UseCompression
    )

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("ProfileDomain", "ProfileDefault", "ProfileCustomerId") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

    Begin {
    }

    Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -like "Profile*")
		{
			$ClientId = $PSBoundParameters["ClientId"]
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

		$Headers = @{"Authorization" = "Bearer $BearerToken"}
		$UserAgent = $script:UserAgent

		if ($UseCompression)
		{
			$UserAgent = $script:UserAgentGzip
			$Headers.Add("Accept-Encoding", "gzip")
		}

        do {
            try
			{
				[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Get -Headers $Headers -ErrorAction Stop -UserAgent $UserAgent
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

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$Force
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
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

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$Force
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
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

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$Force
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
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

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$PassThru,

		[Parameter()]
		[Switch]$UseCompression
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$UserId/aliases"
		[System.String]$Body = ConvertTo-Json -InputObject @{"alias" = $UserAlias} -Compress -Depth 3

		try
		{
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Post -Body $Body -Headers $Headers -UserAgent $UserAgent

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

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$UseCompression
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$UserId/aliases"
		[System.Collections.Hashtable[]]$Aliases = @()

		try
		{
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Get -Headers $Headers -UserAgent $UserAgent
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

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
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

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$UseCompression
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -like "Profile*")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$UserId/photos/thumbnail"

		try
		{
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Get -Headers $Headers -UserAgent $UserAgent
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

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$UseCompression
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
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
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Put -Body $Body -Headers $Headers -UserAgent $UserAgent
			
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

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:UserBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
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

#region Organizational Units

Function New-GoogleDirectoryOU {
	<#
		.SYNOPSIS
			Creates a new GSuite Organizational Unit.

		.DESCRIPTION

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable

		
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[System.String]$Name,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[System.String]$Description,

		# This can be empty to represent the top level
		[Parameter(Mandatory = $true)]
		[ValidateNotNull()]
		[AllowEmptyString()]
		[System.String]$ParentOrgUnitPath,

		[Parameter()]
		[Switch]$BlockInheritance,

		[Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]$CustomerId = "my_customer",

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$PassThru,

		[Parameter()]
		[Switch]$UseCompression
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:OUBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		if (-not $ParentOrgUnitPath.StartsWith("/"))
		{
			$ParentOrgUnitPath = "/$ParentOrgUnitPath"
		}

		if ($ParentOrgUnitPath.EndsWith("/"))
		{
			$ParentOrgUnitPath = $ParentOrgUnitPath.TrimEnd("/")
		}

		[System.String]$Url = "$Base/$CustomerId/orgunits"

		[System.Collections.Hashtable]$OU = @{"name" = $Name; "parentOrgUnitPath" = $ParentOrgUnitPath}

		if ($BlockInheritance)
		{
			$OU.Add("blockInheritance", $true)
		}

		if ($PSBoundParameters.ContainsKey("Description"))
		{
			$OU.Add("description", $Description)
		}

		[System.String]$Body = ConvertTo-Json -InputObject $OU -Compress -Depth 3

		try
		{
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Post -Body $Body -Headers $Headers -UserAgent $UserAgent

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

Function Set-GoogleDirectoryOU {
	<#
		.SYNOPSIS
			Updates a GSuite Organizational Unit.

		.DESCRIPTION

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable

		
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[System.String]$OrgUnitPath,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[System.String]$Name,

		# This can be empty to remove the description
		[Parameter()]
		[ValidateNotNull()]
		[System.String]$Description,

		# This can be empty to represent the top level
		[Parameter()]
		[ValidateNotNull()]
		[System.String]$ParentOrgUnitPath,

		[Parameter()]
		[Switch]$BlockInheritance,

		[Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]$CustomerId = "my_customer",

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$PassThru,

		[Parameter()]
		[Switch]$UseCompression
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:OUBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		if ([System.String]::IsNullOrEmpty($ParentOrgUnitPath) -and 
			[System.String]::IsNullOrEmpty($Description) -and 
			-not $PSBoundParameters.ContainsKey("BlockInheritance") -and
			[System.String]::IsNullOrEmpty($Name))
		{
			Write-Error -Exception (New-Object -TypeName System.ArgumentException("You must specify a property to update for the OU.")) -ErrorAction Stop
		}

		if ($OrgUnitPath.StartsWith("/"))
		{
			$OrgUnitPath = $OrgUnitPath.TrimStart("/")
		}

		if ($OrgUnitPath.EndsWith("/"))
		{
			$OrgUnitPath = $OrgUnitPath.TrimEnd("/")
		}

		[System.String]$Url = "$Base/$CustomerId/orgunits/$([System.Uri]::EscapeUriString($OrgUnitPath))"

		[System.Collections.Hashtable]$OU = @{}

		if ($BlockInheritance)
		{
			$OU.Add("blockInheritance", $true)
		}

		if ($PSBoundParameters.ContainsKey("Description"))
		{
			$OU.Add("description", $Description)
		}

		if (-not [System.String]::IsNullOrEmpty($Name))
		{
			$OU.Add("name", $Name)
		}

		if (-not [System.String]::IsNullOrEmpty($ParentOrgUnitPath))
		{
			if (-not $ParentOrgUnitPath.StartsWith("/"))
			{
				$ParentOrgUnitPath = "/$ParentOrgUnitPath"
			}

			if ($ParentOrgUnitPath.EndsWith("/"))
			{
				$ParentOrgUnitPath = $ParentOrgUnitPath.TrimEnd("/")
			}

			$OU.Add("parentOrgUnitPath", $ParentOrgUnitPath)
		}

		[System.String]$Body = ConvertTo-Json -InputObject $OU -Compress -Depth 3

		try
		{
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Put -Body $Body -Headers $Headers -UserAgent $UserAgent

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

Function Get-GoogleDirectoryOU {
	<#
		.SYNOPSIS
			Gets a GSuite Organizational Unit.

		.DESCRIPTION

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable

		
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(

		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[System.String]$OrgUnitPath,

		[Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]$CustomerId = "my_customer",

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$UseCompression
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:OUBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		if ($OrgUnitPath.StartsWith("/"))
		{
			$OrgUnitPath = $OrgUnitPath.TrimStart("/")
		}

		if ($OrgUnitPath.EndsWith("/"))
		{
			$OrgUnitPath = $OrgUnitPath.TrimEnd("/")
		}

		[System.String]$Url = "$Base/$CustomerId/orgunits/$([System.Uri]::EscapeUriString($OrgUnitPath))"

		try
		{
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Get -Headers $Headers -UserAgent $UserAgent

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

Function Get-GoogleDirectoryOUChildren {
	<#
		.SYNOPSIS
			Gets GSuite Organizational Unit children org units.

		.DESCRIPTION

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable

		
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(

		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[System.String]$OrgUnitPath,

		[Parameter()]
		[Switch]$All,

		[Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]$CustomerId = "my_customer",

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$UseCompression
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:OUBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		if ($OrgUnitPath.StartsWith("/"))
		{
			$OrgUnitPath = $OrgUnitPath.TrimStart("/")
		}

		if ($OrgUnitPath.EndsWith("/"))
		{
			$OrgUnitPath = $OrgUnitPath.TrimEnd("/")
		}

		[System.String]$Url = "$Base/$CustomerId/orgunits?orgUnitPath=$([System.Uri]::EscapeUriString($OrgUnitPath))"

		if ($All)
		{
			$Url += "&type=all"
		}
		else
		{
			$Url += "&type=children"
		}

		try
		{
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Get -Headers $Headers -UserAgent $UserAgent

			[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content
			
			[System.Collections.Hashtable[]]$OUs = @()

			foreach ($OU in $ParsedResponse.organizationalUnits)
			{
				[System.Collections.Hashtable]$Temp = @{}
				foreach($Property in ($OU | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name))
				{
					$Temp.Add($Property, $OU.$Property)
				}

				$OUs += $Temp
			}

			Write-Output -InputObject $OU
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

Function Remove-GoogleDirectoryOU {
	<#
		.SYNOPSIS
			Deletes a GSuite Organizational Unit.

		.DESCRIPTION

		.INPUTS 
			None
		
		.OUTPUTS
			None

		
	#>
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "HIGH")]
	[OutputType()]
	Param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[System.String]$OrgUnitPath,

		[Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]$CustomerId = "my_customer",

		[Parameter(Mandatory = $true, ParameterSetName = "Token")]
        [ValidateNotNullOrEmpty()]
        [System.String]$BearerToken,

		[Parameter(ParameterSetName = "Profile")]
		[System.String]$ProfileLocation,

		[Parameter(ParameterSetName = "Profile")]
		[Switch]$Persist,

		[Parameter()]
		[Switch]$Force
	)

	DynamicParam {
		New-DynamicParameter -Name "ClientId" -Type ([System.String]) -Mandatory -ParameterSets @("Profile") -ValidateNotNullOrEmpty -ValidateSet (Get-GoogleOAuth2Profile -ProfileLocation $ProfileLocation)
	}

	Begin {
	}

	Process {
		[System.String]$Base = $script:OUBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		if ($OrgUnitPath.StartsWith("/"))
		{
			$OrgUnitPath = $OrgUnitPath.TrimStart("/")
		}

		if ($OrgUnitPath.EndsWith("/"))
		{
			$OrgUnitPath = $OrgUnitPath.TrimEnd("/")
		}

		[System.String]$Url = "$Base/$CustomerId/orgunits/$([System.Uri]::EscapeUriString($OrgUnitPath))"

		try
		{
			$ConfirmMessage = "You are about to delete GSuite OU $OrgUnitPath."
			$WhatIfDescription = "Deleted OU $OrgUnitPath."
			$ConfirmCaption = "Delete GSuite OU"

			if ($Force -or $PSCmdlet.ShouldProcess($WhatIfDescription, $ConfirmMessage, $ConfirmCaption))
			{
				[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Delete -Headers @{"Authorization" = "Bearer $BearerToken"} -UserAgent PowerShell

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

#endregion