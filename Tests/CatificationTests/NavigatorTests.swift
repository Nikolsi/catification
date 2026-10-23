import XCTest
@testable import Catification

final class NavigatorTests: XCTestCase {
    private let g = Cat.gravity
    private let limits = NavLimits(up: 300, across: 200, margin: 8)

    private func surface(_ id: SurfaceID, y: CGFloat, _ range: ClosedRange<CGFloat>) -> Surface {
        Surface(id: id, y: y, segments: [range], anchor: .zero)
    }

    // MARK: Ballistics

    func testBallisticJumpLandsOnTarget() {
        let from = CGPoint(x: 0, y: 0), to = CGPoint(x: 200, y: 150)
        let b = Navigator.ballistic(from: from, to: to, ceiling: 1000, gravity: g)
        let t = b.duration
        XCTAssertEqual(from.x + b.vx * t, to.x, accuracy: 0.5)
        XCTAssertEqual(from.y + b.vy * t - g * t * t / 2, to.y, accuracy: 0.5)
    }

    func testBallisticJumpStaysUnderCeiling() {
        let b = Navigator.ballistic(from: .zero, to: CGPoint(x: 300, y: 0), ceiling: 20, gravity: g)
        let apex = b.vy * b.vy / (2 * g)
        XCTAssertLessThanOrEqual(apex, 20.5)
        XCTAssertGreaterThan(apex, 0)
    }

    func testTrajectoryStartsAtOriginAndIsEvenlySpaced() {
        let b = Navigator.ballistic(from: .zero, to: CGPoint(x: 120, y: 80), ceiling: 1000, gravity: g)
        let points = Navigator.trajectory(from: .zero, vx: b.vx, vy: b.vy, duration: b.duration, gravity: g, spacing: 7)
        XCTAssertEqual(points.first, .zero)
        XCTAssertGreaterThan(points.count, 10)
        for (a, c) in zip(points, points.dropFirst()) {
            XCTAssertEqual(hypot(c.x - a.x, c.y - a.y), 7, accuracy: 2)
        }
    }

    // MARK: Single hops

    func testJumpStraightUpOntoOverlappingShelf() {
        let floor = surface(.ground, y: 0, 0...1000)
        let shelf = surface(.shelf(UUID()), y: 200, 100...300)
        let hop = Navigator.hop(from: floor, 0, at: 50, to: shelf, 0, limits: limits)
        XCTAssertEqual(hop?.kind, .jump)
        XCTAssertEqual(hop?.takeoffX, 108)
        XCTAssertEqual(hop?.landX, 108)
    }

    func testTooHighIsUnreachable() {
        let floor = surface(.ground, y: 0, 0...1000)
        let shelf = surface(.shelf(UUID()), y: 500, 100...300)
        XCTAssertNil(Navigator.hop(from: floor, 0, at: 200, to: shelf, 0, limits: limits))
    }

    func testDropDownFromAnywhereAboveTheTarget() {
        let shelf = surface(.shelf(UUID()), y: 300, 0...400)
        let floor = surface(.ground, y: 0, 0...1000)
        let hop = Navigator.hop(from: shelf, 0, at: 250, to: floor, 0, limits: limits)
        XCTAssertEqual(hop?.takeoffX, 250)
        XCTAssertEqual(hop?.landX, 250)
    }

    func testLeapAcrossAGap() {
        let a = surface(.shelf(UUID()), y: 100, 0...100)
        let b = surface(.shelf(UUID()), y: 100, 200...300)
        let hop = Navigator.hop(from: a, 0, at: 50, to: b, 0, limits: limits)
        XCTAssertEqual(hop?.takeoffX, 96)
        XCTAssertEqual(hop?.landX, 208)
        XCTAssertNil(Navigator.hop(from: a, 0, at: 50, to: b, 0, limits: NavLimits(up: 300, across: 50, margin: 8)))
    }

    func testJumpUpOntoAWindowInFront() {
        // The window behind is cut exactly where the one in front begins.
        let back = surface(.window(1), y: 200, 100...372)
        let front = surface(.window(2), y: 260, 372...600)
        let hop = Navigator.hop(from: back, 0, at: 200, to: front, 0, limits: limits)
        XCTAssertEqual(hop?.takeoffX, 368)
        XCTAssertEqual(hop?.landX, 380)
    }

    // MARK: The default furniture

    /// The default layout must let cats climb from the floor to the menu bar and back,
    /// using the same limits and surfaces as `CatWorld`.
    func testDefaultFurnitureConnectsFloorAndMenuBar() {
        for (width, height, menuBar) in [(1440.0, 900.0, 24.0), (1728.0, 1117.0, 38.0), (2560.0, 1440.0, 25.0)] {
            let geo = WorldGeometry(mode: .screen, frame: NSRect(x: 0, y: 0, width: width, height: height),
                                    menuBarHeight: menuBar, menuBarY: height - menuBar, groundY: 0, notch: nil)
            let p = geo.furniturePixel
            let catLimits = NavLimits(up: 9 * CGFloat(CatArt.H) * p, across: 120 * p, margin: 4 * p)

            var surfaces: [SurfaceID: Surface] = [
                .menuBar: surface(.menuBar, y: geo.menuBarY, 0...width),
                .ground: surface(.ground, y: 0, 0...width),
            ]
            var links: [ClimbLink] = []
            for f in Furniture.defaults(screenWidth: width, screenHeight: height, floor: 0) {
                switch f.kind {
                case .shelf:
                    surfaces[.shelf(f.id)] = surface(.shelf(f.id), y: f.y, f.x...(f.x + f.width))
                case .post:
                    let perchY = (CGFloat(f.height) / p).rounded() * p
                    let half = CGFloat(PropArt.postWidth - 2) / 2 * p
                    surfaces[.perch(f.id)] = surface(.perch(f.id), y: perchY, (f.x - half)...(f.x + half))
                    links.append(ClimbLink(post: f.id, x: f.x, bottom: .ground, top: .perch(f.id)))
                default:
                    break
                }
            }

            let up = Navigator.explore(from: .init(id: .ground, segment: 0), x: width / 2, surfaces: surfaces,
                                       links: links, limits: catLimits) { _, x in x }
            XCTAssertNotNil(up[.init(id: .menuBar, segment: 0)], "menu bar unreachable from the floor on \(width)×\(height)")

            let down = Navigator.explore(from: .init(id: .menuBar, segment: 0), x: width / 2, surfaces: surfaces,
                                         links: links, limits: catLimits) { _, x in x }
            XCTAssertNotNil(down[.init(id: .ground, segment: 0)], "floor unreachable from the menu bar on \(width)×\(height)")
        }
    }
}
