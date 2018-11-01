function Test-Administrator {
	[Security.Principal.WindowsPrincipal]::New(
		[Security.Principal.WindowsIdentity]::GetCurrent()
	).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

<#
.SYNOPSIS
        Finds the valid executables in $PATH for a given name; like unix `which`
#>
function Get-ExecutableName {
	[CmdletBinding()]
	Param(
		[Parameter(ValueFromPipeline=$True)]
		[String]$Name,
		[Switch]$All
	)
	
	Process {
		$ret = where.exe $Name
		If(!$All -and $ret -is [Object[]]) {
			$ret = $ret[0]
		}
		$ret
	}
}

function New-SymbolicLink {
	[CmdletBinding()]
	Param(
		[String]$From,
		[String]$To,
		[Switch]$Force,
		[String]$ItemType="SymbolicLink"
	)

	$ToPath = Resolve-Path $To

	$itemArgs = @{
		"Path"     = $From
		"ItemType" = $ItemType
		"Value"    = $ToPath
	}

	If($Force) {
		$itemArgs.Add("Force", [Switch]::Present)
	}

	New-Item @itemArgs
}

function Remove-SymbolicLink {
	[CmdletBinding()]
	Param(
		[Parameter(
			ValueFromPipeline=$True
		)]
		[String]$Link
	)

	Process {
		cmd /c rmdir $Link
	}
}

function Hide-File {
	[CmdletBinding()]
	Param(
		[Parameter(
			ValueFromPipeline=$True
		)]
		[String]$Path
        )

	Process {
		Get-Item $Path | %{
			$_.Attributes = $_.Attributes -bor "Hidden"
		}
	}
}

function New-SymbolicLink {
	[CmdletBinding()]
	Param(
		[String]$From,
		[String]$To,
		[Switch]$Force,
		[String]$ItemType="SymbolicLink"
	)

	$ToPath = Resolve-Path $To

	$itemArgs = @{
		"Path"     = $From
		"ItemType" = $ItemType
		"Value"    = $ToPath
	}

	If($Force) {
		$itemArgs.Add("Force", [Switch]::Present)
	}

	New-Item @itemArgs
}

function Remove-SymbolicLink {
	[CmdletBinding()]
	Param(
		[Parameter(
			ValueFromPipeline=$True
		)]
		[String]$Link
	)

	Process {
		cmd /c rmdir $Link
	}
}

function Get-EnvironmentVariable {
	[CmdletBinding()]
	Param (
		[String]$Name,
		[ValidateSet("Process", "User", "Machine")]
		[String]$Scope = "Machine"
	)

	Process {
		[Environment]::GetEnvironmentVariable($Name, $Scope)
	}
}

<#
.SYNOPSIS
#>
function Set-EnvironmentVariable {
	[CmdletBinding()]
	Param (
		[String]$Name,
		[String]$Value,
		[ValidateSet("Process", "User", "Machine")]
		[String]$Scope = "Machine"
	)

	Process {
		[Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
	}
}

<#
.SYNOPSIS
#>
function Remove-EnvironmentVariable {
	[CmdletBinding()]
	Param (
		[String]$Name,
		[ValidateSet("Process", "User", "Machine")]
		[String]$Scope = "Machine"
	)

	Process {
		[Environment]::SetEnvironmentVariable($Name, $null, $Scope)
	}
}

<#
.SYNOPSIS
#>
function Get-AllEnvironmentVariables {
	[CmdletBinding()]
	Param (
		[ValidateSet("Process", "User", "Machine")]
		[String]$Scope = "Machine"
	)

	Process {
		[Environment]::GetEnvironmentVariables($Scope)
	}
}

<#
.SYNOPSIS
	similar to chocolatey's refreshenv but in pure powershell
#>
function Restore-EnvironmentVariables {
	[CmdletBinding()]
	Param (
	)

	Process {
		("Machine", "User") | %{
			$scope = $_
			[Environment]::GetEnvironmentVariables($scope).GetEnumerator() |
				where Name -ne Path | %{
				Set-Content "Env:\$($_.Name)" $_.Value
				Write-Verbose "Env:\$($_.Name) = $($_.Value)"
			}
		}
		# treat path specially
		Restore-Path
	}
}

<#
.SYNOPSIS
	Restores $PATH to the $PATH in the registry + the user $PATH
#>
function Restore-Path {
	Process {
		Set-Content "Env:\Path" `
			"$(Get-EnvironmentVariable Path Machine);$(Get-EnvironmentVariable Path User)"
		Write-Verbose "Env:\Path = $($env:Path)"
	}
}

<#
.SYNOPSIS
	Gets $PATH as an array
#>
function Get-Path {
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline=$True)]
		[String]$FileName
	)

	Process {
		$env:Path -split ';'
	}
}

<#
.SYNOPSIS
	Adds a directory to $PATH in the selected scope; Machine-level (i.e. in
	the registry) by default
#>
function Add-Path {
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline=$True)]
		[String]$Directory,
		[ValidateSet("Process", "User", "Machine")]
		[String]$Scope = "Machine"
	)

	Process {
		Set-EnvironmentVariable Path "${env:Path};$Directory" -Scope $Scope
		Restore-Path
	}
}

<#
.SYNOPSIS
	Adds a Bash-style alias, i.e. proper partial application of arguments
#>
function New-BashAlias {
	[CmdletBinding()]
	Param (
		[String]$Name,
		[String]$Executable,
		[Parameter(ValueFromRemainingArguments=$True)]
		[String[]]$MoreArgs
	)

	$exe = Get-Command -CommandType Application `
		-TotalCount 1 `
		$Executable
	$argString = $MoreArgs -join " "
	return ("function $Name {" +
		"`t`$input | & `"$($exe.Source)`" $argString `$args" +
		" }")
}
