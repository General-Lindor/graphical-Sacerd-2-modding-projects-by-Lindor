#ifndef S2TYPES_SHADER
#define S2TYPES_SHADER

#ifdef XENON_IMPL
  #define h2tex2D(a,b)           tex2D(a,b).rg
  #define h4tex2D(a,b)           tex2D(a,b).rgba
#endif

#ifdef ORC_USE_D24FS8
  #ifdef PS3_IMPL
    #define DEPTH_SAMPLE_RAW(a,b)  (1.f-texDepth2D(a,b))
    #define DEPTH_SAMPLE(a,b)      (1.f /( (Z_FAR/Z_NEAR-1.f)*texDepth2D(a,b)         +1.f ) )
    #define DEPTH_SAMPLE_PREC(a,b) (1.f /( (Z_FAR/Z_NEAR-1.f)*texDepth2D_precise(a,b) +1.f ) )
    #define DEPTH_SAMPLE_PROJ(a,b) (1.f /( (Z_FAR/Z_NEAR-1.f)*texDepth2Dproj(a,b)     +1.f ) )
	#define SHADOWMAP_SAMPLE(a,b)  h2tex2D(a,b)
  #else
    #define DEPTH_SAMPLE_RAW(a,b)  (1.f-tex2D(a,b))
    #define DEPTH_SAMPLE(a,b)      (1.f /( (Z_FAR/Z_NEAR-1.f)*tex2D(a,b)     +1.f ) )
    #define DEPTH_SAMPLE_PREC(a,b) (1.f /( (Z_FAR/Z_NEAR-1.f)*tex2D(a,b)     +1.f ) )
    #define DEPTH_SAMPLE_PROJ(a,b) (1.f /( (Z_FAR/Z_NEAR-1.f)*tex2Dproj(a,b) +1.f ) )
    #define SHADOWMAP_SAMPLE(a,b)  tex2D(a,b)
  #endif
#else
  #ifdef PS3_IMPL
    #define DEPTH_SAMPLE_RAW(a,b)  (texDepth2D(a,b))
    #define DEPTH_SAMPLE(a,b)      (Z_NEAR /(Z_FAR + (Z_NEAR-Z_FAR)*texDepth2D(a,b) ))
    #define DEPTH_SAMPLE_PREC(a,b) (Z_NEAR /(Z_FAR + (Z_NEAR-Z_FAR)*texDepth2D_precise(a,b) ))
    #define DEPTH_SAMPLE_PROJ(a,b) (Z_NEAR /(Z_FAR + (Z_NEAR-Z_FAR)*texDepth2Dproj(a,b) ))
	#define SHADOWMAP_SAMPLE(a,b)  h2tex2D(a,b)
  #else
    #define DEPTH_SAMPLE_RAW(a,b)  (tex2D(a,b))
    #define DEPTH_SAMPLE(a,b)      (Z_NEAR /(Z_FAR + (Z_NEAR-Z_FAR)*tex2D(a,b) ))
    #define DEPTH_SAMPLE_PREC(a,b) (Z_NEAR /(Z_FAR + (Z_NEAR-Z_FAR)*tex2D(a,b) ))
    #define DEPTH_SAMPLE_PROJ(a,b) (Z_NEAR /(Z_FAR + (Z_NEAR-Z_FAR)*tex2Dproj(a,b) ))
    #define SHADOWMAP_SAMPLE(a,b)  tex2D(a,b)
  #endif
#endif

#ifdef SM1_1
  struct fragout2 {
    float4 col[2];
  };
  struct fragout_t {
    float4 col0 : COLOR;
  };
  
  #define set_out_color(_val) O.col0 = _val;
  #define set_out_glow(_val) 

#else
 struct fragout_2 {
    float4 col0     : COLOR0;
    float4 col1     : COLOR1;
  };

  struct fragout2 {
    float4 col[2]     : COLOR;
  };
  struct fragout_t {
    float4 col0 : COLOR0;
    float4 col1 : COLOR1;
  };

  #define set_out_color(_val) O.col0 = _val;
  #define set_out_glow(_val)  O.col1 = _val;

#endif

struct fragout1 {
  float4 col      : COLOR;
};





#ifndef PS3_IMPL //somebody stop removing the halves!
#undef s2half
#undef s2half2
#undef s2half3
#undef s2half4
#undef s2half4x4
#ifdef FULL_PRECISION
  #define s2half    float
  #define s2half2   float2
  #define s2half3   float3
  #define s2half4   float4
  #define s2half4x4 float4x4
#else
  #define s2half    half
  #define s2half2   half2
  #define s2half3   half3
  #define s2half4   half4
  #define s2half4x4 half4x4
#endif
#endif

#define S2_WORLD_METER 35.0
#define S2_PI          3.141592653
#define S2_PI2         6.283185307
#define S2_SECTOR_SIZE 3200.0f

struct sPntLightInfo
{
  s2half4  vLightPos;  // Pointlight Pos
  s2half4  vLightDat;  // Radius, Intentiy, invRadius, shadowIntensity
  s2half4  vLightCol;  // Pointlight Color
};

#ifdef PS3_IMPL
uniform float4    target_data : register (c103);
#else
uniform float4    target_data;
#endif
uniform float4    viewport_data;

#ifdef XENON_IMPL
  float4    tiling_data_int_scr   : register( c248 );
  float4    tiling_data_int_tile  : register( c249 );
  float4    tiling_data_half_scr  : register( c250 );
  float4    tiling_data_half_tile : register( c251 ); 
  float4    tiling_data_deferred0 : register( c252 );
  float4    tiling_data_deferred1 : register( c253 );
  float4    tiling_data_reserved0 : register( c254 );
  float4    tiling_data_reserved1 : register( c255 );
#endif
#endif //include guard