# 上传 GitHub

上传整个 `hx1p35a_vision` 目录，包括隐藏的 `.gitignore` 和 `.gitattributes`。当前仓库已经包含源码、约束、IP、脚本、仿真样本和下载文件。

## 创建远程仓库

1. 登录 GitHub，点击右上角 **+ → New repository**。
2. 仓库名称使用 `hx1p35a_vision`。
3. 按比赛提交要求选择 Public 或 Private。
4. 保持远程仓库为空，不额外初始化 README、gitignore 或 license，然后点击 **Create repository**。
5. 复制页面提供的 HTTPS 仓库地址。

## 在 PowerShell 上传

在本目录打开 PowerShell。首次使用 Git 时，通过自己的姓名和邮箱完成 Git 作者配置。

```powershell
Set-Location -LiteralPath 'D:/codex documents/FPGA/Project/13/hx1p35a_vision'
python build/verify.py
git init -b main
git add .
git status --short
git commit -m "Prepare V116 FPGA vision source release"
$remoteUrl = Read-Host '粘贴刚创建仓库的 HTTPS 地址'
git remote add origin $remoteUrl
git push -u origin main
```

登录提示出现时按 Git 的凭据管理器或浏览器登录流程完成认证。完成后刷新仓库网页，确认 README、src、sim、build、board、data、report 均存在。

如果 `git commit` 提示尚未设置作者，在本仓库执行下面两条命令后重新提交；配置只作用于当前仓库：

```powershell
git config user.name (Read-Host '输入提交作者姓名')
git config user.email (Read-Host '输入提交邮箱')
```

如果本地已经有 `origin`，先执行 `git remote -v` 核对地址；需要更换时使用 `git remote set-url origin $remoteUrl`。示例适用于新建的空远程仓库，不需要强制推送。

## 后续更新

```powershell
git status --short
git add .
git commit -m "Update project documentation"
git push
```

维护代码时同步更新验证证据与文件清单。`build/out`、`sim/out`、仿真工作库和编译数据库自动忽略；不要将它们重新纳入提交。需要把 bit 作为单独下载入口时，可在 GitHub Releases 中附加 `build/bitstreams` 下的文件。

本仓库包含厂商生成及加密 IP，来源和原许可说明见 [third_party.md](third_party.md)；未给第三方文件追加 MIT 等统一许可证。

官方操作参考：[Adding locally hosted code to GitHub](https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github)、[Managing remote repositories](https://docs.github.com/en/get-started/git-basics/managing-remote-repositories)。
