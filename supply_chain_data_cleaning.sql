/* ============================================================================
   PROJECT   : Supply Chain Management Dashboard
   FILE      : supply_chain_data_cleaning.sql
   PURPOSE   : Clean and standardize the raw supply chain dataset for analysis
   PREREQ    : Import Supply_Chain_Management_Dataset_RAW.csv into a table
               named `supply_chain`
   RUN ORDER : Run this script BEFORE building the dashboard
   ============================================================================ */

-- ----------------------------------------------------------------------------
-- 0. DATABASE SETUP
-- ----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS projects;
USE projects;

-- Cek dulu isi data mentah, belum diproses
SELECT * FROM supply_chain;

SET sql_safe_updates = 0;

-- ----------------------------------------------------------------------------
-- 1. STANDARDIZE SUPPLIER COLUMN
-- ----------------------------------------------------------------------------
-- Data mentah tidak konsisten: casing campur dan spasi nyasar
-- (contoh: "s2", " S3", "S4 ").
SELECT DISTINCT Supplier FROM supply_chain;

UPDATE supply_chain
SET Supplier = UPPER(TRIM(Supplier));

SELECT DISTINCT Supplier FROM supply_chain;

-- ----------------------------------------------------------------------------
-- 2. STANDARDIZE LOCATION COLUMN
-- ----------------------------------------------------------------------------
-- 2.1 TRIM + UPPER dulu, supaya semua variasi casing
-- ("kolkata", "KOLKATA", "Kolkata ") jadi satu bentuk yang bisa dibandingkan.
SELECT DISTINCT Location FROM supply_chain;

UPDATE supply_chain
SET Location = UPPER(TRIM(Location));

-- 2.2 Data mentah juga punya nama alternatif/legacy untuk kota yang sama
-- (contoh: "BANGLORE", "BENGALURU" -> Bangalore;
UPDATE supply_chain
SET Location = CASE
    WHEN Location IN ('BANGALORE', 'BANGLORE', 'BENGALURU') THEN 'Bangalore'
    WHEN Location IN ('KOLKATA', 'KOLKATTA', 'CALCUTTA')    THEN 'Kolkata'
    WHEN Location IN ('CHENNAI')                            THEN 'Chennai'
    WHEN Location IN ('MUMBAI', 'BOMBAY')                   THEN 'Mumbai'
    WHEN Location IN ('DELHI', 'NEW DELHI')                 THEN 'Delhi'
    ELSE Location
END;

SELECT DISTINCT Location FROM supply_chain;

-- ----------------------------------------------------------------------------
-- 3. STANDARDIZE ORDER_DATE COLUMN
-- ----------------------------------------------------------------------------
-- Data sumber mencampur LIMA format tanggal yang berbeda:
--   "2025-01-05"        (ISO, YYYY-MM-DD)
--   "05/01/2025"        (DD/MM/YYYY)
--   "01/05/2025"        (MM/DD/YYYY)      
--   "05-Jan-2025"        (DD-Mon-YYYY)
--   "January 05, 2025"  (Month DD, YYYY)
-- Deteksi setiap pola berdasarkan bentuk/kata kuncinya, lalu parsing sesuai
-- formatnya masing-masing, dan simpan sebagai teks ISO ("YYYY-MM-DD")
-- SEBELUM tipe kolomnya diubah jadi DATE.
SELECT DISTINCT Order_Date FROM supply_chain LIMIT 20;

UPDATE supply_chain
SET Order_Date = CASE
    WHEN Order_Date LIKE '____-__-__'
        THEN Order_Date
    WHEN Order_Date LIKE '%,%'
        THEN DATE_FORMAT(STR_TO_DATE(Order_Date, '%M %d, %Y'), '%Y-%m-%d')
    WHEN Order_Date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
        THEN DATE_FORMAT(STR_TO_DATE(Order_Date, '%d-%b-%Y'), '%Y-%m-%d')
    WHEN Order_Date LIKE '%/%'
         AND SUBSTRING_INDEX(Order_Date, '/', 1) + 0 > 12
        THEN DATE_FORMAT(STR_TO_DATE(Order_Date, '%d/%m/%Y'), '%Y-%m-%d')
    WHEN Order_Date LIKE '%/%'
         AND SUBSTRING_INDEX(SUBSTRING_INDEX(Order_Date, '/', 2), '/', -1) + 0 > 12
        THEN DATE_FORMAT(STR_TO_DATE(Order_Date, '%m/%d/%Y'), '%Y-%m-%d')
    WHEN Order_Date LIKE '%/%'
        THEN DATE_FORMAT(STR_TO_DATE(Order_Date, '%d/%m/%Y'), '%Y-%m-%d')
    ELSE NULL
END;

-- Ubah tipe kolom jadi DATE asli (bukan lagi teks). Secara internal MySQL
-- akan menyimpan ini sebagai tanggal murni ("2025-01-01"), bukan string.
ALTER TABLE supply_chain
MODIFY COLUMN Order_Date DATE;

-- CATATAN soal ambiguitas: kalau kedua segmen pada tanggal berformat slash
-- sama-sama <= 12 (contoh: "05/01/2025"), secara string memang mustahil
-- dipastikan apakah itu 5 Jan atau 1 Mei. Script ini men-default-kan kasus
-- tersebut ke DD/MM/YYYY. Di project nyata, konfirmasikan format export
-- yang sebenarnya ke source system, jangan hanya berasumsi.

SELECT MIN(Order_Date) AS earliest_order, MAX(Order_Date) AS latest_order
FROM supply_chain;

-- ----------------------------------------------------------------------------
-- 4. DATA QUALITY CHECKS
-- ----------------------------------------------------------------------------
-- 4.1 Pastikan tidak ada NULL yang tidak terduga muncul saat parsing tanggal
SELECT COUNT(*) AS unparsed_dates
FROM supply_chain
WHERE Order_Date IS NULL;

-- 4.2 Pastikan Supplier hanya berisi kode bersih yang diharapkan
SELECT DISTINCT Supplier FROM supply_chain ORDER BY Supplier;

-- 4.3 Pastikan Location hanya berisi lima nama kota baku
SELECT DISTINCT Location FROM supply_chain ORDER BY Location;

-- 4.4 Pastikan Inspection_Result hanya berisi Pass / Fail / Pending / NULL
SELECT Inspection_Result, COUNT(*) AS n
FROM supply_chain
GROUP BY Inspection_Result;

-- 4.5 Cek Order_ID yang duplikat (seharusnya unik per baris)
SELECT Order_ID, COUNT(*) AS n
FROM supply_chain
GROUP BY Order_ID
HAVING COUNT(*) > 1;

-- 4.6 Cek struktur tabel final
DESCRIBE supply_chain;