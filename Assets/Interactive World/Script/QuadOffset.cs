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
                    //Ĭ�Ϻϲ��ṹ�ǣ�quad��һ���������£���ôlocalPosition���Ǿ��븸�������ģ��ֲ��ռ�ԭ�㣩��ƫ��������
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
