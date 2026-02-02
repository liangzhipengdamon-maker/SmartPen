# 智能笔项目虚拟环境使用指南

## 快速开始

### 方法一：使用激活脚本（推荐）
```bash
cd /Users/Zhuanz/Documents/01_SmartPen/smartpen-project
./activate_penenv.sh
```

### 方法二：手动激活
```bash
cd /Users/Zhuanz/Documents/01_SmartPen/smartpen-project
source venv/bin/activate
```

### 方法三：退出虚拟环境
```bash
deactivate
```

## 环境特性

- ✅ **项目专用**：仅在当前项目目录内有效
- ✅ **独立隔离**：不会影响系统全局Python环境
- ✅ **自动依赖安装**：首次激活时会自动安装项目依赖
- ✅ **便捷管理**：提供专门的激活脚本

## 验证环境状态

激活后，可以使用以下命令验证：
```bash
# 检查Python路径
which python

# 检查Python版本
python --version

# 检查已安装包
pip list
```

## 开发工作流

1. 进入项目目录
2. 激活虚拟环境
3. 进行开发工作
4. 退出虚拟环境（可选）

## 注意事项

- 虚拟环境目录 `venv/` 已添加到 `.gitignore`，不会被提交到版本控制
- 如果需要重新创建虚拟环境，只需删除 `venv/` 目录并重新运行激活脚本
- 所有Python依赖都应通过 `pip install -r backend/requirements.txt` 安装
