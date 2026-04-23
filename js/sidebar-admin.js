import { supabase } from './supabase.js'
import { logout }   from './auth.js'

export async function renderSidebarAdmin(paginaActiva) {
  const { data: { user } } = await supabase.auth.getUser()
  const { data: profile }  = await supabase
    .from('profiles').select('nombre').eq('id', user.id).single()

  const iniciales = (profile?.nombre || 'A')
    .split(' ').map(p => p[0]).slice(0, 2).join('').toUpperCase()

  const items = [
    { id: 'inicio',          label: 'Resumen general',    href: '/admin/inicio.html',          icon: iconGrid() },
    { id: 'docentes',        label: 'Docentes',           href: '/admin/docentes.html',        icon: iconPeople() },
    { id: 'revision-planes', label: 'Revisión de planes', href: '/admin/revision-planes.html', icon: iconCheck(), badge: true },
    { id: 'analytics',       label: 'Analytics',          href: '/admin/analytics.html',       icon: iconChart() },
  ]

  const verComo = [
    { id: 'ver-rosalba', label: 'Rosalba',  href: '/docente/inicio.html', avatar: 'RB', cls: 'avatar-rosalba' },
    { id: 'ver-yerim',   label: 'Yerim',    href: '/docente/inicio.html', avatar: 'YS', cls: 'avatar-yerim'   },
  ]

  // Contar planes pendientes de revisión
  const { count } = await supabase
    .from('planes_clase')
    .select('id', { count: 'exact', head: true })
    .eq('estado', 'entregado')

  let html = `
    <aside class="sidebar">
      <div class="sidebar-logo">
        <div class="brand">TechAcademia</div>
        <div class="role">Administrador</div>
      </div>
      <div class="nav-section">Global</div>
  `

  items.forEach(item => {
    const active = paginaActiva === item.id ? 'active' : ''
    const badgeHtml = item.badge && count > 0
      ? `<span style="margin-left:auto;background:var(--co);color:white;font-size:9px;padding:1px 6px;border-radius:99px;font-weight:600;">${count}</span>`
      : ''
    html += `<a class="nav-item ${active}" href="${item.href}">${item.icon} ${item.label}${badgeHtml}</a>`
  })

  html += `<div class="nav-section">Ver como docente</div>`
  verComo.forEach(d => {
    html += `
      <a class="nav-item" href="${d.href}">
        <div class="avatar ${d.cls}" style="width:18px;height:18px;font-size:9px;">${d.avatar}</div>
        ${d.label}
      </a>`
  })

  html += `
      <div class="sidebar-user">
        <div class="avatar avatar-admin">${iniciales}</div>
        <div>
          <div style="font-size:12px;font-weight:500;">${profile?.nombre || 'Admin'}</div>
          <a href="#" id="btn-logout" style="font-size:11px;color:var(--text-3);">Cerrar sesión</a>
        </div>
      </div>
    </aside>
  `

  document.getElementById('sidebar-container').innerHTML = html
  document.getElementById('btn-logout')?.addEventListener('click', e => {
    e.preventDefault(); logout()
  })
}

const svgAttrs = `width="14" height="14" viewBox="0 0 16 16" fill="none"`
function iconGrid()   { return `<svg ${svgAttrs}><rect x="1" y="1" width="6" height="6" rx="1.5" fill="currentColor"/><rect x="9" y="1" width="6" height="6" rx="1.5" fill="currentColor"/><rect x="1" y="9" width="6" height="6" rx="1.5" fill="currentColor"/><rect x="9" y="9" width="6" height="6" rx="1.5" fill="currentColor"/></svg>` }
function iconPeople() { return `<svg ${svgAttrs}><circle cx="5" cy="5" r="2.5" stroke="currentColor" stroke-width="1.2" fill="none"/><circle cx="11" cy="5" r="2.5" stroke="currentColor" stroke-width="1.2" fill="none"/><path d="M1 14c0-2.2 1.8-4 4-4s4 1.8 4 4" stroke="currentColor" stroke-width="1.2" fill="none"/><path d="M11 10c1.7.3 3 1.8 3 4" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" fill="none"/></svg>` }
function iconCheck()  { return `<svg ${svgAttrs}><rect x="2" y="2" width="12" height="12" rx="2" stroke="currentColor" stroke-width="1.2" fill="none"/><path d="M5 8l2 2 4-4" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/></svg>` }
function iconChart()  { return `<svg ${svgAttrs}><path d="M3 12L6 8l3 3 4-6" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/></svg>` }
