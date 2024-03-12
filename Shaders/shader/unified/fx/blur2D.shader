// blur
#include "extractvalues.shader"

#if defined(SM1_1)
  //////////////////////////////////////////////////////////
  // SM1_1 code path
  //////////////////////////////////////////////////////////
  struct appdata {
	  float3 position   : POSITION;
	  float2 texcoord0  : TEXCOORD0;
	  float2 texcoord1  : TEXCOORD1;
  };

  struct pixdata {
	  float4 hposition  : POSITION;
	  float4 texcoord0  : TEXCOORD0;
	  float4 texcoord1  : TEXCOORD1;
	  float4 texcoord2  : TEXCOORD2;
	  float4 texcoord3  : TEXCOORD3;
  };

  struct fragout {
	  float4 col        : COLOR;
  };

  pixdata mainVS(appdata I,
		  uniform float4    param)
  {
	  pixdata O;

	  // vertex pos already transformed
	  O.hposition = float4(I.position.xy, 0.0, 1.0);

	  // use all texcoord[#n] registers
	  float2 pnt = I.texcoord0 - 0.5 * param.xy;

	  O.texcoord0 = pnt.xyyy; // -1.5
	  pnt += param.xy;
	  O.texcoord1 = pnt.xyyy; // -0.5
	  pnt += param.xy;
	  O.texcoord2 = pnt.xyyy; //  0.5
	  pnt += param.xy;
	  O.texcoord3 = pnt.xyyy; //  1.5

	  return O;
  }

  fragout mainPS(pixdata I,
		  uniform sampler2D texture0)
  {
	  fragout O;

	  // intensity to fake hdr!
	  const float intensity = 2.0;

	  // gaus verteilung with step 0.6 (console: SYS STEVE 0.6)
	  float4 color = float4(0.0, 0.0, 0.0, 1.0);
	  color += intensity * (0.667 / 3.246) * tex2D(texture0, I.texcoord0.xy); // -1.5
	  color += intensity * (0.956 / 3.246) * tex2D(texture0, I.texcoord1.xy); // -0.5
	  color += intensity * (0.956 / 3.246) * tex2D(texture0, I.texcoord2.xy); //  0.5
	  color += intensity * (0.667 / 3.246) * tex2D(texture0, I.texcoord3.xy); //  1.5
	  O.col = color;

	  return O;
  } 

#else
  //////////////////////////////////////////////////////////
  // >SM2_0 code path
  //////////////////////////////////////////////////////////
  struct appdata {
	  float3 position   : POSITION;
	  float2 texcoord0  : TEXCOORD0;
	  float2 texcoord1  : TEXCOORD1;
  };

  struct pixdata {
	  float4 hposition  : POSITION;
	  float4 texcoord0  : TEXCOORD0;
	  float4 texcoord1  : TEXCOORD1;
	  float4 texcoord2  : TEXCOORD2;
	  float4 texcoord3  : TEXCOORD3;
	  float4 texcoord4  : TEXCOORD4;
	  float4 texcoord5  : TEXCOORD5;
  };

  struct fragout {
	  float4 col        : COLOR;
  };


  pixdata mainVS(appdata I,
		  uniform float4    param)
  {
	  pixdata O;

	  // vertex pos already transformed
	  O.hposition     = float4(I.position.xy, 0.0, 1.0);
	  float2 texcoord = (I.texcoord0.xy-viewport_data.xy)*viewport_data.zw;
	  // put two texcoords in one register!
	  float4 pnt = texcoord.xyxy - 4.5 * param.xyxy + float4(0.0, 0.0, param.x, param.y);

	  O.texcoord0 = pnt; // -5.5/-4.5
	  pnt += 2.0 * param.xyxy;
	  O.texcoord1 = pnt; // -3.5/-2.5
	  pnt += 2.0 * param.xyxy;
	  O.texcoord2 = pnt; // -1.5/-0.5
	  pnt += 2.0 * param.xyxy;
	  O.texcoord3 = pnt; //  0.5/ 1.5
	  pnt += 2.0 * param.xyxy;
	  O.texcoord4 = pnt; //  2.5/3.5
	  pnt += 2.0 * param.xyxy;
	  O.texcoord5 = pnt; //  4.5/5.5

	  return O;
  }

  fragout mainPS(pixdata I,
		  uniform sampler2D texture0)
  {
	  fragout O;

	  // intensity to fake hdr!
	  const float intensity = 2.0;

	  // gaus verteilung with step 0.6 (console: SYS STEVE 0.395)
	  float4 color = float4(0.0, 0.0, 0.0, 1.0);
	  color += intensity * (0.094 / 6.238) * tex2D(texture0, I.texcoord0.xy); // -5.5
	  color += intensity * (0.206 / 6.238) * tex2D(texture0, I.texcoord0.zw); // -4.5
	  color += intensity * (0.385 / 6.238) * tex2D(texture0, I.texcoord1.xy); // -3.5
	  color += intensity * (0.614 / 6.238) * tex2D(texture0, I.texcoord1.zw); // -2.5
	  color += intensity * (0.839 / 6.238) * tex2D(texture0, I.texcoord2.xy); // -1.5
	  color += intensity * (0.981 / 6.238) * tex2D(texture0, I.texcoord2.zw); // -0.5
	  color += intensity * (0.981 / 6.238) * tex2D(texture0, I.texcoord3.xy); //  0.5
	  color += intensity * (0.839 / 6.238) * tex2D(texture0, I.texcoord3.zw); //  1.5
	  color += intensity * (0.614 / 6.238) * tex2D(texture0, I.texcoord4.xy); //  2.5
	  color += intensity * (0.385 / 6.238) * tex2D(texture0, I.texcoord4.zw); //  3.5
	  color += intensity * (0.206 / 6.238) * tex2D(texture0, I.texcoord5.xy); //  4.5
	  color += intensity * (0.094 / 6.238) * tex2D(texture0, I.texcoord5.zw); //  5.5
	  O.col = color;

	  return O;
  } 
#endif

