// vertical rain streaks
#include "extractvalues.shader"

struct appdata {
	float3 position   : POSITION;
	float4 color      : COLOR;
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 texcoord0  : TEXCOORD0;
	float4 color      : COLOR0;
	float4 color1     : COLOR1;
	float psize       : PSIZE;
};

pixdata mainVS(appdata I,
    uniform float4x4  worldViewProjMatrix,
    uniform float4x4  worldViewMatrix,
    uniform float4    vtx_data_array[34],
    uniform float4    camera_pos)
{
	pixdata O;
	
	
	float id         = I.color.b*255;
	float num        = I.color.g;
	float speed_fact = (id%64)/64;
	int tex_id       = (id%4);
	int group_id     = (id%32);
	float scale_fact = ((id%15)/15)+0.5;
	
	
	
	float fade_start = vtx_data_array[32].x;
	float fade_end   = vtx_data_array[32].y;
	float psize      = vtx_data_array[32].z;
	
	float intensity = 1-smoothstep(fade_start,fade_end,num);
	
	
	float4 group_param = vtx_data_array[group_id];

	// give usefull names
	float3 rainColor   = vtx_data_array[33].xyz;
	

	float3 sn_cubepos = I.position;
	

	float3 snpos = sn_cubepos+group_param.xyz;

	snpos   = snpos%1;
	snpos.z = 1.0f-snpos.z;
	
	float4 pos4 = float4(snpos*200,1);
	// transform
    float camSpaceZ = pos4.x*worldViewMatrix[0][2] +  
 	 				  pos4.y*worldViewMatrix[1][2] + 
 	 				  pos4.z*worldViewMatrix[2][2] + 
					  worldViewMatrix[3][2];
					  
	float nearscale = saturate((camSpaceZ+400)/400);
	O.hposition = mul(pos4, worldViewProjMatrix); 
	
	
	float dist_scale   = camSpaceZ/-600.0f;
	dist_scale         = dist_scale*dist_scale;
	float dist_scale_i = 1-dist_scale;
	
	// color
	O.color     = float4(rainColor, 1);
	O.color.a   = group_param.w*intensity;
//	O.color.a  *= dist_scale_i-sn_cubepos.z*0.3;
	O.texcoord0 = float4(0,0,0,0);
	O.psize     = dist_scale_i*psize*scale_fact+psize;
	O.color1    = float4(nearscale*3,0.25*tex_id,0,0);
//	O.color1.y  = 0.5;
	return O;
}

fragout_t mainPS(pixdata I, 
				 uniform float4 param,
				 uniform sampler2D texture0)
{
	fragout_t O;
	float4 uv4  = float4(I.texcoord0.xy,0,0);
	uv4.y       = uv4.y*0.25+I.color1.y;
	
	uv4.x      *= param.x;
	
	
	
	uv4.w       = I.color1.x;
	float4 tex0 = tex2Dbias(texture0, uv4 );
	
	
	// out	
	set_out_color(tex0*I.color);
	set_out_glow(float4(0.0, 0.0, 0.0, 0.0));
	return O;
} 
