// 2D drawing

struct appdata {
	float3 position   : POSITION;
	float2 texcoord0  : TEXCOORD0;
	float2 texcoord1  : TEXCOORD1;
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 texcoord0  : TEXCOORD0;
};

struct fragout {
	float4 col        : COLOR;
};


pixdata mainVS(appdata I)
{
	pixdata O;

	// vertex pos already transformed
	O.hposition = float4(I.position.xy, 0.0, 1.0);
	// only have one texture coord
	O.texcoord0 = I.texcoord0.xyyy;

	return O;
}

fragout mainPS(pixdata I,
			    uniform sampler2D texture0)
{
	fragout O;

	O.col = tex2D(texture0, I.texcoord0.xy);

	return O;
} 
