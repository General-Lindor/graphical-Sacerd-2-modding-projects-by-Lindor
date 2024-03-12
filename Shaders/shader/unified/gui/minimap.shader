// render a gr2 in the gui

//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:LAYER_BIT2
//#OptDef:LAYER_BIT3
//#OptDef:LAYER_BIT4
//#OptDef:TREE_HOLE


#ifdef TREE_HOLE // new shader code



#ifdef LAYER_BIT0
  #define DRAW_SATMAP
#endif

#ifdef LAYER_BIT1
  #define DRAW_ICONS
#endif

#ifdef LAYER_BIT2
  #define DRAW_WORLDMAP
#endif

#ifdef LAYER_BIT3
  #define DRAW_WORLDMAP_ICONS
#endif

#ifdef LAYER_BIT4
  #define DRAW_WORLDMAP_POIS
#endif


#include "s2types.shader"

#ifdef DRAW_ICONS

void mainVS(  in      float  idx   : TEXCOORD0,
              in      float2 itype : TEXCOORD1,
              in      float2 pos   : TEXCOORD2,
              in      float2 rot   : TEXCOORD3,
              out     float4 hpos  : POSITION,
              out     float2 tcs   : TEXCOORD0,
              out     float  alpha : TEXCOORD1,
              uniform float4 vtx_data_array[100]  )
{
  // rename constants
  float4 verts        = vtx_data_array[idx];
  float4 screen_rect  = vtx_data_array[4];
  float2 uv_offsets   = vtx_data_array[5].xy;
  float  zoom         = vtx_data_array[5].z;
  float2 w            = vtx_data_array[8].xy;
  float  fisheye_pow  = vtx_data_array[8].z;
  float  ar_rcp       = vtx_data_array[9].x;
  float  icon_scale   = vtx_data_array[9].y;
  float  uv_idx_offs  = vtx_data_array[9].z;
  float  uv_icon_size = vtx_data_array[9].w;
  float  sight_range  = vtx_data_array[6].x;

  // texture sampling coordinates
  float2 tuvs = float2( verts.x, 1.0 - verts.y );
  tcs = vtx_data_array[uv_idx_offs+itype.x].xy + tuvs * uv_icon_size;

  // TEXTURE COORDINATES
  float2   tuv  = pos;
           tuv.x =   - uv_offsets.x + tuv.x;
           tuv.y = (   uv_offsets.y - tuv.y );
  float2x2 mat   = vtx_data_array[7];
           tuv   = mul( tuv, mat );

           // no dynamic branching in SM2 and as our hero is in 0,0 we simply add an offset to all icons
           // so we have no division by zero when normalizing. As GeForce 7xxx cards can't properly handle
           // branching even with SM3 we always add the small offset
           tuv += 0.0001;
    float  weight  = w.x / fisheye_pow;
           tuv /= zoom;
    float  l1   = length( tuv );
    float2 dir  = normalize( tuv );
    float  limit = w.x * 0.5 + (1.f - w.x) * 1.0;
           l1   = l1 > limit ? limit : l1;
    float  l2   = sin( l1 * S2_PI );
    float  scale  = weight * l2 * 0.5 + (1.0 - weight) * l1;
           tuv    = dir * scale;
           tuv.y *= ar_rcp; // correct with aspect ratio for tab map
           tuv   += 0.5;
           // clamp to map edge
           tuv.x = tuv.x > 1.0 ? 1.0 : (tuv.x < 0.0 ? 0.0 : tuv.x);
           tuv.y = tuv.y > 1.0 ? 1.0 : (tuv.y < 0.0 ? 0.0 : tuv.y);

  // VERTEX ON SCREEN POSITION
  float2x2 local_rot  = { rot.y,  -rot.x, rot.x, rot.y };
           verts.xy  = mul( mul( verts.xy - 0.5, local_rot ), mat );
  hpos = float4( (screen_rect.xy + tuv * screen_rect.zw - target_data.zw * 0.5 + verts.xy * icon_scale ) * target_data.zw * 2.0 - 1.0, 0.0, 1.0 );

  // alpha value used to fade in/out items at the border of the sight range
  float2 delta = pos;
         delta.x = - uv_offsets.x + delta.x;
         delta.y =   uv_offsets.y - delta.y;
         delta.x = dot( delta, delta ) / sight_range;
         delta.x = delta.x > 1.0 ? 1.0 : delta.x;
  alpha = 1.0 - pow( asin( delta.x ) / S2_PI * 2.0, 2.0 ) + itype.y;
  alpha = alpha > 1.0 ? 1.0 : alpha;
}

void mainPS(  in      float2    tcs   : TEXCOORD0,
              in      float     alpha : TEXCOORD1,
             out      float4    col   : COLOR,
             uniform  sampler2D texture0,
             uniform  float4    param           )
{
  float  glob_alpha  = param.w;
  col = tex2D( texture0, tcs );
  col.a *= glob_alpha * alpha;
}

#endif 


#ifdef DRAW_SATMAP // normal minimap rendering

void mainVS( in  float  idx  : TEXCOORD0,
             out float4 hpos : POSITION,
             out float4 tc0  : TEXCOORD0,
             out float2 fow  : TEXCOORD1,
             out float2 zoom : TEXCOORD2,
             out float4 mc   : TEXCOORD3,
             out float2 rim  : TEXCOORD4,
             uniform float4   vtx_data_array[10])
{
  float4 uvs = vtx_data_array[idx];
  float4 screen_rect  = vtx_data_array[4];
  float2 uv_offsets   = vtx_data_array[5].xy;
         zoom.x       = vtx_data_array[5].z;
         zoom.y       = vtx_data_array[6].w;
  float2 fow_offsets  = vtx_data_array[6].xy;
  float2 fow_zoom     = vtx_data_array[6].zw;
  float  ar_rcp       = vtx_data_array[9].x;  // aspect ratio reciproque


  // VERTEX ON SCREEN POSITION
  // set position of on screen quad in NDC (target_data.zw is 1 / scr_width and 1 / scr_height)
  hpos = float4( (screen_rect.xy + uvs.xy * screen_rect.zw - target_data.zw * 0.5) * target_data.zw * 2.0 - 1.0, 0.0, 1.0 );

  // TEXTURE COORDINATES
  float2 tuv = uvs.zw;
  // move the TCs to the origin
  tuv -= 0.5;
  // rotate and scale them
  float2x2 mat = vtx_data_array[7];
  tuv = mul( tuv, mat );

  // write the coordinates into the output register
  tc0.xy = tuv * zoom.x + uv_offsets + 0.5;
  tc0.zw = mul( (uvs.zw * 2.0 - 1.0), mat );

  // write fog of war coordinates
  fow = tuv * zoom.x * fow_zoom + fow_offsets + 0.5;
  // flip the FoW texture
  fow.y = 1.0 - fow.y;

  // texture center and fow center needed for fisheye effect
  mc.xy = 0.5 + uv_offsets;
  mc.zw = float2( 0.5 + fow_offsets.x, 1.0 - (0.5 + fow_offsets.y) );

  rim.xy = (uvs.zw * 2.0 - 1.0);
  rim.y *= ar_rcp;
}


void mainPS( in float4  tc0  : TEXCOORD0,
             in float2  fow  : TEXCOORD1,
             in float2  zoom : TEXCOORD2,
             in float4  mc   : TEXCOORD3,
             in float2  rim  : TEXCOORD4,
             out float4 col0 : COLOR0,
             uniform sampler2D texture0,
             uniform sampler2D texture1,
             uniform float4    param )
{
  float2 w           = param.xy;
  float  fisheye_pow = param.z;
  float  glob_alpha  = param.w;
  float  l           = length( tc0.zw );
  
  float alpha = (l < 1.0 ? 1.0 : w.y) * glob_alpha;
  clip( alpha - 0.01 );

  // circular rim
  float4 rim_color_circ = float4( 164.0 / 255.0, 164.0 / 255.0, 164.0/ 255.0, 0.0 );
  float  rim_inner = 0.97;
  float  fade = saturate( (l - rim_inner) / ( 1.0 - rim_inner ) );
  if( fade > 0.0 )
  {
    float val  = sin( fade * S2_PI );
    rim_color_circ.a = val;
  }

  // rectangular rim
  float4 rim_color_rect = float4( 164.0 / 255.0, 164.0 / 255.0, 164.0/ 255.0, 0.0 );
  float  inner_rect = 0.985;
  float  fade_x   = saturate( (abs( rim.x ) - inner_rect) / (1.0 - inner_rect) );
  float  fade_y   = saturate( (abs( rim.y ) - inner_rect) / (1.0 - inner_rect) );
  if( fade_x > 0.0 || fade_y > 0.0 )
  {
    float  val_x    = sin( fade_x * S2_PI );
    float  val_y    = sin( fade_y * S2_PI );
    float  val_rect = abs( rim.x ) > abs( rim.y ) ? val_x : val_y;
           rim_color_rect.a = val_rect;
  }

  float4 rim_color = w.x * rim_color_circ + w.y * rim_color_rect;
  fade = w.x * fade + w.y * ( abs( rim.x ) > abs( rim.y ) ? fade_x : fade_y );


  
  float2 dir    = normalize( tc0.zw );
  float  l1     = length( tc0.zw );
  float  l2     = asin( l1 ) / S2_PI;
  float  weight = w.x / fisheye_pow;
  float  scale  = weight * l2 + (1.0 - weight) * l1 * 0.5;
  float2 texctr = mc.xy;
  float2 looky  = texctr + dir * scale * zoom.x;
  float2 fowctr = mc.zw;
  float2 fowdir = normalize( fow - fowctr );
  float2 looky2 = fowctr + fowdir * scale * zoom.x * zoom.y;

#ifdef SM2_0
  // cheaper call but leads to artifacts with the fow when zoomed in and fisheye effect activated
  col0.rgb = tex2D( texture0, looky ).rgb * tex2D( texture1, looky2 ).rgb;
  col0.a = alpha;
#else
  // gauss sample 3x3 area around the texel
  float filter_delta = 1.0 / 48.0; // hard coded filter size
  float3 x = { looky2.x - filter_delta, looky2.x, looky2.x + filter_delta };
  float3 y = { looky2.y - filter_delta, looky2.y, looky2.y + filter_delta };
  float4 tex1 = {0,0,0,0};

  tex1 += 1.0 * tex2D( texture1, float2( x.x, y.x ) );
  tex1 += 2.0 * tex2D( texture1, float2( x.y, y.x ) );
  tex1 += 1.0 * tex2D( texture1, float2( x.z, y.x ) );

  tex1 += 2.0 * tex2D( texture1, float2( x.x, y.y ) );
  tex1 += 4.0 * tex2D( texture1, float2( x.y, y.y ) );
  tex1 += 2.0 * tex2D( texture1, float2( x.z, y.y ) );

  tex1 += 1.0 * tex2D( texture1, float2( x.x, y.z ) );
  tex1 += 2.0 * tex2D( texture1, float2( x.y, y.z ) );
  tex1 += 1.0 * tex2D( texture1, float2( x.z, y.z ) );
  // normalize the filter
  tex1 /= 16.0;
  col0.rgb = tex2D( texture0, looky ).rgb * tex1.rgb;
  col0.a   = 1.0;

  col0 = lerp( col0, rim_color, fade ); 
  col0.a *= alpha;
#endif

}

#endif


#ifdef DRAW_WORLDMAP

void mainVS( in  float  idx  : TEXCOORD0,
             out float4 hpos : POSITION,
             out float4 tcs  : TEXCOORD0,
             uniform float4   vtx_data_array[4] )
{
  float4 uvs = vtx_data_array[idx];
  hpos = float4( uvs.xy, 0.0, 1.0 );
  tcs.xy = (uvs.xy + 1.0) * 0.5;
  tcs.zw = uvs.zw;
  tcs.y = 1.0 - tcs.y;
}

void mainPS( in float4 tcs   : TEXCOORD0,
            out float4 color : COLOR,
            uniform float4    param,
            uniform sampler2D texture0,   // worldmap
            uniform sampler2D texture1,   // burn blend map
            uniform sampler1D texture2,   // burn gradient map
            uniform sampler2D texture3 )  // fog of war map
{

  float2 uv	= tcs.zw;
  color  = tex2D( texture0, uv.xy );

  // fog of war
  float3 fow    = tex2D(texture3, uv.xy).rgb - 1.0;
#ifdef SM2_0
  float  fowed  = dot(color, float3(.3,.59,.11));         // convert col -> grayscale
#else
  float  fowed  = dot(color, float3(.3,.59,.11)) * 0.7;   // desaturize colors a bit
#endif
  
  // ease in/out
  float filter_delta = ( ( fow * fow ) / 2.0 + 0.5 ) / 1024.0 ;
	
  float3 x = { uv.x - filter_delta, uv.x, uv.x + filter_delta };
  float3 y = { uv.y - filter_delta, uv.y, uv.y + filter_delta };

  float4 tex = {0,0,0,0};

  tex += 1.0 * tex2D( texture3, float2( x.x, y.x ) );
  tex += 2.0 * tex2D( texture3, float2( x.y, y.x ) );
  tex += 1.0 * tex2D( texture3, float2( x.z, y.x ) );

  tex += 2.0 * tex2D( texture3, float2( x.x, y.y ) );
  tex += 4.0 * tex2D( texture3, float2( x.y, y.y ) );
  tex += 2.0 * tex2D( texture3, float2( x.z, y.y ) );

  tex += 1.0 * tex2D( texture3, float2( x.x, y.z ) );
  tex += 2.0 * tex2D( texture3, float2( x.y, y.z ) );
  tex += 1.0 * tex2D( texture3, float2( x.z, y.z ) );	

  tex /= 16.0;
  fow = saturate(tex.rgb * color.a);

  color.rgb = lerp( color.rgb, float3( fowed, fowed, fowed ), saturate( fow - 0.2 ) );

  // burn
  float  fade   = param.x;
         fade  += abs( param.y - tex2D( texture1, tcs.xy ).a );
         fade   = saturate( fade );
  float4 color1 = tex1D( texture2, fade );
         color *= color1;

}
#endif


#ifdef DRAW_WORLDMAP_ICONS

void mainVS(  in      float  idx   : TEXCOORD0,
              in      float2 itype : TEXCOORD1,
              in      float2 pos   : TEXCOORD2,
              in      float2 rot   : TEXCOORD3,
              out     float4 hpos  : POSITION,
              out     float4 tcs   : TEXCOORD0,
              uniform float4 vtx_data_array[100]  )
{
  // rename constants
  float4 verts        = vtx_data_array[idx];
  float4 screen_rect  = vtx_data_array[4];
  float2 lb           = vtx_data_array[5].xy;
  float  zoom         = vtx_data_array[5].z;
  float  ar           = vtx_data_array[5].w;
  float  sight_range  = vtx_data_array[6].x;
  float  icon_scale   = vtx_data_array[6].y;
  float  uv_idx_offs  = vtx_data_array[6].z;
  float  uv_icon_size = vtx_data_array[6].w;

  // texture sampling coordinates
  float2 tuvs = float2( verts.x, 1.0 - verts.y );
  tcs.zw = vtx_data_array[uv_idx_offs+itype.x].xy + tuvs * uv_icon_size;
  tcs.xy = verts.zw;

  // TEXTURE COORDINATES
  float2   tuv    = pos + 0.5;
           tuv   -= lb;
           tuv.y  = -tuv.y;
           tuv   /= zoom;
           tuv.y *= ar;
           tuv.x = tuv.x > 1.0 ? 1.0 : (tuv.x < 0.0 ? 0.0 : tuv.x);
           tuv.y = tuv.y > 1.0 ? 1.0 : (tuv.y < 0.0 ? 0.0 : tuv.y);

  // VERTEX ON SCREEN POSITION
  float2x2 local_rot  = { rot.y,  -rot.x, rot.x, rot.y };
           verts.xy  = mul( verts.xy - 0.5, local_rot );
  hpos = float4( (screen_rect.xy + tuv * screen_rect.zw - target_data.zw * 0.5 + verts.xy * icon_scale) * target_data.zw * 2.0 - 1.0, 0.0, 1.0 );
}

void mainPS(  in      float4    tcs   : TEXCOORD0,
             out      float4    color : COLOR,
             uniform  float4    param,
             uniform  sampler2D texture0,
             uniform  sampler2D texture1,
             uniform  sampler1D texture2 )
{
  float  fade   = param.x;
         fade  += tex2D( texture1, tcs.xy ).a;
         fade   = saturate( fade );
  float4 color1 = tex1D( texture2, fade );
         color  = tex2D( texture0, tcs.zw );
         color *= color1;
 
}

#endif 

#ifdef DRAW_WORLDMAP_POIS

void mainVS(  in      float  idx   : TEXCOORD0,
              in      float2 itype : TEXCOORD1,
              in      float2 pos   : TEXCOORD2, // position 
              in      float2 rot   : TEXCOORD3, // atlas uv
              out     float4 hpos  : POSITION,
              out     float4 tcs   : TEXCOORD0,
              uniform float4 vtx_data_array[100]  )
{
  // rename constants
//  float4 verts        = vtx_data_array[idx];
  float4 verts        = vtx_data_array[idx];
  float4 screen_rect  = vtx_data_array[4];
  float2 lb           = vtx_data_array[5].xy;
  float  zoom         = vtx_data_array[5].z;	
  float  ar           = vtx_data_array[5].w;	//aspect ratio

  // texture sampling coordinates
 
  tcs.zw = rot.xy;

  // TEXTURE COORDINATES
  float2   tuv    = pos;
           tuv   -= lb;
           tuv.y  = -tuv.y;
           tuv   /= zoom;
           tuv.y *= ar;

	tcs.xy = (screen_rect.xy + (float2(tuv.x,1-tuv.y)) * screen_rect.zw - target_data.zw * 0.5 + verts.xy) * target_data.zw;
	hpos = float4( (screen_rect.xy + tuv * screen_rect.zw - target_data.zw * 0.5 + verts.xy) * target_data.zw * 2.0 - 1.0, 0.0, 1.0 );
}

void mainPS(  in      float4    tcs   : TEXCOORD0,
             out      float4    color : COLOR,
             uniform  float4    param,
             uniform  sampler2D texture0,	// POI Atlas
             uniform  sampler2D texture1,	// burn mask
             uniform  sampler1D texture2 )	// burn border recolor
{
  float  fade   = param.x;

         fade  += abs( param.y - tex2D( texture1, tcs.xy ).a );
//         fade  += tex2D( texture1, tcs.xy ).a;

         fade   = saturate( fade );
  float4 color1 = tex1D( texture2, fade );
         color  = tex2D( texture0, tcs.zw );
         color *= color1;

 
}

#endif 

#else // OLD SHADER CODE



#ifdef LAYER_BIT0
  #define NO_FOW
#endif

#ifdef SM1_1

  #define VERT_XVERTEX
  #include "extractvalues.shader"
  DEFINE_VERTEX_DATA

#else

  struct appdata
  {
	    float3 position    : POSITION;
	    float3 normal      : NORMAL;
	    float3 tangent     : TANGENT;
	    float3 binormal    : BINORMAL;
	    float2 texcoord    : TEXCOORD0;
	    float2 data        : TEXCOORD1;
    };

#endif



struct pixdata
{
	  float4 hposition   : POSITION;
	  float4 texcoord0   : TEXCOORD0;
#ifdef SM1_1
#ifndef NO_FOW
    float2 texcoord1   : TEXCOORD1;
#endif
#endif
  };


struct fragout {
	float4 col         : COLOR;
};

pixdata mainVS(appdata I,
			   uniform float4   vtx_data_array[2],
			   uniform float4x4 worldViewProjMatrix)
{
	pixdata VSO;
	
	float4 pos4 = float4(I.position, 1.0);
	float4 nrm4 = float4(I.normal, 0.0);

	// vertex pos
	VSO.hposition = mul(pos4, worldViewProjMatrix);

  VSO.texcoord0    = I.texcoord.xyyy    * vtx_data_array[1]   + vtx_data_array[0];

#ifndef NO_FOW
  // texture coords
  #ifdef SM1_1
    VSO.texcoord1.x  = I.texcoord.x         * vtx_data_array[1].x + vtx_data_array[0].z;
    VSO.texcoord1.y  = (1.0 - I.texcoord.y) * vtx_data_array[1].y + vtx_data_array[0].w;
  #else
    VSO.texcoord0.z  = I.texcoord.x         * vtx_data_array[1].z  + vtx_data_array[0].z;
    VSO.texcoord0.w  = (1.0 - I.texcoord.y) * vtx_data_array[1].w  + vtx_data_array[0].w;
  #endif
#endif
	return VSO;
}

fragout mainPS( pixdata I,
 		            uniform float4    light_col_amb,
			          uniform sampler2D texture0
#ifndef NO_FOW
               ,uniform sampler2D texture1
#endif
                                            )
{
	fragout PSO;

	// get texture values
	float4 tex0 = tex2D( texture0, I.texcoord0.xy );

#ifdef NO_FOW
  // set output color
  PSO.col = float4( tex0.xyz, light_col_amb.a );
#else
  #ifdef SM1_1
    float4 tex1 = tex2D( texture1, I.texcoord1.xy );
  #else
    // gauss sample 3x3 area around the texel
    float filter_delta = 1.0 / 64.0;
    float3 x = { I.texcoord0.z - filter_delta, I.texcoord0.z, I.texcoord0.z + filter_delta };
    float3 y = { I.texcoord0.w - filter_delta, I.texcoord0.w, I.texcoord0.w + filter_delta };
    float4 tex1 = {0,0,0,0};

    tex1 += 1.0 * tex2D( texture1, float2( x.x, y.x ) );
    tex1 += 2.0 * tex2D( texture1, float2( x.y, y.x ) );
    tex1 += 1.0 * tex2D( texture1, float2( x.z, y.x ) );

    tex1 += 2.0 * tex2D( texture1, float2( x.x, y.y ) );
    tex1 += 4.0 * tex2D( texture1, float2( x.y, y.y ) );
    tex1 += 2.0 * tex2D( texture1, float2( x.z, y.y ) );

    tex1 += 1.0 * tex2D( texture1, float2( x.x, y.z ) );
    tex1 += 2.0 * tex2D( texture1, float2( x.y, y.z ) );
    tex1 += 1.0 * tex2D( texture1, float2( x.z, y.z ) );
    // normalize the filter
    tex1 /= 16.0;
  #endif
  // set output color
	PSO.col = float4( tex0.xyz * tex1.xyz, light_col_amb.a);
#endif

	return PSO;
} 


#endif
