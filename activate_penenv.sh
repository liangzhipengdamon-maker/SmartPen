#!/bin/bash
# 智能笔项目专用虚拟环境激活脚本
# 仅在项目目录内使用，不会影响全局环境

PROJECT_DIR="/Users/Zhuanz/Documents/01_SmartPen/smartpen-project"
VENV_DIR="$PROJECT_DIR/venv"

# 检查是否在项目目录内
if [ "$PWD" != "$PROJECT_DIR" ]; then
    echo "⚠️  请先进入项目目录: cd $PROJECT_DIR"
    exit 1
fi

# 检查虚拟环境是否存在
if [ ! -d "$VENV_DIR" ]; then
    echo "❌ 虚拟环境不存在，正在创建..."
    python3 -m venv venv
    echo "✅ 虚拟环境创建完成"
fi

# 激活虚拟环境
source "$VENV_DIR/bin/activate"

echo "✅ 虚拟环境已激活"
echo "📁 项目目录: $PROJECT_DIR"
echo "🐍 Python路径: $(which python)"
echo "💡 使用 'deactivate' 退出虚拟环境"
echo ""
echo "🔍 验证命令:"
echo "    which python    # 查看Python路径"
echo "    pip list         # 查看已安装包"
echo "    python --version # 查看Python版本"
