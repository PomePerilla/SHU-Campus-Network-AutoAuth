# SHU NetAuth

SHU NetAuth 是一个面向上海大学校园网 ePortal 认证环境的 Windows 自动认证工具。

当前 `v1.0.0` 版本提供命令行安装向导：用户双击 `setup.cmd` 后，向导会自动请求管理员权限，检查系统和网络状态，收集校园网账号信息，保存本机配置，安装开机自动认证计划任务，并运行一次测试。

## 适用环境

本项目只面向上海大学校园网 ePortal 认证环境。满足以下任一条件时通常可以使用：

- Windows 电脑通过网口直连宿舍、实验室或其他校园网有线接口。
- Windows 电脑通过路由器、交换机或其他子网络设备接入校园有线网，只要这台 Windows 电脑能访问 `http://10.10.9.9`。
- Windows 电脑连接无线网络 `Shu(ForAll)`。
- 其他能在浏览器访问 `http://10.10.9.9` 并进入上海大学 ePortal 登录页面的校内网络。

不适用的情况：

- 设备不在上海大学校园网环境内。
- 无法访问 `http://10.10.9.9`。
- 所在网络不使用上海大学 ePortal 认证。
- 需要短信、二维码、CAS 单点登录或图形验证码等交互式认证方式。

## 下载

从 GitHub Releases 下载：

[SHU-NetAuth-v1.0.0.zip](https://github.com/PomePerilla/SHU-Campus-Network-AutoAuth/releases/download/v1.0.0/SHU-NetAuth-v1.0.0.zip)

解压后进入：

```text
SHU-NetAuth-v1.0.0
```

## 安装

先在浏览器访问：

```text
http://10.10.9.9
```

进入 ePortal 登录页后，复制浏览器地址栏中的完整长地址。它通常以：

```text
http://10.10.9.9/eportal/index.jsp?
```

开头，并带有一长串参数。不要只复制 `http://10.10.9.9/`。

然后双击运行：

```text
setup.cmd
```

安装向导会要求输入：

- 校园网账号。
- 校园网密码。
- 服务名，默认是 `shu`。
- Portal 网关地址，默认是 `http://10.10.9.9/`。
- 完整 ePortal 登录 URL fallback，也就是上面从浏览器复制的长地址。

安装完成后会创建计划任务：

```text
\SHU NetAuth\SHUCampusNetworkAutoAuth
```

该任务会在 Windows 开机时以 `SYSTEM` 身份运行，并每 5 分钟补充检查一次。

## 当前限制

目前无法在所有环境中稳定通过简单访问 `http://10.10.9.9/` 自动获得完整 ePortal 登录长地址。当前版本要求用户人工复制一次完整长地址，并把其中的 query string 保存为 fallback。

这个长地址通常包含设备 IP、接入控制器、端口、VLAN、MAC 等参数。它通常只适合同一台设备、同一个网络接口、同一种接入环境短期复用。换设备、换网口、换路由器、切换有线/无线或学校后端参数变化后，可能需要重新运行 `setup.cmd` 并粘贴新的长地址。

代码中已预留 `Get-AutoDetectedPortalUrl` 接口，后续自动长地址获取模块会接入这里。

## 手动命令

推荐使用 `setup.cmd`。如需手动操作：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\configure.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-startup-task.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-login.ps1
```

`install-startup-task.ps1` 需要管理员 PowerShell。

查看日志：

```powershell
Get-Content .\logs\shu-autoauth.log -Tail 50
```

如果当前已经联网，测试脚本会直接退出并记录：

```text
Internet is already available. No login needed.
```

这是正常行为。

## 安全

校园网账号写入：

```text
config\portal.json
```

密码不会明文写入配置文件，而是保存为：

```text
config\portal.password.bin
```

该文件使用 Windows DPAPI `LocalMachine` 作用域加密，使计划任务能在用户未登录时由 `SYSTEM` 解密并执行认证。

当前版本的安全策略组仍在开发中，代码中已预留 `Invoke-SecurityPolicyCheck` 接口，但不启用 host pinning、public key pinning 或 credential endpoint restriction 等强校验。详细说明见 [SECURITY.md](SECURITY.md) 和 [TECHNICAL_NOTES.md](TECHNICAL_NOTES.md)。
