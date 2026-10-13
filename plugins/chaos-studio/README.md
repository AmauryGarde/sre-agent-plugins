# Azure Chaos Studio

This marketplace plugin packages the 11 skills from
[`microsoft/chaos-studio`](https://github.com/microsoft/chaos-studio) for import
into Azure SRE Agent.

## Included skills

- `start-chaos`
- `create-workspace`
- `setup-scenario`
- `run-scenario`
- `chaos-impact`
- `chaos-study`
- `chaos-study-design`
- `chaos-study-scope`
- `chaos-study-run`
- `chaos-study-report`
- `chaos-study-history`

The package includes the skills' runtime PowerShell scripts, shared libraries,
schemas, templates, KQL files, and references. Development tests are intentionally
excluded from the marketplace package.

## Runtime requirements

- PowerShell 7 or later
- Azure CLI with an authenticated Azure context
- The Azure CLI Chaos Studio commands required by the selected workflow
- Azure permissions appropriate to the requested read or write operation

The upstream `chaos-mcp` server is not registered by this marketplace plugin.
It is a local stdio server that requires a separately installed Python package
and is not a portable SRE Agent marketplace connector. The interactive skills
use their bundled PowerShell workflows instead. If you deploy `chaos-mcp`
separately, configure it as a separate SRE Agent connector.

## Safety

Importing the plugin does not create a workspace, configuration, run, role
assignment, or fault. The skills preserve the upstream approval, validation,
blast-radius, and dry-run gates. Review the exact workspace scope, targets,
permissions, duration, and abort criteria before approving any write or run.

## Source and license

The extracted skills come from the MIT-licensed
[`microsoft/chaos-studio`](https://github.com/microsoft/chaos-studio)
repository at commit `35b54fb9101dd4d13cc9d5070913d1d8ed9d6b2d`.
The upstream license is included in this plugin directory.
