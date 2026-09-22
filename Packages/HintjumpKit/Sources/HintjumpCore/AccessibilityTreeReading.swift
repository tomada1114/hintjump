import CoreGraphics
import Foundation

/// One element of another application's accessibility tree, flattened to a value.
///
/// Everything the Accessibility API says about an element that a hint-label decision
/// could turn on, and nothing that names the OS object it came from: an adapter
/// collapses each `AXUIElement` into one of these before anything crosses an isolation
/// boundary (the `integrating-system-apis` skill, rule 1). No field here is a decision —
/// "is this clickable?" is Core's question to answer over `role` and `actions`, and it
/// is asked nowhere in the adapter.
public struct ElementSnapshot: Equatable, Sendable {
    /// `AXRole`, when the element reports one.
    public let role: String?
    /// `AXSubrole`, when the element reports one.
    public let subrole: String?
    /// `AXTitle`, when the element reports one. Data about the person's screen: log it
    /// `.private`.
    public let title: String?
    /// `AXDescription`, when the element reports one. Log it `.private`, as `title`.
    public let description: String?
    /// The element's bounds in screen coordinates (origin top-left, as the Accessibility
    /// API reports them), or `nil` when it has no position or size — an application
    /// element, or a hidden one.
    public let frame: CGRect?
    /// `AXEnabled`; `true` when the element does not report it, since most elements that
    /// omit it are enabled containers.
    public let isEnabled: Bool
    /// The action names the element supports, verbatim (`AXPress`, `AXShowMenu`, …).
    public let actions: [String]
    /// Distance from the tree's root, which is at depth 0.
    public let depth: Int
    /// The index of this element's parent in ``TreeSnapshot/elements``, or `nil` for the
    /// root. The flat list is in pre-order, so a parent always precedes its children.
    public let parentIndex: Int?

    public init(
        role: String?,
        subrole: String?,
        title: String?,
        description: String?,
        frame: CGRect?,
        isEnabled: Bool,
        actions: [String],
        depth: Int,
        parentIndex: Int?,
    ) {
        self.role = role
        self.subrole = subrole
        self.title = title
        self.description = description
        self.frame = frame
        self.isEnabled = isEnabled
        self.actions = actions
        self.depth = depth
        self.parentIndex = parentIndex
    }
}

/// Which part of an application's tree a read starts from.
///
/// One case per product entry point that reads a tree, plus the whole application for
/// the verifications that need to see everything.
public enum ReadScope: String, CaseIterable, Sendable {
    /// The application element itself: every window, menu bar, and floating panel.
    case application
    /// The window the application reports as focused (`AXFocusedWindow`).
    case focusedWindow
    /// The application's menu bar (`AXMenuBar`).
    case menuBar
}

/// How an adapter walks the tree — a translation choice, never a product decision.
///
/// The four cases exist so the read-latency verification can compare them on the same
/// application; the product picks one once that measurement is in. They combine two
/// independent techniques, exposed as flags so an adapter reads them where it needs
/// them rather than switching on the case in several places:
/// ``readsAttributesInOneCall`` and ``prunesInvisibleSubtrees``.
public enum ReadStrategy: String, CaseIterable, Sendable {
    /// All of an element's attributes in one call.
    case batched
    /// ``batched`` and ``pruned`` together.
    case batchedPruned
    /// One Accessibility API call per attribute per element, the simplest possible walk.
    case naive
    /// Skips a subtree whose frame does not intersect the visible rectangle or is clipped
    /// to a sliver, and reads only the visible rows or children of a table, outline, or
    /// list.
    case pruned

    /// Whether every attribute of an element is fetched in a single call.
    public var readsAttributesInOneCall: Bool {
        switch self {
        case .batched, .batchedPruned:
            true

        case .naive, .pruned:
            false
        }
    }

    /// Whether subtrees outside the visible rectangle or clipped to a sliver, and rows
    /// or children the application reports as invisible, are left unread.
    public var prunesInvisibleSubtrees: Bool {
        switch self {
        case .batchedPruned, .pruned:
            true

        case .batched, .naive:
            false
        }
    }
}

/// One read of an application's accessibility tree, with what it cost.
public struct TreeSnapshot: Equatable, Sendable {
    /// The application's bundle identifier, when it has one.
    public let bundleIdentifier: String?
    /// The process the tree was read from.
    public let pid: pid_t
    /// Where the read started.
    public let scope: ReadScope
    /// How the tree was walked.
    public let strategy: ReadStrategy
    /// Every element read, in pre-order; index 0 is the scope's root.
    public let elements: [ElementSnapshot]
    /// Wall-clock time from the first Accessibility API call to the last.
    public let readDuration: Duration

    public init(
        bundleIdentifier: String?,
        pid: pid_t,
        scope: ReadScope,
        strategy: ReadStrategy,
        elements: [ElementSnapshot],
        readDuration: Duration,
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.pid = pid
        self.scope = scope
        self.strategy = strategy
        self.elements = elements
        self.readDuration = readDuration
    }
}

/// Why a tree could not be read, told apart so a caller can distinguish a missing
/// grant from a broken adapter.
public enum AccessibilityReadError: Error, Equatable, Sendable {
    /// The scope's root attribute is not supported or has no value — an application
    /// with no focused window asked for `.focusedWindow`, for instance. Carries the
    /// attribute name.
    case attributeUnsupported(String)
    /// Any other `AXError` from the root read, carried as its raw code. Reading a single
    /// element's attribute never fails the whole read: that attribute is left `nil`.
    case failed(code: Int32)
    /// No process with this pid is running.
    case noSuchProcess(pid_t)
    /// This process does not hold the Accessibility permission (`AXError.apiDisabled`).
    case notTrusted
}

/// A port: "what is in this application's accessibility tree right now?"
///
/// The frontmost-window entry points and the verifications that precede them all ask
/// this one question, so the answer is a value Core can rank, filter, and label without
/// ever seeing an `AXUIElement`. `@MainActor` because the Accessibility API is bound to
/// the main run loop, stated once here rather than justified in every adapter.
///
/// Pull-style, like ``FrontmostAppProviding``: each call is a fresh snapshot, and an
/// app that wants to follow changes adds an observing port rather than turning this one
/// into a publisher.
public protocol AccessibilityTreeReading: Sendable {
    /// Reads the tree under `scope` of the process `pid`, walked with `strategy`, no
    /// deeper than `maxDepth`.
    ///
    /// `maxDepth` is how many levels below the root the walk descends: an element at
    /// `depth >= maxDepth` is recorded but its children are not read, so `0` reads the
    /// root alone and `nil` reads everything. It is independent of `scope` — "how deep"
    /// is a separate question from "where to start" — which is why it is a parameter
    /// rather than another ``ReadScope`` case. The app-menus entry point asks for `1`:
    /// every closed menu under a menu bar title still publishes its items, so the whole
    /// bar is hundreds of elements when only its dozen titles are wanted.
    @MainActor
    func readTree(
        pid: pid_t,
        scope: ReadScope,
        strategy: ReadStrategy,
        maxDepth: Int?,
    ) throws -> TreeSnapshot

    /// Asks the application to build its accessibility tree even though no assistive
    /// client has been detected: sets `AXManualAccessibility` on the application element.
    ///
    /// Applications built on Chromium and Electron leave their tree empty until this is
    /// set (or a screen reader is running), which the Electron-tree verification needs
    /// to confirm before the product can rely on it. Errors as ``readTree`` does.
    @MainActor
    func enableManualAccessibility(pid: pid_t) throws
}
