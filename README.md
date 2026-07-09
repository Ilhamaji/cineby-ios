# Cineby iOS Wrapper App

Aplikasi ini adalah wrapper iOS native untuk situs streaming film [Cineby](https://cineby.at). Aplikasi ini dirancang agar berjalan layaknya aplikasi native Apple dengan fitur unggulan **Bypass Portrait Orientation Lock**, yang memungkinkan pengguna memutar video secara fullscreen landscape cukup dengan menekan satu tombol tanpa perlu mengubah pengaturan rotasi sistem pada iPhone mereka.

---

## Fitur Utama

1. **Bypass Portrait Orientation Lock**: Menonton film dalam posisi landscape layar penuh secara instan meskipun fitur *Portrait Orientation Lock* (Kunci Orientasi Potret) di iPhone Anda sedang **Aktif/Menyala**.
2. **Kontrol Navigasi Bulat Premium (Reddit-Style)**:
   * **Mode Portrait:** Tombol teks **"Rotate ↻"** yang bersih di sebelah kanan atas navigation bar untuk memutar layar.
   * **Mode Landscape:** Tombol melayang berbentuk bulat (Reddit-Style) berukuran 50x50 dengan desain gelap semi-transparan, bingkai putih yang elegan, dan ikon **SF Symbols** (`arrow.triangle.2.circlepath` untuk rotasi, `lock.open.fill` untuk kunci).
3. **Playback Lock Screen Instan & Auto-Hide**:
   * **Tombol "Lock"**: Berbentuk bulat di pojok kiri bawah landscape (secara fisik di top-left). Saat ditekan, tombol berubah menjadi merah dengan ikon gembok tertutup, menyembunyikan tombol rotasi, dan menonaktifkan seluruh interaksi sentuh pada pemutar video/WebView.
   * **Auto-Hide (Sembunyi Otomatis)**: Tombol gembok merah tersebut akan **otomatis memudar hingga hilang dalam 3 detik** setelah diaktifkan agar tampilan film bersih tanpa gangguan ikon.
   * **Tap-to-Toggle (Ketuk Layar)**: Ketuk layar kosong di mana saja sekali untuk memunculkan kembali tombol gembok (tampil selama 3 detik) atau mengetuknya sekali lagi untuk langsung menyembunyikannya kembali secara instan.
   * **Penyembunyian Kontrol Instan**: Menggunakan penyiaran pesan antar-frame (`window.postMessage`) yang seketika menyembunyikan bilah kontrol pemutar film (JWPlayer, VideoJS, dll) secara instan tanpa menunggu waktu jeda otomatis.
   * Tekan tombol **"Unlock"** (gembok merah) kembali untuk memunculkan tombol rotasi dan mengaktifkan kembali kontrol pemutaran.
4. **True Edge-to-Edge Fullscreen (Bebas Margin Hitam)**: 
   * Menggunakan modifikasi viewport dinamis dan injeksi CSS secara real-time saat rotasi diaktifkan.
   * Mematikan safe area insets secara otomatis di mode landscape agar video memenuhi seluruh layar fisik iPhone tanpa terpotong notch atau home indicator.
   * Memaksa pemutar video HTML5 untuk merender ulang dimensinya secara penuh (*edge-to-edge*).
5. **Keamanan & Blokir Pop-up (Adware Blocker)**:
   * Dilengkapi aturan penanganan navigasi di tingkat native (`WKNavigationDelegate` & `WKUIDelegate`).
   * Memblokir pembuatan window pop-up baru atau pengalihan (*redirect*) ke situs iklan pihak ketiga yang tidak tepercaya (di luar domain `cineby`).

---

## Struktur Proyek

* [ios-cineby/](file:///d:/code/App/cineby/ios-cineby/): Berisi file sumber Swift native utama yang mengatur logika tampilan, navigasi, dan rotasi visual:
  * [AppDelegate.swift](file:///d:/code/App/cineby/ios-cineby/AppDelegate.swift) (Konfigurasi aplikasi tingkat global)
  * [SceneDelegate.swift](file:///d:/code/App/cineby/ios-cineby/SceneDelegate.swift) (Manajer Window dan Root ViewController)
  * [OrientationNavigationController.swift](file:///d:/code/App/cineby/ios-cineby/OrientationNavigationController.swift) (Navigation Controller kustom pendukung rotasi VC)
  * [WebViewController.swift](file:///d:/code/App/cineby/ios-cineby/WebViewController.swift) (Inti aplikasi: konfigurasi WKWebView, UI tombol, visual rotasi, dan injeksi script)
* [capacitor-app/](file:///d:/code/App/cineby/capacitor-app/): Struktur aplikasi Capacitor sebagai basis proyek web-to-native, aset, serta skrip integrasi.
* [.github/workflows/](file:///d:/code/App/cineby/.github/workflows/): Alur kerja integrasi otomatis (CI/CD) GitHub Actions untuk mengompilasi aplikasi menjadi file `.ipa` secara otomatis di cloud macOS.

---

## Alur Kerja Build Otomatis (GitHub Actions)

Aplikasi ini menggunakan skrip penyelarasan otomatis sehingga Anda tidak perlu memiliki komputer Mac untuk mengompilasi aplikasinya.

1. Lakukan perubahan kode pada file Swift di folder `ios-cineby/`.
2. Lakukan **Git Commit** dan **Push** perubahan Anda ke branch `main` atau `master` di GitHub.
3. GitHub Actions akan otomatis memicu workflow `Build iOS (.ipa)`. Workflow ini akan:
   * Mengunduh kode di server macOS virtual.
   * Menjalankan [patch_ios.sh](file:///d:/code/App/cineby/capacitor-app/patch_ios.sh) untuk menyalin dan menggabungkan kode terbaru dari `ios-cineby/` ke dalam proyek target iOS.
   * Menyaring baris `import` yang duplikat agar kompilasi Swift berjalan lancar.
   * Melakukan kompilasi proyek Xcode menggunakan perintah `xcodebuild` tanpa penandatanganan sertifikat developer (`unsigned`).
   * Membungkus aplikasi ke dalam arsip `.ipa` siap pasang.
4. Setelah build selesai, unduh file `unsigned-App.ipa` dari tab **Actions** di repositori GitHub Anda.

---

## Cara Instalasi di iPhone (Windows / macOS)

Karena file `.ipa` yang dihasilkan tidak ditandatangani secara resmi (unsigned), Anda dapat memasangnya ke iPhone fisik menggunakan alat sideload gratis:

1. Unduh dan instal **Sideloadly** di komputer Windows atau Mac Anda.
2. Sambungkan iPhone Anda ke komputer menggunakan kabel data.
3. Buka Sideloadly, masukkan Apple ID Anda, lalu seret file `unsigned-App.ipa` ke dalam kolom Sideloadly.
4. Klik **Start** dan tunggu hingga proses instalasi selesai.
5. Di iPhone Anda, masuk ke **Settings → General → VPN & Device Management**, ketuk Apple ID Anda, lalu pilih **Trust** agar aplikasi dapat dibuka.

---

## Panduan Penggunaan

1. Buka aplikasi **Cineby** di iPhone Anda.
2. Jelajahi situs dan pilih film yang ingin Anda tonton.
3. Saat film mulai diputar, ketuk tombol **"Rotate ↻"** di pojok kanan atas navigation bar.
4. Layar aplikasi akan berputar 90 derajat. Miringkan iPhone Anda secara horizontal untuk menonton film dalam tampilan landscape layar penuh.
5. Saat berada di mode landscape, Anda dapat menekan tombol bulat gembok terbuka di sebelah kiri bawah landscape untuk mengunci layar. Tombol akan berubah menjadi merah dengan gembok tertutup, dan tombol rotasi di sebelah kanan akan langsung menghilang beserta seluruh bilah kontrol pemutar film secara instan. Tombol gembok merah tersebut kemudian akan otomatis menghilang setelah 3 detik.
6. Untuk membuka kunci: Ketuk layar kosong sekali di mana saja untuk memunculkan kembali tombol merah gembok, lalu segera ketuk tombol gembok tersebut untuk membuka kunci. Setelah terbuka, ketuk tombol melayang bulat rotasi di pojok kanan bawah untuk mengembalikan aplikasi ke mode tegak normal.
