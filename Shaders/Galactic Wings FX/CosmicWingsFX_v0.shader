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
	float4 surfNrm_ws   : TEXCOORD1;
	float4 lightNrm_ws  : TEXCOORD2;
	float4 camDist_ws   : TEXCOORD3;
	float4 screenCoord  : TEXCOORD4;
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
		float4 halfway = calcScreenToTexCoord(O.hposition);
		O.screenCoord = halfway;
		float resolution = 0.05 * c_dist_ws;
		//float resolution = 0.01 * c_dist_ws;
		O.texcoord0 = float4(((halfway.x / halfway.w) - 0.5) * resolution, ((halfway.y / halfway.w) - 0.5) * resolution, halfway.z * resolution, halfway.w * resolution);

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

  //take the wobbly effect from the fx6 shader (it's called "fx6" in surface.txt, but the shader is called "ambDiffFx5.shader")
	float4 sum_color = float4(0.0, 0.0, 0.0, 0.0);
	float I = 0, sum_num = 6;
	for(I = 0; I < sum_num; I++)
	{
	  //calc horizontal offset
		float2 offsetUV = I.texcoord0.xy / 5.0;
	  //make it a little bit slower than in fx6
		offsetUV.y += frac(0.55 + 0.3375 * I * time / sum_num + 0.15 + I / sum_num);
		s2half4 wave_offset = tex2D(texture2, offsetUV);
		float h_offs = (I / sum_num) + (0.1 + 0.03 * I / sum_num) * (wave_offset.x - 0.5);
		
	  //calc vertical offset
		offsetUV = I.texcoord0.xy / 5.0;
		wave_offset = tex2D(texture2, offsetUV);
		float v_offs = (0.3 * I / sum_num) * wave_offset.z * (wave_offset.y - 0.5);

	  //calc lookup
		float2 newUV = I.texcoord0.xy / 5.0;
	  //increase range of wobblyness compared to fx6 through multiplying by 2
		newUV += 2.0 * float2(h_offs, v_offs);

	  //fx base color
		s2half4 base_color = tex2D(texture1, newUV);
		base_color = pow(base_color, 1.0 + 2.0 * wave_offset.x + 2.0 * wave_offset.y);
		
	  //fx sum color
		sum_color += base_color;
	}

	sum_color /= sum_num;
	
  //end of fx6's wobbly effect calculation
	  
  //HSL color room's Lightness and Saturation from RGB color room
	  //sum_color
		float lightness_gamma_corrected_sum = (0.2126 * sum_color.x) + (0.7152 * sum_color.y) + (0.0722 * sum_color.z);
	  //tex0
		float saturation_tex0 = sqrt(dot(tex0.xyz, tex0.xyz) - dot(tex0.xyz, tex0.yzx));
		float lightness_gamma_corrected_tex0 = 0.2126 * tex0.x + 0.7152 * tex0.y + 0.0722 * tex0.z;
		
  //compose wobbly+starry. saturation is necessary so that the stars don't get overlayed with the wobbly.
	float3 final_col = float3(0.0, 0.0, 0.0);
	float3 final_glow = float3(0.0, 0.0, 0.0);
	float glow_intensity = 0.0;
  //star
	if ((1.0 - saturation_tex0) * lightness_gamma_corrected_tex0 > 0.27) {
		final_col = tex0.xyz;
		final_glow = tex0.xyz;
	  //high_nebula
		if (lightness_gamma_corrected_sum > 0.05f) {
		//aimed effect: stars inside nebulas shall glow bright
		
			glow_intensity = lightness_gamma_corrected_tex0;
		}
	  //low_nebula
		else {
		//aimed effect: visual difference between glowing star inside nebula and normal background star outside nebula
		
		  //the lower the dimm value, the more the star gets dimmed
			float dimm_min = 0.5f;
			float dimm_max = 1.0f;
		  //the less saturation and the more brightness, the more the star gets dimmed aka the lower the dimm value
			float dimm = lerp(dimm_min, dimm_max, sqrt(saturation_tex0 * (1.0f - lightness_gamma_corrected_tex0)));
			float glow_min = lightness_gamma_corrected_tex0 * dimm;
			float glow_max = lightness_gamma_corrected_sum;
			final_col *= dimm;
			final_glow *= dimm;
		  //multiply by 20.0 because (0.0 < lightness_gamma_corrected_sum < 0.05) and (20.0 * 0.05 = 1)
			glow_intensity = lerp(glow_min, glow_max, 20.0 * lightness_gamma_corrected_sum);
		}
	}
  //no_star
	else {
	  //high_nebula
		if (lightness_gamma_corrected_sum > 0.05) {
		//aimed effect: nebula replaces everything that is not a star and glows a little bit
		
			final_col = sum_color.xyz;
			final_glow = sum_color.xyz;
			glow_intensity = 0.35;
		}
	  //low_nebula
		else {
		//aimed effect: smooth fade-off of nebula diffuse and glow into starry background
		
		  //multiply by 20.0 because (0.0 < lightness_gamma_corrected_sum < 0.05) and (20.0 * 0.05 = 1)
			float lerpval =  20.0 * lightness_gamma_corrected_sum;
			
		  //calc diffuse, glow and glow_intensity for starry and nebula
		  
			//copy code from star/low_nebula
			  float dimm_min = 0.5f;
			  float dimm_max = 1.0f;
			  float dimm = lerp(dimm_min, dimm_max, sqrt(saturation_tex0 * (1.0f - lightness_gamma_corrected_tex0)));
			  float glow_min = lightness_gamma_corrected_tex0 * dimm;
			  float glow_max = lightness_gamma_corrected_sum;
			  
			//diffuse
			  float3 diffuse_starry = tex0.xyz * dimm;
			  float3 diffuse_nebula = sum_color.xyz;
			  
			//glow
			  float3 glow_starry = tex0.xyz * dimm;
			  float3 glow_nebula = sum_color.xyz;
			  
			//intensity
			  float glow_intensity_starry = lerp(glow_min, glow_max, lerpval);
			  float glow_intensity_nebula = 0.35;
			  
		  //compose
			final_col = lerp(diffuse_starry, diffuse_nebula.xyz, lerpval);
			final_glow = lerp(glow_starry, glow_nebula.xyz, lerpval);
			glow_intensity = lerp(glow_intensity_starry, glow_intensity_nebula, lerpval);
		}
	}

  //apply intensity
	final_glow *= glow_intensity;

  //and ready to go
	O.col[0] = float4(final_col, tex0.w);
	O.col[1] = float4(final_glow, tex0.w);
#endif

	return O;
} 