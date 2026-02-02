SELECT 
    id,
    name,
    json_array_length(path) as point_count,
    path->0 as first_point,
    path->1 as second_point,
    ST_AsText(location) as location_wkt
FROM territories 
WHERE user_id = 'e7401902-9b15-4a50-9511-e1f3ce113eb7'
ORDER BY created_at DESC
LIMIT 2;
