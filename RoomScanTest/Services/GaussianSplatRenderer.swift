//
//  GaussianSplatRenderer.swift
//  RoomScanTest
//
//  Metal-based renderer for 3D Gaussian Splatting scenes.
//  Projects each Gaussian to a screen-space 2D ellipse and renders
//  them as alpha-blended quads with proper Gaussian falloff.
//
//  Shader source is compiled at runtime to avoid .metal file management issues.
//

import Foundation
import Metal
import MetalKit
import simd

// MARK: - Renderer

class GaussianSplatRenderer: NSObject {

    // Metal state
    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    // Buffers
    private var gaussianBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?

    // Scene
    private(set) var gaussianCount: Int = 0
    private var gpuGaussians: [GaussianGPU] = []
    private var scene: GaussianSplatScene?
    private var sortedIndices: [UInt32] = []

    // Camera
    var orbitTheta: Float = 0                       // azimuth (radians)
    var orbitPhi: Float = Float.pi / 6              // elevation (radians)
    var orbitDistance: Float = 2.0                   // distance from center
    var orbitCenter: SIMD3<Float> = .zero            // look-at target

    // Performance
    private(set) var lastFrameTime: CFTimeInterval = 0
    private var lastTimestamp: CFTimeInterval = 0

    // MARK: - Init

    init?(device: MTLDevice? = nil) {
        guard let dev = device ?? MTLCreateSystemDefaultDevice() else {
            print("[GaussianSplatRenderer] Metal is not available")
            return nil
        }
        self.device = dev

        guard let queue = dev.makeCommandQueue() else {
            print("[GaussianSplatRenderer] Could not create command queue")
            return nil
        }
        self.commandQueue = queue

        // Compile shader from embedded source
        do {
            let library = try dev.makeLibrary(source: Self.shaderSource, options: nil)
            guard let vertexFn = library.makeFunction(name: "gaussianVertex"),
                  let fragmentFn = library.makeFunction(name: "gaussianFragment") else {
                print("[GaussianSplatRenderer] Could not find shader functions")
                return nil
            }

            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vertexFn
            desc.fragmentFunction = fragmentFn

            // Color attachment with alpha blending (premultiplied)
            let colorAtt = desc.colorAttachments[0]!
            colorAtt.pixelFormat = .bgra8Unorm
            colorAtt.isBlendingEnabled = true
            colorAtt.sourceRGBBlendFactor = .one
            colorAtt.destinationRGBBlendFactor = .oneMinusSourceAlpha
            colorAtt.sourceAlphaBlendFactor = .one
            colorAtt.destinationAlphaBlendFactor = .oneMinusSourceAlpha

            self.pipelineState = try dev.makeRenderPipelineState(descriptor: desc)
        } catch {
            print("[GaussianSplatRenderer] Shader compilation failed: \(error)")
            return nil
        }

        super.init()
    }

    // MARK: - Scene Loading

    func loadScene(_ scene: GaussianSplatScene) {
        self.scene = scene
        self.gaussianCount = scene.gaussians.count

        // Convert to GPU format
        gpuGaussians = scene.gaussians.map { g in
            GaussianGPU(
                px: g.position.x, py: g.position.y, pz: g.position.z,
                opacity: g.opacity,
                cr: g.color.x, cg: g.color.y, cb: g.color.z,
                sx: g.scale.x, sy: g.scale.y, sz: g.scale.z,
                rw: g.rotation.real,
                rx: g.rotation.imag.x,
                ry: g.rotation.imag.y,
                rz: g.rotation.imag.z
            )
        }

        // Create GPU buffers
        let gaussianBytes = gpuGaussians.count * MemoryLayout<GaussianGPU>.stride
        gaussianBuffer = device.makeBuffer(bytes: gpuGaussians, length: gaussianBytes, options: .storageModeShared)

        sortedIndices = Array(0..<UInt32(gaussianCount))
        let indexBytes = sortedIndices.count * MemoryLayout<UInt32>.stride
        indexBuffer = device.makeBuffer(length: indexBytes, options: .storageModeShared)

        // Set initial camera: frame center region (object is usually there in full-scene reconstructions)
        orbitCenter = scene.center
        orbitDistance = max(scene.extent * 0.4, 0.2)
        orbitDistance = min(orbitDistance, 50)
        orbitTheta = 0
        orbitPhi = Float.pi / 6

        print("[GaussianSplatRenderer] Loaded \(gaussianCount) Gaussians")
    }

    /// Zoom camera in to the center region (object is often there in object-centric scans).
    /// Call after loadScene to frame the likely object area instead of the full scene.
    func frameCenterRegion(zoomFactor: Float = 0.4) {
        guard let scene = scene else { return }
        orbitCenter = scene.center
        orbitDistance = max(scene.extent * zoomFactor, 0.2)
        orbitDistance = min(orbitDistance, 50)
    }

    // MARK: - Rendering

    func render(in view: MTKView) {
        guard gaussianCount > 0,
              let gaussianBuffer = gaussianBuffer,
              let indexBuffer = indexBuffer,
              let drawable = view.currentDrawable,
              let passDescriptor = view.currentRenderPassDescriptor else { return }

        let now = CACurrentMediaTime()
        if lastTimestamp > 0 { lastFrameTime = now - lastTimestamp }
        lastTimestamp = now

        let drawableSize = view.drawableSize
        let aspect = Float(drawableSize.width / drawableSize.height)

        // Compute camera matrices
        let viewMatrix = Self.lookAt(
            eye: cameraPosition, center: orbitCenter, up: SIMD3<Float>(0, 1, 0)
        )
        let projMatrix = Self.perspective(
            fovY: Float.pi / 3, aspect: aspect, near: 0.01, far: 200.0
        )

        // Sort Gaussians back-to-front
        sortGaussians(viewMatrix: viewMatrix)

        //  Upload sorted indices
        let idxPtr = indexBuffer.contents().bindMemory(to: UInt32.self, capacity: sortedIndices.count)
        for i in 0..<sortedIndices.count { idxPtr[i] = sortedIndices[i] }

        // Uniforms
        var uniforms = GaussianUniforms(
            viewMatrix: viewMatrix,
            projectionMatrix: projMatrix,
            viewport: SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height))
        )

        // Render
        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.04, green: 0.05, blue: 0.09, alpha: 1)
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].storeAction = .store

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(gaussianBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(indexBuffer, offset: 0, index: 1)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<GaussianUniforms>.stride, index: 2)

        // Instanced rendering: 4 vertices per quad × N instances
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0,
                               vertexCount: 4, instanceCount: gaussianCount)

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Camera

    var cameraPosition: SIMD3<Float> {
        let cosPhi = cos(orbitPhi)
        return orbitCenter + SIMD3<Float>(
            orbitDistance * cosPhi * sin(orbitTheta),
            orbitDistance * sin(orbitPhi),
            orbitDistance * cosPhi * cos(orbitTheta)
        )
    }

    // MARK: - Sorting

    private func sortGaussians(viewMatrix: simd_float4x4) {
        guard let scene = scene else { return }

        // Extract the third row of the view matrix for z-depth computation
        let r20 = viewMatrix[0][2]
        let r21 = viewMatrix[1][2]
        let r22 = viewMatrix[2][2]
        let r23 = viewMatrix[3][2]

        // Compute depth for each Gaussian and sort
        struct IndexedDepth { var index: UInt32; var depth: Float }
        var depths = [IndexedDepth]()
        depths.reserveCapacity(scene.gaussians.count)

        for i in 0..<scene.gaussians.count {
            let p = scene.gaussians[i].position
            let depth = r20 * p.x + r21 * p.y + r22 * p.z + r23
            depths.append(IndexedDepth(index: UInt32(i), depth: depth))
        }

        // Sort back-to-front: most negative z first (farthest from camera)
        depths.sort { $0.depth < $1.depth }
        sortedIndices = depths.map(\.index)
    }

    // MARK: - Matrix Helpers

    static func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
        let sy = 1.0 / tan(fovY * 0.5)
        let sx = sy / aspect
        let zRange = near - far
        return simd_float4x4(columns: (
            SIMD4<Float>(sx, 0, 0, 0),
            SIMD4<Float>(0, sy, 0, 0),
            SIMD4<Float>(0, 0, far / zRange, -1),
            SIMD4<Float>(0, 0, (near * far) / zRange, 0)
        ))
    }

    static func lookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
        let f = simd_normalize(center - eye)
        let s = simd_normalize(simd_cross(f, up))
        let u = simd_cross(s, f)
        return simd_float4x4(columns: (
            SIMD4<Float>(s.x, u.x, -f.x, 0),
            SIMD4<Float>(s.y, u.y, -f.y, 0),
            SIMD4<Float>(s.z, u.z, -f.z, 0),
            SIMD4<Float>(-simd_dot(s, eye), -simd_dot(u, eye), simd_dot(f, eye), 1)
        ))
    }

    // MARK: - Embedded Metal Shader Source

    static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    // GPU data structures (must match Swift GaussianGPU / GaussianUniforms) 

    struct GaussianGPU {
        packed_float3 position;   // 12 B
        float         opacity;    //  4 B
        packed_float3 color;      // 12 B
        packed_float3 scale;      // 12 B
        packed_float4 rotation;   // 16 B   (w, x, y, z)
    };

    struct Uniforms {
        float4x4 viewMatrix;
        float4x4 projectionMatrix;
        float2   viewport;
        float2   _padding;
    };

    struct VertexOut {
        float4 position [[position]];
        float2 pixelOffset;
        float3 color;
        float  opacity;
        float3 cov2D;            // (a, b, c)  of  [[a,b],[b,c]]
    };

    // Quaternion -> rotation matrix 

    float3x3 quatToRotMat(float4 q) {
        float w = q.x, x = q.y, y = q.z, z = q.w;
        return float3x3(
            float3(1-2*(y*y+z*z),   2*(x*y+w*z),   2*(x*z-w*y)),
            float3(2*(x*y-w*z),   1-2*(x*x+z*z),   2*(y*z+w*x)),
            float3(2*(x*z+w*y),   2*(y*z-w*x),   1-2*(x*x+y*y))
        );
    }

    //  Vertex shader: project Gaussians and compute 2D covariance

    vertex VertexOut gaussianVertex(
        uint vertexID   [[vertex_id]],
        uint instanceID [[instance_id]],
        const device GaussianGPU* gaussians [[buffer(0)]],
        const device uint*        indices   [[buffer(1)]],
        constant Uniforms&        uniforms  [[buffer(2)]]
    ) {
        uint idx = indices[instanceID];
        GaussianGPU g = gaussians[idx];

        // Quad corners (triangle strip)
        float2 corners[4] = { float2(-1,-1), float2(1,-1), float2(-1,1), float2(1,1) };
        float2 corner = corners[vertexID];

        // World -> camera 
        float3 worldPos = float3(g.position);
        float4 camPos   = uniforms.viewMatrix * float4(worldPos, 1.0);

        // Cull behind camera
        if (camPos.z >= -0.01) {
            VertexOut out;
            out.position = float4(0, 0, 2, 1);
            out.opacity  = 0;
            return out;
        }

        // 3D covariance  E = R * S * S^T * R^T 
        float3x3 R = quatToRotMat(float4(g.rotation));
        float3 s   = float3(g.scale);
        float3x3 S = float3x3(float3(s.x,0,0), float3(0,s.y,0), float3(0,0,s.z));
        float3x3 M = R * S;
        float3x3 cov3D = M * transpose(M);

        // Focal lengths in pixels 
        float fx = uniforms.projectionMatrix[0][0] * uniforms.viewport.x * 0.5;
        float fy = uniforms.projectionMatrix[1][1] * uniforms.viewport.y * 0.5;

        float d  = -camPos.z;   // positive depth
        float d2 = d * d;

        //  Jacobian of projection (3 x 3 padded) 
        float3x3 J = float3x3(
            float3(fx/d, 0, 0),
            float3(0, fy/d, 0),
            float3(fx*camPos.x/d2, fy*camPos.y/d2, 0)
        );

        // View rotation (3 x 3 part of view matrix)
        float3x3 W = float3x3(
            uniforms.viewMatrix[0].xyz,
            uniforms.viewMatrix[1].xyz,
            uniforms.viewMatrix[2].xyz
        );

        // 2D covariance 
        float3x3 T   = J * W;
        float3x3 cov = T * cov3D * transpose(T);

        float a = cov[0][0] + 0.3;   // low-pass filter
        float b = cov[0][1];
        float c = cov[1][1] + 0.3;

        // Eigenvalues -> quad radius (3 sig) 
        float det  = a * c - b * b;
        if (det <= 0) det = 0.0001;
        float tr   = a + c;
        float disc = max(0.01, tr * tr * 0.25 - det);
        float lam  = max(0.1, tr * 0.5 + sqrt(disc));
        float radius = clamp(ceil(3.0 * sqrt(lam)), 1.0, 2048.0);

        // Project center -> clip / NDC 
        float4 clip = uniforms.projectionMatrix * camPos;
        float2 ndc  = clip.xy / clip.w;

        // Quad vertex position 
        float2 pxOff  = corner * radius;
        float2 ndcOff = pxOff / (uniforms.viewport * 0.5);

        VertexOut out;
        out.position    = float4(ndc + ndcOff, clip.z / clip.w, 1.0);
        out.pixelOffset = pxOff;
        out.color       = float3(g.color);
        out.opacity     = g.opacity;
        out.cov2D       = float3(a, b, c);
        return out;
    }

    // Fragment shader: evaluate 2D Gaussian 

    fragment float4 gaussianFragment(VertexOut in [[stage_in]]) {
        float a = in.cov2D.x;
        float b = in.cov2D.y;
        float c = in.cov2D.z;

        float det = a * c - b * b;
        if (det <= 0) discard_fragment();

        float invDet = 1.0 / det;
        float2 d = in.pixelOffset;

        // x^T E^{-1} x  for  E^{-1} = (1/det)·[[c, -b], [-b, a]]
        float power = -0.5 * (d.x*d.x*c*invDet - 2.0*d.x*d.y*b*invDet + d.y*d.y*a*invDet);

        if (power > 0.0) discard_fragment();

        float alpha = min(0.99, in.opacity * exp(power));
        if (alpha < 1.0/255.0) discard_fragment();

        // Premultiplied alpha output
        return float4(in.color * alpha, alpha);
    }
    """
}
