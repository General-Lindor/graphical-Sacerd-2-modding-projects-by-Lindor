#ifdef  XENON_IMPL
#define V_FETCHING
#endif

//Vertex shader input
struct appdata
{
	float4 position    : POSITION;
	float4 normal      : NORMAL;
	float2 texcoord    : TEXCOORD0;
  float4 color       : COLOR;
};

#ifdef SPASS_ZONLY
	struct pixdata
	{
		float4 hposition  : POSITION;
		#ifndef IS_OPAQUE
		  float4 data1  : TEXCOORD0;
		#endif

	};
#ifndef IS_OPAQUE
	#define VS_OUT_data1
#endif
	#define VS_OUT_hposition
#endif

#ifdef SPASS_G
	/////////////////////////////////////
	// SPASS_G setup
	/////////////////////////////////////
	#define VS_OUT_G_20
	#define PS_G_20

	#ifdef VS_OUT_G_20
	  struct pixdata
	  {
		float4 hposition  : POSITION;
		float4 data1      : TEXCOORD0;
		float3 normal     : TEXCOORD1;
		float4 color      : COLOR;
	  };
	  #define VS_OUT_hposition
	  #define VS_OUT_data1
	  #define VS_OUT_NORMAL
	  #define VS_OUT_color
	#endif
#endif

#if defined(PS3_IMPL) && defined(SPASS_PNT)
	/////////////////////////////////////
	// SPASS_PNT setup
	/////////////////////////////////////
	#define VS_OUT_PNT
	#define PS_PNT_20

	struct pixdata
	{
		float4 hposition   : POSITION;
		float4 texcoord    : TEXCOORD0;
		float4 pix_to_li   : TEXCOORD1;
  		float4 li_to_pix_w : TEXCOORD2;
		float2 depthFog    : TEXCOORD3;
	};
	#define VS_OUT_hposition
	#define VS_OUT_texcoord
	#define VS_OUT_pix_to_li
	#define VS_OUT_li_to_pix_w
	#define VS_OUT_depthFog
#endif


#include "extractvalues.shader"
#include "shadow.shader"

#ifdef V_FETCHING

// sampler vertexSampler : register(s0); 
// sampler instanceSampler : register(s1); 
// 
appdata ReadInstancedVertex(int nIndex:INDEX, int nNumVertsPerInstance)
{
  appdata V;

  int nInstanceIndex = ( nIndex + .5 ) / nNumVertsPerInstance;


  // Vertex Data
  half4   Position_Tu;  // W contains the TU
  half4   Normal_Tv;    // A contains the TV*255

  // Instance Data
  half4   Offset_Scale;     // Contains position offset and scaling factor
  half4   Nx_Ny;            // Since all look up, we can generate Nz in shader
  int4    Rot_ModelOffset;  // Rotation around the normal and base vertex offset

  // Get per vertex data. 
  // Get per instance data
  asm
  {
    vfetch Offset_Scale, nInstanceIndex, position1, UseTextureCache = true;
    vfetch Nx_Ny, nInstanceIndex, normal1, UseTextureCache = true;
    vfetch Rot_ModelOffset, nInstanceIndex, texcoord0, UseTextureCache = true;
   };

  int nIndexOfIndex = nIndex - ( nInstanceIndex * nNumVertsPerInstance ) + Rot_ModelOffset.y;

  asm
  {
    vfetch Position_Tu, nIndexOfIndex, position0;
    vfetch Normal_Tv, nIndexOfIndex, normal0;
  };


  V.position = float4(Position_Tu.xyz, 1);
  V.normal   = float4(Normal_Tv.xyz,   0);
  V.texcoord = float2(Position_Tu.w,   Normal_Tv.w) * 2048;
  V.color    = float4(1,1,1,1);

  // first rotate the position

  float s,c;

  sincos(Rot_ModelOffset.x / 2048, s, c);

  // Moved this into the matrix
  V.position.xy = float2(V.position.x*c-V.position.y*s , V.position.x*s+V.position.y*c);
  V.normal.xy = float2(V.normal.x*c-V.normal.y*s , V.normal.x*s+V.normal.y*c);

  // Now create the transformation matrix
  float4x4 theMatrix;
  float4 vec_z = float4(Nx_Ny.xy,sqrt(1-dot(Nx_Ny.xy,Nx_Ny.xy)),0);
  float4 vec_x = float4(normalize(cross(float3(1,0,0), vec_z.xyz)), 0);
  float4 vec_y = float4(cross(vec_z.xyz, vec_x.xyz), 0);

  theMatrix = float4x4( vec_x, vec_y, vec_z, float4(0,0,0,1));
//   // And now update the vertex data
  V.position = mul( V.position , theMatrix  );
  V.normal   = mul( V.normal   , theMatrix  );
// 
  V.position.xyz = V.position.xyz * Offset_Scale.www + Offset_Scale.xyz;

  return V;
}

pixdata mainVS(	int nIndex:INDEX,
#else
pixdata mainVS(	appdata I,
#endif
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 invWorldMatrix,
    uniform float4x4 worldMatrix,
    uniform float4x4 lightMatrix,
    uniform float4   light_pos,
    uniform float4   camera_pos,
    uniform lightData globLightData,
    uniform float4   param,
    uniform float4   zfrustum_data,
    uniform float4   fog_data
#if defined(XENON_IMPL) && !defined(SPASS_SHADOWMAP)	    
   ,uniform float4   jitter_data
#endif      
    )
{
	pixdata O;

#ifdef V_FETCHING
  appdata I = ReadInstancedVertex(nIndex, param.y);
	float4 nrm4 = float4(I.normal.xyz, 0.0);
#else
  float4 nrm4 = float4(I.normal.xyz * 2.0 - 1.0, 0.0);
#endif

	float4 pos4 = float4(I.position.xyz, 1.0);

  // convert light pos from worldspace into objectspace
  float4 l_pos_obj = mul(light_pos, invWorldMatrix);
  // build vector from vertex pos to light pos
  float3 pix_to_li     = l_pos_obj.xyz - pos4.xyz;
  float3 pix_to_li_nrm = normalize(pix_to_li);


  #ifdef VS_OUT_hposition
	  // vertex pos
	  O.hposition = mul(pos4, worldViewProjMatrix);
	  #if defined(XENON_IMPL) && !defined(SPASS_SHADOWMAP)	
        O.hposition.xy += jitter_data.xy*O.hposition.ww;
      #endif
  #endif

	#ifdef VS_OUT_screencoord
    // vertex-position in screen space
    O.screenCoord.x = O.hposition.w + O.hposition.x;
    O.screenCoord.y = O.hposition.w - O.hposition.y;
    O.screenCoord.z = 0.0;
    O.screenCoord.w = 2.0 * O.hposition.w;
    O.screenCoord.xy *= target_data.xy;
	#endif

  #ifdef VS_OUT_depthFog
    O.depthFog = getFogTCs( O.hposition.w, fog_data );
  #endif

    // put (normalized!) distance
  float distance = (O.hposition.w - zfrustum_data.x) * zfrustum_data.z;

	#ifdef VS_OUT_posInLight
	  // vertex pos in light-space
	  O.posInLight = mul(pos4, lightMatrix);
	#endif


  #ifdef VS_OUT_data0
	  // calc texturecoords for rg(b)-depth encoding
	  O.depthUV = float4(distance * float2(1.0, 256.0), 0.0, O.hposition.w*zfrustum_data.w);
  #endif	

  #ifdef VS_OUT_data1
	  float diffuse = dot(light_pos.xyz, nrm4.xyz);
	  diffuse = max(0.0,diffuse);
	  diffuse = diffuse + param.x;
	  diffuse = min(diffuse, 1.0);

	  // compose data (diffuse + texcoords + minitypeID)
	  O.data1 = float4(I.texcoord.x / 2048.0, I.texcoord.y / 2048.0, diffuse, param.x);
	#endif
	
  #ifdef VS_OUT_li_to_pix_w
	  // convert vertex-pos from object to worldspace
	  float4 v_pos_w = mul(pos4, worldMatrix);
	  // pass light-to-pixel to fragment-shader
	  O.li_to_pix_w = v_pos_w - light_pos;
  #endif 

  #ifdef VS_OUT_color
	  O.color = I.color;
  #endif
  #ifdef VS_OUT_texcoord
	  // pass texture coords
	  O.texcoord = I.texcoord.xyyy / 2048.0;
  #endif
  #ifdef VS_OUT_pix_to_li
	  // calc diffuse
	  float diffuse = dot(pix_to_li_nrm, nrm4.xyz);// + bin.y;
	  // store pix2li and diffuse in one vector
	  O.pix_to_li = float4(pix_to_li, diffuse);
  #endif
  
  #ifdef VS_OUT_lightDir
	  // convert light pos from worldspace into objectspace
	  float4 l_dir_obj = mul(light_pos, invWorldMatrix);
	  // store light vector & dot
	  O.lightDir = float4(l_dir_obj.xyz, dot(nrm4.xyz, l_dir_obj.xyz));
  #endif

 	#ifdef VS_OUT_lighting_11
  	O.shadowCoord = mul(pos4, lightMatrix);

	  float3 worldVertPos = mul(pos4, worldMatrix);
	  float3 worldVertNormal = normalize(mul(nrm4.xyz, (float3x3) worldMatrix));
  	O.diffuse = calcDiffuseLightShadowed(worldVertPos, worldVertNormal, globLightData, O.mainDiffuseLight, O.lightRelPos);
 	#endif

 	#ifdef VS_OUT_NORMAL
    	  // O.normal = nrm4.xyz;
    	  O.normal = normalize(mul(nrm4.xyz, (float3x3) worldMatrix));
 	#endif

	#ifdef VS_OUT_lowendFog
  O.fog = calcFog(O.hposition, fog_data);
	#endif

	return O;
}

#ifdef SPASS_ZONLY
  #ifndef IS_OPAQUE
    float4 mainPS( pixdata I, uniform sampler2D texture0 ) : COLOR0
    {
    	float4 tex0 = tex2D(texture0, I.data1.xy);
    	clip( tex0.a - 0.5f );
	    return float4( 1, 0, 0, tex0.a );
    } 
  #else
//	#ifndef XENON_IMPL
	  float4 mainPS() : COLOR0
	  {
	    return float4( 1, 0, 0, 1 );
	  }
//	#endif
  #endif
#else
	#include "normalmap.shader"
	struct fragout3 {
	  float4 col0 : COLOR0;
	  float4 col1 : COLOR1;
	  float4 col2 : COLOR2;
	};

	fragout3 mainPS(pixdata I
			 ,uniform sampler2D texture0
		 ,uniform float4    materialID )
	{
		fragout3 O;
		float4 tex0 = tex2D(texture0, I.data1.xy) * I.color;
	    
		clip( tex0.a - 0.5f );
	    
		s2half3 diffuse = tex0.xyz;
	  s2half3 normal = normalize(I.normal);
	  s2half3 specular = 0.1; // fixed specular of 0.1 for miniobjects
	  //EncodeNormal( normal, specular );
	  normal = normalize(normal)*0.5 + 0.5;

	  s2half texCoord = dot(I.data1.xy, s2half2( 0.5, 0.5 ) ); //Kind of texcoord-hash for motion-FSAA
	  O.col0 = half4( diffuse,  texCoord );
	  O.col1 = half4( normal,   materialID.x );
	  O.col2 = half4( specular, 0 );

      return O;
	}
#endif