//#OptDef:SPASS_G
//#OptDef:LAYER_BIT0 // NO_SHADOWS
//#OptDef:S2_FOG
//#OptDef:SPASS_AMBDIF
//#OptDef:SPASS_PNT
//#OptDef:SPASS_SHADOWMAP
//#OptDef:SPASS_CUBESHADOWMAP

// ambient
#include "extractvalues.shader"


struct appdata
{
	float3 position   : POSITION;
	float3 normal     : NORMAL;
	float3 tangent    : TANGENT;
	float3 binormal   : BINORMAL;
	float2 texcoord   : TEXCOORD0;
	float2 data       : TEXCOORD1;
};


#ifdef SPASS_SHADOWMAP
  struct pixdata
  {
	float4 hposition   : POSITION;
	float4 hpos        : TEXCOORD0;
	float4 texcoord0   : TEXCOORD1;
  };
  struct fragout 
  {
    float4 col         : COLOR;
  };

  // Shadow vertex shader
  pixdata mainVS(appdata I, uniform float4x4 lightMatrix)
  {
	  pixdata O;
	  float4 pos4 = float4(I.position, 1.0);
	  // vertex pos
	  O.hposition = mul(pos4, lightMatrix);
	  O.hpos = O.hposition;
	  // pass texcoords to fragment shader
	  O.texcoord0 = I.texcoord.xyyy;
	  return O;
  }

  #if defined(XENON_IMPL)
    half4 mainPS( pixdata I,
          uniform sampler2D texture0 ) : COLOR0
    {
      float fDist = I.hpos.z/I.hpos.w;
      #ifdef IS_OPAQUE
	    return half4( fDist, fDist*fDist, 0.0, 0.0 );
      #else
  	  clip(tex2D(texture0, I.texcoord0.xy).a-0.9f);
	    return half4( fDist, fDist*fDist, 0.0, 1.f );
      #endif
    }
  #else
    fragout mainPS(pixdata   I,
           uniform sampler2D texture0 )
    {
      fragout O;
      #ifdef IS_OPAQUE 
		O.col = float4(1,0,0,0);
      #else
		O.col = tex2D(texture0, I.texcoord0.xy);
		clip(O.col.a-0.9f);
      #endif
      return O;
    }
  #endif
#endif



#ifdef SPASS_CUBESHADOWMAP
  struct pixdata
  {
	float4 hposition   : POSITION;
	float4 texcoord0   : TEXCOORD1;
    float4 li_to_pix_w : TEXCOORD2;
  };
  struct fragout 
  {
    float4 col         : COLOR;
  };

  // Shadow vertex shader
  pixdata mainVS( appdata I, 
                  uniform float4x4 worldMatrix, 
                  uniform float4x4 lightMatrix,
                  uniform float4   light_pos )
  {
	  pixdata O;
	  float4 pos4 = float4(I.position, 1.0);
	  // vertex pos
	  O.hposition = mul(pos4, lightMatrix);
    // add small bias to avoid self shadowing
    O.li_to_pix_w = mul( pos4, worldMatrix ) - light_pos;
	  // pass texcoords to fragment shader
	  O.texcoord0 = I.texcoord.xyyy;
	  return O;
  }

  // Shadow pixel shader
  fragout mainPS(pixdata I,
      uniform sampler2D texture0,
      uniform float4    light_data)
  {
    fragout O;
    // need opacity-channel, since this is shadowmapping!
    float opacity;
    #ifndef IS_OPAQUE
      float4 tex0 = tex2D(texture0, I.texcoord0.xy);
      opacity     = tex0.a;
      clip(opacity-0.9f);
    #else
      opacity = 1.0;
    #endif

    // square distance of scaled
    float3 li_to_pix_w_s = light_data.z * I.li_to_pix_w.xyz;
    #ifdef PS3_IMPL
	  float sq_dist = saturate(dot(li_to_pix_w_s, li_to_pix_w_s));

      // endcode it in rgb!!
  	  float3 depth_encoded = sq_dist * float3(1.0, 256.f, 256.f * 256.f);
  	  // do not put the .x component through the frac, this gives 0.0 for 1.0 -> ERRORs
  	  depth_encoded.yz = frac(depth_encoded.yz);

      // pass it to texture
      O.col = float4(depth_encoded, tex0.a);
    #else	
      O.col.r = saturate( length(li_to_pix_w_s) );
      O.col.g = saturate( dot(li_to_pix_w_s,li_to_pix_w_s) );
      O.col.b = 1;
      O.col.a = opacity;
    #endif    
    return O;
  }
#endif




#ifdef SPASS_G
  #define GLOB_VS
  struct pixdata
  {
	  float4 hposition			: POSITION;
	  float4 texcoord0			: TEXCOORD0;
	  float3 matrix_TS_to_WS[3] : TEXCOORD1;
  };
  #define VS_OUT_texcoord0
  #define VS_OUT_matrix
#endif

#ifdef SPASS_PNT
  #define GLOB_VS
  struct pixdata 
  {
	  float4 hposition             : POSITION;
	  float4 texcoord0             : TEXCOORD0;
	  float4 sun_data              : TEXCOORD1;
	  float4 pl_data               : TEXCOORD2;
	  float4 pl_color              : TEXCOORD3;
    float4 screenCoordInTexSpace : TEXCOORD4;
    float4 posInLight            : TEXCOORD5;
    float4 li_to_pix_w           : TEXCOORD6;
#ifdef S2_FOG
    float2 depthFog    : TEXCOORD7;
#endif

  #define VS_OUT_texcoord0
  #define VS_OUT_pl_data
  #define VS_OUT_pl_color
  #define VS_OUT_sun_data
  #define VS_OUT_screenCoordInTexSpace
  #define VS_OUT_posInLight
  #define VS_OUT_li_to_pix_w
#ifdef S2_FOG
  #define VS_OUT_depthFog
#endif
  };

#endif




#ifdef SPASS_AMBDIF
  #define GLOB_VS
  struct pixdata
  {
	  float4 hposition              : POSITION;
	  float4 texcoord0              : TEXCOORD0;
      float4 posInLight             : TEXCOORD1;
	  float4 color                  : TEXCOORD2;
  #ifdef S2_FOG
    float2 depthFog               : TEXCOORD3;
  #endif
  };
  #define VS_OUT_texcoord0
  #define VS_OUT_posInLight
  #define VS_OUT_color
  #ifdef S2_FOG
    #define VS_OUT_depthFog
  #endif
#endif


#ifdef GLOB_VS
  #ifdef SPASS_G
	struct fragout {
	  float4 diffuse  : COLOR0;
	  float4 normal   : COLOR1;
	  float4 specular : COLOR2;
 	};
  #else
    struct fragout 
    {
      float4 col[2]      : COLOR;
    };
  #endif


#include "shadow.shader"

pixdata mainVS(appdata I,
	  uniform float4x4 worldViewProjMatrix,
    uniform float4x4 worldMatrix,
    uniform float4x4 worldViewMatrix,
    uniform float4x4 invWorldMatrix,
    uniform float4   vtx_data_array[3],
    uniform float4x4 lightMatrix,
    uniform float4   light_pos,
    uniform float4   camera_pos,
    uniform float4   zfrustum_data,
    uniform float4   fog_data,
    uniform lightData globLightData)
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);
  float camSpaceZ = pos4.x*worldViewMatrix[0][2] +  
                    pos4.y*worldViewMatrix[1][2] + 
                    pos4.z*worldViewMatrix[2][2] + 
                    worldViewMatrix[3][2];

#ifdef VS_OUT_li_to_pix_w
  // pass vector in WS from point light to vertex
  O.li_to_pix_w = mul( pos4, worldMatrix ) - vtx_data_array[0];
#endif

#ifdef VS_OUT_depthFog
  O.depthFog = getFogTCs( O.hposition.w, fog_data );
#endif

#ifdef VS_OUT_depthUV
  // calc texturecoords for rg(b)-depth encoding
  O.depthUV = float4(0,0,0, -camSpaceZ*zfrustum_data.w);
#endif

#ifdef VS_OUT_posInLight
  O.posInLight = mul( pos4, lightMatrix );
#endif

#ifdef VS_OUT_screenCoordInTexSpace
	// vertex-position in screen space
  O.screenCoordInTexSpace = calcScreenToTexCoord(O.hposition);
#endif

#ifndef SPASS_G   	// need light dir in object-space
	float4 l_dir_obj = mul(light_pos, invWorldMatrix);
	// need cam dir in object-space
	float4 c_dir_obj = mul(camera_pos, invWorldMatrix);
	c_dir_obj = normalize(c_dir_obj - pos4);

	// must selfshadow (hm...)
	float self_s = saturate(dot(I.normal, l_dir_obj.xyz));

	// calc diffuse
	float diffuse = sqrt(1.0 - dot(I.binormal, l_dir_obj.xyz) * dot(I.binormal, l_dir_obj.xyz));
	diffuse *= self_s;

	// calc specular
	float3 half_vec = normalize(c_dir_obj.xyz + l_dir_obj.xyz);
	float specular = sqrt(1.0 - dot(I.binormal, half_vec) * dot(I.binormal, half_vec));
	specular = pow(specular, 16.0);
	specular *= self_s;

#ifdef VS_OUT_color
	// pass to pixel shader
	O.color = float4(diffuse, specular, 0.0, 0.0);
#endif

#ifdef VS_OUT_sun_data
  	// pass to pixel shader
	O.sun_data = float4(diffuse, specular, 0.0, 0.0);
#endif

#ifdef VS_OUT_pl_color
  	O.pl_color = vtx_data_array[1];
#endif

#ifdef VS_OUT_pl_data
  // need point light dir in object-space
  float4 pl_pos     = vtx_data_array[0];
  float4 pl_dir_obj = mul(pl_pos, invWorldMatrix);
  float pl_distance = dot(pl_dir_obj.xyz, pl_dir_obj.xyz);
  pl_dir_obj  = normalize(pl_dir_obj - pos4);

  // must selfshadow (hm...)
  self_s = saturate(dot(I.normal, pl_dir_obj.xyz));
  // calc diffuse
  diffuse = sqrt(1.0 - dot(I.binormal, pl_dir_obj.xyz) * dot(I.binormal, pl_dir_obj.xyz));
  diffuse *= self_s;
  // calc specular
  half_vec = normalize(c_dir_obj.xyz + l_dir_obj.xyz);
  specular = sqrt(1.0 - dot(I.binormal, half_vec) * dot(I.binormal, half_vec));
  specular = pow(specular, 16.0);
  specular *= self_s;
  // build intensity from distance to light using light radius
  float4 pl_dat   = vtx_data_array[2];
  pl_distance     = saturate(pl_distance / (pl_dat.x * pl_dat.x));
  float intensity = (1.0 - pl_distance) * (1.0 - pl_distance); // 1.0 - sin(1.5708 * pl_distance);
  // multiply it by intensity of light source
  diffuse  *= intensity * pl_dat.y;
  specular *= intensity * pl_dat.y;
  // pass to pixel shader
  O.pl_data = float4(diffuse, specular, vtx_data_array[2].z, vtx_data_array[2].w);
#endif

#endif

#ifdef VS_OUT_matrix
  float3 nrm3 = I.normal;
  float3 tan3 = I.tangent;
  float3 bin3 = I.binormal;
	
  float3x3 invTangentSpaceMatrix;
  invTangentSpaceMatrix[0] = - tan3;
  invTangentSpaceMatrix[1] = - bin3;
  invTangentSpaceMatrix[2] =   nrm3;

  #ifdef PS3_IMPL	
    float3x3 mattmp = mul( worldMatrix, invTangentSpaceMatrix );
  #else
    float3x3 mattmp = mul( invTangentSpaceMatrix, worldMatrix );
  #endif
  O.matrix_TS_to_WS[0] = mattmp[0];
  O.matrix_TS_to_WS[1] = mattmp[1];
  O.matrix_TS_to_WS[2] = mattmp[2];
#endif

#ifdef VS_OUT_texcoord0
	// texture coords
	O.texcoord0 = I.texcoord.xyyy;
#endif

#ifdef VS_OUT_lowendFog
  O.fog = calcFog(O.hposition, fog_data);
#endif
	return O;
}
#endif


#ifdef SPASS_G
  #include "normalmap.shader"
  #ifdef SPASS_ZONLY  
    float4 mainPS( pixdata I
                  ,uniform sampler2D texture0
                  ,uniform sampler2D texture2
                  ,uniform float4    materialID ) : COLOR0
    {
      s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
      clip(tex0.a-0.9f);
      return 1.f;
    }
  #else
    fragout mainPS( pixdata I
                   ,uniform sampler2D texture0
                   ,uniform sampler2D texture2
                   ,uniform float4    materialID )
    {
      fragout O;
      s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
      s2half4 tex1 = tex2D(texture2, I.texcoord0.xy);
      // calc worldspace normal
	  s2half3 normal_TS = s2half3(tex2D(texture2, I.texcoord0.xy).xx,1)*2-1;
	  normal_TS    = normalize( normal_TS );
	  normal_TS.y *= -1;
	
      float3x3 TS_to_WS = { normalize(I.matrix_TS_to_WS[0]), 
                            normalize(I.matrix_TS_to_WS[1]), 
                            normalize(I.matrix_TS_to_WS[2]) };
      #ifdef PS3_IMPL
        s2half3 normal_WS = normalize(mul( TS_to_WS, normal_TS ));
      #else
        s2half3 normal_WS = normalize(mul( normal_TS, TS_to_WS ));
      #endif
  
      s2half3 diffuse = tex0.xyz;
      s2half3 normal = normal_WS;
      s2half3 specular = tex1.rgb/2;
      normal = normalize(normal)*0.5 + 0.5;
  
      O.diffuse  = half4( diffuse,  tex0.a );
      O.normal   = half4( normal,   0.f );
      O.specular = half4( specular, 0.f );
  
      return O;
    } 
  #endif  
#endif



#ifdef SPASS_AMBDIF
fragout mainPS( pixdata     I,
                float2      vPos : VPOS,
	    uniform sampler2D   texture0,
        uniform sampler2D   texture2,
        uniform sampler2D   shadow_map,
        uniform sampler3D   textureVolume,
        uniform int         anzIterations,
        uniform float4      shadow_data,
        uniform sampler2D   fog_texture,
        uniform float4      fog_color,
	    uniform float4      light_col_amb,   // is ambient color
	    uniform float4      light_col_diff,  // is diffuse color
	    uniform float4      light_data )     // is hair color
{
  fragout O;

  // get texture values
  s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
  s2half4 tex2 = tex2D(texture2, I.texcoord0.xy);
  s2half shadow = 1.0;
#ifndef LAYER_BIT0
  #ifdef CONSOLE_IMPL
    shadow = calcShadowSimple( shadow_map, I.posInLight );
  #else 
    shadow = calcShadow( shadow_map, textureVolume, I.posInLight, vPos, shadow_data.y, shadow_data.x, anzIterations );
  #endif
#endif

	// give var useful names
	float3 hair_col = light_data.rgb;
	
	// modify hair_col, so it gets color and texture
	hair_col.rgb = tex0.rgb * lerp(float3(1.0, 1.0, 1.0), hair_col, tex2.a);

	// calc ambient
	float3 ambient = light_col_amb.rgb * hair_col;
	
    // calc hair diffuse
	float3 diffuse  = I.color.x * light_col_diff.rgb * hair_col + I.color.y * light_col_diff.rgb * tex2;
    diffuse *= shadow;

  s2half3 final_color = ambient + diffuse;
  s2half3 final_glow  = 0.3 * diffuse;

#ifdef S2_FOG
  fogDiffuse( final_color, fog_texture, I.depthFog, fog_color );
  fogGlow( final_glow, fog_texture, I.depthFog );
#endif

	// set output color
	O.col[0] = float4(final_color, tex0.a);
	O.col[1] = float4(final_glow,  tex0.a);

	return O;
} 
#endif




#ifdef SPASS_PNT
fragout mainPS( pixdata     I,
                float2      vPos : VPOS,
	    uniform sampler2D   texture0,
        uniform sampler2D   texture2,
        uniform samplerCUBE textureCube,
        uniform sampler2D   fog_texture,
        uniform float4      fog_color,
	    uniform float4      light_data )     // is hair color
{
	fragout O;

	// get texture values
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	s2half4 tex2 = tex2D(texture2, I.texcoord0.xy);
  
	// give var useful names
	float4 hair_col = light_data;
	
	// modify hair_col, so it gets color and texture
	hair_col = tex0 * lerp(float4(1.0, 1.0, 1.0, 1.0), hair_col, tex2.a);

	// calc hair pl diffuse
	float4 pl_diffuse  = I.pl_data.x * I.pl_color * hair_col + I.pl_data.y * I.pl_color * tex2;
#ifndef LAYER_BIT0
  #ifdef CONSOLE_IMPL
    s2half pntshadow = calcPntFadeShadow( textureCube, normalize(I.li_to_pix_w.xzy), length(I.li_to_pix_w.xzy)*I.pl_data.z, 1-I.pl_data.w );
  #else   
    s2half pntshadow = calcPntFadeShadow( textureCube, I.pl_data.z * I.li_to_pix_w.xzy, I.pl_data.w );
  #endif
  pl_diffuse.rgb  *= pntshadow;
#endif
  float3 final_color = pl_diffuse.xyz;
  float3 final_glow  = 0.5 * pl_diffuse.xyz;

  float intensity = 1.0;
//#ifdef S2_FOG
//  fogPnt( intensity, fog_texture, I.depthFog );
//#endif

  // set output color
  O.col[0] = float4(final_color, tex0.a * intensity);
  O.col[1] = float4(final_glow , tex0.a * intensity);

  return O;
} 
#endif