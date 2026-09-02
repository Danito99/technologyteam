-- ══════════════════════════════════════════════════════════════
-- HOMOLOGACIÓN DE PERIODOS — ejecutar en el SQL Editor de Supabase
--
-- Modelo canónico:
--   · Secundaria (trimestral):  3 periodos → T1, T2, T3 (sin parciales)
--   · Preparatoria (semestral): 6 periodos → Sem A · P1..P3, Sem B · P1..P3
--
-- Qué hace:
--   1. Permite regenerar el plan analítico sin romper sesiones (FK → SET NULL)
--   2. Colapsa los trimestres duplicados (T1·P1, T1·P2...) a un solo T por número
--   3. Reasigna filas del plan, sesiones, planes de clase y calificaciones
--   4. Normaliza etiquetas y garantiza que existan los 3+6 periodos
--   5. Reemplaza la función de sincronización por una versión incremental
-- ══════════════════════════════════════════════════════════════

begin;

-- ── 1. FK de sesiones → plan_analitico_filas: no bloquear regeneración ──
alter table public.sesiones
  drop constraint if exists sesiones_plan_analitico_ref_id_fkey;
alter table public.sesiones
  add constraint sesiones_plan_analitico_ref_id_fkey
  foreign key (plan_analitico_ref_id) references public.plan_analitico_filas(id)
  on delete set null;

-- ── 2. Trimestre canónico = fila con parcial mínimo por (ciclo, numero) ──
drop table if exists periodos_canon;
create temp table periodos_canon as
select distinct on (ciclo_id, numero) id as canon_id, ciclo_id, numero
from public.periodos
where tipo = 'trimestre'
order by ciclo_id, numero, parcial;

drop table if exists periodo_map;
create temp table periodo_map as
select p.id as old_id, c.canon_id
from public.periodos p
join periodos_canon c on c.ciclo_id = p.ciclo_id and c.numero = p.numero
where p.tipo = 'trimestre';

-- ── 3. Plan analítico: respetar la intención del docente ──
-- Las pestañas viejas guardaban periodo_numero = trimestre que el docente creyó elegir.
update public.plan_analitico_filas f
set periodo_id = c.canon_id
from public.periodos p, periodos_canon c
where f.periodo_id = p.id
  and p.tipo = 'trimestre'
  and c.ciclo_id = p.ciclo_id
  and c.numero = least(greatest(coalesce(f.periodo_numero, p.numero), 1), 3);

-- ── 4. Sesiones vinculadas a una fila siguen a su fila ──
update public.sesiones s
set periodo_id = f.periodo_id
from public.plan_analitico_filas f
where s.plan_analitico_ref_id = f.id
  and s.periodo_id <> f.periodo_id;

-- Sesiones sueltas: remap por número de trimestre
update public.sesiones s
set periodo_id = m.canon_id
from periodo_map m
where s.plan_analitico_ref_id is null
  and s.periodo_id = m.old_id
  and m.old_id <> m.canon_id;

-- Renumerar sesiones por si el merge dejó números duplicados
with r as (
  select id, row_number() over (
    partition by grupo_materia_id, periodo_id
    order by numero, created_at
  ) as rn
  from public.sesiones
)
update public.sesiones s
set numero = r.rn
from r where r.id = s.id and s.numero <> r.rn;

-- ── 5. Planes de clase: remap + dedupe (conserva el más reciente) ──
update public.planes_clase pc
set periodo_id = m.canon_id
from periodo_map m
where pc.periodo_id = m.old_id and m.old_id <> m.canon_id;

delete from public.planes_clase a
using public.planes_clase b
where a.grupo_materia_id = b.grupo_materia_id
  and a.periodo_id = b.periodo_id
  and a.id <> b.id
  and (coalesce(a.entregado_at, 'epoch'::timestamptz), a.ctid)
    < (coalesce(b.entregado_at, 'epoch'::timestamptz), b.ctid);

-- ── 6. Calificaciones: dedupe antes de remap (hay unique por alumno/gm/periodo) ──
-- 6a. Borrar las que colisionarían con una calificación ya existente en el canon
delete from public.calificaciones c
using periodo_map m
where c.periodo_id = m.old_id and m.old_id <> m.canon_id
  and exists (
    select 1 from public.calificaciones c2
    where c2.alumno_id = c.alumno_id
      and c2.grupo_materia_id = c.grupo_materia_id
      and c2.periodo_id = m.canon_id
  );

-- 6b. Entre duplicados que van al mismo canon, conservar uno
delete from public.calificaciones c
using periodo_map m1, public.calificaciones c2, periodo_map m2
where c.periodo_id  = m1.old_id and m1.old_id <> m1.canon_id
  and c2.periodo_id = m2.old_id and m2.old_id <> m2.canon_id
  and m1.canon_id = m2.canon_id
  and c.alumno_id = c2.alumno_id
  and c.grupo_materia_id = c2.grupo_materia_id
  and c.id <> c2.id
  and c.ctid < c2.ctid;

-- 6c. Remap
update public.calificaciones c
set periodo_id = m.canon_id
from periodo_map m
where c.periodo_id = m.old_id and m.old_id <> m.canon_id;

-- ── 7. Eliminar periodos trimestre no canónicos ──
delete from public.periodos p
using periodo_map m
where p.id = m.old_id and m.old_id <> m.canon_id;

-- ── 8. Normalizar etiquetas ──
update public.periodos set etiqueta = 'T' || numero, parcial = 1
where tipo = 'trimestre';

update public.periodos
set etiqueta = 'Sem ' || case when numero = 1 then 'A' else 'B' end || ' · P' || parcial
where tipo = 'semestre';

-- ── 9. Garantizar que existan todos los periodos del ciclo activo ──
insert into public.periodos (ciclo_id, tipo, numero, parcial, etiqueta)
select c.id, 'trimestre', n, 1, 'T' || n
from public.ciclos_escolares c
cross join generate_series(1, 3) n
where c.activo
on conflict (ciclo_id, tipo, numero, parcial) do nothing;

insert into public.periodos (ciclo_id, tipo, numero, parcial, etiqueta)
select c.id, 'semestre', n, p,
       'Sem ' || case when n = 1 then 'A' else 'B' end || ' · P' || p
from public.ciclos_escolares c
cross join generate_series(1, 2) n
cross join generate_series(1, 3) p
where c.activo
on conflict (ciclo_id, tipo, numero, parcial) do nothing;

-- ── 10. Sincronización incremental de sesiones ──
-- Reemplaza la versión anterior, que solo generaba cuando el periodo estaba
-- vacío (por eso las filas nuevas del plan nunca creaban su sesión).
-- Esta versión: alinea por posición, actualiza título/vínculo de las
-- existentes, crea las faltantes y conserva el estado "completada".
drop function if exists public.sincronizar_sesiones_con_plan_analitico(uuid);

create or replace function public.sincronizar_sesiones_con_plan_analitico(
  p_grupo_materia_id uuid default null
)
returns table(
  grupo_materia_id uuid,
  periodo_id uuid,
  sesiones_sincronizadas integer
)
language plpgsql security definer as $$
declare
  gm record;
  fila record;
  n integer;
  creadas integer;
begin
  for gm in
    select distinct f.grupo_materia_id as gm_id, f.periodo_id as per_id
    from public.plan_analitico_filas f
    join public.grupo_materias gmt on gmt.id = f.grupo_materia_id
    join public.grupos g on g.id = gmt.grupo_id and g.docente_id = auth.uid()
    where (p_grupo_materia_id is null or f.grupo_materia_id = p_grupo_materia_id)
      and f.es_examen = false
  loop
    creadas := 0;
    n := 0;
    for fila in
      select f.* from public.plan_analitico_filas f
      where f.grupo_materia_id = gm.gm_id
        and f.periodo_id = gm.per_id
        and f.es_examen = false
      order by f.orden, f.created_at
    loop
      n := n + 1;
      if exists (
        select 1 from public.sesiones s
        where s.grupo_materia_id = gm.gm_id
          and s.periodo_id = gm.per_id
          and s.numero = n
      ) then
        update public.sesiones s
        set titulo = coalesce(fila.aprendizaje_esperado, s.titulo),
            plan_analitico_ref_id = fila.id
        where s.grupo_materia_id = gm.gm_id
          and s.periodo_id = gm.per_id
          and s.numero = n;
      else
        insert into public.sesiones
          (grupo_materia_id, periodo_id, numero, titulo, plan_analitico_ref_id, completada)
        values
          (gm.gm_id, gm.per_id, n,
           coalesce(fila.aprendizaje_esperado, 'Sesión ' || n), fila.id, false);
        creadas := creadas + 1;
      end if;
    end loop;
    return query select gm.gm_id, gm.per_id, creadas;
  end loop;
end;
$$;

commit;

-- ══════════════════════════════════════════════════════════════
-- Verificación rápida después de ejecutar:
--   select tipo, numero, parcial, etiqueta from public.periodos order by tipo, numero, parcial;
--   → Debe mostrar: T1, T2, T3 y Sem A · P1..P3, Sem B · P1..P3
--
--   La sincronización corre sola cuando el docente abre "Planes de clase"
--   (desde el SQL Editor auth.uid() es null, así que ahí no genera nada)
-- ══════════════════════════════════════════════════════════════
