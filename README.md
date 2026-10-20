# Azure SRE Agent Plugins

Repackaged from [Azure/sre-agent-plugins](https://github.com/Azure/sre-agent-plugins), upstream commit `3783a11f2f6e3c9b47c6dd9f5b39720ef66b37a3`,
and extended with the MIT-licensed Chaos Studio skills from
[microsoft/chaos-studio](https://github.com/microsoft/chaos-studio), commit
`35b54fb9101dd4d13cc9d5070913d1d8ed9d6b2d`.
The catalog contains nine plugins and 26 skills.

> **Note:** These plugins are designed for use with the [Azure SRE Agent](https://azure.microsoft.com/en-us/products/sre-agent) and may not work with other coding agents.

## Install in Azure SRE Agent

The publication target is the standalone repository
[AmauryGarde/sre-agent-plugins](https://github.com/AmauryGarde/sre-agent-plugins),
with the package at the root of its default branch, `main`.
The SRE repository field accepts a base repository reference, not a `/tree/<branch>` URL:

```text
https://github.com/AmauryGarde/sre-agent-plugins
```

1. In **Builder > Plugins**, choose **Add marketplace** and enter the base repository URL above (or `AmauryGarde/sre-agent-plugins`). Authenticate with a GitHub connection that can read the repository if it is private.
2. Install only the plugins you need from the nine-plugin catalog. Choose `chaos-studio` for the 11 Chaos Studio v2 workflows, or start with `azure-proactive-operations` for Azure assessments without an external MCP server.
3. Alternatively, choose **Install from URL** with the same base repository URL to import the root `sre-agent-plugins` bundle: all 26 skills and seven MCP server requirements.
4. Configure the required MCP connectors separately in SRE Agent. Installation records the requirements; it does not authenticate or provision the connectors.

To install **only Chaos Studio** without registering the catalog, use
**Install from URL** with the base repository URL above and **Path in repo**
set to `plugins/chaos-studio`. Verify its 11 skills in **Builder > Skill builder**.
See the [Chaos Studio setup guide](plugins/chaos-studio/README.md) for the
skill list, runtime prerequisites, safety gates, and update procedure.

Installations are pinned to a git commit: publishing changes does not silently
update existing agents. Check for updates explicitly in the portal and review
the new version before importing it.

Do not install the bundle and its individual plugins together unless you intentionally want duplicate skills.
Do not use the demo repository or append `/tree/main`, a folder path, or a manifest filename to the repository field.
Packaging is validated locally; installation in your SRE Agent instance still needs to be confirmed.

## Why the root manifest exists

Upstream already contains `plugins/<name>/plugin.json` for each plugin and a catalog at
`.github/plugin/marketplace.json`, but no `plugin.json` at the repository root.
A single-plugin importer pointed at that root can therefore report a missing manifest.
This copy supports both entry points:

| File | Purpose |
| --- | --- |
| `marketplace.json` | Root catalog listing nine individually installable plugins |
| `.github/plugin/marketplace.json` | Matching catalog at the original upstream location |
| `plugin.json` | Standalone root bundle referencing all existing skill directories |
| `.mcp.json` | Seven MCP server definitions needed by the standalone bundle |
| `plugins/<name>/plugin.json` | Individual SRE plugin manifests; Chaos Studio uses an adapted skills-only manifest |

The root bundle references existing files rather than duplicating skill content.
The marketplace is named `amaury-sre-agent-plugins` to distinguish it from the upstream catalog.

## Chaos Studio plugin

The `chaos-studio` plugin includes the 11 upstream skill definitions and their
runtime PowerShell scripts, shared libraries, templates, schemas, KQL files, and
references. Development tests are excluded. The plugin does not register the
upstream local stdio `chaos-mcp` server because marketplace import cannot install
its Python runtime portably. The interactive skills use their bundled PowerShell
workflows; deploy and register `chaos-mcp` separately if you need its autonomous
tool surface.

Importing the plugin performs no Azure changes. Workspace creation, RBAC changes,
scenario configuration, and fault execution remain behind the skills' explicit
approval and validation gates.

## Connector setup

MCP configurations contain upstream placeholder endpoints and credentials only. Replace these in the
SRE Agent connector setup, not in Git. Never commit real tokens, API keys, or tenant credentials.
See each plugin's README for its prerequisites. This packaging change does not validate external-service connectivity.

The AWS definition is preserved verbatim from upstream. Its bearer-token placeholder is not a
complete authentication recipe for the AWS MCP endpoint: AWS access requires an appropriate
SigV4-signing integration or proxy. Follow the current
[Microsoft AWS integration walkthrough](https://techcommunity.microsoft.com/blog/appsonazureblog/announcing-aws-with-azure-sre-agent-cross-cloud-investigation-using-the-brand-ne/4507413)
before using that connector.

## Validate the package

Run from this repository with PowerShell 7 or later:

```powershell
pwsh -NoProfile -File ./scripts/Test-PluginPackaging.ps1
```

The check parses every JSON file, compares both marketplace catalogs, resolves every manifest path,
checks all 26 skills are included exactly once, validates skill names, descriptions, and required
Chaos Studio runtime assets, and compares the seven bundled MCP definitions
against their individual plugin configurations.

## Adding plugins

1. Add the plugin directory under `plugins/` in this repository.
2. Add matching entries to [`marketplace.json`](marketplace.json) and [`.github/plugin/marketplace.json`](.github/plugin/marketplace.json).
3. Add the skill directory to the root [`plugin.json`](plugin.json) and any MCP server to [`.mcp.json`](.mcp.json).
4. Update the expected counts in the validation script and run it before publishing.
