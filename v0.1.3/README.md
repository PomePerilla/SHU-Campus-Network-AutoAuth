# SHU Campus Network AutoAuth CLI v0.1.3

上海大学校园网自动认证服务命令行版。

该版本提供一个可双击运行的安装向导。用户不需要手动逐条复制 PowerShell 命令；向导会自动请求管理员权限，检查系统和网络状态，完成账号配置，安装开机计划任务，运行测试，并输出最终状态。

## 适用网络环境

本项目只面向上海大学校园网 ePortal 认证环境。满足以下任一条件时通常可以使用：

- 有线校园网：Windows 电脑通过网口直连宿舍、实验室或其他校园网有线接口。
- 子网络接入设备：Windows 电脑通过路由器、交换机或其他子网络设备接入校园有线网，只要这台 Windows 电脑能够访问 `http://10.10.9.9` 并完成 ePortal 认证。
- 无线校园网：Windows 电脑连接无线网络 `Shu(ForAll)`。
- 其他校内网络：虽然不属于上述两类，但能够在浏览器访问 `http://10.10.9.9` 并进入上海大学 ePortal 登录认证页面。

不适用的情况：

- 设备不在上海大学校园网环境内。
- 无法访问 `http://10.10.9.9`。
- 所在网络不使用上海大学 ePortal 认证。
- 需要短信、二维码、CAS 单点登录或图形验证码等交互式认证方式。

## Requirements

- Windows 10/11 或 Windows Server
- Windows PowerShell 5.1
- 设备已连接可访问 `http://10.10.9.9` 的上海大学校园网
- 安装开机任务时需要管理员权限

## Download

推荐方式：下载 Release 包。

```text
https://github.com/PomePerilla/SHU-Campus-Network-AutoAuth/releases/download/v0.1.3/SHU-CNAA-v0.1.3.zip
```

解压后进入：

```text
SHU-CNAA-v0.1.3
```

方式二：下载源码 ZIP。

打开仓库页面：

```text
https://github.com/PomePerilla/SHU-Campus-Network-AutoAuth
```

点击 `Code` -> `Download ZIP`，解压后进入：

```text
SHU-Campus-Network-AutoAuth-main\v0.1.3
```

方式三：使用 Git。

```powershell
git clone https://github.com/PomePerilla/SHU-Campus-Network-AutoAuth.git
cd .\SHU-Campus-Network-AutoAuth\v0.1.3
```

## Recommended Setup

进入 `v0.1.3` 文件夹，双击运行：

```text
setup.cmd
```

安装向导会自动完成：

- 请求管理员权限。
- 显示 Windows、PowerShell、当前目录、配置文件、密码文件状态。
- 显示当前活动网络适配器。
- 检测互联网访问状态。
- 检测 `http://10.10.9.9` 校园网关状态。
- 检测计划任务是否已安装。
- 提示输入校园网账号、密码、服务名和网关地址。
- 创建本机配置和 DPAPI 加密密码文件。
- 安装开机自动认证计划任务。
- 运行一次测试。
- 显示最终计划任务状态和最近日志。

UAC 管理员权限弹窗需要用户手动确认。这是 Windows 安全机制，程序不能绕过。

## Configuration Inputs

向导会要求输入：

- 校园网账号。
- 校园网密码，不能为空；如果误按回车，会继续要求输入。
- 服务名，默认直接回车使用 `shu`。
- Portal 网关地址，默认直接回车使用 `http://10.10.9.9/`。
- 可选的完整 ePortal 登录 URL 备用值，通常直接回车跳过。

从 `v0.1.2` 开始，配置阶段不再要求用户复制 ePortal 登录页长 URL。用户下载项目时通常已经在线，所以此时强制获取登录页并不可靠。实际认证时，脚本会在检测到无法访问互联网后，再实时访问校园网关获取当前登录参数。

## Manual Setup

如果不想使用一键向导，也可以手动运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\configure.ps1
```

然后用管理员 PowerShell 运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-startup-task.ps1
```

手动测试：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-login.ps1
```

查看日志：

```powershell
Get-Content .\logs\shu-autoauth.log -Tail 50
```

如果当前已经联网，测试脚本会直接退出并记录 `Internet is already available. No login needed.`。这是正常行为。

## Scheduled Task

安装后会创建计划任务：

```text
\SHU Campus Network AutoAuth\SHUCampusNetworkAutoAuth
```

该任务会在 Windows 开机时以 `SYSTEM` 身份运行，并每 5 分钟补充检查一次。

## Uninstall

用管理员 PowerShell 进入 `v0.1.3` 目录，然后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-startup-task.ps1
```

## Files

```text
setup.cmd                         双击运行的一键安装入口
setup.ps1                         安装向导
configure.ps1                     生成本机配置和加密密码
install-startup-task.ps1           安装开机计划任务
uninstall-startup-task.ps1         卸载计划任务
test-login.ps1                     手动测试认证脚本
scripts/Invoke-SHUAutoAuth.ps1     核心自动认证脚本
config/portal.example.json         配置模板
```

## Credential Storage

账号写入：

```text
config/portal.json
```

密码不会明文写入配置文件，而是保存为：

```text
config/portal.password.bin
```

该文件使用 Windows DPAPI `LocalMachine` 作用域加密。这样计划任务可以在用户未登录时由 `SYSTEM` 解密并使用。拥有本机管理员权限的人仍然可能通过系统能力读取凭据，因此请只在可信设备上使用。
