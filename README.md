# acps_redistricting

A project to run some GIS based analysis of the ACPS redistricting effort.

See http://overpass-turbo.eu/map.html?Q=%2F*%0AThis%20has%20been%20generated%20by%20the%20overpass-turbo%20wizard.%0AThe%20original%20search%20was%3A%0A%E2%80%9Camenity%3Dschool%E2%80%9D%0A*%2F%0A%5Bout%3Ajson%5D%5Btimeout%3A25%5D%3B%0A%2F%2F%20gather%20results%0A(%0A%20%20node%5B%22operator%22%3D%22Alexandria%20City%20Public%20Schools%22%5D(38.79945023076236%2C-77.12196350097656%2C38.853678691309526%2C-77.04892158508301)%3B%0A%20%20way%5B%22operator%22%3D%22Alexandria%20City%20Public%20Schools%22%5D(38.79945023076236%2C-77.12196350097656%2C38.853678691309526%2C-77.04892158508301)%3B%0A%20%20relation%5B%22operator%22%3D%22Alexandria%20City%20Public%20Schools%22%5D(38.79945023076236%2C-77.12196350097656%2C38.853678691309526%2C-77.04892158508301)%3B%0A)%3B%0A%2F%2F%20print%20results%0Aout%20body%3B%0A%3E%3B%0Aout%20skel%20qt%3B

```
/*
This has been generated by the overpass-turbo wizard.
The original search was:
“amenity=school”
*/
[out:json][timeout:25];
// gather results
(
  node["operator"="Alexandria City Public Schools"]({{bbox}});
  way["operator"="Alexandria City Public Schools"]({{bbox}});
  relation["operator"="Alexandria City Public Schools"]({{bbox}});
);
// print results
out body;
>;
out skel qt;
```
