Shader "Hidden/Ink" {
    Properties {
        _MainTex ("Texture", 2D) = "white" {}
    }

    CGINCLUDE
        #include "UnityCG.cginc"

        sampler2D _MainTex, _CameraDepthTexture;
        sampler2D _PaperTex;
        sampler2D _NoiseTex;
        sampler2D _StippleTex;
        sampler2D _LuminanceTex;
        sampler2D _InkTex;
        float4 _NoiseTex_TexelSize;
        float4 _MainTex_TexelSize;
        float _ContrastThreshold;
        float _HighThreshold;
        float _LowThreshold;
        float _LuminanceCorrection;
        float _Contrast;
        float _StippleSize;
        uint _UsingImage;

        struct VertexData {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
        };

        struct v2f {
            float2 uv : TEXCOORD0;
            float4 vertex : SV_POSITION;
            float4 screenPosition : TEXCOORD1;
        };

        v2f vp(VertexData v) {
            v2f f;
            f.vertex = UnityObjectToClipPos(v.vertex);
            f.uv = v.uv;
            f.screenPosition = ComputeScreenPos(f.vertex);
            
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

                if ((0.0f <= theta && theta <= 45.0f) || (135.0f <= theta && theta <= 180.0f)) {
                    float northMag = tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(0, -1)).a;
                    float southMag = tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(0, 1)).a;

                    canny = Mag >= northMag && Mag >= southMag ? canny : 0.0f;
                } else if (45.0f <= theta && theta <= 135.0f) {
                    float westMag = tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(-1, 0)).a;
                    float eastMag = tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(1, 0)).a;

                    canny = Mag >= westMag && Mag >= eastMag ? canny : 0.0f;
                }

                return canny;
            }

            ENDCG
        }

        // Canny Double Threshold Pass
        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            float4 fp(v2f i) : SV_Target {
                float Mag = tex2D(_MainTex, i.uv).a;

                float4 result = 0.0f;

                if (Mag > _HighThreshold)
                    result = 1.0f;
                else if (Mag > _LowThreshold)
                    result = 0.5f;

                return result;
            }

            ENDCG
        }

        // Canny Hysteresis Pass
        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            float preserve(float2 uv) {
                int x, y;

                [unroll]
                for (x = -1; x <= 1; ++x) {
                    for (y = -1; y <= 1; ++y) {
                        if (x == 0 && y == 0) continue;

                        float2 nuv = uv + _MainTex_TexelSize * float2(x, y);
                        
                        half neighborStrength = tex2D(_MainTex, nuv).a;
                        if (neighborStrength == 1.0f) 
                            return 1.0f;
                    }
                }

                return 0.0f;
            }

            float4 fp(v2f i) : SV_Target {
                float strength = tex2D(_MainTex, i.uv).a;

                float4 result = strength;

                if (strength == 0.5f) {
                    result = preserve(i.uv);
                }

                return result;
            }

            ENDCG
        }

        // Line Width Pass
        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            float4 fp(v2f i) : SV_Target {
                int x, y;
                float4 ink = tex2D(_MainTex, i.uv);
                float luminance = tex2D(_LuminanceTex, i.uv).r;
                float depth = 1 - Linear01Depth(tex2D(_CameraDepthTexture, i.uv).r);
                depth = min(1.0f, max(0.0f, depth));


                float4 topNeighbor = tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(0, -1));
                float4 rightNeighbor = tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(1, -0));
                

                if ((topNeighbor.a != 0.0f || rightNeighbor.a != 0.0f) && luminance <= 0.7f) {
                    ink = !_UsingImage ? 1.0f * depth : 1.0f;
                }


                return ink;
            }

            ENDCG
        }

        // Diffusion (Anti Aliasing) Pass
        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            float4 fp(v2f i) : SV_Target {
                int x, y;
                float4 ink = tex2D(_MainTex, i.uv);

                float avg = 0.0f;
                /*
                for (x = -1; x <= 1; ++x) {
                    for (y = -1; y <= 1; ++y) {
                        //if (x == 0 && y == 0) continue;

                        float2 nuv = i.uv + _MainTex_TexelSize * float2(x, y);
                        
                        half neighbor = tex2D(_MainTex, nuv).r;
                        avg += neighbor;
                    }
                }
                */
                float n = tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(0, 1)).r;
                float e = tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(1, 0)).r;
                float s = tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(0, -1)).r;
                float w = tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(-1, 0)).r;

                avg = n + e + s + w + ink.r;

                return smoothstep(0.0, 1.0f, avg / 4.0f);
            }

            ENDCG
        }

        // Stippling Pass
        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            #include "Random.cginc"

            float4 fp(v2f i) : SV_Target {
                float luminance = tex2D(_MainTex, i.uv).a;


                float2 noiseCoord = i.screenPosition.xy / i.screenPosition.w;
                noiseCoord *= _ScreenParams.xy * _NoiseTex_TexelSize.xy;
                noiseCoord *= _StippleSize;
                float noise = tex2Dlod(_NoiseTex, float4(noiseCoord.x, noiseCoord.y, 0, 0)).a;

                luminance = _Contrast * (luminance - 0.5f) + 0.5f;
                luminance = min(1.0f, max(0.0f, luminance));
                luminance = pow(luminance, 1.0f / _LuminanceCorrection);
                luminance = min(1.0f, max(0.0f, luminance));
                

                return luminance < noise ? 1.0f : 0.0f;
            }

            ENDCG
        }
        
        // Combination Pass
        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            #include "Random.cginc"

            float4 fp(v2f i) : SV_Target {
                float edge = tex2D(_MainTex, i.uv).a;
                float4 stipple = tex2D(_StippleTex, i.uv);
                float depth = 1 - Linear01Depth(tex2D(_CameraDepthTexture, i.uv).r);
                depth = min(1.0f, max(0.0f, depth));

                float4 result = 1 - (edge + stipple);

                if (!_UsingImage) {
                    if (depth < 0.0001)
                        stipple *= depth;
                }

                return 1 - (edge + stipple);
            }

            ENDCG
        }

        // Color Pass
        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            #include "Random.cginc"

            float4 fp(v2f i) : SV_Target {
                float4 ink = tex2D(_InkTex, i.uv);
                float4 paper = tex2D(_PaperTex, i.uv);
                float col = tex2D(_MainTex, i.uv).r;

                
                return col >= 1.0f ? paper : ink;
            }

            ENDCG
        }
    }
}
