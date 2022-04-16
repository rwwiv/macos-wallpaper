import AppKit
import SQLite

public enum Wallpaper {
    public enum Screen {
        case all
        case main
        case index(Int)
        case nsScreens([NSScreen])

        fileprivate var nsScreens: [NSScreen] {
            switch self {
            case .all:
                return NSScreen.screens
            case .main:
                guard let mainScreen = NSScreen.main else {
                    return []
                }

                return [mainScreen]
            case .index(let index):
                guard let screen = NSScreen.screens[safe: index] else {
                    return []
                }

                return [screen]
            case .nsScreens(let nsScreens):
                return nsScreens
            }
        }
    }

    public enum Scale: String, CaseIterable {
        case auto
        case fill
        case fit
        case stretch
        case center
    }

    /**
    Get the current wallpapers.
    */
    public static func get(screen: Screen = .all) throws -> [URL] {
        return screen.nsScreens.compactMap { NSWorkspace.shared.desktopImageURL(for: $0) }
    }

    /**
    Works around a macOS bug where if you set a wallpaper to the same path as the existing wallpaper but with different content, it doesn't update.

    https://openradar.appspot.com/radar?id=6095446787227648
    */
    private static func forceRefreshIfNeeded(_ image: URL, screen: Screen) throws {
        var shouldSleep = false
        let currentImages = try get(screen: screen)

        for (index, nsScreen) in screen.nsScreens.enumerated() {
            if image == currentImages[index] {
                shouldSleep = true
                try NSWorkspace.shared.setDesktopImageURL(URL(fileURLWithPath: ""), for: nsScreen, options: [:])
            }
        }

        if shouldSleep {
            // We need to sleep for a little bit, otherwise it doesn't take effect.
            // It works with 0.3, but not with 0.2, so we're using 0.4 just to be sure.
            sleep(for: 0.4)
        }
    }

    /**
    Set an image URL as wallpaper.
    */
    public static func set(_ image: URL, screen: Screen = .all, scale: Scale = .auto, fillColor: NSColor? = nil) throws {
        var options = [NSWorkspace.DesktopImageOptionKey: Any]()

        switch scale {
        case .auto:
            break
        case .fill:
            options[.imageScaling] = NSImageScaling.scaleProportionallyUpOrDown.rawValue
            options[.allowClipping] = true
        case .fit:
            options[.imageScaling] = NSImageScaling.scaleProportionallyUpOrDown.rawValue
            options[.allowClipping] = false
        case .stretch:
            options[.imageScaling] = NSImageScaling.scaleAxesIndependently.rawValue
            options[.allowClipping] = true
        case .center:
            options[.imageScaling] = NSImageScaling.scaleNone.rawValue
            options[.allowClipping] = false
        }

        options[.fillColor] = fillColor

        try forceRefreshIfNeeded(image, screen: screen)

        for nsScreen in screen.nsScreens {
            try NSWorkspace.shared.setDesktopImageURL(image, for: nsScreen, options: options)
        }
    }

    /**
    Set a solid color as wallpaper.
    */
    public static func set(_ solidColor: NSColor, screen: Screen = .all) throws {
        let transparentImage = URL(fileURLWithPath: "/System/Library/PreferencePanes/DesktopScreenEffectsPref.prefPane/Contents/Resources/DesktopPictures.prefPane/Contents/Resources/Transparent.tiff")

        try set(transparentImage, screen: screen, scale: .fit, fillColor: solidColor)
    }

    /**
    Names of available screens.
    */
    public static var screenNames: [String] {
        NSScreen.screens.map(\.localizedName)
    }
}
