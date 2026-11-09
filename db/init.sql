-- Script de inicialización de la base de datos.
-- Idempotente: se puede ejecutar varias veces sin error.

CREATE TABLE IF NOT EXISTS mascotas (
    id      INT AUTO_INCREMENT PRIMARY KEY,
    nombre  VARCHAR(60) NOT NULL,
    especie VARCHAR(30) NOT NULL
);

-- Datos de prueba (solo se insertan si la tabla está vacía)
INSERT INTO mascotas (nombre, especie)
SELECT 'Luna', 'perro' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM mascotas WHERE nombre = 'Luna' AND especie = 'perro');

INSERT INTO mascotas (nombre, especie)
SELECT 'Michi', 'gato' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM mascotas WHERE nombre = 'Michi' AND especie = 'gato');

