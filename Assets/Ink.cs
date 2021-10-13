using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
public class Ink : MonoBehaviour {

    public Shader inkShader;
    public Texture background;
    public GameObject lightObj;

    public Texture image;
    public bool useImage = false;

    public enum EdgeDetector {
        contrast = 1,
        sobelFeldman,
        prewitt,
        canny
    } public EdgeDetector edgeDetector;
    
    [Range(0.01f, 1.0f)]
    public float contrastThreshold = 0.5f;

    [Range(0.01f, 1.0f)]
    public float highThreshold = 0.8f;

    [Range(0.01f, 1.0f)]
    public float lowThreshold = 0.1f;

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

    void Update() {
        ++frameCount;
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination) {
        inkMaterial.SetFloat("_ContrastThreshold", contrastThreshold);
        inkMaterial.SetTexture("_PaperTex", background);

        int width = useImage ? image.width : source.width;
        int height = useImage ? image.height : source.height;

        RenderTexture luminanceSource = RenderTexture.GetTemporary(width, height, 0, source.format);
        Graphics.Blit(useImage ? image : source, luminanceSource, inkMaterial, 0);
        
        if (edgeDetector == EdgeDetector.canny) {
            inkMaterial.SetFloat("_LowThreshold", lowThreshold);
            inkMaterial.SetFloat("_HighThreshold", highThreshold);
            RenderTexture gradientSource = RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGBFloat);
            Graphics.Blit(luminanceSource, gradientSource, inkMaterial, 4);


            RenderTexture magThresholdSource = RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGBFloat);
            Graphics.Blit(gradientSource, magThresholdSource, inkMaterial, 5);

            RenderTexture doubleThresholdSource = RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGBFloat);
            Graphics.Blit(magThresholdSource, doubleThresholdSource, inkMaterial, 6);

            RenderTexture hysteresisSource = RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGBFloat);
            Graphics.Blit(doubleThresholdSource, hysteresisSource, inkMaterial, 7);

            RenderTexture.ReleaseTemporary(luminanceSource);
            RenderTexture.ReleaseTemporary(gradientSource);
            RenderTexture.ReleaseTemporary(magThresholdSource);
            RenderTexture.ReleaseTemporary(doubleThresholdSource);
            RenderTexture.ReleaseTemporary(hysteresisSource);

            Graphics.Blit(hysteresisSource, destination, inkMaterial, 8);
            //Graphics.Blit(hysteresisSource, destination);
        } else {
            RenderTexture.ReleaseTemporary(luminanceSource);
            
            Graphics.Blit(luminanceSource, destination, inkMaterial, (int)edgeDetector);
        }
     }

     private void Capture() {
        if (capturing) {
            RenderTexture rt = new RenderTexture(600, 600, 24);
            GetComponent<Camera>().targetTexture = rt;
            Texture2D screenshot = new Texture2D(600, 600, TextureFormat.RGB24, false);
            GetComponent<Camera>().Render();
            RenderTexture.active = rt;
            screenshot.ReadPixels(new Rect(0, 0, 600, 600), 0, 0);
            GetComponent<Camera>().targetTexture = null;
            RenderTexture.active = null;
            Destroy(rt);
            string filename = string.Format("{0}/../Recordings/{1:000000}.png", Application.dataPath, frameCount);
            System.IO.File.WriteAllBytes(filename, screenshot.EncodeToPNG());
        }
    }
}
