//#OptDef:LAYER_BIT0 // no sun shadow
//#OptDef:SPASS_LIGHTNING

#ifdef PS3_IMPL
  #define SQRT(a) sqrt(max(0.0001,a))
  #define POW(x,y) pow(max(x,0.0001),y)
  #define MUL(a,b) mul(b,a)
  #define REAL_MUL(a,b) mul(a,b)
#else
  #define SQRT(a) sqrt(a)
  #define POW(x,y) pow(y)
  #define MUL(a,b) mul(a,b)
  #define REAL_MUL(a,b) mul(a,b)
#endif

#include "extractvalues.shader"
//--------------------------------------------------------------------------------------
// Shader globals
//--------------------------------------------------------------------------------------
  sampler2D   DepthSampler        : register(s0); // Z-Buffer
  sampler2D   DiffuseSampler      : register(s1); // DiffuseColor
  sampler2D   NormalSampler       : register(s2); // Normal.rgb
  sampler2D   SpecularSampler     : register(s3); // SpecularInt + GlowIntensity
  sampler2D   FogSampler          : register(s4); // Fog
  sampler2D   Brdf_Sampler        : register(s5);
  sampler2D   ShadowSampler       : register(s6); // ShadowMap  
  #ifdef XENON_IMPL
    samplerCUBE PntShadowSampler[8] : register(s8);
  #else
    samplerCUBE PntShadowSampler[8] ; //TB: This is somewhat hackish, because Cgc sucks and sets *all* samplers ro s8...
  #endif

//--------------------------------------------------------------------------------------
// Pixelshader constants
//--------------------------------------------------------------------------------------
float4x4 g_mLightMatrixCam       : register(  c0 );
float4   g_vShadowData	         : register(  c5 );
float4   g_vWeatherInfo          : register(  c6 );
s2half4  g_vLightningDirection   : register(  c7 );
s2half4  g_vLightningAmbient     : register(  c8 );
s2half4  g_vSunAmbient	         : register(  c9 );
s2half4  g_vSunAmbient2	         : register( c10 );
s2half4  g_vSunDiffuse           : register( c11 );
s2half4  g_vSunSpecular          : register( c12 );
s2half4  g_vSunAmbientSpecular   : register( c13 );
float4   g_vSunPosition          : register( c14 );
s2half4  g_vFogData              : register( c15 );
float4x4 g_mOldViewProj          : register( c16 );
s2half4  g_vJitterDir            : register( c20 );

sPntLightInfo  g_LightInfo[12]   : register( c21 );
sPntLightInfo  g_ShdLightInfo[8] : register( c69 );

uniform float3 g_UpperLeft       : register(c100); //upper left corner of view-plane
uniform float3 g_DeltaHorizontal : register(c101); //vector along horizontal borders of view-plane
uniform float3 g_DeltaVertical   : register(c102); //vector along vertical borders of view-plane
// 103 contains target_data

uniform float4 g_PlayerPos[2]    : register(c104); //position of the Players

//#define SHOW_SHADERS
//--------------------------------------------------------------------------------------
// Name: ScreenSpaceShaderVS()
// Desc: Pass-thru shader
//--------------------------------------------------------------------------------------
uniform float4 g_SpriteOffset : register (c100);

s2half4 mainVS( float4 vPosition : POSITION ) : POSITION
{
#ifdef PS3_IMPL
  return float4(vPosition.xy + g_SpriteOffset.xy,1,1);
#else
  float2 pos = vPosition*float2(0.5, -0.5)+0.5;
  pos = pos*g_SpriteOffset.zw;
  pos = pos*float2(2, -2)+float2(-1, 1);
  
  return float4( pos, 1.f, 1.f );
#endif
}

//--------------------------------------------------------------------------------------
// Name: DeferredShadow()
// Desc: calculate Depth from D24S8 Z-Buffer (write in red/green) 
//       and compute shadow-intensity (write in blue)
//--------------------------------------------------------------------------------------
struct fragout {
	half4 col     : COLOR0;
	half4 glow    : COLOR1;
#ifdef PS3_IMPL
	half4 colCopy : COLOR2;
#endif
};

#include "shadow_xenon.shader"
#include "sunlight_xenon.shader"
#include "debug_xenon.shader"
#include "normalmap.shader"

#ifdef SHOW_SHADERS
  #define LAYER_BIT0
#endif

#ifdef XENON_IMPL
fragout mainPS( float2 vPos : VPOS )
#else
fragout mainPS( float2 vPos : WPOS )
#endif
{
  fragout ret;
 
#ifdef XENON_IMPL  
  s2half4 vTexCoord = vPos.xyxy*tiling_data_deferred0 + tiling_data_deferred1;
  float3 In_TexCoord=g_UpperLeft+vTexCoord.zzz*g_DeltaHorizontal+vTexCoord.www*g_DeltaVertical;
#else
  s2half2 vTexCoord = (vPos+0.5.xx)*target_data.zw;
  float3 In_TexCoord=g_UpperLeft+vTexCoord.xxx*g_DeltaHorizontal+vTexCoord.yyy*g_DeltaVertical;
#endif

    /*****************/
   /* calc worldpos */
  /*****************/
  float z_world = DEPTH_SAMPLE_PREC(DepthSampler,vTexCoord.xy).x;
  
  float3 viewVec    = z_world * In_TexCoord;
  float  world_dist = z_world * Z_FAR; // using Z_FAR instead of length(In_TexCoord) is less accurate but cheaper
  
    /*****************/
   /* read textures */
  /*****************/  
  s2half4 tex_normal     = tex2D( NormalSampler,   vTexCoord.xy );
  s2half4 tex_diffuse    = tex2D( DiffuseSampler,  vTexCoord.xy );
  s2half4 tex_specular   = tex2D( SpecularSampler, vTexCoord.xy );
  float idColor          = tex_normal.a;

  float3 brdf_offset   = float3( 0.5/2048.f, 0.5f/32.f, 32.5/2048.f ) + idColor * float3( 255.f/32.f, 0.f, 255.f/32.f );
  float2 brdf_scale    = float2( 31.f/2048.f, 31.f/32.f );
  
  tex_normal             = float4(tex_normal.xyz * 2 - 1, tex_normal.z );
  tex_diffuse.rgb        = srgb2linear( tex_diffuse.rgb );
//  tex_specular.rgb       = srgb2linear( max(tex_specular.rgb, g_vWeatherInfo.x) );
  tex_specular.rgb       = srgb2linear(tex_specular.rgb );
  
  tex_specular.a = srgb2linear( float3(tex_specular.a, tex_specular.a, tex_specular.a) ).x;

  s2half3 playerLight = 0;

  {
    s2half2 playerDot= 0;
	s2half playerLightRangeMultiplier = 1.0f;
	s2half3 playerColor0 = s2half3(1.0, 1.0, 1.0);
	s2half3 playerColor1 = s2half3(1.0, 1.0, 1.0);

	s2half3 pLightPos0 = g_PlayerPos[0].xyz - viewVec;
	s2half3 pLightPos1 = g_PlayerPos[1].xyz - viewVec;
	s2half3 pLightDir0 = normalize(pLightPos0);
	s2half3 pLightDir1 = normalize(pLightPos1);

	pLightDir0.z = abs(pLightDir0.z);
	pLightDir1.z = abs(pLightDir1.z);

	playerDot.x = dot(pLightDir0.xyz, tex_normal.xyz);
	playerDot.y = dot(pLightDir1.xyz, tex_normal.xyz);
	s2half2  light_dist_sq = s2half2(dot(pLightPos0, pLightPos0),dot(pLightPos1, pLightPos1));
	s2half2 temp_dist = 1-saturate(light_dist_sq/(20000 * playerLightRangeMultiplier)); // we need to modify the range (as there is a buff/ability that can increase the range of the playerlight)
	playerDot *= s2half2(g_PlayerPos[0].w, g_PlayerPos[1].w); 
	playerDot *= temp_dist * temp_dist;
	playerDot = saturate(playerDot);
	playerLight = playerDot.x * playerColor0 + playerDot.y * playerColor1; 
  }

  /////////////////////////////////////////////////////////
  // FSAA and Edge-detection
  /////////////////////////////////////////////////////////
  ret.col.a = tex_diffuse.a + idColor;
//  #ifdef XENON_IMPL
//    {
//      float3  tex_normal2 = tex2D( NormalSampler,  vTexCoord.xy + g_vJitterDir ) * 2 - 1;
//      float   tex_depth2  = DEPTH_SAMPLE_PREC(DepthSampler,  vTexCoord.xy + g_vJitterDir ).x;
//    
//      ret.col.a = ( abs( z_world - tex_depth2 ) < (15.f/Z_FAR) ) * 
//                  ( dot( tex_normal.xyz, tex_normal2*2-1 )>0.25 );
//    }
//  #endif

    /*****************/
   /* calc lighting */
  /*****************/
  s2half3 dir_light =  normalize( g_vSunPosition.xyz - viewVec.xyz );
  s2half3 dir_view  =  normalize( -In_TexCoord );
  s2half3 dir_refl  = -reflect( dir_view.xyz, tex_normal.xyz );
  
  // fill values
  s2half3 diffuse;
  s2half3 ambient;
  s2half3 specular;
  s2half3 viewAmbient = 0;
  s2half3 ambientSpecular;
  
  s2half3 dots_d = 0;
//  dots_d.x = dot(dir_light.xyz, tex_normal.xyz)*0.5+0.5;
  dots_d.x = dot(dir_light.xyz, tex_normal.xyz);
  
//  s2half ambientDiffuseFade = saturate((-dots_d.x));

  dots_d.x = dots_d.x * 0.5 + 0.5;

  dots_d.y = saturate(dot(dir_view.xyz,  tex_normal.xyz));
  dots_d.z = dot(dir_light.xyz, dir_refl.xyz) * 0.5 + 0.5;
  dots_d =  dots_d*brdf_scale.xyx + brdf_offset;
  
    /***************/
   /* calc shadow */
  /***************/
  #ifdef LAYER_BIT0
    s2half shadow = 1.0f;
    s2half fader  = 1.0f;
  #else
    float4 posInLight = MUL(float4(viewVec,1), g_mLightMatrixCam);
	s2half shadow = calcShadow( ShadowSampler, posInLight );

	shadow = lerp(1, shadow, g_vSunDiffuse.a);
	shadow = lerp( shadow, 1, saturate( (world_dist-1250.f)/250.f ) );  //distance fade
	
//	s2half ambientDiffuseFade = saturate(-dots_d.x);
//	s2half fader = saturate(lerp(shadow, 1, ambientDiffuseFade));		//ambient fade
  #endif
    
  tex_brdf( Brdf_Sampler,
            dots_d.xyz,
            diffuse,    //Out
            specular ); //Out

  s2half3 dots_a;
  dots_a.x  = 1.0;
  dots_a.y  = dots_d.y;
  dots_a.z  = (dot( dir_view, dir_refl )*0.5+0.5);
  dots_a.xz = dots_a.xz * brdf_scale.xx + brdf_offset.xz;
    
  tex_brdf( Brdf_Sampler,
            dots_a.xyz,
            viewAmbient,       //Out
            ambientSpecular ); //Out

  ambient = abs(tex_normal.w - 0.75 ) * 2.0 + .750;// + viewAmbient ;
  ambient *= viewAmbient + .25;
  ambient *= g_vSunAmbient.xyz;
  ambient += playerLight;

  diffuse =  ambient + diffuse * g_vSunDiffuse.rgb * shadow + tex_specular.a;
  specular = specular * g_vSunSpecular.rgb * shadow + ambientSpecular * g_vSunAmbientSpecular.rgb;

//	float2 dots_yw = dots_d.yz; // Tmp for debugging. actually was yw
    float  dots_y = dots_d.y;

#ifdef PS3_IMPL
  for(int i=0;i<NUM_SHADOW_LIGHTS;++i)
  {
    CalcShdPointLight( i, 
                       PntShadowSampler[i],
                       viewVec, 
                       dir_refl,
                       tex_normal.rgb,
                       dots_y,
                       brdf_scale.x,
                       brdf_offset.xz,
                       diffuse,
                       specular );
  }
  for(int i=0;i<NUM_LIGHTS;++i)
  {
   	  CalcPointLight( i,
                      viewVec, 
                      dir_refl,
                      tex_normal.rgb,
                      dots_y,
                      brdf_scale.x,
                      brdf_offset.xz,
                      diffuse,
                      specular );                     
  }
#else //PS3_IMPL 
	//===========================//
   // calc shadowed pointlights //
  //===========================//
  [isolate]
  {
    if( 0<NUM_SHADOW_LIGHTS )
	  CalcShdPointLight( 0,
                         PntShadowSampler[0],
                         viewVec,
                         dir_refl,
                         tex_normal.rgb,
                         dots_y,
                         brdf_scale.x,
                         brdf_offset.xz,
                         diffuse,
                         specular );
    if( 1<NUM_SHADOW_LIGHTS )
      CalcShdPointLight( 1,
                         PntShadowSampler[1],
                         viewVec,
                         dir_refl,
                         tex_normal.rgb,
                         dots_y,
                         brdf_scale.x,
                         brdf_offset.xz,
                         diffuse,
                         specular );
  }
  [isolate]
  {                       
    if( 2<NUM_SHADOW_LIGHTS )
      CalcShdPointLight( 2,
                         PntShadowSampler[2],
                         viewVec,
                         dir_refl,
                         tex_normal.rgb,
                         dots_y,
                         brdf_scale.x,
                         brdf_offset.xz,
                         diffuse,
                         specular );
    if( 3<NUM_SHADOW_LIGHTS )
      CalcShdPointLight( 3,
                         PntShadowSampler[3],
                         viewVec,
                         dir_refl,
                         tex_normal.rgb,
                         dots_y,
                         brdf_scale.x,
                         brdf_offset.xz,
                         diffuse,
                         specular );
  }
  [isolate]
  {
    if( 4<NUM_SHADOW_LIGHTS )
      CalcShdPointLight( 4,
                         PntShadowSampler[4],
                         viewVec,
                         dir_refl,
                         tex_normal.rgb,
                         dots_y,
                         brdf_scale.x,
                         brdf_offset.xz,
                         diffuse,
                         specular );
    if( 5<NUM_SHADOW_LIGHTS )
      CalcShdPointLight( 5,
                         PntShadowSampler[5],
                         viewVec,
                         dir_refl,
                         tex_normal.rgb,
                         dots_y,
                         brdf_scale.x,
                         brdf_offset.xz,
                         diffuse,
                         specular );
  }
  [isolate]
  {
    if( 6<NUM_SHADOW_LIGHTS )
      CalcShdPointLight( 6,
                         PntShadowSampler[6],
                         viewVec,
                         dir_refl,
                         tex_normal.rgb,
                         dots_y,
                         brdf_scale.x,
                         brdf_offset.xz,
                         diffuse,
                         specular );
    if( 7<NUM_SHADOW_LIGHTS )
      CalcShdPointLight( 7,
                         PntShadowSampler[7],
                         viewVec,
                         dir_refl,
                         tex_normal.rgb,
                         dots_y,
                         brdf_scale.x,
                         brdf_offset.xz,
                         diffuse,
                         specular );
  }
    //=============================//
   // calc unshadowed pointlights //
  //=============================//
  [isolate]
  {
    if( 0<NUM_LIGHTS )
      CalcPointLight( 0,
                      viewVec,
                      dir_refl,
                      tex_normal.rgb,
                      dots_y,
                      brdf_scale.x,
                      brdf_offset.xz,
                      diffuse,
                      specular );
    if( 1<NUM_LIGHTS )
      CalcPointLight( 1,
                      viewVec,
                      dir_refl,
                      tex_normal.rgb,
                      dots_y,
                      brdf_scale.x,
                      brdf_offset.xz,
                      diffuse,
                      specular );
  }
  [isolate]
  {
    if( 2<NUM_LIGHTS )
      CalcPointLight( 2,
                      viewVec,
                      dir_refl,
                      tex_normal,
                      dots_y,
                      brdf_scale.x,
                      brdf_offset.xz,
                      diffuse,
                      specular );
    if( 3<NUM_LIGHTS )
      CalcPointLight( 3,
                      viewVec,
                      dir_refl,
                      tex_normal,
                      dots_y,
                      brdf_scale.x,
                      brdf_offset.xz,
                      diffuse,
                      specular );
  }
  [isolate]
  {
    if( 4<NUM_LIGHTS )
      CalcPointLight( 4,
                      viewVec,
                      dir_refl,
                      tex_normal,
                      dots_y,
                      brdf_scale.x,
                      brdf_offset.xz,
                      diffuse,
                      specular );
    if( 5<NUM_LIGHTS )
      CalcPointLight( 5,
                      viewVec,
                      dir_refl,
                      tex_normal,
                      dots_y,
                      brdf_scale.x,
                      brdf_offset.xz,
                      diffuse,
                      specular );
  }
  [isolate]
  {
    if( 6<NUM_LIGHTS )
      CalcPointLight( 6,
                      viewVec,
                      dir_refl,
                      tex_normal,
                      dots_y,
                      brdf_scale.x,
                      brdf_offset.xz,
                      diffuse,
                      specular );
    if( 7<NUM_LIGHTS )
      CalcPointLight( 7,
                      viewVec,
                      dir_refl,
                      tex_normal,
                      dots_y,
                      brdf_scale.x,
                      brdf_offset.xz,
                      diffuse,
                      specular );
  }
  [isolate]
  {
    if( 8<NUM_LIGHTS )
      CalcPointLight( 8,
                      viewVec,
                      dir_refl,
                      tex_normal,
                      dots_y,
                      brdf_scale.x,
                      brdf_offset.xz,
                      diffuse,
                      specular );
    if( 9<NUM_LIGHTS )
      CalcPointLight( 9,
                      viewVec,
                      dir_refl,
                      tex_normal,
                      dots_y,
                      brdf_scale.x,
                      brdf_offset.xz,
                      diffuse,
                      specular );
  }
  [isolate]
  {
    if( 10<NUM_LIGHTS )
      CalcPointLight( 10,
                      viewVec,
                      dir_refl,
                      tex_normal,
                      dots_y,
                      brdf_scale.x,
                      brdf_offset.xz,
                      diffuse,
                      specular );
    if( 11<NUM_LIGHTS )
      CalcPointLight( 11,
                      viewVec,
                      dir_refl,
                      tex_normal,
                      dots_y,
                      brdf_scale.x,
                      brdf_offset.xz,
                      diffuse,
                      specular );
  } 
#endif //PS3

  diffuse  *= tex_diffuse.rgb;
  specular *= tex_specular.rgb;
  
  s2half3 final_color =  specular + diffuse;
  s2half3 final_glow =  tex_specular.a * tex_diffuse.rgb + specular ;
  s2half3 final_copy = final_color;

  s2half fog_intensity = 0.f;

    //============//
   // do Fogging //
  //============//
  float2 fog_coord = getFogTCs(world_dist, g_vFogData);

  s2half3 skyFog = g_vSunDiffuse.rgb/5.f;
  fogGlowMK( final_color, final_glow, fog_intensity, FogSampler, fog_coord, skyFog );

  fog_intensity *= g_vSunSpecular.w;
  final_glow *= .5;

#ifdef XENON_IMPL //RSX dos this in hardware.
  final_color.rgb = linear2srgb( final_color.rgb );
  final_glow.rgb  = linear2srgb( final_glow.rgb );
#else
  final_color.rgb	= final_color.rgb;
  final_glow.rgb	= final_glow.rgb;
  final_copy.rgb    = final_copy.rgb;
#endif

  #ifdef SPASS_LIGHTNING
    float is2Lightning = step( 0.2, dot( tex_normal.xyz, g_vLightningDirection ) );
    final_color += float3( is2Lightning * g_vLightningAmbient.www );
    final_glow  += float3( is2Lightning * g_vLightningAmbient.xyz );
    final_copy  += float3( is2Lightning * g_vLightningAmbient.www );
  #endif

  ret.col.rgb  = s2half3(final_color);
  ret.glow = s2half4( final_glow + final_color * fog_intensity, 1 - fog_intensity);

  #ifdef PS3_IMPL
	  ret.colCopy = s2half4(final_copy,1.f);
      ret.glow.a = 1 - SQRT(fog_intensity); // Hardware converts RGB to srgb - we do it for alpha
  #endif
  return ret;
}