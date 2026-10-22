-- ========================================================
-- RIZO DENTAL SANCTUARY - SCRIPT DE ESTRUCTURA Y SEGURIDAD SUPABASE
-- Versión Hardened (RLS + Políticas de Acceso Clínico Idempotentes)
-- Ejecutar en: https://supabase.com/dashboard/project/eadmcexipsdytyjbwgis/sql
-- ========================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. TABLA DE USUARIOS / DOCTORES (users)
CREATE TABLE IF NOT EXISTS public.users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  colegiado TEXT,
  especialidad TEXT,
  telefono TEXT,
  direccion_clinica TEXT,
  firma_digital TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS colegiado TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS especialidad TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS telefono TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS direccion_clinica TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS firma_digital TEXT;

-- 2. TABLA DE PACIENTES (pacientes)
CREATE TABLE IF NOT EXISTS public.pacientes (
  id TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  apellido TEXT NOT NULL,
  email TEXT,
  telefono TEXT,
  fechaNacimiento TEXT,
  fecha_nacimiento TEXT,
  genero TEXT,
  direccion TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.pacientes ADD COLUMN IF NOT EXISTS fechaNacimiento TEXT;
ALTER TABLE public.pacientes ADD COLUMN IF NOT EXISTS fecha_nacimiento TEXT;

-- 3. TABLA DE EVALUACIONES (evaluaciones)
CREATE TABLE IF NOT EXISTS public.evaluaciones (
  id TEXT PRIMARY KEY,
  pacienteId TEXT,
  paciente_id TEXT,
  paciente_nombre TEXT,
  fecha TEXT NOT NULL,
  puntuacion INTEGER,
  diagnostico TEXT,
  respuestas JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. TABLA DE RECETAS MÉDICAS (recetas)
CREATE TABLE IF NOT EXISTS public.recetas (
  id TEXT PRIMARY KEY,
  paciente_id TEXT NOT NULL,
  paciente_nombre TEXT NOT NULL,
  doctor_nombre TEXT,
  fecha TEXT NOT NULL,
  medicamentos TEXT,
  indicaciones TEXT,
  indicaciones_generales TEXT,
  firma_digital TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.recetas ADD COLUMN IF NOT EXISTS indicaciones_generales TEXT;

-- 5. TABLA DE INVENTARIO CLÍNICO (inventario)
CREATE TABLE IF NOT EXISTS public.inventario (
  id TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  categoria TEXT NOT NULL,
  cantidad INTEGER NOT NULL DEFAULT 0,
  unidad TEXT DEFAULT 'unidades',
  stock_minimo INTEGER DEFAULT 5,
  costo_unitario NUMERIC(10,2),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. TABLA DE CITAS MÉDICAS (citas)
CREATE TABLE IF NOT EXISTS public.citas (
  id TEXT PRIMARY KEY,
  paciente_id TEXT NOT NULL,
  paciente_nombre TEXT NOT NULL,
  paciente_telefono TEXT,
  fecha_hora TEXT NOT NULL,
  fecha TEXT,
  hora TEXT,
  motivo TEXT NOT NULL,
  estado TEXT DEFAULT 'Programada',
  notas TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.citas ADD COLUMN IF NOT EXISTS fecha TEXT;
ALTER TABLE public.citas ADD COLUMN IF NOT EXISTS hora TEXT;

-- 7. TABLA DE CONFIGURACIÓN (configuracion)
CREATE TABLE IF NOT EXISTS public.configuracion (
  id TEXT PRIMARY KEY,
  tema TEXT DEFAULT 'light',
  notificaciones BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 8. TABLA DE REPORTES (reportes)
CREATE TABLE IF NOT EXISTS public.reportes (
  id TEXT PRIMARY KEY,
  pacienteId TEXT,
  paciente_id TEXT,
  fecha TEXT NOT NULL,
  tipo TEXT DEFAULT 'fonseca',
  contenido TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 9. TABLA DE TRATAMIENTOS CLÍNICOS (tratamientos)
CREATE TABLE IF NOT EXISTS public.tratamientos (
  id TEXT PRIMARY KEY,
  paciente_id TEXT NOT NULL,
  diente INTEGER DEFAULT 0,
  diagnostico TEXT,
  tratamiento TEXT,
  evolucion TEXT,
  precio_gtq NUMERIC(10,2) DEFAULT 0.0,
  abono_gtq NUMERIC(10,2),
  categoria TEXT,
  estado TEXT,
  notas TEXT,
  fecha TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 10. TABLA DE EXÁMENES Y RADIOGRAFÍAS 360° (examenes_clinicos)
CREATE TABLE IF NOT EXISTS public.examenes_clinicos (
  id TEXT PRIMARY KEY,
  paciente_id TEXT NOT NULL,
  paciente_nombre TEXT,
  titulo TEXT NOT NULL,
  tipo TEXT,
  subtipo TEXT,
  zona TEXT,
  fecha TEXT,
  observaciones TEXT,
  file_name TEXT,
  file_type TEXT,
  file_size_bytes BIGINT DEFAULT 0,
  file_base64 TEXT,
  file_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ========================================================
-- POLÍTICAS DE SEGURIDAD (ROW LEVEL SECURITY - RLS)
-- ========================================================

-- 1. Habilitar RLS en todas las tablas
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pacientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evaluaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recetas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventario ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.citas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracion ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reportes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tratamientos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.examenes_clinicos ENABLE ROW LEVEL SECURITY;

-- 2. Revocar privilegios destructivos a conexiones anónimas públicas (anon)
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;

-- Conceder permisos de lectura/escritura a personal autenticado y service_role
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;

-- 3. Crear Políticas Idempotentes para Personal Clínico Autenticado (authenticated)

-- USERS
DROP POLICY IF EXISTS "allow_auth_users_all" ON public.users;
CREATE POLICY "allow_auth_users_all" ON public.users
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

-- PACIENTES
DROP POLICY IF EXISTS "allow_auth_pacientes_all" ON public.pacientes;
CREATE POLICY "allow_auth_pacientes_all" ON public.pacientes
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

-- EVALUACIONES
DROP POLICY IF EXISTS "allow_auth_evaluaciones_all" ON public.evaluaciones;
CREATE POLICY "allow_auth_evaluaciones_all" ON public.evaluaciones
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

-- RECETAS
DROP POLICY IF EXISTS "allow_auth_recetas_all" ON public.recetas;
CREATE POLICY "allow_auth_recetas_all" ON public.recetas
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

-- INVENTARIO
DROP POLICY IF EXISTS "allow_auth_inventario_all" ON public.inventario;
CREATE POLICY "allow_auth_inventario_all" ON public.inventario
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

-- CITAS
DROP POLICY IF EXISTS "allow_auth_citas_all" ON public.citas;
CREATE POLICY "allow_auth_citas_all" ON public.citas
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

-- CONFIGURACION
DROP POLICY IF EXISTS "allow_auth_configuracion_all" ON public.configuracion;
CREATE POLICY "allow_auth_configuracion_all" ON public.configuracion
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

-- REPORTES
DROP POLICY IF EXISTS "allow_auth_reportes_all" ON public.reportes;
CREATE POLICY "allow_auth_reportes_all" ON public.reportes
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

-- TRATAMIENTOS
DROP POLICY IF EXISTS "allow_auth_tratamientos_all" ON public.tratamientos;
CREATE POLICY "allow_auth_tratamientos_all" ON public.tratamientos
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

-- EXAMENES CLINICOS
DROP POLICY IF EXISTS "allow_auth_examenes_clinicos_all" ON public.examenes_clinicos;
CREATE POLICY "allow_auth_examenes_clinicos_all" ON public.examenes_clinicos
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

-- ========================================================
-- REGISTROS CLÍNICOS INICIALES (6 PACIENTES Y TRATAMIENTOS)
-- ========================================================

INSERT INTO public.pacientes (id, nombre, apellido, email, telefono, fecha_nacimiento, fechaNacimiento, genero, direccion)
VALUES
  ('pac_catarina_ramirez', 'Catarina', 'Ramirez', 'catarina.ramirez@pacientes.rizo.gt', '+502 5123 4567', '1972-04-12', '1972-04-12', 'Femenino', 'Ciudad de Guatemala (54 años)'),
  ('pac_josue_naz', 'Josue David', 'Naz Morales', 'josue.naz@pacientes.rizo.gt', '+502 5432 9876', '1998-06-20', '1998-06-20', 'Masculino', 'Guatemala (28 años)'),
  ('pac_maria_giron', 'María', 'Girón', 'maria.giron@pacientes.rizo.gt', '+502 4111 2233', '1993-09-14', '1993-09-14', 'Femenino', 'Mixco, Guatemala (33 años)'),
  ('pac_cesar_lopez', 'Cesar Augusto', 'López Rodríguez', 'cesar.lopez@pacientes.rizo.gt', '+502 5888 7766', '1977-02-18', '1977-02-18', 'Masculino', 'Zona 14, Ciudad de Guatemala (49 años)'),
  ('pac_adriana_lemus', 'Adriana Guadalupe', 'Lemus', 'adriana.lemus@pacientes.rizo.gt', '+502 4222 3344', '2006-11-05', '2006-11-05', 'Femenino', 'Carretera a El Salvador, Guatemala (20 años)'),
  ('pac_alfonso_rosales', 'Alfonso Dorian', 'Rosales Cisneros', 'alfonso.rosales@pacientes.rizo.gt', '+502 5999 8811', '1953-05-10', '1953-05-10', 'Masculino', 'Zona 1, Ciudad de Guatemala (DPI: 1983 58555 0101, 73 años)')
ON CONFLICT (id) DO UPDATE SET
  nombre = EXCLUDED.nombre,
  apellido = EXCLUDED.apellido,
  telefono = EXCLUDED.telefono,
  fecha_nacimiento = EXCLUDED.fecha_nacimiento,
  direccion = EXCLUDED.direccion;

INSERT INTO public.tratamientos (id, paciente_id, diente, categoria, tratamiento, subtipo, diagnostico, evolucion, precio_gtq, abono_gtq, estado, notas, fecha)
VALUES
  ('trat_catarina_1', 'pac_catarina_ramirez', 0, 'cirugia_implantes', 'Implantes Subperiósticos Bimaxilares + Prótesis Atornillada', 'Cirugía de Implantes Subperiósticos', 'Pérdida total de piezas dentales y reabsorción ósea grave. Desajuste de prótesis removible por pérdida ósea.', 'Planificación Quirúrgica & Diseño 3D', 38000.0, 15000.0, 'En Proceso', 'Colocación de implantes subperiósticos en ambas arcadas para colocación de prótesis provisional atornillada sobre implantes dentales.', '2026-10-20'),
  ('trat_josue_1', 'pac_josue_naz', 31, 'cirugia_implantes', 'Extracción Quirúrgica Pza. 31 + Implante Dental + Regeneración Ósea', 'Implante Inmediato con Membrana de Colágeno', 'Pieza 31 con caries profunda no restaurable.', 'Fase Quirúrgica Programada', 6500.0, 3000.0, 'Programado', 'Se extrae quirúrgicamente pieza 31 y se rehabilita con colocación de implante dental en pieza 31 para restauración de pieza ausente. Requiere regeneración ósea y membrana de colágeno. Se rehabilita posteriormente con corona de zirconio atornillada sobre implante.', '2026-10-21'),
  ('trat_maria_1', 'pac_maria_giron', 18, 'cirugia_implantes', 'Colocación de Implantes Dentales en Piezas 18, 19, 3 y 4', 'Implantes Múltiples con Regeneración y Membrana', 'Piezas 18, 19, 3 y 4 ausentes. Pérdida ósea', 'Regeneración Ósea y Fase Quirúrgica', 24000.0, 8000.0, 'En Proceso', 'Se colocan implantes dentales en piezas 18, 19, 3 y 4 para reposición de piezas dentales ausentes. Es necesario regeneración ósea y membrana en piezas 18 y 19. Se rehabilita con coronas de zirconio.', '2026-10-19'),
  ('trat_cesar_1', 'pac_cesar_lopez', 8, 'cirugia_implantes', 'Extracción Quirúrgica Resto Radicular Pza. 8 + Implante + Injerto Conectivo', 'Implante Dental con Membrana de Tejido Conectivo', 'Resto radicular de pieza 8 no restaurable.', 'Programación Quirúrgica', 8500.0, 4000.0, 'Programado', 'Extracción quirúrgica de resto radicular y colocación de implante dental para reponer pieza 8. Se realiza regeneración ósea y membrana de tejido conectivo para protección de injerto.', '2026-10-21'),
  ('trat_adriana_1', 'pac_adriana_lemus', 0, 'cirugia_maxilofacial', 'Remoción de Ameloblastoma + Injerto de Peroné + Placa + Implante Subperióstico', 'Cirugía Maxilofacial Reconstructiva Microvascular', 'Ameloblastoma en cuerpo mandibular izquierdo.', 'Planificación Hospitalaria & VSP 3D', 75000.0, 30000.0, 'En Proceso', 'Remoción quirúrgica de Ameloblastoma en cuerpo mandibular izquierdo, injerto microvascularizado de peroné para reconstrucción mandibular, colocación de placa de reconstrucción y posterior, colocación de implante dental subperióstico para rehabilitación y repoisción de piezas dentales ausentes.', '2026-10-18'),
  ('trat_alfonso_1', 'pac_alfonso_rosales', 0, 'cirugia_maxilofacial', 'Biopsia Escisional de Quiste Nasopalatino en Quirófano + Estudio Histopatológico', 'Cirugía Hospitalaria y Enucleación de Quiste', 'Quiste nasopalatino.', 'Programación en Sala de Operaciones', 14500.0, 5000.0, 'Programado', 'DPI: 1983 58555 0101. Biopsia escisional para retiro de quiste nasopalatino en sala de operaciones, 24 hrs hospitalización, más estudio histopatológico.', '2026-10-21')
ON CONFLICT (id) DO UPDATE SET
  tratamiento = EXCLUDED.tratamiento,
  diagnostico = EXCLUDED.diagnostico,
  estado = EXCLUDED.estado,
  notas = EXCLUDED.notas;

INSERT INTO public.evaluaciones (id, paciente_id, paciente_nombre, fecha, puntuacion, diagnostico, respuestas)
VALUES
  ('eval_catarina_1', 'pac_catarina_ramirez', 'Catarina Ramirez', '2026-10-20', 15, 'Pérdida total de piezas dentales y reabsorción ósea grave. Desajuste de prótesis removible por pérdida ósea.', '{"motivo": "Pérdida total de piezas dentales", "edad": "54 años"}'),
  ('eval_josue_1', 'pac_josue_naz', 'Josue David Naz Morales', '2026-10-21', 10, 'Pieza 31 con caries profunda no restaurable.', '{"motivo": "Caries profunda no restaurable en pza 31", "edad": "28 años"}'),
  ('eval_maria_1', 'pac_maria_giron', 'María Girón', '2026-10-19', 14, 'Piezas 18, 19, 3 y 4 ausentes. Pérdida ósea', '{"motivo": "Piezas 18, 19, 3 y 4 ausentes", "edad": "33 años"}'),
  ('eval_cesar_1', 'pac_cesar_lopez', 'Cesar Augusto López Rodríguez', '2026-10-21', 11, 'Resto radicular de pieza 8 no restaurable.', '{"motivo": "Resto radicular pza 8", "edad": "49 años"}'),
  ('eval_adriana_1', 'pac_adriana_lemus', 'Adriana Guadalupe Lemus', '2026-10-18', 18, 'Ameloblastoma en cuerpo mandibular izquierdo.', '{"motivo": "Ameloblastoma mandibular", "edad": "20 años"}'),
  ('eval_alfonso_1', 'pac_alfonso_rosales', 'Alfonso Dorian Rosales Cisneros', '2026-10-21', 16, 'Quiste nasopalatino.', '{"motivo": "Quiste nasopalatino", "edad": "73 años", "dpi": "1983 58555 0101"}')
ON CONFLICT (id) DO UPDATE SET
  diagnostico = EXCLUDED.diagnostico,
  respuestas = EXCLUDED.respuestas;

