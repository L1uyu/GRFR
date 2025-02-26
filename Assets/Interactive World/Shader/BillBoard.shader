Shader "Unlit/BillBoard"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _AlphaClip("AlphaClip" ,Range(0,1)) = 0.1
        [Toggle(_MULTIPLE)] _Multiple("Multiple Mesh", float) = 0
        [KeywordEnum(X, Y, Z, Custom)] _AxisSelection("Alignment Axis", Float) = 1
        _CustomAxis("Custom Axis", Vector) = (0,1,0,0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Cull Off
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #pragma shader_feature _MULTIPLE

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            half _AlphaClip;

            struct Varings
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;

                #ifdef _MULTIPLE
                    float3 tangent : TANGENT;
                #endif
            };

            CBUFFER_START(UnityPerMaterial)
                float3 _CustomAxis;
                int _AxisSelection; // 0=X, 1=Y, 2=Z, 3=Custom
            CBUFFER_END
            struct Output
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Output vert(Varings input)
            {
                // In world space
                // float3 worldPos = TransformObjectToWorld(input.positionOS.xyz);
                // float3 center = TransformObjectToWorld(float3(0, 0, 0)); // or directly use object position
                // float3 cameraPos = GetCameraPositionWS();

                // // Calculate billboard orientation in world space
                // float3 N = center - cameraPos;
                // N.y = 0; // For vertical billboard
                // N = normalize(N);

                // // Create TBN matrix in world space
                // float3 B = abs(N.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);
                // float3 T = normalize(cross(N, B));
                // B = normalize(cross(T, N));
                // float3x3 billboardTBN = float3x3(T, B, N);

                // // Apply billboard rotation
                // float3 offset = input.positionOS.xyz; // Original local vertex position
                // float3 billboardedPos = center + mul(billboardTBN, offset);

                // Output o;
                // o.positionCS = TransformWorldToHClip(billboardedPos);
                // o.uv = input.uv;
                // return o;

                half3 center = half3(0, 0, 0);
                half3 viewer = TransformWorldToObject(GetCameraPositionWS());
                half3 N = viewer - center;
                N.y = 0;
                N = normalize(N);
                float sqrt2_2 = sqrt(2) / 2;
                half3 B = normalize(center - half3(0, -sqrt2_2, sqrt2_2));
                half3 T = normalize(cross(N, B));

                half3x3 billboardTBN = half3x3(T, B, N);
                half3 localPos = input.positionOS.xyz;
                localPos = mul(billboardTBN, localPos);
                Output o;
                o.positionCS = TransformObjectToHClip(localPos);
                o.uv = input.uv;
                return o;

                // half3 center = half3(0, 0, 0);
                // half3 viewer = TransformWorldToObject(GetCameraPositionWS());
                // half3 N = viewer - center;
                
                // // Select up axis based on _AxisSelection
                // half3 upAxis = half3(0, 0, 0);
                // if (_AxisSelection == 0) // X
                // {
                //     upAxis = half3(1, 0, 0);
                //     N.x = 0;
                // }
                // else if (_AxisSelection == 1) // Y
                // {
                //     upAxis = half3(0, 1, 0);
                //     N.y = 0;
                // }
                // else if (_AxisSelection == 2) // Z
                // {
                //     upAxis = half3(0, 0, 1);
                //     N.z = 0;
                // }
                // else // Custom
                // {
                //     upAxis = normalize(center - half3(0, -sqrt2_2, sqrt2_2));//normalize(_CustomAxis);
                //     // Project N onto the plane defined by customAxis
                //     N = N - dot(N, upAxis) * upAxis;
                // }
                
                // N = normalize(N);
                // half3 T = normalize(cross(N, upAxis));
                // half3 B = normalize(cross(T, N));
                
                // half3x3 billboardTBN = half3x3(T, B, N);
                // half3 localPos = input.positionOS.xyz;
                // localPos = mul(billboardTBN, localPos);
                
                // Output o;
                // o.positionCS = TransformObjectToHClip(localPos);
                // o.uv = input.uv;
                // return o;

            }
            half4 frag(Output i) : SV_Target
            {
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

                clip(col.a - _AlphaClip); //͸���Ȳ���

                return col;
            }
            ENDHLSL
        }
    }
}