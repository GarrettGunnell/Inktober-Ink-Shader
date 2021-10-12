using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
public class Ink : MonoBehaviour {

    public Shader inkShader;
    public Texture background;
    public GameObject lightObj;

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

        RenderTexture luminanceSource = RenderTexture.GetTemporary(source.width, source.height, 0, source.format);
        Graphics.Blit(source, luminanceSource, inkMaterial, 0);
        
        if (edgeDetector == EdgeDetector.canny) {
            inkMaterial.SetFloat("_LowThreshold", lowThreshold);
            inkMaterial.SetFloat("_HighThreshold", highThreshold);
            RenderTexture gradientSource = RenderTexture.GetTemporary(source.width, source.height, 0, RenderTextureFormat.ARGBFloat);
            Graphics.Blit(luminanceSource, gradientSource, inkMaterial, 4);


            RenderTexture thresholdSource = RenderTexture.GetTemporary(source.width, source.height, 0, RenderTextureFormat.ARGBFloat);
            Graphics.Blit(gradientSource, thresholdSource, inkMaterial, 5);

            RenderTexture.ReleaseTemporary(luminanceSource);
            RenderTexture.ReleaseTemporary(gradientSource);
            RenderTexture.ReleaseTemporary(thresholdSource);

            Graphics.Blit(thresholdSource, destination, inkMaterial, 6);
        } else {
            RenderTexture.ReleaseTemporary(luminanceSource);
            
            Graphics.Blit(luminanceSource, destination, inkMaterial, (int)edgeDetector);
        }
     }

     private void Capture() {
        if (capturing) {
            RenderTexture rt = new RenderTexture(512, 512, 24);
            GetComponent<Camera>().targetTexture = rt;
            Texture2D screenshot = new Texture2D(512, 512, TextureFormat.RGB24, false);
            GetComponent<Camera>().Render();
            RenderTexture.active = rt;
            screenshot.ReadPixels(new Rect(0, 0, 512, 512), 0, 0);
            GetComponent<Camera>().targetTexture = null;
            RenderTexture.active = null;
            Destroy(rt);
            string filename = string.Format("{0}/../Recordings/{1:000000}.png", Application.dataPath, frameCount);
            System.IO.File.WriteAllBytes(filename, screenshot.EncodeToPNG());
        }
    }
}
