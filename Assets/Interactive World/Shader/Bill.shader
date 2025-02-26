Shader "Custom/Billboard"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _AxisType ("Axis Type", Float) = 1 // 0:X, 1:Y, 2:Z, 3:Custom
        _CustomAxis ("Custom Axis", Vector) = (0,1,0,0)
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "DisableBatching"="True" }
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
            float _AxisType;
            float4 _CustomAxis;

            v2f vert (appdata v)
            {
                v2f o;
                float4 worldPos = mul(unity_ObjectToWorld, float4(0,0,0,1));
                float3 cameraPos = _WorldSpaceCameraPos;
                
                // Calculate look direction (from object to camera)
                float3 lookDir = normalize(cameraPos - worldPos.xyz);
                float3 upDir = float3(0,0,0);
                
                // Handle different axis alignments
                if (_AxisType == 0) // X
                {
                    upDir = float3(1,0,0);
                    lookDir.x = 0;
                }
                else if (_AxisType == 1) // Y
                {
                    upDir = float3(0,1,0);
                    lookDir.y = 0;
                }
                else if (_AxisType == 2) // Z
                {
                    upDir = float3(0,0,1);
                    lookDir.z = 0;
                }
                else // Custom
                {
                    upDir = normalize(_CustomAxis.xyz);
                    lookDir = lookDir - dot(lookDir, upDir) * upDir;
                }
                
                lookDir = normalize(lookDir);
                float3 rightDir = normalize(cross(upDir, lookDir));  // First cross product
                float3 forwardDir = -normalize(cross(rightDir, upDir));  // Second cross product and negated
                
                // Create billboard matrix
                float3x3 billboardMatrix = float3x3(
                    rightDir,
                    upDir,
                    forwardDir
                );
                
                // Transform vertex
                float3 billboardPos = mul(billboardMatrix, v.vertex.xyz);
                float4 finalPos = float4(billboardPos + worldPos.xyz, 1);
                o.vertex = UnityWorldToClipPos(finalPos);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return tex2D(_MainTex, i.uv);
            }
            ENDCG
        }
    }
}