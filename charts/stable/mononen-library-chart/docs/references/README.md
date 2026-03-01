# Chart Reference Materials

**Purpose:** Detailed reference documentation for the common-library-chart. This folder is designed to be symlinked into Cursor skills for progressive loading.

## Reference Files

### Configuration References

| File | Purpose |
|------|---------|
| `VALUES_PATTERNS.md` | Complete values.yaml structure and patterns |
| `COMPONENT_EXAMPLES.md` | Multi-container, storage, secrets, jobs |
| `ALB_INGRESS_CONFIG.md` | ALB annotation helpers and patterns |

### Specialized Topics

| File | Purpose |
|------|---------|
| `LOGGING_SIDECARS.md` | Alloy/Loki configuration |

### Troubleshooting

| File | Purpose |
|------|---------|
| `TROUBLESHOOTING_CHARTS.md` | Common chart issues and solutions |

## Usage with Cursor Skills

This folder should be symlinked into each chart skill directory:

```bash
# For new-helm-chart skill
ln -s /path/to/ml-common-library-chart/docs/references ~/.cursor/skills/new-helm-chart/references

# For migrate-helm-chart skill
ln -s /path/to/ml-common-library-chart/docs/references ~/.cursor/skills/migrate-helm-chart/references
```

## Progressive Loading

The main SKILL.md files are intentionally kept small (~150-200 lines) for efficient context usage. These reference files are loaded on-demand when the agent needs:

- Complete values.yaml templates
- Detailed component configuration examples
- ALB ingress annotation helpers
- Troubleshooting procedures

## Adding More References

When adding new reference materials:
1. Create focused, single-purpose files
2. Use clear file names indicating content
3. Update this README with the new file
4. Reference from SKILL.md files as needed
