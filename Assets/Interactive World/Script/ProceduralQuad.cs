using UnityEngine;

[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class ProceduralQuad : MonoBehaviour
{
    [Header("Quad Parameters")]
    [SerializeField] private float width = 1f;
    [SerializeField] private float height = 1f;
    [SerializeField] private int heightSegments = 10;

    [Header("Shape Control")]
    [SerializeField] private AnimationCurve shapeCurve = AnimationCurve.Linear(0, 0, 1, 0);
    [SerializeField] private AnimationCurve widthCurve = AnimationCurve.Linear(0, 1, 1, 1);

    private const int WIDTH_SEGMENTS = 4;
    private Mesh mesh;

    private void Start()
    {
        GenerateMesh();
    }

    private void GenerateMesh()
    {
        mesh = new Mesh();
        GetComponent<MeshFilter>().mesh = mesh;

        int vertexCount = (heightSegments + 1) * (WIDTH_SEGMENTS + 1);
        Vector3[] vertices = new Vector3[vertexCount];
        Vector2[] uvs = new Vector2[vertexCount];
        Color[] colors = new Color[vertexCount];

        for (int y = 0; y <= heightSegments; y++)
        {
            float yPos = ((float)y / heightSegments) * height;
            float yUV = (float)y / heightSegments;
            float widthMultiplier = widthCurve.Evaluate(yUV);

            for (int x = 0; x <= WIDTH_SEGMENTS; x++)
            {
                float xPos = ((float)x / WIDTH_SEGMENTS) * width;
                float xUV = (float)x / WIDTH_SEGMENTS;

                // Apply curve deformations
                float curveOffset = shapeCurve.Evaluate(yUV);
                float adjustedXPos = (xPos - (width / 2f)) * widthMultiplier;

                int index = y * (WIDTH_SEGMENTS + 1) + x;
                Vector3 vertexPosition = new Vector3(adjustedXPos, yPos, curveOffset);
                vertices[index] = vertexPosition;
                uvs[index] = new Vector2(xUV, yUV);

                // Calculate normalized position for vertex colors
                // Red = X position (0-1)
                // Green = Y position (0-1)
                // Blue = Z position (0-1)
                // Alpha = Distance from pivot point (0-1)
                float normalizedX = (adjustedXPos + (width / 2f)) / width;
                float normalizedY = yPos / height;
                float normalizedZ = (curveOffset + (width / 2f)) / width; // Assuming Z range similar to width

                colors[index] = new Color(normalizedX, normalizedY, normalizedZ);
            }
        }

        // Calculate triangles
        int quadCount = heightSegments * WIDTH_SEGMENTS;
        int[] triangles = new int[quadCount * 6];
        int triIndex = 0;

        for (int y = 0; y < heightSegments; y++)
        {
            for (int x = 0; x < WIDTH_SEGMENTS; x++)
            {
                int vertIndex = y * (WIDTH_SEGMENTS + 1) + x;

                triangles[triIndex] = vertIndex;
                triangles[triIndex + 1] = vertIndex + WIDTH_SEGMENTS + 1;
                triangles[triIndex + 2] = vertIndex + 1;

                triangles[triIndex + 3] = vertIndex + 1;
                triangles[triIndex + 4] = vertIndex + WIDTH_SEGMENTS + 1;
                triangles[triIndex + 5] = vertIndex + WIDTH_SEGMENTS + 2;

                triIndex += 6;
            }
        }

        // Assign mesh data
        mesh.vertices = vertices;
        mesh.triangles = triangles;
        mesh.uv = uvs;
        mesh.colors = colors;
        mesh.RecalculateNormals();
    }

    private void OnValidate()
    {
        if (Application.isPlaying && mesh != null)
        {
            GenerateMesh();
        }
    }
}