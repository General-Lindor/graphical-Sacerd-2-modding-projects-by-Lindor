//#OptDef:SPASS_G
//#OptDef:SPASS_SHADOWMAP
//#OptDef:SPASS_CUBESHADOWMAP
//#OptDef:SPASS_AMBDIF
//#OptDef:SPASS_PNT
//#OptDef:SPASS_LIGHTNING

#define VS_IN_TREELEAFVERTEX
#define PS_SIMPLESHADOW

#define ZTEST
#define USE_EARLY_OUT
#ifdef SPASS_G
  #define USE_VERTEX_NORMAL
#endif

/////////////////////////////////////
// SPASS_AMBDIF setup
/////////////////////////////////////
#ifdef SPASS_AMBDIF 
  #define USE_VERTEX_NORMAL
  #define VS_OUT_G
  #define PS_SPASS_AMBDIF_NONORMAL_20
#endif  

/////////////////////////////////////
// SPASS_PNT setup
/////////////////////////////////////
#ifdef SPASS_PNT
  #define VS_OUT_PNT_20
  #define PS_SPASS_PNT_NONORMAL_20
#endif

#include "treeShared.shader"

