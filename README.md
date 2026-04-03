# Windows 软件恢复仓库

一个用于快速恢复 Windows 开发环境的自动化脚本仓库。

## 仓库用途

本仓库旨在帮助用户在重装 Windows 系统后，快速恢复常用的开发工具和应用程序。通过简单的入口脚本，可以选择性地安装 Scoop 包管理器管理的工具、winget 管理的应用程序，或全部安装。

## 第一版范围

初版聚焦于核心开发工具的快速恢复，包含以下功能：

- Scoop 包管理器的自动安装与配置
- 常用开发工具（Git、7-Zip、VS Code 等）的批量安装
- 自定义 Scoop bucket 支持便携软件
- winget 应用程序的基础支持

## 入口选项

运行 `bootstrap.ps1` 时，会提供以下三个选项：

| 选项 | 含义 | 说明 |
|------|------|------|
| `0` | 安装全部 | 安装 Scoop 和 winget 管理的所有已启用软件 |
| `1` | 安装 Scoop | 仅安装 Scoop 包管理器及其管理的软件 |
| `2` | 安装 winget | 仅安装 winget 管理的软件 |

## Scoop 与 winget 的职责边界

### Scoop

- **定位**：开发者工具、命令行工具、便携软件
- **典型软件**：Git、7-Zip、VS Code、Node.js、Python 等
- **特点**：
  - 软件安装在用户目录，无需管理员权限
  - 支持自定义 bucket 安装非公开软件
  - 版本管理灵活，支持多版本并存

### winget

- **定位**：系统级应用程序、大型商业软件
- **典型软件**：Microsoft Office、Adobe Creative Cloud、浏览器等
- **特点**：
  - 使用 Windows 官方包管理器
  - 部分软件需要管理员权限
  - 依赖 Windows 系统组件

## 自定义 Bucket

`bucket/` 目录用于存放自定义 Scoop bucket 的 manifest 文件，主要用途：

- 安装未进入 Scoop 官方仓库的便携软件
- 管理内部工具或特定版本的软件
- 存放需要特殊安装配置的应用程序

自定义 bucket 的软件在 `apps.json` 中使用 `mybucket/package-name` 格式引用。

## 已知限制

1. **无软件分类**：初版不包含 3-9 分类功能，所有软件统一在 `apps.json` 中管理
2. **不自动安装 winget**：如果系统未安装 winget（Windows 10 早期版本），脚本不会自动安装，需要用户手动安装应用安装程序（App Installer）
3. **Sandbox 测试**：Windows Sandbox 测试环境搭建属于第二阶段工作，初版不包含

## 快速开始

```powershell
# 克隆仓库
git clone <repository-url>
cd win-bootstrap

# 运行入口脚本
.\bootstrap.ps1
```

## 项目结构

```
win-bootstrap/
├── bootstrap.ps1          # 入口脚本
├── apps.json              # 软件清单配置文件
├── README.md              # 本文件
├── scripts/
│   ├── common.ps1         # 公共函数
│   ├── install-scoop.ps1  # Scoop 安装脚本
│   ├── install-winget.ps1 # winget 检查脚本
│   └── install-apps.ps1   # 应用安装脚本
├── bucket/                # 自定义 Scoop bucket
└── assets/                # 便携软件资产
```

## 许可证

MIT
