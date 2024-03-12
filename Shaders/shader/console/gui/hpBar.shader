//#OptDef:LAYER_BIT0 // no sun shadow

#define FLIP_TEXTURE_Y

////////////////////////////////////////////////////////////
sampler2D   ColorSampler		: register( s0 );
sampler2D   BloodFadeSampler	: register( s1 );

float4		bgColor				: register( c0 ); // = float4(0.0,0.0,0.0,0.75);
float4		healthColor			: register( c1 ); // = float4(0.5,0.0,0.0,1.0);
float4		lastHealthColor		: register( c2 ); // = float4(1.0,0.0,0.0,1.0);

float4		BarData				: register( c3 ); // time/Health/lastHealth/iconOffset = { 0.0f, 0.75f,       0.25f, 0.00f  }
float4		PosScaleData 		: register( c4 ); // scale/aspectRatio/position.xy     = { 0.3f, 16.0f/10.0f, float2(.5,.5) }

////////////////////////////////////////////////////////////

struct appdata
{
    float2 UV			: POSITION;
};

struct vertexOutput
{
    float4 HPosition	: POSITION;
    float4 UV			: TEXCOORD0;
};

#ifdef LAYER_BIT0
	vertexOutput mainVS(appdata IN) 
	{		
		float  scale       = PosScaleData.x;
		float  aspectRatio = PosScaleData.y;
		float2 position    = PosScaleData.zw;
		float  iconOffset  = BarData.w;
	    
		vertexOutput OUT;// = (vertexOutput)0;
		OUT.UV = 0;
		OUT.UV.xy = float2(IN.UV.x,(1.0-IN.UV.y));

		float2 barScale = float2(scale, scale / 4 );
		position = position * 2 - 1;
		float2	pos = IN.UV.xy * 2 - 1;

		//scale
		pos.xy *= float2(barScale.x, barScale.y * aspectRatio);
		//move
		pos.xy += position;

		OUT.HPosition = float4(pos.xy, 0, 1);

		return OUT;
	}

	float4 mainPS(vertexOutput IN) : COLOR 
	{
		float  time        = BarData.x;
		float  Health      = BarData.y;
		float  lastHealth  = BarData.z;
		
		float iconOffset = .0	;
		float4 diffuseColor = tex2D(ColorSampler,float2(IN.UV.x, IN.UV.y * .25 + iconOffset)).rgba;

		float t = frac(time);

		Health = Health * 0.6875 + 0.28125;
		lastHealth = lastHealth * 0.6875 + 0.28125;

		float4 result = 0;

		result = IN.UV.x < lastHealth ? (bgColor + lastHealthColor * (1.0-t) * IN.UV.y * IN.UV.y) * diffuseColor.a  : bgColor * diffuseColor;
		result = IN.UV.x < Health ? healthColor * diffuseColor : result;
		result = IN.UV.x < .25 ? diffuseColor : result;

		return float4(result);
	}
#else
	vertexOutput mainVS(appdata IN) 
	{
		float  scale       = PosScaleData.x;
		float  aspectRatio = PosScaleData.y;
		float2 position    = PosScaleData.zw;
		float  time        = BarData.x;
		float  Health      = BarData.y;
		float  lastHealth  = BarData.z;
		
		vertexOutput OUT = (vertexOutput)0;
		OUT.UV = 0;
		OUT.UV.xy = float2(IN.UV.x,(1.0-IN.UV.y));

		float t = frac(time);
		float2 barScale = float2(scale, scale / 4 );
		position = position * 2 - 1;
		float2	pos = IN.UV.xy;

		pos.x = pos.x * ( lastHealth - Health ) + Health; //modify to lastHealthPart
		pos.x = pos.x * 0.6875 + 0.28125; //modify to hpbar
		pos = pos * 2 - 1 ; // move pivot to center
		pos.xy *= float2(barScale.x, barScale.y * aspectRatio); // modify to complete bar

		OUT.UV.x = OUT.UV.x * ( lastHealth - Health ) + Health; 
		OUT.UV.x = OUT.UV.x * 0.6875 + 0.28125; 
		
		//move
		pos.xy += position;

		//animate
		pos.y = pos.y - (t*t*8 * barScale.x * OUT.UV.y); 

		OUT.UV.zw = float2(OUT.UV.xy);
		OUT.UV.w = OUT.UV.w /4;
		OUT.UV.w = OUT.UV.w+t*t*.8 ;
		
		OUT.HPosition = float4(pos.xy, 0, 1);

		return OUT;
	}

	float4 mainPS(vertexOutput IN) : COLOR 
	{
		float  time        = BarData.x;
		float  Health      = BarData.y;
		float  lastHealth  = BarData.z;
		
		float iconOffset = .5;
		float4 diffuseColor = tex2D(ColorSampler,float2(IN.UV.x, IN.UV.y * .25 + iconOffset)).rgba;
		float4 bloodFade = tex2D(BloodFadeSampler,float2(IN.UV.zw)).rgba;

		Health = Health * 0.6875 + 0.28125;

		float t = frac(time);

		float4 result = lastHealthColor * diffuseColor;
	//	result.a *= 1-t;
		result.a *= saturate(bloodFade.a*2-1)*IN.UV.y*IN.UV.y;
		return float4(result);
	}
#endif