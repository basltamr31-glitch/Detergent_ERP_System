# Windows test access — 1.1.1

1. Extract the complete Windows ZIP to a folder on your computer.
2. Double-click **START-TEST.cmd** in that folder.
3. Click **Enter test app / دخول التطبيق التجريبي**, then choose English or العربية.

No typing or Windows credentials dialog is needed for the test button.
Alternatively, the regular login page has **Open test workspace — no password needed** to open the same separate trial window.
For manual sign-in, use these temporary **test-workspace-only** credentials:

- Username: `tester`
- Password: `Tester@2026!Demo`

The test account has owner permissions so you can try all ERP modules. Start with sample records; the workspace initially has no business records. It saves your test work between launches. The amber TEST banner stays visible across screens, and the window title ends in TEST.

The test workspace stores its own Hive database and account files in the application's local support directory under `test-profile-v1`. It does not open the existing Documents/OneDrive business database. Its Windows single-instance guard is separate: opening START-TEST.cmd twice brings the existing test window forward. Existing business data and accounts are not reset, copied or overwritten. Changes in the test workspace are not synchronized into your business workspace.

Opening **detergent_factory.exe** directly still opens the existing business workspace and requires its original local account. The tester credentials do not work there. “Incorrect username or password” means that the local account details did not match; it is not an application crash. After repeated failures, wait five minutes before trying the business account again. There is no automatic password reset for an existing business owner.

Do not change/remove the tester account while using the shortcut: it uses normal password verification and roles, and does not bypass a changed password or an account lock. Keep the temporary credentials limited to test records.

Keep the executable, all DLLs and data folder together. If the launcher reports an incomplete folder, extract the full archive again. Windows x64 is required. The package remains unsigned; a clean computer may require the Visual C++ runtime described in RELEASE_GUIDE.md.

## خطوات التجربة

فك ضغط الحزمة كاملة، ثم افتح **START-TEST.cmd** واضغط **دخول التطبيق التجريبي**، وبعدها اختر اللغة. اسم المستخدم `tester` وكلمة المرور `Tester@2026!Demo`. لا تحتاج إلى كتابة أي بيانات عند استخدام زر الدخول التجريبي.

هذا الحساب خاص ببيئة تجربة منفصلة بصلاحيات المالك، ويبدأ بسجلات عمل فارغة. تظهر عبارة الوضع التجريبي أعلى جميع الصفحات. تبقى بيانات التجربة محفوظة بعد إغلاق البرنامج. فتح ملف exe مباشرة يستخدم حسابات العمل الأصلية؛ حساب التجربة لا يغيّرها ولا يستبدلها.
