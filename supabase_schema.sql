-- ══════════════════════════════════════════════════════════
-- TechAcademia — Schema Supabase
-- Ejecutar en orden en el SQL Editor de Supabase
-- ══════════════════════════════════════════════════════════

-- ── 1. PROFILES ──────────────────────────────────────────
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  nombre      text not null,
  rol         text not null check (rol in ('admin', 'docente')),
  avatar_url  text,
  created_at  timestamptz default now()
);

-- Auto-crear profile al registrar usuario en auth
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, nombre, rol)
  values (new.id, new.raw_user_meta_data->>'nombre', coalesce(new.raw_user_meta_data->>'rol', 'docente'));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ── 2. CICLOS ESCOLARES ───────────────────────────────────
create table public.ciclos_escolares (
  id           uuid primary key default gen_random_uuid(),
  nombre       text not null,        -- ej. '2025-2026'
  activo       boolean default false,
  fecha_inicio date,
  fecha_fin    date,
  created_at   timestamptz default now()
);

-- Solo un ciclo activo a la vez
create unique index idx_ciclo_activo on public.ciclos_escolares (activo)
  where activo = true;


-- ── 3. METAS DE RENDIMIENTO ───────────────────────────────
create table public.metas_rendimiento (
  id         uuid primary key default gen_random_uuid(),
  ciclo_id   uuid not null references public.ciclos_escolares(id) on delete cascade,
  banda      text not null check (banda in ('gold1','green2','green1','yellow1','red2','red1')),
  rango_min  numeric(4,1) not null,
  rango_max  numeric(4,1) not null,
  meta_pct   numeric(5,2) not null,  -- ej. 22.0
  unique (ciclo_id, banda)
);

-- Datos por defecto (ejecutar después de crear el ciclo)
-- insert into public.metas_rendimiento (ciclo_id, banda, rango_min, rango_max, meta_pct) values
--   ('<ciclo_id>', 'gold1',   9.5, 10.0, 22),
--   ('<ciclo_id>', 'green2',  8.5,  9.4, 38),
--   ('<ciclo_id>', 'green1',  7.5,  8.4, 21),
--   ('<ciclo_id>', 'yellow1', 6.5,  7.4,  7),
--   ('<ciclo_id>', 'red2',    6.0,  6.4,  9),
--   ('<ciclo_id>', 'red1',    5.0,  5.9,  3);


-- ── 4. PERIODOS ───────────────────────────────────────────
create table public.periodos (
  id           uuid primary key default gen_random_uuid(),
  ciclo_id     uuid not null references public.ciclos_escolares(id) on delete cascade,
  tipo         text not null check (tipo in ('trimestre','semestre')),
  numero       int not null,   -- 1, 2, 3
  parcial      int not null,   -- 1, 2, 3
  etiqueta     text not null,  -- ej. 'T2 · P1', 'Sem A · P2'
  fecha_inicio date,
  fecha_fin    date,
  unique (ciclo_id, tipo, numero, parcial)
);


-- ── 5. GRUPOS ─────────────────────────────────────────────
create table public.grupos (
  id                uuid primary key default gen_random_uuid(),
  ciclo_id          uuid not null references public.ciclos_escolares(id) on delete cascade,
  docente_id        uuid not null references public.profiles(id) on delete cascade,
  nombre            text not null,   -- ej. '9°A'
  nivel             text not null check (nivel in ('primaria','secundaria','preparatoria')),
  grado             int not null,    -- 1–12
  sistema_periodos  text not null check (sistema_periodos in ('trimestral','semestral')),
  created_at        timestamptz default now(),
  unique (ciclo_id, docente_id, nombre)
);


-- ── 6. MATERIAS ───────────────────────────────────────────
create table public.materias (
  id          uuid primary key default gen_random_uuid(),
  docente_id  uuid not null references public.profiles(id) on delete cascade,
  ciclo_id    uuid not null references public.ciclos_escolares(id) on delete cascade,
  nombre      text not null,
  created_at  timestamptz default now(),
  unique (docente_id, ciclo_id, nombre)
);


-- ── 7. GRUPO_MATERIAS (tabla puente) ─────────────────────
create table public.grupo_materias (
  id          uuid primary key default gen_random_uuid(),
  grupo_id    uuid not null references public.grupos(id) on delete cascade,
  materia_id  uuid not null references public.materias(id) on delete cascade,
  created_at  timestamptz default now(),
  unique (grupo_id, materia_id)
);


-- ── 8. ALUMNOS ────────────────────────────────────────────
create table public.alumnos (
  id          uuid primary key default gen_random_uuid(),
  grupo_id    uuid not null references public.grupos(id) on delete cascade,
  nombre      text not null,
  apellido    text not null,
  activo      boolean default true,
  created_at  timestamptz default now()
);


-- ── 9. SESIONES ───────────────────────────────────────────
create table public.sesiones (
  id                uuid primary key default gen_random_uuid(),
  grupo_materia_id  uuid not null references public.grupo_materias(id) on delete cascade,
  periodo_id        uuid not null references public.periodos(id),
  numero            int not null,
  titulo            text,
  completada        boolean default false,
  fecha_completada  timestamptz,
  unique (grupo_materia_id, periodo_id, numero)
);


-- ── 10. PLAN ANALÍTICO (filas) ────────────────────────────
create table public.plan_analitico_filas (
  id                  uuid primary key default gen_random_uuid(),
  grupo_materia_id    uuid not null references public.grupo_materias(id) on delete cascade,
  periodo_id          uuid not null references public.periodos(id),
  semana              text,
  eje_articulador     text,
  contenido           text,             -- objetivo general
  aprendizaje_esperado text,
  saber_hacer         text,             -- objetivos particulares
  es_examen           boolean default false,
  orden               int default 0,
  created_at          timestamptz default now()
);


-- ── 11. PLANES DE CLASE ───────────────────────────────────
create table public.planes_clase (
  id                  uuid primary key default gen_random_uuid(),
  grupo_materia_id    uuid not null references public.grupo_materias(id) on delete cascade,
  periodo_id          uuid not null references public.periodos(id),
  estado              text default 'borrador' check (estado in ('borrador','entregado','aprobado','rechazado')),
  nombre_proyecto     text,
  situacion_problema  text,
  metodologia         text,
  ejes_articuladores  text,
  ajustes_razonados   text,
  comentario_admin    text,
  revisado_by         uuid references public.profiles(id),
  entregado_at        timestamptz,
  modificado_at       timestamptz,
  created_at          timestamptz default now(),
  unique (grupo_materia_id, periodo_id)
);


-- ── 12. PLAN DE CLASE — SESIONES ─────────────────────────
create table public.plan_clase_sesiones (
  id                   uuid primary key default gen_random_uuid(),
  plan_clase_id        uuid not null references public.planes_clase(id) on delete cascade,
  numero               int not null,
  objetivo_particular  text,   -- copiado del plan analítico
  inicio               text,
  desarrollo           text,
  cierre               text,
  monitoreo            text,
  evaluacion           text,
  dua                  text,   -- null en primaria
  tipo_actividad       text,   -- solo preparatoria
  unique (plan_clase_id, numero)
);


-- ── 13. CALIFICACIONES ────────────────────────────────────
create table public.calificaciones (
  id                uuid primary key default gen_random_uuid(),
  alumno_id         uuid not null references public.alumnos(id) on delete cascade,
  grupo_materia_id  uuid not null references public.grupo_materias(id) on delete cascade,
  periodo_id        uuid not null references public.periodos(id),
  trabajo_clase     numeric(4,1),   -- 30%
  proyecto          numeric(4,1),   -- 25%
  examen            numeric(4,1),   -- 40%
  autoevaluacion    numeric(4,1),   -- 5%
  promedio_parcial  numeric(4,2),   -- calculado por trigger
  banda             text,           -- calculado por trigger
  updated_at        timestamptz default now(),
  unique (alumno_id, grupo_materia_id, periodo_id)
);

-- Trigger: calcular promedio y banda al guardar calificación
create or replace function public.calcular_promedio_banda()
returns trigger language plpgsql as $$
declare
  prom   numeric(4,2);
  v_banda text;
  meta   record;
  ciclo_id uuid;
begin
  -- Calcular promedio ponderado
  prom := coalesce(new.trabajo_clase, 0) * 0.30
        + coalesce(new.proyecto,      0) * 0.25
        + coalesce(new.examen,        0) * 0.40
        + coalesce(new.autoevaluacion,0) * 0.05;

  new.promedio_parcial := round(prom, 2);
  new.updated_at       := now();

  -- Obtener ciclo_id desde el periodo
  select p.ciclo_id into ciclo_id
  from public.periodos p where p.id = new.periodo_id;

  -- Asignar banda según metas del ciclo
  select banda into v_banda
  from public.metas_rendimiento
  where ciclo_id = ciclo_id
    and prom >= rango_min
    and prom <= rango_max
  limit 1;

  new.banda := coalesce(v_banda, 'red1');
  return new;
end;
$$;

create trigger trg_calcular_promedio
  before insert or update on public.calificaciones
  for each row execute function public.calcular_promedio_banda();


-- ── 14. HISTORIAL DE PLANES ───────────────────────────────
create table public.historial_planes (
  id             uuid primary key default gen_random_uuid(),
  plan_clase_id  uuid not null references public.planes_clase(id) on delete cascade,
  snapshot       jsonb not null,   -- copia completa del plan + sesiones
  accion         text not null check (accion in ('entregado','modificado','aprobado','rechazado')),
  actor_id       uuid not null references public.profiles(id),
  created_at     timestamptz default now()
);


-- ══════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY (RLS)
-- ══════════════════════════════════════════════════════════

alter table public.profiles            enable row level security;
alter table public.ciclos_escolares    enable row level security;
alter table public.metas_rendimiento   enable row level security;
alter table public.periodos            enable row level security;
alter table public.grupos              enable row level security;
alter table public.materias            enable row level security;
alter table public.grupo_materias      enable row level security;
alter table public.alumnos             enable row level security;
alter table public.sesiones            enable row level security;
alter table public.plan_analitico_filas enable row level security;
alter table public.planes_clase        enable row level security;
alter table public.plan_clase_sesiones enable row level security;
alter table public.calificaciones      enable row level security;
alter table public.historial_planes    enable row level security;

-- Helper: obtener rol del usuario actual
create or replace function public.mi_rol()
returns text language sql security definer stable as $$
  select rol from public.profiles where id = auth.uid()
$$;

-- Helper: obtener ids de grupos del docente actual
create or replace function public.mis_grupo_ids()
returns setof uuid language sql security definer stable as $$
  select id from public.grupos where docente_id = auth.uid()
$$;


-- ── Profiles ──
create policy "profiles: ver el propio" on public.profiles
  for select using (id = auth.uid() or public.mi_rol() = 'admin');

create policy "profiles: editar el propio" on public.profiles
  for update using (id = auth.uid());


-- ── Ciclos, periodos, metas: lectura libre, escritura solo admin ──
create policy "ciclos: lectura libre"    on public.ciclos_escolares  for select using (true);
create policy "periodos: lectura libre"  on public.periodos           for select using (true);
create policy "metas: lectura libre"     on public.metas_rendimiento  for select using (true);
create policy "ciclos: admin escribe"    on public.ciclos_escolares   for all using (public.mi_rol() = 'admin');
create policy "periodos: admin escribe"  on public.periodos           for all using (public.mi_rol() = 'admin');
create policy "metas: admin escribe"     on public.metas_rendimiento  for all using (public.mi_rol() = 'admin');


-- ── Grupos ──
create policy "grupos: docente ve los suyos" on public.grupos
  for select using (docente_id = auth.uid() or public.mi_rol() = 'admin');

create policy "grupos: docente crea/edita los suyos" on public.grupos
  for all using (docente_id = auth.uid());


-- ── Materias ──
create policy "materias: docente ve las suyas" on public.materias
  for select using (docente_id = auth.uid() or public.mi_rol() = 'admin');

create policy "materias: docente escribe las suyas" on public.materias
  for all using (docente_id = auth.uid());


-- ── Grupo_materias ──
create policy "grupo_materias: docente ve los suyos" on public.grupo_materias
  for select using (
    grupo_id in (select id from public.grupos where docente_id = auth.uid())
    or public.mi_rol() = 'admin'
  );

create policy "grupo_materias: docente escribe los suyos" on public.grupo_materias
  for all using (
    grupo_id in (select id from public.grupos where docente_id = auth.uid())
  );


-- ── Alumnos ──
create policy "alumnos: docente ve los suyos" on public.alumnos
  for select using (
    grupo_id in (select public.mis_grupo_ids())
    or public.mi_rol() = 'admin'
  );

create policy "alumnos: docente escribe los suyos" on public.alumnos
  for all using (grupo_id in (select public.mis_grupo_ids()));


-- ── Sesiones ──
create policy "sesiones: docente ve las suyas" on public.sesiones
  for select using (
    grupo_materia_id in (
      select gm.id from public.grupo_materias gm
      join public.grupos g on g.id = gm.grupo_id
      where g.docente_id = auth.uid()
    ) or public.mi_rol() = 'admin'
  );

create policy "sesiones: docente escribe las suyas" on public.sesiones
  for all using (
    grupo_materia_id in (
      select gm.id from public.grupo_materias gm
      join public.grupos g on g.id = gm.grupo_id
      where g.docente_id = auth.uid()
    )
  );


-- ── Plan analítico ──
create policy "plan_analitico: docente ve el suyo" on public.plan_analitico_filas
  for select using (
    grupo_materia_id in (
      select gm.id from public.grupo_materias gm
      join public.grupos g on g.id = gm.grupo_id
      where g.docente_id = auth.uid()
    ) or public.mi_rol() = 'admin'
  );

create policy "plan_analitico: docente escribe el suyo" on public.plan_analitico_filas
  for all using (
    grupo_materia_id in (
      select gm.id from public.grupo_materias gm
      join public.grupos g on g.id = gm.grupo_id
      where g.docente_id = auth.uid()
    )
  );


-- ── Planes de clase ──
create policy "planes_clase: docente ve los suyos" on public.planes_clase
  for select using (
    grupo_materia_id in (
      select gm.id from public.grupo_materias gm
      join public.grupos g on g.id = gm.grupo_id
      where g.docente_id = auth.uid()
    ) or public.mi_rol() = 'admin'
  );

create policy "planes_clase: docente escribe los suyos" on public.planes_clase
  for insert with check (
    grupo_materia_id in (
      select gm.id from public.grupo_materias gm
      join public.grupos g on g.id = gm.grupo_id
      where g.docente_id = auth.uid()
    )
  );

create policy "planes_clase: docente actualiza los suyos" on public.planes_clase
  for update using (
    grupo_materia_id in (
      select gm.id from public.grupo_materias gm
      join public.grupos g on g.id = gm.grupo_id
      where g.docente_id = auth.uid()
    )
  );

-- Admin solo puede tocar estado y comentario_admin
create policy "planes_clase: admin revisa" on public.planes_clase
  for update using (public.mi_rol() = 'admin');


-- ── Plan clase sesiones ──
create policy "plan_clase_sesiones: acceso via plan" on public.plan_clase_sesiones
  for all using (
    plan_clase_id in (
      select pc.id from public.planes_clase pc
      join public.grupo_materias gm on gm.id = pc.grupo_materia_id
      join public.grupos g on g.id = gm.grupo_id
      where g.docente_id = auth.uid() or public.mi_rol() = 'admin'
    )
  );


-- ── Calificaciones ──
create policy "calificaciones: docente ve las suyas" on public.calificaciones
  for select using (
    grupo_materia_id in (
      select gm.id from public.grupo_materias gm
      join public.grupos g on g.id = gm.grupo_id
      where g.docente_id = auth.uid()
    ) or public.mi_rol() = 'admin'
  );

create policy "calificaciones: docente escribe las suyas" on public.calificaciones
  for all using (
    grupo_materia_id in (
      select gm.id from public.grupo_materias gm
      join public.grupos g on g.id = gm.grupo_id
      where g.docente_id = auth.uid()
    )
  );


-- ── Historial planes ──
create policy "historial: lectura para docente y admin" on public.historial_planes
  for select using (
    plan_clase_id in (
      select pc.id from public.planes_clase pc
      join public.grupo_materias gm on gm.id = pc.grupo_materia_id
      join public.grupos g on g.id = gm.grupo_id
      where g.docente_id = auth.uid() or public.mi_rol() = 'admin'
    )
  );

create policy "historial: insert por sistema" on public.historial_planes
  for insert with check (actor_id = auth.uid());
