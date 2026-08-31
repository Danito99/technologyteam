-- ── Tabla: indicadores_propuestos ─────────────────────────────────────────────
-- Los docentes proponen indicadores/objetivos custom cuando no encuentran
-- lo que necesitan en el catálogo. El admin los revisa y aprueba o rechaza.

create table if not exists public.indicadores_propuestos (
  id                uuid primary key default gen_random_uuid(),
  docente_id        uuid not null references public.profiles(id) on delete cascade,
  grupo_materia_id  uuid references public.grupo_materias(id) on delete set null,
  nivel             text,           -- 'primaria','secundaria','preparatoria'
  eje_articulador   text,
  contenido         text,
  bloom_nivel       text,           -- 'conocimiento','comprension', etc. (o null si es objetivo libre)
  texto             text not null,  -- el texto propuesto
  estado            text not null default 'pendiente'
                    check (estado in ('pendiente','aprobado','rechazado')),
  nota_admin        text,           -- feedback del admin al rechazar
  created_at        timestamptz default now()
);

-- RLS
alter table public.indicadores_propuestos enable row level security;

-- Docente: ve sus propias propuestas
create policy "indicadores_prop: docente ve los suyos"
  on public.indicadores_propuestos for select
  using (docente_id = auth.uid() or public.mi_rol() = 'admin');

-- Docente: puede insertar propuestas propias
create policy "indicadores_prop: docente inserta los suyos"
  on public.indicadores_propuestos for insert
  with check (docente_id = auth.uid());

-- Admin: puede actualizar estado y nota
create policy "indicadores_prop: admin actualiza"
  on public.indicadores_propuestos for update
  using (public.mi_rol() = 'admin');

-- Admin: puede borrar
create policy "indicadores_prop: admin borra"
  on public.indicadores_propuestos for delete
  using (public.mi_rol() = 'admin');
