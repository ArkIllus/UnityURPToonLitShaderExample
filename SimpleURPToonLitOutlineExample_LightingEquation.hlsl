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
// �ο���Samlee
// TODO: [ͷ��]lightMap��Rͨ��û����
// TODO: ����Ϊ��Ϸ���һ/������Ӱ��
half3 NPR_Specular(float3 NdotH, float4 lightMap)
{
    // ���ﲻ��albedoColor����ShadeSingleLight���������saturate(light.color)����ShadeSingleLight�����Ŀǰ����rampColor

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

    float3 SpecularColor = lightMap.g; //�൱�ڸ�����ĸ߹�ǿ��

    float SpecularRadius = _IsHair ? pow(max(0, NdotH), lightMap.a * 50) : pow(max(0, NdotH), lightMap.r * 50); // TODO: Ҫ��Ҫ����50�������
    // ��������������(�·�)��ʹ�ý�����ͨ����Ϊָ������ܺ���
    // ����ͷ����ʹ��ͷ�����������򣨰�ɫ=ͷ����ͨ����Ϊָ�����������
    
    //return smoothstep(0.3, 0.5, SpecularRadius) * SpecularColor * lightMap.g; //ƫNPR

    // Samlee:
    return _IsHair ? smoothstep(0.3, 0.5, SpecularRadius) * SpecularColor * lerp(_HairSpecularStrength, 1, step(0.9, lightMap.g)) : //����ͷ����ʹ��һ���������������߹�ǿ��
                     smoothstep(0.3, 0.5, SpecularRadius) * SpecularColor * lightMap.g; //0.3, 0.5 ƫNPR

    // ������smoothstep ���ø߹���ӵĶ�ֵ����0-1��/���贻�/��ͨ����
    // �������smoothstep��smoothstep(0, 1, x)��ô������Ȼ��ʵ��ƽ������
    // ��lightMap.g��ƽ�����߹���lightMap.g����
    // e.g.: [����(�·�)]����
    // return smoothstep(0.3, 0.4, SpecularRadius) * SpecularColor * lightMap.g; //ƫNPR
    // return smoothstep(0.3, 0.5, SpecularRadius) * SpecularColor * lightMap.g; //ƫNPR
    // return smoothstep(0, 1, SpecularRadius) * SpecularColor * lightMap.g; //ƫPBR
}

// ͷ���������NPR_Specular������Ҫ����ĸ߹⣨��Ϊ[ͷ��]lightMap��Gͨ����󲿷�ͷ�������Ǵ��ڵģ��ⲿ����NPR_Specular��û�и߹⣩ // �������_IsHair������0
// �ο������� ���Ч���Ƕ���ĸ߹⼯�����м䣬�����ǰ��ģ��Ҿ��÷ǳ�����ѧ
half3 NPR_Hair_Additional_Specular_v1(float3 normalWS, float3 NdotL, float4 lightMap)
{
    float HariSpecRadius = 0.25;//����ͷ���ķ��䷶Χ
    float3 normalVS = normalize(mul(UNITY_MATRIX_V,normalWS));
    float HariSpecDir = normalVS * 0.5 + 0.5; // ӳ�䵽[0, 1] ������
    float3 HariSpecular = smoothstep(HariSpecRadius, HariSpecRadius + 0.1, 1 - HariSpecDir) 
                        * smoothstep(HariSpecRadius, HariSpecRadius + 0.1, HariSpecDir) * NdotL; // ����������
    return _IsHair ? HariSpecular * _HairSpecularStrength * lightMap.b * step(lightMap.r, 0.1) * 1.0 : 0; //Bͨ��ָʾͷ������Ӱ���򲻸��и߹� //step(lightMap.r, 0.1)��[ͷ��]lightMap��Rͨ��<0.1Ϊͷ�����򣬼��ų�[ͷ��]lightMap�е���������
}

//TODO: �Ľ�������normalVS����������ͼ
//half3 NPR_Hair_Additional_Specular()
//{
//    return 0;
//}

// ԭ��ʽ�����߹� Glossiness
// �ο���Samlee
// TODO: �Ľ�������normalVS����������ͼ
half3 NPR_MetalSpecular(float3 normalWS, float4 lightMap)
{
    // ���ﲻ��albedoColor����ShadeSingleLight���������saturate(light.color)����ShadeSingleLight�����Ŀǰ����rampColor

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
    
    float MetalMap = tex2D(_MetalMap, normalVS * 0.5 + 0.5) * 2;  //ʹ��normalVS����������ͼ Ϊɶ�أ�8̫���� //���Ч���ǽ����߹⼯�����м䣬�����ǰ��ģ��ǲ����е㲻��ѧ��
    
    //return step(0.95, MetalMap) * lightMap.r; // �����Ļ�ֻ�н�������ǿ���ǲ����н����߹�
    half3 metalSpecular = MetalMap * lightMap.r * _MetalColor;
    metalSpecular *= _IsHair ? step(0.1, lightMap.r) : 1; //step(lightMap.r, 0.1)��[ͷ��]lightMap��Rͨ��<0.1Ϊͷ�����򣬼��ų�[ͷ��]lightMap�е�ͷ����������Ҫ����Ϊ�н����߹⼯����ͷ���м䲻�ÿ�������ѧ��
    return metalSpecular;
}

// ����ԭ��ʽRamp��ͼ
// �ο���Samplee������
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

// ���ڳ�ʼ��faceShadowMask������Ϊֱ�ӹ��ա���ӹ��յĳ�������������Ӱ��������ֵ��0��1��
// ***ע��***�����ڷ�����������ֵ��1��
// �汾1���ο�Noirc
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

    // ��Ӱ�����޸���ʵ�ָ�ƽ���Ĺ��� -> https://zhuanlan.zhihu.com/p/279334552;  // ��
    // Light�ӽ�ɫǰ������ʱ��RightLight��[0,pi]ӳ�䵽[-1,1]
    // Light�ӽ�ɫ��������ʱ��RightLight��[pi,2pi]ӳ�䵽[1,-1]
    RightLight = -(acos(RightLight) / 3.14159265 - 0.5) * 2;

    // ʹ��sdf��ͼ��Rͨ��ֵ
    // �� RightLight > 0ʱ������Ұ������䣻�� RightLight <= 0ʱ�������������� [ע������������Ƕ��ڽ�ɫ������Ե�]
    float LightMap = RightLight > 0 ? surfaceData._faceLightMapR.r : surfaceData._facelightMapL.r;

    // dirThreshold�������Ź������䷽��ı仯��������Ӱ�������ٶȣ�
    // ֵԽ��=�泯�ƹ�ʱ��Ӱ����Խ�죬������ƹ�ʱ��Ӱ����Խ����ֵԽ��=�෴�� // ��
    // TODO:Ҫ��Ҫ������￪�����������
    float dirThreshold = 0.1;

    // ���Light�ӽ�ɫǰ������ʱ����ʹ��RightLight�����dirThreshold��
    // ���Light�ӽ�ɫ��������ʱ����ʹ��FrontLight����ͣ�1-dirThreshold������Ӧ��ƽ��...   // ��������������������
    // ...��ȷ��180��ʱ��ƽ�����ɣ�����ǰ��һ���ƹⷽ��==0����
    float lightAttenuation_temp = (FrontLight > 0) ? 
        min((LightMap > dirThreshold * RightLight), (LightMap > dirThreshold * -RightLight)) : //���ͣ�����Ұ�������ʱ��RightLight<0�������൱��LightMap > dirThreshold * -RightLight��
                                                                                               //������������ʱ��RightLight>0�������൱��LightMap > dirThreshold * RightLight����ʵ������min�滻if���
        min((LightMap > (1 - dirThreshold * 2) * FrontLight - dirThreshold), (LightMap > (1 - dirThreshold * 2) * -FrontLight + dirThreshold));

    // �Ľ�����smoothstep��[0,1]֮��ƽ�������Ա����沿��Ӱ�ֽ��ߵľ��(Ȼ��Ч�����á�����)
    // TODO�������
    //float lightAttenuation_temp = (FrontLight > 0) ? 
    //    min(smoothstep(dirThreshold * RightLight - _FaceShadowRangeSmooth, dirThreshold * RightLight + _FaceShadowRangeSmooth, LightMap), 
    //        smoothstep(dirThreshold * -RightLight - _FaceShadowRangeSmooth, dirThreshold * -RightLight + _FaceShadowRangeSmooth, LightMap)) : // Light�ӽ�ɫǰ������ʱ��RightLight��[0,pi]ӳ�䵽[-1,1]
    //    min(smoothstep( (1 - dirThreshold * 2) * FrontLight - dirThreshold - _FaceShadowRangeSmooth, (1 - dirThreshold * 2) * FrontLight - dirThreshold + _FaceShadowRangeSmooth, LightMap), 
    //        smoothstep( (1 - dirThreshold * 2) * -FrontLight + dirThreshold - _FaceShadowRangeSmooth, (1 - dirThreshold * 2) * -FrontLight + dirThreshold + _FaceShadowRangeSmooth, LightMap));
     
    // [����]�����Թ���ʱ������ƽ�ƣ�
	//lightAttenuation_temp += (FrontLight < -0.9) ? (min((LightMap > 1 * FrontLight), (LightMap > 1 * -FrontLight))) : 0;

    // û��Ramp, Night������˵Ramp=1

    half lightAttenuation = surfaceData._useFaceLightMap ? lightAttenuation_temp : 1;

    return lightAttenuation;
}

// ���ڳ�ʼ��faceShadowMask������Ϊֱ�ӹ��ա���ӹ��յĳ�������������Ӱ��������ֵ��0~1��0/1֮��⻬���ɣ����������ݣ���
// ***ע��***�����ڷ�����������ֵ��1��
// �汾2���ο����� (�����е�����)
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
    return surfaceData.albedo * max(indirectLight, _IndirectLightMinColor); //��ֹlightprobeû�б��決��_OcclusionIndirectStrength=1����_IndirectLightMultiplier=0ʱ��ȫ���
}

// Most important part: lighting equation, edit it according to your needs, write whatever you want here, be creative!
// This function will be used by all direct lights (directional/point/spot) 
// �汾1�ο���Colin
// | ����Ҫ�ĺ�������������ᱻ�������͵Ĺ�Դʹ�ã�ƽ�й�/���Դ/�۹�ƣ�������Դ + �����Դ��
// TODO���ƺ�ֻ���������ȱ�ٸ߹ⷴ���Ҳ���Կ�����_Metallic��PBR�ķ�������
half3 ShadeSingleLight_v1(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight)
{
    half3 N = lightingData.normalWS;
    half3 L = light.direction;
    half3 V = lightingData.viewDirectionWS;
    half3 H = normalize(L+V);

    half NoL = dot(N,L);
    half NoH = dot(N,H);

    half lightAttenuation = 1; //����û�ð�
    // �ο�Noirc:
	// Replace original initialization of lightAttenuation with custom face shading result;
    //half lightAttenuation = CustomFaceShade(surfaceData, lightingData, light, isAdditionalLight);
     //��ʵ������faceShadowMask����lightAttenuation���������Ч����������Ӱ����ȫ����˰�������

    // light's distance & angle fade for point light & spot light (see GetAdditionalPerObjectLight(...) in Lighting.hlsl)
    // | ���Դ�;۹�ƵĹ��յľ���&�Ƕ�˥������μ�Lighting.hlsl�е�GetAdditionalPerObjectLight(...)��
    // Lighting.hlsl -> https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
    half distanceAttenuation = min(4,light.distanceAttenuation); //clamp to prevent light over bright if point/spot light too close to vertex 
                                                                 // | ������Դ/�۹���붥��̫������ȡ����=4�Է�ֹ���߹���

    // simplest 1 line cel shade, you can always replace this line by your own method! | ��򵥵�1���߽��ߵİ���������+����+ʹ��smoothstep��͹��ɣ�
    // litOrShadowArea�ķ�ΧΪ[0,1]
    half litOrShadowArea = smoothstep(_CelShadeMidPoint-_CelShadeSoftness,_CelShadeMidPoint+_CelShadeSoftness, NoL); //smoothstep��������0��1��ƽ������ //Ŀǰ����������_CelShadeSoftness=0.5���Դﵽ�ǳ�ƽ���Ĺ���

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
    half3 lightAttenuationRGB = litOrShadowColor * distanceAttenuation; // �١�����˥����������˥����
    //half3 lightAttenuationRGB = litOrShadowColor * distanceAttenuation * lightAttenuation;// lightAttenuation = 1 ûɶ�ð�

    // ����Ramp��ͼ
    half3 rampColor = (1, 1, 1);
    #if ENABLE_RAMP_SHADOW
        rampColor = NPR_Ramp(NoL, _InNight, surfaceData._lightMap);
        rampColor = lerp(1, rampColor, _AlbedoMulByRampColor); //����albedo��ɫ����ramp��ɫ�ĳ̶�
    #endif

    // saturate() light.color to prevent over bright | saturate(light.color)��ֹ����������Դ��intensity��Ϊ����1ʱ��light.color�ķ�Χ�ͳ���1�ˣ�
    // additional light reduce intensity since it is additive | ���ڶ����Դ�Ĺ��0.25��������һЩ������Ϊɶ����������о�����û�仯����Ϊû�ж����Դ��
    //return surfaceData.albedo * rampColor * saturate(light.color) * lightAttenuationRGB * (isAdditionalLight ? 0.25 : 1);
    
    half3 diffuse = surfaceData.albedo * rampColor * saturate(light.color) * lightAttenuationRGB * (isAdditionalLight ? 0.25 : 1);
    diffuse *= _UseLightMap ? (1 - surfaceData._lightMap.r) : 1; //��lightmapʱ�����ǵ�Blinn-Phong�����غ㣬������Խǿ�ĵط�diffuseԽ��

    half3 specular = _UseLightMap ? surfaceData.albedo * saturate(light.color) * NPR_Specular(NoH, surfaceData._lightMap): 0; //û��lightmapʱ �߹���=0 //��Ҫ��light��color������ʹ���ߺܰ�Ҳ�и߹⣬������ //Ŀǰ����rampColor

    // TODO
    half3 hairAdditionalSpecular = 0;
    //half3 hairAdditionalSpecular = _UseLightMap ? surfaceData.albedo * saturate(light.color) * NPR_Hair_Additional_Specular(N, NoL, surfaceData._lightMap) : 0; //��lightmap����_IsFace���ڸú������жϣ�ʱ���ż���ͷ���Ķ���߹⣬����=0

    half3 metalSpecular = _UseLightMap ? surfaceData.albedo * saturate(light.color) * NPR_MetalSpecular(N, surfaceData._lightMap) : 0;  //û��lightmapʱ �����߹���=0 //��Ҫ��light��color������ʹ���ߺܰ�Ҳ�н����߹⣬������ //Ŀǰ����rampColor

    half3 finalColor = diffuse + specular + hairAdditionalSpecular + metalSpecular;

    return finalColor;
}

// Most important part: lighting equation, edit it according to your needs, write whatever you want here, be creative!
// This function will be used by all direct lights (directional/point/spot) 
// �汾2�ο���NoirRC
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
    
    // ����Ramp��ͼ
    half3 rampColor = (1, 1, 1);
    #if ENABLE_RAMP_SHADOW
        rampColor = NPR_Ramp(NoL, _InNight, surfaceData._lightMap);
    #endif

    //half3 litOrShadowColor = lerp(_ShadowMapColor,1, litOrShadowArea); // ������Ӱ����ɫ��ʹ��lerp��һ����[0,1]��[_ShadowMapColor,1]������ӳ�䣬litOrShadowArea=0ʱ��litOrShadowColor=_ShadowMapColor
    //
    // ����ʹ��_ShadowMapColor������Ӱ����ɫ

    // saturate() light.color to prevent over bright | saturate(light.color)��ֹ����������Դ��intensity��Ϊ����1ʱ��light.color�ķ�Χ�ͳ���1�ˣ�
    // additional light reduce intensity since it is additive | ���ڶ����Դ�Ĺ��0.25��������һЩ������Ϊɶ����������о�����û�仯����Ϊû�ж����Դ��
    //return saturate(light.color) * lightAttenuationRGB * (isAdditionalLight ? 0.25 : 1);
    //
    // ����saturate(light.color)��ֹ����������Դ��intensity��Ϊ����1ʱ����������CompositeAllLightResultsʱ���ƹ����������ٶ��ڶ����Դ�Ĺ��0.25������һЩ
    return surfaceData.albedo * rampColor * light.color * lightAttenuation; 

    // ***��ע�⡿ò����Ҫ����� CompositeAllLightResults��Luminance���ƹ��� ʹ�ã�����������Ӱ���Ǻܺڵģ�������
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

// �Գơ���������Ե�⣨���ǣ�������������ˡ������� https://zhuanlan.zhihu.com/p/435005339
// �о�Ч����ԭ����ࡣ����
float3 NPR_Base_RimLight(float NdotV,float halfLambert,float3 baseColor)
{
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
half3 ShadeEmissionAndRim_v1(ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    half3 emissionResult = lerp(surfaceData.emission, surfaceData.emission * surfaceData.albedo, _EmissionMulByBaseColor); // optional mul albedo // �����Է�����ɫ����albedo��ɫ��Base��ɫ���ĳ̶�
    return emissionResult;
}
// �Ľ��棨����rimLight ���鵽����emission��ĺ����
half3 ShadeEmissionAndRim_v2(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight)
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

    // ����һ��rimLight������ʹ��NdotV + �������أ�NdotL��
    half ndv =  1 - max(0, NdotV);
    half rim = smoothstep(rimMin, rimMax, ndv) * (1 - halfLambert); //���Ʊ߹�ķ�Χ //����ϣ�������ı�Ե�����������ʹ�ð������أ�NdotV������
    // ������������Ⱑ��̫����
    //if (useRimLight == 1) // ����RimLight,1,FakeSSS,2������ �� ���Բ�ֵ
    //{
    //    rim = lerp(rimMin, rimMax, ndv);
    //}
    rim = smoothstep(0, rimSmooth, rim); //���Ʊ߹����Ӳ��ʵ��Ч�����У���_RimSmooth=1ʱ��smoothstep(0, 1, rim)��rim��_RimSmooth=0ʱ��smoothstep(0, 0, rim)=1��
    //rimIntensity = 1; // ����������������������������������������������������������������������������������������������������������������������������������������
    half3 rimLight = rim * lerp(1, rimMask.rgb, rimMaskStrength) * rimIntensity * rimColor.rgb; //���Ʊ�Ե������֡�ǿ�ȡ���ɫ

    //// ���������Գơ���������Ե�⣨�������ûɶ���𡣡�����
    //half3 rimLight = NPR_Base_RimLight(NdotV, halfLambert, rimColor.rgb);
    
    //// ���������桤��������Ե�⣨ΪɶûЧ����
    //half3 rimLight = Fresnel_RimLight(NdotV, VdotL, rimColor.rgb);
    
    rimLight = useRimLight ? rimLight : 0;
    rimLight = lerp(rimLight, rimLight * surfaceData.albedo, _RimMulByBaseColor); // ���Ʊ�Ե����ɫ����albedo��ɫ��Base��ɫ���ĳ̶�
    // ====== End of Rim Light ======
    
    // ====== Emission ======
    // ���û������Emission����surfaceData.emission = 0
    // ��2��Emission��ԭ��ʽ�ͷ�ԭ��ʽ����GetFinalEmissionColor()����
    half3 emissionResult = surfaceData.emission;
    emissionResult = _isGenshinEmission ? emissionResult : lerp(emissionResult, emissionResult * surfaceData.albedo, _EmissionMulByBaseColor); // ��ԭ��ʽ�������Է�����ɫ����albedo��ɫ��Base��ɫ���ĳ̶�
    // ====== End of Emission ======

    half3 emissionAndRim = emissionResult + rimLight;
    return emissionAndRim;
}
half3 ShadeEmissionAndRim(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light)
{
    return ShadeEmissionAndRim_v2(surfaceData, lightingData, light, false); 
}

// ԭ��
half3 CompositeAllLightResultsDefault(half3 indirectResult, half3 mainLightResult, half3 additionalLightSumResult, half3 emissionResult, ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    // ֻ��һ�����ڼ򵥵�ʵ�֣��ر���indirectDirectLightSum ��ȡmax�������е����졣
    // [remember you can write anything here, this is just a simple tutorial method]
    // here we prevent light over bright,
    // while still want to preserve light color's hue

    half3 indirectDirectLightSum  = max(indirectResult, mainLightResult + additionalLightSumResult); // pick the highest between indirect and direct light  
                                                                                         // ȡmax(��ӹ��ս�� �� ����Դ���ս��+�����Դ���ս��)��Ҳ����˵���ǹ�Դ�ܰ��������ӹ��յļ�������ʵ���ӵ��ˣ����Ƿ��е㡣����������                                                        
    //half3 indirectDirectLightSum  = indirectResult + mainLightResult + additionalLightSumResult; // ���+ֱ��

    return surfaceData.albedo * indirectDirectLightSum  + emissionResult; // ***ע�����������ɫ��ʱ����ˡ��Է������û�г�albedo���������albedo(Base) Color���������Է�����
}
// �Ľ���
half3 CompositeAllLightResults(half3 indirectResult, half3 mainLightResult, half3 additionalLightSumResult, half3 emissionAndRimResult, half3 faceShadowMask, ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    // Legacy method;
	/*half3 shadowColor = lerp(2*surfaceData._shadowColor, 1, faceShadowMask);
	half3 result = indirectResult*shadowColor + mainLightResult + additionalLightSumResult + emissionResult;
    return result;*/

    // ������������[��ӹ��ղ��ֵ�]��sdf��ͼ�γɵ���Ӱ // ***ע��***��������faceShadowMask = (1,1,1)��
    // faceShadowMaskֻ��2�ַ���ֵ��0=(0,0,0)��1=(1,1,1)����ʱʹ��lerp�����һ�ֶԱ���ʹ��if���ļ��ɣ�
    half3 shadowColor = lerp(surfaceData._shadowColor, 1, faceShadowMask); // faceShadowMask = (1,1,1)��ʾ[��ӹ��ղ��ֵ�]��ȫû����Ӱ��indirectResult��1����=(0,0,0)��ʾ100%������Ӱ��indirectResult��_FaceShadowColor��

    //half3 indirectDirectLightSum  = max(indirectResult * shadowColor, mainLightResult + additionalLightSumResult); // max(��ӣ�ֱ��) 
    // ���ǹ�Դ�ܰ��������ӹ��յļ�������ʵ���ӵ��ˣ����Ƿ��е㡣���������� 
    // ��ӹ��ս�� * shadowColor ������Ӱ����
    // ֱ�ӹ��յİ����أ��������� ����������������  
    
    half3 indirectDirectLightSum  = indirectResult * shadowColor + mainLightResult + additionalLightSumResult;  // ���+ֱ�� //TODO:�о�������Ӱ���ǲ�̫��

    //Noirc�Ĵ���:
    //half lightLuminance = Luminance(indirectDirectLightSum );
    //half3 finalLightMulResult = indirectDirectLightSum  / max(1,lightLuminance / max(1,log(lightLuminance))); // allow controlled over bright using log | ��������ƹ��� ������
    //return surfaceData.albedo * finalLightMulResult + emissionResult;

    return indirectDirectLightSum  + emissionAndRimResult;
}

half3 ShadeFaceShadow(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light)
{
	return CustomFaceShade(surfaceData, lightingData, light, false); //isAdditionalLight = false��Ȼ�����isAdditionalLightû����
}
#endif