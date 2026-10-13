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
if ($catalog.plugins.Count -ne 9) {
    throw 'Expected nine marketplace plugins.'
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
        foreach ($skillFile in $skillFiles) {
            $frontmatter = Get-Content -LiteralPath $skillFile.FullName -TotalCount 8
            $nameLine = $frontmatter | Where-Object { $_ -match '^name:\s*(.+?)\s*$' } | Select-Object -First 1
            if (-not $nameLine) {
                throw "Missing skill name frontmatter: $($skillFile.FullName)"
            }
            $skillName = ([regex]::Match($nameLine, '^name:\s*(.+?)\s*$')).Groups[1].Value.Trim("'`"")
            if ($skillName -cne $skillFile.Directory.Name) {
                throw "Skill name/folder mismatch: $skillName != $($skillFile.Directory.Name)"
            }
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
if ($actualSkillFiles.Count -ne 26 -or
    @($actualSkillFiles | Sort-Object -Unique).Count -ne $actualSkillFiles.Count -or
    (Compare-Object ($expectedSkillFiles | Sort-Object) ($actualSkillFiles | Sort-Object))) {
    throw 'Root plugin must include each of the 26 marketplace skills exactly once.'
}

$chaosPlugin = Resolve-PackagePath $repositoryRoot 'plugins/chaos-studio'
$chaosSkillFiles = @(Get-ChildItem -LiteralPath (Join-Path $chaosPlugin 'skills') -Recurse -File -Filter 'SKILL.md')
if ($chaosSkillFiles.Count -ne 11) {
    throw 'Chaos Studio plugin must contain all 11 upstream skills.'
}
$requiredChaosAssets = @(
    'LICENSE',
    'README.md',
    'scripts/State.ps1',
    'scripts/Invoke-AzRest.ps1',
    'scripts/Invoke-AzChaos.ps1',
    'skills/chaos-study/references/study-method.md',
    'skills/chaos-study/references/report-contract.md',
    'skills/chaos-study/scripts/Invoke-ChaosStudy.ps1',
    'skills/chaos-impact/schema/impact-report.schema.json',
    'skills/chaos-impact/templates/report.md.tmpl',
    'skills/chaos-study-report/templates/study-report.html.tmpl'
)
foreach ($asset in $requiredChaosAssets) {
    $null = Resolve-PackagePath $chaosPlugin $asset
}
if (Get-ChildItem -LiteralPath $chaosPlugin -Recurse -Directory -Filter 'tests') {
    throw 'Chaos Studio marketplace package must not contain development test directories.'
}

$chaosScripts = @(Get-ChildItem -LiteralPath $chaosPlugin -Recurse -File -Filter '*.ps1')
if ($chaosScripts.Count -ne 54) {
    throw "Chaos Studio plugin must contain 54 runtime PowerShell files; found $($chaosScripts.Count)."
}
foreach ($scriptFile in $chaosScripts) {
    $tokens = $null
    $parseErrors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile(
        $scriptFile.FullName,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        $messages = $parseErrors.Message -join '; '
        throw "PowerShell syntax error in $($scriptFile.FullName): $messages"
    }
}

$markdownFiles = @(Get-ChildItem -LiteralPath $chaosPlugin -Recurse -File -Filter '*.md')
foreach ($markdownFile in $markdownFiles) {
    $content = Get-Content -LiteralPath $markdownFile.FullName -Raw
    foreach ($link in [regex]::Matches($content, '\]\(([^)]+)\)')) {
        $target = $link.Groups[1].Value
        if ($target -match '^(https?://|mailto:|#)' -or $target -match '[<>]') {
            continue
        }
        $relativeTarget = ($target -split '#')[0]
        $resolvedTarget = [IO.Path]::GetFullPath((Join-Path $markdownFile.DirectoryName $relativeTarget))
        if (-not (Test-Path -LiteralPath $resolvedTarget)) {
            throw "Broken relative Markdown link in $($markdownFile.FullName): $target"
        }
    }
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

Write-Output "PASS: $($jsonFiles.Count) JSON files; matching catalogs; 9 plugins; 26 skills; Chaos runtime assets; 7 matching MCP definitions."