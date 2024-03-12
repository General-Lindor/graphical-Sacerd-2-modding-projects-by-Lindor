//#OptDef:SPASS_G
//#OptDef:SPASS_SHADOWMAP
//#OptDef:SPASS_CUBESHADOWMAP
//#OptDef:SPASS_AMBDIF
//#OptDef:SPASS_PNT
//#OptDef:SPASS_LIGHTNING
//#OptDef:VERTEXLIGHTING_TEST


#define VS_IN_TREEVERTEX
#define PS_SIMPLESHADOW

/////////////////////////////////////
// SPASS_AMBDIF setup
/////////////////////////////////////
#ifdef SPASS_AMBDIF
  #if defined(SM1_1)
    #define PS_SPASS_AMBDIF_NONORMAL_11
  #else
    #define PS_SPASS_AMBDIF_NONORMAL_20
  #endif
#endif
/////////////////////////////////////
// SPASS_PNT setup
/////////////////////////////////////
#ifdef SPASS_PNT
  #if defined(SM1_1)
    #define PS_DUMMY_11
  #else
    #define PS_SPASS_PNT_NONORMAL_20
  #endif
#endif
/////////////////////////////////////
// SPASS_LIGHTNING setup
/////////////////////////////////////
#ifdef SPASS_LIGHTNING
  #if defined(SM1_1)
    #define PS_NULL_11
  #else
    #define PS_NULL_20
  #endif
#endif

#include "treeShared.shader"

