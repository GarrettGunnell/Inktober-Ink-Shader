Shader "Hidden/Ink" {
    Properties {
        _MainTex ("Texture", 2D) = "white" {}
    }

    CGINCLUDE
        #include "UnityCG.cginc"

        sampler2D _MainTex;
        sampler2D _PaperTex;
        float4 _MainTex_TexelSize;
        float _ContrastThreshold;
        float _HighThreshold;
        float _LowThreshold;

        struct VertexData {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
        };

        struct v2f {
            float2 uv : TEXCOORD0;
            float4 vertex : SV_POSITION;
        };

        v2f vp(VertexData v) {
            v2f f;
            f.vertex = UnityObjectToClipPos(v.vertex);
            f.uv = v.uv;
            
            return f;
        }
    ENDCG

    SubShader {
        Cull Off ZWrite Off ZTest Always

        // Luminance Pass
        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            fixed4 fp(v2f i) : SV_Target {
                return LinearRgbToLuminance(tex2D(_MainTex, i.uv));
            }

            ENDCG
        }

        // Edge Detection By Contrast
        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            half SampleLuminance(float2 uv) {
                return tex2D(_MainTex, uv).a;
            }

            half SampleLuminance(float2 uv, float uOffset, float vOffset) {
                uv += _MainTex_TexelSize * float2(uOffset, vOffset);
                return SampleLuminance(uv);
            }

            fixed4 fp(v2f i) : SV_Target {
                half m = SampleLuminance(i.uv);
                half n = SampleLuminance(i.uv, 0, 1);
                half e = SampleLuminance(i.uv, 1, 0);
                half s = SampleLuminance(i.uv, 0, -1);
                half w = SampleLuminance(i.uv, -1, 0);
                half highest = max(max(max(max(n, e), s), w), m);
                half lowest = min(min(min(min(n, e), s), w), m);
                half contrast = highest - lowest;
                
                return contrast;
            }

            ENDCG
        }

        // Edge Detection By Sobel-Feldman Operator
        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            fixed4 fp(v2f i) : SV_Target {
                int x, y;

                int3x3 Kx = {
                    1, 0, -1,
                    2, 0, -2,
                    1, 0, -1
                };

                int3x3 Ky = {
                    1, 2, 1,
                    0, 0, 0,
                    -1, -2, -1
                };

                float Gx = 0.0f;
                float Gy = 0.0f;

                for (x = -1; x <= 1; ++x) {
                    for (y = -1; y <= 1; ++y) {
                        float2 uv = i.uv + _MainTex_TexelSize * float2(x, y);
                        
                        half l = tex2D(_MainTex, uv).a;
                        Gx += Kx[x + 1][y + 1] * l;
                        Gy += Ky[x + 1][y + 1] * l;
                    }
                }

                float Mag = sqrt(Gx * Gx + Gy * Gy);
                
                return Mag;
            }

            ENDCG
        }

        // Edge Detection By Prewitt Operator
        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            fixed4 fp(v2f i) : SV_Target {
                int x, y;

                int3x3 Kx = {
                    1, 0, -1,
                    1, 0, -1,
                    1, 0, -1
                };

                int3x3 Ky = {
                    1, 1, 1,
                    0, 0, 0,
                    -1, -1, -1
                };

                float Gx = 0.0f;
                float Gy = 0.0f;

                for (x = -1; x <= 1; ++x) {
                    for (y = -1; y <= 1; ++y) {
                        float2 uv = i.uv + _MainTex_TexelSize * float2(x, y);
                        
                        half l = tex2D(_MainTex, uv).a;
                        Gx += Kx[x + 1][y + 1] * l;
                        Gy += Ky[x + 1][y + 1] * l;
                    }
                }

                float Mag = sqrt(Gx * Gx + Gy * Gy);
                
                return Mag;
            }

            ENDCG
        }

        // Canny Intensity Pass (Sobel-Feldman)
        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            float4 fp(v2f i) : SV_Target {
                int x, y;

                int3x3 Kx = {
                    1, 0, -1,
                    2, 0, -2,
                    1, 0, -1
                };

                int3x3 Ky = {
                    1, 2, 1,
                    0, 0, 0,
                    -1, -2, -1
                };

                float Gx = 0.0f;
                float Gy = 0.0f;

                for (x = -1; x <= 1; ++x) {
                    for (y = -1; y <= 1; ++y) {
                        float2 uv = i.uv + _MainTex_TexelSize * float2(x, y);
                        
                        half l = tex2D(_MainTex, uv).a;
                        Gx += Kx[x + 1][y + 1] * l;
                        Gy += Ky[x + 1][y + 1] * l;
                    }
                }

                float Mag = sqrt(Gx * Gx + Gy * Gy);
                float theta = abs(atan2(Gy, Gx));

                return float4(Gx, Gy, theta, Mag);
            }

            ENDCG
        }

        // Canny Magnitude Suppression Pass
        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            float4 fp(v2f i) : SV_Target {
                float4 canny = tex2D(_MainTex, i.uv);

                float Mag = canny.a;
                float theta = degrees(canny.b);

                float4 result = 0.0f;

                if ((0.0f <= theta && theta <= 45.0f) || (135.0f <= theta && theta <= 180.0f)) {
                    float northMag = tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(0, -1)).a;
                    float southMag = tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(0, 1)).a;

                    result = Mag >= northMag && Mag >= southMag ? canny : 0.0f;
                } else if (45.0f <= theta && theta <= 135.0f) {
                    float westMag = tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(-1, 0)).a;
                    float eastMag = tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(1, 0)).a;

                    result = Mag >= westMag && Mag >= eastMag ? canny : 0.0f;
                }

                return result;
            }

            ENDCG
        }

        // Canny Double Threshold Pass
        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            float4 fp(v2f i) : SV_Target {
                float4 Mag = tex2D(_MainTex, i.uv).a;
                
                float4 result = 0.0f;

                if (Mag > _HighThreshold)
                    result = 1.0f;
                else if (Mag > _LowThreshold)
                    result = float4(1.0f, 1.0f, 1.0f, 0.0f);

                return result;
            }

            ENDCG
        }
    }
}
