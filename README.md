# acps_redistricting

A project to run some GIS based analysis of the ACPS redistricting effort.

See http://overpass-turbo.eu/

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

https://www.census.gov/geo/maps-data/data/tiger.html
