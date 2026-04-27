import { supabase } from './supabase.js'
import { logout }   from './auth.js'

export async function renderSidebarAdmin(paginaActiva) {
  const { data: { user } } = await supabase.auth.getUser()
  const { data: profile }  = await supabase
    .from('profiles').select('nombre').eq('id', user.id).single()

  const iniciales = (profile?.nombre || 'A')
    .split(' ').map(p => p[0]).slice(0, 2).join('').toUpperCase()

  const { count } = await supabase
    .from('planes_clase').select('id', { count:'exact', head:true }).eq('estado','entregado')

  const items = [
    { id:'inicio',          label:'Resumen general',    href:'/admin/inicio.html' },
    { id:'docentes',        label:'Docentes',           href:'/admin/docentes.html' },
    { id:'revision-planes', label:'Revisión de planes', href:'/admin/revision-planes.html', badge: count > 0 ? count : null },
    { id:'analytics',       label:'Analytics',          href:'/admin/analytics.html' },
  ]

  const verComo = [
    { label:'Rosalba', href:'/docente/inicio.html' },
    { label:'Yerim',   href:'/docente/inicio.html' },
  ]

  let html = `
    <aside class="sidebar">
      <div class="sidebar-logo">
        <div class="brand">TechAcademia</div>
        <div class="role">Administrador</div>
      </div>
      <div class="nav-section">Global</div>`

  items.forEach(item => {
    const active = paginaActiva === item.id ? 'active' : ''
    const badge  = item.badge ? `<span style="margin-left:auto;background:var(--co);color:white;font-size:9px;padding:1px 6px;border-radius:99px;font-weight:600;">${item.badge}</span>` : ''
    html += `<a class="nav-item ${active}" href="${item.href}">${item.label}${badge}</a>`
  })

  html += `<div class="nav-section">Ver como docente</div>`
  verComo.forEach(d => {
    html += `<a class="nav-item" href="${d.href}">${d.label}</a>`
  })

  html += `
      <div class="sidebar-user">
        <div class="avatar avatar-admin">${iniciales}</div>
        <div>
          <div style="font-size:12px;font-weight:500;">${profile?.nombre || 'Admin'}</div>
          <a href="#" id="btn-logout" style="font-size:11px;color:var(--text-3);">Cerrar sesión</a>
        </div>
      </div>
    </aside>`

  document.getElementById('sidebar-container').innerHTML = html
  document.getElementById('btn-logout')?.addEventListener('click', e => {
    e.preventDefault(); logout()
  })
}
