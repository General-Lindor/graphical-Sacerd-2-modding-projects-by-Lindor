#ifndef GAMMA_CORRECT_SHADER
#define GAMMA_CORRECT_SHADER
#if 0
#define GAMMA_KEY           2.0f
#define AMBIENT_MULTIPLIER  0.75f * GAMMA_KEY
#define DIFFUSE_MULTIPLIER  1.75f * GAMMA_KEY
#define SPECULAR_MULTIPLIER 1.f * GAMMA_KEY
#define GLOW_MULTIPLIER     1.0f * GAMMA_KEY
#endif

//#define LINEARIZE_HQ
//#define LINEARIZE_MQ
#define LINEARIZE_LQ

s2half4 do_srgb2linear(s2half4 f)
{
  #if defined( LINEARIZE_HQ )
    return ((f<=0.03928) ? f/12.92 : pow((f + 0.055)/1.055, 2.4));
  #elif defined( LINEARIZE_MQ )
    return pow( f,  2.2f );
  #elif defined( LINEARIZE_LQ )
    return f*f;
  #else
    return f;
  #endif
}

s2half4 do_linear2srgb(s2half4 f)
{
  #if defined( LINEARIZE_HQ )
    return ((f<=.0031308) ? 12.92 * f : 1.055 * pow(f,1.0/2.4) - 0.055);
  #elif defined( LINEARIZE_MQ )
    return pow( f, 1.f/2.2 );
  #elif defined( LINEARIZE_LQ )
    return sqrt(f);
  #else
    return f;
  #endif
}

s2half3 srgb2linear(s2half3 f)
{
	return do_srgb2linear(s2half4(f,0)).xyz;
}
s2half4 srgb2linear(s2half4 f)
{
	return do_srgb2linear(f);
}

s2half3 linear2srgb(s2half3 f)
{
	return do_linear2srgb(s2half4(f,0)).xyz;
}
float4 linear2srgb(s2half4 f)
{
	return do_linear2srgb(f);
}
#endif //include guard