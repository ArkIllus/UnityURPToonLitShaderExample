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
        _EmissionMulByBaseColor("_EmissionMulByBaseColor", Range(0,1)) = 0 //�����Է�����ɫ����albedo��ɫ��Base��ɫ���ĳ̶�
        [NoScaleOffset]_EmissionMap("_EmissionMap", 2D) = "white" {}
        _EmissionMapChannelMask("_EmissionMapChannelMask", Vector) = (1,1,1,0) //Ĭ��alphaͨ����Mask��0

        [Header(Occlusion)] 
        //occlusionֵ��һ��half����Χ=[0,1]����Ŀǰ����ShadeGI����ӹ��գ���ShadeSingleLight����Դֱ�ӹ��գ����õ�
        [Toggle]_UseOcclusion("_UseOcclusion (on/off Occlusion completely)", Float) = 0
        _OcclusionStrength("_OcclusionStrength", Range(0.0, 1.0)) = 1.0 // �������ϣ����+ֱ�ӹ��գ������ڵ�Occlusion�ĳ̶�
        _OcclusionIndirectStrength("_OcclusionIndirectStrength", Range(0.0, 1.0)) = 0.5 // �ڼ�ӹ����п��ƿ����ڵ�Occlusion�ĳ̶�
        _OcclusionDirectStrength("_OcclusionDirectStrength", Range(0.0, 1.0)) = 0.75 // ��ֱ�ӹ����п��ƿ����ڵ�Occlusion�ĳ̶�
        [NoScaleOffset]_OcclusionMap("_OcclusionMap", 2D) = "white" {} //�ڵ���ͼ
        _OcclusionMapChannelMask("_OcclusionMapChannelMask", Vector) = (1,0,0,0) //Ĭ��ֻ��Rͨ����Mask��1
        _OcclusionRemapStart("_OcclusionRemapStart", Range(0,1)) = 0
        _OcclusionRemapEnd("_OcclusionRemapEnd", Range(0,1)) = 1

        [Header(Lighting)]
        _IndirectLightMinColor("_IndirectLightMinColor", Color) = (0.1,0.1,0.1,1) // can prevent completely black if lightprobe not baked | �ܹ���ֹ��ȫ��ɫ�������̽��û�к決
        _IndirectLightMultiplier("_IndirectLightMultiplier", Range(0,1)) = 1 //��Ϊ����������ӹ���
        _DirectLightMultiplier("_DirectLightMultiplier", Range(0,1)) = 1 //��Ϊ��������ֱ�ӹ���
        _CelShadeMidPoint("_CelShadeMidPoint", Range(-1,1)) = -0.5 //�������������߽��߳��ֵ�λ��
        _CelShadeSoftness("_CelShadeSoftness", Range(0,1)) = 0.05 //�������������߽����͹��ɳ̶�
        _MainLightIgnoreCelShade("_MainLightIgnoreCelShade", Range(0,1)) = 0 //��������Դ����cel��������������ĳ̶ȣ��������������������
        _AdditionalLightIgnoreCelShade("_AdditionalLightIgnoreCelShade", Range(0,1)) = 0.8  //���ƶ����Դ����cel��������������ĳ̶ȣ��������������������

        [Header(Lightmap)]
		[Toggle]_UseLightMap("_UseLightMap (on/off Custom Lightmap)", Float) = 0
		[NoScaleOffset]_LightMap("_LightMap", 2D) = "white" {}
        //[Header(ShadowColor)]
		_ShadowColor("_ShadowColor(Face sdf)", Color) = (0,0,0) //����ֻ���������沿��Ӱ��

        [Header(Rim Light)]
        [Enum(off,0,RimLight,1,FakeSSS,2)]_UseRimLight("_UseRimLight", Float) = 0 //FakeSSS����û��ʹ�ð���
        [HDR]_RimColor("_RimColor (alpha to control strength)", Color) = (0.8, 0.8, 0.8, 0.5) //rgbͨ�����Ʊ�Ե����ɫ��aͨ�����Ʊ�Ե��ǿ��
        _RimMin ("RimMin", Range(0, 2)) = 0.8 //���Ʊ�Ե��ķ�Χ
        _RimMax ("RimMax", Range(0, 2)) = 1 //���Ʊ�Ե��ķ�Χ
        _RimSmooth ("RimSmooth", Range(0, 1)) = 1 //���Ʊ�Ե�����Ӳ��_RimSmooth=1ʱ��smoothstep(0, 1, rim)��rim��_RimSmooth=0ʱ��smoothstep(0, 0, rim)=1��
        [NoScaleOffset]_MaskMap("_MaskMap (G: rim lgiht)", 2D) = "white" {} //������ͼ
        _RimMaskStrength("_RimMaskStrength", Range(0.0, 1.0)) = 1.0 // �������ֵĳ̶�
        _RimInstensity("_RimInstensity", Range(0.0, 1.0)) = 1.0 // ���Ʊ�Ե���ǿ��
        //_FresnelEff("_FresnelEff", Range(0, 1)) = 1 //���Ʒ�������Ե��ǿ��
        //-------------------------------------new-------------------------------------
        // TODO: rampTexture �������� ��

        
        [Header(Specular)]
        //TODO

        [Header(Normal map)]
        //TODO

        [Header(Roughness)]
        //TODO

        [Header(Shadow mapping)]
        _ReceiveShadowMappingAmount("_ReceiveShadowMappingAmount", Range(0,1)) = 0.65 // ��������Ӧ����Ӱ˥���ĳ̶ȣ�=0ʱû����Ӱ����
        _ReceiveShadowMappingPosOffset("_ReceiveShadowMappingPosOffset (increase it if is face!)", Float) = 0 //increase it if is face! //������������
        _ShadowMapColor("_ShadowMapColor", Color) = (1,0.825,0.78) // ����������Ӱ����ɫ //NoirRC�����ˣ�

        [Header(Outline)]
        _OutlineWidth("_OutlineWidth (World Space)", Range(0,5)) = 1
        _OutlineColor("_OutlineColor", Color) = (0.5,0.5,0.5,1) // ��������outline����ɫ����Ѽ���õ�������ط���ƬԪ��ԭ����color�������_OutlineColor
        _OutlineZOffset("_OutlineZOffset (View Space) (increase it if is face!)", Range(0,1)) = 0.0001 //increase it if is face! // ���ڿ���outline��Zƫ�ƣ��������_OutlineZOffsetMaskTexһ��ʹ��
        [NoScaleOffset]_OutlineZOffsetMaskTex("_OutlineZOffsetMask (black is apply ZOffset)", 2D) = "black" {} // ���ڿ���outline Zƫ�Ƶĳ̶ȵ���ͼ���ƺ��Ǻ�ɫ��ʾ��Zƫ�ƣ����������_OutlineZOffsetһ��ʹ��
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
            //������URP Lit.shader������Properties�����ӣ�
            [HideInInspector] _SrcBlend("__src", Float) = 1.0
            [HideInInspector] _DstBlend("__dst", Float) = 0.0
            [HideInInspector] _ZWrite("__zw", Float) = 1.0
            [HideInInspector] _Cull("__cull", Float) = 2.0
            //Ȼ��������ʹ�ã�
            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull[_Cull]
            //�����о�ûʲô����
            */
            Cull Back
            ZTest LEqual
            ZWrite On
            Blend One Zero //�൱��Blend Off

            HLSLPROGRAM

            // ---------------------------------------------------------------------------------------------
            // Universal Render Pipeline keywords (you can always copy this section from URP's Lit.shader)
            // | �����ǿ��Դ�URP��Lit Shader�����ⲿ�� // ����ֻ��ForwardLit��Outline��GBuffer Pass��Ҫ��Щָ��
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
            // 5���ؼ��������ֱ��ǣ�������������
            // ����Դ��Ӱ���öιؼ����ǻ��Լ��ٶ���һ��MAIN_LIGHT_CALCULATE_SHADOWS��������MainLightRealtimeShadow(float4 shadowCoord)���������õ���ȷ����Ӱ˥�����Ǳ������ݡ�
            // ����Դ�㼶��Ӱ�Ƿ������ùؼ�����Ϊ���ú���TransformWorldToShadowCoord(float3 positionWS)�õ���ȷ����Ӱ���꣬�Ǳ������ݡ�
            // ���������Դ��_ADDITIONAL_LIGHTS_VERTEX���ڶ�����ɫ�����������գ�����ģ����Lambert��_ADDITIONAL_LIGHTS����ƬԪ��ɫ�����������գ�����ģ���Ǽ��׵�PBR��������
            // �����Դ��Ӱ���ùؼ�����Ϊ�˺���AdditionalLightRealtimeShadow(int lightIndex, float3 positionWS)�õ���ȷ����Ӱ˥�����Ǳ������ݡ�
            // ��������Ӱ


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
        // ������������Ϣ��Ⱦ�� ��Դ����Ӱӳ������(shadowmap) 
        // ������������������(CameraDepthTexture)�ǲ����Ѿ��Ƶ�DepthOnly Pass���ˣ�����������
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            // more explict render state to avoid confusion
            ZWrite On // the only goal of this pass is to write depth! | ShadowCaster passΨһ��Ŀ��������д��
            ZTest LEqual // early exit at Early-Z stage if possible            
            ColorMask 0 // we don't care about color, we just want to write depth, ColorMask 0 will save some write bandwidth | ���ǲ�������ɫ������ֻ�����д�룬ColorMask 0����ʡһЩд����
            Cull Back // support Cull[_Cull] requires "flip vertex normal" using VFACE in fragment shader, which is maybe beyond the scope of a simple tutorial shader
                      // | ֧��Cull[_Cull]��Ҫ��Ƭ����ɫ����ʹ�� VFACE����ת���㷨�ߡ�������ܳ����˼򵥵Ľ̳���ɫ���ķ�Χ ������������������ // TODO

            HLSLPROGRAM

            // the only keywords we need in this pass = _UseAlphaClipping, which is already defined inside the HLSLINCLUDE block
            // (so no need to write any multi_compile or shader_feature in this pass)
            // | ���pass��������Ҫ��Ψһ�ؼ��� = _UseAlphaClipping�����Ѿ��� HLSLINCLUDE ���ж����� (��������������в���Ҫ��д�κ� multi_compile �� shader_feature)

            #pragma vertex VertexShaderWork
            #pragma fragment BaseColorAlphaClipTest // we only need to do Clip(), no need shading
                                                    // ֻ���� ͸���Ȳ��� ��û�������κι���

            // because it is a ShadowCaster pass, define "ToonShaderApplyShadowBiasFix" to inject "remove shadow mapping artifact" code into VertexShaderWork()
            // ��������һ��ShadowCaster pass������һ���꣬�����Ƴ���Ӱӳ�乤������������������ע�붥����ɫ��VertexShaderWork()��
            #define ToonShaderApplyShadowBiasFix

            // all shader logic written inside this .hlsl, remember to write all #define BEFORE writing #include
            #include "SimpleURPToonLitOutlineExample_Shared.hlsl"

            ENDHLSL
        }
        
        //TODO: ����GBuffer pass
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
        // | DepthOnly Pass��������Ⱦ URP ��offscreen depth prepass ����������������������URP���е�DepthOnlyPass.cs��
        // ���磬����������ʱ��������ҪΪ��� toon ��ɫ��ִ��offscreen depth prepass��
        //
        // �²⣺������������Ϣ��Ⱦ��RenderTarget��Ĭ��Ϊ��������������(CameraDepthTexture)����  ��ȡ�����Ƿ�ʹ����Ļ�ռ����Ӱӳ�似��Screenspace Shadow Map��������
        //
        // DepthOnly Pass ����Ⱦ��ȡ�Ŀ������ǰ���������Ϣ���Ӷ��𵽼����ظ����ƣ�OverDraw�������á�
        // ��Ĭ�ϵ������Ⱦ�����£����Pass�ǲ�ִ�еġ���������ȫ����������Ա�����ʱ����camera��depth texture��ΪOnʱ�������Pass�ᱻ������Ⱦ�����У�����DrawCall���ӡ�
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            // more explict render state to avoid confusion
            ZWrite On // the only goal of this pass is to write depth! | DepthOnly passΨһ��Ŀ��������д��
            ZTest LEqual // early exit at Early-Z stage if possible            
            ColorMask 0 // we don't care about color, we just want to write depth, ColorMask 0 will save some write bandwidth | ���ǲ�������ɫ������ֻ�����д�룬ColorMask 0����ʡһЩд����
            Cull Back // support Cull[_Cull] requires "flip vertex normal" using VFACE in fragment shader, which is maybe beyond the scope of a simple tutorial shader
                      // | ֧��Cull[_Cull]��Ҫ��Ƭ����ɫ����ʹ�� VFACE����ת���㷨�ߡ�������ܳ����˼򵥵Ľ̳���ɫ���ķ�Χ ������������������ // TODO

            HLSLPROGRAM

            // the only keywords we need in this pass = _UseAlphaClipping, which is already defined inside the HLSLINCLUDE block
            // (so no need to write any multi_compile or shader_feature in this pass)
            // | ���pass��������Ҫ��Ψһ�ؼ��� = _UseAlphaClipping�����Ѿ��� HLSLINCLUDE ���ж����� (��������������в���Ҫ��д�κ� multi_compile �� shader_feature)

            #pragma vertex VertexShaderWork
            #pragma fragment BaseColorAlphaClipTest // we only need to do Clip(), no need color shading
                                                    // ֻ���� ͸���Ȳ��� ��û�������κι���

            // because Outline area should write to depth also, define "ToonShaderIsOutline" to inject outline related code into VertexShaderWork()
            // | ��Ϊ Outline ����ҲӦ�����д�룬���Զ�������꣬��outline��ش���ע�뵽 ������ɫ��VertexShaderWork()��
            #define ToonShaderIsOutline

            // all shader logic written inside this .hlsl, remember to write all #define BEFORE writing #include
            #include "SimpleURPToonLitOutlineExample_Shared.hlsl"

            ENDHLSL
        }

        // Starting from version 10.0.x, URP can generate a normal texture called _CameraNormalsTexture. | ��10.0.x �汾��ʼ��URP ��������һ����Ϊ _CameraNormalsTexture �ķ�������
        // To render to this texture in your custom shader, add a Pass with the name DepthNormals. | Ҫ���Զ�����ɫ������Ⱦ����������һ����Ϊ DepthNormals �� Pass��
        // For example, see the implementation in Lit.shader. | ���ӣ���μ� Lit.shader �е�ʵ�֡�
        // TODO: DepthNormals pass (see URP's Lit.shader) | TODO: DepthNormals Pass (�μ� URP �� Lit.shader)
        /*
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            //...
        }
        */

        //TODO: ����Meta pass
        /*
        // This pass it not used during regular rendering, only for lightmap baking.
        Pass
        {
            Name "Meta"
            Tags{"LightMode" = "Meta"}

            //...
        }
        */

        /*���Universal2D Pass�Ͳ���Ҫ��
        Pass
        {
            Name "Universal2D"
            Tags{ "LightMode" = "Universal2D" }

            //...
        }
        */
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError" //Ҳ�������һ��SubShader��FallBackʹ����ɫ������builtin-pipeline�¹������������ﶨλΪֻ֧��URP
    //TODO: ����CustomEditor�ı�GUI
}
