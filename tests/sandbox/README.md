# Windows Sandbox 测试环境

## 什么是 Windows Sandbox 测试

Windows Sandbox 是 Windows 10/11 专业版和企业版提供的一项轻量级虚拟化功能。它提供了一个干净、临时的 Windows 环境，非常适合测试安装脚本和软件，而不会影响主机系统。

### 主要特点

- **干净环境**：每次启动都是全新的 Windows 系统
- **完全隔离**：Sandbox 内的操作不会影响主机
- **自动清理**：关闭后所有更改自动丢弃
- **轻量级**：基于 Windows 容器技术，启动快速

## 如何启用 Windows Sandbox 功能

### 方法一：通过 Windows 功能界面

1. 按 `Win + R`，输入 `optionalfeatures` 回车
2. 找到 **Windows Sandbox** 选项并勾选
3. 点击确定，等待安装完成
4. 重启电脑

### 方法二：通过 PowerShell（管理员）

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClient" -All
```

安装完成后需要重启电脑。

### 验证是否启用

```powershell
Get-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClient"
```

如果显示 `State : Enabled`，则表示已启用。

## 两种测试模式

本测试环境提供**两种** Windows Sandbox 测试模式，分别用于不同场景：

### 模式一：Mapped Mode（映射本地代码）——开发调试

**用途**：快速验证你当前工作区里的代码修改

**行为**：
- 将主机上的本地仓库目录**映射**进 Sandbox
- Sandbox 内直接运行映射的本地 `bootstrap.ps1`
- **无需网络下载**，启动最快
- 本地代码修改立即生效

**适用场景**：
- 开发阶段快速验证脚本逻辑
- 调试 apps.json 配置变更
- 测试 bucket manifest 修改
- 验证修复是否生效

**启动方式**：
```powershell
# 使用参数
.\tests\sandbox\launch-sandbox.ps1 -Mode Mapped

# 或通过菜单选择
.\tests\sandbox\launch-sandbox.ps1
# 然后输入 1
```

### 模式二：Clean Clone Mode（干净克隆）——生产验证

**用途**：模拟真实用户从 GitHub 克隆并执行的完整流程

**行为**：
- Sandbox 内**不映射**主机目录
- Sandbox 启动后自动从 GitHub 克隆仓库
- 克隆完成后执行 `bootstrap.ps1`
- 完全模拟新用户的首次使用体验

**适用场景**：
- 发布前验证 GitHub 仓库可正常克隆和执行
- 验证 README 中的 clone 指令是否准确
- 测试网络依赖（Scoop、winget 下载）
- 确保推送的代码在生产环境可用

**启动方式**：
```powershell
# 使用参数
.\tests\sandbox\launch-sandbox.ps1 -Mode CleanClone

# 或通过菜单选择
.\tests\sandbox\launch-sandbox.ps1
# 然后输入 2
```

## 如何选择测试模式

| 场景 | 推荐模式 | 原因 |
|------|----------|------|
| 修改了代码，想快速验证 | **Mapped** | 无需等待克隆，即时反馈 |
| 测试 apps.json 变更 | **Mapped** | 本地修改立即生效 |
| 准备发布前最终验证 | **CleanClone** | 确保 GitHub 上的代码可用 |
| 验证 README 指令 | **CleanClone** | 模拟真实用户操作 |
| 排查网络/下载问题 | **CleanClone** | 完整依赖网络流程 |
| 调试 bucket manifest | **Mapped** | 本地文件修改即时生效 |

## 快速启动

### 通过菜单选择（推荐）

直接运行脚本，按提示选择模式：

```powershell
.\tests\sandbox\launch-sandbox.ps1
```

输出示例：
```
Windows Sandbox Test Modes
==========================

1 - Mapped Mode: Test with local repository (fast, for development)
    Maps current working directory into Sandbox and runs local code.

2 - Clean Clone Mode: Test fresh GitHub clone (simulates real user)
    Clones repository from GitHub inside Sandbox, then runs bootstrap.

Enter mode (1/2):
```

### 通过参数指定模式

适合自动化或脚本调用：

```powershell
# 模式一：测试本地代码
.\tests\sandbox\launch-sandbox.ps1 -Mode Mapped

# 模式二：测试 GitHub 克隆
.\tests\sandbox\launch-sandbox.ps1 -Mode CleanClone
```

## 测试流程说明

### Mapped Mode 流程

1. **脚本检查**：验证 Windows Sandbox 功能已启用
2. **路径解析**：获取本地仓库根目录
3. **配置生成**：生成 `.wsb` 文件，配置本地目录映射
4. **启动 Sandbox**：打开 Windows Sandbox 窗口
5. **自动执行**：Sandbox 内运行映射的本地 `bootstrap.ps1`

### Clean Clone Mode 流程

1. **脚本检查**：验证 Windows Sandbox 功能已启用
2. **配置生成**：生成 `.wsb` 文件，无目录映射，仅配置启动命令
3. **启动 Sandbox**：打开 Windows Sandbox 窗口
4. **克隆仓库**：Sandbox 内自动执行 `git clone`
5. **自动执行**：克隆完成后运行 `bootstrap.ps1`

## 注意事项

- 首次运行可能需要等待 Windows Sandbox 初始化
- 确保主机有足够的磁盘空间（建议至少 5GB 可用空间）
- **Mapped Mode** 不需要网络，**Clean Clone Mode** 需要网络连接 GitHub
- 测试完成后直接关闭 Sandbox 窗口即可，所有更改会自动丢弃
- Clean Clone Mode 每次测试都从 GitHub 拉取最新代码

## 故障排除

### Sandbox 无法启动

- 确认 Windows 版本为专业版或企业版
- 确认已在 BIOS 中启用虚拟化（Intel VT-x 或 AMD-V）
- 检查 Hyper-V 功能是否已启用

### 脚本运行失败

- 检查 PowerShell 执行策略：`Get-ExecutionPolicy`
- 如需修改执行策略（管理员）：`Set-ExecutionPolicy RemoteSigned`

### Mapped Mode：映射目录无法访问

- 确认仓库路径不包含特殊字符
- 检查主机目录权限

### Clean Clone Mode：克隆失败

- 检查网络连接
- 确认 GitHub 可访问
- 检查 `git` 命令是否可用（Windows Sandbox 默认可能未安装 Git）
  - 如果未安装，需要在 Clean Clone 逻辑中先安装 Git

## 技术说明

### 生成的 .wsb 文件位置

- **Mapped Mode**：`$env:TEMP\win-bootstrap-mapped.wsb`
- **Clean Clone Mode**：`$env:TEMP\win-bootstrap-clean-clone.wsb`

这些临时文件会在每次运行时重新生成，使用最新的配置。

### 与 README 中方式的对应关系

- **Mapped Mode** ≠ README 中的方式（README 要求 clone 后执行）
- **Clean Clone Mode** ≈ README 中的方式（完整模拟 clone + 执行）

**建议**：在推送代码前，使用 Clean Clone Mode 验证，确保 GitHub 上的仓库状态与用户按 README 操作时的体验一致。