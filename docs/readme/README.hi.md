<p align="center">
  <img src="../images/readme/hero.webp" alt="रात में बर्फ़ीले जंगल पर iRiS डेस्कटॉप" width="100%">
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: light)" srcset="../images/readme/mark-light.svg">
    <img src="../images/readme/mark-dark.svg" alt="" width="56">
  </picture>
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <a href="https://github.com/YaLTeR/niri">Niri</a> और <a href="https://github.com/noctalia-dev/umbriel">Umbriel</a> के लिए एक पूरा डेस्कटॉप शेल। कोई परिवार चुनें, उसे अपने हिसाब से ढालें, और एक ही कमांड से उसे नया रखें।
</p>

<p align="center">
  <a href="https://github.com/snowarch/iNiR/releases/latest"><img src="https://img.shields.io/github/v/release/snowarch/iNiR?style=flat-square&label=release&color=111111" alt="Latest release"></a>
  <a href="https://github.com/snowarch/iNiR/stargazers"><img src="https://img.shields.io/github/stars/snowarch/iNiR?style=flat-square&color=111111" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/discord-join-111111?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-111111?style=flat-square" alt="GPL-3.0"></a>
</p>

<p align="center">
  <a href="https://inir.space">inir.space</a> ·
  <a href="https://inir.space/docs/install/">स्थापना</a> ·
  <a href="https://inir.space/docs">दस्तावेज़</a> ·
  <a href="https://inir.space/hub">Hub</a> ·
  <a href="https://inir.space/changelog">बदलाव</a> ·
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

## परिवार

<p align="center"><img src="../shots/at-work-iris.webp" alt="iRiS" width="100%"><br><sub><b>iRiS</b> · किसी भी किनारे पर एक Island, जो आप खोलते हैं वही बन जाता है, साथ में एक डॉक</sub></p>

<table>
<tr>
<td width="50%" valign="top"><img src="../shots/at-work-material.webp" alt="Material" width="100%"><br><sub><b>Material</b> · किसी भी किनारे पर बार, साइडबार, ओवरव्यू, और ग्लोबल स्टाइल</sub></td>
<td width="50%" valign="top"><img src="../shots/at-work-waffle.webp" alt="Waffle" width="100%"><br><sub><b>Waffle</b> · Windows 11 का टास्कबार और एक्शन सेंटर</sub></td>
</tr>
</table>

`Super+Shift+W` से इनके बीच बदलें। और अधिक लुक, विजेट, थीम और वेब ऐप्स [hub](https://inir.space/hub) में हैं।

## स्थापना

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

Arch, Fedora, Debian, Ubuntu, Void और NixOS। हर एक के लिए ज़रूरी बातें [स्थापना गाइड](https://inir.space/docs/install/) में दी गई हैं। यह Niri और Umbriel दोनों पर चलता है: Umbriel जोड़ने का तरीका [कंपोज़िटर](https://inir.space/docs/compositors/) में है।

## अपडेट

```bash
inir update
```

आपकी कॉन्फ़िगरेशन और आपके बदलाव बने रहते हैं। अगर नया संस्करण शुरू नहीं होता, तो अपडेट आपका पिछला संस्करण वापस लगा देता है।

## यह कैसे बना है

iNiR एक आधार है और उसके आसपास के हिस्से हैं, हर हिस्सा अपनी अलग रिपॉज़िटरी में है। आपकी मशीन पर कुछ भी कंपाइल नहीं होता: setup और
`inir update` हर हिस्से को पहले से बना हुआ लाता है और sha256 से जाँचता है।

| रिपॉज़िटरी | यह क्या है | नवीनतम |
|---|---|---|
| **iNiR** (यही रिपॉज़िटरी) | आधार: सर्विसेज़, कॉन्फ़िगरेशन, Settings, स्वागत विज़ार्ड, setup और अपडेट, प्लगइन होस्ट | ![](https://img.shields.io/github/v/release/snowarch/iNiR?label=&style=flat-square&color=111111) |
| [inir-hub](https://github.com/snowarch/inir-hub) | हर प्लगइन: तीनों परिवार, कंपोनेंट, थीम, विजेट, वेब ऐप्स | [inir.space/hub](https://inir.space/hub) |
| [qs-rs](https://github.com/snowarch/qs-rs) | रनटाइम: Rust में दोबारा लिखा गया Quickshell, अपने Qt के साथ | ![](https://img.shields.io/github/v/release/snowarch/qs-rs?label=&style=flat-square&color=111111) |
| [inir-accel](https://github.com/snowarch/inir-accel) | शेल जो बैकग्राउंड में चलाता है, Rust में: रंग, थंबनेल, सेंसर, खोज | ![](https://img.shields.io/github/v/release/snowarch/inir-accel?label=&style=flat-square&color=111111) |
| [inir-cli](https://github.com/snowarch/inir-cli) | `inir` कमांड: IPC, जाँच, अपडेट, `inir hub` | ![](https://img.shields.io/github/v/release/snowarch/inir-cli?label=&style=flat-square&color=111111) |
| [inir-site](https://github.com/snowarch/inir-site) | [inir.space](https://inir.space): साइट, दस्तावेज़, hub का कैटलॉग | |
| [iNiR-Walls](https://github.com/snowarch/iNiR-Walls), [inir-mascot](https://github.com/snowarch/inir-mascot) | वॉलपेपर पैक और Kira की आर्ट, दोनों setup में वैकल्पिक हैं | |

[Architecture](../ARCHITECTURE_OVERVIEW.md) में पूरा नक्शा है। कुछ जोड़ने के लिए, उसे प्लगइन बनाएँ:
[inir-hub की गाइड](https://github.com/snowarch/inir-hub/blob/main/CONTRIBUTING.md)। आधार बदलने के लिए:
[CONTRIBUTING](../../.github/CONTRIBUTING.md)।

## श्रेय

- [end-4](https://github.com/end-4/dots-hyprland): illogical-impulse, वे Hyprland dots जहाँ से iNiR शुरू हुआ
- [Quickshell](https://quickshell.outfoxxed.me/), outfoxxed द्वारा: फ़्रेमवर्क, और वह API जिसके साथ qs-rs संगत रहता है
- [Niri](https://github.com/YaLTeR/niri), YaLTeR द्वारा: कंपोज़िटर
- [Umbriel](https://github.com/noctalia-dev/umbriel), Noctalia टीम द्वारा: दूसरा कंपोज़िटर जिस पर iNiR चलता है
- [Gakuseei](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin), जहाँ से पिल बार और washi व flame लुक आते हैं
- [pctrade/end4-pC](https://github.com/pctrade/end4-pC): एक फ़ॉर्क, जिसमें अपनाने लायक विचार हैं
- हर वह व्यक्ति जो [योगदान](https://github.com/snowarch/iNiR/graphs/contributors) देता है और Discord पर परखता है

[GPL-3.0](../../LICENSE) के तहत, शर्तें [NOTICE](../../NOTICE) में हैं। कॉपीराइट (C) 2025-2026 snowarch।
