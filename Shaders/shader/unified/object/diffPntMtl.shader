//#OptDef:S2_FOG
//#OptDef:NORMALFORMAT_DXN
//#OptDef:NORMALFORMAT_565
//#OptDef:NORMALFORMAT_DXT5

#define VERT_XVERTEX
#include "extractvalues.shader"


#ifdef SM1_1

// diffuse + specular for point lights




DEFINE_VERTEX_DATA


struct pixdata {
	float4 hposition    : POSITION;
	float4 texcoord0    : TEXCOORD0;
	float4 pix_to_li_t  : TEXCOORD1;
	float4 pix_to_c     : TEXCOORD2;
	float4 pix_to_li_o  : TEXCOORD3;
#ifdef S2_FOG
  float  fog          : FOG;
#endif
};

struct fragout {
	s2half4 col      : COLOR;
};

pixdata mainVS(appdata I,
	uniform float4x4 worldViewProjMatrix,
	uniform float4x4 invWorldMatrix,
	uniform float4 light_pos,
	uniform float4 camera_pos,
   uniform float4 fog_data)
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

#ifdef S2_FOG
  O.fog = calcFog(O.hposition, fog_data);
#endif

	return O;
}

fragout mainPS(pixdata I,
    uniform sampler2D   texture0,
    uniform sampler2D   texture1,
    uniform sampler2D   texture2,
    uniform samplerCUBE textureCube,
    uniform float4      light_col_diff,
    uniform float4      light_data)
{
	fragout O;

	// get texture values
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
/*	s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	s2half4 tex2 = tex2D(texture2, I.texcoord0.xy);
	// get normal vector from bumpmap texture
	s2half3 nrm = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));

	// calc diffuse
	s2half3 l0_dir = normalize(I.pix_to_li_t.xyz);
	float4 diffuse = saturate(dot(l0_dir, nrm)) * light_col_diff;

	// calc specular
	s2half3 c_dir = normalize(I.pix_to_c.xyz);
	s2half3 half_vec = normalize(l0_dir + c_dir);
	s2half4 specular =  pow(saturate(dot(half_vec, nrm)), 20.0) * tex1 * light_col_diff;

	// calc distance of light
	float dist_to_light = dot(I.pix_to_li_o.xyz, I.pix_to_li_o.xyz);
	// build intensity from distance to light using light radius
	s2half temp_dist = saturate(dist_to_light  * light_data.z * light_data.z);
	s2half intensity = (1.0 - temp_dist) * (1.0 - temp_dist); // 1.0 - sin(1.5708 * temp_dist);
	// multiply it by intensity of ight source
	intensity *= light_data.y;

	// shadow
	s2half4 texC = texCUBE(textureCube, -1.0 * l0_dir.xzy);

	O.col = intensity * ((diffuse * tex0) + specular);
	O.col.a = tex0.a;*/
	O.col = float4(1.0f, 0.0, 1.0f, 1.0f);

	return O;
} 

#else

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
#ifdef S2_FOG
  float2 depthFog     : TEXCOORD4;
#endif
};

struct fragout {
	s2half4 col[2]      : COLOR;
};

pixdata mainVS(appdata I,
	uniform float4x4 worldViewProjMatrix,
	uniform float4x4 invWorldMatrix,
	uniform float4 light_pos,
	uniform float4 camera_pos,
  uniform float4 zfrustum_data,
  uniform float4 fog_data )
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

fragout mainPS(pixdata I,
    uniform sampler2D   texture0,
    uniform sampler2D   texture1,
    uniform sampler2D   texture2,
    uniform sampler2D   fog_texture,
    uniform samplerCUBE textureCube,
    uniform float4      light_col_diff,
    uniform float4      light_data)
{
	fragout O;

	// get texture values
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	s2half4 tex2 = decode_normal(tex2D(texture2, I.texcoord0.xy));
	// get normal vector from bumpmap texture
//	s2half3 nrm = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));
	s2half3 nrm = tex2;

	// calc diffuse
	s2half3 l0_dir = normalize(I.pix_to_li_t.xyz);
	s2half4 diffuse = saturate(dot(l0_dir, nrm)) * light_col_diff;

	// calc specular
	s2half3 c_dir = normalize(I.pix_to_c.xyz);
	s2half3 half_vec = normalize(l0_dir + c_dir);
	s2half4 specular =  pow(saturate(dot(half_vec, nrm)), 20.0) * tex1 * light_col_diff;

	// calc distance of light
	float dist_to_light = dot(I.pix_to_li_o.xyz, I.pix_to_li_o.xyz);
	// build intensity from distance to light using light radius
	s2half temp_dist = saturate(dist_to_light  * light_data.z * light_data.z);
	s2half intensity = (1.0 - temp_dist) * (1.0 - temp_dist); // 1.0 - sin(1.5708 * temp_dist);
	// multiply it by intensity of ight source
	intensity *= light_data.y;
#ifdef S2_FOG
  fogPnt( intensity, fog_texture, I.depthFog );
#endif

	// shadow
	s2half4 texC = texCUBE(textureCube, -1.0 * l0_dir.xzy);

	O.col[0] = intensity * ((diffuse * tex0) + specular);
	O.col[0].a = tex0.a;
	O.col[1] = 2.5 * intensity * specular;
	O.col[1].a = tex0.a;

	return O;
} 

#endif