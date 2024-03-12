//#OptDef:SPASS_G
//#OptDef:SPASS_FX

#include "extractvalues.shader"
#include "shadow.shader"

#ifdef SPASS_G
    #define VS_OUT_G
    #define PS_SPASS_G
#endif
#ifdef SPASS_FX
    #define VS_OUT_HAZE
    #define PS_SPASS_HAZE_20
#endif
 
#ifdef VS_OUT_G
  struct pixdata {
    float4 hposition  : POSITION;
    float4 texcoord0  : TEXCOORD0;    //scrollpos,height,0,0
    float4 texcoord1  : TEXCOORD1;    //uv,glow,0
    float4 texcoord2  : TEXCOORD2;    //uvw1 volume texture,0
    float4 texcoord3  : TEXCOORD3;    //height^2,height^4,depthfact,segmentindex
  };
  #define VS_OUT_hposition
  #define VS_OUT_texcoords
#endif //VS_OUT_G

#ifdef VS_OUT_HAZE
  struct pixdata {
    float4 hposition  : POSITION;
    float4 NoiseUV                 : TEXCOORD1;
    float4 HazeParam               : TEXCOORD3; 
  };
  #define VS_OUT_hposition
  #define VS_OUT_HazeParam
  #define VS_OUT_NoiseUV
  #define VS_OUT_HALFPIPE
#endif //VS_OUT_HAZE

struct appdata
{
  float4 position     : POSITION;
  float4 norm_binorm  : TEXCOORD0;
  float4 texcoord     : TEXCOORD1;
  float4 texcoord1    : TEXCOORD2;
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
               uniform float4   param,
               uniform float4   light_pos,
               uniform float4   camera_pos,
               uniform float4   zfrustum_data
#ifdef XENON_IMPL
             , uniform float4   viewport_data
#endif                 
               )
{
	pixdata VSO; 
  float4 localPos = float4( I.position.xyz, 1.0 );
  float4 nrm4 = { I.norm_binorm.xy * 2.0 - 1.0, 0.0, 0.0 };
  nrm4.z      = sqrt( 1.0 - dot( nrm4.xy, nrm4.xy ) );
  float4 binrm4 = { I.norm_binorm.zw * 2.0 - 1.0, 0.0, 0.0 };
  binrm4.z      = sqrt( 1.0 - dot( binrm4.xy, binrm4.xy ) );

  float width       = I.texcoord.w/256.0f;
  float border      = saturate(I.position.w * 10 / 256.0);

  nrm4   = normalize(nrm4);
  binrm4 = normalize(binrm4);
   
  float4 texcoord   = I.texcoord / 256.0;
  
  float height      = I.texcoord.z*1.0f/100.0f;
  height            = lerp(1,height,param.z);
  float acc         = 1.0-abs(width);
  float scrollpos   = param.x;
  float haze_pos    = param.y;
  float haze_uv_scale = param.w;


#ifdef VS_OUT_HALFPIPE
    float4 wpos      = mul(localPos, worldMatrix);
    float dist       = distance(wpos,camera_pos);
    float dist_scale = dist*0.2f;
    float ang        = width*PI/2;
    
    float heightFact   = cos(ang);

    float4 part_nrm    = nrm4*heightFact;
    float4 part_binrm  = binrm4*sin(ang);
    localPos          += part_nrm*dist_scale;
    nrm4               = part_nrm-part_binrm;
#else
    localPos.xyz -= nrm4.xyz*height*0.25; 
#endif

  

  float4 wvp_pos = mul(localPos, worldViewProjMatrix);
  float4 w_pos   = mul(localPos, worldMatrix);
  // vertex pos
  #ifdef VS_OUT_hposition
    VSO.hposition = wvp_pos;
  #endif

  float camSpaceZ = localPos.x*worldViewMatrix[0][2] +  
                    localPos.y*worldViewMatrix[1][2] + 
                    localPos.z*worldViewMatrix[2][2] + 
                    worldViewMatrix[3][2];



  #ifdef VS_OUT_texcoords


	  float depthscale   = height*height;
	  float depthfact    = min(depthscale*4,1);
	  float noisefact    = depthscale*depthscale*0.5f;
	  float segmentindex = acc*SCROLL_SEGMENTS;

    VSO.texcoord0 = float4(scrollpos,segmentindex,0,0); 
    VSO.texcoord1 = float4(texcoord.xyxy); 
    VSO.texcoord1.w *= 0.9f;
    VSO.texcoord1.w +=scrollpos*0.25;


    VSO.texcoord2 = float4(texcoord.xy,scrollpos,0);
    VSO.texcoord2.y += scrollpos;
    
    VSO.texcoord3 = float4(depthscale,
                           depthfact,
                           noisefact,
                           height);

  #endif
  #ifdef VS_OUT_depthUV
    VSO.depthUV = float4(0,0,0,-camSpaceZ*zfrustum_data.w);
  #endif

  #ifdef VS_OUT_HazeParam
    float4 ws_nrm4   = mul(nrm4.xyz, worldViewMatrix);
    float haze_range = 1/(target_data.w*128);
	  VSO.HazeParam    = float4(ws_nrm4.z,
	                            haze_range*acc,
	                            0,
	                            0);
  #endif
  #ifdef VS_OUT_NoiseUV
	  VSO.NoiseUV    = float4(w_pos.xyz,0)*haze_uv_scale;
	  VSO.NoiseUV.z += haze_pos; 
  #endif

  #ifdef VS_OUT_DepthDist
	  VSO.DepthDist.x = (VSO.hposition.w - Z_NEAR) / (Z_FAR - Z_NEAR);
	  VSO.DepthDist.y = 0;
  #endif


  return VSO; 
}

  
#ifdef PS_SPASS_G
  struct fragout
  {
    float4 col0  : COLOR0;
    float4 col1  : COLOR1;
    float4 col2  : COLOR2;
  };
  fragout mainPS( pixdata In,
                  uniform sampler2D   texture0,
                  uniform sampler2D   texture1,
                  uniform sampler3D   textureVolume,
                  uniform float4      system_data,
                  uniform float4      light_col_amb,
                  uniform float4      param,
                  uniform float4      light_data)
  { 
	  fragout O;  
  	 
	  float4 glow_col    = light_data;

	  float scrollpos    = In.texcoord0.x;
	  float segmentindex = In.texcoord0.y;

	  float depthscale   = In.texcoord3.x;
	  float depthfact    = In.texcoord3.y;
	  float noisefact    = In.texcoord3.z;
	  float height       = In.texcoord3.w;
//	  depthfact = depthscale;
	  float lava_clamp_liquid = param.y; 
	  float lava_clamp_stone  = param.x;
	  float plate_glow        = param.z;

  	 
    float4 noise       = tex3D(textureVolume,In.texcoord2)*noisefact;

    float scroll_fact  = segmentindex;
    float scroll_blend = frac(scroll_fact);
    float scroll_1     = ceil(scroll_fact);
    scroll_1          /= SCROLL_SEGMENTS;
    float scroll_2     = scroll_1+1.0f/SCROLL_SEGMENTS;
    

    
    float4 tex0 = In.texcoord1;
    float4 tex1 = In.texcoord1;
    tex0.y  += scroll_1*scrollpos; 
    tex1.y  += scroll_2*scrollpos;

    scroll_blend = pow(scroll_blend,3);
    
	  float4 stream_1 = tex2D(texture0, tex0.xy);
	  float4 stream_2 = tex2D(texture0, tex1.xy);
	  float4 stream_3 = tex2D(texture0, In.texcoord1.zw);
	  stream_1 = lerp(stream_1,stream_2,scroll_blend);

  	
    float lava_mask     = stream_1.w*stream_3.w;
    float fact_lava_hot = lava_mask*depthfact;

    float glow          = fact_lava_hot*fact_lava_hot;
    if(fact_lava_hot < lava_clamp_stone)
    {
      depthscale = min(depthscale,plate_glow);
    }
    if(fact_lava_hot < lava_clamp_liquid)
    {
      fact_lava_hot = 0;
    }

	  float4 liquid  = tex2D(texture1, In.texcoord2.xy+noise.xy); 
	  
	  stream_1 += glow_col * depthscale;
	  liquid   += glow_col * depthscale;

    float4 color_mul = lerp(light_col_amb,float4(1,1,1,1),depthfact);
    
    float4 color_out  = color_mul*stream_1*(1-fact_lava_hot)+liquid*fact_lava_hot;
    float4 color_glow = float4(color_out.xyz*glow,1);
    
    O.col0 = color_out;
    O.col1 = float4( 0.5, 0.5, 1, 0 );
    O.col2 = 0*float4( 0, 0, 0, glow );
	  return O; 
  }
#endif 

// decode depth from 2-channel-encoded-depthbuffer
float getDepth(float2 encoded)
{
  return dot(encoded, float2(1.0, 1.0 / 256.0));
}

#ifdef PS_SPASS_HAZE_20
  fragout_t mainPS(pixdata   I,
                   float2    vPos           : VPOS,
           uniform sampler2D texture0,
           uniform sampler2D texture1,
           uniform sampler2D texture2,
           uniform sampler2D texture3,
           uniform sampler3D textureVolume,
           uniform float4    param,
           uniform float4    light_data)
  { 
	  fragout_t PSO;  
  	 
    //calc intensity of refraction
    float ref_intensity = I.HazeParam.x; 
    float haze_scale    = I.HazeParam.y; 
    ref_intensity      *= ref_intensity;
 
  	float4 distortion = tex3D(textureVolume,I.NoiseUV.xyz);
    ref_intensity    *= distortion.w;

    distortion        = distortion*2-1.0;
	distortion       *= ref_intensity;
	distortion.zw     = 0; 
	distortion       *= haze_scale;

    // screenpos of this pixel, zw is refracted
#ifdef XENON_IMPL    
      float4 scr_pos = float4( tiling_data_half_tile.zw*vPos.xy,
                               tiling_data_half_tile.zw*vPos.xy );
#else
      float4 scr_pos = float4( target_data.zw*vPos.xy,
                               target_data.zw*vPos.xy );
#endif 
	                         
//    float4 refractionMask = tex2D(texture2, scr_pos.zw);
//    scr_pos.zw            = scr_pos.xy + distortion*refractionMask.r;
    float4 refractionMap  = tex2D(texture0, scr_pos.zw);
  	  
    PSO.col0 = float4(refractionMap.xyz,1);
    PSO.col1 = float4(0,0,0,0);
    return PSO; 
    }
#endif 
