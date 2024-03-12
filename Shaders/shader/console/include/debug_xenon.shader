
s2half4 debugOutput(	s2half4 replacement0,
						s2half4 color0,
						s2half2 texcoord,
						s2half pos,
						s2half size)
{
	if(texcoord.x > pos && texcoord.x < (pos + size) && texcoord.y > .5 && texcoord.y < 0.75){
		color0 = replacement0;
	}else{
		color0 = color0;
	}

	return color0;

} 
