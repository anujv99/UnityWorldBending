using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class Axis : MonoBehaviour {

    public GameObject other;

    // Start is called before the first frame update
    private void Start() {
        other = null;
    }

    // Update is called once per frame
    private void Update() {
        if ( other == null )
            return;

        Renderer rend = other.GetComponent<Renderer>();

        if ( transform.hasChanged ) {
            Vector3 newAxis = Vector3.forward;
            newAxis = transform.rotation * newAxis;

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
}
