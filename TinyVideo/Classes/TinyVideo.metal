#include <metal_stdlib>

using namespace metal;


struct TinyVertex{
    float4 location [[position]];
    float2 textureVX;
};


vertex TinyVertex vertexShader(uint vertexID [[vertex_id]],
             constant TinyVertex *vertices [[buffer(0)]],
             constant float2 *size [[buffer(1)]]){
    TinyVertex r;
    
    r.location = float4(vertices[vertexID].location.x / size[0].x * 2,vertices[vertexID].location.y / size[0].y * 2 ,0,1);
    r.textureVX = vertices[vertexID].textureVX;
    return r;
}

fragment half4 fragmentShader(TinyVertex in [[stage_in]], const texture2d<half> texture [[texture(0)]]){
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    return texture.sample(textureSampler, in.textureVX);
}


kernel void add_arrays(device const float* inA,
                       device const float* inB,
                       device float* result,
                       uint index [[thread_position_in_grid]])
{
    result[index] = inA[index] + inB[index];
}
float2 createSampleCood(uint2 gid,float w,float h,int offsetX,int offsetY,uint2 thread_grid_size){
    float2 startPix = float2(gid.x * thread_grid_size.x,gid.y * thread_grid_size.y);
    float2 temp = float2((startPix.x + offsetX) / w ,1 - (startPix.y + offsetY) / h);
    return temp;
}

kernel void imageScale(const texture2d<half, access::sample> from [[texture(0)]],
                       texture2d<half, access::write> to [[texture (1)]],
                       device const float* scale [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]])
{
    constexpr sampler sample;
    float g = scale[0];
    float2 startPix = float2(gid.x * g,gid.y * g);
    float w = to.get_width();
    
    float h = to.get_height();
    for (int i = 0; i < g; i++){
        for (int j = 0; j < g; j++){
            if(startPix.x + i >= to.get_width() || startPix.y + j >= to.get_height()){
                break;
            }
            float2 temp = createSampleCood(gid, w, h, i, j, uint2(g,g));
            half4 c = from.sample(sample, temp);
            
//            half4 c = half4(temp.x,temp.y,0,1);
//            half4 c = half4(gid.x / 20.0,gid.y / 20.0 ,temp.x,1);
            to.write(c, uint2(startPix.x + i,startPix.y + j));
        }
    }
}

kernel void imageScaleToFit(const texture2d<half, access::sample> from [[ texture(0) ]],
                            texture2d<half, access::write> to [[texture(1)]],
                            device const uint2* scale [[buffer(0)]],
                            uint2 gid [[thread_position_in_grid]])
{
    float rw = from.get_width() / to.get_width();
    float rh = from.get_height() / to.get_height();
    float r = 1;
    if(rw > 1 && rh > 1){
        r = 1 / max(rw, rh);
    }else if(rw < 1 && rh < 1){
        r = 1 / min(rw, rh);
    }else{
        if(rw > 1){
            r = 1 / rw;
        }else if (rh > 1){
            r = 1 / rh;
        }
    }
    uint2 grid = uint2(1,1);
    constexpr sampler imgSample;
    uint2 targetSize = uint2(from.get_width() * r,from.get_height() * r);
//    for (uint i = 0 ; i < grid.x; i++){
//        for (uint j = 0 ; j < grid.y; j++){
//            float2 location = createSampleCood(gid, targetSize.x, targetSize.y, i, j, grid);
//            half4 color = from.sample(imgSample, location);
////
//            uint x = (to.get_width() - targetSize.x) / 2 + (gid.x * grid.x + i);
//            uint y = (to.get_height() - targetSize.y) / 2 + (gid.y * grid.y + j);
//            uint2 start = uint2(x,y);
//            to.write(color, uint2(gid.x * grid.x + i,gid.y * grid.y + j));
//        }
//    }
//
    float2 location = createSampleCood(gid, targetSize.x, targetSize.y, 0, 0, grid);
    half4 color = from.sample(imgSample, location);
//
//    uint x = (to.get_width() - targetSize.x) / 2 + (gid.x * grid.x + i);
//    uint y = (to.get_height() - targetSize.y) / 2 + (gid.y * grid.y + j);
//    uint2 start = uint2(x,y);
    to.write(color, uint2(gid.x,gid.y));
    
    
    
}

