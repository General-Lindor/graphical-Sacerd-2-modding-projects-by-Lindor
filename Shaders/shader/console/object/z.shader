//#OptDef:LAYER_BIT0
//#OptDef:IS_OPAQUE
//#OptDef:SPASS_ZONLY
//#OptDef:SPASS_G

#include "s2types.shader"

struct appdata {
	float3 position   : POSITION;
	float3 normal     : NORMAL;
	float3 tangent    : TANGENT;
	float3 binormal   : BINORMAL;
	float2 texcoord   : TEXCOORD0;
	float2 data       : TEXCOORD1;
};

#if defined(SPASS_ZONLY)
  struct pixdata 
  {
    float4 hposition  : POSITION;
    #ifndef IS_OPAQUE
      float4 texcoord0  : TEXCOORD0;
    #endif
  };
#else
  struct pixdata {
    float4 hposition          : POSITION;
    float4 texcoord0          : TEXCOORD0;
    float3 matrix_TS_to_WS[3] : TEXCOORD1;
  };
#endif

#include "shadow.shader"

pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix
#if defined(XENON_IMPL) && !defined(SPASS_SHADOWMAP)	    
    ,uniform float4   jitter_data
#endif    
#ifndef SPASS_ZONLY	    
    ,uniform float4x4 worldMatrix
    ,uniform float4x4 lightMatrix
    ,uniform float4   zfrustum_data
#endif
    )
{
	pixdata O;
	
	// vertex pos
	O.hposition = mul( float4(I.position, 1.0), worldViewProjMatrix);
#if defined(XENON_IMPL) && !defined(SPASS_SHADOWMAP)	
	O.hposition.xy += jitter_data.xy*O.hposition.ww;
#endif
	
#if !defined(IS_OPAQUE) || !defined(SPASS_ZONLY)
	// only have one texture, so pass texture coords...
	O.texcoord0 = I.texcoord.xyyy;
#endif

#ifndef SPASS_ZONLY	
  #ifdef PS3_IMPL
	worldMatrix = transpose(worldMatrix);
  #endif
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
	return O;
}

#if defined(SPASS_ZONLY)
  #ifndef IS_OPAQUE
    float4 mainPS( pixdata I, uniform sampler2D texture0 ) : COLOR0
    {
      return tex2D(texture0, I.texcoord0.xy);
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

  struct fragout {
    float4 diffuse  : COLOR0;
    float4 normal   : COLOR1;
    float4 specular : COLOR2;
  };

  fragout mainPS(pixdata I
      ,uniform sampler2D texture0
      ,uniform sampler2D texture1
      ,uniform sampler2D texture2
  #ifdef LAYER_BIT0    
      ,uniform sampler2D texture3
      ,uniform float4    pix_data_array
  #endif    
      ,uniform float4    materialID )
  {
    fragout O;

    s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
    s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
    #ifdef LAYER_BIT0
      s2half4 tex3 = tex2D(texture3, I.texcoord0.xy);
      if( pix_data_array.x )
        clip( - tex3.a );
    #endif
  
    // calc worldspace normal
    s2half3 normal_TS = ReadNormalMap2D(texture2, I.texcoord0.xy).xyz;
    //s2half3 normal_TS=s2half3(0,0,1);
    float3x3 TS_to_WS = { normalize(I.matrix_TS_to_WS[0]), 
                          normalize(I.matrix_TS_to_WS[1]), 
                          normalize(I.matrix_TS_to_WS[2]) };
    #ifdef PS3_IMPL
      s2half3 normal_WS = mul( TS_to_WS, normal_TS );
    #else
      s2half3 normal_WS = mul( normal_TS, TS_to_WS );
    #endif

    s2half3 diffuse = tex0.xyz;
    s2half3 normal = normal_WS;
    s2half3 specular = tex1.rgb;
    normal = normalize(normal)*0.5 + 0.5;

	s2half texCoord = dot(I.texcoord0.xy, s2half2( 0.5, 0.5 ) ); //Kind of texcoord-hash for motion-FSAA
    O.diffuse  = half4( diffuse,  texCoord );
    #ifdef LAYER_BIT0  
      O.normal   = half4( normal,   (tex3.a>0.5f) ? materialID.x : materialID.y );
    #else  
      O.normal   = half4( normal,   materialID.x );
    #endif  
    O.specular = half4( specular, tex1.a );

    return O;
  }
#endif