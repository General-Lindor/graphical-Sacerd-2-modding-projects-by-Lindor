// ----------------------------------------------------------------------------
struct WaveRecord {
	float y;
	float3 Position;
	//float3 Normal;
};

#define SECTOR_SIZE 3200.0f

// ----------------------------------------------------------------------------
// calculate per-vertex displacement and derivatives
WaveRecord CalculateWaves (float3 position, float weight, float2 time, float4 waveheight,float4 waveDirSpeed)
{
  WaveRecord Out;

  float wavePos = position.x * waveDirSpeed.x + position.y * waveDirSpeed.y; // dot really
  float periodicyValue = 6.283185307 / (100.0 * (abs(waveDirSpeed.x) + abs(waveDirSpeed.y))); // 2 * PI / (sector_size * size scale) - this value can be precalced, given a set direction!

  wavePos = wavePos * periodicyValue;

  float4 sins;
  float4 coss;
  sincos(time.xxxx * waveDirSpeed.zzzz + float4(wavePos, wavePos / 2.0, wavePos / 4.0, wavePos / 8.0), sins, coss);
  sins = sins * 0.5 + 0.5; // change range from -1..1 to 0..1
  Out.y = waveheight * (dot(sins, float4(0.35, 0.0, 0.2, 0.15)) + dot(coss, float4(0.0, 0.3, 0.0, 0.0))); // relative importance for each term (ought to add up to 1.0)

	// set to zero - there is no way to render water sectors seamless since we're using multiple matrices 
	//Out.y = 0;

	Out.Position = position + float3( 0, 0, Out.y );
	//Out.Normal = normalize( float3( 0, 1, 0 ) + dN * weight );

	return Out;
}