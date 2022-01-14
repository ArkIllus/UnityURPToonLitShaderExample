// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

#ifndef Include_NiloZOffset
#define Include_NiloZOffset

// Push an imaginary vertex towards camera in view space (linear, view space unit), 
// then only overwrite original positionCS.z using imaginary vertex's result positionCS.z value
// Will only affect ZTest ZWrite's depth value of vertex shader
// | 在观察空间（线性，观察空间单元）中将一个假想顶点往相机方向推动， 
// 然后只使用假想顶点的结果 positionCS.z 值覆盖原始 positionCS.z
// 只会影响 ZTest ZWrite 的顶点着色器的深度值 ？？？？？？

// Useful for:
// -Hide ugly outline on face/eye
// -Make eyebrow render on top of hair
// -Solve ZFighting issue without moving geometry
// | ZOffset的用处：
// - 隐藏面部/眼睛上的难看的outline
// - 在头发上渲染眉毛 （TODO）
// - 在不移动几何体的情况下解决 ZFighting 问题 ？？？
//
// ***总结：ZOffset方法，让裁剪空间的Z值沿着摄像机的Z偏移，常用于隐藏面部/眼睛上的难看的outline。
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

