# AirText

**English** | [简体中文](README.zh-CN.md)

A lightweight, native Mac app for sending text directly between nearby Macs using system AirDrop. Built with AppKit, with no third-party dependencies.

**Device-to-device, encrypted AirDrop transfer. No app-operated server, cloud relay, account, telemetry, text history, or Internet transport.** AirText relies on system AirDrop encryption; it does not implement its own end-to-end encryption protocol.

AirDrop uses Bluetooth for discovery and peer-to-peer Wi-Fi for transfer. Local payload transfer does not require Internet access or the same router. This does **not** mean network hardware is unused or all of macOS stays offline: system features such as Apple identity services may involve Internet access.

Currently supports **UTF-8 text up to 1 MiB**, preserving whitespace and line breaks. **Small-file transfer is planned**, but not available yet. The app interface is currently Chinese; the language switch above changes the documentation only.

## Download and install

Requires **macOS 13 or later**, on Apple Silicon or Intel.

1. Download [AirText-v0.1.0-macos-universal.zip](https://github.com/haroldvandy2013/AirText/releases/download/v0.1.0/AirText-v0.1.0-macos-universal.zip) and [SHA256SUMS.txt](https://github.com/haroldvandy2013/AirText/releases/download/v0.1.0/SHA256SUMS.txt) from the [v0.1.0 release](https://github.com/haroldvandy2013/AirText/releases/tag/v0.1.0). The automatically generated source archives are not the app.
2. Optionally check download integrity in Terminal, from the folder containing both files:

   ```sh
   shasum -a 256 -c SHA256SUMS.txt
   ```

3. Double-click the ZIP in Finder, then move `AirText.app` to Applications on **both Macs**. No Xcode or manual build is needed.
4. Open the app. This early release is **ad-hoc signed only, not Developer ID signed or Apple notarized**. Gatekeeper may block the first launch. Only if you trust the source, follow **System Settings → Privacy & Security → Open Anyway**, if offered. Do not disable Gatekeeper or other system protections.

A checksum checks archive integrity; it does not replace Developer ID signing or notarization. See [all releases](https://github.com/haroldvandy2013/AirText/releases) for future versions.

## Use

1. Launch AirText on both Macs.
2. Enable Wi-Fi, Bluetooth, and system AirDrop receiving; keep the Macs nearby.
3. On the sender, enter text or click “粘贴” (Paste), then “通过 AirDrop 发送…” (Send via AirDrop) and select the receiving Mac.
4. On the receiver, accept `Text.airtext` in AirDrop. If it does not open automatically, double-click the received file.
5. Click “复制全部” (Copy All) to copy the original text. “文件 → 打开…” (File → Open) is also supported.

The receiver needs AirText installed for this opening experience. This is not a general-purpose file transfer manager.

## Privacy boundaries

- System AirDrop encrypts the transfer, but an `.airtext` file is **plaintext on disk**, not an encrypted container.
- The sender creates a separate directory (permissions `0700`) and file (`0600`) in the system temporary directory. AirText attempts cleanup when the system reports success or failure; quitting during a transfer prompts first and attempts cleanup.
- Cancellation is controlled by AirDrop. Without a completion callback, temporary files remain until quit-time cleanup. A crash, force quit, or power loss may leave files behind, typically at `$TMPDIR/AirText-<UUID>/Text.airtext`. AirText does not promise secure erasure of SSD data.
- AirDrop saves received files, usually in Downloads. They are **not automatically deleted**. The app displays the path; delete sensitive files yourself after use, and consider backups and sync tools.
- AirText reads the clipboard only when you click Paste. Copy All writes the original text to the system clipboard, which Universal Clipboard or third-party history tools may record or sync. AirText does not automatically clear it or change other clipboard contents.
- AirText does not log text, send it automatically, execute received content, or render it as HTML.
- “清空” (Clear) clears the current editor and undo history, but does not securely erase memory, delete received files, or clear the system clipboard.

**Early release limitation:** discovery, receiving, and system cancellation between two physical Macs have not been verified. Compilation and unit tests on one Mac do not replace real two-Mac testing.

## Build from source

Requires macOS and Xcode or compatible Command Line Tools, with Swift 5.9 or later:

```sh
swift test
bash build.sh
open dist/AirText.app
```

`build.sh` builds a universal Apple Silicon + Intel app at `dist/AirText.app`, targeting macOS 13 or later, and applies an ad-hoc signature. Tests cover text formats and temporary-file handling.

## Publishing future releases

Maintainers need repository push access and an authenticated [GitHub CLI](https://cli.github.com/). Releases are manual; there is no automatic release workflow.

1. Update `CFBundleShortVersionString` and increment `CFBundleVersion` in `Resources/Info.plist`. Update the download links in both READMEs. Review and commit changes, then start from a clean `main` working tree.
2. Set the intended version (`0.1.1` below is an example), test and build **that commit**, and check the bundle:

   ```sh
   VERSION=0.1.1
   swift test
   bash build.sh
   lipo -verify_arch arm64 x86_64 dist/AirText.app/Contents/MacOS/AirText
   plutil -lint dist/AirText.app/Contents/Info.plist
   /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/AirText.app/Contents/Info.plist
   codesign --verify --deep --strict --verbose=2 dist/AirText.app
   ```

3. Confirm the printed version matches `VERSION`. Test discovery, receiving, and cancellation on two Macs before claiming those behaviors are verified. Package the **whole bundle**, not just the executable:

   ```sh
   ditto -c -k --sequesterRsrc --keepParent \
     dist/AirText.app "dist/AirText-v${VERSION}-macos-universal.zip"
   (cd dist && shasum -a 256 "AirText-v${VERSION}-macos-universal.zip" > SHA256SUMS.txt)
   (cd dist && shasum -a 256 -c SHA256SUMS.txt)
   ```

4. Push the release commit and a new tag, then create a draft with both assets:

   ```sh
   git push origin main
   git tag "v${VERSION}"
   git push origin "v${VERSION}"
   gh release create "v${VERSION}" --repo haroldvandy2013/AirText \
     --verify-tag --draft --title "AirText v${VERSION}" \
     --notes "Before publishing, describe changes, installation, signing status, and known limitations." \
     "dist/AirText-v${VERSION}-macos-universal.zip" dist/SHA256SUMS.txt
   ```

5. Edit the draft on GitHub with accurate notes, including signing/notarization status and untested behavior. Verify the tag points to the built commit and both assets are present, then publish. Download the uploaded assets, check the checksum, and verify the extracted bundle's architectures, version, and signature.

For smoother first launch, future releases need a Developer ID certificate and Apple notarization; the current build script does neither.
