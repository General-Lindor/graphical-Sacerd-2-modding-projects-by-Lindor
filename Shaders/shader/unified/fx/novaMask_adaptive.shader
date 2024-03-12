// standard nova in ground

struct appdata {
	float3 position    : POSITION;
	float3 normal      : NORMAL;
	float3 tangent     : TANGENT;
	float3 binormal    : BINORMAL;
	float2 texcoord    : TEXCOORD0;
	float2 data        : TEXCOORD1;
};

struct pixdata {
	float4 hposition   : POSITION;
  float  v           : TEXCOORD;
};

struct fragout {
	float4 col         : COLOR;
};


pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4 vtx_data_array[4])
{
	pixdata O;

  // rotation matrices 
  // ( x ^= cos( rotation ), y ^= sin( rotation ), z ^= cos( rotation2 ), w ^= sin( rotation2 ) )
  // -rot for second rotation only temporary?
  float  rot          = vtx_data_array[0].x;
  float  anz_layer    = vtx_data_array[0].y;
  float  size         = vtx_data_array[0].z;
  float  bias         = vtx_data_array[0].w * 0.001;
  // center of effect
  float2 color_offset = vtx_data_array[1].xy;
  float  intensity    = vtx_data_array[1].z;
  float  ef_height    = vtx_data_array[1].w;
  float  anzPatterns  = vtx_data_array[2].x;
  float  depth        = vtx_data_array[2].y;
  float  glob_z       = vtx_data_array[2].z;
  float4 e_center     = vtx_data_array[3];
  // vertex position + z offset along normal
	float4 pos4         = float4(I.position + bias * I.normal, 1.0);
  pos4.z             += glob_z;

	// transform vertices into clip space
	O.hposition = mul(pos4, worldViewProjMatrix);
  // pass distance to effect center
  O.v = ( length( pos4.xy - e_center.xy ) - size ) / ( 2.0 * depth );

	return O;
}

fragout mainPS(pixdata I )
{
	fragout O;

  if( I.v >= 0.0 && I.v <= 1.0 )
    O.col = float4( 1.0, 1.0, 1.0, 1.0 );
  else
    O.col = float4( 0.0, 0.0, 0.0, 0.0 );

	return O;
} 
