# HoverGridSnap — specification

**Tagline:** Hover a hotkey to pop up a small grid and click cells to snap the front window anywhere.

**Category:** Window Management

**Inspired by (paid):** Moom ($15 one-time)

**Frameworks:** SwiftUI, AppKit, ApplicationServices, CoreGraphics, ServiceManagement

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

(1) What the paid app does. Moom sells for 15 dollars one-time with a free trial. Its signature feature is a palette that appears when you hover over a window's green button, plus a keyboard grid, saved layouts and move-and-zoom actions. Its developer page highlights a long list of actions and it is a fixture in window manager roundups and comparison pages, which is the evidence of lasting demand. Our clean-room version focuses on the grid idea only: a compact pop-up grid that lets you drag across cells to define the window rectangle.

(2) Feature set for our version. A global hotkey opens a small floating grid panel near the mouse pointer. The grid has a configurable number of columns and rows, default six by four. The user clicks one cell to move the front window into that cell, or click-drags across several cells to span a rectangle. Releasing the mouse applies the frame to the focused window of the frontmost app. Escape or clicking outside closes the panel. A second tab in settings stores up to nine named presets such as left two thirds or centered large, each a fractional rectangle. A preset can be applied from the menu bar menu or from the grid panel footer. Windows are placed on the screen that currently contains the mouse pointer, honoring the visible frame so the menu bar and Dock are respected. A configurable gap in points between window and screen edge is supported.

(3) UI spec. The app is a MenuBarExtra with a grid icon. The menu lists the nine presets, a Show Grid item with the shortcut shown, Settings and Quit. The grid panel is a borderless non-activating NSPanel hosting a SwiftUI view with a rows by columns lattice. Cells highlight in the accent color while dragging, and a live translucent preview rectangle is drawn on the target screen by a second click-through overlay window. The Settings window has fields for the global hotkey recorder, columns stepper, rows stepper, edge gap slider, launch at login toggle, and a preset editor table with name and four fraction fields. Empty state: if Accessibility permission is missing, the menu shows a single prominent item reading Grant Accessibility Access and the grid refuses to open.

(4) Technical approach. Use the Accessibility API through AXUIElement to read the focused window of the frontmost application and to set its position and size attributes. Request trust with AXIsProcessTrustedWithOptions and the prompt option, and open the Privacy and Security pane via the system settings URL scheme if the user declines. Register the global hotkey with the Carbon RegisterEventHotKey function, which needs no extra permission. Convert between AppKit bottom-left coordinates and the top-left coordinates used by Accessibility by flipping against the primary screen height. Persist settings and presets with AppStorage and a JSON-encoded array in UserDefaults. Launch at login uses SMAppService main app register and unregister. Set the activation policy to accessory so there is no Dock icon.

(5) Edge cases. Some windows are not resizable, so after setting size, read it back and re-position to keep the window on screen. Full-screen windows and windows with no focused window should be skipped with a short beep. When displays change, close the panel. Apps that animate resize may need a second set of the position after the size to avoid drift, so apply size, position, then size once more. If hotkey registration fails because of a conflict, show the error inline in Settings. Presets with invalid fractions are clamped between zero and one. Multi-display setups with differing scale factors must use points consistently, never pixels.
