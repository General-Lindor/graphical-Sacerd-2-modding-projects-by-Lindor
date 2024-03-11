// ambient
#include "extractvalues.shader"
#define LIGHTBLOCKS 4

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
	float4 surfNrm_ws   : TEXCOORD2;
	float4 lightNrm_ws  : TEXCOORD3;
	float4 camDist_ws   : TEXCOORD4;
	float4 screenCoord  : TEXCOORD5;
};

#ifdef SM1_1
struct fragout {
	float4 col         : COLOR;
};
#else
struct fragout {
	float4 col[2]      : COLOR;
};
#endif

pixdata mainVS(appdata I,
	uniform float4x4 worldViewProjMatrix,
	uniform float4x4 worldMatrix,
	uniform float4   target_data,
	uniform float4   light_pos,
	uniform float4   camera_pos)
{
	pixdata O;
	
	// vertex pos
		float4 pos4 = float4(I.position.xyz, 1.0);
		float4 nrm4 = float4(I.normal, 0.0);
		O.hposition = mul(pos4, worldViewProjMatrix);
	
	// lighting
		O.surfNrm_ws = mul(nrm4, worldMatrix);
		O.lightNrm_ws = normalize(light_pos);
		O.camDist_ws = camera_pos - mul(pos4, worldMatrix);
		
		float c_dist_ws = sqrt(dot(O.camDist_ws.xyz, O.camDist_ws.xyz));
	
	// pass texture coords
		//O.texcoord0 = mul(float4(I.texcoord.xy, 1.0, 1.0), worldViewProjMatrix);
		//O.texcoord0 = mul(float4(I.data.xy - I.texcoord.xy, 1.0, 1.0), worldViewProjMatrix);
		float4 halfway = calcScreenToTexCoord(O.hposition);
		O.screenCoord = halfway;
		float resolution = 0.05 * c_dist_ws;
		O.texcoord0 = float4(((halfway.x / halfway.w) - 0.5) * resolution, ((halfway.y / halfway.w) - 0.5) * resolution, halfway.z * resolution, halfway.w * resolution);
		O.texcoord1 = float4(I.texcoord.xy, 1.0, 1.0);

	return O;
}

fragout mainPS(pixdata I,
	uniform sampler2D   texture0,
	uniform sampler2D   texture1,
	uniform sampler2D   texture2,
    uniform sampler2D   shadow_texture,
	uniform samplerCUBE textureCube,
	uniform float4      system_data)
{
	fragout O;

#ifdef SM1_1
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	O.col = float4(tex0.xyz, 1.0);
#else
	float time = system_data.x;

	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	s2half4 shadow = tex2Dproj(shadow_texture, I.screenCoord);
	
	/*
	//calc reflection and glow
		s2half3 c_dir_ws = normalize(I.camDist_ws.xyz);
		s2half3 nrm_wrld = normalize(I.surfNrm_ws.xyz);
		float4 reflection = texCUBE(textureCube, reflect(-c_dir_ws, nrm_wrld));
		float4 final_glow = tex0 * reflection;
		float glow_alpha = dot(final_glow.xyz, final_glow.xyz);
	*/	
	//calc fx6's wobbly effect
		float4 sum_color = float4(0.0, 0.0, 0.0, 0.0);
	
		float I = 0, sum_num = 6;

		for(I = 0; I < sum_num; I++)
		{
			float2 offsetUV = I.texcoord0.xy / 7.0;
			offsetUV.y += frac(0.55 + 0.45 * I * time / sum_num + 0.15 + I / sum_num);
			s2half4 wave_offset = tex2D(texture2, offsetUV);
			float h_offs = (I / sum_num) + (0.1 + 0.03 * I / sum_num) * (wave_offset.x - 0.5);
			
			offsetUV = I.texcoord0.xy / 7.0;
			wave_offset = tex2D(texture2, offsetUV);
			float v_offs = (0.3 * I / sum_num) * wave_offset.z * (wave_offset.y - 0.5);
			
		// calc lookup
			float2 newUV = I.texcoord0.xy / 7.0;
			newUV += float2(h_offs, v_offs);
		
		// fx base color
			s2half4 base_color = tex2D(texture1, newUV);
			
			base_color = pow(base_color, 1.0 + 2.0 * wave_offset.x + 2.0 * wave_offset.y);
			
			sum_color += base_color;
		}

		sum_color /= sum_num;
  
		float lerpval = 0.5 + ((dot(tex0.xyz, tex0.xyz) - dot(sum_color.xyz, sum_color.xyz)) / 6.0);
		float4 final_col = lerp(sum_color, tex0, lerpval);
		float glow_alpha = saturate(dot(final_col.xyz, final_col.xyz) + 20.0 * dot(sum_color.xyz, sum_color.xyz));
		float4 final_glow = final_col * glow_alpha;

			O.col[0] = float4(final_col.xyz, 1.0);
			//O.col[1] = float4(0.0, 0.0, 0.0, 0.0);
			O.col[1] = float4(final_glow.xyz, glow_alpha);
#endif

	return O;
} 