Shader "Custom/MyBlur"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        //_BlurAmount ("Blur Amount", Vector) = (1, 1, 0, 0)
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }

        Pass
        {
            Name "Forward"
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            float4 _MainTex_ST;
            float4 _BlurAmount;


            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 uv01 : TEXCOORD1;
                float4 uv23 : TEXCOORD2;
                float4 uv45 : TEXCOORD3;
            };

            Varings vert(Attributes i)
            {
                Varings o;
                VertexPositionInputs posInputs = GetVertexPositionInputs(i.positionOS.xyz);
                o.positionCS = posInputs.positionCS;

                o.uv = TRANSFORM_TEX(i.uv, _MainTex);
                o.uv01 =  i.uv.xyxy + _BlurAmount.xyxy * float4(1, 1, -1, -1);
                o.uv23 =  i.uv.xyxy + _BlurAmount.xyxy * float4(1, 1, -1, -1) * 2.0;
                o.uv45 =  i.uv.xyxy + _BlurAmount.xyxy * float4(1, 1, -1, -1) * 3.0;

                return o;
            }

            float4 frag(Varings i) : SV_Target 
            {
                float4 color = float4(0, 0, 0, 0);
                color += 0.40 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                color += 0.15 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv01.xy); 
                color += 0.15 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv01.zw); 
                color += 0.10 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv23.xy); 
                color += 0.10 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv23.zw); 
                color += 0.05 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv45.xy); 
                color += 0.05 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv45.zw); 

                return color;
            }
            ENDHLSL
        }
    }
}