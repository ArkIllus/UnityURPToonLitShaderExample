// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

/*
This shader is a simple example showing you how to write your first URP custom lit shader with "minimum" shader code.
You can use this shader as a starting point, add/edit code to develop your own custom lit shader for URP10.3.2 or above.

*Usually, just by editing "SimpleURPToonLitOutlineExample_LightingEquation.hlsl" alone can control most of the visual result.

This shader includes 5 passes:
0.ForwardLit    pass    (this pass will always render to the color buffer _CameraColorTexture)
1.Outline       pass    (this pass will always render to the color buffer _CameraColorTexture)
2.ShadowCaster  pass    (only for URP's shadow mapping, this pass won't render at all if your character don't cast shadow)
3.DepthOnly     pass    (only for URP's depth texture _CameraDepthTexture's rendering, this pass won't render at all if your project don't render URP's offscreen depth prepass)
4.DepthNormals  pass    (only for URP's normal texture _CameraNormalsTexture's rendering)

*Because most of the time, you use this toon lit shader for unique characters, so all lightmap & GPU instancing related code are removed for simplicity.
*For batching, we only rely on SRP batcher, which is the most practical batching method in URP for rendering lots of unique skinnedmesh characters

*In this shader, we choose static uniform branching over "shader_feature & multi_compile" for some of the togglable feature like "_UseEmission","_UseOcclusion"..., 
because:
    - we want to avoid this shader's build time takes too long (2^n)
    - we want to avoid rendering spike when a new shader variant was seen by the camera first time (create GPU program)
    - we want to avoid increasing ShaderVarientCollection's complexity
    - we want to avoid shader size becomes too large easily (2^n)
    - we want to avoid breaking SRP batcher's batching because SRP batcher is per shader variant batching, not per shader
    - all modern GPU(include newer mobile devices) can handle static uniform branching with "almost" no performance cost
*/
Shader "SimpleURPToonLitExample(With Outline)"
{
    Properties
    {
        [Header(High Level Setting)]
        [ToggleUI]_IsFace("Is Face? (please turn on if this is a face material)", Float) = 0

        // all properties will try to follow URP Lit shader's naming convention
        // so switching your URP lit material's shader to this toon lit shader will preserve most of the original properties if defined in this shader

        // for URP Lit shader's naming convention, see URP's Lit.shader
        [Header(Base Color)]
        [MainTexture]_BaseMap("_BaseMap (Albedo)", 2D) = "white" {}
        [HDR][MainColor]_BaseColor("_BaseColor", Color) = (1,1,1,1)

        [Header(Alpha)]
        [Toggle(_UseAlphaClipping)]_UseAlphaClipping("_UseAlphaClipping", Float) = 0
        _Cutoff("_Cutoff (Alpha Cutoff)", Range(0.0, 1.0)) = 0.5

        [Header(Emission)]
        [Toggle]_UseEmission("_UseEmission (on/off Emission completely)", Float) = 0
        [HDR] _EmissionColor("_EmissionColor", Color) = (0,0,0)
        _EmissionMulByBaseColor("_EmissionMulByBaseColor", Range(0,1)) = 0 //控制自发光颜色乘上albedo颜色（Base颜色）的程度
        [NoScaleOffset]_EmissionMap("_EmissionMap", 2D) = "white" {}
        _EmissionMapChannelMask("_EmissionMapChannelMask", Vector) = (1,1,1,0) //默认alpha通道的Mask是0

        [Header(Occlusion)] 
        //occlusion值是一个half（范围=[0,1]），目前会在ShadeGI（间接光照）和ShadeSingleLight（光源直接光照）中用到
        [Toggle]_UseOcclusion("_UseOcclusion (on/off Occlusion completely)", Float) = 0
        _OcclusionStrength("_OcclusionStrength", Range(0.0, 1.0)) = 1.0 // 在总体上（间接+直接光照）控制遮挡Occlusion的程度
        _OcclusionIndirectStrength("_OcclusionIndirectStrength", Range(0.0, 1.0)) = 0.5 // 在间接光照中控制控制遮挡Occlusion的程度
        _OcclusionDirectStrength("_OcclusionDirectStrength", Range(0.0, 1.0)) = 0.75 // 在直接光照中控制控制遮挡Occlusion的程度
        [NoScaleOffset]_OcclusionMap("_OcclusionMap", 2D) = "white" {} //遮挡贴图
        _OcclusionMapChannelMask("_OcclusionMapChannelMask", Vector) = (1,0,0,0) //默认只有R通道的Mask是1
        _OcclusionRemapStart("_OcclusionRemapStart", Range(0,1)) = 0
        _OcclusionRemapEnd("_OcclusionRemapEnd", Range(0,1)) = 1

        [Header(Lighting)]
        _IndirectLightMinColor("_IndirectLightMinColor", Color) = (0.1,0.1,0.1,1) // can prevent completely black if lightprobe not baked | 能够防止完全黑色如果光照探针没有烘焙
        _IndirectLightMultiplier("_IndirectLightMultiplier", Range(0,1)) = 1 //作为乘数修正间接光照
        _DirectLightMultiplier("_DirectLightMultiplier", Range(0,1)) = 1 //作为乘数修正直接光照
        _CelShadeMidPoint("_CelShadeMidPoint", Range(-1,1)) = -0.5 //用来控制明暗边界线出现的位置
        _CelShadeSoftness("_CelShadeSoftness", Range(0,1)) = 0.05 //用来控制明暗边界的柔和过渡程度
        _MainLightIgnoreCelShade("_MainLightIgnoreCelShade", Range(0,1)) = 0 //控制主光源忽略cel风格的明暗部结果的程度（比如可以让脸部更亮）
        _AdditionalLightIgnoreCelShade("_AdditionalLightIgnoreCelShade", Range(0,1)) = 0.8  //控制额外光源忽略cel风格的明暗部结果的程度（比如可以让脸部更亮）

        [Header(Lightmap)]
		[Toggle]_UseLightMap("_UseLightMap (on/off Custom Lightmap)", Float) = 0
		[NoScaleOffset]_LightMap("_LightMap", 2D) = "white" {}
        //[Header(ShadowColor)]
		_ShadowColor("_ShadowColor(Face sdf)", Color) = (0,0,0) //好像只是用来做面部阴影的

        [Header(Rim Light)]
        [Enum(off,0,RimLight,1,FakeSSS,2)]_UseRimLight("_UseRimLight", Float) = 0 //FakeSSS好像没有使用啊？
        [HDR]_RimColor("_RimColor (alpha to control strength)", Color) = (0.8, 0.8, 0.8, 0.5) //rgb通道控制边缘光颜色，a通道控制边缘光强度
        _RimMin ("RimMin", Range(0, 2)) = 0.8 //控制边缘光的范围
        _RimMax ("RimMax", Range(0, 2)) = 1 //控制边缘光的范围
        _RimSmooth ("RimSmooth", Range(0, 1)) = 1 //控制边缘光的软硬（_RimSmooth=1时，smoothstep(0, 1, rim)≈rim，_RimSmooth=0时，smoothstep(0, 0, rim)=1）
        [NoScaleOffset]_MaskMap("_MaskMap (G: rim lgiht)", 2D) = "white" {} //遮罩贴图
        _RimMaskStrength("_RimMaskStrength", Range(0.0, 1.0)) = 1.0 // 控制遮罩的程度
        _RimInstensity("_RimInstensity", Range(0.0, 1.0)) = 1.0 // 控制边缘光的强度
        //_FresnelEff("_FresnelEff", Range(0, 1)) = 1 //控制菲涅尔边缘光强度
        //-------------------------------------new-------------------------------------
        // TODO: rampTexture 渐变纹理 ？

        
        [Header(Specular)]
        //TODO

        [Header(Normal map)]
        //TODO

        [Header(Roughness)]
        //TODO

        [Header(Shadow mapping)]
        _ReceiveShadowMappingAmount("_ReceiveShadowMappingAmount", Range(0,1)) = 0.65 // 用来控制应用阴影衰减的程度（=0时没有阴影？）
        _ReceiveShadowMappingPosOffset("_ReceiveShadowMappingPosOffset (increase it if is face!)", Float) = 0 //increase it if is face! //？？？？？？
        _ShadowMapColor("_ShadowMapColor", Color) = (1,0.825,0.78) // 用来控制阴影的颜色 //NoirRC不用了？

        [Header(Outline)]
        _OutlineWidth("_OutlineWidth (World Space)", Range(0,5)) = 1
        _OutlineColor("_OutlineColor", Color) = (0.5,0.5,0.5,1) // 用来控制outline的颜色，会把计算得到的这个地方（片元）原本的color乘上这个_OutlineColor
        _OutlineZOffset("_OutlineZOffset (View Space) (increase it if is face!)", Range(0,1)) = 0.0001 //increase it if is face! // 用于控制outline的Z偏移，和下面的_OutlineZOffsetMaskTex一起使用
        [NoScaleOffset]_OutlineZOffsetMaskTex("_OutlineZOffsetMask (black is apply ZOffset)", 2D) = "black" {} // 用于控制outline Z偏移的程度的贴图（似乎是黑色表示不Z偏移），和上面的_OutlineZOffset一起使用
        _OutlineZOffsetMaskRemapStart("_OutlineZOffsetMaskRemapStart", Range(0,1)) = 0
        _OutlineZOffsetMaskRemapEnd("_OutlineZOffsetMaskRemapEnd", Range(0,1)) = 1
    }
    SubShader
    {       
        Tags 
        {
            // SRP introduced a new "RenderPipeline" tag in Subshader. This allows you to create shaders
            // that can match multiple render pipelines. If a RenderPipeline tag is not set it will match
            // any render pipeline. In case you want your subshader to only run in URP, set the tag to
            // "UniversalPipeline"

            // here "UniversalPipeline" tag is required, because we only want this shader to run in URP.
            // If Universal render pipeline is not set in the graphics settings, this Subshader will fail.

            // One can add a subshader below or fallback to Standard built-in to make this
            // material work with both Universal Render Pipeline and Builtin Unity Pipeline

            // the tag value is "UniversalPipeline", not "UniversalRenderPipeline", be careful!
            // https://github.com/Unity-Technologies/Graphics/pull/1431/
            "RenderPipeline" = "UniversalPipeline"

            // explict SubShader tag to avoid confusion
            "RenderType"="Opaque"
            "UniversalMaterialType" = "Lit"
            "Queue"="Geometry"
            //"IgnoreProjector" = "False" 
            //"ShaderModel"="4.5"
        }
        //LOD 300

        // We can extract duplicated hlsl code from all passes into this HLSLINCLUDE section. Less duplicated code = Less error
        HLSLINCLUDE

        // all Passes will need this keyword
        #pragma shader_feature_local_fragment _UseAlphaClipping

        ENDHLSL

        // [#0 Pass - ForwardLit]
        // Shades GI, all lights, emission and fog in a single pass.
        // Compared to Builtin pipeline forward renderer, URP forward renderer will
        // render a scene with multiple lights with less drawcalls and less overdraw.
        Pass
        {               
            Name "ForwardLit"
            Tags
            {
                // "Lightmode" matches the "ShaderPassName" set in UniversalRenderPipeline.cs. 
                // SRPDefaultUnlit and passes with no LightMode tag are also rendered by Universal Render Pipeline

                // "Lightmode" tag must be "UniversalForward" in order to render lit objects in URP.
                "LightMode" = "UniversalForward"
            }

            // explict render state to avoid confusion
            // you can expose these render state to material inspector if needed (see URP's Lit.shader)
            /* 
            //可以像URP Lit.shader那样在Properties中增加：
            [HideInInspector] _SrcBlend("__src", Float) = 1.0
            [HideInInspector] _DstBlend("__dst", Float) = 0.0
            [HideInInspector] _ZWrite("__zw", Float) = 1.0
            [HideInInspector] _Cull("__cull", Float) = 2.0
            //然后在这里使用：
            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull[_Cull]
            //不过感觉没什么意义
            */
            Cull Back
            ZTest LEqual
            ZWrite On
            Blend One Zero //相当于Blend Off

            HLSLPROGRAM

            // ---------------------------------------------------------------------------------------------
            // Universal Render Pipeline keywords (you can always copy this section from URP's Lit.shader)
            // | 你总是可以从URP的Lit Shader拷贝这部分 // 但是只有ForwardLit和Outline和GBuffer Pass需要这些指令
            // When doing custom shaders you most often want to copy and paste these #pragmas
            // These multi_compile variants are stripped from the build depending on:
            // 1) Settings in the URP Asset assigned in the GraphicsSettings at build time
            // e.g If you disabled AdditionalLights in the asset then all _ADDITIONA_LIGHTS variants
            // will be stripped from build
            // 2) Invalid combinations are stripped. e.g variants with _MAIN_LIGHT_SHADOWS_CASCADE
            // but not _MAIN_LIGHT_SHADOWS are invalid and therefore stripped.
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            //#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION 
            //#pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            //#pragma multi_compile _ SHADOWS_SHADOWMASK
            // 5个关键字声明分别是：？？？？？？
            // 主光源阴影，该段关键字是会自己再定义一个MAIN_LIGHT_CALCULATE_SHADOWS，用于在MainLightRealtimeShadow(float4 shadowCoord)函数里计算得到正确的阴影衰减，是必须内容。
            // 主光源层级阴影是否开启，该关键字是为了让函数TransformWorldToShadowCoord(float3 positionWS)得到正确的阴影坐标，是必须内容。
            // 开启额外光源，_ADDITIONAL_LIGHTS_VERTEX会在顶点着色器计算额外光照，光照模型是Lambert。_ADDITIONAL_LIGHTS会在片元着色器计算额外光照，光照模型是简易的PBR。？？？
            // 额外光源阴影，该关键字是为了函数AdditionalLightRealtimeShadow(int lightIndex, float3 positionWS)得到正确的阴影衰减，是必须内容。
            // 开启软阴影


            // ---------------------------------------------------------------------------------------------
            // Unity defined keywords
            //#pragma multi_compile _ DIRLIGHTMAP_COMBINED
            //#pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

            // ---------------------------------------------------------------------------------------------
            // GPU Instancing
            //#pragma multi_compile_instancing
            //#pragma multi_compile _ DOTS_INSTANCING_ON

            #pragma vertex VertexShaderWork
            #pragma fragment ShadeFinalColor

            // because this pass is just a ForwardLit pass, no need any special #define
            // (no special #define)

            // all shader logic written inside this .hlsl, remember to write all #define BEFORE writing #include
            #include "SimpleURPToonLitOutlineExample_Shared.hlsl"

            ENDHLSL
        }
        
        // [#1 Pass - Outline]
        // Same as the above "ForwardLit" pass, but 
        // -vertex position are pushed out a bit base on normal direction
        // -also color is tinted
        // -Cull Front instead of Cull Back because Cull Front is a must for all extra pass outline method
        Pass 
        {
            Name "Outline"
            Tags 
            {
                // IMPORTANT: don't write this line for any custom pass! else this outline pass will not be rendered by URP!
                //"LightMode" = "UniversalForward" 

                // [Important CPU performance note]
                // If you need to add a custom pass to your shader (outline pass, planar shadow pass, XRay pass when blocked....),
                // (0) Add a new Pass{} to your shader
                // (1) Write "LightMode" = "YourCustomPassTag" inside new Pass's Tags{}
                // (2) Add a new custom RendererFeature(C#) to your renderer,
                // (3) write cmd.DrawRenderers() with ShaderPassName = "YourCustomPassTag"
                // (4) if done correctly, URP will render your new Pass{} for your shader, in a SRP-batcher friendly way (usually in 1 big SRP batch)

                // For tutorial purpose, current everything is just shader files without any C#, so this Outline pass is actually NOT SRP-batcher friendly.
                // If you are working on a project with lots of characters, make sure you use the above method to make Outline pass SRP-batcher friendly!
            }

            Cull Front // Cull Front is a must for extra pass outline method

            HLSLPROGRAM

            // Direct copy all keywords from "ForwardLit" pass
            // ---------------------------------------------------------------------------------------------
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            // ---------------------------------------------------------------------------------------------
            #pragma multi_compile_fog
            // ---------------------------------------------------------------------------------------------

            #pragma vertex VertexShaderWork
            #pragma fragment ShadeFinalColor

            // because this is an Outline pass, define "ToonShaderIsOutline" to inject outline related code into both VertexShaderWork() and ShadeFinalColor()
            #define ToonShaderIsOutline

            // all shader logic written inside this .hlsl, remember to write all #define BEFORE writing #include
            #include "SimpleURPToonLitOutlineExample_Shared.hlsl"

            ENDHLSL
        }
 
        // ShadowCaster pass. Used for rendering URP's shadowmaps
        // 把物体的深度信息渲染到 光源的阴影映射纹理(shadowmap) 
        // 至于摄像机的深度纹理(CameraDepthTexture)是不是已经移到DepthOnly Pass中了？？？？？？
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            // more explict render state to avoid confusion
            ZWrite On // the only goal of this pass is to write depth! | ShadowCaster pass唯一的目标就是深度写入
            ZTest LEqual // early exit at Early-Z stage if possible            
            ColorMask 0 // we don't care about color, we just want to write depth, ColorMask 0 will save some write bandwidth | 我们不关心颜色，我们只想深度写入，ColorMask 0将节省一些写带宽
            Cull Back // support Cull[_Cull] requires "flip vertex normal" using VFACE in fragment shader, which is maybe beyond the scope of a simple tutorial shader
                      // | 支持Cull[_Cull]需要在片段着色器中使用 VFACE“翻转顶点法线”，这可能超出了简单的教程着色器的范围 ？？？？？？？？？ // TODO

            HLSLPROGRAM

            // the only keywords we need in this pass = _UseAlphaClipping, which is already defined inside the HLSLINCLUDE block
            // (so no need to write any multi_compile or shader_feature in this pass)
            // | 这个pass中我们需要的唯一关键字 = _UseAlphaClipping，它已经在 HLSLINCLUDE 块中定义了 (所以在这个过程中不需要编写任何 multi_compile 或 shader_feature)

            #pragma vertex VertexShaderWork
            #pragma fragment BaseColorAlphaClipTest // we only need to do Clip(), no need shading
                                                    // 只是做 透明度测试 ，没有其他任何工作

            // because it is a ShadowCaster pass, define "ToonShaderApplyShadowBiasFix" to inject "remove shadow mapping artifact" code into VertexShaderWork()
            // 由于这是一个ShadowCaster pass，定义一个宏，将“移除阴影映射工件（？？？）”代码注入顶点着色器VertexShaderWork()中
            #define ToonShaderApplyShadowBiasFix

            // all shader logic written inside this .hlsl, remember to write all #define BEFORE writing #include
            #include "SimpleURPToonLitOutlineExample_Shared.hlsl"

            ENDHLSL
        }
        
        //TODO: 增加GBuffer pass
        /*
        Pass
        {
            // Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Universal Render Pipeline
            Name "GBuffer"
            Tags{"LightMode" = "UniversalGBuffer"}

            //...
        }
        */

        // DepthOnly pass. Used for rendering URP's offscreen depth prepass (you can search DepthOnlyPass.cs in URP package)
        // For example, when depth texture is on, we need to perform this offscreen depth prepass for this toon shader. 
        // | DepthOnly Pass，用于渲染 URP 的offscreen depth prepass ？？？？？？（可以搜索URP包中的DepthOnlyPass.cs）
        // 例如，当深度纹理打开时，我们需要为这个 toon 着色器执行offscreen depth prepass。
        //
        // 猜测：把物体的深度信息渲染到RenderTarget（默认为摄像机的深度纹理(CameraDepthTexture)）中  （取决于是否使用屏幕空间的阴影映射技术Screenspace Shadow Map？？？）
        //
        // DepthOnly Pass 仅渲染深度。目的是提前处理深度信息，从而起到减少重复绘制（OverDraw）的作用。
        // 在默认的最简渲染流程下，这个Pass是不执行的。而当诸如全屏后处理等特性被启用时？（camera的depth texture设为On时），这个Pass会被加入渲染流程中，导致DrawCall增加。
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            // more explict render state to avoid confusion
            ZWrite On // the only goal of this pass is to write depth! | DepthOnly pass唯一的目标就是深度写入
            ZTest LEqual // early exit at Early-Z stage if possible            
            ColorMask 0 // we don't care about color, we just want to write depth, ColorMask 0 will save some write bandwidth | 我们不关心颜色，我们只想深度写入，ColorMask 0将节省一些写带宽
            Cull Back // support Cull[_Cull] requires "flip vertex normal" using VFACE in fragment shader, which is maybe beyond the scope of a simple tutorial shader
                      // | 支持Cull[_Cull]需要在片段着色器中使用 VFACE“翻转顶点法线”，这可能超出了简单的教程着色器的范围 ？？？？？？？？？ // TODO

            HLSLPROGRAM

            // the only keywords we need in this pass = _UseAlphaClipping, which is already defined inside the HLSLINCLUDE block
            // (so no need to write any multi_compile or shader_feature in this pass)
            // | 这个pass中我们需要的唯一关键字 = _UseAlphaClipping，它已经在 HLSLINCLUDE 块中定义了 (所以在这个过程中不需要编写任何 multi_compile 或 shader_feature)

            #pragma vertex VertexShaderWork
            #pragma fragment BaseColorAlphaClipTest // we only need to do Clip(), no need color shading
                                                    // 只是做 透明度测试 ，没有其他任何工作

            // because Outline area should write to depth also, define "ToonShaderIsOutline" to inject outline related code into VertexShaderWork()
            // | 因为 Outline 区域也应该深度写入，所以定义这个宏，将outline相关代码注入到 顶点着色器VertexShaderWork()中
            #define ToonShaderIsOutline

            // all shader logic written inside this .hlsl, remember to write all #define BEFORE writing #include
            #include "SimpleURPToonLitOutlineExample_Shared.hlsl"

            ENDHLSL
        }

        // Starting from version 10.0.x, URP can generate a normal texture called _CameraNormalsTexture. | 从10.0.x 版本开始，URP 可以生成一个称为 _CameraNormalsTexture 的法线纹理。
        // To render to this texture in your custom shader, add a Pass with the name DepthNormals. | 要在自定义着色器中渲染这个纹理，添加一个名为 DepthNormals 的 Pass。
        // For example, see the implementation in Lit.shader. | 例子，请参见 Lit.shader 中的实现。
        // TODO: DepthNormals pass (see URP's Lit.shader) | TODO: DepthNormals Pass (参见 URP 的 Lit.shader)
        /*
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            //...
        }
        */

        //TODO: 增加Meta pass
        /*
        // This pass it not used during regular rendering, only for lightmap baking.
        Pass
        {
            Name "Meta"
            Tags{"LightMode" = "Meta"}

            //...
        }
        */

        /*这个Universal2D Pass就不需要了
        Pass
        {
            Name "Universal2D"
            Tags{ "LightMode" = "Universal2D" }

            //...
        }
        */
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError" //也可以添加一个SubShader或FallBack使该着色器能在builtin-pipeline下工作，不过这里定位为只支持URP
    //TODO: 增加CustomEditor改变GUI
}
