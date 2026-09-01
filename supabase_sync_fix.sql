-- ══════════════════════════════════════════════════════════
-- Fix adicional: columna faltante en sesiones
-- ══════════════════════════════════════════════════════════
-- sesion-editor.html guarda comentarios_docente pero la columna
-- no existe en el schema original ni en supabase_sesiones_update.sql.
-- Supabase silenciosamente ignora campos no definidos al hacer UPDATE.
ALTER TABLE public.sesiones

  ADD COLUMN IF NOT EXISTS comentarios_docente text;

-- tipo_actividad faltante en plan_analitico_filas
-- La columna se usa en plan-analitico.html y en obtener_sesion_con_plan_analitico()
-- pero nunca se definió en el schema original.
ALTER TABLE public.plan_analitico_filas
  ADD COLUMN IF NOT EXISTS tipo_actividad text;

-- ══════════════════════════════════════════════════════════
-- Fix: sincronización segura de sesiones con plan analítico
-- Ejecutar en el SQL Editor de Supabase
--
-- Problema que resuelve:
--   La función anterior solo creaba sesiones si NO existía
--   ninguna para ese (grupo_materia, periodo). Si ya había
--   sesiones, no hacía nada — los cambios al plan analítico
--   nunca se reflejaban.
--   Peor aún: cuando sí creaba sesiones, primero borraba
--   TODAS las existentes, destruyendo el contenido
--   (inicio/desarrollo/cierre) que el docente había escrito.
--
-- Comportamiento nuevo:
--   ✅ Solo CREA sesiones para filas del plan que aún no
--      tienen sesión vinculada (por plan_analitico_ref_id).
--   ✅ Nunca borra sesiones existentes.
--   ✅ Nunca modifica el contenido de sesiones existentes.
--   ✅ Si el plan crece, se agregan las sesiones faltantes.
--   ✅ Si el plan shrinks, las sesiones huérfanas se conservan.
-- ══════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.sincronizar_sesiones_con_plan_analitico(
  p_grupo_materia_id uuid DEFAULT NULL
)
RETURNS TABLE(
  grupo_materia_id     uuid,
  periodo_id           uuid,
  sesiones_sincronizadas integer   -- número de sesiones CREADAS en esta llamada
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  gm_record   record;
  fila_plan   record;
  proximo_num integer;
  creadas     integer;
BEGIN
  FOR gm_record IN
    SELECT gm.id AS gm_id, per.id AS per_id
    FROM   public.grupo_materias    gm
    JOIN   public.grupos             g   ON g.id   = gm.grupo_id
    JOIN   public.ciclos_escolares   c   ON c.id   = g.ciclo_id AND c.activo = true
    JOIN   public.periodos           per ON per.ciclo_id = c.id
    WHERE  (p_grupo_materia_id IS NULL OR gm.id = p_grupo_materia_id)
      AND  g.docente_id = auth.uid()
  LOOP
    -- Si no hay plan analítico para este par, saltar
    IF NOT EXISTS (
      SELECT 1 FROM public.plan_analitico_filas
      WHERE grupo_materia_id = gm_record.gm_id
        AND periodo_id        = gm_record.per_id
        AND es_examen         = false
    ) THEN CONTINUE; END IF;

    creadas := 0;

    -- Próximo número disponible (por encima del máximo existente)
    SELECT COALESCE(MAX(numero), 0) + 1 INTO proximo_num
    FROM   public.sesiones
    WHERE  grupo_materia_id = gm_record.gm_id
      AND  periodo_id        = gm_record.per_id;

    -- Procesar solo las filas del plan que AÚN NO tienen sesión vinculada
    FOR fila_plan IN
      SELECT paf.*
      FROM   public.plan_analitico_filas paf
      WHERE  paf.grupo_materia_id = gm_record.gm_id
        AND  paf.periodo_id        = gm_record.per_id
        AND  paf.es_examen         = false
        AND  paf.id NOT IN (
          SELECT s.plan_analitico_ref_id
          FROM   public.sesiones s
          WHERE  s.grupo_materia_id        = gm_record.gm_id
            AND  s.periodo_id              = gm_record.per_id
            AND  s.plan_analitico_ref_id IS NOT NULL
        )
      ORDER BY paf.orden, paf.created_at
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
        gm_record.gm_id,
        gm_record.per_id,
        proximo_num,
        COALESCE(fila_plan.aprendizaje_esperado, 'Sesión ' || proximo_num),
        fila_plan.id,
        false,
        now()
      )
      ON CONFLICT (grupo_materia_id, periodo_id, numero) DO NOTHING;

      proximo_num := proximo_num + 1;
      creadas     := creadas + 1;
    END LOOP;

    -- Solo reportar pares donde se creó algo
    IF creadas > 0 THEN
      RETURN QUERY SELECT gm_record.gm_id, gm_record.per_id, creadas;
    END IF;
  END LOOP;
END;
$$;

-- ══════════════════════════════════════════════════════════
-- NOTA SOBRE generar_sesiones_desde_plan_analitico:
-- ══════════════════════════════════════════════════════════
-- Esta función (definida en supabase_sesiones_update.sql)
-- es DESTRUCTIVA: borra TODAS las sesiones del (gm, periodo)
-- antes de recrearlas, destruyendo el contenido del docente.
--
-- Ya NO es llamada por sincronizar_sesiones_con_plan_analitico.
-- Conservarla solo para usos manuales explícitos cuando se
-- quiera reiniciar un periodo desde cero sin ningún contenido.
-- ══════════════════════════════════════════════════════════
