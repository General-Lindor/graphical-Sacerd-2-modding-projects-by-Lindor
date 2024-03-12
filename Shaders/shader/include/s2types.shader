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

  #ifdef LOWEND_PIPELINE
    #ifdef SM3_0
      #undef SM3_0
      #define SM2_0
    #endif
  #endif


#endif

struct fragout1 {
  float4 col      : COLOR;
};





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

#define S2_WORLD_METER 35.0
#define S2_PI          3.141592653
#define S2_PI2         6.283185307
#define S2_SECTOR_SIZE 3200.0f


uniform float4 target_data;
uniform float4 viewport_data;
uniform float4 shadow_settings;