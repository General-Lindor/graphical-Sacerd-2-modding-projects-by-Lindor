// vertical rain streaks
#include "extractvalues.shader"

struct appdata {
	float3 position   : POSITION;
	float4 color      : COLOR;
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 color      : COLOR;
};

pixdata mainVS(appdata I,
    uniform float4x4  worldViewProjMatrix,
    uniform float4    vtx_data_array[4])
{
	pixdata O;
	
	// give usefull names
	float weather_time = vtx_data_array[0].x;
	float drop_speed = 0.8;
	float streak_length = lerp(20.0, 45.0, vtx_data_array[0].y);
	float distortion_strength = 0.12;
	float drop_height = vtx_data_array[2].z;
	float3 rainColor = vtx_data_array[1].xyz;
	float2 drop_area = vtx_data_array[2].xy;
	
	// calc random0
	float random0 = 10.0 * I.position.x;
	// calc random1
	float random1 = fmod(3719.0 * random0 + (3719.0 / 2.0), 32768.0);
	float offs_x = random1 / 32768.0;
	// calc random2
	float random2 = fmod(3719.0 * random1 + (3719.0 / 2.0), 32768.0);
	float offs_y = random2 / 32768.0;
	// calc random3
	float random3 = fmod(3719.0 * random2 + (3719.0 / 2.0), 32768.0);
	float offs_t = random3 / 32768.0;
	// calc random4
	float random4 = fmod(3719.0 * random3 + (3719.0 / 2.0), 32768.0);
	float dir_x = random4 / 32768.0;
	// calc random5
	float random5 = fmod(3719.0 * random4 + (3719.0 / 2.0), 32768.0);
	float dir_y = random5 / 32768.0;
	
	// form direction vector for slightly anti-parallelism
	float3 drop_dir = normalize(float3(distortion_strength * (dir_x - 0.5), distortion_strength * (dir_y - 0.5), -1.0));
	
	// calc height
	float h = drop_height * (1.0 - fmod(weather_time + drop_speed * offs_t, drop_speed) / drop_speed);
	
	// calc 3d startpoint
	float3 start_pnt = float3(drop_area * float2(offs_x, offs_y) - drop_area * float2(0.5, 0.5), drop_height);

	// calc 3d point	
	float3 current_pnt = start_pnt + drop_dir * (drop_height * fmod(weather_time + drop_speed * offs_t, drop_speed) / drop_speed + I.position.z * streak_length - streak_length);
	
	// pos
	float4 pos4 = float4(current_pnt, 1.0);

	// transform
	O.hposition = mul(pos4, worldViewProjMatrix);
	
	// color
	O.color = float4(rainColor, I.position.z * 0.3);

	return O;
}

fragout_t mainPS(pixdata I)
{
	fragout_t O;
	
  // out
  set_out_color(I.color);
  set_out_glow(float4(0.0, 0.0, 0.0, 0.0));
	return O;
} 
