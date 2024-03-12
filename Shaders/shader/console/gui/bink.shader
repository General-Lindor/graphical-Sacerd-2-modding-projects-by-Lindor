
// vs
float4 mainVS( float4 pos : POSITION, out float2 tex : TEXCOORD0 ) : POSITION
{
	tex = pos.zw;
	return float4( pos.xy, 0, 1 );
}

// ps
sampler2D	YplaneNPA	: register(s0);
sampler2D	cRplaneNPA	: register(s1);
sampler2D	cBplaneNPA	: register(s2);
float4		AlphaNPA	: register(c0);

float4 mainPS( float2 texcoord : TEXCOORD0 ) : COLOR
{
  const float3 crc = { 1.595794678f, -0.813476563f, 0 };
  const float3 crb = { 0, -0.391448975f, 2.017822266f };
  const float3 adj = { -0.87065506f, 0.529705048f, -1.081668854f };
  float3 p;

  float y = tex2D( YplaneNPA, texcoord ).x;
  float cr = tex2D( cRplaneNPA, texcoord ).x;
  float cb = tex2D( cBplaneNPA, texcoord ).x;

  p = y * 1.164123535f;

  p += crc * cr;
  p += crb * cb;
  p += adj;

//  p *= AlphaNPA;

  return float4( p, 1 );
}
