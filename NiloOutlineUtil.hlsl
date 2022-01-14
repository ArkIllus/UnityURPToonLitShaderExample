// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

#ifndef Include_NiloOutlineUtil
#define Include_NiloOutlineUtil

// TODO：如下面所说的，可以有更快速的获摄像机的FOV的方法
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
    return fov; //返回值是角度制的fovY
}
float ApplyOutlineDistanceFadeOut(float inputMulFix)
{
    //make outline "fadeout" if character is too small in camera's view
    // | 如果角色在相机视图中太小，则使outline“淡出”
    // inputMulFix > 0 所以其实就是限制 inputMulFix > 1 时的上限 = 1，对应该顶点到相机的距离超过1m的情况
    return saturate(inputMulFix);
}
float GetOutlineCameraFovAndDistanceFixMultiplier(float positionVS_Z)
{
    //返回一个世界空间下的顶点外扩的修正系数
    float cameraMulFix;

    /*
    // unity_OrthoParams（float4）定义在UnityInput.hlsl中：
    // x = orthographic camera's width
    // y = orthographic camera's height
    // z = unused
    // w = 1.0 if camera is ortho, 0.0 if perspective
    float4 unity_OrthoParams;
    */
    if(unity_OrthoParams.w == 0)
    {
        ////////////////////////////////
        // Perspective camera case | 相机使用透视投影
        ////////////////////////////////

        // keep outline similar width on screen accoss all camera distance 
        // | 对所有相机距离，在屏幕上保持outline宽度相似 
        // ***主要是为了避免相机太近时，outline太粗
        //（观察/相机空间中顶点位置的z坐标）（unity中摄像机的前方是-z轴）（unity中观察空间使用的是右手坐标系，模型空间和世界空间使用的是左手坐标系）
        cameraMulFix = abs(positionVS_Z);

        // can replace to a tonemap function if a smooth stop is needed
        // | 如果需要平滑停止（smooth stop），可以替换为色调映射（tonemap）函数 ？？？？？？
        // ***主要是为了避免相机太远时，由于经过了上面的修正，outline太粗
        cameraMulFix = ApplyOutlineDistanceFadeOut(cameraMulFix);

        // keep outline similar width on screen accoss all camera fov
        // | 对所有相机FOV，在屏幕上保持outline宽度相似 
        // 使用角度制的fovY进行修正
        cameraMulFix *= GetCameraFOV();       
    }
    else
    {
        ////////////////////////////////
        // Orthographic camera case | 相机使用正交投影
        ////////////////////////////////
        float orthoSize = abs(unity_OrthoParams.y);
        orthoSize = ApplyOutlineDistanceFadeOut(orthoSize);
        cameraMulFix = orthoSize * 50; // 50 is a magic number to match perspective camera's outline width
    }

    return cameraMulFix * 0.00005; // mul a const to make return result = default normal expand amount WS
}
#endif

