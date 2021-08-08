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
                float factor = -dot( po, dir );
                return origin + ( dir * factor );
            }

            // [TODO]: Add comments.
            float3 Bend( float3 modelPos ) {
                const float3 ROTATIONAL_PLANE = float3( 1.0f, 0.0f, 0.0f );

                float3 worldPos = TransformObjectToWorld( modelPos );

                float3 rotationalAxis = normalize( _Axis.xyz );
                float3 pointOnAxis = ProjectPointOnRay( worldPos, _Origin.xyz, rotationalAxis );
                float3 perpendicularToAxis = worldPos - pointOnAxis;
                float3 originOnPlane = ProjectPointOnRay( pointOnAxis, worldPos, ROTATIONAL_PLANE );

                float degree = _Degree;
                float curveLength = _CurveLength;

                float oopToWorld = length( worldPos - originOnPlane );
                float distDot = dot( worldPos - originOnPlane, ROTATIONAL_PLANE );

                if ( oopToWorld > curveLength && distDot > 0.0f ) {
                    // beyond rotation, should become straight after curve
                    float3 toRotate = worldPos - originOnPlane;
                    toRotate = normalize( toRotate ) * ( oopToWorld - curveLength );
                    toRotate = Unity_RotateAboutAxis_Degrees_float( toRotate, rotationalAxis, degree );
                    float3 offset = Unity_RotateAboutAxis_Degrees_float( originOnPlane - pointOnAxis, rotationalAxis, degree );
                    worldPos = pointOnAxis + offset + toRotate;
                } else if ( distDot > 0.0f ) {
                    // in between curve, should be bent
                    float toRotate = lerp( 0, degree, oopToWorld / curveLength );
                    float3 rotatedPos = Unity_RotateAboutAxis_Degrees_float( originOnPlane - pointOnAxis, rotationalAxis, toRotate );
                    worldPos = pointOnAxis + rotatedPos;
                }

                return worldPos;
            }

            VertexOutput vert( VertexInput vsi ) {
                // bend the vertices
                float3 worldCoord = Bend( vsi.pos.xyz );

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
