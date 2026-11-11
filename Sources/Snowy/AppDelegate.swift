import AppKit
import SnowCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSMenuDelegate {
    private var coordinator: DesktopCoordinator?
    private var statusItem: NSStatusItem?
    private let pauseItem = NSMenuItem(title: "Pause Snow", action: #selector(togglePause), keyEquivalent: "p")
    private let stateItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var weatherItems: [NSMenuItem] = []
    private let seasonSwitch = NSSwitch()
    private let winterCaption = NSTextField(labelWithString: "Winter")
    private let leavesCaption = NSTextField(labelWithString: "Autumn")
    private let clearItem = NSMenuItem(title: "Clear Settled Snow", action: #selector(clearSnow), keyEquivalent: "k")
    private var windPopover: NSPopover?
    private var toolItems: [NSMenuItem] = []
    private var welcomeWindow: WelcomeWindowController?
    private var snowyWindow: SnowyWindowController?
    private let decorationSettings = DecorationSettings()
    private let updater = SnowyUpdater()
    private let updateItem = NSMenuItem(title: "Update", action: #selector(installUpdate), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Read the persisted domain before coordinator startup can write settings.
        let defaults = UserDefaults.standard
        let domainName = Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
        let shouldShowWelcome = FirstLaunchPolicy.shouldPresent(in: defaults, domainName: domainName)
        buildMenu()
        updater.onChange = { [weak self] in self?.updateAvailableRelease() }
        updater.start()
        do {
            let coordinator = try DesktopCoordinator()
            self.coordinator = coordinator
            coordinator.onStateChange = { [weak self] in self?.updateMenu() }
            decorationSettings.onChange = { [weak coordinator] configuration in
                coordinator?.setDecorations(configuration)
            }
            decorationSettings.desktops = coordinator.editorDesktops
            decorationSettings.onEditorVisibility = { [weak coordinator] visible in
                coordinator?.setEditorVisible(visible)
            }
            coordinator.onDesktopGeometryChange = { [weak self] desktops in
                self?.decorationSettings.desktops = desktops
            }
            decorationSettings.apply()
        } catch {
            stateItem.title = "Metal is unavailable on this Mac"
            pauseItem.isEnabled = false
        }
        updateMenu()
        if coordinator != nil {
            FirstLaunchPolicy.markConsidered(in: defaults)
            if shouldShowWelcome { presentWelcome() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let welcomeWindow { welcomeWindow.present() }
        else { presentSnowyWindow() }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        welcomeWindow?.close()
        snowyWindow?.close()
        windPopover?.performClose(nil)
        coordinator?.stop()
    }

    private func buildMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "snowflake", accessibilityDescription: "Window Weather")
        item.button?.image?.isTemplate = true
        item.button?.toolTip = "Window Weather — on your windows"
        statusItem = item
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        let title = NSMenuItem(title: "Window Weather", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(.separator())
        let open = NSMenuItem(title: "Open Window Weather…", action: #selector(openSnowyWindow), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())
        pauseItem.target = self
        menu.addItem(pauseItem)
        clearItem.target = self
        menu.addItem(clearItem)
        let tool = NSMenuItem(title: "Cursor Tool", action: nil, keyEquivalent: "")
        let tools = NSMenu(title: "Cursor Tool")
        tools.autoenablesItems = false
        for (index, name) in ["Glove", "Shovel"].enumerated() {
            let option = NSMenuItem(title: name, action: #selector(selectTool(_:)), keyEquivalent: "")
            option.tag = index
            option.target = self
            tools.addItem(option)
            toolItems.append(option)
        }
        tool.submenu = tools
        menu.addItem(tool)
        menu.addItem(.separator())
        for (index, snowfall) in Snowfall.allCases.enumerated() {
            let option = NSMenuItem(title: snowfall.rawValue, action: #selector(setSnowfall(_:)), keyEquivalent: "")
            option.target = self
            option.tag = index
            weatherItems.append(option)
            menu.addItem(option)
        }
        let season = NSMenuItem()
        season.view = makeSeasonSwitch()
        menu.addItem(season)
        let wind = NSMenuItem(title: "Wind…", action: #selector(showWind), keyEquivalent: "w")
        wind.target = self
        menu.addItem(wind)
        menu.addItem(.separator())
        updateItem.target = self
        updateItem.isHidden = true
        updateItem.isEnabled = false
        menu.addItem(updateItem)
        let quit = NSMenuItem(title: "Quit Window Weather", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        item.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) { updateAvailableRelease() }

    private func updateAvailableRelease() {
        guard let version = updater.availableVersion else {
            updateItem.isHidden = true
            return
        }
        updateItem.attributedTitle = NSAttributedString(
            string: "Update to \(version)…",
            attributes: [.foregroundColor: NSColor.linkColor]
        )
        updateItem.isHidden = false
        updateItem.isEnabled = updater.canInstall
    }

    @objc private func installUpdate() { updater.install() }

    @objc private func openSnowyWindow() {
        DispatchQueue.main.async { [weak self] in self?.presentSnowyWindow() }
    }

    private func presentSnowyWindow() {
        if snowyWindow == nil {
            snowyWindow = SnowyWindowController(
                settings: decorationSettings,
                resetDecorations: { [weak self] in self?.coordinator?.resetDecorations() },
                replayWalkthrough: { [weak self] in self?.presentWelcome() }
            )
        }
        snowyWindow?.present()
    }

    private func presentWelcome() {
        if welcomeWindow == nil {
            let welcome = WelcomeWindowController()
            welcome.onClose = { [weak self] in self?.welcomeWindow = nil }
            welcomeWindow = welcome
        }
        welcomeWindow?.present()
    }

    private func updateMenu() {
        guard let coordinator else { return }
        let autumn = coordinator.season == .autumn
        pauseItem.title = coordinator.paused ? "Resume Snow" : "Pause Snow"
        clearItem.title = autumn ? "Clear Settled Autumn" : "Clear Settled Snow"
        if let button = statusItem?.button {
            let symbol = autumn ? "leaf.fill" : "snowflake"
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: autumn ? "Autumn" : "Window Weather")
            button.image?.isTemplate = true
            button.toolTip = autumn ? "Window Weather — autumn on your windows" : "Window Weather — winter on your windows"
        }
        if coordinator.failed { stateItem.title = "Rendering stopped — relaunch to retry" }
        else if coordinator.policy.suspended { stateItem.title = "Resting while your Mac cools down" }
        else if coordinator.paused { stateItem.title = autumn ? "Autumn is paused" : "Snow is paused" }
        else if coordinator.policy.reducedMotion {
            stateItem.title = autumn ? "Quiet litter · Reduce Motion" : "Quiet drifts · Reduce Motion"
        }
        else {
            stateItem.title = autumn ? "Brush a leafy edge to sweep it away" : "Brush a snowy edge to sweep it away"
        }
        for (index, item) in weatherItems.enumerated() {
            item.state = Snowfall.allCases[index] == coordinator.snowfall ? .on : .off
        }
        seasonSwitch.state = autumn ? .on : .off
        winterCaption.textColor = autumn ? .secondaryLabelColor : .labelColor
        leavesCaption.textColor = autumn ? .labelColor : .secondaryLabelColor
        for (index, item) in toolItems.enumerated() {
            item.state = (index == 1 ? coordinator.tool == .shovel : coordinator.tool == .glove) ? .on : .off
        }
    }

    @objc private func togglePause() { coordinator?.paused.toggle() }
    @objc private func clearSnow() { coordinator?.clear() }
    @objc private func showWind() {
        // A menu action runs during tracking; show after it closes so the popover receives focus.
        DispatchQueue.main.async { [weak self] in
            guard let self, let button = self.statusItem?.button, let coordinator = self.coordinator else { return }
            if let popover = self.windPopover, popover.isShown { popover.performClose(nil); return }
            let content = WindViewController()
            content.settings = coordinator.wind
            content.onChange = { [weak coordinator] value in coordinator?.wind = value }
            let popover = NSPopover()
            popover.behavior = .transient
            popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            popover.contentViewController = content
            popover.delegate = self
            content.onClose = { [weak popover] in popover?.performClose(nil) }
            self.windPopover = popover
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate()
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        guard let closed = notification.object as? NSPopover, closed === windPopover else { return }
        windPopover = nil
    }

    @objc private func selectTool(_ sender: NSMenuItem) {
        coordinator?.tool = sender.tag == 1 ? .shovel : .glove
    }
    @objc private func setSnowfall(_ sender: NSMenuItem) {
        guard Snowfall.allCases.indices.contains(sender.tag) else { return }
        coordinator?.snowfall = Snowfall.allCases[sender.tag]
    }

    @objc private func seasonSwitchChanged(_ sender: NSSwitch) {
        coordinator?.season = sender.state == .on ? .autumn : .winter
    }

    private func makeSeasonSwitch() -> NSView {
        let row = NSView(frame: NSRect(x: 0, y: 0, width: 230, height: 32))
        winterCaption.font = .menuFont(ofSize: 0)
        leavesCaption.font = .menuFont(ofSize: 0)
        seasonSwitch.target = self
        seasonSwitch.action = #selector(seasonSwitchChanged(_:))
        seasonSwitch.setAccessibilityLabel("Autumn")
        for view in [winterCaption, seasonSwitch, leavesCaption] {
            view.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(view)
        }
        NSLayoutConstraint.activate([
            winterCaption.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 18),
            winterCaption.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            seasonSwitch.leadingAnchor.constraint(equalTo: winterCaption.trailingAnchor, constant: 10),
            seasonSwitch.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            leavesCaption.leadingAnchor.constraint(equalTo: seasonSwitch.trailingAnchor, constant: 8),
            leavesCaption.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])
        return row
    }
}
