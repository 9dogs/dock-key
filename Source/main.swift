import AppKit
import SwiftUI
import Carbon
import ServiceManagement
import UniformTypeIdentifiers

let numberKeys: [UInt32] = [18,19,20,21,23,22,26,28,25,29]
let numberLabels = ["1","2","3","4","5","6","7","8","9","0"]
let modifierChoices: [(String, UInt32)] = [("⌃ Control", UInt32(controlKey)), ("⌥ Option", UInt32(optionKey)), ("⇧ Shift", UInt32(shiftKey)), ("⌘ Command", UInt32(cmdKey))]
func modifierLabel(_ mask: UInt32) -> String {
    [(UInt32(controlKey),"⌃"),(UInt32(optionKey),"⌥"),(UInt32(shiftKey),"⇧"),(UInt32(cmdKey),"⌘")].filter { mask & $0.0 != 0 }.map { $0.1 }.joined()
}
struct ManualShortcut: Codable, Identifiable {
    var id = UUID()
    var path: String
    var key: UInt32 = 18
    var modifiers: UInt32 = UInt32(controlKey | optionKey)
    var label: String = "1"
    var name: String { URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent }
}
final class HotKeys {
    var refs: [EventHotKeyRef] = []
    var actions: [UInt32: () -> Void] = [:]
    var handler: EventHandlerRef?
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr else { return status }
            Unmanaged<HotKeys>.fromOpaque(context).takeUnretainedValue().actions[id.id]?()
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func clear() { refs.forEach { UnregisterEventHotKey($0) }; refs.removeAll(); actions.removeAll() }
    func add(key: UInt32, modifiers: UInt32, action: @escaping () -> Void) -> Bool {
        let id = UInt32(actions.count + 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(key, modifiers, EventHotKeyID(signature: 0x444B4559, id: id), GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        refs.append(ref); actions[id] = action; return true
    }
    deinit { clear(); if let handler { RemoveEventHandler(handler) } }
}
final class Model: ObservableObject {
    @Published var tab = 0
    @Published var apps: [DockApp] = []
    @Published var issues: [String] = []
    @Published var dockError = ""
    @Published var enabled = UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true
    @Published var modifiers = UInt32(UserDefaults.standard.object(forKey: "modifiers") as? Int ?? optionKey)
    @Published var showIcon = UserDefaults.standard.object(forKey: "showIcon") as? Bool ?? true
    @Published var manual: [ManualShortcut] = []
    @Published var recording: UUID?
    @Published var login = SMAppService.mainApp.status == .enabled
    @Published var message = ""
    let hotkeys = HotKeys()
    var timer: Timer?
    var monitor: Any?
    var iconChanged: (() -> Void)?
    init() {
        if let data = UserDefaults.standard.data(forKey: "manual"), let decoded = try? JSONDecoder().decode([ManualShortcut].self, from: data) { manual = decoded }
        refresh(); register()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let id = self.recording else { return event }
            if event.keyCode == 53 { self.recording = nil; self.register(); return nil }
            var mask: UInt32 = 0
            if event.modifierFlags.contains(.command) { mask |= UInt32(cmdKey) }
            if event.modifierFlags.contains(.option) { mask |= UInt32(optionKey) }
            if event.modifierFlags.contains(.control) { mask |= UInt32(controlKey) }
            if event.modifierFlags.contains(.shift) { mask |= UInt32(shiftKey) }
            guard mask & UInt32(cmdKey | optionKey | controlKey) != 0 else { self.message = "Include Command, Option, or Control in a shortcut."; return nil }
            if let i = self.manual.firstIndex(where: { $0.id == id }) {
                self.manual[i].key = UInt32(event.keyCode); self.manual[i].modifiers = mask
                self.manual[i].label = event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
            }
            self.recording = nil; self.save(); return nil
        }
    }
    func refresh() {
        do { let new = try DockReader.read(); dockError = ""; if new != apps { apps = new; register() } }
        catch { dockError = error.localizedDescription }
    }
    func save() {
        let d = UserDefaults.standard
        d.set(enabled, forKey: "enabled"); d.set(Int(modifiers), forKey: "modifiers"); d.set(showIcon, forKey: "showIcon")
        d.set(try? JSONEncoder().encode(manual), forKey: "manual")
        register(); iconChanged?()
    }
    func register() {
        hotkeys.clear(); issues = []
        guard recording == nil else { return }
        if enabled && modifiers != 0 {
            for index in 0..<min(apps.count, 10) {
                if !hotkeys.add(key: numberKeys[index], modifiers: modifiers, action: { [weak self] in
                    guard let self else { return }
                    self.refresh()
                    if index < self.apps.count { self.open(self.apps[index].url) }
                }) { issues.append("\(modifierLabel(modifiers))\(numberLabels[index]) is already in use. Quit Snap or choose another modifier.") }
            }
        }
        for shortcut in manual {
            if !hotkeys.add(key: shortcut.key, modifiers: shortcut.modifiers, action: { [weak self] in self?.open(URL(fileURLWithPath: shortcut.path)) }) {
                issues.append("\(modifierLabel(shortcut.modifiers))\(shortcut.label) for \(shortcut.name) is already in use.")
            }
        }
    }
    func open(_ url: URL) {
        let configuration = NSWorkspace.OpenConfiguration(); configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error { DispatchQueue.main.async { self.message = error.localizedDescription } }
        }
    }
    func add() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.application]; panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let item = ManualShortcut(path: url.path); manual.append(item); recording = item.id; save()
        }
    }
    func setLogin(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            login = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval { message = "Approve DockKey in System Settings → General → Login Items." }
        } catch { message = error.localizedDescription; login = SMAppService.mainApp.status == .enabled }
    }
}
struct AppIcon: View {
    let url: URL
    var body: some View { Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 30, height: 30) }
}
struct Preferences: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "command.square.fill").font(.system(size: 38)).foregroundStyle(.blue)
                VStack(alignment: .leading) { Text("DockKey").font(.title.bold()); Text("Your apps. One shortcut away.").foregroundStyle(.secondary) }
                Spacer()
            }
            Picker("Mode", selection: $model.tab) { Text("Automatic").tag(0); Text("Manual").tag(1) }.pickerStyle(.segmented)
            if model.tab == 0 {
                Toggle("Enable Dock shortcuts", isOn: $model.enabled).onChange(of: model.enabled) { _ in model.save() }
                HStack {
                    ForEach(modifierChoices, id: \.1) { title, mask in
                        Toggle(title, isOn: Binding(get: { model.modifiers & mask != 0 }, set: { value in
                            let next = value ? model.modifiers | mask : model.modifiers & ~mask
                            if next != 0 { model.modifiers = next; model.save() }
                        })).toggleStyle(.button)
                    }
                }
                Text("Pinned Dock apps, in order. Finder and spacers are skipped. 0 opens the tenth app.").font(.callout).foregroundStyle(.secondary)
                List(Array(model.apps.prefix(10).enumerated()), id: \.element.id) { index, app in
                    HStack { AppIcon(url: app.url); Text(app.name); Spacer(); Text(modifierLabel(model.modifiers) + numberLabels[index]).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary) }.padding(.vertical, 3)
                }.listStyle(.bordered)
                if !model.dockError.isEmpty { Text(model.dockError).foregroundStyle(.red) }
            } else {
                Text("Assign any application its own shortcut. These work alongside automatic shortcuts.").font(.callout).foregroundStyle(.secondary)
                List {
                    ForEach(model.manual) { item in
                        HStack {
                            AppIcon(url: URL(fileURLWithPath: item.path)); Text(item.name); Spacer()
                            Button(model.recording == item.id ? "Type shortcut… Esc to cancel" : modifierLabel(item.modifiers) + item.label) {
                                model.recording = item.id; model.register()
                            }
                            Button { model.manual.removeAll { $0.id == item.id }; if model.recording == item.id { model.recording = nil }; model.save() } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless).accessibilityLabel("Remove \(item.name)")
                        }.padding(.vertical, 3)
                    }
                    if model.manual.isEmpty { Text("No manual shortcuts yet. Add an application below.").foregroundStyle(.secondary).padding(.vertical) }
                }.listStyle(.bordered)
                Button("Add Application…", action: model.add)
            }
            if !model.issues.isEmpty {
                ScrollView { VStack(alignment: .leading) { ForEach(model.issues, id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) } } }.frame(maxHeight: 66)
            }
            Divider()
            Toggle("Start DockKey at login", isOn: Binding(get: { model.login }, set: model.setLogin))
            Toggle("Show menu bar icon", isOn: $model.showIcon).onChange(of: model.showIcon) { _ in model.save() }
            Text("If the icon is hidden, open DockKey again to reach these settings.").font(.caption).foregroundStyle(.secondary)
            HStack { Text("Apple Silicon · Native macOS").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Quit DockKey") { NSApp.terminate(nil) } }
        }.padding(24).frame(width: 570, height: 650)
        .alert("DockKey", isPresented: Binding(get: { !model.message.isEmpty }, set: { if !$0 { model.message = "" } })) { Button("OK") { model.message = "" } } message: { Text(model.message) }
    }
}
final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var model: Model!
    var window: NSWindow!
    var status: NSStatusItem?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model = Model()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 618, height: 698), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "DockKey"; window.contentView = NSHostingView(rootView: Preferences(model: model)); window.center(); window.isReleasedWhenClosed = false; window.delegate = self
        model.iconChanged = { [weak self] in self?.updateIcon() }; updateIcon()
        let launchedAtLogin = NSAppleEventManager.shared().currentAppleEvent?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !launchedAtLogin { show() }
    }
    func updateIcon() {
        if model.showIcon && status == nil {
            status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            status?.button?.image = NSImage(systemSymbolName: "command.square", accessibilityDescription: "DockKey")
            let menu = NSMenu()
            let settings = menu.addItem(withTitle: "DockKey Settings…", action: #selector(show), keyEquivalent: ","); settings.target = self
            menu.addItem(.separator()); menu.addItem(withTitle: "Quit DockKey", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            status?.menu = menu
        } else if !model.showIcon, let item = status { NSStatusBar.system.removeStatusItem(item); status = nil }
    }
    @objc func show() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    func windowWillClose(_ notification: Notification) { model.recording = nil; model.save() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
if CommandLine.arguments.contains("--check-dock") {
    do { for (index, app) in try DockReader.read().prefix(10).enumerated() { print("\(numberLabels[index]): \(app.name) — \(app.url.path)") } } catch { fputs("\(error)\n", stderr); exit(1) }
} else {
    let app = NSApplication.shared
    let delegate = Delegate(); app.delegate = delegate; app.run()
}
