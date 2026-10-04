package com.elutung.elutung

import io.flutter.embedding.android.FlutterActivity

// FragmentActivity tidak lagi diperlukan sejak fitur kunci aplikasi (local_auth)
// dihapus atas permintaan pengguna. Bila suatu saat menambah plugin yang
// membutuhkannya, ubah kembali ke FlutterFragmentActivity.
class MainActivity : FlutterActivity()
