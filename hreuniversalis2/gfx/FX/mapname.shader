## Includes

Includes = {
	"constants.fxh"
	"standardfuncsgfx.fxh"
}


## Samplers

PixelShader = 
{
	Samplers = 
	{
		DiffuseTexture = 
		{
			AddressV = "Clamp"
			MagFilter = "Linear"
			MipMapLodBias = -1
			AddressU = "Clamp"
			Index = 0
			MipFilter = "Linear"
			MinFilter = "Linear"
		}

		FoWTexture = 
		{
			AddressV = "Wrap"
			MagFilter = "Linear"
			AddressU = "Wrap"
			Index = 1
			MipFilter = "Linear"
			MinFilter = "Linear"
		}

		FoWDiffuse = 
		{
			AddressV = "Wrap"
			MagFilter = "Linear"
			AddressU = "Wrap"
			Index = 2
			MipFilter = "Linear"
			MinFilter = "Linear"
		}


	}
}


## Vertex Structs


VertexStruct VS_INPUT
{
    float3 vPosition  : POSITION;
	float2 vTexCoord  : TEXCOORD0;
};


VertexStruct VS_OUTPUT
{
    float4 vPosition : PDX_POSITION;
	float3 vPrepos   : TEXCOORD0;
    float2 vTexCoord : TEXCOORD1;
};


## Constant Buffers

ConstantBuffer( 1, 32 )
{
	float2 vTargetOpacity_Fade;
}

## Shared Code

Code
[[
#ifndef AD_LUCEM
static const float4 MAP_NAME_COLOR				= float4(0.0f, 0.0f, 0.0f, 0.75f);
static const float4 MAP_NAME_GLOW				= float4(0.566f, 0.566f, 0.566f, 0.5f);

// http://developer.download.nvidia.com/books/HTML/gpugems/gpugems_ch25.html
float filterwidth(float2 v)
{
	#ifdef PDX_OPENGL
		#ifdef PIXEL_SHADER
			return (abs(fwidth(v.x)) + abs(fwidth(v.y))) / 2.0f;
		#else
			return 0.002f;
		#endif //PIXEL_SHADER
	#else
		float2 fw = max(abs(ddx(v)), abs(ddy(v)));
		return (fw.x + fw.y) / 2.0f;// return max(fw.x, fw.y);
	#endif //PDX_OPENGL
}
#endif
]]

## Vertex Shaders

VertexShader = 
{
	MainCode VertexShader
	[[
		VS_OUTPUT main( const VS_INPUT v )
		{
			VS_OUTPUT Out;
			float4 vPos = float4( v.vPosition, 1.0f );
			float4 vDistortedPos = vPos - float4( vCamLookAtDir * 0.5f, 0.0f );
			vPos = mul( ViewProjectionMatrix, vPos );
			
			// move z value slightly closer to camera to avoid intersections with terrain
			float vNewZ = dot( vDistortedPos, float4( GetMatrixData( ViewProjectionMatrix, 2, 0 ), GetMatrixData( ViewProjectionMatrix, 2, 1 ), GetMatrixData( ViewProjectionMatrix, 2, 2 ), GetMatrixData( ViewProjectionMatrix, 2, 3 ) ) );
			
			Out.vPosition = float4( vPos.xy, vNewZ, vPos.w );
			Out.vPrepos = v.vPosition.xyz;
			Out.vTexCoord = v.vTexCoord;
			return Out;
		}
	]]

}


## Pixel Shaders

PixelShader = 
{
	MainCode PixelShader
	[[
		float4 main( VS_OUTPUT v ) : PDX_COLOR
		{
			float vDistance = 0.0f;
			if (v.vTexCoord.y > 3.0f) {
				vDistance = tex2D( DiffuseTexture, float2(v.vTexCoord.x, v.vTexCoord.y - 3.0f) ).a;
			}
			else if (v.vTexCoord.y > 2.0f) {
				vDistance = tex2D( DiffuseTexture, float2(v.vTexCoord.x, v.vTexCoord.y - 2.0f) ).b;
			}
			else if (v.vTexCoord.y > 1.0f) {
				vDistance = tex2D( DiffuseTexture, float2(v.vTexCoord.x, v.vTexCoord.y - 1.0f) ).g;
			}
			else {
				vDistance = tex2D( DiffuseTexture, float2(v.vTexCoord.x, v.vTexCoord.y) ).r;
			}
			
			float smoothing = filterwidth(v.vTexCoord) * 75.0f;
			float4 vMapname = lerp(MAP_NAME_COLOR, MAP_NAME_GLOW, 1.0f - saturate( ( vDistance - 0.5f ) / smoothing + 0.5f ) );
			vMapname.a *= saturate( vDistance * 2.0f ) * vTargetOpacity_Fade.x * vTargetOpacity_Fade.y;
			#ifdef AD_LUCEM
				vMapname.rgb = CalculateMapLighting( vMapname.rgb );
				vMapname.rgb = ApplyDistanceFog( vMapname.rgb, v.vPrepos, GetFoWColor( v.vPrepos, FoWTexture), FoWDiffuse, FOW_WEIGHT_MAP_NAME );
			#else
				vMapname.rgb = ApplyDistanceFog( vMapname.rgb, v.vPrepos, GetFoWColor( v.vPrepos, FoWTexture), FoWDiffuse );
			#endif

			return vMapname;
			
		}
	]]

}


## Blend States

BlendState BlendState
{
	AlphaTest = no
	WriteMask = "RED|GREEN|BLUE"
	SourceBlend = "src_alpha"
	DestBlend = "inv_src_alpha"
	BlendEnable = yes
}

## Rasterizer States

## Depth Stencil States

## Effects

Effect mapname
{
	VertexShader = "VertexShader"
	PixelShader = "PixelShader"
}