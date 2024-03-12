// skin

struct appdata {
	float3 position     : POSITION;
	float3 normal       : NORMAL;
	float3 tangent      : TANGENT;
	float3 binormal     : BINORMAL;
	float2 texcoord     : TEXCOORD0;
	float2 data         : TEXCOORD1;
};

struct pixdata {
	float4 hposition    : POSITION;
	float4 texcoord0    : TEXCOORD0;
	float4 texcoord1    : TEXCOORD1;
	float4 screenCoord  : TEXCOORD2;
	float4 surfNrm_ws   : TEXCOORD3;
	float4 lightNrm_ws  : TEXCOORD4;
	float4 camDist_ws   : TEXCOORD5;
};

struct fragout {
	float4 col[2]      : COLOR;
};

pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 invWorldMatrix,
  uniform float4x4 worldMatrix,
  uniform float4   light_pos,
  uniform float4   camera_pos)
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);
	float4 nrm4 = float4(I.normal, 0.0);

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

	// vertex-position in screen space
	O.screenCoord.x = O.hposition.w + O.hposition.x;
	O.screenCoord.y = O.hposition.w - O.hposition.y;
	O.screenCoord.z = 0.0;
	O.screenCoord.w = 2.0 * O.hposition.w;
	O.screenCoord.xy *= target_data.xy;

	// texture coords
	O.texcoord0 = I.texcoord.xyyy;
	O.texcoord1 = I.data.xyyy;
	
	// lighting
	O.surfNrm_ws = mul(nrm4, worldMatrix);
	O.lightNrm_ws = normalize(light_pos);
	O.camDist_ws = camera_pos - mul(pos4, worldMatrix);

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D texture0,
  uniform sampler2D texture1,
  uniform sampler2D texture2,
  uniform sampler2D shadow_texture,
  uniform float4    system_data,
  uniform float4    light_col_amb,
  uniform float4    light_col_diff)
{
	fragout O;

	// time
	float time = system_data.x;
	
	// sum
	float4 sum_color = float4(0.0, 0.0, 0.0, 0.0);
	
	float i = 0, sum_num = 2; //ps_3_0 has 6, ps_2_0 has only 2
	for(i = 0; i < sum_num; i++)
	{
	  float2 offsetUV = I.texcoord1.xy;
	  offsetUV.y += frac(0.55 + 0.45 * i * time / sum_num + 0.15 + i / sum_num);
	  s2half4 wave_offset = tex2D(texture1, offsetUV);
	  float h_offs = (i / sum_num) + (0.1 + 0.03 * i / sum_num) * (wave_offset.x - 0.5);
  	
	  offsetUV = I.texcoord1.xy;
	  wave_offset = tex2D(texture1, offsetUV);
	  float v_offs = (0.3 * i / sum_num) * wave_offset.z * (wave_offset.y - 0.5);
  	
	  // calc lookup
	  float2 newUV = I.texcoord1.xy;
	  newUV += float2(h_offs, v_offs);

	  // fx base color
	  s2half4 base_color = tex2D(texture0, newUV);
  	
	  base_color = pow(base_color, 1.0 + 2.0 * wave_offset.x + 2.0 * wave_offset.y);
	  
	  sum_color += base_color;
  }

  sum_color /= sum_num;
  
  // effect sum is "alpha'ed"
  s2half4 alpha = tex2D(texture0, I.texcoord1.xy);
  sum_color *= alpha.w;
  
	// get shadow term from shadow texture
	float4 shadow = tex2Dproj(shadow_texture, I.screenCoord);
	
	// standard lighting
	s2half4 tex2 = tex2D(texture2, I.texcoord0.xy);
	float4 dot_l_n = saturate(dot(I.lightNrm_ws.xyz, normalize(I.surfNrm_ws.xyz)));
	float4 std_color = (light_col_amb + dot_l_n * light_col_diff) * tex2;
	
	// boost glow!
	s2half4 glow = tex2D(texture1, I.texcoord1.xy);

	// prepare output color
	float4 out0 = float4(sum_color.xyz + std_color.xyz, 0.0);
	float4 out1 = float4(glow.a * sum_color.xyz, 0.0);
	
  // und raus damit	
	O.col[0] = out0;
	O.col[1] = out1;

	return O;
} 
