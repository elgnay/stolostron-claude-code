# ACM Skills for Claude Code

This repository contains Claude Code skills for ACM (Advanced Cluster Management). Skills are organized into installable plugins based on functionality.

## 📦 Available Plugins

### Hub Certificate Tools (`hub-cert-tools`)
Certificate configuration checking and change assessment for ACM hub clusters.
- ✅ **check-hub-cert-config** - Check certificate compatibility with ACM
- ✅ **assess-hub-cert-change** - Assess risk of certificate changes

[📖 Full Documentation](plugins/hub-cert-tools/README.md)

## 🚀 Quick Installation

### Option 1: Using the Interactive Plugin Manager (Recommended)

```bash
/plugin
```

Then in the UI:
1. Go to the **Marketplaces** tab
2. Click "Add Marketplace"
3. Enter: `https://github.com/stolostron/claude-code.git`
4. Go to the **Discover** tab
5. Find **hub-cert-tools** and click Install

### Option 2: Using Commands

```bash
# Add this repository as a marketplace
/plugin marketplace add https://github.com/stolostron/claude-code.git

# Install the hub certificate tools plugin
/plugin install hub-cert-tools@acm-skills-marketplace
```

### Option 3: Manual Installation (Not Recommended)

Clone the repository and add to your Claude Code `settings.json`:

```json
{
  "skills": [
    "/path/to/stolostron/claude-code/plugins/hub-cert-tools/skills/check-hub-cert-config",
    "/path/to/stolostron/claude-code/plugins/hub-cert-tools/skills/assess-hub-cert-change"
  ]
}
```

## 🎯 Quick Start

Once installed, you can use the skills:

```bash
# Check hub cluster certificate configuration
/check-hub-cert-config --kubeconfig /path/to/kubeconfig

# Assess certificate change risk
/assess-hub-cert-change --kubeconfig /path/to/kubeconfig --new-cert /path/to/new-cert.pem
```

For detailed documentation, examples, and use cases, see the [hub-cert-tools plugin documentation](plugins/hub-cert-tools/README.md).

## 🏗️ Architecture

### Why Plugin-Based?

This repository is organized as a **marketplace** containing multiple **plugins**. Each plugin is a self-contained collection of related skills.

**Benefits:**
- ✅ **Modular Installation** - Users install only what they need
- ✅ **Self-Contained** - Each plugin includes its own skills, libraries, docs, and examples
- ✅ **No Dependencies** - Plugins don't depend on each other
- ✅ **Easy Maintenance** - Clear boundaries between different functionality areas

### Marketplace Structure

```
Marketplace (acm-skills-marketplace)
├── Plugin: hub-cert-tools
│   ├── Skill: check-hub-cert-config
│   └── Skill: assess-hub-cert-change
│
└── Plugin: your-future-plugin
    ├── Skill: your-skill-1
    └── Skill: your-skill-2
```

Users interact with it like:
```bash
/plugin install hub-cert-tools@acm-skills-marketplace
```

## 📚 Resources

- **[Plugin Documentation](plugins/hub-cert-tools/README.md)** - Complete documentation for hub-cert-tools
- **[Contributing Guide](CONTRIBUTING.md)** - How to add skills or create new plugins
- **[Usage Examples](plugins/hub-cert-tools/examples/usage.md)** - Real-world usage scenarios

## 🤝 Contributing

We welcome contributions!

**Want to contribute?** See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- How to add skills to existing plugins
- How to create new plugins
- Best practices and testing guidelines
- Repository structure reference

## 📄 License

See [LICENSE](LICENSE) for details.
