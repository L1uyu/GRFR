using UnityEngine;

[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class WaterStream : MonoBehaviour
{
    public int segments = 10;
    public float width = 0.2f;
    public float height = 2f;

    // Curves to control the stream shape
    public AnimationCurve widthCurve = AnimationCurve.Linear(0, 1, 1, 0); // Default: starts wide, narrows down
    public AnimationCurve xCurve = new AnimationCurve(); // Control X position along height
    public AnimationCurve zCurve = new AnimationCurve(); // Control Z position along height

    // Optional: Multipliers for curve effects
    public float xMultiplier = 1f;
    public float zMultiplier = 1f;

    private Mesh mesh;
    private Vector3[] vertices;
    private int[] triangles;
    private Vector2[] uvs;

    void Start()
    {
        CreateStream();
    }

    void LateUpdate()
    {
        //UpdateStreamMesh();
    }

    void CreateStream()
    {
        mesh = new Mesh();
        GetComponent<MeshFilter>().mesh = mesh;

        vertices = new Vector3[(segments + 1) * 2];
        uvs = new Vector2[(segments + 1) * 2];
        triangles = new int[segments * 6];

        // First update the vertices
        UpdateStreamMesh();

        // Create triangles
        for (int i = 0; i < segments; i++)
        {
            int baseIndex = i * 6;
            int vertIndex = i * 2;

            triangles[baseIndex] = vertIndex;
            triangles[baseIndex + 1] = vertIndex + 2;
            triangles[baseIndex + 2] = vertIndex + 1;

            triangles[baseIndex + 3] = vertIndex + 1;
            triangles[baseIndex + 4] = vertIndex + 2;
            triangles[baseIndex + 5] = vertIndex + 3;
        }

        mesh.vertices = vertices;
        mesh.uv = uvs;
        mesh.triangles = triangles;
        mesh.RecalculateNormals();
    }

    void UpdateStreamMesh()
    {
        // Get the vector that points to the right of the camera
        Vector3 right = Camera.main.transform.right;

        for (int i = 0; i <= segments; i++)
        {
            float t = i / (float)segments;

            // Calculate position using curves
            float yPos = height * (1 - t);
            float xPos = xCurve.Evaluate(t) * xMultiplier;
            float zPos = zCurve.Evaluate(t) * zMultiplier;

            // Create center point with curved path
            Vector3 center = new Vector3(xPos, yPos, zPos);

            // Get current width from curve
            float currentWidth = width * widthCurve.Evaluate(t);

            // Create vertices on both sides of the center line
            vertices[i * 2] = center - right * currentWidth;
            vertices[i * 2 + 1] = center + right * currentWidth;

            // UV coordinates
            uvs[i * 2] = new Vector2(0, t);
            uvs[i * 2 + 1] = new Vector2(1, t);
        }

        mesh.vertices = vertices;
        mesh.uv = uvs;
        mesh.RecalculateNormals();
    }

    // Optional: Visualize the path in the editor
    void OnDrawGizmosSelected()
    {
        if (!Application.isPlaying)
        {
            Gizmos.color = Color.blue;
            Vector3 lastPos = transform.position;

            for (int i = 0; i <= segments; i++)
            {
                float t = i / (float)segments;
                float yPos = height * (1 - t);
                float xPos = xCurve.Evaluate(t) * xMultiplier;
                float zPos = zCurve.Evaluate(t) * zMultiplier;

                Vector3 pos = transform.position + new Vector3(xPos, yPos, zPos);
                Gizmos.DrawLine(lastPos, pos);
                lastPos = pos;
            }
        }
    }
}