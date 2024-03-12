#ifndef EXTRACTVALUES_H
#define EXTRACTVALUES_H

#include "s2types.shader"
#include "gamma_correct.shader"
#include "BrdfLighting.shader"

#define CALC_DEFERRED_FOG



#ifdef VS_IN_TREEVERTEX
  #define VERT_TREEVERTEX
#endif
#ifdef VS_IN_TREELEAFVERTEX
  #define VERT_TREELEAFVERTEX
#endif
#ifdef VS_IN_MINIVERTEX
  #define VERT_MINIOBJVERTEX
#endif
#ifdef VS_IN_INSTANCED_MINIVERTEX
  #define VERT_INSTANCED_MINIOBJVERTEX
#endif

#ifdef PS3_IMPL
#define UB4toD3DCOLOR(a) (a.yzwx)
#else
#define UB4toD3DCOLOR(a) a
#endif

#define MAX_LIGHT_BLOCKS 4
#define LIGHT_BLK_VECTOR_CNT 10

#define VS_PARAM_BLOCK   uniform float4x4  worldViewProjMatrix, \
	                       uniform float4x4  invWorldMatrix, \
                         uniform float4x4  worldMatrix, \
                         uniform float4x4  worldViewMatrix, \
	                       uniform float4    light_pos , \
	                       uniform float4    param, \
	                       uniform float4    camera_pos, \
                         uniform float4x4  lightMatrix, \
                         uniform float4    zfrustum_data, \
                         uniform float4    vtx_data2_array[4], \
                         uniform float4    fog_data, \
                         uniform float4    vtx_lightBlocks[MAX_LIGHT_BLOCKS*LIGHT_BLK_VECTOR_CNT], \
                         uniform float4    weather_pos
#define PS_PARAM_BLOCK   float2              vPos : VPOS, \
                         uniform sampler2D   texture0, \
                         uniform sampler2D   texture1, \
                         uniform sampler2D   texture2, \
                         uniform sampler2D   texture3, \
                         uniform sampler2D   texture4, \
                         uniform sampler2D   texture5, \
                         uniform sampler2D   texture6, \
                         uniform sampler2D   texture7, \
                         uniform sampler2D   texture8, \
                         uniform sampler2D   texture9, \
                         uniform sampler2D   texture10, \
                         uniform sampler2D   texture11, \
                         uniform sampler2D   texture12, \
                         uniform sampler2D   texture13, \
                         uniform sampler2D   shadow_map, \
                         uniform sampler3D   textureVolume, \
                         uniform sampler2D   colvar_mask  , \
                         uniform int         anzIterations, \
                         uniform float4      shadow_data, \
                         uniform sampler2D   gradient_texture, \
                         uniform float4      light_col_diff, \
                         uniform float4      light_col_amb, \
                         uniform sampler2D   shadow_texture, \
                         uniform float4      light_data, \
                         uniform samplerCUBE textureCube, \
                         uniform float4      fog_color, \
                         uniform float4      pix_color_ramp[8], \
                         uniform sampler2D   fog_texture


// --------------------------------------------------------------------------------------------------------
// XVertex
// --------------------------------------------------------------------------------------------------------
#ifdef VERT_XVERTEX

#define DEFINE_VERTEX_DATA struct appdata {\
	float3 position    : POSITION;\
	float3 normal      : NORMAL;\
	float3 tangent     : TANGENT;\
	float3 binormal    : BINORMAL;\
	float2 texcoord    : TEXCOORD0;\
	float2 data        : TEXCOORD1;\
};

#define EXTRACT_VERTEX_VALUES 	float4 pos4 = float4(I.position, 1.0);\
	float4 nrm4 = float4(I.normal, 0.0);\
	float3 tan3 = I.tangent;\
	float3 bin3 = I.binormal;\
	float4 uv0 = I.texcoord.xyyy;\
	float2 data2 = I.data;

#endif // VERT_XVERTEX



// --------------------------------------------------------------------------------------------------------
// SpeedTree branch/frond vertices
// --------------------------------------------------------------------------------------------------------
#ifdef VERT_TREEVERTEX

#define DEFINE_VERTEX_DATA struct appdata {\
	float4 position    : POSITION;\
	float4 normal      : TEXCOORD0;\
	float4 tangent     : TEXCOORD1;\
	float4 binormal    : TEXCOORD2;\
	float2 texcoord    : TEXCOORD3;\
};


#define EXTRACT_VERTEX_VALUES float4 pos4 = float4(I.position.xyz / I.position.w, 1.0);\
	float4 nrm4 = float4(UB4toD3DCOLOR(I.normal).xyz * 2.0 - 1.0, 0.0);\
	float3 tan3 = float3(UB4toD3DCOLOR(I.tangent).xyz * 2.0 - 1.0);\
	float3 bin3 = float3(UB4toD3DCOLOR(I.binormal).xyz * 2.0 - 1.0);\
	float4 uv0 = I.texcoord.xyyy / 2048.0;\
    float2 data2 = float2(UB4toD3DCOLOR(I.normal).w * 255.1f, UB4toD3DCOLOR(I.tangent).w);\
    float  windidx = data2.x;\
	float4 windLerpFact = data2.yyyy;
  


#endif // VERT_TREEVERTEX



// --------------------------------------------------------------------------------------------------------
// SpeedTree leaf vertices
// --------------------------------------------------------------------------------------------------------
#ifdef VERT_TREELEAFVERTEX

#define DEFINE_VERTEX_DATA struct appdata {\
	float4 position    : POSITION;\
	float4 normal      : TEXCOORD0;\
	float4 binormal    : TEXCOORD1;\
	float4 texcoord    : TEXCOORD2;\
};


#define EXTRACT_VERTEX_VALUES 	float4 pos4 = float4(I.position.xyz / I.position.w, 1.0);\
	float4 nrm4 = float4(UB4toD3DCOLOR(I.normal).xyz * 2.0 - 1.0, 0.0);\
	float2 bin2 = float2(UB4toD3DCOLOR(I.binormal).x * 255.1f, UB4toD3DCOLOR(I.binormal).y * 2.0 - 1.0);\
	float4 uv0 = UB4toD3DCOLOR(I.texcoord).xyyy * 2.0 - 1.0;\
	float2 data2 = float2(UB4toD3DCOLOR(I.texcoord).z * 255.1f, UB4toD3DCOLOR(I.texcoord).w);\
	float dim = UB4toD3DCOLOR(I.normal).w;\
  float  windidx = bin2.x;\
	float4 windLerpFact = bin2.yyyy;

#endif // VERT_TREELEAFVERTEX



// --------------------------------------------------------------------------------------------------------
// Miniobj vertices
// --------------------------------------------------------------------------------------------------------
#ifdef VERT_MINIOBJVERTEX

#define DEFINE_VERTEX_DATA struct appdata {\
	float4 position    : POSITION;\
	float4 normal      : NORMAL;\
	float4 center      : TEXCOORD0;\
	float2 ww_hs       : TEXCOORD1;  /*windweight,heightscale,0,0*/  \
	float2 texcoord    : TEXCOORD2;  /*u,v*/  \
};

#define EXTRACT_VERTEX_VALUES float4 vertex_pos = float4(I.position.xyz / I.position.w + I.center.www, 1.0);\
	float3 ground_normal = float3(UB4toD3DCOLOR(I.normal).xyz * 2.0 - 1.0);\
	float3 flower_center = I.center.xyz / I.position.w + I.center.www;\
	float2 bin = I.ww_hs.xy / 100;\
	float4 uv0 = I.texcoord.xyyy / 2048.0;\
	float wind_group  = UB4toD3DCOLOR(I.normal).w * 255.1f;\
	float wind_weight = bin.x;\
	float height_scale = bin.y;
	

#endif // VERT_TREELEAFVERTEX

#ifdef VS_IN_INSTANCED_MINIVERTEX

#ifdef XENON_IMPL

#define DEFINE_VERTEX_DATA struct appdata {\
	float3 position    : POSITION;\
	float2 texcoord0   : TEXCOORD0;\
	float1 flowerIndex : TEXCOORD1;\
};\
struct SInstanceData {\
	float4 texcoord1   : TEXCOORD1;\
	float4 texcoord2   : TEXCOORD2;\
	float4 texcoord3   : TEXCOORD3;\
};

#define EXTRACT_VERTEX_VALUES  	SInstanceData J = TFetchInstanceData(instanceData,I.flowerIndex,param.y);\
  float3 flower_center = J.texcoord1.xyz; \
  float flower_scale   = J.texcoord1.w; \
  float3 ground_normal = J.texcoord2.xyz; \
  float flower_rot     = J.texcoord2.w; \
  float wind_group     = J.texcoord3.x; \
  float height_scale   = J.texcoord3.y; \
  float u_offset       = J.texcoord3.z; \
  float4 vertex_pos    = float4(I.position.x * cos(flower_rot) + I.position.y * sin(flower_rot), I.position.x * sin(flower_rot) - I.position.y * cos(flower_rot), I.position.z,1); \
  vertex_pos.xyz      *= flower_scale; \
  float wind_weight    = vertex_pos.z; \
  vertex_pos.z        *= height_scale; \
  float4 uv0           = float4(I.texcoord0.xy * float2(param.zw) + float2(u_offset, 0.0),0,0); 

#else

#define DEFINE_VERTEX_DATA struct appdata {\
	float3 position    : POSITION; \
	float2 texcoord0   : TEXCOORD0; \
	float4 texcoord1   : TEXCOORD1; \
	float4 texcoord2   : TEXCOORD2; \
	float3 texcoord3   : TEXCOORD3; \
};

#define EXTRACT_VERTEX_VALUES  float3 flower_center = I.texcoord1.xyz; \
  float flower_scale   = I.texcoord1.w; \
  float3 ground_normal = I.texcoord2.xyz; \
  float flower_rot     = I.texcoord2.w; \
  float wind_group     = I.texcoord3.x; \
  float height_scale   = I.texcoord3.y; \
  float u_offset       = I.texcoord3.z; \
  float4 vertex_pos    = float4(I.position.x * cos(flower_rot) + I.position.y * sin(flower_rot), I.position.x * sin(flower_rot) - I.position.y * cos(flower_rot), I.position.z,1); \
  vertex_pos.xyz      *= flower_scale; \
  float wind_weight    = vertex_pos.z; \
  vertex_pos.z        *= height_scale; \
  float4 uv0           = float4(I.texcoord0.xy * float2(param.xy) + float2(u_offset, 0.0),0,0); 

#endif

#endif // VERT_TREELEAFVERTEX


// --------------------------------------------------------------------------------------------------------
// Diffuse and specular light calculation stuff
// --------------------------------------------------------------------------------------------------------
#define MAX_NUM_POINTLIGHTS 5 // if this is changed, then MAX_NUM_LOWEND_ACTIVE_LIGHTS in lighting.h must be changed as well

struct lightData
{
	float3 myAmbientColor;
	
	float4 myLightPosition[MAX_NUM_POINTLIGHTS];
	float3 myLightDiffuseColor[MAX_NUM_POINTLIGHTS];
};


float4 calcLight(float3 aVertexPosition, float3 aVertexNormal, float3 aCameraPosition, lightData someLightData, out float4 aReturnSpecularColor)
{
	float3 diffColor = someLightData.myAmbientColor;
	float3 specColor = float3(0.0f, 0.0f, 0.0f);

#ifdef MINIMAPMODE
  float3 viewDir = normalize(aCameraPosition);
#else
	float3 viewDir = normalize(aCameraPosition - aVertexPosition);
#endif

	/*[unroll]*/ for(int i = 0; i < MAX_NUM_POINTLIGHTS; i++)
	{
		float3 lightDir = someLightData.myLightPosition[i].xyz - aVertexPosition;
		float lightDistance = length(lightDir);
		lightDir /= lightDistance;

		float lightAttenuationFactor = saturate(1.0f - lightDistance * someLightData.myLightPosition[i].w);

		//float3 halfVec = normalize(viewDir + lightDir);
		//float4 li = lit(dot(aVertexNormal, lightDir), dot(aVertexNormal, halfVec), 20.0f);
		//diffColor += li.y * lightAttenuationFactor * someLightData.myLightDiffuseColor[i];
		//specColor += li.z * lightAttenuationFactor * someLightData.myLightDiffuseColor[i];

		diffColor += saturate(dot(aVertexNormal, lightDir)) * lightAttenuationFactor * someLightData.myLightDiffuseColor[i];
		//specColor += pow(saturate(dot(aVertexNormal, halfVec)), 20) * lightAttenuationFactor * someLightData.myLightDiffuseColor[i];
		
		/*if(i == 0)
		{
			float3 halfVec = normalize(viewDir + lightDir);
			specColor += pow(saturate(dot(aVertexNormal, halfVec)), 20) * lightAttenuationFactor * someLightData.myLightDiffuseColor[i];
		}*/
	}

	aReturnSpecularColor.xyz = specColor * 0.8f;
	aReturnSpecularColor.w = 0.0f;

	return float4(diffColor, 0.0f);
}


float4 calcDiffuseLight(float3 aVertexPosition, float3 aVertexNormal, lightData someLightData)
{
	float3 diffColor = float3(0.0f, 0.0f, 0.0f);

	/*[unroll]*/ for(int i = 0; i < MAX_NUM_POINTLIGHTS; i++)
	{
		float3 lightDir = someLightData.myLightPosition[i].xyz - aVertexPosition;
		float lightDistance = length(lightDir);
		lightDir /= lightDistance;

		float lightAttenuationFactor = saturate(1.0f - lightDistance * someLightData.myLightPosition[i].w);

		diffColor += saturate(dot(aVertexNormal, lightDir)) * lightAttenuationFactor * someLightData.myLightDiffuseColor[i];
	}

	return float4(someLightData.myAmbientColor + diffColor, 0.0f);
}



float4 calcDiffuseLightShadowed(float3 aVertexPosition, float3 aVertexNormal, lightData someLightData, out float4 aReturnShadowedLightColor, out float3 aReturnShadowedLightPosition)
{
	float3 diffColor = float3(0.0f, 0.0f, 0.0f);

	float3 lightDir = someLightData.myLightPosition[0].xyz - aVertexPosition;
	float lightDistance = length(lightDir);
	lightDir /= lightDistance;
	float lightAttenuationFactor = saturate(1.0f - lightDistance * someLightData.myLightPosition[0].w);
	aReturnShadowedLightColor = float4(saturate(dot(aVertexNormal, lightDir)) * lightAttenuationFactor * someLightData.myLightDiffuseColor[0], 0.0f);
	aReturnShadowedLightPosition = (aVertexPosition - someLightData.myLightPosition[0].xyz);

	/*[unroll]*/ for(int i = 1; i < MAX_NUM_POINTLIGHTS; i++)
	{
		float3 lightDir = someLightData.myLightPosition[i].xyz - aVertexPosition;
		float lightDistance = length(lightDir);
		lightDir /= lightDistance;

		float lightAttenuationFactor = saturate(1.0f - lightDistance * someLightData.myLightPosition[i].w);

		diffColor += saturate(dot(aVertexNormal, lightDir)) * lightAttenuationFactor * someLightData.myLightDiffuseColor[i];
	}

	return float4(someLightData.myAmbientColor + diffColor, 0.0f);
}


float calcFog(float4 aVertexPosition, float4 someFogData)
{
	return 1.0f - saturate(aVertexPosition.w * someFogData.x + someFogData.y);
}

s2half4 decode_normal(s2half4 value)
{
  #ifdef NORMALFORMAT_565
    value.xy = (value.xy-0.5)*2;
    value.z  = sqrt( 1.0 - dot( value.xy, value.xy ) );
  #elif NORMALFORMAT_88
    value.z  = sqrt( 1.0 - dot( value.xy, value.xy ) );
  #elif NORMALFORMAT_DXN
    #ifdef PS3_IMPL
      value.xy = (value.ag - 0.5)*2;
    #else
      value.xy = (value.xy - 0.5)*2;
    #endif
    value.z = sqrt( 1.0f - dot(value.xy,value.xy) )/2.f;
    value   = normalize(value);
  #else
    value   = (value-0.5)*2;
  #endif
  return s2half4(value.xyz,0);
}


float4 calcItemPreviewColor(float3 tan_to_view0,float3 tan_to_view1,float3 tan_to_view2,
                            float4 tex0,float4 tex1,float4 texNormal)
{
  float4 col;
   // build matrix to tranform from tangent to view-space
  float3x3 tangent_to_view;
  tangent_to_view[0] = normalize(tan_to_view0.xyz);
  tangent_to_view[1] = normalize(tan_to_view1.xyz);
  tangent_to_view[2] = normalize(tan_to_view2.xyz);

  // build normal
//  s2half3 nrm = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));
  s2half3 nrm_wrld = mul(texNormal, tangent_to_view);

  // build color from normal
  s2half3 nem_col = 0.5 * (nrm_wrld + s2half3(1.0, 1.0, 1.0));

/*
  // 1st preview texture (rgb=diffuse, a=alpha)
  clip(tex0.a-0.1); 
*/
  col = tex0;
  #if LAYER_BIT0
    // 2nd preview texture (rgb=nrmal, a=glow)
  //  col = float4(nem_col, tex1.a);
    col = float4(nem_col, tex1.a);
  #endif
  #if LAYER_BIT1
    // 3nd preview texture (r=const diffuse, g=specular)
    col = float4(0.2 + 0.5 * saturate(dot(nrm_wrld, normalize(float3(0.5, 0.5, 1.0)))), dot(tex1.xyz, float3(0.222, 0.707, 0.071)), 0.0, 0.0);
  #endif
  return col;
}

    float4 apply_colorramp_org(float4 color,float4 mask,float4 ramp[8])
    {
#ifdef SM3_0
      // We calculate the diffuse Luminance to multiply it later with the ramp colors 
      // there is an optimize option here if the areas that get recoloring are already gray in the texture 
      float diffuseLuminance = (color.r * .3 + color.g * .59 + color.b * .11) ;
      // split the positive and negative areas of the texture and cut off the unneeded values
      mask              = mask*2-1;
      float4 posConvert = saturate(mask);
      float4 negConvert = saturate(mask*-1);
      // calculate the falseLuminance of the mask - we need that later as an indicator if recoloring occurs or not
      float4 convert = posConvert + negConvert;
    //	float convertFalseLuminance = convert.r + convert.g + convert.b + convert.a;
	    float convertFalseLuminance = dot(convert,convert);
      // multiply the values with the diffuse Luminance. We need to do that here cause for real Ramps we need them unmultiplied
      float4 posConvertMul = posConvert * diffuseLuminance;
      float4 negConvertMul = negConvert * diffuseLuminance;
      // current Ramp
      int rampLevel = 0;
      // result after recoloring
      float4 result;
      result  = ramp[0] * posConvertMul.r;
      result += ramp[1] * posConvertMul.g;
      result += ramp[2] * posConvertMul.b;
      result += ramp[3] * negConvertMul.r;
      result += ramp[4] * negConvertMul.g;
      result += ramp[5] * negConvertMul.b;
      result += ramp[6] * posConvertMul.a;
      result += ramp[7] * negConvertMul.a;
      // lerp between the recolored result and the original color - this way the unmarked areas keep their original color
      result = lerp (result , color,1 - convertFalseLuminance );
      return result;
#else
      return color;
#endif
    }
    float4 apply_colorramp(float4 color,float4 mask,float4 ramp[8])
    {
#ifdef SM3_0
      // We calculate the diffuse Luminance to multiply it later with the ramp colors 
      // there is an optimize option here if the areas that get recoloring are already gray in the texture 
      float4 lumMul          = float4(.3,.59,.11,0);
      float diffuseLuminance = dot(color,lumMul);
      // shift mask value into -1 / 1 range
      mask              = mask*2-1;

//fix interpolate errors
		float threshold = .05;
		mask = (abs(mask) * (1.0 - step(mask, -threshold) - step(mask,threshold)));


		if(dot(mask,mask)>0.0000001f){
			mask = normalize(mask);
		}
//endfix

      // calculate the falseLuminance of the mask - we need that later as an indicator if recoloring occurs or not
      // multiply the values with the diffuse Luminance. We need to do that here cause for real Ramps we need them unmultiplied

	    float convertFalseLuminance = dot(mask,mask);

      float4 posConvertMul = saturate(mask*diffuseLuminance);
      float4 negConvertMul = saturate(mask*-diffuseLuminance);
      // result after recoloring
      float4 result;
      result  = ramp[0] * posConvertMul.r;
      result += ramp[1] * posConvertMul.g;
      result += ramp[2] * posConvertMul.b;
      result += ramp[3] * negConvertMul.r;
      result += ramp[4] * negConvertMul.g;
      result += ramp[5] * negConvertMul.b;
      result += ramp[6] * posConvertMul.a;
      result += ramp[7] * negConvertMul.a;
      // lerp between the recolored result and the original color - this way the unmarked areas keep their original color
//      result = lerp (result , color,1 - convertFalseLuminance );
      result = result*convertFalseLuminance+color*(1-convertFalseLuminance);
      return result;
#else
      return color;
#endif
    }

  struct sTEnergy
  {
    float4 color0;
    float4 color1;
    float4 color_fractal;
    float4 color_pulse1;
    float4 color_pulse2;
  };
  
  float4 calc_tnoise(sampler3D tex_noise3d,sampler2D tex_color,float2 texccord,float  sc_time)
  {
    int i, octaves = 3;
    float ampi = 0.652;
    float ampm = 0.408;
    float freqi = 0.94;
    float freqm = 2.88;
  	
    float freq     = freqi;
    float amp      = ampi;
    float4 sum_col = float4(0.0, 0.0, 0.0, 0.0);
  	
    for(i = 0; i < octaves; i++)
    {
	    sum_col += amp * tex3D(tex_noise3d, float3(freq * texccord.xy, 0.03 * sc_time));
	    freq *= freqm;
	    amp *= ampm;	
    }
    // look up in color-fade texture
    return tex2D(tex_color, 0.9 * sum_col.xy);
  }
  
  void calc_tenergy(out sTEnergy te,
                    sampler3D tex_noise3d,
                    sampler2D tex_tenergy1,
                    sampler2D tex_tenergy2,
                    float2 texccord,
                    float  sc_dist,
                    float  sc_time)
  {
    // look up in color-fade texture
    te.color_fractal = calc_tnoise(tex_noise3d,tex_tenergy2,texccord,sc_time);
    // overlay burst (radial!)
//    float dist    = length(texccord.xy);
//    dist = -texccord.y;
    te.color_pulse1 = tex2D(tex_tenergy1, float2(sc_dist - 0.3 * sc_time, 0.0));
    // push_up
    te.color_pulse2  = 3.0 * te.color_pulse1 + te.color_pulse1.wwww;

	  te.color0 = float4(te.color_fractal.xyz * te.color_pulse2.xyz + 0.5 * te.color_pulse1.xyz,1);
	  te.color1 = float4(0.4 * te.color_fractal.xyz * te.color_pulse2.xyz + 0.3 * te.color_pulse1.xyz,1);
  }
  
#ifdef CONSOLE_IMPL
 /*
 * Routines used for calculating fog
 */
void fogDiffuse( inout s2half3 source_color, in sampler2D fog_texture, in float2 fog_tcs, in float3 sunlight_col )
{
  s2half4 fog_color = tex2D( fog_texture, fog_tcs );
  source_color = lerp( source_color, sunlight_col.xyz * fog_color.xyz, fog_color.w );
}

void fogDiffuse2( inout s2half3 source_color, in sampler2D fog_texture, in float2 fog_tcs, in float3 sunlight_col )
{
  s2half4 fog_color = srgb2linear( tex2D( fog_texture, fog_tcs ) );
  source_color = lerp( source_color, sunlight_col.xyz * fog_color.xyz, fog_color.w );
}

void fogPnt( inout half light_intensity, in sampler2D fog_texture, float2 fog_tcs )
{
  light_intensity *= 1.0 - tex2D( fog_texture, fog_tcs ).w;
}


void fogGlow( inout s2half3 source_glow, in sampler2D fog_texture, in float2 fog_tcs )
{
  source_glow *= 1.0 - tex2D( fog_texture, fog_tcs ).wwww;
}

float2 getFogTCs( in float w, in float4 fog_data )
{
  // scale fog to distance between hero and z_far
  
  // Tiefenunschärfe im Nahbereich (also change BrdfLighting.shader)
//*  
  // enabled
  if( w > fog_data.x )
    return float2( saturate( ( w - fog_data.x ) * fog_data.z ), fog_data.w );
  else
    return -float2( saturate( (fog_data.x-w)/fog_data.x ), fog_data.w ); 
/*/
  // disabled
  return float2( saturate( ( w - fog_data.x ) * fog_data.z ), fog_data.w );
//*/    
}

#else
/*
 * Routines used for calculating fog
 */
void fogDiffuseI( inout float3 source_color, in float intensity, in float4 fog_color)
{
  source_color = lerp( fog_color.xyz, source_color, intensity);
}
void fogDiffuse( inout float3 source_color, in sampler2D fog_texture, in float2 fog_tcs, in float4 fog_color)
{
  float4 fog_intensity = tex2D( fog_texture, fog_tcs );
  source_color = lerp( fog_color.xyz, source_color, fog_intensity.w );
}

void fogPntI( inout float light_intensity, in float intensity)
{
  light_intensity *= intensity;
}
void fogPnt( inout float light_intensity, in sampler2D fog_texture, float2 fog_tcs )
{
  light_intensity *= tex2D( fog_texture, fog_tcs ).w;
}

void fogGlowI( inout float3 source_glow, in float intensity )
{
  source_glow *= intensity;
}
void fogGlow( inout float3 source_glow, in sampler2D fog_texture, in float2 fog_tcs )
{
  source_glow *= tex2D( fog_texture, fog_tcs ).w;
}

float2 getFogTCs( in float w, in float4 fog_data)
{
  // scale fog to distance between hero and z_far
//  fog_data  = vector4d( dist, dist/(zf - dist), 1.f / (zf - dist), cWeatherMgr::Instance().getTimeOfDay() );
  return float2( w* fog_data.z-fog_data.y, fog_data.w );
}
#endif



float4 calcScreenToTexCoord(float4 hpos)
{
  float4 screenCoordInTexSpace;
  
#ifndef PS3_IMPL  
  // calculate vertex position in screen space and transform to texture space in PS
  screenCoordInTexSpace.x   = hpos.w + hpos.x;
  screenCoordInTexSpace.y   = hpos.w - hpos.y;
  screenCoordInTexSpace.z   = hpos.z;
  screenCoordInTexSpace.w   = 2.0 * hpos.w;
  screenCoordInTexSpace.xy *= target_data.xy;

  screenCoordInTexSpace.xy /= screenCoordInTexSpace.w;
  screenCoordInTexSpace.xy  = (screenCoordInTexSpace.xy - viewport_data.xy) * viewport_data.zw;
  screenCoordInTexSpace.xy *= screenCoordInTexSpace.w;
#else
  screenCoordInTexSpace=float4(hpos.x,-hpos.y,hpos.z,1);
  screenCoordInTexSpace.xyz/=2*hpos.w;
  screenCoordInTexSpace.xyz+=float3(0.5f,0.5f,0.5f);
  screenCoordInTexSpace.xyzw*=hpos.wwww;
#endif        

  return screenCoordInTexSpace;
}

#ifdef CONSOLE_IMPL
    float4 RefractionOffsets(uniform const bool bHalf, float2 xy, float factor, float2 ofs)
    {
      if(bHalf)
      {
#ifdef XENON_IMPL
        return float4(tiling_data_half_tile.xy * xy,
                      tiling_data_half_tile.xy * (xy + factor*ofs));
#else
        return float4(target_data.xy * xy,
                      target_data.xy * (xy + factor*ofs));
#endif
      }
      else
      {
#ifdef XENON_IMPL
        return float4(tiling_data_half_tile.zw * xy,
                      tiling_data_half_tile.zw * (xy + factor*ofs));
#else
        return float4(target_data.zw * xy,
                      target_data.zw * (xy + factor*ofs));
#endif
      }
    }
#endif


#endif //EXTRACTVALUES_H
