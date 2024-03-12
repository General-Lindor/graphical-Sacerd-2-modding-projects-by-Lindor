#include "s2types.shader"

// XVERTEX
struct appdata 
{
  float3 position  : POSITION;
  float3 normal    : NORMAL;
  float3 tangent   : TANGENT;
  float3 binormal  : BINORMAL;
  float2 texcoord  : TEXCOORD0;
  float2 data      : TEXCOORD1;
};

struct pixdata
{
  float4 hposition : POSITION;
  float4 tcs       : TEXCOORD0;
  float3 params    : TEXCOORD1;
  float4 vec_OS    : TEXCOORD2;
};

struct fragout
{
  float4 color[2]  : COLOR;
};

pixdata mainVS( appdata In, 
                uniform float4x4 worldViewProjMatrix,
                uniform float4x4 invWorldMatrix,
                uniform float4 camera_pos,
                uniform float4 param )
{
  pixdata VSO;

  float3 view_OS = mul( camera_pos, invWorldMatrix ).xyz - In.position;
  VSO.vec_OS.xy  = normalize( view_OS.xy );
  VSO.vec_OS.zw  = In.normal.xy;
  float signum   = view_OS.y > 0.0 ? -1.0 : 1.0;

  float  time   = param.y;
  float4 pos    = { In.position, 1.0 };
  // stretch the cylinder
         pos.z *= param.x * 1.2;
  // find out which end is at the hilt (hack because graphics designer screwed up the weapon bones)
  float2 tcs = In.texcoord;
  // widen the cylinder
  pos.xy *= 3.5;
  // output the vertex in clip space
  VSO.hposition = mul( pos, worldViewProjMatrix );
  // texture coordinates
  VSO.tcs    = tcs.xyxy;
  VSO.tcs.x += time * 2.7 * signum;
  VSO.tcs.z += time * 2.9 * signum;
  VSO.params = float3( time, In.texcoord.y, param.z );

  return VSO;
}

fragout mainPS( pixdata In, uniform sampler2D texture0, uniform sampler1D texture1, uniform float4 param )
{
  fragout PSO;

  // make TCs flap along the edge of the weapon
  float4 tcs    = In.tcs;

  // read the textures to get the mask for the effect
  float4 col1   = tex2D( texture0, tcs.xy );
  float4 col2   = tex2D( texture0, tcs.zw );
  
  // fade towards cylinder edges
  float  theta  = pow( saturate( dot( In.vec_OS.xy, In.vec_OS.zw ) ), 5.0 );
  // fade towards hilt of weapon
         theta *= pow( sin( In.params.y * S2_PI ), 1.0 );
  // alpha value
  float  alpha  = theta * col1.x * col2.x;
  // heat intensity
  float  intensity = theta * col1.x * col2.x * 1.0;

  // texture lookup for coloring
  float3 final_color = tex1D( texture1, intensity ).rgb * alpha * 10.0;

  // final color
  PSO.color[0] = float4( final_color, 1.0f ) * In.params.z;
  PSO.color[1] = 0.0;
  return PSO;
}