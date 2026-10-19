import Metal
import SceneKit

/// Renders the scene at a fraction of the window's resolution, then scales it up with
/// nearest-neighbor sampling, for crisp, chunky pixels. Transparency is kept.
enum PixelTechnique {
    /// Fraction of the window's resolution the scene is drawn at. Smaller means chunkier pixels.
    static let resolution = 0.25

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct QuadIn { float4 position [[attribute(0)]]; };
    struct QuadOut { float4 position [[position]]; float2 uv; };

    vertex QuadOut pixel_vertex(QuadIn in [[stage_in]]) {
        QuadOut out;
        out.position = in.position;
        out.uv = float2((in.position.x + 1) * 0.5, 1 - (in.position.y + 1) * 0.5);
        return out;
    }

    fragment half4 pixel_fragment(QuadOut in [[stage_in]],
                                  texture2d<half, access::sample> colorSampler [[texture(0)]]) {
        constexpr sampler nearest(filter::nearest, address::clamp_to_edge);
        return colorSampler.sample(nearest, in.uv);
    }
    """

    /// Returns nil if the shader can't be built, in which case the scene just renders normally.
    static func make(device: MTLDevice?) -> SCNTechnique? {
        guard let device, let library = try? device.makeLibrary(source: shaderSource, options: nil) else { return nil }
        let technique = SCNTechnique(dictionary: [
            "passes": [
                "lowres": [
                    "draw": "DRAW_SCENE",
                    "outputs": ["color": "lowColor", "depth": "lowDepth"],
                    "colorStates": ["clear": true, "clearColor": "0 0 0 0"],
                    "depthStates": ["clear": true],
                ],
                "upscale": [
                    "draw": "DRAW_QUAD",
                    "metalVertexShader": "pixel_vertex",
                    "metalFragmentShader": "pixel_fragment",
                    "inputs": ["colorSampler": "lowColor"],
                    "outputs": ["color": "COLOR"],
                ],
            ],
            "sequence": ["lowres", "upscale"],
            "targets": [
                "lowColor": ["type": "color", "scaleFactor": resolution],
                "lowDepth": ["type": "depth", "scaleFactor": resolution],
            ],
        ])
        technique?.library = library
        return technique
    }
}
