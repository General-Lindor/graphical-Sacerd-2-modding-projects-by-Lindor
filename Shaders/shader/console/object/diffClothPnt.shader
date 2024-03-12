//#OptDef:S2_FOG

// diffuse + specular for point lights

#include "extractvalues.shader"

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
#ifdef S2_FOG
  float2 depthFog     : TEXCOORD4;
#endif
};


pixdata mainVS(appdata I,
	uniform float4x4 worldViewProjMatrix,
	uniform float4x4 invWorldMatrix,
	uniform float4 light_pos,
	uniform float4 camera_pos,
  uniform float4 fog_data,
  uniform float4 zfrustum_data )
{
	pixdata O;
	float4 pos4 = float4(I.position, 1.0);
	float4 nrm4 = float4(I.normal, 0.0);
	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

#ifdef S2_FOG
  O.depthFog = getFogTCs( O.hposition.w, fog_data );
#endif

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
#ifdef PS3_IMPL
	float3 vertex_to_light_tan = REAL_MUL(objToTangentSpace, vertex_to_light);
#else
	float3 vertex_to_light_tan = mul(objToTangentSpace, vertex_to_light);
#endif
	// pass vertex to light to pixelshader, so it becomes pixel to light
	O.pix_to_li_t = float4(vertex_to_light_tan, 0.0);
	O.pix_to_li_o = float4(vertex_to_light, 0.0);

	// convert cam pos from worldspace into objectspace
	float4 c_pos_obj = mul(camera_pos, invWorldMatrix);
	// build vector from vertex pos to cam pos
	float3 vertex_to_cam = c_pos_obj.xyz - pos4.xyz;
	// convert vertex_to_cam from objectspace to tangentspace
#ifdef PS3_IMPL
	float3 vertex_to_cam_tan = REAL_MUL(objToTangentSpace, vertex_to_cam);
#else
	float3 vertex_to_cam_tan = mul(objToTangentSpace, vertex_to_cam);
#endif
	// pass vertex to cam to pixelshader, so it becomes pixel to cam
	O.pix_to_c = float4(vertex_to_cam_tan, 0.0);

	// texcoords passen
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout_t mainPS(pixdata I,
    uniform sampler2D   texture0,
    uniform sampler2D   texture1,
    uniform sampler2D   texture2,
    uniform sampler2D   texture3,
    uniform samplerCUBE textureCube,
    uniform sampler2D   fog_texture,
    uniform sampler2D   colvar_mask,
    uniform float4      pix_color_ramp[8],
    uniform float4      light_col_diff,
    uniform float4      light_data,
    uniform float4      pix_data_array )
{
	fragout_t O;

  float clipper = - tex2D( texture3, I.texcoord0.xy ).a;
  if( pix_data_array.x )
    clip( clipper );

	// get texture values
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	s2half4 tex2 = decode_normal(tex2D(texture2, I.texcoord0.xy));
#ifdef COLORVARIATIONS
  tex0 = apply_colorramp(tex0,
                         tex2D(colvar_mask, I.texcoord0.xy),
                         pix_color_ramp);
#endif

	// get normal vector from bumpmap texture
//	s2half3 nrm = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));
	s2half3 nrm = tex2.xyz;

	// lighting
	s2half3 to_light = normalize(I.pix_to_li_t.xyz);
	s2half3 to_cam = normalize(I.pix_to_c.xyz);
	
  // calc standard vars
	s2half3 half_vec = normalize(to_light + to_cam);
	s2half dot_l_n = dot(to_light, nrm);
	s2half dot_c_n = dot(to_cam, nrm);
	s2half dot_hv_n = dot(half_vec, nrm);
	s2half dot_l_c = dot(to_light, to_cam);
	
	// calc distance of light
	float dist_to_light = dot(I.pix_to_li_o.xyz, I.pix_to_li_o.xyz);
	// build intensity from distance to light using light radius
	s2half temp_dist = saturate(dist_to_light  * light_data.z * light_data.z);
	s2half intensity = (1.0 - temp_dist) * (1.0 - temp_dist); // 1.0 - sin(1.5708 * temp_dist);
	// multiply it by intensity of ight source
	intensity *= light_data.y;
#ifdef S2_FOG
  #ifdef SM3_0 // Shader is too complex for SM 2
    fogPnt( intensity, fog_texture, I.depthFog );
  #endif
#endif

	// modulate light color with intensity
	s2half3 pnt_l_color = intensity * light_col_diff.xyz;

	// retro-reflective lobe
	s2half cosine = saturate(dot_l_c);
	s2half3 shiny = pow(cosine, 7.0) * 0.3 * pnt_l_color * tex0;

	// horizon scattering
	cosine = saturate(dot_c_n);
	s2half sine = sqrt(1.0 - cosine * cosine);
	shiny += pow(sine, 5.0) * saturate(dot_l_n) * pnt_l_color * tex0;

	// specular
	s2half3 specular = tex1.xyz * pnt_l_color * pow(saturate(dot_hv_n), 20);

	// calc sun diffuse
	s2half3 diffuse = pnt_l_color * tex0.xyz * saturate(dot_l_n);

	// compose color
	O.col0.xyz = (0.5 * diffuse + 1.5 * shiny + specular.xyz);
	O.col0.a = tex0.a;
	O.col1 = float4(0.0, 0.0, 0.0, 0.0);

	return O;
} 
