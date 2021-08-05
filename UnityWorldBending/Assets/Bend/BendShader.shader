Shader "Unlit/BendShader"
{
    Properties
    {
        _Color ("Color", Color) = (1, 1, 1, 1)
        _Axis  ("Axis", Vector) = (0, 1, 0, 1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _Color;

            // axis to rotate the vertices around
            float4 _Axis;
        CBUFFER_END

        struct VertexInput {
            float4 pos : POSITION;
        };

        struct VertexOutput {
            float4 pos : SV_POSITION;
        };

        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // taken from https://docs.unity3d.com/Packages/com.unity.shadergraph@6.9/manual/Rotate-About-Axis-Node.html
            void Unity_RotateAboutAxis_Degrees_float( float3 In, float3 Axis, float Rotation, out float3 Out ) {
                Rotation = radians( Rotation );
                float s = sin( Rotation );
                float c = cos( Rotation );
                float one_minus_c = 1.0 - c;

                Axis = normalize( Axis );
                float3x3 rot_mat =
                {   one_minus_c * Axis.x * Axis.x + c, one_minus_c * Axis.x * Axis.y - Axis.z * s, one_minus_c * Axis.z * Axis.x + Axis.y * s,
                    one_minus_c * Axis.x * Axis.y + Axis.z * s, one_minus_c * Axis.y * Axis.y + c, one_minus_c * Axis.y * Axis.z - Axis.x * s,
                    one_minus_c * Axis.z * Axis.x - Axis.y * s, one_minus_c * Axis.y * Axis.z + Axis.x * s, one_minus_c * Axis.z * Axis.z + c
                };
                Out = mul( rot_mat,  In );
            }

            float3 Bend( float3 worldPos ) {
                float3 dist = worldPos - _Axis.xyz;
                float3 rotatedDist;

                Unity_RotateAboutAxis_Degrees_float( dist, _Axis.xyz, dist.x, rotatedDist );

                return rotatedDist;
            }

            VertexOutput vert( VertexInput vsi ) {
                // transform model space to world space
                float3 worldCoord = TransformObjectToWorld( vsi.pos.xyz );

                // bend the vertices
                worldCoord = Bend( worldCoord );

                VertexOutput o;
                // transform world space to screen space
                o.pos = TransformWorldToHClip( worldCoord );
                return o;
            }

            float4 frag( VertexOutput vso ) : SV_TARGET {
                return _Color;
            }

            ENDHLSL

        }
    }
}
