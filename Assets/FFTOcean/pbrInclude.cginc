#define PI 3.14159265359

//F(v,h)公式 cosTheta = v dot h
half3 fresnelSchlick(float cosTheta, half3 F0)
{
	return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

half3 DiffuseLambert(half3 diffuse)
{
	return diffuse / PI;
}

//D(h)GGX公式，计算法线分布
//alpha = roughness * roughness
float normalDistribution_GGX(float ndh, float alpha)
{
	float alphaPow = alpha * alpha;
	float t = ndh * ndh * (alphaPow - 1) + 1;
	return alphaPow / (PI * t * t);
}

float BeckmannNormalDistribution(float roughness, float NdotH)
{
	float roughnessSqr = roughness * roughness;
	float NdotHSqr = NdotH * NdotH;
	return max(0.000001, (1.0 / (3.1415926535 * roughnessSqr * NdotHSqr*NdotHSqr)) * exp((NdotHSqr - 1) / (roughnessSqr*NdotHSqr)));
}

//G(l,v,h)，计算微表面遮挡
float smith_schilck(float roughness, float ndv, float ndl)
{
	float k = (roughness + 1) * (roughness + 1) / 8;
	float Gv = ndv / (ndv * (1 - k) + k);
	float Gl = ndl / (ndl * (1 - k) + k);
	return Gv * Gl;
}

half3 brdf(half3 fresnel, float D, float G, float ndv, float ndl)
{
	return fresnel * D * G / (4 * ndv * ndl + 0.0001);
}