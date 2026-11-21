# X'Nest (Supabase, tanpa server)

Website statis. Tidak ada perintah yang perlu dijalankan.

## Setup (sekali saja)

1. Supabase > Authentication > Providers > Email: nyalakan "Confirm email" (wajib, supaya kode OTP terkirim). Atur juga Email OTP Length 6 dan Email OTP Expiration 600 detik. Lalu atur pengirim email lewat Gmail, lihat bagian "Kirim OTP lewat Gmail" di bawah.
2. Supabase > SQL Editor: tempel isi `setup.sql` (sudah termasuk semua update), lalu Run. Aman dijalankan ulang, jadi kalau sebelumnya sudah menjalankan SQL versi lama, jalankan lagi `setup.sql` ini.
3. Upload semua file di folder ini (`index.html`, `sw.js`, `manifest.json`, folder `icons` dan `assets`) ke Netlify, GitHub Pages, atau Cloudflare Pages.
4. Buka situsnya dan daftar dulu dengan websitescarlett@gmail.com. Akun itu otomatis dev (centang biru, gelar Dev Web, Menu dev). Lakukan ini sebelum membagikan link.

## Catatan

- URL dan kunci publishable ada di bagian atas script `index.html`. Aman dipublikasikan karena semua tabel dikunci RLS. Jangan pernah menaruh Secret key di file ini.
- Daftar hanya dengan Gmail asli (gmail.com). Daftar dan masuk memakai email, sandi, lalu kode OTP 6 digit yang dikirim ke Gmail pengguna.
- Situs tidak mengubah alamat atau riwayat browser saat berpindah halaman, dan tombol unduh TikTok mengunduh langsung tanpa membuka tab baru (kalau server tikwm mengizinkan).
- Centang biru dibeli dengan Mora. Setiap akun bisa klaim 100 Mora seminggu sekali. Developer punya Mora tak terbatas.
- Sandi pengguna tidak bisa dibaca siapa pun. Di Menu dev > Sandi, dev mengatur daftar sandi terlarang; pengguna yang memakainya diminta ganti sandi.
- Foto dan video diunggah ke Supabase Storage (bucket `media`). Aplikasi tidak membatasi ukuran; batas per file mengikuti pengaturan Storage project (Free: 50 MB).

## Update terbaru
- Top up Mora: Menu dev > Top up (username + Gmail + jumlah Mora). Riwayat top up tampil di dev dan di halaman Centang biru.
- Menu dev > Sandi: daftar semua pengguna dengan status Aman atau Tidak pantas. Sandi asli tetap terenkripsi dan tidak bisa dibaca.
- Harga centang biru: 500 Mora per bulan (5 bulan 2.500, 1 tahun 6.000). Ubah harga di `PL` pada `index.html` dan di `buy_check` pada `setup.sql` dan `tambahan-mora.sql`.
- Saluran dan komunitas: pemilik (dan co-pemilik) bisa ganti nama, ikon, tambah anggota, tambah pemilik. Hanya pemilik utama yang bisa transfer kepemilikan.
- Komentar gaya Facebook: panel komentar dengan Suka, Balas, balasan bertingkat, dan pratinjau komentar di bawah kiriman.
- Unduh TikTok: kartu pratinjau video.
- Bubble pesan kustom untuk akun terverifikasi (Pengaturan): foto atau video galeri, atau bubble bawaan di `assets/bubbles`.
- PWA: bisa dipasang di layar utama (`manifest.json`, `sw.js`, `icons`).

## Kirim OTP lewat Gmail (websitescarlett@gmail.com)
Supabase mengirim email OTP lewat SMTP yang kamu atur sendiri. Pengaturannya ada di dashboard, bukan di kode:
1. Akun Google websitescarlett@gmail.com: aktifkan Verifikasi 2 Langkah, lalu buat Sandi aplikasi (App password) bernama X'Nest. Simpan 16 karakternya.
2. Supabase > Authentication > Emails > SMTP Settings: nyalakan Custom SMTP. Sender email `websitescarlett@gmail.com`, Sender name `X'Nest`, Host `smtp.gmail.com`, Port `465`, Username `websitescarlett@gmail.com`, Password = sandi aplikasi tadi.
3. Supabase > Authentication > Emails > Templates: tempel isi `email/konfirmasi-daftar.html` ke "Confirm signup" dan `email/kode-masuk.html` ke "Magic Link". Keduanya memakai `{{ .Token }}` (kode 6 digit), bukan tautan.
4. Supabase > Authentication > Rate Limits: naikkan batas pengiriman email per jam sesuai kebutuhan. Gmail gratis membatasi sekitar 500 email per hari.
Catatan: akun lama yang memakai email palsu tidak bisa menerima kode, jadi tidak bisa masuk lagi. Akun yang tidak pernah verifikasi bisa dibersihkan dengan `select public.purge_unverified();` di SQL Editor.

## Update: tab beranda dan afinitas
- Beranda punya tab Beranda, Mengikuti, dan Teman (teman = saling mengikuti).
- Profil punya Afinitas: Pasangan (maks 1), Sahabat (maks 3), Saudara (maks 3). Hanya bisa diajak ke teman. Setelah diterima ada hari bersama, level, dan check-in harian untuk menambah poin.
