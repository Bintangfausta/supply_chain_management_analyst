# Supply Chain Supplier Performance, Cost & Quality Risk Analysis

## 1. Executive Summary

Proyek ini menganalisis data transaksi procurement dalam supply chain yang melibatkan banyak Supplier, Location, dan Product Type. Data mentah datang dengan format tidak konsisten — penulisan kode Supplier yang berantakan, nama kota dengan banyak varian ejaan, dan Order Date yang tercampur dalam lima format berbeda — dibersihkan dan distandarisasi terlebih dahulu, sebelum dimodelkan dan divisualisasikan dalam Power BI. Analisis ini tidak berhenti pada pelaporan angka, melainkan menjawab pertanyaan bisnis inti: **Supplier mana yang paling cost-efficient, paling cepat memenuhi pesanan, dan paling konsisten kualitasnya — dan keputusan sourcing apa yang perlu diambil tim procurement berdasarkan hal tersebut?**


### Business Goals & Objectives

- Mengukur Total Cost dan Ordered Quantity secara keseluruhan, termasuk tren Monthly Orders dan Daily Orders.
- Membandingkan efisiensi biaya antar Supplier, dari sisi Unit Cost tertinggi/terendah maupun rata-rata Unit Cost per Product Type.
- Mengevaluasi kecepatan pemenuhan pesanan melalui Manufacturing Lead Time vs. Supplier Lead Time, untuk membedakan Supplier tercepat dari yang paling lambat.
- Mengukur performa kualitas melalui Inspection Result (Pass / Fail / Pending) dan Defect Rate, termasuk mengidentifikasi SKU dengan Defect Rate tertinggi dan terendah.
- Memetakan distribusi Total Cost dan Revenue berdasarkan kombinasi Location, Supplier, dan Product Type untuk mendukung keputusan sourcing dan alokasi anggaran.

---

## 2. Tech Stack / Tools Used

| Layer | Tools |
|---|---|
| Data Cleaning & Standardization | SQL (MySQL) |
| Data Modeling & DAX Measures | Power BI Desktop |
| Data Visualization & Reporting | Power BI Desktop |
| Environment | MySQL Workbench, Power BI Desktop |

---

## 3. Business Problems Addressed

Dashboard ini disusun untuk menjawab pertanyaan-pertanyaan bisnis berikut:

1. Berapa Total Cost dan Ordered Quantity secara keseluruhan, dan bagaimana tren Monthly Orders maupun Daily Orders?
2. Berapa Unit Cost tertinggi dan terendah yang tercatat, serta bagaimana rata-rata Unit Cost bervariasi antar Supplier dan Product Type?
3. Supplier mana yang memiliki Lead Time terbaik — baik dari sisi Manufacturing Lead Time maupun Supplier Lead Time?
4. Supplier mana yang memasok jumlah SKU terbanyak, dan bagaimana distribusi jumlah SKU di setiap Supplier?
5. Berapa Total Cost yang terasosiasi dengan setiap kombinasi Location dan Supplier?
6. Bagaimana distribusi Inspection Result (Pass / Fail / Pending), dan berapa rata-rata Defect Rate secara keseluruhan?
7. SKU mana yang memiliki Defect Rate tertinggi dan terendah?
8. Supplier mana yang menghasilkan Revenue tertinggi, dan bagaimana Revenue tersebut terdistribusi lintas Location dan Product Type?

---

## 4. Data Pipeline & Methodology

Proyek ini mengikuti alur kerja **Clean → Model → Visualize**, terbagi menjadi dua tahap:

**Stage 1 — Data Cleaning & Standardization (SQL)**
- Mengimpor dataset mentah (`Supply_Chain_Management_Dataset_RAW.csv`) ke tabel `supply_chain` pada database MySQL, lalu melakukan inspeksi awal terhadap isi data.
- Menstandarkan kolom `Supplier` dengan `TRIM` + `UPPER` untuk menyatukan variasi penulisan (contoh: `"s2"`, `" S3"`, `"S4 "`) menjadi kode yang konsisten.
- Menstandarkan kolom `Location` dalam dua langkah: (1) `TRIM` + `UPPER` untuk menyeragamkan casing dan spasi liar, kemudian (2) memetakan nama kota alternatif/legacy ke lima kota baku — misalnya `BANGLORE`/`BENGALURU` → **Bangalore**, `KOLKATTA`/`CALCUTTA` → **Kolkata**, `BOMBAY` → **Mumbai**, dan `NEW DELHI` → **Delhi**.
- Menstandarkan kolom `Order_Date` yang awalnya mencampur **lima format tanggal berbeda** (ISO `YYYY-MM-DD`, `DD/MM/YYYY`, `MM/DD/YYYY`, `DD-Mon-YYYY`, dan `Month DD, YYYY`) — setiap pola dideteksi berdasarkan bentuk/kata kuncinya, diparsing sesuai formatnya masing-masing, dikonversi ke teks ISO, baru kemudian tipe kolom diubah menjadi `DATE` murni.
- Menangani ambiguitas pada format bertanda slash (ketika kedua segmen tanggal bernilai ≤ 12, sehingga urutan hari/bulan tidak bisa dipastikan hanya dari string) dengan men-default-kan kasus tersebut ke konvensi `DD/MM/YYYY`, disertai catatan eksplisit di dalam script bahwa asumsi ini perlu dikonfirmasi ke source system pada proyek nyata — bukan sekadar ditebak.
- Menjalankan serangkaian **data quality checks** pasca-cleaning: memastikan tidak ada `Order_Date` yang gagal diparsing (NULL tak terduga), memvalidasi bahwa `Supplier` dan `Location` hanya berisi nilai baku yang diharapkan, memeriksa distribusi `Inspection_Result`, mendeteksi `Order_ID` yang duplikat, dan memverifikasi struktur akhir tabel (`DESCRIBE`).

**Stage 2 — Data Modeling & Dashboard Development (Power BI)**
- Memuat dataset yang sudah bersih ke Power BI dan membangun data model dengan fact table `SupplyChainData`, measures table terpisah (`M1`), dan auto date table untuk mendukung analisis berbasis waktu.
- Membuat DAX measures kunci, termasuk dua definisi yang secara khusus mengkodifikasi logika bisnis:
  - `Avg Lead Time (Days)` — merepresentasikan **total waktu pemenuhan pesanan**, yaitu jumlah hari sejak pesanan dibuat hingga produk siap/diterima (`Manufacturing_Lead_Time_Days` + `Supplier_Lead_Time_Days`), dirata-ratakan di seluruh order.
  - `SKU High Defect` dan `SKU Low Defect` — menghitung jumlah SKU dengan `Defect_Rate` di atas dan di bawah/sama dengan ambang **2%**:
    ```DAX
    SKU High Defect = CALCULATE(COUNT(SupplyChainData[SKU]), SupplyChainData[Defect_Rate] > 2)
    SKU Low Defect  = CALCULATE(COUNT(SupplyChainData[SKU]), SupplyChainData[Defect_Rate] <= 2)
    ```
  - Measures lain: `Total Cost`, `Average Defect Rate`, `Monthly Orders`, `Daily Orders`, `Max/Min Cost per Unit`, `Avg Manufacturing Lead Time`, `Avg Supplier Lead Time`.
- Merancang dashboard satu halaman yang interaktif dengan slicer `Product_Type` sebagai filter global, didukung empat KPI card utama (**Total Cost**, **Ordered Qty**, **Avg Lead Time**, **Avg Defect Rate**) beserta multi-row card pendukung di bawah masing-masing.
- Membangun visual analitis: donut chart distribusi `Inspection_Result`, bar chart *Revenue by Supplier*, tiga bar chart perbandingan Supplier (jumlah SKU, Lead Time, volume produk terbanyak), pivot table *Total Cost per Location x Supplier*, ribbon chart *Revenue by Location across Product Type*, dan clustered column chart *Average Unit Cost by Supplier per Product Type*.

---

## 5. Key Business Insights & Recommendations

**Insight 1 — Ketergantungan Cost Terkonsentrasi pada Satu Supplier dan Satu Location**
- **S1** menyumbang **26,8%** dari total Total Cost ($463.228,27 dari $1.728.266,20), sementara dari sisi Location, **Kolkata** menyumbang **26,3%** ($454.355,42). Titik konsentrasi tertinggi ada pada kombinasi **S1 di Kolkata**, yang sendirian menyumbang **$126.560,75 (7,3%)** dari seluruh Total Cost — sel tunggal terbesar di seluruh pivot table Supplier x Location.
- **Rekomendasi:** Prioritaskan audit kontrak dan opsi diversifikasi sourcing untuk kombinasi S1–Kolkata, karena di sanalah konsentrasi risiko dan potensi penghematan (melalui negosiasi ulang) paling besar.

**Insight 2 — Supplier dengan Volume Terbesar Bukan yang Tercepat**
- **S1** unggul di hampir semua dimensi volume — SKU terbanyak (**56**), Ordered Quantity tertinggi (**2.459 unit**), dan Revenue tertinggi (**$185.890,50**) — namun rata-rata Lead Time-nya (**28,71 hari**) masih lebih lambat dibanding **S3**, yang justru mencatat Lead Time tercepat di seluruh Supplier (**26,81 hari**), meski volumenya paling kecil (26 SKU, 1.259 unit).
- Sebaliknya, **S4** mencatat Lead Time terlambat (**29,58 hari**) dari seluruh Supplier.
- **Rekomendasi:** Jangan menjadikan volume sebagai satu-satunya dasar alokasi pesanan. Pertimbangkan mengalihkan sebagian pesanan yang sensitif terhadap waktu (fast-moving SKU) ke S3, dan evaluasi ulang ketergantungan pada S4 untuk kebutuhan yang time-critical.

**Insight 3 — Efisiensi Unit Cost Sangat Bergantung pada Kombinasi Supplier dan Product Type, Bukan Supplier Saja**
- **S4** mencatat rata-rata Unit Cost terendah untuk **Cosmetics** ($145,52) dan **Haircare** ($130,60), menjadikannya pilihan paling cost-efficient di dua kategori tersebut.
- Namun **S5** — yang paling murah untuk **Skincare** ($172,97) — justru mencatat Unit Cost **tertinggi di seluruh matriks** untuk **Haircare** ($237,91), lebih dari 80% lebih mahal dibanding S4 pada kategori yang sama.
- **Rekomendasi:** Terapkan strategi sourcing per kombinasi Supplier–Product Type, bukan per Supplier secara umum. Alihkan pembelian Haircare dari S5 ke S4 atau S3 (Unit Cost $141,08) untuk potensi penghematan biaya yang signifikan.

**Insight 4 — Hampir Setengah dari Seluruh Order Gagal Lolos Inspeksi Kualitas**
- Dari 200 order, **Fail** adalah hasil Inspection Result yang paling sering muncul (**43,5%**, 87 order) — melebihi Pass (36,0%, 72 order) dan Pending (20,5%, 41 order).
- Menariknya, rata-rata Defect Rate antar ketiga hasil inspeksi ini relatif berdekatan (Fail 3,24%, Pass 2,99%, Pending 2,95%), dengan selisih hanya 0,29 poin persentase — mengindikasikan bahwa keputusan Pass/Fail kemungkinan tidak semata-mata ditentukan oleh besaran Defect Rate saja.
- Secara keseluruhan, **136 dari 200 SKU (68%)** berada di atas ambang Defect Rate 2% (`SKU High Defect`), dan hanya **64 SKU (32%)** yang berada di bawah/sama dengan ambang tersebut (`SKU Low Defect`).
- **Rekomendasi:** Tingkat kegagalan inspeksi sebesar 43,5% tergolong tinggi dan perlu menjadi perhatian utama tim quality control. Investigasi kriteria inspeksi di luar Defect Rate numerik, dan prioritaskan root-cause analysis pada SKU yang masuk kategori `SKU High Defect`.

**Insight 5 — Setiap Location Memiliki Pola Product Type Unggulan yang Berbeda**
- **Kolkata** adalah Location dengan Revenue tertinggi (**$147.067,09**), didorong oleh **Haircare** ($60.643,17). **Bangalore** adalah yang terendah (**$117.831,17**), dengan **Cosmetics** sebagai kontributor utamanya ($55.136,59).
- Pola preferensi Product Type per Location bervariasi: Haircare unggul di Chennai dan Kolkata, Skincare unggul di Delhi dan Mumbai, sementara Cosmetics unggul di Bangalore. Secara keseluruhan, ketiga Product Type relatif seimbang kontribusinya terhadap total Revenue $657.837,61 (Cosmetics 35,1%, Haircare 33,7%, Skincare 31,1%).
- **Rekomendasi:** Sesuaikan alokasi inventory dan strategi sourcing produk berdasarkan pola regional ini — misalnya memperkuat stok Skincare di Delhi/Mumbai dan Haircare di Chennai/Kolkata — alih-alih menerapkan bauran produk yang seragam di semua Location.

---

## 6. Repository Structure

```
supply-chain-management-analysis/
│
├── README.md                                   # Project overview and business insights
├── data/
│   ├── supply_chain_management_dataset_raw.csv # Raw source dataset 
│   └── supply_chain_management_dataset_clean.xlsx      # Cleaned dataset after SQL processing
│
├── supply_chain_data_cleaning.sql              # Data cleaning & standardization script (MySQL)
│
├── Supply_Chain_Management.pbix                # Power BI dashboard (data model, DAX measures & visuals)
│
└── assets/                                     # Dashboard screenshots for README
```

> File `.pbix` dapat dibuka dan dieksplorasi secara interaktif menggunakan **Power BI Desktop** (gratis, tersedia untuk Windows).

---

### Author's Note
Proyek ini mendemonstrasikan end-to-end analytics workflow — mulai dari data procurement mentah yang tidak konsisten hingga menjadi dataset bersih yang terstandarisasi, dilanjutkan dengan business intelligence berbasis Power BI — mencerminkan jenis analisis yang akan disampaikan seorang supply chain / data analyst untuk mendukung keputusan sourcing, cost control, dan quality management di level manajemen procurement.
