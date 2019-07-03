using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

//[ExecuteInEditMode]
public class Ocean : MonoBehaviour
{
    // Start is called before the first frame update
    Mesh mOceanMesh;
    Material mMaterial;
    //GameObject mOceanObject;
    private Vector3[] mVertices;
    private Vector3[] mNormals;
    private Vector2[] mUVs;
    private int[] mTriangles;

    public RenderTexture mh0;
    public RenderTexture mHeightTexture;
    public RenderTexture mGaussionRandom;
    public RenderTexture mButterflyTexture;
    public RenderTexture mPingpong0;
    public RenderTexture mPingpong1;

    public RenderTexture mPingpongChoppy0;
    public RenderTexture mPingpongChoppy1;
    public RenderTexture mNormalMap;

    private RenderTexture[] mPingpongs = new RenderTexture[2];
    private RenderTexture[] mPingpongChoppys = new RenderTexture[2];

    public Vector2 mWindDirection = new Vector2(1.0f, 1.0f);
    public float A = 1.5f;
    public float mWindSpeed = 10.0f;

    int mResolution = 256;
    float length = 0.5f;
    private float mPatchSize;

    public ComputeShader mComputeShader;

    public Color waterColor = new Color(9, 45, 103);
    public Color foamColor = Color.white;
    public float mHeightScale = 1.0f;

    void Start()
    {
        mVertices = new Vector3[mResolution * mResolution];
        mNormals = new Vector3[mResolution * mResolution];
        mUVs = new Vector2[mResolution * mResolution];

        mTriangles = new int[(mResolution - 1) * (mResolution - 1) * 6];

        int nIndex = 0;
        for (int i = 0; i < mResolution; ++i)
        {
            for (int j = 0; j < mResolution; ++j)
            {
                nIndex = i * mResolution + j;

                mVertices[nIndex] = new Vector3(i * length, 0, j * length);

                mUVs[nIndex] = new Vector2((float)i / (mResolution - 1), (float)j / (mResolution - 1));

                mNormals[nIndex] = new Vector3(0, 1, 0);
            }
        }

        nIndex = 0;
        for (int i = 0; i < mResolution - 1; ++i)
        {
            for (int j = 0; j < mResolution - 1; ++j)
            {
                mTriangles[nIndex++] = i * mResolution + j;
                mTriangles[nIndex++] = i * mResolution + j + 1;
                mTriangles[nIndex++] = (i + 1) * mResolution + j;
                mTriangles[nIndex++] = i * mResolution + j + 1;
                mTriangles[nIndex++] = (i + 1) * mResolution + j + 1;
                mTriangles[nIndex++] = (i + 1) * mResolution + j;
            }
        }

        if (mOceanMesh != null)
        {
            mOceanMesh.Clear();
        }
        mOceanMesh = new Mesh();
        mOceanMesh.vertices = mVertices;
        mOceanMesh.uv = mUVs;
        mOceanMesh.triangles = mTriangles;

        MeshRenderer renderer = gameObject.GetComponent<MeshRenderer>();
        if (renderer == null)
        {
            gameObject.AddComponent<MeshRenderer>();
        }
        
        MeshFilter meshFilter = gameObject.GetComponent<MeshFilter>();
        if (meshFilter == null)
        {
            meshFilter = gameObject.AddComponent<MeshFilter>();
        }
        meshFilter.mesh = mOceanMesh;

        if (mMaterial == null)
        {
            mMaterial = new Material(Shader.Find("liangairan/ocean/fft_ocean"));

            gameObject.GetComponent<Renderer>().sharedMaterial = mMaterial;
            mMaterial.SetColor("_Color", waterColor);
            mMaterial.SetColor("_FoamColor", foamColor);
            mMaterial.SetFloat("texelSize", length);
            mMaterial.SetFloat("resolution", mResolution);
        }

        mPatchSize = mResolution * length;

        RunComputeShader();

        mMaterial.SetTexture("_HeightTex", mHeightTexture);
        mMaterial.SetTexture("_NormalMap", mNormalMap);
    }

    // Update is called once per frame
    void Update()
    {
        if (mComputeShader != null)
        {
            int kGenerateHeight = mComputeShader.FindKernel("GenerateHeight");

            mComputeShader.SetTexture(kGenerateHeight, "H0InputTexture", mh0);
            mComputeShader.SetTexture(kGenerateHeight, "HeightTexture", mPingpong0);   //这个时候pingpong0作为第一个输入
            mComputeShader.SetTexture(kGenerateHeight, "ChoppyTexture", mPingpongChoppy0);   //这个时候pingpong0作为第一个输入
            mComputeShader.SetFloat("time", Time.time);

            mComputeShader.Dispatch(kGenerateHeight, 256 / 8, 256 / 8, 1);


            int maxStage = (int)(Mathf.Log(256) / Mathf.Log(2));

            int kIFFTHorizontalHeight = mComputeShader.FindKernel("IFFTHorizontalHeight");
            mComputeShader.SetTexture(kIFFTHorizontalHeight, "ButterflyInput", mButterflyTexture);
            int inputPingPong = 0;
            int outputPingPong = 1;
            int pingpongIndex = 0;
            
            for (int i = 0; i < maxStage; ++i)
            {
                mComputeShader.SetInt("stage", i);
                mComputeShader.SetTexture(kIFFTHorizontalHeight, "PingpongInput", mPingpongs[inputPingPong]);
                mComputeShader.SetTexture(kIFFTHorizontalHeight, "PingpongOutput", mPingpongs[outputPingPong]);
                //mComputeShader.SetTexture(kIFFTHorizontalHeight, "PingpongChoppyInput", mPingpongChoppys[inputPingPong]);
                //mComputeShader.SetTexture(kIFFTHorizontalHeight, "PingpongChoppyOutput", mPingpongChoppys[outputPingPong]);
                pingpongIndex++;
                inputPingPong = pingpongIndex % 2;
                outputPingPong = (pingpongIndex + 1) % 2;

                mComputeShader.Dispatch(kIFFTHorizontalHeight, 256 / 8, 256 / 8, 1);
            }
            
            int kIFFTVerticalHeight = mComputeShader.FindKernel("IFFTVerticalHeight");
            mComputeShader.SetTexture(kIFFTVerticalHeight, "ButterflyInput", mButterflyTexture);
            for (int i = 0; i < maxStage; ++i)
            {
                mComputeShader.SetInt("stage", i);
                mComputeShader.SetTexture(kIFFTVerticalHeight, "PingpongInput", mPingpongs[inputPingPong]);
                mComputeShader.SetTexture(kIFFTVerticalHeight, "PingpongOutput", mPingpongs[outputPingPong]);
                //mComputeShader.SetTexture(kIFFTVerticalHeight, "PingpongChoppyInput", mPingpongChoppys[inputPingPong]);
                //mComputeShader.SetTexture(kIFFTVerticalHeight, "PingpongChoppyOutput", mPingpongChoppys[outputPingPong]);
                pingpongIndex++;
                inputPingPong = pingpongIndex % 2;
                outputPingPong = (pingpongIndex + 1) % 2;

                mComputeShader.Dispatch(kIFFTVerticalHeight, 256 / 8, 256 / 8, 1);
            }

            //处理choppy
            int inputPingPongChoppy = 0;
            int outputPingPongChoppy = 1;
            pingpongIndex = 0;

            int kIFFTHorizontalChoppy = mComputeShader.FindKernel("IFFTHorizontalChoppy");
            mComputeShader.SetTexture(kIFFTHorizontalChoppy, "ButterflyInput", mButterflyTexture);
            for (int i = 0; i < maxStage; ++i)
            {
                mComputeShader.SetInt("stage", i);
                mComputeShader.SetTexture(kIFFTHorizontalChoppy, "PingpongChoppyInput", mPingpongChoppys[inputPingPongChoppy]);
                mComputeShader.SetTexture(kIFFTHorizontalChoppy, "PingpongChoppyOutput", mPingpongChoppys[outputPingPongChoppy]);
                pingpongIndex++;
                inputPingPongChoppy = pingpongIndex % 2;
                outputPingPongChoppy = (pingpongIndex + 1) % 2;

                mComputeShader.Dispatch(kIFFTHorizontalChoppy, 256 / 8, 256 / 8, 1);
            }

            int kIFFTVerticalChoppy = mComputeShader.FindKernel("IFFTVerticalChoppy");
            mComputeShader.SetTexture(kIFFTVerticalChoppy, "ButterflyInput", mButterflyTexture);
            for (int i = 0; i < maxStage; ++i)
            {
                mComputeShader.SetInt("stage", i);
                mComputeShader.SetTexture(kIFFTVerticalChoppy, "PingpongChoppyInput", mPingpongChoppys[inputPingPongChoppy]);
                mComputeShader.SetTexture(kIFFTVerticalChoppy, "PingpongChoppyOutput", mPingpongChoppys[outputPingPongChoppy]);
                pingpongIndex++;
                inputPingPongChoppy = pingpongIndex % 2;
                outputPingPongChoppy = (pingpongIndex + 1) % 2;

                mComputeShader.Dispatch(kIFFTVerticalChoppy, 256 / 8, 256 / 8, 1);
            }


            int kFinalHeight = mComputeShader.FindKernel("FinalHeight");
            mComputeShader.SetTexture(kFinalHeight, "PingpongInput", mPingpongs[inputPingPong]);
            mComputeShader.SetTexture(kFinalHeight, "PingpongChoppyInput", mPingpongChoppys[inputPingPongChoppy]);
            mComputeShader.SetTexture(kFinalHeight, "HeightTexture", mHeightTexture);
            mComputeShader.SetFloat("heightScale", mHeightScale);
            mComputeShader.Dispatch(kFinalHeight, 256 / 8, 256 / 8, 1);

            int kNormalMap = mComputeShader.FindKernel("GenerateNormalMap");
            mComputeShader.SetTexture(kNormalMap, "DisplacementMap", mHeightTexture);
            mComputeShader.SetTexture(kNormalMap, "NormalMapTex", mNormalMap);

            mComputeShader.Dispatch(kNormalMap, 256 / 8, 256 / 8, 1);

            mMaterial.SetColor("_Color", waterColor);
            mMaterial.SetColor("_FoamColor", foamColor);
        }
    }

    private void OnDestroy()
    {
        if (mOceanMesh != null)
        {
            mOceanMesh.Clear();
            mOceanMesh = null;
        }

        if (mMaterial != null)
        {
            DestroyImmediate(mMaterial);
            mMaterial = null;
        }

        if (mh0 != null)
        {
            DestroyImmediate(mh0);
            mh0 = null;
        }

        if (mHeightTexture != null)
        {
            DestroyImmediate(mHeightTexture);
            mHeightTexture = null;
        }

        if (mGaussionRandom != null)
        {
            DestroyImmediate(mGaussionRandom);
            mGaussionRandom = null;
        }

        if (mButterflyTexture != null)
        {
            DestroyImmediate(mButterflyTexture);
            mButterflyTexture = null;
        }

        mPingpongs[0] = null;
        mPingpongs[1] = null;

        if (mPingpong0 != null)
        {
            DestroyImmediate(mPingpong0);
            mPingpong0 = null;
        }

        if (mPingpong1 == null)
        {
            DestroyImmediate(mPingpong1);
            mPingpong1 = null;
        }

        mPingpongChoppys[0] = null;
        mPingpongChoppys[1] = null;

        if (mPingpongChoppy0 != null)
        {
            DestroyImmediate(mPingpongChoppy0);
            mPingpongChoppy0 = null;
        }

        if (mPingpongChoppy1 == null)
        {
            DestroyImmediate(mPingpongChoppy1);
            mPingpongChoppy1 = null;
        }

        if (mComputeShader != null)
        {
            //Object.DestroyImmediate(mComputeShader);
            //mComputeShader = null;
        }
        
    }

    private void RunComputeShader()
    {
        if (mh0 == null)
        {
            mh0 = new RenderTexture(256, 256, 0, RenderTextureFormat.ARGBFloat);
            mh0.enableRandomWrite = true;
            mh0.Create();
        }

        if (mHeightTexture == null)
        {
            mHeightTexture = new RenderTexture(256, 256, 0, RenderTextureFormat.ARGBFloat);
            mHeightTexture.enableRandomWrite = true;
            mHeightTexture.wrapMode = TextureWrapMode.Repeat;
            mHeightTexture.useMipMap = false;
            mHeightTexture.Create();
        }

        if (mGaussionRandom == null)
        {
            mGaussionRandom = new RenderTexture(256, 256, 0, RenderTextureFormat.ARGBFloat);
            mGaussionRandom.enableRandomWrite = true;
            mGaussionRandom.Create();
        }

        if (mNormalMap == null)
        {
            mNormalMap = new RenderTexture(256, 256, 0);
            mNormalMap.enableRandomWrite = true;
            mNormalMap.wrapMode = TextureWrapMode.Repeat;
            mNormalMap.useMipMap = false;
            mNormalMap.Create();
        }

        if (mComputeShader != null)
        {
            ComputeBuffer randomBuffer = new ComputeBuffer(256 * 256, 8);
            float[] randomArray = new float[256 * 256 * 2];
            for (int i = 0; i < 256 * 256 * 2; ++i)
            {
                randomArray[i] = Random.Range(0.00001f, 1.0f);
            }
            randomBuffer.SetData(randomArray);


            ComputeBuffer randomBuffer2 = new ComputeBuffer(256 * 256, 8);
            float[] randomArray2 = new float[256 * 256 * 2];
            for (int i = 0; i < 256 * 256 * 2; ++i)
            {
                randomArray2[i] = Random.Range(0.00001f, 1.0f);
            }
            randomBuffer2.SetData(randomArray2);

            int generateRandom = mComputeShader.FindKernel("GenerateGaussianMap");

            mComputeShader.SetBuffer(generateRandom, "randomData1", randomBuffer);
            mComputeShader.SetBuffer(generateRandom, "randomData2", randomBuffer2);
            mComputeShader.SetTexture(generateRandom, "GaussianRandom", mGaussionRandom);
            mComputeShader.Dispatch(generateRandom, 256 / 8, 256 / 8, 1);

            int generateHeight0 = mComputeShader.FindKernel("GenerateHeight0");
            mComputeShader.SetBuffer(generateHeight0, "randomData1", randomBuffer);
            mComputeShader.SetBuffer(generateHeight0, "randomData2", randomBuffer2);
            mComputeShader.SetTexture(generateHeight0, "H0Texture", mh0);
            //mComputeShader.SetTexture(generateHeight0, "GaussianRandom", mGaussionRandom);
            mComputeShader.SetInt("N", 256);
            mComputeShader.SetFloat("A", A);
            mComputeShader.SetVector("windDirection", mWindDirection);
            mComputeShader.SetFloat("windSpeed", mWindSpeed);
            mComputeShader.SetFloat("patchSize", mPatchSize);
            mComputeShader.Dispatch(generateHeight0, 256 / 8, 256 / 8, 1);
            randomBuffer.Release();
            randomBuffer2.Release();


            //生成butterfly纹理
            int widthButterfly = 0;
            if (mButterflyTexture == null)
            {
                widthButterfly = (int)(Mathf.Log(256) / Mathf.Log(2));
                mButterflyTexture = new RenderTexture(widthButterfly, 256, 0, RenderTextureFormat.ARGBFloat);
                mButterflyTexture.enableRandomWrite = true;
                mButterflyTexture.Create();
            }

            int generateButterfly = mComputeShader.FindKernel("GenerateButterfly");

            int[] test = new int[256];
            for (int i = 0; i < test.Length; ++i)
            {
                test[i] = i;
            }

            ReserveBit(test, 256);

            ComputeBuffer reserveBit = new ComputeBuffer(256, 4);
            reserveBit.SetData(test);
            mComputeShader.SetBuffer(generateButterfly, "reserveBit", reserveBit);
            mComputeShader.SetTexture(generateButterfly, "ButterflyTex", mButterflyTexture);
            mComputeShader.Dispatch(generateButterfly, widthButterfly, 256 / 8, 1);

            reserveBit.Release();
        }

        if (mPingpong0 == null)
        {
            mPingpong0 = new RenderTexture(256, 256, 0, RenderTextureFormat.ARGBFloat);
            mPingpong0.enableRandomWrite = true;
            mPingpong0.Create();
        }

        if (mPingpong1 == null)
        {
            mPingpong1 = new RenderTexture(256, 256, 0, RenderTextureFormat.ARGBFloat);
            mPingpong1.enableRandomWrite = true;
            mPingpong1.Create();
        }

        mPingpongs[0] = mPingpong0;
        mPingpongs[1] = mPingpong1;

        if (mPingpongChoppy0 == null)
        {
            mPingpongChoppy0 = new RenderTexture(256, 256, 0, RenderTextureFormat.ARGBFloat);
            mPingpongChoppy0.enableRandomWrite = true;
            mPingpongChoppy0.Create();
        }

        if (mPingpongChoppy1 == null)
        {
            mPingpongChoppy1 = new RenderTexture(256, 256, 0, RenderTextureFormat.ARGBFloat);
            mPingpongChoppy1.enableRandomWrite = true;
            mPingpongChoppy1.Create();
        }

        mPingpongChoppys[0] = mPingpongChoppy0;
        mPingpongChoppys[1] = mPingpongChoppy1;
    }

    void ReserveBit(int[] x, int N)
    {
        //float2 temp;
        int i = 0, j = 0, k = 0;
        int t;
        int temp = 0;
        for (i = 0; i < N; i++)
        {
            k = i; j = 0;
            t = (int)(Mathf.Log((float)N) / Mathf.Log(2.0f));
            while ((t--) > 0)    //利用按位与以及循环实现码位颠倒  
            {
                j = j << 1;
                j |= (k & 1);
                k = k >> 1;
            }
            if (j > i)    //将x(n)的码位互换  
            {
                temp = x[i];
                x[i] = x[j];
                x[j] = temp;
            }
        }
    }

    public void SaveRenderTexture(RenderTexture renderT, string fileName)
    {
        if (renderT == null)
            return;

        int width = renderT.width;
        int height = renderT.height;
        Texture2D tex2d = new Texture2D(width, height, TextureFormat.ARGB32, false);
        RenderTexture.active = renderT;
        tex2d.ReadPixels(new Rect(0, 0, width, height), 0, 0);
        tex2d.Apply();

        byte[] b = tex2d.EncodeToTGA();
        Destroy(tex2d); 

        File.WriteAllBytes(Application.dataPath + "/" + fileName, b); 
    }
}
