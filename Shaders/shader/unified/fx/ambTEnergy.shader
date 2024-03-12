//#OptDef:SPASS_ITEMPREVIEW

#include "extractvalues.shader"

struct appdata {
	float3 position   : POSITION;
	float3 normal     : NORMAL;
	float3 tangent    : TANGENT;
	float3 binormal   : BINORMAL;
	float2 texcoord  : TEXCOORD0;
	float2 texcoord2  : TEXCOORD1;
};

struct pixdata {
	float4 hposition   : POSITION;
	float4 texcoord0   : TEXCOORD0;
	float4 texcoord1   : TEXCOORD1;
};

#if defined(SM1_1)
  //////////////////////////////////////////////////////////
  //SM1_1 code path
  //////////////////////////////////////////////////////////
  struct fragout {
	  float4 col      : COLOR;
  };

  pixdata mainVS(appdata I,
                 uniform float4x4 worldViewProjMatrix)
  {
	  pixdata O;
  	
	  float4 pos4 = float4(I.position, 1.0);
  	
	  // vertex pos
	  O.hposition = mul(pos4, worldViewProjMatrix);
  	
	  // pass texture coords (two channels for this shader!)
	  O.texcoord0 = I.texcoord.xyyy;
	  O.texcoord1 = 0.94 * I.texcoord.xyyy;
	  //O.texcoord1.z = 0.3 * system_data.x;
	  //O.texcoord1.x += 0.3 * system_data.x;

	  return O;
  }

  fragout mainPS(pixdata I,
      uniform sampler2D   texture0,
      uniform sampler2D   texture1,
      uniform sampler2D   texture2,
      uniform sampler3D   textureVolume,
	    uniform float4      system_data)
  {
	  fragout O;

  /*	int i, octaves = 3;
	  float ampi = 0.652;
	  float ampm = 0.408;
	  float freqi = 0.94;
	  float freqm = 2.88;

	  float freq = freqi;
	  float amp = ampi;

	  float4 sum_col = float4(0.0, 0.0, 0.0, 0.0);

	  for(i = 0; i < octaves; i++)
	  {
		  sum_col += amp * tex3D(textureVolume, float3(freq * I.texcoord1.xy, 0.03 * system_data.x));
		  freq *= freqm;
		  amp *= ampm;	
	  }

	  // look up in color-fade texture
	  float4 perlin_col = tex2D(texture2, 0.9 * sum_col.xy);

	  // get mask
	  float4 tex0 = tex2D(texture0, I.texcoord0.xy);

	  // overlay burst (radial!)
	  float dist = length(I.texcoord1.xy);
	  float4 ob_col = tex2D(texture1, float2(dist - 0.3 * system_data.x, 0.0));
	  // push_up
	  float4 ob_col2 = 3.0 * ob_col + ob_col.wwww;

	  // compose color & glow
	  O.col = float4(perlin_col.xyz * ob_col2.xyz + 0.5 * ob_col.xyz, 1.0);
	  O.col.xyz *= tex0.a;*/

	  float4 tex0 = tex2D(texture0, I.texcoord0.xy);
	  float4 tex2 = tex2D(texture2, I.texcoord1.xy);
	  O.col.xyz = tex2.xyz * tex0.a;
	  O.col.w = 1.0f;

  /*	float4 sum_col = tex3D(textureVolume, I.texcoord1.xyz);
	  float4 perlin_col = tex2D(texture2, sum_col.xy);
	  float4 tex0 = tex2D(texture0, I.texcoord0.xy);

	  O.col.xyz = perlin_col.xyz * tex0.a;
	  O.col.w = 1.0f;*/

	  return O;
  } 

#else


  //////////////////////////////////////////////////////////
  // >SM2_0 code path
  //////////////////////////////////////////////////////////


  #ifdef SPASS_ITEMPREVIEW
    struct fragout {
	    float4 col[2]      : COLOR;
    };
  struct item_pixdata {
    float4 hposition   : POSITION;
    float4 texcoord0   : TEXCOORD0;
    float4 texcoord1   : TEXCOORD1;
    float3 tan_to_view0 : TEXCOORD5;
    float3 tan_to_view1 : TEXCOORD6;
    float3 tan_to_view2 : TEXCOORD7;
  };
  item_pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 invWorldMatrix,
    uniform float4   light_pos,
    uniform float4   camera_pos,
    uniform float4   zfrustum_data,
    uniform float4   fog_data,
    uniform float4x4 lightMatrix )
  {
	  item_pixdata O;
  	
	  float4 pos4 = float4(I.position, 1.0);
	  float4 nrm4 = float4(I.normal, 0.0);

	  // vertex pos
	  O.hposition = mul(pos4, worldViewProjMatrix);

	  // build object-to-tangent space matrix
	  float3x3 objToTangentSpace;
	  objToTangentSpace[0] = -1.0 * I.tangent;
	  objToTangentSpace[1] = -1.0 * I.binormal;
	  objToTangentSpace[2] = I.normal;
	  
	  objToTangentSpace = mul(objToTangentSpace,lightMatrix);

    // build tangent to view matrix
    O.tan_to_view0 = objToTangentSpace[0];
    O.tan_to_view1 = objToTangentSpace[1];
    O.tan_to_view2 = objToTangentSpace[2];

	  // texture coords
	  O.texcoord0 = I.texcoord.xyyy;
    O.texcoord1 = I.texcoord2.xyyy;
	  return O;
  }

  struct item_out {
    float4 col[2]      : COLOR;
  };
  


  item_out mainPS(item_pixdata I,
    uniform sampler2D texture0,
    uniform sampler2D texture1,
    uniform sampler2D texture2,
    uniform sampler2D texture3,
    uniform sampler3D textureVolume,
    uniform float4    system_data,
    uniform float4    pix_data_array) 
  {
	  item_out O;
    sTEnergy te;
    calc_tenergy(te,textureVolume,texture1,texture2,I.texcoord1.xy,length(I.texcoord1.xy),system_data.x);
    
    // get mask
    float4 tex0 = tex2D(texture0, I.texcoord0.xy);

    float4 out_color0 = float4(te.color0.xyz, tex0.a);
    float4 out_color1 = float4(te.color1.xyz, tex0.a);
  	
    O.col[0] = calcItemPreviewColor(I.tan_to_view0,I.tan_to_view1,I.tan_to_view2,
                                    out_color0,out_color0,float4(0,0,1,0));
    O.col[1] = float4(0,0,0,1);
    return O;
  } 

  #else
    struct fragout {
	    float4 col[2]      : COLOR;
    };
    pixdata mainVS(appdata I,
                   uniform float4x4 worldViewProjMatrix)
    {
	    pixdata O;
    	
	    float4 pos4 = float4(I.position, 1.0);
    	
	    // vertex pos
	    O.hposition = mul(pos4, worldViewProjMatrix);
    	
	    // pass texture coords (two channels for this shader!)
	    O.texcoord0 = I.texcoord.xyyy;
	    O.texcoord1 = I.texcoord2.xyyy;

	    return O;
    }

    fragout mainPS(pixdata I,
        uniform sampler2D   texture0,
        uniform sampler2D   texture1,
        uniform sampler2D   texture2,
        uniform sampler3D   textureVolume,
  	    uniform float4      system_data)
    {
	    fragout O;
      sTEnergy te;
      calc_tenergy(te,textureVolume,texture1,texture2,I.texcoord1.xy,length(I.texcoord1.xy),system_data.x);
    	
	    // get mask
	    float4 tex0 = tex2D(texture0, I.texcoord0.xy);

    	
	    // compose color & glow
	    O.col[0]      = te.color0;
	    O.col[0].xyz *= tex0.a;
	    O.col[1]      = te.color1;
	    O.col[1].xyz *= tex0.a;
    	
	    return O;
    } 
  #endif
#endif



