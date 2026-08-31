import { supabase }      from './supabase.js'
import { renderSidebar } from './sidebar-docente.js'

/**
 * Detecta el modo "ver como docente" (admin impersonando a un docente).
 * Siempre renderiza el sidebar docente (que ya propaga ?verComo en sus links)
 * y devuelve el perfil activo para usarlo en las queries de datos.
 *
 * @param {object} profile  - resultado de requireAuth()
 * @param {string} pagina   - id de la página activa para el sidebar docente
 * @returns {{ docenteActivo: object, verComoId: string|null }}
 */
export async function initDocenteActivo(profile, pagina) {
  const params    = new URLSearchParams(window.location.search)
  const verComoId = params.get('verComo')
  let docenteActivo = profile

  if (verComoId && profile.rol === 'admin') {
    const { data: docenteVer } = await supabase
      .from('profiles').select('id, nombre, rol').eq('id', verComoId).single()
    if (docenteVer) docenteActivo = docenteVer
  }

  // Siempre sidebar docente — sus links ya propagan ?verComo (sidebar-docente.js)
  await renderSidebar(pagina)

  return { docenteActivo, verComoId }
}

/**
 * Inyecta el badge "Viendo como [nombre]" en el primer .topbar-title del DOM.
 * No hace nada si no hay verComoId.
 */
export function mostrarBadgeVerComo(docenteActivo, verComoId) {
  if (!verComoId) return
  const el = document.querySelector('.topbar-title')
  if (!el) return
  el.innerHTML = el.textContent.trim() +
    ` <span style="background:var(--am-l);color:var(--am);padding:2px 8px;border-radius:12px;font-size:10px;margin-left:8px;">Viendo como ${docenteActivo.nombre}</span>`
}
