// special ground fog
#include "S2Types.shader"

struct appdata
{
	float	 height                 : POSITION;
	float4 uvn                    : COLOR;
};

struct pixdata
{
  float4 hposition              : POSITION;
  float4 data                   : TEXCOORD0;
  float4 screenCoordsInTexSpace : TEXCOORD1;
  float4 worldPosition          : TEXCOORD2;
  float4 eyePosition            : TEXCOORD3;
};

struct fragout
{
  float4 col0                   : COLOR0;
  float4 col1                   : COLOR1;
};

pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 worldMatrix,
  uniform float4   weather_pos,
  uniform float4   camera_pos,
  uniform float4   zfrustum_data)
{
	pixdata O;
	
	// Do all the decompression here, compiler will optimize and remove unused calculations
	// Please do not change this code, as it has been carefully reordered to trick the optimizer
	// vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
	float4 scaler = I.uvn.xyxy * float4(weather_pos.zw * 42.5, 42.5, 42.5);	// Rescale from 0/255..6/255 to 0..1
	float3 position = float3(scaler.xy + weather_pos.xy, I.height);
	float2 texcoord = scaler.zw;	
	// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
	
	// groundfog height
	float3 fog_position = position + float3(0.0, 0.0, 40.0);
	
	// vertex pos
	float4 pos4 = float4(fog_position, 1.0);
	O.hposition = mul(pos4, worldViewProjMatrix);
	
	// distance of high-border
  float distance = (O.hposition.w - zfrustum_data) * zfrustum_data.z;
  
  // screen coords
  O.screenCoordsInTexSpace.x = O.hposition.w + O.hposition.x;
  O.screenCoordsInTexSpace.y = O.hposition.w - O.hposition.y;
  O.screenCoordsInTexSpace.z = O.hposition.z;
  O.screenCoordsInTexSpace.w = 2.0 * O.hposition.w;
  O.screenCoordsInTexSpace.xy *= target_data.xy;
	
	// put all data in vec4
	O.data = float4(distance, texcoord, zfrustum_data.y);
	O.worldPosition = mul(pos4, worldMatrix);
	O.eyePosition = camera_pos;

	return O;
}





fragout mainPS(pixdata I,
  uniform sampler2D   depth_map,
  uniform sampler3D   textureVolume,
  uniform float4      light_col_amb)
{
	fragout O;
	
	// consts
	const float IT_STEP_LEN = 1.0 / 500.0;
	const float FOG_SIZE = float4(0.005, 0.005, 0.02, 0.0);
	const float OPAQUE_DEPTH = 0.075;
	
	// give usefull names
	float near_dist = I.data.x;
	float2 tex_coords = I.data.yz;
	float z_far = I.data.w;
	
	// get low_dist from depth-texture
  float far_dist = tex2Dproj(depth_map ,I.screenCoordsInTexSpace).x;
  
  // delta is how-deep-in-fog
  float delta_fog = saturate(OPAQUE_DEPTH * (far_dist - near_dist));
  
  // iterate along view-line!
  float3 view_line = I.worldPosition.xyz - I.eyePosition.xyz;
  float3 view_dir = normalize(view_line);
  // startpoint in 3d texture space
  float4 start_pnt_tv = frac(FOG_SIZE * float4(I.worldPosition.xyz, 0.0));
  // how many iterations?
  int it_count = 1 + (int)((far_dist - near_dist) / IT_STEP_LEN);
  // how long is a single iteration step?
  float3 delta_tv = view_dir * z_far * IT_STEP_LEN * FOG_SIZE;
  
  float fog_intensity = 0.0;
  for(int i = 0; i < it_count; i++)
  {
    // acuumulate!
    fog_intensity += tex3Dlod(textureVolume, start_pnt_tv).x;
    start_pnt_tv.xyz += delta_tv;
  }
  fog_intensity *= OPAQUE_DEPTH;
  
  float debug_c = 0.1 * (float)it_count;
  
	O.col0 = float4(light_col_amb.xyz, fog_intensity/* * delta_fog*/);
//	O.col0 = float4(fog_intensity, 0.0, 0.0, 1.0);
//  O.col0 = float4(delta_tv, 1.0);
	O.col1 = float4(0.0, 0.0, 0.0, 1.0);

	return O;
} 
