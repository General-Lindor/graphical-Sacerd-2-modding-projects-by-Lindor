This is a pack of different fur shaders. You can try them all out if you want to. Choose one and install it via following those steps:

	1. manual:

		1. Open [Sacred 2 installation folder]/pak.
		2. Unzip shader.zip.
		3. Go to shader/unified/object and replace gur.shader and fins.shader with your choice.
		4. Rezip the shader folder again.
		5. Clear your shader cache. Here's how to do that: http://darkmatters.org/forums/index.php?/topic/72259-deeply-understanding-surfacetxt-flags-shaders/#comment-7136963
		
	2. via GME (Generic mod enabler) - possibility 1
	
		1. Choose a mod name you like.
		2. In the MODS folder, create [insert mod name hear]/pak/unified/object.
		3. Place the shader pair you chose there.
		4. Clear your shader cache. Here's how to do that: http://darkmatters.org/forums/index.php?/topic/72259-deeply-understanding-surfacetxt-flags-shaders/#comment-7136963
		
	2. via GME (Generic mod enabler) - possibility 2

		1. Open [Sacred 2 installation folder]/pak.
		2. Duplicate and unzip shader.zip.
		3. Go to shader/unified/object and replace gur.shader and fins.shader with your choice.
		4. Rezip the shader folder duplicate again.
		5. Choose a mod name you like.
		6. In the MODS folder, create [insert mod name hear]/pak/unified/object.
		7. Place your shader.zip duplicate there.
		8. Clear your shader cache. Here's how to do that: http://darkmatters.org/forums/index.php?/topic/72259-deeply-understanding-surfacetxt-flags-shaders/#comment-7136963

General changes:
	-All shaders got a working glow texture now (tex1)
	-Comments and leftovers in the fur.shader file cleaned up, increased overview by standardizing patterns
	-i did not touch the fog rendering and i don't plan to in the future
How does fur generation work??:
	-fins/shells:
		Read here what fins and shells are: https://darkmatters.org/forums/index.php?/topic/72326-fur-shader-pack-20-different-furshader-finsshader-pairs/#comment-7137560
		Option to disable either fins or shells by making them completely transparent.
Lighting models explanation:
	-Lambertian
		This is the lighting model also used in Vanilla. It is pretty "aggressive" with the lighting and the best model when it comes to lighting each individual hair visible, but it makes the overall look somewhat bright and unnatural.
	-Oren-Nayar + Phong Specular
		The Oren-Nayar model is a complicated model to render rough materials (like fur). It is the most natural looking one. It makes the colour more matt. Albedo and roughness have been estimated by me to both be 0.3 to save computation capacity, but inside the fur.shader file i included the full formula with the option to change those values to your liking, you can even set them dependent on the texture input if you want to. Just requires a text editor (i recommend Notepad ++).
		Phong specular lighting is more computational expensive than Phong-Blinn's specular, but also looks way better imho.
	-Phong-Blinn
		The Phong-Blinn lighting model is a less computational expensive and less realistic enhancement of the Phong specular model and describes both diffuse and specular. It adds an Oil-painting-like effect to the fur which has its own artistical value.