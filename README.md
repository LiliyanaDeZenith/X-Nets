# X'Nest (Supabase, tanpa server)

Website statis. Tidak ada perintah yang perlu dijalankan.

## Setup (sekali saja)

1. Supabase > Authentication > Providers > Email: matikan "Confirm email" (kode verifikasi dikirim lewat EmailJS, bukan Supabase).
2. Supabase > SQL Editor: tempel isi `setup.sql` (sudah termasuk semua update), lalu Run. Aman dijalankan ulang, jadi kalau sebelumnya sudah menjalankan SQL versi lama, jalankan lagi `setup.sql` ini.
3. Upload semua file di folder ini (`index.html`, `sw.js`, `manifest.json`, folder `icons` dan `assets`) ke Netlify, GitHub Pages, atau Cloudflare Pages.
4. Buka situsnya dan daftar dulu dengan websitescarlett@gmail.com. Akun itu otomatis dev (centang biru, gelar Dev Web, Menu dev). Lakukan ini sebelum membagikan link.

## Catatan

- URL dan kunci publishable ada di bagian atas script `index.html`. Aman dipublikasikan karena semua tabel dikunci RLS. Jangan pernah menaruh Secret key di file ini.
- Daftar hanya dengan Gmail asli (gmail.com). Daftar dan masuk memakai email, sandi, lalu kode verifikasi 6 digit yang dikirim ke Gmail pengguna.
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

## Verifikasi email 6 digit (EmailJS)
Kode dikirim lewat EmailJS dari websitescarlett@gmail.com. ID layanan, template, dan Public Key ada di `CFG` (cari `const CFG` di `index.html`).
1. EmailJS > Email Services: layanan `service_448sksw` harus terhubung ke websitescarlett@gmail.com.
2. EmailJS > Email Templates > `template_mvi5kya`: To Email isi `{{to_email}}`, From Name isi `{{from_name}}`, Subject isi `Kode verifikasi {{from_name}}`. Tempel isi `email/emailjs-template.html` ke Content (pilih Code Editor / HTML).
3. Daftar dan masuk: email, sandi, lalu 6 kotak kode. Kode berlaku 10 menit, kirim ulang bisa tiap 60 detik (maksimal 5 kali), salah memasukkan kode maksimal 5 kali.
4. `verifikasi-email.html` adalah halaman mandiri 1 file dengan fitur yang sama, untuk dicoba atau disalin ke halaman lain.

Catatan: EmailJS gratis dibatasi 200 email per bulan, dan setiap daftar atau masuk memakai 1 email. Kode dibuat dan dicek di browser, jadi ini verifikasi tingkat tampilan: mencegah email asal ketik, tapi orang yang paham teknis bisa melewatinya.

## Mode Supabase (opsional, lebih aman)
Kode dikirim dan dicek oleh Supabase, bukan browser. Ubah `verif:'emailjs'` menjadi `verif:'supabase'` di `CFG`, lalu:
1. Authentication > Providers > Email: nyalakan "Confirm email", Email OTP Length 6, Expiration 600.
2. Authentication > Emails > SMTP Settings: nyalakan Custom SMTP. Sender `websitescarlett@gmail.com`, host `smtp.gmail.com`, port `465`, username `websitescarlett@gmail.com`, password = Sandi aplikasi Google (Verifikasi 2 Langkah harus aktif).
3. Authentication > Emails > Templates: tempel `email/konfirmasi-daftar.html` ke "Confirm signup" dan `email/kode-masuk.html` ke "Magic Link".

Catatan umum: akun lama yang memakai email palsu tidak bisa menerima kode, jadi tidak bisa masuk. Akun yang tidak pernah verifikasi bisa dibersihkan dengan `select public.purge_unverified();` di SQL Editor.

## Update terbaru
- Top up Mora: Menu dev > Top up (username + Gmail + jumlah Mora). Riwayat top up tampil di dev dan di halaman Centang biru.
- Menu dev > Sandi: daftar semua pengguna dengan status Aman atau Tidak pantas. Sandi asli tetap terenkripsi dan tidak bisa dibaca.
- Harga centang biru: 500 Mora per bulan (5 bulan 2.500, 1 tahun 6.000). Ubah di `PL` pada `index.html` dan di `buy_check` pada `setup.sql` dan `tambahan-mora.sql`.
- Saluran dan komunitas: pemilik (dan co-pemilik) bisa ganti nama, ikon, tambah anggota, tambah pemilik. Hanya pemilik utama yang bisa transfer kepemilikan.
- Komentar gaya Facebook: panel komentar dengan Suka, Balas, balasan bertingkat, dan pratinjau komentar di bawah kiriman.
- Unduh TikTok: kartu pratinjau video.
- Bubble pesan kustom untuk akun terverifikasi (Pengaturan): foto atau video galeri, atau bubble bawaan di `assets/bubbles`.
- Beranda punya tab Beranda, Mengikuti, dan Teman (teman = saling mengikuti).
- Profil punya Afinitas: Pasangan (maks 1), Sahabat (maks 3), Saudara (maks 3). Hanya bisa diajak ke teman. Ada hari bersama, level, dan check-in harian.
- PWA: bisa dipasang di layar utama (`manifest.json`, `sw.js`, `icons`).

## Hapus kode lama, pasang kode baru
`reset-dan-pasang.sql` menghapus fungsi, trigger, dan aturan akses lama lalu memasang yang baru (data tidak dihapus). Di dalamnya ada Bagian 2 yang dimatikan untuk menghapus semua data kalau mau mulai dari nol.
