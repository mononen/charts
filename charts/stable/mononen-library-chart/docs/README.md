# Helm Chart Documentation

This folder contains Cursor Agent Skills for the common-library-chart.

## Skills

### new-helm-chart

**Location:** `new-helm-chart/SKILL.md`

Use when creating **new Helm charts from scratch** using the common-library-chart.

**Capabilities:**
- Component-based values.yaml structure
- Auto-generated ingress with configurable class and annotations
- Security contexts and resource limits
- Multi-environment configuration

### migrate-helm-chart

**Location:** `migrate-helm-chart/SKILL.md`

Use when **migrating existing Helm charts** to use the common-library-chart.

**Capabilities:**
- Restructures values.yaml to component-based
- Adds library dependency
- Updates template references
- Migrates ingress configuration

### modify-chart

**Location:** `modify-chart/SKILL.md`

Use when **making incremental changes** to existing Helm charts.

**Capabilities:**
- Add ingress (internal/external), sidecars, or init containers
- Add persistent storage, ConfigMaps, or Secrets
- Add CronJobs, Jobs, or ServiceMonitors
- Enable logging sidecar, customize ingress annotations

## References

**Location:** `references/`

Detailed reference materials loaded on-demand by the agent:

| File | Content |
|------|---------|
| `VALUES_PATTERNS.md` | Complete values.yaml templates |
| `COMPONENT_EXAMPLES.md` | Multi-container, storage, secrets, jobs |
| `INGRESS_CONFIG.md` | Ingress configuration and host generation |
| `TROUBLESHOOTING_CHARTS.md` | Issue resolution |
| `LOGGING_SIDECARS.md` | Alloy/Loki configuration |

## Setting Up Skills

All chart skills share the same references folder:

```bash
# new-helm-chart skill
mkdir -p ~/.cursor/skills/new-helm-chart
ln -s /path/to/mononen-library-chart/docs/new-helm-chart/SKILL.md ~/.cursor/skills/new-helm-chart/SKILL.md
ln -s /path/to/mononen-library-chart/docs/references ~/.cursor/skills/new-helm-chart/references

# migrate-helm-chart skill
mkdir -p ~/.cursor/skills/migrate-helm-chart
ln -s /path/to/mononen-library-chart/docs/migrate-helm-chart/SKILL.md ~/.cursor/skills/migrate-helm-chart/SKILL.md
ln -s /path/to/mononen-library-chart/docs/references ~/.cursor/skills/migrate-helm-chart/references

# modify-chart skill
mkdir -p ~/.cursor/skills/modify-chart
ln -s /path/to/mononen-library-chart/docs/modify-chart/SKILL.md ~/.cursor/skills/modify-chart/SKILL.md
ln -s /path/to/mononen-library-chart/docs/references ~/.cursor/skills/modify-chart/references
```

## Progressive Loading

The SKILL.md files are intentionally small (~150 lines) for efficient context usage. Reference files are loaded on-demand when the agent needs:

- Complete values.yaml templates
- Detailed component configuration examples
- Ingress configuration and host generation
- Troubleshooting procedures

## Version Information

- **Chart Library:** v1.0.0+
- **Registry:** `https://mononen.github.io/charts/`
- **Helm:** v3+
- **Kubernetes:** v1.21+
