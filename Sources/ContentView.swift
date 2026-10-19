import SwiftUI
import AppKit

/// The menu bar popup: app column on the left, clips of the chosen app on the right.
struct ContentView: View {
    @EnvironmentObject private var store: ClipStore
    @State private var search = ""
    @State private var favoritesOnly = false
    @State private var selectedApp: String?
    @State private var selection: UUID?
    @State private var renaming: Clip?
    @State private var labelDraft = ""
    @State private var keyMonitor: Any?
    @FocusState private var searchFocused: Bool

    private func matches(_ c: Clip) -> Bool {
        (selectedApp == nil || c.appKey == selectedApp)
            && (search.isEmpty || (c.text ?? "").localizedCaseInsensitiveContains(search)
                || (c.label ?? "").localizedCaseInsensitiveContains(search))
    }
    private var favoriteClips: [Clip] { store.clips.filter { $0.isFavorite && matches($0) } }
    private var recentClips: [Clip] { favoritesOnly ? [] : store.clips.filter { !$0.isFavorite && matches($0) } }
    private var visibleClips: [Clip] { favoriteClips + recentClips }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let notice = store.notice { noticeBanner(notice) }
            HStack(spacing: 0) {
                sidebar.frame(width: 68)
                Divider()
                clipPane.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            footer
        }
        .frame(width: 520, height: 380)
        .background(WindowAccessor { PopupController.shared.window = $0 })
        .onAppear(perform: installKeyMonitor)
        .alert("Rename Label", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("e.g. Billing address", text: $labelDraft)
            Button("Save") { if let c = renaming { store.rename(c.id, to: labelDraft) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Labelled clips are kept as favorites.")
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search clips", text: $search)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            Toggle(isOn: $favoritesOnly) { Label("Favorites", systemImage: favoritesOnly ? "star.fill" : "star") }
                .toggleStyle(.button)
                .help("Show favorites only")
        }
        .padding(10)
    }

    private func noticeBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.shield").foregroundStyle(.orange)
            Text(text).font(.caption).fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Open Settings") { PasteService.openAccessibilitySettings() }.controlSize(.small)
            Button { store.notice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.borderless)
        }
        .padding(8)
        .background(Color.orange.opacity(0.12))
    }

    private var sidebar: some View {
        ScrollView {
            VStack(spacing: 6) {
                appButton(key: nil, name: "All", count: store.clips.count,
                          image: Image(systemName: "tray.full.fill"))
                ForEach(store.groups) { g in
                    appButton(key: g.key, name: g.name, count: g.count, image: Image(nsImage: store.icon(for: g.key)))
                }
            }
            .padding(6)
        }
    }

    private func appButton(key: String?, name: String, count: Int, image: Image) -> some View {
        Button {
            selectedApp = key
            selection = nil
        } label: {
            VStack(spacing: 2) {
                image.resizable().scaledToFit().frame(width: 28, height: 28)
                Text("\(count)").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(width: 52, height: 48)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(selectedApp == key ? Color.accentColor.opacity(0.25) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(name)
    }

    @ViewBuilder private var clipPane: some View {
        if store.clips.isEmpty {
            emptyState("Copy something to get started", symbol: "doc.on.clipboard")
        } else if visibleClips.isEmpty {
            if !search.isEmpty {
                emptyState("No matching clips", symbol: "magnifyingglass")
            } else if favoritesOnly {
                emptyState("No favorites yet — star a clip to keep it", symbol: "star")
            } else {
                emptyState("No clips from this app yet", symbol: "app.dashed")
            }
        } else {
            List(selection: $selection) {
                if !favoriteClips.isEmpty {
                    Section("Favorites") { ForEach(favoriteClips) { row($0) } }
                }
                if !recentClips.isEmpty {
                    Section(selectedApp == nil ? "All" : "Recent") { ForEach(recentClips) { row($0) } }
                }
            }
            .listStyle(.inset)
            .contextMenu(forSelectionType: UUID.self) { ids in
                if let id = ids.first, let clip = store.clips.first(where: { $0.id == id }) {
                    contextMenu(for: clip)
                }
            } primaryAction: { ids in
                if let id = ids.first, let clip = store.clips.first(where: { $0.id == id }) { paste(clip) }
            }
        }
    }

    @ViewBuilder private func contextMenu(for clip: Clip) -> some View {
        Button("Rename Label…") { labelDraft = clip.label ?? ""; renaming = clip }
        Button("Copy Back") { store.writeToPasteboard(clip) }
        Button(clip.isFavorite ? "Unstar" : "Star") { store.toggleFavorite(clip.id) }
        Divider()
        Button("Delete", role: .destructive) { store.delete([clip.id]) }
        if let bundleID = clip.bundleID {
            Button("Never Record From \(clip.appName)") { store.neverRecord(from: bundleID) }
        }
    }

    private func row(_ clip: Clip) -> some View {
        let favIndex = store.favorites.firstIndex(where: { $0.id == clip.id })
        return HStack(spacing: 8) {
            if selectedApp == nil {
                Image(nsImage: store.icon(for: clip.appKey)).resizable().frame(width: 16, height: 16)
            }
            if clip.kind == .image, let thumb = store.thumbnail(for: clip) {
                Image(nsImage: thumb).resizable().scaledToFit().frame(maxWidth: 80, maxHeight: 40)
            } else if clip.kind != .text {
                Image(systemName: clip.kind == .link ? "link" : "doc.on.doc").foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                if let label = clip.label { Text(label).font(.callout.bold()).lineLimit(1) }
                Text(clip.preview).font(clip.label == nil ? .callout : .caption)
                    .foregroundStyle(clip.label == nil ? .primary : .secondary)
                    .lineLimit(clip.label == nil ? 2 : 1)
            }
            Spacer(minLength: 4)
            if let i = favIndex, i < 9 {
                Text("\(i + 1)").font(.caption2.monospacedDigit()).padding(.horizontal, 4)
                    .background(Capsule().stroke(.secondary.opacity(0.5)))
                    .help("Press \(i + 1) to paste")
            }
            VStack(alignment: .trailing, spacing: 2) {
                Button { store.toggleFavorite(clip.id) } label: {
                    Image(systemName: clip.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(clip.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.borderless)
                Text(Self.relative.localizedString(for: clip.date, relativeTo: Date()))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .tag(clip.id)
    }

    private func emptyState(_ text: String, symbol: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(.tertiary)
            Text(text).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding()
    }

    private var footer: some View {
        HStack {
            SettingsLink { Label("Settings", systemImage: "gear") }
                .simultaneousGesture(TapGesture().onEnded { NSApp.activate(ignoringOtherApps: true) })
            Button("Support / Donate ❤️") { AppDelegate.openDonate() }
            Spacer()
            Text("↩ paste · 1–9 favorites").font(.caption2).foregroundStyle(.tertiary)
            Button("Quit") { NSApp.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    // MARK: - Keyboard

    private func paste(_ clip: Clip) { PasteService.shared.paste(clip, store: store) }

    private func installKeyMonitor() {
        searchFocused = false
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKey(event) ? nil : event
        }
    }

    /// Returns true when the key was consumed by the popup.
    private func handleKey(_ event: NSEvent) -> Bool {
        guard let window = PopupController.shared.window, event.window === window, renaming == nil else { return false }
        let mods = event.modifierFlags.intersection([.command, .control, .option])
        let list = visibleClips
        switch Int(event.keyCode) {
        case 36, 76: // Return / Enter
            if let clip = list.first(where: { $0.id == selection }) ?? list.first { paste(clip) }
            return true
        case 125, 126: // Down / Up
            let step = event.keyCode == 125 ? 1 : -1
            let current = list.firstIndex(where: { $0.id == selection }) ?? (step == 1 ? -1 : list.count)
            let next = min(max(current + step, 0), list.count - 1)
            if list.indices.contains(next) { selection = list[next].id }
            return true
        case 53: // Escape
            if !search.isEmpty { search = "" } else { PopupController.shared.close() }
            return true
        default:
            break
        }
        guard mods.isEmpty, !searchFocused, let chars = event.characters, !chars.isEmpty else { return false }
        if let n = Int(chars), (1...9).contains(n) {
            let favs = store.favorites
            if favs.indices.contains(n - 1) { paste(favs[n - 1]) }
            return true
        }
        if chars.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.union(.punctuationCharacters).contains($0) }) {
            search += chars
            searchFocused = true
            return true
        }
        return false
    }
}

/// Reports the hosting NSWindow of a SwiftUI view.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onWindow(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onWindow(nsView.window) }
    }
}
