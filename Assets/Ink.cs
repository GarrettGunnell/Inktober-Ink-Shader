using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
public class Ink : MonoBehaviour {

    public void onRenderImage(RenderTexture target, RenderTexture destination) {
        Graphics.Blit(target, destination);
    }
}
