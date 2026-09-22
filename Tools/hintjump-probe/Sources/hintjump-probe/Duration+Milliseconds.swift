import Foundation

extension Duration {
    /// This duration in milliseconds.
    ///
    /// Divided by a one-millisecond `Duration` rather than scaled from `components`: the
    /// standard library owns the arithmetic, and no conversion factor has to be written
    /// down as a literal. Spelled again here rather than shared with `HintjumpPlatform`:
    /// the adapter's copy is internal to the package that logs with it, and exporting one
    /// to a probe would widen a module's public surface for a print statement.
    var milliseconds: Double {
        self / .milliseconds(1)
    }
}
