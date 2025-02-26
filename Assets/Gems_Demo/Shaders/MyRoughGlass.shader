Shader "Custom/MyRoughGlass"
{
    Properties
    {
        [MainTexture] _FrostTexture("Frost Pattern", 2D) = "white" {}
        _FrostIntensity("Frost Intensity", Range(0, 1)) = 1
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

            TEXTURE2D(_FrostTexture);
            SAMPLER(sampler_FrostTexture);

            TEXTURE2D(_BluredTexture0);
            SAMPLER(sampler_BluredTexture0);

            TEXTURE2D(_BluredTexture1);
            TEXTURE2D(_BluredTexture2);
            TEXTURE2D(_BluredTexture3);

            float4 _FrostTexture_ST;
            float _FrostIntensity;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 uvBluredTex : TEXCOORD1;
            };

            Varings vert(Attributes i)
            {
                Varings o;
                VertexPositionInputs posInputs = GetVertexPositionInputs(i.positionOS.xyz);
                o.positionCS = posInputs.positionCS;
                o.uv = TRANSFORM_TEX(i.uv, _FrostTexture);
                o.uvBluredTex = ComputeScreenPos(o.positionCS);

                return o;
            }

            half4 frag(Varings i) : SV_Target 
            {
                float surfSmooth = 1 - SAMPLE_TEXTURE2D(_FrostTexture, sampler_FrostTexture, i.uv).x * _FrostIntensity;
                surfSmooth = clamp(0, 1, surfSmooth);

                half4 ref00 = SAMPLE_TEXTURE2D(_BluredTexture0, sampler_BluredTexture0, i.uvBluredTex.xy / i.uvBluredTex.w);
                half4 ref01 = SAMPLE_TEXTURE2D(_BluredTexture1, sampler_BluredTexture0, i.uvBluredTex.xy / i.uvBluredTex.w);
                half4 ref02 = SAMPLE_TEXTURE2D(_BluredTexture2, sampler_BluredTexture0, i.uvBluredTex.xy / i.uvBluredTex.w);
                half4 ref03 = SAMPLE_TEXTURE2D(_BluredTexture3, sampler_BluredTexture0, i.uvBluredTex.xy / i.uvBluredTex.w);

                float step00 = smoothstep(0.75, 1.00, surfSmooth);
                float step01 = smoothstep(0.5, 0.75, surfSmooth);
                float step02 = smoothstep(0.05, 0.5, surfSmooth);
                float step03 = smoothstep(0.00, 0.05, surfSmooth);

                return lerp(ref03, lerp(lerp(lerp(ref03, ref02, step02), ref01, step01), ref00, step00), step03);
            }
            ENDHLSL
        }
    }
}