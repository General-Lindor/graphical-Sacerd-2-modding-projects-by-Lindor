// granny2 object shadowmap
#include "S2Types.shader"

struct appdata {
	float3 position   : POSITION;
	float3 normal     : NORMAL;
  #ifndef IS_OPAQUE 
	float2 texcoord   : TEXCOORD0;
  #endif
};

struct pixdata {
	float4 hposition  : POSITION;
    #ifdef XENON_IMPL
		float4 hpos		  : TEXCOORD0;
		#ifndef IS_OPAQUE 	
			float4 texcoord0  : TEXCOORD1;
		#endif
    #else
		#ifndef IS_OPAQUE 	
			float4 texcoord0  : TEXCOORD0;
		#endif
    #endif
};

pixdata mainVS(appdata I,
    uniform float4x4 lightMatrix)
{
	pixdata O;
	float4 pos4 = float4(I.position, 1.0);

	// vertex pos
	O.hposition = mul(pos4, lightMatrix);
	
  #ifdef XENON_IMPL
    O.hpos = O.hposition;
  #endif
  
  #ifndef IS_OPAQUE 
	// pass texcoords to fragment shader
	O.texcoord0 = I.texcoord.xyyy;
  #endif
  
	return O;
}

#if defined(PS3_IMPL)
  fragout mainPS(pixdata   I,
         uniform sampler2D texture0 )
  {
    fragout O;
    #ifdef IS_OPAQUE 
		O.col = float4(1,0,0,0);
    #else
		O.col = tex2D(texture0, I.texcoord0.xy);
    #endif
    return O;
  }
#elif defined(XENON_IMPL)
  half4 mainPS( pixdata I,
        uniform sampler2D texture0 ) : COLOR0
  {
    float fDist = I.hpos.z/I.hpos.w;
    #ifdef IS_OPAQUE
	  return half4( fDist, fDist*fDist, 0.0, 0.0 );
    #else
	  return half4( fDist, fDist*fDist, 0.0, tex2D(texture0, I.texcoord0.xy).a );
    #endif
  }
#endif