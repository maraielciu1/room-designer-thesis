//
//  TextureGenerator.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 02.03.2026.
//
//  Generates procedural tileable textures (wood, brick, tiles, etc.)
//  for room surfaces in RealityKit.
//

import UIKit
import CoreGraphics

enum TextureGenerator {

    // Pixels per real-world meter (balance quality vs. memory)
    private static let ppm: Int = 128

    // MARK: - Public API

    /// Returns a `CGImage` with the given pattern baked at the correct scale.
    /// `widthM` / `heightM` are the surface dimensions in metres.
    static func texture(
        for pattern: SurfacePattern,
        color: UIColor,
        widthM: Float,
        heightM: Float
    ) -> CGImage? {
        guard pattern != .none else { return nil }
        let w = min(max(Int(widthM * Float(ppm)), 64), 1024)
        let h = min(max(Int(heightM * Float(ppm)), 64), 1024)
        switch pattern {
        case .none:          return nil
        case .woodPlanks:    return wood(w, h, color, widthM, heightM)
        case .ceramicTiles:  return tiles(w, h, color, widthM, heightM)
        case .brick:         return bricks(w, h, color, widthM, heightM)
        case .herringbone:   return parquet(w, h, color, widthM, heightM)
        case .concrete:      return concrete(w, h, color)
        case .marble:        return marble(w, h, color)
        }
    }

    /// Small preview for the pattern picker (84 × 84 px).
    static func thumbnail(for pattern: SurfacePattern, color: UIColor) -> UIImage {
        let s = 84
        if pattern == .none {
            return solidImage(color: color, w: s, h: s)
        }
        if let cg = texture(for: pattern, color: color, widthM: 2, heightM: 2) {
            return UIImage(cgImage: cg)
        }
        return solidImage(color: color, w: s, h: s)
    }

    // MARK: - Patterns

    /// Wood planks — horizontal boards with grain and stagger joints.
    private static func wood(
        _ w: Int, _ h: Int, _ color: UIColor,
        _ mW: Float, _ mH: Float
    ) -> CGImage? {
        let size = CGSize(width: w, height: h)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        // Background
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))

        let planks = max(Int(mH * 6), 3) // ~6 planks per metre
        let pH = CGFloat(h) / CGFloat(planks)

        for i in 0..<planks {
            let y = CGFloat(i) * pH
            // Slight colour variation per plank
            let v = CGFloat.random(in: -0.07...0.07)
            let pc = UIColor(red: clamp01(r + v), green: clamp01(g + v * 0.8),
                             blue: clamp01(b + v * 0.5), alpha: 1)
            ctx.setFillColor(pc.cgColor)
            ctx.fill(CGRect(x: 0, y: y + 1, width: CGFloat(w), height: pH - 2))

            // Grain lines
            ctx.setStrokeColor(UIColor(red: clamp01(r - 0.06), green: clamp01(g - 0.06),
                                       blue: clamp01(b - 0.08), alpha: 0.25).cgColor)
            ctx.setLineWidth(0.5)
            for _ in 0..<Int.random(in: 2...4) {
                let gy = y + CGFloat.random(in: 3...(pH - 3))
                ctx.move(to: CGPoint(x: 0, y: gy))
                ctx.addLine(to: CGPoint(x: CGFloat(w), y: gy + CGFloat.random(in: -1...1)))
                ctx.strokePath()
            }

            // Gap between planks
            ctx.setStrokeColor(UIColor(red: clamp01(r - 0.15), green: clamp01(g - 0.15),
                                       blue: clamp01(b - 0.15), alpha: 0.5).cgColor)
            ctx.setLineWidth(1.5)
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: CGFloat(w), y: y))
            ctx.strokePath()

            // Stagger joints (vertical end-to-end)
            let joints = max(Int(mW * 1.5), 1)
            for j in 0..<joints {
                let jx = (CGFloat(j) + CGFloat.random(in: 0.3...0.7)) * CGFloat(w) / CGFloat(joints)
                ctx.move(to: CGPoint(x: jx, y: y))
                ctx.addLine(to: CGPoint(x: jx, y: y + pH))
                ctx.strokePath()
            }
        }

        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img?.cgImage
    }

    /// Ceramic tiles — regular grid with grout.
    private static func tiles(
        _ w: Int, _ h: Int, _ color: UIColor,
        _ mW: Float, _ mH: Float
    ) -> CGImage? {
        let size = CGSize(width: w, height: h)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        // Grout fill
        let grout = UIColor(red: clamp01(r - 0.20), green: clamp01(g - 0.20),
                            blue: clamp01(b - 0.20), alpha: 1)
        ctx.setFillColor(grout.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))

        let tpm = 3 // tiles per metre
        let tx = max(Int(mW * Float(tpm)), 1)
        let ty = max(Int(mH * Float(tpm)), 1)
        let tw = CGFloat(w) / CGFloat(tx)
        let th = CGFloat(h) / CGFloat(ty)
        let gap: CGFloat = 2

        for row in 0..<ty {
            for col in 0..<tx {
                let v = CGFloat.random(in: -0.03...0.03)
                let tc = UIColor(red: clamp01(r + v), green: clamp01(g + v),
                                 blue: clamp01(b + v), alpha: 1)
                ctx.setFillColor(tc.cgColor)
                let rect = CGRect(x: CGFloat(col) * tw + gap,
                                  y: CGFloat(row) * th + gap,
                                  width: tw - gap * 2, height: th - gap * 2)
                ctx.fill(rect)
            }
        }

        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img?.cgImage
    }

    /// Running-bond brick.
    private static func bricks(
        _ w: Int, _ h: Int, _ color: UIColor,
        _ mW: Float, _ mH: Float
    ) -> CGImage? {
        let size = CGSize(width: w, height: h)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        // Mortar
        let mortarColor = UIColor(white: clamp01((r + g + b) / 3 - 0.15), alpha: 1)
        ctx.setFillColor(mortarColor.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))

        let coursesPerM = 4
        let bricksPerM  = 3
        let courses = max(Int(mH * Float(coursesPerM)), 1)
        let bricksW = max(Int(mW * Float(bricksPerM)), 1)
        let bH = CGFloat(h) / CGFloat(courses)
        let bW = CGFloat(w) / CGFloat(bricksW)
        let gap: CGFloat = 3

        for course in 0..<courses {
            let y = CGFloat(course) * bH
            let offset: CGFloat = course % 2 == 0 ? 0 : bW / 2
            let start = course % 2 == 0 ? 0 : -1
            for col in start...bricksW {
                let x = CGFloat(col) * bW + offset
                let v = CGFloat.random(in: -0.06...0.06)
                let bc = UIColor(red: clamp01(r + v), green: clamp01(g + v * 0.7),
                                 blue: clamp01(b + v * 0.5), alpha: 1)
                ctx.setFillColor(bc.cgColor)
                ctx.fill(CGRect(x: x + gap, y: y + gap,
                                width: bW - gap * 2, height: bH - gap * 2))
            }
        }

        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img?.cgImage
    }

    /// Parquet / herringbone — alternating horizontal & vertical blocks.
    private static func parquet(
        _ w: Int, _ h: Int, _ color: UIColor,
        _ mW: Float, _ mH: Float
    ) -> CGImage? {
        let size = CGSize(width: w, height: h)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        let gapColor = UIColor(red: clamp01(r - 0.12), green: clamp01(g - 0.12),
                               blue: clamp01(b - 0.12), alpha: 1)
        ctx.setFillColor(gapColor.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))

        // Unit block size (~0.25 m)
        let unitW = CGFloat(w) / CGFloat(max(mW * 4, 1))
        let unitH = unitW / 3
        let gap: CGFloat = 1.5
        let cols = Int(CGFloat(w) / unitW) + 2
        let rows = Int(CGFloat(h) / (unitH * 2)) + 2

        for row in 0..<rows {
            for col in 0..<cols {
                let bx = CGFloat(col) * unitW
                let by = CGFloat(row) * unitH * 2

                // Block A — horizontal
                let v1 = CGFloat.random(in: -0.04...0.04)
                ctx.setFillColor(UIColor(red: clamp01(r + v1), green: clamp01(g + v1),
                                         blue: clamp01(b + v1 * 0.6), alpha: 1).cgColor)
                ctx.fill(CGRect(x: bx + gap, y: by + gap,
                                width: unitW - gap * 2, height: unitH - gap * 2))

                // Block B — offset half-unit
                let v2 = CGFloat.random(in: -0.04...0.04)
                ctx.setFillColor(UIColor(red: clamp01(r + v2), green: clamp01(g + v2),
                                         blue: clamp01(b + v2 * 0.6), alpha: 1).cgColor)
                ctx.fill(CGRect(x: bx + unitW / 2 + gap, y: by + unitH + gap,
                                width: unitW - gap * 2, height: unitH - gap * 2))
            }
        }

        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img?.cgImage
    }

    /// Concrete — subtle speckle noise.
    private static func concrete(_ w: Int, _ h: Int, _ color: UIColor) -> CGImage? {
        let size = CGSize(width: w, height: h)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))

        let count = w * h / 25
        for _ in 0..<count {
            let x = CGFloat.random(in: 0...CGFloat(w))
            let y = CGFloat.random(in: 0...CGFloat(h))
            let v = CGFloat.random(in: -0.08...0.08)
            ctx.setFillColor(UIColor(red: clamp01(r + v), green: clamp01(g + v),
                                     blue: clamp01(b + v), alpha: 0.35).cgColor)
            let s = CGFloat.random(in: 1...3)
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: s, height: s))
        }

        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img?.cgImage
    }

    /// Marble — base colour with curved veins.
    private static func marble(_ w: Int, _ h: Int, _ color: UIColor) -> CGImage? {
        let size = CGSize(width: w, height: h)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))

        let veins = max(w, h) / 40
        for _ in 0..<veins {
            let v = CGFloat.random(in: -0.15...0.15)
            let vc = UIColor(red: clamp01(r + v), green: clamp01(g + v),
                             blue: clamp01(b + v), alpha: CGFloat.random(in: 0.08...0.30))
            ctx.setStrokeColor(vc.cgColor)
            ctx.setLineWidth(CGFloat.random(in: 0.5...2.5))

            ctx.move(to: CGPoint(x: CGFloat.random(in: 0...CGFloat(w)),
                                 y: CGFloat.random(in: 0...CGFloat(h))))
            for _ in 0..<Int.random(in: 3...6) {
                ctx.addCurve(
                    to:       CGPoint(x: CGFloat.random(in: 0...CGFloat(w)),
                                      y: CGFloat.random(in: 0...CGFloat(h))),
                    control1: CGPoint(x: CGFloat.random(in: 0...CGFloat(w)),
                                      y: CGFloat.random(in: 0...CGFloat(h))),
                    control2: CGPoint(x: CGFloat.random(in: 0...CGFloat(w)),
                                      y: CGFloat.random(in: 0...CGFloat(h))))
            }
            ctx.strokePath()
        }

        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img?.cgImage
    }

    // MARK: - Helpers

    private static func clamp01(_ v: CGFloat) -> CGFloat { max(0, min(1, v)) }

    private static func solidImage(color: UIColor, w: Int, h: Int) -> UIImage {
        let s = CGSize(width: w, height: h)
        UIGraphicsBeginImageContextWithOptions(s, true, 1)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: s))
        let img = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return img
    }
}
