using UnityEngine;
namespace TTI
{
    public class FreeCamera : MonoBehaviour
    {
        public float movementSpeed = 10.0f;
        public float lookSpeed = 2.0f;

        private float yaw = 0.0f;
        private float pitch = 0.0f;

        void Update()
        {
            // Mouse look
            yaw += lookSpeed * Input.GetAxis("Mouse X");
            pitch -= lookSpeed * Input.GetAxis("Mouse Y");
            pitch = Mathf.Clamp(pitch, -90f, 90f); // Limit pitch to prevent flipping

            transform.eulerAngles = new Vector3(pitch, yaw, 0.0f);

            // Keyboard movement
            float moveForward = Input.GetAxis("Vertical") * movementSpeed * Time.deltaTime;
            float moveRight = Input.GetAxis("Horizontal") * movementSpeed * Time.deltaTime;

            transform.Translate(moveRight, 0, moveForward);
        }
    }
}
