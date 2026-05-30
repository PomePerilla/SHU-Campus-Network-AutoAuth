# SHU NetAuth

語言：[English](README.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

SHU NetAuth 是一個面向上海大學校園網 ePortal 環境的 Windows 開機自動認證工具。

`v1.1.1` 版本新增了基於 Playwright 的實驗性 ePortal 長 URL 偵測模組，同時保持開機自動認證主流程穩定。使用者仍然可以透過一條從瀏覽器複製的完整 ePortal 登入長網址完成安裝，詳細診斷資訊會寫入 `logs\shu-netauth.log`，不會堆在安裝視窗裡。

## 適用環境

SHU NetAuth 面向能存取以下地址的上海大學校園網環境：

```text
http://10.10.9.9
```

通常適用於：

- 校園有線網路。
- 透過路由器或交換器接入校園網的 Windows 電腦。
- 無線網路 `Shu(ForAll)`。
- 其他能開啟上海大學 ePortal 登入頁的校內接入方式。

不適用於：

- 非上海大學校園網。
- 無法存取 `http://10.10.9.9` 的網路。
- 需要簡訊、QR Code、CAS、驗證碼或其他互動式驗證的登入流程。

## 下載

從 GitHub Releases 下載：

[SHU-NetAuth-v1.1.1.zip](https://github.com/PomePerilla/SHU-Campus-Network-AutoAuth/releases/download/v1.1.1/SHU-NetAuth-v1.1.1.zip)

解壓縮後開啟：

```text
SHU-NetAuth-v1.1.1
```

## 安裝

執行安裝前，先在瀏覽器裡開啟：

```text
http://10.10.9.9
```

等待瀏覽器跳轉到 ePortal 登入頁，然後複製瀏覽器地址列裡的完整長網址。它通常以：

```text
http://10.10.9.9/eportal/index.jsp?
```

開頭。不要只複製 `http://10.10.9.9/`，完整地址必須包含 `?` 後面的一長串參數。

然後執行：

```text
setup.cmd
```

安裝精靈會要求輸入：

- 校園網使用者名稱。
- 校園網密碼。
- 完整 ePortal 登入 URL fallback。

普通安裝流程會隱藏服務名稱和閘道地址，並使用預設值：

```text
Service = shu
PortalGatewayUrl = http://10.10.9.9/
```

安裝後會建立排程工作：

```text
\SHU NetAuth\SHUCampusNetworkAutoAuth
```

該工作會在 Windows 開機時以 `SYSTEM` 身分執行，並每 5 分鐘檢查一次。

## 使用者介面

安裝視窗只顯示簡潔狀態：

```text
Project Status
Network Status
SUCCESS
SETUP NEEDS ATTENTION
```

原始 HTTP 錯誤、閘道狀態碼、檔案路徑和執行細節會寫入：

```text
logs\shu-netauth.log
```

## 目前限制

SHU NetAuth 目前還不能在所有校園網狀態下穩定地從 `http://10.10.9.9/` 自動取得完整 ePortal 登入 URL。因此目前版本需要使用者在安裝時手動複製一次瀏覽器裡的完整 ePortal URL。

這條長 URL 可能與目前設備、網路介面、接入控制器、連接埠、VLAN 或 IP 環境有關。它可能在同一台設備、同一接入路徑下使用一段時間，但不保證跨設備或網路環境變化後仍然可用。

如果更換網口、路由器、有線/無線模式或網路環境後認證失敗，請重新執行 `setup.cmd`，並貼上新的 ePortal URL。

## 實驗性 URL 偵測模組

v1.1.1 包含一個獨立的 Playwright 偵測模組，用於測試自動取得 ePortal 長 URL：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Detect-PortalUrl.Playwright.ps1
```

只返回偵測到的長 URL：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Detect-PortalUrl.Playwright.ps1 -OnlyUrl
```

安裝偵測模組依賴：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-PortalDetectorDependencies.ps1
```

該偵測模組目前仍是獨立模組，尚未接入開機自動認證主流程。

## 預留介面

主認證腳本預留了：

```powershell
Get-AutoDetectedPortalUrl
```

用於後續自動取得長 URL。

同時預留了：

```powershell
Invoke-SecurityPolicyCheck
```

用於後續安全策略組。在 `v1.1.1` 中，該介面不會強制執行 host pinning、public key pinning 或憑據提交端點限制。

## 手動命令

推薦使用安裝精靈。手動命令如下：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\configure.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-startup-task.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-login.ps1
```

`install-startup-task.ps1` 需要系統管理員 PowerShell。

查看日誌：

```powershell
Get-Content .\logs\shu-netauth.log -Tail 50
```

## 安全

使用者名稱儲存於：

```text
config\portal.json
```

密碼儲存於：

```text
config\portal.password.bin
```

密碼檔案使用 Windows DPAPI `LocalMachine` 作用域保護，因此排程工作可以在使用者登入前以 `SYSTEM` 身分執行。請只在可信的個人設備上使用 SHU NetAuth。

更多細節見 [SECURITY.md](SECURITY.md) 和 [TECHNICAL_NOTES.md](TECHNICAL_NOTES.md)。
