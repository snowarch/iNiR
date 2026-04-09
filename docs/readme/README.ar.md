<div dir="rtl">

<p align="center">
  <img src="https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8" alt="iNiR" width="800">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>واجهة سطح مكتب كاملة لـ Niri، مبنية على Quickshell</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.18.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
</p>

<p align="center">
  <a href="../INSTALL.md">التثبيت</a> &bull;
  <a href="../KEYBINDS.md">اختصارات لوحة المفاتيح</a> &bull;
  <a href="../IPC.md">مرجع IPC</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">المساهمة</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **حول الترجمة:** ترجمة مجتمعية. في حال وجود أي غموض، راجع [النسخة الإنجليزية](../../README.md).

---

<details>
<summary><b>أول مرة هنا؟ اضغط إذا ما تعرف شو هذا 🤔</b></summary>

### شو هذا؟

iNiR هو سطح المكتب كامل. الشريط فوق، الدوك، الإشعارات، الإعدادات، الخلفيات، كل شي. مو ثيم، مو ملفات dotfiles تنسخها. شل كامل يشتغل على لينكس.

### شو أحتاج عشان أشغله؟

كومبوزيتر. هذا اللي يدير النوافذ ويحط البكسلات على الشاشة. iNiR مصمم لـ [Niri](https://github.com/YaLTeR/niri) (كومبوزيتر Wayland تايلنق). في كود قديم من Hyprland من أيام ما كان فورك من dots الـ end-4، بس Niri هو اللي فعلياً أجربه وأستخدمه.

الشل يشتغل على [Quickshell](https://quickshell.outfoxxed.me/)، فريمورك لبناء شلات بـ QML (لغة UI من Qt). ما تحتاج تعرفها عشان تستخدمه، كل شي يتضبط من الـ GUI أو ملف JSON.

### كيف كل شي مرتبط

```
تطبيقاتك
   ↓
iNiR (شل: بار، سايدبار، دوك، إشعارات، إعدادات...)
   ↓
Quickshell (يشغل شلات QML)
   ↓
Niri (كومبوزيتر: نوافذ، رندرنق)
   ↓
Wayland ← GPU
```

### هل هو مستقر؟

مشروع شخصي طلع عن السيطرة. أستخدمه كل يوم، ناس كثير في الـ Discord بعد. بس أحياناً ينكسر، الكود فوضوي في أماكن، أتعلم وأنا أسوي.

إذا شي ما اشتغل، `inir doctor` يصلح أغلب الأشياء. إذا ما نفع، الـ Discord نشط. لا تتوقع سوفتوير مصقول، هذا rice شخص واحد عجب ناس ثانيين.

### ليش موجود؟

كنت أبي سطح المكتب يطلع ويشتغل بطريقة معينة، وما في شي ثاني يسويها بالظبط. بدأ كـ dots الـ end-4 لـ Hyprland، صار ريرايت كامل لـ Niri مع فيتشرز أكثر بكثير.

### كلمات راح تشوفها

- **Shell**: طبقة الـ UI (بار، بانلز، أوفرليز)
- **Compositor**: يدير النوافذ، يرسم على الشاشة (Niri، Hyprland، Sway...)
- **Wayland**: بروتوكول العرض في لينكس (الجديد، بديل X11)
- **QML**: لغة UI من Qt، iNiR مكتوب فيها
- **Material You**: نظام ألوان قوقل اللي يسوي باليتات من الصور (كذا يشتغل الـ auto-theming)
- **ii / waffle**: ستايلين للبانل. ii = فايب Material Design، waffle = فايب Windows 11. `Super+Shift+W` يبدل بينهم

</details>

---

## لقطات الشاشة

<details open>
<summary><b>Material ii</b> — شريط عائم، أشرطة جانبية، جمالية Material Design</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b> — شريط مهام سفلي، مركز الإجراءات، أسلوب Windows 11</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

## الميزات

**عائلتان من اللوحات**، قابلة للتبديل أثناء التشغيل بـ `Super+Shift+W`:
- **Material ii** — شريط عائم، أشرطة جانبية، رصيف، 5 أنماط بصرية (material، cards، aurora، inir، angel)
- **Waffle** — شريط مهام بأسلوب Windows 11، قائمة ابدأ، مركز الإجراءات، مركز الإشعارات

**سمات تلقائية** — اختر خلفية ويتكيف كل شيء:
- ألوان الواجهة عبر Material You، تنتشر إلى GTK3/4، Qt، المحطات الطرفية، Firefox، Discord، SDDM
- 10 أدوات طرفية تلقائية السمات (foot، kitty، alacritty، starship، fuzzel، btop، lazygit، yazi)
- قوالب سمات: Gruvbox، Catppuccin، Rosé Pine، ومخصصة

**المُركّب** — مصمم لـ Niri.

<details>
<summary><b>قائمة الميزات الكاملة</b></summary>

### السمات والمظهر

اختر خلفية والنظام بأكمله يتبع — الواجهة، تطبيقات GTK/Qt، المحطات الطرفية، Firefox، Discord، شاشة تسجيل الدخول SDDM. تلقائياً بالكامل.

- **5 أنماط بصرية** — Material (صلب)، Cards، Aurora (ضبابية زجاجية)، iNiR (مستوحى من TUI)، Angel (وحشية جديدة)
- **ألوان ديناميكية من الخلفية** عبر Material You — تنتشر في كل النظام
- **10 أدوات طرفية تلقائية السمات** — foot، kitty، alacritty، starship، fuzzel، pywalfox، btop، lazygit، yazi
- **سمات التطبيقات** — GTK3/4، Qt (عبر plasma-integration + darkly)، Firefox (MaterialFox)، Discord/Vesktop (System24)
- **قوالب سمات** — Gruvbox، Catppuccin، Rosé Pine، والمزيد — أو أنشئ قالبك الخاص
- **خلفيات فيديو** — mp4/webm/gif مع ضبابية اختيارية، أو تجميد الإطار الأول للأداء
- **سمة تسجيل دخول SDDM** — ألوان Material You متزامنة مع الخلفية
- **ودجات سطح المكتب** — ساعة (أنماط متعددة)، طقس، تحكم بالوسائط على طبقة الخلفية

### الأشرطة الجانبية والودجات (Material ii)

الشريط الجانبي الأيسر (درج التطبيقات):
- **محادثة ذكاء اصطناعي** — Gemini، Mistral، OpenRouter، أو نماذج محلية عبر Ollama
- **YT Music** — مشغل كامل مع بحث وقائمة انتظار وتحكم
- **متصفح Wallhaven** — ابحث وطبّق الخلفيات مباشرة
- **متتبع أنمي** — تكامل مع AniList وعرض الجدول
- **تغذية Reddit** — تصفح المنتديات الفرعية مباشرة
- **مترجم** — عبر Gemini أو translate-shell
- **ودجات قابلة للسحب** — عملات رقمية، مشغل وسائط، ملاحظات سريعة، حلقات الحالة، تقويم أسبوعي

الشريط الجانبي الأيمن:
- **تقويم** مع تكامل الأحداث
- **مركز الإشعارات**
- **مفاتيح سريعة** — WiFi، Bluetooth، إضاءة ليلية، عدم الإزعاج، ملفات تعريف الطاقة، WARP VPN، EasyEffects
- **خلاط الصوت** — تحكم لكل تطبيق
- **إدارة أجهزة Bluetooth وWiFi**
- **مؤقت بومودورو**، **قائمة مهام**، **آلة حاسبة**، **مفكرة**
- **مراقب النظام** — CPU، RAM، الحرارة

### الأدوات

- **نظرة عامة على مساحات العمل** — متكيفة مع نموذج التمرير في Niri، مع بحث التطبيقات وآلة حاسبة
- **مبدّل النوافذ** — Alt+Tab عبر كل مساحات العمل
- **مدير الحافظة** — سجل مع بحث ومعاينة الصور
- **أدوات المنطقة** — لقطات شاشة، تسجيل شاشة، OCR، بحث عكسي عن الصور
- **ورقة مختصرات** — عارض اختصارات مستخرج من إعدادات Niri
- **تحكم بالوسائط** — مشغل MPRIS كامل مع قوالب تخطيط متعددة
- **عرض على الشاشة** — OSD للصوت والسطوع والوسائط
- **التعرف على الأغاني** — تعريف بأسلوب Shazam عبر SongRec
- **بحث صوتي** — سجّل وابحث عبر Gemini

### النظام

- **إعدادات واجهة رسومية** — إعداد كل شيء بدون تحرير ملفات
- **GameMode** — تعطيل تلقائي للتأثيرات عند التطبيقات بملء الشاشة
- **تحديثات تلقائية** — `inir update` مع تراجع وترحيل وحفظ تغييرات المستخدم
- **شاشة القفل** و**شاشة الجلسة** (تسجيل خروج/إعادة تشغيل/إيقاف/سكون)
- **وكيل Polkit**، **لوحة مفاتيح على الشاشة**، **مدير التشغيل التلقائي**
- **9 لغات** — كشف تلقائي، مع توليد ترجمات بمساعدة الذكاء الاصطناعي
- **إضاءة ليلية** — مجدولة أو يدوية
- **الطقس** — Open-Meteo، يدعم GPS، إحداثيات يدوية، أو اسم المدينة
- **إدارة البطارية** — حدود قابلة للتكوين، سكون تلقائي عند المستوى الحرج
- **مدقق تحديثات الواجهة** — يُعلم عند توفر إصدارات جديدة

</details>

---

## البداية السريعة

<div dir="ltr">

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # تفاعلي — يسأل قبل كل خطوة
./setup install -y    # تلقائي — بدون أسئلة
```

</div>

يتعامل المُثبّت مع التبعيات، إعداد النظام، السمات — كل شيء. بعد التثبيت، شغّل `inir run` أو سجّل الخروج وأعد تسجيل الدخول.

<div dir="ltr">

```bash
inir run                        # تشغيل الواجهة
inir settings                   # فتح إعدادات واجهة رسومية
inir logs                       # فحص سجلات وقت التشغيل
inir doctor                     # تشخيص وإصلاح تلقائي
inir update                     # سحب + ترحيل + إعادة تشغيل
```

</div>

**التوزيعات المدعومة:** Arch (مثبّت آلي). التوزيعات الأخرى يمكنها التثبيت يدوياً — راجع [PACKAGES.md](../PACKAGES.md).

| الطريقة | الأمر |
|--------|---------|
| تثبيت نظام | `sudo make install && inir run` |
| قائمة TUI | `./setup` |
| تراجع | `./setup rollback` |

---

## اختصارات لوحة المفاتيح

| المفتاح | الإجراء |
|-----|--------|
| `Super+Space` | نظرة عامة — بحث التطبيقات، التنقل بين مساحات العمل |
| `Alt+Tab` | مبدّل النوافذ |
| `Super+V` | سجل الحافظة |
| `Super+Shift+S` | لقطة شاشة منطقة |
| `Super+Shift+X` | OCR منطقة |
| `Super+,` | الإعدادات |
| `Super+Shift+W` | تبديل عائلة اللوحات |

القائمة الكاملة: [KEYBINDS.md](../KEYBINDS.md)

---

## الخلفيات

15 خلفية مضمنة. للمزيد، تحقق من [iNiR-Walls](https://github.com/snowarch/iNiR-Walls) — مجموعة منسقة تعمل جيداً مع خط أنابيب Material You.

---

## التوثيق

| | |
|---|---|
| [INSTALL.md](../INSTALL.md) | دليل التثبيت |
| [SETUP.md](../SETUP.md) | أوامر الإعداد — تحديثات، ترحيل، تراجع |
| [KEYBINDS.md](../KEYBINDS.md) | جميع اختصارات لوحة المفاتيح |
| [IPC.md](../IPC.md) | أهداف IPC للنصوص البرمجية والاختصارات |
| [PACKAGES.md](../PACKAGES.md) | كل تبعية ولماذا هي موجودة |
| [LIMITATIONS.md](../LIMITATIONS.md) | القيود المعروفة والحلول البديلة |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | نظرة عامة على البنية التقنية |

---

## استكشاف الأخطاء وإصلاحها

<div dir="ltr">

```bash
inir logs                       # فحص سجلات وقت التشغيل الأخيرة
inir restart                    # إعادة تشغيل وقت التشغيل النشط
inir repair                     # doctor + إعادة تشغيل + فحص سجلات مفلترة
./setup doctor                  # تشخيص وإصلاح المشاكل الشائعة تلقائياً
./setup rollback                # التراجع عن آخر تحديث
```

</div>

تحقق من [LIMITATIONS.md](../LIMITATIONS.md) قبل فتح issue.

---

## المساهمة

انظر [CONTRIBUTING.md](../../CONTRIBUTING.md) — إعداد بيئة التطوير، أنماط الكود، وإرشادات طلبات السحب.

---

## الشكر والتقدير

- [**end-4**](https://github.com/end-4/dots-hyprland) — illogical-impulse الأصلي لـ Hyprland
- [**Quickshell**](https://quickshell.outfoxxed.me/) — الإطار الذي يشغّل هذه الواجهة
- [**Niri**](https://github.com/YaLTeR/niri) — مُركّب Wayland للتبليط بالتمرير

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">المساهمون</a> &bull;
  <a href="CHANGELOG.md">سجل التغييرات</a> &bull;
  <a href="LICENSE">رخصة MIT</a>
</p>

</div>
