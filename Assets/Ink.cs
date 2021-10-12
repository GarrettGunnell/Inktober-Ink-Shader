using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
public class Ink : MonoBehaviour {

    public Shader inkShader;
    public Texture background;

    public enum EdgeDetector {
        contrast = 1,
        sobelFeldman,
        prewitt,
        canny
    } public EdgeDetector edgeDetector;
    
    [Range(0.01f, 1.0f)]
    public float contrastThreshold = 0.5f;

    private Material inkMaterial;

    void OnEnable() {
        if (inkMaterial == null) {
            inkMaterial = new Material(inkShader);
            inkMaterial.hideFlags = HideFlags.HideAndDontSave;
        }
    }

    void OnDisable() {
        inkMaterial = null;
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination) {
        inkMaterial.SetFloat("_ContrastThreshold", contrastThreshold);
        inkMaterial.SetTexture("_PaperTex", background);

        RenderTexture luminanceSource = RenderTexture.GetTemporary(source.width, source.height, 0, source.format);
        Graphics.Blit(source, luminanceSource, inkMaterial, 0);
        RenderTexture.ReleaseTemporary(luminanceSource);

        Graphics.Blit(luminanceSource, destination, inkMaterial, (int)edgeDetector);
    }
}
