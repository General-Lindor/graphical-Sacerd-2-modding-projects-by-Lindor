// speedTree tree z
#include "extractvalues.shader"
#include "shadow.shader"


/////////////////////////////////////
// SPASS_ZONLY setup
/////////////////////////////////////
#ifdef SPASS_ZONLY
  #define VS_OUT_ZONLY
  #define PS_SPASS_Z_20
#endif

/////////////////////////////////////
// SPASS_G setup
/////////////////////////////////////
#ifdef SPASS_G
  #define VS_OUT_G
  #define PS_SPASS_G_20 
#endif
/////////////////////////////////////
// SPASS_SHADOWMAP setup
/////////////////////////////////////
#ifdef SPASS_SHADOWMAP
  #define VS_OUT_SHADOWMAP
  #define PS_SPASS_SHADOWMAP
#endif
/////////////////////////////////////
// SPASS_CUBESHADOWMAP setup
/////////////////////////////////////
#ifdef SPASS_CUBESHADOWMAP
  #define VS_OUT_CUBESHADOWMAP
  #define PS_SPASS_CUBESHADOWMAP_20
#endif





/////////////////////////////////////
// Vertex Shader Setups
/////////////////////////////////////
#ifdef VS_OUT_G
  struct pixdata {
    float4 hposition            : POSITION;
    float4 texcoord0            : TEXCOORD0;
    #ifdef SPASS_AMBDIF
      float4 hpos               : TEXCOORD1;
      float4 pix_to_cam         : TEXCOORD2;
      float4 li_to_pix_w        : TEXCOORD3;
      float4 posInLight         : TEXCOORD4;
    #endif
    #ifdef USE_VERTEX_NORMAL
      float3 normal             : TEXCOORD5;
    #else
      float3 matrix_TS_to_WS[3] : TEXCOORD5;
    #endif
  };
  #ifdef SPASS_AMBDIF
    #define VS_OUT_hpos
    #define VS_OUT_pix_to_cam
    #define VS_OUT_posInLight
    #define VS_OUT_li_to_pix_w
  #endif
  
  #ifdef USE_VERTEX_NORMAL
    #define VS_OUT_NORMAL
  #else
    #define VS_OUT_TS_to_WS
  #endif
  #define VS_OUT_hposition
  #define VS_OUT_TEXCOORD0
#endif //VS_OUT_G

#ifdef VS_OUT_ZONLY
  struct pixdata {
    float4 hposition  : POSITION;
    #ifndef IS_OPAQUE
      float4 texcoord0  : TEXCOORD0;
    #endif
  };
  #define VS_OUT_hposition
  #ifndef IS_OPAQUE
    #define VS_OUT_TEXCOORD0
  #endif
#endif //VS_OUT_ZONLY

#ifdef VS_OUT_SHADOWMAP
  struct pixdata {
    float4 posInLight : POSITION;
	#ifdef XENON_IMPL
	  float4 pos          : TEXCOORD0;
	  #if !defined(IS_OPAQUE)
	    float4 texcoord0  : TEXCOORD1;
	  #endif
	#elif !defined(IS_OPAQUE)
	  float4 texcoord0  : TEXCOORD0;
	#endif
  };
  #define VS_OUT_posInLight
  #ifdef XENON_IMPL
    #define VS_OUT_pos
  #endif
  #if !defined(IS_OPAQUE)
    #define VS_OUT_TEXCOORD0
  #endif
#endif //VS_OUT_SHADOWMAP

#ifdef VS_OUT_CUBESHADOWMAP
  struct pixdata {
    float4 posInLight  : POSITION;
    float4 texcoord0   : TEXCOORD0;
	float4 li_to_pix_w : TEXCOORD1;
  };
  #define VS_OUT_li_to_pix_w
  #define VS_OUT_posInLight
  #define VS_OUT_TEXCOORD0
#endif //VS_OUT_CUBESHADOWMAP


#ifdef VS_OUT_PNT_20
    struct pixdata {
	    float4 hposition   : POSITION;
	    float4 texcoord0   : TEXCOORD0;
	    float4 pix_to_li   : TEXCOORD1;
	    float4 normal      : TEXCOORD2;
	    float4 hpos        : TEXCOORD3;
    #ifdef S2_FOG
      float2 depthFog    : TEXCOORD4;
    #endif
    };
    #define VS_OUT_hposition
    #define VS_OUT_pix_to_li
    #define VS_OUT_NORMAL
    #define VS_OUT_hpos
    #define VS_OUT_TEXCOORD0
  #ifdef S2_FOG
    #define VS_OUT_depthFog
  #endif
#endif //VS_OUT_PNT_20

#ifdef VS_OUT_PNT_20_X
    struct pixdata {
	    float4 hposition    : POSITION;
	    float4 texcoord0    : TEXCOORD0;
	    float4 pix_to_li_t  : TEXCOORD1;
	    float4 pix_to_c     : TEXCOORD2;
	    float4 pix_to_li_o  : TEXCOORD3;
    #ifdef S2_FOG
      float2 depthFog     : TEXCOORD4;
    #endif
    };
    #define VS_OUT_hposition
    #define VS_OUT_pix_to_li_T
    #define VS_OUT_pix_to_li_O
    #define VS_OUT_PIX_TO_C
    #define VS_OUT_TEXCOORD0
  #ifdef S2_FOG
    #define VS_OUT_depthFog
  #endif
#endif //VS_OUT_PNT_20_X

#ifdef VS_OUT_LIGHTNING_20
    struct pixdata {
	    float4 hposition   : POSITION;
	    float4 texcoord0   : TEXCOORD0;
	    float4 lightDist   : TEXCOORD1;
    };
    #define VS_OUT_hposition
    #define VS_OUT_lightDist
    #define VS_OUT_TEXCOORD0
#endif




DEFINE_VERTEX_DATA 

////////////////////////////////////////////////////////////////
//Unified Vertex shader used for all shader models
////////////////////////////////////////////////////////////////
pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 invWorldMatrix,
    uniform float4x4 worldMatrix,
    uniform float4x4 lightMatrix,
    uniform float4   vtx_data_array[32],
    uniform float4x4 vtx_matrix_array[4],
    uniform lightData globLightData,
    uniform float4   param,
    uniform float4   light_pos,
    uniform float4   camera_pos,
    uniform float4   zfrustum_data,
    uniform float4   fog_data
#if defined(XENON_IMPL) && !defined(SPASS_SHADOWMAP)	    
   ,uniform float4   jitter_data
#endif    
    )
{
	pixdata O;
	EXTRACT_VERTEX_VALUES

	// apply wind and calc extreme (=1.0) position
	float4 wind_pos4 = mul(pos4, vtx_matrix_array[windidx]);
	// now interpolate between org pos and extr pos
	pos4 = lerp(pos4, wind_pos4, windLerpFact);
	

#ifdef VS_IN_TREELEAFVERTEX
	float leaf_scale = param.z;
	// get vertex billboard offset from array and scale it by size
	float4 offs4 = data2.y * vtx_data_array[data2.x] * leaf_scale;
	// transform this offset backwards with inv objmat, so it is "billboarded" after next transform
	pos4 += mul(offs4, invWorldMatrix);
#endif

	// convert vertex pos from objspace to screen space
  float4 wvp_pos = mul(pos4, worldViewProjMatrix);
	// put (normalized!) distance
  float distance = (wvp_pos.w - zfrustum_data.x) * zfrustum_data.z;
	// convert vertex pos from objspace to worldspace
	float4 worldVertPos    = mul(pos4, worldMatrix);
	float3 worldVertNormal = normalize(mul(nrm4.xyz, (float3x3) worldMatrix));
	
#ifdef VS_OUT_TEXCOORD0	
	O.texcoord0 = uv0;
#endif

#ifdef VS_OUT_depthFog
  O.depthFog = getFogTCs( wvp_pos.w, fog_data );
  //O.depthFog.x = saturate( (wvp_pos.w - fog_data.x) * zfrustum_data.z );
  //O.depthFog.y = fog_data.w;
#endif

#ifdef VS_OUT_hposition
	// vertex pos
	O.hposition = wvp_pos;
	#if defined(XENON_IMPL) && !defined(SPASS_SHADOWMAP)	
		O.hposition.xy += jitter_data.xy * wvp_pos.ww;
	#endif	
#endif

#ifdef VS_OUT_SM1_TEXCOORD1
	O.texcoord1 = uv0;
#endif

#ifdef VS_OUT_depthUV
  // calc texturecoords for rg(b)-depth encoding
  O.depthUV = float4(distance * float2(1.0, 256.0), 0.0, O.hposition.w*zfrustum_data.w);
#endif

#ifdef VS_OUT_posInLight
	// vertex pos in light-space
	O.posInLight = mul(pos4, lightMatrix);
#endif

#ifdef VS_OUT_pos
   O.pos = mul(pos4, lightMatrix);
#endif

#ifdef VS_OUT_li_to_pix_w
	// pass light-to-pixel to fragment shader
	O.li_to_pix_w = worldVertPos - light_pos;
#endif
#ifdef VS_OUT_pix_to_cam
  O.pix_to_cam = camera_pos - worldVertPos;
#endif


	// convert light pos from worldspace into objectspace
	float4 l_pos_obj = mul(light_pos, invWorldMatrix);
	// build vector from vertex pos to light pos
	float3 vertex_to_light = l_pos_obj.xyz - pos4.xyz;
	// convert cam pos from worldspace into objectspace
	float4 c_pos_obj = mul(camera_pos, invWorldMatrix);
	// build vector from vertex pos to cam pos
#ifdef MINIMAPMODE
  float3 vertex_to_cam = c_pos_obj;
#else
	float3 vertex_to_cam = c_pos_obj.xyz - pos4.xyz;
#endif
	// convert light direction vector from worldspace to objectspace
	float4 l0_dir_obj = mul(light_pos, invWorldMatrix);
	// convert camera direction vector from worldspace to objectspace
	float4 c_dir_obj = mul(camera_pos, invWorldMatrix);

#ifdef VERT_TREEVERTEX

	// build object-to-tangent space matrix
	float3x3 objToTangentSpace;
	objToTangentSpace[0] = -1.0 * tan3;
	objToTangentSpace[1] = -1.0 * bin3;
	objToTangentSpace[2] = nrm4.xyz;

  // convert vertex_to_light from objectspace to tangentspace
  float3 vertex_to_light_tan = mul(objToTangentSpace, vertex_to_light);
	// convert vertex_to_cam from objectspace to tangentspace
	float3 vertex_to_cam_tan = mul(objToTangentSpace, vertex_to_cam);

	// convert light direction vector from objectspace to tangentspace
	float3 l0_dir_tan = mul(objToTangentSpace, l0_dir_obj.xyz);

	// calc direction vector from vertex position to camera-position
	c_dir_obj -= pos4;
	// convert camera direction vector from objectspace to tangentspace
	float3 c_dir_tan = mul(objToTangentSpace, c_dir_obj.xyz);

  #ifdef VS_OUT_lightDist
	  // store light vector
	  O.lightDist = float4(l0_dir_tan, 0.0);
  #endif
#else
  #ifdef VS_OUT_lightDist
	  // store light vector & dot
	  O.lightDist = float4(l0_dir_obj.xyz, dot(nrm4.xyz, l0_dir_obj.xyz));
  #endif
#endif 


#ifdef VS_OUT_camDist
	// store camera vec in texcoord2
	O.camDist = float4(c_dir_tan, 0.0);
#endif
#ifdef VS_OUT_hpos
	// pass screenpos to fragment shader
	O.hpos     = O.hposition;
	O.hpos.xy *= param.xy;
#endif

#ifdef VS_OUT_NORMAL
	// norma
  O.normal = float4(worldVertNormal, 0.f );
#endif

#ifdef VS_OUT_TS_to_WS
  float3x3 invTangentSpaceMatrix;
	invTangentSpaceMatrix[0] = tan3;
	invTangentSpaceMatrix[1] = bin3;
	invTangentSpaceMatrix[2] = nrm4.xyz;
#ifdef PS3_IMPL
  float3x3 mattmp = mul( worldMatrix, invTangentSpaceMatrix );
#else	
  float3x3 mattmp = mul( invTangentSpaceMatrix, worldMatrix );
#endif  
  O.matrix_TS_to_WS[0] = mattmp[0];
  O.matrix_TS_to_WS[1] = mattmp[1];
  O.matrix_TS_to_WS[2] = mattmp[2];
#endif

#ifdef VS_OUT_screenCoord
	// vertex-position in screen space
	O.screenCoord.x = O.hposition.w + O.hposition.x;
	O.screenCoord.y = O.hposition.w - O.hposition.y;
	O.screenCoord.z = 0.0;
	O.screenCoord.w = 2.0 * O.hposition.w;
	O.screenCoord.xy *= target_data.xy;
#endif


#ifdef VS_OUT_SM1_LIGHTING
	O.diffuse = calcLight(worldVertPos, worldVertNormal, camera_pos, globLightData, O.specular);
#endif 
#ifdef VS_OUT_diffuse
	// convert light direction vector from worldspace to objectspace
  float3 li_to_pix_w = normalize( light_pos - worldVertPos );
  float  diffuse = saturate( dot( worldVertNormal.xyz, li_to_pix_w ));
  O.diffuse = float4( diffuse.xxx, 1);
#endif 


#ifdef VS_OUT_lowendFog
	O.fog = calcFog(O.hposition, fog_data);
#endif


	// pass vertex to light to pixelshader, so it becomes pixel to light
#ifdef VS_OUT_pix_to_li_T
	O.pix_to_li_t = float4(vertex_to_light_tan, 0.0);
#endif
#ifdef VS_OUT_pix_to_li_O
	O.pix_to_li_o = float4(vertex_to_light, 0.0);
#endif
#ifdef VS_OUT_pix_to_li
	// pass vertex to light to pixelshader, so it becomes pixel to light
	O.pix_to_li = float4(vertex_to_light, 0.0);
#endif
#ifdef VS_OUT_PIX_TO_C
	// pass vertex to cam to pixelshader, so it becomes pixel to cam
	O.pix_to_c = float4(vertex_to_cam_tan, 0.0);
#endif

#ifdef POS_IN_WORLD
	O.posInWorld.z = wvp_pos.w;
	O.posInWorld.xyw = wvp_pos.xyw/wvp_pos.w;
//	O.posInWorld.z = Z_NEAR + O.posInWorld*(Z_FAR-Z_NEAR);
#endif

	return O;
}


#ifdef PS3_IMPL
float calcHoleAlpha(float4 vpos,float opacity)
{
  vpos /= vpos.w;
  
  float fact = vpos.x*vpos.x+vpos.y*vpos.y;
  fact = saturate( fact + 0.5f - frac(vpos.x*769.f+vpos.y*401.f) );
  fact = fact*fact*fact*fact;
  return fact + opacity;
}
#else // PS3_IMPL

float calcHoleAlpha(float4 vpos,float opacity)
{
  vpos /= vpos.w;
  
  float fact = vpos.x*vpos.x+vpos.y*vpos.y;
  fact = saturate( fact + 0.5f - frac(vpos.x*7699.f+vpos.y*4001.f) );
  fact = fact*fact*fact*fact;
  return fact + opacity;
}
#endif // PS3_IMPL

////////////////////////////////////////////////////////////////
//SPASS_G pixel shader (>=SM2_0)
////////////////////////////////////////////////////////////////
#ifdef PS_SPASS_G_20
  #include "normalmap.shader"
  struct fragout3 {
    float4 col0 : COLOR0;
    float4 col1 : COLOR1;
    float4 col2 : COLOR2;
  };
  fragout3 mainPS( pixdata I
          ,        float2    vPos : VPOS
          ,uniform float4    param  
          ,uniform sampler2D texture0
          ,uniform sampler2D texture1
          ,uniform float4   materialID )
  {
    fragout3 O;

    s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
    
    #if TREE_HOLE
      #ifdef XENON_IMPL	  
        s2half4 pos = s2half4( (vPos*tiling_data_half_scr.zw + tiling_data_half_scr.xy)*2-1, 0, 1 );
        pos.x *= tiling_data_half_scr.w/tiling_data_half_scr.z;
      #else
        s2half4 pos = s2half4( vPos*target_data.zw*2-1, 0, 1 );
      #endif
      tex0.a *= calcHoleAlpha( pos, param.x );
      clip( tex0.a-0.5f );
    #endif
      
    s2half3 specular;
    #ifdef USE_VERTEX_NORMAL
      s2half3 normal = normalize( I.normal );
      specular = 0.0;
    #else
      // calc worldspace normal
      s2half4 normal_TS = ReadNormalMap2D(texture1, I.texcoord0.xy);
    
      float3x3 TS_to_WS = { normalize(I.matrix_TS_to_WS[0]), 
                            normalize(I.matrix_TS_to_WS[1]), 
                            normalize(I.matrix_TS_to_WS[2]) };
                            
#ifdef PS3_IMPL
      s2half3 normal = mul( TS_to_WS, normal_TS.xyz );
#else
      s2half3 normal = mul( normal_TS.xyz, TS_to_WS );
#endif        
      specular = tex0.w;
    #endif
      
    s2half3 diffuse = tex0.xyz;
    //EncodeNormal( normal, specular );
    normal = normalize(normal)*0.5 + 0.5;

	s2half texCoord = dot(I.texcoord0.xy, s2half2( 0.5, 0.5 ) ); //Kind of texcoord-hash for motion-FSAA
    O.col0 = half4( diffuse,  texCoord );
    O.col1 = half4( normal,   materialID.x );
    O.col2 = half4( specular, 0 );

    return O;
  } 
#endif
////////////////////////////////////////////////////////////////
//SPASS_ZONLY pixel shader (>=SM2_0)
////////////////////////////////////////////////////////////////
#ifdef PS_SPASS_Z_20
  #if !defined(XENON_IMPL) || !defined(IS_OPAQUE)
    fragout1 mainPS( pixdata   I,
                     float2    vPos : VPOS,
             uniform sampler2D texture0,
             uniform float4    param)
    {
      fragout1 O;
      
      #ifdef IS_OPAQUE 
	    O.col = float4( 0,0,0,1.f );
	  #else
	    O.col = tex2D(texture0, I.texcoord0.xy);
	  #endif
      
      #if TREE_HOLE
        #ifdef XENON_IMPL	  
          s2half4 pos = s2half4( (vPos*tiling_data_half_scr.zw + tiling_data_half_scr.xy)*2-1, 0, 1 );
          pos.x *= tiling_data_half_scr.w/tiling_data_half_scr.z;
        #else
          s2half4 pos = s2half4( vPos*target_data.zw*2-1, 0, 1 );
        #endif
        O.col.a *= calcHoleAlpha( pos, param.x );
      #endif
      	  
	  return O;
    } 
  #endif
#endif

////////////////////////////////////////////////////////////////
//SPASS_SHADOWMAP pixel shader (unified)
////////////////////////////////////////////////////////////////
#ifdef SPASS_SHADOWMAP
  #if defined(XENON_IMPL)
    fragout1 mainPS(pixdata I,
                    uniform sampler2D texture0,
                    uniform float4 shadow_data)
    {
      fragout1 O;
      float fDist = I.pos.z/I.pos.w;
      #ifdef IS_OPAQUE 
        O.col = half4( fDist, fDist*fDist, 0.0, 1.0 );
      #else
        O.col = half4( fDist, fDist*fDist, 0.0, tex2D(texture0, I.texcoord0.xy).a );
      #endif 
      return O;
    } 
  #else
    fragout1 mainPS(pixdata I,
                    uniform sampler2D texture0,
                    uniform float4 shadow_data)
    {
      fragout1 O;
      #ifdef IS_OPAQUE 
        O.col = float4( 0,0,0,1 );
      #else
        O.col = tex2D(texture0, I.texcoord0.xy);
      #endif
      return O;
    } 
  #endif
#endif

////////////////////////////////////////////////////////////////
//SPASS_CUBEMAPSHADOW pixel shader (>=SM2_0)
////////////////////////////////////////////////////////////////
#ifdef PS_SPASS_CUBESHADOWMAP_20
  fragout1 mainPS(pixdata I,
                  uniform sampler2D texture0,
                  uniform float4    light_data)
  {
	  fragout1 O;
	  // need opacity-channel, since this is shadowmapping!
	  float4 tex0 = tex2D(texture0, I.texcoord0.xy);
	  // square distance of scaled
	  float3 li_to_pix_w_s = light_data.z * I.li_to_pix_w.xyz;

  //*
      // G16R16
	  #ifdef USE_EARLY_OUT
	    clip( tex0.a-0.01 );
	  #endif
	  O.col.r = saturate( length(li_to_pix_w_s) );
	  O.col.g = saturate( dot(li_to_pix_w_s,li_to_pix_w_s) );
	  O.col.b = 0.f;
	  #ifdef USE_EARLY_OUT
	    O.col.a = tex0.a;
	  #else
	    O.col.a = 1;
	  #endif
	  return O;
  /*/
	  float dist = saturate( length(li_to_pix_w_s) );
	  // endcode it in rgb!!
	  float3 depth_encoded = dist * float3(1.0, 256.f, 256.f * 256.f);
	  // do not put the .x component through the frac, this gives 0.0 for 1.0 -> ERRORs
	  depth_encoded.yz = frac(depth_encoded.yz);
	  // pass it to texture
	  #ifdef USE_EARLY_OUT
		O.col = float4(depth_encoded, tex0.a);
	  #else
		O.col = float4(depth_encoded, 1);
	  #endif
	  return O;
  //*/
  } 
#endif


/////////////////////////////////////////////////
//SPASS_AMBDIF pixel shader (>=SM2_0)
/////////////////////////////////////////////////
#ifdef PS_SPASS_AMBDIF_NONORMAL_20 
  fragout2 mainPS(pixdata I,
                  uniform sampler2D texture0,
                  uniform sampler2D shadow_map,
                  uniform sampler2D fog_texture,
                  uniform sampler3D textureVolume,
                  uniform float4    light_col_amb,
                  uniform float4    light_col_diff,
                  uniform float4    param,
                  uniform float4    materialID )
  {
    fragout2 O;
    	    
  	half4  tex_diffuse = tex2D(texture0, I.texcoord0.xy);
  	tex_diffuse.rgb		 = srgb2linear( tex_diffuse.rgb );
  	
    s2half3 diffuse    = tex_diffuse.xyz;
    s2half3 specular   = 0.f;
    clip( tex_diffuse.a-0.5f );

    s2half3 normal = normalize( I.normal );

    // set output color
    O = CalcSunlight( s2half4(diffuse, 1 ),
                      s2half4(normal, materialID.x ),
                      s2half4(specular, 0 ),
                      I.posInLight,
                      I.pix_to_cam,
                      -I.li_to_pix_w,
                      light_col_amb,
                      light_col_diff,
                      shadow_map,
                      textureVolume //Brdf_Sampler
     );
    O.col[0].rgb = linear2srgb(O.col[0].rgb);
    O.col[1].rgb = linear2srgb(O.col[1].rgb);
    O.col[0].a   = calcHoleAlpha(I.hpos, param.x);

    return O;
  }
#endif


/////////////////////////////////////////////////
//SPASS_PNT pixel shader (>=SM2_0)
/////////////////////////////////////////////////
#ifdef PS_SPASS_PNT_NONORMAL_20
  fragout2 mainPS(pixdata I,
      uniform sampler2D texture0,
      uniform sampler2D fog_texture,
      uniform float4 light_col_diff,
      uniform float4 light_data,
      uniform float4    param)
  {
	  fragout2 O;

	  // get texture values
	  s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);

	  // get normal vector from bumpmap texture
	  s2half3 nrm = normalize(I.normal.xyz);

	  // calc diffuse
	  s2half3 l0_dir = normalize(I.pix_to_li.xyz);
	  s2half4 diffuse = saturate(dot(l0_dir, nrm)) * light_col_diff;

	  // calc distance of light
	  float dist_to_light = dot(I.pix_to_li.xyz, I.pix_to_li.xyz);
	  // build intensity from distance to light using light radius
	  s2half temp_dist = saturate(dist_to_light / (light_data.x * light_data.x));
	  s2half intensity = (1.0 - temp_dist) * (1.0 - temp_dist); // 1.0 - sin(1.5708 * temp_dist);
	  // multiply it by intensity of ight source
	  intensity *= light_data.y;
  #ifdef S2_FOG
    // attenuate by fog
    fogPnt( intensity, fog_texture, I.depthFog );
    //intensity *= (1.0 - tex2D( fog_texture, I.depthFog ).w);
  #endif

  #if TREE_HOLE
	  intensity *= calcHoleAlpha(I.hpos,param.x);
  #endif
	  O.col[0] = intensity * diffuse * tex0;
	  O.col[0].a = tex0.a;
	  O.col[1] = float4(0.0, 0.0, 0.0, 0.0);

	  return O;
  } 
#endif