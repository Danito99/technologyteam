import { supabase } from './supabase.js'

// Obtiene el perfil del usuario autenticado (incluye rol)
export async function getProfile() {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return null

  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .single()

  return profile
}

// Redirige según rol. Llámalo en cada página protegida.
export async function requireAuth(rolRequerido = null) {
  const profile = await getProfile()

  if (!profile) {
    window.location.href = '/index.html'
    return null
  }

  if (rolRequerido && profile.rol !== rolRequerido) {
    // Si es docente intentando entrar a /admin, lo manda a su dashboard
    if (profile.rol === 'docente') window.location.href = '/docente/inicio.html'
    if (profile.rol === 'admin') window.location.href = '/admin/inicio.html'
    return null
  }

  return profile
}

// Login con email y password
export async function login(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password })
  if (error) throw error
  return data
}

// Logout
export async function logout() {
  await supabase.auth.signOut()
  window.location.href = '/index.html'
}

// Escucha cambios de sesión (útil para el header)
export function onAuthChange(callback) {
  supabase.auth.onAuthStateChange((_event, session) => {
    callback(session)
  })
}
