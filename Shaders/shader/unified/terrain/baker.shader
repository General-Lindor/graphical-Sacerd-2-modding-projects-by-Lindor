// terrain baker

//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:LAYER_BIT2
//#OptDef:LAYER_BIT3
//#OptDef:NORMALFORMAT_565
//#OptDef:NORMALFORMAT_88
#include "extractvalues.shader"

#ifdef LAYER_BIT0
  #define DIFFUSE_PASS
#endif

#ifdef LAYER_BIT1
  #define NORMAL_PASS
#endif

#ifdef LAYER_BIT2
  #define FIRST_PASS
#endif

#ifdef LAYER_BIT3
  #define SECOND_PASS
#endif



#ifdef SM1_1
  #define PS_2PASS
#else
  #define PS_1PASS
#endif


// general Vertex Shader input used by all variants
struct appdata {
	float3 position   : POSITION;
	float3 normal     : NORMAL;
	float3 tangent    : TANGENT;
	float3 binormal   : BINORMAL;
	float2 texcoord   : TEXCOORD0;
	float2 data       : TEXCOORD1;
};

struct small_appdata 
{
    float height : position ;
    float4 uvn : color ;
};

// Vertex Shader Output
#ifdef SM1_1
  struct pixdata
  {
	  float4 hposition  : POSITION;
	  float4 steigung   : COLOR0;
	  float2 texcoord0  : TEXCOORD0;
	  float2 texcoord1  : TEXCOORD1;
	  float2 texcoord2  : TEXCOORD2;
	  float2 texcoord3  : TEXCOORD3;
  };
#else
  struct pixdata 
  {
	  float4 hposition  : POSITION;
	  float4 texcoord   : TEXCOORD0;
  };
#endif

// Output fragment
struct fragout
{
	float4 col        : COLOR;
};


pixdata mainVS( small_appdata sI, uniform float4 param )
{
	appdata I;
	// Do all the reformatting here, compiler will optimize
	float3 rUV = float4(sI.uvn.xy * 42.5f,1,0);	// Rescale from 0/255..6/255 to 0..1
	
	I.position = float3(0,0,0);
	
	I.data.xy = I.texcoord.xy = rUV.xy;
	
	I.normal.xy = sI.uvn.zw*2-1;
	I.normal.z = sqrt(1-dot(I.normal.xy,I.normal.xy));
	
	I.binormal = normalize(cross(I.normal, float3(I.normal.z, 0, -I.normal.x)));
	I.tangent  = normalize(cross(I.normal, float3(0, I.normal.z, -I.normal.y))); 
	

	pixdata VSO;
 	float4 pos4 = float4(I.position, 1.0);
	float4 nrm4 = float4(I.normal, 0.0);

  // do not use ::position but use ::texcoord for vertex-pos, since we do this one planar!!
  float2 planar_pos = float2(2.0, -2.0) * (I.texcoord.xy - float2(0.5, 0.5));
	VSO.hposition = float4(planar_pos, 0.0, 1.0);

  // calc steigung for aufbrechen
  float steigung = saturate(dot(nrm4.xyz, float3(0.0, 0.0, 1.0)));

#ifdef SM1_1
  VSO.steigung = float4(steigung, steigung, steigung, steigung);

  #ifdef NORMAL_PASS
    // pass texcoords
	  VSO.texcoord0 = VSO.texcoord1 = VSO.texcoord2 = VSO.texcoord3 = I.texcoord.xy;
  #else
    // pass texcoords
	  float2 uv = I.texcoord.xy;
	  uv.x = uv.x * param.x + param.y;
	  uv.y = uv.y * param.x + param.y;
	  VSO.texcoord0 = VSO.texcoord1 = VSO.texcoord2 = VSO.texcoord3 = uv;
  #endif
#else
  // pass texcoords
	VSO.texcoord = float4(I.texcoord.xyy, steigung);
	VSO.texcoord.x = VSO.texcoord.x*param.x+param.y;
	VSO.texcoord.y = VSO.texcoord.y*param.x+param.y;
#endif

	return VSO;
}


//----------- Used by SM_1_1 renderer ------------------- //

#ifdef PS_2PASS
fragout mainPS(pixdata I,
		uniform sampler2D texture0,
		uniform sampler2D texture1,
		uniform sampler2D texture2,
		uniform sampler2D texture3,
		uniform sampler2D texture4,
		uniform sampler2D texture5,
		uniform sampler2D texture6
#ifdef NORMAL_PASS
   ,uniform float4    light_pos
#endif    
                                )
{
	fragout PSO;

  PSO.col = float4(0.0f, 0.0f, 0.0f, 1.0);

// first pass: t0, sb, alpha_mask and relax_limit
#ifdef FIRST_PASS
  // sample all needed
  s2half4 t0 = tex2D(texture0, I.texcoord0.xy);
  s2half4 sb = tex2D(texture4, I.texcoord1.xy);
  s2half4 alpha_mask = tex2D(texture5, I.texcoord2.xy);
  s2half4 relax_limit = tex2D(texture6, I.texcoord3.xy);

  // standard or sub for base layer?
  float4 output;
  if(I.steigung.x >= relax_limit.w)
	  output = t0;
  else
	  output = sb;

  output *= alpha_mask.x;

  #ifdef DIFFUSE_PASS
 	  // out
    PSO.col = float4(output.xyz, 1.0);
  #endif
  #ifdef NORMAL_PASS
	  float lightAmount = saturate( dot( output.xyz, light_pos.xyz ) ) * alpha_mask.x;
    // out
    PSO.col = float4(lightAmount, lightAmount, lightAmount, lightAmount);
  #endif
#endif

// second pass: t1, t2, t3 and alpha_mask
#ifdef SECOND_PASS
	// sample all needed
  s2half4 t1 = tex2D(texture1, I.texcoord0.xy);
  s2half4 t2 = tex2D(texture2, I.texcoord1.xy);
  s2half4 t3 = tex2D(texture3, I.texcoord2.xy);
  s2half4 alpha_mask = tex2D(texture5, I.texcoord3.xy);

  float4 output = alpha_mask.y * t1 + alpha_mask.z * t2 + alpha_mask.w * t3;
  

  #ifdef DIFFUSE_PASS
	  // out
    PSO.col = float4(output.xyz, 1.0);
  #endif
  #ifdef NORMAL_PASS
    float lightAmount = saturate( dot( output, light_pos ) ); // CHANGE LATER!!! incorrect!
    // out
    PSO.col = float4(lightAmount, lightAmount, lightAmount, lightAmount);
  #endif
#endif

  return PSO;
}
#endif





//--------------- Used by >= SM_2_0 renderer ---------------//

#ifdef PS_1PASS
fragout mainPS(pixdata I,
		uniform sampler2D texture0,
		uniform sampler2D texture1,
		uniform sampler2D texture2,
		uniform sampler2D texture3,
		uniform sampler2D texture4,
		uniform sampler2D texture5,
		uniform sampler2D texture6 )
{
	fragout PSO;

	// sample all needed
	s2half4 alpha_mask = tex2D(texture5, I.texcoord.xy);
	s2half4 relax_limit = tex2D(texture6, I.texcoord.xy);


#ifdef DIFFUSE_PASS
	s2half4 t0 = tex2D(texture0, I.texcoord.xy);
	s2half4 t1 = tex2D(texture1, I.texcoord.xy);
	s2half4 t2 = tex2D(texture2, I.texcoord.xy);
	s2half4 t3 = tex2D(texture3, I.texcoord.xy);
	s2half4 sb = tex2D(texture4, I.texcoord.xy);

  // standard or sub for base layer?
	float4 output;

	if(I.texcoord.w > relax_limit.w)
		output = t0;
	else
		output = sb;

  output *= alpha_mask.x;

 	// add all other layers
  output += alpha_mask.y * t1 + alpha_mask.z * t2 + alpha_mask.w * t3;
  
	// out
  PSO.col = float4( output.xyz, 1.0 );
#endif
 
#ifdef NORMAL_PASS
	s2half4 t0 = tex2D(texture0, I.texcoord.xy);
	s2half4 t1 = tex2D(texture1, I.texcoord.xy);
	s2half4 t2 = tex2D(texture2, I.texcoord.xy);
	s2half4 t3 = tex2D(texture3, I.texcoord.xy);
	s2half4 sb = tex2D(texture4, I.texcoord.xy);

  // standard or sub for base layer?
	float4 output;

  if( I.texcoord.w >relax_limit.w )
    output = t0;
  else
    output = sb;

  output *= alpha_mask.x;

 	// add all other layers
  output += alpha_mask.y * t1 + alpha_mask.z * t2 + alpha_mask.w * t3;
  #ifdef NORMALFORMAT_565
	  // out
    PSO.col = float4( output.xy, output.z, 1.0 );
  #else
    // re-normalize
    output.xyz = normalize( output.xyz - float3( 0.5, 0.5, 0.5 ) );
    // put back in half-space
    output.xyz = 0.5 * ( output + float3( 1.0, 1.0, 1.0 ) );
	  // out
    PSO.col = float4( output.xy, output.w, 1.0 );
  #endif
#endif  //NORMAL_PASS
  return PSO;
} 
#endif
