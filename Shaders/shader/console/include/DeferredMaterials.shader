// warning: this file gets included in shader as well as cpp code!
// make sure not to add HLSL or cpp specific code!

//#ifdef PS3_IMPL
#define MAT_DEFAULT       (  0.f/255.f )
#define MAT_METAL         (  1.f/255.f )
#define MAT_SKIN          (  2.f/255.f )
#define MAT_CLOTH         (  3.f/255.f )
#define MAT_VELVET        (  4.f/255.f )
#define MAT_LTX           (  5.f/255.f )
#define MAT_BARK          (  6.f/255.f )
#define MAT_LEAVES        (  7.f/255.f )
#define MAT_ANISOCLOTH    (  8.f/255.f )
#define MAT_WHATEVERCLOTH (  9.f/255.f )
#define MAT_THINFILM      ( 10.f/255.f )

#define MAT_GROUND        ( 30.f/255.f )
#define MAT_GRASS         ( 31.f/255.f )