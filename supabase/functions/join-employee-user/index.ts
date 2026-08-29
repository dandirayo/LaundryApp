import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method tidak didukung.' }, 405)

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const serviceKey =
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY') ?? ''
  const inviteCode = Deno.env.get('IDOLA_EMPLOYEE_INVITE_CODE') ?? 'IDOLA2026'
  const shopId =
    Deno.env.get('IDOLA_SHOP_ID') ?? '00000000-0000-0000-0000-000000000001'

  if (!supabaseUrl || !serviceKey) {
    return json({ error: 'Environment Supabase function belum lengkap.' }, 500)
  }

  const adminClient = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  try {
    const body = await req.json()
    const receivedCode = String(body.inviteCode ?? '').trim()
    const name = String(body.name ?? '').trim()
    const phone = String(body.phone ?? '').trim()
    const username = String(body.username ?? '').trim().toLowerCase()
    const password = String(body.password ?? '')

    if (receivedCode !== inviteCode) return json({ error: 'Kode toko salah.' }, 403)
    if (name.length < 2) return json({ error: 'Nama karyawan wajib diisi.' }, 400)
    if (phone.length < 8) return json({ error: 'Nomor WhatsApp tidak valid.' }, 400)
    if (!/^[a-z0-9._-]{3,32}$/.test(username)) {
      return json({ error: 'Username hanya huruf, angka, titik, strip, underscore.' }, 400)
    }
    if (password.length < 8) return json({ error: 'Password minimal 8 karakter.' }, 400)

    const { data: existingProfile } = await adminClient
      .from('profiles')
      .select('id')
      .ilike('username', username)
      .maybeSingle()
    if (existingProfile) return json({ error: 'Username sudah dipakai.' }, 409)

    const loginEmail = `${username}@idola.local`
    const { data: authData, error: authError } = await adminClient.auth.admin.createUser({
      email: loginEmail,
      password,
      email_confirm: true,
      user_metadata: { username, full_name: name },
    })
    if (authError || !authData.user) {
      return json({ error: authError?.message ?? 'Gagal membuat akun auth.' }, 400)
    }

    const { data: employee, error: employeeError } = await adminClient
      .from('employees')
      .insert({
        shop_id: shopId,
        name,
        phone,
        position: 'Karyawan',
        role: 'EMPLOYEE',
        shift_start: '06:00',
        shift_end: '14:00',
        late_tolerance_minutes: 120,
        is_active: true,
      })
      .select('id, name, phone')
      .single()

    if (employeeError || !employee) {
      await adminClient.auth.admin.deleteUser(authData.user.id)
      return json({ error: employeeError?.message ?? 'Gagal menyimpan data karyawan.' }, 400)
    }

    const { error: profileError } = await adminClient.from('profiles').insert({
      id: authData.user.id,
      shop_id: shopId,
      employee_id: employee.id,
      full_name: name,
      role: 'EMPLOYEE',
      is_active: true,
      phone,
      username,
    })

    if (profileError) {
      await adminClient.from('employees').delete().eq('id', employee.id)
      await adminClient.auth.admin.deleteUser(authData.user.id)
      return json({ error: profileError.message }, 400)
    }

    return json({
      id: employee.id,
      auth_user_id: authData.user.id,
      username,
      login_email: loginEmail,
    })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : String(error) }, 500)
  }
})
