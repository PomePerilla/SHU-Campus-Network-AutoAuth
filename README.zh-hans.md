# SHU NetAuth

语言：[English](README.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

SHU NetAuth 是一个面向上海大学校园网 ePortal 环境的 Windows 开机自动认证工具。

`v1.1.1` 版本新增了基于 Playwright 的实验性 ePortal 长 URL 检测模块，同时保持开机自动认证主流程稳定。用户仍然可以通过一条从浏览器复制的完整 ePortal 登录长地址完成安装，详细诊断信息会写入 `logs\shu-netauth.log`，不会堆在安装窗口里。

## 适用环境

SHU NetAuth 面向能访问以下地址的上海大学校园网环境：

```text
http://10.10.9.9
```

通常适用于：

- 校园有线网络。
- 通过路由器或交换机接入校园网的 Windows 电脑。
- 无线网络 `Shu(ForAll)`。
- 其他能打开上海大学 ePortal 登录页的校内接入方式。

不适用于：

- 非上海大学校园网。
- 无法访问 `http://10.10.9.9` 的网络。
- 需要短信、二维码、CAS、验证码或其他交互式验证的登录流程。

## 下载

从 GitHub Releases 下载：

[SHU-NetAuth-v1.1.1.zip](https://github.com/PomePerilla/SHU-Campus-Network-AutoAuth/releases/download/v1.1.1/SHU-NetAuth-v1.1.1.zip)

解压后打开：

```text
SHU-NetAuth-v1.1.1
```

## 安装

运行安装前，先在浏览器里打开：

```text
http://10.10.9.9
```

等待浏览器跳转到 ePortal 登录页，然后复制浏览器地址栏里的完整长地址。它通常以：

```text
http://10.10.9.9/eportal/index.jsp?
```

开头。不要只复制 `http://10.10.9.9/`，完整地址必须包含 `?` 后面的一长串参数。

然后运行：

```text
setup.cmd
```

安装向导会要求输入：

- 校园网用户名。
- 校园网密码。
- 完整 ePortal 登录 URL fallback。

普通安装流程会隐藏服务名和网关地址，并使用默认值：

```text
Service = shu
PortalGatewayUrl = http://10.10.9.9/
```

安装后会创建计划任务：

```text
\SHU NetAuth\SHUCampusNetworkAutoAuth
```

该任务会在 Windows 开机时以 `SYSTEM` 身份运行，并每 5 分钟检查一次。

## 用户界面

安装窗口只显示简洁状态：

```text
Project Status
Network Status
SUCCESS
SETUP NEEDS ATTENTION
```

原始 HTTP 错误、网关状态码、文件路径和运行细节会写入：

```text
logs\shu-netauth.log
```

## 当前限制

SHU NetAuth 目前还不能在所有校园网状态下稳定地从 `http://10.10.9.9/` 自动获取完整 ePortal 登录 URL。因此当前版本需要用户在安装时手动复制一次浏览器里的完整 ePortal URL。

这条长 URL 可能与当前设备、网络接口、接入控制器、端口、VLAN 或 IP 环境有关。它可能在同一台设备、同一接入路径下使用一段时间，但不保证跨设备或网络环境变化后仍然可用。

如果更换网口、路由器、有线/无线模式或网络环境后认证失败，请重新运行 `setup.cmd`，并粘贴新的 ePortal URL。

## 实验性 URL 检测模块

v1.1.1 包含一个独立的 Playwright 检测模块，用于测试自动获取 ePortal 长 URL：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Detect-PortalUrl.Playwright.ps1
```

只返回检测到的长 URL：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Detect-PortalUrl.Playwright.ps1 -OnlyUrl
```

安装检测模块依赖：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-PortalDetectorDependencies.ps1
```

该检测模块目前仍是独立模块，尚未接入开机自动认证主流程。

## 预留接口

主认证脚本预留了：

```powershell
Get-AutoDetectedPortalUrl
```

用于后续自动获取长 URL。

同时预留了：

```powershell
Invoke-SecurityPolicyCheck
```

用于后续安全策略组。在 `v1.1.1` 中，该接口不会强制执行 host pinning、public key pinning 或凭据提交端点限制。

## 手动命令

推荐使用安装向导。手动命令如下：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\configure.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-startup-task.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-login.ps1
```

`install-startup-task.ps1` 需要管理员 PowerShell。

查看日志：

```powershell
Get-Content .\logs\shu-netauth.log -Tail 50
```

## 安全

用户名保存于：

```text
config\portal.json
```

密码保存于：

```text
config\portal.password.bin
```

密码文件使用 Windows DPAPI `LocalMachine` 作用域保护，因此计划任务可以在用户登录前以 `SYSTEM` 身份运行。请只在可信的个人设备上使用 SHU NetAuth。

更多细节见 [SECURITY.md](SECURITY.md) 和 [TECHNICAL_NOTES.md](TECHNICAL_NOTES.md)。
