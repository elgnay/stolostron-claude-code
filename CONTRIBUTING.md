# Contributing to ACM Skills Marketplace

Thank you for contributing to the ACM Skills marketplace for Claude Code!

This repository is organized as a **marketplace** containing multiple **plugins**, where each plugin is a self-contained collection of related skills.

## Table of Contents

- [Types of Contributions](#types-of-contributions)
- [Adding a Skill to Existing Plugin](#adding-a-skill-to-existing-plugin)
- [Creating a New Plugin](#creating-a-new-plugin)
- [Best Practices](#best-practices)
- [Testing Locally](#testing-locally)
- [Submitting Your Contribution](#submitting-your-contribution)

## Types of Contributions

### 1. Adding a Skill to an Existing Plugin

Choose this if your skill belongs to an existing functional area (e.g., hub certificate management).

**When to choose:** Your skill is related to existing functionality in a plugin.

### 2. Creating a New Plugin

Choose this if your skill represents a new functional area (e.g., cluster lifecycle, policy management).

**When to choose:** Your skill doesn't fit into existing plugins.

## Adding a Skill to Existing Plugin

Example: Adding a skill to the `hub-cert-tools` plugin.

### Step 1: Create Skill Directory

```bash
mkdir -p plugins/hub-cert-tools/skills/your-skill-name
cd plugins/hub-cert-tools/skills/your-skill-name
```

### Step 2: Create SKILL.md

Every skill needs a `SKILL.md` file with frontmatter:

```markdown
---
name: your-skill-name
description: Brief description of what your skill does
invocation_pattern: "^/your-skill-name"
---

# Your Skill Name

Instructions for Claude on how to execute this skill.

## 🚀 Execution Instructions

**When this skill is invoked:**

1. **Parse Arguments**
   - List expected arguments
   - Handle defaults

2. **Execute Workflow**
   - Step-by-step execution flow
   - What commands to run

3. **Present Results**
   - How to format output
   - What to show the user

## Parameters

### Required
- `--param1 <value>` - Description

### Optional
- `--param2 <value>` - Description (defaults to X)

## Usage Examples

\`\`\`bash
/your-skill-name --param1 value
\`\`\`

## When to Use This Skill

- Use case 1
- Use case 2

## Prerequisites

- Requirement 1
- Requirement 2
```

### Step 3: Add Scripts (if needed)

If your skill requires shell scripts:

```bash
mkdir -p scripts
# Create your scripts in scripts/
# You can use shared libraries from the plugin's lib/ directory
```

### Step 4: Create README.md

Create a user-facing README for your skill:

```markdown
# Your Skill Name

Brief description of what it does.

## What This Skill Does

Detailed explanation...

## Quick Start

\`\`\`bash
/your-skill-name --param value
\`\`\`

## Parameters

...

## Examples

...
```

### Step 5: Update Plugin README

Update `plugins/hub-cert-tools/README.md`:

```markdown
## Included Skills

### 1. Existing Skill
...

### 2. Your New Skill
- **Command**: `/your-skill-name`
- **Purpose**: Brief description
- **Documentation**: [Full README](skills/your-skill-name/README.md)
```

### Step 6: Test Locally

See [Testing Locally](#testing-locally) section below.

## Creating a New Plugin

Example: Creating a plugin for cluster lifecycle management.

### Step 1: Create Plugin Structure

```bash
mkdir -p plugins/cluster-lifecycle/.claude-plugin
mkdir -p plugins/cluster-lifecycle/skills
mkdir -p plugins/cluster-lifecycle/examples
```

### Step 2: Create Plugin Metadata

Create `plugins/cluster-lifecycle/.claude-plugin/plugin.json`:

```json
{
  "name": "cluster-lifecycle",
  "version": "1.0.0",
  "description": "Cluster lifecycle management skills for ACM",
  "author": {
    "name": "stolostron"
  }
}
```

**Naming guidelines:**
- Use **kebab-case** (lowercase with hyphens)
- Keep it concise and descriptive
- No "acm-" prefix (the marketplace already provides that context)

### Step 3: Add Your Skills

Create skills under `plugins/cluster-lifecycle/skills/`:

```bash
mkdir -p plugins/cluster-lifecycle/skills/import-cluster
# Create SKILL.md, README.md, scripts/, etc.
```

Follow the [Adding a Skill](#adding-a-skill-to-existing-plugin) guide for each skill.

### Step 4: Create Plugin README

Create `plugins/cluster-lifecycle/README.md`:

```markdown
# ACM Cluster Lifecycle

This plugin provides cluster lifecycle management skills for ACM.

## Included Skills

### 1. Import Cluster
- **Command**: `/import-cluster`
- **Purpose**: Import a cluster into ACM
- **Documentation**: [Full README](skills/import-cluster/README.md)

## Installation

### From Marketplace

\`\`\`bash
/plugin marketplace add https://github.com/stolostron/claude-code.git
/plugin install cluster-lifecycle@acm-skills-marketplace
\`\`\`

## Use Cases

...

## Prerequisites

...
```

### Step 5: Add Usage Examples

Create `plugins/cluster-lifecycle/examples/usage.md` with detailed usage examples.

### Step 6: Register in Marketplace

Update `.claude-plugin/marketplace.json`:

```json
{
  "name": "acm-skills-marketplace",
  "owner": {
    "name": "stolostron"
  },
  "description": "Claude Code skills for ACM (Advanced Cluster Management)",
  "plugins": [
    {
      "name": "hub-cert-tools",
      "source": "./plugins/hub-cert-tools",
      "description": "Hub cluster certificate tools - check configuration and assess certificate changes"
    },
    {
      "name": "cluster-lifecycle",
      "source": "./plugins/cluster-lifecycle",
      "description": "Cluster lifecycle management - import, upgrade, and detach clusters"
    }
  ]
}
```

### Step 7: Update Root README

Add your plugin to the main `README.md`:

```markdown
## 📦 Available Plugins

### Hub Certificate Tools (`hub-cert-tools`)
...

### Cluster Lifecycle (`cluster-lifecycle`)
Cluster lifecycle management for ACM - import, upgrade, and detach clusters.
- ✅ **import-cluster** - Import clusters into ACM
- ✅ **upgrade-cluster** - Upgrade managed clusters

[📖 Full Documentation](plugins/cluster-lifecycle/README.md)
```

## Best Practices

### Plugin Design

✅ **Do:**
- Keep plugins focused on a specific functional area
- Make plugins self-contained (no dependencies between plugins)
- Include comprehensive documentation and examples
- Use clear, descriptive names
- Provide both SKILL.md (for Claude) and README.md (for users)

❌ **Don't:**
- Create overly broad plugins that do everything
- Create dependencies between plugins
- Duplicate functionality across plugins

### Skill Design

✅ **Do:**
- Write clear, specific instructions in SKILL.md
- Include concrete examples
- Document ACM-specific knowledge
- Keep skills focused on one task
- Test thoroughly before submitting
- Use actual file paths and commands (not placeholders)
- Include error handling guidance

❌ **Don't:**
- Create overly broad skills
- Hard-code sensitive information
- Use vague instructions
- Skip testing

### Shared Code

**Within a plugin:**
- ✅ Share libraries between skills in the same plugin
- Place shared code in `plugins/<plugin-name>/skills/<any-skill>/scripts/lib/`
- Other skills in the same plugin can reference these libraries

**Between plugins:**
- ❌ Don't create dependencies between plugins
- ✅ Duplicate code if needed (plugins must be self-contained)

### Documentation

Each plugin should include:
- ✅ `README.md` - User-facing documentation
- ✅ `examples/usage.md` - Detailed usage examples
- ✅ Each skill has both `SKILL.md` and `README.md`

## Testing Locally

### Test Individual Skills

1. **Symlink the skill** to your project:
   ```bash
   mkdir -p .claude/skills
   ln -s /absolute/path/to/plugins/hub-cert-tools/skills/your-skill .claude/skills/
   ```

2. **Test the skill**:
   ```bash
   /your-skill-name --your-params
   ```

3. **Verify it works** as expected

### Test Entire Plugin

1. **Install the plugin locally**:
   ```bash
   # Add the local repository as a marketplace
   /plugin marketplace add file:///absolute/path/to/claude-code

   # Install your plugin
   /plugin install your-plugin-name@acm-skills-marketplace
   ```

2. **Test all skills** in the plugin

3. **Verify installation** works correctly

## Submitting Your Contribution

### 1. Commit Your Changes

```bash
# For new skill in existing plugin
git add plugins/hub-cert-tools/skills/your-skill-name
git commit -m "Add your-skill-name to hub-cert-tools"

# For new plugin
git add plugins/your-plugin-name .claude-plugin/marketplace.json README.md
git commit -m "Add your-plugin-name plugin"
```

### 2. Push and Create Pull Request

```bash
git push origin your-branch-name
```

Then create a pull request on GitHub.

### 3. Pull Request Checklist

- [ ] Skill has both SKILL.md and README.md
- [ ] Plugin README is updated with new skill
- [ ] Examples are provided
- [ ] Tested locally and works correctly
- [ ] No sensitive information hard-coded
- [ ] Documentation is clear and comprehensive
- [ ] If new plugin: marketplace.json and root README.md updated

## ACM-Specific Guidelines

When creating ACM-related skills:

- ✅ Reference [official ACM documentation](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes) when relevant
- ✅ Include common `oc` commands for ACM resources
- ✅ Document ACM API versions and resource types
- ✅ Consider multi-cluster scenarios
- ✅ Include troubleshooting steps
- ✅ Document ACM version compatibility if applicable

## Repository Structure Reference

```text
claude-code/
├── .claude-plugin/
│   └── marketplace.json              # Marketplace catalog (lists all plugins)
├── README.md                         # Main documentation
├── CONTRIBUTING.md                   # This file
│
└── plugins/                          # All plugins
    ├── hub-cert-tools/               # Example plugin
    │   ├── .claude-plugin/
    │   │   └── plugin.json           # Plugin metadata
    │   ├── README.md                 # Plugin documentation
    │   ├── examples/
    │   │   └── usage.md              # Usage examples
    │   └── skills/
    │       ├── check-hub-cert-config/
    │       │   ├── SKILL.md          # Claude instructions
    │       │   ├── README.md         # User documentation
    │       │   └── scripts/
    │       │       ├── script.sh
    │       │       └── lib/          # Shared libraries
    │       └── assess-hub-cert-change/
    │           ├── SKILL.md
    │           ├── README.md
    │           └── scripts/
    │
    └── your-plugin/                  # Your new plugin
        ├── .claude-plugin/
        │   └── plugin.json
        ├── README.md
        ├── examples/
        │   └── usage.md
        └── skills/
            └── your-skill/
                ├── SKILL.md
                ├── README.md
                └── scripts/
```

## Need Help?

- 📖 Check existing plugins for examples (especially `hub-cert-tools`)
- 📝 [Claude Code documentation](https://code.claude.com/docs)
- 🐛 Open an issue for questions
- 💬 Discuss in pull requests

## License

By contributing, you agree that your contributions will be licensed under the same license as this repository.

---

Thank you for contributing to making ACM management easier with Claude Code! 🚀
