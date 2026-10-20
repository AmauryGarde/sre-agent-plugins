# Azure Chaos Studio

This marketplace plugin packages the 11 skills from
[`microsoft/chaos-studio`](https://github.com/microsoft/chaos-studio) for import
into Azure SRE Agent.

## Included skills

| Skill | Purpose |
| --- | --- |
| `start-chaos` | Orchestrate authentication, workspace, scenario, and run |
| `create-workspace` | Provision a workspace, identity, and RBAC |
| `setup-scenario` | Discover, configure, and validate scenarios |
| `run-scenario` | Execute a scenario and follow its results |
| `chaos-impact` | Correlate run impact with Azure Monitor signals |
| `chaos-study` | Guide a targeted study from scope to report |
| `chaos-study-design` | Inspect a system and propose scenario candidates |
| `chaos-study-scope` | Freeze the question, targets, and evidence plan |
| `chaos-study-run` | Preview or execute a frozen plan with typed consent |
| `chaos-study-report` | Render collected evidence as an HTML report |
| `chaos-study-history` | List, compare, and re-run past studies |

The package includes the skills' runtime PowerShell scripts, shared libraries,
schemas, templates, KQL files, and references. Development tests are intentionally
excluded from the marketplace package.

## Runtime requirements

- PowerShell 7.4 or later (`pwsh`)
- Azure CLI 2.75 or later (`az`) with an authenticated Azure context
- The Azure CLI `chaos` extension required by the selected workflow
- Azure permissions appropriate to the requested read or write operation

These are the upstream runtime prerequisites, not dependencies installed by
marketplace import. Verify them in the SRE execution environment before using
the skills. The workflows target `Microsoft.Chaos` API `2026-05-01-preview`;
availability and permissions must be checked for the intended subscription.

The upstream `chaos-mcp` server is not registered by this marketplace plugin.
It is a local stdio server that requires a separately installed Python package
and is not a portable SRE Agent marketplace connector. The interactive skills
use their bundled PowerShell workflows instead. If you deploy `chaos-mcp`
separately, configure it as a separate SRE Agent connector.

## Import and verify

1. In **Builder > Plugins > Add marketplace**, enter
   `https://github.com/AmauryGarde/sre-agent-plugins`.
2. Open `chaos-studio`, preview its skills, and select **Install** (or
   **Import selected** if the portal presents a skill-selection step).
3. In **Builder > Skill builder**, verify that all 11 skills above are present.
   This plugin has no additional MCP connector requirement.
4. Start with `chaos-study-design` for planning. Before execution, review a
   `chaos-study-run` dry run and obtain the required explicit consent.

For a standalone import, use **Install from URL** with the same base repository
URL and set **Path in repo** to `plugins/chaos-studio`. Leave that field empty
only when you intend to install the entire root bundle.

Installations are pinned to the source commit. A Git push does not update an
already installed plugin: explicitly check for updates and review/import the
new version in the portal. Avoid installing both this plugin and the root
bundle, which would duplicate its skills.

See Microsoft's [marketplace installation guide](https://learn.microsoft.com/azure/sre-agent/install-plugin-from-marketplace)
and [standalone installation guide](https://learn.microsoft.com/azure/sre-agent/install-plugin-from-url).
Local packaging validation does not confirm installation or runtime execution
inside a particular SRE Agent instance.

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

Packaging adaptations: the SRE manifest replaces the Copilot CLI manifest,
the five interactive skill introductions point to this README instead of the
unbundled MCP documentation, and development tests, custom agents, and the
Python MCP package are omitted. The runtime scripts retain upstream behavior.
