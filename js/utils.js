// Shared business logic — imported by calificaciones, scoreboard, grupo-detalle, planes-clase

export const bandaDefs = [
  { key:'gold1',   label:'Gold',    cls:'bc-gold',   bandaCls:'banda-gold',   fill:'#DAA520', min:9.5, max:10   },
  { key:'green2',  label:'Green 2', cls:'bc-green2', bandaCls:'banda-green2', fill:'#1a6b1a', min:8.5, max:9.49 },
  { key:'green1',  label:'Green 1', cls:'bc-green1', bandaCls:'banda-green1', fill:'#2d7a2d', min:7.5, max:8.49 },
  { key:'yellow1', label:'Yellow',  cls:'bc-yellow', bandaCls:'banda-yellow', fill:'#EF9F27', min:6.5, max:7.49 },
  { key:'red2',    label:'Red 2',   cls:'bc-red2',   bandaCls:'banda-red2',   fill:'#D85A30', min:6.0, max:6.49 },
  { key:'red1',    label:'Red 1',   cls:'bc-red1',   bandaCls:'banda-red1',   fill:'#a32d2d', min:0,   max:5.99 },
]

// Weighted average: trabajo 30% · proyecto 25% · examen 40% · autoevaluación 5%
export function calcProm(c) {
  if (!c) return null
  if ([c.trabajo_clase, c.proyecto, c.examen, c.autoevaluacion].every(v => v == null)) return null
  return (c.trabajo_clase  ?? 0) * 0.30
       + (c.proyecto       ?? 0) * 0.25
       + (c.examen         ?? 0) * 0.40
       + (c.autoevaluacion ?? 0) * 0.05
}

// Pass metas from metas_rendimiento for DB-driven thresholds; omit to use built-in fallback.
export function calcBanda(prom, metas = []) {
  if (metas.length) {
    const m = metas.find(m => prom >= m.rango_min && prom <= m.rango_max)
    return m?.banda || 'red1'
  }
  return bandaDefs.find(d => prom >= d.min && prom <= d.max)?.key || 'red1'
}

// Shared toast — reuses existing #toast element if present, otherwise creates one.
let _toastEl = null
export function mostrarToast(msg, tipo = 'ok') {
  let el = document.getElementById('toast') || _toastEl
  if (!el) {
    el = _toastEl = document.createElement('div')
    el.style.cssText = [
      'position:fixed', 'bottom:20px', 'right:20px',
      'padding:10px 16px', 'border-radius:9px',
      'font-size:12px', 'font-weight:500', 'font-family:inherit',
      'z-index:9999', 'display:none',
      'box-shadow:0 4px 12px rgba(0,0,0,.18)', 'max-width:300px',
    ].join(';')
    document.body.appendChild(el)
  }
  const colors = { ok:'#3B6D11', success:'#3B6D11', error:'#993C1D', warning:'#BA7517', info:'#185FA5' }
  el.style.background = colors[tipo] ?? colors.ok
  el.style.color = 'white'
  el.textContent = msg
  el.style.display = 'block'
  clearTimeout(el._timer)
  el._timer = setTimeout(() => { el.style.display = 'none' }, 2800)
}
