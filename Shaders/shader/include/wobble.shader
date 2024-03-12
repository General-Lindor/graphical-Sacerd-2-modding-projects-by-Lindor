
//no wooble support for <sm30
#ifndef SM3_0
 #ifdef ENABLE_WOBBLE
   #undef ENABLE_WOBBLE
 #endif
#endif
 
 

#define FLOWERS_WOBBLE_CENTER_MAX 8
#ifdef ENABLE_WOBBLE
  ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // main function for wobbling grass
  float3x3 calcWobble(float4 wobbleCenterList[FLOWERS_WOBBLE_CENTER_MAX], float2 flowerPos, float height)
  {
	  // sum up wobbles
	  float2 wobbleAxis = float2(0.0, 0.1);
	  float wobblePower = 0.0;
	  for(int i = 0; i < FLOWERS_WOBBLE_CENTER_MAX; i++)
	  {
		  // from-to
		  float2 fromTo = wobbleCenterList[i].xy - flowerPos.xy;
		  // calc dist from flower-pos to wobble-center
		  float dist = saturate(length(fromTo) / wobbleCenterList[i].z);
		  // influence
		  float infl = wobbleCenterList[i].w * lerp(1.0, 0.0, dist);
		  // add influence-pre-scaled
		  wobbleAxis += infl * fromTo;
		  wobblePower += infl * sin(2.0 * 3.1415926 * 3.0 * wobbleCenterList[i].w);
	  }
	  // normalize!
	  wobblePower = clamp(wobblePower, -1.0, 1.0);
	  wobbleAxis = normalize(wobbleAxis);
	  // 90degree turn to get rotate vector
	  wobbleAxis = float2(-1.0, 1.0) * wobbleAxis.yx;
	  // wobble angle depends on height
	  float alpha = height * 0.01 * wobblePower;
	  // build wobble rotation matrix
	  float cs = cos(alpha);
	  float sn = sin(alpha);
	  float oneMinusCos = 1.0 - cs;
	  float3 f2 = float3(wobbleAxis.xy * wobbleAxis.xy, 0.0);
	  float3 fM = oneMinusCos * float3(wobbleAxis.x * wobbleAxis.y, 0.0, 0.0);
	  float3 fSin = float3(sn * wobbleAxis.xy, 0.0);
	  float3x3 rotMat;
	  rotMat[0] = float3(f2.x * oneMinusCos + cs, fM.x - fSin.z,           fM.y + fSin.y          );
	  rotMat[1] = float3(fM.x + fSin.z,           f2.y * oneMinusCos + cs, fM.z - fSin.x          );
	  rotMat[2] = float3(fM.y - fSin.y,           fM.z + fSin.x,           f2.z * oneMinusCos + cs);

	  return rotMat;
  }
#else
  float3x3 calcWobble(float4 wobbleCenterList[FLOWERS_WOBBLE_CENTER_MAX], float2 flowerPos, float height)
  {
	  float3x3 rotMat;
	  rotMat[0] = float3(1.0, 0.0, 0.0);
	  rotMat[1] = float3(0.0, 1.0, 0.0);
	  rotMat[2] = float3(0.0, 0.0, 1.0);

	  return rotMat;
  }
#endif //ENABLE_WOBBLE
