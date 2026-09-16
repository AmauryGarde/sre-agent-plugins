#requires -Version 7.0

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Read-JsonFile {
    param([string]$Path)
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
}

function Resolve-PackagePath {
    param([string]$BasePath, [string]$RelativePath)
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or [IO.Path]::IsPathRooted($RelativePath)) {
        throw "Expected a relative package path: $RelativePath"
    }
    $resolvedPath = [IO.Path]::GetFullPath((Join-Path $BasePath $RelativePath))
    $prefix = [IO.Path]::GetFullPath($BasePath).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedPath.StartsWith($prefix, [StringComparison]::Ordinal)) {
        throw "Path escapes package: $RelativePath"
    }
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "Missing package path: $RelativePath"
    }
    $resolvedPath
}

$jsonFiles = @(Get-ChildItem -LiteralPath $repositoryRoot -Recurse -Force -File -Filter '*.json' |
    Where-Object { $_.FullName -notmatch '[/\\]\.git[/\\]' })
foreach ($jsonFile in $jsonFiles) {
    $null = Read-JsonFile $jsonFile.FullName
}

$catalog = Read-JsonFile (Join-Path $repositoryRoot 'marketplace.json')
$githubCatalog = Read-JsonFile (Join-Path $repositoryRoot '.github/plugin/marketplace.json')
if (($catalog | ConvertTo-Json -Depth 100 -Compress) -cne ($githubCatalog | ConvertTo-Json -Depth 100 -Compress)) {
    throw 'The root and .github marketplace catalogs differ.'
}
if ($catalog.plugins.Count -ne 8) {
    throw 'Expected eight marketplace plugins.'
}
if (@($catalog.plugins.name | Sort-Object -Unique).Count -ne $catalog.plugins.Count) {
    throw 'Duplicate marketplace plugin names.'
}

$expectedSkillFiles = @()
$expectedServers = @{}
foreach ($entry in $catalog.plugins) {
    $pluginDirectory = Resolve-PackagePath $repositoryRoot $entry.source
    $plugin = Read-JsonFile (Join-Path $pluginDirectory 'plugin.json')
    if ($plugin.name -cne $entry.name) {
        throw "Manifest/catalog name mismatch: $($entry.name)"
    }
    foreach ($skillsDirectory in $plugin.skills) {
        $skillsPath = Resolve-PackagePath $pluginDirectory $skillsDirectory
        $skillFiles = @(Get-ChildItem -LiteralPath $skillsPath -Recurse -File -Filter 'SKILL.md')
        if ($skillFiles.Count -eq 0) {
            throw "No skills found for $($entry.name)."
        }
        $expectedSkillFiles += $skillFiles.FullName
    }
    if ($plugin.Contains('mcpServers')) {
        $configPath = Resolve-PackagePath $pluginDirectory $plugin.mcpServers
        $config = Read-JsonFile $configPath
        foreach ($serverName in $config.mcpServers.Keys) {
            if ($expectedServers.ContainsKey($serverName)) {
                throw "Duplicate MCP server: $serverName"
            }
            $expectedServers[$serverName] = $config.mcpServers[$serverName]
        }
    }
}

$rootPlugin = Read-JsonFile (Join-Path $repositoryRoot 'plugin.json')
$actualSkillFiles = @(foreach ($skillsDirectory in $rootPlugin.skills) {
    $skillsPath = Resolve-PackagePath $repositoryRoot $skillsDirectory
    (Get-ChildItem -LiteralPath $skillsPath -Recurse -File -Filter 'SKILL.md').FullName
})
if ($actualSkillFiles.Count -ne 15 -or
    @($actualSkillFiles | Sort-Object -Unique).Count -ne $actualSkillFiles.Count -or
    (Compare-Object ($expectedSkillFiles | Sort-Object) ($actualSkillFiles | Sort-Object))) {
    throw 'Root plugin must include each of the 15 upstream skills exactly once.'
}

$rootConfig = Read-JsonFile (Resolve-PackagePath $repositoryRoot $rootPlugin.mcpServers)
if ($rootConfig.mcpServers.Count -ne 7 -or
    (Compare-Object @($expectedServers.Keys | Sort-Object) @($rootConfig.mcpServers.Keys | Sort-Object))) {
    throw 'Root MCP config must include all seven upstream servers.'
}
foreach ($serverName in $expectedServers.Keys) {
    $expected = $expectedServers[$serverName] | ConvertTo-Json -Depth 100 -Compress
    $actual = $rootConfig.mcpServers[$serverName] | ConvertTo-Json -Depth 100 -Compress
    if ($expected -cne $actual) {
        throw "Root MCP config differs from upstream plugin: $serverName"
    }
}

Write-Output "PASS: $($jsonFiles.Count) JSON files; matching catalogs; 8 plugins; 15 skills; 7 matching MCP definitions."