<p align="center">
  <img src="../images/iris-2.32-principal.webp" alt="سطح مكتب iNiR مع عائلة iRiS" width="900">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  صدفة سطح مكتب كاملة لـ <a href="https://github.com/YaLTeR/niri">Niri</a>. اختر عائلة، واجعلها على ذوقك، وحافظ على تحديثها بأمر واحد.
</p>

<p align="center">
  <a href="https://inir.space">inir.space</a> ·
  <a href="https://inir.space/docs">الوثائق</a> ·
  <a href="https://inir.space/hub">Hub</a> ·
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

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

## العائلات

| Material | Waffle | iRiS |
|:---:|:---:|:---:|
| <img src="../shots/families-material.webp" alt="Material" width="290"> | <img src="../shots/families-waffle.webp" alt="Waffle" width="290"> | <img src="../shots/families-iris.webp" alt="iRiS" width="290"> |
| شريط على أي حافة، وأشرطة جانبية، ونظرة عامة، وتسعة أنماط عامة | شريط مهام ومركز إجراءات على طراز Windows 11 | Island واحدة على أي حافة تتحول إلى ما تفتحه، ومعها الرصيف (dock) |

يتم التبديل بينها عبر `Super+Shift+W`. المزيد من المظاهر والأدوات والسمات وتطبيقات الويب في [hub](https://inir.space/hub).

## كيف بُني

iNiR هو الأساس مع الأجزاء المحيطة به، وكل جزء في مستودعه الخاص. لا يُجمَّع شيء على جهازك: يجلب setup و
`inir update` كل جزء جاهزًا مبنيًا مسبقًا، ويتحقق منه باستخدام sha256.

| المستودع | المحتوى | الأحدث |
|---|---|---|
| **iNiR** (هذا المستودع) | الأساس: الخدمات، والإعدادات، و Settings، ومعالج الترحيب، و setup والتحديث، ومضيف الإضافات | ![](https://img.shields.io/github/v/release/snowarch/iNiR?label=&style=flat-square) |
| [inir-hub](https://github.com/snowarch/inir-hub) | كل الإضافات: العائلات الثلاث، والمكونات، والسمات، والأدوات، وتطبيقات الويب | [inir.space/hub](https://inir.space/hub) |
| [qs-rs](https://github.com/snowarch/qs-rs) | بيئة التشغيل: Quickshell مُعاد كتابته بلغة Rust، مع Qt الخاص به | ![](https://img.shields.io/github/v/release/snowarch/qs-rs?label=&style=flat-square) |
| [inir-accel](https://github.com/snowarch/inir-accel) | ما تشغّله الصدفة في الخلفية، بلغة Rust: الألوان، والصور المصغّرة، والمستشعرات، والبحث | ![](https://img.shields.io/github/v/release/snowarch/inir-accel?label=&style=flat-square) |
| [inir-cli](https://github.com/snowarch/inir-cli) | أمر `inir`: IPC، والتشخيص، والتحديث، `inir hub` | ![](https://img.shields.io/github/v/release/snowarch/inir-cli?label=&style=flat-square) |
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

<p align="center">
  <img src="https://raw.githubusercontent.com/snowarch/inir-mascot/main/inir-mascot-hero-banner.png" alt="Kira، ماسكوت iNiR، متكئة على الشعار النصي لـ iNiR" width="640">
</p>
