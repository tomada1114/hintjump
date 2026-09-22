import CoreGraphics
import HintjumpCore
import Testing

extension TargetRankerTests {
    @Suite("order")
    struct Order {
        @Test
        func `within a tier, reading order: top to bottom, then left to right`() {
            let elements = tree([
                Spec(frame: rect(10, 200, 40, 20)),
                Spec(frame: rect(300, 100, 40, 20)),
                Spec(frame: rect(10, 100, 40, 20)),
                Spec(frame: rect(150, 100, 40, 20)),
            ])
            #expect(TargetRanker().rank(elements).map(\.elementIndex) == [3, 4, 2, 1])
        }

        @Test
        func `items of different heights centered on one line read left to right`() {
            let elements = tree([
                Spec(role: "AXMenuButton", frame: rect(400, 0, 60, 52)),
                Spec(role: "AXPopUpButton", frame: rect(100, 8, 36, 36)),
            ])
            #expect(TargetRanker().rank(elements).map(\.elementIndex) == [2, 1])
        }

        @Test
        func `elements sharing a center keep their tree order`() {
            let frame = rect(100, 100, 40, 20)
            let elements = tree([Spec(frame: frame), Spec(frame: frame), Spec(frame: frame)])
            #expect(TargetRanker().rank(elements).map(\.elementIndex) == [1, 2, 3])
        }

        @Test
        func `the same snapshot yields the same order, with ranks numbered from 1`() {
            let elements = tree([
                Spec(role: "AXLink", frame: rect(500, 300, 40, 20)),
                Spec(role: "AXTextField", frame: rect(10, 10, 200, 24)),
                Spec(frame: rect(500, 300, 40, 20)),
                Spec(role: "AXCell", frame: rect(10, 400, 100, 20)),
                Spec(role: "AXLink", frame: rect(10, 300, 40, 20)),
            ])
            let first = TargetRanker().rank(elements)
            let second = TargetRanker().rank(elements)
            #expect(first == second)
            #expect(first.map(\.rank) == Array(1 ... elements.count - 1))
            #expect(first.map(\.elementIndex) == [2, 5, 1, 3, 4])
            #expect(first.allSatisfy { elements[$0.elementIndex] == $0.element })
        }

        @Test
        func `a replacement tier assignment reorders without changing the output's shape`() {
            let elements = tree([
                Spec(role: "AXTextField", frame: rect(10, 10, 200, 24)),
                Spec(role: "AXLink", frame: rect(10, 300, 40, 20)),
            ])
            let linksFirst = TargetRanker { candidate in
                candidate.element.role == "AXLink" ? .primary : .other
            }
            let ranked = linksFirst.rank(elements)
            #expect(ranked.map(\.elementIndex) == [2, 1])
            #expect(ranked.map(\.tier) == [.primary, .other])
        }

        @Test
        func `a tier assignment sees the element's ancestors, nearest first, and the window frame`() {
            let elements = tree([
                Spec(role: "AXToolbar", frame: rect(0, 0, 900, 50)),
                Spec(frame: rect(10, 5, 40, 40), parent: 1),
            ])
            // The assignment answers `.primary` only when it was shown exactly the context
            // under test, so the tier it returns is the assertion — no state is captured.
            let ranked = TargetRanker { candidate in
                let roles = candidate.ancestors.map(\.role)
                let isExpected = roles == ["AXToolbar", "AXWindow"]
                    && candidate.windowFrame == windowFrame
                return isExpected ? .primary : .other
            }.rank(elements)
            // The toolbar itself is not clickable, so the button is the only target.
            #expect(ranked.map(\.elementIndex) == [2])
            #expect(ranked.map(\.tier) == [.primary])
        }
    }
}
