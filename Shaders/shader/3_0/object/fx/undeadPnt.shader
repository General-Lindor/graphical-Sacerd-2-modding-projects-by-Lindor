// diffuse + specular for point lights

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
	float4 pix_to_li_t  : TEXCOORD1;
	float4 pix_to_c     : TEXCOORD2;
	float4 pix_to_li_o  : TEXCOORD3;
};

struct fragout {
	float4 col[2]      : COLOR;
};

pixdata mainVS(appdata I,
	uniform float4x4 worldViewProjMatrix,
	uniform float4x4 invWorldMatrix,
	uniform float4 light_pos,
	uniform float4 camera_pos)
{
	pixdata O;
	float4 pos4 = float4(I.position, 1.0);
	float4 nrm4 = float4(I.normal, 0.0);
	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

	// build object-to-tangent space matrix
	float3x3 objToTangentSpace;
	objToTangentSpace[0] = -1.0 * I.tangent;
	objToTangentSpace[1] = -1.0 * I.binormal;
	objToTangentSpace[2] = I.normal;

	// convert light pos from worldspace into objectspace
	float4 l_pos_obj = mul(light_pos, invWorldMatrix);
	// build vector from vertex pos to light pos
	float3 vertex_to_light = l_pos_obj.xyz - pos4.xyz;
	// convert vertex_to_light from objectspace to tangentspace
	float3 vertex_to_light_tan = mul(objToTangentSpace, vertex_to_light);
	// pass vertex to light to pixelshader, so it becomes pixel to light
	O.pix_to_li_t = float4(vertex_to_light_tan, 0.0);
	O.pix_to_li_o = float4(vertex_to_light, 0.0);

	// convert cam pos from worldspace into objectspace
	float4 c_pos_obj = mul(camera_pos, invWorldMatrix);
	// build vector from vertex pos to cam pos
	float3 vertex_to_cam = c_pos_obj.xyz - pos4.xyz;
	// convert vertex_to_cam from objectspace to tangentspace
	float3 vertex_to_cam_tan = mul(objToTangentSpace, vertex_to_cam);
	// pass vertex to cam to pixelshader, so it becomes pixel to cam
	O.pix_to_c = float4(vertex_to_cam_tan, 0.0);

	// texcoords passen
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
    uniform sampler2D   texture0,
    uniform sampler2D   texture1,
    uniform sampler2D   texture2,
    uniform sampler3D   textureVolume,
    uniform float4      light_col_diff,
    uniform float4      light_data,
    uniform float4      system_data)
{
	fragout O;

	// get texture values
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	s2half4 tex2 = tex2D(texture2, I.texcoord0.xy);

  // get animated normal
  s2half4 tex_v = tex3D(textureVolume, float3(6.0 * I.texcoord0.xy, 0.08 * system_data.x));

	// get normal vector from bumpmap texture
  s2half3 nrm_tex = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));
	s2half3 nrm_anim = normalize(tex_v.xyz - s2half3(0.5, 0.5, 0.5));

  // lighting
	s2half3 l0_dir = normalize(I.pix_to_li_t.xyz);
	s2half3 c_dir = normalize(I.pix_to_c.xyz);
	s2half3 half_vec = normalize(c_dir + l0_dir);

  // calc "undead" texture color
  s2half3 tex0_undead = lerp(dot(tex0.rgb, float3(0.222, 0.707, 0.071)).xxx, tex0.rgb, 0.6);

	// calc diffuse
	float3 diffuse_tex = saturate(dot(l0_dir, nrm_tex)) * tex0_undead * light_col_diff.xyz;

	// calc specular
	float3 specular_tex =  pow(saturate(dot(half_vec, nrm_tex)), 20.0) * tex1.xyz * light_col_diff.xyz;
	float3 specular_anim = pow(saturate(dot(half_vec, nrm_anim)), 20.0) * float3(0.8, 0.8, 0.9) * light_col_diff.xyz;

	// calc distance of light
	float dist_to_light = dot(I.pix_to_li_o.xyz, I.pix_to_li_o.xyz);
	// build intensity from distance to light using light radius
	float temp_dist = saturate(dist_to_light  * light_data.z * light_data.z);
	float intensity = (1.0 - temp_dist) * (1.0 - temp_dist); // 1.0 - sin(1.5708 * temp_dist);
	// multiply it by intensity of ight source
	intensity *= light_data.y;

  // lerp between goo and normal
  float3 out0 = lerp(specular_anim, diffuse_tex + specular_tex, tex_v.a);
  float3 out1 = lerp(specular_anim, specular_tex, tex_v.a);

  // out
	O.col[0].xyz = intensity * out0;
	O.col[0].a = tex0.a;
	O.col[1].xyz = 0.5 * intensity * out1;
	O.col[1].a = tex0.a;

	return O;
} 
