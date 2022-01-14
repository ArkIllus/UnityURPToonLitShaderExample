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
// | ����URP shader����Ҫinclude����ļ���
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// Include this if you are doing a lit shader. This includes lighting shader variables,
// lighting and shadow functions
// | ���������һ��������ɫ����lit shader����include����ļ����������ɫ���Ĺ��ձ�����lighting shader variables�������պ���Ӱ����
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// Material shader variables are not defined in SRP or URP shader library.
// | ��ɫ���Ĳ��ʱ�����Material shader variables��δ�� SRP �� URP ��ɫ�����ж��塣
// ����ζ�� _BaseColor��_BaseMap��_BaseMap_ST �Լ���ɫ�����Բ����е����б�����������ɫ�������塣
// This means _BaseColor, _BaseMap, _BaseMap_ST, and all variables in the Properties section of a shader
// must be defined by the shader itself. If you define all those properties in CBUFFER named
// UnityPerMaterial, SRP can cache the material properties between frames and reduce significantly the cost
// of each drawcall.
// In this case, although URP's LitInput.hlsl contains the CBUFFER for the material
// properties defined above. As one can see this is not part of the ShaderLibrary, it specific to the
// URP Lit shader.
// So we are not going to use LitInput.hlsl, we will implement everything by ourself.
// �������ǲ�����ʹ��LitInput.hlsl�����ǽ��Լ�ʵ��һ�С�
//#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

// we will include some utility .hlsl files to help us
// include�Զ����һЩͨ�ù��ܵ�hlsl�ļ�
#include "NiloOutlineUtil.hlsl"
#include "NiloZOffset.hlsl"
#include "NiloInvLerpRemap.hlsl"

// note:
// subfix OS means object spaces    (e.g. positionOS = position object space) ģ�Ϳռ䣨ֱ�룺����ռ䣩
// subfix WS means world space      (e.g. positionWS = position world space) ����ռ�
// subfix VS means view space       (e.g. positionVS = position view space) �۲�ռ䣨Ҳ��Camera space������ռ䣩
// subfix CS means clip space       (e.g. positionCS = position clip space) �ü��ռ�

// all pass will share this Attributes struct (define data needed from Unity app to our vertex shader) 
// ��a2v
struct Attributes
{
    float3 positionOS   : POSITION;
    half3 normalOS      : NORMAL;
    half4 tangentOS     : TANGENT;
    float2 uv           : TEXCOORD0;
};

// all pass will share this Varyings struct (define data needed from our vertex shader to our fragment shader) 
// ��v2f
struct Varyings
{
    float2 uv                       : TEXCOORD0;
    float4 positionWSAndFogFactor   : TEXCOORD1; // xyz: positionWS, w: vertex fog factor
    half3 normalWS                  : TEXCOORD2;
    float4 positionCS               : SV_POSITION;
};

///////////////////////////////////////////////////////////////////////////////////////
// CBUFFER and Uniforms 
// (you should put all uniforms of all passes inside this single UnityPerMaterial CBUFFER! else SRP batching is not possible!)
///////////////////////////////////////////////////////////////////////////////////////

// all sampler2D don't need to put inside CBUFFER | ���е� sampler2D ������Ҫ���� CBUFFER ���� 
sampler2D _BaseMap; 
sampler2D _EmissionMap;
sampler2D _OcclusionMap;
sampler2D _OutlineZOffsetMaskTex;
sampler2D _LightMap;
sampler2D _MaskMap;

// put all your uniforms(usually things inside .shader file's properties{}) inside this CBUFFER, in order to make SRP batcher compatible
// | ������uniform��ͨ����.shader�ļ���properties{}�е����ݣ����ڴ� CBUFFER��ǿ�����ǡ�per material����cbuffer�� �У���ʹSRP����������SRP batcher������
// ɶ��uniform ������������
// see -> https://blogs.unity3d.com/2019/02/28/srp-batcher-speed-up-your-rendering/
CBUFFER_START(UnityPerMaterial)
    
    // high level settings
    float   _IsFace;

    // base color
    float4  _BaseMap_ST;
    half4   _BaseColor;

    // alpha
    half    _Cutoff;

    // emission
    float   _UseEmission;
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

    // lightmap
	float _UseLightMap;
	half3 _ShadowColor;

    // rimlight
	float _UseRimLight;
	half4 _RimColor;
	half _RimMin;
	half _RimMax;
	half _RimSmooth;
    half _RimMaskStrength;
    half _RimIntensity;

    // shadow mapping
    half    _ReceiveShadowMappingAmount;
    float   _ReceiveShadowMappingPosOffset;
    half3   _ShadowMapColor;  //NoirRC�����ˣ�

    // outline
    float   _OutlineWidth;
    half3   _OutlineColor;
    float   _OutlineZOffset;
    float   _OutlineZOffsetMaskRemapStart;
    float   _OutlineZOffsetMaskRemapEnd;

CBUFFER_END

// �ⲻ��һ����ÿ�����ϵ�uniform����per material uniform�������Է���CBUFFER���棿����������
//a special uniform for applyShadowBiasFixToHClipPos() only, it is not a per material uniform, 
//so it is fine to write it outside our UnityPerMaterial CBUFFER
float3 _LightDirection;

struct ToonSurfaceData
{
    half3   albedo;
    half    alpha;
    half3   emission;
    half    occlusion;
    // lightmap
	float _useLightMap;
    half3 _lightMapL; // ����ֵ
    half3 _lightMapR; // ����ֵ
    // shadow color
	half3 _shadowColor; // 
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
};

///////////////////////////////////////////////////////////////////////////////////////
// vertex shared functions
///////////////////////////////////////////////////////////////////////////////////////

float3 TransformPositionWSToOutlinePositionWS(float3 positionWS, float positionVS_Z, float3 normalWS)
{
    //Ŀǰֻ��һ���ܼ򵥵�ʵ�֣�������ռ��½������ط��߷��������������������������������ռ�ľ��룬����ռ�ľ����Զʱ������1m���ġ��������������FOV�Ƕȡ�
    //TODO: �Ľ���
    //you can replace it to your own method! Here we will write a simple world space method for tutorial reason, it is not the best method!
    float outlineExpandAmount = _OutlineWidth * GetOutlineCameraFovAndDistanceFixMultiplier(positionVS_Z);
    return positionWS + normalWS * outlineExpandAmount; 
}

// ������ɫ�����루Ŀǰ����Passͨ�ã������л����ToonShaderIsOutline��ToonShaderApplyShadowBiasFix2������Ϊ�������в�ͬ�Ĵ���
// if "ToonShaderIsOutline" is not defined    = do regular MVP transform
// if "ToonShaderIsOutline" is defined        = do regular MVP transform + push vertex out a bit according to normal direction
Varyings VertexShaderWork(Attributes input)
{
    Varyings output;

    // VertexPositionInputs contains position in multiple spaces (world, view, homogeneous clip space, ndc)
    // Unity compiler will strip all unused references (say you don't use view space).
    // Therefore there is more flexibility at no additional cost with this struct.
    // | VertexPositionInputs ��������ռ��е�λ�ã����硢�۲졢��βü��ռ䡢ndc��
    // Unity ��������ɾ������δʹ�õ�����
    // ��ˣ�ʹ�ô�struct�������ɱ����ɻ�ø��������ԡ�
    /*
    VertexPositionInputs������Core.hlsl�У�
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
    VertexNormalInputs��VertexPositionInputs���ƣ�Ҳ������Core.hlsl�У��������ߡ����ߺ͸����ߣ�����δʹ�õ�����Ҳ�ᱻUnity������ɾ����
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

    // Computes fog factor per-vertex. | �����𶥵�������ӡ�
    // ComputeFogFactorֻ��Ҫһ���������ü��ռ��е�z����
    float fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

    // TRANSFORM_TEX is the same as the old shader library.
    output.uv = TRANSFORM_TEX(input.uv,_BaseMap);

    // packing positionWS(xyz) & fog(w) into a vector4 | ������λ��(xyz) ��������(w) �����һ��vector4
    output.positionWSAndFogFactor = float4(positionWS, fogFactor);
    output.normalWS = vertexNormalInput.normalWS; //normlaized already by GetVertexNormalInputs(...) | ͨ�� GetVertexNormalInputs(...) ��һ��

    output.positionCS = TransformWorldToHClip(positionWS);

#ifdef ToonShaderIsOutline
    // ***�ܽ᣺ZOffset�������òü��ռ��Zֵ�����������Zƫ�ƣ������������沿/�۾��ϵ��ѿ���outline��
    // ZOffset����˼�������ViewSpace����Z����Զ������ķ�����һ�ξ��룬ʹ�����ܸ�ס���������Ĳ��֣�ZOffsetֵԽ�����Խ���ɼ���

    // [Read ZOffset mask texture]
    // we can't use tex2D() in vertex shader because ddx & ddy is unknown before rasterization, 
    // so use tex2Dlod() with an explict mip level 0, put explict mip level 0 inside the 4th component of param uv)
    // | [��ȡZOffset��������]
    // ���ǲ����ڶ�����ɫ����ʹ�� tex2D()����Ϊ�ڹ�դ��֮ǰ ddx & ddy ��δ֪�ģ�����
    // ����ʹ�� tex2Dlod() ���� explict mip level=0��Ҳ����lod������ָ��Ҫʹ�õ�����㣩���ڲ��� uv �ĵ� 4 ��������
    //
    // ���䣺��Shader��ʹ��tex2D(tex, uv)��ʱ���൱����GPU�ڲ�չ�����£�
    //tex2D(sampler2D tex, float4 uv) 
    //{    
    // float lod = CalcLod(ddx(uv), ddy(uv));   
    // uv.w= lod;    
    // return tex2Dlod(tex, uv); 
    //}
    //
    // tex2Dlod������ʹ�� mipmap ����һ����ά����
    // �÷���tex2Dlod(textureMap, float4(texCoord.xy, 0, lod))
    float outlineZOffsetMaskTexExplictMipLevel = 0;
    float outlineZOffsetMask = tex2Dlod(_OutlineZOffsetMaskTex, float4(input.uv,0,outlineZOffsetMaskTexExplictMipLevel)).r; //we assume it is a Black/White texture
    //����������һ����/������ �����Է���ֵ��float�������ƺ��Ǻ�ɫ��ʾ��Zƫ�ƣ�

    // [Remap ZOffset texture value]
    // flip texture read value so default black area = apply ZOffset, because usually outline mask texture are using this format(black = hide outline)
    // | [����ӳ��ZOffset����ֵ]
    // ��ת�����ȡֵ����Ĭ�Ϻ�ɫ����=Ӧ��ZOffset����Ϊͨ��oultine��������ʹ�����ָ�ʽ����ɫ=����outline��
    outlineZOffsetMask = 1-outlineZOffsetMask;
    outlineZOffsetMask = invLerpClamp(_OutlineZOffsetMaskRemapStart,_OutlineZOffsetMaskRemapEnd,outlineZOffsetMask);// allow user to flip value or remap | �����û���תֵ������ӳ��

    // [Apply ZOffset, Use remapped value as ZOffset mask]
    // | [Ӧ��ZOffset��ʹ������ӳ���ֵ��ΪZOffset����] 
    // ����ʹ������һ��������õ���outlineZOffsetMask���������_OutlineZOffsetһͬ�����������������_IsFace=0/1�����ﻹ�������һ�������Ե�����
    output.positionCS = NiloGetNewClipPosWithZOffset(output.positionCS, _OutlineZOffset * outlineZOffsetMask + 0.03 * _IsFace);
#endif

    // ShadowCaster pass needs special process to positionCS, else shadow artifact will appear
    // | ShadowCaster pass ��Ҫ��positionCS���⴦������������ӰαӰ��shadow artifact��������������
    //--------------------------------------------------------------------------------------
#ifdef ToonShaderApplyShadowBiasFix
    // see GetShadowPositionHClip() in URP/Shaders/ShadowCasterPass.hlsl
    // ApplyShadowBias����������Shadows.hlsl��
    // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl
    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, output.normalWS, _LightDirection));

    // ƽ̨���컯����
    // �� DX11/12��PS4��XboxOne �� Metal �У�Z ��������Χ�� 1 �� 0���������� UNITY_REVERSED_Z��������ƽ̨�ϣ���Χ�� 0 �� 1��
    #if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #else
    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #endif
    output.positionCS = positionCS;
#endif
    //--------------------------------------------------------------------------------------    

    return output;
}

///////////////////////////////////////////////////////////////////////////////////////
// fragment shared functions (Step1: prepare data structs for lighting calculation)
// | ƬԪ��������Step1��Ϊ���ռ���׼�����ݽṹ��
///////////////////////////////////////////////////////////////////////////////////////
half4 GetFinalBaseColor(Varyings input)
{
    return tex2D(_BaseMap, input.uv) * _BaseColor;
}
half3 GetFinalEmissionColor(Varyings input)
{
    half3 result = 0;
    if(_UseEmission)
    {
        result = tex2D(_EmissionMap, input.uv).rgb * _EmissionMapChannelMask * _EmissionColor.rgb;
    }

    return result;
}
half GetFinalOcculsion(Varyings input)
{
    //occlusionֵ��һ��half����Χ=[0,1]����Ŀǰ����ShadeGI����ӹ��գ���ShadeSingleLight����Դֱ�ӹ��գ����õ�
    half result = 1; //û�п���Occulsionʱ������ֵΪ1
    if(_UseOcclusion)
    {
        half4 texValue = tex2D(_OcclusionMap, input.uv); //_OcclusionMap��һ�ŻҶ�ͼ��һ����˵����
        half occlusionValue = dot(texValue, _OcclusionMapChannelMask); //Ĭ��ֻȡRͨ�� //���ֵ��[0,1]
        occlusionValue = lerp(1, occlusionValue, _OcclusionStrength); //����һ������ǿ��
        occlusionValue = invLerpClamp(_OcclusionRemapStart, _OcclusionRemapEnd, occlusionValue); //���û�����
        result = occlusionValue;
    }

    return result;
}
half3 GetFinalShadowColor(Varyings input) 
{
	return _ShadowColor.rgb;
}
half GetUseLightMap(Varyings input)
{
	if (_UseLightMap)
	{
		return 1;
	}
	return 0;
}
half3 GetLeftLightMap(Varyings input) //�����LightMap��sdf��ͼ������ֻ����0-90������µ���Ӱ���������������������
{
	if (_UseLightMap)
	{
		float4 lightMapL = tex2D(_LightMap, input.uv);
		return lightMapL;
	}
	return 1;
}
half3 GetRightLightMap(Varyings input) //�����LightMap��sdf��ͼ������ֻ����0-90������µ���Ӱ���Ұ������ҵ���תuv.x����
{
	if (_UseLightMap)
	{
		float2 flippedUV = float2(1 - input.uv.x, input.uv.y);
		float4 lightMapR = tex2D(_LightMap, flippedUV);
		return lightMapR;
	}
	return 1;
}

half GetUseRimLight(Varyings input) {
	if (_UseRimLight) { // ����RimLight,1,FakeSSS,2
		return 1;
	}
	return 0;
}
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
void DoClipTestToTargetAlphaValue(half alpha) // ͸���Ȳ��� AlphaTest/AlphaClipping
{
#if _UseAlphaClipping
    clip(alpha - _Cutoff);
#endif
}
ToonSurfaceData InitializeSurfaceData(Varyings input) // ��ʼ�� ToonSurfaceData �ṹ��
{
    ToonSurfaceData output;

    // albedo & alpha
    float4 baseColorFinal = GetFinalBaseColor(input);
    output.albedo = baseColorFinal.rgb;
    output.alpha = baseColorFinal.a;
    DoClipTestToTargetAlphaValue(output.alpha);// early exit if possible // ������͸���Ȳ�����ǰ

    // emission
    output.emission = GetFinalEmissionColor(input);

    // occlusion
    output.occlusion = GetFinalOcculsion(input);

    // lightmap
	output._useLightMap = GetUseLightMap(input);
	output._lightMapL = GetLeftLightMap(input);
	output._lightMapR = GetRightLightMap(input);

	// shadow color
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
ToonLightingData InitializeLightingData(Varyings input) // ��ʼ�� lightingData �ṹ��
{
    ToonLightingData lightingData;
    lightingData.positionWS = input.positionWSAndFogFactor.xyz;
    lightingData.viewDirectionWS = SafeNormalize(GetCameraPositionWS() - lightingData.positionWS); //SafeNormalize�����һ����������г���0  
    lightingData.normalWS = normalize(input.normalWS); //interpolated normal is NOT unit vector, we need to normalize it | ��ֵ���߲��ǵ�λ������������Ҫ������й�һ��

    return lightingData;
}

///////////////////////////////////////////////////////////////////////////////////////
// fragment shared functions (Step2: calculate lighting & final color)
// | ƬԪ��������Step2��������պ�������ɫ��
///////////////////////////////////////////////////////////////////////////////////////

// all lighting equation written inside this .hlsl,
// just by editing this .hlsl can control most of the visual result.
// | ���й��շ��̶�д����� .hlsl �У�����ͨ���༭��� .hlsl �Ϳ��Կ��ƴ󲿷ֵ��Ӿ�Ч����
#include "SimpleURPToonLitOutlineExample_LightingEquation.hlsl"

// this function contains no lighting logic, it just pass lighting results data around
// the job done in this function is "do shadow mapping depth test positionWS offset"
// | ������������������߼�����ֻ�Ǵ��ݹ��ս������
// �����������ɵĹ����ǡ���Ӱӳ�� ��Ȳ��� ����λ��ƫ�ơ�������������
half3 ShadeAllLights(ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    // Indirect lighting | ��ӹ���
    half3 indirectResult = ShadeGI(surfaceData, lightingData);

    //////////////////////////////////////////////////////////////////////////////////
    // Light struct is provided by URP to abstract light shader variables.| URP�ṩ��Light�ṹ��
    // It contains light's | �������
    // - direction | ����
    // - color | ��ɫ
    // - distanceAttenuation | ����˥���� 
    // - shadowAttenuation | ��Ӱ˥����
    /*
    // Light�ṹ�嶨����Lighting.hlsl��
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
    // You should never reference light shader variables in your shader, instead use the | ���ʹ��
    // -GetMainLight()
    // -GetLight()
    // funcitons to fill this Light struct. | �����Light�ṹ��
    //////////////////////////////////////////////////////////////////////////////////

    //==============================================================================================
    // Main light is the brightest directional light.
    // It is shaded outside the light loop and it has a specific set of variables and shading path
    // so we can be as fast as possible in the case when there's only a single directional light
    // You can pass optionally a shadowCoord. If so, shadowAttenuation will be computed.
    //| ����ԴMain light�������Ķ����Դdirectional light��
    // ����light loop֮�ⱻ��ɫ����������һ���ض��ı�������ɫ·��
    // �������ǿ�����ֻ��һ�������Դ������¾����ܿ�
    // GetMainLight����ѡ�񴫵�һ��float4 shadowCoord��������ʱ������ light.shadowAttenuation��
    /*
    // GetMainLight()������Lighting.hlsl��
    Light GetMainLight()
    {
        Light light;
        light.direction = _MainLightPosition.xyz;
        light.distanceAttenuation = unity_LightData.z; // unity_LightData.z is 1 when not culled by the culling mask, otherwise 0.
        light.shadowAttenuation = 1.0; // Ĭ��ֵ=1
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

    // ��positionWS������Դ�ķ������ƫ�ƣ���Ϊ���ݸ�TransformWorldToShadowCoord������positionWS����
    // ע������ _IsFace �����ƫ����һ��
    float3 shadowTestPosWS = lightingData.positionWS + mainLight.direction * (_ReceiveShadowMappingPosOffset + _IsFace); // Ϊɶ������
#ifdef _MAIN_LIGHT_SHADOWS
    // ��������Դ��Ӱ��������Ӱ����
    // compute the shadow coords in the fragment shader now due to this change | ��������仯��������ƬԪ��ɫ���м�����Ӱ����
    // https://forum.unity.com/threads/shadow-cascades-weird-since-7-2-0.828453/#post-5516425

    // _ReceiveShadowMappingPosOffset will control the offset the shadow comparsion position, 
    // doing this is usually for hide ugly self shadow for shadow sensitive area like face
    // | _ReceiveShadowMappingPosOffset ��������Ӱλ�õ�ƫ������������ 
    // ������ͨ����Ϊ��������Ӱ�����������沿���ѿ���������Ӱ
    /*
    // TransformWorldToShadowCoord����������Shadow.hlsl��
    float4 TransformWorldToShadowCoord(float3 positionWS)
    {
    #ifdef _MAIN_LIGHT_SHADOWS_CASCADE
        half cascadeIndex = ComputeCascadeIndex(positionWS); // ��������������㼶������
    #else
        half cascadeIndex = 0;
    #endif

        float4 shadowCoord = mul(_MainLightWorldToShadow[cascadeIndex], float4(positionWS, 1.0));

        return float4(shadowCoord.xyz, cascadeIndex);
    }
    // MainLightRealtimeShadow����Ҳ������Shadow.hlsl�У����ڼ�����Ӱ˥�� //���Ǻܶ�����
    half MainLightRealtimeShadow(float4 shadowCoord)
    {
    #if !defined(MAIN_LIGHT_CALCULATE_SHADOWS) //_MAIN_LIGHT_SHADOWS���Լ��ٶ���һ��MAIN_LIGHT_CALCULATE_SHADOWS
        return 1.0h;
    #endif

        ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
        half4 shadowParams = GetMainLightShadowParams();
        return SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowCoord, shadowSamplingData, shadowParams, false);
    }
    */
    float4 shadowCoord = TransformWorldToShadowCoord(shadowTestPosWS); //��Ӱ���꣨������ռ�ת������Ӱ����ϵ�£�
    mainLight.shadowAttenuation = MainLightRealtimeShadow(shadowCoord); //������Ӱ˥��
#endif 

    // Main light | ����Դ
    half3 mainLightResult = ShadeSingleLight(surfaceData, lightingData, mainLight, false);
    // Face Shadow Mask
    half3 faceShadowMask = ShadeFaceShadow(surfaceData, lightingData, mainLight); // ����ֵ��0=(0,0,0)��1=(1,1,1)

    //==============================================================================================
    // All additional lights | ���ж���Ĺ�Դ

    half3 additionalLightSumResult = 0;

#ifdef _ADDITIONAL_LIGHTS
    // Returns the amount of lights affecting the object being renderer. | ����Ӱ����Ⱦ����Ĺ�Դ������
    // These lights are culled per-object in the forward renderer of URP. | ��Щ���� URP ��ǰ����Ⱦ���б�������޳���������
    int additionalLightsCount = GetAdditionalLightsCount();
    for (int i = 0; i < additionalLightsCount; ++i)
    {
        // Similar to GetMainLight(), but it takes a for-loop index. This figures out the
        // per-object light index and samples the light buffer accordingly to initialized the
        // Light struct. If ADDITIONAL_LIGHT_CALCULATE_SHADOWS is defined it will also compute shadows.
        /*
        // GetAdditionalPerObjectLight���� ������ GetMainLight()��������Ҫһ�� ������Դ������perObjectLightIndex����Ҳ������Shadow.hlsl��:
        // Fills a light struct given a perObjectLightIndex
        Light GetAdditionalPerObjectLight(int perObjectLightIndex, float3 positionWS){}

        // AdditionalLightRealtimeShadow���� Ҳ������Shadow.hlsl��:
        half AdditionalLightRealtimeShadow(int lightIndex, float3 positionWS){
            ����˵��
            �ȵ���GetAdditionalLightShadowSamplingData������
            �ٵ���GetAdditionalLightShadowParams������
            ������SampleShadowmap����������Shadowmap
        }

        // AdditionalLightShadow���� Ҳ������Shadow.hlsl��:
        half AdditionalLightShadow(int lightIndex, float3 positionWS, half4 shadowMask, half4 occlusionProbeChannels){
            ����˵��
            �ȵ���AdditionalLightRealtimeShadow������
            �ٵ���MixRealtimeAndBakedShadows��������ʵʱRealtime�ͺ決Baked��Shadow��ϵõ�����Shadow���
        }
        */
        int perObjectLightIndex = GetPerObjectLightIndex(i);
        Light light = GetAdditionalPerObjectLight(perObjectLightIndex, lightingData.positionWS); // use original positionWS for lighting | ʹ��ԭʼpositionWS��������
        //light.shadowAttenuation = AdditionalLightRealtimeShadow(perObjectLightIndex, shadowTestPosWS); //ԭ�� 
        light.shadowAttenuation = AdditionalLightShadow(perObjectLightIndex, shadowTestPosWS, 0, 0); //�Ľ� //use offseted positionWS for shadow test | ʹ��ƫ��positionWS������Ӱ���ԣ�������Ӱ˥���� //ɶ����Ӱ���ԣ�����

        // Different function used to shade additional lights.
        additionalLightSumResult += ShadeSingleLight(surfaceData, lightingData, light, true);
    }
#endif
    //==============================================================================================

    // emission + rimLight | �Է��� + ��Ե��
    //half3 emissionResult = ShadeEmission(surfaceData, lightingData); //ԭ��
    half3 emissionRimLightResult = ShadeEmission(surfaceData, lightingData, mainLight); //�Ľ�

    // �ϳ���Щ�⣺��ӹ��� + ������ + ���ж������ + �Է���
    //return CompositeAllLightResults(indirectResult, mainLightResult, additionalLightSumResult, emissionRimLightResult, surfaceData, lightingData); //ԭ��
    return CompositeAllLightResults(indirectResult, mainLightResult, additionalLightSumResult, emissionRimLightResult, faceShadowMask, surfaceData, lightingData); //�Ľ�
}

// �������ɫת����outline����ɫ
half3 ConvertSurfaceColorToOutlineColor(half3 originalSurfaceColor)
{
    return originalSurfaceColor * _OutlineColor;
}
half3 ApplyFog(half3 color, Varyings input)
{
    half fogFactor = input.positionWSAndFogFactor.w;
    // Mix the pixel color with fogColor. You can optionaly use MixFogColor to override the fogColor
    // with a custom one.
    // MixFog ����������Core.hlsl ��
    color = MixFog(color, fogFactor);

    return color;  
}

// ƬԪ��ɫ�����루���� ForwardLit �� Outline 2��Pass�������л����ToonShaderIsOutline����Ϊ�������в�ͬ�Ĵ���
// only the .shader file will call this function by 
// #pragma fragment ShadeFinalColor
half4 ShadeFinalColor(Varyings input) : SV_TARGET
{
    //////////////////////////////////////////////////////////////////////////////////////////
    // first prepare all data for lighting function | ����׼���������ܵ���������
    //////////////////////////////////////////////////////////////////////////////////////////

    // fillin ToonSurfaceData struct: | ��� ToonSurfaceData �ṹ�壺
    ToonSurfaceData surfaceData = InitializeSurfaceData(input);

    // fillin ToonLightingData struct: | ��� ToonLightingData �ṹ�壺
    ToonLightingData lightingData = InitializeLightingData(input);
 
    // apply all lighting calculation | Ӧ�����й��ռ���
    half3 color = ShadeAllLights(surfaceData, lightingData);

#ifdef ToonShaderIsOutline
    color = ConvertSurfaceColorToOutlineColor(color); // �����outline����Ҫ�ѱ������ɫת����outline����ɫ
#endif

    // ����ʹ�õ����Զ����ApplyFog�����������ú���
    color = ApplyFog(color, input);

    return half4(color, surfaceData.alpha);
}

// ƬԪ��ɫ�����루������ ShadowCaster Pass �� DepthOnly Pass 2��Pass��
//////////////////////////////////////////////////////////////////////////////////////////
// fragment shared functions (for ShadowCaster pass & DepthOnly pass to use only)
//////////////////////////////////////////////////////////////////////////////////////////
void BaseColorAlphaClipTest(Varyings input)
{
    DoClipTestToTargetAlphaValue(GetFinalBaseColor(input).a);
}
