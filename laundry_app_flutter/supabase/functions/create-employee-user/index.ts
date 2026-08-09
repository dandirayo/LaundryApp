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
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const userClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authorization } },
    })
    const adminClient = createClient(url, serviceRoleKey)

    const { data: authData, error: authError } = await userClient.auth.getUser()
    if (authError || !authData.user) return json({ error: 'Sesi Owner tidak valid.' }, 401)

    const { data: owner, error: ownerError } = await adminClient
      .from('profiles')
      .select('shop_id, role, is_active')
      .eq('id', authData.user.id)
      .single()
    if (ownerError || owner?.role !== 'OWNER' || owner?.is_active !== true) {
      return json({ error: 'Hanya Owner aktif yang dapat membuat akun karyawan.' }, 403)
    }

    const body = await request.json()
    const username = String(body.username ?? '').trim().toLowerCase()
    const password = String(body.password ?? '')
    const name = String(body.name ?? '').trim()
    const phone = String(body.phone ?? '').trim()
    const position = String(body.position ?? 'Operator').trim()

    if (!/^[a-z0-9._-]{3,32}$/.test(username)) {
      return json({ error: 'Username harus 3-32 karakter: huruf kecil, angka, titik, garis bawah, atau strip.' }, 400)
    }
    if (password.length < 8) return json({ error: 'Password minimal 8 karakter.' }, 400)
    if (!name) return json({ error: 'Nama karyawan wajib diisi.' }, 400)

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
    const { data: employee, error: employeeError } = await adminClient
      .from('employees')
      .insert({
        shop_id: owner.shop_id,
        name,
        phone,
        position,
        role: 'EMPLOYEE',
        is_active: true,
      })
      .select('id')
      .single()

    if (employeeError || !employee) {
      await adminClient.auth.admin.deleteUser(userId)
      return json({ error: employeeError?.message ?? 'Data karyawan gagal dibuat.' }, 400)
    }

    const { error: profileError } = await adminClient.from('profiles').insert({
      id: userId,
      shop_id: owner.shop_id,
      employee_id: employee.id,
      full_name: name,
      role: 'EMPLOYEE',
      is_active: true,
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
    }, 201)
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Terjadi kesalahan server.' }, 500)
  }
})
