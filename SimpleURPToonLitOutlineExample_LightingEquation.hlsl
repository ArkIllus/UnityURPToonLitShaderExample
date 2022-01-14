// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// This file is intented for you to edit and experiment with different lighting equation.
// Add or edit whatever code you want here

// #pragma once is a safe guard best practice in almost every .hlsl (need Unity2020 or up), 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
//#pragma once

// #ifndef XXX + #define XXX + #endif is a safe guard best practice in almost every .hlsl, 
#ifndef SimpleURPToonLitOutlineExample_LightingEquation_Include
#define SimpleURPToonLitOutlineExample_LightingEquation_Include

half3 ShadeGI(ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    // hide 3D feeling by ignoring all detail SH (leaving only the constant SH term)
    // SH 1 (only use this)
    // SH 234 (ignored)
    // SH 56789 (ignored)
    // we just want some average envi indirect color only
    half3 averageSH = SampleSH(0); // ���������������3������̽�벢��ֵ������������
    // ������ǹر����Զ��決����û�к決lightprobe�����������Ǻ�ɫ�� 
    // ���������û��probe����ʹ�ù��������еĻ���probe��ͨ����Sky Box��
    // ��̬����ͨ������probe��þ�̬����ļ�ӹ⹱�ף� probe�еļ�¼��probeλ�ô�����ǶȲ�������ɫ������ΪSHϵ���� 
    // ����probe�Ĺ�����ͨ��SHϵ�����ټ����������������Cubemap��ͼ��˵��Լ���ܡ� 
    // probe����Ϊ������ɫ�ķ�ʽ������Щ��ɫ����ͨ��RayTracing���߼���ģ�����ʵʱ�仯��
    // probe��Ҳ�޷��ж�������룬�޷��ṩ��Ӱ��

    // can prevent result becomes completely black if lightprobe was not baked | ��ֹlightprobeû�б��決ʱ��ȫ���
    //averageSH = max(_IndirectLightMinColor,averageSH);

    // occlusion (to prevent result becomes completely black) 
    // ʹ��_OcclusionIndirectStrength�ڼ�ӹ����п����ڵ��ĳ̶�
    half indirectOcclusion = lerp(1, surfaceData.occlusion, _OcclusionIndirectStrength);
    /* 
    e.g.: Ĭ�� _OcclusionIndirectStrength = 0.5ʱ��indirectOcclusion = (1 + surfaceData.occlusion) / 2������1=û���ڵ�=��ȫ���ܼ�ӹ���
    ����surfaceData.occlusion��[0,1]������indirectOcclusion��[0.5, 1]���������50%�����Է�ֹ��ȫ���
    */

    // _IndirectLightMultiplier ��Ϊ����������ӹ��գ�ĿǰĬ��=1��
    half3 indirectLight = averageSH * (_IndirectLightMultiplier * indirectOcclusion);
                                                                  
    //return averageSH * indirectOcclusion;
    //return indirectLight;
    return max(indirectLight, _IndirectLightMinColor); //��ֹlightprobeû�б��決��_OcclusionIndirectStrength=1����_IndirectLightMultiplier=0ʱ��ȫ���
}

// ���ڳ�ʼ��lightAttenuation����faceShadowMask������ֵ��0��1
half CustomFaceShade(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight) // isAdditionalLightĿǰû����
{
    half3 N = lightingData.normalWS;
    half3 L = light.direction;
    half3 V = lightingData.viewDirectionWS;
    half3 H = normalize(L+V);

    half NoL = dot(N,L);

    // ====== Genshin Style facial shading ======

    // Get front and right vectors from rotation matrix
    // ���ͣ� Unity��ģ�Ϳռ䣨ʹ����������ϵ���У�x����(1, 0, 0)��y����(0, 1, 0)��z����(0, 0, 1) �ֱ��Ӧ ģ�͵����ҡ��ϡ�ǰ����
    // ���ڣ�������ռ���ģ����������ϵ��xyz�����Ӧ�ķ������� 
    // ���� x�������ҷ�����float3 Right = TransformObjectToWorldDir(float3(1, 0, 0)).xyz;
    // ����õ� float3 Right = (unity_Object2Wolrd._m00, unity_Object2Wolrd._m10, unity_Object2Wolrd._m20);
    float3 Right = unity_ObjectToWorld._m00_m10_m20; //����ռ��и�ƬԪ����ɫ�������ҷ�������δ��һ��
    //float3 Up = unity_ObjectToWorld._m01_m11_m21; //...���Ϸ�
    float3 Front = unity_ObjectToWorld._m02_m12_m22; //...��ǰ��

    // Nomralize light direction in relation to front and right vectors
    // ��λ�����ĵ�� = �н�����
    // ֻȡxz���������ҡ�ǰ���򣬺������Ϸ����൱�ڴ���ά������ɶ�άxzƽ��������
    float RightLight = dot(normalize(Right.xz), normalize(L.xz));
    float FrontLight = dot(normalize(Front.xz), normalize(L.xz));

    // ��Ӱ�����޸���ʵ�ָ�ƽ���Ĺ��� -> https://zhuanlan.zhihu.com/p/279334552;  // ��������������������
    RightLight = -(acos(RightLight) / 3.14159265 - 0.5) * 2;

    // ʹ��ԭʼLightMap����ֵ��Rͨ��ֵ����Ӱ�е���ಿ�֣��� ��ת��LightMap����ֵ��Rͨ��ֵ����Ӱ�е��Ҳಿ�֣���ȡ���ڹ��߷���
    float LightMap = RightLight > 0 ? surfaceData._lightMapR.r : surfaceData._lightMapL.r;

    //�������������θ��ݹ�һ���Ĺ��߷���ֲ���lightmap�Ϲ������ٶȣ�
    //ֵԽ��=����ƹ�ʱת��Խ�죬������Զ��ƹ�ʱת��Խ����ֵԽ��=�෴��  // ��������������������
    float dirThreshold = 0.1;

    //�������ƹ⣬��ʹ���ҹ�һ���ƹⷽ���dirThreshold��
    //�������ƹ⣬��ʹ��ǰ��һ���ƹⷽ��ͣ�1-dirThreshold������Ӧ��ƽ��...
    // ...��ȷ��180��ʱ��ƽ�����ɣ�����ǰ��һ���ƹⷽ��==0����  // ��������������������
    float lightAttenuation_temp = (FrontLight > 0) ? 
        min((LightMap > dirThreshold * RightLight), (LightMap > dirThreshold * -RightLight)) :
        min((LightMap > (1 - dirThreshold * 2) * FrontLight - dirThreshold), (LightMap > (1 - dirThreshold * 2) * -FrontLight + dirThreshold));
     
    //[����]�����Թ���ʱ������ƽ�ƣ�
	//lightAttenuation_temp += (FrontLight < -0.9) ? (min((LightMap > 1 * FrontLight), (LightMap > 1 * -FrontLight))) : 0;

    // ====== End of Genshin Style facial shading ======

    half lightAttenuation = surfaceData._useLightMap ? lightAttenuation_temp : 1;

    return lightAttenuation; // ����ֵ��0��1
}

// Most important part: lighting equation, edit it according to your needs, write whatever you want here, be creative!
// This function will be used by all direct lights (directional/point/spot) 
// | ����Ҫ�ĺ�������������ᱻ�������͵Ĺ�Դʹ�ã�ƽ�й�/���Դ/�۹�ƣ�������Դ + �����Դ��
// TODO���ƺ�ֻ���������ȱ�ٸ߹ⷴ���Ҳ���Կ�����_Metallic��PBR�ķ�������
half3 ShadeSingleLight_v1(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight)
{
    half3 N = lightingData.normalWS;
    half3 L = light.direction;
    half3 V = lightingData.viewDirectionWS;
    half3 H = normalize(L+V);

    half NoL = dot(N,L);

	// Replace original initialization of lightAttenuation with custom face shading result;
    //half lightAttenuation = 1;
    half lightAttenuation = CustomFaceShade(surfaceData, lightingData, light, isAdditionalLight);

    // light's distance & angle fade for point light & spot light (see GetAdditionalPerObjectLight(...) in Lighting.hlsl)
    // | ���Դ�;۹�ƵĹ��յľ���&�Ƕ�˥������μ�Lighting.hlsl�е�GetAdditionalPerObjectLight(...)��
    // Lighting.hlsl -> https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
    half distanceAttenuation = min(4,light.distanceAttenuation); //clamp to prevent light over bright if point/spot light too close to vertex 
                                                                 // | ������Դ/�۹���붥��̫������ȡ����=4�Է�ֹ���߹���

    // N dot L
    // simplest 1 line cel shade, you can always replace this line by your own method! | ��򵥵�1���߽��ߵİ���������+����+ʹ��smoothstep��͹��ɣ�
    // litOrShadowArea�ķ�ΧΪ[0,1]
    half litOrShadowArea = smoothstep(_CelShadeMidPoint-_CelShadeSoftness,_CelShadeMidPoint+_CelShadeSoftness, NoL); //smoothstep��������0��1��ƽ������

    // occlusion
    // ʹ��_OcclusionDirectStrength��ֱ�ӹ����п����ڵ��ĳ̶�
    litOrShadowArea *= lerp(1, surfaceData.occlusion, _OcclusionDirectStrength);

    // face ignore celshade since it is usually very ugly using NoL method
    // �沿ֱ��ʹ��litOrShadowArea�Ƚ��ѿ�������ʹ��lerp��һ����[0,1]��[0.5,1]������ӳ�䣬�൱������������һЩ����ʱ������litOrShadowArea�ķ�ΧΪ[0.5,1]
    litOrShadowArea = _IsFace ? lerp(0.5,1,litOrShadowArea) : litOrShadowArea;

    // light's shadow map | ���յ�shadow map��Ҳ������Ӱ˥����ʹ��_ReceiveShadowMappingAmount����Ӧ����Ӱ˥���ĳ̶ȣ�=0ʱû����Ӱ����
    // *** �����ž�Ҫ���У�UNITY_LIGHT_ATTENUATION�������˥������Ӱֵ��˵Ľ���洢��atten�У������յ�color����attenֵ��
    // *** ������shadowAttenuation��Ϊһ����������litOrShadowArea������litOrShadowArea����litOrShadowColor������
    // shadowAttenuationֵ�ķ�ΧΪ[0,1]
    litOrShadowArea *= lerp(1,light.shadowAttenuation,_ReceiveShadowMappingAmount);

    half3 litOrShadowColor = lerp(_ShadowMapColor,1, litOrShadowArea); // ������Ӱ����ɫ��ʹ��lerp��һ����[0,1]��[_ShadowMapColor,1]������ӳ�䣬litOrShadowArea=0ʱ��litOrShadowColor=_ShadowMapColor
    
    // distanceAttenuationֵ�ķ�ΧΪ[0,1]
    half3 lightAttenuationRGB = litOrShadowColor * distanceAttenuation; // �ٳ� ����˥����������˥����

    // saturate() light.color to prevent over bright | saturate(light.color)��ֹ����������Դ��intensity��Ϊ����1ʱ��light.color�ķ�Χ�ͳ���1�ˣ�
    // additional light reduce intensity since it is additive | ���ڶ����Դ�Ĺ��0.25��������һЩ������Ϊɶ����������о�����û�仯����Ϊû�ж����Դ��
    return saturate(light.color) * lightAttenuationRGB * (isAdditionalLight ? 0.25 : 1);
    //return light.color * lightAttenuationRGB * (isAdditionalLight ? 0.25 : 1);
}
// Most important part: lighting equation, edit it according to your needs, write whatever you want here, be creative!
// This function will be used by all direct lights (directional/point/spot) 
// | ����Ҫ�ĺ�������������ᱻ�������͵Ĺ�Դʹ�ã�ƽ�й�/���Դ/�۹�ƣ�������Դ + �����Դ��
// TODO���ƺ�ֻ���������ȱ�ٸ߹ⷴ���Ҳ���Կ�����_Metallic��PBR�ķ�������
half3 ShadeSingleLight_v2(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight)
{
    half3 N = lightingData.normalWS;
    half3 L = light.direction;
    half3 V = lightingData.viewDirectionWS;
    half3 H = normalize(L+V);

    half NoL = dot(N,L);

	// Replace original initialization of lightAttenuation with custom face shading result;
    //half lightAttenuation = 1;
    half lightAttenuation = CustomFaceShade(surfaceData, lightingData, light, isAdditionalLight);

    // light's shadow map | ���յ�shadow map��Ҳ������Ӱ˥����ʹ��_ReceiveShadowMappingAmount����Ӧ����Ӱ˥���ĳ̶ȣ�=0ʱû����Ӱ˥����
    // *** �����ž�Ҫ���У�UNITY_LIGHT_ATTENUATION�������˥������Ӱֵ��˵Ľ���洢��atten�У������յ�color����attenֵ��
    // *** ������shadowAttenuation��Ϊһ����������lightAttenuation
    // shadowAttenuationֵ�ķ�ΧΪ[0,1]
    lightAttenuation *= lerp(1,light.shadowAttenuation,_ReceiveShadowMappingAmount);

    // light's distance & angle fade for point light & spot light (see GetAdditionalPerObjectLight(...) in Lighting.hlsl)
    // | ���Դ�;۹�ƵĹ��յľ���&�Ƕ�˥������μ�Lighting.hlsl�е�GetAdditionalPerObjectLight(...)��
    // Lighting.hlsl -> https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
    half distanceAttenuation = min(4,light.distanceAttenuation); //clamp to prevent light over bright if point/spot light too close to vertex 
                                                                 // | ������Դ/�۹���붥��̫������ȡ����=4�Է�ֹ���߹���

    lightAttenuation *= distanceAttenuation; // �ٳ� ����˥����������˥����// distanceAttenuationֵ�ķ�ΧΪ[0,1]

    // N dot L
    // simplest 1 line cel shade, you can always replace this line by your own method! | ��򵥵�1���߽��ߵİ���������+����+ʹ��smoothstep��͹��ɣ�
    // cellitOrShadowArea�ķ�ΧΪ[0,1]
    half celLitOrShadowArea = smoothstep(_CelShadeMidPoint-_CelShadeSoftness,_CelShadeMidPoint+_CelShadeSoftness, NoL); //smoothstep��������0��1��ƽ������
    
    // face ignore celshade since it is usually very ugly using NoL method
    // �沿ֱ��ʹ��celLitOrShadowArea�Ƚ��ѿ�������ʹ��lerp��һ����[0,1]��[0.5,1]������ӳ�䣬�൱������������һЩ����ʱ������celLitOrShadowArea�ķ�ΧΪ[0.5,1]
    //celLitOrShadowArea = _IsFace ? lerp(0.5,1,litOrShadowArea) : litOrShadowArea;

    // don't want direct lighting's cel shade effect looks too strong? set ignoreValue to a higher value | ���ƺ���cel�����������ĳ̶ȣ��������������������
    // ĿǰĬ��_AdditionalLightIgnoreCelShade = 0.8��_MainLightIgnoreCelShade = 0
    lightAttenuation *= lerp(celLitOrShadowArea, 1, isAdditionalLight ? _AdditionalLightIgnoreCelShade : _MainLightIgnoreCelShade);
    
    // don't want direct lighting becomes too bright for toon lit characters? set this value to a lower value 
    // ĿǰĬ��_DirectLightMultiplier=1
    lightAttenuation *= _DirectLightMultiplier;
    //lightAttenuation *= 0.25;

    // occlusion
    // ʹ��_OcclusionDirectStrength��ֱ�ӹ����п����ڵ��ĳ̶�
    half directOcclusion = lerp(1, surfaceData.occlusion, _OcclusionDirectStrength);
    lightAttenuation *= directOcclusion;

    //half3 litOrShadowColor = lerp(_ShadowMapColor,1, litOrShadowArea); // ������Ӱ����ɫ��ʹ��lerp��һ����[0,1]��[_ShadowMapColor,1]������ӳ�䣬litOrShadowArea=0ʱ��litOrShadowColor=_ShadowMapColor
    //
    // ����ʹ��_ShadowMapColor������Ӱ����ɫ

    // saturate() light.color to prevent over bright | saturate(light.color)��ֹ����������Դ��intensity��Ϊ����1ʱ��light.color�ķ�Χ�ͳ���1�ˣ�
    // additional light reduce intensity since it is additive | ���ڶ����Դ�Ĺ��0.25��������һЩ������Ϊɶ����������о�����û�仯����Ϊû�ж����Դ��
    //return saturate(light.color) * lightAttenuationRGB * (isAdditionalLight ? 0.25 : 1);
    //
    // ����saturate(light.color)��ֹ����������Դ��intensity��Ϊ����1ʱ����������CompositeAllLightResultsʱ���ƹ����������ٶ��ڶ����Դ�Ĺ��0.25������һЩ
    return light.color * lightAttenuation; 

    // ***��ע�⡿ò����Ҫ����� CompositeAllLightResults��Luminance���ƹ��� ʹ�ã�����������Ӱ���Ǻܺڵģ�������
}
half3 ShadeSingleLight(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight)
{
    return ShadeSingleLight_v1(surfaceData, lightingData, light, isAdditionalLight);
}

// ��Ҫ��������Ramp Map����ʱû��
//half3 CalculateRamp(half halfLambert){}

// �Գơ���������Ե�⣨���ǣ�������������ˡ������� https://zhuanlan.zhihu.com/p/435005339
// �о�Ч����ԭ����ࡣ����
float3 NPR_Base_RimLight(float NdotV,float halfLambert,float3 baseColor)
{
    _RimIntensity = 1; // ����������������������������������������������������������������������������������������������������������������������������������������
    //return (1 - smoothstep(_RimRadius,_RimRadius + 0.03,NdotV)) * _RimIntensity * (1 - halfLambert) * baseColor;
    return (1 - smoothstep(_RimMin,_RimMin + 0.03, NdotV)) * _RimIntensity * (1 - halfLambert) * baseColor; //���Խ���_RimMax=_rimMin+0.03����������
}

// �桤��������Ե�� https://zhuanlan.zhihu.com/p/95986273
float3 Fresnel_schlick(float VoN, float3 rF0) {
		return rF0 + (1 - rF0) * pow(1 - VoN, 5);
	}
float3 Fresnel_extend(float VoN, float3 rF0) {
	return rF0 + (1 - rF0) * pow(1 - VoN, 3);
}
float3 Fresnel_RimLight(float NdotV,float VdotL,float3 baseColor) {
    half3 fresnel = Fresnel_extend(NdotV, float3(0.1, 0.1, 0.1));
    //half3 fresnelResult = _FresnelEff * fresnel * (1 - VoL) / 2;
    _RimIntensity = 1; // ����������������������������������������������������������������������������������������������������������������������������������������
    half3 fresnelResult = _RimIntensity * fresnel * (1 - VdotL) / 2 * baseColor.rgb;
    return fresnelResult;
}

//��JTRP��������Ե�� ������
/*
��ſ���һ�£����ڵ�㸴�ӣ��������Ϻ���Ӧ����ʹ��dot(N, L)�����Ե�⣬Ȼ���и�RimLightMask��ͼ���ǳ���Ҫ��Ȼ���Ǹ���ͼֻ�б��������б�Ե�⣩
*/

//��JTRP����Ļ�ռ���ȱ�Ե�� Screen Space Depth Rimlight https://zhuanlan.zhihu.com/p/139290492
/*
float2 L_View = normalize(mul((float3x3)UNITY_MATRIX_V, context.L).xy);
float2 N_View = normalize(mul((float3x3)UNITY_MATRIX_V, lerp(context.N, context.SN, _RimLightSNBlend)).xy);
float lDotN = saturate(dot(N_View, L_View) + _RimLightLength * 0.1);
float2 ssUV = posInput.positionSS + N_View * lDotN * _RimLightWidth * input.color.b * 40 * GetSSRimScale(posInput.linearDepth);
float depthTex = LoadCameraDepth(clamp(ssUV, 0, _ScreenParams.xy - 1));
float depthScene = LinearEyeDepth(depthTex, _ZBufferParams);
float depthDiff = depthScene - posInput.linearDepth;
float intensity = smoothstep(0.24 * _RimLightFeather * posInput.linearDepth, 0.25 * posInput.linearDepth, depthDiff);
intensity *= lerp(1, _RimLightIntInShadow, context.shadowStep) * _RimLightIntensity * mask;
            
float3 ssColor = intensity * lerp(1, context.brightBaseColor, _RimLightBlend)
* lerp(_RimLightColor.rgb, context.pointLightColor, luminance * _RimLightBlendPoint);
            
c = max(c, ssColor);
*/

// ԭ��
half3 ShadeEmission_v1(ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    half3 emissionResult = lerp(surfaceData.emission, surfaceData.emission * surfaceData.albedo, _EmissionMulByBaseColor); // optional mul albedo // �����Է�����ɫ����albedo��ɫ��Base��ɫ���ĳ̶�
    return emissionResult;
}
// �Ľ��棨����rimLight ���鵽����emission��ĺ����
half3 ShadeEmission_v2(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight)
{
    // ====== Rim Light ======
    half3 N = lightingData.normalWS;
    half3 V = lightingData.viewDirectionWS;
	half3 L = light.direction;

    half NdotL = dot(N, L);
    half NdotV = dot(N, V);
    half VdotL = dot(V, L);
    half halfLambert = NdotL * 0.5 + 0.5;
    
	half useRimLight = surfaceData._useRimLight;
	half4 rimColor = surfaceData._rimColor;
	half3 rimMin = surfaceData._rimMin;
	half3 rimMax = surfaceData._rimMax;
	half3 rimSmooth = surfaceData._rimSmooth;
    half rimIntensity = surfaceData._rimIntensity;

    //half3 ramp = CalculateRamp(halfLambert);
    //ramp *= CustomFaceShade(surfaceData, lightingData, lightingData, isAdditionalLight); //ĿǰisAdditionalLight����false������û����
                                                                        // CustomFaceShade���ڳ�ʼ��lightAttenuation����faceShadowMask������ֵ��0��1
                                                                        // ���ǣ����ramp�����õģ�������������������������Ӧ����һ�Ž�������������

	// initialize rimMask if not using custom rim light lightmask;
    //half3 rimMask = half3(1, 1, 1);
    // if use custom rim light lightmask;
    half3 rimMask = surfaceData._rimMask; // _rimMask�Ǹ�half
    half3 rimMaskStrength = surfaceData._rimMaskStrength;

    // rimLight������ʹ��NdotV + �������أ�NdotL��
    half ndv =  1 - max(0, NdotV);
    half rim = smoothstep(rimMin, rimMax, ndv) * (1 - halfLambert); //���Ʊ߹�ķ�Χ //ϣ�������ı�Ե�����������ʹ�ð������أ�NdotV������
    // ������������Ⱑ��̫����
    //if (useRimLight == 1) // ����RimLight,1,FakeSSS,2������ �� ���Բ�ֵ
    //{
    //    rim = lerp(rimMin, rimMax, ndv);
    //}
    rim = smoothstep(0, rimSmooth, rim); //���Ʊ߹����Ӳ��ʵ��Ч�����У���_RimSmooth=1ʱ��smoothstep(0, 1, rim)��rim��_RimSmooth=0ʱ��smoothstep(0, 0, rim)=1��
    rimIntensity = 1; // ����������������������������������������������������������������������������������������������������������������������������������������
    half rimLight = rim * lerp(1, rimMask.rgb, rimMaskStrength) * rimIntensity * rimColor.rgb; //���Ʊ�Ե������֡���ɫ��ǿ��

    //// �Գơ���������Ե�⣨�������ûɶ���𡣡�����
    //half3 rimLight = NPR_Base_RimLight(NdotV, halfLambert, rimColor.rgb);
    
    //// �桤��������Ե�⣨ΪɶûЧ����
    //half3 rimLight = Fresnel_RimLight(NdotV, VdotL, rimColor.rgb);
    // ====== End of Rim Light ======

    half3 emissionAndRim = surfaceData.emission;
    emissionAndRim.rgb += useRimLight ? rimLight : 0;

    half3 emissionAndRimResult = lerp(emissionAndRim, emissionAndRim * surfaceData.albedo, _EmissionMulByBaseColor); // �����Է�����ɫ����albedo��ɫ��Base��ɫ���ĳ̶�
    return emissionAndRimResult;
}
half3 ShadeEmission(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light)
{
    return ShadeEmission_v2(surfaceData, lightingData, light, false); 
}
// ԭ��
half3 CompositeAllLightResultsDefault(half3 indirectResult, half3 mainLightResult, half3 additionalLightSumResult, half3 emissionResult, ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    // ֻ��һ�����ڼ򵥵�ʵ�֣��ر���rawLightSum��ȡmax�������е����졣
    // [remember you can write anything here, this is just a simple tutorial method]
    // here we prevent light over bright,
    // while still want to preserve light color's hue

    half3 rawLightSum = max(indirectResult, mainLightResult + additionalLightSumResult); // pick the highest between indirect and direct light  
                                                                                         // ȡmax(��ӹ��ս�� �� ����Դ���ս��+�����Դ���ս��)��Ҳ����˵���ǹ�Դ�ܰ��������ӹ��յļ�������ʵ���ӵ��ˣ����Ƿ��е㡣����������                                                        
    //half3 rawLightSum = indirectResult + mainLightResult + additionalLightSumResult; // ���+ֱ��

    return surfaceData.albedo * rawLightSum + emissionResult; // ***ע�����������ɫ��ʱ����ˡ��Է������û�г�albedo���������albedo(Base) Color���������Է�����
}
// �Ľ���
half3 CompositeAllLightResults(half3 indirectResult, half3 mainLightResult, half3 additionalLightSumResult, half3 emissionResult, half3 faceShadowMask, ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    // Legacy method;
	/*half3 shadowColor = lerp(2*surfaceData._shadowColor, 1, faceShadowMask);
	half3 result = indirectResult*shadowColor + mainLightResult + additionalLightSumResult + emissionResult;
    return result;*/

    half3 shadowColor = lerp(surfaceData._shadowColor, 1, faceShadowMask); // faceShadowMask =1��ʾ��ȫû��[��ӹ��ղ��ֵ�]��Ӱ��=0��ʾ100%����[��ӹ��ղ��ֵ�]��Ӱ

    //half3 rawLightSum = max(indirectResult * shadowColor, mainLightResult + additionalLightSumResult); // max(��ӣ�ֱ��) 
    // ���ǹ�Դ�ܰ��������ӹ��յļ�������ʵ���ӵ��ˣ����Ƿ��е㡣���������� 
    // ��ӹ��ս�� * shadowColor ������Ӱ����
    // ֱ�ӹ��յİ����أ��������� ����������������  
    
    half3 rawLightSum = indirectResult * shadowColor + mainLightResult + additionalLightSumResult;  // ���+ֱ�� ***�����������������ܺ��ѿ�*** ��ν����
    
    //half3 rawLightSum = indirectResult + mainLightResult + additionalLightSumResult; //û��shadowColor����ӹ��ղ��־�û����Ӱ
    //half3 rawLightSum = indirectResult * shadowColor;

    //half lightLuminance = Luminance(rawLightSum);
    //half3 finalLightMulResult = rawLightSum / max(1,lightLuminance / max(1,log(lightLuminance))); // allow controlled over bright using log | ��������ƹ��� ������
    half3 finalLightMulResult = rawLightSum;

    return surfaceData.albedo * finalLightMulResult + emissionResult; // ***ע�����������ɫ��ʱ����ˡ��Է������û�г�albedo���������albedo(Base) Color���������Է�����
}
half3 ShadeFaceShadow(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light) // ȷ��������
{
	return CustomFaceShade(surfaceData, lightingData, light, false);
}
#endif