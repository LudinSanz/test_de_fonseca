-- ========================================================
-- RIZO DENTAL - SCRIPT COMPLETO DE TABLAS EN SUPABASE
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

-- Asegurar columnas si la tabla ya existía anteriormente
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS colegiado TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS especialidad TEXT;
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
  medicamentos JSONB NOT NULL,
  indicaciones TEXT,
  firma_digital TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. TABLA DE INVENTARIO CLÍNICO (inventario)
CREATE TABLE IF NOT EXISTS public.inventario (
  id TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  categoria TEXT NOT NULL, -- Medicamentos, Instrumentos, Insumos
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
  motivo TEXT NOT NULL,
  estado TEXT DEFAULT 'Programada', -- Programada, Confirmada, Cancelada, Realizada
  notas TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

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

-- PERMISOS PUBLICOS / RLS DESHABILITADO PARA ACCESO DIRECTO DESDE FLUTTER
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.pacientes DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.evaluaciones DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.recetas DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventario DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.citas DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracion DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.reportes DISABLE ROW LEVEL SECURITY;

GRANT ALL ON TABLE public.users TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.pacientes TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.evaluaciones TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.recetas TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.inventario DISABLE ROW LEVEL SECURITY;
GRANT ALL ON TABLE public.citas TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.configuracion TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.reportes TO anon, authenticated, service_role;
