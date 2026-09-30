import { useEffect, useMemo, useState } from 'react'
import type { FormEvent, ReactNode } from 'react'
import {
  AlertTriangle,
  BarChart3,
  Banknote,
  CheckCircle2,
  ClipboardCheck,
  Contact,
  LayoutDashboard,
  LogIn,
  LogOut,
  Menu,
  PackageCheck,
  Pencil,
  Plus,
  ReceiptText,
  RefreshCw,
  Search,
  Settings,
  ShieldCheck,
  Signal,
  Users,
  WifiOff,
  X,
  XCircle,
} from 'lucide-react'
import { supabase, supabaseEnabled } from './supabaseClient'
import './App.css'

type Profile = {
  id: string
  shop_id: string
  employee_id: string | null
  full_name: string
  role: 'OWNER' | 'EMPLOYEE'
  is_active: boolean
}

type Employee = {
  id: string
  name: string
  phone: string
  position: string
  is_active: boolean
  shift_start: string
  shift_end: string
  late_tolerance_minutes: number
}

type EmployeeRequest = {
  id: string
  employee_name: string
  type: string
  reason: string
  amount: number
  status: string
  created_at: string
  review_note: string
}

type Order = {
  id: string
  order_number: string
  customer_name_snapshot: string
  order_status: string
  payment_status: string
  total_price: number
  paid_amount: number
  created_at: string
  updated_at: string
}

type CashTransaction = {
  id: string
  type: 'IN' | 'OUT'
  category: string
  description: string
  amount: number
  created_at: string
}

type Customer = { id: string; name: string; phone: string; address: string; created_at: string }

type InventoryItem = {
  id: string
  name: string
  stock: number
  unit: string
  min_stock: number
  purchase_price: number
  note: string
  is_active: boolean
}

type WeeklyShift = {
  id: string
  employee_id: string
  employee_name: string
  day_of_week: number
  start_time: string
  end_time: string
  is_day_off: boolean
}

type InventoryMovement = {
  id: string
  item_id: string
  item_name: string
  type: 'IN' | 'OUT' | 'ADJUSTMENT'
  quantity: number
  note: string
  created_at: string
}

type AuditLog = {
  id: number
  actor_role: string
  action: string
  entity_table: string
  summary: string
  created_at: string
}

type Shop = { id: string; name: string; phone: string; address: string }

type DashboardData = {
  employees: Employee[]
  requests: EmployeeRequest[]
  orders: Order[]
  cash: CashTransaction[]
  customers: Customer[]
  inventory: InventoryItem[]
  shifts: WeeklyShift[]
  inventoryMovements: InventoryMovement[]
  auditLogs: AuditLog[]
  shop: Shop | null
  totalCustomers: number
}

type RealtimeState = 'connecting' | 'live' | 'offline'

const tabs = [
  { id: 'overview', label: 'Beranda', icon: LayoutDashboard },
  { id: 'orders', label: 'Pesanan', icon: ReceiptText },
  { id: 'analytics', label: 'Analitik', icon: BarChart3 },
  { id: 'requests', label: 'Pengajuan', icon: ClipboardCheck },
  { id: 'inventory', label: 'Stok', icon: PackageCheck },
  { id: 'customers', label: 'Pelanggan', icon: Contact },
  { id: 'team', label: 'Tim', icon: Users },
  { id: 'reports', label: 'Laporan', icon: Banknote },
  { id: 'settings', label: 'Pengaturan', icon: Settings },
] as const

const localPreview = import.meta.env.DEV && new URLSearchParams(window.location.search).has('preview')
const previewProfile: Profile = { id: 'preview-owner', shop_id: 'demo-shop', employee_id: null, full_name: 'Owner Idola', role: 'OWNER', is_active: true }

const demoData: DashboardData = {
  employees: [
    { id: 'emp-1', name: 'Ratna', phone: '081234567891', position: 'Operator', is_active: true, shift_start: '06:00', shift_end: '14:00', late_tolerance_minutes: 15 },
    { id: 'emp-2', name: 'Dimas', phone: '081234567892', position: 'Kasir', is_active: true, shift_start: '12:00', shift_end: '20:00', late_tolerance_minutes: 15 },
  ],
  requests: [
    { id: 'req-1', employee_name: 'Ratna', type: 'Request Stok', reason: 'Deterjen cair hampir habis', amount: 2, status: 'pending', created_at: new Date().toISOString(), review_note: '' },
    { id: 'req-2', employee_name: 'Dimas', type: 'Request Lembur', reason: 'Order express masih menumpuk', amount: 0, status: 'approved', created_at: new Date(Date.now() - 86400000).toISOString(), review_note: 'Disetujui untuk 2 jam.' },
  ],
  orders: [
    { id: 'ord-1', order_number: 'IDL-20260817-0001', customer_name_snapshot: 'Budi Santoso', order_status: 'received', payment_status: 'unpaid', total_price: 45000, paid_amount: 0, created_at: new Date().toISOString(), updated_at: new Date().toISOString() },
    { id: 'ord-2', order_number: 'IDL-20260817-0002', customer_name_snapshot: 'Siti Aminah', order_status: 'ready', payment_status: 'paid', total_price: 72000, paid_amount: 72000, created_at: new Date().toISOString(), updated_at: new Date().toISOString() },
  ],
  cash: [
    { id: 'cash-1', type: 'IN', category: 'Pembayaran', description: 'Pembayaran order IDL-20260817-0002', amount: 72000, created_at: new Date().toISOString() },
    { id: 'cash-2', type: 'OUT', category: 'Operasional', description: 'Pembelian plastik laundry', amount: 25000, created_at: new Date().toISOString() },
  ],
  customers: [{ id: 'cus-1', name: 'Budi Santoso', phone: '081234567800', address: 'Jl. Merdeka No. 1', created_at: new Date().toISOString() }],
  inventory: [
    { id: 'inv-1', name: 'Deterjen cair', stock: 2, unit: 'liter', min_stock: 5, purchase_price: 25000, note: '', is_active: true },
    { id: 'inv-2', name: 'Plastik laundry', stock: 80, unit: 'pcs', min_stock: 20, purchase_price: 500, note: '', is_active: true },
  ],
  shifts: [],
  inventoryMovements: [],
  auditLogs: [],
  shop: { id: 'demo-shop', name: 'Idola Laundry', phone: '081234567890', address: 'Alamat toko' },
  totalCustomers: 1,
}

function App() {
  const [activeTab, setActiveTab] = useState<(typeof tabs)[number]['id']>('overview')
  const [mobileNavOpen, setMobileNavOpen] = useState(false)
  const [teamView, setTeamView] = useState<'employees' | 'shifts'>('employees')
  const [profile, setProfile] = useState<Profile | null>(localPreview ? previewProfile : null)
  const [data, setData] = useState<DashboardData>(demoData)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState('')
  const [query, setQuery] = useState('')
  const [employeeEditor, setEmployeeEditor] = useState<Employee | 'new' | null>(null)
  const [customerEditor, setCustomerEditor] = useState<Customer | 'new' | null>(null)
  const [inventoryEditor, setInventoryEditor] = useState(false)
  const [stockAdjuster, setStockAdjuster] = useState<InventoryItem | null>(null)
  const [shiftEditor, setShiftEditor] = useState<WeeklyShift | 'new' | null>(null)
  const [cashEditor, setCashEditor] = useState(false)
  const [realtimeState, setRealtimeState] = useState<RealtimeState>('connecting')
  const [lastSyncedAt, setLastSyncedAt] = useState<Date | null>(null)

  useEffect(() => {
    if (!supabaseEnabled || localPreview) return
    supabase.auth.getSession().then(({ data: sessionData }) => {
      const userId = sessionData.session?.user.id
      if (userId) void loadProfile(userId)
    })
    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session?.user.id) void loadProfile(session.user.id)
      else { setProfile(null); setData(demoData); setRealtimeState('offline') }
    })
    return () => listener.subscription.unsubscribe()
  }, [])

  useEffect(() => {
    if (!profile || !supabaseEnabled || localPreview) return
    const refresh = () => void loadDashboard(profile.shop_id)
    const refreshWhenVisible = () => {
      if (document.visibilityState === 'visible') refresh()
    }
    const channel = supabase
      .channel(`owner-dashboard:${profile.shop_id}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'employee_requests', filter: `shop_id=eq.${profile.shop_id}` }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'orders', filter: `shop_id=eq.${profile.shop_id}` }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'employees', filter: `shop_id=eq.${profile.shop_id}` }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'customers', filter: `shop_id=eq.${profile.shop_id}` }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_items', filter: `shop_id=eq.${profile.shop_id}` }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'weekly_shifts', filter: `shop_id=eq.${profile.shop_id}` }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_movements', filter: `shop_id=eq.${profile.shop_id}` }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'cash_transactions', filter: `shop_id=eq.${profile.shop_id}` }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'audit_logs', filter: `shop_id=eq.${profile.shop_id}` }, refresh)
      .subscribe((status) => {
        if (status === 'SUBSCRIBED') setRealtimeState('live')
        else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT' || status === 'CLOSED') setRealtimeState('offline')
        else setRealtimeState('connecting')
      })
    const timer = window.setInterval(refreshWhenVisible, 15_000)
    window.addEventListener('focus', refresh)
    document.addEventListener('visibilitychange', refreshWhenVisible)
    return () => {
      window.clearInterval(timer)
      window.removeEventListener('focus', refresh)
      document.removeEventListener('visibilitychange', refreshWhenVisible)
      void supabase.removeChannel(channel)
    }
  }, [profile])

  const metrics = useMemo(() => {
    const today = new Date().toDateString()
    const monthStart = new Date(); monthStart.setDate(1); monthStart.setHours(0, 0, 0, 0)
    const monthCash = data.cash.filter((item) => new Date(item.created_at) >= monthStart)
    const income = monthCash.filter((item) => item.type === 'IN').reduce((sum, item) => sum + item.amount, 0)
    const out = monthCash.filter((item) => item.type === 'OUT').reduce((sum, item) => sum + item.amount, 0)
    return {
      todayOrders: data.orders.filter((item) => new Date(item.created_at).toDateString() === today).length,
      newOrders: data.orders.filter((item) => item.order_status === 'received').length,
      income,
      out,
      balance: income - out,
      pendingRequests: data.requests.filter((item) => item.status.toLowerCase() === 'pending').length,
      activeEmployees: data.employees.filter((item) => item.is_active).length,
      customers: data.totalCustomers,
      lowStock: data.inventory.filter((item) => item.is_active && item.stock <= item.min_stock).length,
    }
  }, [data])

  async function loadProfile(userId: string) {
    setLoading(true); setMessage('')
    try {
      const { data: row, error } = await supabase.from('profiles').select('id, shop_id, employee_id, full_name, role, is_active').eq('id', userId).single()
      if (error || !row) { setMessage('Akun Anda tidak terdaftar atau sesi telah berakhir.'); return }
      if (row.role !== 'OWNER' || !row.is_active) { setMessage('Akses ditolak. Halaman ini hanya dapat diakses oleh Pemilik (Owner) aktif.'); return }
      setProfile(row as Profile)
      await loadDashboard(row.shop_id)
    } catch (e: any) {
      setMessage(e.message || 'Gagal memuat profil.')
    } finally {
      setLoading(false)
    }
  }

  async function loadDashboard(shopId: string) {
    try {
      const historyStart = new Date(new Date().getFullYear() - 1, 0, 1).toISOString()
      const [employees, requests, orders, cash, customers, customerCount, inventory, shifts, inventoryMovements, auditLogs, shop] = await Promise.all([
        supabase.from('employees').select('id, name, phone, position, is_active, shift_start, shift_end, late_tolerance_minutes').eq('shop_id', shopId).eq('role', 'EMPLOYEE').order('name'),
        supabase.from('employee_requests').select('id, employee_name, type, reason, amount, status, review_note, created_at').eq('shop_id', shopId).order('created_at', { ascending: false }),
        supabase.from('orders').select('id, order_number, customer_name_snapshot, order_status, payment_status, total_price, paid_amount, created_at, updated_at').eq('shop_id', shopId).gte('created_at', historyStart).order('created_at', { ascending: false }).limit(5000),
        supabase.from('cash_transactions').select('id, type, category, description, amount, created_at').eq('shop_id', shopId).gte('created_at', historyStart).order('created_at', { ascending: false }).limit(5000),
        supabase.from('customers').select('id, name, phone, address, created_at').eq('shop_id', shopId).is('deleted_at', null).order('created_at', { ascending: false }).limit(5000),
        supabase.from('customers').select('id', { count: 'exact', head: true }).eq('shop_id', shopId).is('deleted_at', null),
        supabase.from('inventory_items').select('id, name, stock, unit, min_stock, purchase_price, note, is_active').eq('shop_id', shopId).order('name'),
        supabase.from('weekly_shifts').select('id, employee_id, employee_name, day_of_week, start_time, end_time, is_day_off').eq('shop_id', shopId).order('day_of_week'),
        supabase.from('inventory_movements').select('id, item_id, item_name, type, quantity, note, created_at').eq('shop_id', shopId).order('created_at', { ascending: false }).limit(30),
        supabase.from('audit_logs').select('id, actor_role, action, entity_table, summary, created_at').eq('shop_id', shopId).order('created_at', { ascending: false }).limit(50),
        supabase.from('shops').select('id, name, phone, address').eq('id', shopId).single(),
      ])
      setData({ employees: (employees.data ?? []) as Employee[], requests: (requests.data ?? []) as EmployeeRequest[], orders: (orders.data ?? []) as Order[], cash: (cash.data ?? []) as CashTransaction[], customers: (customers.data ?? []) as Customer[], inventory: (inventory.data ?? []) as InventoryItem[], shifts: (shifts.data ?? []) as WeeklyShift[], inventoryMovements: (inventoryMovements.data ?? []) as InventoryMovement[], auditLogs: (auditLogs.data ?? []) as AuditLog[], shop: (shop.data ?? null) as Shop | null, totalCustomers: customerCount.count ?? 0 })
      setLastSyncedAt(new Date())
      const firstError = [employees.error, requests.error, orders.error, cash.error, customers.error, customerCount.error, inventory.error, shifts.error, inventoryMovements.error, auditLogs.error, shop.error].find(Boolean)
      if (firstError) setMessage(`Sebagian data gagal dimuat: ${firstError.message}`)
    } catch (e: any) {
      setMessage(e.message || 'Gagal memuat data dashboard.')
    }
  }

  async function signIn(event: FormEvent) {
    event.preventDefault()
    if (!supabaseEnabled) { setMessage('Konfigurasi Supabase belum tersedia.'); return }
    setLoading(true); setMessage('')
    try {
      const login = email.trim().toLowerCase()
      const { error } = await supabase.auth.signInWithPassword({ email: login.includes('@') ? login : `${login}@idola.local`, password })
      if (error) setMessage(error.message)
    } catch (e: any) {
      setMessage(e.message || 'Proses masuk gagal.')
    } finally {
      setLoading(false)
    }
  }

  async function signOut() {
    try {
      await supabase.auth.signOut()
    } catch (e: any) {
      setMessage(e.message || 'Proses keluar gagal.')
    } finally {
      setProfile(null); setData(demoData); setRealtimeState('offline')
    }
  }

  async function reviewRequest(request: EmployeeRequest, status: 'approved' | 'rejected' | 'completed' | 'paid') {
    if (!profile) return
    const requiredNote = status === 'rejected'
    const note = window.prompt(requiredNote ? 'Alasan penolakan (wajib)' : 'Catatan Owner (opsional)', request.review_note)
    if (note === null || (requiredNote && !note.trim())) return
    setLoading(true); setMessage('')
    try {
      const { error } = await supabase.from('employee_requests').update({
        status,
        review_note: note.trim() || statusLabel(status),
        reviewed_at: new Date().toISOString(),
        ...(status === 'paid' ? { payment_method: 'Tunai' } : {}),
      }).eq('id', request.id).eq('shop_id', profile.shop_id)
      if (error) {
        setMessage(error.message)
        return
      }
      await loadDashboard(profile.shop_id)
    } catch (e: any) {
      setMessage(e.message || 'Gagal merespons request.')
    } finally {
      setLoading(false)
    }
  }

  async function saveEmployee(values: EmployeeFormValues) {
    if (!profile) { setMessage('Masuk sebagai Owner dulu sebelum menyimpan karyawan.'); setEmployeeEditor(null); return }
    setLoading(true); setMessage('')
    try {
      if (employeeEditor === 'new') {
        const { data: result, error } = await supabase.functions.invoke('create-employee-user', { body: values })
        if (error || result?.error) setMessage(result?.error ?? error?.message ?? 'Karyawan gagal dibuat.')
        else { setEmployeeEditor(null); setMessage(`Karyawan ${values.name} berhasil dibuat.`); await loadDashboard(profile.shop_id) }
      } else if (employeeEditor) {
        const { error } = await supabase.from('employees').update({ name: values.name, phone: values.phone, position: values.position, shift_start: values.shift_start, shift_end: values.shift_end, late_tolerance_minutes: values.late_tolerance_minutes, is_active: values.is_active }).eq('id', (employeeEditor as Employee).id).eq('shop_id', profile.shop_id)
        if (!error) await supabase.from('profiles').update({ full_name: values.name, phone: values.phone, is_active: values.is_active }).eq('employee_id', (employeeEditor as Employee).id).eq('shop_id', profile.shop_id)
        if (error) setMessage(error.message); else { setEmployeeEditor(null); setMessage(`Data ${values.name} berhasil disimpan.`); await loadDashboard(profile.shop_id) }
      }
    } catch (e: any) {
      setMessage(e.message || 'Gagal menyimpan data karyawan.')
    } finally {
      setLoading(false)
    }
  }

  async function saveCustomer(values: CustomerFormValues) {
    if (!profile) return
    setLoading(true); setMessage('')
    try {
      if (customerEditor === 'new') {
        const { error } = await supabase.from('customers').insert({ ...values, shop_id: profile.shop_id })
        if (error) setMessage(error.message); else { setCustomerEditor(null); await loadDashboard(profile.shop_id) }
      } else if (customerEditor) {
        const { error } = await supabase.from('customers').update(values).eq('id', (customerEditor as Customer).id).eq('shop_id', profile.shop_id)
        if (error) setMessage(error.message); else { setCustomerEditor(null); await loadDashboard(profile.shop_id) }
      }
    } catch (e: any) {
      setMessage(e.message || 'Gagal menyimpan data pelanggan.')
    } finally {
      setLoading(false)
    }
  }

  async function deleteCustomer(customer: Customer) {
    if (!profile || !window.confirm(`Hapus pelanggan ${customer.name}?`)) return
    setLoading(true); setMessage('')
    try {
      const { error } = await supabase.from('customers').update({
        deleted_at: new Date().toISOString(),
        deleted_by: profile.id,
      }).eq('id', customer.id).eq('shop_id', profile.shop_id)
      if (error) setMessage(error.message); else await loadDashboard(profile.shop_id)
    } catch (e: any) {
      setMessage(e.message || 'Gagal menghapus pelanggan.')
    } finally {
      setLoading(false)
    }
  }

  async function addInventoryItem(values: InventoryFormValues) {
    if (!profile) return
    setLoading(true); setMessage('')
    try {
      const { error } = await supabase.from('inventory_items').insert({ ...values, shop_id: profile.shop_id })
      if (error) setMessage(error.message); else { setInventoryEditor(false); await loadDashboard(profile.shop_id) }
    } catch (e: any) {
      setMessage(e.message || 'Gagal menambahkan barang.')
    } finally {
      setLoading(false)
    }
  }

  async function adjustStock(values: StockAdjustmentValues) {
    if (!profile || !stockAdjuster) return
    setLoading(true); setMessage('')
    try {
      const { error } = await supabase.rpc('adjust_inventory_stock', {
        p_item_id: stockAdjuster.id,
        p_quantity: values.quantity,
        p_type: values.type,
        p_note: values.note,
      })
      if (error) setMessage(error.message)
      else { setStockAdjuster(null); await loadDashboard(profile.shop_id) }
    } catch (e: any) {
      setMessage(e.message || 'Gagal mengubah stok.')
    } finally {
      setLoading(false)
    }
  }

  async function updateOrderStatus(order: Order, status: string) {
    if (!profile || order.order_status === status) return
    setLoading(true); setMessage('')
    try {
      const { error } = await supabase.from('orders').update({ order_status: status, updated_at: new Date().toISOString() }).eq('id', order.id).eq('shop_id', profile.shop_id)
      if (error) setMessage(error.message); else await loadDashboard(profile.shop_id)
    } catch (e: any) {
      setMessage(e.message || 'Gagal memperbarui status pesanan.')
    } finally {
      setLoading(false)
    }
  }

  async function recordPayment(order: Order) {
    if (!profile) return
    const remaining = Math.max(0, order.total_price - order.paid_amount)
    const amountText = window.prompt(`Nominal pembayaran (sisa ${rupiah(remaining)})`, String(remaining))
    if (!amountText) return
    const amount = Number(amountText)
    if (!Number.isFinite(amount) || amount <= 0) { setMessage('Nominal pembayaran tidak valid.'); return }
    const method = window.prompt('Metode pembayaran', 'Tunai') || 'Tunai'
    setLoading(true); setMessage('')
    try {
      const { error } = await supabase.rpc('record_order_payment', { p_order_id: order.id, p_amount: Math.round(amount), p_method: method })
      if (error) setMessage(error.message); else await loadDashboard(profile.shop_id)
    } catch (e: any) {
      setMessage(e.message || 'Gagal mencatat pembayaran.')
    } finally {
      setLoading(false)
    }
  }

  async function saveShift(values: ShiftFormValues) {
    if (!profile) return
    const employee = data.employees.find((item) => item.id === values.employee_id)
    if (!employee) { setMessage('Karyawan shift tidak ditemukan.'); return }
    setLoading(true); setMessage('')
    try {
      const payload = { shop_id: profile.shop_id, employee_id: employee.id, employee_name: employee.name, day_of_week: values.day_of_week, start_time: values.start_time, end_time: values.end_time, is_day_off: values.is_day_off }
      const query = shiftEditor === 'new'
        ? supabase.from('weekly_shifts').upsert(payload, { onConflict: 'shop_id,employee_id,day_of_week' })
        : supabase.from('weekly_shifts').update(payload).eq('id', (shiftEditor as WeeklyShift).id).eq('shop_id', profile.shop_id)
      const { error } = await query
      if (error) setMessage(error.message); else { setShiftEditor(null); await loadDashboard(profile.shop_id) }
    } catch (e: any) {
      setMessage(e.message || 'Gagal menyimpan jadwal.')
    } finally {
      setLoading(false)
    }
  }

  async function deleteShift(shift: WeeklyShift) {
    if (!profile || !window.confirm(`Hapus shift ${shift.employee_name} pada ${dayLabel(shift.day_of_week)}?`)) return
    setLoading(true); setMessage('')
    try {
      const { error } = await supabase.from('weekly_shifts').delete().eq('id', shift.id).eq('shop_id', profile.shop_id)
      if (error) setMessage(error.message); else { setShiftEditor(null); await loadDashboard(profile.shop_id) }
    } catch (e: any) {
      setMessage(e.message || 'Gagal menghapus jadwal.')
    } finally {
      setLoading(false)
    }
  }

  async function addCashTransaction(values: CashFormValues) {
    if (!profile) return
    setLoading(true); setMessage('')
    try {
      const { error } = await supabase.from('cash_transactions').insert({ ...values, shop_id: profile.shop_id, reference_type: 'MANUAL' })
      if (error) setMessage(error.message); else { setCashEditor(false); await loadDashboard(profile.shop_id) }
    } catch (e: any) {
      setMessage(e.message || 'Gagal menyimpan kas.')
    } finally {
      setLoading(false)
    }
  }

  async function saveShop(values: ShopFormValues) {
    if (!profile) return
    setLoading(true); setMessage('')
    try {
      const { error } = await supabase.from('shops').update(values).eq('id', profile.shop_id)
      if (error) setMessage(error.message); else await loadDashboard(profile.shop_id)
    } catch (e: any) {
      setMessage(e.message || 'Gagal menyimpan pengaturan toko.')
    } finally {
      setLoading(false)
    }
  }

  function exportCashCsv() {
    const rows = [['Tanggal', 'Tipe', 'Kategori', 'Keterangan', 'Nominal'], ...data.cash.map((item) => [new Date(item.created_at).toLocaleString('id-ID'), item.type, item.category, item.description, String(item.amount)])]
    const csv = rows.map((row) => row.map((cell) => `"${cell.replaceAll('"', '""')}"`).join(',')).join('\n')
    const link = document.createElement('a')
    link.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }))
    link.download = `laporan-kas-${new Date().toISOString().slice(0, 10)}.csv`
    link.click()
    URL.revokeObjectURL(link.href)
  }

  const filteredEmployees = data.employees.filter((item) => `${item.name} ${item.position}`.toLowerCase().includes(query.toLowerCase()))
  const filteredOrders = data.orders.filter((item) => `${item.order_number} ${item.customer_name_snapshot}`.toLowerCase().includes(query.toLowerCase()))
  const filteredCustomers = data.customers.filter((item) => `${item.name} ${item.phone}`.toLowerCase().includes(query.toLowerCase()))
  const currentTab = tabs.find((tab) => tab.id === activeTab) ?? tabs[0]
  const navigate = (tab: (typeof tabs)[number]['id']) => {
    setActiveTab(tab)
    setMobileNavOpen(false)
    setQuery('')
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }
  const search = (value: string) => {
    if (!['orders', 'customers', 'team'].includes(activeTab)) setActiveTab('orders')
    setQuery(value)
  }

  if (!profile) {
    return (
      <main className="login-page">
        <div className="login-container">
          <div className="brand login-brand">
            <div className="brand-mark">ID</div>
            <div><strong>Idola Laundry</strong><span>Owner Dashboard</span></div>
          </div>
          <LoginPanel email={email} password={password} loading={loading} onEmail={setEmail} onPassword={setPassword} onSubmit={signIn} />
          {message ? <div className="notice" style={{ marginTop: '16px' }}>{message}</div> : null}
        </div>
      </main>
    )
  }

  return (
    <main className="admin-shell">
      {mobileNavOpen ? <button className="nav-scrim" aria-label="Tutup menu" type="button" onClick={() => setMobileNavOpen(false)} /> : null}
      <aside className={`sidebar ${mobileNavOpen ? 'open' : ''}`}>
        <div className="brand"><div className="brand-mark">ID</div><div><strong>Idola Laundry</strong><span>Owner workspace</span></div></div>
        <p className="nav-caption">MENU UTAMA</p>
        <nav className="nav-list" aria-label="Menu admin">
          {tabs.map((tab) => { const Icon = tab.icon; return <button key={tab.id} className={activeTab === tab.id ? 'active' : ''} type="button" onClick={() => navigate(tab.id)} aria-current={activeTab === tab.id ? 'page' : undefined}><Icon size={18} /><span>{tab.label}</span>{tab.id === 'requests' && metrics.pendingRequests > 0 ? <b className="nav-count">{metrics.pendingRequests}</b> : null}</button> })}
        </nav>
        <div className={`sidebar-card sync-card ${realtimeState}`}><ShieldCheck size={18} /><div><strong>{localPreview ? 'Preview lokal' : realtimeState === 'live' ? 'Realtime aktif' : realtimeState === 'connecting' ? 'Menghubungkan realtime' : 'Realtime terputus'}</strong><span>{localPreview ? 'Data contoh untuk melihat tampilan.' : realtimeState === 'live' ? 'Perubahan aplikasi langsung masuk.' : 'Polling cadangan berjalan tiap 15 detik.'}</span></div></div>
      </aside>

      <section className="workspace">
        <header className="topbar">
          <div className="topbar-heading"><button className="mobile-menu-button icon-button" type="button" aria-label="Buka menu" onClick={() => setMobileNavOpen(true)}><Menu size={21} /></button><div><p className="eyebrow">IDOLA LAUNDRY / {currentTab.label.toUpperCase()}</p><h1>{currentTab.label === 'Beranda' ? 'Dashboard' : currentTab.label}</h1><div className={`live-status ${realtimeState}`}>{localPreview ? <ShieldCheck size={14} /> : realtimeState === 'offline' ? <WifiOff size={14} /> : <Signal size={14} />}<span>{localPreview ? 'Data contoh' : realtimeState === 'live' ? 'Tersinkron' : realtimeState === 'connecting' ? 'Menghubungkan' : 'Mode cadangan'}{lastSyncedAt && !localPreview ? ` • ${lastSyncedAt.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}` : ''}</span></div></div></div>
          <div className="topbar-actions">
            <label className="search-box"><Search size={18} /><input value={query} onChange={(event) => search(event.target.value)} placeholder={activeTab === 'team' ? 'Cari karyawan' : activeTab === 'customers' ? 'Cari pelanggan' : 'Cari pesanan atau pelanggan'} aria-label="Cari data" /></label>
            {!localPreview ? <button className="icon-button" type="button" onClick={() => void loadDashboard(profile.shop_id)} aria-label="Refresh data"><RefreshCw size={18} /></button> : null}
            <div className="profile-chip"><span className="profile-avatar">{profile.full_name.trim().charAt(0).toUpperCase()}</span><div><strong>{profile.full_name}</strong><small>Owner</small></div></div>
            {!localPreview ? <button className="icon-button logout-button" type="button" onClick={signOut} aria-label="Keluar" title="Keluar"><LogOut size={18} /></button> : null}
          </div>
        </header>

        {message ? <div className="notice">{message}</div> : null}

        {activeTab === 'overview' ? <Overview metrics={metrics} data={data} onNavigate={navigate} /> : null}
        {activeTab === 'orders' ? <OrdersPanel orders={filteredOrders} onUpdateOrder={updateOrderStatus} onRecordPayment={recordPayment} /> : null}
        {activeTab === 'analytics' ? <DashboardAnalytics orders={data.orders} /> : null}
        {activeTab === 'requests' ? <ApprovalPanel requests={data.requests} loading={loading} onReview={reviewRequest} /> : null}
        {activeTab === 'inventory' ? <InventoryPanel items={data.inventory} movements={data.inventoryMovements} onAdd={() => setInventoryEditor(true)} onAdjust={setStockAdjuster} /> : null}
        {activeTab === 'customers' ? <CustomersPanel customers={filteredCustomers} onAdd={() => setCustomerEditor('new')} onEdit={setCustomerEditor} onDelete={deleteCustomer} /> : null}
        {activeTab === 'team' ? <TeamPanel view={teamView} setView={setTeamView} employees={filteredEmployees} shifts={data.shifts} onAdd={() => setEmployeeEditor('new')} onEdit={setEmployeeEditor} onAddShift={() => setShiftEditor('new')} onEditShift={setShiftEditor} /> : null}
        {activeTab === 'reports' ? <ReportsPanel cash={data.cash} metrics={metrics} auditLogs={data.auditLogs} onAddCash={() => setCashEditor(true)} onExport={exportCashCsv} /> : null}
        {activeTab === 'settings' ? <SettingsPanel shop={data.shop} loading={loading} onSave={saveShop} /> : null}
      </section>

      {employeeEditor ? <Modal title={employeeEditor === 'new' ? 'Tambah karyawan & akun' : 'Edit karyawan dan shift'} onClose={() => setEmployeeEditor(null)}><EmployeeForm employee={employeeEditor === 'new' ? null : employeeEditor} loading={loading} onSubmit={saveEmployee} /></Modal> : null}
      {customerEditor ? <Modal title={customerEditor === 'new' ? 'Tambah pelanggan' : 'Edit pelanggan'} onClose={() => setCustomerEditor(null)}><CustomerForm customer={customerEditor === 'new' ? null : customerEditor} loading={loading} onSubmit={saveCustomer} /></Modal> : null}
      {inventoryEditor ? <Modal title="Tambah item stok" onClose={() => setInventoryEditor(false)}><InventoryForm loading={loading} onSubmit={addInventoryItem} /></Modal> : null}
      {stockAdjuster ? <Modal title={`Mutasi ${stockAdjuster.name}`} onClose={() => setStockAdjuster(null)}><StockAdjustmentForm item={stockAdjuster} loading={loading} onSubmit={adjustStock} /></Modal> : null}
      {shiftEditor ? <Modal title={shiftEditor === 'new' ? 'Tambah jadwal mingguan' : 'Edit jadwal mingguan'} onClose={() => setShiftEditor(null)}><ShiftForm shift={shiftEditor === 'new' ? null : shiftEditor} employees={data.employees} loading={loading} onSubmit={saveShift} onDelete={shiftEditor === 'new' ? undefined : () => void deleteShift(shiftEditor)} /></Modal> : null}
      {cashEditor ? <Modal title="Catat kas manual" onClose={() => setCashEditor(false)}><CashForm loading={loading} onSubmit={addCashTransaction} /></Modal> : null}
    </main>
  )
}

function LoginPanel({ email, password, loading, onEmail, onPassword, onSubmit }: { email: string; password: string; loading: boolean; onEmail: (value: string) => void; onPassword: (value: string) => void; onSubmit: (event: FormEvent) => void }) {
  return <section className="login-panel"><div className="login-intro"><p className="eyebrow">Supabase Auth</p><h2>Masuk sebagai Owner</h2><p>Kelola toko, tim, approval, dan laporan yang sama dengan aplikasi Android.</p></div><form className="login-form" onSubmit={onSubmit}><label>Username atau email<input value={email} onChange={(event) => onEmail(event.target.value)} placeholder="owner" required /></label><label>Password<input value={password} type="password" onChange={(event) => onPassword(event.target.value)} required /></label><button className="primary-button" disabled={loading} type="submit"><LogIn size={18} />Masuk Dashboard</button></form></section>
}

function Overview({ metrics, data, onNavigate }: { metrics: ReturnType<typeof useDashboardMetrics>; data: DashboardData; onNavigate: (tab: (typeof tabs)[number]['id']) => void }) {
  const cards = [
    ['Pesanan hari ini', metrics.todayOrders, ReceiptText, 'blue', 'orders'],
    ['Pesanan baru', metrics.newOrders, ClipboardCheck, 'orange', 'orders'],
    ['Pelanggan', metrics.customers, Contact, 'purple', 'customers'],
    ['Karyawan aktif', metrics.activeEmployees, Users, 'green', 'team'],
    ['Pemasukan bulan ini', rupiah(metrics.income), Banknote, 'indigo', 'reports'],
    ['Stok menipis', metrics.lowStock, AlertTriangle, 'rose', 'inventory'],
  ] as const
  return <section className="overview-layout">
    <div className="page-intro"><div><p className="eyebrow">RINGKASAN TOKO</p><h2>Selamat datang, {data.shop?.name || 'Idola Laundry'}</h2><p>Pantau pesanan dan aktivitas toko dari satu tempat.</p></div><span className="date-pill">{new Intl.DateTimeFormat('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }).format(new Date())}</span></div>
    <div className="metrics-grid">{cards.map(([label, value, Icon, tone, destination]) => <button className={`metric-card tone-${tone}`} type="button" key={label} onClick={() => onNavigate(destination)}><span className="metric-icon"><Icon size={20} /></span><span className="metric-label">{label}</span><strong>{value}</strong></button>)}</div>
    {metrics.pendingRequests > 0 ? <button className="attention-strip" type="button" onClick={() => onNavigate('requests')}><span className="attention-icon"><AlertTriangle size={18} /></span><span><strong>{metrics.pendingRequests} pengajuan menunggu keputusan</strong><small>Buka pengajuan untuk meninjau dan memberi keputusan.</small></span><span className="attention-link">Lihat pengajuan →</span></button> : null}
    <article className="wide-panel home-orders"><div className="panel-header"><div><h2>Pesanan terbaru</h2><p>Perubahan dari aplikasi langsung terlihat di sini.</p></div><button className="ghost-button" type="button" onClick={() => onNavigate('orders')}>Semua pesanan →</button></div><OrderTable orders={data.orders.slice(0, 7)} /></article>
  </section>
}

function useDashboardMetrics() { return { todayOrders: 0, newOrders: 0, income: 0, out: 0, balance: 0, pendingRequests: 0, activeEmployees: 0, customers: 0, lowStock: 0 } }

function DashboardAnalytics({ orders }: { orders: Order[] }) {
  const [period, setPeriod] = useState<'week' | 'month'>('week')
  const [selectedMonth, setSelectedMonth] = useState(monthKey(new Date()))
  const monthOptions = calendarMonthOptions(orders)
  const days = period === 'week' ? calendarWeekSeries(orders) : calendarMonthSeries(orders, selectedMonth)
  const maxOrders = Math.max(1, ...days.map((day) => Math.max(day.received, day.completed)))
  const visibleKeys = new Set(days.map((day) => day.key))
  const selectedOrders = orders.filter((order) => visibleKeys.has(localDayKey(order.created_at)))
  const statusRows = [
    ['received', 'Diterima'],
    ['processing', 'Diproses'],
    ['ready', 'Siap diambil'],
    ['picked_up', 'Sudah diambil'],
  ].map(([id, label]) => ({ id, label, count: selectedOrders.filter((order) => order.order_status === id).length }))
  const statusTotal = Math.max(1, statusRows.reduce((sum, row) => sum + row.count, 0))
  const unpaid = orders.filter((order) => order.payment_status !== 'paid').reduce((sum, order) => sum + Math.max(0, order.total_price - order.paid_amount), 0)
  const periodOrders = days.reduce((sum, day) => sum + day.received, 0)
  const periodCompleted = days.reduce((sum, day) => sum + day.completed, 0)
  const periodLabel = period === 'week' ? 'minggu ini' : new Intl.DateTimeFormat('id-ID', { month: 'long', year: 'numeric' }).format(new Date(`${selectedMonth}-01T12:00:00`))
  return <div className="analytics-grid"><article className="wide-panel chart-panel"><div className="panel-header chart-header"><div><h2>Progres pesanan</h2><p>Pesanan masuk dan selesai pada periode kalender.</p></div><div className="chart-controls"><SegmentedControl value={period} items={[["week", 'Minggu ini'], ["month", 'Per bulan']]} onChange={setPeriod} />{period === 'month' ? <select className="month-select" aria-label="Pilih bulan" value={selectedMonth} onChange={(event) => setSelectedMonth(event.target.value)}>{monthOptions.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}</select> : null}</div></div><div className="period-caption">Periode: <strong>{period === 'week' ? weekRangeLabel(days) : periodLabel}</strong></div><div className="progress-totals"><div><span>Masuk</span><strong>{periodOrders}</strong></div><div><span>Selesai</span><strong>{periodCompleted}</strong></div><div><span>Tingkat selesai</span><strong>{periodOrders ? `${Math.round(periodCompleted / periodOrders * 100)}%` : '0%'}</strong></div></div><div className="chart-legend"><span><i className="legend-dot received" />Pesanan masuk</span><span><i className="legend-dot completed" />Selesai</span></div><div className={`cash-chart order-chart period-${period}`} role="img" aria-label={`Grafik pesanan masuk dan selesai ${periodLabel}`}><div className="chart-scroll-inner" style={{ gridTemplateColumns: `repeat(${days.length}, minmax(${period === 'month' ? 24 : 54}px, 1fr))` }}>{days.map((day) => <div className="chart-day" key={day.key}><div className="bar-area"><div className="chart-bar received" style={{ height: `${Math.max(day.received ? 8 : 0, day.received / maxOrders * 100)}%` }} title={`Masuk ${day.fullLabel}: ${day.received}`} /><div className="chart-bar completed" style={{ height: `${Math.max(day.completed ? 8 : 0, day.completed / maxOrders * 100)}%` }} title={`Selesai ${day.fullLabel}: ${day.completed}`} /></div><strong>{day.received}/{day.completed}</strong><span>{day.label}</span></div>)}</div></div><p className="chart-footnote">Format angka: masuk/selesai. Bulanan memakai tanggal 1 sampai akhir bulan yang dipilih.</p></article><article className="wide-panel chart-panel"><PanelHeader title="Posisi pesanan" description={`Status pesanan yang dibuat pada ${periodLabel}.`} /><div className="status-summary">{statusRows.map((row) => <div className="status-line" key={row.id}><div><span>{row.label}</span><strong>{row.count}</strong></div><div className="status-track"><i className={row.id} style={{ width: `${row.count / statusTotal * 100}%` }} /></div></div>)}</div><div className="receivable-card"><span>Sisa tagihan belum lunas</span><strong>{rupiah(unpaid)}</strong><small>Dari {orders.filter((order) => order.payment_status !== 'paid').length} pesanan yang masih memiliki tagihan</small></div></article></div>
}

function OrdersPanel({ orders, onUpdateOrder, onRecordPayment }: { orders: Order[]; onUpdateOrder: (order: Order, status: string) => Promise<void>; onRecordPayment: (order: Order) => Promise<void> }) {
  const [filter, setFilter] = useState('all')
  const [page, setPage] = useState(1)
  const filters = [['all', 'Semua'], ['received', 'Diterima'], ['processing', 'Diproses'], ['ready', 'Siap diambil'], ['picked_up', 'Diambil']] as const
  const shown = orders.filter((order) => filter === 'all' || order.order_status === filter)
  const pageSize = 10
  const totalPages = Math.max(1, Math.ceil(shown.length / pageSize))
  const currentPage = Math.min(page, totalPages)
  return <article className="wide-panel orders-panel"><div className="panel-header"><div><h2>Daftar pesanan</h2><p>{shown.length} pesanan ditemukan. Ubah status dan catat pembayaran di sini.</p></div><span className="list-count">{shown.length} pesanan</span></div><div className="order-filters" role="group" aria-label="Filter status pesanan">{filters.map(([id, label]) => <button type="button" key={id} className={filter === id ? 'active' : ''} onClick={() => { setFilter(id); setPage(1) }}>{label}</button>)}</div><OrderTable orders={shown.slice((currentPage - 1) * pageSize, currentPage * pageSize)} onUpdateStatus={onUpdateOrder} onRecordPayment={onRecordPayment} /><Pagination page={currentPage} pages={totalPages} total={shown.length} onChange={setPage} /></article>
}

function ApprovalPanel({ requests, loading, onReview }: { requests: EmployeeRequest[]; loading: boolean; onReview: (request: EmployeeRequest, status: 'approved' | 'rejected' | 'completed' | 'paid') => Promise<void> }) {
  const [filter, setFilter] = useState('pending')
  const shown = requests.filter((item) => filter === 'all' || item.status === filter || (filter === 'completed' && item.status === 'paid'))
  return <section className="wide-panel"><PanelHeader title="Approval Center" description="Semua request stok, lembur, izin, tukar shift, insentif, kasbon, dan pengeluaran ada di sini." /><div className="filter-row">{[['pending', 'Menunggu'], ['approved', 'Disetujui'], ['completed', 'Selesai'], ['rejected', 'Ditolak'], ['all', 'Semua']].map(([id, label]) => <button key={id} type="button" className={filter === id ? 'active' : ''} onClick={() => setFilter(id)}>{label}</button>)}</div><div className="request-stack">{shown.map((request) => <article className="approval-card" key={request.id}><div className="approval-copy"><div className="approval-title"><strong>{request.type}</strong><span>{request.employee_name} - {dateLabel(request.created_at)}</span></div><p>{request.reason}</p>{request.amount > 0 ? <b>{request.type.includes('Stok') ? `${request.amount} unit` : rupiah(request.amount)}</b> : null}{request.review_note ? <small>Catatan: {request.review_note}</small> : null}</div><div className="approval-actions"><StatusBadge label={request.status} />{request.status === 'pending' ? <><button className="approve" disabled={loading} type="button" onClick={() => void onReview(request, 'approved')}><CheckCircle2 size={16} />Setujui</button><button className="reject" disabled={loading} type="button" onClick={() => void onReview(request, 'rejected')}><XCircle size={16} />Tolak</button></> : null}{request.status === 'approved' ? <button className="approve" disabled={loading} type="button" onClick={() => void onReview(request, isMoneyRequest(request.type) ? 'paid' : 'completed')}><CheckCircle2 size={16} />{isMoneyRequest(request.type) ? 'Bayar' : 'Selesaikan'}</button> : null}</div></article>)}{!shown.length ? <div className="empty-state">Tidak ada request pada status ini.</div> : null}</div></section>
}

function CustomersPanel({ customers, onAdd, onEdit, onDelete }: { customers: Customer[]; onAdd: () => void; onEdit: (c: Customer) => void; onDelete: (c: Customer) => void }) {
  const [page, setPage] = useState(1)
  const pageSize = 12
  const totalPages = Math.max(1, Math.ceil(customers.length / pageSize))
  const currentPage = Math.min(page, totalPages)
  return <section className="wide-panel"><PanelHeader title="Data Pelanggan" description="Kelola daftar pelanggan toko." action="Tambah Pelanggan" onAction={onAdd} /><div className="table-list">{customers.slice((currentPage - 1) * pageSize, currentPage * pageSize).map((customer) => <div className="table-row" key={customer.id}><div><strong>{customer.name}</strong><span>{customer.phone || 'Tanpa telepon'} {customer.address ? `- ${customer.address}` : ''}</span></div><div className="row-meta"><button className="icon-button" type="button" title="Edit pelanggan" onClick={() => onEdit(customer)}><Pencil size={16} /></button><button className="icon-button reject" style={{ minHeight: '38px', padding: '0 10px', color: '#b42318' }} type="button" title="Hapus pelanggan" onClick={() => onDelete(customer)}><XCircle size={16} /></button></div></div>)}{!customers.length ? <div className="empty-state">Belum ada pelanggan.</div> : null}</div><Pagination page={currentPage} pages={totalPages} total={customers.length} onChange={setPage} /></section>
}

type CustomerFormValues = { name: string; phone: string; address: string }
function CustomerForm({ customer, loading, onSubmit }: { customer: Customer | null; loading: boolean; onSubmit: (values: CustomerFormValues) => Promise<void> }) {
  const [values, setValues] = useState<CustomerFormValues>({ name: customer?.name ?? '', phone: customer?.phone ?? '', address: customer?.address ?? '' })
  const change = (key: keyof CustomerFormValues, value: string) => setValues((current) => ({ ...current, [key]: value }))
  return <form className="editor-form" onSubmit={(event) => { event.preventDefault(); void onSubmit(values) }}><label>Nama Pelanggan<input value={values.name} onChange={(event) => change('name', event.target.value)} required /></label><label>Nomor Telepon<input value={values.phone} onChange={(event) => change('phone', event.target.value)} /></label><label>Alamat<textarea value={values.address} onChange={(event) => change('address', event.target.value)} rows={3} /></label><button className="primary-button" disabled={loading} type="submit"><CheckCircle2 size={18} />Simpan Pelanggan</button></form>
}

function TeamPanel({ view, setView, employees, shifts, onAdd, onEdit, onAddShift, onEditShift }: { view: 'employees' | 'shifts'; setView: (value: 'employees' | 'shifts') => void; employees: Employee[]; shifts: WeeklyShift[]; onAdd: () => void; onEdit: (employee: Employee) => void; onAddShift: () => void; onEditShift: (shift: WeeklyShift) => void }) {
  return <section><SegmentedControl value={view} items={[['employees', 'Karyawan'], ['shifts', 'Jadwal Mingguan']]} onChange={setView} /><section className="wide-panel"><PanelHeader title={view === 'employees' ? 'Karyawan & Akun' : 'Jadwal Shift Mingguan'} description={view === 'employees' ? 'Tambah akun, ubah data, dan aktifkan karyawan.' : 'Atur jam kerja atau hari libur setiap karyawan.'} action={view === 'employees' ? 'Tambah Karyawan' : 'Tambah Shift'} onAction={view === 'employees' ? onAdd : onAddShift} />{view === 'employees' ? <div className="table-list">{employees.map((employee) => <div className="table-row" key={employee.id}><div><strong>{employee.name}</strong><span>{employee.position} - {employee.phone || 'Tanpa nomor telepon'}</span></div><div className="row-meta"><StatusBadge label={employee.is_active ? 'Aktif' : 'Nonaktif'} /><button className="icon-button" type="button" title="Edit karyawan" onClick={() => onEdit(employee)}><Pencil size={16} /></button></div></div>)}</div> : <WeeklyShiftGrid shifts={shifts} onEdit={onEditShift} />}</section></section>
}

function WeeklyShiftGrid({ shifts, onEdit }: { shifts: WeeklyShift[]; onEdit: (shift: WeeklyShift) => void }) {
  if (!shifts.length) return <div className="empty-state">Belum ada jadwal mingguan. Tambahkan shift untuk mulai menyusun jadwal.</div>
  return <div className="schedule-grid">{[1, 2, 3, 4, 5, 6, 7].map((day) => <section className="schedule-day" key={day}><strong>{dayLabel(day)}</strong>{shifts.filter((shift) => shift.day_of_week === day).map((shift) => <button type="button" key={shift.id} onClick={() => onEdit(shift)}><span>{shift.employee_name}</span><b>{shift.is_day_off ? 'Libur' : `${shortTime(shift.start_time)} - ${shortTime(shift.end_time)}`}</b></button>)}{!shifts.some((shift) => shift.day_of_week === day) ? <small>Belum dijadwalkan</small> : null}</section>)}</div>
}

function InventoryPanel({ items, movements, onAdd, onAdjust }: { items: InventoryItem[]; movements: InventoryMovement[]; onAdd: () => void; onAdjust: (item: InventoryItem) => void }) {
  return <section className="section-grid"><article className="wide-panel"><PanelHeader title="Stok & Persediaan" description="Pantau stok minimum dan catat stok masuk atau keluar." action="Tambah Item" onAction={onAdd} /><div className="table-list">{items.map((item) => { const low = item.stock <= item.min_stock; return <div className="table-row" key={item.id}><div><strong>{item.name}</strong><span>Minimum {item.min_stock} {item.unit} - {rupiah(item.purchase_price)}</span></div><div className="row-meta">{low ? <StatusBadge label="Menipis" /> : null}<strong>{item.stock} {item.unit}</strong><button className="ghost-button" type="button" onClick={() => onAdjust(item)}>Mutasi</button></div></div> })}{!items.length ? <div className="empty-state">Belum ada item stok.</div> : null}</div></article><article className="wide-panel"><PanelHeader title="Riwayat Mutasi" description="Pergerakan stok terbaru dan catatannya." /><div className="table-list">{movements.slice(0, 12).map((movement) => <div className="table-row" key={movement.id}><div><strong>{movement.item_name}</strong><span>{movement.note || dateLabel(movement.created_at)}</span></div><strong className={movement.type === 'IN' ? 'money-in' : 'money-out'}>{movement.type === 'IN' ? '+' : '-'}{movement.quantity}</strong></div>)}{!movements.length ? <div className="empty-state">Belum ada mutasi stok.</div> : null}</div></article></section>
}

function ReportsPanel({ cash, metrics, auditLogs, onAddCash, onExport }: { cash: CashTransaction[]; metrics: ReturnType<typeof useDashboardMetrics>; auditLogs: AuditLog[]; onAddCash: () => void; onExport: () => void }) {
  const [page, setPage] = useState(1)
  const pageSize = 12
  const totalPages = Math.max(1, Math.ceil(cash.length / pageSize))
  const currentPage = Math.min(page, totalPages)
  return <section className="section-grid"><div className="metrics-grid"><article className="metric-card"><Banknote size={20} /><strong>{rupiah(metrics.income)}</strong><span>Pemasukan</span></article><article className="metric-card"><Banknote size={20} /><strong>{rupiah(metrics.out)}</strong><span>Pengeluaran</span></article><article className="metric-card"><Banknote size={20} /><strong>{rupiah(metrics.balance)}</strong><span>Saldo</span></article></div><article className="wide-panel"><div className="panel-header"><div><h2>Buku Kas</h2><p>Transaksi terbaru toko dan pencatatan manual.</p></div><div className="row-meta"><button className="ghost-button" type="button" onClick={onExport}>Export CSV</button><button className="primary-button" type="button" onClick={onAddCash}><Plus size={16} />Catat Kas</button></div></div><div className="table-list">{cash.slice((currentPage - 1) * pageSize, currentPage * pageSize).map((item) => <div className="table-row" key={item.id}><div><strong>{item.category}</strong><span>{item.description || dateLabel(item.created_at)}</span></div><strong className={item.type === 'IN' ? 'money-in' : 'money-out'}>{item.type === 'IN' ? '+' : '-'}{rupiah(item.amount)}</strong></div>)}</div><Pagination page={currentPage} pages={totalPages} total={cash.length} onChange={setPage} /></article><article className="wide-panel"><PanelHeader title="Audit Aktivitas" description="Riwayat perubahan penting oleh Owner dan karyawan." /><div className="table-list">{auditLogs.slice(0, 15).map((log) => <div className="table-row" key={log.id}><div><strong>{log.action} {log.entity_table}</strong><span>{log.actor_role || 'SYSTEM'} - {dateLabel(log.created_at)}</span></div><StatusBadge label={log.action} /></div>)}{!auditLogs.length ? <div className="empty-state">Audit aktivitas akan muncul setelah migrasi dijalankan.</div> : null}</div></article></section>
}

function SettingsPanel({ shop, loading, onSave }: { shop: Shop | null; loading: boolean; onSave: (values: ShopFormValues) => Promise<void> }) { return <section className="two-column"><article className="wide-panel"><PanelHeader title="Pengaturan Toko" description="Profil ini dipakai bersama oleh dashboard dan aplikasi Android." />{shop ? <ShopForm shop={shop} loading={loading} onSubmit={onSave} /> : <div className="empty-state">Data toko belum dimuat.</div>}</article><article className="side-panel"><PanelHeader title="Keamanan & Sinkronisasi" description="Kontrol akses Supabase." /><Checklist items={['Login Owner dan karyawan', 'Pembatasan data per shop_id', 'Notifikasi request tertarget', 'Audit perubahan operasional', 'Realtime lintas perangkat']} /></article></section> }

type EmployeeFormValues = { username?: string; password?: string; name: string; phone: string; position: string; shift_start: string; shift_end: string; late_tolerance_minutes: number; is_active: boolean }
function EmployeeForm({ employee, loading, onSubmit }: { employee: Employee | null; loading: boolean; onSubmit: (values: EmployeeFormValues) => Promise<void> }) {
  const [values, setValues] = useState<EmployeeFormValues>({ username: '', password: '', name: employee?.name ?? '', phone: employee?.phone ?? '', position: employee?.position ?? 'Operator', shift_start: shortTime(employee?.shift_start ?? '06:00'), shift_end: shortTime(employee?.shift_end ?? '14:00'), late_tolerance_minutes: employee?.late_tolerance_minutes ?? 15, is_active: employee?.is_active ?? true })
  const change = (key: keyof EmployeeFormValues, value: string | number | boolean) => setValues((current) => ({ ...current, [key]: value }))
  return <form className="editor-form" onSubmit={(event) => { event.preventDefault(); void onSubmit(values) }}>{!employee ? <div className="form-grid"><label>Username<input value={values.username} onChange={(event) => change('username', event.target.value)} minLength={3} required /></label><label>Password awal<input type="password" value={values.password} onChange={(event) => change('password', event.target.value)} minLength={8} required /></label></div> : null}<div className="form-grid"><label>Nama<input value={values.name} onChange={(event) => change('name', event.target.value)} required /></label><label>Nomor telepon<input value={values.phone} onChange={(event) => change('phone', event.target.value)} /></label></div><label>Posisi<input value={values.position} onChange={(event) => change('position', event.target.value)} required /></label><div className="form-grid"><label>Mulai shift<input type="time" value={values.shift_start} onChange={(event) => change('shift_start', event.target.value)} required /></label><label>Selesai shift<input type="time" value={values.shift_end} onChange={(event) => change('shift_end', event.target.value)} required /></label></div><label>Toleransi terlambat (menit)<input type="number" min="0" max="480" value={values.late_tolerance_minutes} onChange={(event) => change('late_tolerance_minutes', Number(event.target.value))} required /></label><label className="toggle-row"><input type="checkbox" checked={values.is_active} onChange={(event) => change('is_active', event.target.checked)} />Karyawan aktif</label><button className="primary-button" disabled={loading} type="submit"><CheckCircle2 size={18} />{loading ? 'Menyimpan...' : 'Simpan'}</button></form>
}

type InventoryFormValues = { name: string; stock: number; unit: string; min_stock: number; purchase_price: number; note: string; is_active: boolean }
function InventoryForm({ loading, onSubmit }: { loading: boolean; onSubmit: (values: InventoryFormValues) => Promise<void> }) {
  const [values, setValues] = useState<InventoryFormValues>({ name: '', stock: 0, unit: 'pcs', min_stock: 0, purchase_price: 0, note: '', is_active: true })
  const change = (key: keyof InventoryFormValues, value: string | number) => setValues((current) => ({ ...current, [key]: value }))
  return <form className="editor-form" onSubmit={(event) => { event.preventDefault(); void onSubmit(values) }}><label>Nama item<input value={values.name} onChange={(event) => change('name', event.target.value)} required /></label><div className="form-grid"><label>Stok awal<input type="number" min="0" value={values.stock} onChange={(event) => change('stock', Number(event.target.value))} /></label><label>Satuan<input value={values.unit} onChange={(event) => change('unit', event.target.value)} required /></label></div><div className="form-grid"><label>Stok minimum<input type="number" min="0" value={values.min_stock} onChange={(event) => change('min_stock', Number(event.target.value))} /></label><label>Harga beli<input type="number" min="0" value={values.purchase_price} onChange={(event) => change('purchase_price', Number(event.target.value))} /></label></div><label>Catatan<textarea value={values.note} onChange={(event) => change('note', event.target.value)} rows={3} /></label><button className="primary-button" disabled={loading} type="submit"><Plus size={18} />Tambah Item</button></form>
}

type StockAdjustmentValues = { type: 'IN' | 'OUT' | 'ADJUSTMENT'; quantity: number; note: string }
function StockAdjustmentForm({ item, loading, onSubmit }: { item: InventoryItem; loading: boolean; onSubmit: (values: StockAdjustmentValues) => Promise<void> }) {
  const [values, setValues] = useState<StockAdjustmentValues>({ type: 'IN', quantity: 1, note: '' })
  return <form className="editor-form" onSubmit={(event) => { event.preventDefault(); void onSubmit(values) }}><div className="form-grid"><label>Jenis<select value={values.type} onChange={(event) => setValues({ ...values, type: event.target.value as StockAdjustmentValues['type'] })}><option value="IN">Stok masuk</option><option value="OUT">Stok keluar</option><option value="ADJUSTMENT">Set stok aktual</option></select></label><label>Jumlah ({item.unit})<input type="number" min="0.01" step="0.01" value={values.quantity} onChange={(event) => setValues({ ...values, quantity: Number(event.target.value) })} required /></label></div><label>Catatan<textarea rows={3} value={values.note} onChange={(event) => setValues({ ...values, note: event.target.value })} placeholder="Pembelian, pemakaian, koreksi stok..." /></label><button className="primary-button" disabled={loading} type="submit"><CheckCircle2 size={18} />Simpan Mutasi</button></form>
}

type ShiftFormValues = { employee_id: string; day_of_week: number; start_time: string; end_time: string; is_day_off: boolean }
function ShiftForm({ shift, employees, loading, onSubmit, onDelete }: { shift: WeeklyShift | null; employees: Employee[]; loading: boolean; onSubmit: (values: ShiftFormValues) => Promise<void>; onDelete?: () => void }) {
  const [values, setValues] = useState<ShiftFormValues>({ employee_id: shift?.employee_id ?? employees[0]?.id ?? '', day_of_week: shift?.day_of_week ?? 1, start_time: shortTime(shift?.start_time ?? '06:00'), end_time: shortTime(shift?.end_time ?? '14:00'), is_day_off: shift?.is_day_off ?? false })
  return <form className="editor-form" onSubmit={(event) => { event.preventDefault(); void onSubmit(values) }}><label>Karyawan<select value={values.employee_id} disabled={Boolean(shift)} onChange={(event) => setValues({ ...values, employee_id: event.target.value })} required>{employees.map((employee) => <option key={employee.id} value={employee.id}>{employee.name}</option>)}</select></label><label>Hari<select value={values.day_of_week} onChange={(event) => setValues({ ...values, day_of_week: Number(event.target.value) })}>{[1, 2, 3, 4, 5, 6, 7].map((day) => <option key={day} value={day}>{dayLabel(day)}</option>)}</select></label><label className="toggle-row"><input type="checkbox" checked={values.is_day_off} onChange={(event) => setValues({ ...values, is_day_off: event.target.checked })} />Hari libur</label>{!values.is_day_off ? <div className="form-grid"><label>Mulai<input type="time" value={values.start_time} onChange={(event) => setValues({ ...values, start_time: event.target.value })} required /></label><label>Selesai<input type="time" value={values.end_time} onChange={(event) => setValues({ ...values, end_time: event.target.value })} required /></label></div> : null}<div className="form-actions"><button className="primary-button" disabled={loading || !values.employee_id} type="submit"><CheckCircle2 size={18} />Simpan Jadwal</button>{onDelete ? <button className="reject" disabled={loading} type="button" onClick={onDelete}><XCircle size={18} />Hapus</button> : null}</div></form>
}

type CashFormValues = { type: 'IN' | 'OUT'; category: string; description: string; amount: number; method: string }
function CashForm({ loading, onSubmit }: { loading: boolean; onSubmit: (values: CashFormValues) => Promise<void> }) {
  const [values, setValues] = useState<CashFormValues>({ type: 'OUT', category: 'Operasional', description: '', amount: 0, method: 'Tunai' })
  return <form className="editor-form" onSubmit={(event) => { event.preventDefault(); void onSubmit(values) }}><div className="form-grid"><label>Tipe<select value={values.type} onChange={(event) => setValues({ ...values, type: event.target.value as 'IN' | 'OUT' })}><option value="IN">Pemasukan</option><option value="OUT">Pengeluaran</option></select></label><label>Kategori<input value={values.category} onChange={(event) => setValues({ ...values, category: event.target.value })} required /></label></div><label>Keterangan<textarea rows={3} value={values.description} onChange={(event) => setValues({ ...values, description: event.target.value })} required /></label><div className="form-grid"><label>Nominal<input type="number" min="1" value={values.amount} onChange={(event) => setValues({ ...values, amount: Number(event.target.value) })} required /></label><label>Metode<select value={values.method} onChange={(event) => setValues({ ...values, method: event.target.value })}><option>Tunai</option><option>Transfer</option><option>QRIS</option></select></label></div><button className="primary-button" disabled={loading} type="submit"><Plus size={18} />Simpan Kas</button></form>
}

type ShopFormValues = { name: string; phone: string; address: string }
function ShopForm({ shop, loading, onSubmit }: { shop: Shop; loading: boolean; onSubmit: (values: ShopFormValues) => Promise<void> }) {
  const [values, setValues] = useState<ShopFormValues>({ name: shop.name, phone: shop.phone, address: shop.address })
  return <form className="editor-form" onSubmit={(event) => { event.preventDefault(); void onSubmit(values) }}><label>Nama toko<input value={values.name} onChange={(event) => setValues({ ...values, name: event.target.value })} required /></label><label>Nomor telepon<input value={values.phone} onChange={(event) => setValues({ ...values, phone: event.target.value })} /></label><label>Alamat<textarea rows={4} value={values.address} onChange={(event) => setValues({ ...values, address: event.target.value })} /></label><button className="primary-button" disabled={loading} type="submit"><CheckCircle2 size={18} />Simpan Pengaturan</button></form>
}

function Modal({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) { return <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}><section className="modal" role="dialog" aria-modal="true" aria-label={title}><header><h2>{title}</h2><button className="icon-button" type="button" onClick={onClose} aria-label="Tutup"><X size={18} /></button></header>{children}</section></div> }

function SegmentedControl<T extends string>({ value, items, onChange }: { value: T; items: readonly (readonly [T, string])[]; onChange: (value: T) => void }) { return <div className="segmented-control">{items.map(([id, label]) => <button key={id} className={value === id ? 'active' : ''} type="button" onClick={() => onChange(id)}>{label}</button>)}</div> }
function PanelHeader({ title, description, action, onAction }: { title: string; description: string; action?: string; onAction?: () => void }) { return <div className="panel-header"><div><h2>{title}</h2><p>{description}</p></div>{action ? <button className="ghost-button" type="button" onClick={onAction}><Plus size={16} />{action}</button> : null}</div> }
function OrderTable({ orders, onUpdateStatus, onRecordPayment }: { orders: Order[]; onUpdateStatus?: (order: Order, status: string) => Promise<void>; onRecordPayment?: (order: Order) => Promise<void> }) {
  if (!orders.length) return <div className="empty-state">Belum ada pesanan pada tampilan ini.</div>
  return <div className="order-table-wrap"><table className="order-table"><thead><tr><th>Nomor nota</th><th>Pelanggan</th><th>Tanggal</th><th>Total</th><th>Status</th><th>Pembayaran</th>{onUpdateStatus ? <th>Tindakan</th> : null}</tr></thead><tbody>{orders.map((order) => <tr key={order.id} className={order.order_status === 'received' ? 'is-new' : ''}><td data-label="Nomor nota"><strong>{order.order_number}</strong></td><td data-label="Pelanggan">{order.customer_name_snapshot}</td><td data-label="Tanggal">{dateLabel(order.created_at)}</td><td data-label="Total"><strong>{rupiah(order.total_price)}</strong></td><td data-label="Status"><StatusBadge label={order.order_status} /></td><td data-label="Pembayaran"><StatusBadge label={order.payment_status} /></td>{onUpdateStatus ? <td data-label="Tindakan"><div className="table-actions"><select className="compact-select" aria-label={`Ubah status ${order.order_number}`} value={order.order_status} onChange={(event) => void onUpdateStatus(order, event.target.value)}><option value="received">Diterima</option><option value="processing">Diproses</option><option value="ready">Siap diambil</option><option value="picked_up">Diambil</option><option value="cancelled">Dibatalkan</option></select>{onRecordPayment && order.paid_amount < order.total_price ? <button className="table-pay-button" type="button" onClick={() => void onRecordPayment(order)}>Bayar</button> : null}</div></td> : null}</tr>)}</tbody></table></div>
}

function Pagination({ page, pages, total, onChange }: { page: number; pages: number; total: number; onChange: (page: number) => void }) {
  if (total === 0) return null
  return <div className="pagination"><span>Halaman {page} dari {pages} · {total} data</span><div><button type="button" disabled={page <= 1} onClick={() => onChange(page - 1)}>‹ Sebelumnya</button><button type="button" disabled={page >= pages} onClick={() => onChange(page + 1)}>Berikutnya ›</button></div></div>
}
function Checklist({ items }: { items: string[] }) { return <ul className="checklist">{items.map((item) => <li key={item}><CheckCircle2 size={16} /><span>{item}</span></li>)}</ul> }
const statusLabels: Record<string, string> = {
  received: 'Diterima',
  processing: 'Diproses',
  ready: 'Siap diambil',
  picked_up: 'Sudah diambil',
  cancelled: 'Dibatalkan',
  unpaid: 'Belum bayar',
  partial: 'DP',
  paid: 'Lunas',
  pending: 'Menunggu',
  approved: 'Disetujui',
  completed: 'Selesai',
  rejected: 'Ditolak',
}

function StatusBadge({ label }: { label: string }) {
  const statusKey = label.toLowerCase()
  return <span className={`status ${statusKey}`}>{statusLabels[statusKey] || label}</span>
}
function rupiah(value: number) { return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(value) }
function dateLabel(value: string) { return new Intl.DateTimeFormat('id-ID', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }).format(new Date(value)) }
function localDayKey(value: Date | string) {
  const date = value instanceof Date ? value : new Date(value)
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}
function monthKey(value: Date | string) {
  const date = value instanceof Date ? value : new Date(value)
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`
}
function orderProgressForDates(orders: Order[], dates: Date[], monthly = false) {
  return dates.map((date) => {
    const key = localDayKey(date)
    return {
      key,
      label: monthly ? String(date.getDate()) : new Intl.DateTimeFormat('id-ID', { weekday: 'short' }).format(date).replace('.', ''),
      fullLabel: new Intl.DateTimeFormat('id-ID', { day: 'numeric', month: 'long', year: 'numeric' }).format(date),
      received: orders.filter((order) => localDayKey(order.created_at) === key).length,
      completed: orders.filter((order) => ['ready', 'picked_up'].includes(order.order_status) && localDayKey(order.updated_at) === key).length,
    }
  })
}
function calendarWeekSeries(orders: Order[]) {
  const start = new Date(); start.setHours(0, 0, 0, 0)
  start.setDate(start.getDate() - ((start.getDay() + 6) % 7))
  return orderProgressForDates(orders, Array.from({ length: 7 }, (_, index) => { const date = new Date(start); date.setDate(start.getDate() + index); return date }))
}
function calendarMonthSeries(orders: Order[], selectedMonth: string) {
  const [year, month] = selectedMonth.split('-').map(Number)
  const days = new Date(year, month, 0).getDate()
  return orderProgressForDates(orders, Array.from({ length: days }, (_, index) => new Date(year, month - 1, index + 1)), true)
}
function calendarMonthOptions(orders: Order[]) {
  const keys = new Set(orders.map((order) => monthKey(order.created_at)))
  const now = new Date()
  for (let offset = 0; offset < 12; offset += 1) keys.add(monthKey(new Date(now.getFullYear(), now.getMonth() - offset, 1)))
  return [...keys].sort((a, b) => b.localeCompare(a)).map((value) => ({ value, label: new Intl.DateTimeFormat('id-ID', { month: 'long', year: 'numeric' }).format(new Date(`${value}-01T12:00:00`)) }))
}
function weekRangeLabel(days: ReturnType<typeof calendarWeekSeries>) {
  if (!days.length) return '-'
  return `${days[0].fullLabel} – ${days[days.length - 1].fullLabel}`
}
function shortTime(value: string) { return value.slice(0, 5) }
function statusLabel(status: string) { return status === 'approved' ? 'Disetujui Owner.' : status === 'rejected' ? 'Ditolak Owner.' : status === 'paid' ? 'Sudah dibayar.' : 'Sudah diselesaikan.' }
function dayLabel(day: number) { return ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'][day - 1] ?? 'Hari' }
function isMoneyRequest(type: string) { return type.includes('Kasbon') || type.includes('Insentif') || type.includes('Pengeluaran') }

export default App
