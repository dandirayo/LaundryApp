import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Banknote, CheckCircle2, ClipboardList, Pencil, Plus, Search, ShieldCheck } from 'lucide-react'
import { supabase } from './supabaseClient'

type RecordRow = Record<string, any>
type Project = RecordRow & { id: string; title: string; customer_id: string; target_pieces: number; pricing_unit: 'KG' | 'PIECE'; unit_price: number; status: string; note: string }
type Batch = RecordRow & { id: string; project_id: string; pieces: number; weight_kg: number; note: string; processed_at: string }
type Payment = RecordRow & { id: string; project_id: string; amount: number; method: string; created_at: string }
type Incentive = RecordRow & { id: string; item_kind: string; quantity: number; rate: number; amount: number; employee_id: string; order_id: string; earned_at: string; paid_at: string | null; paid_method: string | null }
export type AuditEntry = { id: number; actor_role: string; action: string; entity_table: string; summary: string; old_data?: unknown; new_data?: unknown; created_at: string }

const money = (n: number) => new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(n)
const stamp = (v: string) => new Intl.DateTimeFormat('id-ID', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(v))

export function ProjectsPanel({ shopId, onCashChanged }: { shopId: string; onCashChanged: () => void }) {
  const onCashChangedRef = useRef(onCashChanged)
  onCashChangedRef.current = onCashChanged
  const [projects, setProjects] = useState<Project[]>([])
  const [batches, setBatches] = useState<Batch[]>([])
  const [payments, setPayments] = useState<Payment[]>([])
  const [customers, setCustomers] = useState<RecordRow[]>([])
  const [selected, setSelected] = useState<string | null>(null)
  const [editing, setEditing] = useState<Project | 'new' | null>(null)
  const [title, setTitle] = useState('')
  const [customerId, setCustomerId] = useState('')
  const [target, setTarget] = useState(2300)
  const [unit, setUnit] = useState<'KG' | 'PIECE'>('KG')
  const [rate, setRate] = useState(0)
  const [note, setNote] = useState('')
  const [status, setStatus] = useState('active')
  const [message, setMessage] = useState('')

  const reload = useCallback(async () => {
    const [p, b, pay, c] = await Promise.all([
      supabase.from('laundry_projects').select('*').eq('shop_id', shopId).order('created_at', { ascending: false }),
      supabase.from('laundry_project_batches').select('*').eq('shop_id', shopId).order('processed_at', { ascending: false }),
      supabase.from('laundry_project_payments').select('*').eq('shop_id', shopId).order('created_at', { ascending: false }),
      supabase.from('customers').select('id,name').eq('shop_id', shopId).is('deleted_at', null).order('name'),
    ])
    const failed = [p.error, b.error, pay.error, c.error].find(Boolean)
    if (failed) { setMessage(failed.message); return }
    setProjects((p.data ?? []) as Project[])
    setBatches((b.data ?? []) as Batch[])
    setPayments((pay.data ?? []) as Payment[])
    setCustomers(c.data ?? [])
    setCustomerId((value) => value || c.data?.[0]?.id || '')
    setMessage('')
  }, [shopId])

  useEffect(() => {
    void reload()
    const channel = supabase.channel(`owner-projects:${shopId}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'laundry_projects', filter: `shop_id=eq.${shopId}` }, () => void reload())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'laundry_project_batches', filter: `shop_id=eq.${shopId}` }, () => void reload())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'laundry_project_payments', filter: `shop_id=eq.${shopId}` }, () => { void reload(); onCashChangedRef.current() })
      .subscribe()
    return () => { void supabase.removeChannel(channel) }
  }, [shopId, reload])

  function openEditor(project?: Project) {
    setEditing(project ?? 'new')
    setTitle(project?.title ?? '')
    setCustomerId(project?.customer_id ?? customers[0]?.id ?? '')
    setTarget(project?.target_pieces ?? 2300)
    setUnit(project?.pricing_unit ?? 'KG')
    setRate(project?.unit_price ?? 0)
    setNote(project?.note ?? '')
    setStatus(project?.status ?? 'active')
  }

  async function saveProject(event: React.FormEvent) {
    event.preventDefault()
    if (!title.trim() || !customerId || target <= 0 || rate < 0) { setMessage('Lengkapi nama, pelanggan, target, dan harga.'); return }
    const values = { title: title.trim(), target_pieces: target, pricing_unit: unit, unit_price: rate, note: note.trim(), status, updated_at: new Date().toISOString() }
    const result = editing === 'new'
      ? await supabase.from('laundry_projects').insert({ ...values, shop_id: shopId, customer_id: customerId })
      : await supabase.from('laundry_projects').update(values).eq('id', (editing as Project).id).eq('shop_id', shopId).select('id').single()
    if (result.error) { setMessage(result.error.message); return }
    setEditing(null); await reload()
  }

  async function saveBatch(project: Project, existing?: Batch) {
    const pieces = Number(window.prompt('Jumlah pcs pada batch ini', String(existing?.pieces ?? '')))
    if (!Number.isInteger(pieces) || pieces <= 0) return
    const kg = Number(window.prompt('Berat aktual (kg)', String(existing?.weight_kg ?? ''))?.replace(',', '.'))
    if (!Number.isFinite(kg) || kg <= 0) { setMessage('Berat kg harus lebih dari nol.'); return }
    const nextNote = window.prompt('Catatan batch', existing?.note ?? '')
    if (nextNote === null) return
    const values = { pieces, weight_kg: kg, note: nextNote.trim() }
    const result = existing
      ? await supabase.from('laundry_project_batches').update(values).eq('id', existing.id).eq('shop_id', shopId).select('id').single()
      : await supabase.from('laundry_project_batches').insert({ ...values, shop_id: shopId, project_id: project.id }).select('id').single()
    if (result.error) setMessage(result.error.message); else await reload()
  }

  async function savePayment(project: Project, existing?: Payment) {
    const amount = Number(window.prompt('Nominal pembayaran yang diterima', String(existing?.amount ?? '')))
    if (!Number.isInteger(amount) || amount <= 0) return
    const method = window.prompt('Metode: Tunai, Transfer, atau QRIS', existing?.method ?? 'Tunai')
    if (!method?.trim()) return
    const values = { amount, method: method.trim() }
    const result = existing
      ? await supabase.from('laundry_project_payments').update(values).eq('id', existing.id).eq('shop_id', shopId).select('id').single()
      : await supabase.from('laundry_project_payments').insert({ ...values, shop_id: shopId, project_id: project.id }).select('id').single()
    if (result.error) setMessage(result.error.message)
    else { await reload(); onCashChanged() }
  }

  return <section className="section-grid">
    <article className="wide-panel"><div className="panel-header"><div><h2>Proyek Laundry</h2><p>Target pcs, batch harian, dan tagihan berjalan per kg atau per pcs.</p></div><button className="primary-button" onClick={() => openEditor()} type="button"><Plus size={16} />Buat Proyek</button></div>
      {message ? <p className="notice">{message}</p> : null}
      {projects.length === 0 ? <div className="empty-state">Belum ada proyek. Buat proyek untuk pekerjaan jumlah besar.</div> : null}
      <div className="project-list">{projects.map((project) => {
        const rows = batches.filter((b) => b.project_id === project.id)
        const moneyRows = payments.filter((p) => p.project_id === project.id)
        const pieces = rows.reduce((sum, b) => sum + Number(b.pieces), 0)
        const kg = rows.reduce((sum, b) => sum + Number(b.weight_kg), 0)
        const subtotal = Math.round((project.pricing_unit === 'KG' ? kg : pieces) * project.unit_price)
        const billed = subtotal === 0 ? 0 : Math.ceil(subtotal / 1000) * 1000
        const paid = moneyRows.reduce((sum, p) => sum + Number(p.amount), 0)
        return <article className="project-card" key={project.id}>
          <div className="project-card-head"><div><h3>{project.title}</h3><p>{customers.find((c) => c.id === project.customer_id)?.name ?? 'Pelanggan'} · {project.status}</p></div><button className="ghost-button" type="button" onClick={() => setSelected(selected === project.id ? null : project.id)}>{selected === project.id ? 'Tutup' : 'Lihat detail'}</button></div>
          <div className="project-stats"><span><strong>{pieces}/{project.target_pieces}</strong> pcs</span><span><strong>{kg.toFixed(2)}</strong> kg</span><span><strong>{money(billed)}</strong> tagihan</span><span><strong>{money(Math.max(0, billed - paid))}</strong> sisa</span></div>
          <div className="project-progress"><i style={{ width: `${Math.min(100, pieces / project.target_pieces * 100)}%` }} /></div>
          {selected === project.id ? <div className="project-details"><p>Tarif {money(project.unit_price)} / {project.pricing_unit === 'KG' ? 'kg' : 'pcs'} · Dibayar {money(paid)}</p><div className="row-meta"><button className="ghost-button" type="button" onClick={() => openEditor(project)}><Pencil size={14} />Edit proyek</button><button className="ghost-button" type="button" onClick={() => void saveBatch(project)}><Plus size={14} />Catat batch</button><button className="ghost-button" type="button" onClick={() => void savePayment(project)}><Banknote size={14} />Terima pembayaran</button></div><div className="project-sublist"><strong>Batch harian</strong>{rows.map((b) => <button key={b.id} type="button" onClick={() => void saveBatch(project, b)}>{b.pieces} pcs · {Number(b.weight_kg).toFixed(2)} kg · {stamp(b.processed_at)} <Pencil size={13} /></button>)}{!rows.length ? <small>Belum ada batch.</small> : null}<strong>Pembayaran</strong>{moneyRows.map((p) => <button key={p.id} type="button" onClick={() => void savePayment(project, p)}>{money(p.amount)} · {p.method} · {stamp(p.created_at)} <Pencil size={13} /></button>)}{!moneyRows.length ? <small>Belum ada pembayaran.</small> : null}</div></div> : null}
        </article>
      })}</div>
    </article>
    {editing ? <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) setEditing(null) }}><section className="modal" role="dialog" aria-modal="true" aria-label="Edit proyek"><header><h2>{editing === 'new' ? 'Proyek baru' : 'Edit proyek'}</h2></header><form className="editor-form" onSubmit={(event) => void saveProject(event)}><label>Nama proyek<input value={title} onChange={(event) => setTitle(event.target.value)} required /></label><label>Pelanggan<select value={customerId} onChange={(event) => setCustomerId(event.target.value)} disabled={editing !== 'new'} required>{customers.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select></label><div className="form-grid"><label>Target pcs<input type="number" min="1" value={target} onChange={(event) => setTarget(Number(event.target.value))} required /></label><label>Dasar harga<select value={unit} onChange={(event) => setUnit(event.target.value as 'KG' | 'PIECE')}><option value="KG">Per kg</option><option value="PIECE">Per pcs</option></select></label></div><label>Tarif per satuan (Rp)<input type="number" min="0" value={rate} onChange={(event) => setRate(Number(event.target.value))} required /></label><label>Catatan<textarea value={note} onChange={(event) => setNote(event.target.value)} /></label>{editing !== 'new' ? <label>Status<select value={status} onChange={(event) => setStatus(event.target.value)}><option value="active">Aktif</option><option value="completed">Selesai</option><option value="cancelled">Dibatalkan</option></select></label> : null}<div className="form-actions"><button className="primary-button" type="submit">Simpan</button><button className="ghost-button" type="button" onClick={() => setEditing(null)}>Batal</button></div></form></section></div> : null}
  </section>
}

export function OrderKiloServiceEditor({ shopId, orders, onChanged }: { shopId: string; orders: RecordRow[]; onChanged: () => void }) {
  const [orderId, setOrderId] = useState('')
  const [items, setItems] = useState<RecordRow[]>([])
  const [services, setServices] = useState<RecordRow[]>([])
  const [draft, setDraft] = useState<Record<string, string>>({})
  const [message, setMessage] = useState('')
  const loadItems = useCallback(async (id: string) => {
    if (!id) { setItems([]); return }
    const { data, error } = await supabase.from('order_items')
      .select('id,service_id,service_name_snapshot,unit,quantity,unit_price')
      .eq('shop_id', shopId).eq('order_id', id)
    if (error) { setMessage(error.message); return }
    setItems((data ?? []).filter((row) => String(row.unit).toUpperCase() === 'KG'))
    setDraft({})
  }, [shopId])
  useEffect(() => { void loadItems(orderId) }, [orderId, loadItems])
  useEffect(() => {
    if (shopId === 'demo-shop') return
    void supabase.from('services').select('id,item_name,category_name,size_variant,material_variant,price,unit,is_active')
      .eq('shop_id', shopId).eq('unit', 'KG').eq('is_active', true).order('price')
      .then(({ data, error }) => { if (error) setMessage(error.message); else setServices(data ?? []) })
  }, [shopId])
  async function save(item: RecordRow) {
    const serviceId = draft[item.id]
    if (!serviceId || serviceId === item.service_id) return
    const { error } = await supabase.rpc('update_order_kilo_services', {
      p_order_id: orderId, p_replacements: [{ item_id: item.id, service_id: serviceId }],
    })
    if (error) setMessage(error.message)
    else { setMessage('Layanan diperbarui. Total nota dan sisa tagihan telah dihitung ulang.'); await loadItems(orderId); onChanged() }
  }
  return <article className="wide-panel"><div className="panel-header"><div><h2>Edit layanan kiloan pada nota</h2><p>Ganti Reguler, Express, atau Kilat tanpa mengubah item satuan. Harga nota dihitung ulang oleh server.</p></div></div><div className="editor-form"><label>Pesanan<select value={orderId} onChange={(event) => setOrderId(event.target.value)}><option value="">Pilih nota</option>{orders.map((order) => <option key={order.id} value={order.id}>{order.order_number} · {order.customer_name_snapshot}</option>)}</select></label></div>{message ? <p className="notice">{message}</p> : null}<div className="table-list">{items.map((item) => <div className="table-row" key={item.id}><div><strong>{item.service_name_snapshot}</strong><span>{item.quantity} kg × {money(item.unit_price)}</span></div><div className="row-meta"><select value={draft[item.id] ?? item.service_id ?? ''} aria-label={`Ganti layanan ${item.service_name_snapshot}`} onChange={(event) => setDraft((current) => ({ ...current, [item.id]: event.target.value }))}>{!item.service_id ? <option value="">Pilih layanan</option> : null}{services.map((service) => <option key={service.id} value={service.id}>{service.item_name} · {service.category_name} · {money(service.price)}/kg</option>)}</select><button className="primary-button" type="button" disabled={!draft[item.id] || draft[item.id] === item.service_id} onClick={() => void save(item)}>Simpan</button></div></div>)}{orderId && !items.length ? <div className="empty-state">Nota ini tidak memiliki layanan kiloan.</div> : null}</div></article>
}

export function OrderPaymentCorrections({ shopId, orders, onChanged }: { shopId: string; orders: RecordRow[]; onChanged: () => void }) {
  const [orderId, setOrderId] = useState('')
  const [payments, setPayments] = useState<RecordRow[]>([])
  const [editing, setEditing] = useState<RecordRow | null>(null)
  const [amount, setAmount] = useState(0)
  const [method, setMethod] = useState('Tunai')
  const [paidAt, setPaidAt] = useState('')
  const [message, setMessage] = useState('')
  const reload = useCallback(async (id: string) => {
    if (!id) { setPayments([]); return }
    const { data, error } = await supabase.from('payments').select('id,order_id,amount,method,created_at')
      .eq('shop_id', shopId).eq('order_id', id).order('created_at', { ascending: false })
    if (error) setMessage(error.message)
    else { setPayments(data ?? []); setMessage('') }
  }, [shopId])
  useEffect(() => { void reload(orderId) }, [orderId, reload])
  function open(row: RecordRow) {
    setEditing(row); setAmount(Number(row.amount)); setMethod(String(row.method))
    const date = new Date(row.created_at)
    setPaidAt(`${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}T${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`)
  }
  async function save(event: React.FormEvent) {
    event.preventDefault()
    if (!editing || !Number.isInteger(amount) || amount <= 0 || !method.trim() || !paidAt) return
    const { error } = await supabase.rpc('owner_correct_order_payment', {
      p_payment_id: editing.id, p_amount: amount, p_method: method.trim(), p_paid_at: new Date(paidAt).toISOString(),
    })
    if (error) { setMessage(error.message); return }
    setEditing(null); await reload(orderId); onChanged()
  }
  return <article className="wide-panel"><div className="panel-header"><div><h2>Koreksi pembayaran pesanan</h2><p>Owner dapat mengubah nominal, metode, dan waktu. Sisa tagihan serta Buku Kas ikut diperbarui.</p></div></div><div className="editor-form"><label>Pilih nota<select value={orderId} onChange={(event) => setOrderId(event.target.value)}><option value="">Pilih pesanan</option>{orders.map((order) => <option key={order.id} value={order.id}>{order.order_number} · {order.customer_name_snapshot}</option>)}</select></label></div>{message ? <p className="notice">{message}</p> : null}<div className="table-list">{payments.map((payment) => <div className="table-row" key={payment.id}><div><strong>{money(payment.amount)} · {payment.method}</strong><span>{stamp(payment.created_at)}</span></div><button className="ghost-button" type="button" onClick={() => open(payment)}><Pencil size={14} />Edit</button></div>)}{orderId && !payments.length ? <div className="empty-state">Belum ada pembayaran pada nota ini.</div> : null}</div>{editing ? <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) setEditing(null) }}><section className="modal" role="dialog" aria-modal="true" aria-label="Koreksi pembayaran"><header><h2>Koreksi pembayaran</h2></header><form className="editor-form" onSubmit={(event) => void save(event)}><label>Nominal (Rp)<input type="number" min="1" value={amount} onChange={(event) => setAmount(Number(event.target.value))} required /></label><label>Metode<select value={method} onChange={(event) => setMethod(event.target.value)}><option value="Tunai">Tunai</option><option value="Transfer">Transfer</option><option value="QRIS">QRIS</option></select></label><label>Waktu pembayaran<input type="datetime-local" value={paidAt} onChange={(event) => setPaidAt(event.target.value)} required /></label><div className="form-actions"><button className="primary-button" type="submit">Simpan koreksi</button><button className="ghost-button" type="button" onClick={() => setEditing(null)}>Batal</button></div></form></section></div> : null}</article>
}

function OrderIncentiveConfig({ shopId, orders, employees }: { shopId: string; orders: RecordRow[]; employees: RecordRow[] }) {
  const eligibleOrders = orders.filter((row) => ['received', 'processing'].includes(String(row.order_status)))
  const [orderId, setOrderId] = useState('')
  const [items, setItems] = useState<RecordRow[]>([])
  const [message, setMessage] = useState('')
  const load = useCallback(async (id: string) => {
    if (!id) { setItems([]); return }
    const { data, error } = await supabase.from('order_items')
      .select('id,order_id,service_name_snapshot,unit,quantity,incentive_rate,incentive_employee_id')
      .eq('shop_id', shopId).eq('order_id', id)
    if (error) { setMessage(error.message); return }
    setItems((data ?? []).filter((row) => /(^|[^a-z0-9])(sepatu|helm|tas)([^a-z0-9]|$)/i.test(String(row.service_name_snapshot))))
    setMessage('')
  }, [shopId])
  useEffect(() => { void load(orderId) }, [orderId, load])
  async function save(item: RecordRow) {
    const { error } = await supabase.rpc('configure_order_item_incentives', {
      p_order_id: orderId,
      p_choices: [{ order_item_id: item.id, rate: Number(item.incentive_rate), employee_id: item.incentive_employee_id || null }],
    })
    if (error) setMessage(error.message)
    else { setMessage('Pilihan insentif tersimpan. Hak karyawan muncul saat pesanan siap.'); await load(orderId) }
  }
  return <article className="wide-panel"><div className="panel-header"><div><h2>Atur insentif sebelum selesai</h2><p>Owner dapat mengoreksi nominal dan penerima pada item sepatu, helm, atau tas.</p></div></div><div className="editor-form"><label>Pilih pesanan aktif<select value={orderId} onChange={(event) => setOrderId(event.target.value)}><option value="">Pilih nota</option>{eligibleOrders.map((row) => <option key={row.id} value={row.id}>{row.order_number} · {row.customer_name_snapshot}</option>)}</select></label></div>{message ? <p className="notice">{message}</p> : null}<div className="table-list">{items.map((item) => <div className="table-row" key={item.id}><div><strong>{item.service_name_snapshot}</strong><span>{item.quantity} {item.unit}</span></div><div className="row-meta"><select aria-label={`Nominal insentif ${item.service_name_snapshot}`} value={item.incentive_rate ?? 0} onChange={(event) => setItems((rows) => rows.map((row) => row.id === item.id ? { ...row, incentive_rate: Number(event.target.value) } : row))}><option value={0}>Tanpa insentif</option><option value={10000}>Rp10.000</option><option value={15000}>Rp15.000</option><option value={20000}>Rp20.000</option></select><select aria-label={`Penerima insentif ${item.service_name_snapshot}`} value={item.incentive_employee_id ?? ''} onChange={(event) => setItems((rows) => rows.map((row) => row.id === item.id ? { ...row, incentive_employee_id: event.target.value || null } : row))}><option value="">Pilih karyawan</option>{employees.filter((employee) => employee.is_active !== false).map((employee) => <option value={employee.id} key={employee.id}>{employee.name}</option>)}</select><button className="primary-button" type="button" onClick={() => void save(item)}>Simpan</button></div></div>)}{orderId && !items.length ? <div className="empty-state">Nota ini tidak memiliki item sepatu, helm, atau tas.</div> : null}</div></article>
}

export function IncentivesPanel({ shopId, employees, orders, onCashChanged }: { shopId: string; employees: RecordRow[]; orders: RecordRow[]; onCashChanged: () => void }) {
  const [rows, setRows] = useState<Incentive[]>([])
  const [message, setMessage] = useState('')
  const reload = useCallback(async () => {
    const { data, error } = await supabase.from('order_item_incentives').select('*').eq('shop_id', shopId).order('earned_at', { ascending: false }).limit(500)
    if (error) setMessage(error.message); else { setRows((data ?? []) as Incentive[]); setMessage('') }
  }, [shopId])
  useEffect(() => {
    void reload()
    const channel = supabase.channel(`owner-incentives:${shopId}`).on('postgres_changes', { event: '*', schema: 'public', table: 'order_item_incentives', filter: `shop_id=eq.${shopId}` }, () => void reload()).subscribe()
    return () => { void supabase.removeChannel(channel) }
  }, [shopId, reload])
  const pending = rows.filter((row) => !row.paid_at)
  async function pay(row: Incentive) {
    const method = window.prompt(`Bayar insentif ${money(row.amount)} lewat Tunai atau Transfer?`, 'Tunai')
    if (!method?.trim()) return
    const { error } = await supabase.rpc('pay_order_item_incentive', { p_incentive_id: row.id, p_method: method.trim() })
    if (error) setMessage(error.message); else { await reload(); onCashChanged() }
  }
  return <section className="section-grid"><OrderIncentiveConfig shopId={shopId} orders={orders} employees={employees} /><div className="metrics-grid"><article className="metric-card"><ClipboardList size={20} /><strong>{pending.length}</strong><span>Belum dibayar</span></article><article className="metric-card"><Banknote size={20} /><strong>{money(pending.reduce((sum, row) => sum + row.amount, 0))}</strong><span>Hak karyawan</span></article><article className="metric-card"><CheckCircle2 size={20} /><strong>{money(rows.filter((row) => row.paid_at).reduce((sum, row) => sum + row.amount, 0))}</strong><span>Sudah dibayar</span></article></div><article className="wide-panel"><div className="panel-header"><div><h2>Insentif Sepatu, Helm & Tas</h2><p>Muncul saat pesanan siap. Buku Kas mencatat pengeluaran saat owner membayar.</p></div><button className="ghost-button" type="button" onClick={() => void reload()}>Perbarui</button></div>{message ? <p className="notice">{message}</p> : null}<div className="table-list">{rows.map((row) => <div className="table-row" key={row.id}><div><strong>{row.item_kind} · {row.quantity} × {money(row.rate)}</strong><span>{employees.find((e) => e.id === row.employee_id)?.name ?? 'Karyawan'} · {orders.find((o) => o.id === row.order_id)?.order_number ?? 'Nota'} · {stamp(row.earned_at)}</span></div><div className="row-meta"><strong>{money(row.amount)}</strong>{row.paid_at ? <span className="status paid">Dibayar {row.paid_method}</span> : <button className="primary-button" type="button" onClick={() => void pay(row)}>Bayar</button>}</div></div>)}{!rows.length ? <div className="empty-state">Belum ada insentif yang diperoleh.</div> : null}</div></article></section>
}

export function AuditPanel({ logs }: { logs: AuditEntry[] }) {
  const [search, setSearch] = useState('')
  const [table, setTable] = useState('all')
  const [expanded, setExpanded] = useState<number | null>(null)
  const tables = useMemo(() => [...new Set(logs.map((log) => log.entity_table))].sort(), [logs])
  const filtered = logs.filter((log) => (table === 'all' || log.entity_table === table) && `${log.summary} ${log.action} ${log.entity_table} ${log.actor_role}`.toLowerCase().includes(search.toLowerCase()))
  return <section className="section-grid"><div className="audit-summary"><div><ShieldCheck size={23} /><strong>{logs.length}</strong><span>Aktivitas terbaru</span></div><div><Pencil size={23} /><strong>{tables.length}</strong><span>Jenis data</span></div><div><CheckCircle2 size={23} /><strong>{logs.filter((l) => l.actor_role === 'OWNER').length}</strong><span>Oleh Owner</span></div></div><article className="wide-panel"><div className="panel-header"><div><h2>Jejak Aktivitas</h2><p>Catatan perubahan tetap utuh untuk memeriksa siapa mengubah apa dan kapan.</p></div></div><div className="audit-filters"><label><Search size={17} /><input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Cari aktivitas..." /></label><select value={table} onChange={(event) => setTable(event.target.value)} aria-label="Filter jenis data"><option value="all">Semua data</option>{tables.map((value) => <option value={value} key={value}>{value}</option>)}</select></div><div className="audit-timeline">{filtered.map((log) => <article className="audit-event" key={log.id}><div className="audit-event-mark"><span /></div><div className="audit-event-body"><div className="audit-event-top"><span className="audit-entity">{log.entity_table}</span><time>{stamp(log.created_at)}</time></div><h3>{log.summary || `${log.action} ${log.entity_table}`}</h3><p><strong>{log.actor_role || 'SYSTEM'}</strong> · {log.action}</p>{(log.old_data || log.new_data) ? <button className="audit-details-button" type="button" onClick={() => setExpanded(expanded === log.id ? null : log.id)}>{expanded === log.id ? 'Sembunyikan perubahan' : 'Lihat perubahan'}</button> : null}{expanded === log.id ? <div className="audit-comparison"><div><strong>Sebelum</strong><pre>{JSON.stringify(log.old_data ?? {}, null, 2)}</pre></div><div><strong>Sesudah</strong><pre>{JSON.stringify(log.new_data ?? {}, null, 2)}</pre></div></div> : null}</div></article>)}{!filtered.length ? <div className="empty-state">Tidak ada aktivitas sesuai filter.</div> : null}</div></article></section>
}

type Service = { id: string; category_name: string; item_name: string; size_variant: string; material_variant: string; unit: string; price: number; estimated_hours: number; is_express: boolean; is_active: boolean }
export function ServicesPanel({ shopId }: { shopId: string }) {
  const [rows, setRows] = useState<Service[]>([])
  const [editing, setEditing] = useState<Service | 'new' | null>(null)
  const [values, setValues] = useState<Omit<Service, 'id'>>({ category_name: 'Satuan', item_name: '', size_variant: '', material_variant: '', unit: 'PCS', price: 0, estimated_hours: 72, is_express: false, is_active: true })
  const [message, setMessage] = useState('')
  const reload = useCallback(async () => {
    const { data, error } = await supabase.from('services').select('id,category_name,item_name,size_variant,material_variant,unit,price,estimated_hours,is_express,is_active').eq('shop_id', shopId).order('category_name').order('item_name')
    if (error) setMessage(error.message); else { setRows((data ?? []) as Service[]); setMessage('') }
  }, [shopId])
  useEffect(() => { void reload() }, [reload])
  function open(row?: Service) {
    setEditing(row ?? 'new')
    setValues(row ? { category_name: row.category_name, item_name: row.item_name, size_variant: row.size_variant, material_variant: row.material_variant, unit: row.unit, price: row.price, estimated_hours: row.estimated_hours, is_express: row.is_express, is_active: row.is_active } : { category_name: 'Satuan', item_name: '', size_variant: '', material_variant: '', unit: 'PCS', price: 0, estimated_hours: 72, is_express: false, is_active: true })
  }
  async function save(event: React.FormEvent) {
    event.preventDefault()
    const result = editing === 'new'
      ? await supabase.from('services').insert({ ...values, shop_id: shopId }).select('id').single()
      : await supabase.from('services').update(values).eq('id', (editing as Service).id).eq('shop_id', shopId).select('id').single()
    if (result.error) setMessage(result.error.message); else { setEditing(null); await reload() }
  }
  return <section className="wide-panel"><div className="panel-header"><div><h2>Layanan & Harga</h2><p>Edit katalog yang dipakai bersama oleh aplikasi Flutter dan web.</p></div><button className="primary-button" type="button" onClick={() => open()}><Plus size={16} />Tambah Layanan</button></div>{message ? <p className="notice">{message}</p> : null}<div className="table-list">{rows.map((row) => <div className="table-row" key={row.id}><div><strong>{row.item_name}{row.size_variant ? ` · ${row.size_variant}` : ''}</strong><span>{row.category_name} · {row.unit} · {row.is_active ? 'Aktif' : 'Nonaktif'}</span></div><div className="row-meta"><strong>{money(row.price)}</strong><button className="icon-button" type="button" title="Edit layanan" onClick={() => open(row)}><Pencil size={16} /></button></div></div>)}{!rows.length ? <div className="empty-state">Belum ada layanan.</div> : null}</div>{editing ? <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) setEditing(null) }}><section className="modal" role="dialog" aria-modal="true" aria-label="Edit layanan"><header><h2>{editing === 'new' ? 'Tambah layanan' : 'Edit layanan'}</h2></header><form className="editor-form" onSubmit={(event) => void save(event)}><label>Nama layanan<input value={values.item_name} onChange={(event) => setValues({ ...values, item_name: event.target.value })} required /></label><div className="form-grid"><label>Kategori<input value={values.category_name} onChange={(event) => setValues({ ...values, category_name: event.target.value })} required /></label><label>Satuan<select value={values.unit} onChange={(event) => setValues({ ...values, unit: event.target.value })}><option value="KG">KG</option><option value="PCS">PCS</option><option value="PAIR">PAIR</option><option value="SET">SET</option><option value="M">M</option></select></label></div><div className="form-grid"><label>Ukuran<input value={values.size_variant} onChange={(event) => setValues({ ...values, size_variant: event.target.value })} /></label><label>Material<input value={values.material_variant} onChange={(event) => setValues({ ...values, material_variant: event.target.value })} /></label></div><div className="form-grid"><label>Harga (Rp)<input type="number" min="0" value={values.price} onChange={(event) => setValues({ ...values, price: Number(event.target.value) })} required /></label><label>Estimasi (jam)<input type="number" min="0" value={values.estimated_hours} onChange={(event) => setValues({ ...values, estimated_hours: Number(event.target.value) })} /></label></div><label className="toggle-row"><input type="checkbox" checked={values.is_express} onChange={(event) => setValues({ ...values, is_express: event.target.checked })} />Express / Kilat</label><label className="toggle-row"><input type="checkbox" checked={values.is_active} onChange={(event) => setValues({ ...values, is_active: event.target.checked })} />Aktif</label><div className="form-actions"><button className="primary-button" type="submit">Simpan</button><button className="ghost-button" type="button" onClick={() => setEditing(null)}>Batal</button></div></form></section></div> : null}</section>
}
