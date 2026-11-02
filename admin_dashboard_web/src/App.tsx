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
  CreditCard,
  Printer,
  QrCode,
  Trash2,
  TrendingUp,
  TrendingDown,
  Users,
  Wallet,
  WifiOff,
  X,
  XCircle,
} from 'lucide-react'
import { supabase, supabaseEnabled } from './supabaseClient'
import { AuditPanel, IncentivesPanel, OrderKiloServiceEditor, OrderPaymentCorrections, ProjectsPanel, ServicesPanel } from './OwnerExtras'
import type { AuditEntry } from './OwnerExtras'
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
  note: string
  due_at: string
  assigned_employee_id: string | null
}

type CashTransaction = {
  id: string
  type: 'IN' | 'OUT'
  category: string
  description: string
  amount: number
  created_at: string
  method: string
  reference_type: string
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

type AuditLog = AuditEntry

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

type QueryError = { message: string }

const dataPageSize = 500

async function fetchAllPages<T>(
  fetchPage: (from: number, to: number) => PromiseLike<{ data: T[] | null; error: QueryError | null }>,
) {
  const data: T[] = []
  for (let from = 0; ; from += dataPageSize) {
    const page = await fetchPage(from, from + dataPageSize - 1)
    if (page.error) return { data, error: page.error }
    const rows = page.data ?? []
    data.push(...rows)
    if (rows.length < dataPageSize) return { data, error: null }
  }
}

const tabs = [
  { id: 'overview', label: 'Beranda', icon: LayoutDashboard },
  { id: 'orders', label: 'Pesanan', icon: ReceiptText },
  { id: 'projects', label: 'Proyek', icon: PackageCheck },
  { id: 'incentives', label: 'Insentif', icon: Banknote },
  { id: 'analytics', label: 'Analitik', icon: BarChart3 },
  { id: 'requests', label: 'Pengajuan', icon: ClipboardCheck },
  { id: 'inventory', label: 'Stok', icon: PackageCheck },
  { id: 'services', label: 'Layanan & Harga', icon: ReceiptText },
  { id: 'customers', label: 'Pelanggan', icon: Contact },
  { id: 'team', label: 'Tim', icon: Users },
  { id: 'reports', label: 'Laporan', icon: Banknote },
  { id: 'audit', label: 'Audit', icon: ShieldCheck },
  { id: 'settings', label: 'Pengaturan', icon: Settings },
] as const

const navGroups = [
  { label: 'RINGKASAN', tabs: ['overview', 'analytics'] },
  { label: 'OPERASIONAL', tabs: ['orders', 'projects', 'customers', 'services', 'inventory'] },
  { label: 'TIM', tabs: ['team', 'requests'] },
  { label: 'KEUANGAN', tabs: ['incentives', 'reports'] },
  { label: 'KONTROL', tabs: ['audit', 'settings'] },
] as const satisfies ReadonlyArray<{
  label: string
  tabs: ReadonlyArray<(typeof tabs)[number]['id']>
}>

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
    { id: 'ord-1', order_number: 'IDL-20260817-0001', customer_name_snapshot: 'Budi Santoso', order_status: 'received', payment_status: 'unpaid', total_price: 45000, paid_amount: 0, note: '', due_at: new Date().toISOString(), assigned_employee_id: null, created_at: new Date().toISOString(), updated_at: new Date().toISOString() },
    { id: 'ord-2', order_number: 'IDL-20260817-0002', customer_name_snapshot: 'Siti Aminah', order_status: 'ready', payment_status: 'paid', total_price: 72000, paid_amount: 72000, note: '', due_at: new Date().toISOString(), assigned_employee_id: null, created_at: new Date().toISOString(), updated_at: new Date().toISOString() },
  ],
  cash: [
    { id: 'cash-1', type: 'IN', category: 'Pembayaran', description: 'Pembayaran order IDL-20260817-0002', amount: 72000, method: 'Tunai', reference_type: 'ORDER', created_at: new Date().toISOString() },
    { id: 'cash-2', type: 'OUT', category: 'Operasional', description: 'Pembelian plastik laundry', amount: 25000, method: 'Tunai', reference_type: 'MANUAL', created_at: new Date().toISOString() },
  ],
  customers: [{ id: 'cus-1', name: 'Budi Santoso', phone: '081234567800', address: 'Jl. Merdeka No. 1', created_at: new Date().toISOString() }],
  inventory: [
    { id: 'inv-1', name: 'Deterjen cair', stock: 2, unit: 'liter', min_stock: 5, purchase_price: 25000, note: '', is_active: true },
    { id: 'inv-2', name: 'Plastik laundry', stock: 80, unit: 'pcs', min_stock: 20, purchase_price: 500, note: '', is_active: true },
  ],
  shifts: [],
  inventoryMovements: [],
  auditLogs: [
    { id: 3, actor_role: 'OWNER', action: 'UPDATE', entity_table: 'laundry_projects', summary: 'Tarif proyek thrifting diperbarui', old_data: { unit_price: 6000 }, new_data: { unit_price: 6500 }, created_at: new Date().toISOString() },
    { id: 2, actor_role: 'EMPLOYEE', action: 'INSERT', entity_table: 'laundry_project_batches', summary: 'Ratna mencatat batch 112 kg / 230 pcs', old_data: null, new_data: { pieces: 230, weight_kg: 112 }, created_at: new Date(Date.now() - 3600000).toISOString() },
    { id: 1, actor_role: 'OWNER', action: 'UPDATE', entity_table: 'order_item_incentives', summary: 'Insentif sepatu dibayar', old_data: { paid_at: null }, new_data: { paid_method: 'Transfer' }, created_at: new Date(Date.now() - 7200000).toISOString() },
  ],
  shop: { id: 'demo-shop', name: 'Idola Laundry', phone: '081234567890', address: 'Alamat toko' },
  totalCustomers: 1,
}

function App() {
  const [activeTab, setActiveTab] = useState<(typeof tabs)[number]['id']>(() => {
    const requested = localPreview ? new URLSearchParams(window.location.search).get('tab') : null
    return tabs.find((tab) => tab.id === requested)?.id ?? 'overview'
  })
  const [mobileNavOpen, setMobileNavOpen] = useState(false)
  const [teamView, setTeamView] = useState<'employees' | 'shifts'>('employees')
  const [ordersView, setOrdersView] = useState<'list' | 'details' | 'services' | 'payments'>('list')
  const [profile, setProfile] = useState<Profile | null>(localPreview ? previewProfile : null)
  const [data, setData] = useState<DashboardData>(demoData)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState('')
  const [query, setQuery] = useState('')
  const [employeeEditor, setEmployeeEditor] = useState<Employee | 'new' | null>(null)
  const [customerEditor, setCustomerEditor] = useState<Customer | 'new' | null>(null)
  const [orderEditor, setOrderEditor] = useState<Order | null>(null)
  const [requestEditor, setRequestEditor] = useState<EmployeeRequest | null>(null)
  const [inventoryEditor, setInventoryEditor] = useState<InventoryItem | 'new' | null>(null)
  const [stockAdjuster, setStockAdjuster] = useState<InventoryItem | null>(null)
  const [shiftEditor, setShiftEditor] = useState<WeeklyShift | 'new' | null>(null)
  const [cashEditor, setCashEditor] = useState<CashTransaction | 'new' | null>(null)
  const [receiptOrder, setReceiptOrder] = useState<Order | null>(null)
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
        fetchAllPages<Order>((from, to) => supabase.from('orders').select('id, order_number, customer_name_snapshot, order_status, payment_status, total_price, paid_amount, note, due_at, assigned_employee_id, created_at, updated_at').eq('shop_id', shopId).gte('created_at', historyStart).order('created_at', { ascending: false }).range(from, to)),
        fetchAllPages<CashTransaction>((from, to) => supabase.from('cash_transactions').select('id, type, category, description, amount, method, reference_type, created_at').eq('shop_id', shopId).gte('created_at', historyStart).order('created_at', { ascending: false }).range(from, to)),
        fetchAllPages<Customer>((from, to) => supabase.from('customers').select('id, name, phone, address, created_at').eq('shop_id', shopId).is('deleted_at', null).order('created_at', { ascending: false }).range(from, to)),
        supabase.from('customers').select('id', { count: 'exact', head: true }).eq('shop_id', shopId).is('deleted_at', null),
        supabase.from('inventory_items').select('id, name, stock, unit, min_stock, purchase_price, note, is_active').eq('shop_id', shopId).order('name'),
        supabase.from('weekly_shifts').select('id, employee_id, employee_name, day_of_week, start_time, end_time, is_day_off').eq('shop_id', shopId).order('day_of_week'),
        supabase.from('inventory_movements').select('id, item_id, item_name, type, quantity, note, created_at').eq('shop_id', shopId).order('created_at', { ascending: false }).limit(30),
        supabase.from('audit_logs').select('id, actor_role, action, entity_table, summary, old_data, new_data, created_at').eq('shop_id', shopId).order('created_at', { ascending: false }).limit(100),
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
      }).eq('id', request.id).eq('shop_id', profile.shop_id).select('id').single()
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
        const employeeId = (employeeEditor as Employee).id
        const { error } = await supabase.from('employees').update({ name: values.name, phone: values.phone, position: values.position, shift_start: values.shift_start, shift_end: values.shift_end, late_tolerance_minutes: values.late_tolerance_minutes, is_active: values.is_active }).eq('id', employeeId).eq('shop_id', profile.shop_id).select('id').single()
        if (error) { setMessage(error.message); return }
        const { error: profileError } = await supabase.from('profiles').update({ full_name: values.name, phone: values.phone, is_active: values.is_active }).eq('employee_id', employeeId).eq('shop_id', profile.shop_id).select('id').single()
        if (profileError) setMessage(`Data karyawan tersimpan, tetapi profil login gagal diperbarui: ${profileError.message}`)
        else { setEmployeeEditor(null); setMessage(`Data ${values.name} berhasil disimpan.`); await loadDashboard(profile.shop_id) }
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
        const { error } = await supabase.from('customers').insert({ ...values, shop_id: profile.shop_id }).select('id').single()
        if (error) setMessage(error.message); else { setCustomerEditor(null); await loadDashboard(profile.shop_id) }
      } else if (customerEditor) {
        const { error } = await supabase.from('customers').update(values).eq('id', (customerEditor as Customer).id).eq('shop_id', profile.shop_id).select('id').single()
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
      }).eq('id', customer.id).eq('shop_id', profile.shop_id).select('id').single()
      if (error) setMessage(error.message); else await loadDashboard(profile.shop_id)
    } catch (e: any) {
      setMessage(e.message || 'Gagal menghapus pelanggan.')
    } finally {
      setLoading(false)
    }
  }

  async function deleteEmployee(employee: Employee) {
    if (!profile || !window.confirm(`Hapus atau nonaktifkan karyawan ${employee.name}?`)) return
    setLoading(true); setMessage('')
    try {
      const { error } = await supabase.from('employees').delete().eq('id', employee.id).eq('shop_id', profile.shop_id).select('id').single()
      if (error) {
        const { error: updErr } = await supabase.from('employees').update({ is_active: false }).eq('id', employee.id).eq('shop_id', profile.shop_id).select('id').single()
        await supabase.from('profiles').update({ is_active: false }).eq('employee_id', employee.id).eq('shop_id', profile.shop_id)
        if (updErr) setMessage(updErr.message)
        else { setMessage(`Karyawan ${employee.name} dinonaktifkan karena memiliki riwayat operasional.`); await loadDashboard(profile.shop_id) }
      } else {
        await supabase.from('profiles').delete().eq('employee_id', employee.id).eq('shop_id', profile.shop_id)
        setMessage(`Karyawan ${employee.name} berhasil dihapus.`)
        await loadDashboard(profile.shop_id)
      }
    } catch (e: any) {
      setMessage(e.message || 'Gagal menghapus karyawan.')
    } finally {
      setLoading(false)
    }
  }

  async function addInventoryItem(values: InventoryFormValues) {
    if (!profile) return
    setLoading(true); setMessage('')
    try {
      const { error } = inventoryEditor === 'new'
        ? await supabase.from('inventory_items').insert({ ...values, shop_id: profile.shop_id }).select('id').single()
        : await supabase.from('inventory_items').update({ name: values.name, unit: values.unit, min_stock: values.min_stock, purchase_price: values.purchase_price, note: values.note, is_active: values.is_active }).eq('id', (inventoryEditor as InventoryItem).id).eq('shop_id', profile.shop_id).select('id').single()
      if (error) setMessage(error.message); else { setInventoryEditor(null); await loadDashboard(profile.shop_id) }
    } catch (e: any) {
      setMessage(e.message || 'Gagal menambahkan barang.')
    } finally {
      setLoading(false)
    }
  }

  async function deleteInventoryItem(item: InventoryItem) {
    if (!profile || !window.confirm(`Hapus item persediaan ${item.name}?`)) return
    setLoading(true); setMessage('')
    try {
      const { error } = await supabase.from('inventory_items').delete().eq('id', item.id).eq('shop_id', profile.shop_id).select('id').single()
      if (error) {
        const { error: updErr } = await supabase.from('inventory_items').update({ is_active: false }).eq('id', item.id).eq('shop_id', profile.shop_id).select('id').single()
        if (updErr) setMessage(updErr.message)
        else { setMessage(`Item ${item.name} dinonaktifkan karena memiliki riwayat mutasi stok.`); await loadDashboard(profile.shop_id) }
      } else {
        setMessage(`Item ${item.name} berhasil dihapus.`)
        await loadDashboard(profile.shop_id)
      }
    } catch (e: any) {
      setMessage(e.message || 'Gagal menghapus item persediaan.')
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
      const { error } = await supabase.from('orders').update({ order_status: status, updated_at: new Date().toISOString() }).eq('id', order.id).eq('shop_id', profile.shop_id).select('id').single()
      if (error) setMessage(error.message); else await loadDashboard(profile.shop_id)
    } catch (e: any) {
      setMessage(e.message || 'Gagal memperbarui status pesanan.')
    } finally {
      setLoading(false)
    }
  }

  async function deleteOrder(order: Order) {
    if (!profile) return
    if (order.paid_amount > 0) {
      if (!window.confirm(`Pesanan ${order.order_number} memiliki catatan pembayaran (${rupiah(order.paid_amount)}). Batalkan pesanan ini (ubah status ke Dibatalkan)?`)) return
      await updateOrderStatus(order, 'cancelled')
      return
    }
    if (!window.confirm(`Hapus permanen pesanan ${order.order_number} (${order.customer_name_snapshot})?`)) return
    setLoading(true); setMessage('')
    try {
      await supabase.from('order_items').delete().eq('order_id', order.id).eq('shop_id', profile.shop_id)
      const { error } = await supabase.from('orders').delete().eq('id', order.id).eq('shop_id', profile.shop_id).select('id').single()
      if (error) {
        await updateOrderStatus(order, 'cancelled')
        setMessage('Pesanan dibatalkan karena memiliki riwayat transaksi/log.')
      } else {
        setMessage(`Pesanan ${order.order_number} berhasil dihapus.`)
        await loadDashboard(profile.shop_id)
      }
    } catch (e: any) {
      setMessage(e.message || 'Gagal menghapus pesanan.')
    } finally {
      setLoading(false)
    }
  }

  async function saveOrderDetails(values: { note: string; due_at: string; assigned_employee_id: string | null }) {
    if (!profile || !orderEditor) return
    setLoading(true); setMessage('')
    try {
      const { error } = await supabase.from('orders').update({ ...values, updated_at: new Date().toISOString() }).eq('id', orderEditor.id).eq('shop_id', profile.shop_id).select('id').single()
      if (error) setMessage(error.message)
      else { setOrderEditor(null); await loadDashboard(profile.shop_id) }
    } catch (e: any) { setMessage(e.message || 'Gagal mengubah pesanan.') }
    finally { setLoading(false) }
  }

  async function saveRequestDetails(values: { reason: string; amount: number; review_note: string }) {
    if (!profile || !requestEditor) return
    setLoading(true); setMessage('')
    try {
      const { error } = await supabase.from('employee_requests').update(values).eq('id', requestEditor.id).eq('shop_id', profile.shop_id).select('id').single()
      if (error) setMessage(error.message)
      else { setRequestEditor(null); await loadDashboard(profile.shop_id) }
    } catch (e: any) { setMessage(e.message || 'Gagal mengubah pengajuan.') }
    finally { setLoading(false) }
  }

  async function deleteRequest(request: EmployeeRequest) {
    if (!profile || !window.confirm(`Hapus pengajuan "${request.type}" (${request.employee_name})?`)) return
    setLoading(true); setMessage('')
    try {
      const { error } = await supabase.from('employee_requests').delete().eq('id', request.id).eq('shop_id', profile.shop_id).select('id').single()
      if (error) {
        const { error: updErr } = await supabase.from('employee_requests').update({ status: 'rejected', review_note: 'Dibatalkan oleh Owner' }).eq('id', request.id).eq('shop_id', profile.shop_id).select('id').single()
        if (updErr) setMessage(updErr.message)
        else { setMessage('Pengajuan ditandai ditolak.'); await loadDashboard(profile.shop_id) }
      } else {
        setMessage('Pengajuan berhasil dihapus.')
        await loadDashboard(profile.shop_id)
      }
    } catch (e: any) {
      setMessage(e.message || 'Gagal menghapus pengajuan.')
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
        ? supabase.from('weekly_shifts').upsert(payload, { onConflict: 'shop_id,employee_id,day_of_week' }).select('id').single()
        : supabase.from('weekly_shifts').update(payload).eq('id', (shiftEditor as WeeklyShift).id).eq('shop_id', profile.shop_id).select('id').single()
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
      const { error } = await supabase.from('weekly_shifts').delete().eq('id', shift.id).eq('shop_id', profile.shop_id).select('id').single()
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
      const { error } = cashEditor === 'new'
        ? await supabase.from('cash_transactions').insert({ ...values, shop_id: profile.shop_id, reference_type: 'MANUAL' }).select('id').single()
        : await supabase.from('cash_transactions').update(values).eq('id', (cashEditor as CashTransaction).id).eq('shop_id', profile.shop_id).eq('reference_type', 'MANUAL').select('id').single()
      if (error) setMessage(error.message); else { setCashEditor(null); await loadDashboard(profile.shop_id) }
    } catch (e: any) {
      setMessage(e.message || 'Gagal menyimpan kas.')
    } finally {
      setLoading(false)
    }
  }

  async function deleteCashTransaction(entry: CashTransaction) {
    if (!profile || !window.confirm(`Hapus catatan kas "${entry.category} - ${rupiah(entry.amount)}"?`)) return
    if (entry.reference_type && entry.reference_type !== 'MANUAL') {
      setMessage('Hanya mutasi kas manual yang dapat dihapus agar saldo transaksi pesanan/proyek tetap sinkron.')
      return
    }
    setLoading(true); setMessage('')
    try {
      const { error } = await supabase.from('cash_transactions').delete().eq('id', entry.id).eq('shop_id', profile.shop_id).select('id').single()
      if (error) setMessage(error.message)
      else { setMessage('Catatan kas berhasil dihapus.'); await loadDashboard(profile.shop_id) }
    } catch (e: any) {
      setMessage(e.message || 'Gagal menghapus catatan kas.')
    } finally {
      setLoading(false)
    }
  }

  async function saveShop(values: ShopFormValues) {
    if (!profile) return
    setLoading(true); setMessage('')
    try {
      const { error } = await supabase.from('shops').update(values).eq('id', profile.shop_id).select('id').single()
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
        <p className="nav-caption">NAVIGASI</p>
        <nav className="nav-list" aria-label="Menu admin">
          {navGroups.map((group) => <section className="nav-group" key={group.label} aria-label={group.label}><p className="nav-group-label">{group.label}</p>{group.tabs.map((tabId) => { const tab = tabs.find((item) => item.id === tabId)!; const Icon = tab.icon; return <button key={tab.id} className={activeTab === tab.id ? 'active' : ''} type="button" onClick={() => navigate(tab.id)} aria-current={activeTab === tab.id ? 'page' : undefined}><Icon size={18} /><span>{tab.label}</span>{tab.id === 'requests' && metrics.pendingRequests > 0 ? <b className="nav-count">{metrics.pendingRequests}</b> : null}</button> })}</section>)}
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
        {activeTab === 'orders' ? <><nav className="module-subnav" aria-label="Kelola pesanan"><button type="button" className={ordersView === 'list' ? 'active' : ''} onClick={() => setOrdersView('list')}>Daftar & status</button><button type="button" className={ordersView === 'details' ? 'active' : ''} onClick={() => setOrdersView('details')}>Edit detail</button><button type="button" className={ordersView === 'services' ? 'active' : ''} onClick={() => setOrdersView('services')}>Layanan kiloan</button><button type="button" className={ordersView === 'payments' ? 'active' : ''} onClick={() => setOrdersView('payments')}>Koreksi pembayaran</button></nav>{ordersView === 'list' ? <OrdersPanel orders={filteredOrders} onUpdateOrder={updateOrderStatus} onRecordPayment={recordPayment} onPrintOrder={setReceiptOrder} onDeleteOrder={deleteOrder} /> : null}{ordersView === 'details' ? <OwnerEditAccess title="Edit detail pesanan" entries={filteredOrders} label={(order) => `${order.order_number} · ${order.customer_name_snapshot}`} onEdit={setOrderEditor} /> : null}{ordersView === 'services' ? <OrderKiloServiceEditor shopId={profile.shop_id} orders={filteredOrders} onChanged={() => void loadDashboard(profile.shop_id)} /> : null}{ordersView === 'payments' ? <OrderPaymentCorrections shopId={profile.shop_id} orders={filteredOrders} onChanged={() => void loadDashboard(profile.shop_id)} /> : null}</> : null}
        {activeTab === 'projects' ? <ProjectsPanel shopId={profile.shop_id} onCashChanged={() => void loadDashboard(profile.shop_id)} /> : null}
        {activeTab === 'incentives' ? <IncentivesPanel shopId={profile.shop_id} employees={data.employees} orders={data.orders} onCashChanged={() => void loadDashboard(profile.shop_id)} /> : null}
        {activeTab === 'analytics' ? <DashboardAnalytics orders={data.orders} cash={data.cash} employees={data.employees} inventory={data.inventory} /> : null}
        {activeTab === 'requests' ? <><ApprovalPanel requests={data.requests} loading={loading} onReview={reviewRequest} onDelete={deleteRequest} /><OwnerEditAccess title="Edit isi pengajuan" entries={data.requests} label={(request) => `${request.employee_name} · ${request.type}`} onEdit={setRequestEditor} /></> : null}
        {activeTab === 'inventory' ? <><InventoryPanel items={data.inventory} movements={data.inventoryMovements} onAdd={() => setInventoryEditor('new')} onEdit={setInventoryEditor} onDelete={deleteInventoryItem} onAdjust={setStockAdjuster} /><OwnerEditAccess title="Edit item stok" entries={data.inventory} label={(item) => item.name} onEdit={setInventoryEditor} /></> : null}
        {activeTab === 'services' ? <ServicesPanel shopId={profile.shop_id} /> : null}
        {activeTab === 'customers' ? <CustomersPanel customers={filteredCustomers} onAdd={() => setCustomerEditor('new')} onEdit={setCustomerEditor} onDelete={deleteCustomer} /> : null}
        {activeTab === 'team' ? <TeamPanel view={teamView} setView={setTeamView} employees={filteredEmployees} shifts={data.shifts} onAdd={() => setEmployeeEditor('new')} onEdit={setEmployeeEditor} onDelete={deleteEmployee} onAddShift={() => setShiftEditor('new')} onEditShift={setShiftEditor} /> : null}
        {activeTab === 'reports' ? <><ReportsPanel cash={data.cash} metrics={metrics} onAddCash={() => setCashEditor('new')} onExport={exportCashCsv} onEditCash={setCashEditor} onDeleteCash={deleteCashTransaction} /><OwnerEditAccess title="Koreksi kas manual" entries={data.cash.filter((entry) => entry.reference_type === 'MANUAL')} label={(entry) => `${entry.category} · ${rupiah(entry.amount)} · ${dateLabel(entry.created_at)}`} onEdit={setCashEditor} /></> : null}
        {activeTab === 'audit' ? <AuditPanel logs={data.auditLogs} /> : null}
        {activeTab === 'settings' ? <SettingsPanel shop={data.shop} loading={loading} onSave={saveShop} /> : null}
      </section>

      {employeeEditor ? <Modal title={employeeEditor === 'new' ? 'Tambah karyawan & akun' : 'Edit karyawan dan shift'} onClose={() => setEmployeeEditor(null)}><EmployeeForm employee={employeeEditor === 'new' ? null : employeeEditor} loading={loading} onSubmit={saveEmployee} /></Modal> : null}
      {customerEditor ? <Modal title={customerEditor === 'new' ? 'Tambah pelanggan' : 'Edit pelanggan'} onClose={() => setCustomerEditor(null)}><CustomerForm customer={customerEditor === 'new' ? null : customerEditor} loading={loading} onSubmit={saveCustomer} /></Modal> : null}
      {orderEditor ? <Modal title={`Edit ${orderEditor.order_number}`} onClose={() => setOrderEditor(null)}><OrderDetailsForm order={orderEditor} employees={data.employees} loading={loading} onSubmit={saveOrderDetails} /></Modal> : null}
      {requestEditor ? <Modal title="Edit pengajuan" onClose={() => setRequestEditor(null)}><RequestDetailsForm request={requestEditor} loading={loading} onSubmit={saveRequestDetails} /></Modal> : null}
      {inventoryEditor ? <Modal title={inventoryEditor === 'new' ? 'Tambah item stok' : 'Edit item stok'} onClose={() => setInventoryEditor(null)}>{inventoryEditor === 'new' ? <InventoryForm loading={loading} onSubmit={addInventoryItem} /> : <EditInventoryForm item={inventoryEditor} loading={loading} onSubmit={addInventoryItem} />}</Modal> : null}
      {stockAdjuster ? <Modal title={`Mutasi ${stockAdjuster.name}`} onClose={() => setStockAdjuster(null)}><StockAdjustmentForm item={stockAdjuster} loading={loading} onSubmit={adjustStock} /></Modal> : null}
      {shiftEditor ? <Modal title={shiftEditor === 'new' ? 'Tambah jadwal mingguan' : 'Edit jadwal mingguan'} onClose={() => setShiftEditor(null)}><ShiftForm shift={shiftEditor === 'new' ? null : shiftEditor} employees={data.employees} loading={loading} onSubmit={saveShift} onDelete={shiftEditor === 'new' ? undefined : () => void deleteShift(shiftEditor)} /></Modal> : null}
      {cashEditor ? <Modal title={cashEditor === 'new' ? 'Catat kas manual' : 'Edit kas manual'} onClose={() => setCashEditor(null)}>{cashEditor === 'new' ? <CashForm loading={loading} onSubmit={addCashTransaction} /> : <EditCashForm entry={cashEditor} loading={loading} onSubmit={addCashTransaction} onDelete={deleteCashTransaction} />}</Modal> : null}
      {receiptOrder ? <ReceiptModal order={receiptOrder} shop={data.shop} onClose={() => setReceiptOrder(null)} /> : null}
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

function ReceiptModal({ order, shop, onClose }: { order: Order; shop: Shop | null; onClose: () => void }) {
  const remaining = Math.max(0, order.total_price - order.paid_amount)
  return (
    <div className="modal-backdrop" role="presentation" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose() }}>
      <section className="modal receipt-modal-box" role="dialog" aria-modal="true" aria-label="Cetak Nota">
        <header>
          <h2>Cetak Nota / Struk</h2>
          <button className="icon-button" type="button" onClick={onClose} aria-label="Tutup"><X size={18} /></button>
        </header>
        <div className="printable-receipt" id="printable-receipt">
          <div className="receipt-header">
            <h3>{shop?.name || 'Idola Laundry'}</h3>
            <p>{shop?.address || 'Jl. Operasional Toko'}</p>
            <p>Telp: {shop?.phone || '-'}</p>
          </div>
          <div className="receipt-divider" />
          <div className="receipt-meta">
            <div><span>No. Nota:</span><strong>{order.order_number}</strong></div>
            <div><span>Tanggal:</span><span>{new Date(order.created_at).toLocaleString('id-ID')}</span></div>
            <div><span>Pelanggan:</span><strong>{order.customer_name_snapshot}</strong></div>
            {order.due_at ? <div><span>Estimasi:</span><span>{new Date(order.due_at).toLocaleDateString('id-ID')}</span></div> : null}
          </div>
          <div className="receipt-divider" />
          <div className="receipt-totals">
            <div><span>Total Tagihan:</span><strong>{rupiah(order.total_price)}</strong></div>
            <div><span>Sudah Dibayar:</span><span>{rupiah(order.paid_amount)}</span></div>
            <div><span>Status Bayar:</span><strong>{statusLabels[order.payment_status] || order.payment_status}</strong></div>
            {remaining > 0 ? (
              <div className="receipt-unpaid">
                <span>Sisa Tagihan:</span>
                <strong>{rupiah(remaining)}</strong>
              </div>
            ) : (
              <div style={{ color: '#059669', fontWeight: 700 }}>
                <span>Status:</span>
                <strong>LUNAS</strong>
              </div>
            )}
          </div>
          {order.note ? (
            <div className="receipt-note" style={{ marginTop: '8px', fontSize: '11px', color: '#475467' }}>
              Catatan: {order.note}
            </div>
          ) : null}
          <div className="receipt-divider" />
          <div className="receipt-footer">
            <p>Terima kasih atas kepercayaan Anda!</p>
            <small>Cucian yang tidak diambil lebih dari 30 hari di luar tanggung jawab toko.</small>
          </div>
        </div>
        <div className="form-actions" style={{ marginTop: '18px' }}>
          <button className="primary-button" type="button" onClick={() => window.print()}>
            <Printer size={18} /> Cetak Struk
          </button>
          <button className="ghost-button" type="button" onClick={onClose}>
            Tutup
          </button>
        </div>
      </section>
    </div>
  )
}

function DashboardAnalytics({ orders, cash = [], employees = [], inventory = [] }: { orders: Order[]; cash?: CashTransaction[]; employees?: Employee[]; inventory?: InventoryItem[] }) {
  const [chartMode, setChartMode] = useState<'cashflow' | 'orders' | 'payments' | 'peakdays'>('cashflow')
  const [period, setPeriod] = useState<'week' | 'month'>('week')
  const [selectedMonth, setSelectedMonth] = useState(monthKey(new Date()))
  const monthOptions = calendarMonthOptions(orders)
  const orderDays = period === 'week' ? calendarWeekSeries(orders) : calendarMonthSeries(orders, selectedMonth)
  const cashDays = period === 'week' ? calendarWeekCashflow(cash) : calendarMonthCashflow(cash, selectedMonth)
  const periodLabel = period === 'week' ? 'minggu ini' : new Intl.DateTimeFormat('id-ID', { month: 'long', year: 'numeric' }).format(new Date(`${selectedMonth}-01T12:00:00`))

  const maxOrders = Math.max(1, ...orderDays.map((day) => Math.max(day.received, day.completed)))
  const visibleKeys = new Set(orderDays.map((day) => day.key))
  const selectedOrders = orders.filter((order) => visibleKeys.has(localDayKey(order.created_at)))
  const statusRows = [
    ['received', 'Diterima'],
    ['processing', 'Diproses'],
    ['ready', 'Siap diambil'],
    ['picked_up', 'Sudah diambil'],
    ['cancelled', 'Dibatalkan'],
  ].map(([id, label]) => ({ id, label, count: selectedOrders.filter((order) => order.order_status === id).length }))
  const statusTotal = Math.max(1, statusRows.reduce((sum, row) => sum + row.count, 0))
  const unpaid = orders.filter((order) => order.payment_status !== 'paid').reduce((sum, order) => sum + Math.max(0, order.total_price - order.paid_amount), 0)
  const periodOrders = orderDays.reduce((sum, day) => sum + day.received, 0)
  const periodCompleted = orderDays.reduce((sum, day) => sum + day.completed, 0)

  const maxCash = Math.max(1, ...cashDays.map((day) => Math.max(day.income, day.expense)))
  const totalIncome = cashDays.reduce((sum, day) => sum + day.income, 0)
  const totalExpense = cashDays.reduce((sum, day) => sum + day.expense, 0)
  const netProfit = totalIncome - totalExpense

  const selectedCash = cash.filter((c) => visibleKeys.has(localDayKey(c.created_at)))
  const methodMap: Record<string, { count: number; total: number }> = {
    Tunai: { count: 0, total: 0 },
    Transfer: { count: 0, total: 0 },
    QRIS: { count: 0, total: 0 },
  }
  selectedCash.filter((c) => c.type === 'IN').forEach((c) => {
    const m = (c.method || 'Tunai').trim()
    const key = m.toLowerCase().includes('qris') ? 'QRIS' : m.toLowerCase().includes('transfer') ? 'Transfer' : 'Tunai'
    methodMap[key].count += 1
    methodMap[key].total += c.amount
  })
  const paymentTotalAmount = Math.max(1, methodMap.Tunai.total + methodMap.Transfer.total + methodMap.QRIS.total)

  const dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu']
  const peakDayCounts = [1, 2, 3, 4, 5, 6, 7].map((d, index) => {
    const count = orders.filter((o) => {
      const day = new Date(o.created_at).getDay()
      const dIndex = day === 0 ? 7 : day
      return dIndex === d
    }).length
    return { dayNumber: d, name: dayNames[index], count }
  })
  const maxPeak = Math.max(1, ...peakDayCounts.map((d) => d.count))
  const busiestDay = peakDayCounts.reduce((prev, curr) => curr.count > prev.count ? curr : prev, peakDayCounts[0])

  return (
    <section className="analytics-section">
      <div className="analytics-top-nav">
        <SegmentedControl
          value={chartMode}
          items={[
            ['cashflow', 'Arus Kas & Finansial'],
            ['orders', 'Progres Pesanan'],
            ['payments', 'Metode Bayar'],
            ['peakdays', 'Hari Tersibuk'],
          ]}
          onChange={setChartMode}
        />
        <div className="chart-controls">
          <SegmentedControl value={period} items={[["week", 'Minggu ini'], ["month", 'Per bulan']]} onChange={setPeriod} />
          {period === 'month' ? (
            <select className="month-select" aria-label="Pilih bulan" value={selectedMonth} onChange={(event) => setSelectedMonth(event.target.value)}>
              {monthOptions.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
            </select>
          ) : null}
        </div>
      </div>

      <div className="period-caption" style={{ marginBottom: '16px' }}>
        Periode Analisis: <strong>{period === 'week' ? weekRangeLabel(orderDays) : periodLabel}</strong>
      </div>

      <div className="metrics-grid" style={{ marginBottom: '20px' }}>
        <article className="metric-card">
          <TrendingUp size={20} style={{ color: '#059669' }} />
          <strong>{rupiah(totalIncome)}</strong>
          <span>Total Pemasukan</span>
        </article>
        <article className="metric-card">
          <TrendingDown size={20} style={{ color: '#d97706' }} />
          <strong>{rupiah(totalExpense)}</strong>
          <span>Total Pengeluaran</span>
        </article>
        <article className="metric-card">
          <Banknote size={20} style={{ color: netProfit >= 0 ? '#0b2d71' : '#b42318' }} />
          <strong style={{ color: netProfit >= 0 ? '#0b2d71' : '#b42318' }}>{rupiah(netProfit)}</strong>
          <span>Laba Bersih Operasional</span>
        </article>
        <article className="metric-card">
          <ReceiptText size={20} />
          <strong>{periodOrders} pesanan</strong>
          <span>Volume Masuk ({periodCompleted} selesai)</span>
        </article>
      </div>

      {chartMode === 'cashflow' ? (
        <div className="analytics-grid">
          <article className="wide-panel chart-panel">
            <div className="panel-header chart-header">
              <div>
                <h2>Grafik Arus Kas</h2>
                <p>Perbandingan uang masuk dan uang keluar toko per {period === 'week' ? 'hari' : 'tanggal'}.</p>
              </div>
            </div>
            <div className="chart-legend">
              <span><i className="legend-dot income" />Pemasukan</span>
              <span><i className="legend-dot expense" />Pengeluaran</span>
            </div>
            <div className={`cash-chart period-${period}`} role="img" aria-label={`Grafik arus kas ${periodLabel}`}>
              <div className="chart-scroll-inner" style={{ gridTemplateColumns: `repeat(${cashDays.length}, minmax(${period === 'month' ? 24 : 54}px, 1fr))` }}>
                {cashDays.map((day) => (
                  <div className="chart-day" key={day.key}>
                    <div className="bar-area">
                      <div className="chart-bar income" style={{ height: `${Math.max(day.income ? 8 : 0, day.income / maxCash * 100)}%` }} title={`Masuk ${day.fullLabel}: ${rupiah(day.income)}`} />
                      <div className="chart-bar expense" style={{ height: `${Math.max(day.expense ? 8 : 0, day.expense / maxCash * 100)}%` }} title={`Keluar ${day.fullLabel}: ${rupiah(day.expense)}`} />
                    </div>
                    <strong>{day.income > 0 ? (day.income >= 1000000 ? `${(day.income / 1000000).toFixed(1)}jt` : `${Math.round(day.income / 1000)}k`) : '0'}</strong>
                    <span>{day.label}</span>
                  </div>
                ))}
              </div>
            </div>
            <p className="chart-footnote">Format label atas: ringkasan pemasukan. Hover bar untuk melihat rincian.</p>
          </article>

          <article className="wide-panel chart-panel">
            <PanelHeader title="Ringkasan Margin" description={`Efisiensi keuangan ${periodLabel}.`} />
            <div className="status-summary">
              <div className="status-line">
                <div><span>Total Pemasukan</span><strong>{rupiah(totalIncome)}</strong></div>
                <div className="status-track"><i style={{ width: '100%', background: '#0f766e' }} /></div>
              </div>
              <div className="status-line">
                <div><span>Total Pengeluaran</span><strong>{rupiah(totalExpense)}</strong></div>
                <div className="status-track"><i style={{ width: `${totalIncome > 0 ? Math.min(100, totalExpense / totalIncome * 100) : 0}%`, background: '#f59e0b' }} /></div>
              </div>
              <div className="status-line">
                <div><span>Margin Laba</span><strong>{totalIncome > 0 ? `${Math.round(netProfit / totalIncome * 100)}%` : '0%'}</strong></div>
                <div className="status-track"><i style={{ width: `${totalIncome > 0 && netProfit > 0 ? Math.min(100, netProfit / totalIncome * 100) : 0}%`, background: '#2563eb' }} /></div>
              </div>
            </div>
            <div className="receivable-card" style={{ marginTop: '20px' }}>
              <span>Piutang Pesanan Berjalan</span>
              <strong>{rupiah(unpaid)}</strong>
              <small>Tagihan dari pelanggan yang belum lunas</small>
            </div>
          </article>
        </div>
      ) : null}

      {chartMode === 'orders' ? (
        <div className="analytics-grid">
          <article className="wide-panel chart-panel">
            <div className="panel-header chart-header">
              <div>
                <h2>Progres Pesanan Masuk & Selesai</h2>
                <p>Volume pesanan yang masuk dan diselesaikan tim operasional.</p>
              </div>
            </div>
            <div className="progress-totals">
              <div><span>Masuk</span><strong>{periodOrders}</strong></div>
              <div><span>Selesai</span><strong>{periodCompleted}</strong></div>
              <div><span>Tingkat Selesai</span><strong>{periodOrders ? `${Math.round(periodCompleted / periodOrders * 100)}%` : '0%'}</strong></div>
            </div>
            <div className="chart-legend">
              <span><i className="legend-dot received" />Pesanan Masuk</span>
              <span><i className="legend-dot completed" />Selesai</span>
            </div>
            <div className={`cash-chart order-chart period-${period}`} role="img" aria-label={`Grafik pesanan ${periodLabel}`}>
              <div className="chart-scroll-inner" style={{ gridTemplateColumns: `repeat(${orderDays.length}, minmax(${period === 'month' ? 24 : 54}px, 1fr))` }}>
                {orderDays.map((day) => (
                  <div className="chart-day" key={day.key}>
                    <div className="bar-area">
                      <div className="chart-bar received" style={{ height: `${Math.max(day.received ? 8 : 0, day.received / maxOrders * 100)}%` }} title={`Masuk ${day.fullLabel}: ${day.received}`} />
                      <div className="chart-bar completed" style={{ height: `${Math.max(day.completed ? 8 : 0, day.completed / maxOrders * 100)}%` }} title={`Selesai ${day.fullLabel}: ${day.completed}`} />
                    </div>
                    <strong>{day.received}/{day.completed}</strong>
                    <span>{day.label}</span>
                  </div>
                ))}
              </div>
            </div>
            <p className="chart-footnote">Format angka: masuk/selesai. Angka selesai dihitung saat status Siap Diambil atau Diambil.</p>
          </article>

          <article className="wide-panel chart-panel">
            <PanelHeader title="Posisi Status Pesanan" description={`Status seluruh pesanan pada periode ${periodLabel}.`} />
            <div className="status-summary">
              {statusRows.map((row) => (
                <div className="status-line" key={row.id}>
                  <div><span>{row.label}</span><strong>{row.count}</strong></div>
                  <div className="status-track"><i className={row.id} style={{ width: `${row.count / statusTotal * 100}%` }} /></div>
                </div>
              ))}
            </div>
            <div className="receivable-card" style={{ marginTop: '20px' }}>
              <span>Total Pesanan Terdaftar</span>
              <strong>{orders.length} pesanan</strong>
              <small>Semua pesanan tersimpan di database</small>
            </div>
          </article>
        </div>
      ) : null}

      {chartMode === 'payments' ? (
        <div className="analytics-grid">
          <article className="wide-panel chart-panel">
            <PanelHeader title="Distribusi Metode Pembayaran" description="Komposisi pembayaran yang diterima (Tunai, Transfer, QRIS)." />
            <div className="payment-method-grid" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '14px', marginBottom: '22px' }}>
              <div className="method-stat-card" style={{ padding: '16px', background: '#f0fdf4', borderRadius: '8px', border: '1px solid #bbf7d0' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#166534', fontWeight: 700 }}><Wallet size={18} /> Tunai</div>
                <strong style={{ display: 'block', fontSize: '20px', margin: '8px 0 4px', color: '#14532d' }}>{rupiah(methodMap.Tunai.total)}</strong>
                <small style={{ color: '#166534' }}>{methodMap.Tunai.count} transaksi ({Math.round(methodMap.Tunai.total / paymentTotalAmount * 100)}%)</small>
              </div>
              <div className="method-stat-card" style={{ padding: '16px', background: '#eff6ff', borderRadius: '8px', border: '1px solid #bfdbfe' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#1e40af', fontWeight: 700 }}><CreditCard size={18} /> Transfer Bank</div>
                <strong style={{ display: 'block', fontSize: '20px', margin: '8px 0 4px', color: '#1e3a8a' }}>{rupiah(methodMap.Transfer.total)}</strong>
                <small style={{ color: '#1e40af' }}>{methodMap.Transfer.count} transaksi ({Math.round(methodMap.Transfer.total / paymentTotalAmount * 100)}%)</small>
              </div>
              <div className="method-stat-card" style={{ padding: '16px', background: '#faf5ff', borderRadius: '8px', border: '1px solid #e9d5ff' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#6b21a8', fontWeight: 700 }}><QrCode size={18} /> QRIS</div>
                <strong style={{ display: 'block', fontSize: '20px', margin: '8px 0 4px', color: '#581c87' }}>{rupiah(methodMap.QRIS.total)}</strong>
                <small style={{ color: '#6b21a8' }}>{methodMap.QRIS.count} transaksi ({Math.round(methodMap.QRIS.total / paymentTotalAmount * 100)}%)</small>
              </div>
            </div>

            <div className="status-summary">
              <div className="status-line">
                <div><span>Tunai (Kas Fisik Toko)</span><strong>{rupiah(methodMap.Tunai.total)}</strong></div>
                <div className="status-track"><i style={{ width: `${methodMap.Tunai.total / paymentTotalAmount * 100}%`, background: '#16a34a' }} /></div>
              </div>
              <div className="status-line">
                <div><span>Transfer Bank</span><strong>{rupiah(methodMap.Transfer.total)}</strong></div>
                <div className="status-track"><i style={{ width: `${methodMap.Transfer.total / paymentTotalAmount * 100}%`, background: '#2563eb' }} /></div>
              </div>
              <div className="status-line">
                <div><span>QRIS</span><strong>{rupiah(methodMap.QRIS.total)}</strong></div>
                <div className="status-track"><i style={{ width: `${methodMap.QRIS.total / paymentTotalAmount * 100}%`, background: '#9333ea' }} /></div>
              </div>
            </div>
          </article>

          <article className="wide-panel chart-panel">
            <PanelHeader title="Keamanan Kas & Rekonsiliasi" description="Zero Leakage: sinkronisasi pembayaran pesanan ke Buku Kas." />
            <div style={{ display: 'grid', gap: '14px', marginTop: '14px' }}>
              <div style={{ padding: '14px', background: '#f8fafc', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
                <p style={{ margin: '0 0 6px', fontWeight: 700, color: '#334155' }}>Rekonsiliasi Kas Fisik</p>
                <p style={{ margin: 0, fontSize: '12px', color: '#64748b' }}>Uang fisik di kasir harus sesuai nominal Tunai ({rupiah(methodMap.Tunai.total)}) pada akhir hari saat tutup toko.</p>
              </div>
              <div style={{ padding: '14px', background: '#f8fafc', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
                <p style={{ margin: '0 0 6px', fontWeight: 700, color: '#334155' }}>Rekening Digital</p>
                <p style={{ margin: 0, fontSize: '12px', color: '#64748b' }}>Nominal Transfer ({rupiah(methodMap.Transfer.total)}) & QRIS ({rupiah(methodMap.QRIS.total)}) langsung diverifikasi mutasi bank.</p>
              </div>
            </div>
          </article>
        </div>
      ) : null}

      {chartMode === 'peakdays' ? (
        <div className="analytics-grid">
          <article className="wide-panel chart-panel">
            <PanelHeader title="Analisis Hari Paling Ramai (Peak Days)" description="Jumlah pesanan cucian yang masuk berdasarkan hari dalam seminggu." />
            <div className="cash-chart period-week" role="img" aria-label="Grafik hari ramai">
              <div className="chart-scroll-inner" style={{ gridTemplateColumns: 'repeat(7, 1fr)' }}>
                {peakDayCounts.map((item) => (
                  <div className="chart-day" key={item.dayNumber}>
                    <div className="bar-area">
                      <div className="chart-bar received" style={{ height: `${Math.max(item.count ? 8 : 0, item.count / maxPeak * 100)}%`, background: item.name === busiestDay.name ? 'linear-gradient(180deg, #f59e0b, #fbbf24)' : undefined }} title={`${item.name}: ${item.count} pesanan`} />
                    </div>
                    <strong>{item.count}</strong>
                    <span style={{ fontWeight: item.name === busiestDay.name ? 800 : undefined, color: item.name === busiestDay.name ? '#b45309' : undefined }}>{item.name}</span>
                  </div>
                ))}
              </div>
            </div>
            <p className="chart-footnote">Warna oranye menandakan hari dengan pesanan tertinggi sepanjang histori.</p>
          </article>

          <article className="wide-panel chart-panel">
            <PanelHeader title="Rekomendasi Jadwal & Shift" description="Berdasarkan tren volume pesanan pelanggan." />
            <div style={{ padding: '18px', background: '#fffbeb', borderRadius: '8px', border: '1px solid #fde68a', marginBottom: '16px' }}>
              <div style={{ color: '#92400e', fontWeight: 800, fontSize: '15px' }}>
                Hari Tersibuk: {busiestDay.name} ({busiestDay.count} pesanan)
              </div>
              <p style={{ margin: '6px 0 0', fontSize: '13px', color: '#78350f' }}>
                Pastikan seluruh staf operasional cuci & setrika bertugas penuh pada hari {busiestDay.name} untuk mencegah penumpukan antrean cucian. Tim saat ini: {employees.filter((e) => e.is_active).length} staf aktif, {inventory.filter((i) => i.is_active && i.stock <= i.min_stock).length} stok bahan menipis.
              </p>
            </div>
            <Checklist items={[
              'Atur jadwal libur staf pada hari yang lebih sepi',
              'Cek stok sabun & plastik sebelum hari puncak',
              'Aktifkan notifikasi WhatsApp saat cucian selesai diproses',
            ]} />
          </article>
        </div>
      ) : null}
    </section>
  )
}

function OrdersPanel({ orders, onUpdateOrder, onRecordPayment, onPrintOrder, onDeleteOrder }: { orders: Order[]; onUpdateOrder: (order: Order, status: string) => Promise<void>; onRecordPayment: (order: Order) => Promise<void>; onPrintOrder: (order: Order) => void; onDeleteOrder: (order: Order) => Promise<void> }) {
  const [filter, setFilter] = useState('all')
  const [page, setPage] = useState(1)
  const filters = [['all', 'Semua'], ['received', 'Diterima'], ['processing', 'Diproses'], ['ready', 'Siap diambil'], ['picked_up', 'Diambil'], ['cancelled', 'Dibatalkan']] as const
  const shown = orders.filter((order) => filter === 'all' || order.order_status === filter)
  const pageSize = 10
  const totalPages = Math.max(1, Math.ceil(shown.length / pageSize))
  const currentPage = Math.min(page, totalPages)
  return <article className="wide-panel orders-panel"><div className="panel-header"><div><h2>Daftar pesanan</h2><p>{shown.length} pesanan ditemukan. Ubah status, catat pembayaran, cetak nota, dan kelola pesanan.</p></div><span className="list-count">{shown.length} pesanan</span></div><div className="order-filters" role="group" aria-label="Filter status pesanan">{filters.map(([id, label]) => <button type="button" key={id} className={filter === id ? 'active' : ''} onClick={() => { setFilter(id); setPage(1) }}>{label}</button>)}</div><OrderTable orders={shown.slice((currentPage - 1) * pageSize, currentPage * pageSize)} onUpdateStatus={onUpdateOrder} onRecordPayment={onRecordPayment} onPrintOrder={onPrintOrder} onDeleteOrder={onDeleteOrder} /><Pagination page={currentPage} pages={totalPages} total={shown.length} onChange={setPage} /></article>
}

function ApprovalPanel({ requests, loading, onReview, onDelete }: { requests: EmployeeRequest[]; loading: boolean; onReview: (request: EmployeeRequest, status: 'approved' | 'rejected' | 'completed' | 'paid') => Promise<void>; onDelete: (request: EmployeeRequest) => Promise<void> }) {
  const [filter, setFilter] = useState('pending')
  const shown = requests.filter((item) => filter === 'all' || item.status === filter || (filter === 'completed' && item.status === 'paid'))
  return <section className="wide-panel"><PanelHeader title="Pusat Pengajuan" description="Semua pengajuan stok, lembur, izin, tukar shift, insentif, kasbon, dan pengeluaran ada di sini." /><div className="filter-row">{[['pending', 'Menunggu'], ['approved', 'Disetujui'], ['completed', 'Dilaksanakan'], ['rejected', 'Ditolak'], ['all', 'Semua']].map(([id, label]) => <button key={id} type="button" className={filter === id ? 'active' : ''} onClick={() => setFilter(id)}>{label}</button>)}</div><div className="request-stack">{shown.map((request) => <article className="approval-card" key={request.id}><div className="approval-copy"><div className="approval-title"><strong>{request.type}</strong><span>{request.employee_name} - {dateLabel(request.created_at)}</span></div><p>{request.reason}</p>{request.amount > 0 ? <b>{request.type.includes('Stok') ? `${request.amount} unit` : rupiah(request.amount)}</b> : null}{request.review_note ? <small>Catatan: {request.review_note}</small> : null}</div><div className="approval-actions"><StatusBadge label={request.status} />{request.status === 'pending' ? <><button className="approve" disabled={loading} type="button" onClick={() => void onReview(request, 'approved')}><CheckCircle2 size={16} />Setujui</button><button className="reject" disabled={loading} type="button" onClick={() => void onReview(request, 'rejected')}><XCircle size={16} />Tolak</button></> : null}{request.status === 'approved' ? <button className="approve" disabled={loading} type="button" onClick={() => void onReview(request, isMoneyRequest(request.type) ? 'paid' : 'completed')}><CheckCircle2 size={16} />{isMoneyRequest(request.type) ? 'Bayar' : 'Tandai Dilaksanakan'}</button> : null}<button className="icon-button reject" style={{ color: '#b42318' }} disabled={loading} type="button" title="Hapus pengajuan" onClick={() => void onDelete(request)}><Trash2 size={16} /></button></div></article>)}{!shown.length ? <div className="empty-state">Tidak ada pengajuan pada status ini.</div> : null}</div></section>
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

function TeamPanel({ view, setView, employees, shifts, onAdd, onEdit, onDelete, onAddShift, onEditShift }: { view: 'employees' | 'shifts'; setView: (value: 'employees' | 'shifts') => void; employees: Employee[]; shifts: WeeklyShift[]; onAdd: () => void; onEdit: (employee: Employee) => void; onDelete: (employee: Employee) => void; onAddShift: () => void; onEditShift: (shift: WeeklyShift) => void }) {
  return <section><SegmentedControl value={view} items={[['employees', 'Karyawan'], ['shifts', 'Jadwal Mingguan']]} onChange={setView} /><section className="wide-panel"><PanelHeader title={view === 'employees' ? 'Karyawan & Akun' : 'Jadwal Shift Mingguan'} description={view === 'employees' ? 'Tambah akun, ubah data, dan aktifkan karyawan.' : 'Atur jam kerja atau hari libur setiap karyawan.'} action={view === 'employees' ? 'Tambah Karyawan' : 'Tambah Shift'} onAction={view === 'employees' ? onAdd : onAddShift} />{view === 'employees' ? <div className="table-list">{employees.map((employee) => <div className="table-row" key={employee.id}><div><strong>{employee.name}</strong><span>{employee.position} - {employee.phone || 'Tanpa nomor telepon'}</span></div><div className="row-meta"><StatusBadge label={employee.is_active ? 'Aktif' : 'Nonaktif'} /><button className="icon-button" type="button" title="Edit karyawan" onClick={() => onEdit(employee)}><Pencil size={16} /></button><button className="icon-button reject" style={{ color: '#b42318' }} type="button" title="Hapus / Nonaktifkan karyawan" onClick={() => onDelete(employee)}><Trash2 size={16} /></button></div></div>)}</div> : <WeeklyShiftGrid shifts={shifts} onEdit={onEditShift} />}</section></section>
}

function WeeklyShiftGrid({ shifts, onEdit }: { shifts: WeeklyShift[]; onEdit: (shift: WeeklyShift) => void }) {
  if (!shifts.length) return <div className="empty-state">Belum ada jadwal mingguan. Tambahkan shift untuk mulai menyusun jadwal.</div>
  return <div className="schedule-grid">{[1, 2, 3, 4, 5, 6, 7].map((day) => <section className="schedule-day" key={day}><strong>{dayLabel(day)}</strong>{shifts.filter((shift) => shift.day_of_week === day).map((shift) => <button type="button" key={shift.id} onClick={() => onEdit(shift)}><span>{shift.employee_name}</span><b>{shift.is_day_off ? 'Libur' : `${shortTime(shift.start_time)} - ${shortTime(shift.end_time)}`}</b></button>)}{!shifts.some((shift) => shift.day_of_week === day) ? <small>Belum dijadwalkan</small> : null}</section>)}</div>
}

function InventoryPanel({ items, movements, onAdd, onEdit, onDelete, onAdjust }: { items: InventoryItem[]; movements: InventoryMovement[]; onAdd: () => void; onEdit: (item: InventoryItem) => void; onDelete: (item: InventoryItem) => void; onAdjust: (item: InventoryItem) => void }) {
  return <section className="section-grid"><article className="wide-panel"><PanelHeader title="Stok & Persediaan" description="Pantau stok minimum dan catat stok masuk atau keluar." action="Tambah Item" onAction={onAdd} /><div className="table-list">{items.map((item) => { const low = item.stock <= item.min_stock; return <div className="table-row" key={item.id}><div><strong>{item.name}</strong><span>Minimum {item.min_stock} {item.unit} - {rupiah(item.purchase_price)}</span></div><div className="row-meta">{low ? <StatusBadge label="Menipis" /> : null}<strong>{item.stock} {item.unit}</strong><button className="ghost-button" type="button" onClick={() => onAdjust(item)}>Mutasi</button><button className="icon-button" type="button" title="Edit item stok" onClick={() => onEdit(item)}><Pencil size={15} /></button><button className="icon-button reject" style={{ color: '#b42318' }} type="button" title="Hapus item stok" onClick={() => onDelete(item)}><Trash2 size={15} /></button></div></div> })}{!items.length ? <div className="empty-state">Belum ada item stok.</div> : null}</div></article><article className="wide-panel"><PanelHeader title="Riwayat Mutasi" description="Pergerakan stok terbaru dan catatannya." /><div className="table-list">{movements.slice(0, 12).map((movement) => <div className="table-row" key={movement.id}><div><strong>{movement.item_name}</strong><span>{movement.note || dateLabel(movement.created_at)}</span></div><strong className={movement.type === 'IN' ? 'money-in' : 'money-out'}>{movement.type === 'IN' ? '+' : '-'}{movement.quantity}</strong></div>)}{!movements.length ? <div className="empty-state">Belum ada mutasi stok.</div> : null}</div></article></section>
}

function ReportsPanel({ cash, metrics, onAddCash, onExport, onEditCash, onDeleteCash }: { cash: CashTransaction[]; metrics: ReturnType<typeof useDashboardMetrics>; onAddCash: () => void; onExport: () => void; onEditCash: (entry: CashTransaction) => void; onDeleteCash: (entry: CashTransaction) => void }) {
  const [page, setPage] = useState(1)
  const pageSize = 12
  const totalPages = Math.max(1, Math.ceil(cash.length / pageSize))
  const currentPage = Math.min(page, totalPages)
  return <section className="section-grid"><div className="metrics-grid"><article className="metric-card"><Banknote size={20} /><strong>{rupiah(metrics.income)}</strong><span>Pemasukan</span></article><article className="metric-card"><Banknote size={20} /><strong>{rupiah(metrics.out)}</strong><span>Pengeluaran</span></article><article className="metric-card"><Banknote size={20} /><strong>{rupiah(metrics.balance)}</strong><span>Saldo</span></article></div><article className="wide-panel"><div className="panel-header"><div><h2>Buku Kas</h2><p>Transaksi terbaru toko dan pencatatan manual.</p></div><div className="row-meta"><button className="ghost-button" type="button" onClick={onExport}>Export CSV</button><button className="primary-button" type="button" onClick={onAddCash}><Plus size={16} />Catat Kas</button></div></div><div className="table-list">{cash.slice((currentPage - 1) * pageSize, currentPage * pageSize).map((item) => <div className="table-row" key={item.id}><div><strong>{item.category}</strong><span>{item.description || dateLabel(item.created_at)} · {item.method || 'Tunai'}</span></div><div className="row-meta"><strong className={item.type === 'IN' ? 'money-in' : 'money-out'}>{item.type === 'IN' ? '+' : '-'}{rupiah(item.amount)}</strong>{item.reference_type === 'MANUAL' ? <><button className="icon-button" type="button" title="Edit catatan kas manual" onClick={() => onEditCash(item)}><Pencil size={15} /></button><button className="icon-button reject" style={{ color: '#b42318' }} type="button" title="Hapus catatan kas manual" onClick={() => onDeleteCash(item)}><Trash2 size={15} /></button></> : <small style={{ color: '#667085', fontSize: '11px' }}>{item.reference_type || 'Sistem'}</small>}</div></div>)}</div><Pagination page={currentPage} pages={totalPages} total={cash.length} onChange={setPage} /></article></section>
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

function OrderDetailsForm({ order, employees, loading, onSubmit }: { order: Order; employees: Employee[]; loading: boolean; onSubmit: (values: { note: string; due_at: string; assigned_employee_id: string | null }) => Promise<void> }) {
  const [note, setNote] = useState(order.note ?? '')
  const [dueAt, setDueAt] = useState(order.due_at ? new Date(order.due_at).toISOString().slice(0, 16) : '')
  const [employee, setEmployee] = useState(order.assigned_employee_id ?? '')
  return <form className="editor-form" onSubmit={(event) => { event.preventDefault(); void onSubmit({ note, due_at: new Date(dueAt).toISOString(), assigned_employee_id: employee || null }) }}><label>Catatan pesanan<textarea rows={3} value={note} onChange={(event) => setNote(event.target.value)} /></label><label>Estimasi selesai<input type="datetime-local" value={dueAt} onChange={(event) => setDueAt(event.target.value)} required /></label><label>Penanggung jawab<select value={employee} onChange={(event) => setEmployee(event.target.value)}><option value="">Belum ditugaskan</option>{employees.map((row) => <option key={row.id} value={row.id}>{row.name}</option>)}</select></label><button className="primary-button" disabled={loading} type="submit">Simpan detail</button></form>
}

function RequestDetailsForm({ request, loading, onSubmit }: { request: EmployeeRequest; loading: boolean; onSubmit: (values: { reason: string; amount: number; review_note: string }) => Promise<void> }) {
  const [reason, setReason] = useState(request.reason)
  const [amount, setAmount] = useState(request.amount)
  const [note, setNote] = useState(request.review_note ?? '')
  return <form className="editor-form" onSubmit={(event) => { event.preventDefault(); void onSubmit({ reason, amount, review_note: note }) }}><p>{request.employee_name} · {request.type}</p><label>Alasan/keterangan<textarea rows={3} value={reason} onChange={(event) => setReason(event.target.value)} required /></label><label>Nominal/jumlah<input type="number" min="0" value={amount} onChange={(event) => setAmount(Number(event.target.value))} required /></label><label>Catatan Owner<textarea rows={3} value={note} onChange={(event) => setNote(event.target.value)} /></label><button className="primary-button" disabled={loading} type="submit">Simpan pengajuan</button></form>
}

function EditInventoryForm({ item, loading, onSubmit }: { item: InventoryItem; loading: boolean; onSubmit: (values: InventoryFormValues) => Promise<void> }) {
  const [values, setValues] = useState<InventoryFormValues>({ name: item.name, stock: item.stock, unit: item.unit, min_stock: item.min_stock, purchase_price: item.purchase_price, note: item.note, is_active: item.is_active })
  return <form className="editor-form" onSubmit={(event) => { event.preventDefault(); void onSubmit(values) }}><label>Nama item<input value={values.name} onChange={(event) => setValues({ ...values, name: event.target.value })} required /></label><div className="form-grid"><label>Satuan<input value={values.unit} onChange={(event) => setValues({ ...values, unit: event.target.value })} required /></label><label>Stok minimum<input type="number" min="0" value={values.min_stock} onChange={(event) => setValues({ ...values, min_stock: Number(event.target.value) })} /></label></div><label>Harga beli<input type="number" min="0" value={values.purchase_price} onChange={(event) => setValues({ ...values, purchase_price: Number(event.target.value) })} /></label><label>Catatan<textarea value={values.note} onChange={(event) => setValues({ ...values, note: event.target.value })} /></label><label className="toggle-row"><input type="checkbox" checked={values.is_active} onChange={(event) => setValues({ ...values, is_active: event.target.checked })} />Aktif</label><p>Stok aktual diubah melalui tombol Mutasi agar riwayatnya tercatat.</p><button className="primary-button" disabled={loading} type="submit">Simpan item</button></form>
}

function EditCashForm({ entry, loading, onSubmit, onDelete }: { entry: CashTransaction; loading: boolean; onSubmit: (values: CashFormValues) => Promise<void>; onDelete?: (entry: CashTransaction) => void }) {
  const [values, setValues] = useState<CashFormValues>({ type: entry.type, category: entry.category, description: entry.description, amount: entry.amount, method: entry.method || 'Tunai' })
  return <form className="editor-form" onSubmit={(event) => { event.preventDefault(); void onSubmit(values) }}><div className="form-grid"><label>Tipe<select value={values.type} onChange={(event) => setValues({ ...values, type: event.target.value as 'IN' | 'OUT' })}><option value="IN">Pemasukan</option><option value="OUT">Pengeluaran</option></select></label><label>Kategori<input value={values.category} onChange={(event) => setValues({ ...values, category: event.target.value })} required /></label></div><label>Keterangan<textarea value={values.description} onChange={(event) => setValues({ ...values, description: event.target.value })} required /></label><div className="form-grid"><label>Nominal<input type="number" min="1" value={values.amount} onChange={(event) => setValues({ ...values, amount: Number(event.target.value) })} required /></label><label>Metode<select value={values.method} onChange={(event) => setValues({ ...values, method: event.target.value })}><option>Tunai</option><option>Transfer</option><option>QRIS</option></select></label></div><div className="form-actions"><button className="primary-button" disabled={loading} type="submit">Simpan koreksi</button>{onDelete ? <button className="reject" disabled={loading} type="button" onClick={() => onDelete(entry)}><Trash2 size={16} />Hapus</button> : null}</div></form>
}

function OwnerEditAccess<T extends { id: string }>({ title, entries, label, onEdit }: { title: string; entries: T[]; label: (entry: T) => string; onEdit: (entry: T) => void }) {
  const [selected, setSelected] = useState('')
  const current = entries.find((entry) => entry.id === selected)
  return <article className="wide-panel edit-access"><div><h2>{title}</h2><p>Pilih data yang akan diperbaiki oleh Owner.</p></div><div className="row-meta"><select aria-label={title} value={selected} onChange={(event) => setSelected(event.target.value)}><option value="">Pilih data...</option>{entries.map((entry) => <option key={entry.id} value={entry.id}>{label(entry)}</option>)}</select><button className="ghost-button" type="button" disabled={!current} onClick={() => current && onEdit(current)}><Pencil size={15} />Edit</button></div></article>
}

function Modal({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) { return <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}><section className="modal" role="dialog" aria-modal="true" aria-label={title}><header><h2>{title}</h2><button className="icon-button" type="button" onClick={onClose} aria-label="Tutup"><X size={18} /></button></header>{children}</section></div> }

function SegmentedControl<T extends string>({ value, items, onChange }: { value: T; items: readonly (readonly [T, string])[]; onChange: (value: T) => void }) { return <div className="segmented-control">{items.map(([id, label]) => <button key={id} className={value === id ? 'active' : ''} type="button" onClick={() => onChange(id)}>{label}</button>)}</div> }
function PanelHeader({ title, description, action, onAction }: { title: string; description: string; action?: string; onAction?: () => void }) { return <div className="panel-header"><div><h2>{title}</h2><p>{description}</p></div>{action ? <button className="ghost-button" type="button" onClick={onAction}><Plus size={16} />{action}</button> : null}</div> }
function OrderTable({ orders, onUpdateStatus, onRecordPayment, onPrintOrder, onDeleteOrder }: { orders: Order[]; onUpdateStatus?: (order: Order, status: string) => Promise<void>; onRecordPayment?: (order: Order) => Promise<void>; onPrintOrder?: (order: Order) => void; onDeleteOrder?: (order: Order) => Promise<void> }) {
  if (!orders.length) return <div className="empty-state">Belum ada pesanan pada tampilan ini.</div>
  return <div className="order-table-wrap"><table className="order-table"><thead><tr><th>Nomor nota</th><th>Pelanggan</th><th>Tanggal</th><th>Total</th><th>Status</th><th>Pembayaran</th>{onUpdateStatus || onPrintOrder || onDeleteOrder ? <th>Tindakan</th> : null}</tr></thead><tbody>{orders.map((order) => { const remaining = Math.max(0, order.total_price - order.paid_amount); return <tr key={order.id} className={order.order_status === 'received' ? 'is-new' : ''}><td data-label="Nomor nota"><strong>{order.order_number}</strong></td><td data-label="Pelanggan">{order.customer_name_snapshot}</td><td data-label="Tanggal">{dateLabel(order.created_at)}</td><td data-label="Total"><div><strong>{rupiah(order.total_price)}</strong>{remaining > 0 ? <small style={{ display: 'block', color: '#b42318', fontSize: '11px' }}>Sisa {rupiah(remaining)}</small> : null}</div></td><td data-label="Status"><StatusBadge label={order.order_status} /></td><td data-label="Pembayaran"><StatusBadge label={order.payment_status} /></td>{onUpdateStatus || onPrintOrder || onDeleteOrder ? <td data-label="Tindakan"><div className="table-actions">{onUpdateStatus ? <select className="compact-select" aria-label={`Ubah status ${order.order_number}`} value={order.order_status} onChange={(event) => void onUpdateStatus(order, event.target.value)}><option value="received">Diterima</option><option value="processing">Diproses</option><option value="ready">Siap diambil</option><option value="picked_up">Diambil</option><option value="cancelled">Dibatalkan</option></select> : null}{onRecordPayment && remaining > 0 ? <button className="table-pay-button" type="button" onClick={() => void onRecordPayment(order)}>Bayar</button> : null}{onPrintOrder ? <button className="icon-button" type="button" title="Cetak Nota" onClick={() => onPrintOrder(order)}><Printer size={15} /></button> : null}{onDeleteOrder ? <button className="icon-button reject" style={{ color: '#b42318' }} type="button" title="Hapus / Batalkan pesanan" onClick={() => void onDeleteOrder(order)}><Trash2 size={15} /></button> : null}</div></td> : null}</tr> })}</tbody></table></div>
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
function cashflowForDates(cash: CashTransaction[], dates: Date[], monthly = false) {
  return dates.map((date) => {
    const key = localDayKey(date)
    const dayCash = cash.filter((c) => localDayKey(c.created_at) === key)
    const income = dayCash.filter((c) => c.type === 'IN').reduce((sum, c) => sum + c.amount, 0)
    const expense = dayCash.filter((c) => c.type === 'OUT').reduce((sum, c) => sum + c.amount, 0)
    return {
      key,
      label: monthly ? String(date.getDate()) : new Intl.DateTimeFormat('id-ID', { weekday: 'short' }).format(date).replace('.', ''),
      fullLabel: new Intl.DateTimeFormat('id-ID', { day: 'numeric', month: 'long', year: 'numeric' }).format(date),
      income,
      expense,
      net: income - expense,
    }
  })
}
function calendarWeekCashflow(cash: CashTransaction[]) {
  const start = new Date(); start.setHours(0, 0, 0, 0)
  start.setDate(start.getDate() - ((start.getDay() + 6) % 7))
  return cashflowForDates(cash, Array.from({ length: 7 }, (_, index) => { const date = new Date(start); date.setDate(start.getDate() + index); return date }))
}
function calendarMonthCashflow(cash: CashTransaction[], selectedMonth: string) {
  const [year, month] = selectedMonth.split('-').map(Number)
  const days = new Date(year, month, 0).getDate()
  return cashflowForDates(cash, Array.from({ length: days }, (_, index) => new Date(year, month - 1, index + 1)), true)
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
