// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "liangairan/ocean/fft_ocean" {
// 　　　　　　D(h) F(v,h) G(l,v,h)
//f(l,v) = ---------------------------
// 　　　　　　4(n·l)(n·v)
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_FoamColor("Foam Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_HeightTex("HeightTex (RGB)", 2D) = "white" {}
		//_HeightScale("HeightScale", Range(1, 100)) = 1
		_ChoppyScale("ChoppyScale",Range(0.1,10)) = 1
		Kdiffuse("Kdiffuse", Range(0,10)) = 0.91
		_ReflectScale("ReflectScale", Range(0,10)) = 2.0
		_NormalMap("NormalMap (RGB)", 2D) = "white" {}
		_EnvironmentMap("EnvironmentMap", Cube) = "_Skybox" {}
		_Roughness("Roughness", Range(0, 1)) = 0.15
	}
	SubShader {
		Tags { "RenderType" = "Opaque"}
		LOD 200
		
        Pass
        {
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"
			#include "pbrInclude.cginc"
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma exclude_renderers xbox360 flash	
            #pragma multi_compile_fwdbase 
            #define PI 3.14159265359

            sampler2D _MainTex;
			sampler2D _HeightTex;
			sampler2D _NormalMap;
			samplerCUBE _EnvironmentMap;

			fixed4 _Color;
			fixed4 _FoamColor;
			//uniform float _HeightScale;
			uniform float _ChoppyScale;
			float Kdiffuse = 0.91;
			float _ReflectScale;
			uniform float texelSize;
			uniform float resolution;
			float _Roughness;

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
            };


			float fresnel(float3 V, float3 N)
			{

				half NdotL = max(dot(V, N), 0.0);
				half fresnelBias = 0.4;
				half fresnelPow = 5.0;
				fresnelPow = 0.8;

				half facing = (1.0 - NdotL);
				return max(fresnelBias + (1 - fresnelBias) * pow(facing, fresnelPow), 0.0);
			}

            VSOut vert(appdata v)
            {
                VSOut o;
                o.color = v.color;

				float4 heightMap = tex2Dlod(_HeightTex, float4(v.uv, 0, 0));
				v.vertex.xyz += float3(heightMap.x * _ChoppyScale, heightMap.y, heightMap.z * _ChoppyScale);
                o.pos = UnityObjectToClipPos(v.vertex);
                //TANGENT_SPACE_ROTATION;
                o.uv = v.uv;
				
                o.normalWorld = UnityObjectToWorldNormal(v.normal);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
				o.tangentWorld = UnityObjectToWorldDir(v.tangent.xyz);
                return o;
            }

            half4 frag(VSOut i) : COLOR
            {
				//fixed4 upwelling = fixed4(0, 0.2, 0.3, 1.0);
				fixed4 sky = fixed4(0.69, 0.84, 1.0, 1.0);
				fixed4 air = fixed4(0.1, 0.1, 0.1, 1.0);
				float nSnell = 1.34;  //水的折射率
				

                fixed3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
                fixed3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
				//fixed4 normalDirection = tex2D(_NormalMap, i.uv);//normalize(i.normalWorld); //UnpackNormal(tex2D(_NormalTex, i.uv));

				float3 offset = float3(-1 / resolution, 0, 1 / resolution);

				float4 xLeft = tex2D(_HeightTex, i.uv + offset.xy);
				float4 xRight = tex2D(_HeightTex, i.uv + offset.zy);
				float4 yTop = tex2D(_HeightTex, i.uv + offset.yx);
				float4 yBottom = tex2D(_HeightTex, i.uv + offset.yz);

				float3 tangentR2L = float3(2.0 * texelSize, (xRight.y - xLeft.y), 0);
				float3 binormalT2B = float3(0, (yBottom.y - yTop.y), 2.0 * texelSize);
				float3 normal = cross(binormalT2B, tangentR2L);
				float2 dx = (xRight.xz - xLeft.xz);
				float2 dz = (yBottom.xz - yTop.xz);
				//float dxz = 1 + (xRight.z - xLeft.z) * N * 0.5;
				float Jacobian = (1.0f + dx.x) * (1.0f + dz.y) - dx.y * dz.x;
				float fold = max(1.0f - saturate(Jacobian), 0);

				fixed3 normalDirection = normalize(normal);
				//return normalDirection;
				normalDirection.xyz = UnityObjectToWorldNormal(normalDirection.xyz);
				

				fixed3 R = reflect(-viewDirection, normalDirection.xyz);

				float reflectivity;
				float costhetai = abs(dot(lightDirection, normalDirection.xyz));
				float thetai = acos(costhetai);
				float sinthetat = sin(thetai) / nSnell;
				float thetat = asin(sinthetat);
				if (thetai == 0.0)
				{
					reflectivity = (nSnell - 1) / (nSnell + 1);
					reflectivity = reflectivity * reflectivity;
				}
				else
				{
					float fs = abs(sin(thetat - thetai) / sin(thetat + thetai));
					float ts = abs(tan(thetat - thetai) / tan(thetat + thetai));
					reflectivity = 0.5 * (fs * fs + ts * ts);
				}


				float dist = length(_WorldSpaceCameraPos.xyz - i.posWorld.xyz) * Kdiffuse;
				dist = exp(-dist);
				sky = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, R);
				//return sky;
				//fixed4 Ci = dist * (reflectivity * sky + (1 - reflectivity) * _Color) + (1 - dist) * air;
				fixed4 Ci = lerp(_Color, sky, reflectivity); // (reflectivity * sky + (1 - reflectivity) * _Color);
				float foam = fold * fold;
				
				fixed3 h = normalize(lightDirection + viewDirection);
				float NdL = max(dot(normalDirection, lightDirection), 0);
				float NdV = max(dot(normalDirection, viewDirection), 0);
				float VdH = max(dot(viewDirection, h), 0);
				float NdH = max(dot(normalDirection, h), 0);
				float D = BeckmannNormalDistribution(_Roughness, NdH);
				float G = smith_schilck(_Roughness, NdV, NdH);
				half3 F = fresnelSchlick(VdH, _LightColor0.xyz);
				fixed3 specular = brdf(F, D, G, NdV, NdL) * reflectivity;

				Ci += fixed4(specular, 0);
				//return Ci;
				return lerp(Ci, _FoamColor, foam);
            }
            ENDCG
        }
	}
    FallBack "Diffuse"
}