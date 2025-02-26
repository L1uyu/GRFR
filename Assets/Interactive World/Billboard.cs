using UnityEngine;
using static UnityEngine.GraphicsBuffer;

public class Billboard : MonoBehaviour
{
    private Camera mainCamera;

    // Choose which axis to lock (if any)
    public bool lockX = false;
    public bool lockY = false;
    public bool lockZ = false;

    void Start()
    {
        // Get reference to main camera
        mainCamera = Camera.main;
    }

    void LateUpdate()
    {
        if (!mainCamera)
            return;

        // Store current rotation
        Vector3 rotation = transform.eulerAngles;
        /*Debug.Log("ss");
        Vector3 lookPoint = transform.position - mainCamera.transform.position;
        lookPoint.y = mainCamera.transform.position.y;
        transform.LookAt(lookPoint)*/;

        // Make the object look at the camera
        transform.LookAt(mainCamera.transform);

        // Lock axes if specified
        if (lockX) transform.eulerAngles = new Vector3(rotation.x, transform.eulerAngles.y, transform.eulerAngles.z);
        if (lockY) transform.eulerAngles = new Vector3(transform.eulerAngles.x, rotation.y, transform.eulerAngles.z);
        if (lockZ) transform.eulerAngles = new Vector3(transform.eulerAngles.x, transform.eulerAngles.y, rotation.z);
    }
}