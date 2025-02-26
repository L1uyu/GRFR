using UnityEngine;
using UnityEngine.Splines;

[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class SplineMeshRenderer : MonoBehaviour
{
    public SplineContainer splineContainer;
    public float lineWidth = 0.5f;
    public int segments = 100;

    private Mesh mesh;
    private Camera mainCamera;

    void Start()
    {
        mainCamera = Camera.main;
        mesh = new Mesh();
        GetComponent<MeshFilter>().mesh = mesh;
        UpdateSplineMesh();
    }

    void Update()
    {
        UpdateSplineMesh();
    }

    void UpdateSplineMesh()
    {
        if (splineContainer == null) return;

        Spline spline = splineContainer.Spline;
        Vector3[] vertices = new Vector3[segments * 4];
        Vector2[] uvs = new Vector2[segments * 4];
        int[] triangles = new int[segments * 6];

        for (int i = 0; i < segments; i++)
        {
            float t = i / (float)(segments - 1);
            Vector3 position = spline.EvaluatePosition(t);
            Vector3 forward = spline.EvaluateTangent(t);
            
            // Calculate the right vector perpendicular to both the forward direction and camera up
            Vector3 right = Vector3.Cross(forward.normalized, mainCamera.transform.forward).normalized;

            // Calculate the four corners of the quad
            Vector3 topLeft = position + right * lineWidth / 2;
            Vector3 topRight = position - right * lineWidth / 2;
            Vector3 bottomLeft = topLeft;
            Vector3 bottomRight = topRight;

            if (i < segments - 1)
            {
                float nextT = (i + 1) / (float)(segments - 1);
                Vector3 nextPos = spline.EvaluatePosition(nextT);
                bottomLeft = nextPos + right * lineWidth / 2;
                bottomRight = nextPos - right * lineWidth / 2;
            }

            // Assign vertices
            int vIndex = i * 4;
            vertices[vIndex] = topLeft;
            vertices[vIndex + 1] = topRight;
            vertices[vIndex + 2] = bottomLeft;
            vertices[vIndex + 3] = bottomRight;

            // Assign UVs
            uvs[vIndex] = new Vector2(0, t);
            uvs[vIndex + 1] = new Vector2(1, t);
            uvs[vIndex + 2] = new Vector2(0, t + 1f/segments);
            uvs[vIndex + 3] = new Vector2(1, t + 1f/segments);

            // Create triangles
            if (i < segments - 1)
            {
                int tIndex = i * 6;
                triangles[tIndex] = vIndex;
                triangles[tIndex + 1] = vIndex + 2;
                triangles[tIndex + 2] = vIndex + 1;
                triangles[tIndex + 3] = vIndex + 1;
                triangles[tIndex + 4] = vIndex + 2;
                triangles[tIndex + 5] = vIndex + 3;
            }
        }

        mesh.Clear();
        mesh.vertices = vertices;
        mesh.triangles = triangles;
        mesh.uv = uvs;
        mesh.RecalculateNormals();
    }
}