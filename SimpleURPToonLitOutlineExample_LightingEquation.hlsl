// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// This file is intented for you to edit and experiment with different lighting equation.
// Add or edit whatever code you want here

// #pragma once is a safe guard best practice in almost every .hlsl (need Unity2020 or up), 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
//#pragma once

// #ifndef XXX + #define XXX + #endif is a safe guard best practice in almost every .hlsl, 
#ifndef SimpleURPToonLitOutlineExample_LightingEquation_Include
#define SimpleURPToonLitOutlineExample_LightingEquation_Include

// 原神式高光 Blinn-Phong Specular
// TODO: [头发]lightMap的R通道没用上
// TODO: （改为游戏里的一/二级阴影）
half3 NPR_Specular(float3 NdotH, float4 lightMap)
{
    // [身体(衣服)]lightMap的通道：
    // R: Glossiness（金属区域）
    // G: Specular（高光区域）
    // B: 阴影权重（固定阴影）
    // A: RampAreaMask

    // [头发]lightMap的通道：
    // R: 头发和配饰区域（白色=配饰 深灰=头发）
    // G: Specular（高光区域）（大部分头发区域都是纯黑的，这部分在NPR_Specular里没有高光，所以在NPR_Hair_Additional_Specular中处理）
    // B: 阴影权重（固定阴影）
    // A: 头发和配饰区域（白色=头发 浅灰=配饰）

    float3 SpecularColor = lightMap.g;

    float SpecularRadius = _IsHair ? pow(max(0, NdotH), lightMap.a * 50) : pow(max(0, NdotH), lightMap.r * 50);
    // 对于身体(衣服)，使用金属性通道作为指数
    // 对于头发，使用头发和配饰区域（白色=头发）通道作为指数，这合理吗？

    return _IsHair ? smoothstep(0.3, 0.5, SpecularRadius) * SpecularColor * lerp(_HairSpecularStrength, 1, step(0.9, lightMap.g)) : //对于头发，使用一个参数额外控制其高光强度
                     smoothstep(0.3, 0.5, SpecularRadius) * SpecularColor * lightMap.g; //0.3, 0.5 偏NPR
    // e.g.: [身体(衣服)]部分
    // return smoothstep(0, 1, SpecularRadius) * SpecularColor * lightMap.g; //偏PBR
}

// 头发区域除了NPR_Specular，还需要额外的高光（因为[头发]lightMap的G通道里大部分头发区域都是纯黑的，这部分在NPR_Specular里没有高光） // 如果不是_IsHair，返回0
// TODO：这个效果是额外的高光集中在中间，两边是暗的，不科学
half3 NPR_Hair_Additional_Specular_v1(float3 normalWS, float3 NdotL, float4 lightMap)
{
    float HariSpecRadius = 0.25; //控制头发的反射范围
    float3 normalVS = normalize(mul(UNITY_MATRIX_V,normalWS));
    float HariSpecDir = normalVS * 0.5 + 0.5; // 映射到[0, 1] 
    float3 HariSpecular = smoothstep(HariSpecRadius, HariSpecRadius + 0.1, 1 - HariSpecDir) 
                        * smoothstep(HariSpecRadius, HariSpecRadius + 0.1, HariSpecDir) * NdotL;
    return _IsHair ? HariSpecular * _HairSpecularStrength * lightMap.b * step(lightMap.r, 0.1) * 1.0 : 0; //B通道指示头发的阴影区域不该有高光 //step(lightMap.r, 0.1)：[头发]lightMap的R通道<0.1为头发区域，即排除[头发]lightMap中的配饰区域
}

//TODO: 改进，不用normalVS采样金属贴图
//half3 NPR_Hair_Additional_Specular()
//{
//    return 0;
//}

// 原神式金属高光 Glossiness
// TODO: 改进，不用normalVS采样金属贴图
half3 NPR_MetalSpecular(float3 normalWS, float4 lightMap)
{
    // [身体(衣服)]lightMap的通道：
    // R: Glossiness（金属区域）
    // G: Specular（高光区域）
    // B: 阴影权重（固定阴影）
    // A: RampAreaMask

    // [头发]lightMap的通道：
    // R: 头发和配饰区域（白色=配饰 深灰=头发）
    // G: Specular（高光区域）
    // B: 阴影权重（固定阴影）
    // A: 头发和配饰区域（白色=头发 浅灰=配饰）

    float3 normalVS = normalize(mul(UNITY_MATRIX_V, normalWS));
    
    float MetalMap = tex2D(_MetalMap, normalVS * 0.5 + 0.5) * 2;  //使用normalVS采样金属贴图
    
    //return step(0.95, MetalMap) * lightMap.r; // 这样的话只有金属性最强的那部分有金属高光
    half3 metalSpecular = MetalMap * lightMap.r * _MetalColor;
    metalSpecular *= _IsHair ? step(0.1, lightMap.r) : 1; //step(lightMap.r, 0.1)：[头发]lightMap的R通道<0.1为头发区域，即排除[头发]lightMap中的头发区域。这主要是因为有金属高光集中在头发中间不好看、不科学。
    return metalSpecular;
}

// 采样原神式Ramp贴图
// TODO: 梯度漫反射效果
half3 NPR_Ramp(half NdotL, half _InNight, float4 lightMap) 
{
    //使用[身体(衣服)]lightMap的A通道：RampAreaMask 作为RampMap采样坐标的y值
    //[头发]如何处理？尽管[头发]A通道和[身体]不同，暂时采用和[身体]一样的处理方式。

    //使用lightMap的B通道：阴影权重（固定阴影）作为halfLambert的乘数

    half halfLambert = smoothstep(0.0, 0.5, NdotL) * (smoothstep(0.0, 0.5, lightMap.b) * 2); // 令NdotL>=0.5的部分=1 //因为lightMap.b的范围在0~0.5，这里把它映射到[0, 1]
    /*
    Skin = 255
    Silk Stokings = 200
    Metal = 160
    Cloth = 113
    Other Hard Stuff = 0
    */
    return _InNight ? tex2D(_RampMap, (halfLambert, lightMap.a * 0.45)).rgb : tex2D(_RampMap, (halfLambert, lightMap.a * 0.45 + 0.55)).rgb; // Ramp贴图的上半部分是白天，下半部分是晚上
}

// 用于初始化faceShadowMask，【作为直接光照、间接光照的乘数产生脸部阴影】，返回值是0或1。***注意***：对于非脸部，返回值是1。
// TODO：抗锯齿
half CustomFaceShade_v1(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight) // isAdditionalLight目前没用上
{
    half3 N = lightingData.normalWS;
    half3 L = light.direction;
    half NoL = dot(N,L);

    // 解释： Unity的模型空间（使用左手坐标系）中，x方向(1, 0, 0)、y方向(0, 1, 0)、z方向(0, 0, 1) 分别对应 模型的正右、上、前方向
    // 现在，求世界空间中模型自身坐标系的xyz方向对应的方向向量 
    // 比如 x方向（正右方）：float3 Right = TransformObjectToWorldDir(float3(1, 0, 0)).xyz;
    // 代入得到 float3 Right = (unity_Object2Wolrd._m00, unity_Object2Wolrd._m10, unity_Object2Wolrd._m20);
    float3 Right = unity_ObjectToWorld._m00_m10_m20; //世界空间中该片元（角色）的正右方向量（未归一）
    //float3 Up = unity_ObjectToWorld._m01_m11_m21; //...正上方
    float3 Front = unity_ObjectToWorld._m02_m12_m22; //...正前方

    // 只取xz分量（正右、前方向，忽略正上方向，相当于从三维向量变成二维xz平面向量）
    float RightLight = dot(normalize(Right.xz), normalize(L.xz));
    float FrontLight = dot(normalize(Front.xz), normalize(L.xz));

    // 阴影覆盖修复可实现更平滑的过渡 -> https://zhuanlan.zhihu.com/p/279334552;
    // Light从角色前面入射时，RightLight从[0,pi]映射到[-1,1]
    // Light从角色后面入射时，RightLight从[pi,2pi]映射到[1,-1]
    RightLight = -(acos(RightLight) / 3.14159265 - 0.5) * 2;

    // 使用sdf贴图的R通道值
    // 当 RightLight > 0时，光从右半脸入射；当 RightLight <= 0时，光从左半脸入射 [注：这里的左右是对于角色自身而言的]
    float LightMap = RightLight > 0 ? surfaceData._faceLightMapR.r : surfaceData._facelightMapL.r;

    // dirThreshold控制随着光线入射方向的变化，脸部阴影滚动的速度；
    // 值越高=面朝灯光时阴影滚动越快，而背向灯光时阴影滚动越慢；值越低=相反；
    float dirThreshold = 0.1;

    // 如果Light从角色前面入射时，请使用RightLight方向和dirThreshold。
    // 如果Light从角色后面入射时，请使用FrontLight方向和（1-dirThreshold）和相应的平移...
    // ...以确保180度时的平滑过渡（其中前归一化灯光方向==0）。
    float lightAttenuation_temp = (FrontLight > 0) ? 
        min((LightMap > dirThreshold * RightLight), (LightMap > dirThreshold * -RightLight)) : //解释：光从右半脸入射时，RightLight<0，所以相当于LightMap > dirThreshold * -RightLight；
                                                                                               //光从左半脸入射时，RightLight>0，所以相当于LightMap > dirThreshold * RightLight。其实就是用min替换if语句
        min((LightMap > (1 - dirThreshold * 2) * FrontLight - dirThreshold), (LightMap > (1 - dirThreshold * 2) * -FrontLight + dirThreshold));

    // 用smoothstep在[0,1]之间平滑过渡以避免面部阴影分界线的锯齿(然而效果不好。。。)
    //float lightAttenuation_temp = (FrontLight > 0) ? 
    //    min(smoothstep(dirThreshold * RightLight - _FaceShadowRangeSmooth, dirThreshold * RightLight + _FaceShadowRangeSmooth, LightMap), 
    //        smoothstep(dirThreshold * -RightLight - _FaceShadowRangeSmooth, dirThreshold * -RightLight + _FaceShadowRangeSmooth, LightMap)) : // Light从角色前面入射时，RightLight从[0,pi]映射到[-1,1]
    //    min(smoothstep( (1 - dirThreshold * 2) * FrontLight - dirThreshold - _FaceShadowRangeSmooth, (1 - dirThreshold * 2) * FrontLight - dirThreshold + _FaceShadowRangeSmooth, LightMap), 
    //        smoothstep( (1 - dirThreshold * 2) * -FrontLight + dirThreshold - _FaceShadowRangeSmooth, (1 - dirThreshold * 2) * -FrontLight + dirThreshold + _FaceShadowRangeSmooth, LightMap));
     
    // [冗余]当背对光线时，补偿平移
	//lightAttenuation_temp += (FrontLight < -0.9) ? (min((LightMap > 1 * FrontLight), (LightMap > 1 * -FrontLight))) : 0;

    half lightAttenuation = surfaceData._useFaceLightMap ? lightAttenuation_temp : 1;

    return lightAttenuation;
}

// 用于初始化faceShadowMask，【作为直接光照、间接光照的乘数产生脸部阴影】，返回值是0~1（0/1之间光滑过渡，尽量避免锯齿）。
// ***注意***：对于非脸部，返回值是1。
// 版本2
half CustomFaceShade_v2(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight)
//float3 NPR_Function_face (float NdotL,float4 baseColor,float4 parameter,Light light,float Night)
{

    half3 N = lightingData.normalWS;
    half3 L = light.direction;
    half NdotL = dot(N,L);
        
    float3 Right = unity_ObjectToWorld._m00_m10_m20; //世界空间中该片元（角色）的正右方向量（未归一）
    //float3 Up = unity_ObjectToWorld._m01_m11_m21; //...正上方
    float3 Front = unity_ObjectToWorld._m02_m12_m22; //...正前方

    // 阴影贴图左右正反切换的开关
    float switchShadow  = dot(normalize(Right.xz), normalize(L.xz)) < 0;
    // 阴影贴图左右正反切换
    float FaceShadow = switchShadow > 0 ? surfaceData._faceLightMapR.r : surfaceData._facelightMapL.r;
    //float FaceShadow = lerp(1 - parameter.g,1 - parameter.r,switchShadow.r); //这里必须使用双通道来反转阴影贴图 因为需要让苹果肌那里为亮的
    // 脸部阴影切换的阈值
    float FaceShadowRange = dot(normalize(Front.xz), normalize(L.xz));
    float lightAttenuation = 1 - smoothstep(FaceShadowRange - 0.05,FaceShadowRange + 0.05,FaceShadow);
    
    lightAttenuation = surfaceData._useFaceLightMap ? lightAttenuation : 1;
    return lightAttenuation;
    //float3 rampColor = NPR_Base_Ramp(lightAttenuation * light.shadowAttenuation,Night,parameter);//这里的脸部参数贴图的Alpha必须是1
    //return baseColor.rgb * rampColor ;
}
half CustomFaceShade(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight) 
{
    return CustomFaceShade_v1(surfaceData,lightingData, light, isAdditionalLight);
}

// （用全局光照计算）间接光照
half3 ShadeGI(ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    // hide 3D feeling by ignoring all detail SH (leaving only the constant SH term)
    // SH 1 (only use this)
    // SH 234 (ignored)
    // SH 56789 (ignored)
    // we just want some average envi indirect color only
    half3 averageSH = SampleSH(0); 

    // can prevent result becomes completely black if lightprobe was not baked | 防止lightprobe没有被烘焙时完全变黑
    //averageSH = max(_IndirectLightMinColor,averageSH);

    // occlusion (to prevent result becomes completely black) 
    // 使用_OcclusionIndirectStrength在间接光照中控制遮挡的程度
    half indirectOcclusion = lerp(1, surfaceData.occlusion, _OcclusionIndirectStrength);
    /* 
    e.g.: 默认 _OcclusionIndirectStrength = 0.5时，indirectOcclusion = (1 + surfaceData.occlusion) / 2，其中1=没有遮挡=完全接受间接光照
    由于surfaceData.occlusion∈[0,1]，所以indirectOcclusion∈[0.5, 1]，不会低于50%，可以防止完全变黑
    */

    // _IndirectLightMultiplier 作为乘数修正间接光照（目前默认=1）
    half3 indirectLight = averageSH * (_IndirectLightMultiplier * indirectOcclusion);
    
    //return averageSH * indirectOcclusion;
    //return indirectLight;
    return surfaceData.albedo * max(indirectLight, _IndirectLightMinColor); //防止lightprobe没有被烘焙且_OcclusionIndirectStrength=1，或_IndirectLightMultiplier=0时完全变黑
}

// Most important part: lighting equation, edit it according to your needs, write whatever you want here, be creative!
// This function will be used by all direct lights (directional/point/spot) 
// 版本1
// TODO：只有漫反射项，缺少高光反射项。也可以考虑往_Metallic等PBR的方向做。
half3 ShadeSingleLight_v1(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight)
{
    half3 N = lightingData.normalWS;
    half3 L = light.direction;
    half3 V = lightingData.viewDirectionWS;
    half3 H = normalize(L+V);

    half NoL = dot(N,L);
    half NoH = dot(N,H);

    half lightAttenuation = 1; //未使用

    // light's distance & angle fade for point light & spot light (see GetAdditionalPerObjectLight(...) in Lighting.hlsl)
    // Lighting.hlsl -> https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
    half distanceAttenuation = min(4,light.distanceAttenuation); //clamp to prevent light over bright if point/spot light too close to vertex

    // simplest 1 line cel shade, you can always replace this line by your own method! | 最简单的1条边界线的暗部（亮部+暗部+使用smoothstep柔和过渡）
    // litOrShadowArea的范围为[0,1]
    half litOrShadowArea = smoothstep(_CelShadeMidPoint-_CelShadeSoftness,_CelShadeMidPoint+_CelShadeSoftness, NoL); //目前对于脸部，_CelShadeSoftness=0.5，以达到非常平滑的过渡

    // occlusion
    // 使用_OcclusionDirectStrength在直接光照中控制遮挡的程度
    litOrShadowArea *= lerp(1, surfaceData.occlusion, _OcclusionDirectStrength);

    // face ignore celshade since it is usually very ugly using NoL method
    // 面部直接使用litOrShadowArea比较难看，所以使用lerp做一个从[0,1]到[0.5,1]的线性映射，相当于让脸部更亮一些。此时脸部的litOrShadowArea的范围为[0.5,1]
    litOrShadowArea = _IsFace ? lerp(0.5,1,litOrShadowArea) : litOrShadowArea;

    // light's shadow map | 光照的shadow map，也就是阴影衰减，使用_ReceiveShadowMappingAmount控制应用阴影衰减的程度
    // shadowAttenuation值的范围为[0,1]
    litOrShadowArea *= lerp(1,light.shadowAttenuation,_ReceiveShadowMappingAmount);

    half3 litOrShadowColor = lerp(_ShadowMapColor,1, litOrShadowArea); // 控制阴影的颜色
    
    // distanceAttenuation值的范围为[0,1]
    half3 lightAttenuationRGB = litOrShadowColor * distanceAttenuation; // 再×距离衰减（即光照衰减）

    // 采样Ramp贴图
    half3 rampColor = (1, 1, 1);
    #if ENABLE_RAMP_SHADOW
        rampColor = NPR_Ramp(NoL, _InNight, surfaceData._lightMap);
        rampColor = lerp(1, rampColor, _AlbedoMulByRampColor); //控制albedo颜色乘上ramp颜色的程度
    #endif
    
    half3 diffuse = surfaceData.albedo * rampColor * saturate(light.color) * lightAttenuationRGB * (isAdditionalLight ? 0.25 : 1);
    diffuse *= _UseLightMap ? (1 - surfaceData._lightMap.r) : 1; //有lightmap时，考虑到Blinn-Phong能量守恒，金属性越强的地方diffuse越暗

    half3 specular = _UseLightMap ? surfaceData.albedo * saturate(light.color) * NPR_Specular(NoH, surfaceData._lightMap): 0; //没有lightmap时 高光项=0 //需要×light的color，否则即使光线很暗也有高光，不合理 //目前不×rampColor

    // TODO
    half3 hairAdditionalSpecular = 0;
    //half3 hairAdditionalSpecular = _UseLightMap ? surfaceData.albedo * saturate(light.color) * NPR_Hair_Additional_Specular(N, NoL, surfaceData._lightMap) : 0; //有lightmap并且_IsFace（在该函数内判断）时，才计算头发的额外高光，否则=0

    half3 metalSpecular = _UseLightMap ? surfaceData.albedo * saturate(light.color) * NPR_MetalSpecular(N, surfaceData._lightMap) : 0;  //没有lightmap时 金属高光项=0 //需要×light的color，否则即使光线很暗也有金属高光，不合理 //目前不×rampColor

    half3 finalColor = diffuse + specular + hairAdditionalSpecular + metalSpecular;

    //half4 finalColor_and_litOrShadowArea = (finalColor, 1);

    //return finalColor_and_litOrShadowArea; //把litOrShadowArea（范围[0,1]）存到alpha通道中

    return finalColor;
}

// Most important part: lighting equation, edit it according to your needs, write whatever you want here, be creative!
// This function will be used by all direct lights (directional/point/spot) 
// 版本2
// TODO：只有漫反射项。缺少高光反射项。也可以考虑往_Metallic等PBR的方向做。
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

    // light's shadow map | 光照的shadow map，也就是阴影衰减，使用_ReceiveShadowMappingAmount控制应用阴影衰减的程度
    // shadowAttenuation值的范围为[0,1]
    lightAttenuation *= lerp(1,light.shadowAttenuation,_ReceiveShadowMappingAmount);

    // light's distance & angle fade for point light & spot light (see GetAdditionalPerObjectLight(...) in Lighting.hlsl)
    // Lighting.hlsl -> https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
    half distanceAttenuation = min(4,light.distanceAttenuation); //clamp to prevent light over bright if point/spot light too close to vertex

    lightAttenuation *= distanceAttenuation; // distanceAttenuation值的范围为[0,1]

    // N dot L
    // simplest 1 line cel shade, you can always replace this line by your own method! | 最简单的1条边界线的暗部（亮部+暗部+使用smoothstep柔和过渡）
    // cellitOrShadowArea的范围为[0,1]
    half celLitOrShadowArea = smoothstep(_CelShadeMidPoint-_CelShadeSoftness,_CelShadeMidPoint+_CelShadeSoftness, NoL);

    // don't want direct lighting's cel shade effect looks too strong? set ignoreValue to a higher value | 控制忽略cel风格的明暗部的程度（比如可以让脸部更亮）
    // 目前默认_AdditionalLightIgnoreCelShade = 0.8，_MainLightIgnoreCelShade = 0
    lightAttenuation *= lerp(celLitOrShadowArea, 1, isAdditionalLight ? _AdditionalLightIgnoreCelShade : _MainLightIgnoreCelShade);
    
    // don't want direct lighting becomes too bright for toon lit characters? set this value to a lower value 
    // 目前默认_DirectLightMultiplier=1
    lightAttenuation *= _DirectLightMultiplier;
    //lightAttenuation *= 0.25;

    // occlusion
    // 使用_OcclusionDirectStrength在直接光照中控制遮挡的程度
    half directOcclusion = lerp(1, surfaceData.occlusion, _OcclusionDirectStrength);
    lightAttenuation *= directOcclusion;
    
    // 采样Ramp贴图
    half3 rampColor = (1, 1, 1);
    #if ENABLE_RAMP_SHADOW
        rampColor = NPR_Ramp(NoL, _InNight, surfaceData._lightMap);
    #endif

    return surfaceData.albedo * rampColor * light.color * lightAttenuation; 

    // ***【注意】需要和配合CompositeAllLightResults中Luminance控制过亮使用，否则脸上阴影都是很黑的，超级丑
}
half3 ShadeSingleLight(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight)
{
    return ShadeSingleLight_v1(surfaceData, lightingData, light, isAdditionalLight);
}

// 需要渐变纹理Ramp Map，暂时没用
//half3 CalculateRamp(half halfLambert){}

///////////////////////////////////////////////////////////////////////////////////////
// 边缘光计算函数
///////////////////////////////////////////////////////////////////////////////////////

// https://zhuanlan.zhihu.com/p/435005339
// 感觉效果和原来差不多。。。
//float3 NPR_Base_RimLight(float NdotV,float halfLambert,float3 baseColor)
//{
//    //return (1 - smoothstep(_RimRadius,_RimRadius + 0.03,NdotV)) * _RimIntensity * (1 - halfLambert) * baseColor;
//    return (1 - smoothstep(_RimMin,_RimMin + 0.03, NdotV)) * _RimIntensity * (1 - halfLambert) * baseColor; //建议_RimMax=_rimMin+0.03
//}

// 菲涅尔边缘光 https://zhuanlan.zhihu.com/p/95986273
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

//【JTRP】基础边缘光 。。。
/*
核心应该是使用dot(N, L)计算边缘光，然后有个RimLightMask贴图
*/

// =======================================================================================================
//【JTRP】屏幕空间深度边缘光 Screen Space Depth Rimlight https://zhuanlan.zhihu.com/p/139290492
float GetScaleWithHight()
{
    /*
    float4 _ScreenParams	
    x is the width of the camera’s target texture in pixels, 
    y is the height of the camera’s target texture in pixels, 
    z is 1.0 + 1.0/width and w is 1.0 + 1.0/height.
    */
	return _ScreenParams.y / 1080;
}
/*
float3 GetCameraRelativePositionWS(float3 _WorldSpaceCameraPos)
{
    【HDRP和URP的内置函数】
    如果启用摄像机相对渲染（Camera-relative rendering）：返回 float3(0, 0, 0)。
    如果禁用摄像机相对渲染：返回传入的位置，不做任何修改。
}
*/
float LoadCameraDepth(uint2 pixelCoords)
{
    /*
    【HDRP的内置函数】
    */
    //LOAD_TEXTURE2D_X_LOD是com.unity.render-pipelines.core的内置函数
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
    UNITY_BRANCH //在条件语句之前添加此宏，告知编译器应将其编译为实际分支。在 HLSL 平台上扩展为 [branch]。
    if (!_EnableSSRim) return 0;

    float2 uv = lightingData.uv;
    float3 normalDirWS = lightingData.normalWS;

    half4 mask = tex2D(_SSRimMask, uv);
    half widthRamp = 1; // TODO
	//half widthRamp = SampleRampSignalLine(_SSRimWidthRamp, distance(posInput.positionWS, GetCameraRelativePositionWS(_WorldSpaceCameraPos)) / _SSRimRampMaxDistance).r;

    float2 L_VS = normalize(mul((float3x3)UNITY_MATRIX_V, lightDirWS).xy) * (_SSRimInvertLightDir ? -1 : 1); //翻转
    float2 N_VS = normalize(mul((float3x3)UNITY_MATRIX_V, normalDirWS).xy);
    float NdotL = saturate(dot(N_VS, L_VS) + _SSRimLength); //_SSRimLength可以让最终的边缘光区域扩大
    float scale = mask.r * widthRamp * NdotL * _SSRimWidth * GetScaleWithHight(); //_SSRimWidth其实是控制控制偏移距离的，视觉效果约等于控制rimLight宽度
    // 原理：取屏幕空间当前像素坐标UV，向N_VS方向偏移后采样深度，与当前像素深度进行比较，深度差大于某一阈值则为边缘。
    float2 ssUV1 = clamp(lightingData.positionSS + N_VS * scale, 0, _ScreenParams.xy - 1); //scale控制偏移距离
    float viewDepth = distance(lightingData.positionWS, GetCameraRelativePositionWS(_WorldSpaceCameraPos));

    float3 sceneWorldPos = GetWorldPosFromDepthBuffer(ssUV1 * _ScreenSize.zw, LoadCameraDepth(ssUV1));
	float sceneViewDepth = distance(GetCameraRelativePositionWS(sceneWorldPos), GetCameraRelativePositionWS(_WorldSpaceCameraPos));

	float intensity = smoothstep(viewDepth, viewDepth + _SSRimFeather, sceneViewDepth); //强度=0~1，羽化（深度差的阈值）：_SSRimFeather范围=0~2，越小羽化越强 //【注意】由于是smoothstep平滑过渡，可能导致非边缘也会变亮
	intensity *= mask.a * lerp(1, _SSRimInShadow, shadowValue) * _SSRimIntensity; //mask //在阴影中减弱边缘光
	
	return _SSRimColor * intensity * lerp(1, color, _SSRimColor.a); //边缘光直接加在原color上 //A通道指示混合diffuse颜色的程度（=0时，...）
}
//【JTRP】屏幕空间深度边缘光 Screen Space Depth Rimlight
// =======================================================================================================

// 原版
half3 ShadeEmission_v1(ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    half3 emissionResult = lerp(surfaceData.emission, surfaceData.emission * surfaceData.albedo, _EmissionMulByBaseColor); // optional mul albedo // 控制自发光颜色乘上albedo颜色（Base颜色）的程度
    return emissionResult;
}
// 改进版
half3 ShadeEmission_v2(ToonSurfaceData surfaceData, ToonLightingData lightingData, bool isAdditionalLight)
{
    // 如果没有启用Emission，则surfaceData.emission = 0
    // 有2种Emission，原神式和非原神式，见GetFinalEmissionColor()函数
    half3 emissionResult = surfaceData.emission;
    emissionResult = _isGenshinEmission ? emissionResult : lerp(emissionResult, emissionResult * surfaceData.albedo, _EmissionMulByBaseColor); // 非原神式，控制自发光颜色乘上albedo颜色（Base颜色）的程度

    return emissionResult;
}
half3 ShadeEmission(ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    return ShadeEmission_v2(surfaceData, lightingData, false); 
}

// 普通的边缘光
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
    //ramp *= CustomFaceShade(surfaceData, lightingData, lightingData, isAdditionalLight); //目前isAdditionalLight总是false，而且没用上 // CustomFaceShade用于初始化lightAttenuation或者faceShadowMask，返回值是0或1

	// initialize rimMask if not using custom rim light lightmask;
    //half3 rimMask = half3(1, 1, 1);
    // if use custom rim light lightmask;
    half3 rimMask = surfaceData._rimMask; // _rimMask是个half
    half3 rimMaskStrength = surfaceData._rimMaskStrength;

    // 方法一：rimLight做法：使用NdotV + 半兰伯特（NdotL）
    half ndv =  1 - max(0, NdotV);
    half rim = smoothstep(rimMin, rimMax, ndv) * (1 - halfLambert); //控制边光的范围 //我们希望向光面的边缘光很弱，所以使用半兰伯特（NdotV）控制
    //有问题，太亮了
    //if (useRimLight == 1)
    //{
    //    rim = lerp(rimMin, rimMax, ndv);
    //}
    rim = smoothstep(0, rimSmooth, rim); //控制边光的软硬（实际效果还行）（_RimSmooth=1时，smoothstep(0, 1, rim)≈rim，_RimSmooth=0时，smoothstep(0, 0, rim)=1）
    half3 rimLight = rim * lerp(1, rimMask.rgb, rimMaskStrength) * rimIntensity * rimColor.rgb; //控制边缘光的遮罩、强度、颜色

    //// 方法二：
    //half3 rimLight = NPR_Base_RimLight(NdotV, halfLambert, rimColor.rgb);
    
    //// 方法三：菲涅尔边缘光
    //half3 rimLight = Fresnel_RimLight(NdotV, VdotL, rimColor.rgb);
    
    rimLight = lerp(rimLight, rimLight * surfaceData.albedo, _RimMulByBaseColor); // 控制边缘光颜色乘上albedo颜色（Base颜色）的程度

    return rimLight;
}

// 原版
half3 CompositeAllLightResultsDefault(half3 indirectResult, half3 mainLightResult, half3 additionalLightSumResult, half3 emissionResult, ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    // 只是一个过于简单的实现。
    // [remember you can write anything here, this is just a simple tutorial method]
    // here we prevent light over bright,
    // while still want to preserve light color's hue

    half3 indirectDirectLightSum  = max(indirectResult, mainLightResult + additionalLightSumResult); // pick the highest between indirect and direct light  
    // 取max(间接光照结果 和 主光源光照结果+额外光源光照结果)，也就是说除非光源很暗，否则间接光照的计算结果其实被扔掉了，这是否有点。。。。。。                                                        

    return surfaceData.albedo * indirectDirectLightSum  + emissionResult; // 上面计算颜色的时候除了“自发光项”都没有乘albedo
}
// 改进版
half3 CompositeAllLightResults(half3 indirectResult, half3 mainLightResult, half3 additionalLightSumResult, half3 emissionResult, half3 rimlightResult, half3 faceShadowMask, ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, half shadowValue)
{
    // Legacy method;
	/*half3 shadowColor = lerp(2*surfaceData._shadowColor, 1, faceShadowMask);
	half3 result = indirectResult*shadowColor + mainLightResult + additionalLightSumResult + emissionResult;
    return result;*/

    // 仅用于脸部的[间接光照部分的]的sdf贴图形成的阴影 // ***注意***：非脸部faceShadowMask = (1,1,1)。
    // faceShadowMask只有2种返回值：0=(0,0,0)或1=(1,1,1)，此时使用lerp语句是一种对避免使用if语句的技巧。
    half3 shadowColor = lerp(surfaceData._shadowColor, 1, faceShadowMask);

    // 间接光照结果 * shadowColor 进行阴影修正；直接光照的暗部不修正？
    half3 indirectDirectLightSum = indirectResult * shadowColor + mainLightResult + additionalLightSumResult;  // 间接+直接 //TODO:感觉脸部阴影还是不太对

    //一种处理:
    //half lightLuminance = Luminance(indirectDirectLightSum );
    //half3 finalLightMulResult = indirectDirectLightSum  / max(1,lightLuminance / max(1,log(lightLuminance))); // allow controlled over bright using log
    //return surfaceData.albedo * finalLightMulResult + emissionResult;
    
    // Screen Space rimLight | SS边缘光
    // TODO：改进lightDirWS
    half3 lightDirWS = -light.direction; // light.direction = _MainLightPosition.xyz; (mainLight)
    // TODO：改进shadowValue 0表示完全不在阴影中，1表示完全在阴影中
    half3 SSRimLight = GetSSRimLight(indirectDirectLightSum, lightingData, lightDirWS, shadowValue);
    //half3 SSRimLight = GetSSRimLight(surfaceData.albedo, lightingData, lightDirWS, shadowValue);
    
    half3 finalColor = indirectDirectLightSum + emissionResult + rimlightResult + SSRimLight;

    return finalColor;
}

half3 ShadeFaceShadow(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light)
{
	return CustomFaceShade(surfaceData, lightingData, light, false); //这个isAdditionalLight（= false）没用上
}
#endif