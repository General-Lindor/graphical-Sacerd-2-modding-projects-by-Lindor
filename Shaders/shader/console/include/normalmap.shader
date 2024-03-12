#ifdef CONSOLE_IMPL
s2half4 ReadNormalMap2D(sampler2D tex, s2half2 uv)
{
#ifdef PS3_IMPL
	s2half4 col = (s2half4(tex2D(tex, uv).ag,0,0) - s2half4(0.5, 0.5, 5.0, 0))*s2half4(2,2,2,1);
#else
	s2half4 col = (tex2D(tex, uv) - s2half4(0.5, 0.5, 5.0, 0))*s2half4(2,2,2,1);
#endif
	col.z = sqrt( 1.0f - col.x*col.x - col.y*col.y );
	
	// verstärken der Normalmap
	// col.z /= 2.f;
	// col.xyz = normalize(col.xyz);
	//return s2half4(0,0,1,0);
	return col;
}

void  EncodeNormal( in out s2half3 normal, in out s2half3 specular )
{
  normal.xy = normal.xy*0.5 + 0.5;
  specular.b = specular.b * 127.f/255.f + ( ( normal.z < 0 ) ? 0 : 128.f/255.f );
}

void  DecodeNormal( in out s2half3 normal, in out s2half4 specular )
{
  normal.xy = normal.xy * 2 - 1;
  normal.z  = sqrt( 1.f - dot( normal.xy, normal.xy ) );
  
  if( specular.b < 128.f/255.f )
  {
    normal.z = -normal.z;
    specular.b = (specular.b * (255.f/127.f));
  }
  else
  {
    specular.b = (specular.b * (255.f/127.f)) - (128.f/127.f);
  }
}
#endif