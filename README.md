# X'Nest (Supabase, tanpa server)

Website statis. Tidak ada perintah yang perlu dijalankan.

## Setup (sekali saja)

1. Supabase > Authentication > Providers > Email: matikan "Confirm email".
2. Supabase > SQL Editor: tempel isi `setup.sql` (sudah termasuk semua update), lalu Run. Aman dijalankan ulang, jadi kalau sebelumnya sudah menjalankan SQL versi lama, jalankan lagi `setup.sql` ini.
3. Upload semua file di folder ini (`index.html`, `sw.js`, `manifest.json`, folder `icons` dan `assets`) ke Netlify, GitHub Pages, atau Cloudflare Pages.
4. Buka situsnya dan daftar dulu dengan websitescarlett@gmail.com. Akun itu otomatis dev (centang biru, gelar Dev Web, Menu dev). Lakukan ini sebelum membagikan link.

## Catatan

- URL dan kunci publishable ada di bagian atas script `index.html`. Aman dipublikasikan karena semua tabel dikunci RLS. Jangan pernah menaruh Secret key di file ini.
- Login memakai email dan sandi.
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
