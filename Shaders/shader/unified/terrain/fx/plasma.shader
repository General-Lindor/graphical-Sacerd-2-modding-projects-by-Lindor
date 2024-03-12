//#OptDef:SPASS_AMBDIF


#include "extractvalues.shader"
#include "shadow.shader"


/////////////////////////////////////
// SPASS_AMBDIF setup
/////////////////////////////////////
#ifdef SPASS_AMBDIF
    #define VS_OUT_AMBDIFF
    #define PS_SPASS_AMBDIF_20
#endif
 
 
#ifdef VS_OUT_AMBDIFF
  struct pixdata {
    float4 hposition  : POSITION;
    float4 texcoord0  : TEXCOORD0;    //uv,glow,0
    float4 texcoord3d : TEXCOORD1;
    float4 ScreenCoordsInTexSpace  : TEXCOORD2;
    float4 texcoord_noise          : TEXCOORD3;
  }; 
  #define VS_OUT_hposition
  #define VS_OUT_ScreenCoordsInTexSpace
  #define VS_OUT_texcoords
#endif //VS_OUT_G

struct appdata
{
  float4 position    : POSITION;
  float4 normal      : NORMAL;  
  float4 binormal    : BINORMAL;  
  float4 texcoord    : TEXCOORD0;   //u,v,depth,minP
  float4 texcoord1   : TEXCOORD1;   //
};

#define SCROLL_SEGMENTS 8.0 
#define PI 3.1415926535897932384626433832795

//-------------------------------  Unified Vertex Shader -------------------------------
pixdata mainVS(appdata I,
               uniform float4x4 worldViewProjMatrix,
               uniform float4x4 invWorldMatrix,
               uniform float4x4 worldMatrix,
               uniform float4x4 worldViewMatrix,
               uniform float4x4 lightMatrix,
               uniform float4   vtx_data_array[2],
               uniform float4   light_pos,
               uniform float4   camera_pos)
{
	pixdata VSO; 
  float4 localPos = float4(I.position.xyz / I.position.w + I.texcoord.www, 1.0);
  float4 nrm4     = float4(I.normal.xyz * 2.0 - 1.0, 0.0 );
  float4 binrm4   = float4(I.binormal.xyz * 2.0 - 1.0, 0.0 );
  

  float4 texcoord   = I.texcoord / 256.0;

  float4 world_pos = mul(localPos, worldMatrix);
  float4 wvp_pos   = mul(localPos, worldViewProjMatrix);
  
	// convert camera direction vector from worldspace to objectspace
	float4 c_dir_obj = mul(camera_pos, invWorldMatrix);
	// calc direction vector from vertex position to camera-position
	c_dir_obj -= localPos;

  // calc "horizon" per-vertex
  float horizon_strength = 1.0 - abs(dot(normalize(c_dir_obj.xyz), I.normal));
  
  // vertex pos
  #ifdef VS_OUT_hposition
    VSO.hposition = wvp_pos;
  #endif
  #ifdef VS_OUT_ScreenCoordsInTexSpace
	  float rand_val   = vtx_data_array[0].w;
	  float distortion = vtx_data_array[1].x*0.05;
	  float2 rand_uv   = float2(rand_val,rand_val*4);


	  float2 screenPos = VSO.hposition.xy;
	  
	  
	  screenPos = screenPos-0.5f;
	  screenPos.x *= 1-distortion;
	  screenPos.y *= 1-distortion*0.2;
	  screenPos = screenPos+0.5f;
	  
    VSO.screenCoordsInTexSpace = calcScreenToTexCoord(VSO.hposition);
	  
	  
	  
	  VSO.texcoord_noise     = VSO.ScreenCoordsInTexSpace;
	  VSO.texcoord_noise.xy += rand_uv*VSO.ScreenCoordsInTexSpace.w;
  #endif

  #ifdef VS_OUT_texcoords
    VSO.texcoord0  = float4(texcoord.xy,horizon_strength,0); 
    VSO.texcoord3d = float4(world_pos.xyz*0.003+vtx_data_array[0].xyz,0); 
  #endif 

  return VSO; 
}

//-------------------------------  Pixel Shader AMBDIFF 20 -------------------------------
 
  
#ifdef PS_SPASS_AMBDIF_20
  fragout2 mainPS( pixdata I,
                   uniform sampler2D   texture0,
                   uniform sampler2D   texture1,
                   uniform sampler2D   texture2,
                   uniform sampler3D   textureVolume,
                   uniform float4      system_data,
                   uniform float4      param) 
  {  
	  fragout2 O;  
    float4 test = tex3D(textureVolume,I.texcoord3d); 
    test        = tex2D(texture1, test.x);
    
    
    float noise_strength = param.x;
    
	  float4 noise_col  = tex2Dproj(texture0, I.texcoord_noise);
	  float4 bg_col     = tex2Dproj(texture2, I.ScreenCoordsInTexSpace);
	  float gray_val    = (bg_col.x+bg_col.y)*0.5f;
	  
	  
	  
	  
	  gray_val        *= lerp(1,noise_col.x*2,noise_strength);
	  float4 gray_col  = float4(gray_val,gray_val,gray_val,0);
	  
	  
	  test = lerp(gray_col,test,test.a);
	  
	  float cutoff = 0.8;
	  
	  float glow = (gray_val-cutoff)/(1-cutoff);
  	
    // out
	  O.col[0] = float4(test.rgb,1);
	  O.col[1] = float4(noise_col.rgb,test.a);

	  return O; 
  }
#endif 

