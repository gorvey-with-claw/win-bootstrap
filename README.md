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

### 示例：Starship

本仓库包含 [Starship](https://starship.rs)（跨 shell 提示符工具）作为自定义 bucket 的示例：

- **Manifest 文件**：`bucket/starship.json`
- **引用方式**：`mybucket/starship`
- **用途**：展示如何通过自定义 bucket 安装便携软件

Starship 是一个真实的开源项目，提供 Windows x64 便携版，适合作为自定义 bucket 机制的演示示例。

## 已知限制

1. **无软件分类**：初版不包含 3-9 分类功能，所有软件统一在 `apps.json` 中管理
2. **不自动安装 winget**：如果系统未安装 winget（Windows 10 早期版本），脚本不会自动安装，需要用户手动安装应用安装程序（App Installer）
3. **Sandbox 测试**：Windows Sandbox 测试环境搭建属于第二阶段工作，初版不包含

## 快速开始

### 方式一：克隆仓库后执行（推荐开发调试）

```powershell
# 克隆仓库
git clone <repository-url>
cd win-bootstrap

# 运行入口脚本
.\bootstrap.ps1
```

### 方式二：远程直接执行（快速恢复）

如果你不想克隆仓库，可以直接从 GitHub 远程执行：

```powershell
# 使用 Invoke-Expression 远程执行（推荐）
Invoke-Expression (Invoke-RestMethod -Uri "https://raw.githubusercontent.com/<username>/win-bootstrap/main/bootstrap.ps1")

# 或者先下载再执行
Invoke-RestMethod -Uri "https://raw.githubusercontent.com/<username>/win-bootstrap/main/bootstrap.ps1" -OutFile "$env:TEMP\bootstrap.ps1"
& "$env:TEMP\bootstrap.ps1"
```

**注意**：请将 `<username>` 替换为你的 GitHub 用户名。

## 配置软件清单

编辑 `apps.json` 来自定义你要安装的软件：

```json
[
  {
    "id": "git",
    "name": "Git",
    "installer": "scoop",
    "package": "git",
    "enabled": true
  }
]
```

字段说明：
- `id`：软件的唯一标识
- `name`：显示名称
- `installer`：安装器类型（`scoop` 或 `winget`）
- `package`：包名（Scoop 支持 `bucket/package` 格式）
- `enabled`：是否启用安装

## 常见问题

### Q: 为什么 Scoop 优先于 winget？

**A**: Scoop 更适合开发场景：
- 安装在用户目录，无需管理员权限
- 自动处理环境变量（PATH）
- 版本管理更灵活
- 便携软件支持更好

winget 适合安装系统级的大型应用程序。

### Q: 自定义 bucket 的软件无法安装？

**A**: 请检查以下几点：
1. 运行选项 `1` 确保 Scoop 和自定义 bucket 已正确注册
2. 检查 `bucket/<package>.json` 文件格式是否正确
3. 检查 manifest 中的 URL 是否可访问
4. 查看 Scoop 错误输出：`scoop install mybucket/package`

### Q: winget 提示 "找不到应用安装程序"？

**A**: 你的 Windows 版本可能较旧，需要手动安装 winget：
1. 打开 Microsoft Store
2. 搜索 "App Installer"
3. 点击更新（或安装）
4. 重启 PowerShell 后再试

或者直接从 GitHub 下载：[https://aka.ms/getwinget](https://aka.ms/getwinget)

### Q: 如何添加自己的便携软件到自定义 bucket？

**A**: 
1. 将软件文件放入 `assets/` 目录（可选，如果是公开下载链接可跳过）
2. 在 `bucket/` 创建 manifest JSON 文件
3. 在 `apps.json` 中添加条目，使用 `mybucket/package-name` 格式
4. 参考 `bucket/starship.json` 作为示例

### Q: 安装失败如何排查？

**A**: 脚本会输出分级日志，按以下步骤排查：
1. 查看红色 `[Error]` 级别的错误信息
2. 检查 Scoop 或 winget 是否可用：`scoop --version` / `winget --version`
3. 单独测试安装命令：`scoop install <package>` 或 `winget install --id <package>`
4. 检查网络连接（部分软件需要从 GitHub 下载）

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
