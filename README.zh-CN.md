# AirText

[English](README.md) | **简体中文**

AirText 是一个轻量的 Mac 原生文本传输工具，通过系统 AirDrop 在附近的 Mac 之间直接传递文字。使用 AppKit，不包含第三方依赖。

**设备到设备、由系统 AirDrop 加密传输；没有应用自建服务器、云端中转、账号、遥测、文本历史或互联网传输服务。** AirText 使用系统 AirDrop 提供的加密，不自行实现端到端加密协议。

AirDrop 使用蓝牙发现设备、点对点 Wi-Fi 传输。传输本地内容不需要互联网，也不要求连接同一个路由器。这**不代表不使用网络硬件，也不代表整个 macOS 完全不联网**：Apple 身份服务等系统功能可能涉及互联网访问。

目前支持 **UTF-8 文本，单次最多 1 MiB**，保留空白和换行。**未来计划增加小文件传输**，目前尚未提供。应用界面目前为中文；顶部的语言切换仅切换文档。

## 下载与安装

需要 **macOS 13 或更新版本**，支持 Apple Silicon 和 Intel。

1. 从 [v0.1.0 Release](https://github.com/haroldvandy2013/AirText/releases/tag/v0.1.0) 下载 [AirText-v0.1.0-macos-universal.zip](https://github.com/haroldvandy2013/AirText/releases/download/v0.1.0/AirText-v0.1.0-macos-universal.zip) 和 [SHA256SUMS.txt](https://github.com/haroldvandy2013/AirText/releases/download/v0.1.0/SHA256SUMS.txt)。GitHub 自动生成的源码压缩包不是可运行的 App。
2. 可选：在终端进入两个文件所在的目录，校验下载完整性：

   ```sh
   shasum -a 256 -c SHA256SUMS.txt
   ```

3. 在 Finder 中双击 ZIP 解压，把 `AirText.app` 放入**两台 Mac** 的“应用程序”目录。不需要 Xcode，也不需要手动构建。
4. 打开应用。此早期版本**仅进行 ad-hoc 签名，未进行 Developer ID 签名或 Apple 公证**，首次启动可能被 Gatekeeper 阻止。仅在确认来源可信后，按“系统设置 → 隐私与安全性”中的“仍要打开”提示（如有）批准运行。不要关闭 Gatekeeper 或其他系统安全保护。

校验文件用于检查压缩包完整性，不能替代 Developer ID 签名或 Apple 公证。后续版本可在[全部 Releases](https://github.com/haroldvandy2013/AirText/releases) 查看。

## 使用

1. 在两台 Mac 上启动 AirText。
2. 开启 Wi-Fi、蓝牙以及系统 AirDrop 接收；两台 Mac 保持靠近。
3. 在发送端输入文本或点击“粘贴”，再点击“通过 AirDrop 发送…”并选择接收 Mac。
4. 接收端在系统 AirDrop 中接收 `Text.airtext`；若系统没有自动打开，双击收到的文件。
5. 点击“复制全部”即可复制原文，也支持“文件 → 打开…”。

接收端必须安装 AirText 才能获得对应的打开体验。本项目不是通用文件传输管理器。

## 隐私边界

- 系统 AirDrop 加密传输，但 `.airtext` 本身是**磁盘上的明文文件**，不是加密容器。
- 发送端在系统临时目录创建独立目录（权限 `0700`）和文件（`0600`）。系统报告完成或失败后尝试清理；传输期间退出会先提示并尝试清理。
- 系统取消行为由 AirDrop 控制。如果未收到结束回调，临时文件会保留至退出清理。进程崩溃、强制退出或断电可能遗留临时文件，位置通常为 `$TMPDIR/AirText-<UUID>/Text.airtext`。程序不承诺安全擦除 SSD 数据。
- 接收文件由系统 AirDrop 保存（通常在“下载”目录），**不会自动删除**。界面会显示路径；敏感文本使用后请自行删除，且注意备份和同步工具。
- 只在点击“粘贴”时读取剪贴板。点击“复制全部”会将原文写入系统剪贴板，可能被通用剪贴板或第三方历史工具记录、同步；程序不会自动清空或改动其他剪贴板内容。
- 不记录文本日志，不自动发送，不自动执行收到的内容，不将收到的文本渲染为 HTML。
- “清空”会清空当前编辑器及撤销记录，但不代表内存安全擦除，也不会删除接收文件或系统剪贴板。

**早期版本限制：**尚未在两台实体 Mac 之间验证 AirDrop 发现、接收和系统取消行为；单机编译与单元测试不能替代实际双机验证。

## 从源码构建

需要 macOS、Xcode 或兼容的 Command Line Tools，Swift 5.9 以上：

```sh
swift test
bash build.sh
open dist/AirText.app
```

`build.sh` 生成 `dist/AirText.app`，同时支持 Apple Silicon 和 Intel，最低 macOS 13，并进行 ad-hoc 签名。测试覆盖文本格式和临时文件处理。

## 维护者：发布后续版本

需要仓库推送权限和已登录的 [GitHub CLI](https://cli.github.com/)。目前手动发布附件，没有自动发布工作流。

1. 更新 `Resources/Info.plist` 中的 `CFBundleShortVersionString` 并递增 `CFBundleVersion`，同步更新两份 README 中的下载链接。检查并提交改动，从干净的 `main` 工作区开始。
2. 设置目标版本（以下 `0.1.1` 仅为示例），测试并构建**该提交**，检查 App：

   ```sh
   VERSION=0.1.1
   swift test
   bash build.sh
   lipo dist/AirText.app/Contents/MacOS/AirText -verify_arch arm64 x86_64
   plutil -lint dist/AirText.app/Contents/Info.plist
   /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/AirText.app/Contents/Info.plist
   codesign --verify --deep --strict --verbose=2 dist/AirText.app
   ```

3. 确认输出的版本与 `VERSION` 一致。在宣称相关行为已验证之前，用两台 Mac 实测发现、接收及取消。打包**完整 App**，不要只打包可执行文件：

   ```sh
   ditto -c -k --sequesterRsrc --keepParent \
     dist/AirText.app "dist/AirText-v${VERSION}-macos-universal.zip"
   (cd dist && shasum -a 256 "AirText-v${VERSION}-macos-universal.zip" > SHA256SUMS.txt)
   (cd dist && shasum -a 256 -c SHA256SUMS.txt)
   ```

4. 推送发布提交和新的版本标签，然后创建包含两个附件的草稿：

   ```sh
   git push origin main
   git tag "v${VERSION}"
   git push origin "v${VERSION}"
   gh release create "v${VERSION}" --repo haroldvandy2013/AirText \
     --verify-tag --draft --title "AirText v${VERSION}" \
     --notes "发布前请填写变更、安装方式、签名状态和已知限制。" \
     "dist/AirText-v${VERSION}-macos-universal.zip" dist/SHA256SUMS.txt
   ```

5. 在 GitHub 编辑草稿，准确说明变更、签名与公证状态，以及尚未验证的行为。确认标签指向构建所用的提交、两个附件均存在后再发布。下载已上传的附件，检查校验和，以及解压后 App 的架构、版本和签名。

如需更顺畅的首次启动体验，后续版本需要 Developer ID 证书和 Apple 公证；当前构建脚本不包含这两项。
