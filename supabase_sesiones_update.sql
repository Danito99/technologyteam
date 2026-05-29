-- ══════════════════════════════════════════════════════════
-- Actualización de tabla SESIONES para integración con plan analítico
-- Ejecutar en el SQL Editor de Supabase
-- ══════════════════════════════════════════════════════════

-- ── 1. AGREGAR CAMPOS FALTANTES A LA TABLA SESIONES ──────────
ALTER TABLE public.sesiones
ADD COLUMN IF NOT EXISTS inicio text,
ADD COLUMN IF NOT EXISTS desarrollo text,
ADD COLUMN IF NOT EXISTS cierre text,
ADD COLUMN IF NOT EXISTS materiales text,
ADD COLUMN IF NOT EXISTS materiales_json jsonb,
ADD COLUMN IF NOT EXISTS plan_analitico_ref_id uuid REFERENCES public.plan_analitico_filas(id),
ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- ── 2. FUNCIÓN PARA AUTO-GENERAR SESIONES DESDE PLAN ANALÍTICO ──
CREATE OR REPLACE FUNCTION public.generar_sesiones_desde_plan_analitico(
  p_grupo_materia_id uuid,
  p_periodo_id uuid
)
RETURNS TABLE(sesiones_creadas integer)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  fila_plan record;
  sesion_numero integer := 1;
  sesiones_count integer := 0;
BEGIN
  -- Limpiar sesiones existentes para este grupo_materia y periodo
  DELETE FROM public.sesiones
  WHERE grupo_materia_id = p_grupo_materia_id
    AND periodo_id = p_periodo_id;

  -- Crear sesiones basadas en el plan analítico
  FOR fila_plan IN
    SELECT * FROM public.plan_analitico_filas
    WHERE grupo_materia_id = p_grupo_materia_id
      AND periodo_id = p_periodo_id
      AND es_examen = false
    ORDER BY orden, created_at
  LOOP
    INSERT INTO public.sesiones (
      grupo_materia_id,
      periodo_id,
      numero,
      titulo,
      plan_analitico_ref_id,
      completada,
      created_at
    ) VALUES (
      p_grupo_materia_id,
      p_periodo_id,
      sesion_numero,
      COALESCE(fila_plan.aprendizaje_esperado, 'Sesión ' || sesion_numero),
      fila_plan.id,
      false,
      now()
    );

    sesion_numero := sesion_numero + 1;
    sesiones_count := sesiones_count + 1;
  END LOOP;

  RETURN QUERY SELECT sesiones_count;
END;
$$;

-- ── 3. FUNCIÓN PARA SINCRONIZAR SESIONES CON PLAN ANALÍTICO ──
CREATE OR REPLACE FUNCTION public.sincronizar_sesiones_con_plan_analitico(
  p_grupo_materia_id uuid DEFAULT NULL
)
RETURNS TABLE(
  grupo_materia_id uuid,
  periodo_id uuid,
  sesiones_sincronizadas integer
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  gm_record record;
  resultado record;
BEGIN
  -- Si no se especifica grupo_materia_id, sincronizar todos los del docente actual
  FOR gm_record IN
    SELECT gm.id as gm_id, per.id as per_id
    FROM public.grupo_materias gm
    JOIN public.grupos g ON g.id = gm.grupo_id
    JOIN public.ciclos_escolares c ON c.id = g.ciclo_id AND c.activo = true
    JOIN public.periodos per ON per.ciclo_id = c.id
    WHERE (p_grupo_materia_id IS NULL OR gm.id = p_grupo_materia_id)
      AND g.docente_id = auth.uid()
  LOOP
    -- Verificar si hay plan analítico para este grupo-materia-periodo
    IF EXISTS (
      SELECT 1 FROM public.plan_analitico_filas
      WHERE grupo_materia_id = gm_record.gm_id
        AND periodo_id = gm_record.per_id
        AND es_examen = false
    ) THEN
      -- Solo generar si no existen sesiones o si están desactualizadas
      IF NOT EXISTS (
        SELECT 1 FROM public.sesiones
        WHERE grupo_materia_id = gm_record.gm_id
          AND periodo_id = gm_record.per_id
      ) THEN
        SELECT INTO resultado.sesiones_sincronizadas
          * FROM public.generar_sesiones_desde_plan_analitico(
            gm_record.gm_id,
            gm_record.per_id
          );

        RETURN QUERY SELECT
          gm_record.gm_id,
          gm_record.per_id,
          resultado.sesiones_sincronizadas;
      END IF;
    END IF;
  END LOOP;
END;
$$;

-- ── 4. FUNCIÓN PARA OBTENER DATOS COMPLETOS DE SESIÓN ──────────
CREATE OR REPLACE FUNCTION public.obtener_sesion_con_plan_analitico(
  p_sesion_id uuid
)
RETURNS TABLE(
  -- Campos de sesión
  sesion_id uuid,
  numero integer,
  titulo text,
  inicio text,
  desarrollo text,
  cierre text,
  materiales text,
  materiales_json jsonb,
  completada boolean,
  fecha_completada timestamptz,
  -- Campos del plan analítico
  eje_articulador text,
  contenido text,
  aprendizaje_esperado text,
  saber_hacer text,
  tipo_actividad text,
  semana text
)
LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.id as sesion_id,
    s.numero,
    s.titulo,
    s.inicio,
    s.desarrollo,
    s.cierre,
    s.materiales,
    s.materiales_json,
    s.completada,
    s.fecha_completada,
    pa.eje_articulador,
    pa.contenido,
    pa.aprendizaje_esperado,
    pa.saber_hacer,
    COALESCE(pa.tipo_actividad, 'Trabajo de clase') as tipo_actividad,
    pa.semana
  FROM public.sesiones s
  LEFT JOIN public.plan_analitico_filas pa ON pa.id = s.plan_analitico_ref_id
  WHERE s.id = p_sesion_id;
END;
$$;

-- ── 5. ACTUALIZAR POLÍTICAS RLS PARA NUEVOS CAMPOS ────────────

-- Las políticas existentes cubren la tabla sesiones, pero agregamos una específica para la función
CREATE POLICY "sesiones: usar funciones propias" ON public.sesiones
  FOR ALL USING (
    grupo_materia_id IN (
      SELECT gm.id FROM public.grupo_materias gm
      JOIN public.grupos g ON g.id = gm.grupo_id
      WHERE g.docente_id = auth.uid()
    )
  );

-- ── 6. TRIGGER PARA AUTO-ACTUALIZAR updated_at ──────────────────
CREATE OR REPLACE FUNCTION public.actualizar_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Aplicar trigger a la tabla sesiones
DROP TRIGGER IF EXISTS trg_sesiones_updated_at ON public.sesiones;
CREATE TRIGGER trg_sesiones_updated_at
  BEFORE UPDATE ON public.sesiones
  FOR EACH ROW EXECUTE FUNCTION public.actualizar_updated_at();

-- ── 7. ÍNDICES PARA MEJOR RENDIMIENTO ──────────────────────────
CREATE INDEX IF NOT EXISTS idx_sesiones_plan_ref
  ON public.sesiones(plan_analitico_ref_id)
  WHERE plan_analitico_ref_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_sesiones_completada
  ON public.sesiones(completada);

CREATE INDEX IF NOT EXISTS idx_sesiones_updated_at
  ON public.sesiones(updated_at DESC);

-- ══════════════════════════════════════════════════════════
-- INSTRUCCIONES DE USO:
-- ══════════════════════════════════════════════════════════
--
-- 1. Para sincronizar todas las sesiones del docente actual:
--    SELECT * FROM public.sincronizar_sesiones_con_plan_analitico();
--
-- 2. Para generar sesiones de un grupo-materia específico:
--    SELECT * FROM public.generar_sesiones_desde_plan_analitico('uuid-gm', 'uuid-periodo');
--
-- 3. Para obtener datos completos de una sesión:
--    SELECT * FROM public.obtener_sesion_con_plan_analitico('uuid-sesion');
-- ══════════════════════════════════════════════════════════