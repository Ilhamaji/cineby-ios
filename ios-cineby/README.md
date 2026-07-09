# Cineby iOS — Minimal WKWebView App

Instruksi singkat untuk menjalankan demo ini di Xcode:

1. Buka Xcode → Create a new project → App (iOS).
2. Pilih interface `UIKit` dan lifecycle `UIKit App Delegate`.
3. Hapus Main.storyboard (opsional) dan atur `SceneDelegate` untuk membuat `WebViewController` sebagai root.
4. Salin file `AppDelegate.swift`, `SceneDelegate.swift`, dan `WebViewController.swift` dari folder ini ke target Xcode Anda.
5. Pastikan Deployment Target iOS 13+.
6. Build & Run di simulator atau perangkat nyata. Untuk tes orientation penuh gunakan perangkat fisik.

Catatan:

- Aplikasi ini menyuntikkan sebuah tombol `Rotate` ke halaman web (`cineby.at`). Tombol akan mengirimkan pesan ke native untuk toggle orientasi antara portrait/landscape.
- Anda mungkin perlu menyesuaikan selektor JS jika situs mengubah struktur DOM.
