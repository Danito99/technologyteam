# TechAcademia

Plataforma de gestión académica para academia de Tecnología.  
Stack: HTML + CSS + JS vanilla · Supabase · Netlify

---

## Estructura del proyecto

```
techacademia/
├── index.html                  ← Login
├── docente/
│   ├── inicio.html
│   ├── materias.html           ← Registro de materias y grupos
│   ├── plan-analitico.html
│   ├── planes-clase.html       ← Historial de planes
│   ├── plan-editor.html        ← Editor de un plan de clase
│   ├── grupos.html             ← Lista de grupos
│   ├── grupo-detalle.html      ← Sesiones, alumnos, califs, historial
│   ├── calificaciones.html
│   └── reactivos.html
├── admin/
│   ├── inicio.html             ← Dashboard global
│   ├── docentes.html           ← Métricas por docente
│   ├── revision-planes.html    ← Aprobar / rechazar planes
│   ├── analytics.html          ← Panel de bandas de rendimiento
│   └── configuracion.html      ← Ciclo, periodos, metas
├── js/
│   ├── supabase.js             ← Cliente Supabase
│   ├── auth.js                 ← Login, logout, requireAuth
│   ├── sidebar-docente.js      ← Sidebar reutilizable
│   └── sidebar-admin.js        ← Sidebar admin reutilizable
├── css/
│   └── global.css
├── netlify/
│   └── functions/              ← Funciones server-side si se necesitan
├── supabase_schema.sql         ← Schema completo con RLS
└── README.md
```

---

## Setup inicial

### 1. Clonar y conectar a Netlify
```bash
git clone https://github.com/TU_USUARIO/techacademia.git
```
Conectar el repo en Netlify → Deploy automático en cada push a `main`.

### 2. Crear proyecto en Supabase
1. Ir a [supabase.com](https://supabase.com) → New project
2. Copiar `Project URL` y `anon public key`
3. Editar `js/supabase.js` con tus credenciales

### 3. Ejecutar el schema
En Supabase → SQL Editor → pegar y ejecutar `supabase_schema.sql`

### 4. Crear ciclo escolar y periodos
```sql
-- Ciclo
insert into public.ciclos_escolares (nombre, activo, fecha_inicio, fecha_fin)
values ('2025-2026', true, '2025-08-01', '2026-07-31');

-- Periodos trimestral (para Rosalba)
-- T1: P1, P2, P3 | T2: P1, P2, P3 | T3: P1, P2, P3
insert into public.periodos (ciclo_id, tipo, numero, parcial, etiqueta) values
  ('<ciclo_id>', 'trimestre', 1, 1, 'T1 · P1'),
  ('<ciclo_id>', 'trimestre', 1, 2, 'T1 · P2'),
  ('<ciclo_id>', 'trimestre', 1, 3, 'T1 · P3'),
  ('<ciclo_id>', 'trimestre', 2, 1, 'T2 · P1'),
  ('<ciclo_id>', 'trimestre', 2, 2, 'T2 · P2'),
  ('<ciclo_id>', 'trimestre', 2, 3, 'T2 · P3'),
  ('<ciclo_id>', 'trimestre', 3, 1, 'T3 · P1'),
  ('<ciclo_id>', 'trimestre', 3, 2, 'T3 · P2'),
  ('<ciclo_id>', 'trimestre', 3, 3, 'T3 · P3');

-- Periodos semestral (para Yerim)
insert into public.periodos (ciclo_id, tipo, numero, parcial, etiqueta) values
  ('<ciclo_id>', 'semestre', 1, 1, 'Sem A · P1'),
  ('<ciclo_id>', 'semestre', 1, 2, 'Sem A · P2'),
  ('<ciclo_id>', 'semestre', 1, 3, 'Sem A · P3'),
  ('<ciclo_id>', 'semestre', 2, 1, 'Sem B · P1'),
  ('<ciclo_id>', 'semestre', 2, 2, 'Sem B · P2'),
  ('<ciclo_id>', 'semestre', 2, 3, 'Sem B · P3');
```

### 5. Crear usuarios en Supabase Auth
En Supabase → Authentication → Users → Invite user  
Al crear, pasar metadata:
```json
{ "nombre": "Daniel", "rol": "admin" }
{ "nombre": "Rosalba", "rol": "docente" }
{ "nombre": "Yerim Seul Maya Retama", "rol": "docente" }
```

---

## Convenciones del código

- Cliente Supabase: `import { supabase } from '../js/supabase.js'`
- Auth guard en cada página protegida: `await requireAuth('docente')` o `requireAuth('admin')`
- CSS: variables en `--az`, `--vd`, `--am`, `--co` (azul, verde, ámbar, coral)
- Bandas: clases `.banda-gold`, `.banda-green2`, `.banda-green1`, `.banda-yellow`, `.banda-red2`, `.banda-red1`

---

## Páginas por construir (en orden)

- [x] `index.html` — Login
- [x] `docente/inicio.html` — Dashboard docente
- [ ] `docente/materias.html`
- [ ] `docente/plan-analitico.html`
- [ ] `docente/planes-clase.html` + `plan-editor.html`
- [ ] `docente/grupos.html` + `grupo-detalle.html`
- [ ] `docente/calificaciones.html`
- [ ] `admin/inicio.html`
- [ ] `admin/revision-planes.html`
- [ ] `admin/analytics.html`
- [ ] `admin/configuracion.html`
