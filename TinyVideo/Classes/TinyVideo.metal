//
//  TinyVideo.metal
//  TinyVideo
//
//  Created by hao yin on 2021/2/20.
//

#include <metal_stdlib>
using namespace metal;


struct Vertex {
    float2 position;
    float point_size;
    float4 color;
    float rotation;
};

struct VertexOut {
    float4 position [[position]];
    float point_size [[point_size]];
    float4 color;
    float rotation;
};



vertex VertexOut main_vertex(const device Vertex* vertices [[ buffer(0) ]], unsigned int vid [[ vertex_id ]]) {
    VertexOut output;
    
    output.position = float4(vertices[vid].position, 0, 1);
    output.point_size = vertices[vid].point_size;
    output.color = vertices[vid].color;
    output.rotation = vertices[vid].rotation;
    
    return output;
};

fragment half4 main_fragment(Vertex vert [[stage_in]]) {
    return half4(vert.color);
};

/** Gets the proper texture coordinate given the rotation of the vertex. */
float2 transformPointCoord(float2 pointCoord, float rotation, float2 anchor) {
    float2 point = pointCoord - anchor;
    float x = point.x * cos(rotation) - point.y * sin(rotation);
    float y = point.x * sin(rotation) + point.y * cos(rotation);
    return float2(x, y) + anchor;
}
fragment half4 textured_fragment(Vertex vert [[stage_in]], sampler sampler2D,
                                 texture2d<float> texture [[texture(0)]],
                                 float2 pointCoord [[point_coord]]) {
    
    // TODO: This is just a temporary fix for drawing shapes, since they for some reason don't show up with textures.
    if(vert.rotation == -1) {
        return half4(vert.color);
    }
    
    float2 text_coord = transformPointCoord(pointCoord, vert.rotation, float2(0.5));
    float4 color = float4(texture.sample(sampler2D, text_coord));
    float4 ret = float4(vert.color.rgb, color.a * vert.color.a * vert.color.a);
    
    return half4(ret);
}


