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
