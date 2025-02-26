using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class GrabScreenRendererFeature : ScriptableRendererFeature
{
    class GrabScreenPass : ScriptableRenderPass
    {
        private static class ShaderIDs {
            public static readonly int _Size = Shader.PropertyToID("_Size");
            public static readonly int _Source = Shader.PropertyToID("_Source");
            public static readonly int _Destination = Shader.PropertyToID("_Destination");
        }
        private const int MIP_COUNT = 5;
        private readonly int m_ColorPyramidDownSampleKernel;
        private readonly int m_ColorPyramidGaussianKernel;

        private RTHandle m_ColorRT;
        private RTHandle m_GrabScreenTexture;

        private RTHandle[] m_TempDownsamplePyramid0; // 双缓冲临时纹理
        private RTHandle[] m_TempDownsamplePyramid1;
        private ComputeShader m_ColorPyramidCS;


        private RenderTextureFormat m_CurrentColorFormat;
        private Vector2Int m_CurrentColorResolution;

        public GrabScreenPass(ComputeShader colorPyramidCS)
        {
            m_CurrentColorFormat = RenderTextureFormat.Default;
            m_CurrentColorResolution = Vector2Int.zero;
            m_TempDownsamplePyramid0 = new RTHandle[MIP_COUNT]; 
            m_TempDownsamplePyramid1 = new RTHandle[MIP_COUNT];

            try
            {
                m_ColorPyramidCS = colorPyramidCS;
                m_ColorPyramidDownSampleKernel = m_ColorPyramidCS.FindKernel("Downsample");
                m_ColorPyramidGaussianKernel = m_ColorPyramidCS.FindKernel("GaussianBlur");
            }
            catch (System.Exception e)
            {
                Debug.LogError($"Failed to initialize GrabScreenPass: {e.Message}");
            } 
        }

        public void SetUpColorRT(RTHandle rt)
        {
            m_ColorRT = rt;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor targetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            //m_ColorRT = renderingData.cameraData.renderer.cameraColorTargetHandle;
            bool needRecreate =
                //targetDescriptor.colorFormat != m_CurrentColorFormat ||
                targetDescriptor.width != m_CurrentColorResolution.x ||
                targetDescriptor.height != m_CurrentColorResolution.y;

             if (m_GrabScreenTexture == null || needRecreate)
             {
                if (m_GrabScreenTexture != null)
                {
                    RTHandles.Release(m_GrabScreenTexture);
                    m_GrabScreenTexture = null;
                }

                var desc = new RenderTextureDescriptor(
                    targetDescriptor.width, 
                    targetDescriptor.height,
                    //targetDescriptor.colorFormat, 
                    RenderTextureFormat.ARGB32,
                0)
                {
                    autoGenerateMips = false,
                    useMipMap = true,
                    mipCount = MIP_COUNT,
                    enableRandomWrite = true
                };
                m_GrabScreenTexture = RTHandles.Alloc(desc, name: "Grab Screen RT");

                // 更新缓存
                m_CurrentColorFormat = RenderTextureFormat.ARGB32;//targetDescriptor.colorFormat;
                m_CurrentColorResolution = new Vector2Int(targetDescriptor.width, targetDescriptor.height);

                for (int i = 0; i < MIP_COUNT - 1; i++)
                {
                    int width = Mathf.Max(1, m_CurrentColorResolution.x >> (i + 1));
                    int height = Mathf.Max(1, m_CurrentColorResolution.y >> (i + 1));

                    var pyramidDesc = new RenderTextureDescriptor(width, height, m_CurrentColorFormat, 0)
                    {
                        enableRandomWrite = true
                    };

                    RenderingUtils.ReAllocateIfNeeded(ref m_TempDownsamplePyramid0[i], 
                        pyramidDesc, 
                        name: $"TempPyramid0_{i}");
                    RenderingUtils.ReAllocateIfNeeded(ref m_TempDownsamplePyramid1[i], 
                        pyramidDesc, 
                        name: $"TempPyramid1_{i}");
                }
             }
            
        }


        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get();
            try 
            {
                if (m_ColorRT == null || m_GrabScreenTexture == null)
                {
                    Debug.LogError("GrabScreenRendererFeature: Source or destination texture is null");
                    return;
                }
                if (m_ColorPyramidCS == null)
                {
                    Debug.LogError("GrabScreenRendererFeature: ColorPyramidCS is null");
                    return;
                }
                Blitter.BlitCameraTexture(cmd, m_ColorRT, m_GrabScreenTexture);
                //cmd.CopyTexture(m_ColorRT, 0, 0, 0, 0, m_CurrentColorResolution.x, m_CurrentColorResolution.y, m_GrabScreenTexture, 0, 0, 0, 0);
                bool isFirstLoop = true;
                bool switchFlag = false;

                Vector2Int srcSize = new Vector2Int(m_CurrentColorResolution.x, m_CurrentColorResolution.y);
                float baseResolutionX = 1920.0f;
                float pixelBlurScale =  m_CurrentColorResolution.x / baseResolutionX;
                cmd.SetGlobalFloat("_PixelBlurScale", pixelBlurScale);

                for (int currentLevel = 0; currentLevel < MIP_COUNT - 1; currentLevel++)
                {
                    int dstWidth = Mathf.Max(1, srcSize.x >> 1);
                    int dstHeight = Mathf.Max(1, srcSize.y >> 1);
                    RTHandle sourceRT, destRT;
                    if (isFirstLoop)
                    {
                        sourceRT = m_ColorRT;
                        destRT = m_TempDownsamplePyramid0[currentLevel];
                        isFirstLoop = false;
                    }
                    else
                    {
                        if (switchFlag)
                        {
                            sourceRT = m_TempDownsamplePyramid1[currentLevel - 1];
                            destRT = m_TempDownsamplePyramid0[currentLevel];
                        }
                        else
                        {
                            sourceRT = m_TempDownsamplePyramid0[currentLevel - 1];
                            destRT = m_TempDownsamplePyramid1[currentLevel];
                        }
                        
                        switchFlag = !switchFlag;
                    }


                    //Downsample Pass
                    cmd.SetComputeVectorParam(m_ColorPyramidCS, ShaderIDs._Size, new Vector4(srcSize.x, srcSize.y, 0, 0));
                    cmd.SetComputeTextureParam(m_ColorPyramidCS, m_ColorPyramidDownSampleKernel, ShaderIDs._Source, sourceRT);
                    cmd.SetComputeTextureParam(m_ColorPyramidCS, m_ColorPyramidDownSampleKernel, ShaderIDs._Destination, destRT);
                    cmd.DispatchCompute(m_ColorPyramidCS, m_ColorPyramidDownSampleKernel, (dstWidth + 7) / 8, (dstHeight + 7) / 8, 1);
                    //Gaussian Blur Pass
                    cmd.SetComputeVectorParam(m_ColorPyramidCS, ShaderIDs._Size, new Vector4(dstWidth, dstHeight, 0, 0));
                    cmd.SetComputeTextureParam(m_ColorPyramidCS, m_ColorPyramidGaussianKernel, ShaderIDs._Source, destRT);
                    cmd.SetComputeTextureParam(m_ColorPyramidCS, m_ColorPyramidGaussianKernel, ShaderIDs._Destination, m_GrabScreenTexture, currentLevel + 1);
                    cmd.DispatchCompute(m_ColorPyramidCS, m_ColorPyramidGaussianKernel, (dstWidth + 7) / 8, (dstHeight + 7) / 8, 1);

                    srcSize = new Vector2Int(dstWidth, dstHeight);
                }
                cmd.SetGlobalTexture("_GrabScreenTexture", m_GrabScreenTexture);
                context.ExecuteCommandBuffer(cmd);
            }
            finally 
            {
                CommandBufferPool.Release(cmd);
            }
        }


        public void Dispose()
        {
            if (m_GrabScreenTexture != null)
            {
                RTHandles.Release(m_GrabScreenTexture);
                m_GrabScreenTexture = null;
            }
            if (m_TempDownsamplePyramid0 != null)
            {
                for (int i = 0; i < MIP_COUNT; i++)
                {
                    if (m_TempDownsamplePyramid0[i] != null)
                    {
                        m_TempDownsamplePyramid0[i].Release();
                        m_TempDownsamplePyramid0[i] = null;
                    }
                }
                m_TempDownsamplePyramid0 = null;
            }

            if (m_TempDownsamplePyramid1 != null)
            {
                for (int i = 0; i < MIP_COUNT; i++)
                {
                    if (m_TempDownsamplePyramid1[i] != null)
                    {
                        m_TempDownsamplePyramid1[i].Release();
                        m_TempDownsamplePyramid1[i] = null;
                    }
                }
                m_TempDownsamplePyramid1 = null;
            }
        }
        
    }
    
    [SerializeField]
    private ComputeShader m_ColorPyramidCS;

    private GrabScreenPass m_ScriptablePass;

    /// <inheritdoc/>
    public override void Create()
    {
        if (m_ColorPyramidCS == null)
        {
            Debug.LogError("GrabScreenRendererFeature: ColorPyramidCS is null");
            SetActive(false);
            return;
        }
        m_ScriptablePass = new GrabScreenPass(m_ColorPyramidCS);

        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingSkybox;
    }

    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        m_ScriptablePass.SetUpColorRT(renderer.cameraColorTargetHandle);
    }


    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }

    protected override void Dispose(bool disposing)
    {
        m_ScriptablePass?.Dispose();
        m_ScriptablePass = null;
    }

}


