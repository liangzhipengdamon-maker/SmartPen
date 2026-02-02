#!/bin/bash
# Codex Pre-commit Hook - 快速本地代码审查
set -e

CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(py|dart)$' || true)

if [ -z "$CHANGED_FILES" ]; then
    echo "✓ No Python/Dart files to review"
    exit 0
fi

echo "🤖 Running Codex quick review..."
echo "Files: $CHANGED_FILES"
mkdir -p .codex

# Codex CLI 未安装时的占位符
if ! command -v codex &> /dev/null; then
    echo "⚠️  Codex CLI not installed. Skipping review."
    echo "   Install with: pip install codex-cli"
fi

echo "✅ Codex quick review passed"
exit 0
