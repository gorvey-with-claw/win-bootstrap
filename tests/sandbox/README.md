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

## 如何运行测试

### 一键启动

双击运行 `launch-sandbox.ps1` 脚本，或在 PowerShell 中执行：

```powershell
.\tests\sandbox\launch-sandbox.ps1
```

### 测试流程说明

1. **脚本检查**：自动检查 Windows Sandbox 是否已启用
2. **配置生成**：动态生成 `.wsb` 配置文件，将仓库目录映射到 Sandbox 内
3. **启动 Sandbox**：打开 Windows Sandbox 窗口
4. **自动执行**：Sandbox 启动后自动打开 PowerShell 终端，并运行映射进 Sandbox 的本地仓库脚本

### Sandbox 内自动执行的内容

Sandbox 启动后会自动：
1. 打开 PowerShell 终端窗口
2. 切换到映射进去的本地仓库目录
3. 直接运行该本地目录中的 `bootstrap.ps1` 进行测试

> 这里**不依赖远程仓库下载**。测试目标是你当前工作区里的脚本与配置，便于本地开发阶段快速验证。

### 注意事项

- 首次运行可能需要等待 Windows Sandbox 初始化
- 确保主机有足够的磁盘空间（建议至少 5GB 可用空间）
- Sandbox 内的网络连接默认启用，可以下载必要的依赖
- 测试完成后直接关闭 Sandbox 窗口即可，所有更改会自动丢弃

## 故障排除

### Sandbox 无法启动

- 确认 Windows 版本为专业版或企业版
- 确认已在 BIOS 中启用虚拟化（Intel VT-x 或 AMD-V）
- 检查 Hyper-V 功能是否已启用

### 脚本运行失败

- 检查 PowerShell 执行策略：`Get-ExecutionPolicy`
- 如需修改执行策略（管理员）：`Set-ExecutionPolicy RemoteSigned`

### 映射目录无法访问

- 确认仓库路径不包含特殊字符
- 检查主机目录权限
