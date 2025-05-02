-- Cuenta todos los álbumes
SELECT COUNT(*) FROM public.album;

-- Selecciona todos los registros de la tabla Album
SELECT * FROM public.album;

-- Selecciona todos los géneros únicos
SELECT DISTINCT(name) FROM public.genre;

-- Cuenta el número de pistas por género
SELECT 
    b.name, 
    COUNT(a.*) AS total_tracks
FROM track a
LEFT JOIN genre b ON a.genre_id = b.genre_id 
GROUP BY b.name
ORDER BY total_tracks DESC;

-- Longitud total de todas las pistas para cada álbum
SELECT 
    a.title, 
    SUM(b.milliseconds) AS total_milliseconds
FROM album a
LEFT JOIN track b ON a.album_id = b.album_id 
GROUP BY a.title
ORDER BY total_milliseconds DESC;

-- Top 10 álbumes con más pistas
SELECT 
    a.title, 
    COUNT(b.track_id) AS num_tracks
FROM album a
LEFT JOIN track b ON a.album_id = b.album_id 
GROUP BY a.title
ORDER BY num_tracks DESC
LIMIT 10;

-- Longitud promedio de la pista para cada género
SELECT 
    b.name, 
    AVG(a.milliseconds) AS avg_milliseconds
FROM track a
LEFT JOIN genre b ON a.genre_id = b.genre_id 
GROUP BY b.name
ORDER BY avg_milliseconds DESC;

-- Gasto total por cliente
SELECT 
    c.first_name, 
    c.last_name, 
    SUM(i.total) AS total_gastado
FROM customer c 
LEFT JOIN invoice i ON c.customer_id = i.customer_id 
GROUP BY c.first_name, c.last_name
ORDER BY total_gastado;

-- Gasto total por país
SELECT 
    billing_country, 
    SUM(total) AS total_gastado
FROM invoice
GROUP BY billing_country
ORDER BY total_gastado DESC;

-- Clasificación de clientes por gasto
SELECT 
    c.first_name, 
    c.last_name, 
    i.billing_country, 
    SUM(i.total) AS total_gastado,
    CASE 
        WHEN SUM(i.total) > 38 THEN 'Heavy customer' 
        ELSE 'Light customer' 
    END AS fl_gasto
FROM customer c 
LEFT JOIN invoice i ON c.customer_id = i.customer_id 
GROUP BY c.first_name, c.last_name, i.billing_country
ORDER BY i.billing_country DESC;

-- Álbum con más pistas por artista
WITH album_pistas AS (
    SELECT 
        a.name, 
        b.title, 
        COUNT(c.*) AS count_pistas,
        RANK() OVER (PARTITION BY a.name ORDER BY COUNT(c.*) DESC) AS rnk
    FROM artist a
    LEFT JOIN album b ON a.artist_id = b.artist_id
    LEFT JOIN track c ON b.album_id = c.album_id
    GROUP BY a.name, b.title
)
SELECT 
    name, 
    title, 
    count_pistas, 
    RANK() OVER (ORDER BY count_pistas DESC) AS overall_rank
FROM album_pistas
WHERE rnk = 1;

-- Pistas que contienen "love" en el título
SELECT *
FROM track
WHERE name ILIKE '%love%';

-- Clientes cuyo primer nombre comienza con 'A'
SELECT *
FROM customer
WHERE first_name ILIKE 'A%';

-- Porcentaje del total de facturación que representa cada cliente
WITH recaudo_total AS (
    SELECT SUM(total) AS q_facturado FROM invoice
),
total_cliente AS (
    SELECT 
        customer_id, 
        SUM(total) AS total_cliente
    FROM invoice 
    GROUP BY customer_id
)
SELECT 
    tc.customer_id, 
    (tc.total_cliente / rt.q_facturado) * 100 AS porcentaje
FROM total_cliente tc
CROSS JOIN recaudo_total rt;

-- Porcentaje de pistas por género
WITH total AS (
    SELECT COUNT(*) AS tracks_totales FROM track
)
SELECT 
    g.name, 
    (1.0 * COUNT(t.track_id) / ta.tracks_totales) * 100 AS porcentaje_tracks
FROM genre g
LEFT JOIN track t ON g.genre_id = t.genre_id
CROSS JOIN total ta
GROUP BY g.name, ta.tracks_totales;

-- Para cada cliente, compara su gasto total con el del cliente que gastó más.
WITH total_gastos AS (
    SELECT
        customer_id,
        SUM(total) AS gasto_total
    FROM Invoice
    GROUP BY customer_id
),
mayor_gasto AS (
    SELECT MAX(gasto_total) AS gasto_maximo
    FROM total_gastos
)
SELECT
    t.customer_id,
    t.gasto_total,
    m.gasto_maximo,
    m.gasto_maximo - t.gasto_total AS diferencia_con_mayor
FROM total_gastos t
CROSS JOIN mayor_gasto m
ORDER BY diferencia_con_mayor ASC;

-- Para cada factura, calcula la diferencia en el gasto total entre ella y la factura anterior.

SELECT
    invoice_id,
    total,
    LAG(total) OVER (ORDER BY invoice_id) AS total_factura_anterior,
    total - LAG(total) OVER (ORDER BY invoice_id) AS diferencia_con_anterior
FROM invoice;


-- Para cada factura, calcula la diferencia en el gasto total entre ella y la próxima factura.

SELECT
    invoice_id,
    total,
    LEAD(total) OVER (ORDER BY invoice_id) AS total_factura_siguiente,
    total - LEAD(total) OVER (ORDER BY invoice_id) AS diferencia_con_siguiente
FROM invoice;

-- Encuentra al artista con el mayor número de pistas para cada género.

WITH pistas_por_artista_genero AS (
    SELECT
        g.genre_id,
        g.name AS genero,
        ar.artist_id,
        ar.Name AS artista,
        COUNT(t.track_id) AS cantidad_pistas
    FROM track t
    JOIN album al ON t.album_id = al.album_id
    JOIN artist ar ON al.artist_id = ar.artist_id
    JOIN Genre g ON t.genre_id = g.genre_id
    GROUP BY g.genre_id, g.name, ar.artist_id, ar.Name
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY genre_id ORDER BY cantidad_pistas DESC) AS rn
    FROM pistas_por_artista_genero
)
SELECT
    genero,
    artista,
    cantidad_pistas
FROM ranked
WHERE rn = 1;


-- Compara el total de la última factura de cada cliente con el total de su factura anterior.

WITH facturas_ordenadas AS (
    SELECT
        customer_id,
        invoice_id,
        total,
        invoice_date,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY invoice_date DESC) AS rn
    FROM invoice
)
SELECT
    f1.customer_id,
    f1.invoice_id AS ultima_factura,
    f1.total AS total_ultima_factura,
    f2.invoice_id AS factura_anterior,
    f2.total AS total_factura_anterior,
    f1.total - f2.total AS diferencia
FROM facturas_ordenadas f1
LEFT JOIN facturas_ordenadas f2
    ON f1.customer_id = f2.customer_id AND f1.rn = f2.rn - 1
WHERE f1.rn = 1;


-- Encuentra cuántas pistas de más de 3 minutos tiene cada álbum.

SELECT
    al.title AS album,
    COUNT(t.track_id) AS pistas_mas_3_min
FROM track t
JOIN album al ON t.album_id = al.album_id
WHERE t.milliseconds > 180000
GROUP BY al.album_id, al.title
ORDER BY pistas_mas_3_min DESC;