using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public class QuadOffset : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        MeshFilter[] meshfilters = gameObject.GetComponentsInChildren<MeshFilter>();
        if (meshfilters != null && meshfilters.Length > 0)
        {
            List<Vector4> centerOffset = new();
            for (int i = 0; i < meshfilters.Length; i++)
            {
                Mesh mesh = meshfilters[i].sharedMesh;
                for (int j = 0; j < mesh.vertexCount; j++)
                {
                    //默认合并结构是，quad在一个父物体下，那么localPosition就是距离父物体中心（局部空间原点）的偏离向量。
                    centerOffset.Add(meshfilters[i].transform.position);
                }
                mesh.tangents = centerOffset.ToArray();
            }
        }
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
