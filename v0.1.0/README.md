# SHU Campus Network AutoAuth CLI v0.1.0

上海大学校园网自动认证服务命令行版。

该版本在 Windows 启动后以 `SYSTEM` 身份运行计划任务，不需要等待用户登录。任务会先检测是否已经联网；如果未联网，则自动向上海大学校园网 ePortal 接口提交认证请求。

## Requirements

- Windows 10/11 或 Windows Server
- Windows PowerShell 5.1
- 设备已连接上海大学校园网
- 安装开机任务时需要管理员权限

## Install

打开 PowerShell，进入本目录：

```powershell
cd "C:\path\to\SHU-Campus-Network-AutoAuth\v0.1.0"
```

先配置账号：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\configure.ps1
```

配置脚本会要求输入：

- 上海大学校园网登录页完整 URL
- 校园网账号
- 校园网密码
- 服务名，默认 `shu`

然后用管理员 PowerShell 安装开机任务：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-startup-task.ps1
```

## Test

手动执行一次认证检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-login.ps1
```

查看日志：

```powershell
Get-Content .\logs\shu-autoauth.log -Tail 50
```

## Scheduled Task

计划任务名称：

```text
SHUCampusNetworkAutoAuth
```

计划任务路径：

```text
\SHU Campus Network AutoAuth\
```

查询任务：

```powershell
Get-ScheduledTask -TaskPath "\SHU Campus Network AutoAuth\" -TaskName SHUCampusNetworkAutoAuth
```

## Uninstall

用管理员 PowerShell 运行：

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

账号写入 `config/portal.json`。密码不会明文写入配置文件，而是保存为：

```text
config/portal.password.bin
```

该文件使用 Windows DPAPI `LocalMachine` 作用域加密。这样计划任务可以在用户未登录时由 `SYSTEM` 解密并使用。拥有本机管理员权限的人仍然可能通过系统能力读取凭据，因此请只在可信设备上使用。
