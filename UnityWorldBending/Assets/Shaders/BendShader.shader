Shader "Unlit/BendShader"
{
    Properties
    {
        _Color  ("Color",  Color ) = (1, 1, 1, 1)
        _Axis   ("Axis",   Vector) = (0, 1, 0, 1)
        _Origin ("Origin", Vector) = (0, 0, 0, 1)
        _Degree ("Degree", Float ) = 45
        _CurveLength ("Curve Length", Float) = 10.0

        [Toggle(AUTO_SIGN)]
        _AutoSign ("Automatically Determine Sign", Float) = 1

        [KeywordEnum(PositiveX, NegativeX, PositiveY, NegativeY, PositiveZ, NegativeZ)]
        _RefrencePlane ("Refrence Plane", Float) = 0.0
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

            // automatically determine the relative side of position and curve accordingly
            int _AutoSign;
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

            // used to toggle sign determination
            #pragma shader_feature AUTO_SIGN

            // used to set refrence plane
            #pragma shader_feature _REFRENCEPLANE_POSITIVEX
            #pragma shader_feature _REFRENCEPLANE_NEGATIVEX
            #pragma shader_feature _REFRENCEPLANE_POSITIVEY
            #pragma shader_feature _REFRENCEPLANE_NEGATIVEY
            #pragma shader_feature _REFRENCEPLANE_POSITIVEZ
            #pragma shader_feature _REFRENCEPLANE_NEGATIVEZ

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

            float3 GetRefrencePlane( void ) {
            #if defined( _REFRENCEPLANE_POSITIVEX )
                return float3( 1.0f, 0.0f, 0.0f );
            #elif defined( _REFRENCEPLANE_NEGATIVEX )
                return float3( -1.0f, 0.0f, 0.0f );
            #elif defined( _REFRENCEPLANE_POSITIVEY )
                return float3( 0.0f, 1.0f, 0.0f );
            #elif defined( _REFRENCEPLANE_NEGATIVEY )
                return float3( 0.0f, -1.0f, 0.0f );
            #elif defined( _REFRENCEPLANE_POSITIVEZ )
                return float3( 0.0f, 0.0f, 1.0f );
            #elif defined( _REFRENCEPLANE_NEGATIVEZ )
                return float3( 0.0f, 0.0f, -1.0f );
            #else
                return float3( 0.0f, 1.0f, 0.0f ); // return positive x by default
            #endif
            }

            // ============================================================================================================
            // 
            //   CASE 1
            // 
            // - In the below case the `worldPos` is less than the `curveLength` when measured from `PRP`, in this case
            //   the vector `originToRefrencePlane` is rotated around `O` by a fraction of degrees, the fraction is
            //   calculated using this formula:
            //
            //   ```
            //   fraction = length( PRP - worldPos ) / curveLength;
            //   newWorldPos = Rotate( point = originToRefrencePlane, origin = O, axis = A, degrees = _Degree * fraction );
            //   ```
            //
            //   Finally the worldPos is simply set to the vector rotated above.
            //
            //
            //                              ( axis's origin, assume the direction to be inside the plane, A )
            //                                                            |
            //                                                            |
            //                                                            v
            //                                                            x <- ( O )
            //                                                           /|
            //                                                          / |
            //                                                         /  |
            //                                ( originToWorldPos )--> /   | <--( originToRefrencePlane )
            //                                                       /    |
            //                                                      /     |
            //                                                     /      |
            //                                                    v       v
            //          <--------------------------------------- x ------ x -----------------------------------x
            //               ^                                   ^        ^
            //               |                                   |        |
            //        ( refrence plane )                   ( worldPos )( PRP )
            //                                                            
            //                                          <-----------------x
            //                                                   ^
            //                                                   |
            //                                            ( curveLength )
            //
            // ============================================================================================================
            // 
            //   CASE 2
            // 
            // - In the below case the `worldPos` is greater than the `curveLength` when measured from `PRP`, in this case
            //   two rotations are computed. We first rotate the vector `worldPos - T` by _Degree around our axis. And then
            //   we rotate the `originToRefrencePlane` vector again by _Degree, and finally we add the two to find the new
            //   world position. The pseudo code is as follows:
            //
            //   ```
            //   toRotate = worldPos - T;
            //   firstRotate = Rotate( point = toRotate, origin = O, axis = A, degrees = _Degree );
            // 
            //   offset = originToRefrencePlane;
            //   secondRotate = Rotate( point = offset, origin = O, axis = A, degrees = _Degree );
            // 
            //   -- since both `firstRotate` and `secondRotate` are vectors we need to determine there position, in this
            //   -- case `secondRotate` is relative to `O` so we can use `O` to determine the new world pos.
            // 
            //   newWorldPos = O + secondRotate + firstRotate;
            //   ```
            //
            //   Finally the worldPos is simply set to the vector rotated above.
            //
            //
            //                              ( axis's origin, assume the direction to be inside the plane, A )
            //                                                            |
            //                                                            |
            //                                                            v
            //                                                            x <- ( O )
            //                                                           /|
            //                                                          / |
            //                                                         /  |
            //                                ( originToWorldPos )--> /   | <--( originToRefrencePlane )
            //                                                       /    |
            //                                                      /     |
            //                                                     /      |
            //                                                    v       v
            //          <--------------------------------------- x --x--- x -----------------------------------x
            //               ^                                   ^   ^    ^
            //               |                                   |   |    |
            //        ( refrence plane )               ( worldPos )  |   ( PRP )
            //                                                     ( T )
            //                                                       <----x
            //                                                        ^
            //                                                        |
            //                                                 ( curveLength )
            //
            // ============================================================================================================
            //
            float3 Bend( float3 modelPos ) {
                // Since the input positions are just plain 3D coordinates it does not make sense
                // to rotate them about a point, that would just give a rotated world which can
                // easily be achieved by rotating the camera. So, in order to rotate the positions
                // we pick a refrence plane along which we calculate distance and determine weather
                // to rotate the positions or not.
                const float3 REFRENCE_PLANE = GetRefrencePlane();

                // we do all computations in world space
                float3 worldPos = TransformObjectToWorld( modelPos );

                // axis to rotate the positions around, normalized if not already done
                float3 rotationalAxis = normalize( _Axis.xyz );

                // projection of our world position on the rotational axis
                float3 pointOnAxis = ProjectPointOnRay( worldPos, _Origin.xyz, rotationalAxis );

                // projection of pointOnAxis to our refrence plane
                float3 perpToAxis = normalize( cross( REFRENCE_PLANE, rotationalAxis ) );
                float3 originOnPlane = ProjectPointOnRay( worldPos, pointOnAxis, perpToAxis );

                // amount of degrees to rotate
                float degree = _Degree;

                // determine the sign of degree depending on the relative position of worldPos from
                // the axis
                #ifdef AUTO_SIGN
                    float3 planeCrossVec = cross( REFRENCE_PLANE, normalize( pointOnAxis - worldPos ) );
                    degree *= sign( dot( rotationalAxis, planeCrossVec ) );
                #endif

                // This is a unique parameter which decide the distance from our axis till the curveLength.
                // Anything that lie in between this distance will be curved by a fraction of our degrees,
                // and anything beyond that will simple be rotated by a fixed amount.
                float curveLength = _CurveLength;

                // this distance is used to determine weather to rotate by a fraction of degrees or just
                // rotate the position completely
                float oopToWorld = length( worldPos - originOnPlane );

                // This is just to determine the direction of this position along the refrence plane when
                // seen from our axis origin. If the direction is negative we can simply ignore all transformations
                // and return our worldPos.
                float distDot = dot( worldPos - originOnPlane, REFRENCE_PLANE );
                if ( distDot < 0.0f )
                    return worldPos;

                // If the position from our axis to the worldPos along our refrence plane is greater than curveLength,
                // then the positions are rotated completely by degrees, otherwise they are rotated by a fraction of
                // degrees which is calculated in the `else` clause.
                if ( oopToWorld > curveLength ) {
                    // Here we determine our rotational axis for positions beyond `curveLength`. This lies on the refrence
                    // plane which passes through our worldPos. See `CASE 1` in the comment above function.
                    float3 toRotate = worldPos - originOnPlane;

                    // clamp our vector from new axis to our worldPos
                    toRotate = normalize( toRotate ) * ( oopToWorld - curveLength );

                    // rotate the new vector around the original axis
                    toRotate = Unity_RotateAboutAxis_Degrees_float( toRotate, rotationalAxis, degree );

                    // compute the offset vector which will be rotated by degrees, we can then just add our
                    // toRotate vector to this offset to compute the new position
                    float3 offset = Unity_RotateAboutAxis_Degrees_float( originOnPlane - pointOnAxis, rotationalAxis, degree );
                    worldPos = pointOnAxis + offset + toRotate;
                } else {
                    // In this case we simply determine the fraction of the degrees that we have to rotate and then
                    // rotate the `originOnPlane - pointOnAxis` vector around the axis by this fraction. See `CASE 2`
                    // in the comment above function.
                    float toRotate = lerp( 0, degree, oopToWorld / curveLength );
                    float3 rotatedPos = Unity_RotateAboutAxis_Degrees_float( originOnPlane - pointOnAxis, rotationalAxis, toRotate );

                    // the world pos simply becomes the rotated pos
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
