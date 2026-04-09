<p align="center">
  <img src="https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8" alt="iNiR" width="800">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Niri के लिए Quickshell पर बना एक पूर्ण डेस्कटॉप शेल</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.18.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
</p>

<p align="center">
  <a href="../INSTALL.md">इंस्टॉल</a> &bull;
  <a href="../KEYBINDS.md">कीबाइंड</a> &bull;
  <a href="../IPC.md">IPC संदर्भ</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">योगदान</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **अनुवाद के बारे में:** सामुदायिक अनुवाद। अगर कुछ स्पष्ट न हो, तो [अंग्रेज़ी संस्करण](../../README.md) देखें।

---

<details>
<summary><b>🤔 पहली बार आए हैं? अगर समझ नहीं आ रहा तो यहाँ क्लिक करें</b></summary>

### ये क्या है?

iNiR आपका पूरा डेस्कटॉप है। ऊपर की बार, डॉक, नोटिफिकेशन, सेटिंग्स, वॉलपेपर, सब कुछ। ये थीम नहीं है, कॉपी-पेस्ट करने वाली dotfiles नहीं है। Linux पर चलने वाला एक पूरा शेल है।

### चलाने के लिए क्या चाहिए?

एक compositor। ये वो चीज़ है जो विंडोज़ को मैनेज करती है और स्क्रीन पर पिक्सल्स डालती है। iNiR [Niri](https://github.com/YaLTeR/niri) (एक tiling Wayland compositor) के लिए बना है। end-4 के dots से फोर्क होने के समय का पुराना Hyprland कोड है, लेकिन असल में टेस्ट और इस्तेमाल Niri होता है।

शेल [Quickshell](https://quickshell.outfoxxed.me/) पर चलता है, QML (Qt की UI भाषा) में शेल बनाने का फ्रेमवर्क। इसे जानने की ज़रूरत नहीं, सब कुछ GUI या JSON फाइल से configure होता है।

### सब कैसे जुड़ा है

```
आपकी apps
   ↓
iNiR (शेल: बार, साइडबार, डॉक, नोटिफिकेशन, सेटिंग्स...)
   ↓
Quickshell (QML शेल चलाता है)
   ↓
Niri (compositor: विंडोज़, रेंडरिंग)
   ↓
Wayland → GPU
```

### stable है?

ये एक personal project है जो हाथ से निकल गया। मैं रोज़ इस्तेमाल करता हूँ, Discord पर बहुत लोग भी। लेकिन कभी-कभी टूटता है, कोड जगह-जगह गंदा है, करते-करते सीख रहा हूँ।

कुछ काम नहीं करे तो `inir doctor` ज़्यादातर ठीक कर देता है। वो भी नहीं हुआ तो Discord active है। polished software की उम्मीद मत रखो, ये एक आदमी का rice है जो दूसरों को पसंद आ गया।

### ये क्यों exist करता है?

मैं चाहता था कि मेरा डेस्कटॉप एक खास तरीके से दिखे और काम करे, और कोई और चीज़ बिल्कुल वैसा नहीं करती थी। end-4 के Hyprland dots से शुरू हुआ, Niri के लिए पूरा rewrite बन गया बहुत सारे features के साथ।

### दिखने वाले शब्द

- **Shell**: UI layer (बार, पैनल, overlays)
- **Compositor**: विंडोज़ मैनेज करता है, स्क्रीन पर ड्रॉ करता है (Niri, Hyprland, Sway...)
- **Wayland**: Linux का display protocol (नया वाला, X11 की जगह)
- **QML**: Qt की declarative UI भाषा, iNiR इसमें लिखा है
- **Material You**: Google का color system जो इमेज से palette बनाता है (auto-theming ऐसे काम करता है)
- **ii / waffle**: दो panel styles। ii = Material Design वाइब, waffle = Windows 11 वाइब। `Super+Shift+W` से switch करो

</details>

---

## स्क्रीनशॉट

<details open>
<summary><b>Material ii</b> — फ़्लोटिंग बार, साइडबार, Material Design सौंदर्य</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b> — नीचे टास्कबार, एक्शन सेंटर, Windows 11 शैली</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

## विशेषताएँ

**दो पैनल फ़ैमिली**, `Super+Shift+W` से तुरंत स्विच:
- **Material ii** — फ़्लोटिंग बार, साइडबार, डॉक, 5 विज़ुअल स्टाइल (material, cards, aurora, inir, angel)
- **Waffle** — Windows 11 शैली टास्कबार, स्टार्ट मेन्यू, एक्शन सेंटर, नोटिफ़िकेशन सेंटर

**ऑटोमैटिक थीमिंग** — वॉलपेपर चुनें और सब कुछ अनुकूलित हो जाता है:
- Material You के माध्यम से शेल रंग, GTK3/4, Qt, टर्मिनल, Firefox, Discord, SDDM तक प्रसारित
- 10 टर्मिनल टूल्स ऑटो-थीम (foot, kitty, alacritty, starship, fuzzel, btop, lazygit, yazi)
- थीम प्रीसेट: Gruvbox, Catppuccin, Rosé Pine, और कस्टम

**कंपोज़िटर** — Niri के लिए बनाया गया।

<details>
<summary><b>पूर्ण सुविधा सूची</b></summary>

### थीम और दिखावट

वॉलपेपर चुनें और पूरा सिस्टम अनुसरण करता है — शेल, GTK/Qt ऐप्स, टर्मिनल, Firefox, Discord, SDDM लॉगिन स्क्रीन। सब स्वचालित।

- **5 विज़ुअल स्टाइल** — Material (ठोस), Cards, Aurora (ग्लास ब्लर), iNiR (TUI-प्रेरित), Angel (नव-ब्रूटलिज़्म)
- **वॉलपेपर से डायनामिक रंग** — Material You के ज़रिए पूरे सिस्टम में प्रसारित
- **10 टर्मिनल टूल्स ऑटो-थीम** — foot, kitty, alacritty, starship, fuzzel, pywalfox, btop, lazygit, yazi
- **ऐप थीमिंग** — GTK3/4, Qt (plasma-integration + darkly), Firefox (MaterialFox), Discord/Vesktop (System24)
- **थीम प्रीसेट** — Gruvbox, Catppuccin, Rosé Pine, और अन्य — या अपना बनाएँ
- **वीडियो वॉलपेपर** — mp4/webm/gif, वैकल्पिक ब्लर, या प्रदर्शन के लिए फ़्रोज़न पहला फ़्रेम
- **SDDM लॉगिन थीम** — वॉलपेपर के साथ सिंक्रनाइज़ Material You रंग
- **डेस्कटॉप विजेट** — घड़ी (कई शैलियाँ), मौसम, वॉलपेपर लेयर पर मीडिया नियंत्रण

### साइडबार और विजेट (Material ii)

बायाँ साइडबार (ऐप ड्रॉअर):
- **AI चैट** — Gemini, Mistral, OpenRouter, या Ollama के माध्यम से लोकल मॉडल
- **YT Music** — खोज, कतार और नियंत्रण के साथ पूर्ण प्लेयर
- **Wallhaven ब्राउज़र** — सीधे वॉलपेपर खोजें और लागू करें
- **एनीमे ट्रैकर** — AniList एकीकरण और शेड्यूल दृश्य
- **Reddit फ़ीड** — इनलाइन सबरेडिट ब्राउज़ करें
- **अनुवादक** — Gemini या translate-shell के माध्यम से
- **ड्रैग करने योग्य विजेट** — क्रिप्टो, मीडिया प्लेयर, त्वरित नोट्स, स्टेटस रिंग, साप्ताहिक कैलेंडर

दायाँ साइडबार:
- **कैलेंडर** — इवेंट एकीकरण के साथ
- **नोटिफ़िकेशन सेंटर**
- **क्विक टॉगल** — WiFi, Bluetooth, नाइट लाइट, DND, पावर प्रोफ़ाइल, WARP VPN, EasyEffects
- **वॉल्यूम मिक्सर** — प्रति-ऐप नियंत्रण
- **Bluetooth और WiFi** डिवाइस प्रबंधन
- **पोमोडोरो टाइमर**, **कार्य सूची**, **कैलकुलेटर**, **नोटपैड**
- **सिस्टम मॉनिटर** — CPU, RAM, तापमान

### टूल्स

- **वर्कस्पेस ओवरव्यू** — Niri के स्क्रॉलिंग मॉडल के अनुकूल, ऐप खोज और कैलकुलेटर के साथ
- **विंडो स्विचर** — सभी वर्कस्पेस में Alt+Tab
- **क्लिपबोर्ड मैनेजर** — खोज और इमेज प्रीव्यू के साथ इतिहास
- **रीजन टूल्स** — स्क्रीनशॉट, स्क्रीन रिकॉर्डिंग, OCR, रिवर्स इमेज सर्च
- **चीटशीट** — आपकी Niri कॉन्फ़िग से निकाला गया कीबाइंड व्यूअर
- **मीडिया नियंत्रण** — कई लेआउट प्रीसेट के साथ पूर्ण MPRIS प्लेयर
- **ऑन-स्क्रीन डिस्प्ले** — वॉल्यूम, ब्राइटनेस, और मीडिया OSD
- **गाना पहचान** — SongRec के माध्यम से Shazam शैली पहचान
- **वॉइस सर्च** — रिकॉर्ड करें और Gemini से खोजें

### सिस्टम

- **GUI सेटिंग्स** — फ़ाइलें संपादित किए बिना सब कुछ कॉन्फ़िगर करें
- **GameMode** — फ़ुलस्क्रीन ऐप्स के लिए इफ़ेक्ट्स स्वचालित रूप से अक्षम
- **ऑटो-अपडेट** — `inir update`, रोलबैक, माइग्रेशन, और उपयोगकर्ता परिवर्तन संरक्षण के साथ
- **लॉक स्क्रीन** और **सेशन स्क्रीन** (लॉगआउट/रीस्टार्ट/शटडाउन/सस्पेंड)
- **Polkit एजेंट**, **ऑन-स्क्रीन कीबोर्ड**, **ऑटोस्टार्ट मैनेजर**
- **9 भाषाएँ** — ऑटो-डिटेक्शन, AI-सहायित अनुवाद जनरेशन के साथ
- **नाइट लाइट** — शेड्यूल या मैनुअल
- **मौसम** — Open-Meteo, GPS, मैनुअल निर्देशांक, या शहर का नाम सपोर्ट
- **बैटरी प्रबंधन** — कॉन्फ़िगर करने योग्य थ्रेशोल्ड, क्रिटिकल पर ऑटो-सस्पेंड
- **शेल अपडेट चेकर** — नए वर्शन आने पर सूचित करता है

</details>

---

## त्वरित शुरुआत

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # इंटरैक्टिव — हर चरण पर पूछता है
./setup install -y    # स्वचालित — बिना पूछे इंस्टॉल
```

इंस्टॉलर डिपेंडेंसी, सिस्टम कॉन्फ़िग, थीमिंग — सब संभालता है। इंस्टॉल के बाद `inir run` चलाएँ, या लॉगआउट करके वापस लॉगिन करें।

```bash
inir run                        # शेल शुरू करें
inir settings                   # सेटिंग्स GUI खोलें
inir logs                       # रनटाइम लॉग देखें
inir doctor                     # ऑटो-डायग्नोस और ठीक करें
inir update                     # pull + माइग्रेशन + रीस्टार्ट
```

**समर्थित डिस्ट्रो:** Arch (स्वचालित इंस्टॉलर)। अन्य डिस्ट्रो मैन्युअल रूप से इंस्टॉल कर सकते हैं — देखें [PACKAGES.md](../PACKAGES.md)।

| तरीक़ा | कमांड |
|--------|---------|
| सिस्टम इंस्टॉल | `sudo make install && inir run` |
| TUI मेन्यू | `./setup` |
| रोलबैक | `./setup rollback` |

---

## कीबाइंड

| कुंजी | कार्य |
|-----|--------|
| `Super+Space` | ओवरव्यू — ऐप खोजें, वर्कस्पेस नेविगेट करें |
| `Alt+Tab` | विंडो स्विचर |
| `Super+V` | क्लिपबोर्ड इतिहास |
| `Super+Shift+S` | रीजन स्क्रीनशॉट |
| `Super+Shift+X` | रीजन OCR |
| `Super+,` | सेटिंग्स |
| `Super+Shift+W` | पैनल फ़ैमिली बदलें |

पूर्ण सूची: [KEYBINDS.md](../KEYBINDS.md)

---

## वॉलपेपर

15 वॉलपेपर शामिल हैं। और चाहिए तो [iNiR-Walls](https://github.com/snowarch/iNiR-Walls) देखें — Material You पाइपलाइन के साथ अच्छा काम करने वाला एक क्यूरेटेड कलेक्शन।

---

## दस्तावेज़ीकरण

| | |
|---|---|
| [INSTALL.md](../INSTALL.md) | इंस्टॉलेशन गाइड |
| [SETUP.md](../SETUP.md) | Setup कमांड — अपडेट, माइग्रेशन, रोलबैक |
| [KEYBINDS.md](../KEYBINDS.md) | सभी कीबोर्ड शॉर्टकट |
| [IPC.md](../IPC.md) | स्क्रिप्टिंग और कीबाइंड के लिए IPC टारगेट |
| [PACKAGES.md](../PACKAGES.md) | हर डिपेंडेंसी और उसका कारण |
| [LIMITATIONS.md](../LIMITATIONS.md) | ज्ञात सीमाएँ और समाधान |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | तकनीकी आर्किटेक्चर ओवरव्यू |

---

## समस्या निवारण

```bash
inir logs                       # हाल के रनटाइम लॉग देखें
inir restart                    # सक्रिय रनटाइम रीस्टार्ट करें
inir repair                     # doctor + रीस्टार्ट + फ़िल्टर्ड लॉग जाँच
./setup doctor                  # सामान्य समस्याओं का ऑटो-डायग्नोस और ठीक
./setup rollback                # आख़िरी अपडेट पूर्ववत करें
```

इश्यू खोलने से पहले [LIMITATIONS.md](../LIMITATIONS.md) देखें।

---

## योगदान

[CONTRIBUTING.md](../../CONTRIBUTING.md) देखें — विकास सेटअप, कोड पैटर्न, और PR दिशानिर्देश।

---

## श्रेय

- [**end-4**](https://github.com/end-4/dots-hyprland) — Hyprland के लिए मूल illogical-impulse
- [**Quickshell**](https://quickshell.outfoxxed.me/) — इस शेल को चलाने वाला फ़्रेमवर्क
- [**Niri**](https://github.com/YaLTeR/niri) — स्क्रॉलिंग टाइलिंग Wayland कंपोज़िटर

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">योगदानकर्ता</a> &bull;
  <a href="CHANGELOG.md">चेंजलॉग</a> &bull;
  <a href="LICENSE">MIT लाइसेंस</a>
</p>
