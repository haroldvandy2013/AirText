import AppKit
import AirTextCore
import UniformTypeIdentifiers

@MainActor
final class TextWindow: NSWindowController, NSWindowDelegate {
    let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 468, height: 230))
    private let status = NSTextField(wrappingLabelWithString: "")
    var onClose: (() -> Void)?
    var onSend: ((String) -> Void)?

    init(text: String = "", receivedURL: URL? = nil) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.title = receivedURL == nil ? "AirText" : "AirText · 收到的文本"
        window.minSize = NSSize(width: 400, height: 300)
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false

        editor.isRichText = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isContinuousSpellCheckingEnabled = false
        editor.isGrammarCheckingEnabled = false
        editor.isAutomaticLinkDetectionEnabled = false
        editor.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        editor.textContainerInset = NSSize(width: 10, height: 10)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.minSize = .zero
        editor.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude
        )
        editor.autoresizingMask = [.width]
        editor.textContainer?.containerSize = NSSize(width: 468, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainer?.widthTracksTextView = true
        editor.string = text
        editor.allowsUndo = true
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.documentView = editor
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let paste = NSButton(title: "粘贴", target: self, action: #selector(pasteText))
        let copy = NSButton(title: "复制全部", target: self, action: #selector(copyText))
        let clear = NSButton(title: "清空", target: self, action: #selector(clearText))
        let send = NSButton(title: "通过 AirDrop 发送…", target: self, action: #selector(sendText))
        send.bezelStyle = .rounded
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [paste, copy, clear, spacer, send])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.translatesAutoresizingMaskIntoConstraints = false

        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        status.maximumNumberOfLines = 3
        status.stringValue = receivedURL.map {
            "接收文件仍保存在 \($0.path)。复制会写入系统剪贴板，可能被剪贴板工具记录或同步。"
        } ?? "仅在点击时读取剪贴板。AirDrop 使用明文临时文件；复制内容可能被剪贴板工具记录或同步。"
        status.translatesAutoresizingMaskIntoConstraints = false
        guard let content = window.contentView else { preconditionFailure("Missing content view") }
        for view in [scroll, buttons, status] { content.addSubview(view) }
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            scroll.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -12),
            buttons.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            buttons.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            buttons.bottomAnchor.constraint(equalTo: status.topAnchor, constant: -10),
            status.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            status.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            status.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14)
        ])
        window.makeFirstResponder(editor)
    }

    required init?(coder: NSCoder) { fatalError("Not supported") }

    @objc private func pasteText() { editor.pasteAsPlainText(nil) }
    @objc private func copyText() {
        NSPasteboard.general.clearContents()
        if !NSPasteboard.general.setString(editor.string, forType: .string) {
            NSAlert(error: NSError(
                domain: "AirText", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "无法写入系统剪贴板。"]
            )).runModal()
        }
    }
    @objc private func clearText() {
        editor.string = ""
        editor.undoManager?.removeAllActions()
    }
    @objc private func sendText() { onSend?(editor.string) }
    func windowWillClose(_ notification: Notification) {
        editor.string = ""
        editor.undoManager?.removeAllActions()
        onClose?()
    }
}

@MainActor
final class AirDropTransfer: NSObject, NSSharingServiceDelegate {
    let payload: OutgoingPayload
    let service: NSSharingService
    var onFinish: ((Error?) -> Void)?

    init(text: String) throws {
        guard let service = NSSharingService(named: .sendViaAirDrop) else {
            throw NSError(domain: "AirText", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "这台 Mac 当前不提供 AirDrop 服务。"
            ])
        }
        self.service = service
        payload = try OutgoingPayload(text: text)
        super.init()
        service.delegate = self
    }

    func start() {
        guard service.canPerform(withItems: [payload.fileURL]) else {
            finish(NSError(domain: "AirText", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "AirDrop 无法发送该文件，请检查 Wi-Fi、蓝牙和系统限制。"
            ]))
            return
        }
        service.perform(withItems: [payload.fileURL])
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        finish(nil)
    }

    func sharingService(
        _ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error
    ) {
        finish(error)
    }

    private func finish(_ transferError: Error?) {
        do {
            try payload.remove()
        } catch {
            onFinish?(NSError(domain: "AirText", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "临时文件清理失败：\(payload.fileURL.path)\n\(error.localizedDescription)"
                    + (transferError.map { "\n传输错误：\($0.localizedDescription)" } ?? "")
            ]))
            return
        }
        onFinish?(transferError)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [TextWindow] = []
    private var transfer: AirDropTransfer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        if windows.isEmpty { newDocument(nil) }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func newDocument(_ sender: Any?) { showText() }

    private func showText(_ text: String = "", receivedURL: URL? = nil) {
        let controller = TextWindow(text: text, receivedURL: receivedURL)
        controller.onClose = { [weak self, weak controller] in
            self?.windows.removeAll { $0 === controller }
        }
        controller.onSend = { [weak self] text in self?.send(text) }
        windows.append(controller)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "airtext") ?? .plainText, .plainText]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }

    @discardableResult
    private func open(_ url: URL) -> Bool {
        do {
            showText(try TextPayload.read(url), receivedURL: url)
            NSApp.activate(ignoringOtherApps: true)
            return true
        } catch {
            NSAlert(error: error).runModal()
            return false
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        var succeeded = true
        for name in filenames {
            if !open(URL(fileURLWithPath: name)) { succeeded = false }
        }
        sender.reply(toOpenOrPrint: succeeded ? .success : .failure)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { newDocument(nil) }
        return true
    }

    private func send(_ text: String) {
        guard transfer == nil else {
            let alert = NSAlert()
            alert.messageText = "已有 AirDrop 传输"
            alert.informativeText = "请先完成或取消当前系统 AirDrop 窗口。"
            alert.runModal()
            return
        }
        do {
            let pending = try AirDropTransfer(text: text)
            pending.onFinish = { [weak self] error in
                self?.transfer = nil
                if let error { NSAlert(error: error).runModal() }
            }
            transfer = pending
            pending.start()
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let transfer else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "AirDrop 可能仍在传输"
        alert.informativeText = "退出会删除发送临时文件，并可能中断传输。"
        alert.addButton(withTitle: "继续传输")
        alert.addButton(withTitle: "退出并清理")
        guard alert.runModal() == .alertSecondButtonReturn else { return .terminateCancel }
        do {
            try transfer.payload.remove()
            self.transfer = nil
            return .terminateNow
        } catch {
            NSAlert(error: error).runModal()
            return .terminateCancel
        }
    }

    private func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 AirText", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 AirText", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "文件")
        let newItem = fileMenu.addItem(withTitle: "新建", action: #selector(newDocument(_:)), keyEquivalent: "n")
        newItem.target = self
        let openItem = fileMenu.addItem(withTitle: "打开…", action: #selector(openDocument(_:)), keyEquivalent: "o")
        openItem.target = self
        fileMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = fileMenu
        main.addItem(fileItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)
        NSApp.mainMenu = main
    }
}

@main
enum AirTextApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
