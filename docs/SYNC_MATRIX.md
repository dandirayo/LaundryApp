# LaundryApp Sync Matrix — Chat 3

Status ini konservatif: `PASS` hanya untuk pemeriksaan/test lokal; komunikasi dua perangkat tetap `NEEDS MANUAL TEST`.

| Feature | Owner → Employee | Employee → Owner | Realtime | Pull Refresh | Notification | RLS Safe | Tested | Notes |
|---|---|---|---|---|---|---|---|---|
| Orders | NEEDS MANUAL TEST | NEEDS MANUAL TEST | PASS | PASS | PARTIAL | PARTIAL | PASS | Channel shop mendengar `orders`, `order_items`, dan `payments`; trigger notifikasi order belum diverifikasi E2E. |
| Customers | NEEDS MANUAL TEST | NEEDS MANUAL TEST | PASS | PASS | NOT APPLICABLE | PARTIAL | PASS | Duplicate berdasarkan normalized phone; customer tanpa nomor valid. |
| Payments | NEEDS MANUAL TEST | NEEDS MANUAL TEST | PASS | PASS | PARTIAL | PARTIAL | PASS | Perubahan payment me-refresh order; ledger canonical dibuat trigger DB. |
| Expenses | NEEDS MANUAL TEST | NOT APPLICABLE | PASS | PASS | NOT APPLICABLE | PASS | PASS | Owner-only route + RLS; ledger melalui trigger. |
| Payroll | NEEDS MANUAL TEST | NOT APPLICABLE | PASS | PASS | PARTIAL | PASS | PASS | Guard UI dan unique DB ada; visibility history employee perlu device test. |
| Attendance | NEEDS MANUAL TEST | NEEDS MANUAL TEST | PASS | PASS | PARTIAL | PARTIAL | PASS | Subscription `attendance_records` ditambahkan; upload kamera perlu device test. |
| Weekly Shifts | NEEDS MANUAL TEST | NOT APPLICABLE | PASS | PASS | PASS | PASS | PASS | Shop-filtered realtime; RLS membatasi employee terkait. |
| Employee Requests | NEEDS MANUAL TEST | NEEDS MANUAL TEST | PASS | PASS | PASS | PASS | PASS | Notification trigger durable tersedia; transition/RLS masih perlu production verification. |
| Inventory | NEEDS MANUAL TEST | NEEDS MANUAL TEST | PASS | PASS | PARTIAL | PASS | PASS | Item dan movement dalam satu channel; low-stock notification perlu device test. |
| Notifications | NEEDS MANUAL TEST | NEEDS MANUAL TEST | PASS | PARTIAL | PASS | PASS | PASS | Durable rows, unread/mark-read, safe route fallback; pull-to-refresh UI belum eksplisit. |
| Dashboard | NEEDS MANUAL TEST | NEEDS MANUAL TEST | PARTIAL | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | Menonton controller operasional; cash/payroll summary lintas device perlu manual test. |
| Contact Import | NEEDS MANUAL TEST | NEEDS MANUAL TEST | PASS | PASS | NOT APPLICABLE | PARTIAL | PASS | Device contacts saja; Google Contacts terlihat bila tersinkron ke Android Contacts. |
| Admin Dashboard Web | NEEDS MANUAL TEST | NEEDS MANUAL TEST | PARTIAL | PARTIAL | NOT APPLICABLE | PARTIAL | PARTIAL | Tidak memakai `employees.pin`; canonical ledger perlu browser/manual verification. |

## Audit source dan recovery

| Feature | Source | Repository/controller | Recovery / catatan audit |
|---|---|---|---|
| Orders / payments | `orders`, `order_items`, `payments` | `OrderRepository` / `OrderController` | Realtime shop + pull refresh; widget tidak query Supabase langsung. |
| Customers | `customers` | `CustomerRepository` / `CustomerController` | Realtime shop + pull refresh; preview hanya mode preview/offline config. |
| Services | `services` | `ServiceRepository` / `ServiceController` | Realtime shop ditambahkan; halaman memiliki refresh controller. |
| Cashbook | `cash_transactions` | `CashbookRepository` / `CashbookController` | Canonical source benar; realtime shop + refresh. |
| Expenses | `expenses` | `ExpenseRepository` / `ExpenseController` | Realtime shop + refresh; Owner only. |
| Payroll | `payroll_payments` | `PayrollRepository` / `PayrollController` | Realtime shop, retry, dan in-process guard. |
| Employees | `employees`, `profiles` | `EmployeeRepository`; page-managed state | Pull refresh ada; belum controller realtime sehingga `PARTIAL`. |
| Attendance | `attendance_records`, Storage | `AttendanceRepository` / `AttendanceController` | Realtime shop ditambahkan + refresh; error mapper ada di UI. |
| Shifts | `weekly_shifts` | `ShiftRepository` / `ShiftController` | Realtime shop + refresh, RLS employee-specific. |
| Requests | `employee_requests` | `EmployeeRequestRepository` / controller | Realtime shop + refresh; UI filters employee dan RLS adalah enforcement. |
| Inventory | `inventory_items`, `inventory_movements` | repository/controller | Kedua tabel disubscribe dengan shop filter + refresh. |
| Notifications | `notifications` | repository/controller | Durable + realtime shop; RLS target recipient. |
| Dashboard | Controller state di atas | Riverpod providers | Refresh fan-out tersedia; tidak ada query Supabase langsung dari widget. |

## Database follow-up

`supabase/migrations/20260829064248_durable_notification_references.sql` adalah **MANUAL DATABASE CHANGE REQUIRED**. Migration hanya menambah metadata `reference_type`/`reference_id` dan index; tidak menghapus data.
