#include "S2Types.shader"

//--------------------------------------------------------------------------------------
// Vertex shader globals
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
// Pixel  shader globals
//--------------------------------------------------------------------------------------

sampler2D Sampler0          : register(s0); // Shadow map texture for downsample pixel shader.

//--------------------------------------------------------------------------------------
// Name: ScreenSpaceShaderVS()
// Desc: Pass-thru shader
//--------------------------------------------------------------------------------------
struct PASSTHRU_VERTEX
{
    float4 Position   : POSITION;
    float2 TexCoords  : TEXCOORD0;
};

PASSTHRU_VERTEX mainVS( float4 vPosition : POSITION )
{
    PASSTHRU_VERTEX Output;
    Output.Position  = float4( vPosition.x, vPosition.y, 1.0f, 1.0f );
    Output.TexCoords = (float2( vPosition.x, vPosition.y ) + 1.0f) * 0.5f;
    Output.TexCoords.y = 1-Output.TexCoords.y;
    return Output;
}

//--------------------------------------------------------------------------------------
// Name: 5TapMaxPS()
// Desc: Copy depth to variance and perform the 3x3 Gaussian blur

//--------------------------------------------------------------------------------------
struct fragout {
	float4 col     : COLOR;
};


fragout mainPS( in float2 vTexCoord : TEXCOORD0 )
{
    fragout ret;

    // 5-tap max blur
    float4 DepthSamples0;
    float4 DepthSamples;
    asm
    {
        tfetch2D DepthSamples0.w___, vTexCoord, Sampler0, OffsetX =  0, OffsetY = -1, MinFilter=point, MagFilter=point
        tfetch2D DepthSamples0._w__, vTexCoord, Sampler0, OffsetX = -1, OffsetY =  0, MinFilter=point, MagFilter=point
        tfetch2D DepthSamples,       vTexCoord, Sampler0, OffsetX =  0, OffsetY =  0, MinFilter=point, MagFilter=point
        tfetch2D DepthSamples0.__w_, vTexCoord, Sampler0, OffsetX =  1, OffsetY =  0, MinFilter=point, MagFilter=point
        tfetch2D DepthSamples0.___w, vTexCoord, Sampler0, OffsetX =  0, OffsetY =  1, MinFilter=point, MagFilter=point
    };

    float4 _maxA = DepthSamples0;
    _maxA.xy = max( _maxA.xy, _maxA.zw );
    _maxA.x  = max( _maxA.x,  _maxA.y );
    _maxA.x  = max( _maxA.x,  DepthSamples.a );
        
    ret.col  = float4( 0, 0, 0, _maxA.x );
    return ret;
}