Shader "Unlit/BendShader"
{
    Properties
    {
        _Color  ("Color",  Color ) = (1, 1, 1, 1)
        _Axis   ("Axis",   Vector) = (0, 1, 0, 1)
        _Origin ("Origin", Vector) = (0, 0, 0, 1)
        _Degree ("Degree", Float ) = 45
        _CurveLength ("Curve Length", Float) = 10
    }
    SubShader
    {
        Cull Off
        Tags { "RenderType"="Opaque" }
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _Color;

            // axis to rotate the vertices around
            float4 _Axis;

            // origin of the axis to move it around
            float4 _Origin;

            // degrees to rotate around the axis
            float  _Degree;

            // used to determine how smooth the curve will be
            float _CurveLength;
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

            // #define PI = 3.14159265f;

            // taken from https://docs.unity3d.com/Packages/com.unity.shadergraph@6.9/manual/Rotate-About-Axis-Node.html
            float3 Unity_RotateAboutAxis_Degrees_float( float3 In, float3 Axis, float Rotation ) {
                Rotation = radians( Rotation );
                float s = sin( Rotation );
                float c = cos( Rotation );
                float one_minus_c = 1.0f - c;

                Axis = normalize( Axis );
                float3x3 rot_mat =
                {   one_minus_c * Axis.x * Axis.x + c, one_minus_c * Axis.x * Axis.y - Axis.z * s, one_minus_c * Axis.z * Axis.x + Axis.y * s,
                    one_minus_c * Axis.x * Axis.y + Axis.z * s, one_minus_c * Axis.y * Axis.y + c, one_minus_c * Axis.y * Axis.z - Axis.x * s,
                    one_minus_c * Axis.z * Axis.x - Axis.y * s, one_minus_c * Axis.y * Axis.z + Axis.x * s, one_minus_c * Axis.z * Axis.z + c
                };
                return mul( rot_mat, In );
            }

            // [TODO]: Add comments.
            float3 ProjectPointOnRay( float3 pt, float3 origin, float3 dir ) {
                float3 po = origin - pt;
                float factor = dot( po, dir );
                return origin + ( dir * factor );
            }

            // [TODO]: Add comments.
            float3 BendZ( float3 modelPos ) {
                float3 worldPos = TransformObjectToWorld( modelPos );

                if ( _Axis.z < 0.0f ) {
                    worldPos.x = -worldPos.x;
                }

                float3 pointOnAxis = ProjectPointOnRay( worldPos, _Origin.xyz, _Axis.xyz );
                float3 perp = worldPos - pointOnAxis;

                float curveLength = _CurveLength;

                _Degree = _Degree * sign( -perp.y ) * sign( _Axis.z );

                if ( worldPos.x > pointOnAxis.x + curveLength ) {
                    float3 toRotate = worldPos - ( pointOnAxis + float3( 0.0f, perp.y, 0.0f ) );
                    toRotate.x -= curveLength;
                    toRotate = Unity_RotateAboutAxis_Degrees_float( toRotate, _Axis.xyz, _Degree );
                    float3 offset = Unity_RotateAboutAxis_Degrees_float( float3( 0.0f, perp.y, 0.0f ), _Axis.xyz, _Degree );
                    worldPos = pointOnAxis + offset + toRotate;
                } else if ( worldPos.x > pointOnAxis.x ) {
                    float toRotate = lerp( 0, _Degree, abs( worldPos.x - pointOnAxis.x ) / curveLength );
                    float3 rotatedPos = Unity_RotateAboutAxis_Degrees_float( float3( 0.0f, perp.y, 0.0f ), _Axis.xyz, toRotate );
                    worldPos = pointOnAxis + rotatedPos;
                    worldPos.z = -worldPos.z;
                }

                if ( _Axis.z < 0.0f ) {
                    worldPos.x = -worldPos.x;
                }

                return worldPos;
            }

            VertexOutput vert( VertexInput vsi ) {
                // bend the vertices
                float3 worldCoord = BendZ( vsi.pos.xyz );

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
