//#OptDef:S2_FOG

#define VERT_XVERTEX
#include "extractvalues.shader"


#ifdef SM1_1

// diffuse part of a velvet surface from a point lightsource




DEFINE_VERTEX_DATA


struct pixdata {
	float4 hposition   : POSITION;
	float4 texcoord0   : TEXCOORD0;
	float4 pix_to_c    : TEXCOORD1;
	float4 pix_to_li_o : TEXCOORD2;
	float4 normal      : TEXCOORD3;
#ifdef S2_FOG
  float fog    : FOG;
#endif
};

struct fragout {
	float4 col      : COLOR;
};

pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 invWorldMatrix,
    uniform float4   light_pos,
    uniform float4   camera_pos,
    uniform float4   fog_data)
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);
	float4 nrm4 = float4(I.normal, 0.0);

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

	// convert light pos from worldspace into objectspace
	float4 l_pos_obj = mul(light_pos, invWorldMatrix);
	// build vector from vertex pos to light pos
	float3 vertex_to_light = l_pos_obj.xyz - pos4.xyz;
	// pass vertex to light to pixelshader, so it becomes pixel to light
	O.pix_to_li_o = float4(vertex_to_light, 0.0);

	// convert cam pos from worldspace into objectspace
	float4 c_pos_obj = mul(camera_pos, invWorldMatrix);
	// build vector from vertex pos to cam pos
	float3 vertex_to_cam = c_pos_obj.xyz - pos4.xyz;
	// pass vertex to cam to pixelshader, so it becomes pixel to cam
	O.pix_to_c = float4(vertex_to_cam, 0.0);

	// normal
	O.normal = nrm4;

	// texture coords
	O.texcoord0 = I.texcoord.xyyy;

#ifdef S2_FOG
  O.fog = calcFog(O.hposition, fog_data);
#endif

	return O;
}

fragout mainPS(pixdata I,
    uniform sampler2D texture0,
    uniform sampler2D texture1,
    uniform float4 light_data,
    uniform float4 light_col_diff)
{
	fragout O;

	// get texture values
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);

	O.col = float4(1.0f, 0.0, 1.0f, 1.0f);

	return O;
} 

#else

// diffuse part of a velvet surface from a point lightsource

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
	float4 pix_to_c    : TEXCOORD1;
	float4 pix_to_li_o : TEXCOORD2;
	float4 normal      : TEXCOORD3;
#ifdef S2_FOG
  float2 depthFog    : TEXCOORD4;
#endif
};

struct fragout {
	float4 col[2]      : COLOR;
};

pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 invWorldMatrix,
    uniform float4   light_pos,
    uniform float4   camera_pos,
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

	// convert light pos from worldspace into objectspace
	float4 l_pos_obj = mul(light_pos, invWorldMatrix);
	// build vector from vertex pos to light pos
	float3 vertex_to_light = l_pos_obj.xyz - pos4.xyz;
	// pass vertex to light to pixelshader, so it becomes pixel to light
	O.pix_to_li_o = float4(vertex_to_light, 0.0);

	// convert cam pos from worldspace into objectspace
	float4 c_pos_obj = mul(camera_pos, invWorldMatrix);
	// build vector from vertex pos to cam pos
	float3 vertex_to_cam = c_pos_obj.xyz - pos4.xyz;
	// pass vertex to cam to pixelshader, so it becomes pixel to cam
	O.pix_to_c = float4(vertex_to_cam, 0.0);

	// normal
	O.normal = nrm4;

	// texture coords
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
#ifdef SM3_0
    float vFace : VFACE,
#endif
    uniform sampler2D texture0,
    uniform sampler2D texture1,
    uniform sampler2D fog_texture,
    uniform float4 light_data,
    uniform float4 light_col_diff)
{
	fragout O;

	// get texture values
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);

	// norm vector to light
	s2half3 to_light = normalize(I.pix_to_li_o.xyz);
	// norm vector to camera
	s2half3 to_cam = normalize(I.pix_to_c.xyz);
	// norm surface normal
	s2half3 sf_nrm = normalize(I.normal.xyz);
#ifdef SM3_0
	if(vFace > 0.0)
		sf_nrm *= -1.0;
#endif

	// retroreflective lobe
	s2half cosine = saturate(dot(to_light, to_cam));
	s2half3 shiny = pow(cosine, 7.0) * 0.3 * light_col_diff.xyz * tex0;

	// horizon scattering
	cosine = saturate(dot(sf_nrm, to_cam));
	s2half sine = sqrt(1.0 - cosine * cosine);
	shiny += pow(sine, 5.0) * dot(to_light, sf_nrm) * light_col_diff.xyz * tex0;

	// specular
	s2half3 half_vec = normalize(to_light + to_cam);
	s2half4 specular = tex1 * light_col_diff * pow(saturate(dot(half_vec, sf_nrm)), 10);

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

	// compose color
	O.col[0].xyz = /*shadow.rgb * */intensity * (shiny + specular.xyz); // shadows not working: extreme acne thin polys!
	O.col[0].a = tex0.a;
	O.col[1] = float4(0.0, 0.0, 0.0, 0.0);

	return O;
} 
#endif