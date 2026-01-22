# 应用图标说明

图标位置: `android/app/src/main/res/mipmap-*/ic_launcher.png`

## 图标尺寸

| 文件夹 | 尺寸 |
|--------|------|
| mipmap-mdpi | 48x48 px |
| mipmap-hdpi | 72x72 px |
| mipmap-xhdpi | 96x96 px |
| mipmap-xxhdpi | 144x144 px |
| mipmap-xxxhdpi | 192x192 px |

## 生成图标

### 方法 1: 使用在线工具

访问 https://icon.kitchen/ 或 https://easyappicon.com/ 生成图标

### 方法 2: 使用 Flutter 命令

```bash
# 将图标放入 android/app/src/main/res/mipmap-*/ 目录
# 或使用 flutter_launcher_icons 包
```

### 方法 3: 手动创建

1. 设计一个 192x192 的 PNG 图标
2. 使用 Android Studio 的 Image Asset Studio 生成各尺寸图标
3. 放入对应的 mipmap 文件夹

## 临时图标

当前使用默认的 Android 图标，请替换为您自己的应用图标。
