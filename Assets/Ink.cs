using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
public class Ink : MonoBehaviour {

    public Shader inkShader;
    public Texture paperTexture;
    public Texture inkTexture;

    public Texture image;
    public bool useImage = false;

    public Texture blueNoise;

    public enum EdgeDetector {
        contrast = 1,
        sobelFeldman,
        prewitt,
        canny,
        stippling = 10
    } public EdgeDetector edgeDetector;
    
    [Range(0.01f, 1.0f)]
    public float contrastThreshold = 0.5f;

    [Range(0.01f, 1.0f)]
    public float highThreshold = 0.8f;

    [Range(0.01f, 1.0f)]
    public float lowThreshold = 0.1f;

    [Range(0.01f, 5.0f)]
    public float luminanceContrast = 1.0f;

    [Range(1.0f, 10.0f)]
    public float luminanceCorrection = 1.0f;

    [Range(0.01f, 1.0f)]
    public float stippleSize = 1.0f;

    public bool capturing = false;

    private Material inkMaterial;
    private int frameCount = 0;

    void OnEnable() {
        if (inkMaterial == null) {
            inkMaterial = new Material(inkShader);
            inkMaterial.hideFlags = HideFlags.HideAndDontSave;
        }
    }

    void OnDisable() {
        inkMaterial = null;
    }

    void Start() {
        Camera cam = GetComponent<Camera>();
        cam.depthTextureMode = cam.depthTextureMode | DepthTextureMode.Depth;
    }

    void Update() {
        ++frameCount;
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination) {
        inkMaterial.SetFloat("_ContrastThreshold", contrastThreshold);
        inkMaterial.SetTexture("_NoiseTex", blueNoise);
        inkMaterial.SetFloat("_LuminanceCorrection", luminanceCorrection);
        inkMaterial.SetFloat("_Contrast", luminanceContrast);
        inkMaterial.SetFloat("_StippleSize", stippleSize);
        inkMaterial.SetFloat("_UsingImage", useImage ? 1 : 0);

        int width = useImage ? image.width : source.width;
        int height = useImage ? image.height : source.height;

        RenderTexture luminanceSource = RenderTexture.GetTemporary(width, height, 0, source.format);
        Graphics.Blit(useImage ? image : source, luminanceSource, inkMaterial, 0);

        RenderTexture edgeSource = RenderTexture.GetTemporary(width, height, 0, source.format);
        
        if (edgeDetector == EdgeDetector.canny) {
            inkMaterial.SetFloat("_LowThreshold", lowThreshold);
            inkMaterial.SetFloat("_HighThreshold", highThreshold);
            RenderTexture gradientSource = RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGBFloat);
            Graphics.Blit(luminanceSource, gradientSource, inkMaterial, 4);

            inkMaterial.SetTexture("_LuminanceTex", luminanceSource);

            RenderTexture magThresholdSource = RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGBFloat);
            Graphics.Blit(gradientSource, magThresholdSource, inkMaterial, 5);

            RenderTexture doubleThresholdSource = RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGBFloat);
            Graphics.Blit(magThresholdSource, doubleThresholdSource, inkMaterial, 6);

            RenderTexture hysteresisSource = RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGBFloat);
            Graphics.Blit(doubleThresholdSource, hysteresisSource, inkMaterial, 7);

            RenderTexture widthSource = RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGBFloat);
            Graphics.Blit(hysteresisSource, widthSource, inkMaterial, 8);

            RenderTexture.ReleaseTemporary(gradientSource);
            RenderTexture.ReleaseTemporary(magThresholdSource);
            RenderTexture.ReleaseTemporary(doubleThresholdSource);
            RenderTexture.ReleaseTemporary(hysteresisSource);
            RenderTexture.ReleaseTemporary(widthSource);

            Graphics.Blit(widthSource, edgeSource);
        } else {
            Graphics.Blit(luminanceSource, edgeSource, inkMaterial, (int)edgeDetector);
        }

        RenderTexture stippleSource = RenderTexture.GetTemporary(width, height, 0, source.format);
        Graphics.Blit(luminanceSource, stippleSource, inkMaterial, 10);
        RenderTexture.ReleaseTemporary(luminanceSource);

        inkMaterial.SetTexture("_StippleTex", stippleSource);

        RenderTexture comboSource = RenderTexture.GetTemporary(width, height, 0, source.format);
        Graphics.Blit(edgeSource, comboSource, inkMaterial, 11);

        inkMaterial.SetTexture("_InkTex", inkTexture);
        inkMaterial.SetTexture("_PaperTex", paperTexture);

        RenderTexture.ReleaseTemporary(edgeSource);
        RenderTexture.ReleaseTemporary(stippleSource);
        RenderTexture.ReleaseTemporary(comboSource);

        Graphics.Blit(comboSource, destination, inkMaterial, 12);
     }

     private void LateUpdate() {
        if (capturing || Input.GetKeyDown(KeyCode.Space)) {
            int width = useImage ? image.width : 600;
            int height = useImage ? image.height : 600;

            RenderTexture rt = new RenderTexture(width, height, 24);
            GetComponent<Camera>().targetTexture = rt;
            Texture2D screenshot = new Texture2D(width, height, TextureFormat.RGB24, false);
            GetComponent<Camera>().Render();
            RenderTexture.active = rt;
            screenshot.ReadPixels(new Rect(0, 0, width, height), 0, 0);
            GetComponent<Camera>().targetTexture = null;
            RenderTexture.active = null;
            Destroy(rt);
            //string filename = string.Format("{0}/../Recordings/{1:000000}.png", Application.dataPath, frameCount);
            string filename = string.Format("{0}/../Recordings/snap_{1}.png", Application.dataPath, System.DateTime.Now.ToString("HH-mm-ss"));
            System.IO.File.WriteAllBytes(filename, screenshot.EncodeToPNG());
        }
    }
}
