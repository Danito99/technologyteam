import { supabase } from './supabase.js'
import { logout }   from './auth.js'
import { logoSVG }  from './brand.js'

export async function renderSidebarAdmin(paginaActiva) {
  const { data: { user } } = await supabase.auth.getUser()
  const { data: profile }  = await supabase
    .from('profiles').select('nombre').eq('id', user.id).single()

  const iniciales = (profile?.nombre || 'A')
    .split(' ').map(p => p[0]).slice(0, 2).join('').toUpperCase()

  const { count } = await supabase
    .from('planes_clase').select('id', { count:'exact', head:true }).eq('estado','entregado')

  const { count: countIndicadores } = await supabase
    .from('indicadores_propuestos').select('id', { count:'exact', head:true }).eq('estado','pendiente')

  const items = [
    { id:'inicio',          label:'Resumen general',    href:'/admin/inicio.html' },
    { id:'docentes',        label:'Docentes',           href:'/admin/docentes.html' },
    { id:'revision-planes', label:'Revisión de planes', href:'/admin/revision-planes.html', badge: count > 0 ? count : null },
    { id:'indicadores',     label:'Indicadores propuestos', href:'/admin/indicadores.html', badge: countIndicadores > 0 ? countIndicadores : null },
    { id:'analytics',       label:'Analytics',          href:'/admin/analytics.html' },
  ]

  // Obtener docentes dinámicamente
  const { data: docentes } = await supabase
    .from('profiles')
    .select('id, nombre')
    .eq('rol', 'docente')
    .order('nombre')

  const verComo = docentes?.map(d => ({
    label: d.nombre,
    href: `/docente/inicio.html?verComo=${d.id}`,
    id: d.id
  })) || []

  let html = `
    <aside class="sidebar">
      <div class="sidebar-logo">
        <div class="brand-row">
          ${logoSVG(34)}
          <div>
            <div class="brand">Christel House</div>
            <div class="role">TechAcademia · Admin</div>
          </div>
        </div>
      </div>
      <div class="nav-section">Global</div>`

  items.forEach(item => {
    const active = paginaActiva === item.id ? 'active' : ''
    const badge  = item.badge ? `<span style="margin-left:auto;background:var(--co);color:white;font-size:9px;padding:1px 6px;border-radius:99px;font-weight:600;">${item.badge}</span>` : ''
    html += `<a class="nav-item ${active}" href="${item.href}">${item.label}${badge}</a>`
  })

  html += `<div class="nav-section">Ver como docente</div><div style="max-height:160px;overflow-y:auto;margin:0 4px;">`
  verComo.forEach(d => {
    html += `<a class="nav-item" href="${d.href}" style="padding:6px 12px;font-size:12px;">
      <span style="width:18px;height:18px;border-radius:50%;background:var(--ch-indigo-l);color:var(--ch-indigo);display:inline-flex;align-items:center;justify-content:center;font-size:9px;font-weight:700;flex-shrink:0;">${d.label[0]}</span>
      <span style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">${d.label}</span>
    </a>`
  })
  html += `</div>`

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
