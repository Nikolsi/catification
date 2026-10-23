import CoreGraphics

struct Hop {
    enum Kind { case jump, climbUp, climbDown }
    var kind: Kind
    var from: SurfaceID
    var to: SurfaceID
    var takeoffX: CGFloat
    var landX: CGFloat
}

struct Route {
    var hops: [Hop]
    var goal: SurfaceID
    var goalX: CGFloat
}

struct NavLimits {
    /// Highest jump up.
    var up: CGFloat
    /// Widest gap across.
    var across: CGFloat
    /// How far from a segment's end a cat stands.
    var margin: CGFloat
}

/// Plans routes between surfaces: walk to a takeoff point, jump or climb, repeat.
enum Navigator {
    struct Node: Hashable, Comparable {
        let id: SurfaceID
        let segment: Int

        static func < (a: Node, b: Node) -> Bool { a.id != b.id ? a.id < b.id : a.segment < b.segment }
    }

    struct Entry {
        var cost: CGFloat
        var x: CGFloat
        var previous: Node?
        var hop: Hop?
    }

    /// One hop from segment `ai` of `a` (standing at `fromX`) to segment `bi` of `b`, if a cat can make it.
    static func hop(from a: Surface, _ ai: Int, at fromX: CGFloat, to b: Surface, _ bi: Int, limits: NavLimits) -> Hop? {
        let ar = a.segments[ai], br = b.segments[bi]
        let m = limits.margin
        let dy = b.y - a.y
        if dy > limits.up { return nil }

        let overlapLo = max(ar.lowerBound, br.lowerBound) + m
        let overlapHi = min(ar.upperBound, br.upperBound) - m

        if dy > 4, overlapHi >= overlapLo {
            // Straight up: surfaces can be passed through from below.
            let x = min(max(fromX, overlapLo), overlapHi)
            return Hop(kind: .jump, from: a.id, to: b.id, takeoffX: x, landX: x)
        }

        if dy < -4, overlapHi >= overlapLo {
            // Down onto something right below: in this front view a cat simply hops off the ledge.
            let x = min(max(fromX, overlapLo), overlapHi)
            return Hop(kind: .jump, from: a.id, to: b.id, takeoffX: x, landX: x)
        }

        if dy < -4 {
            // Down: step off an end of `a` onto the part of `b` that sticks out past it.
            var options: [Hop] = []
            if br.lowerBound + m <= ar.lowerBound - m {
                let land = min(max(ar.lowerBound - 3 * m, br.lowerBound + m), min(br.upperBound - m, ar.lowerBound - m))
                options.append(Hop(kind: .jump, from: a.id, to: b.id, takeoffX: ar.lowerBound + m * 0.5, landX: land))
            }
            if br.upperBound - m >= ar.upperBound + m {
                let land = max(min(ar.upperBound + 3 * m, br.upperBound - m), max(br.lowerBound + m, ar.upperBound + m))
                options.append(Hop(kind: .jump, from: a.id, to: b.id, takeoffX: ar.upperBound - m * 0.5, landX: land))
            }
            let reach = limits.across * (1 + min(-dy, 600) / 600)
            return options
                .filter { abs($0.landX - $0.takeoffX) <= reach }
                .min { abs($0.takeoffX - fromX) < abs($1.takeoffX - fromX) }
        }

        // Roughly level, or up without overlap: leap across the gap.
        let takeoff: CGFloat, land: CGFloat
        // `>=`: a window in front of another cuts its top edge exactly where its own begins.
        if br.lowerBound >= ar.upperBound {
            takeoff = ar.upperBound - m * 0.5
            land = br.lowerBound + m
        } else if br.upperBound <= ar.lowerBound {
            takeoff = ar.lowerBound + m * 0.5
            land = br.upperBound - m
        } else {
            return nil
        }
        guard abs(land - takeoff) <= limits.across else { return nil }
        return Hop(kind: .jump, from: a.id, to: b.id, takeoffX: takeoff, landX: land)
    }

    static func cost(of hop: Hop, dy: CGFloat) -> CGFloat {
        switch hop.kind {
        case .climbUp, .climbDown:
            return 40 + abs(dy) * 0.4
        case .jump:
            return 60 + abs(hop.landX - hop.takeoffX) + (dy > 0 ? dy * 1.3 : -dy * 0.5)
        }
    }

    /// Dijkstra over surface segments.
    static func explore(
        from start: Node, x startX: CGFloat,
        surfaces: [SurfaceID: Surface], links: [ClimbLink], limits: NavLimits,
        adjust: (SurfaceID, CGFloat) -> CGFloat
    ) -> [Node: Entry] {
        var best: [Node: Entry] = [start: Entry(cost: 0, x: startX)]
        var open: Set<Node> = [start]
        var done = Set<Node>()
        let nodes = surfaces.values.flatMap { s in s.segments.indices.map { Node(id: s.id, segment: $0) } }.sorted()

        while let current = open.min(by: { a, b in
            let ca = best[a]!.cost, cb = best[b]!.cost
            return ca != cb ? ca < cb : a < b
        }) {
            open.remove(current)
            done.insert(current)
            guard let entry = best[current], let a = surfaces[current.id] else { continue }

            var candidates: [(Node, Hop)] = []
            for n in nodes where n != current && !done.contains(n) {
                guard let b = surfaces[n.id], var h = hop(from: a, current.segment, at: entry.x, to: b, n.segment, limits: limits) else { continue }
                h.takeoffX = adjust(a.id, h.takeoffX)
                h.landX = adjust(b.id, h.landX)
                candidates.append((n, h))
            }
            for link in links {
                if link.bottom == current.id, a.segmentIndex(containing: link.x) == current.segment,
                   let top = surfaces[link.top], let seg = top.segmentIndex(containing: link.x) {
                    candidates.append((Node(id: link.top, segment: seg),
                                       Hop(kind: .climbUp, from: a.id, to: link.top, takeoffX: link.x, landX: link.x)))
                }
                if link.top == current.id, let bottom = surfaces[link.bottom], let seg = bottom.segmentIndex(containing: link.x) {
                    candidates.append((Node(id: link.bottom, segment: seg),
                                       Hop(kind: .climbDown, from: a.id, to: link.bottom, takeoffX: link.x, landX: link.x)))
                }
            }

            for (n, h) in candidates where !done.contains(n) {
                let dy = (surfaces[n.id]?.y ?? a.y) - a.y
                let c = entry.cost + abs(h.takeoffX - entry.x) + cost(of: h, dy: dy)
                if c < best[n]?.cost ?? .infinity {
                    best[n] = Entry(cost: c, x: h.landX, previous: current, hop: h)
                    open.insert(n)
                }
            }
        }
        return best
    }

    static func hops(to goal: Node, in explored: [Node: Entry]) -> [Hop]? {
        guard explored[goal] != nil else { return nil }
        var hops: [Hop] = []
        var node = goal
        while let entry = explored[node], let previous = entry.previous, let hop = entry.hop {
            hops.append(hop)
            node = previous
        }
        return hops.reversed()
    }

    /// Initial velocity for a jump from `p0` to `p1` that clears both by a bit and stays under `ceiling`.
    static func ballistic(from p0: CGPoint, to p1: CGPoint, ceiling: CGFloat, gravity g: CGFloat) -> (vx: CGFloat, vy: CGFloat, duration: CGFloat) {
        let dx = p1.x - p0.x
        let top = max(p0.y, p1.y)
        var apex = top + max(10, min(60, abs(dx) * 0.25))
        apex = max(min(apex, ceiling), top + 2)
        let vy = (2 * g * (apex - p0.y)).squareRoot()
        let t = vy / g + (2 * (apex - p1.y) / g).squareRoot()
        let duration = max(t, 0.05)
        return (dx / duration, vy, duration)
    }

    static func trajectory(from p0: CGPoint, vx: CGFloat, vy: CGFloat, duration: CGFloat, gravity g: CGFloat, spacing: CGFloat) -> [CGPoint] {
        var points: [CGPoint] = []
        var t: CGFloat = 0
        var last = p0
        points.append(p0)
        while t < duration {
            t += 0.004
            let p = CGPoint(x: p0.x + vx * t, y: p0.y + vy * t - g * t * t / 2)
            if hypot(p.x - last.x, p.y - last.y) >= spacing {
                points.append(p)
                last = p
            }
        }
        return points
    }
}
