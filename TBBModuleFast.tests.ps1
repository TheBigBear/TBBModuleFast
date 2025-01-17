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
using namespace System.Management.Automation
using namespace System.Collections.Generic
using namespace System.Diagnostics.CodeAnalysis
Import-Module ./TBBModuleFast.psm1 -Force

BeforeAll {
	if ($env:MFURI) {
		$PSDefaultParameterValues['Get-TBBModuleFastPlan:Source'] = $env:MFURI
	}
}

InModuleScope 'TBBModuleFast' {
	Describe 'TBBModuleFastSpec' {
		Context 'Constructors' {
			It 'Name' {
				$spec = [TBBModuleFastSpec]'Test'
				$spec.Name | Should -Be 'Test'
				$spec.Guid | Should -Be ([Guid]::Empty)
				$spec.Min | Should -Be ([TBBModuleFastSpec]::MinVersion)
				$spec.Max | Should -Be ([TBBModuleFastSpec]::MaxVersion)
				$spec.Required | Should -BeNull
			}

			It 'Has non-settable properties' {
				$spec = [TBBModuleFastSpec]'Test'
				{ $spec.Min = '1' } | Should -Throw
				{ $spec.Max = '1' } | Should -Throw
				{ $spec.Required = '1' } | Should -Throw
				{ $spec.Name = 'fake' } | Should -Throw
				{ $spec.Guid = New-Guid } | Should -Throw
			}

			It 'ModuleSpecification' {
				$in = [ModuleSpecification]@{
					ModuleName    = 'Test'
					ModuleVersion = '2.1.5'
				}
				$spec = [TBBModuleFastSpec]$in
				$spec.Name | Should -Be 'Test'
				$spec.Guid | Should -Be ([Guid]::Empty)
				$spec.Min | Should -Be '2.1.5'
				$spec.Max | Should -Be ([TBBModuleFastSpec]::MaxVersion)
				$spec.Required | Should -BeNull
			}
		}

		Context 'ModuleSpecification Conversion' {
			It 'Name' {
				$spec = [ModuleSpecification][TBBModuleFastSpec]'Test'
				$spec.Name | Should -Be 'Test'
				$spec.Version | Should -Be '0.0.0'
			}
			It 'RequiredVersion' {
				$spec = [ModuleSpecification][TBBModuleFastSpec]::new('Test', '1.2.3')
				$spec.Name | Should -Be 'Test'
				$spec.RequiredVersion | Should -Be '1.2.3'
			}
			It 'ModuleVersion' {
				$spec = [ModuleSpecification][TBBModuleFastSpec]::new('Test', '1.2.3', '')
				$spec.Name | Should -Be 'Test'
				$spec.Version | Should -Be '1.2.3'
			}
		}

		Context 'ParseVersion' {
			It 'parses a normal version' {
				$version = '1.2.3'
				$result = [TBBModuleFastSpec]::ParseVersion($version)
				$result.Major | Should -Be 1
				$result.Minor | Should -Be 2
				$result.Patch | Should -Be 3
				$result.PreReleaseLabel | Should -BeNull
				$result.BuildLabel | Should -BeNull
				[TBBModuleFastSpec]::ParseSemanticVersion($result) | Should -BeExactly $version
			}
			It 'parses a system version' {
				$version = '1.2.3.4'
				$result = [TBBModuleFastSpec]::ParseVersion($version)
				$result.Major | Should -Be 1
				$result.Minor | Should -Be 2
				$result.Patch | Should -Be (3 + 1)
				$result.PreReleaseLabel | Should -Be (4).ToString().PadLeft(10, '0')
				$result.BuildLabel | Should -Be 'SYSTEMVERSION.HASREVISION'
				[TBBModuleFastSpec]::ParseSemanticVersion($result) | Should -BeExactly $version
			}
			It 'parses a major/minor only version' {
				$version = '1.4'
				$result = [TBBModuleFastSpec]::ParseVersion($version)
				$result.Major | Should -Be 1
				$result.Minor | Should -Be 4
				$result.Patch | Should -Be 0
				$result.PreReleaseLabel | Should -BeNull
				$result.BuildLabel | Should -Be 'SYSTEMVERSION.NOBUILD'
				[TBBModuleFastSpec]::ParseSemanticVersion($result) | Should -BeExactly $version
			}
			It 'parses a patch version being zero' {
				$version = '1.4.0.5'
				$result = [TBBModuleFastSpec]::ParseVersion($version)
				$result.Major | Should -Be 1
				$result.Minor | Should -Be 4
				$result.Patch | Should -Be (0 + 1)
				$result.PreReleaseLabel | Should -Be (5).ToString().PadLeft(10, '0')
				$result.BuildLabel | Should -Be 'SYSTEMVERSION.HASREVISION'
				[TBBModuleFastSpec]::ParseSemanticVersion($result) | Should -BeExactly $version
			}
		}
		Context 'ParseSemanticVersion' {
			It 'parses a normal version' {
				$version = '1.2.3'
				$result = [TBBModuleFastSpec]::ParseSemanticVersion($version)
				$result.Major | Should -Be 1
				$result.Minor | Should -Be 2
				$result.Build | Should -Be 3
				$result.Revision | Should -Be -1
			}
			It 'strips non-version fields' {
				$version = '1.2.3-something+4'
				$result = [TBBModuleFastSpec]::ParseSemanticVersion($version)
				$result.Major | Should -Be 1
				$result.Minor | Should -Be 2
				$result.Build | Should -Be 3
				$result.Revision | Should -Be -1
			}
		}
		Context 'Overlap' {
			It 'overlaps exactly' {
				$spec1 = [TBBModuleFastSpec]::new('Test', '1.2.3', '1.2.4')
				$spec2 = [TBBModuleFastSpec]::new('Test', '1.2.3', '1.2.4')
				$spec1.Overlaps($spec2) | Should -BeTrue
				$spec2.Overlaps($spec1) | Should -BeTrue
			}
			It 'overlaps partially' {
				$spec1 = [TBBModuleFastSpec]::new('Test', '1.2.1', '1.2.4')
				$spec2 = [TBBModuleFastSpec]::new('Test', '1.2.3', '1.2.5')
				$spec1.Overlaps($spec2) | Should -BeTrue
				$spec2.Overlaps($spec1) | Should -BeTrue
			}
			It 'no overlap' {
				$spec1 = [TBBModuleFastSpec]::new('Test', '1.2.1', '1.2.2')
				$spec2 = [TBBModuleFastSpec]::new('Test', '1.2.3', '1.2.4')
				$spec1.Overlaps($spec2) | Should -BeFalse
				$spec2.Overlaps($spec1) | Should -BeFalse
			}
			It 'overlaps partially with no max' {
				$spec1 = [TBBModuleFastSpec]::new('Test', '1.2.1', '1.2.4')
				$spec2 = [TBBModuleFastSpec]::new('Test', '1.2.3')
				$spec1.Overlaps($spec2) | Should -BeTrue
				$spec2.Overlaps($spec1) | Should -BeTrue
			}
			It 'overlaps partially with no min' {
				$spec1 = [TBBModuleFastSpec]::new('Test', $null, '1.2.4')
				$spec2 = [TBBModuleFastSpec]::new('Test', '1.2.3')
				$spec1.Overlaps($spec2) | Should -BeTrue
				$spec2.Overlaps($spec1) | Should -BeTrue
			}
			It 'overlaps partially with no min or max' {
				$spec1 = [TBBModuleFastSpec]'Test'
				$spec2 = [TBBModuleFastSpec]'Test'
				$spec1.Overlaps($spec2) | Should -BeTrue
				$spec2.Overlaps($spec1) | Should -BeTrue
			}
			It 'errors on different Names' {
				$spec1 = [TBBModuleFastSpec]'Test'
				$spec2 = [TBBModuleFastSpec]'Test2'
				{ $spec1.Overlaps($spec2) } | Should -Throw
				{ $spec2.Overlaps($spec1) } | Should -Throw
			}
			It 'errors on different GUIDs' {
				$spec1 = [TBBModuleFastSpec]::new('Test', '1.0.0', [Guid]::NewGuid())
				$spec2 = [TBBModuleFastSpec]::new('Test', '1.0.0', [Guid]::NewGuid())
				{ $spec1.Overlaps($spec2) } | Should -Throw
				{ $spec2.Overlaps($spec1) } | Should -Throw
			}
		}
		Context 'Equals' {
			It 'TBBModuleFastSpec' {
				$spec1 = [TBBModuleFastSpec]::new('Test', '1.2.3', '1.2.4')
				$spec2 = [TBBModuleFastSpec]::new('Test', '1.2.3', '1.2.4')
				$spec1 -eq $spec2 | Should -BeTrue
			}
			It 'TBBModuleFastSpec not equal on name' {
				$spec1 = [TBBModuleFastSpec]'Test'
				$spec2 = [TBBModuleFastSpec]'Test2'
				$spec1 -eq $spec2 | Should -BeFalse
			}
			It 'TBBModuleFastSpec not equal on min' {
				$spec1 = [TBBModuleFastSpec]::new('Test', '1.2.3')
				$spec2 = [TBBModuleFastSpec]::new('Test', '1.2.4')
				$spec1 -eq $spec2 | Should -BeFalse
			}
			It 'TBBModuleFastSpec not equal on max' {
				$spec1 = [TBBModuleFastSpec]::new('Test', $null, '1.2.3')
				$spec2 = [TBBModuleFastSpec]::new('Test', $null, '1.2.4')
				$spec1 -eq $spec2 | Should -BeFalse
			}
			It 'Version In Range' {
				$spec1 = [TBBModuleFastSpec]::new('Test', '1.2.3', '1.2.4')
				$version = [Version]::new('1.2.3')
				$spec1 -eq $version | Should -BeTrue
			}
			It 'Version NotIn Range' {
				$spec1 = [TBBModuleFastSpec]::new('Test', '1.2.3', '1.2.4')
				$version = [Version]::new('1.2.2')
				$spec1 -eq $version | Should -BeFalse
			}
			It 'SemanticVersion In Range' {
				$spec1 = [TBBModuleFastSpec]::new('Test', '1.2.3', '1.2.4')
				$version = [SemanticVersion]::new('1.2.3')
				$spec1 -eq $version | Should -BeTrue
			}
			It 'SemanticVersion NotIn Range' {
				$spec1 = [TBBModuleFastSpec]::new('Test', '1.2.3', '1.2.4')
				$version = [SemanticVersion]::new('1.2.3')
				$spec1 -eq $version | Should -BeTrue
			}

			It 'String Comparisons' {
				$spec = [TBBModuleFastSpec]::new('Test', '1.1.1', '2.2.2')
				$spec -eq '1' | Should -BeFalse
				$spec -eq '2' | Should -BeTrue
				$spec -eq '3' | Should -BeFalse
				$spec -eq '1.0' | Should -BeFalse
				$spec -eq '1.1' | Should -BeFalse
				$spec -eq '1.2' | Should -BeTrue
				$spec -eq '2.0' | Should -BeTrue
				$spec -eq '2.2' | Should -BeTrue
				$spec -eq '2.3' | Should -BeFalse
				$spec -eq '3.0' | Should -BeFalse
				$spec -eq '1.1.0' | Should -BeFalse
				$spec -eq '1.1.1' | Should -BeTrue
				$spec -eq '1.1.2' | Should -BeTrue
				$spec -eq '2.2.2' | Should -BeTrue
				$spec -eq '2.2.3' | Should -BeFalse
				$spec -eq '3.0.0' | Should -BeFalse
			}
		}

		Context 'Compare' {
			It 'Sorts' {
				$spec1 = [TBBModuleFastSpec]::new('Test', '1.2.3')
				$spec2 = [TBBModuleFastSpec]::new('Test', '1.2.4')
				$spec3 = [TBBModuleFastSpec]::new('Test', '1.2.5')
				$spec3, $spec1, $spec2
			| Sort-Object
			| Should -Be @( $spec1, $spec2, $spec3 )

				$spec3, $spec1, $spec2
			| Sort-Object -Descending
			| Should -Be @( $spec3, $spec2, $spec1 )
			}
		}
	}

	Describe 'HashSet Dedupe (GetHashCode)' {
		It 'Name' {
			$spec1 = [TBBModuleFastSpec]'Test'
			$spec2 = [TBBModuleFastSpec]'Test'
			$spec1.GetHashCode() | Should -Be $spec2.GetHashCode()
		}
		It 'RequiredVersion' {
			$spec1 = [TBBModuleFastSpec]::new('Test', '1.2.3')
			$spec2 = [TBBModuleFastSpec]::new('Test', '1.2.3')
			$spec1.GetHashCode() | Should -Be $spec2.GetHashCode()
		}
		It 'Min and Max Version' {
			$spec1 = [TBBModuleFastSpec]::new('Test', '1.2.3', '1.2.4')
			$spec2 = [TBBModuleFastSpec]::new('Test', '1.2.3', '1.2.4')
			$spec1.GetHashCode() | Should -Be $spec2.GetHashCode()
		}
		It 'Max Version Only' {
			$spec1 = [TBBModuleFastSpec]::new('Test', $null, '1.2.4')
			$spec2 = [TBBModuleFastSpec]::new('Test', $null, '1.2.4')
			$spec1.GetHashCode() | Should -Be $spec2.GetHashCode()
		}
		It 'Min Version Only' {
			$spec1 = [TBBModuleFastSpec]::new('Test', '1.2.3')
			$spec2 = [TBBModuleFastSpec]::new('Test', '1.2.3')
			$spec1.GetHashCode() | Should -Be $spec2.GetHashCode()
		}
		It 'Guid' {
			[HashSet[TBBModuleFastSpec]]$hs = @{}
			$guid = [Guid]::NewGuid()
			$spec1 = [TBBModuleFastSpec]::new('Test', '1.2.4', $guid)
			$hs.Add($spec1) | Should -BeTrue
			$spec2 = [TBBModuleFastSpec]::new('Test', '1.2.4', $guid)
			$hs.Add($spec2) | Should -BeFalse
		}
	}

	Describe 'NugetRange' {
		Context 'Decrement' {
			It '<In> should be <Out>' {
				$actual = [NugetRange]::Decrement($In)
				$actual | Should -Be $Out
				$actual | Should -BeLessThan $In
			} -TestCases @(
				@{In = '1.0.1-build+5'; Out = '1.0.0' }
				@{In = '1.0.1'; Out = '1.0.0' }
				@{In = '1.0.2'; Out = '1.0.1' }
				@{In = '1.1.2'; Out = '1.1.1' }
				@{In = '0.1.2'; Out = '0.1.1' }
			)
		}
	}
}

Describe 'Get-TBBModuleFastPlan' -Tag 'E2E' {
	BeforeAll {
		$SCRIPT:__existingPSModulePath = $env:PSModulePath
		$env:PSModulePath = $testDrive

		$SCRIPT:__existingProgressPreference = $ProgressPreference
		$ProgressPreference = 'SilentlyContinue'

	}
	AfterAll {
		$env:PSModulePath = $SCRIPT:__existingPSModulePath
		$ProgressPreference = $SCRIPT:__existingProgressPreference
	}

	#This is used for testcases
	$SCRIPT:moduleName = 'Az.Accounts'

	It 'Gets Module by <Test>' {
		$actual = Get-TBBModuleFastPlan $spec
		$actual | Should -HaveCount 1
		$actual.Name | Should -Be $moduleName
		$actual.Required -as [Version] | Should -Not -BeNullOrEmpty
	} -TestCases (
		@{Test = 'Name'; Spec = $moduleName },
		@{Test = 'MinimumVersion'; Spec = @{ ModuleName = $moduleName; ModuleVersion = '0.0.0' } },
		@{Test = 'RequiredVersionNotLatest'; Spec = @{ ModuleName = $moduleName; RequiredVersion = '2.7.3' } }
	)
	It 'Gets Module with 1 dependency' {
		Get-TBBModuleFastPlan 'Az.Compute' | Should -HaveCount 2
	}
	It 'Gets Module with lots of dependencies (Az)' {
		#TODO: Mocks
		Get-TBBModuleFastPlan 'Az' | Should -HaveCount 78
	}
	It 'Gets Module with 4 section version number and a 4 section version number dependency (VMware.VimAutomation.Common)' {
		Get-TBBModuleFastPlan 'VMware.VimAutomation.Common' | Should -HaveCount 2

	}
	It 'Gets multiple modules' {
		Get-TBBModuleFastPlan 'Az', 'VMware.PowerCLI' | Should -HaveCount 153
	}
}

Describe 'Install-TBBModuleFast' -Tag 'E2E' {
	BeforeAll {
		$SCRIPT:__existingPSModulePath = $env:PSModulePath
		filter Limit-ModulePath {
			param(
				[string]$path,

				[Parameter(ValueFromPipeline)]
				[Management.Automation.PSModuleInfo]$InputObject
			)
			if ($PSItem.Path.StartsWith($path)) {
				return $PSItem
			}
		}
	}
	BeforeEach {
		#Remove all PSModulePath to not affect existing environment
		$installTempPath = Join-Path $testdrive $(New-Guid)
		New-Item -ItemType Directory -Path $installTempPath -ErrorAction stop
		$env:PSModulePath = $installTempPath

		[SuppressMessageAttribute(
			<#Category#>'PSUseDeclaredVarsMoreThanAssignments',
			<#CheckId#>$null,
			Justification = 'PSScriptAnalyzer doesnt see the connection between beforeeach and Describe/It'
		)]
		$imfParams = @{
			Destination          = $installTempPath
			NoProfileUpdate      = $true
			NoPSModulePathUpdate = $true
			Confirm              = $false
		}
	}
	AfterAll {
		$env:PSModulePath = $SCRIPT:__existingPSModulePath
	}
	It 'Installs Module' {
		#HACK: The testdrive mount is not available in the threadjob runspaces so we need to translate it
		Install-TBBModuleFast @imfParams 'Az.Accounts'
		Get-Item $installTempPath\Az.Accounts\*\Az.Accounts.psd1 | Should -Not -BeNullOrEmpty
	}
	It '4 section version numbers (VMware.PowerCLI)' {
		Install-TBBModuleFast @imfParams 'VMware.VimAutomation.Common'
		Get-Item $installTempPath\VMware*\*\*.psd1 | ForEach-Object {
			$moduleFolderVersion = $_ | Split-Path | Split-Path -Leaf
			Import-PowerShellDataFile -Path $_.FullName | ForEach-Object ModuleVersion | Should -Be $moduleFolderVersion
		}
		Get-Module VMWare* -ListAvailable
		| Limit-ModulePath $installTempPath
		| Should -HaveCount 2
	}
	It 'lots of dependencies (Az)' {
		Install-TBBModuleFast @imfParams 'Az'
		(Get-Module Az* -ListAvailable).count | Should -BeGreaterThan 10
	}
	It 'specific requiredVersion' {
		Install-TBBModuleFast @imfParams @{ ModuleName = 'Az.Accounts'; RequiredVersion = '2.7.4' }
		Get-Module Az.Accounts -ListAvailable
		| Limit-ModulePath $installTempPath
		| Select-Object -ExpandProperty Version
		| Should -Be '2.7.4'
	}
	It 'specific requiredVersion when newer version is present' {
		Install-TBBModuleFast @imfParams 'Az.Accounts'
		Install-TBBModuleFast @imfParams @{ ModuleName = 'Az.Accounts'; RequiredVersion = '2.7.4' }
		$installedVersions = Get-Module Az.Accounts -ListAvailable
		| Limit-ModulePath $installTempPath
		| Select-Object -ExpandProperty Version

		$installedVersions | Should -HaveCount 2
		$installedVersions | Should -Contain '2.7.4'
	}
	It 'Installs when Maximumversion is lower than currently installed' {
		Install-TBBModuleFast @imfParams 'Az.Accounts'
		Install-TBBModuleFast @imfParams @{ ModuleName = 'Az.Accounts'; MaximumVersion = '2.7.3' }
		Get-Module Az.Accounts -ListAvailable
		| Limit-ModulePath $installTempPath
		| Select-Object -ExpandProperty Version
		| Should -Contain '2.7.3'
	}
	It 'Only installs once when Update is specified and latest has not changed' {
		Install-TBBModuleFast @imfParams 'Az.Accounts' -Update
		#This will error if the file already exists
		Install-TBBModuleFast @imfParams 'Az.Accounts' -Update
	}

	It 'Updates only dependent module that requires update' {
		Install-TBBModuleFast @imfParams @{ ModuleName = 'Az.Accounts'; RequiredVersion = '2.10.2' }
		Install-TBBModuleFast @imfParams	@{ ModuleName = 'Az.Compute'; RequiredVersion = '5.0.0' }
		Get-Module Az.Accounts -ListAvailable
		| Limit-ModulePath $installTempPath
		| Select-Object -ExpandProperty Version
		| Sort-Object Version -Descending
		| Select-Object -First 1
		| Should -Be '2.10.2'

		Install-TBBModuleFast @imfParams 'Az.Compute', 'Az.Accounts' #Should not update
		Get-Module Az.Accounts -ListAvailable
		| Limit-ModulePath $installTempPath
		| Select-Object -ExpandProperty Version
		| Sort-Object Version -Descending
		| Select-Object -First 1
		| Should -Be '2.10.2'

		Install-TBBModuleFast @imfParams 'Az.Compute' -Update #Should disregard local install and update latest Az.Accounts
		Get-Module Az.Accounts -ListAvailable
		| Limit-ModulePath $installTempPath
		| Select-Object -ExpandProperty Version
		| Sort-Object Version -Descending
		| Select-Object -First 1
		| Should -BeGreaterThan ([version]'2.10.2')

		Get-Module Az.Compute -ListAvailable
		| Limit-ModulePath $installTempPath
		| Select-Object -ExpandProperty Version
		| Sort-Object Version -Descending
		| Select-Object -First 1
		| Should -BeGreaterThan ([version]'5.0.0')
	}
}
