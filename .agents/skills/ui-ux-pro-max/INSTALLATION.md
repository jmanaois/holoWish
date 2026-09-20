# Project installation

Source: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
Revision: de5f12b400775997d213524ef02a7c7d2746806f
Source directory: `.claude/skills/ui-ux-pro-max`
Installed with the Codex skill-installer into `.agents/skills/ui-ux-pro-max`.

The self-contained upstream skill includes scripts, data, and references. Its Claude-specific script paths were changed to a portable `<skill-dir>` placeholder resolved from SKILL.md. The upstream MIT license is included.

For this native iOS project, use `--stack swiftui` for implementation guidance. From the repository root:

```sh
python3 .agents/skills/ui-ux-pro-max/scripts/search.py "navigation accessibility" --stack swiftui -n 3
```

Whitespace-only lines in `scripts/design_system.py` were normalized for repository whitespace checks.
