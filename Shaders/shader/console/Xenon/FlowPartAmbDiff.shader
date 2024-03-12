// standard
/*
#ifdef CONSOLE_IMPL
  const CHAR* g_strFlowPartVSCode = 
  "float4x4 g_matWVP    : register(c0 );         "
  "float4   g_OfsTex[16]: register(c4 );         "
  "float4   g_fTime     : register(c20);         "
  "                                              "
  "struct FlowPartVS_Input                       "
  "{                                             "
  "    float4 Pos : POSITION;                    "
  "    float4 Col : COLOR;                       "
  "};                                            "
  "                                              "
  "struct FlowPartVS_Output                      "
  "{                                             "
  "    float4 Pos   : POSITION;                  "
  "    float2 UV    : TEXCOORD0;                 "
  "};                                            "
  "                                              "
  "FlowPartVS_Output main( FlowPartVS_Input Input )"
  "{                                             "
  "    FlowPartVS_Output Output;                 "
  "                                              "
  "    float4 pos    = Input.Pos;                "
  "                                              "
  " //////////////// Rotation ////////////////   "
  "    int    idx    = Input.Col.a*256;          "
  "    float4 ofs    = g_OfsTex[idx];            "
  "    float3 offset = float3( ofs.xy, 0 );      "
  "                                              "
  "	   float2 SC;                                "
  "	   float3 rot   = Input.Col.xyz*2-1;         "
  "    float  angle = length(rot)*g_fTime.x;     "
  "	                                             "
  "	   sincos( angle, SC.x, SC.y );              "
  "    rot = normalize(rot.zyx);                 "
  "	                                             "
  "	   float3 diag = (((rot*rot)-1)*(1-SC.y))+1; "
  "	   float3 spos = SC.x * rot;                 "
  "	   float3 cpos = ((1-SC.y) * rot) * rot.yzx; "
  "                                              "
  " float3x3 mat =                               "
  " { diag.x, -spos.z + cpos.x, spos.y + cpos.z, "
  "   spos.z + cpos.x, diag.y, -spos.x + cpos.y, "
  "  -spos.y + cpos.z, spos.x + cpos.y, diag.z   "
  " };                                           "
  "    offset      = mul(offset, mat );          "
  "                                              "
  "    pos.xyz    += offset;                     "
  " ////////////// End Rotation //////////////   "
  "                                              "
  "    Output.Pos  = mul( pos, g_matWVP );       "
  "                                              "
  "    Output.UV  = ofs.zw;                      "
  "                                              "
  "    return Output;                            "
  "}                                             ";

  const CHAR* g_strFlowPartPSCode = 
  " sampler2D ColorTexture : register(s0);       "
  "                                              "
  "struct FlowPartPS_Input                       "
  "{                                             "
  "    float2 UV    : TEXCOORD0;                 "
  "};                                            "
  "                                              "  
  "float4 main( FlowPartPS_Input Input ) : COLOR "
  "{                                             "
  "    return tex2D(ColorTexture, Input.UV );    "
  "}                                             ";
#endif
*/

#include "S2Types.shader"

struct appdata {
	float3 position : POSITION;
	float4 Col		: COLOR;
};

struct pixdata {
	float4 hposition   : POSITION;
	float4 texcoord0   : TEXCOORD0;
	float4 screenCoord : TEXCOORD1;
};

struct fragout {
	float4 col[2]      : COLOR;
};

float4   g_OfsTex[16]: register(c14);
float4   g_fTime     : register(c30);
  
pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4   target_data )
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);

    //////////////// Rotation ////////////////
    int    idx    = I.Col.a*256;
    float4 ofs    = g_OfsTex[idx];
    float3 offset = float3( ofs.xy, 0 );

    float2 SC;
    float3 rot   = I.Col.xyz*2-1;
    float  angle = length(rot)*g_fTime.x;

    sincos( angle, SC.x, SC.y );
    rot = normalize(rot.zyx);

    float3 diag = (((rot*rot)-1)*(1-SC.y))+1;
    float3 spos = SC.x * rot;
    float3 cpos = ((1-SC.y) * rot) * rot.yzx;

    float3x3 mat =
    { diag.x, -spos.z + cpos.x, spos.y + cpos.z,
      spos.z + cpos.x, diag.y, -spos.x + cpos.y,
     -spos.y + cpos.z, spos.x + cpos.y, diag.z
    };
    offset      = mul(offset, mat );

    pos4.xyz    += offset;
    ////////////// End Rotation //////////////
  
	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

	// vertex-position in screen space
	O.screenCoord.x = O.hposition.w + O.hposition.x;
	O.screenCoord.y = O.hposition.w - O.hposition.y;
	O.screenCoord.z = 0.0;
	O.screenCoord.w = 2.0 * O.hposition.w;
	O.screenCoord.xy *= target_data.xy;

	// texture coords
	O.texcoord0 = ofs.zwww;

	return O;
}

fragout mainPS(pixdata I,
    uniform sampler2D texture0,
    uniform sampler2D shadow_texture,
    uniform float4    light_col_amb,
    uniform float4    light_col_diff)
{
  fragout O;

  // get texture values
  s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);

  // get shadow term from shadow texture
  s2half4 shadow = tex2Dproj(shadow_texture, I.screenCoord);

  // lighting
  // calc sun diffuse
  float3 sun_diff = light_col_diff.xyz * tex0.rgb * 0.5f;

  // calc moon diffuse
  float3 moon_diff = light_col_amb.xyz * tex0.rgb * (0.5 + 0.5f);

  // set output color
  O.col[0].rgb = moon_diff + shadow.z * sun_diff;
  O.col[0].a = tex0.a;
  O.col[1].rgb = 0;
  O.col[1].a = 0;

  return O;
} 
