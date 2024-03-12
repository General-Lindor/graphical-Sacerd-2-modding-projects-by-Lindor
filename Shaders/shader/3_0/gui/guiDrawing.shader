// gui Drawing

struct appdata {
	float3 position   : POSITION;
	float4 texcoord0  : TEXCOORD0;
	float4 color      : COLOR0;
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 texcoord0  : TEXCOORD0;
	float4 color      : COLOR0;
}; 

struct fragout {
	float4 col        : COLOR;
};

pixdata mainVS(appdata I)
{
	pixdata O;

	// vertex pos already transformed
	O.hposition = float4(I.position.x, I.position.y, 0.0, 1.0);
	// only have one texture coord
	O.texcoord0 = I.texcoord0.xyyy;
	// pass color
	O.color = I.color;

	return O;
}

fragout mainPS(pixdata I,
	uniform sampler2D texture0)
{
	fragout O;

	O.col = I.color * tex2D(texture0, I.texcoord0.xy);

	return O;
} 
