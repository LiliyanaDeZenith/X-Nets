# X'Nest (Supabase, tanpa server)

Website statis. Tidak ada perintah yang perlu dijalankan.

## Setup (sekali saja)

1. Supabase > Authentication > Providers > Email: matikan "Confirm email".
2. Supabase > SQL Editor: tempel isi `setup.sql`, lalu Run. Kalau sebelumnya sudah menjalankan SQL versi lama, cukup jalankan `tambahan-mora.sql`.
3. Upload `index.html` ke Netlify, GitHub Pages, atau Cloudflare Pages.
4. Buka situsnya dan daftar dulu dengan websitescarlett@gmail.com. Akun itu otomatis dev (centang biru, gelar Dev Web, Menu dev). Lakukan ini sebelum membagikan link.

## Catatan

- URL dan kunci publishable ada di bagian atas script `index.html`. Aman dipublikasikan karena semua tabel dikunci RLS. Jangan pernah menaruh Secret key di file ini.
- Login memakai email dan sandi.
- Situs tidak mengubah alamat atau riwayat browser saat berpindah halaman, dan tombol unduh TikTok mengunduh langsung tanpa membuka tab baru (kalau server tikwm mengizinkan).
- Centang biru dibeli dengan Mora. Setiap akun bisa klaim 100 Mora seminggu sekali. Developer punya Mora tak terbatas.
- Sandi pengguna tidak bisa dibaca siapa pun. Di Menu dev > Sandi, dev mengatur daftar sandi terlarang; pengguna yang memakainya diminta ganti sandi.
- Foto dan video diunggah ke Supabase Storage (bucket `media`). Aplikasi tidak membatasi ukuran; batas per file mengikuti pengaturan Storage project (Free: 50 MB).
