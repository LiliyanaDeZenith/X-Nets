import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req) => {
  const { email } = await req.json()
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)

  // 1. Bikin kode 4 digit di database
  const { data } = await supabase.rpc("request_code", { email_in: email })
  const code = data as string

  // 2. Kirim pake Gmail websitescarlett@gmail.com
  const res = await fetch("https://api.nodemailer.com/send", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      from: "websitescarlett@gmail.com",
      to: email,
      subject: "Kode Verifikasi X-NET Kamu: " + code,
      text: "Kode verifikasi kamu adalah: " + code + ". Berlaku 5 menit. Jangan kasih ke siapa-siapa ya!"
    })
  })

  return new Response(JSON.stringify({ ok: true }), { headers: { "Content-Type": "application/json" } })
})
