// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// This file is intented for you to edit and experiment with different lighting equation.
// Add or edit whatever code you want here

// #pragma once is a safe guard best practice in almost every .hlsl (need Unity2020 or up), 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
//#pragma once

// #ifndef XXX + #define XXX + #endif is a safe guard best practice in almost every .hlsl, 
#ifndef SimpleURPToonLitOutlineExample_LightingEquation_Include
#define SimpleURPToonLitOutlineExample_LightingEquation_Include

// ԭ��ʽ�߹� Blinn-Phong Specular
// TODO: [ͷ��]lightMap��Rͨ��û����
// TODO: ����Ϊ��Ϸ���һ/������Ӱ��
half3 NPR_Specular(float3 NdotH, float4 lightMap)
{
    // [����(�·�)]lightMap��ͨ����
    // R: Glossiness����������
    // G: Specular���߹�����
    // B: ��ӰȨ�أ��̶���Ӱ��
    // A: RampAreaMask

    // [ͷ��]lightMap��ͨ����
    // R: ͷ�����������򣨰�ɫ=���� ���=ͷ����
    // G: Specular���߹����򣩣��󲿷�ͷ�������Ǵ��ڵģ��ⲿ����NPR_Specular��û�и߹⣬������NPR_Hair_Additional_Specular�д���
    // B: ��ӰȨ�أ��̶���Ӱ��
    // A: ͷ�����������򣨰�ɫ=ͷ�� ǳ��=���Σ�

    float3 SpecularColor = lightMap.g;

    float SpecularRadius = _IsHair ? pow(max(0, NdotH), lightMap.a * 50) : pow(max(0, NdotH), lightMap.r * 50);
    // ��������(�·�)��ʹ�ý�����ͨ����Ϊָ��
    // ����ͷ����ʹ��ͷ�����������򣨰�ɫ=ͷ����ͨ����Ϊָ�����������

    return _IsHair ? smoothstep(0.3, 0.5, SpecularRadius) * SpecularColor * lerp(_HairSpecularStrength, 1, step(0.9, lightMap.g)) : //����ͷ����ʹ��һ���������������߹�ǿ��
                     smoothstep(0.3, 0.5, SpecularRadius) * SpecularColor * lightMap.g; //0.3, 0.5 ƫNPR
    // e.g.: [����(�·�)]����
    // return smoothstep(0, 1, SpecularRadius) * SpecularColor * lightMap.g; //ƫPBR
}

// ͷ���������NPR_Specular������Ҫ����ĸ߹⣨��Ϊ[ͷ��]lightMap��Gͨ����󲿷�ͷ�������Ǵ��ڵģ��ⲿ����NPR_Specular��û�и߹⣩ // �������_IsHair������0
// TODO�����Ч���Ƕ���ĸ߹⼯�����м䣬�����ǰ��ģ�����ѧ
half3 NPR_Hair_Additional_Specular_v1(float3 normalWS, float3 NdotL, float4 lightMap)
{
    float HariSpecRadius = 0.25; //����ͷ���ķ��䷶Χ
    float3 normalVS = normalize(mul(UNITY_MATRIX_V,normalWS));
    float HariSpecDir = normalVS * 0.5 + 0.5; // ӳ�䵽[0, 1] 
    float3 HariSpecular = smoothstep(HariSpecRadius, HariSpecRadius + 0.1, 1 - HariSpecDir) 
                        * smoothstep(HariSpecRadius, HariSpecRadius + 0.1, HariSpecDir) * NdotL;
    return _IsHair ? HariSpecular * _HairSpecularStrength * lightMap.b * step(lightMap.r, 0.1) * 1.0 : 0; //Bͨ��ָʾͷ������Ӱ���򲻸��и߹� //step(lightMap.r, 0.1)��[ͷ��]lightMap��Rͨ��<0.1Ϊͷ�����򣬼��ų�[ͷ��]lightMap�е���������
}

//TODO: �Ľ�������normalVS����������ͼ
//half3 NPR_Hair_Additional_Specular()
//{
//    return 0;
//}

// ԭ��ʽ�����߹� Glossiness
// TODO: �Ľ�������normalVS����������ͼ
half3 NPR_MetalSpecular(float3 normalWS, float4 lightMap)
{
    // [����(�·�)]lightMap��ͨ����
    // R: Glossiness����������
    // G: Specular���߹�����
    // B: ��ӰȨ�أ��̶���Ӱ��
    // A: RampAreaMask

    // [ͷ��]lightMap��ͨ����
    // R: ͷ�����������򣨰�ɫ=���� ���=ͷ����
    // G: Specular���߹�����
    // B: ��ӰȨ�أ��̶���Ӱ��
    // A: ͷ�����������򣨰�ɫ=ͷ�� ǳ��=���Σ�

    float3 normalVS = normalize(mul(UNITY_MATRIX_V, normalWS));
    
    float MetalMap = tex2D(_MetalMap, normalVS * 0.5 + 0.5) * 2;  //ʹ��normalVS����������ͼ
    
    //return step(0.95, MetalMap) * lightMap.r; // �����Ļ�ֻ�н�������ǿ���ǲ����н����߹�
    half3 metalSpecular = MetalMap * lightMap.r * _MetalColor;
    metalSpecular *= _IsHair ? step(0.1, lightMap.r) : 1; //step(lightMap.r, 0.1)��[ͷ��]lightMap��Rͨ��<0.1Ϊͷ�����򣬼��ų�[ͷ��]lightMap�е�ͷ����������Ҫ����Ϊ�н����߹⼯����ͷ���м䲻�ÿ�������ѧ��
    return metalSpecular;
}

// ����ԭ��ʽRamp��ͼ
// TODO: �ݶ�������Ч��
half3 NPR_Ramp(half NdotL, half _InNight, float4 lightMap) 
{
    //ʹ��[����(�·�)]lightMap��Aͨ����RampAreaMask ��ΪRampMap���������yֵ
    //[ͷ��]��δ�������[ͷ��]Aͨ����[����]��ͬ����ʱ���ú�[����]һ���Ĵ���ʽ��

    //ʹ��lightMap��Bͨ������ӰȨ�أ��̶���Ӱ����ΪhalfLambert�ĳ���

    half halfLambert = smoothstep(0.0, 0.5, NdotL) * (smoothstep(0.0, 0.5, lightMap.b) * 2); // ��NdotL>=0.5�Ĳ���=1 //��ΪlightMap.b�ķ�Χ��0~0.5���������ӳ�䵽[0, 1]
    /*
    Skin = 255
    Silk Stokings = 200
    Metal = 160
    Cloth = 113
    Other Hard Stuff = 0
    */
    return _InNight ? tex2D(_RampMap, (halfLambert, lightMap.a * 0.45)).rgb : tex2D(_RampMap, (halfLambert, lightMap.a * 0.45 + 0.55)).rgb; // Ramp��ͼ���ϰ벿���ǰ��죬�°벿��������
}

// ���ڳ�ʼ��faceShadowMask������Ϊֱ�ӹ��ա���ӹ��յĳ�������������Ӱ��������ֵ��0��1��***ע��***�����ڷ�����������ֵ��1��
// TODO�������
half CustomFaceShade_v1(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight) // isAdditionalLightĿǰû����
{
    half3 N = lightingData.normalWS;
    half3 L = light.direction;
    half NoL = dot(N,L);

    // ���ͣ� Unity��ģ�Ϳռ䣨ʹ����������ϵ���У�x����(1, 0, 0)��y����(0, 1, 0)��z����(0, 0, 1) �ֱ��Ӧ ģ�͵����ҡ��ϡ�ǰ����
    // ���ڣ�������ռ���ģ����������ϵ��xyz�����Ӧ�ķ������� 
    // ���� x�������ҷ�����float3 Right = TransformObjectToWorldDir(float3(1, 0, 0)).xyz;
    // ����õ� float3 Right = (unity_Object2Wolrd._m00, unity_Object2Wolrd._m10, unity_Object2Wolrd._m20);
    float3 Right = unity_ObjectToWorld._m00_m10_m20; //����ռ��и�ƬԪ����ɫ�������ҷ�������δ��һ��
    //float3 Up = unity_ObjectToWorld._m01_m11_m21; //...���Ϸ�
    float3 Front = unity_ObjectToWorld._m02_m12_m22; //...��ǰ��

    // ֻȡxz���������ҡ�ǰ���򣬺������Ϸ����൱�ڴ���ά������ɶ�άxzƽ��������
    float RightLight = dot(normalize(Right.xz), normalize(L.xz));
    float FrontLight = dot(normalize(Front.xz), normalize(L.xz));

    // ��Ӱ�����޸���ʵ�ָ�ƽ���Ĺ��� -> https://zhuanlan.zhihu.com/p/279334552;
    // Light�ӽ�ɫǰ������ʱ��RightLight��[0,pi]ӳ�䵽[-1,1]
    // Light�ӽ�ɫ��������ʱ��RightLight��[pi,2pi]ӳ�䵽[1,-1]
    RightLight = -(acos(RightLight) / 3.14159265 - 0.5) * 2;

    // ʹ��sdf��ͼ��Rͨ��ֵ
    // �� RightLight > 0ʱ������Ұ������䣻�� RightLight <= 0ʱ�������������� [ע������������Ƕ��ڽ�ɫ������Ե�]
    float LightMap = RightLight > 0 ? surfaceData._faceLightMapR.r : surfaceData._facelightMapL.r;

    // dirThreshold�������Ź������䷽��ı仯��������Ӱ�������ٶȣ�
    // ֵԽ��=�泯�ƹ�ʱ��Ӱ����Խ�죬������ƹ�ʱ��Ӱ����Խ����ֵԽ��=�෴��
    float dirThreshold = 0.1;

    // ���Light�ӽ�ɫǰ������ʱ����ʹ��RightLight�����dirThreshold��
    // ���Light�ӽ�ɫ��������ʱ����ʹ��FrontLight����ͣ�1-dirThreshold������Ӧ��ƽ��...
    // ...��ȷ��180��ʱ��ƽ�����ɣ�����ǰ��һ���ƹⷽ��==0����
    float lightAttenuation_temp = (FrontLight > 0) ? 
        min((LightMap > dirThreshold * RightLight), (LightMap > dirThreshold * -RightLight)) : //���ͣ�����Ұ�������ʱ��RightLight<0�������൱��LightMap > dirThreshold * -RightLight��
                                                                                               //������������ʱ��RightLight>0�������൱��LightMap > dirThreshold * RightLight����ʵ������min�滻if���
        min((LightMap > (1 - dirThreshold * 2) * FrontLight - dirThreshold), (LightMap > (1 - dirThreshold * 2) * -FrontLight + dirThreshold));

    // ��smoothstep��[0,1]֮��ƽ�������Ա����沿��Ӱ�ֽ��ߵľ��(Ȼ��Ч�����á�����)
    //float lightAttenuation_temp = (FrontLight > 0) ? 
    //    min(smoothstep(dirThreshold * RightLight - _FaceShadowRangeSmooth, dirThreshold * RightLight + _FaceShadowRangeSmooth, LightMap), 
    //        smoothstep(dirThreshold * -RightLight - _FaceShadowRangeSmooth, dirThreshold * -RightLight + _FaceShadowRangeSmooth, LightMap)) : // Light�ӽ�ɫǰ������ʱ��RightLight��[0,pi]ӳ�䵽[-1,1]
    //    min(smoothstep( (1 - dirThreshold * 2) * FrontLight - dirThreshold - _FaceShadowRangeSmooth, (1 - dirThreshold * 2) * FrontLight - dirThreshold + _FaceShadowRangeSmooth, LightMap), 
    //        smoothstep( (1 - dirThreshold * 2) * -FrontLight + dirThreshold - _FaceShadowRangeSmooth, (1 - dirThreshold * 2) * -FrontLight + dirThreshold + _FaceShadowRangeSmooth, LightMap));
     
    // [����]�����Թ���ʱ������ƽ��
	//lightAttenuation_temp += (FrontLight < -0.9) ? (min((LightMap > 1 * FrontLight), (LightMap > 1 * -FrontLight))) : 0;

    half lightAttenuation = surfaceData._useFaceLightMap ? lightAttenuation_temp : 1;

    return lightAttenuation;
}

// ���ڳ�ʼ��faceShadowMask������Ϊֱ�ӹ��ա���ӹ��յĳ�������������Ӱ��������ֵ��0~1��0/1֮��⻬���ɣ����������ݣ���
// ***ע��***�����ڷ�����������ֵ��1��
// �汾2
half CustomFaceShade_v2(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight)
//float3 NPR_Function_face (float NdotL,float4 baseColor,float4 parameter,Light light,float Night)
{

    half3 N = lightingData.normalWS;
    half3 L = light.direction;
    half NdotL = dot(N,L);
        
    float3 Right = unity_ObjectToWorld._m00_m10_m20; //����ռ��и�ƬԪ����ɫ�������ҷ�������δ��һ��
    //float3 Up = unity_ObjectToWorld._m01_m11_m21; //...���Ϸ�
    float3 Front = unity_ObjectToWorld._m02_m12_m22; //...��ǰ��

    // ��Ӱ��ͼ���������л��Ŀ���
    float switchShadow  = dot(normalize(Right.xz), normalize(L.xz)) < 0;
    // ��Ӱ��ͼ���������л�
    float FaceShadow = switchShadow > 0 ? surfaceData._faceLightMapR.r : surfaceData._facelightMapL.r;
    //float FaceShadow = lerp(1 - parameter.g,1 - parameter.r,switchShadow.r); //�������ʹ��˫ͨ������ת��Ӱ��ͼ ��Ϊ��Ҫ��ƻ��������Ϊ����
    // ������Ӱ�л�����ֵ
    float FaceShadowRange = dot(normalize(Front.xz), normalize(L.xz));
    float lightAttenuation = 1 - smoothstep(FaceShadowRange - 0.05,FaceShadowRange + 0.05,FaceShadow);
    
    lightAttenuation = surfaceData._useFaceLightMap ? lightAttenuation : 1;
    return lightAttenuation;
    //float3 rampColor = NPR_Base_Ramp(lightAttenuation * light.shadowAttenuation,Night,parameter);//���������������ͼ��Alpha������1
    //return baseColor.rgb * rampColor ;
}
half CustomFaceShade(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight) 
{
    return CustomFaceShade_v1(surfaceData,lightingData, light, isAdditionalLight);
}

// ����ȫ�ֹ��ռ��㣩��ӹ���
half3 ShadeGI(ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    // hide 3D feeling by ignoring all detail SH (leaving only the constant SH term)
    // SH 1 (only use this)
    // SH 234 (ignored)
    // SH 56789 (ignored)
    // we just want some average envi indirect color only
    half3 averageSH = SampleSH(0); 

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
    return surfaceData.albedo * max(indirectLight, _IndirectLightMinColor); //��ֹlightprobeû�б��決��_OcclusionIndirectStrength=1����_IndirectLightMultiplier=0ʱ��ȫ���
}

// Most important part: lighting equation, edit it according to your needs, write whatever you want here, be creative!
// This function will be used by all direct lights (directional/point/spot) 
// �汾1
// TODO��ֻ���������ȱ�ٸ߹ⷴ���Ҳ���Կ�����_Metallic��PBR�ķ�������
half3 ShadeSingleLight_v1(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight)
{
    half3 N = lightingData.normalWS;
    half3 L = light.direction;
    half3 V = lightingData.viewDirectionWS;
    half3 H = normalize(L+V);

    half NoL = dot(N,L);
    half NoH = dot(N,H);

    half lightAttenuation = 1; //δʹ��

    // light's distance & angle fade for point light & spot light (see GetAdditionalPerObjectLight(...) in Lighting.hlsl)
    // Lighting.hlsl -> https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
    half distanceAttenuation = min(4,light.distanceAttenuation); //clamp to prevent light over bright if point/spot light too close to vertex

    // simplest 1 line cel shade, you can always replace this line by your own method! | ��򵥵�1���߽��ߵİ���������+����+ʹ��smoothstep��͹��ɣ�
    // litOrShadowArea�ķ�ΧΪ[0,1]
    half litOrShadowArea = smoothstep(_CelShadeMidPoint-_CelShadeSoftness,_CelShadeMidPoint+_CelShadeSoftness, NoL); //Ŀǰ����������_CelShadeSoftness=0.5���Դﵽ�ǳ�ƽ���Ĺ���

    // occlusion
    // ʹ��_OcclusionDirectStrength��ֱ�ӹ����п����ڵ��ĳ̶�
    litOrShadowArea *= lerp(1, surfaceData.occlusion, _OcclusionDirectStrength);

    // face ignore celshade since it is usually very ugly using NoL method
    // �沿ֱ��ʹ��litOrShadowArea�Ƚ��ѿ�������ʹ��lerp��һ����[0,1]��[0.5,1]������ӳ�䣬�൱������������һЩ����ʱ������litOrShadowArea�ķ�ΧΪ[0.5,1]
    litOrShadowArea = _IsFace ? lerp(0.5,1,litOrShadowArea) : litOrShadowArea;

    // light's shadow map | ���յ�shadow map��Ҳ������Ӱ˥����ʹ��_ReceiveShadowMappingAmount����Ӧ����Ӱ˥���ĳ̶�
    // shadowAttenuationֵ�ķ�ΧΪ[0,1]
    litOrShadowArea *= lerp(1,light.shadowAttenuation,_ReceiveShadowMappingAmount);

    half3 litOrShadowColor = lerp(_ShadowMapColor,1, litOrShadowArea); // ������Ӱ����ɫ
    
    // distanceAttenuationֵ�ķ�ΧΪ[0,1]
    half3 lightAttenuationRGB = litOrShadowColor * distanceAttenuation; // �١�����˥����������˥����

    // ����Ramp��ͼ
    half3 rampColor = (1, 1, 1);
    #if ENABLE_RAMP_SHADOW
        rampColor = NPR_Ramp(NoL, _InNight, surfaceData._lightMap);
        rampColor = lerp(1, rampColor, _AlbedoMulByRampColor); //����albedo��ɫ����ramp��ɫ�ĳ̶�
    #endif
    
    half3 diffuse = surfaceData.albedo * rampColor * saturate(light.color) * lightAttenuationRGB * (isAdditionalLight ? 0.25 : 1);
    diffuse *= _UseLightMap ? (1 - surfaceData._lightMap.r) : 1; //��lightmapʱ�����ǵ�Blinn-Phong�����غ㣬������Խǿ�ĵط�diffuseԽ��

    half3 specular = _UseLightMap ? surfaceData.albedo * saturate(light.color) * NPR_Specular(NoH, surfaceData._lightMap): 0; //û��lightmapʱ �߹���=0 //��Ҫ��light��color������ʹ���ߺܰ�Ҳ�и߹⣬������ //Ŀǰ����rampColor

    // TODO
    half3 hairAdditionalSpecular = 0;
    //half3 hairAdditionalSpecular = _UseLightMap ? surfaceData.albedo * saturate(light.color) * NPR_Hair_Additional_Specular(N, NoL, surfaceData._lightMap) : 0; //��lightmap����_IsFace���ڸú������жϣ�ʱ���ż���ͷ���Ķ���߹⣬����=0

    half3 metalSpecular = _UseLightMap ? surfaceData.albedo * saturate(light.color) * NPR_MetalSpecular(N, surfaceData._lightMap) : 0;  //û��lightmapʱ �����߹���=0 //��Ҫ��light��color������ʹ���ߺܰ�Ҳ�н����߹⣬������ //Ŀǰ����rampColor

    half3 finalColor = diffuse + specular + hairAdditionalSpecular + metalSpecular;

    //half4 finalColor_and_litOrShadowArea = (finalColor, 1);

    //return finalColor_and_litOrShadowArea; //��litOrShadowArea����Χ[0,1]���浽alphaͨ����

    return finalColor;
}

// Most important part: lighting equation, edit it according to your needs, write whatever you want here, be creative!
// This function will be used by all direct lights (directional/point/spot) 
// �汾2
// TODO��ֻ���������ȱ�ٸ߹ⷴ���Ҳ���Կ�����_Metallic��PBR�ķ�������
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

    // light's shadow map | ���յ�shadow map��Ҳ������Ӱ˥����ʹ��_ReceiveShadowMappingAmount����Ӧ����Ӱ˥���ĳ̶�
    // shadowAttenuationֵ�ķ�ΧΪ[0,1]
    lightAttenuation *= lerp(1,light.shadowAttenuation,_ReceiveShadowMappingAmount);

    // light's distance & angle fade for point light & spot light (see GetAdditionalPerObjectLight(...) in Lighting.hlsl)
    // Lighting.hlsl -> https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
    half distanceAttenuation = min(4,light.distanceAttenuation); //clamp to prevent light over bright if point/spot light too close to vertex

    lightAttenuation *= distanceAttenuation; // distanceAttenuationֵ�ķ�ΧΪ[0,1]

    // N dot L
    // simplest 1 line cel shade, you can always replace this line by your own method! | ��򵥵�1���߽��ߵİ���������+����+ʹ��smoothstep��͹��ɣ�
    // cellitOrShadowArea�ķ�ΧΪ[0,1]
    half celLitOrShadowArea = smoothstep(_CelShadeMidPoint-_CelShadeSoftness,_CelShadeMidPoint+_CelShadeSoftness, NoL);

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
    
    // ����Ramp��ͼ
    half3 rampColor = (1, 1, 1);
    #if ENABLE_RAMP_SHADOW
        rampColor = NPR_Ramp(NoL, _InNight, surfaceData._lightMap);
    #endif

    return surfaceData.albedo * rampColor * light.color * lightAttenuation; 

    // ***��ע�⡿��Ҫ�����CompositeAllLightResults��Luminance���ƹ���ʹ�ã�����������Ӱ���Ǻܺڵģ�������
}
half3 ShadeSingleLight(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight)
{
    return ShadeSingleLight_v1(surfaceData, lightingData, light, isAdditionalLight);
}

// ��Ҫ��������Ramp Map����ʱû��
//half3 CalculateRamp(half halfLambert){}

///////////////////////////////////////////////////////////////////////////////////////
// ��Ե����㺯��
///////////////////////////////////////////////////////////////////////////////////////

// https://zhuanlan.zhihu.com/p/435005339
// �о�Ч����ԭ����ࡣ����
//float3 NPR_Base_RimLight(float NdotV,float halfLambert,float3 baseColor)
//{
//    //return (1 - smoothstep(_RimRadius,_RimRadius + 0.03,NdotV)) * _RimIntensity * (1 - halfLambert) * baseColor;
//    return (1 - smoothstep(_RimMin,_RimMin + 0.03, NdotV)) * _RimIntensity * (1 - halfLambert) * baseColor; //����_RimMax=_rimMin+0.03
//}

// ��������Ե�� https://zhuanlan.zhihu.com/p/95986273
//float3 Fresnel_schlick(float VoN, float3 rF0) {
//		return rF0 + (1 - rF0) * pow(1 - VoN, 5);
//	}
//float3 Fresnel_extend(float VoN, float3 rF0) {
//	return rF0 + (1 - rF0) * pow(1 - VoN, 3);
//}
//float3 Fresnel_RimLight(float NdotV,float VdotL,float3 baseColor) {
//    half3 fresnel = Fresnel_extend(NdotV, float3(0.1, 0.1, 0.1));
//    //half3 fresnelResult = _FresnelEff * fresnel * (1 - VoL) / 2;
//    half3 fresnelResult = _RimIntensity * fresnel * (1 - VdotL) / 2 * baseColor.rgb;
//    return fresnelResult;
//}

//��JTRP��������Ե�� ������
/*
����Ӧ����ʹ��dot(N, L)�����Ե�⣬Ȼ���и�RimLightMask��ͼ
*/

// =======================================================================================================
//��JTRP����Ļ�ռ���ȱ�Ե�� Screen Space Depth Rimlight https://zhuanlan.zhihu.com/p/139290492
float GetScaleWithHight()
{
    /*
    float4 _ScreenParams	
    x is the width of the camera��s target texture in pixels, 
    y is the height of the camera��s target texture in pixels, 
    z is 1.0 + 1.0/width and w is 1.0 + 1.0/height.
    */
	return _ScreenParams.y / 1080;
}
/*
float3 GetCameraRelativePositionWS(float3 _WorldSpaceCameraPos)
{
    ��HDRP��URP�����ú�����
    �����������������Ⱦ��Camera-relative rendering�������� float3(0, 0, 0)��
    �����������������Ⱦ�����ش����λ�ã������κ��޸ġ�
}
*/
float LoadCameraDepth(uint2 pixelCoords)
{
    /*
    ��HDRP�����ú�����
    */
    //LOAD_TEXTURE2D_X_LOD��com.unity.render-pipelines.core�����ú���
    return LOAD_TEXTURE2D_X_LOD(_CameraDepthTexture, pixelCoords, 0).r;
}
// ASE
float3 InvertDepthDirHD(float3 In)
{
	float3 result = In;
	#if !defined(ASE_SRP_VERSION) || ASE_SRP_VERSION <= 70301 || ASE_SRP_VERSION == 70503 || ASE_SRP_VERSION >= 80301
		result *= float3(1, 1, -1);
	#endif
	return result;
}
//float4x4 unity_CameraProjection;
//float4x4 unity_CameraInvProjection;
//float4x4 unity_WorldToCamera;
//float4x4 unity_CameraToWorld;
// ASE
float3 GetWorldPosFromDepthBuffer(float2 clipPos01, float cameraDepth)
{
	#ifdef UNITY_REVERSED_Z
		float depth = (1.0 - cameraDepth);
	#else
		float depth = cameraDepth;
	#endif
	float3 screenPos_DepthBuffer = (float3(clipPos01, depth));
	float4 clipPos = (float4((screenPos_DepthBuffer * 2.0 - 1.0), 1.0));
	float4 viewPos = mul(unity_CameraInvProjection, clipPos);
	float3 viewPosNorm = viewPos.xyz / viewPos.w;
	float3 localInvertDepthDirHD = InvertDepthDirHD(viewPosNorm);
	
	return mul(unity_CameraToWorld, float4(localInvertDepthDirHD, 1.0)).xyz;
}
float3 GetSSRimLight(float3 color, ToonLightingData lightingData, float3 lightDirWS, half shadowValue)
{
    UNITY_BRANCH //���������֮ǰ��Ӵ˺꣬��֪������Ӧ�������Ϊʵ�ʷ�֧���� HLSL ƽ̨����չΪ [branch]��
    if (!_EnableSSRim) return 0;

    float2 uv = lightingData.uv;
    float3 normalDirWS = lightingData.normalWS;

    half4 mask = tex2D(_SSRimMask, uv);
    half widthRamp = 1; // TODO
	//half widthRamp = SampleRampSignalLine(_SSRimWidthRamp, distance(posInput.positionWS, GetCameraRelativePositionWS(_WorldSpaceCameraPos)) / _SSRimRampMaxDistance).r;

    float2 L_VS = normalize(mul((float3x3)UNITY_MATRIX_V, lightDirWS).xy) * (_SSRimInvertLightDir ? -1 : 1); //��ת
    float2 N_VS = normalize(mul((float3x3)UNITY_MATRIX_V, normalDirWS).xy);
    float NdotL = saturate(dot(N_VS, L_VS) + _SSRimLength); //_SSRimLength���������յı�Ե����������
    float scale = mask.r * widthRamp * NdotL * _SSRimWidth * GetScaleWithHight(); //_SSRimWidth��ʵ�ǿ��ƿ���ƫ�ƾ���ģ��Ӿ�Ч��Լ���ڿ���rimLight���
    // ԭ��ȡ��Ļ�ռ䵱ǰ��������UV����N_VS����ƫ�ƺ������ȣ��뵱ǰ������Ƚ��бȽϣ���Ȳ����ĳһ��ֵ��Ϊ��Ե��
    float2 ssUV1 = clamp(lightingData.positionSS + N_VS * scale, 0, _ScreenParams.xy - 1); //scale����ƫ�ƾ���
    float viewDepth = distance(lightingData.positionWS, GetCameraRelativePositionWS(_WorldSpaceCameraPos));

    float3 sceneWorldPos = GetWorldPosFromDepthBuffer(ssUV1 * _ScreenSize.zw, LoadCameraDepth(ssUV1));
	float sceneViewDepth = distance(GetCameraRelativePositionWS(sceneWorldPos), GetCameraRelativePositionWS(_WorldSpaceCameraPos));

	float intensity = smoothstep(viewDepth, viewDepth + _SSRimFeather, sceneViewDepth); //ǿ��=0~1���𻯣���Ȳ����ֵ����_SSRimFeather��Χ=0~2��ԽС��Խǿ //��ע�⡿������smoothstepƽ�����ɣ����ܵ��·Ǳ�ԵҲ�����
	intensity *= mask.a * lerp(1, _SSRimInShadow, shadowValue) * _SSRimIntensity; //mask //����Ӱ�м�����Ե��
	
	return _SSRimColor * intensity * lerp(1, color, _SSRimColor.a); //��Ե��ֱ�Ӽ���ԭcolor�� //Aͨ��ָʾ���diffuse��ɫ�ĳ̶ȣ�=0ʱ��...��
}
//��JTRP����Ļ�ռ���ȱ�Ե�� Screen Space Depth Rimlight
// =======================================================================================================

// ԭ��
half3 ShadeEmission_v1(ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    half3 emissionResult = lerp(surfaceData.emission, surfaceData.emission * surfaceData.albedo, _EmissionMulByBaseColor); // optional mul albedo // �����Է�����ɫ����albedo��ɫ��Base��ɫ���ĳ̶�
    return emissionResult;
}
// �Ľ���
half3 ShadeEmission_v2(ToonSurfaceData surfaceData, ToonLightingData lightingData, bool isAdditionalLight)
{
    // ���û������Emission����surfaceData.emission = 0
    // ��2��Emission��ԭ��ʽ�ͷ�ԭ��ʽ����GetFinalEmissionColor()����
    half3 emissionResult = surfaceData.emission;
    emissionResult = _isGenshinEmission ? emissionResult : lerp(emissionResult, emissionResult * surfaceData.albedo, _EmissionMulByBaseColor); // ��ԭ��ʽ�������Է�����ɫ����albedo��ɫ��Base��ɫ���ĳ̶�

    return emissionResult;
}
half3 ShadeEmission(ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    return ShadeEmission_v2(surfaceData, lightingData, false); 
}

// ��ͨ�ı�Ե��
half3 ShadeRimLight(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight)
{
	UNITY_BRANCH
	if (!_UseRimLight) return 0;

    half3 N = lightingData.normalWS;
    half3 V = lightingData.viewDirectionWS;
	half3 L = light.direction;

    half NdotL = dot(N, L);
    half NdotV = dot(N, V);
    //half VdotL = dot(V, L);
    half halfLambert = NdotL * 0.5 + 0.5;
    
	half useRimLight = surfaceData._useRimLight;
	half4 rimColor = surfaceData._rimColor;
	half3 rimMin = surfaceData._rimMin;
	half3 rimMax = surfaceData._rimMax;
	half3 rimSmooth = surfaceData._rimSmooth;
    half rimIntensity = surfaceData._rimIntensity;

    //half3 ramp = CalculateRamp(halfLambert);
    //ramp *= CustomFaceShade(surfaceData, lightingData, lightingData, isAdditionalLight); //ĿǰisAdditionalLight����false������û���� // CustomFaceShade���ڳ�ʼ��lightAttenuation����faceShadowMask������ֵ��0��1

	// initialize rimMask if not using custom rim light lightmask;
    //half3 rimMask = half3(1, 1, 1);
    // if use custom rim light lightmask;
    half3 rimMask = surfaceData._rimMask; // _rimMask�Ǹ�half
    half3 rimMaskStrength = surfaceData._rimMaskStrength;

    // ����һ��rimLight������ʹ��NdotV + �������أ�NdotL��
    half ndv =  1 - max(0, NdotV);
    half rim = smoothstep(rimMin, rimMax, ndv) * (1 - halfLambert); //���Ʊ߹�ķ�Χ //����ϣ�������ı�Ե�����������ʹ�ð������أ�NdotV������
    //�����⣬̫����
    //if (useRimLight == 1)
    //{
    //    rim = lerp(rimMin, rimMax, ndv);
    //}
    rim = smoothstep(0, rimSmooth, rim); //���Ʊ߹����Ӳ��ʵ��Ч�����У���_RimSmooth=1ʱ��smoothstep(0, 1, rim)��rim��_RimSmooth=0ʱ��smoothstep(0, 0, rim)=1��
    half3 rimLight = rim * lerp(1, rimMask.rgb, rimMaskStrength) * rimIntensity * rimColor.rgb; //���Ʊ�Ե������֡�ǿ�ȡ���ɫ

    //// ��������
    //half3 rimLight = NPR_Base_RimLight(NdotV, halfLambert, rimColor.rgb);
    
    //// ����������������Ե��
    //half3 rimLight = Fresnel_RimLight(NdotV, VdotL, rimColor.rgb);
    
    rimLight = lerp(rimLight, rimLight * surfaceData.albedo, _RimMulByBaseColor); // ���Ʊ�Ե����ɫ����albedo��ɫ��Base��ɫ���ĳ̶�

    return rimLight;
}

// ԭ��
half3 CompositeAllLightResultsDefault(half3 indirectResult, half3 mainLightResult, half3 additionalLightSumResult, half3 emissionResult, ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    // ֻ��һ�����ڼ򵥵�ʵ�֡�
    // [remember you can write anything here, this is just a simple tutorial method]
    // here we prevent light over bright,
    // while still want to preserve light color's hue

    half3 indirectDirectLightSum  = max(indirectResult, mainLightResult + additionalLightSumResult); // pick the highest between indirect and direct light  
    // ȡmax(��ӹ��ս�� �� ����Դ���ս��+�����Դ���ս��)��Ҳ����˵���ǹ�Դ�ܰ��������ӹ��յļ�������ʵ���ӵ��ˣ����Ƿ��е㡣����������                                                        

    return surfaceData.albedo * indirectDirectLightSum  + emissionResult; // ���������ɫ��ʱ����ˡ��Է������û�г�albedo
}
// �Ľ���
half3 CompositeAllLightResults(half3 indirectResult, half3 mainLightResult, half3 additionalLightSumResult, half3 emissionResult, half3 rimlightResult, half3 faceShadowMask, ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, half shadowValue)
{
    // Legacy method;
	/*half3 shadowColor = lerp(2*surfaceData._shadowColor, 1, faceShadowMask);
	half3 result = indirectResult*shadowColor + mainLightResult + additionalLightSumResult + emissionResult;
    return result;*/

    // ������������[��ӹ��ղ��ֵ�]��sdf��ͼ�γɵ���Ӱ // ***ע��***��������faceShadowMask = (1,1,1)��
    // faceShadowMaskֻ��2�ַ���ֵ��0=(0,0,0)��1=(1,1,1)����ʱʹ��lerp�����һ�ֶԱ���ʹ��if���ļ��ɡ�
    half3 shadowColor = lerp(surfaceData._shadowColor, 1, faceShadowMask);

    // ��ӹ��ս�� * shadowColor ������Ӱ������ֱ�ӹ��յİ�����������
    half3 indirectDirectLightSum = indirectResult * shadowColor + mainLightResult + additionalLightSumResult;  // ���+ֱ�� //TODO:�о�������Ӱ���ǲ�̫��

    //һ�ִ���:
    //half lightLuminance = Luminance(indirectDirectLightSum );
    //half3 finalLightMulResult = indirectDirectLightSum  / max(1,lightLuminance / max(1,log(lightLuminance))); // allow controlled over bright using log
    //return surfaceData.albedo * finalLightMulResult + emissionResult;
    
    // Screen Space rimLight | SS��Ե��
    // TODO���Ľ�lightDirWS
    half3 lightDirWS = -light.direction; // light.direction = _MainLightPosition.xyz; (mainLight)
    // TODO���Ľ�shadowValue 0��ʾ��ȫ������Ӱ�У�1��ʾ��ȫ����Ӱ��
    half3 SSRimLight = GetSSRimLight(indirectDirectLightSum, lightingData, lightDirWS, shadowValue);
    //half3 SSRimLight = GetSSRimLight(surfaceData.albedo, lightingData, lightDirWS, shadowValue);
    
    half3 finalColor = indirectDirectLightSum + emissionResult + rimlightResult + SSRimLight;

    return finalColor;
}

half3 ShadeFaceShadow(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light)
{
	return CustomFaceShade(surfaceData, lightingData, light, false); //���isAdditionalLight��= false��û����
}
#endif