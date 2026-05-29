# SHU Campus Network AutoAuth CLI v0.1.1

上海大学校园网自动认证服务命令行版。

该版本在 Windows 启动后以 `SYSTEM` 身份运行计划任务，不需要等待用户登录。任务会先检测是否已经联网；如果未联网，则自动向上海大学校园网 ePortal 接口提交认证请求。

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
cd .\SHU-Campus-Network-AutoAuth-main\v0.1.1
```

方式二：使用 Git。

```powershell
git clone https://github.com/PomePerilla/SHU-Campus-Network-AutoAuth.git
cd .\SHU-Campus-Network-AutoAuth\v0.1.1
```

## Configure

先确保电脑已经接入上海大学校园网环境，然后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\configure.ps1
```

配置脚本会要求输入：

- 校园网登录页完整 URL，直接回车会尝试自动访问 `10.10.9.9` 探测。
- 校园网账号。
- 校园网密码，不能为空；如果误按回车，会继续要求输入。
- 服务名，默认直接回车使用 `shu`。

自动探测适用于设备尚未认证、访问校内网关会跳转到 ePortal 登录页的状态。如果这台设备已经认证成功，`10.10.9.9` 可能只返回成功页面，这时无法自动得到登录页长 URL。

如果自动探测失败，请用浏览器打开：

```text
http://10.10.9.9
```

进入 ePortal 登录页后，复制浏览器地址栏里的完整长 URL，再重新运行 `configure.ps1` 并粘贴。

## Install

用管理员 PowerShell 进入 `v0.1.1` 目录，然后运行：

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

## Uninstall

用管理员 PowerShell 进入 `v0.1.1` 目录，然后运行：

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
