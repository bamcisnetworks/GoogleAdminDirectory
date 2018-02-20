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
			
				[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

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
				[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

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
			
				[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

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
				[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $Alias

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
			
			[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

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
					[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $Group

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
					[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $Group

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

				[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

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

			[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

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
					[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $Member

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
			
						[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

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
			The id of the user to retrieve.	The UserId can be the user's primary email address, the unique user id, or one of the user's alias email addresses.		

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
			
			[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

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
			The Id of the user to be updated. The UserId can be the user's primary email address, the unique user id, or one of the user's alias email addresses. 

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
			
				[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

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
					[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $User

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

        Write-Output -InputObject $Users 
    }

    End {

    }
}

Function Remove-GoogleDirectoryUser {
	<#
		.SYNOPSIS
			Deletes a GSuite user.

		.DESCRIPTION
			This cmdlet deletes a GSuite user. After the user is deleted, they will no longer be able to login in. A deleted
			user account can be restored within 5 days of deletion.

		.PARAMETER UserId
			The Id of the user to be deleted. The UserId can be the user's primary email address, the unique user id, or one of the user's alias email addresses. 

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
			Remove-GoogleDirectoryUser -UserId liz@example.com -ClientId $Id -Persist -Force

			This deletes the user liz@example.com using stored client credentials and bypasses confirmation.

		.INPUTS
			System.String

		.OUTPUTS
			None

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/12/2018
	#>
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
	<#
		.SYNOPSIS
			Restores a deleted GSuite user.

		.DESCRIPTION
			This cmdlet restores a deleted GSuite user that has been deleted within the last 5 days.

		.PARAMETER UserId
			The Id of the user to restore. The UserId is the unique user id found in the response of the retrieve 
			users deleted within the past 5 days operation. The user's primary email address or one of the user's 
			alias email addresses cannot be used in the UserId for this operation.

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
			Restore-GoogleDirectoryUser -UserId 12309329403209438205 -ClientId $Id -Persist -Force

			This restores (undeletes) the user 12309329403209438205 using stored client credentials and bypasses confirmation.

		.INPUTS
			System.String

		.OUTPUTS
			None

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/12/2018
	#>
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
	<#
		.SYNOPSIS
			Makes a GSuite users a super administrator.

		.DESCRIPTION
			This cmdlet elevates a user's permissions to the super administrator role.

		.PARAMETER UserId
			The Id of the user to make a super administrator. The UserId can be the user's primary email address, the unique user id, or one of the user's alias email addresses.

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
			Invoke-GoogleDirectoryMakeAdmin -UserId liz@example.com -ClientId $Id -Persist -Force

			This makes the user liz@example.com a super administrator using stored client credentials and bypasses confirmation.

		.INPUTS
			System.String

		.OUTPUTS
			None

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/12/2018
	#>
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
			Creates a new alias for a GSuite user.

		.DESCRIPTION
			This cmdlet creates a new alias for a GSuite user. The maximum number of aliases per user is 30.

		.PARAMETER UserId
			The Id of the user to create an alias for. The UserId can be the user's primary email address, the unique user id, or one of the user's alias email addresses.

		.PARAMETER UserAlias
			The email alias to create for the user, like elizabeth@example.com.

		.PARAMETER PassThru
			If specified the new user alias is returned to the pipeline.

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

		.PARAMETER UseCompression
			If specified, the returned data is compressed using gzip.

		.EXAMPLE
			New-GoogleDirectoryUserAlias -UserId liz@example.com -UserAlias elizabeth@example.com -ClientId $Id -Persist

			This creates a new alias, elizabeth@example.com, for the user liz@example.com using stored client credentials and bypasses confirmation.

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
			
				[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

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
	<#
		.SYNOPSIS
			Retrieves all of the aliases for a GSuite user.

		.DESCRIPTION
			This cmdlet retrieves all of the aliases for a GSuite user. All user aliases are returned in 
			alphabetical order. There is no page size such as the maxResults query string or pagination used 
			for the 'Retrieve all aliases' response. The returned aliases are the editable user email alias in 
			the account's primary domain or subdomains. 

		.PARAMETER UserId
			The Id of the user to get the aliases of. The UserId can be the user's primary email address, the unique user id, or one of the user's alias email addresses.

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

		.PARAMETER UseCompression
			If specified, the returned data is compressed using gzip.

		.EXAMPLE
			$Aliases = Get-GoogleDirectoryUserAlias -UserId liz@example.com -ClientId $Id -Persist

			Gets all of the aliases for the user liz@example.com using stored client credentials and bypasses confirmation.

		.INPUTS
			System.String

		.OUTPUTS
			System.Collections.Hashtable[]

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/12/2018
	#>
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
				[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $Alias

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
	<#
		.SYNOPSIS
			Deletes an alias for a GSuite user.

		.DESCRIPTION
			This cmdlet deletes a specified alias for a GSuite user.

		.PARAMETER UserId
			The Id of the user to delete an alias for. The UserId can be the user's primary email address, the unique user id, or one of the user's alias email addresses.

		.PARAMETER UserAlias
			The alias to delete. This parameter is the alias' email address that is being deleted.

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
			Remove-GoogleDirectoryUserAlias -UserId liz@example.com -UserAlias elizabeth@example.com -ClientId $Id -Persist -Force

			Deletes the elizabeth@example.com alias for the user liz@example.com using stored client credentials and bypasses confirmation.

		.INPUTS
			None

		.OUTPUTS
			None

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/12/2018
	#>
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
	<#
		.SYNOPSIS
			Gets one photo thumbnail for a GSuite user.

		.DESCRIPTION
			This cmdlet retrieves one photo thumbnail, the lastest Gmail Chat profile photo for a user. The details of the photo and
			the photo base64 data are returned to the pipeline. Optionally, the photo data can also be written out to a file. If you choose
			to write the photo data to a file, you should check the mimeType property returned with the object to make sure you use
			the correct file extension.

			The output photoData property of the object returned to the pipeline is web safe base64 encoded, meaning:

			- The slash (/) character is replaced with the underscore (_) character.
			- The plus sign (+) character is replaced with the hyphen (-) character.
			- The equals sign (=) character is replaced with the asterisk (*).
			- For padding, the period (.) character is used instead of the RFC-4648 baseURL definition which uses the equals sign (=) for padding. This is done to simplify URL-parsing.
			- Whatever the size of the photo being uploaded, the API downsizes it proportionally to 96x96 pixels.
		
		.PARAMETER UserId
			The Id of the user to get the photo of. The UserId can be the user's primary email address, the unique user id, or one of the user's alias email addresses.

		.PARAMETER OutFile
			The path to a file where the photo data will be written. If the directory path does not exist, it will be created.

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

		.PARAMETER UseCompression
			If specified, the returned data is compressed using gzip.

		.EXAMPLE
			$PhotoData = Get-GoogleDirectoryUserPhoto -UserId liz@example.com -ClientId $Id -Persist
				
			Gets the photo data for the user liz@example.com using stored client credentials and bypasses confirmation.

		.EXAMPLE
			$PhotoData = Get-GoogleDirectoryUserPhoto -OutFile "c:\users\liz\desktop\thumbnail.txt" -UserId liz@example.com -ClientId $Id -Persist
			$MimeType = $PhotoData["mimeType"]		

			Gets the photo data for the user liz@example.com using stored client credentials and bypasses confirmation. The base64 data
			is written to the specified file. The mimetype should be checked to adjust the extension of the output file to make it viewable.

		.INPUTS
			System.String

		.OUTPUTS
			System.Collections.Hashtable
		
			This is a JSON representation of the output data:
			{
			 "kind": "directory#user#photo",
			 "id": "the unique user id",
			 "primaryEmail": "liz@example.com",
			 "mimeType": "the photo mime type",
			 "height": "the photo height in pixels",
			 "width": "the photo width in pixels",
			 "photoData": "web safe base64 encoded photo data"
			}

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/12/2018
	#>
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

			[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

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
	<#
		.SYNOPSIS
			Sets the photo for a GSuite user.

		.DESCRIPTION
			This cmdlet updates a user's photo. In this version of the API, a photo is the user's 
			latest Gmail Chat profile photo. This is different from the Google+ profile photo. 
			When updating a photo, the height and width are ignored by the API.
		
		.PARAMETER UserId
			The Id of the user to set the photo of. The UserId can be the user's primary email address, the unique user id, or one of the user's alias email addresses.

		.PARAMETER Path
			The path to the file containing the photo to be uploaded. The file data will be converted to web safe base64.

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

		.PARAMETER UseCompression
			If specified, the returned data is compressed using gzip.

		.EXAMPLE
			$PhotoData = Set-GoogleDirectoryUserPhoto -UserId liz@example.com -Path c:\users\liz\desktop\photo.jpg -PassThru -ClientId $Id -Persist
				
			Sets the photo data for the user liz@example.com using stored client credentials and bypasses confirmation. The uploaded photo
			information is returned to the pipeline.

		.INPUTS
			None

		.OUTPUTS
			None or System.Collections.Hashtable
		
			This is a JSON representation of the output data:
			{
			 "kind": "directory#user#photo",
			 "id": "the unique user id",
			 "primaryEmail": "liz@example.com",
			 "mimeType": "the photo mime type",
			 "height": "the photo height in pixels",
			 "width": "the photo width in pixels",
			 "photoData": "web safe base64 encoded photo data"
			}

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/12/2018
	#>
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

				[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

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
	<#
		.SYNOPSIS
			Deletes a GSuite user's photo.

		.DESCRIPTION
			This cmdlet deletes a user's photo. Once deleted, the user's photo is not shown. 
			Wherever a user's photo is required, a silhouette will be shown instead.

		.PARAMETER UserId
			The Id of the user to delete the photo of. The UserId can be the user's primary email address, the unique user id, or one of the user's alias email addresses.

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
			Remove-GoogleDirectoryUserPhoto -UserId liz@example.com -ClientId $Id -Persist
				
			Deletes the photo for the user liz@example.com using stored client credentials and bypasses confirmation.

		.INPUTS
			None

		.OUTPUTS
			None

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/12/2018
	#>
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
			Creates a GSuite organizational unit.

		.DESCRIPTION
			This cmdlet creates a new organizational unit. 

		.PARAMETER Name
			The name of the new organizational unit.

		.PARAMETER Description
			An optional description of the organizational unit.

		.PARAMETER ParentOrgUnit
			The parent organizational unit to this new unit. This parameter must be the path of an existing organizational unit.

		.PARAMETER BlockInheritance
			If set, the new organizational unit will not receive policies inherited from its parent. 

		.PARAMETER CustomerId
			If you are an administrator creating an organizational unit, use my_customer. This is the default. If you 
			are reseller creating an organizational unit for a resold customer, use customerId. To retrieve the 
			customerId, use the Retrieve a user operation.

		.PARAMETER PassThru
			If specified, the new organizational unit properties are returned to the pipeline.
		
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
			$OU = New-GoogleDirectoryOU -Name Sales -ParentOrgUnit "/my_org/business" -ClientId $Id -Persist -UseCompression -PassThru

			Creates a new organizational unit called sales unit the parent /my_org/business.

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable

			This is a JSON representation of the output:

			{
				"kind": "directory#orgUnit",
				"name": "sales_support",
				"description": "The sales support team",
				"orgUnitPath": "/corp/support/sales_support",
				"parentOrgUnitPath": "/corp/support",
				"blockInheritance": false
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
		[System.String]$Name,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[System.String]$Description,

		[Parameter(Mandatory = $true)]
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
			
				[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

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
			Updates a GSuite organizational unit.

		.DESCRIPTION
			This cmdlet updates an organizational unit. 

			- You only need to submit the updated information in your request. You do not need to enter 
				all of the group's properties in the request.
			- If a user was not assigned to a specific organizational unit when the user account was created, 
				the account is in the top-level organizational unit.
			- You can move an organizational unit to another part of your account's organization structure 
				by setting the parentOrgUnitPath property in the request. It is important to note, that moving 
				an organizational unit can change the services and settings for the users in the organizational 
				unit being moved.

		.PARAMETER OrgUnitPath
			The path to the organizational unit to be modified.

		.PARAMETER Name
			The new name of the organizational unit.

		.PARAMETER Description
			The new description for the organizational unit.

		.PARAMETER ParentOrgUnit
			The new parent organization unit for this OU. Setting this parameter will move the OU within the OU tree structure.
			This parameter must be the path of an existing organizational unit.

		.PARAMETER BlockInheritance
			If set to true, the new organizational unit will not receive policies inherited from its parent. If set to false,
			the OU will received policies inherited from the OU tree.

		.PARAMETER CustomerId
			If you are an administrator updating an organizational unit, use my_customer. This is the default. If you 
			are reseller updating an organizational unit for a resold customer, use customerId. To retrieve the 
			customerId, use the Retrieve a user operation.

		.PARAMETER PassThru
			If specified, the updated organizational unit is returned to the pipeline.
		
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
			$OU = Set-GoogleDirectoryOU -Name CommercialSales -OrgUnitPath "/my_org/business/sales" -ClientId $Id -Persist -UseCompression -PassThru

			This examples updates the name of the OU 'sales' to 'commercialsales'.

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable

			This is a JSON representation of the output:

			{
				"kind": "directory#orgUnit",
				"name": "sales_support",
				"description": "The sales support team",
				"orgUnitPath": "/corp/support/sales_support",
				"parentOrgUnitPath": "/corp/support",
				"blockInheritance": false
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
		[System.String]$OrgUnitPath,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[System.String]$Name,

		# This can be empty to remove the description
		[Parameter()]
		[ValidateNotNull()]
		[System.String]$Description,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[System.String]$ParentOrgUnitPath,

		[Parameter()]
		[System.Boolean]$BlockInheritance,

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

		if ($PSBoundParameters.ContainsKey("BlockInheritance"))
		{
			$OU.Add("blockInheritance", $BlockInheritance)
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
			
				[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

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
			Gets a GSuite organizational unit.

		.DESCRIPTION
			This cmdlet gets an organizational unit details. 

		.PARAMETER OrgUnitPath
			The path to the organizational unit to retrieve.

		.PARAMETER CustomerId
			If you are an administrator getting an organizational unit, use my_customer. This is the default. If you 
			are reseller getting an organizational unit for a resold customer, use customerId. To retrieve the 
			customerId, use the Retrieve a user operation.

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
			$OU = Get-GoogleDirectoryOU -OrgUnitPath "/my_org/business/sales" -ClientId $Id -Persist -UseCompression

			This examples gets the org unit details for the 'sales' OU.

		.INPUTS 
			System.String
		
		.OUTPUTS
			None or System.Collections.Hashtable

			This is a JSON representation of the output:

			{
				"kind": "directory#orgUnit",
				"name": "sales_support",
				"description": "The sales support team",
				"orgUnitPath": "/corp/support/sales_support",
				"parentOrgUnitPath": "/corp/support",
				"blockInheritance": false
			}

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/12/2018
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
			
			[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

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
			Gets a GSuite organizational unit children organizational units.

		.DESCRIPTION
			This cmdlet gets the children of an organizational unit. This defaults only to direct children, but
			if the -All parameter is specified, all children are enumerated recursively through the tree structure.

		.PARAMETER OrgUnitPath
			The path to the organizational unit to retrieve children from.

		.PARAMETER All
			If specified, all of the children in the tree structure are returned, not just the direct children of the OU.

		.PARAMETER CustomerId
			If you are an administrator, use my_customer. This is the default. If you 
			are reseller getting an OU for a resold customer, use customerId. To retrieve the 
			customerId, use the Retrieve a user operation.

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
			$Children = Get-GoogleDirectoryOUChildren -OrgUnitPath "/my_org/business/sales" -ClientId $Id -Persist -UseCompression

			This examples gets the direct children of the 'sales' OU.

		.EXAMPLE
			$Children = Get-GoogleDirectoryOUChildren -OrgUnitPath "/my_org/business/sales" -All -ClientId $Id -Persist -UseCompression

			This examples gets all of the children of the 'sales' OU.

		.INPUTS 
			System.String
		
		.OUTPUTS
			System.Collections.Hashtable[]

			This is a JSON representation of the output:

			[
				{
					"kind": "directory#orgUnit",
					"name": "sales",
					"description": "The corporate sales team",
					"orgUnitPath": "/corp/sales",
					"parentOrgUnitPath": "/corp",
					"blockInheritance": false
				},
				{
					"kind": "directory#orgUnit",
					"name": "frontline sales",
					"description": "The frontline sales team",
					"orgUnitPath": "/corp/sales/frontline sales",
					"parentOrgUnitPath": "/corp/sales",
					"blockInheritance": false
				},
				{
					"kind": "directory#orgUnit",
					"name": "support",
					"description": "The corporate support team",
					"orgUnitPath": "/corp/support",
					"parentOrgUnitPath": "/corp",
					"blockInheritance": false
				},
				{
					"kind": "directory#orgUnit",
					"name": "sales_support",
					"description": "The BEST support team",
					"orgUnitPath": "/corp/support/sales_support",
					"parentOrgUnitPath": "/corp/support",
					"blockInheritance": false
				}
		  ]

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/12/2018
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
				[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

				$OUs += $Temp
			}

			Write-Output -InputObject $OUs
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
			Delets a GSuite organizational unit.

		.DESCRIPTION
			This cmdlet deletes an orgaizational unit. You can only delete organizational units 
			that do not have any child organizational units or any users assigned to them. You 
			need to reassign users to other organizational units and remove any child organizational 
			units before deleting.

		.PARAMETER OrgUnitPath
			The path to the organizational unit to delete.

		.PARAMETER CustomerId
			If you are an administrator deleting an organizational unit, use my_customer. This is the default. If you 
			are reseller deleting an organizational unit for a resold customer, use customerId. To retrieve the 
			customerId, use the Retrieve a user operation.

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
			Remove-GoogleDirectoryOU -OrgUnitPath "/my_org/business/sales" -Force -ClientId $Id -Persist -UseCompression

			This examples deletes the 'sales' OU and bypasses confirmation.

		.INPUTS 
			System.String
		
		.OUTPUTS
			None

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/12/2018
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

#region Roles

Function Get-GoogleDirectoryPrivileges {
	<#
		.SYNOPSIS
			Gets a list of supported privileges.

		.DESCRIPTION
			This cmdlet gets a list of supported privileges. 

		.PARAMETER CustomerId
			If you are an administrator getting privileges in your own domain, use my_customer as the customer ID. This is the default.
			If you are reseller getting privileges for one of your customers, use the customer ID returned by the Retrieve a user operation.

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
			$Privileges = Get-GoogleDirectoryPrivileges -ClientId $Id -Persist -UseCompression

			This examples gets the supported privileges for the account supporting the current administrator.

		.INPUTS 
			None
		
		.OUTPUTS
			System.Collections.Hashtable[]

			This is a JSON representation of the output:
			[
				{
				  "kind": "admin\#directory\#privilege",
				  "etag": ...,
				  "serviceId": "02afmg282jiquyg",
				  "privilegeName": "APP_ADMIN",
				  "isOuScopable": false
				},
				{
				  "kind": "admin\#directory\#privilege",
				  "etag": ...,
				  "serviceId": "04f1mdlm0ki64aw",
				  "privilegeName": "MANAGE_USER_SETTINGS",
				  "isOuScopable": true,
				  "childPrivileges": [
					{
					  "kind": "admin\#directory\#privilege",
					  "etag": ...,
					  "serviceId": "04f1mdlm0ki64aw",
					  "privilegeName": "MANAGE_APPLICATION_SETTINGS",
					  "isOuScopable": true
					}
				  ]
				},
			...
		  ]

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/20/2018
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
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

		[System.String]$Url = "$Base/$CustomerId/roles/ALL/privileges"

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
			
			[System.Collections.Hashtable[]]$Results = @()

			foreach ($Item in $ParsedResponse.items)
			{
				[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $Item

				$Results += $Temp
			}

			Write-Output -InputObject $Results
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

Function Get-GoogleDirectoryRoleList {
	<#
		.SYNOPSIS
			Gets a list of existing GSuite roles.

		.DESCRIPTION
			This cmdlet gets a list of existing roles. 

		.PARAMETER CustomerId
			If you are an administrator getting roles in your own domain, use my_customer as the customer ID. This is the default.
			If you are reseller getting roles for one of your customers, use the customer ID returned by the Retrieve a user operation.

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
			$Roles = Get-GoogleDirectoryRoleList -ClientId $Id -Persist -UseCompression

			This examples gets the existing roles for the account supporting the current administrator.

		.INPUTS 
			None
		
		.OUTPUTS
			System.Collections.Hashtable[]

			This is a JSON representation of the output:
			[
				{
					"kind": "admin\#directory\#role",
					"etag": ... ,
					"roleId": "3894208461012993",
					"roleName": "_SEED_ADMIN_ROLE",
					"roleDescription": "Google Apps Administrator Seed Role",
					"rolePrivileges": [
						{
						  "privilegeName": "SUPER_ADMIN",
						  "serviceId": "01ci93xb3tmzyin"
						},
						{
						  "privilegeName": "ROOT_APP_ADMIN",
						  "serviceId": "00haapch16h1ysv"
						},
						{
						  "privilegeName": "ADMIN_APIS_ALL",
						  "serviceId": "00haapch16h1ysv"
						},
						...
					],
					"isSystemRole": true,
					"isSuperAdminRole": true
				},
				{
				  "kind": "admin\#directory\#role",
				  "etag": "\"sxH3n22L0-77khHtQ7tiK6I21Yo/bTXiZXfuK1NGr_f4paosCWXuHmw\"",
				  "roleId": "3894208461012994",
				  "roleName": "_GROUPS_ADMIN_ROLE",
				  "roleDescription": "Groups Administrator",
				  "rolePrivileges": [
					{
					  "privilegeName": "CHANGE_USER_GROUP_MEMBERSHIP",
					  "serviceId": "01ci93xb3tmzyin"
					},
					{
					  "privilegeName": "USERS_RETRIEVE",
					  "serviceId": "00haapch16h1ysv"
					},
					{
					  "privilegeName": "GROUPS_ALL",
					  "serviceId": "00haapch16h1ysv"
					},
					{
					  "privilegeName": "ADMIN_DASHBOARD",
					  "serviceId": "01ci93xb3tmzyin"
					},
					{
					  "privilegeName": "ORGANIZATION_UNITS_RETRIEVE",
					  "serviceId": "00haapch16h1ysv"
					}
				  ],
				  "isSystemRole": true
				},
			...
		  ]

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/20/2018
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
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

		[System.String]$Url = "$Base/$CustomerId/roles"

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
			
			[System.Collections.Hashtable[]]$Results = @()

			foreach ($Item in $ParsedResponse.items)
			{
				[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $Item

				$Results += $Temp
			}

			Write-Output -InputObject $Results
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

Function New-GoogleDirectoryRole {
	<#
		.SYNOPSIS
			Creates a new GSuite role.

		.DESCRIPTION
			This cmdlet creates a new GSuite role.

		.PARAMETER Name
			The name of the role to create.

		.PARAMETER Privileges
			The privileges to assign to the role. This is an array of items where each item has a privilege name and service id. For
			example:
			
			$Priv = @{
				"privilegeName": "USERS_ALL";
				"serviceId": "00haapch16h1ysv"
			}
		
		.PARAMETER CustomerId
			If you are an administrator creating a role in your own domain, use my_customer as the customer ID. This is the default.
			If you are reseller creating a role for one of your customers, use the customer ID returned by the Retrieve a user operation.

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
			$Role = New-GoogleDirectoryRole -Name UserAdminRole -Privileges @(@{"privilegeName": "USERS_ALL"; "serviceId": "00haapch16h1ysv"}) -ClientId $Id -Persist -UseCompression -PassThru

			This examples creates a new role called UserAdminRole with the USERS_ALL privilege and returns the new role to the pipeline.

		.INPUTS 
			None
		
		.OUTPUTS
			System.Collections.Hashtable

			This is a JSON representation of the output:
			{
			  "kind": "admin\#directory\#role",
			  "etag": "\"sxH3n22L0-77khHtQ7tiK6I21Yo/uX9tXw0qyijC9nUKgCs08wo8aEM\"",
			  "roleId": "3894208461013031",
			  "roleName": "My New Role",
			  "rolePrivileges": [
				{
				  "privilegeName": "GROUPS_ALL",
				  "serviceId": "00haapch16h1ysv"
				},
				{
				  "privilegeName": "USERS_ALL",
				  "serviceId": "00haapch16h1ysv"
				}
			  ]
			}

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/20/2018
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[System.String]$Name,

		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullOrEmpty()]
		[System.Collections.Hashtable[]]$Privileges,

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
		[System.String]$Base = $script:OUBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$CustomerId/roles"

		try
		{
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[System.Collections.Hashtable]$BodyContent = @{"roleName" = $Name; "rolePrivileges" = @()}

			foreach ($Item in $Privileges)
			{
				if ($Item.ContainsKey("privilegeName") -and $Item.ContainsKey("serviceId"))
				{
					$BodyContent["rolePrivileges"] += @{"privilegeName" = $Item["privilegeName"]; "serviceId" = $Item["serviceId"]}
				}
				else
				{
					Write-Error -Exception (New-Object -TypeName System.ArgumentException("Privileges", "A privilege was supplied that did not possess a privilegeName and serviceId property.")) -ErrorAction Stop
				}
			}

			[System.String]$Body = ConvertTo-Json -InputObject $BodyContent -Depth 3 -Compress

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Post -Body $Body -Headers $Headers -UserAgent $UserAgent

			if ($PassThru)
			{
				[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content
			
				[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

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

Function New-GoogleDirectoryRoleAssignment {
	<#
		.SYNOPSIS
			Creates a new GSuite role assignment.

		.DESCRIPTION
			This cmdlet assigns a role to a user.

		.PARAMETER RoleId
			The id of the role to which the user will be assigned.

		.PARAMETER UserId
			The id of the user who will be assigned to the role.

		.PARAMETER ScopeType
			The scope of the assignment.

		.PARAMETER CustomerId
			If you are an administrator creating a role assignment in your own domain, use my_customer as the customer ID. This is the default.
			If you are reseller creating a role assignment for one of your customers, use the customer ID returned by the Retrieve a user operation.

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
			$RoleAssignment = New-GoogleDirectoryRoleAssignment -RoleId "3894208461012995" -UserId "100662996240850794412" -ClientId $Id -Persist -UseCompression -PassThru

			This examples assigns the specified role to the specified user and returns the response to the pipeline.

		.INPUTS 
			None
		
		.OUTPUTS
			None or System.Collections.Hashtable

			This is a JSON representation of the output:
			{
			  "kind": "admin\#directory\#roleAssignment",
			  "etag": "\"sxH3n22L0-77khHtQ7tiK6I21Yo/VdrrUEz7GyXqlr9I9JL0wGZn8yE\"",
			  "roleAssignmentId": "3894208461013211",
			  "roleId": "3894208461012995",
			  "assignedTo": "100662996240850794412",
			  "scopeType": "CUSTOMER"
			}

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/20/2018
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[System.String]$RoleId,

		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullOrEmpty()]
		[System.String]$UserId,

		[Parameter()]
		[ValidateSet("CUSTOMER")]
		[System.String]$ScopeType = "CUSTOMER",

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
		[System.String]$Base = $script:OUBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$CustomerId/roleassignments"

		try
		{
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[System.String]$Body = ConvertTo-Json -InputObject (@{"roleId" = $RoleId; "assignedTo" = $UserId; "scopeType" = $ScopeType}) -Depth 3 -Compress

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Post -Body $Body -Headers $Headers -UserAgent $UserAgent

			if ($PassThru)
			{
				[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content
			
				[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

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

#region Customers

Function Get-GoogleDirectoryCustomer {
	<#
		.SYNOPSIS
			Gets a GSuite customer.

		.DESCRIPTION
			This cmdlet gets a specified GSuite customer. 

		.PARAMETER CustomerId
			The CustomerId can be the unique customerId, or my_customer to indicate the current customer. This defaults
			to my_customer.

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
			$Customer = Get-GoogleDirectoryCustomer -ClientId $Id -Persist -UseCompression

			This examples gets the current customer details.

		.INPUTS 
			None
		
		.OUTPUTS
			System.Collections.Hashtable

			This is a JSON representation of the output:
			{
			  "etag": "\"spqlTgq5LGeoin0BH1d0f4rpI98/LnbnRK_ZWu_omowg36CZgTKECrY\"",
			  "kind": "admin#directory#customer",
			  "alternateEmail": "marty.mcfly@gmail.com",
			  "id": "C03xgje4y",
			  "customerDomain": "amatchmadeinspace.com",
			  "postalAddress": {
				"organizationName": "A Match Made in Space, LLC",
				"countryCode": "US"
			  },
			  "customerCreationTime": "2015-10-21T20:42:35.224Z"
			}

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/20/2018
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
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

		[System.String]$Url = "$Base/$CustomerId"

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

			[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

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

Function Set-GoogleDirectoryCustomer {
	<#
		.SYNOPSIS
			Updates a GSuite customer.

		.DESCRIPTION
			This cmdlet updates a specified GSuite customer. 

		.PARAMETER CustomerId
			The CustomerId can be the unique customerId, or my_customer to indicate the current customer. This defaults
			to my_customer.

		.PARAMETER CustomerDetails
			The updated information for the customer. This can include any of the following fields:

			{
			  "alternateEmail": "marty.mcfly@gmail.com",
			  "customerDomain": "amatchmadeinspace.com",
			  "language": "EN",
			  "postalAddress": {
				"organizationName": "A Match Made in Space, LLC",
				"phoneNumber": "+15558675309"
			  }
			}

		.PARAMETER PassThru
			If specified, the updated customer details are passed back to the pipeline.

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
			$Customer = Set-GoogleDirectoryCustomer -CustomerId C03xgje4y -CustomerDetails @{"customerDomain" = "fluxcapacitor.com"} -ClientId $Id -Persist -UseCompression -PassThru

			This examples updates the customer primary domain name.

		.INPUTS 
			System.Collections.Hashtable
		
		.OUTPUTS
			None or System.Collections.Hashtable

			This is a JSON representation of the output:
			{
			  "etag": "\"spqlTgq5LGeoin0BH1d0f4rpI98/LnbnRK_ZWu_omowg36CZgTKECrY\"",
			  "kind": "admin#directory#customer",
			  "alternateEmail": "marty.mcfly@gmail.com",
			  "id": "C03xgje4y",
			  "customerDomain": "amatchmadeinspace.com",
			  "postalAddress": {
				"organizationName": "A Match Made in Space, LLC",
				"countryCode": "US"
			  },
			  "customerCreationTime": "2015-10-21T20:42:35.224Z"
			}

		.NOTES
            AUTHOR: Michael Haken
			LAST UPDATE: 2/20/2018
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	Param(
		[Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]$CustomerId = "my_customer",

		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[ValidateNotNull()]
		[System.Collections.Hashtable]$CustomerDetails,

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
		[System.String]$Base = $script:OUBaseUrl

		if ($PSCmdlet.ParameterSetName -eq "Profile")
		{
			$ClientId = $PSBoundParameters["ClientId"]
			[System.Collections.Hashtable]$Token = Get-GoogleOAuth2Token -ClientId $ClientId -ProfileLocation $ProfileLocation -Persist:$Persist -ErrorAction Stop
			$BearerToken = $Token["access_token"]
		}

		[System.String]$Url = "$Base/$CustomerId"

		try
		{
			$Headers = @{"Authorization" = "Bearer $BearerToken"}
			$UserAgent = $script:UserAgent

			if ($UseCompression)
			{
				$UserAgent = $script:UserAgentGzip
				$Headers.Add("Accept-Encoding", "gzip")
			}

			[System.String]$Body = ConvertTo-Json -InputObject $CustomerDetails -Depth 3 -Compress

			[Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $Url -Method Put -Body $Body -Headers $Headers -UserAgent $UserAgent

			if ($PassThru)
			{
				[PSCustomObject]$ParsedResponse = ConvertFrom-Json -InputObject $Response.Content

				[System.Collections.Hashtable]$Temp = Convert-PSCustomToHashtable -InputObject $ParsedResponse

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

Function Convert-PSCustomToHashtable {
	[CmdletBinding()]
	[OutputType()]
	Param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[PSCustomObject]$InputObject
	)

	Begin {
	}

	Process {
		[System.Collections.Hashtable]$Result = @{}

		foreach($Property in ($InputObject | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name))
		{
			$Value = $InputObject.$Property

			[System.Type]$Type = $Value.GetType()

			if ($Type.IsPrimitive -or $Value -is [System.String])
			{
				$Result.Add($Property, $Value)
			}
            elseif($Type.GetInterfaces().Contains([System.Collections.IEnumerable]))
			{
				$Arr = @()
				foreach ($Item in $Value)
				{
					if ($Item -is [PSCustomObject])
                    {
                        $Arr += (Convert-PSCustomToHashtable -InputObject $Item)
                    }
                    else
                    {
                        $Arr += $Item
                    }
				}

                $Result.Add($Property, $Arr)
			}
			elseif ($Value -is [PSCustomObject])
			{
				$Result.Add($Property, (Convert-PSCustomToHashtable -InputObject $Value))
			}
            else
            {
                $Result.Add($Property, $Value)
            }
		}

		Write-Output -InputObject $Result
	}

	End {
	}
}