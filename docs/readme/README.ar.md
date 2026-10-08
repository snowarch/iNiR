<div dir="rtl">

<p align="center">
  <img src="../images/iris-2.32-principal.webp" alt="iNiR iRiS desktop" width="900">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>واجهة سطح مكتب كاملة لـ Niri، مبنية على Quickshell</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.32.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-green?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/wiki/INSTALL">التثبيت</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/KEYBINDS">الاختصارات</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/IPC">مرجع IPC</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">المساهمة</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **عن هذه الترجمة:** إن لم يتضح شيء، فالمرجع هو [النسخة الإنجليزية](../../README.md).

---

<details>
<summary><b>🤔 جديد هنا؟ اضغط إن لم تكن تعرف ما هذا كله</b></summary>

### ما هذا؟

iNiR هو سطح مكتبك كله. الشريط في الأعلى، والـ dock، والإشعارات، والإعدادات، والخلفيات، كل شيء. ليس سمة، وليس ملفات dotfiles تلصقها. إنه shell كامل يعمل على Linux.

### ماذا أحتاج لتشغيله؟

مُركِّب (compositor). هو ما يدير نوافذك ويرسم البكسلات على الشاشة. صُنع iNiR من أجل [Niri](https://github.com/YaLTeR/niri) (مُركِّب Wayland بنظام التبليط). بقي بعض كود Hyprland القديم من أيام كان هذا المشروع فرعًا من dots الخاصة بـ end-4، لكن Niri هو ما أستخدمه وأختبره فعلًا.

يعمل الـ shell على [Quickshell](https://quickshell.outfoxxed.me/)، وهو إطار لبناء واجهات shell بلغة QML (لغة الواجهات في Qt). لا تحتاج إلى معرفة أي من هذا لاستخدامه: كل شيء يُضبط من الواجهة الرسومية أو من ملف JSON.

### كيف يترابط كل شيء

<div dir="ltr">

```
your apps
   ↓
iNiR (shell: bar, sidebars, dock, notifications, settings...)
   ↓
Quickshell (runs QML shells)
   ↓
Niri (compositor: windows, rendering)
   ↓
Wayland → GPU
```

</div>

### هل هو مستقر؟

مشروع شخصي خرج عن السيطرة. أستخدمه يوميًا، وكذلك كثيرون في Discord. لكن أشياء تتعطل أحيانًا، والكود فوضوي في بعض المواضع، وأنا أتعلم أثناء العمل.

إن لم يعمل شيء، فإن `inir doctor` يصلح معظم المشاكل. وإن لم يكفِ، فـ Discord نشط. فقط لا تتوقع برنامجًا مصقولًا: هذا rice شخص واحد أعجب آخرين أيضًا.

### لماذا وُجد؟

أردت أن يبدو سطح مكتبي ويعمل بطريقة معينة، ولم يكن هناك ما يفعل ذلك تمامًا. بدأ كـ dots الخاصة بـ end-4 لـ Hyprland، ثم أصبح إعادة كتابة كاملة لـ Niri بميزات أكثر بكثير.

### كلمات ستراها

- **Shell**: طبقة الواجهة (الشريط، اللوحات، الطبقات العلوية)
- **المُركِّب**: يدير النوافذ ويرسم على الشاشة (Niri، Hyprland، Sway...)
- **Wayland**: بروتوكول العرض في Linux (الجديد، البديل عن X11)
- **QML**: لغة الواجهات التصريحية في Qt، وبها كُتب iNiR
- **Material You**: نظام ألوان Google الذي يستخرج لوحات ألوان من الصور (هكذا تعمل السمة التلقائية)
- **ii / waffle / iRiS**: عائلات اللوحات الثلاث. ii بأسلوب Material Design، وwaffle بأسلوب Windows 11، وiRiS جزيرة (Island) تتحول إلى ما تفتحه. `Super+Shift+W` ينتقل بينها

</details>

---

## لقطات الشاشة

<details open>
<summary><b>iRiS</b>: الـ Island وCustomize وشريط القوائم والبطاقات والـ Dock</summary>

<p align="center">
  <img src="../images/iris-2.31-desktop.webp" alt="iRiS desktop layout" width="49%">
  <img src="../images/iris-2.31-card.webp" alt="iRiS card surface" width="49%">
</p>

<p align="center">
  <img src="../images/iris-2.31-dock.webp" alt="iRiS Dock and edge layout" width="99%">
</p>

</details>

<details open>
<summary><b>Material ii</b>: شريط عائم، أشرطة جانبية، مظهر Material Design</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b>: شريط مهام سفلي، مركز إجراءات، بأسلوب Windows 11</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

> [!WARNING]
> ليس للأجهزة الضعيفة.
> لكن يمكنك تخفيفه كثيرًا: أطفئ المؤثرات، وأزل بعض اللوحات، وبسّط التصميم. من الإعدادات أو من `config.json`، كما تفضّل.

## الميزات

**ثلاث عائلات من اللوحات**، تتبدل فورًا بـ `Super+Shift+W`:
- **Material ii**: شريط عائم، أشرطة جانبية، dock و9 أنماط عامة (Material، Cards، Aurora، iNiR، Angel، Regalia، ZZZ، Cookie Shapes، Editorial)
- **Waffle**: شريط مهام وقائمة ابدأ ومركز إجراءات ومركز إشعارات بأسلوب Windows 11
- **iRiS**: العائلة الرئيسية. جزيرة على أي حافة من الشاشة تتسع إلى صفحات وبطاقات ولوحات، وقطع تنقلها أينما شئت، وDock على أي حافة، وزجاج، وThemes تعيد تصميم كل شيء، وفاتح وحبري وداكن، وCustomize مباشرة على الـ shell

**سمة تلقائية**. اختر خلفية ويتكيف كل شيء:
- ألوان الـ shell عبر Material You، تنتقل إلى GTK3/4 وQt والطرفيات وFirefox وDiscord وSDDM
- 10 أهداف للسمة: الطرفيات والمحررات والمتصفحات وSpicetify وSteam وCava وغيرها
- سمات جاهزة: Regalia / Regalia Ivory وGruvbox وCatppuccin وRosé Pine وسماتك الخاصة

**مصنوع لـ Niri.** كود Hyprland باقٍ من التفرع لكنه غير مختبر.

**Kira**، التميمة، تعيش على سطح مكتبك إن أردت. مطفأة افتراضيًا، وحزمة رسومها تُنزَّل منفصلة.

<details>
<summary><b>قائمة الميزات الكاملة</b></summary>

### iRiS

- **الـ Island**: شكل واحد على حافة الشاشة يخبرك بما يحدث ويصبح الصفحة أو البطاقة أو اللوحة التي فتحتها، ثم ينطوي عائدًا. في الأعلى أو الأسفل أو اليسار أو اليمين (`inir iris edge <side>`، أو اسحبها إلى هناك). على الجانب تقف عموديًا، بساعة مكدسة وفقاعات فوقها وتحتها
- **شريط القوائم**: شريط رفيع فيه مساحات العمل والنافذة والقطع، وتتدلى منه الـ Island كنتوء (`inir iris layout menubar`)
- **وضع الشريط بعرض كامل** بمناطق بداية ووسط ونهاية للـ Island ومساحات العمل والنافذة النشطة والوقت أو أي قطعة (`inir iris zone start|center|end kinds+joined+with+plus`)
- **القطع**: الطقس والصوت والميكروفون وعلبة النظام والإشعارات والأدوات والوسائط وVPN ومُصوِّر للصوت وأنمي (Airing وContinue) وتطبيقاتك، على شكل فقاعات تضعها على الـ Island أو على إطار الشاشة أو حرة على سطح المكتب
- **القطع تلتحم بما تلمسه**: ضع واحدة على حافة الـ Dock أو الـ Island فتصبح جزءًا منه بدل أن تطفو فوقه
- **Dock** على أي حافة (`inir iris dockEdge <side|auto>`)؛ في الوضع auto يجلس مقابل الـ Island، وإن أرسلت أحدهما إلى حافة الآخر تبادلا المكانين
- **زجاج** يُغبّش الخلفية تحت كل سطح ويبقي النص مقروءًا حتى على الخلفيات الساطعة أو المزدحمة. تمويه المُركِّب موجود أيضًا، لكنه ما زال قيد العمل، فلا تحكم عليه بعد
- **Themes**: 20 إعادة تصميم مختارة (Liquid Glass وFrost وObsidian وTerminal وNeo Tokyo وTwilight وLume وSakura وUnit-01 وغيرها) إضافة إلى سماتك كملفات JSON قابلة للمشاركة (`inir iris theme`)
- **فاتح وحبري وداكن**، لكل منها درجته وتغبيشه، وسمات ألوان (Catppuccin وNord وRosé Pine وTokyo Night…) تلبسها تطبيقاتك أيضًا (`inir iris palette`)
- **الشكل**: كبسولة أو دائري أو squircle أو مربع للـ Island والـ Dock
- **Customize على الـ shell نفسه**: المس الـ Island أو الـ Dock أو فقاعة فتخرج خياراتها منها مباشرة، مع Themes وLook وPieces والتراجع تحت الـ Island (`inir iris edit`). وإن فضّلت، يجمع Studio كل شيء في لوحة بجانب الشاشة
- **مركز تحكم ترتبه بنفسك**: كل مفتاح سريع مشترك والمشغّل وكل منزلق خلايا تسحبها وتغيّر حجمها من الزاوية وتضيفها من مكتبة بجانبها، مع ستة تخطيطات للبداية؛ النقر بالزر الأيمن يفتح عنصر التحكم (`inir iris control edit`)
- **شاشة قفل تتدرب عليها**: تُفتح شاشة القفل الحقيقية قابلة للتعديل دون ما يُفتح؛ حرّك الساعة والمشغّل وحقل الدخول، واختر ما يُعرض خلفها، والفيديو ضمنه (`inir iris lock edit`)

### السمات والمظهر

- **9 أنماط عامة**: Material (مصمت)، Cards، Aurora (زجاج مموّه)، iNiR (مستوحى من TUI)، Angel (وحشية جديدة)، Regalia (هيكل أسود، حبر عاجي دافئ، تفاصيل شمبانيا هادئة)، ZZZ (ألواح ملصقات)، Cookie Shapes (أشكال متحركة)، Editorial (طباعة الورق والحبر)
- **ألوان ديناميكية من الخلفية** عبر Material You في النظام كله
- **10 أدوات طرفية وTUI بسمة تلقائية**: foot وkitty وalacritty وghostty وwezterm وstarship وfuzzel وbtop وlazygit وyazi
- **سمات التطبيقات**: GTK3/4 وQt (عبر plasma-integration وdarkly) وFirefox وDiscord/Vesktop (System24) وZed وSpicetify وSteam وSDDM
- **سمات جاهزة**: Gruvbox وCatppuccin وRosé Pine وغيرها، أو اصنع سمتك
- **خلفيات فيديو**: mp4/webm/gif مع تمويه اختياري، أو تجميد الإطار الأول من أجل الأداء
- **أدوات سطح المكتب**: تصميم واحد لها كلها (iRiS أو Material أو iNstrument أو Readout)، ورزم تدور مثل رزم iOS، وحبر يتبع الخلفية التي تحتها

### الشريط

- **6 أنماط للشريط**: classic وislands وscenic وframe وكبسولات Material 3 وpill
- **شريط pill**: جزيرة وسطى متحولة تفتح عند المرور بالمؤشر مساحات العمل والمشغّل والخلاط والوسائط والتقويم ومسجل الشاشة
- **تخطيط معياري** مع محرر سحب في الإعدادات، فأي وحدة تذهب إلى أي مكان
- **شريط عمودي** لمن يريد استعادة حافة الشاشة

### الأشرطة الجانبية والأدوات (Material ii)

الشريط الجانبي الأيسر (درج التطبيقات):
- **دردشة الذكاء الاصطناعي**: قوائم نماذج حية من Ollama وLM Studio وOpenRouter وGemini وGroq وMistral وCerebras وAnthropic وOpenAI وOpenCode
- **YT Music**: مشغّل InnerTube دون ملفات تعريف الارتباط، مع بحث وقائمة انتظار وراديو وكلمات متزامنة
- **متصفح Wallhaven**: ابحث عن الخلفيات وطبّقها مباشرة
- **متابعة الأنمي**: تكامل مع AniList وعرض للجدول
- **مترجم**: عبر Gemini أو translate-shell
- **أدوات قابلة للسحب**: عملات رقمية، مشغّل وسائط، ملاحظات سريعة، حلقات حالة، تقويم أسبوعي

الشريط الجانبي الأيمن:
- **تقويم** مع الأحداث
- **مركز الإشعارات**
- **مفاتيح سريعة**: WiFi وBluetooth والضوء الليلي وعدم الإزعاج وأوضاع الطاقة وWARP VPN وEasyEffects
- **خلاط الصوت** لكل تطبيق
- **إدارة أجهزة Bluetooth وWiFi**
- **مؤقت بومودورو**، **قائمة مهام**، **آلة حاسبة**، **مفكرة**
- **مراقب النظام**: المعالج، الذاكرة، الحرارة

### الأدوات

- **نظرة عامة على مساحات العمل**: مهيأة لنموذج التمرير في Niri، مع بحث التطبيقات وآلة حاسبة
- **لوحة معلومات**: طبقة من ثلاثة أعمدة قابلة للضبط فيها المواعيد والإشعارات والمهام والملاحظات والوسائط والطقس
- **شريط مساحات العمل على الحافة**: سكة تظهر عند المرور بمعاينات حية وإعادة ترتيب بالسحب
- **مبدّل النوافذ**: Alt-Tab متحرك عبر كل مساحات العمل، اختياري بعد أن أصبح لـ Niri مبدّله
- **مدير الحافظة**: سجل مع بحث ومعاينة للصور
- **أدوات المناطق**: لقطات شاشة وتسجيل الشاشة وOCR وبحث عكسي بالصور
- **ورقة الاختصارات**: الاختصارات مأخوذة من إعدادات Niri لديك
- **تحكم الوسائط**: مشغّل MPRIS كامل بعدة تخطيطات
- **مؤشرات على الشاشة**: الصوت والسطوع والوسائط
- **التعرف على الأغاني**: بأسلوب Shazam عبر SongRec
- **الإدخال الصوتي**: whisper.cpp محليًا إن كان مثبتًا، أو Groq أو Gemini أو OpenAI متصلة

### النظام

- **إعدادات رسومية**: اضبط كل شيء دون لمس الملفات
- **GameMode**: يطفئ المؤثرات تلقائيًا للتطبيقات بملء الشاشة
- **تحديثات تلقائية**: `inir update` مع التراجع والترحيل والحفاظ على تعديلاتك
- **شاشة القفل** و**شاشة الجلسة** (خروج/إعادة تشغيل/إيقاف/سكون)
- **وكيل Polkit**، **لوحة مفاتيح على الشاشة**، **مدير بدء تلقائي** يعتمد على ملف بدء التشغيل الخاص بـ niri
- **Kira**: فتاة قطة بفن البكسل تتجول على حواف الشاشة وتتفاعل مع ما تفعله ولها وضع فوضى. اختيارية، مع حزمة رسوم منفصلة بنحو 32 MiB في `./setup` › Extras
- **18 لغة** مع اكتشاف تلقائي، منها الإندونيسية (`id_ID`) والغرينلاندية (`kl_GL`)
- **الضوء الليلي**: مجدول أو يدوي
- **الطقس**: Open-Meteo، عبر GPS أو إحداثيات يدوية أو اسم المدينة
- **إدارة البطارية**: حدود قابلة للضبط، وسكون تلقائي عند المستوى الحرج
- **أصوات الأحداث** مع مستوى صوت عام وملف صوتي لكل حدث
- **فحص التحديثات**: ينبهك عند صدور نسخة جديدة

</details>

---

## البدء السريع

<div dir="ltr">

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # interactive, asks before each step
./setup install -y    # automatic, no questions asked
```

</div>

يتولى المثبّت الاعتماديات وإعدادات النظام والسمة. بعد التثبيت، شغّل `inir run` لبدء الـ shell، أو سجّل الخروج ثم ادخل مجددًا.

<div dir="ltr">

```bash
inir run                        # launch the shell
inir settings                   # open settings GUI
inir logs                       # check runtime logs
inir doctor                     # auto-diagnose and fix
inir update                     # pull + migrate + restart
```

</div>

طرق أخرى، إن لم يكن `./setup install` ما تريده:

<div dir="ltr">

```bash
./setup                 # TUI menu, pick what you want
sudo make install       # system-wide instead of your home
./setup rollback        # undo the last update
```

</div>

**التوزيعات:** Arch هو الهدف الأساسي. لدى Fedora وDebian/Ubuntu أيضًا تثبيت تلقائي للاعتماديات يبدأ بمستودعات التوزيعة؛ أما التوزيعات الأخرى فتتبع الإرشادات العامة في [قائمة الحزم](https://github.com/snowarch/inir/wiki/PACKAGES). يحتاج iNiR إلى Qt 6.9 أو أحدث: Ubuntu 25.10 وFedora 43 وDebian testing أو ما بعدها.

---

## الاختصارات

| المفتاح | الإجراء |
|-----|--------|
| <kbd>Super</kbd> + <kbd>Space</kbd> | نظرة عامة: البحث عن التطبيقات والتنقل بين مساحات العمل |
| <kbd>Super</kbd> + <kbd>V</kbd> | سجل الحافظة |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | لقطة شاشة لمنطقة |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd> | OCR لمنطقة |
| <kbd>Super</kbd> + <kbd>,</kbd> | الإعدادات |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | تبديل عائلة اللوحات |
| <kbd>Super</kbd> + <kbd>/</kbd> | ورقة الاختصارات، إن نسيت الباقي |

القائمة الكاملة: [الاختصارات](https://github.com/snowarch/inir/wiki/KEYBINDS)

---

## الخلفيات

تأتي 15 خلفية مضمّنة. للمزيد، اطّلع على [iNiR-Walls](https://github.com/snowarch/iNiR-Walls)، مجموعة مختارة تعمل جيدًا مع Material You.

---

## التوثيق

كل ما يخص المستخدمين موجود في [الويكي](https://github.com/snowarch/inir/wiki) (بالإنجليزية).

| الصفحة | المحتوى |
|---|---|
| [Install](https://github.com/snowarch/inir/wiki/INSTALL) | تشغيله |
| [Setup](https://github.com/snowarch/inir/wiki/SETUP) | التحديثات والترحيل والتراجع |
| [Keybinds](https://github.com/snowarch/inir/wiki/KEYBINDS) | كل الاختصارات |
| [IPC](https://github.com/snowarch/inir/wiki/IPC) | أوامر للاختصارات والسكربتات |
| [Packages](https://github.com/snowarch/inir/wiki/PACKAGES) | كل اعتمادية وسبب وجودها |
| [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS) | المشاكل المعروفة وطرق الالتفاف عليها |
| [Architecture](../../ARCHITECTURE.md) | كيف نُظّم الكود |

---

## حل المشكلات

<div dir="ltr">

```bash
inir logs                       # check recent runtime logs
inir restart                    # restart the active runtime
inir repair                     # doctor + restart + filtered log check
./setup doctor                  # auto-diagnose and fix common problems
./setup rollback                # undo the last update
```

</div>

راجع [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS) قبل فتح issue. وإن فضّلت أن تسأل أحدًا، فـ Discord أسرع.

---

## المساهمة

راجع [CONTRIBUTING.md](../../CONTRIBUTING.md) لبيئة التطوير وأنماط الكود وطريقة إرسال طلبات الدمج.

---

## الشكر

- [**end-4**](https://github.com/end-4/dots-hyprland): illogical-impulse، وهي dots الـ Hyprland التي تفرّع منها iNiR
- [**pctrade/end4-pC**](https://github.com/pctrade/end4-pC): فرع تظهر فيه فكرة جيدة حقًا من حين لآخر
- [**Gakuseei**](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin)، ومنه جاء شريط pill ومظهر washi وflame
- [**Quickshell**](https://quickshell.outfoxxed.me/): الإطار الذي يعمل عليه
- [**Niri**](https://github.com/YaLTeR/niri): المُركِّب الذي صُنع من أجله

GPL-3.0، مثل dots الخاصة بـ end-4. Copyright (C) 2025-2026 snowarch.

---

<p align="center">
  <img src="https://raw.githubusercontent.com/snowarch/inir-mascot/main/inir-mascot-hero-banner.png" alt="iNiR mascot leaning on the iNiR logotype" width="720">
</p>

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">المساهمون</a> &bull;
  <a href="../../CHANGELOG.md">سجل التغييرات</a> &bull;
  <a href="../../LICENSE">رخصة GPL-3.0</a>
</p>

</div>
