# AppGroupedClips — specification

**Tagline:** A clipboard history that groups what you copied by the app it came from, with custom labels for favorites.

**Category:** Clipboard

**Inspired by (paid):** CopyLess 2 ($9.99 one-time)

**Frameworks:** SwiftUI, AppKit, ServiceManagement, UniformTypeIdentifiers

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

What the paid app does and the demand. CopyLess 2 is a Mac App Store clipboard manager with a free tier limited to 100 history items and 5 favorites, and a one-time unlock listed at 9.99 dollars in some regions and about 6.99 euros in others. It appears in 2026 clipboard manager roundups and has a long record on the store. Our clean-room version, AppGroupedClips, differs from the generic history tools by organizing everything by source application and letting you rename favorites.

Feature set. The app records text, links and images copied to the pasteboard together with the name and icon of the frontmost app at that moment. The main popup has a left column of app icons with counts, and a right list of that app's clips. Choosing All shows a merged timeline. Any clip can be starred, and starred clips appear in a Favorites section at the top that persists forever and can be given a custom label such as Billing address or Standup template. Return pastes the selected clip into the previous app. Number keys one to nine paste the first nine favorites directly while the popup is open.

UI spec. A MenuBarExtra using the window style, about 520 by 380 points. Top row has a search field and a Favorites toggle. The left column is a vertical list of app icons. The right pane is a list of rows with preview text, a star button and a small timestamp. A right click menu has Rename Label, Copy Back, Delete, and Never Record From This App. Settings has fields for maximum history per app (20 to 500), the global hotkey (default Command Shift C), image capture on or off, an ignored apps list, launch at login, and a Clear History button that keeps favorites unless the user ticks a second box. Empty states read Copy something to get started and No clips from this app yet.

Technical approach. Poll NSPasteboard changeCount on a timer of 0.4 seconds. When it changes, read the first available type among string, URL, PNG and TIFF, and read NSWorkspace frontmostApplication for the name, bundle identifier and icon. Skip items carrying concealed or transient type identifiers. Store entries in a JSON file in Application Support with images as separate files. Pasting into the previous app works by closing the popup, restoring focus to the app that was frontmost, writing the item to the pasteboard and posting a Command V key event, which needs Accessibility permission. Ask for it only when the user first uses Return to paste, and fall back to just copying with a notice if it is not granted. The global hotkey uses Carbon. Settings use AppStorage and launch at login uses SMAppService.

Edge cases. If the source app cannot be determined, file the clip under Unknown. When an app is quit and its icon is no longer available, cache the icon as a small PNG at copy time. Enforce limits per app, removing the oldest unstarred clip first. Treat identical consecutive copies as one entry and bump its timestamp. Handle the pasteboard containing multiple files by storing the file paths as text. If the JSON file is corrupt on launch, move it aside with a dated name and start fresh, telling the user in an alert. Large text over 200 thousand characters is stored truncated with a visible marker.
