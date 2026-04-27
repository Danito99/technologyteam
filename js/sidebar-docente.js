import { supabase } from './supabase.js'
import { logout }   from './auth.js'

export async function renderSidebar(paginaActiva) {
  const { data: { user } } = await supabase.auth.getUser()
  const { data: profile }  = await supabase
    .from('profiles').select('nombre').eq('id', user.id).single()

  const iniciales = (profile?.nombre || 'U')
    .split(' ').map(p => p[0]).slice(0, 2).join('').toUpperCase()

  const items = [
    { id:'inicio',         label:'Inicio',             href:'/docente/inicio.html',         icon:iconGrid() },
    { id:'materias',       label:'Materias y grupos',  href:'/docente/materias.html',        icon:iconSettings() },
    { id:'plan-analitico', label:'Plan analítico',     href:'/docente/plan-analitico.html',  icon:iconDoc() },
    { id:'planes-clase',   label:'Planes de clase',    href:'/docente/planes-clase.html',    icon:iconCalendar() },
    { id:'grupos',         label:'Mis grupos',         href:'/docente/grupos.html',          icon:iconPeople() },
    { id:'calificaciones', label:'Calificaciones',     href:'/docente/calificaciones.html',  icon:iconChart() },
    { id:'reactivos',      label:'Reactivos IA',       href:'/docente/reactivos.html',       icon:iconQuestion() },
  ]

  const sections = [
    { label:'Mi espacio',  ids:['inicio','materias'] },
    { label:'Planeación',  ids:['plan-analitico','planes-clase'] },
    { label:'Grupos',      ids:['grupos'] },
    { label:'Evaluación',  ids:['calificaciones','reactivos'] },
  ]

  let html = `
    <aside class="sidebar">
      <div class="sidebar-logo">
        <div class="brand">TechAcademia</div>
        <div class="role">Vista docente</div>
      </div>`

  for (const section of sections) {
    html += `<div class="nav-section">${section.label}</div>`
    for (const id of section.ids) {
      const item = items.find(i => i.id === id)
      const active = paginaActiva === id ? 'active' : ''
      html += `<a class="nav-item ${active}" href="${item.href}">${item.icon} ${item.label}</a>`
    }
  }

  html += `
      <div class="sidebar-user">
        <div class="avatar avatar-rosalba">${iniciales}</div>
        <div>
          <div style="font-size:12px;font-weight:500;">${profile?.nombre || 'Docente'}</div>
          <a href="#" id="btn-logout" style="font-size:11px;color:var(--text-3);">Cerrar sesión</a>
        </div>
      </div>
    </aside>`

  document.getElementById('sidebar-container').innerHTML = html
  document.getElementById('btn-logout')?.addEventListener('click', e => {
    e.preventDefault(); logout()
  })
}

const sv = `width="14" height="14" viewBox="0 0 16 16" fill="none"`
function iconGrid()     { return `<svg ${sv}><rect x="1" y="1" width="6" height="6" rx="1.5" fill="currentColor"/><rect x="9" y="1" width="6" height="6" rx="1.5" fill="currentColor"/><rect x="1" y="9" width="6" height="6" rx="1.5" fill="currentColor"/><rect x="9" y="9" width="6" height="6" rx="1.5" fill="currentColor"/></svg>` }
function iconSettings() { return `<svg ${sv}><circle cx="8" cy="8" r="2.5" stroke="currentColor" stroke-width="1.2" fill="none"/><path d="M8 1v2M8 13v2M1 8h2M13 8h2" stroke="currentColor" stroke-width="1.2" stroke-linecap="round"/></svg>` }
function iconDoc()      { return `<svg ${sv}><rect x="2" y="2" width="12" height="12" rx="2" stroke="currentColor" stroke-width="1.2" fill="none"/><path d="M5 6h6M5 9h4" stroke="currentColor" stroke-width="1.2" stroke-linecap="round"/></svg>` }
function iconCalendar() { return `<svg ${sv}><rect x="2" y="3" width="12" height="11" rx="1.5" stroke="currentColor" stroke-width="1.2" fill="none"/><path d="M5 1v4M11 1v4M2 7h12" stroke="currentColor" stroke-width="1.2" stroke-linecap="round"/></svg>` }
function iconPeople()   { return `<svg ${sv}><circle cx="5" cy="5" r="2.5" stroke="currentColor" stroke-width="1.2" fill="none"/><circle cx="11" cy="5" r="2.5" stroke="currentColor" stroke-width="1.2" fill="none"/><path d="M1 14c0-2.2 1.8-4 4-4s4 1.8 4 4" stroke="currentColor" stroke-width="1.2" fill="none"/><path d="M11 10c1.7.3 3 1.8 3 4" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" fill="none"/></svg>` }
function iconChart()    { return `<svg ${sv}><path d="M3 12L6 8l3 3 4-6" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/></svg>` }
function iconQuestion() { return `<svg ${sv}><circle cx="8" cy="8" r="6" stroke="currentColor" stroke-width="1.2" fill="none"/><path d="M6 6.5C6 5.4 6.9 4.5 8 4.5s2 .9 2 2c0 1-1 1.5-2 2v1" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" fill="none"/><circle cx="8" cy="12" r=".8" fill="currentColor"/></svg>` }
