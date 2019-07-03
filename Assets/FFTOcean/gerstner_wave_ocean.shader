// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "liangairan/ocean/gerstner_wave_ocean" {
// 　　　　　　D(h) F(v,h) G(l,v,h)
//f(l,v) = ---------------------------
// 　　　　　　4(n·l)(n·v)
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Wave1("Wave1 x-wavelength y-amplitude z-speed w-steepness",Vector) = (30,1.5, 100, 0.3)
		_Wave2("Wave2",Vector) = (20,0.3,30,0.1)
		_Wave3("Wave3",Vector) = (15,1.2,20,0.5)
		_StartX("startX", Float) = 0

		_C1("WaveC1 xy-horizontal direction of wave", Vector) = (1,0,1,1)
		_C2("WaveC2", Vector) = (-0.3,0.8,1,1)
		_C3("WaveC3", Vector) = (0.3,0.9,1,1)
		_Transparent("Transparent", Float) = 0.7

	}
	SubShader {
		Tags { "Queue" = "Transparent" "RenderType" = "Transparent"}
		LOD 200
		
        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest Off
			ZWrite Off

            CGPROGRAM
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma exclude_renderers xbox360 flash	
            #pragma multi_compile_fwdbase 
            #define PI 3.14159265359

            sampler2D _MainTex;

			fixed4 _Color;

			float4 _Wave1;
			float4 _Wave2;
			float4 _Wave3;
			float _StartX;
			float4 _C1;
			float4 _C2;
			float4 _C3;
			float _Transparent;

            struct appdata
            {
                half4 vertex : POSITION;
                half4 color : COLOR;
                half2 uv : TEXCOORD0;
                half3 normal : NORMAL;
				half3 tangent: TANGENT;
            };

            struct VSOut
            {
                half4 pos		: SV_POSITION;
                half4 color     : COLOR;
                half2 uv : TEXCOORD0;
                half3 normalWorld : TEXCOORD1;
                half3 posWorld : TEXCOORD2;
				half3 tangentWorld : TEXCOORD3;
                SHADOW_COORDS(4)
            };

			float4 DisVec(float4 v, fixed i)
			{

				if (i == 1)
				{
					return normalize(v - _C1);
				}
				else if (i == 2)
				{
					return normalize(v - _C2);
				}
				else if (i == 3)
				{
					return normalize(v - _C3);
				}

			}

			float DiDotXY(float4 v, fixed i)
			{
				return dot(DisVec(v, i), v);
			}

			float fresnel(float3 V, float3 N)
			{

				half NdotL = max(dot(V, N), 0.0);
				half fresnelBias = 0.4;
				half fresnelPow = 5.0;
				fresnelPow = 0.8;

				half facing = (1.0 - NdotL);
				return max(fresnelBias + (1 - fresnelBias) * pow(facing, fresnelPow), 0.0);
			}

			float4 GerstnerWave(float4 v, float t, out float3 normal)
			{
				fixed A = 0;//振幅
				fixed W = 1;//角速度
				fixed Q = 2;//初相
				fixed Step = 3;//陡度控制

				

				float CT1 = cos(_Wave1[W] * DiDotXY(v, 1) + _Wave1[Q] * t);
				float CT2 = cos(_Wave2[W] * DiDotXY(v, 2) + _Wave2[Q] * t);
				float CT3 = cos(_Wave3[W] * DiDotXY(v, 3) + _Wave3[Q] * t);

				float xT = v.x + _Wave1[Step] * _Wave1[A] * DisVec(v, 1).x * CT1
					+ _Wave2[Step] * _Wave2[A] * DisVec(v, 2).x * CT2
					+ _Wave3[Step] * _Wave3[A] * DisVec(v, 3).x * CT3;

				float yT = _Wave1[A] * sin(_Wave1[W] * DiDotXY(v, 1) + _Wave1[Q] * t)
					+ _Wave2[A] * sin(_Wave2[W] * DiDotXY(v, 2) + _Wave2[Q] * t)
					+ _Wave3[A] * sin(_Wave3[W] * DiDotXY(v, 3) + _Wave3[Q] * t);

				float zT = v.z + _Wave1[Step] * _Wave1[A] * DisVec(v, 1).z * CT1
					+ _Wave2[Step] * _Wave2[A] * DisVec(v, 2).z * CT2
					+ _Wave3[Step] * _Wave3[A] * DisVec(v, 3).z * CT3;

				float4 P = float4(xT, yT, zT, v.w);

				//法线计算
				float DP1 = dot(DisVec(v, 1), P);
				float DP2 = dot(DisVec(v, 2), P);
				float DP3 = dot(DisVec(v, 3), P);

				float C1 = cos(_Wave1[W] * DP1 + _Wave1[Q] * t);
				float C2 = cos(_Wave2[W] * DP2 + _Wave2[Q] * t);
				float C3 = cos(_Wave3[W] * DP3 + _Wave3[Q] * t);

				float nXT = -1 * (DisVec(v, 1).x * _Wave1[W] * _Wave1[A] * C1)
					- (DisVec(v, 2).x * _Wave2[W] * _Wave2[A] * C2)
					- (DisVec(v, 3).x * _Wave3[W] * _Wave3[A] * C3);

				float nYT = 1 - _Wave1[Step] * _Wave1[W] * _Wave1[A] * sin(_Wave1[W] * DP1 + _Wave1[Q] * t)
					- _Wave2[Step] * _Wave2[W] * _Wave2[A] * sin(_Wave2[W] * DP2 + _Wave2[Q] * t)
					- _Wave3[Step] * _Wave3[W] * _Wave3[A] * sin(_Wave3[W] * DP3 + _Wave3[Q] * t);

				float nZT = -1 * (DisVec(v, 1).z * _Wave1[W] * _Wave1[A] * C1)
					- (DisVec(v, 2).z * _Wave2[W] * _Wave2[A] * C2)
					- (DisVec(v, 3).z * _Wave3[W] * _Wave3[A] * C3);

				normal = float3(nXT, nYT, nZT);

				return P;
			}

			float4 GerstnerWave1(float4 v, float t, out float3 normal)
			{
				float waveLength1 = _Wave1.x;   //波长
				float amplitude1 = _Wave1.y;    //振幅
				float speed1 = _Wave1.z;
				float frequency1 = 2 * PI / waveLength1;
				float steepness1 = _Wave1.w;    //steepness陡度
				float phase1 = speed1 * 2 * PI / waveLength1;   //初相

				float waveLength2 = _Wave2.x;   //波长
				float amplitude2 = _Wave2.y;    //振幅
				float speed2 = _Wave2.z;
				float frequency2 = 2 * PI / waveLength2;
				float steepness2 = _Wave1.w;    //steepness陡度
				float phase2 = speed2 * 2 * PI / waveLength2;   //初相

				float waveLength3 = _Wave3.x;   //波长
				float amplitude3 = _Wave3.y;    //振幅
				float speed3 = _Wave3.z;
				float frequency3 = 2 * PI / waveLength3;
				float steepness3 = _Wave3.w;    //steepness陡度
				float phase3 = speed3 * 2 * PI / waveLength3;   //初相

				float dot1 = dot(normalize(_C1.xy), v.xz);
				float dot2 = dot(normalize(_C2.xy), v.xz);
				float dot3 = dot(normalize(_C3.xy), v.xz);
				float x = v.x + steepness1 * amplitude1 * _C1.x * cos(frequency1 * dot1 + phase1 * t)
					+ steepness2 * amplitude2 * _C2.x * cos(frequency2 * dot2 + phase2 * t)
					+ steepness3 * amplitude3 * _C3.x * cos(frequency3 * dot3 + phase3 * t);

				float z = v.z + steepness1 * amplitude1 * _C1.y * cos(frequency1 * dot1 + phase1 * t)
					+ steepness2 * amplitude2 * _C2.y * cos(frequency2 * dot2 + phase2 * t)
					+ steepness3 * amplitude3 * _C3.y * cos(frequency3 * dot3 + phase3 * t);

				float y = amplitude1 * sin(amplitude1 * dot1 + phase1 * t) + amplitude2 * sin(amplitude2 * dot2 + phase2 * t)
					+ amplitude3 * sin(amplitude3 * dot3 + phase3 * t);


				float4 P = float4(x, y, z, v.w);

				float wa1 = frequency1 * amplitude1;
				float wa2 = frequency2 * amplitude2;
				float wa3 = frequency3 * amplitude3;

				float s1 = sin(frequency1 * dot(normalize(_C1.xy), P.xz) + phase1 * t);
				float s2 = sin(frequency2 * dot(normalize(_C2.xy), P.xz) + phase2 * t);
				float s3 = sin(frequency3 * dot(normalize(_C3.xy), P.xz) + phase3 * t);

				float c1 = cos(frequency1 * dot(normalize(_C1.xy), P.xz) + phase1 * t);
				float c2 = cos(frequency2 * dot(normalize(_C2.xy), P.xz) + phase2 * t);
				float c3 = cos(frequency3 * dot(normalize(_C3.xy), P.xz) + phase3 * t);

				float xn = -(_C1.x * wa1 * c1 + _C2.x * wa2 * c2 + _C3.x * wa3 * c3);
				float yn = 1 - (steepness1 * wa1 * s1 + steepness2 * wa2 * s2 + steepness3 * wa3 * s3);
				float zn = -(_C1.y * wa1 * c1 + _C2.y * wa2 * c2 + _C3.y * wa3 * c3);

				normal = float3(xn, yn, zn);

				return P;
			}

            VSOut vert(appdata v)
            {
                VSOut o;
                o.color = v.color;
				v.vertex = GerstnerWave1(v.vertex, _Time.x, v.normal);
                o.pos = UnityObjectToClipPos(v.vertex);
                //TANGENT_SPACE_ROTATION;
                o.uv = v.uv;
				
                o.normalWorld = UnityObjectToWorldNormal(v.normal);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
				o.tangentWorld = UnityObjectToWorldDir(v.tangent.xyz);
                TRANSFER_SHADOW(o);
                return o;
            }

            half4 frag(VSOut i) : COLOR
            {
                fixed3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
                fixed3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
                fixed3 normalDirection = normalize(i.normalWorld); //UnpackNormal(tex2D(_NormalTex, i.uv));
				float3 vDir = normalize(_WorldSpaceCameraPos - i.posWorld);
				float fr = fresnel(vDir, i.normalWorld);
                fixed4 albedo = i.color * tex2D(_MainTex, i.uv) * _Color;
				albedo.a = _Transparent;
                
				return albedo * fr;
            }
            ENDCG
        }
	}
    FallBack "Diffuse"
}