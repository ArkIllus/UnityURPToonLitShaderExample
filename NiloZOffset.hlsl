// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

#ifndef Include_NiloZOffset
#define Include_NiloZOffset

// Push an imaginary vertex towards camera in view space (linear, view space unit), 
// then only overwrite original positionCS.z using imaginary vertex's result positionCS.z value
// Will only affect ZTest ZWrite's depth value of vertex shader
// | �ڹ۲�ռ䣨���ԣ��۲�ռ䵥Ԫ���н�һ�����붥������������ƶ��� 
// Ȼ��ֻʹ�ü��붥��Ľ�� positionCS.z ֵ����ԭʼ positionCS.z
// ֻ��Ӱ�� ZTest ZWrite �Ķ�����ɫ�������ֵ ������������

// Useful for:
// -Hide ugly outline on face/eye
// -Make eyebrow render on top of hair
// -Solve ZFighting issue without moving geometry
// | ZOffset���ô���
// - �����沿/�۾��ϵ��ѿ���outline
// - ��ͷ������Ⱦüë ��TODO��
// - �ڲ��ƶ������������½�� ZFighting ���� ������
//
// ***�ܽ᣺ZOffset�������òü��ռ��Zֵ�����������Zƫ�ƣ������������沿/�۾��ϵ��ѿ���outline��
// ZOffset����˼�������ViewSpace����Z����Զ������ķ�����һ�ξ��룬ʹ�����ܸ�ס���������Ĳ��֣�ZOffsetֵԽ�����Խ���ɼ���
float4 NiloGetNewClipPosWithZOffset(float4 originalPositionCS, float viewSpaceZOffsetAmount)
{
    if(unity_OrthoParams.w == 0)
    {
        ////////////////////////////////
        //Perspective camera case | ͸�����
        ////////////////////////////////
        float2 ProjM_ZRow_ZW = UNITY_MATRIX_P[2].zw;
        float modifiedPositionVS_Z = -originalPositionCS.w + -viewSpaceZOffsetAmount; // push imaginary vertex //��ViewSpace��Z��������ƣ���Ϊ��ʱ���Ƶľ����ǿɿص�
        float modifiedPositionCS_Z = modifiedPositionVS_Z * ProjM_ZRow_ZW[0] + ProjM_ZRow_ZW[1];
        originalPositionCS.z = modifiedPositionCS_Z * originalPositionCS.w / (-modifiedPositionVS_Z); // overwrite positionCS.z
        return originalPositionCS;    
    }
    else
    {
        ////////////////////////////////
        //Orthographic camera case | �������
        ////////////////////////////////
        originalPositionCS.z += -viewSpaceZOffsetAmount / _ProjectionParams.z; // push imaginary vertex and overwrite positionCS.z
        return originalPositionCS;
    }
}

#endif

