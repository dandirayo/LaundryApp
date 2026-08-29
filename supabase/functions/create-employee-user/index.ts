import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authorization = request.headers.get('Authorization')
    if (!authorization) return json({ error: 'Sesi Owner tidak ditemukan.' }, 401)

    const url = Deno.env.get('SUPABASE_URL')!
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ??
      Deno.env.get('SUPABASE_SECRET_KEY') ??
      ''
    if (!serviceRoleKey) {
      return json({ error: 'Secret SUPABASE_SERVICE_ROLE_KEY belum diset di Edge Function.' }, 500)
    }
    const userClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authorization } },
    })
    const adminClient = createClient(url, serviceRoleKey)

    const { data: authData, error: authError } = await userClient.auth.getUser()
    if (authError || !authData.user) return json({ error: 'Sesi Owner tidak valid.' }, 401)

    const { data: owner, error: ownerError } = await userClient
      .from('profiles')
      .select('shop_id, role, is_active')
      .eq('id', authData.user.id)
      .single()
    if (ownerError || owner?.role !== 'OWNER' || owner?.is_active !== true) {
      return json({
        error: 'Hanya Owner aktif yang dapat membuat akun karyawan.',
        auth_user_id: authData.user.id,
        email: authData.user.email,
        profile_role: owner?.role ?? null,
        profile_is_active: owner?.is_active ?? null,
        profile_error: ownerError?.message ?? null,
      }, 403)
    }

    const body = await request.json()
    const username = String(body.username ?? '').trim().toLowerCase()
    const password = String(body.password ?? '')
    const name = String(body.name ?? '').trim()
    const phone = String(body.phone ?? '').trim()
    const position = String(body.position ?? 'Operator').trim()
    const shiftStart = normalizeTime(String(body.shift_start ?? '06:00'))
    const shiftEnd = normalizeTime(String(body.shift_end ?? '14:00'))
    const lateToleranceMinutes = Number(body.late_tolerance_minutes ?? 120)
    const isActive = body.is_active !== false

    if (!/^[a-z0-9._-]{3,32}$/.test(username)) {
      return json({ error: 'Username harus 3-32 karakter: huruf kecil, angka, titik, garis bawah, atau strip.' }, 400)
    }
    if (password.length < 8) return json({ error: 'Password minimal 8 karakter.' }, 400)
    if (!name) return json({ error: 'Nama karyawan wajib diisi.' }, 400)
    if (!shiftStart || !shiftEnd) return json({ error: 'Format jam shift belum valid.' }, 400)
    if (!Number.isInteger(lateToleranceMinutes) || lateToleranceMinutes < 0 || lateToleranceMinutes > 480) {
      return json({ error: 'Toleransi telat harus 0-480 menit.' }, 400)
    }

    const { data: existing } = await adminClient
      .from('profiles')
      .select('id')
      .ilike('username', username)
      .maybeSingle()
    if (existing) return json({ error: 'Username sudah digunakan.' }, 409)

    const loginEmail = `${username}@idola.local`
    const { data: createdAuth, error: createAuthError } = await adminClient.auth.admin.createUser({
      email: loginEmail,
      password,
      email_confirm: true,
      user_metadata: { username, full_name: name },
    })
    if (createAuthError || !createdAuth.user) {
      return json({ error: createAuthError?.message ?? 'Akun Auth gagal dibuat.' }, 400)
    }

    const userId = createdAuth.user.id
    const { data: employee, error: employeeError } = await userClient
      .from('employees')
      .insert({
        shop_id: owner.shop_id,
        name,
        phone,
        position,
        role: 'EMPLOYEE',
        shift_start: shiftStart,
        shift_end: shiftEnd,
        late_tolerance_minutes: lateToleranceMinutes,
        is_active: isActive,
      })
      .select('id')
      .single()

    if (employeeError || !employee) {
      await adminClient.auth.admin.deleteUser(userId)
      return json({ error: employeeError?.message ?? 'Data karyawan gagal dibuat.' }, 400)
    }

    const { error: profileError } = await userClient.from('profiles').insert({
      id: userId,
      shop_id: owner.shop_id,
      employee_id: employee.id,
      full_name: name,
      role: 'EMPLOYEE',
      is_active: isActive,
      phone,
      username,
    })

    if (profileError) {
      await adminClient.from('employees').delete().eq('id', employee.id)
      await adminClient.auth.admin.deleteUser(userId)
      return json({ error: profileError.message }, 400)
    }

    return json({
      employee_id: employee.id,
      user_id: userId,
      username,
      name,
      phone,
      position,
      shift_start: shiftStart,
      shift_end: shiftEnd,
      late_tolerance_minutes: lateToleranceMinutes,
      is_active: isActive,
    }, 201)
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Terjadi kesalahan server.' }, 500)
  }
})

function normalizeTime(value: string) {
  const match = value.trim().replace('.', ':').match(/^(\d{1,2}):(\d{1,2})$/)
  if (!match) return ''
  const hour = Number(match[1])
  const minute = Number(match[2])
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return ''
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`
}
