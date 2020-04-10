//
//  Shaders.metal
//  MetalSwift
//
//  Created by Seth Sowerby on 8/14/14.
//  Copyright (c) 2014 Seth Sowerby. All rights reserved.
//

#include <metal_stdlib>

using namespace metal;


#define ESCAPERADIUS 2
#define ER2 ESCAPERADIUS * ESCAPERADIUS

#define MIN(X, Y) (((X) < (Y)) ? (X) : (Y))


half4 lerpf(half4 a, half4 b, float t);
half4 HeatMapColor(float value, float minValue, float maxValue);


half4 lerpf(half4 a, half4 b, float t)
{
    return a + (b - a) * t;
}

half4 HeatMapColor(float value, float minValue, float maxValue)
{
/* ORIGINAL COLOR SCHEME
#define HEATMAP_COLORS_COUNT 6
    half4 colors[HEATMAP_COLORS_COUNT] =
    {
        half4(0.32, 0.00, 0.32, 1.00),
        half4(0.00, 0.00, 1.00, 1.00),
        half4(0.00, 1.00, 0.00, 1.00),
        half4(1.00, 1.00, 0.00, 1.00),
        half4(1.00, 0.60, 0.00, 1.00),
        half4(1.00, 0.00, 0.00, 1.00),
    };
 */

/* COLOR SCHEME TWO */
#define HEATMAP_COLORS_COUNT 5
    half4 colors[HEATMAP_COLORS_COUNT] =
    {
        half4(0.00, 0.00, 0.25, 1.00),
        half4(0.00, 0.00, 1.00, 1.00),
        half4(1.00, 1.00, 0.00, 1.00),
        half4(1.00, 0.60, 0.00, 1.00),
        half4(0.00, 0.00, 0.00, 1.00),
    };

/* COLOR SCHEME THREE
#define HEATMAP_COLORS_COUNT 3
    half4 colors[HEATMAP_COLORS_COUNT] =
    {
        half4(0.0, 0.0, 0.2, 1.0),
        half4(1.0, 1.0, 1.0, 1.0),
        half4(0.0, 0.0, 0.0, 1.0)
    };
 */

    float ratio=(HEATMAP_COLORS_COUNT-1.0)*saturate((value-minValue)/(maxValue-minValue));
    int indexMin = floor(ratio);
    
    int indexMax = MIN(indexMin+1, HEATMAP_COLORS_COUNT-1);
    
    return lerpf(colors[indexMin], colors[indexMax], ratio-indexMin);
}


struct VertexInOut
{
    float4  position [[position]];
    float4  color;
    float2  textCoord [[user(textcoord)]];
    float2  mandel;
};

//[ mandel.zoom, mandel.delta.x, mandel.delta.y, mandel.origin.x, mandel.origin.y ]
struct MandelBrot
{
    float zoom;
    float deltax;
    float deltay;
    float originx;
    float originy;
};

vertex VertexInOut passThroughVertex(uint                    vid [[ vertex_id ]],
                                     constant packed_float4* position    [[ buffer(0) ]],
                                     constant packed_float2* pTextCoords [[ buffer(1) ]])                                
{
    VertexInOut outVertex;
    
    outVertex.textCoord = pTextCoords[vid];
    outVertex.position = position[vid];
    
    return outVertex;
};

fragment half4 passThroughFragment( VertexInOut inFrag [[stage_in]],
                                    constant MandelBrot &mandel  [[buffer(0)]] )
{
    half4 color = half4(0,0,0,1);
    
    float x = (mandel.originx + inFrag.textCoord.x * (mandel.deltax ) );
    float y = (mandel.originy + inFrag.textCoord.y * (mandel.deltay ) );
    
    /* initial value of orbit = critical point Z = 0 */
    float Zx=0.0;
    float Zy=0.0;
    float Zx2=Zx*Zx;
    float Zy2=Zy*Zy;
    /* */
    int iter = 0;
    for (iter=0;iter<200 && ((Zx2+Zy2)<ER2);iter++)
    {
        Zy=2*Zx*Zy + y;
        Zx=Zx2-Zy2 + x;
        Zx2=Zx*Zx;
        Zy2=Zy*Zy;
    }
    
    if (iter < 200)
    { /* exterior of Mandelbrot set = white or gradient of colors */
        
        float zn = sqrt( Zx2 + Zy2 );
        float nu = metal::log( log(zn) / log(2.0) ) / log(2.0);
        
        // Rearranging the potential function.
        // Could remove the sqrt and multiply log(zn) by 1/2, but less clear.
        // Dividing log(zn) by log(2) instead of log(N = 1<<8)
        // because we want the entire palette to range from the
        // center to radius 2, NOT our bailout radius.
        iter = iter + 1 - nu;
    }
    
    color = HeatMapColor(iter, 0.0, 60.0);
    
    return color;
    
    return half4(inFrag.textCoord.x,inFrag.textCoord.y,0.0,1.0);
    return half4(inFrag.color);
};
