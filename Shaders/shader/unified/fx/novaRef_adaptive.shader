// refraction nova in ground

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
  float4 texcoord0   : TEXCOORD0;
  float4 circ_pos    : TEXCOORD1;
	float4 screenCoord : TEXCOORD2;
};

struct fragout {
	float4 col[2]      : COLOR;
};


pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4   target_data,
    uniform float4   vtx_data_array[4])
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

  // pass pos
  float2 tc = pos4.xy - e_center.xy;
  O.circ_pos = float4( tc, size, depth );
  float u, v;
  u = acos( normalize( tc ).y );
  v = (length( tc ) - size) / ( 1.5 * depth );
  // texcoords
  O.texcoord0 = float4( u, v, intensity, 0.f);

	// vertex-position in screen space
	O.screenCoord.x = O.hposition.w + O.hposition.x;
	O.screenCoord.y = O.hposition.w - O.hposition.y;
	O.screenCoord.z = O.hposition.z;
	O.screenCoord.w = 2.0 * O.hposition.w;
	O.screenCoord.xy *= target_data.xy;

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D   texture0,
  uniform sampler2D   texture1,
  uniform sampler2D   texture2,
  uniform sampler2D   texture3,
  uniform sampler3D   textureVolume,
  uniform float4      param,
  uniform float4      target_data)
{
	fragout O;

  // usefull names
  float intensity = I.texcoord0.z;
  float inner_radius = I.circ_pos.z;
  float delta_radius = I.circ_pos.w;
  float time = param.x;

  // one texcoord comes from pos
  s2half radial_tc = saturate((length(I.circ_pos.xy) - inner_radius) / delta_radius);

  // calc v-stretch
  float umfang = 0.5 * delta_radius;

	// gradient
	s2half4 tex0 = tex2D(texture0, float2(radial_tc, umfang * I.texcoord0.x));
  // caust
  s2half4 cau = tex3D(textureVolume, float3(radial_tc, umfang * I.texcoord0.x, time));


	// offset
	float2 scr_offset = (I.screenCoord.z / I.screenCoord.w) * target_data.zw * normalize(I.circ_pos.xy) * tex0.x * intensity * cau.x;
	// screenpos of this pixel
	float2 scr_pos = I.screenCoord.xy / I.screenCoord.w;
	// offset due to refraction and distance!
	float2 offs_scr_pos = scr_pos - 20.0 * scr_offset;
	
	// transparency <-> opaque mask
	s2half4 t_mask = tex2D(texture3, offs_scr_pos);
	
	// offset'ed background
	s2half4 offs_bgr = tex2D(texture2, offs_scr_pos);
	// non-offset'ed background
	s2half4 nonoffs_bgr = tex2D(texture2, scr_pos);
	
	// lerp with mask
	s2half4 bgr = lerp(nonoffs_bgr, offs_bgr, t_mask.x);

  // out
	O.col[0] = float4(bgr.xyz, 1.0);
	O.col[1] = float4(0.0, 0.0, 0.0, 0.0);

	return O;
} 