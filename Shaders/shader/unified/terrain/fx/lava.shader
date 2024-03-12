//#OptDef:SPASS_G
//#OptDef:SPASS_AMBDIF
//#OptDef:SPASS_FX
//#OptDef:SPASS_MASK
//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:TREE_HOLE
//#OptDef:S2_FOG


#include "extractvalues.shader"
#include "shadow.shader"


/////////////////////////////////////
// SPASS_AMBDIF setup
/////////////////////////////////////
#ifdef SPASS_AMBDIF
    #define VS_OUT_AMBDIFF
    #define PS_SPASS_AMBDIF_20
#endif
#ifdef SPASS_G
    #define VS_OUT_G
    #define PS_SPASS_G
#endif
#ifdef SPASS_FX
    #define VS_OUT_HAZE
    #define PS_SPASS_HAZE_20
#endif
#ifdef SPASS_MASK
    #define VS_OUT_MASK
    #define PS_SPASS_MASK_20
#endif
 
#ifdef TREE_HOLE
  #define NEW_LAVA
#endif

 
#ifdef VS_OUT_AMBDIFF
  struct pixdata {
    float4 hposition  : POSITION;
    float4 texcoord0  : TEXCOORD0;    //scrollpos,height,0,0
    float4 texcoord1  : TEXCOORD1;    //uv,glow,0
    float4 texcoord2  : TEXCOORD2;    //uvw1 volume texture,0
    float4 texcoord3  : TEXCOORD3;    //height^2,height^4,depthfact,segmentindex
#ifdef S2_FOG
    float2 depthFog   : TEXCOORD4;
#endif
  }; 
  #define VS_OUT_hposition
  #define VS_OUT_texcoords
#ifdef S2_FOG
  #define VS_OUT_depthFog
#endif
#endif //VS_OUT_G

#ifdef VS_OUT_G
  struct pixdata {
    float4 hposition  : POSITION;
    float4 depthUV    : TEXCOORD0;
  };
  #define VS_OUT_hposition
  #define VS_OUT_depthUV
#endif //VS_OUT_G

#ifdef VS_OUT_HAZE
  struct pixdata {
    float4 hposition  : POSITION;
    float4 ScreenCoordsInTexSpace  : TEXCOORD0;
    float4 NoiseUV                 : TEXCOORD1;
    float4 HazeParam               : TEXCOORD3; 
  };
  #define VS_OUT_hposition
  #define VS_OUT_ScreenCoordsInTexSpace
  #define VS_OUT_HazeParam
  #define VS_OUT_NoiseUV
  #define VS_OUT_HALFPIPE
#endif //VS_OUT_G

#ifdef VS_OUT_MASK
  struct pixdata {
    float4 hposition  : POSITION;
  };
  #define VS_OUT_hposition
  #define VS_OUT_HALFPIPE
#endif //VS_OUT_G

#ifdef NEW_LAVA
  struct appdata
  {
    float4 position     : POSITION;
    float4 norm_binorm  : TEXCOORD0;
    float4 texcoord     : TEXCOORD1;
    float4 texcoord1    : TEXCOORD2;
  };
#else
  struct appdata
  {
    float4 position    : POSITION;
    float4 normal      : NORMAL;  
    float4 binormal    : BINORMAL;  
    float4 texcoord    : TEXCOORD0;   //u,v,depth,minP
    float4 texcoord1   : TEXCOORD1;   //
  };
#endif
    #define VS_FADE_PARAMETERS        5
    #define VS_NUMOF                  6


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
               uniform float4   fog_data,
               uniform float4   vtx_data_array[1],
               uniform float4   zfrustum_data)
{
	pixdata VSO; 
#ifdef NEW_LAVA
  float4 localPos = float4( I.position.xyz, 1.0 );
  float4 nrm4 = { I.norm_binorm.xy * 2.0 - 1.0, 0.0, 0.0 };
  nrm4.z      = sqrt( 1.0 - dot( nrm4.xy, nrm4.xy ) );
  float4 binrm4 = { I.norm_binorm.zw * 2.0 - 1.0, 0.0, 0.0 };
  binrm4.z      = sqrt( 1.0 - dot( binrm4.xy, binrm4.xy ) );

  float width       = I.texcoord.w/256.0f;
  float border      = saturate(I.position.w * 10 / 256.0);
#else
  float4 localPos = float4(I.position.xyz / I.position.w + I.texcoord.www, 1.0);
  float4 nrm4     = float4(I.normal.xyz * 2.0 - 1.0, 0.0 );
  float4 binrm4   = float4(I.binormal.xyz * 2.0 - 1.0, 0.0 );
  float width     = I.texcoord.w/256.0;
  float border    = saturate(I.position.w * 10 / 256.0);
#endif

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
    VSO.texcoord1.w +=scrollpos*0.25;


    VSO.texcoord2 = float4(texcoord.xy,scrollpos,0);
    VSO.texcoord2.y += scrollpos;
    

    float4 vals = I.texcoord1 / 256.0;
    float4 fade_values = vtx_data_array[0];
    float trans = dot( vals.xz, fade_values.xy );
    VSO.texcoord2.w = trans;

    VSO.texcoord3 = float4(depthscale,
                           depthfact,
                           noisefact,
                           height);

  #endif
  #ifdef VS_OUT_depthUV
    VSO.depthUV = float4(0,0,0,-camSpaceZ*zfrustum_data.w);
  #endif

  #ifdef VS_OUT_ScreenCoordsInTexSpace
    VSO.ScreenCoordsInTexSpace = calcScreenToTexCoord(VSO.hposition);
  #endif
  #ifdef VS_OUT_HazeParam
    float4 ws_nrm4   = mul(nrm4.xyz, worldViewMatrix);
    float haze_range = 2/(target_data.w*128);
	  VSO.HazeParam    = float4(ws_nrm4.z,
	                            haze_range*acc,
	                            0,
	                            0);
  #endif
  #ifdef VS_OUT_NoiseUV
	  VSO.NoiseUV    = float4(w_pos.xyz,0)*haze_uv_scale;
	  VSO.NoiseUV.z += haze_pos; 
  #endif

#ifdef VS_OUT_depthFog
    VSO.depthFog = getFogTCs( VSO.hposition.w, fog_data );
#endif

  return VSO; 
}

//-------------------------------  Pixel Shader AMBDIFF 20 -------------------------------
 
  
#ifdef PS_SPASS_AMBDIF_20
  fragout_t mainPS( pixdata In,
                   uniform sampler2D   texture0,
                   uniform sampler2D   texture1,
                   uniform sampler3D   textureVolume,
                   uniform float4      system_data,
                   uniform float4      light_col_amb,
                   uniform float4      light_col_diff,
                   uniform float4      param,
                   uniform float4      light_data,
                   uniform float4      fog_color,
                   uniform sampler2D   fog_texture )
  { 
	  fragout_t O;  
  	 
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
    
#ifdef S2_FOG
    // fog (we only fade diffuse, not glow - this is important for the specific look of the lava)
    fogDiffuse( color_out.xyz, fog_texture, In.depthFog, light_col_diff );
#endif

    float trans  = In.texcoord2.w;
    color_out.a  = trans;
    color_glow.a = trans;
    set_out_color(color_out);
    set_out_glow(color_glow);
	  return O; 
  }
#endif 

#ifdef PS_SPASS_G
  fragout1 mainPS(pixdata I,
                  uniform sampler2D gradient_texture)

  { 
	  fragout1 O;  
  	O.col        = float4(I.depthUV.w,0,0,1);
    return O;
  }
#endif 
#ifdef PS_SPASS_MASK_20
  fragout2 mainPS(pixdata I,
                  uniform sampler2D gradient_texture)

  { 
	  fragout_t PSO;  
    PSO.col0 = float4(1,0,0,1);
    PSO.col1 = float4(0,0,0,0);
	  return PSO; 
  }
#endif 

 // decode depth from 2-channel-encoded-depthbuffer
float getDepth(float2 encoded)
{
  return dot(encoded, float2(1.0, 1.0 / 256.0));
}

#ifdef PS_SPASS_HAZE_20
  fragout2 mainPS(pixdata I,
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

	  float4 refractionCoord  = I.ScreenCoordsInTexSpace+distortion;
	  float4 refractionMask   = tex2Dproj(texture2, refractionCoord);
	  refractionCoord         = I.ScreenCoordsInTexSpace+distortion*refractionMask.r;
	  // get refraction color
	  float4 refractionMap    = tex2Dproj(texture0, refractionCoord);
	  
    PSO.col0 = float4(refractionMap.xyz,1);
    PSO.col1 = float4(0,0,0,0);
    return PSO; 
    }
#endif 
