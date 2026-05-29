# SHU Campus Network AutoAuth CLI v0.1.2

上海大学校园网自动认证服务命令行版。

该版本在 Windows 启动后以 `SYSTEM` 身份运行计划任务，不需要等待用户登录。任务会先检测是否已经联网；如果未联网，则访问上海大学校园网关获取当前 ePortal 登录参数，再自动提交认证请求。

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

方式一：下载 ZIP。

打开仓库页面：

```text
https://github.com/PomePerilla/SHU-Campus-Network-AutoAuth
```

点击 `Code` -> `Download ZIP`，解压后进入：

```powershell
cd .\SHU-Campus-Network-AutoAuth-main\v0.1.2
```

方式二：使用 Git。

```powershell
git clone https://github.com/PomePerilla/SHU-Campus-Network-AutoAuth.git
cd .\SHU-Campus-Network-AutoAuth\v0.1.2
```

## Configure

先确保电脑已经接入上海大学校园网环境，然后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\configure.ps1
```

配置脚本会要求输入：

- 校园网账号。
- 校园网密码，不能为空；如果误按回车，会继续要求输入。
- 服务名，默认直接回车使用 `shu`。
- Portal 网关地址，默认直接回车使用 `http://10.10.9.9/`。
- 可选的完整 ePortal 登录 URL 备用值，通常直接回车跳过。

从 `v0.1.2` 开始，配置阶段不再要求用户复制 ePortal 登录页长 URL。用户下载项目时通常已经在线，所以此时强制获取登录页并不可靠。实际认证时，脚本会在检测到无法访问互联网后，再实时访问校园网关获取当前登录参数。

只有在自动获取登录参数失败时，才需要提供备用完整 ePortal 登录 URL。

## Install

用管理员 PowerShell 进入 `v0.1.2` 目录，然后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-startup-task.ps1
```

安装后会创建计划任务：

```text
\SHU Campus Network AutoAuth\SHUCampusNetworkAutoAuth
```

该任务会在 Windows 开机时以 `SYSTEM` 身份运行，并每 5 分钟补充检查一次。

## Test

手动执行一次认证检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-login.ps1
```

查看日志：

```powershell
Get-Content .\logs\shu-autoauth.log -Tail 50
```

如果当前已经联网，测试脚本会直接退出并记录 `Internet is already available. No login needed.`。这是正常行为。

## Uninstall

用管理员 PowerShell 进入 `v0.1.2` 目录，然后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-startup-task.ps1
```

## Files

```text
configure.ps1                    生成本机配置和加密密码
install-startup-task.ps1          安装开机计划任务
uninstall-startup-task.ps1        卸载计划任务
test-login.ps1                    手动测试认证脚本
scripts/Invoke-SHUAutoAuth.ps1    核心自动认证脚本
config/portal.example.json        配置模板
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
