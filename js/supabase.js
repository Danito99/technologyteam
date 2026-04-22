import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm'

const SUPABASE_URL = 'https://irfhuqvbkqqazpiswybm.supabase.co'
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlyZmh1cXZia3FxYXpwaXN3eWJtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY3OTc3NTksImV4cCI6MjA5MjM3Mzc1OX0.EiTN8hgYI-4rBJ47cPSVVFupRUVz2Af3y-jY3ti2lrs'

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
