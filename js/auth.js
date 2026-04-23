import { supabase } from './supabase.js'

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

export async function requireAuth(rolRequerido = null) {
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

  // Admin puede acceder a cualquier página sin restricción
  if (profile.rol === 'admin') return profile

  // Docente solo puede acceder a páginas de docente
  if (rolRequerido && profile.rol !== rolRequerido) {
    const path = window.location.pathname
    if (profile.rol === 'docente' && !path.includes('/docente/')) {
      window.location.href = '/docente/inicio.html'
    }
    return null
  }

  return profile
}

export async function login(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password })
  if (error) throw error
  return data
}

export async function logout() {
  await supabase.auth.signOut()
  window.location.href = '/index.html'
}

export function onAuthChange(callback) {
  supabase.auth.onAuthStateChange((_event, session) => {
    callback(session)
  })
}
