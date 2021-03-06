#include <metal_stdlib>

using namespace metal;


struct TinyVertex{
    float4 location [[position]];
    float2 textureVX;
};
struct TinyVertexIn{
    float4 location [[attribute(0)]];
    float2 textureVX [[attribute(1)]];
};


vertex TinyVertex vertexShader(TinyVertexIn vertices [[stage_in]]){
    TinyVertex r;
    r.location = vertices.location;
    r.textureVX = vertices.textureVX;
    return r;
}

fragment half4 fragmentShader(TinyVertex in [[stage_in]],
                              const texture2d<half> texture [[texture(0)]],
                              const sampler textureSampler [[sampler(0)]]){
    half4 color = texture.sample(textureSampler, in.textureVX);
    return half4(color.xyz,1);
}
float2 createSampleCood(uint2 gid,float w,float h,int offsetX,int offsetY,uint2 thread_grid_size){
    float2 startPix = float2(gid.x * thread_grid_size.x,gid.y * thread_grid_size.y);
    float2 temp = float2((startPix.x + offsetX) / w ,(startPix.y + offsetY) / h);
    return temp;
}

float2 createSampleCood(uint2 gid,float w,float h){
    return float2(float(gid.x) / w, float(gid.y) / h);
}
enum fillType{
    scaleToFit,
    scaleToFill,
    Fill
};

void imageFill(const texture2d<half, access::sample> from,
                            texture2d<half, access::write> to ,
               uint2 gid,fillType ft)
{
    constexpr sampler imgSample(mag_filter::linear,min_filter::linear,filter::linear,mip_filter::linear);
    float2 originSize = float2(from.get_width(),from.get_height());
    float2 targetSize = originSize;
    float2 canvas = float2(to.get_width(),to.get_height());
    
    float rw = canvas.x / originSize.x;
    float rh = canvas.y / originSize.y;
    if(ft == scaleToFit){
        targetSize = originSize * min(rw, rh);
    }else if(ft == scaleToFill){
        targetSize = originSize * max(rw, rh);
    }else if(ft == Fill){
        targetSize = canvas;
    }
    
    float px = (canvas.x - targetSize.x) / 2.0;
    float py = (canvas.y - targetSize.y) / 2.0;
    float2 location = createSampleCood(gid, targetSize.x, targetSize.y);
    half4 color = from.sample(imgSample, location);
    uint2 wp = uint2(ceil(gid.x + px),ceil(gid.y + py));
    if(gid.x <= targetSize.x && gid.y <= targetSize.y){
        to.write(color, wp);
    }
}
kernel void imageScaleToFit(const texture2d<half, access::sample> from [[ texture(0) ]],
                            texture2d<half, access::write> to [[texture(1)]],
                            uint2 gid [[thread_position_in_grid]])
{
    imageFill(from, to, gid, scaleToFit);
}

kernel void imageScaleToFill(const texture2d<half, access::sample> from [[ texture(0) ]],
                            texture2d<half, access::write> to [[texture(1)]],
                            uint2 gid [[thread_position_in_grid]])
{
    imageFill(from, to, gid, scaleToFill);
}
kernel void imageTransform(const texture2d<half, access::sample> from [[ texture(0) ]],
                            texture2d<half, access::write> to [[texture(1)]],
                            device float3x3 *transform [[buffer(0)]],
                            uint2 gid [[thread_position_in_grid]])
{
    constexpr sampler imgSample(mag_filter::linear,min_filter::linear,filter::linear,mip_filter::linear);;

    float3 fg = float3(gid.x,gid.y,1);
    float3 gv = transform[0] * fg;
    float2 sp = float2(gv.x  / to.get_height(),gv.y / to.get_width());
    half4 color = from.sample(imgSample, sp);
    to.write(color, gid);
}



