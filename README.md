# SHU Campus Network AutoAuth

上海大学校园网自动认证服务。

本项目用于在 Windows 设备启动后自动完成上海大学校园网 ePortal 认证。当前首发形态是命令行版本，适合轻量部署、服务器或无人值守设备。

## Versions

本仓库采用手动版本目录管理：

```text
v0.1.0/  命令行安装版
v0.1.1/  命令行安装版，增加输入校验和自动探测登录 URL
v0.1.2/  命令行安装版，改为认证时实时获取登录参数
v0.1.3/  命令行安装版，增加一键安装向导
```

后续计划：

```text
v0.2.0/  图形界面版
```

## Current Release

进入 [v0.1.3](v0.1.3/) 查看命令行版本的安装和使用说明。

## Recommended Download

普通用户建议从 GitHub Releases 下载发布包，而不是使用 `Code -> Download ZIP`：

[Download SHU-CNAA-v0.1.3.zip](https://github.com/PomePerilla/SHU-Campus-Network-AutoAuth/releases/download/v0.1.3/SHU-CNAA-v0.1.3.zip)

解压后双击：

```text
setup.cmd
```

## Roadmap

开发路线见 [ROADMAP.md](ROADMAP.md)。

## Security

真实账号配置和加密密码文件不会提交到仓库。用户在本机运行配置脚本后生成：

```text
config/portal.json
config/portal.password.bin
```

密码使用 Windows DPAPI 机器级加密保存，以支持开机后由 `SYSTEM` 计划任务自动运行。
