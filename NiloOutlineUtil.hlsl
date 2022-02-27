// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

#ifndef Include_NiloOutlineUtil
#define Include_NiloOutlineUtil

// TODO����������˵�ģ������и����ٵĻ��������FOV�ķ���
// If your project has a faster way to get camera fov in shader, you can replace this slow function to your method.
// For example, you write cmd.SetGlobalFloat("_CurrentCameraFOV",cameraFOV) using a new RendererFeature in C#.
// For this tutorial shader, we will keep things simple and use this slower but convenient method to get camera fov
float GetCameraFOV()
{
    //https://answers.unity.com/questions/770838/how-can-i-extract-the-fov-information-from-the-pro.html
    float t = unity_CameraProjection._m11;
    //t = unity_CameraProjection._m11 = 2.0F * near / (top - bottom);
    float Rad2Deg = 180 / 3.1415;
    float fov = atan(1.0f / t) * 2.0 * Rad2Deg;
    return fov; //����ֵ�ǽǶ��Ƶ�fovY
}

float ApplyOutlineDistanceFadeOut(float inputMulFix)
{
    //make outline "fadeout" if character is too small in camera's view
    return saturate(inputMulFix); // ��Ӧ�ö��㵽����ľ��볬��1m�����
}

float GetOutlineCameraFovAndDistanceFixMultiplier(float positionVS_Z)
{
    //����һ������ռ��µĶ�������������ϵ��
    float cameraMulFix;

    /*
    // unity_OrthoParams��float4��������UnityInput.hlsl�У�
    // x = orthographic camera's width
    // y = orthographic camera's height
    // z = unused
    // w = 1.0 if camera is ortho, 0.0 if perspective
    float4 unity_OrthoParams;
    */
    if(unity_OrthoParams.w == 0)
    {
        ////////////////////////////////
        // Perspective camera case | ���ʹ��͸��ͶӰ
        ////////////////////////////////

        // keep outline similar width on screen accoss all camera distance
        // ***��Ҫ��Ϊ�˱������̫��ʱ��outline̫��***
        cameraMulFix = abs(positionVS_Z);

        // can replace to a tonemap function if a smooth stop is needed
        // ***��Ҫ��Ϊ�˱������̫Զʱ�����ھ����������������outline̫��***
        cameraMulFix = ApplyOutlineDistanceFadeOut(cameraMulFix);

        // keep outline similar width on screen accoss all camera fov
        cameraMulFix *= GetCameraFOV(); // ʹ�ýǶ��Ƶ�fovY��������
    }
    else
    {
        ////////////////////////////////
        // Orthographic camera case | ���ʹ������ͶӰ
        ////////////////////////////////
        float orthoSize = abs(unity_OrthoParams.y);
        orthoSize = ApplyOutlineDistanceFadeOut(orthoSize);
        cameraMulFix = orthoSize * 50; // 50 is a magic number to match perspective camera's outline width
    }

    return cameraMulFix * 0.00005; // mul a const to make return result = default normal expand amount WS
}
#endif

