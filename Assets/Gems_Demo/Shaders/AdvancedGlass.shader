Shader "Custom/AdvancedGlass"
{
    Properties
    {
        [Header(Roughness Settings)]
        _RoughnessMap ("Roughness Map", 2D) = "white" {}
        _RoughnessScale ("Roughness Scale", Range(0, 1)) = 1
        
        [Header(Normal Settings)] 
        [Toggle(_USE_NORMAL_MAP)] _UseNormalMap("Use Normal Map", Float) = 0
        _NormalMap ("Normal Map", 2D) = "bump" {}
        _NormalIntensity ("Normal Intensity", Range(0, 2)) = 1

        [Header(Refraction Settings)]
        [KeywordEnum(Sphere, Box)] _RefractionModel ("Refraction Model", Float) = 0
        _IOR ("Index of Refraction", Range(1.0, 2.5)) = 1.5
        _Thickness ("Glass Thickness", Range(0, 10)) = 0.1

        [Header(PBR Settings)]
        _Metallic ("Metallic", Range(0, 1)) = 0

    }
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }
        LOD 100
        Pass
        {
            Name "Forward"
            Tags { "LightMode" = "UniversalForward" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _REFRACTIONMODEL_SPHERE _REFRACTIONMODEL_BOX
            #pragma shader_feature_local _USE_NORMAL_MAP
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_GrabScreenTexture);

            // 添加 Roughness Map 相关声明
            TEXTURE2D(_RoughnessMap);
            SAMPLER(sampler_RoughnessMap);
            float4 _RoughnessMap_ST;
            float _RoughnessScale;

            float _PixelBlurScale;

            TEXTURE2D(_NormalMap);        // 法线贴图
            SAMPLER(sampler_NormalMap);   // 法线贴图采样器
            float4 _NormalMap_ST;         // 法线贴图缩放偏移
            float _NormalIntensity;       // 法线强度

            float _IOR;
            float _Thickness;

            float _Metallic;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;     // 添加物体空间法线
                float4 tangentOS : TANGENT;   // 添加物体空间切线
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 screenPos : TEXCOORD0;
                float2 uv : TEXCOORD1;
                
                // 切线空间向量
                float3 tangent : TEXCOORD2;
                float3 bitangent : TEXCOORD3;
                float3 normal : TEXCOORD4;
                float3 positionWS : TEXCOORD5;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.screenPos = ComputeScreenPos(output.positionCS);
                output.uv = TRANSFORM_TEX(input.uv, _NormalMap); // 使用法线贴图的ST参数
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                
                // 构建切线空间矩阵
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.tangent = normalInput.tangentWS;
                output.bitangent = normalInput.bitangentWS;
                output.normal = normalInput.normalWS;

                
                return output;
            }


            float3 SampleOpaquePyramid(float2 uv, float smoothness) 
            {
                smoothness = saturate(1 - (1 - smoothness) * _PixelBlurScale);
                const float sampleRanges[] = {1.0, 0.875, 0.75, 0.5, 0.0};
                int preLod = 0;
                int maxLod = 3;
                for(int i = maxLod; i >= 0; --i) 
                {
                    preLod = i;
                    if(smoothness <= sampleRanges[i]) break;
                }
                float3 ref0 = SAMPLE_TEXTURE2D_LOD(_GrabScreenTexture, sampler_LinearClamp, uv, preLod).rgb;
                float3 ref1 = SAMPLE_TEXTURE2D_LOD(_GrabScreenTexture, sampler_LinearClamp, uv, preLod + 1).rgb;
                float step = (sampleRanges[preLod] - smoothness) / (sampleRanges[preLod] - sampleRanges[preLod + 1]);
                step = saturate(step);
                return lerp(ref0, ref1, step);
            }

            float3 SampleWithDistortion(float2 baseUV, float2 distortion, float roughness)
            {
                float2 distortedUV = baseUV + distortion;
                return SampleOpaquePyramid(distortedUV, 1.0 - roughness);
            }

            struct RefractionModelResult
            {
                real3 rayWS;
                real  dist;
                real3 positionWS;
            };

            RefractionModelResult RefractionModelSphere(real3 V, float3 positionWS, real3 normalWS, real ior, real thickness)
            {
                RefractionModelResult result;
                
                // 第一次折射（进入球体）
                real3 R1 = refract(-normalize(V), normalWS, 1.0 / ior);
                
                // 计算虚拟球体中心
                real3 C = positionWS - normalWS * thickness * 0.5;
                
                // 计算光线在球体内的传播
                real NoR1 = dot(normalWS, R1);
                real dist = -NoR1 * thickness;
                
                // 第二次折射（离开球体）
                real3 P1 = positionWS + R1 * dist;
                real3 N1 = normalize(C - P1);
                real3 R2 = refract(R1, N1, ior);
                
                result.rayWS = R2;
                result.dist = dist;
                result.positionWS = P1;
                
                return result;
            }

            RefractionModelResult RefractionModelBox(real3 V, float3 positionWS, real3 normalWS, real ior, real thickness)
            {
                // Plane shape model:
                //  We approximate locally the shape of the object as a plane with normal {normalWS} at {positionWS}
                //  with a thickness {thickness}

                // Refracted ray
                real3 R = refract(-V, normalWS, 1.0 / ior);

                // Optical depth within the thin plane
                real dist = thickness / max(dot(R, -normalWS), 1e-5f);

                RefractionModelResult result;
                result.dist = dist;
                result.positionWS = positionWS + R * dist;
                result.rayWS = -V;

                return result;
            }

            float3 IBL_EnvironmentReflection(float3 viewDirWS, float3 normalWS, float roughness, float metallic)
            {
                float NoV = saturate(dot(normalWS, viewDirWS));
                float3 reflectDirectionWS = reflect(-viewDirWS, normalWS);
                
                // Keep the original smooth mip calculation
                float square_roughness = roughness * (1.7 - 0.7 * roughness);
                float Midlevel = square_roughness * 6;
                
                // Sample environment reflection
                float4 specularColor = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectDirectionWS, Midlevel);
                
                // Decode HDR
                #if !defined(UNITY_USE_NATIVE_HDR)
                    float3 envReflection = DecodeHDREnvironment(specularColor, unity_SpecCube0_HDR).rgb;
                #else
                    float3 envReflection = specularColor.rgb;
                #endif
                
                // Add PBR controls
                float3 F0 = lerp(0.04, 1.0, metallic);
                float grazingTerm = saturate((1.0 - roughness) + metallic);
                float3 fresnelTerm = lerp(F0, grazingTerm, 1.0 - NoV);
                
                return envReflection * fresnelTerm;
            }

            float3 CalculateEnvironmentReflection(float3 viewDirWS, float3 normalWS, float roughness, float metallic)
            {
                float NoV = saturate(dot(normalWS, viewDirWS));
                
                float3 reflectVector = reflect(-viewDirWS, normalWS);
                
                float perceptualRoughness = roughness;
                float mip = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness) * 6.0;
                
                float3 specularColor = lerp(0.04, 1.0, metallic);
                float surfaceReduction = 1.0 / (perceptualRoughness * perceptualRoughness + 1.0);
                float grazingTerm = saturate((1.0 - perceptualRoughness) + metallic);
                float3 fresnelTerm = lerp(specularColor, grazingTerm, 1.0 - NoV);
                
                float3 envReflection = GlossyEnvironmentReflection(reflectVector, mip, 1.0);
                return surfaceReduction * envReflection * fresnelTerm;
            }

            float4 frag(Varyings input) : SV_Target
            {
                float3 finalNormal;
                
                #if defined(_USE_NORMAL_MAP)
                    // Sample normal map
                    float3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv));
                    // Lerp between geometric normal and normal map based on intensity
                    normalTS = lerp(float3(0, 0, 1), normalTS, _NormalIntensity);
                    
                    // Ensure TBN vectors are normalized
                    float3 T = normalize(input.tangent);
                    float3 B = normalize(input.bitangent);
                    float3 N = normalize(input.normal);
                    
                    float3x3 TBN = float3x3(T, B, N);
                    finalNormal = normalize(mul(normalTS, TBN));
                #else
                    finalNormal = normalize(input.normal);
                #endif
                
                // Calculate view direction
                float3 positionWS = input.positionWS;
                float3 viewDirWS = normalize(GetCameraPositionWS() - positionWS);
                
                // Calculate refraction
                RefractionModelResult refraction;
                #if defined(_REFRACTIONMODEL_SPHERE)
                    refraction = RefractionModelSphere(viewDirWS, positionWS, finalNormal, _IOR, _Thickness);
                #else // BOX model
                    refraction = RefractionModelBox(viewDirWS, positionWS, finalNormal, _IOR, _Thickness);
                #endif
                
                // Calculate screen UV offset based on refracted ray
                float4 refractionPositionCS = TransformWorldToHClip(refraction.positionWS + refraction.rayWS * refraction.dist);
                float2 refractionScreenUV = ComputeScreenPos(refractionPositionCS).xy / refractionPositionCS.w;
                float2 distortion = refractionScreenUV - (input.screenPos.xy / input.screenPos.w);

                float2 uv = TRANSFORM_TEX(input.uv, _RoughnessMap); 
                
                // 采样粗糙度贴图
                float roughness = SAMPLE_TEXTURE2D(_RoughnessMap, sampler_RoughnessMap, uv).r * _RoughnessScale;

                float3 envReflection = IBL_EnvironmentReflection(viewDirWS, finalNormal, roughness, _Metallic);
                //float3 envReflection = CalculateEnvironmentReflection(viewDirWS, finalNormal, roughness, _Metallic);
                
                // Sample scene with distortion and roughness
                float3 sceneColor = SampleWithDistortion(input.screenPos.xy / input.screenPos.w, distortion, roughness);
                
                return float4(sceneColor + envReflection, 1.0);
            }
            ENDHLSL
        }
    }
}