// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

#ifndef Include_NiloZOffset
#define Include_NiloZOffset

// Push an imaginary vertex towards camera in view space (linear, view space unit), 
// then only overwrite original positionCS.z using imaginary vertex's result positionCS.z value
// Will only affect ZTest ZWrite's depth value of vertex shader

// Useful for:
// -Hide ugly outline on face/eye
// -Make eyebrow render on top of hair
// -Solve ZFighting issue without moving geometry
// 关于在头发上渲染眉毛 （TODO）
// 通常有2种方法。方法1:第一个Pass ZTEST LEqual，第二Pass ZTEST GEqual。方法2：模板测试。https://zhuanlan.zhihu.com/p/129291888 https://zhuanlan.zhihu.com/p/163791090
// ------------------------------------------------------------------------------------------
// 总结：ZOffset方法，让裁剪空间的Z值沿着摄像机的Z偏移，常用于隐藏面部/眼睛上的难看的outline。
// ZOffset顾名思义就是在ViewSpace下沿Z方向远离相机的方向推一段距离，使正面能盖住背面外扩的部分，ZOffset值越大描边越不可见。
float4 NiloGetNewClipPosWithZOffset(float4 originalPositionCS, float viewSpaceZOffsetAmount)
{
    if(unity_OrthoParams.w == 0)
    {
        ////////////////////////////////
        //Perspective camera case | 透视相机
        ////////////////////////////////
        float2 ProjM_ZRow_ZW = UNITY_MATRIX_P[2].zw;
        float modifiedPositionVS_Z = -originalPositionCS.w + -viewSpaceZOffsetAmount; // push imaginary vertex //在ViewSpace做Z方向的推移，因为这时的推的距离是可控的
        float modifiedPositionCS_Z = modifiedPositionVS_Z * ProjM_ZRow_ZW[0] + ProjM_ZRow_ZW[1];
        originalPositionCS.z = modifiedPositionCS_Z * originalPositionCS.w / (-modifiedPositionVS_Z); // overwrite positionCS.z
        return originalPositionCS;    
    }
    else
    {
        ////////////////////////////////
        //Orthographic camera case | 正交相机
        ////////////////////////////////
        originalPositionCS.z += -viewSpaceZOffsetAmount / _ProjectionParams.z; // push imaginary vertex and overwrite positionCS.z
        return originalPositionCS;
    }
}

#endif

