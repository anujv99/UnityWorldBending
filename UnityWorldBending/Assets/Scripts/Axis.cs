using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class Axis : MonoBehaviour {

    public GameObject other;

    // Start is called before the first frame update
    private void Start() {

    }

    // Update is called once per frame
    private void Update() {
        Renderer rend = other.GetComponent<Renderer>();

        if ( transform.hasChanged ) {
            transform.hasChanged = false;

            Vector3 newAxis = Vector3.forward;
            newAxis = transform.rotation * newAxis;

            Debug.Log( newAxis );
            Debug.Log( transform.position );

            rend.sharedMaterial.SetVector( "_Axis", newAxis );
            rend.sharedMaterial.SetVector( "_Origin", transform.position );
        }

        Vector4 axis = rend.sharedMaterial.GetVector( "_Axis" );
        Vector4 origin = rend.sharedMaterial.GetVector( "_Origin" );

        Quaternion quat = Quaternion.LookRotation( axis );
        transform.rotation = quat;
        transform.position = origin;

        transform.hasChanged = false;
    }

    private Renderer _renderer;
}
