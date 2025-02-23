// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// #pragma once is a safe guard best practice in almost every .hlsl (need Unity2020 or up), 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
#pragma once

// We don't have "UnityCG.cginc" in SRP/URP's package anymore, so:
// Including the following two hlsl files is enough for shading with Universal Pipeline. Everything is included in them.
// Core.hlsl will include SRP shader library, all constant buffers not related to materials (perobject, percamera, perframe).
// It also includes matrix/space conversion functions and fog.
// Lighting.hlsl will include the light functions/data to abstract light constants. You should use GetMainLight and GetLight functions
// that initialize Light struct. Lighting.hlsl also include GI, Light BDRF functions. It also includes Shadows.

// Required by all Universal Render Pipeline shaders.
// It will include Unity built-in shader variables (except the lighting variables)
// (https://docs.unity3d.com/Manual/SL-UnityShaderVariables.html
// It will also include many utilitary functions. 
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// Include this if you are doing a lit shader. This includes lighting shader variables,
// lighting and shadow functions
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// Material shader variables are not defined in SRP or URP shader library.
// This means _BaseColor, _BaseMap, _BaseMap_ST, and all variables in the Properties section of a shader
// must be defined by the shader itself. If you define all those properties in CBUFFER named
// UnityPerMaterial, SRP can cache the material properties between frames and reduce significantly the cost
// of each drawcall.
// In this case, although URP's LitInput.hlsl contains the CBUFFER for the material
// properties defined above. As one can see this is not part of the ShaderLibrary, it specific to the
// URP Lit shader.
// So we are not going to use LitInput.hlsl, we will implement everything by ourself.
// 所以我们不打算使用LitInput.hlsl，我们将自己实现一切。
//#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

// we will include some utility .hlsl files to help us
// include自定义的一些通用功能的hlsl文件
#include "NiloOutlineUtil.hlsl"
#include "NiloZOffset.hlsl"
#include "NiloInvLerpRemap.hlsl"

// note:
// subfix OS means object spaces    (e.g. positionOS = position object space) 模型空间（直译：对象空间）
// subfix WS means world space      (e.g. positionWS = position world space) 世界空间
// subfix VS means view space       (e.g. positionVS = position view space) 观察空间（也叫Camera space摄像机空间）
// subfix CS means clip space       (e.g. positionCS = position clip space) 裁剪空间

// all pass will share this Attributes struct (define data needed from Unity app to our vertex shader) 
// 即a2v
struct Attributes
{
    float3 positionOS   : POSITION;
    half3 normalOS      : NORMAL;
    half4 tangentOS     : TANGENT;
    float2 uv           : TEXCOORD0;
};

// all pass will share this Varyings struct (define data needed from our vertex shader to our fragment shader) 
// 即v2f
struct Varyings
{
    float2 uv                       : TEXCOORD0;
    float4 positionWSAndFogFactor   : TEXCOORD1; // xyz: positionWS, w: vertex fog factor
    half3 normalWS                  : TEXCOORD2;
    float4 positionCS               : SV_POSITION;
    float4 screenPos                : TEXCOORD3; // for SSRimlight //x,y分量的范围为[0,w]，而不是[0,width]，[0,height]
};

///////////////////////////////////////////////////////////////////////////////////////
// CBUFFER and Uniforms 
// (you should put all uniforms of all passes inside this single UnityPerMaterial CBUFFER! else SRP batching is not possible!)
///////////////////////////////////////////////////////////////////////////////////////

// all sampler2D don't need to put inside CBUFFER
sampler2D _BaseMap; 
sampler2D _RampMap;
sampler2D _EmissionMap;
sampler2D _OcclusionMap;
sampler2D _OutlineZOffsetMaskTex;
sampler2D _FaceLightMap;
sampler2D _LightMap;
sampler2D _MetalMap;
sampler2D _MaskMap;
sampler2D _SSRimWidthRamp;
sampler2D _SSRimMask;
//sampler2D _CameraDepthTexture;
Texture2D _CameraDepthTexture; //？

// put all your uniforms(usually things inside .shader file's properties{}) inside this CBUFFER, in order to make SRP batcher compatible
// see -> https://blogs.unity3d.com/2019/02/28/srp-batcher-speed-up-your-rendering/
CBUFFER_START(UnityPerMaterial)
    
    // high level settings
    float   _IsFace;
    float   _IsHair;
    int     _InNight;

    // base color
    float4  _BaseMap_ST;
    half4   _BaseColor;

    // alpha
    half    _Cutoff;

    // shadow ramp
    half    _AlbedoMulByRampColor;

    // emission
    float   _UseEmission;
    float   _isGenshinEmission;
    float   _isBlink;
    half    _EmissionStrength;
    half3   _EmissionColor;
    half    _EmissionMulByBaseColor;
    half3   _EmissionMapChannelMask;

    // occlusion
    float   _UseOcclusion;
    half    _OcclusionStrength;
    half    _OcclusionIndirectStrength;
    half    _OcclusionDirectStrength;
    half4   _OcclusionMapChannelMask;
    half    _OcclusionRemapStart;
    half    _OcclusionRemapEnd;

    // lighting
    half3   _IndirectLightMinColor;
    half    _IndirectLightMultiplier;
    half    _DirectLightMultiplier;
    half    _CelShadeMidPoint;
    half    _CelShadeSoftness;
    half    _MainLightIgnoreCelShade;
    half    _AdditionalLightIgnoreCelShade;

    // face lightmap
	float _UseFaceLightMap;
	half3 _FaceShadowColor;
    half _FaceShadowRangeSmooth;
    
    // body/hair lightmap
	float _UseLightMap;
    half  _HairSpecularStrength;
    
    // metal specular
    half3 _MetalColor;

    // rimlight
	float _UseRimLight;
	half4 _RimColor;
	half _RimMin;
	half _RimMax;
	half _RimSmooth;
    half _RimMaskStrength;
    half _RimIntensity;
    half _RimMulByBaseColor;

    // screen space rimlight
    uniform half _EnableSSRim;
    uniform half _SSRimIntensity;
    uniform half4 _SSRimColor;
    uniform half _SSRimWidth;
    uniform half _SSRimRampMaxDistance;
    uniform half _SSRimLength;
    uniform half _SSRimInvertLightDir;
    uniform float _SSRimFeather;
    uniform half _SSRimInShadow;

    // shadow mapping
    half    _ReceiveShadowMappingAmount;
    float   _ReceiveShadowMappingPosOffset;
    half3   _ShadowMapColor;  //NoirRC不用了？

    // outline
    float   _OutlineWidth;
    half3   _OutlineColor;
    float   _OutlineZOffset;
    float   _OutlineZOffsetMaskRemapStart;
    float   _OutlineZOffsetMaskRemapEnd;

CBUFFER_END

//a special uniform for applyShadowBiasFixToHClipPos() only, it is not a per material uniform, 
//so it is fine to write it outside our UnityPerMaterial CBUFFER
float3 _LightDirection;

struct ToonSurfaceData
{
    half3   albedo;
    half    alpha;
    half3   emission;
    half    occlusion;
    // Face lightmap
	float _useFaceLightMap;
    half3 _facelightMapL; // 采样值
    half3 _faceLightMapR; // 采样值
    // Body/hair lightmap
	float _useLightMap;
    half4 _lightMap; // 采样值
    // Metal Specular
    //half3 _MetalMap; // 采样值
    half3 _MetalColor;
    // shadow color
	half3 _shadowColor;
    // rimlight
	float _useRimLight;
	half4 _rimColor;
	half _rimMin;
	half _rimMax;
	half _rimSmooth;
	half _rimMask;
	half _rimMaskStrength;
    half _rimIntensity;
};
struct ToonLightingData
{
    half3   normalWS;
    float3  positionWS;
    half3   viewDirectionWS;
    float4  shadowCoord;
    float2  positionSS; // Screen space pixel coordinates //范围[0,width]和[0,height]
    float2  uv;
};

///////////////////////////////////////////////////////////////////////////////////////
// vertex shared functions
///////////////////////////////////////////////////////////////////////////////////////

float3 TransformPositionWSToOutlinePositionWS(float3 positionWS, float positionVS_Z, float3 normalWS)
{
    //目前只是一个很简单的实现：在世界空间下将顶点沿法线方向外扩，外扩距离的修正包括：相机空间的距离，相机空间的距离过远时（超过1m）的“淡出”，相机的FOV角度。
    //TODO: 改进。
    //you can replace it to your own method! Here we will write a simple world space method for tutorial reason, it is not the best method!
    float outlineExpandAmount = _OutlineWidth * GetOutlineCameraFovAndDistanceFixMultiplier(positionVS_Z);
    return positionWS + normalWS * outlineExpandAmount; 
}

// 顶点着色器代码（目前所有Pass通用），其中会根据ToonShaderIsOutline、ToonShaderApplyShadowBiasFix2个宏作为条件进行不同的处理
// if "ToonShaderIsOutline" is not defined    = do regular MVP transform
// if "ToonShaderIsOutline" is defined        = do regular MVP transform + push vertex out a bit according to normal direction
Varyings VertexShaderWork(Attributes input)
{
    Varyings output;

    // VertexPositionInputs contains position in multiple spaces (world, view, homogeneous clip space, ndc)
    // Unity compiler will strip all unused references (say you don't use view space).
    // Therefore there is more flexibility at no additional cost with this struct.
    /*
    VertexPositionInputs定义在Core.hlsl中：
    struct VertexPositionInputs
    {
        float3 positionWS; // World space position
        float3 positionVS; // View space position
        float4 positionCS; // Homogeneous clip space position
        float4 positionNDC;// Homogeneous normalized device coordinates
    };
    */
    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS);

    // Similar to VertexPositionInputs, VertexNormalInputs will contain normal, tangent and bitangent
    // in world space. If not used it will be stripped.
    /*
    struct VertexNormalInputs
    {
        real3 tangentWS;
        real3 bitangentWS;
        float3 normalWS;
    };
    */
    VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    float3 positionWS = vertexInput.positionWS;

#ifdef ToonShaderIsOutline
    positionWS = TransformPositionWSToOutlinePositionWS(vertexInput.positionWS, vertexInput.positionVS.z, vertexNormalInput.normalWS);
#endif

    // Computes fog factor per-vertex.
    // ComputeFogFactor只需要一个参数：裁剪空间中的z坐标
    float fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

    // TRANSFORM_TEX is the same as the old shader library.
    output.uv = TRANSFORM_TEX(input.uv,_BaseMap);

    // packing positionWS(xyz) & fog(w) into a vector4
    output.positionWSAndFogFactor = float4(positionWS, fogFactor);
    output.normalWS = vertexNormalInput.normalWS; //normlaized already by GetVertexNormalInputs(...) 

    output.positionCS = TransformWorldToHClip(positionWS); //VP变换

#ifdef ToonShaderIsOutline
    // ***总结：ZOffset方法，让裁剪空间的Z值沿着摄像机的Z偏移，常用于隐藏面部/眼睛上的难看的outline。
    // ZOffset顾名思义就是在ViewSpace下沿Z方向远离相机的方向推一段距离，使正面能盖住背面外扩的部分，ZOffset值越大描边越不可见。

    // [Read ZOffset mask texture]
    // we can't use tex2D() in vertex shader because ddx & ddy is unknown before rasterization, 
    // so use tex2Dlod() with an explict mip level 0, put explict mip level 0 inside the 4th component of param uv)
    //
    // 补充：在Shader中使用tex2D(tex, uv)的时候相当于在GPU内部展开如下：
    //tex2D(sampler2D tex, float4 uv) 
    //{    
    // float lod = CalcLod(ddx(uv), ddy(uv));   
    // uv.w= lod;    
    // return tex2Dlod(tex, uv); 
    //}
    //
    // tex2Dlod函数：使用 mipmap 采样一个二维纹理。
    // 用法：tex2Dlod(textureMap, float4(texCoord.xy, 0, lod))
    float outlineZOffsetMaskTexExplictMipLevel = 0;
    float outlineZOffsetMask = tex2Dlod(_OutlineZOffsetMaskTex, float4(input.uv,0,outlineZOffsetMaskTexExplictMipLevel)).r; //we assume it is a Black/White texture
    //（假设它是一个黑/白纹理 ，所以返回值是float？黑色表示不Z偏移）

    // [Remap ZOffset texture value]
    // flip texture read value so default black area = apply ZOffset, because usually outline mask texture are using this format(black = hide outline)
    outlineZOffsetMask = 1-outlineZOffsetMask;
    outlineZOffsetMask = invLerpClamp(_OutlineZOffsetMaskRemapStart,_OutlineZOffsetMaskRemapEnd,outlineZOffsetMask);// allow user to flip value or remap

    // [Apply ZOffset, Use remapped value as ZOffset mask]
    // 这里使用以上一长串计算得到的outlineZOffsetMask和输入参数_OutlineZOffset一同修正，另外对脸部（_IsFace=0/1）这里还额外加了一个经验性的修正
    output.positionCS = NiloGetNewClipPosWithZOffset(output.positionCS, _OutlineZOffset * outlineZOffsetMask + 0.03 * _IsFace);
#endif

    // ShadowCaster pass needs special process to positionCS, else shadow artifact will appear
    // | ShadowCaster pass 需要对positionCS特殊处理，否则会出现阴影伪影（shadow artifact）
    //--------------------------------------------------------------------------------------
#ifdef ToonShaderApplyShadowBiasFix
    // see GetShadowPositionHClip() in URP/Shaders/ShadowCasterPass.hlsl
    // ApplyShadowBias函数定义在Shadows.hlsl中
    // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl
    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, output.normalWS, _LightDirection));

    // 平台差异化处理
    // 在 DX11/12、PS4、XboxOne 和 Metal 中，Z 缓冲区范围是 1 到 0，并定义了 UNITY_REVERSED_Z。在其他平台上，范围是 0 到 1。
    #if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #else
    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #endif
    output.positionCS = positionCS;
#endif
    //--------------------------------------------------------------------------------------
    
    output.screenPos = ComputeScreenPos(output.positionCS);  // for SSRimlight //x,y分量的范围为[0,w]，而不是[0,width]，[0,height]

    return output;
}

///////////////////////////////////////////////////////////////////////////////////////
// fragment shared functions (Step1: prepare data structs for lighting calculation)
// | 片元共享函数（Step1：为光照计算准备数据结构）
///////////////////////////////////////////////////////////////////////////////////////
half4 GetFinalBaseColor(Varyings input)
{
    return tex2D(_BaseMap, input.uv) * _BaseColor;
}
half3 GetFinalEmissionColor(Varyings input, float4 baseColorFinal)
{
    half3 result = 0;
    if(_UseEmission)
    {
        if(_isGenshinEmission) 
        {   
            // 原神的角色自发光，使用BaseMap的Alpha通道作为自发光Mask，RGB通道作为自发光颜色

            //TODO：这里不用baseColorFinal，用tex2D(_BaseMap, input.uv)，但这样和上面的GetFinalBaseColor就采样了2次_BaseMap，重复了
            result = baseColorFinal.rgb * baseColorFinal.a * _EmissionStrength * _EmissionColor.rgb;
            result *= _isBlink ? abs((frac(_Time.y * 0.5) - 0.5) * 2) : 1; //闪烁效果
        }
        else 
        {
            result = tex2D(_EmissionMap, input.uv).rgb * _EmissionMapChannelMask * _EmissionColor.rgb;
        }
    }

    return result;
}
half GetFinalOcculsion(Varyings input)
{
    //occlusion值是一个half（范围=[0,1]），目前会在ShadeGI（间接光照）和ShadeSingleLight（光源直接光照）中用到
    half result = 1; //没有开启Occulsion时，返回值为1
    if(_UseOcclusion)
    {
        half4 texValue = tex2D(_OcclusionMap, input.uv); //_OcclusionMap是一张灰度图
        half occlusionValue = dot(texValue, _OcclusionMapChannelMask); //默认只取R通道 //这个值∈[0,1]
        occlusionValue = lerp(1, occlusionValue, _OcclusionStrength); //控制一下遮罩强度
        occlusionValue = invLerpClamp(_OcclusionRemapStart, _OcclusionRemapEnd, occlusionValue); //供用户调整
        result = occlusionValue;
    }

    return result;
}
half3 GetFinalShadowColor(Varyings input) 
{
	return _FaceShadowColor.rgb;
}
// Face lightMap
half GetUseFaceLightMap(Varyings input)
{
	if (_UseFaceLightMap)
	{
		return 1;
	}
	return 0;
}
half3 GetLeftLightMap(Varyings input) //这里的LightMap是脸部sdf贴图，由于只存了0-90°光照下的阴影，左半脸从左到右正常采样
{
	if (_UseFaceLightMap)
	{
		float4 lightMapL = tex2D(_FaceLightMap, input.uv);
		return lightMapL;
	}
	return 1;
}
half3 GetRightLightMap(Varyings input) //这里的LightMap是脸部sdf贴图，由于只存了0-90°光照下的阴影，右半脸从右到左反转uv.x采样
{
	if (_UseFaceLightMap)
	{
		float2 flippedUV = float2(1 - input.uv.x, input.uv.y);
		float4 lightMapR = tex2D(_FaceLightMap, flippedUV);
		return lightMapR;
	}
	return 1;
}
// Body lightMap
half GetUseLightMap(Varyings input)
{
	if (_UseLightMap)
	{
		return 1;
	}
	return 0;
}
half4 GetLightMap(Varyings input) //这里的LightMap是身体的lightmap（原神式body lightmap）
{
	if (_UseLightMap)
	{
		float4 lightMap = tex2D(_LightMap, input.uv);
		return lightMap;
	}
	return 1; //。。。
}
half GetUseRimLight(Varyings input) {
	if (_UseRimLight) { // 包括RimLight,1,FakeSSS,2
		return 1;
	}
	return 0;
}
// Metal Specular
//half3 GetMetalMap(Varyings input)
//{
//	return tex2D(_MetalMap, input.uv);
//}
half3 GetFinalMetalColor(Varyings input) 
{
	return _MetalColor.rgb;
}
// Rim
half4 GetRimColor(Varyings input) {
	return _RimColor;
}
half GetRimMin(Varyings input) {
	return _RimMin;
}
half GetRimMax(Varyings input) {
	return _RimMax;
}
half GetRimSmooth(Varyings input) {
	return _RimSmooth;
}
half GetRimMask(Varyings input)
{
    return tex2D(_MaskMap, input.uv).g;
}
half GetRimMaskStrength(Varyings input)
{
    return _RimMaskStrength;
}
half GetRimIntensity(Varyings input)
{
    return _RimIntensity;
}

void DoClipTestToTargetAlphaValue(half alpha) // 透明度测试 AlphaTest/AlphaClipping
{
#if _UseAlphaClipping
    clip(alpha - _Cutoff);
#endif
}

ToonSurfaceData InitializeSurfaceData(Varyings input) // 初始化 ToonSurfaceData 结构体
{
    ToonSurfaceData output;

    // albedo & alpha
    float4 baseColorFinal = GetFinalBaseColor(input);
    output.albedo = baseColorFinal.rgb;
    output.alpha = baseColorFinal.a;
    DoClipTestToTargetAlphaValue(output.alpha);// early exit if possible // 尽量把透明度测试提前

    // emission
    output.emission = GetFinalEmissionColor(input, baseColorFinal);

    // occlusion
    output.occlusion = GetFinalOcculsion(input);

    // Face lightmap
	output._useFaceLightMap = GetUseFaceLightMap(input);
	output._facelightMapL = GetLeftLightMap(input);
	output._faceLightMapR = GetRightLightMap(input);

    // Body lightmap
	output._lightMap = GetLightMap(input);

    // Metal specular
	//output._MetalMap = GetMetalMap(input);
    output._MetalColor = GetFinalMetalColor(input);

	// shadow color
	output._useLightMap = GetUseLightMap(input);
	output._shadowColor = GetFinalShadowColor(input);

	// rim light
	output._useRimLight = GetUseRimLight(input);
	output._rimColor = GetRimColor(input);
	output._rimMin = GetRimMin(input);
	output._rimMax = GetRimMax(input);
	output._rimSmooth = GetRimSmooth(input);
	output._rimMask = GetRimMask(input);
	output._rimMaskStrength = GetRimMaskStrength(input);
	output._rimIntensity = GetRimIntensity(input);

    return output;
}
ToonLightingData InitializeLightingData(Varyings input) // 初始化 lightingData 结构体
{
    ToonLightingData lightingData;
    lightingData.positionWS = input.positionWSAndFogFactor.xyz;
    lightingData.viewDirectionWS = SafeNormalize(GetCameraPositionWS() - lightingData.positionWS); //SafeNormalize避免归一化计算过程中除以0  
    lightingData.normalWS = normalize(input.normalWS); //interpolated normal is NOT unit vector, we need to normalize it
    lightingData.positionSS = input.screenPos.xy / input.screenPos.w * _ScreenParams.xy; //从[0,w]映射到[0,width]和[0,height]
    lightingData.uv = input.uv;

    return lightingData;
}

///////////////////////////////////////////////////////////////////////////////////////
// fragment shared functions (Step2: calculate lighting & final color)
// | 片元共享函数（Step2：计算光照和最终颜色）
///////////////////////////////////////////////////////////////////////////////////////

// all lighting equation written inside this .hlsl,
// just by editing this .hlsl can control most of the visual result.
#include "SimpleURPToonLitOutlineExample_LightingEquation.hlsl"

// this function contains no lighting logic, it just pass lighting results data around
// the job done in this function is "do shadow mapping depth test positionWS offset"
half3 ShadeAllLights(ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    //==============================================================================================
    // Indirect lighting | 间接光照
    half3 indirectResult = ShadeGI(surfaceData, lightingData);

    //////////////////////////////////////////////////////////////////////////////////
    // Light struct is provided by URP to abstract light shader variables.| URP提供的Light结构体
    // It contains light's | 包含光的
    // - direction | 方向
    // - color | 颜色
    // - distanceAttenuation | 距离衰减
    // - shadowAttenuation | 阴影衰减
    /*
    // Light结构体定义于Lighting.hlsl：
    struct Light
    {
        half3   direction;
        half3   color;
        half    distanceAttenuation;
        half    shadowAttenuation;
    };
    */
    //
    // URP take different shading approaches depending on light and platform.
    // You should never reference light shader variables in your shader, instead use the
    // -GetMainLight()
    // -GetLight()
    // funcitons to fill this Light struct.
    //////////////////////////////////////////////////////////////////////////////////

    //==============================================================================================
    // 直接光源：主光源

    // Main light is the brightest directional light.
    // It is shaded outside the light loop and it has a specific set of variables and shading path
    // so we can be as fast as possible in the case when there's only a single directional light
    // You can pass optionally a shadowCoord. If so, shadowAttenuation will be computed.
    /*
    // GetMainLight()定义于Lighting.hlsl：
    Light GetMainLight()
    {
        Light light;
        light.direction = _MainLightPosition.xyz;
        light.distanceAttenuation = unity_LightData.z; // unity_LightData.z is 1 when not culled by the culling mask, otherwise 0.
        light.shadowAttenuation = 1.0; // 默认值=1
        light.color = _MainLightColor.rgb;

        return light;
    }

    Light GetMainLight(float4 shadowCoord)
    {
        Light light = GetMainLight();
        light.shadowAttenuation = MainLightRealtimeShadow(shadowCoord);
        return light;
    }

    Light GetMainLight(float4 shadowCoord, float3 positionWS, half4 shadowMask)
    {
        Light light = GetMainLight();
        light.shadowAttenuation = MainLightShadow(shadowCoord, positionWS, shadowMask, _MainLightOcclusionProbes);
        return light;
    }
    */
    Light mainLight = GetMainLight();

    // 将positionWS向主光源的方向进行偏移，作为传递给TransformWorldToShadowCoord函数的positionWS参数
    // 注意脸部 _IsFace 额外多偏移了一点
    float3 shadowTestPosWS = lightingData.positionWS + mainLight.direction * (_ReceiveShadowMappingPosOffset + _IsFace); //
#ifdef _MAIN_LIGHT_SHADOWS
    // 计算主光源阴影，计算阴影坐标
    // compute the shadow coords in the fragment shader now due to this change
    // https://forum.unity.com/threads/shadow-cascades-weird-since-7-2-0.828453/#post-5516425

    // _ReceiveShadowMappingPosOffset will control the offset the shadow comparsion position, 
    // doing this is usually for hide ugly self shadow for shadow sensitive area like face
    /*
    // TransformWorldToShadowCoord函数定义在Shadow.hlsl中
    float4 TransformWorldToShadowCoord(float3 positionWS)
    {
    #ifdef _MAIN_LIGHT_SHADOWS_CASCADE
        half cascadeIndex = ComputeCascadeIndex(positionWS); // 根据世界坐标计算级联索引
    #else
        half cascadeIndex = 0;
    #endif

        float4 shadowCoord = mul(_MainLightWorldToShadow[cascadeIndex], float4(positionWS, 1.0));

        return float4(shadowCoord.xyz, cascadeIndex);
    }
    // MainLightRealtimeShadow函数也定义在Shadow.hlsl中，用于计算阴影衰减
    half MainLightRealtimeShadow(float4 shadowCoord)
    {
    #if !defined(MAIN_LIGHT_CALCULATE_SHADOWS) //_MAIN_LIGHT_SHADOWS会自己再定义一个MAIN_LIGHT_CALCULATE_SHADOWS
        return 1.0h;
    #endif

        ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
        half4 shadowParams = GetMainLightShadowParams();
        return SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowCoord, shadowSamplingData, shadowParams, false);
    }
    */
    float4 shadowCoord = TransformWorldToShadowCoord(shadowTestPosWS); //阴影坐标（从世界空间转换到阴影坐标系下）
    mainLight.shadowAttenuation = MainLightRealtimeShadow(shadowCoord); //计算阴影衰减
#endif 

    // Main light | 主光源
    half3 mainLightResult = ShadeSingleLight(surfaceData, lightingData, mainLight, false);
    //half4 mainLight_and_litOrShadowArea = ShadeSingleLight(surfaceData, lightingData, mainLight, false);
    //half3 mainLightResult = mainLight_and_litOrShadowArea.rgb;
    //half mainLight_litOrShadowArea = mainLight_and_litOrShadowArea.a;
    // Face Shadow Mask
    // faceShadowMask只有2种返回值：0=(0,0,0)或1=(1,1,1)
    half3 faceShadowMask = ShadeFaceShadow(surfaceData, lightingData, mainLight);

    //==============================================================================================
    // All additional lights | 直接光照：所有额外的光源

    half3 additionalLightSumResult = 0;

#ifdef _ADDITIONAL_LIGHTS
    // Returns the amount of lights affecting the object being renderer.
    // These lights are culled per-object in the forward renderer of URP.
    int additionalLightsCount = GetAdditionalLightsCount();
    for (int i = 0; i < additionalLightsCount; ++i)
    {
        // Similar to GetMainLight(), but it takes a for-loop index. This figures out the
        // per-object light index and samples the light buffer accordingly to initialized the
        // Light struct. If ADDITIONAL_LIGHT_CALCULATE_SHADOWS is defined it will also compute shadows.
        /*
        // GetAdditionalPerObjectLight函数 类似于 GetMainLight()，但它需要一个 逐对象光源索引（perObjectLightIndex），也定义在Shadow.hlsl中:
        // Fills a light struct given a perObjectLightIndex
        Light GetAdditionalPerObjectLight(int perObjectLightIndex, float3 positionWS){}

        // AdditionalLightRealtimeShadow函数 也定义在Shadow.hlsl中:
        half AdditionalLightRealtimeShadow(int lightIndex, float3 positionWS){
            简单来说，
            先调用GetAdditionalLightShadowSamplingData函数，
            再调用GetAdditionalLightShadowParams函数，
            最后调用SampleShadowmap函数，采样Shadowmap
        }

        // AdditionalLightShadow函数 也定义在Shadow.hlsl中:
        half AdditionalLightShadow(int lightIndex, float3 positionWS, half4 shadowMask, half4 occlusionProbeChannels){
            简单来说，
            先调用AdditionalLightRealtimeShadow函数，
            再调用MixRealtimeAndBakedShadows函数，把实时Realtime和烘焙Baked的Shadow混合得到最终Shadow结果
        }
        */
        int perObjectLightIndex = GetPerObjectLightIndex(i);
        Light light = GetAdditionalPerObjectLight(perObjectLightIndex, lightingData.positionWS); // use original positionWS for lighting
        //light.shadowAttenuation = AdditionalLightRealtimeShadow(perObjectLightIndex, shadowTestPosWS); //原版 
        light.shadowAttenuation = AdditionalLightShadow(perObjectLightIndex, shadowTestPosWS, 0, 0); //改进 //use offseted positionWS for shadow test ？

        // Different function used to shade additional lights.
        additionalLightSumResult += ShadeSingleLight(surfaceData, lightingData, light, true);
        //half4 additionalLight_and_litOrShadowArea = ShadeSingleLight(surfaceData, lightingData, light, true);
        //additionalLightSumResult += additionalLight_and_litOrShadowArea.rgb;
        ////(half)  additionalLight_litOrShadowArea += additionalLight_and_litOrShadowArea.a; //未使用
    }
#endif

    //==============================================================================================
    // emission | 自发光
    half3 emissionResult = ShadeEmission(surfaceData, lightingData);
    
    //==============================================================================================
    // rimLight | 普通边缘光（SS边缘光在CompositeAllLightResults中计算）
    half3 rimlightResult = ShadeRimLight(surfaceData, lightingData, mainLight, false);

    //==============================================================================================
    // 合成：间接光照 + 主光照 + 所有额外光照 + 自发光 + 普通边缘光
    // TODO：改进shadowValue 0表示完全不在阴影中，1表示完全在阴影中
    //half shadowValue = 1 - mainLight_litOrShadowArea;
    half shadowValue = 0;
    return CompositeAllLightResults(indirectResult, mainLightResult, additionalLightSumResult, emissionResult, rimlightResult, faceShadowMask, surfaceData, lightingData, mainLight, shadowValue);
}

// 表面的颜色转换成outline的颜色
half3 ConvertSurfaceColorToOutlineColor(half3 originalSurfaceColor)
{
    return originalSurfaceColor * _OutlineColor;
}
half3 ApplyFog(half3 color, Varyings input)
{
    half fogFactor = input.positionWSAndFogFactor.w;
    // MixFog 函数定义在Core.hlsl 中
    // Mix the pixel color with fogColor. You can optionaly use MixFogColor to override the fogColor with a custom one.
    color = MixFog(color, fogFactor);

    return color;  
}

// 片元着色器函数（用于 ForwardLit 和 Outline 2个Pass），会对outline做额外处理
half4 ShadeFinalColor(Varyings input) : SV_TARGET
{
    // first prepare all data for lighting function | 首先准备照明功能的所有数据

    // fillin ToonSurfaceData struct:
    ToonSurfaceData surfaceData = InitializeSurfaceData(input);

    // fillin ToonLightingData struct:
    ToonLightingData lightingData = InitializeLightingData(input);
 
    // apply all lighting calculation
    half3 color = ShadeAllLights(surfaceData, lightingData);

#ifdef ToonShaderIsOutline
    color = ConvertSurfaceColorToOutlineColor(color); // 如果是outline，需要把表面的颜色转换成outline的颜色
//#else 
//    color = 1; //测试用，观察outline效果
#endif

    color = ApplyFog(color, input);

    return half4(color, surfaceData.alpha);
}

// 片元着色器函数（用于 ShadowCaster Pass 和 DepthOnly Pass）
void BaseColorAlphaClipTest(Varyings input)
{
    DoClipTestToTargetAlphaValue(GetFinalBaseColor(input).a);
}
