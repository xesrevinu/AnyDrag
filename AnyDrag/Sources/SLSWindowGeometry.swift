import CoreGraphics
import Foundation

/// Thin wrappers around SkyLight / CoreGraphics private window-geometry APIs.
///
/// On this machine with SIP disabled, an independent process can move **other
/// apps'** windows via `SLSMoveWindowWithGroup` (verified against Grok / Zed /
/// Multica / Zen). Space *reassignment* APIs remain a separate privilege story
/// and are not used here.
///
/// These symbols are private: they can vanish or change semantics across
/// macOS updates. Callers must treat `isAvailable` as dynamic and keep a
/// public fallback (title-bar synth or AX).
enum SLSWindowGeometry {

    private static let log = FileLog("SLSGeometry")

    typealias ConnectionID = Int32
    typealias WindowID = UInt32

    private typealias MainConnectionFn = @convention(c) () -> ConnectionID
    private typealias GetBoundsFn = @convention(c) (ConnectionID, WindowID, UnsafeMutablePointer<CGRect>) -> CGError
    private typealias MoveWithGroupFn = @convention(c) (ConnectionID, WindowID, UnsafePointer<CGPoint>) -> Int32
    private typealias MoveFn = @convention(c) (ConnectionID, WindowID, UnsafePointer<CGPoint>) -> CGError
    private typealias ReassociateFn = @convention(c) (ConnectionID, CFArray) -> CGError

    private struct Fns {
        let mainConnection: MainConnectionFn
        let getBounds: GetBoundsFn
        let moveWithGroup: MoveWithGroupFn
        let move: MoveFn?
        let reassociate: ReassociateFn?
    }

    private static let fns: Fns? = {
        let sky = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)

        func sym<T>(_ name: String) -> T? {
            let raw: UnsafeMutableRawPointer? = {
                if let sky, let p = dlsym(sky, name) { return p }
                if let rtldDefault, let p = dlsym(rtldDefault, name) { return p }
                return nil
            }()
            guard let raw else { return nil }
            return unsafeBitCast(raw, to: T.self)
        }

        guard let main: MainConnectionFn = sym("SLSMainConnectionID") ?? sym("CGSMainConnectionID"),
              let getBounds: GetBoundsFn = sym("SLSGetWindowBounds") ?? sym("CGSGetWindowBounds"),
              let moveWithGroup: MoveWithGroupFn = sym("SLSMoveWindowWithGroup")
        else {
            return nil
        }
        let move: MoveFn? = sym("SLSMoveWindow") ?? sym("CGSMoveWindow")
        let reassociate: ReassociateFn? = sym("SLSReassociateWindowsSpacesByGeometry")
            ?? sym("CGSReassociateWindowsSpacesByGeometry")
        return Fns(mainConnection: main, getBounds: getBounds, moveWithGroup: moveWithGroup,
                   move: move, reassociate: reassociate)
    }()

    /// True when the private move entry points resolved at process start.
    static var isAvailable: Bool { fns != nil }

    private static var connection: ConnectionID {
        fns!.mainConnection()
    }

    static func bounds(of windowID: CGWindowID) -> CGRect? {
        guard let fns else { return nil }
        var rect = CGRect.zero
        let err = fns.getBounds(fns.mainConnection(), WindowID(windowID), &rect)
        guard err == .success else { return nil }
        return rect
    }

    /// Move `windowID` so its **origin** (top-left in CGWindowList / SLS space)
    /// becomes `origin`. Returns whether the call reported success; callers
    /// should still re-read bounds when they need confirmation.
    @discardableResult
    static func moveWindow(_ windowID: CGWindowID, origin: CGPoint) -> Bool {
        guard let fns else { return false }
        var point = CGPoint(x: origin.x.rounded(), y: origin.y.rounded())
        let cid = fns.mainConnection()
        let wid = WindowID(windowID)
        let status = fns.moveWithGroup(cid, wid, &point)
        if let reassociate = fns.reassociate {
            let arr = [NSNumber(value: wid)] as CFArray
            _ = reassociate(cid, arr)
        }
        return status == 0
    }

    /// One-shot probe used at engine start: try resolving symbols and log.
    static func logAvailability() {
        if isAvailable {
            let cid = connection
            log.info("available cid=\(cid) moveWithGroup=yes")
        } else {
            log.warn("unavailable — title-bar / AX fallback only")
        }
    }
}
