Shader "Custom/WaterStream"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Width ("Width", Float) = 0.2
        _Height ("Height", Float) = 2.0
        _XMultiplier ("X Multiplier", Float) = 1.0
        _ZMultiplier ("Z Multiplier", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Width;
            float _Height;
            float _XMultiplier;
            float _ZMultiplier;
            float4x4 _CameraMatrix;

            v2f vert (appdata v)
            {
                v2f o;
                
                // Get the normalized height position
                float t = 1 - (v.vertex.y / _Height);
                
                // Calculate center position
                float3 center = float3(
                    sin(t * 3.14159) * _XMultiplier, // Simple sine wave instead of curve
                    v.vertex.y,
                    cos(t * 3.14159) * _ZMultiplier  // Simple cosine wave instead of curve
                );
                
                // Get camera right vector
                float3 cameraRight = normalize(_CameraMatrix[0].xyz);
                
                // Calculate width (you can add width curve here)
                float currentWidth = _Width * (1 - t); // Simple linear width reduction
                
                // Calculate final position
                float3 offset = cameraRight * currentWidth * (v.uv.x * 2 - 1);
                float3 finalPos = center + offset;
                
                o.vertex = UnityObjectToClipPos(float4(finalPos, 1));
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                return col;
            }
            ENDCG
        }
    }
}