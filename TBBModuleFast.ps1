# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# # # Copyright 2023 Justin Grote @justinwgrote
# # #
# # # Permission is hereby granted, free of charge, to any person obtaining a
# # # copy of this software and associated documentation files (the
# # # "Software"), to deal in the Software without restriction, including
# # # without limitation the rights to use, copy, modify, merge, publish,
# # # distribute, sublicense, and/or sell copies of the Software, and to permit
# # # persons to whom the Software is furnished to do so, subject to the
# # # following conditions:
# # #
# # # The above copyright notice and this permission notice shall be included
# # # in all copies or substantial portions of the Software.
# # #
# # # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# # # OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# # # MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
# # # NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# # # DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# # # OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# # # USE OR OTHER DEALINGS IN THE SOFTWARE.
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
#
using namespace System.Net.Http
#requires -version 7.2
# This is the bootstrap script for Modules
[CmdletBinding(PositionalBinding = $false)]
param (
	#Specify a specific release to use, otherwise 'latest' is used
	[string]$Release = 'latest',
	#Specify the user
	[string]$User = 'TheBigBear',
	#Specify the repo
	[string]$Repo = 'TBBModuleFast',
	#Specify the module file
	[string]$ModuleFile = 'TBBModuleFast.psm1',
	#Entrypoint to be used if additional args are specified
	[string]$EntryPoint = 'Install-TBBModuleFast',
	#Specify the module name
	[string]$ModuleName = 'TBBModuleFast',
	#Path of the module to bootstrap. You normally won't change this but you can override it if you want
	[string]$Uri = $(
		$base = "https://github.com/$User/$Repo/releases/{0}/$ModuleFile";
		$version = $Release -eq 'latest' ? 'latest/download' : "download/$Release";
		$base -f $version
	),
	#All additional arguments passed to this script will be passed to Install-TBBModuleFast
	[Parameter(ValueFromRemainingArguments)]$installArgs
)
$ErrorActionPreference = 'Stop'

if (Get-Module $ModuleName) {
	Write-Warning "Module $ModuleName already loaded, skipping bootstrap."
	return
}

Write-Debug "Fetching $ModuleName from $Uri"
$ProgressPreference = 'SilentlyContinue'
try {
	$httpClient = [HttpClient]::new()
	$httpClient.DefaultRequestHeaders.AcceptEncoding.Add('gzip')
	$response = $httpClient.GetStringAsync($Uri).GetAwaiter().GetResult()
} catch {
	$PSItem.ErrorDetails = "Failed to fetch $ModuleName from $Uri`: $PSItem"
	$PSCmdlet.ThrowTerminatingError($PSItem)
}
Write-Debug 'Fetched response'
$scriptBlock = [ScriptBlock]::Create($response)
$ProgressPreference = 'Continue'

$bootstrapModule = New-Module -Name $ModuleName -ScriptBlock $scriptblock | Import-Module -PassThru
Write-Debug "Loaded Module $ModuleName"

if ($installArgs) {
	Write-Debug "Detected we were started with args, running $Entrypoint $($installArgs -join ' ')"
	& $EntryPoint @installArgs

	#Remove the bootstrap module if args were specified, otherwise persist it in memory
	Remove-Module $bootstrapModule
}
