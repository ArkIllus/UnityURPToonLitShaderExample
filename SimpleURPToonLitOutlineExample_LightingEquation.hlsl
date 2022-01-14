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
    half3 averageSH = SampleSH(0); // 采样离网格最近的3个光照探针并插值？？？？？？
    // 如果我们关闭了自动烘焙导致没有烘焙lightprobe，则采样结果是黑色； 
    // 如果场景中没有probe，则使用光照设置中的环境probe，通常是Sky Box；
    // 动态物体通过采样probe获得静态物体的间接光贡献； probe中的记录了probe位置处多个角度采样的颜色，保存为SH系数； 
    // 采样probe的过程中通过SH系数快速计算出采样结果，相比Cubemap贴图来说节约性能。 
    // probe仅作为保存颜色的方式，而这些颜色都是通过RayTracing离线计算的，不能实时变化。
    // probe中也无法判断物体距离，无法提供阴影。

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
    return max(indirectLight, _IndirectLightMinColor); //防止lightprobe没有被烘焙且_OcclusionIndirectStrength=1，或_IndirectLightMultiplier=0时完全变黑
}

// 用于初始化lightAttenuation或者faceShadowMask，返回值是0或1
half CustomFaceShade(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight) // isAdditionalLight目前没用上
{
    half3 N = lightingData.normalWS;
    half3 L = light.direction;
    half3 V = lightingData.viewDirectionWS;
    half3 H = normalize(L+V);

    half NoL = dot(N,L);

    // ====== Genshin Style facial shading ======

    // Get front and right vectors from rotation matrix
    // 解释： Unity的模型空间（使用左手坐标系）中，x方向(1, 0, 0)、y方向(0, 1, 0)、z方向(0, 0, 1) 分别对应 模型的正右、上、前方向
    // 现在，求世界空间中模型自身坐标系的xyz方向对应的方向向量 
    // 比如 x方向（正右方）：float3 Right = TransformObjectToWorldDir(float3(1, 0, 0)).xyz;
    // 代入得到 float3 Right = (unity_Object2Wolrd._m00, unity_Object2Wolrd._m10, unity_Object2Wolrd._m20);
    float3 Right = unity_ObjectToWorld._m00_m10_m20; //世界空间中该片元（角色）的正右方向量（未归一）
    //float3 Up = unity_ObjectToWorld._m01_m11_m21; //...正上方
    float3 Front = unity_ObjectToWorld._m02_m12_m22; //...正前方

    // Nomralize light direction in relation to front and right vectors
    // 单位向量的点积 = 夹角余弦
    // 只取xz分量（正右、前方向，忽略正上方向，相当于从三维向量变成二维xz平面向量）
    float RightLight = dot(normalize(Right.xz), normalize(L.xz));
    float FrontLight = dot(normalize(Front.xz), normalize(L.xz));

    // 阴影覆盖修复可实现更平滑的过渡 -> https://zhuanlan.zhihu.com/p/279334552;  // ？？？？？？？？？？
    RightLight = -(acos(RightLight) / 3.14159265 - 0.5) * 2;

    // 使用原始LightMap采样值的R通道值（阴影中的左侧部分）或 翻转的LightMap采样值的R通道值（阴影中的右侧部分），取决于光线方向
    float LightMap = RightLight > 0 ? surfaceData._lightMapR.r : surfaceData._lightMapL.r;

    //这控制了我们如何根据归一化的光线方向分布在lightmap上滚动的速度；
    //值越高=朝向灯光时转换越快，而朝向远离灯光时转换越慢，值越低=相反；  // ？？？？？？？？？？
    float dirThreshold = 0.1;

    //如果面向灯光，请使用右归一化灯光方向和dirThreshold。
    //如果背向灯光，请使用前归一化灯光方向和（1-dirThreshold）和相应的平移...
    // ...以确保180度时的平滑过渡（其中前归一化灯光方向==0）。  // ？？？？？？？？？？
    float lightAttenuation_temp = (FrontLight > 0) ? 
        min((LightMap > dirThreshold * RightLight), (LightMap > dirThreshold * -RightLight)) :
        min((LightMap > (1 - dirThreshold * 2) * FrontLight - dirThreshold), (LightMap > (1 - dirThreshold * 2) * -FrontLight + dirThreshold));
     
    //[冗余]当背对光线时，补偿平移？
	//lightAttenuation_temp += (FrontLight < -0.9) ? (min((LightMap > 1 * FrontLight), (LightMap > 1 * -FrontLight))) : 0;

    // ====== End of Genshin Style facial shading ======

    half lightAttenuation = surfaceData._useLightMap ? lightAttenuation_temp : 1;

    return lightAttenuation; // 返回值是0或1
}

// Most important part: lighting equation, edit it according to your needs, write whatever you want here, be creative!
// This function will be used by all direct lights (directional/point/spot) 
// | 最重要的函数。这个函数会被所有类型的光源使用（平行光/点光源/聚光灯）（主光源 + 额外光源）
// TODO：似乎只有漫反射项。缺少高光反射项。也可以考虑往_Metallic等PBR的方向做。
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
    // | 点光源和聚光灯的光照的距离&角度衰减（请参见Lighting.hlsl中的GetAdditionalPerObjectLight(...)）
    // Lighting.hlsl -> https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
    half distanceAttenuation = min(4,light.distanceAttenuation); //clamp to prevent light over bright if point/spot light too close to vertex 
                                                                 // | 如果点光源/聚光灯离顶点太近，则取上限=4以防止光线过亮

    // N dot L
    // simplest 1 line cel shade, you can always replace this line by your own method! | 最简单的1条边界线的暗部（亮部+暗部+使用smoothstep柔和过渡）
    // litOrShadowArea的范围为[0,1]
    half litOrShadowArea = smoothstep(_CelShadeMidPoint-_CelShadeSoftness,_CelShadeMidPoint+_CelShadeSoftness, NoL); //smoothstep用来生成0到1的平滑过渡

    // occlusion
    // 使用_OcclusionDirectStrength在直接光照中控制遮挡的程度
    litOrShadowArea *= lerp(1, surfaceData.occlusion, _OcclusionDirectStrength);

    // face ignore celshade since it is usually very ugly using NoL method
    // 面部直接使用litOrShadowArea比较难看，所以使用lerp做一个从[0,1]到[0.5,1]的线性映射，相当于让脸部更亮一些。此时脸部的litOrShadowArea的范围为[0.5,1]
    litOrShadowArea = _IsFace ? lerp(0.5,1,litOrShadowArea) : litOrShadowArea;

    // light's shadow map | 光照的shadow map，也就是阴影衰减，使用_ReceiveShadowMappingAmount控制应用阴影衰减的程度（=0时没有阴影？）
    // *** 《入门精要》中，UNITY_LIGHT_ATTENUATION计算光照衰减和阴影值相乘的结果存储在atten中，将最终的color乘上atten值。
    // *** 这里是shadowAttenuation作为一个乘数计算litOrShadowArea，再由litOrShadowArea计算litOrShadowColor。最终
    // shadowAttenuation值的范围为[0,1]
    litOrShadowArea *= lerp(1,light.shadowAttenuation,_ReceiveShadowMappingAmount);

    half3 litOrShadowColor = lerp(_ShadowMapColor,1, litOrShadowArea); // 控制阴影的颜色，使用lerp做一个从[0,1]到[_ShadowMapColor,1]的线性映射，litOrShadowArea=0时，litOrShadowColor=_ShadowMapColor
    
    // distanceAttenuation值的范围为[0,1]
    half3 lightAttenuationRGB = litOrShadowColor * distanceAttenuation; // 再乘 距离衰减（即光照衰减）

    // saturate() light.color to prevent over bright | saturate(light.color)防止过亮（当光源的intensity设为超过1时，light.color的范围就超过1了）
    // additional light reduce intensity since it is additive | 对于额外光源的光乘0.25，让它弱一些，但是为啥调整这个数感觉画面没变化？因为没有额外光源！
    return saturate(light.color) * lightAttenuationRGB * (isAdditionalLight ? 0.25 : 1);
    //return light.color * lightAttenuationRGB * (isAdditionalLight ? 0.25 : 1);
}
// Most important part: lighting equation, edit it according to your needs, write whatever you want here, be creative!
// This function will be used by all direct lights (directional/point/spot) 
// | 最重要的函数。这个函数会被所有类型的光源使用（平行光/点光源/聚光灯）（主光源 + 额外光源）
// TODO：似乎只有漫反射项。缺少高光反射项。也可以考虑往_Metallic等PBR的方向做。
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

    // light's shadow map | 光照的shadow map，也就是阴影衰减，使用_ReceiveShadowMappingAmount控制应用阴影衰减的程度（=0时没有阴影衰减）
    // *** 《入门精要》中，UNITY_LIGHT_ATTENUATION计算光照衰减和阴影值相乘的结果存储在atten中，将最终的color乘上atten值。
    // *** 这里是shadowAttenuation作为一个乘数计算lightAttenuation
    // shadowAttenuation值的范围为[0,1]
    lightAttenuation *= lerp(1,light.shadowAttenuation,_ReceiveShadowMappingAmount);

    // light's distance & angle fade for point light & spot light (see GetAdditionalPerObjectLight(...) in Lighting.hlsl)
    // | 点光源和聚光灯的光照的距离&角度衰减（请参见Lighting.hlsl中的GetAdditionalPerObjectLight(...)）
    // Lighting.hlsl -> https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
    half distanceAttenuation = min(4,light.distanceAttenuation); //clamp to prevent light over bright if point/spot light too close to vertex 
                                                                 // | 如果点光源/聚光灯离顶点太近，则取上限=4以防止光线过亮

    lightAttenuation *= distanceAttenuation; // 再乘 距离衰减（即光照衰减）// distanceAttenuation值的范围为[0,1]

    // N dot L
    // simplest 1 line cel shade, you can always replace this line by your own method! | 最简单的1条边界线的暗部（亮部+暗部+使用smoothstep柔和过渡）
    // cellitOrShadowArea的范围为[0,1]
    half celLitOrShadowArea = smoothstep(_CelShadeMidPoint-_CelShadeSoftness,_CelShadeMidPoint+_CelShadeSoftness, NoL); //smoothstep用来生成0到1的平滑过渡
    
    // face ignore celshade since it is usually very ugly using NoL method
    // 面部直接使用celLitOrShadowArea比较难看，所以使用lerp做一个从[0,1]到[0.5,1]的线性映射，相当于让脸部更亮一些。此时脸部的celLitOrShadowArea的范围为[0.5,1]
    //celLitOrShadowArea = _IsFace ? lerp(0.5,1,litOrShadowArea) : litOrShadowArea;

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

    //half3 litOrShadowColor = lerp(_ShadowMapColor,1, litOrShadowArea); // 控制阴影的颜色，使用lerp做一个从[0,1]到[_ShadowMapColor,1]的线性映射，litOrShadowArea=0时，litOrShadowColor=_ShadowMapColor
    //
    // 不再使用_ShadowMapColor控制阴影的颜色

    // saturate() light.color to prevent over bright | saturate(light.color)防止过亮（当光源的intensity设为超过1时，light.color的范围就超过1了）
    // additional light reduce intensity since it is additive | 对于额外光源的光乘0.25，让它弱一些，但是为啥调整这个数感觉画面没变化？因为没有额外光源！
    //return saturate(light.color) * lightAttenuationRGB * (isAdditionalLight ? 0.25 : 1);
    //
    // 不再saturate(light.color)防止过亮（当光源的intensity设为超过1时）（在最后的CompositeAllLightResults时控制过亮），不再对于额外光源的光乘0.25让它弱一些
    return light.color * lightAttenuation; 

    // ***【注意】貌似需要和配合 CompositeAllLightResults中Luminance控制过亮 使用，否则脸上阴影都是很黑的，超级丑
}
half3 ShadeSingleLight(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light, bool isAdditionalLight)
{
    return ShadeSingleLight_v1(surfaceData, lightingData, light, isAdditionalLight);
}

// 需要渐变纹理Ramp Map，暂时没用
//half3 CalculateRamp(half halfLambert){}

// 自称·菲涅尔边缘光（不是，这哪里菲涅尔了。。。） https://zhuanlan.zhihu.com/p/435005339
// 感觉效果和原来差不多。。。
float3 NPR_Base_RimLight(float NdotV,float halfLambert,float3 baseColor)
{
    _RimIntensity = 1; // ？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？
    //return (1 - smoothstep(_RimRadius,_RimRadius + 0.03,NdotV)) * _RimIntensity * (1 - halfLambert) * baseColor;
    return (1 - smoothstep(_RimMin,_RimMin + 0.03, NdotV)) * _RimIntensity * (1 - halfLambert) * baseColor; //所以建议_RimMax=_rimMin+0.03！！！！！
}

// 真·菲涅尔边缘光 https://zhuanlan.zhihu.com/p/95986273
float3 Fresnel_schlick(float VoN, float3 rF0) {
		return rF0 + (1 - rF0) * pow(1 - VoN, 5);
	}
float3 Fresnel_extend(float VoN, float3 rF0) {
	return rF0 + (1 - rF0) * pow(1 - VoN, 3);
}
float3 Fresnel_RimLight(float NdotV,float VdotL,float3 baseColor) {
    half3 fresnel = Fresnel_extend(NdotV, float3(0.1, 0.1, 0.1));
    //half3 fresnelResult = _FresnelEff * fresnel * (1 - VoL) / 2;
    _RimIntensity = 1; // ？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？
    half3 fresnelResult = _RimIntensity * fresnel * (1 - VdotL) / 2 * baseColor.rgb;
    return fresnelResult;
}

//【JTRP】基础边缘光 。。。
/*
大概看了一下，有亿点点复杂，但本质上核心应该是使用dot(N, L)计算边缘光，然后有个RimLightMask贴图（非常重要，然而那个贴图只有鼻子那里有边缘光）
*/

//【JTRP】屏幕空间深度边缘光 Screen Space Depth Rimlight https://zhuanlan.zhihu.com/p/139290492
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

// 原版
half3 ShadeEmission_v1(ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    half3 emissionResult = lerp(surfaceData.emission, surfaceData.emission * surfaceData.albedo, _EmissionMulByBaseColor); // optional mul albedo // 控制自发光颜色乘上albedo颜色（Base颜色）的程度
    return emissionResult;
}
// 改进版（新增rimLight 并归到计算emission项的函数里）
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
    //ramp *= CustomFaceShade(surfaceData, lightingData, lightingData, isAdditionalLight); //目前isAdditionalLight总是false，而且没用上
                                                                        // CustomFaceShade用于初始化lightAttenuation或者faceShadowMask，返回值是0或1
                                                                        // 不是，这个ramp干嘛用的？？？？？？？？？？？？？应该有一张渐变纹理？？？？

	// initialize rimMask if not using custom rim light lightmask;
    //half3 rimMask = half3(1, 1, 1);
    // if use custom rim light lightmask;
    half3 rimMask = surfaceData._rimMask; // _rimMask是个half
    half3 rimMaskStrength = surfaceData._rimMaskStrength;

    // rimLight做法：使用NdotV + 半兰伯特（NdotL）
    half ndv =  1 - max(0, NdotV);
    half rim = smoothstep(rimMin, rimMax, ndv) * (1 - halfLambert); //控制边光的范围 //希望向光面的边缘光很弱，所以使用半兰伯特（NdotV）控制
    // 你这代码有问题啊，太亮了
    //if (useRimLight == 1) // 包括RimLight,1,FakeSSS,2（？） 则 线性插值
    //{
    //    rim = lerp(rimMin, rimMax, ndv);
    //}
    rim = smoothstep(0, rimSmooth, rim); //控制边光的软硬（实际效果还行）（_RimSmooth=1时，smoothstep(0, 1, rim)≈rim，_RimSmooth=0时，smoothstep(0, 0, rim)=1）
    rimIntensity = 1; // ？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？？
    half rimLight = rim * lerp(1, rimMask.rgb, rimMaskStrength) * rimIntensity * rimColor.rgb; //控制边缘光的遮罩、颜色、强度

    //// 自称·菲涅尔边缘光（和上面的没啥区别。。。）
    //half3 rimLight = NPR_Base_RimLight(NdotV, halfLambert, rimColor.rgb);
    
    //// 真·菲涅尔边缘光（为啥没效果）
    //half3 rimLight = Fresnel_RimLight(NdotV, VdotL, rimColor.rgb);
    // ====== End of Rim Light ======

    half3 emissionAndRim = surfaceData.emission;
    emissionAndRim.rgb += useRimLight ? rimLight : 0;

    half3 emissionAndRimResult = lerp(emissionAndRim, emissionAndRim * surfaceData.albedo, _EmissionMulByBaseColor); // 控制自发光颜色乘上albedo颜色（Base颜色）的程度
    return emissionAndRimResult;
}
half3 ShadeEmission(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light)
{
    return ShadeEmission_v2(surfaceData, lightingData, light, false); 
}
// 原版
half3 CompositeAllLightResultsDefault(half3 indirectResult, half3 mainLightResult, half3 additionalLightSumResult, half3 emissionResult, ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    // 只是一个过于简单的实现，特别是rawLightSum的取max操作，有点逆天。
    // [remember you can write anything here, this is just a simple tutorial method]
    // here we prevent light over bright,
    // while still want to preserve light color's hue

    half3 rawLightSum = max(indirectResult, mainLightResult + additionalLightSumResult); // pick the highest between indirect and direct light  
                                                                                         // 取max(间接光照结果 和 主光源光照结果+额外光源光照结果)，也就是说除非光源很暗，否则间接光照的计算结果其实被扔掉了，这是否有点。。。。。。                                                        
    //half3 rawLightSum = indirectResult + mainLightResult + additionalLightSumResult; // 间接+直接

    return surfaceData.albedo * rawLightSum + emissionResult; // ***注意上面计算颜色的时候除了“自发光项”都没有乘albedo，在这里乘albedo(Base) Color，并加上自发光项
}
// 改进版
half3 CompositeAllLightResults(half3 indirectResult, half3 mainLightResult, half3 additionalLightSumResult, half3 emissionResult, half3 faceShadowMask, ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    // Legacy method;
	/*half3 shadowColor = lerp(2*surfaceData._shadowColor, 1, faceShadowMask);
	half3 result = indirectResult*shadowColor + mainLightResult + additionalLightSumResult + emissionResult;
    return result;*/

    half3 shadowColor = lerp(surfaceData._shadowColor, 1, faceShadowMask); // faceShadowMask =1表示完全没有[间接光照部分的]阴影，=0表示100%接受[间接光照部分的]阴影

    //half3 rawLightSum = max(indirectResult * shadowColor, mainLightResult + additionalLightSumResult); // max(间接，直接) 
    // 除非光源很暗，否则间接光照的计算结果其实被扔掉了，这是否有点。。。。。。 
    // 间接光照结果 * shadowColor 进行阴影修正
    // 直接光照的暗部呢？？？？？ 不修正？？？？？  
    
    half3 rawLightSum = indirectResult * shadowColor + mainLightResult + additionalLightSumResult;  // 间接+直接 ***问题是这样脸部可能很难看*** 如何解决？
    
    //half3 rawLightSum = indirectResult + mainLightResult + additionalLightSumResult; //没乘shadowColor，间接光照部分就没有阴影
    //half3 rawLightSum = indirectResult * shadowColor;

    //half lightLuminance = Luminance(rawLightSum);
    //half3 finalLightMulResult = rawLightSum / max(1,lightLuminance / max(1,log(lightLuminance))); // allow controlled over bright using log | 在这里控制过亮 ？？？
    half3 finalLightMulResult = rawLightSum;

    return surfaceData.albedo * finalLightMulResult + emissionResult; // ***注意上面计算颜色的时候除了“自发光项”都没有乘albedo，在这里乘albedo(Base) Color，并加上自发光项
}
half3 ShadeFaceShadow(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light) // 确定是脸部
{
	return CustomFaceShade(surfaceData, lightingData, light, false);
}
#endif