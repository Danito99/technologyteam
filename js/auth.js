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
  // getSession es más rápido: no hace llamada al servidor
  const { data: { session } } = await supabase.auth.getSession()

  if (!session) {
    const path = window.location.pathname
    if (!path.endsWith('index.html') && path !== '/') {
      window.location.href = '/index.html'
    }
    return null
  }

  const profile = await getProfile()

  if (!profile) {
    window.location.href = '/index.html'
    return null
  }

  // Solo redirigir si el rol no coincide Y no estamos ya en la página correcta
  if (rolRequerido && profile.rol !== rolRequerido) {
    const path = window.location.pathname
    if (profile.rol === 'docente' && !path.includes('/docente/')) {
      window.location.href = '/docente/inicio.html'
    } else if (profile.rol === 'admin' && !path.includes('/admin/')) {
      window.location.href = '/admin/inicio.html'
    }
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

// Escucha cambios de sesión
export function onAuthChange(callback) {
  supabase.auth.onAuthStateChange((_event, session) => {
    callback(session)
  })
}
