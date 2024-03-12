struct appdata
{
  float3 pos : POSITION;
  float4 col : COLOR;
};

struct pixdata
{
  float4 hpos : POSITION;
  float  alpha: TEXCOORD0;
};

struct outcolor
{
  float4 col[2] : COLOR;
};

void mainVS( in appdata I, uniform float4x4 worldViewProjMatrix, out pixdata VSOUT )
{
  VSOUT.hpos = mul( float4( I.pos, 1.0 ), worldViewProjMatrix );
  VSOUT.alpha = I.col.r * 2.0 - 1.0;
}

void mainPS( in pixdata I, uniform float4 param, out outcolor col )
{
  float alpha = (1.0 - abs(I.alpha)) * 0.4;
  col.col[0] = float4( 1.0, 1.0, 1.0, 1.0 ) * param.x * alpha;
  col.col[1] = float4( 40.0 / 255.0, 220.0 / 255.0, 220.0 / 255.0, 1.0 ) * param.x * alpha;
}