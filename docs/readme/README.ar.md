<p align="center">
  <img src="../images/releases/3.0.0/00-hero.webp" alt="iNiR 3.0: سطح مكتب iRiS فوق غابة مثلجة ليلًا" width="100%">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  صدفة سطح مكتب كاملة لـ <a href="https://github.com/YaLTeR/niri">Niri</a>. اختر عائلة، واجعلها على ذوقك، وحافظ على تحديثها بأمر واحد.
</p>

<p align="center">
  <a href="https://github.com/snowarch/iNiR/releases/latest"><img src="https://img.shields.io/github/v/release/snowarch/iNiR?style=flat-square&label=release&color=111111" alt="Latest release"></a>
  <a href="https://github.com/snowarch/iNiR/stargazers"><img src="https://img.shields.io/github/stars/snowarch/iNiR?style=flat-square&color=111111" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/discord-join-111111?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-111111?style=flat-square" alt="GPL-3.0"></a>
</p>

<p align="center">
  <a href="https://inir.space">inir.space</a> ·
  <a href="https://inir.space/docs/install/">التثبيت</a> ·
  <a href="https://inir.space/docs">الوثائق</a> ·
  <a href="https://inir.space/hub">Hub</a> ·
  <a href="https://inir.space/changelog">سجل التغييرات</a> ·
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

## الجديد في 3.0

قاعدة صغيرة كل عائلة فيها إضافة، وبيئة تشغيل خاصة بها، وموطن على [inir.space](https://inir.space)، وSettings جديدة لـ iRiS. أمر `inir update` واحد يجلب كل ذلك ويحافظ على إعداداتك. [اقرأ سجل التغييرات كاملًا](../../CHANGELOG.md).

<table>
<tr>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/01-prism.webp" alt="Prism" width="100%"><br><sub><b>Prism</b><br>إعادة بناء Settings في iRiS: كل خيار في مكان واحد، مع معاينة حية لما يغيّره.</sub></td>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/02-island.webp" alt="Island" width="100%"><br><sub><b>Island</b><br>الموسيقى والمؤقتات والأنشطة الحية في كائن واحد في الأعلى، بستة عشر تصميمًا.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/04-airisu.webp" alt="AIRISU" width="100%"><br><sub><b>AIRISU</b><br>أول Design: لوحاته وتخطيطه وطابعه الخاص فوق محرك iRiS.</sub></td>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/03-edit-mode.webp" alt="وضع التحرير" width="100%"><br><sub><b>وضع التحرير</b><br>اسحب أدوات سطح المكتب وغيّر حجمها واحفظها، ثم بدّل أسطح مكتب كاملة بنقرة واحدة.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/06-material.webp" alt="Material" width="100%"><br><sub><b>Material</b><br>الأدوات نفسها بوجوه Material الخاصة، مع Settings وخطوط مُجدَّدة.</sub></td>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/05-hub.webp" alt="iNiR Hub" width="100%"><br><sub><b>iNiR Hub</b><br>العائلات وDesigns والسمات والأدوات كإضافات، على inir.space/hub وداخل الواجهة.</sub></td>
</tr>
</table>

## العائلات

| Material | Waffle | iRiS |
|:---:|:---:|:---:|
| <img src="../shots/families-material.webp" alt="Material" width="290"> | <img src="../shots/families-waffle.webp" alt="Waffle" width="290"> | <img src="../shots/families-iris.webp" alt="iRiS" width="290"> |
| شريط على أي حافة، وأشرطة جانبية، ونظرة عامة، وتسعة أنماط عامة | شريط مهام ومركز إجراءات على طراز Windows 11 | Island واحدة على أي حافة تتحول إلى ما تفتحه، ومعها الرصيف (dock) |

يتم التبديل بينها عبر `Super+Shift+W`. المزيد من المظاهر والأدوات والسمات وتطبيقات الويب في [hub](https://inir.space/hub).

## التثبيت

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

Arch، Fedora، Debian، Ubuntu، Void و NixOS. يوضح [دليل التثبيت](https://inir.space/docs/install/) ما يحتاجه كل منها.

## التحديث

```bash
inir update
```

تبقى إعداداتك وتعديلاتك كما هي. إذا لم يبدأ الإصدار الجديد، يعيد التحديث الإصدار الذي كان لديك.

## كيف بُني

iNiR هو الأساس مع الأجزاء المحيطة به، وكل جزء في مستودعه الخاص. لا يُجمَّع شيء على جهازك: يجلب setup و
`inir update` كل جزء جاهزًا مبنيًا مسبقًا، ويتحقق منه باستخدام sha256.

| المستودع | المحتوى | الأحدث |
|---|---|---|
| **iNiR** (هذا المستودع) | الأساس: الخدمات، والإعدادات، و Settings، ومعالج الترحيب، و setup والتحديث، ومضيف الإضافات | ![](https://img.shields.io/github/v/release/snowarch/iNiR?label=&style=flat-square&color=111111) |
| [inir-hub](https://github.com/snowarch/inir-hub) | كل الإضافات: العائلات الثلاث، والمكونات، والسمات، والأدوات، وتطبيقات الويب | [inir.space/hub](https://inir.space/hub) |
| [qs-rs](https://github.com/snowarch/qs-rs) | بيئة التشغيل: Quickshell مُعاد كتابته بلغة Rust، مع Qt الخاص به | ![](https://img.shields.io/github/v/release/snowarch/qs-rs?label=&style=flat-square&color=111111) |
| [inir-accel](https://github.com/snowarch/inir-accel) | ما تشغّله الصدفة في الخلفية، بلغة Rust: الألوان، والصور المصغّرة، والمستشعرات، والبحث | ![](https://img.shields.io/github/v/release/snowarch/inir-accel?label=&style=flat-square&color=111111) |
| [inir-cli](https://github.com/snowarch/inir-cli) | أمر `inir`: IPC، والتشخيص، والتحديث، `inir hub` | ![](https://img.shields.io/github/v/release/snowarch/inir-cli?label=&style=flat-square&color=111111) |
| [inir-site](https://github.com/snowarch/inir-site) | [inir.space](https://inir.space): الموقع، والوثائق، فهرس hub | |
| [iNiR-Walls](https://github.com/snowarch/iNiR-Walls)، [inir-mascot](https://github.com/snowarch/inir-mascot) | حزمة الخلفيات، ورسومات Kira، وكلاهما اختياري في setup | |

يحتوي [Architecture](../ARCHITECTURE_OVERVIEW.md) على الخريطة الكاملة. لإضافة أي شيء، اجعله إضافةً:
[دليل inir-hub](https://github.com/snowarch/inir-hub/blob/main/CONTRIBUTING.md). لتغيير الأساس:
[CONTRIBUTING](../../.github/CONTRIBUTING.md).

## الشكر والتقدير

- [end-4](https://github.com/end-4/dots-hyprland): illogical-impulse، وهي إعدادات Hyprland التي بدأ منها iNiR
- [Quickshell](https://quickshell.outfoxxed.me/) من تطوير outfoxxed: الإطار، والواجهة البرمجية التي يحافظ عليها qs-rs
- [Niri](https://github.com/YaLTeR/niri) من تطوير YaLTeR: المُركِّب (compositor)
- [Gakuseei](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin)، ومنه يأتي الشريط الكبسولي ومظهرا washi و flame
- [pctrade/end4-pC](https://github.com/pctrade/end4-pC): تفرّع (fork) فيه أفكار تستحق الأخذ بها
- كل من [ساهم](https://github.com/snowarch/iNiR/graphs/contributors) وجرّب الإصدارات على Discord

[GPL-3.0](../../LICENSE) مع الشروط الواردة في [NOTICE](../../NOTICE). حقوق النشر (C) 2025-2026 snowarch.
