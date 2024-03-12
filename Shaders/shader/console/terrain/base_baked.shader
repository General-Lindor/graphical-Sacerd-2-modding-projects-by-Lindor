//#OptDef:SPASS_G
//#OptDef:SPASS_SHADOWMAP

#include "S2Types.shader"

struct small_appdata
{
	float	height:position;
	float4	uvn:color;
};

struct appdata {
	float3 position   : POSITION;
	float3 normal     : NORMAL;
	float3 tangent    : TANGENT;
	float3 binormal   : BINORMAL;
	float2 texcoord   : TEXCOORD0;
};

#if defined(SPASS_SHADOWMAP)
  struct pixdata
  {
    float4 hposition  : POSITION;
    float2 pos        : TEXCOORD0;
  };
#else
  struct pixdata
  {
    float4 hposition            : POSITION;
    #if defined(SPASS_G)  
#ifdef PS3_IMPL
      float2 texcoord           : TEXCOORD0;
#else
      float3 texcoord           : TEXCOORD0;
#endif
      float3 matrix_TS_to_WS[3] : TEXCOORD1;
    #endif
  };
#endif
struct fragout
{
  s2half4 col0  : COLOR0;
  s2half4 col1  : COLOR1;
  s2half4 col2  : COLOR2;
};

//////////////////////////////////////////////////
// VERTEX SHADER
//////////////////////////////////////////////////

pixdata mainVS(  small_appdata    sI
				,uniform float4   weather_pos
				,uniform float4x4 worldViewProjMatrix
				,uniform float4x4 worldMatrix
				,uniform float4   param
#if defined(XENON_IMPL) && !defined(SPASS_SHADOWMAP)
                ,uniform float4   jitter_data
#endif
				)
{
	pixdata VSO;
	appdata I;
#if defined(SPASS_SHADOWMAP)
    // Do all the decompression here, compiler will optimize and remove unused calculations
	// Please do not change this code, as it has been carefully reordered to trick the optimizer
	// <<SH>>: 256.f/6.f is wrong, but it prevents gaps in the shadowmap
	// vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv	
	float4 scaler = sI.uvn.xyxy * float4(weather_pos.zw,1,1)*256.f/6.f;	// Rescale from 0/255..6/255 to 0..1
	I.position = float3(scaler.xy + weather_pos.xy, sI.height);
	I.texcoord.xy = scaler.zw;	
	// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    
    // Pass vertex position in clip space to rasterizer
	float4 pos4 = float4( I.position, 1.0 );
    VSO.hposition = mul( pos4, worldViewProjMatrix );
    VSO.pos = VSO.hposition.zw;
#else
	// Do all the decompression here, compiler will optimize and remove unused calculations
	// Please do not change this code, as it has been carefully reordered to trick the optimizer
	// vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv	
	float4 scaler = sI.uvn.xyxy * float4(weather_pos.zw * 42.5, 42.5, 42.5);	// Rescale from 0/255..6/255 to 0..1
	I.position = float3(scaler.xy + weather_pos.xy, sI.height);
	I.texcoord.xy = scaler.zw;	
	// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    // Pass vertex position in clip space to rasterizer
	float4 pos4 = float4( I.position, 1.0 );
    VSO.hposition = mul( pos4, worldViewProjMatrix );

    #if defined(XENON_IMPL)
	  VSO.hposition.xy += jitter_data.xy*VSO.hposition.ww;
    #endif
    
	#if defined(SPASS_G)
         #ifdef PS3_IMPL
                worldMatrix=transpose(worldMatrix);
         #endif
		I.normal.xy = sI.uvn.zw*2-1;
		I.normal.z = sqrt(1-dot(I.normal.xy,I.normal.xy));
		
		I.binormal = normalize(cross(float3(I.normal.z, 0, -I.normal.x), I.normal));
		I.tangent  = normalize(cross(I.normal, float3(0, I.normal.z, -I.normal.y)));

		// the textures of all visible patches are baked into one large texture per frame
		// the param values offset and scale the patch's texture coordinates into this large baked texture
		// we pass the transformed TCs in xy and the untransformed TCs in zw
		VSO.texcoord.x = I.texcoord.x * param.z + param.x;
#ifdef PS3_IMPL
		VSO.texcoord.y = I.texcoord.y * param.w + param.y;
#else
#ifdef LAYER_BIT0
		VSO.texcoord.y = I.texcoord.y * param.w + param.y;
		VSO.texcoord.z = I.texcoord.y * param.w + param.y;
#else
		VSO.texcoord.y = (I.texcoord.y * param.w + param.y)*0.5;
		VSO.texcoord.z = (I.texcoord.y * param.w + param.y)*0.5 + 0.5;
#endif
#endif
		float3x3 invTangentSpaceMatrix;
		invTangentSpaceMatrix[0] = - I.tangent;
		invTangentSpaceMatrix[1] = - I.binormal;
		invTangentSpaceMatrix[2] =   I.normal;
		
		#ifdef PS3_IMPL
			float3x3 mattmp = mul( worldMatrix, invTangentSpaceMatrix );
		#else
			float3x3 mattmp = mul( invTangentSpaceMatrix, worldMatrix );
		#endif	
		VSO.matrix_TS_to_WS[0] = mattmp[0];
		VSO.matrix_TS_to_WS[1] = mattmp[1];
		VSO.matrix_TS_to_WS[2] = mattmp[2];
	#endif
#endif  
	return VSO;
}

#if defined(SPASS_G)
	#include "normalmap.shader"
	fragout mainPS(  pixdata            I
					,uniform sampler2D  texture0 // baked color texture
					,uniform sampler2D  texture1 // baked normal map
					,uniform float4     materialID
				  )
	{
		fragout PSO;
	  float4 tex0  = tex2D( texture0, I.texcoord.xy );
	  
	  // calc worldspace normal
#ifdef PS3_IMPL
	  s2half4 normal_TS = tex2D(texture1, I.texcoord.xy);
#else
	  s2half4 normal_TS = tex2D(texture1, I.texcoord.xz);
#endif
	  normal_TS.xyz = normal_TS.xyz*2-1;
	  
	  float3x3 TS_to_WS = { normalize(I.matrix_TS_to_WS[0]), 
							normalize(I.matrix_TS_to_WS[1]), 
							normalize(I.matrix_TS_to_WS[2]) };
	#ifdef PS3_IMPL
	  s2half3 normal_WS = mul( TS_to_WS, normal_TS.xyz );
	#else
	  s2half3 normal_WS = mul( normal_TS.xyz, TS_to_WS );
	#endif  
	  
	  s2half3 diffuse = tex0.xyz;
	  s2half3 normal = normal_WS;
	  s2half3 specular = normal_TS.a;
	  //EncodeNormal( normal, specular );
	  normal = normalize(normal)*0.5 + 0.5;

	  s2half texCoord = dot(I.texcoord.xy, s2half2( 0.5, 0.5 ) ); //Kind of texcoord-hash for motion-FSAA
	  PSO.col0 = s2half4( diffuse,  texCoord );
	  PSO.col1 = s2half4( normal,   materialID.x );
#ifdef LAYER_BIT0
      //No specular for prebaked texture
	  PSO.col2 = s2half4( 0, 0, 0, 0 );
#else
	  PSO.col2 = s2half4( specular, 0 );
#endif 

	  return PSO;
	}
#elif defined(XENON_IMPL)&&defined(SPASS_SHADOWMAP)
	s2half4 mainPS( pixdata I ) : COLOR0
	{
	  float fDist = I.pos.x/I.pos.y;
	  return s2half4( fDist, fDist*fDist, 0.0, 0.0 );
	}
#elif defined(PS3_IMPL)
	s2half4 mainPS( pixdata I ) : COLOR0
	{
	  return s2half4( 0.0, 0.0, 1.0, 0.0 );
	}
#endif