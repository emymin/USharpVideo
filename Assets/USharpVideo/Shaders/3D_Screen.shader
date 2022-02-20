Shader "Unlit/3D_Screen"
{
    Properties
    {
        _EmissionMap ("Texture", 2D) = "black" {}
        [Toggle]_Enable3D("Toggle 3D mode",Float)=0
        [KeywordEnum(2D,Side By Side,Over Under,Anaglyph)]_Mode("3D Mode",Float)=0
        [Toggle]_2DMode("Toggle adjusted 2D mode",Float)=0
        [Toggle]_IsAVProInput("Is input from AVPro",Int)=0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            #pragma multi_compile
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _EmissionMap;
            float4 _EmissionMap_ST;
            float4 _EmissionMap_TexelSize;
            float _Enable3D;
            float _Mode;
            float _2DMode;
            int _IsAVProInput;

            #define UMP UNITY_MATRIX_P
			inline float4 CalculateObliqueFrustumCorrection()
			{
				float x1 = -UMP._31 / (UMP._11 * UMP._34);
				float x2 = -UMP._32 / (UMP._22 * UMP._34);
				return float4(x1, x2, 0, UMP._33 / UMP._34 + x1 * UMP._13 + x2 * UMP._23);
			}
			static float4 ObliqueFrustumCorrection = CalculateObliqueFrustumCorrection();
			inline float CorrectedLinearEyeDepth(float z, float correctionFactor)
			{
				return 1.f / (z / UMP._34 + correctionFactor);
			}
			// Merlin's mirror detection
			inline bool CalculateIsInMirror()
			{
				return UMP._31 != 0.f || UMP._32 != 0.f;
			}
			static bool IsInMirror = CalculateIsInMirror();
			#undef UMP



            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _EmissionMap);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 GetCol(sampler2D tex,float2 uv){
                return _IsAVProInput == 0 ? tex2D(tex,uv) : float4(pow(tex2D(tex, float2(uv.x, 1 - uv.y)).rgb, 2.2f),1);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv;
                if(IsInMirror){
                    uv.x=1-uv.x;
                }

                float eye_index=float(unity_StereoEyeIndex);
                fixed4 col;
                if(_Enable3D==1){
                    if(_2DMode==1) eye_index=0;
                    if(_Mode==1){
                        uv.x*=0.5;
                        uv.x+=0.5*eye_index;
                    }
                    if(_Mode==2){
                        uv.y*=0.5;
                        uv.y+=0.5*eye_index;
                    }
                    col = GetCol(_EmissionMap, uv);
                    if(_Mode==3){
                        if(eye_index==0) col.gb=0;
                        if(eye_index==1) col.r=0;
                    }
                }else{ 
                    float2 resolution = _EmissionMap_TexelSize.zw;
                    float2 defaultresolution = float2(16,9);
                    float default_ratio = defaultresolution.x / defaultresolution.y;
                    float2 normalizedres = float2(resolution.x / default_ratio, resolution.y);
                    float2 ratioed_scale = normalizedres.x > normalizedres.y ? float2(1, normalizedres.y/normalizedres.x) : float2(normalizedres.x/normalizedres.y, 1);
                    uv = ((uv - .5) / ratioed_scale) + .5;

                    float2 uvPadding = (1 / resolution) * 0.1;
                    float2 uvfwidth = fwidth(uv.xy);
                    float2 maxFactor = smoothstep(uvfwidth + uvPadding + 1, uvPadding + 1, uv.xy);
                    float2 minFactor = smoothstep(-uvfwidth - uvPadding, -uvPadding, uv.xy);

                    float visibility = maxFactor.x * maxFactor.y * minFactor.x * minFactor.y;


                    col = GetCol(_EmissionMap, uv)*visibility;
                
                }
                
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
