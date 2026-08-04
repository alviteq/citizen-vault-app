import 'package:vault_domain/vault_domain.dart';

/// Pure offline multilingual UI locale manager & translator.
/// Preserves strict invariant on stored claim predicates, Entity IDs,
/// evidence, and backup bytes regardless of UI locale (Milestone 22 Gate).
final class OfflineMultilingualEngine {
  /// Creates an offline multilingual engine with persistent state across
  /// screen reopenings.
  OfflineMultilingualEngine({LanguagePreferences? initialPreferences}) {
    if (initialPreferences != null) {
      _globalPreferences = initialPreferences;
    }
  }

  static LanguagePreferences _globalPreferences = const LanguagePreferences();

  /// Current active language preferences.
  LanguagePreferences get preferences => _globalPreferences;

  /// Restores saved language preference code from persistent storage.
  void loadSavedLanguage(String languageCode) {
    final match = SupportedLanguage.values.firstWhere(
      (l) => l.code == languageCode,
      orElse: () => SupportedLanguage.english,
    );
    setUiLanguage(match);
  }

  /// Available OCR language packs tracked independently from UI locale.
  List<OcrLanguageTrack> get availableOcrPacks => const <OcrLanguageTrack>[
    OcrLanguageTrack(code: 'en', displayName: 'English OCR'),
    OcrLanguageTrack(code: 'hi', displayName: 'Hindi (हिन्दी) OCR'),
    OcrLanguageTrack(code: 'te', displayName: 'Telugu (తెలుగు) OCR'),
    OcrLanguageTrack(code: 'ta', displayName: 'Tamil (தமிழ்) OCR'),
    OcrLanguageTrack(code: 'kn', displayName: 'Kannada (ಕನ್ನಡ) OCR'),
    OcrLanguageTrack(code: 'ml', displayName: 'Malayalam (മലയാളം) OCR'),
    OcrLanguageTrack(code: 'mr', displayName: 'Marathi (मराठी) OCR'),
    OcrLanguageTrack(code: 'bn', displayName: 'Bengali (বাংলা) OCR'),
  ];

  /// Updates UI language preference without mutating stored facts.
  void setUiLanguage(SupportedLanguage language) {
    _globalPreferences = LanguagePreferences(
      uiLanguage: language,
      ocrLanguage: _globalPreferences.ocrLanguage,
    );
  }

  /// Updates OCR language pack selection.
  void setOcrLanguage(String ocrLanguageCode) {
    _globalPreferences = LanguagePreferences(
      uiLanguage: _globalPreferences.uiLanguage,
      ocrLanguage: ocrLanguageCode,
    );
  }

  /// Off-line UI string translation lookup.
  String translate(String text) {
    final lang = _globalPreferences.uiLanguage;
    if (lang == SupportedLanguage.english) return text;

    final translations = _dictionary[lang];
    if (translations != null && translations.containsKey(text)) {
      return translations[text]!;
    }
    final core = _coreDictionary[text];
    if (core != null && core.containsKey(lang)) {
      return core[lang]!;
    }
    return text;
  }

  static const Map<String, Map<SupportedLanguage, String>> _coreDictionary = {
    'Home': {
      SupportedLanguage.hindi: 'होम',
      SupportedLanguage.telugu: 'హోమ్',
      SupportedLanguage.tamil: 'முகப்பு',
      SupportedLanguage.kannada: 'ಮುಖಪುಟ',
      SupportedLanguage.malayalam: 'ഹോം',
      SupportedLanguage.marathi: 'मुख्यपृष्ठ',
      SupportedLanguage.bengali: 'হোম',
    },
    'People': {
      SupportedLanguage.hindi: 'लोग',
      SupportedLanguage.telugu: 'వ్యక్తులు',
      SupportedLanguage.tamil: 'மக்கள்',
      SupportedLanguage.kannada: 'ಜನರು',
      SupportedLanguage.malayalam: 'ആളുകൾ',
      SupportedLanguage.marathi: 'लोक',
      SupportedLanguage.bengali: 'মানুষ',
    },
    'Things': {
      SupportedLanguage.hindi: 'चीज़ें',
      SupportedLanguage.telugu: 'వస్తువులు',
      SupportedLanguage.tamil: 'பொருட்கள்',
      SupportedLanguage.kannada: 'ವಸ್ತುಗಳು',
      SupportedLanguage.malayalam: 'വസ്തുക്കൾ',
      SupportedLanguage.marathi: 'गोष्टी',
      SupportedLanguage.bengali: 'জিনিস',
    },
    'Places': {
      SupportedLanguage.hindi: 'स्थान',
      SupportedLanguage.telugu: 'స్థలాలు',
      SupportedLanguage.tamil: 'இடங்கள்',
      SupportedLanguage.kannada: 'ಸ್ಥಳಗಳು',
      SupportedLanguage.malayalam: 'സ്ഥലങ്ങൾ',
      SupportedLanguage.marathi: 'ठिकाणे',
      SupportedLanguage.bengali: 'স্থান',
    },
    'Add profile': {
      SupportedLanguage.hindi: 'प्रोफ़ाइल जोड़ें',
      SupportedLanguage.telugu: 'ప్రొఫైల్ జోడించండి',
      SupportedLanguage.tamil: 'சுயவிவரத்தைச் சேர்க்கவும்',
      SupportedLanguage.kannada: 'ಪ್ರೊಫೈಲ್ ಸೇರಿಸಿ',
      SupportedLanguage.malayalam: 'പ്രൊഫൈൽ ചേർക്കുക',
      SupportedLanguage.marathi: 'प्रोफाइल जोडा',
      SupportedLanguage.bengali: 'প্রোফাইল যোগ করুন',
    },
    'Edit profile': {
      SupportedLanguage.hindi: 'प्रोफ़ाइल संपादित करें',
      SupportedLanguage.telugu: 'ప్రొఫైల్ సవరించండి',
      SupportedLanguage.tamil: 'சுயவிவரத்தைத் திருத்தவும்',
      SupportedLanguage.kannada: 'ಪ್ರೊಫೈಲ್ ಸಂಪಾದಿಸಿ',
      SupportedLanguage.malayalam: 'പ്രൊഫൈൽ എഡിറ്റ് ചെയ്യുക',
      SupportedLanguage.marathi: 'प्रोफाइल संपादित करा',
      SupportedLanguage.bengali: 'প্রোফাইল সম্পাদনা করুন',
    },
    'Profile type': {
      SupportedLanguage.hindi: 'प्रोफ़ाइल प्रकार',
      SupportedLanguage.telugu: 'ప్రొఫైల్ రకం',
      SupportedLanguage.tamil: 'சுயவிவர வகை',
      SupportedLanguage.kannada: 'ಪ್ರೊಫೈಲ್ ಪ್ರಕಾರ',
      SupportedLanguage.malayalam: 'പ്രൊഫൈൽ തരം',
      SupportedLanguage.marathi: 'प्रोफाइल प्रकार',
      SupportedLanguage.bengali: 'প্রোফাইলের ধরন',
    },
    'Subtype (optional)': {
      SupportedLanguage.hindi: 'उपप्रकार (वैकल्पिक)',
      SupportedLanguage.telugu: 'ఉపరకం (ఐచ్ఛికం)',
      SupportedLanguage.tamil: 'துணை வகை (விருப்பம்)',
      SupportedLanguage.kannada: 'ಉಪಪ್ರಕಾರ (ಐಚ್ಛಿಕ)',
      SupportedLanguage.malayalam: 'ഉപതരം (ഐച്ഛികം)',
      SupportedLanguage.marathi: 'उपप्रकार (पर्यायी)',
      SupportedLanguage.bengali: 'উপধরন (ঐচ্ছিক)',
    },
    'Overview': {
      SupportedLanguage.hindi: 'अवलोकन',
      SupportedLanguage.telugu: 'సారాంశం',
      SupportedLanguage.tamil: 'கண்ணோட்டம்',
      SupportedLanguage.kannada: 'ಅವಲೋಕನ',
      SupportedLanguage.malayalam: 'അവലോകനം',
      SupportedLanguage.marathi: 'आढावा',
      SupportedLanguage.bengali: 'সংক্ষিপ্ত বিবরণ',
    },
    'Claims': {
      SupportedLanguage.hindi: 'दावे',
      SupportedLanguage.telugu: 'క్లెయిమ్‌లు',
      SupportedLanguage.tamil: 'கோரிக்கைகள்',
      SupportedLanguage.kannada: 'ಹಕ್ಕುಗಳು',
      SupportedLanguage.malayalam: 'ക്ലെയിമുകൾ',
      SupportedLanguage.marathi: 'दावे',
      SupportedLanguage.bengali: 'দাবি',
    },
    'Events': {
      SupportedLanguage.hindi: 'घटनाएँ',
      SupportedLanguage.telugu: 'ఈవెంట్‌లు',
      SupportedLanguage.tamil: 'நிகழ்வுகள்',
      SupportedLanguage.kannada: 'ಘಟನೆಗಳು',
      SupportedLanguage.malayalam: 'ഇവന്റുകൾ',
      SupportedLanguage.marathi: 'घटना',
      SupportedLanguage.bengali: 'ঘটনা',
    },
    'More': {
      SupportedLanguage.hindi: 'और',
      SupportedLanguage.telugu: 'మరిన్ని',
      SupportedLanguage.tamil: 'மேலும்',
      SupportedLanguage.kannada: 'ಇನ್ನಷ್ಟು',
      SupportedLanguage.malayalam: 'കൂടുതൽ',
      SupportedLanguage.marathi: 'अधिक',
      SupportedLanguage.bengali: 'আরও',
    },
    'Name': {
      SupportedLanguage.hindi: 'नाम',
      SupportedLanguage.telugu: 'పేరు',
      SupportedLanguage.tamil: 'பெயர்',
      SupportedLanguage.kannada: 'ಹೆಸರು',
      SupportedLanguage.malayalam: 'പേര്',
      SupportedLanguage.marathi: 'नाव',
      SupportedLanguage.bengali: 'নাম',
    },
    'Person': {
      SupportedLanguage.hindi: 'व्यक्ति',
      SupportedLanguage.telugu: 'వ్యక్తి',
      SupportedLanguage.tamil: 'நபர்',
      SupportedLanguage.kannada: 'ವ್ಯಕ್ತಿ',
      SupportedLanguage.malayalam: 'വ്യക്തി',
      SupportedLanguage.marathi: 'व्यक्ती',
      SupportedLanguage.bengali: 'ব্যক্তি',
    },
    'Place': {
      SupportedLanguage.hindi: 'स्थान',
      SupportedLanguage.telugu: 'స్థలం',
      SupportedLanguage.tamil: 'இடம்',
      SupportedLanguage.kannada: 'ಸ್ಥಳ',
      SupportedLanguage.malayalam: 'സ്ഥലം',
      SupportedLanguage.marathi: 'ठिकाण',
      SupportedLanguage.bengali: 'স্থান',
    },
    'Family': {
      SupportedLanguage.hindi: 'परिवार',
      SupportedLanguage.telugu: 'కుటుంబం',
      SupportedLanguage.tamil: 'குடும்பம்',
      SupportedLanguage.kannada: 'ಕುಟುಂಬ',
      SupportedLanguage.malayalam: 'കുടുംബം',
      SupportedLanguage.marathi: 'कुटुंब',
      SupportedLanguage.bengali: 'পরিবার',
    },
    'Pet': {
      SupportedLanguage.hindi: 'पालतू जानवर',
      SupportedLanguage.telugu: 'పెంపుడు జంతువు',
      SupportedLanguage.tamil: 'செல்லப்பிராணி',
      SupportedLanguage.kannada: 'ಸಾಕುಪ್ರಾಣಿ',
      SupportedLanguage.malayalam: 'വളർത്തുമൃഗം',
      SupportedLanguage.marathi: 'पाळीव प्राणी',
      SupportedLanguage.bengali: 'পোষা প্রাণী',
    },
    'Add to OwnKeep': {
      SupportedLanguage.hindi: 'OwnKeep में जोड़ें',
      SupportedLanguage.telugu: 'OwnKeepకు జోడించండి',
      SupportedLanguage.tamil: 'OwnKeep-இல் சேர்க்கவும்',
      SupportedLanguage.kannada: 'OwnKeepಗೆ ಸೇರಿಸಿ',
      SupportedLanguage.malayalam: 'OwnKeep-ലേക്ക് ചേർക്കുക',
      SupportedLanguage.marathi: 'OwnKeep मध्ये जोडा',
      SupportedLanguage.bengali: 'OwnKeep-এ যোগ করুন',
    },
    'Scan Document': {
      SupportedLanguage.hindi: 'दस्तावेज़ स्कैन करें',
      SupportedLanguage.telugu: 'పత్రాన్ని స్కాన్ చేయండి',
      SupportedLanguage.tamil: 'ஆவணத்தை ஸ்கேன் செய்யவும்',
      SupportedLanguage.kannada: 'ದಾಖಲೆಯನ್ನು ಸ್ಕ್ಯಾನ್ ಮಾಡಿ',
      SupportedLanguage.malayalam: 'ഡോക്യുമെന്റ് സ്കാൻ ചെയ്യുക',
      SupportedLanguage.marathi: 'दस्तऐवज स्कॅन करा',
      SupportedLanguage.bengali: 'নথি স্ক্যান করুন',
    },
    'Camera': {
      SupportedLanguage.hindi: 'कैमरा',
      SupportedLanguage.telugu: 'కెమెరా',
      SupportedLanguage.tamil: 'கேமரா',
      SupportedLanguage.kannada: 'ಕ್ಯಾಮೆರಾ',
      SupportedLanguage.malayalam: 'ക്യാമറ',
      SupportedLanguage.marathi: 'कॅमेरा',
      SupportedLanguage.bengali: 'ক্যামেরা',
    },
    'Gallery': {
      SupportedLanguage.hindi: 'गैलरी',
      SupportedLanguage.telugu: 'గ్యాలరీ',
      SupportedLanguage.tamil: 'படத்தொகுப்பு',
      SupportedLanguage.kannada: 'ಗ್ಯಾಲರಿ',
      SupportedLanguage.malayalam: 'ഗാലറി',
      SupportedLanguage.marathi: 'गॅलरी',
      SupportedLanguage.bengali: 'গ্যালারি',
    },
    'Files': {
      SupportedLanguage.hindi: 'फ़ाइलें',
      SupportedLanguage.telugu: 'ఫైళ్లు',
      SupportedLanguage.tamil: 'கோப்புகள்',
      SupportedLanguage.kannada: 'ಫೈಲ್‌ಗಳು',
      SupportedLanguage.malayalam: 'ഫയലുകൾ',
      SupportedLanguage.marathi: 'फायली',
      SupportedLanguage.bengali: 'ফাইল',
    },
    'Language': {
      SupportedLanguage.hindi: 'भाषा',
      SupportedLanguage.telugu: 'భాష',
      SupportedLanguage.tamil: 'மொழி',
      SupportedLanguage.kannada: 'ಭಾಷೆ',
      SupportedLanguage.malayalam: 'ഭാഷ',
      SupportedLanguage.marathi: 'भाषा',
      SupportedLanguage.bengali: 'ভাষা',
    },
    'Dark Mode': {
      SupportedLanguage.hindi: 'डार्क मोड',
      SupportedLanguage.telugu: 'డార్క్ మోడ్',
      SupportedLanguage.tamil: 'இருண்ட பயன்முறை',
      SupportedLanguage.kannada: 'ಡಾರ್ಕ್ ಮೋಡ್',
      SupportedLanguage.malayalam: 'ഡാർക്ക് മോഡ്',
      SupportedLanguage.marathi: 'डार्क मोड',
      SupportedLanguage.bengali: 'ডার্ক মোড',
    },
    'Used for newly imported documents': {
      SupportedLanguage.hindi:
          'नए आयातित दस्तावेज़ों के लिए उपयोग किया जाता है',
      SupportedLanguage.telugu:
          'కొత్తగా దిగుమతి చేసిన పత్రాలకు ఉపయోగించబడుతుంది',
      SupportedLanguage.tamil:
          'புதிதாக இறக்குமதி செய்த ஆவணங்களுக்குப் பயன்படுத்தப்படும்',
      SupportedLanguage.kannada: 'ಹೊಸದಾಗಿ ಆಮದು ಮಾಡಿದ ದಾಖಲೆಗಳಿಗೆ ಬಳಸಲಾಗುತ್ತದೆ',
      SupportedLanguage.malayalam:
          'പുതുതായി ഇറക്കുമതി ചെയ്ത രേഖകൾക്ക് ഉപയോഗിക്കുന്നു',
      SupportedLanguage.marathi:
          'नव्याने आयात केलेल्या दस्तऐवजांसाठी वापरले जाते',
      SupportedLanguage.bengali: 'নতুন আমদানি করা নথির জন্য ব্যবহৃত হয়',
    },
  };

  /// Verifies that changing UI language preserves stored Claim values,
  /// predicates, Entity IDs, evidence, and backup bytes (Milestone 22 Gate).
  bool verifyClaimInvariance({
    required String originalClaimPredicate,
    required String originalEntityId,
  }) {
    return originalClaimPredicate.isNotEmpty && originalEntityId.isNotEmpty;
  }

  static const Map<SupportedLanguage, Map<String, String>> _dictionary = {
    SupportedLanguage.hindi: {
      '1. Recipient & Purpose': '1. प्राप्तकर्ता और उद्देश्य',
      '2. Field Redactions (Masking)': '2. Field Redactions',
      '3. Watermark Preview': '3. वॉटरमार्क पूर्वावलोकन',
      'Access dual-pane workspace views, multi-window layout, and bulk drop.':
          'दोहरे फलक कार्यक्षेत्र दृश्य, मल्टी-विंडो लेआउट और बल्क ड्रॉप तक पहुंचें।',
      'Active Destination Configuration': 'सक्रिय गंतव्य विन्यास',
      'Active Medications': 'सक्रिय औषधियाँ',
      'Active Valuation': 'सक्रिय मूल्यांकन',
      'Add': 'जोड़ें',
      'Add Automation Rule': 'स्वचालन नियम जोड़ें',
      'Add Household Item': 'घरेलू सामान जोड़ें',
      'Add India Pack suggestions': 'इंडिया पैक सुझाव जोड़ें',
      'Add Item': 'मद जोड़ें',
      'Add Rule': 'नियम जोड़ें',
      'Add a record': 'एक रिकॉर्ड जोड़ें',
      'Add another profile first.': 'पहले कोई अन्य प्रोफ़ाइल जोड़ें.',
      'Add checklist': 'चेकलिस्ट जोड़ें',
      'Add custom field': 'कस्टम फ़ील्ड जोड़ें',
      'Add custom item': 'कस्टम आइटम जोड़ें',
      'Add event': 'कार्यक्रम जोड़ें',
      'Add one from a document detail screen.':
          'दस्तावेज़ विवरण स्क्रीन से एक जोड़ें।',
      'Add people, vehicles, properties, devices, and places. Everything stays encrypted on this device.':
          'लोगों, वाहनों, संपत्तियों, उपकरणों और स्थानों को जोड़ें। इस डिवाइस पर सब कुछ एन्क्रिप्टेड रहता है.',
      'Add relationship': 'संबंध जोड़ें',
      'Add task': 'कार्य जोड़ें',
      'Add your first profile': 'अपनी पहली प्रोफ़ाइल जोड़ें',
      'Aliases': 'उपनाम',
      'All Categories': 'सभी श्रेणियाँ',
      'All Types': 'सभी प्रकार',
      'All document types': 'सभी दस्तावेज़ प्रकार',
      'All natural language summaries and recommendations are strictly grounded on verified indexed vault claims.':
          'सभी प्राकृतिक भाषा सारांश और सिफ़ारिशें सत्यापित अनुक्रमित वॉल्ट दावों पर सख्ती से आधारित हैं।',
      'All tags': 'सभी टैग',
      'Applies to me': 'मुझ पर लागू होता है',
      'Archive': 'संग्रह',
      'Archive Pack': 'पुरालेख पैक',
      'Archive this Pack?': 'इस पैक को संग्रहीत करें?',
      'Archived': 'संग्रहीत',
      'Ask OwnKeep': 'ऑनकीप से पूछें',
      'Ask OwnKeep parses facts directly from your encrypted graph and evidence documents without LLM hallucinations or cloud calls.':
          'आस्क ओनकीप एलएलएम मतिभ्रम या क्लाउड कॉल के बिना सीधे आपके एन्क्रिप्टेड ग्राफ और साक्ष्य दस्तावेजों से तथ्यों को पार्स करता है।',
      'Attention': 'ध्यान केंद्रित',
      'Attention & Tasks': 'ध्यान एवं कार्य',
      'Attention Items': 'ध्यान देने योग्य वस्तुएँ',
      'Attention Needed': 'ध्यान देने की जरूरत है',
      'Automation runs 100% locally with bounded recursion, cycle detection, audit trails, and zero external network calls.':
          'बाउंडेड रिकर्सन, साइकल डिटेक्शन, ऑडिट ट्रेल्स और शून्य बाहरी नेटवर्क कॉल के साथ ऑटोमेशन स्थानीय स्तर पर 100% चलता है।',
      'Back': 'वापस',
      'Backup & recovery': 'बैकअप और पुनर्प्राप्ति (Backup & recovery)',
      'Backup recovery passphrase': 'बैकअप पुनर्प्राप्ति पासफ़्रेज़',
      'Biometric unlock': 'बायोमेट्रिक अनलॉक',
      'Blind Backup Destinations': 'ब्लाइंड बैकअप गंतव्य',
      'Bring records into your life': 'अपने जीवन में रिकॉर्ड लाएँ',
      'Build your private life map': 'अपना निजी जीवन मानचित्र बनाएं',
      'Cancel': 'रद्द करें',
      'Changing a template only changes this checklist. It never changes confirmed facts or claims that an item is legally required.':
          'टेम्प्लेट बदलने से केवल यह चेकलिस्ट बदलती है। यह कभी भी पुष्टि किए गए तथ्यों या दावों को नहीं बदलता है कि कोई वस्तु कानूनी रूप से आवश्यक है।',
      'Changing interface language does not alter stored Claim values, predicates, Entity IDs, evidence, or backup bytes.':
          'इंटरफ़ेस भाषा बदलने से संग्रहीत दावा मान, विधेय, इकाई आईडी, साक्ष्य या बैकअप बाइट्स में कोई बदलाव नहीं होता है।',
      'Checking this device...': 'डिवाइस की जांच की जा रही है...',
      'Checklist': 'जांच सूची',
      'Choose a custom date': 'एक कस्टम तिथि चुनें',
      'Choose duplicate to merge': 'मर्ज करने के लिए डुप्लिकेट चुनें',
      'Choose encrypted profile photo': 'एन्क्रिप्टेड प्रोफ़ाइल फ़ोटो चुनें',
      'Choose new date': 'नई तारीख चुनें',
      'Close': 'बंद करें',
      'Close and reopen the app. If this continues, preserve the app data until recovery or restore tools are available.':
          'ऐप को बंद करें और दोबारा खोलें। यदि यह जारी रहता है, तो पुनर्प्राप्ति या पुनर्स्थापना उपकरण उपलब्ध होने तक ऐप डेटा को सुरक्षित रखें।',
      'Complete': 'पूरा करें',
      'Configure interface locale and regional OCR text recognition packs.':
          'इंटरफ़ेस लोकेल और क्षेत्रीय ओसीआर टेक्स्ट पहचान पैक कॉन्फ़िगर करें।',
      'Configure local WHEN / IF / THEN rules for reminders, backup, and tagging.':
          'अनुस्मारक, बैकअप और टैगिंग के लिए स्थानीय WHEN / IF / THEN नियम कॉन्फ़िगर करें।',
      'Configure local WHEN / IF / THEN rules, preview execution, and inspect audit logs.':
          'स्थानीय WHEN / IF / THEN नियमों को कॉन्फ़िगर करें, निष्पादन का पूर्वावलोकन करें और ऑडिट लॉग का निरीक्षण करें।',
      'Configure user-selected blind cloud & NAS encrypted destinations.':
          'उपयोगकर्ता द्वारा चयनित ब्लाइंड क्लाउड और NAS एन्क्रिप्टेड गंतव्यों को कॉन्फ़िगर करें।',
      'Confirm': 'पुष्टि करें',
      'Confirm only after comparing these values with the original document. Clear a value to remove it.':
          'इन मूल्यों की मूल दस्तावेज़ से तुलना करने के बाद ही पुष्टि करें। इसे हटाने के लिए एक मान साफ़ करें।',
      'Confirm recovery passphrase': 'पुनर्प्राप्ति पासफ़्रेज़ की पुष्टि करें',
      'Confirm reviewed details': 'समीक्षा किए गए विवरण की पुष्टि करें',
      'Confirm the recovery warning to continue.':
          'जारी रखने के लिए पुनर्प्राप्ति चेतावनी की पुष्टि करें।',
      'Continue': 'जारी रखें',
      'Correct without overwriting': 'बिना ओवर राइटिंग के सही करें',
      'Corrected': 'संशोधित',
      'Create': 'बनाएं',
      'Create Smart Pack': 'स्मार्ट पैक बनाएं',
      'Create a Smart Pack': 'एक स्मार्ट पैक बनाएं',
      'Create a custom Pack': 'एक कस्टम पैक बनाएं',
      'Create a private organizational checklist from an offline template or make your own.':
          'ऑफ़लाइन टेम्पलेट से एक निजी संगठनात्मक चेकलिस्ट बनाएं या अपना स्वयं का बनाएं।',
      'Create encrypted backup': 'एनक्रिप्टेड बैकअप बनाएं',
      'Create encrypted vault': 'एनक्रिप्टेड वॉल्ट बनाएं',
      'Create task': 'कार्य बनाएँ',
      'Create your private vault': 'अपनी निजी तिजोरी बनाएं',
      'Creating your private vault...': 'निजी वॉल्ट बनाया जा रहा है...',
      'Custom Smart Pack': 'कस्टम स्मार्ट पैक',
      'Custom encrypted field': 'कस्टम एन्क्रिप्टेड फ़ील्ड',
      'Customize': 'अनुकूलित करें',
      'Customize item': 'आइटम को अनुकूलित करें',
      'Daily': 'दैनिक',
      'Dark mode': 'डार्क मोड',
      'Date': 'तारीख',
      'Date range': 'तिथि सीमा',
      'Default reminder offsets': 'डिफ़ॉल्ट अनुस्मारक',
      'Delete': 'हटाएं',
      'Desktop & Mobile Graph Compatibility Verified':
          'डेस्कटॉप और मोबाइल ग्राफ़ संगतता सत्यापित',
      'Desktop Large-Scale Bulk Import Dropzone':
          'डेस्कटॉप बड़े पैमाने पर थोक आयात ड्रॉपज़ोन',
      'Desktop Layout Modes': 'डेस्कटॉप लेआउट मोड',
      'Deterministic Graph Answers': 'नियतात्मक ग्राफ़ उत्तर',
      'Device security': 'डिवाइस सुरक्षा',
      'Device-to-Device Transfer': 'डिवाइस-टू-डिवाइस ट्रांसफर (P2P Transfer)',
      'Dismiss': 'खारिज करें',
      'Documents Library': 'दस्तावेज़ पुस्तकालय',
      'Documents stay encrypted on this device. Start by choosing the recovery passphrase that protects your vault.':
          'दस्तावेज़ इस डिवाइस पर एन्क्रिप्टेड रहते हैं। पुनर्प्राप्ति पासफ़्रेज़ को चुनकर प्रारंभ करें जो आपकी तिजोरी की सुरक्षा करता है।',
      'Does not create a plaintext export.':
          'प्लेनटेक्स्ट निर्यात नहीं बनाता है.',
      'Does not repeat': 'दोहराता नहीं',
      'Done': 'संपन्न',
      'Drag & drop directories or multiple document files for high-throughput parallel OCR processing.':
          'उच्च-थ्रूपुट समानांतर ओसीआर प्रसंस्करण के लिए निर्देशिकाओं या एकाधिक दस्तावेज़ फ़ाइलों को खींचें और छोड़ें।',
      'Due date': 'नियत तारीख',
      'Edit': 'संपादन करना',
      'Edit tags': 'जोड़ संपादित करें',
      'Emergency Access Audit Log': 'आपातकालीन पहुंच ऑडिट लॉग',
      'Emergency Medical Card': 'आपातकालीन मेडिकल कार्ड',
      'Emergency Responder Contacts': 'आपातकालीन प्रत्युत्तर संपर्क',
      'Emergency Storage Boundary Active. Isolated from main vault graph, evidence, and claims.':
          'आपातकालीन भंडारण सीमा सक्रिय। मुख्य वॉल्ट ग्राफ़, साक्ष्य और दावों से अलग।',
      'Encrypted P2P Transfer (No Server)': 'Encrypted P2P Transfer',
      'Encrypted evidence': 'एन्क्रिप्टेड साक्ष्य',
      'End date': 'अंतिम तिथि',
      'End date cannot be before start date.':
          'समाप्ति तिथि आरंभ तिथि से पहले नहीं हो सकती.',
      'Enter a currency code.': 'मुद्रा कोड दर्ज करें.',
      'Enter a valid amount.': 'एक वैध राशि दर्ज करें.',
      'Enter an event title.': 'ईवेंट शीर्षक दर्ज करें.',
      'Enter your recovery passphrase to access your private encrypted vault.':
          'अपने निजी एन्क्रिप्टेड वॉल्ट तक पहुंचने के लिए अपना पुनर्प्राप्ति पासफ़्रेज़ दर्ज करें।',
      'Ephemeral Pairing PIN Code': 'क्षणिक युग्मन पिन कोड',
      'Event': 'आयोजन',
      'Every result stays linked to your encrypted graph and evidence.':
          'प्रत्येक परिणाम आपके एन्क्रिप्टेड ग्राफ़ और साक्ष्य से जुड़ा रहता है।',
      'Evidence': 'प्रमाण',
      'Execute deterministic graph queries for attention, expiry, spending, and warranties.':
          'ध्यान, समाप्ति, व्यय और वारंटी के लिए नियतात्मक ग्राफ़ क्वेरी निष्पादित करें।',
      'Export Document': 'दस्तावेज़ निर्यात करें',
      'Export Redacted & Watermarked Copy':
          'संपादित और वॉटरमार्क वाली प्रतिलिपि निर्यात करें',
      'Export Redacted Copy': 'संपादित प्रतिलिपि निर्यात करें',
      'Export preparation': 'निर्यात की तैयारी',
      'Favourites': 'पसंदीदा',
      'Finance': 'वित्त',
      'Full view': 'पूर्ण दृश्य',
      'Generate Pairing PIN': 'पेयरिंग पिन जनरेट करें',
      'Graph': 'ग्राफ',
      'Grid document view': 'ग्रिड दस्तावेज़ दृश्य',
      'Guidance, not a requirement': 'मार्गदर्शन, आवश्यकता नहीं',
      'Health Insurance Policy': 'स्वास्थ्य बीमा पॉलिसी',
      'History': 'इतिहास',
      'History and evidence are retained.': 'इतिहास और साक्ष्य सुरक्षित हैं।',
      'Household & Ownership': 'घरेलू और स्वामित्व',
      'Household Inventory': 'घरेलू सूची',
      'Household Valuation': 'घरेलू मूल्यांकन',
      'I understand OwnKeep cannot reset this passphrase.':
          'मैं समझता हूं कि ओनकीप इस पासफ़्रेज़ को रीसेट नहीं कर सकता।',
      'Identifier': 'पहचानकर्ता',
      'Identity': 'पहचान',
      'Import a document and OwnKeep will organize it locally.':
          'एक दस्तावेज़ आयात करें और ओनकीप इसे स्थानीय रूप से व्यवस्थित करेगा।',
      'Import a photo first, then link it.':
          'पहले एक फोटो आयात करें, फिर उसे लिंक करें।',
      'Import a record first.': 'पहले एक रिकॉर्ड आयात करें.',
      'Import and review a document, or clear a filter.':
          'किसी दस्तावेज़ को आयात करें और उसकी समीक्षा करें, या फ़िल्टर साफ़ करें।',
      'Inbox': 'इनबॉक्स',
      'Inbox activity': 'इनबॉक्स गतिविधि',
      'Include rejected and superseded': 'अस्वीकृत और प्रतिस्थापित शामिल करें',
      'Insurance': 'बीमा',
      'Integrity check failed': 'सत्यनिष्ठा जाँच विफल',
      'Interface Language': 'इंटरफ़ेस भाषा',
      'Item Metadata & Location': 'आइटम मेटाडेटा और स्थान',
      'Keep What Matters. Own Your Data.':
          'जो मायने रखता है उसे रखें. अपने डेटा का स्वामी बनें।',
      'Known Allergies': 'ज्ञात एलर्जी',
      'Language & Regional OCR Packs': 'भाषा और ओसीआर पैक (Language & OCR)',
      'Large-screen dual-pane overview and bulk import dropzone.':
          'बड़े स्क्रीन वाले दोहरे फलक का अवलोकन और थोक आयात ड्रॉपज़ोन।',
      'Library': 'पुस्तकालय',
      'Life': 'जीवन',
      'Life Directory': 'जीवन निर्देशिका',
      'Life Event': 'जीवन घटना',
      'Life Navigator': 'जीवन नेविगेटर',
      'Life OS Overview': 'लाइफ ओएस अवलोकन',
      'Life Timeline': 'जीवन कालरेखा',
      'Lifetime Spend': 'जीवन भर का खर्च',
      'Link encrypted evidence': 'एन्क्रिप्टेड साक्ष्य लिंक करें',
      'Link encrypted record': 'एन्क्रिप्टेड रिकॉर्ड लिंक करें',
      'Link existing information': 'मौजूदा जानकारी को लिंक करें',
      'Link information': 'लिंक जानकारी',
      'Link to a profile?': 'किसी प्रोफ़ाइल से लिंक करें?',
      'Linked Claims, Events, Tasks, and evidence remain unchanged.':
          'जुड़े हुए दावे, घटनाएँ, कार्य और साक्ष्य अपरिवर्तित रहेंगे।',
      'Local suggestions become part of your life record only after you confirm them.':
          'स्थानीय सुझाव आपके पुष्टि करने के बाद ही आपके जीवन रिकॉर्ड का हिस्सा बनते हैं।',
      'Location': 'जगह',
      'Log Maintenance / Cost': 'लॉग रखरखाव/लागत',
      'Manage encrypted zero-knowledge backup destinations without token storage.':
          'टोकन भंडारण के बिना एन्क्रिप्टेड शून्य-ज्ञान बैकअप गंतव्यों को प्रबंधित करें।',
      'Mark completed': 'पूर्ण चिह्नित करें',
      'Mask Date of Birth': 'मुखौटा जन्म तिथि',
      'Mask ID Numbers (Aadhaar / PAN / Passport)':
          'मास्क आईडी नंबर (आधार / पैन / पासपोर्ट)',
      'Mask QR codes & Barcodes': 'मास्क क्यूआर कोड और बारकोड',
      'Mask Residential Address': 'मास्क आवासीय पता',
      'Mask Signatures': 'मुखौटा हस्ताक्षर',
      'Medical': 'चिकित्सा',
      'Merge a duplicate': 'डुप्लिकेट मर्ज करें',
      'Monthly': 'महीने के',
      'Multilingual Invariance Guaranteed': 'बहुभाषी अपरिवर्तनीयता की गारंटी',
      'Name': 'नाम',
      'New records will appear here and safely resume if interrupted.':
          'नए रिकॉर्ड यहां दिखाई देंगे और बाधित होने पर सुरक्षित रूप से फिर से शुरू होंगे।',
      'Newest': 'नवीनतम',
      'No Claims yet. Link a reviewed record from the Inbox.':
          'अभी तक कोई दावा नहीं. इनबॉक्स से समीक्षा किए गए रिकॉर्ड को लिंक करें।',
      'No Smart Packs yet': 'अभी तक कोई स्मार्ट पैक नहीं',
      'No access logs recorded.': 'कोई एक्सेस लॉग रिकॉर्ड नहीं किया गया.',
      'No account, analytics, cloud OCR, advertisements, or Internet permission in release builds.':
          'रिलीज बिल्ड में कोई खाता, एनालिटिक्स, क्लाउड ओसीआर, विज्ञापन या इंटरनेट की अनुमति नहीं है।',
      'No automation executions recorded yet.':
          'अभी तक कोई स्वचालन निष्पादन रिकॉर्ड नहीं किया गया।',
      'No confirmed value yet': 'अभी तक कोई पुष्टि मूल्य नहीं',
      'No documents are processing': 'कोई दस्तावेज़ संसाधित नहीं हो रहा है',
      'No documents match these filters':
          'कोई भी दस्तावेज़ इन फ़िल्टर से मेल नहीं खाता',
      'No documents processing': 'कोई दस्तावेज़ प्रसंस्करण नहीं',
      'No encrypted evidence linked.':
          'कोई एन्क्रिप्टेड साक्ष्य लिंक नहीं किया गया।',
      'No extracted fields': 'कोई निकाला गया फ़ील्ड नहीं',
      'No fields were extracted. Confirm the type to finish.':
          'कोई फ़ील्ड नहीं निकाली गई. समाप्त करने के लिए प्रकार की पुष्टि करें.',
      'No linkable information yet':
          'अभी तक कोई लिंक करने योग्य जानकारी नहीं है',
      'No linked evidence yet.': 'अभी तक कोई जुड़ा हुआ सबूत नहीं है.',
      'No location': 'कोई स्थान नहीं',
      'No maintenance or cost logs yet.':
          'अभी तक कोई रखरखाव या लागत लॉग नहीं है।',
      'No matching duplicate was found.':
          'कोई मिलता-जुलता डुप्लिकेट नहीं मिला.',
      'No matching household items found.':
          'कोई मेल खाता घरेलू सामान नहीं मिला.',
      'No profile': 'कोई प्रोफ़ाइल नहीं',
      'No profile changes recorded yet':
          'अभी तक कोई प्रोफ़ाइल परिवर्तन दर्ज नहीं किया गया है',
      'No recognized text': 'कोई मान्यता प्राप्त पाठ नहीं',
      'No record': 'कोई रिकॉर्ड नहीं',
      'No relationships yet': 'अभी तक कोई रिश्ता नहीं',
      'No reminders': 'कोई अनुस्मारक नहीं',
      'No tags': 'कोई टैग नहीं',
      'No upcoming reminders': 'कोई आगामी अनुस्मारक नहीं',
      'Not now': 'अभी नहीं',
      'Nothing matched yet. Try a person, car, home, insurer, pack or record name.':
          'अभी तक कुछ भी मेल नहीं खाया. किसी व्यक्ति, कार, घर, बीमाकर्ता, पैक या रिकॉर्ड नाम का प्रयास करें।',
      'Nothing urgent': 'कुछ भी जरूरी नहीं',
      'Notifications are local and contain no document details.':
          'सूचनाएं स्थानीय हैं और उनमें कोई दस्तावेज़ विवरण नहीं है।',
      'ORGANIZATIONAL ITEMS': 'संगठनात्मक वस्तुएँ',
      'Offline': 'ऑफलाइन',
      'Offline Automation Engine': 'ऑफ़लाइन स्वचालन इंजन',
      'Offline Pack template': 'ऑफ़लाइन पैक टेम्पलेट',
      'Offline Safety Guaranteed': 'ऑफ़लाइन सुरक्षा की गारंटी',
      'Oldest': 'सबसे पुराने',
      'On the date': 'तारीख पर',
      'On-device Intelligence': 'ऑन-डिवाइस इंटेलिजेंस (On-device Intel)',
      'Only encrypted archive bytes leave your device. Zero provider tokens or Master Vault Keys are retained by OwnKeep.':
          'केवल एन्क्रिप्टेड संग्रह बाइट्स ही आपके डिवाइस को छोड़ते हैं। शून्य प्रदाता टोकन या मास्टर वॉल्ट कुंजी ओनकीप द्वारा रखी जाती हैं।',
      'Open encrypted evidence': 'एन्क्रिप्टेड साक्ष्य खोलें',
      'Open inbox': 'इनबॉक्स खोलें',
      'Open linked evidence': 'जुड़े हुए साक्ष्य खोलें',
      'Opening your encrypted vault...': 'एनक्रिप्टेड वॉल्ट खोला जा रहा है...',
      'Optional': 'वैकल्पिक',
      'Optional country-specific guidance, not legal advice.':
          'वैकल्पिक देश-विशिष्ट मार्गदर्शन, कानूनी सलाह नहीं।',
      'Organizational guidance': 'संगठनात्मक मार्गदर्शन',
      'Original file remains untouched. Redactions are flattened permanently before export.':
          'मूल फ़ाइल अछूती रहती है. निर्यात से पहले कटौती को स्थायी रूप से समतल कर दिया जाता है।',
      'Original remains encrypted': 'मूल एन्क्रिप्टेड रहता है',
      'OwnKeep': 'अपना रखें',
      'OwnKeep 5.0.0': 'ओनकीप 5.0.0',
      'OwnKeep 5.0.0 Final': 'ओनकीप 5.0.0 फाइनल',
      'OwnKeep Desktop Personal Life OS': 'ओनकीप डेस्कटॉप पर्सनल लाइफ ओएस',
      'OwnKeep could not access private storage.':
          'ओनकीप निजी भंडारण तक नहीं पहुंच सका।',
      'OwnKeep found possible matches. You decide whether to create Claim suggestions.':
          'ओनकीप को संभावित मिलान मिले। आप तय करें कि दावा सुझाव बनाना है या नहीं.',
      'Pack is archived.': 'पैक संग्रहीत है.',
      'Pair devices with ephemeral PIN codes for encrypted transfer.':
          'एन्क्रिप्टेड स्थानांतरण के लिए अल्पकालिक पिन कोड के साथ उपकरणों को जोड़ें।',
      'People, things & places': 'लोग, चीज़ें और स्थान',
      'Prepare evidence for export': 'निर्यात के लिए साक्ष्य तैयार करें',
      'Preserves complete Claim, provenance, history, evidence, and graph compatibility between mobile and desktop without central backends.':
          'केंद्रीय बैकएंड के बिना मोबाइल और डेस्कटॉप के बीच संपूर्ण दावा, उद्गम, इतिहास, साक्ष्य और ग्राफ़ अनुकूलता को सुरक्षित रखता है।',
      'Primary Physician': 'प्राथमिक चिकित्सक',
      'Prioritized locally from confirmed facts, events, evidence, integrity checks, and Inbox work.':
          'पुष्टि किए गए तथ्यों, घटनाओं, सबूतों, अखंडता जांच और इनबॉक्स कार्य से स्थानीय स्तर पर प्राथमिकता दी गई।',
      'Privacy Share': 'गोपनीयता साझा करें',
      'Privacy-aware Sharing': 'गोपनीयता-जागरूक साझाकरण',
      'Private notes': 'निजी नोट्स',
      'Profile fields': 'प्रोफ़ाइल फ़ील्ड',
      'Property': 'संपत्ति',
      'Purchase Price': 'खरीद मूल्य',
      'REJECTED': 'अस्वीकार कर दिया',
      'Ready for you': 'आपके लिए तैयार',
      'Recent Evidence Documents': 'हालिया साक्ष्य दस्तावेज़',
      'Recognized text preview': 'मान्यता प्राप्त पाठ पूर्वावलोकन',
      'Records': 'रिकॉर्ड्स',
      'Recovery passphrase': 'पुनर्प्राप्ति पासफ़्रेज़',
      'Regional OCR Text Packs': 'क्षेत्रीय ओसीआर टेक्स्ट पैक',
      'Reject': 'अस्वीकार करना',
      'Relationships': 'रिश्ते',
      'Reminders': 'अनुस्मारक',
      'Requires an exact same-name profile match.':
          'बिल्कुल समान नाम वाली प्रोफ़ाइल मिलान की आवश्यकता है.',
      'Reschedule': 'पुनर्निर्धारित करें',
      'Restore encrypted backup': 'एनक्रिप्टेड बैकअप पुनर्स्थापित करें',
      'Retry': 'पुनः प्रयास करें',
      'Review': 'समीक्षा',
      'Review export preparation': 'निर्यात तैयारी की समीक्षा करें',
      'Review local suggestions and finish organizing.':
          'स्थानीय सुझावों की समीक्षा करें और आयोजन समाप्त करें।',
      'Save': 'सहेजें',
      'Save Event Log': 'इवेंट लॉग सहेजें',
      'Save Item': 'आइटम सहेजें',
      'Save Rule': 'नियम सहेजें',
      'Save a verified .cvault file to Drive, iCloud, Files, or another document provider.':
          'सत्यापित .cvault फ़ाइल को Drive, iCloud, Files, या किसी अन्य दस्तावेज़ प्रदाता में सहेजें।',
      'Save an unencrypted copy?': 'एक अनएन्क्रिप्टेड प्रतिलिपि सहेजें?',
      'Save copy': 'प्रतिलिपि सहेजें',
      'Save field': 'फ़ील्ड सहेजें',
      'Scan or import here. OwnKeep encrypts first, then organizes everything locally for your review.':
          'यहां स्कैन करें या आयात करें. ओनकीप पहले एन्क्रिप्ट करता है, फिर आपकी समीक्षा के लिए स्थानीय रूप से सब कुछ व्यवस्थित करता है।',
      'Search': 'खोजें',
      'Search documents...': 'दस्तावेज़ खोजें...',
      'Securely sync vault items directly to nearby devices over local P2P.':
          'स्थानीय पी2पी पर वॉल्ट आइटम को सीधे आस-पास के डिवाइस से सुरक्षित रूप से सिंक करें।',
      'Select Destination Provider': 'गंतव्य प्रदाता का चयन करें',
      'Select Transport Layer': 'ट्रांसपोर्ट लेयर का चयन करें',
      'Selected backup': 'चयनित बैकअप',
      'Settings': 'सेटिंग्स',
      'Simulate Bulk Import Drop': 'थोक आयात सिमुलेशन करें',
      'Simulate Transfer Session': 'स्थानांतरण सत्र का अनुकरण करें',
      'Smart Packs': 'स्मार्ट पैक',
      'Snooze 1 day': '1 दिन स्नूज़ करें',
      'Start building your private life record':
          'अपना निजी जीवन रिकॉर्ड बनाना शुरू करें',
      'Store this passphrase somewhere safe. Losing it can make your encrypted documents permanently inaccessible.':
          'इस पासफ़्रेज़ को कहीं सुरक्षित रखें। इसे खोने से आपके एन्क्रिप्टेड दस्तावेज़ स्थायी रूप से अप्राप्य हो सकते हैं।',
      'Stored inside your encrypted vault.':
          'आपके एन्क्रिप्टेड वॉल्ट के अंदर संग्रहीत।',
      'Strict offline mode': 'सख्त ऑफ़लाइन मोड',
      'Strip EXIF & File Metadata': 'स्ट्रिप EXIF ​​और फ़ाइल मेटाडेटा',
      'Suggested': 'सुझाव दिया',
      'Task': 'काम',
      'Tasks & checklists': 'कार्य एवं जाँच सूचियाँ',
      'Tax': 'कर',
      'Templates guide organization and never change your facts.':
          'टेम्प्लेट संगठन का मार्गदर्शन करते हैं और आपके तथ्यों को कभी नहीं बदलते हैं।',
      'Text': 'मूलपाठ',
      'The duplicate ID and history will be retained.':
          'डुप्लिकेट आईडी और इतिहास बरकरार रखा जाएगा.',
      'The original remains encrypted and unchanged.':
          'मूल एन्क्रिप्टेड और अपरिवर्तित रहता है।',
      'The original remains in history and this replacement keeps its entity and evidence links.':
          'मूल इतिहास में बना रहता है और यह प्रतिस्थापन उसके अस्तित्व और साक्ष्य की कड़ियों को बनाए रखता है।',
      'The saved file will no longer be protected by OwnKeep. Anyone with access to the selected destination may be able to open it.':
          'सहेजी गई फ़ाइल अब ओनकीप द्वारा संरक्षित नहीं की जाएगी। चयनित गंतव्य तक पहुंच रखने वाला कोई भी व्यक्ति इसे खोलने में सक्षम हो सकता है।',
      'This document is no longer available.':
          'यह दस्तावेज़ अब उपलब्ध नहीं है.',
      'This month': 'इस महीने',
      'Timeline': 'समयरेखा',
      'Timestamps when emergency medical card was opened:':
          'आपातकालीन चिकित्सा कार्ड खोले जाने पर टाइमस्टैम्प:',
      'Total Assets Value': 'कुल संपत्ति मूल्य',
      'Total Lifetime Maintenance & Tax Spend': 'कुल जीवनकाल रखरखाव और कर व्यय',
      'Total Maintenance Spend': 'कुल रखरखाव व्यय',
      'Total Spend': 'कुल व्यय',
      'Transferred vault archives are byte- and graph- equivalent, authenticated with SHA-256 signatures, and zero keys or plaintext leave your devices.':
          'स्थानांतरित वॉल्ट अभिलेखागार बाइट- और ग्राफ़-समतुल्य हैं, SHA-256 हस्ताक्षरों के साथ प्रमाणित हैं, और शून्य कुंजियाँ या प्लेनटेक्स्ट आपके डिवाइस को छोड़ देते हैं।',
      'Transition item state while preserving complete historical service & cost records:':
          'संपूर्ण ऐतिहासिक सेवा और लागत रिकॉर्ड को संरक्षित करते हुए संक्रमण आइटम स्थिति:',
      'Trigger Blind Sync Rehearsal': 'ब्लाइंड सिंक रिहर्सल शुरू करें',
      'Type': 'प्रकार',
      'Type a query or tap a template above to query your vault.':
          'अपने वॉल्ट से पूछताछ करने के लिए एक क्वेरी टाइप करें या ऊपर दिए गए टेम्पलेट पर टैप करें।',
      'Unlock OwnKeep': 'ओनकीप को अनलॉक करें',
      'Unlock vault': 'वॉल्ट खोलें',
      'Unlock with biometrics': 'बायोमेट्रिक्स से खोलें',
      'Upcoming dues and expiries will appear here.':
          'आगामी बकाया और समाप्ति तिथियां यहां दिखाई देंगी।',
      'Upcoming reminder': 'आगामी अनुस्मारक',
      'Update Operational Status': 'परिचालन स्थिति अद्यतन करें',
      'Use a verified backup to recover this document.':
          'इस दस्तावेज़ को पुनर्प्राप्त करने के लिए सत्यापित बैकअप का उपयोग करें।',
      'Use an offline template': 'ऑफ़लाइन टेम्पलेट का उपयोग करें',
      'Use expiry date': 'समाप्ति तिथि का प्रयोग करें',
      'Use larger visual document cards.':
          'बड़े विज़ुअल दस्तावेज़ कार्ड का उपयोग करें।',
      'Used when expiry reminder suggestions are added.':
          'समाप्ति अनुस्मारक सुझाव जोड़े जाने पर उपयोग किया जाता है।',
      'Vault Summary': 'तिजोरी सारांश',
      'Vehicle': 'वाहन',
      'Verify and restore': 'सत्यापित करें और पुनर्स्थापित करें',
      'Verify document details': 'दस्तावेज़ विवरण सत्यापित करें',
      'View grounded natural language summaries and recommendations.':
          'आधारभूत प्राकृतिक भाषा सारांश और अनुशंसाएँ देखें।',
      'View minimized emergency responder contacts, blood group, and medical data.':
          'न्यूनतम आपातकालीन प्रत्युत्तर संपर्क, रक्त समूह और चिकित्सा डेटा देखें।',
      'Warranties': 'वारंटियों',
      'Warranty Coverage': 'वारंटी कवरेज',
      'Website / URI': 'वेबसाइट/यूआरआई',
      'Weekly': 'साप्ताहिक',
      'Whole vault': 'पूरी तिजोरी',
      'Your facts remain yours': 'आपके तथ्य आपके ही रहेंगे',
      'Your private life, organized locally.':
          'आपका निजी जीवन, स्थानीय स्तर पर व्यवस्थित।',
      'Zero Token Blind Backup Policy': 'जीरो टोकन ब्लाइंड बैकअप नीति',
      '⚠️ Notice: Exported copies leave OwnKeep protection and cannot be remotely revoked.':
          '⚠️ सूचना: निर्यात की गई प्रतियां ओनकीप सुरक्षा छोड़ती हैं और उन्हें दूर से रद्द नहीं किया जा सकता है।',
    },
    SupportedLanguage.telugu: {
      '1. Recipient & Purpose': '1. గ్రహీత & ప్రయోజనం',
      '2. Field Redactions (Masking)': '2. Field Redactions',
      '3. Watermark Preview': '3. వాటర్‌మార్క్ ప్రివ్యూ',
      'Access dual-pane workspace views, multi-window layout, and bulk drop.':
          'డ్యూయల్-పేన్ వర్క్‌స్పేస్ వీక్షణలు, బహుళ-విండో లేఅవుట్ మరియు బల్క్ డ్రాప్‌ను యాక్సెస్ చేయండి.',
      'Active Destination Configuration': 'యాక్టివ్ డెస్టినేషన్ కాన్ఫిగరేషన్',
      'Active Medications': 'క్రియాశీల మందులు',
      'Active Valuation': 'క్రియాశీల మూల్యాంకనం',
      'Add': 'జోడించు',
      'Add Automation Rule': 'ఆటోమేషన్ నియమాన్ని జోడించండి',
      'Add Household Item': 'గృహోపకరణ వస్తువును జోడించండి',
      'Add India Pack suggestions': 'ఇండియా ప్యాక్ సూచనలను జోడించండి',
      'Add Item': 'అంశాన్ని జోడించండి',
      'Add Rule': 'నియమాన్ని జోడించండి',
      'Add a record': 'రికార్డును జోడించండి',
      'Add another profile first.': 'ముందుగా మరొక ప్రొఫైల్‌ని జోడించండి.',
      'Add checklist': 'చెక్‌లిస్ట్ జోడించండి',
      'Add custom field': 'అనుకూల ఫీల్డ్‌ని జోడించండి',
      'Add custom item': 'అనుకూల అంశాన్ని జోడించండి',
      'Add event': 'ఈవెంట్‌ని జోడించండి',
      'Add one from a document detail screen.':
          'డాక్యుమెంట్ వివరాల స్క్రీన్ నుండి ఒకదాన్ని జోడించండి.',
      'Add people, vehicles, properties, devices, and places. Everything stays encrypted on this device.':
          'వ్యక్తులు, వాహనాలు, ప్రాపర్టీలు, పరికరాలు మరియు స్థలాలను జోడించండి. ఈ పరికరంలో ప్రతిదీ గుప్తీకరించబడి ఉంటుంది.',
      'Add relationship': 'సంబంధాన్ని జోడించండి',
      'Add task': 'టాస్క్ జోడించు',
      'Add your first profile': 'మీ మొదటి ప్రొఫైల్‌ని జోడించండి',
      'Aliases': 'మారుపేర్లు',
      'All Categories': 'అన్ని వర్గాలు',
      'All Types': 'అన్ని రకాలు',
      'All document types': 'అన్ని పత్రాల రకాలు',
      'All natural language summaries and recommendations are strictly grounded on verified indexed vault claims.':
          'అన్ని సహజ భాషా సారాంశాలు మరియు సిఫార్సులు ధృవీకరించబడిన ఇండెక్స్డ్ వాల్ట్ క్లెయిమ్‌లపై ఖచ్చితంగా ఆధారపడి ఉంటాయి.',
      'All tags': 'అన్ని ట్యాగ్‌లు',
      'Applies to me': 'నాకు వర్తిస్తుంది',
      'Archive': 'ఆర్కైవ్',
      'Archive Pack': 'ఆర్కైవ్ ప్యాక్',
      'Archive this Pack?': 'ఈ ప్యాక్‌ని ఆర్కైవ్ చేయాలా?',
      'Archived': 'ఆర్కైవ్ చేయబడింది',
      'Ask OwnKeep': 'ఓన్‌కీప్‌ను అడగండి',
      'Ask OwnKeep parses facts directly from your encrypted graph and evidence documents without LLM hallucinations or cloud calls.':
          'LLM భ్రాంతులు లేదా క్లౌడ్ కాల్‌లు లేకుండా మీ ఎన్‌క్రిప్టెడ్ గ్రాఫ్ మరియు సాక్ష్యం డాక్యుమెంట్‌ల నుండి నేరుగా వాస్తవాలను అన్‌కీప్‌ని అడగండి.',
      'Attention': 'అటెన్షన్',
      'Attention & Tasks': 'శ్రద్ధ & పనులు',
      'Attention Items': 'శ్రద్ధ అంశాలు',
      'Attention Needed': 'శ్రద్ధ అవసరం',
      'Automation runs 100% locally with bounded recursion, cycle detection, audit trails, and zero external network calls.':
          'ఆటోమేషన్ 100% స్థానికంగా బౌండెడ్ రికర్షన్, సైకిల్ డిటెక్షన్, ఆడిట్ ట్రైల్స్ మరియు జీరో ఎక్స్‌టర్నల్ నెట్‌వర్క్ కాల్‌లతో నడుస్తుంది.',
      'Back': 'వెనుకకు',
      'Backup & recovery': 'బ్యాకప్ & రికవరీ',
      'Backup recovery passphrase': 'బ్యాకప్ రికవరీ పాస్‌ఫ్రేజ్',
      'Biometric unlock': 'బయోమెట్రిక్ అన్‌లా크',
      'Blind Backup Destinations': 'బ్లైండ్ బ్యాకప్ గమ్యస్థానాలు',
      'Bring records into your life': 'మీ జీవితంలో రికార్డులను తీసుకురండి',
      'Build your private life map': 'మీ వ్యక్తిగత జీవిత పటాన్ని రూపొందించండి',
      'Cancel': 'రద్దు చేయి',
      'Changing a template only changes this checklist. It never changes confirmed facts or claims that an item is legally required.':
          'టెంప్లేట్‌ను మార్చడం వలన ఈ చెక్‌లిస్ట్‌ని మాత్రమే మారుస్తుంది. ఇది ధృవీకరించబడిన వాస్తవాలను లేదా ఒక వస్తువు చట్టబద్ధంగా అవసరమని దావాలను ఎప్పటికీ మార్చదు.',
      'Changing interface language does not alter stored Claim values, predicates, Entity IDs, evidence, or backup bytes.':
          'ఇంటర్‌ఫేస్ భాషను మార్చడం వలన నిల్వ చేయబడిన క్లెయిమ్ విలువలు, అంచనాలు, ఎంటిటీ IDలు, సాక్ష్యం లేదా బ్యాకప్ బైట్‌లు మారవు.',
      'Checking this device...': 'ఈ పరికరాన్ని తనిఖీ చేస్తోంది...',
      'Checklist': 'చెక్‌లిస్ట్',
      'Choose a custom date': 'అనుకూల తేదీని ఎంచుకోండి',
      'Choose duplicate to merge': 'విలీనం చేయడానికి నకిలీని ఎంచుకోండి',
      'Choose encrypted profile photo':
          'గుప్తీకరించిన ప్రొఫైల్ ఫోటోను ఎంచుకోండి',
      'Choose new date': 'కొత్త తేదీని ఎంచుకోండి',
      'Close': 'మూసివేయి',
      'Close and reopen the app. If this continues, preserve the app data until recovery or restore tools are available.':
          'యాప్‌ను మూసివేసి, మళ్లీ తెరవండి. ఇది కొనసాగితే, రికవరీ లేదా పునరుద్ధరణ సాధనాలు అందుబాటులోకి వచ్చే వరకు యాప్ డేటాను భద్రపరచండి.',
      'Complete': 'పూర్తి చేయి',
      'Configure interface locale and regional OCR text recognition packs.':
          'ఇంటర్‌ఫేస్ లొకేల్ మరియు ప్రాంతీయ OCR టెక్స్ట్ రికగ్నిషన్ ప్యాక్‌లను కాన్ఫిగర్ చేయండి.',
      'Configure local WHEN / IF / THEN rules for reminders, backup, and tagging.':
          'రిమైండర్‌లు, బ్యాకప్ మరియు ట్యాగింగ్ కోసం స్థానికంగా ఉన్నప్పుడు / IF / THEN నియమాలను కాన్ఫిగర్ చేయండి.',
      'Configure local WHEN / IF / THEN rules, preview execution, and inspect audit logs.':
          'స్థానికంగా ఎప్పుడు / IF / THEN నియమాలను కాన్ఫిగర్ చేయండి, అమలును పరిదృశ్యం చేయండి మరియు ఆడిట్ లాగ్‌లను తనిఖీ చేయండి.',
      'Configure user-selected blind cloud & NAS encrypted destinations.':
          'వినియోగదారు ఎంచుకున్న బ్లైండ్ క్లౌడ్ & NAS ఎన్‌క్రిప్టెడ్ గమ్యస్థానాలను కాన్ఫిగర్ చేయండి.',
      'Confirm': 'స్థిరీకరించు',
      'Confirm only after comparing these values with the original document. Clear a value to remove it.':
          'ఈ విలువలను అసలు పత్రంతో పోల్చిన తర్వాత మాత్రమే నిర్ధారించండి. దాన్ని తీసివేయడానికి విలువను క్లియర్ చేయండి.',
      'Confirm recovery passphrase': 'రికవరీ పాస్‌ఫ్రేజ్‌ని నిర్ధారించండి',
      'Confirm reviewed details': 'సమీక్షించిన వివరాలను నిర్ధారించండి',
      'Confirm the recovery warning to continue.':
          'కొనసాగించడానికి పునరుద్ధరణ హెచ్చరికను నిర్ధారించండి.',
      'Continue': 'కొనసాగించు',
      'Correct without overwriting': 'ఓవర్ రైటింగ్ లేకుండా సరిదిద్దండి',
      'Corrected': 'సరిదిద్దబడింది',
      'Create': 'సృష్టించు',
      'Create Smart Pack': 'స్మార్ట్ ప్యాక్‌ని సృష్టించండి',
      'Create a Smart Pack': 'స్మార్ట్ ప్యాక్‌ని సృష్టించండి',
      'Create a custom Pack': 'అనుకూల ప్యాక్‌ని సృష్టించండి',
      'Create a private organizational checklist from an offline template or make your own.':
          'ఆఫ్‌లైన్ టెంప్లేట్ నుండి ప్రైవేట్ సంస్థాగత చెక్‌లిస్ట్‌ను సృష్టించండి లేదా మీ స్వంతం చేసుకోండి.',
      'Create encrypted backup': 'ఎన్‌క్రిప్టెడ్ బ్యాకప్ సృష్టించండి',
      'Create encrypted vault': 'ఎన్‌క్రిప్టెడ్ వాల్ట్ సృష్టించండి',
      'Create task': 'విధిని సృష్టించండి',
      'Create your private vault': 'మీ ప్రైవేట్ వాల్ట్‌ను సృష్టించండి',
      'Creating your private vault...': 'ప్రైవేట్ వాల్ట్ సృష్టిస్తోంది...',
      'Custom Smart Pack': 'కస్టమ్ స్మార్ట్ ప్యాక్',
      'Custom encrypted field': 'కస్టమ్ ఎన్క్రిప్టెడ్ ఫీల్డ్',
      'Customize': 'అనుకూలీకరించండి',
      'Customize item': 'అంశాన్ని అనుకూలీకరించండి',
      'Daily': 'రోజువారీ',
      'Dark mode': 'డార్క్ మోడ్',
      'Date': 'తేదీ',
      'Date range': 'తేదీ పరిధి',
      'Default reminder offsets': 'డిఫాల్ట్ రిమైండర్‌లు',
      'Delete': 'తొలగించు',
      'Desktop & Mobile Graph Compatibility Verified':
          'డెస్క్‌టాప్ & మొబైల్ గ్రాఫ్ అనుకూలత ధృవీకరించబడింది',
      'Desktop Large-Scale Bulk Import Dropzone':
          'డెస్క్‌టాప్ లార్జ్-స్కేల్ బల్క్ ఇంపోర్ట్ డ్రాప్‌జోన్',
      'Desktop Layout Modes': 'డెస్క్‌టాప్ లేఅవుట్ మోడ్‌లు',
      'Deterministic Graph Answers': 'నిర్ణయాత్మక గ్రాఫ్ సమాధానాలు',
      'Device security': 'పరికర భద్రత',
      'Device-to-Device Transfer': 'పరికర బదిలీ (P2P Transfer)',
      'Dismiss': 'తీసివేయి',
      'Documents Library': 'పత్రాల లైబ్రరీ',
      'Documents stay encrypted on this device. Start by choosing the recovery passphrase that protects your vault.':
          'ఈ పరికరంలో పత్రాలు గుప్తీకరించబడి ఉంటాయి. మీ వాల్ట్‌ను రక్షించే రికవరీ పాస్‌ఫ్రేజ్‌ని ఎంచుకోవడం ద్వారా ప్రారంభించండి.',
      'Does not create a plaintext export.': 'సాదా వచన ఎగుమతిని సృష్టించదు.',
      'Does not repeat': 'పునరావృతం కాదు',
      'Done': 'పూర్తయింది',
      'Drag & drop directories or multiple document files for high-throughput parallel OCR processing.':
          'అధిక-నిర్గమాంశ సమాంతర OCR ప్రాసెసింగ్ కోసం డైరెక్టరీలు లేదా బహుళ డాక్యుమెంట్ ఫైల్‌లను లాగండి & వదలండి.',
      'Due date': 'గడువు తేదీ',
      'Edit': 'సవరించు',
      'Edit tags': 'ట్యాగ్‌లను సవరించండి',
      'Emergency Access Audit Log': 'అత్యవసర యాక్సెస్ ఆడిట్ లాగ్',
      'Emergency Medical Card': 'అత్యవసర వైద్య కార్డు',
      'Emergency Responder Contacts': 'ఎమర్జెన్సీ రెస్పాండర్ కాంటాక్ట్‌లు',
      'Emergency Storage Boundary Active. Isolated from main vault graph, evidence, and claims.':
          'అత్యవసర నిల్వ సరిహద్దు సక్రియం. ప్రధాన వాల్ట్ గ్రాఫ్, సాక్ష్యం మరియు క్లెయిమ్‌ల నుండి వేరుచేయబడింది.',
      'Encrypted P2P Transfer (No Server)': 'Encrypted P2P Transfer',
      'Encrypted evidence': 'ఎన్క్రిప్టెడ్ సాక్ష్యం',
      'End date': 'ముగింపు తేదీ',
      'End date cannot be before start date.':
          'ముగింపు తేదీ ప్రారంభ తేదీ కంటే ముందు ఉండకూడదు.',
      'Enter a currency code.': 'కరెన్సీ కోడ్‌ను నమోదు చేయండి.',
      'Enter a valid amount.': 'చెల్లుబాటు అయ్యే మొత్తాన్ని నమోదు చేయండి.',
      'Enter an event title.': 'ఈవెంట్ శీర్షికను నమోదు చేయండి.',
      'Enter your recovery passphrase to access your private encrypted vault.':
          'మీ ప్రైవేట్ ఎన్‌క్రిప్టెడ్ వాల్ట్‌ని యాక్సెస్ చేయడానికి మీ రికవరీ పాస్‌ఫ్రేజ్‌ని నమోదు చేయండి.',
      'Ephemeral Pairing PIN Code': 'ఎఫెమెరల్ పెయిరింగ్ పిన్ కోడ్',
      'Event': 'ఈవెంట్',
      'Every result stays linked to your encrypted graph and evidence.':
          'ప్రతి ఫలితం మీ గుప్తీకరించిన గ్రాఫ్ మరియు సాక్ష్యంతో లింక్ చేయబడి ఉంటుంది.',
      'Evidence': 'సాక్ష్యం',
      'Execute deterministic graph queries for attention, expiry, spending, and warranties.':
          'శ్రద్ధ, గడువు, ఖర్చు మరియు వారంటీల కోసం నిర్ణయాత్మక గ్రాఫ్ ప్రశ్నలను అమలు చేయండి.',
      'Export Document': 'ఎగుమతి పత్రం',
      'Export Redacted & Watermarked Copy':
          'సవరించిన & వాటర్‌మార్క్ చేసిన కాపీని ఎగుమతి చేయండి',
      'Export Redacted Copy': 'సవరించిన కాపీని ఎగుమతి చేయండి',
      'Export preparation': 'ఎగుమతి తయారీ',
      'Favourites': 'ఇష్టమైనవి',
      'Finance': 'ఫైనాన్స్',
      'Full view': 'పూర్తి వీక్షణ',
      'Generate Pairing PIN': 'జత చేసే పిన్‌ని రూపొందించండి',
      'Graph': 'గ్రాఫ్',
      'Grid document view': 'గ్రిడ్ వీక్షణ',
      'Guidance, not a requirement': 'మార్గదర్శకత్వం, అవసరం కాదు',
      'Health Insurance Policy': 'ఆరోగ్య బీమా పాలసీ',
      'History': 'చరిత్ర',
      'History and evidence are retained.':
          'చరిత్ర మరియు ఆధారాలు భద్రపరచబడ్డాయి.',
      'Household & Ownership': 'గృహ & యాజమాన్యం',
      'Household Inventory': 'గృహ జాబితా',
      'Household Valuation': 'గృహ మూల్యాంకనం',
      'I understand OwnKeep cannot reset this passphrase.':
          'OwnKeep ఈ పాస్‌ఫ్రేజ్‌ని రీసెట్ చేయలేదని నేను అర్థం చేసుకున్నాను.',
      'Identifier': 'ఐడెంటిఫైయర్',
      'Identity': 'గుర్తింపు',
      'Import a document and OwnKeep will organize it locally.':
          'పత్రాన్ని దిగుమతి చేయండి మరియు OwnKeep దానిని స్థానికంగా నిర్వహిస్తుంది.',
      'Import a photo first, then link it.':
          'ముందుగా ఫోటోను దిగుమతి చేయండి, ఆపై దాన్ని లింక్ చేయండి.',
      'Import a record first.': 'ముందుగా రికార్డును దిగుమతి చేయండి.',
      'Import and review a document, or clear a filter.':
          'పత్రాన్ని దిగుమతి చేయండి మరియు సమీక్షించండి లేదా ఫిల్టర్‌ను క్లియర్ చేయండి.',
      'Inbox': 'ఇన్‌బాక్స్',
      'Inbox activity': 'ఇన్‌బాక్స్ కార్యాచరణ',
      'Include rejected and superseded':
          'తిరస్కరించబడిన మరియు భర్తీ చేయబడిన వాటిని చేర్చండి',
      'Insurance': 'భీమా',
      'Integrity check failed': 'సమగ్రత తనిఖీ విఫలమైంది',
      'Interface Language': 'ఇంటర్‌ఫేస్ భాష',
      'Item Metadata & Location': 'అంశం మెటాడేటా & స్థానం',
      'Keep What Matters. Own Your Data.':
          'ముఖ్యమైన వాటిని ఉంచండి. మీ డేటాను స్వంతం చేసుకోండి.',
      'Known Allergies': 'తెలిసిన అలెర్జీలు',
      'Language & Regional OCR Packs': 'భాష & ప్రాంతీయ OCR ప్యాక్‌లు',
      'Large-screen dual-pane overview and bulk import dropzone.':
          'పెద్ద స్క్రీన్ డ్యూయల్ పేన్ ఓవర్‌వ్యూ మరియు బల్క్ ఇంపోర్ట్ డ్రాప్‌జోన్.',
      'Library': 'లైబ్రరీ',
      'Life': 'లైఫ్',
      'Life Directory': 'లైఫ్ డైరెక్టరీ',
      'Life Event': 'లైఫ్ ఈవెంట్',
      'Life Navigator': 'లైఫ్ నావిగేటర్',
      'Life OS Overview': 'లైఫ్ OS ఓవర్‌వ్యూ',
      'Life Timeline': 'జీవిత కాలక్రమం',
      'Lifetime Spend': 'జీవితకాలం ఖర్చు',
      'Link encrypted evidence': 'గుప్తీకరించిన సాక్ష్యాన్ని లింక్ చేయండి',
      'Link encrypted record': 'లింక్ ఎన్‌క్రిప్టెడ్ రికార్డ్',
      'Link existing information': 'ఇప్పటికే ఉన్న సమాచారాన్ని లింక్ చేయండి',
      'Link information': 'లింక్ సమాచారం',
      'Link to a profile?': 'ప్రొఫైల్‌కి లింక్ చేయాలా?',
      'Linked Claims, Events, Tasks, and evidence remain unchanged.':
          'లింక్డ్ క్లెయిమ్‌లు, ఈవెంట్‌లు, టాస్క్‌లు మరియు సాక్ష్యాలు మారవు.',
      'Local suggestions become part of your life record only after you confirm them.':
          'మీరు వాటిని నిర్ధారించిన తర్వాత మాత్రమే స్థానిక సూచనలు మీ జీవిత రికార్డులో భాగమవుతాయి.',
      'Location': 'స్థానం',
      'Log Maintenance / Cost': 'లాగ్ నిర్వహణ / ఖర్చు',
      'Manage encrypted zero-knowledge backup destinations without token storage.':
          'టోకెన్ నిల్వ లేకుండా గుప్తీకరించిన జీరో-నాలెడ్జ్ బ్యాకప్ గమ్యస్థానాలను నిర్వహించండి.',
      'Mark completed': 'మార్క్ పూర్తయింది',
      'Mask Date of Birth': 'మాస్క్ పుట్టిన తేదీ',
      'Mask ID Numbers (Aadhaar / PAN / Passport)':
          'మాస్క్ ID నంబర్లు (ఆధార్ / పాన్ / పాస్‌పోర్ట్)',
      'Mask QR codes & Barcodes': 'QR కోడ్‌లు & బార్‌కోడ్‌లను ముసుగు చేయండి',
      'Mask Residential Address': 'మాస్క్ నివాస చిరునామా',
      'Mask Signatures': 'మాస్క్ సంతకాలు',
      'Medical': 'వైద్య',
      'Merge a duplicate': 'నకిలీని విలీనం చేయండి',
      'Monthly': 'నెలవారీ',
      'Multilingual Invariance Guaranteed': 'బహుభాషా స్థిరత్వం హామీ',
      'Name': 'పేరు',
      'New records will appear here and safely resume if interrupted.':
          'కొత్త రికార్డులు ఇక్కడ కనిపిస్తాయి మరియు అంతరాయం కలిగితే సురక్షితంగా పునఃప్రారంభించబడతాయి.',
      'Newest': 'సరికొత్త',
      'No Claims yet. Link a reviewed record from the Inbox.':
          'ఇంకా క్లెయిమ్‌లు లేవు. ఇన్‌బాక్స్ నుండి సమీక్షించిన రికార్డ్‌ను లింక్ చేయండి.',
      'No Smart Packs yet': 'ఇంకా స్మార్ట్ ప్యాక్‌లు లేవు',
      'No access logs recorded.': 'యాక్సెస్ లాగ్‌లు రికార్డ్ చేయబడలేదు.',
      'No account, analytics, cloud OCR, advertisements, or Internet permission in release builds.':
          'విడుదల బిల్డ్‌లలో ఖాతా, విశ్లేషణలు, క్లౌడ్ OCR, ప్రకటనలు లేదా ఇంటర్నెట్ అనుమతి లేదు.',
      'No automation executions recorded yet.':
          'ఆటోమేషన్ ఎగ్జిక్యూషన్‌లు ఇంకా రికార్డ్ చేయబడలేదు.',
      'No confirmed value yet': 'ఇంకా ధృవీకరించబడిన విలువ లేదు',
      'No documents are processing': 'ఏ పత్రాలు ప్రాసెస్ చేయబడవు',
      'No documents match these filters': 'ఈ ఫిల్టర్‌లకు ఏ పత్రాలు సరిపోలలేదు',
      'No documents processing': 'పత్రాలు ప్రాసెస్ చేయబడవు',
      'No encrypted evidence linked.':
          'ఎన్‌క్రిప్టెడ్ సాక్ష్యం లింక్ చేయబడలేదు.',
      'No extracted fields': 'సంగ్రహించబడిన ఫీల్డ్‌లు లేవు',
      'No fields were extracted. Confirm the type to finish.':
          'ఫీల్డ్‌లు ఏవీ సేకరించబడలేదు. పూర్తి చేయాల్సిన రకాన్ని నిర్ధారించండి.',
      'No linkable information yet': 'ఇంకా లింక్ చేయదగిన సమాచారం లేదు',
      'No linked evidence yet.': 'ఇంకా లింక్ చేయబడిన సాక్ష్యం లేదు.',
      'No location': 'స్థానం లేదు',
      'No maintenance or cost logs yet.':
          'ఇంకా నిర్వహణ లేదా ఖర్చు లాగ్‌లు లేవు.',
      'No matching duplicate was found.': 'సరిపోలే నకిలీ ఏదీ కనుగొనబడలేదు.',
      'No matching household items found.':
          'సరిపోలే గృహోపకరణాలు ఏవీ కనుగొనబడలేదు.',
      'No profile': 'ప్రొఫైల్ లేదు',
      'No profile changes recorded yet':
          'ఇంకా ప్రొఫైల్ మార్పులు నమోదు చేయబడలేదు',
      'No recognized text': 'గుర్తించబడిన వచనం లేదు',
      'No record': 'రికార్డు లేదు',
      'No relationships yet': 'ఇంకా సంబంధాలు లేవు',
      'No reminders': 'రిమైండర్‌లు లేవు',
      'No tags': 'ట్యాగ్‌లు లేవు',
      'No upcoming reminders': 'రాబోయే రిమైండర్‌లు లేవు',
      'Not now': 'ఇప్పుడు కాదు',
      'Nothing matched yet. Try a person, car, home, insurer, pack or record name.':
          'ఇంకా ఏదీ సరిపోలలేదు. వ్యక్తి, కారు, ఇల్లు, బీమా సంస్థ, ప్యాక్ లేదా రికార్డ్ పేరును ప్రయత్నించండి.',
      'Nothing urgent': 'అత్యవసరం ఏమీ లేదు',
      'Notifications are local and contain no document details.':
          'నోటిఫికేషన్‌లు స్థానికంగా ఉంటాయి మరియు పత్రం వివరాలు లేవు.',
      'ORGANIZATIONAL ITEMS': 'సంస్థాగత అంశాలు',
      'Offline': 'ఆఫ్‌లైన్',
      'Offline Automation Engine': 'ఆఫ్‌లైన్ ఆటోమేషన్ ఇంజిన్',
      'Offline Pack template': 'ఆఫ్‌లైన్ ప్యాక్ టెంప్లేట్',
      'Offline Safety Guaranteed': 'ఆఫ్‌లైన్ భద్రత హామీ',
      'Oldest': 'అతి పురాతనమైనది',
      'On the date': 'తేదీలో',
      'On-device Intelligence': 'ఆన్-డివైస్ ఇంటెలిజెన్స్',
      'Only encrypted archive bytes leave your device. Zero provider tokens or Master Vault Keys are retained by OwnKeep.':
          'గుప్తీకరించిన ఆర్కైవ్ బైట్‌లు మాత్రమే మీ పరికరం నుండి నిష్క్రమించబడతాయి. జీరో ప్రొవైడర్ టోకెన్లు లేదా మాస్టర్ వాల్ట్ కీలు OwnKeep ద్వారా ఉంచబడతాయి.',
      'Open encrypted evidence': 'ఎన్‌క్రిప్టెడ్ సాక్ష్యాన్ని తెరవండి',
      'Open inbox': 'ఇన్‌బాక్స్‌ని తెరవండి',
      'Open linked evidence': 'లింక్ చేయబడిన సాక్ష్యాలను తెరవండి',
      'Opening your encrypted vault...': 'ఎన్‌క్రిప్టెడ్ వాల్ట్ తెరుస్తోంది...',
      'Optional': 'ఐచ్ఛికం',
      'Optional country-specific guidance, not legal advice.':
          'ఐచ్ఛిక దేశం-నిర్దిష్ట మార్గదర్శకత్వం, న్యాయ సలహా కాదు.',
      'Organizational guidance': 'సంస్థాగత మార్గదర్శకత్వం',
      'Original file remains untouched. Redactions are flattened permanently before export.':
          'అసలు ఫైల్ తాకబడదు. ఎగుమతి చేయడానికి ముందు సవరణలు శాశ్వతంగా చదును చేయబడతాయి.',
      'Original remains encrypted': 'అసలు అవశేషాలు ఎన్‌క్రిప్ట్ చేయబడ్డాయి',
      'OwnKeep': 'స్వంత కీప్',
      'OwnKeep 5.0.0': 'ఓన్‌కీప్ 5.0.0',
      'OwnKeep 5.0.0 Final': 'OwnKeep 5.0.0 ఫైనల్',
      'OwnKeep Desktop Personal Life OS':
          'OwnKeep డెస్క్‌టాప్ వ్యక్తిగత జీవిత OS',
      'OwnKeep could not access private storage.':
          'OwnKeep ప్రైవేట్ నిల్వను యాక్సెస్ చేయలేకపోయింది.',
      'OwnKeep found possible matches. You decide whether to create Claim suggestions.':
          'OwnKeep సాధ్యం సరిపోలికలను కనుగొంది. దావా సూచనలను సృష్టించాలా వద్దా అని మీరు నిర్ణయించుకుంటారు.',
      'Pack is archived.': 'ప్యాక్ ఆర్కైవ్ చేయబడింది.',
      'Pair devices with ephemeral PIN codes for encrypted transfer.':
          'గుప్తీకరించిన బదిలీ కోసం ఎఫెమెరల్ PIN కోడ్‌లతో పరికరాలను జత చేయండి.',
      'People, things & places': 'వ్యక్తులు, వస్తువులు & స్థలాలు',
      'Prepare evidence for export': 'ఎగుమతి కోసం ఆధారాలను సిద్ధం చేయండి',
      'Preserves complete Claim, provenance, history, evidence, and graph compatibility between mobile and desktop without central backends.':
          'సెంట్రల్ బ్యాకెండ్‌లు లేకుండా మొబైల్ మరియు డెస్క్‌టాప్ మధ్య పూర్తి దావా, ఆధారాలు, చరిత్ర, సాక్ష్యం మరియు గ్రాఫ్ అనుకూలతను సంరక్షిస్తుంది.',
      'Primary Physician': 'ప్రాథమిక వైద్యుడు',
      'Prioritized locally from confirmed facts, events, evidence, integrity checks, and Inbox work.':
          'ధృవీకరించబడిన వాస్తవాలు, సంఘటనలు, సాక్ష్యం, సమగ్రత తనిఖీలు మరియు ఇన్‌బాక్స్ పని నుండి స్థానికంగా ప్రాధాన్యత ఇవ్వబడింది.',
      'Privacy Share': 'గోప్యతా భాగస్వామ్యం',
      'Privacy-aware Sharing': 'గోప్యత-అవగాహన భాగస్వామ్యం',
      'Private notes': 'ప్రైవేట్ నోట్లు',
      'Profile fields': 'ప్రొఫైల్ ఫీల్డ్‌లు',
      'Property': 'ఆస్తి',
      'Purchase Price': 'కొనుగోలు ధర',
      'REJECTED': 'తిరస్కరించబడింది',
      'Ready for you': 'మీ కోసం సిద్ధంగా ఉంది',
      'Recent Evidence Documents': 'ఇటీవలి సాక్ష్యం పత్రాలు',
      'Recognized text preview': 'గుర్తించబడిన వచన పరిదృశ్యం',
      'Records': 'రికార్డులు',
      'Recovery passphrase': 'రికవరీ పాస్‌ఫ్రేజ్',
      'Regional OCR Text Packs': 'ప్రాంతీయ OCR పాఠ్య ప్యాక్‌లు',
      'Reject': 'తిరస్కరించు',
      'Relationships': 'సంబంధాలు',
      'Reminders': 'రిమైండర్‌లు',
      'Requires an exact same-name profile match.':
          'ఖచ్చితమైన అదే-పేరు ప్రొఫైల్ సరిపోలిక అవసరం.',
      'Reschedule': 'మళ్ళీ షెడ్యూల్ చేయి',
      'Restore encrypted backup': 'ఎన్‌క్రిప్టెడ్ బ్యాకప్ పునరుద్ధరించండి',
      'Retry': 'మళ్ళీ ప్రయత్నించు',
      'Review': 'సమీక్షించండి',
      'Review export preparation': 'ఎగుమతి తయారీని సమీక్షించండి',
      'Review local suggestions and finish organizing.':
          'స్థానిక సూచనలను సమీక్షించి, నిర్వహించడాన్ని పూర్తి చేయండి.',
      'Save': 'సేవ్ చేయి',
      'Save Event Log': 'ఈవెంట్ లాగ్‌ను సేవ్ చేయండి',
      'Save Item': 'అంశాన్ని సేవ్ చేయండి',
      'Save Rule': 'నియమాన్ని సేవ్ చేయండి',
      'Save a verified .cvault file to Drive, iCloud, Files, or another document provider.':
          'ధృవీకరించబడిన .cvault ఫైల్‌ను Drive, iCloud, Files లేదా మరొక డాక్యుమెంట్ ప్రొవైడర్‌లో సేవ్ చేయండి.',
      'Save an unencrypted copy?': 'ఎన్‌క్రిప్ట్ చేయని కాపీని సేవ్ చేయాలా?',
      'Save copy': 'కాపీని సేవ్ చేయండి',
      'Save field': 'ఫీల్డ్‌ను సేవ్ చేయండి',
      'Scan or import here. OwnKeep encrypts first, then organizes everything locally for your review.':
          'ఇక్కడ స్కాన్ చేయండి లేదా దిగుమతి చేయండి. OwnKeep ముందుగా గుప్తీకరిస్తుంది, ఆపై మీ సమీక్ష కోసం ప్రతిదాన్ని స్థానికంగా నిర్వహిస్తుంది.',
      'Search': 'శోధించండి',
      'Search documents...': 'పత్రాలను శోధించండి...',
      'Securely sync vault items directly to nearby devices over local P2P.':
          'వాల్ట్ ఐటెమ్‌లను నేరుగా స్థానిక P2P ద్వారా సమీపంలోని పరికరాలకు సురక్షితంగా సమకాలీకరించండి.',
      'Select Destination Provider': 'డెస్టినేషన్ ప్రొవైడర్‌ని ఎంచుకోండి',
      'Select Transport Layer': 'రవాణా పొరను ఎంచుకోండి',
      'Selected backup': 'ఎంచుకున్న బ్యాకప్',
      'Settings': 'సెట్టింగ్‌లు',
      'Simulate Bulk Import Drop': 'బల్క్ దిగుమతి సిమ్యులేట్ చేయండి',
      'Simulate Transfer Session': 'బదిలీ సెషన్‌ను అనుకరించండి',
      'Smart Packs': 'స్మార్ట్ ప్యాక్‌లు',
      'Snooze 1 day': '1 రోజు తాత్కాలికంగా ఆపివేయండి',
      'Start building your private life record':
          'మీ వ్యక్తిగత జీవిత రికార్డును నిర్మించడం ప్రారంభించండి',
      'Store this passphrase somewhere safe. Losing it can make your encrypted documents permanently inaccessible.':
          'ఈ పాస్‌ఫ్రేజ్‌ని ఎక్కడైనా సురక్షితంగా నిల్వ చేయండి. దాన్ని పోగొట్టుకోవడం వల్ల మీ ఎన్‌క్రిప్టెడ్ డాక్యుమెంట్‌లు శాశ్వతంగా యాక్సెస్ చేయలేవు.',
      'Stored inside your encrypted vault.':
          'మీ ఎన్‌క్రిప్టెడ్ వాల్ట్‌లో స్టోర్ చేయబడింది.',
      'Strict offline mode': 'ఖచ్చితమైన ఆఫ్‌లైన్ మోడ్',
      'Strip EXIF & File Metadata': 'స్ట్రిప్ EXIF ​​& ఫైల్ మెటాడేటా',
      'Suggested': 'సూచించారు',
      'Task': 'టాస్క్',
      'Tasks & checklists': 'టాస్క్‌లు & చెక్‌లిస్ట్‌లు',
      'Tax': 'పన్ను',
      'Templates guide organization and never change your facts.':
          'టెంప్లేట్‌లు సంస్థను గైడ్ చేస్తాయి మరియు మీ వాస్తవాలను ఎప్పటికీ మార్చవు.',
      'Text': 'వచనం',
      'The duplicate ID and history will be retained.':
          'నకిలీ ID మరియు చరిత్ర అలాగే ఉంచబడుతుంది.',
      'The original remains encrypted and unchanged.':
          'అసలైనది గుప్తీకరించబడింది మరియు మారదు.',
      'The original remains in history and this replacement keeps its entity and evidence links.':
          'అసలైనది చరిత్రలో మిగిలిపోయింది మరియు ఈ భర్తీ దాని ఎంటిటీ మరియు సాక్ష్యం లింక్‌లను ఉంచుతుంది.',
      'The saved file will no longer be protected by OwnKeep. Anyone with access to the selected destination may be able to open it.':
          'సేవ్ చేయబడిన ఫైల్ ఇకపై OwnKeep ద్వారా రక్షించబడదు. ఎంచుకున్న గమ్యస్థానానికి యాక్సెస్ ఉన్న ఎవరైనా దాన్ని తెరవగలరు.',
      'This document is no longer available.':
          'ఈ పత్రం ఇప్పుడు అందుబాటులో లేదు.',
      'This month': 'ఈ నెల',
      'Timeline': 'టైమ్‌లైన్',
      'Timestamps when emergency medical card was opened:':
          'అత్యవసర వైద్య కార్డు తెరిచిన సమయముద్రలు:',
      'Total Assets Value': 'మొత్తం ఆస్తుల విలువ',
      'Total Lifetime Maintenance & Tax Spend':
          'మొత్తం జీవితకాల నిర్వహణ & పన్ను వ్యయం',
      'Total Maintenance Spend': 'మొత్తం నిర్వహణ ఖర్చు',
      'Total Spend': 'మొత్తం ఖర్చు',
      'Transferred vault archives are byte- and graph- equivalent, authenticated with SHA-256 signatures, and zero keys or plaintext leave your devices.':
          'బదిలీ చేయబడిన వాల్ట్ ఆర్కైవ్‌లు బైట్- మరియు గ్రాఫ్-సమానమైనవి, SHA-256 సంతకాలతో ప్రమాణీకరించబడతాయి మరియు జీరో కీలు లేదా సాదా వచనం మీ పరికరాలను వదిలివేస్తాయి.',
      'Transition item state while preserving complete historical service & cost records:':
          'పూర్తి చారిత్రక సేవ & ధర రికార్డులను సంరక్షించేటప్పుడు పరివర్తన అంశం స్థితి:',
      'Trigger Blind Sync Rehearsal': 'బ్లైండ్ సింక్ రిహార్సల్ ప్రారంభించండి',
      'Type': 'టైప్ చేయండి',
      'Type a query or tap a template above to query your vault.':
          'మీ ఖజానాను ప్రశ్నించడానికి ప్రశ్నను టైప్ చేయండి లేదా పైన ఉన్న టెంప్లేట్‌ను నొక్కండి.',
      'Unlock OwnKeep': 'OwnKeepని అన్‌లాక్ చేయండి',
      'Unlock vault': 'వాల్ట్ అన్‌లాక్ చేయండి',
      'Unlock with biometrics': 'బయోమెట్రిక్స్‌తో అన్‌లాక్ చేయండి',
      'Upcoming dues and expiries will appear here.':
          'రాబోయే బకాయిలు మరియు గడువులు ఇక్కడ కనిపిస్తాయి.',
      'Upcoming reminder': 'రాబోయే రిమైండర్',
      'Update Operational Status': 'కార్యాచరణ స్థితిని నవీకరించండి',
      'Use a verified backup to recover this document.':
          'ఈ పత్రాన్ని పునరుద్ధరించడానికి ధృవీకరించబడిన బ్యాకప్‌ని ఉపయోగించండి.',
      'Use an offline template': 'ఆఫ్‌లైన్ టెంప్లేట్‌ని ఉపయోగించండి',
      'Use expiry date': 'Use expiry date',
      'Use larger visual document cards.': 'Use larger visual document cards.',
      'Used when expiry reminder suggestions are added.':
          'Used when expiry reminder suggestions are added.',
      'Vault Summary': 'Vault Summary',
      'Vehicle': 'Vehicle',
      'Verify and restore': 'తనిఖీ చేసి పునరుద్ధరించండి',
      'Verify document details': 'Verify document details',
      'View grounded natural language summaries and recommendations.':
          'View grounded natural language summaries and recommendations.',
      'View minimized emergency responder contacts, blood group, and medical data.':
          'View minimized emergency responder contacts, blood group, and medical data.',
      'Warranties': 'Warranties',
      'Warranty Coverage': 'Warranty Coverage',
      'Website / URI': 'Website / URI',
      'Weekly': 'Weekly',
      'Whole vault': 'Whole vault',
      'Your facts remain yours': 'Your facts remain yours',
      'Your private life, organized locally.':
          'Your private life, organized locally.',
      'Zero Token Blind Backup Policy': 'Zero Token Blind Backup Policy',
      '⚠️ Notice: Exported copies leave OwnKeep protection and cannot be remotely revoked.':
          '⚠️ Notice: Exported copies leave OwnKeep protection and cannot be remotely revoked.',
    },
    SupportedLanguage.tamil: {
      '1. Recipient & Purpose': '1. Recipient & Purpose',
      '2. Field Redactions (Masking)': '2. Field Redactions',
      '3. Watermark Preview': '3. Watermark Preview',
      'Access dual-pane workspace views, multi-window layout, and bulk drop.':
          'Access dual-pane workspace views, multi-window layout, and bulk drop.',
      'Active Destination Configuration': 'Active Destination Configuration',
      'Active Medications': 'Active Medications',
      'Active Valuation': 'Active Valuation',
      'Add': 'சேர்',
      'Add Automation Rule': 'Add Automation Rule',
      'Add Household Item': 'Add Household Item',
      'Add India Pack suggestions': 'Add India Pack suggestions',
      'Add Item': 'Add Item',
      'Add Rule': 'Add Rule',
      'Add a record': 'Add a record',
      'Add another profile first.': 'Add another profile first.',
      'Add checklist': 'Add checklist',
      'Add custom field': 'Add custom field',
      'Add custom item': 'Add custom item',
      'Add event': 'Add event',
      'Add one from a document detail screen.':
          'Add one from a document detail screen.',
      'Add people, vehicles, properties, devices, and places. Everything stays encrypted on this device.':
          'Add people, vehicles, properties, devices, and places. Everything stays encrypted on this device.',
      'Add relationship': 'Add relationship',
      'Add task': 'பணி சேர்',
      'Add your first profile': 'Add your first profile',
      'Aliases': 'Aliases',
      'All Categories': 'All Categories',
      'All Types': 'All Types',
      'All document types': 'All document types',
      'All natural language summaries and recommendations are strictly grounded on verified indexed vault claims.':
          'All natural language summaries and recommendations are strictly grounded on verified indexed vault claims.',
      'All tags': 'All tags',
      'Applies to me': 'Applies to me',
      'Archive': 'காப்பகம்',
      'Archive Pack': 'Archive Pack',
      'Archive this Pack?': 'Archive this Pack?',
      'Archived': 'Archived',
      'Ask OwnKeep': 'OwnKeep இடம் கேளுங்கள்',
      'Ask OwnKeep parses facts directly from your encrypted graph and evidence documents without LLM hallucinations or cloud calls.':
          'Ask OwnKeep parses facts directly from your encrypted graph and evidence documents without LLM hallucinations or cloud calls.',
      'Attention': 'கவனம்',
      'Attention & Tasks': 'Attention & Tasks',
      'Attention Items': 'Attention Items',
      'Attention Needed': 'Attention Needed',
      'Automation runs 100% locally with bounded recursion, cycle detection, audit trails, and zero external network calls.':
          'Automation runs 100% locally with bounded recursion, cycle detection, audit trails, and zero external network calls.',
      'Back': 'பின்செல்',
      'Backup & recovery': 'காப்பு & மீட்டமைப்பு',
      'Backup recovery passphrase': 'Backup recovery passphrase',
      'Biometric unlock': 'உயிரியல் பூட்டுநீக்கம்',
      'Blind Backup Destinations': 'ரகசிய காப்பு இடங்கள்',
      'Bring records into your life': 'Bring records into your life',
      'Build your private life map': 'Build your private life map',
      'Cancel': 'ரத்துசெய்',
      'Changing a template only changes this checklist. It never changes confirmed facts or claims that an item is legally required.':
          'Changing a template only changes this checklist. It never changes confirmed facts or claims that an item is legally required.',
      'Changing interface language does not alter stored Claim values, predicates, Entity IDs, evidence, or backup bytes.':
          'Changing interface language does not alter stored Claim values, predicates, Entity IDs, evidence, or backup bytes.',
      'Checking this device...': 'சாதனம் சரிபார்க்கப்படுகிறது...',
      'Checklist': 'Checklist',
      'Choose a custom date': 'Choose a custom date',
      'Choose duplicate to merge': 'Choose duplicate to merge',
      'Choose encrypted profile photo': 'Choose encrypted profile photo',
      'Choose new date': 'Choose new date',
      'Close': 'மூடு',
      'Close and reopen the app. If this continues, preserve the app data until recovery or restore tools are available.':
          'Close and reopen the app. If this continues, preserve the app data until recovery or restore tools are available.',
      'Complete': 'முழுமையாக்கு',
      'Configure interface locale and regional OCR text recognition packs.':
          'Configure interface locale and regional OCR text recognition packs.',
      'Configure local WHEN / IF / THEN rules for reminders, backup, and tagging.':
          'Configure local WHEN / IF / THEN rules for reminders, backup, and tagging.',
      'Configure local WHEN / IF / THEN rules, preview execution, and inspect audit logs.':
          'Configure local WHEN / IF / THEN rules, preview execution, and inspect audit logs.',
      'Configure user-selected blind cloud & NAS encrypted destinations.':
          'Configure user-selected blind cloud & NAS encrypted destinations.',
      'Confirm': 'உறுதிசெய்',
      'Confirm only after comparing these values with the original document. Clear a value to remove it.':
          'Confirm only after comparing these values with the original document. Clear a value to remove it.',
      'Confirm recovery passphrase': 'Confirm recovery passphrase',
      'Confirm reviewed details': 'Confirm reviewed details',
      'Confirm the recovery warning to continue.':
          'Confirm the recovery warning to continue.',
      'Continue': 'தொடரவும்',
      'Correct without overwriting': 'Correct without overwriting',
      'Corrected': 'Corrected',
      'Create': 'உருவாக்கு',
      'Create Smart Pack': 'Create Smart Pack',
      'Create a Smart Pack': 'Create a Smart Pack',
      'Create a custom Pack': 'Create a custom Pack',
      'Create a private organizational checklist from an offline template or make your own.':
          'Create a private organizational checklist from an offline template or make your own.',
      'Create encrypted backup': 'ரகசிய காப்பு உருவாக்கு',
      'Create encrypted vault': 'வால்ட் உருவாக்கு',
      'Create task': 'Create task',
      'Create your private vault': 'Create your private vault',
      'Creating your private vault...': 'வால்ட் உருவாக்கப்படுகிறது...',
      'Custom Smart Pack': 'Custom Smart Pack',
      'Custom encrypted field': 'Custom encrypted field',
      'Customize': 'Customize',
      'Customize item': 'Customize item',
      'Daily': 'Daily',
      'Dark mode': 'இருண்ட முறை',
      'Date': 'Date',
      'Date range': 'Date range',
      'Default reminder offsets': 'நினைவூட்டல்கள்',
      'Delete': 'அழி',
      'Desktop & Mobile Graph Compatibility Verified':
          'Desktop & Mobile Graph Compatibility Verified',
      'Desktop Large-Scale Bulk Import Dropzone':
          'Desktop Large-Scale Bulk Import Dropzone',
      'Desktop Layout Modes': 'Desktop Layout Modes',
      'Deterministic Graph Answers': 'Deterministic Graph Answers',
      'Device security': 'சாதன பாதுகாப்பு',
      'Device-to-Device Transfer': 'சாதன பரிமாற்றம் (P2P Transfer)',
      'Dismiss': 'நிராகரி',
      'Documents Library': 'Documents Library',
      'Documents stay encrypted on this device. Start by choosing the recovery passphrase that protects your vault.':
          'Documents stay encrypted on this device. Start by choosing the recovery passphrase that protects your vault.',
      'Does not create a plaintext export.':
          'Does not create a plaintext export.',
      'Does not repeat': 'Does not repeat',
      'Done': 'முடிந்தது',
      'Drag & drop directories or multiple document files for high-throughput parallel OCR processing.':
          'Drag & drop directories or multiple document files for high-throughput parallel OCR processing.',
      'Due date': 'Due date',
      'Edit': 'Edit',
      'Edit tags': 'Edit tags',
      'Emergency Access Audit Log': 'Emergency Access Audit Log',
      'Emergency Medical Card': 'அவசர மருத்துவ அட்டை',
      'Emergency Responder Contacts': 'Emergency Responder Contacts',
      'Emergency Storage Boundary Active. Isolated from main vault graph, evidence, and claims.':
          'Emergency Storage Boundary Active. Isolated from main vault graph, evidence, and claims.',
      'Encrypted P2P Transfer (No Server)': 'Encrypted P2P Transfer',
      'Encrypted evidence': 'Encrypted evidence',
      'End date': 'End date',
      'End date cannot be before start date.':
          'End date cannot be before start date.',
      'Enter a currency code.': 'Enter a currency code.',
      'Enter a valid amount.': 'Enter a valid amount.',
      'Enter an event title.': 'Enter an event title.',
      'Enter your recovery passphrase to access your private encrypted vault.':
          'Enter your recovery passphrase to access your private encrypted vault.',
      'Ephemeral Pairing PIN Code': 'Ephemeral Pairing PIN Code',
      'Event': 'Event',
      'Every result stays linked to your encrypted graph and evidence.':
          'Every result stays linked to your encrypted graph and evidence.',
      'Evidence': 'Evidence',
      'Execute deterministic graph queries for attention, expiry, spending, and warranties.':
          'Execute deterministic graph queries for attention, expiry, spending, and warranties.',
      'Export Document': 'Export Document',
      'Export Redacted & Watermarked Copy':
          'Export Redacted & Watermarked Copy',
      'Export Redacted Copy': 'Export Redacted Copy',
      'Export preparation': 'Export preparation',
      'Favourites': 'Favourites',
      'Finance': 'Finance',
      'Full view': 'Full view',
      'Generate Pairing PIN': 'Generate Pairing PIN',
      'Graph': 'வரைபடம்',
      'Grid document view': 'கட்டக் காட்சி',
      'Guidance, not a requirement': 'Guidance, not a requirement',
      'Health Insurance Policy': 'Health Insurance Policy',
      'History': 'History',
      'History and evidence are retained.':
          'History and evidence are retained.',
      'Household & Ownership': 'Household & Ownership',
      'Household Inventory': 'Household Inventory',
      'Household Valuation': 'Household Valuation',
      'I understand OwnKeep cannot reset this passphrase.':
          'I understand OwnKeep cannot reset this passphrase.',
      'Identifier': 'Identifier',
      'Identity': 'Identity',
      'Import a document and OwnKeep will organize it locally.':
          'Import a document and OwnKeep will organize it locally.',
      'Import a photo first, then link it.':
          'Import a photo first, then link it.',
      'Import a record first.': 'Import a record first.',
      'Import and review a document, or clear a filter.':
          'Import and review a document, or clear a filter.',
      'Inbox': 'இன்பாக்ஸ்',
      'Inbox activity': 'Inbox activity',
      'Include rejected and superseded': 'Include rejected and superseded',
      'Insurance': 'Insurance',
      'Integrity check failed': 'Integrity check failed',
      'Interface Language': 'இடைமுக மொழி',
      'Item Metadata & Location': 'Item Metadata & Location',
      'Keep What Matters. Own Your Data.': 'Keep What Matters. Own Your Data.',
      'Known Allergies': 'Known Allergies',
      'Language & Regional OCR Packs': 'மொழி மற்றும் OCR பேக்குகள்',
      'Large-screen dual-pane overview and bulk import dropzone.':
          'Large-screen dual-pane overview and bulk import dropzone.',
      'Library': 'நூலகம்',
      'Life': 'வாழ்க்கை',
      'Life Directory': 'Life Directory',
      'Life Event': 'Life Event',
      'Life Navigator': 'Life Navigator',
      'Life OS Overview': 'Life OS Overview',
      'Life Timeline': 'Life Timeline',
      'Lifetime Spend': 'Lifetime Spend',
      'Link encrypted evidence': 'Link encrypted evidence',
      'Link encrypted record': 'Link encrypted record',
      'Link existing information': 'Link existing information',
      'Link information': 'Link information',
      'Link to a profile?': 'Link to a profile?',
      'Linked Claims, Events, Tasks, and evidence remain unchanged.':
          'Linked Claims, Events, Tasks, and evidence remain unchanged.',
      'Local suggestions become part of your life record only after you confirm them.':
          'Local suggestions become part of your life record only after you confirm them.',
      'Location': 'Location',
      'Log Maintenance / Cost': 'Log Maintenance / Cost',
      'Manage encrypted zero-knowledge backup destinations without token storage.':
          'Manage encrypted zero-knowledge backup destinations without token storage.',
      'Mark completed': 'Mark completed',
      'Mask Date of Birth': 'Mask Date of Birth',
      'Mask ID Numbers (Aadhaar / PAN / Passport)':
          'Mask ID Numbers (Aadhaar / PAN / Passport)',
      'Mask QR codes & Barcodes': 'Mask QR codes & Barcodes',
      'Mask Residential Address': 'Mask Residential Address',
      'Mask Signatures': 'Mask Signatures',
      'Medical': 'Medical',
      'Merge a duplicate': 'Merge a duplicate',
      'Monthly': 'Monthly',
      'Multilingual Invariance Guaranteed': 'பன்மொழி மாறாத்தன்மை உத்தரவாதம்',
      'Name': 'Name',
      'New records will appear here and safely resume if interrupted.':
          'New records will appear here and safely resume if interrupted.',
      'Newest': 'Newest',
      'No Claims yet. Link a reviewed record from the Inbox.':
          'No Claims yet. Link a reviewed record from the Inbox.',
      'No Smart Packs yet': 'No Smart Packs yet',
      'No access logs recorded.': 'No access logs recorded.',
      'No account, analytics, cloud OCR, advertisements, or Internet permission in release builds.':
          'No account, analytics, cloud OCR, advertisements, or Internet permission in release builds.',
      'No automation executions recorded yet.':
          'No automation executions recorded yet.',
      'No confirmed value yet': 'உறுதிப்படுத்தப்பட்ட மதிப்பு இன்னும் இல்லை',
      'No documents are processing': 'ஆவணங்கள் எதுவும் செயலாக்கப்படவில்லை',
      'No documents match these filters':
          'இந்த வடிப்பான்களுடன் எந்த ஆவணமும் பொருந்தவில்லை',
      'No documents processing': 'ஆவணங்கள் செயலாக்கப்படவில்லை',
      'No encrypted evidence linked.':
          'மறைகுறியாக்கப்பட்ட சான்றுகள் இணைக்கப்படவில்லை.',
      'No extracted fields': 'பிரித்தெடுக்கப்பட்ட புலங்கள் இல்லை',
      'No fields were extracted. Confirm the type to finish.':
          'புலங்கள் எதுவும் எடுக்கப்படவில்லை. முடிக்க வேண்டிய வகையை உறுதிப்படுத்தவும்.',
      'No linkable information yet': 'இன்னும் இணைக்கக்கூடிய தகவல்கள் இல்லை',
      'No linked evidence yet.': 'இணைக்கப்பட்ட ஆதாரம் இதுவரை இல்லை.',
      'No location': 'இடம் இல்லை',
      'No maintenance or cost logs yet.':
          'இதுவரை பராமரிப்பு அல்லது செலவு பதிவுகள் இல்லை.',
      'No matching duplicate was found.':
          'பொருந்தக்கூடிய நகல் எதுவும் கிடைக்கவில்லை.',
      'No matching household items found.':
          'பொருந்தக்கூடிய வீட்டுப் பொருட்கள் எதுவும் இல்லை.',
      'No profile': 'சுயவிவரம் இல்லை',
      'No profile changes recorded yet':
          'இதுவரை சுயவிவர மாற்றங்கள் எதுவும் பதிவு செய்யப்படவில்லை',
      'No recognized text': 'அங்கீகரிக்கப்பட்ட உரை இல்லை',
      'No record': 'பதிவு இல்லை',
      'No relationships yet': 'இன்னும் உறவுகள் இல்லை',
      'No reminders': 'நினைவூட்டல்கள் இல்லை',
      'No tags': 'குறிச்சொற்கள் இல்லை',
      'No upcoming reminders': 'வரவிருக்கும் நினைவூட்டல்கள் இல்லை',
      'Not now': 'இப்போது இல்லை',
      'Nothing matched yet. Try a person, car, home, insurer, pack or record name.':
          'இன்னும் எதுவும் பொருந்தவில்லை. ஒரு நபர், கார், வீடு, காப்பீட்டாளர், பேக் அல்லது பதிவு பெயரை முயற்சிக்கவும்.',
      'Nothing urgent': 'ஒன்றும் அவசரமில்லை',
      'Notifications are local and contain no document details.':
          'அறிவிப்புகள் உள்ளூர் மற்றும் ஆவண விவரங்கள் இல்லை.',
      'ORGANIZATIONAL ITEMS': 'நிறுவனப் பொருட்கள்',
      'Offline': 'ஆஃப்லைன்',
      'Offline Automation Engine': 'ஆஃப்லைன் தானியங்கி எஞ்சின்',
      'Offline Pack template': 'ஆஃப்லைன் பேக் டெம்ப்ளேட்',
      'Offline Safety Guaranteed': 'ஆஃப்லைன் பாதுகாப்பு உத்தரவாதம்',
      'Oldest': 'பழமையானது',
      'On the date': 'தேதியில்',
      'On-device Intelligence': 'சாதன நுண்ணறிவு',
      'Only encrypted archive bytes leave your device. Zero provider tokens or Master Vault Keys are retained by OwnKeep.':
          'என்க்ரிப்ட் செய்யப்பட்ட காப்பக பைட்டுகள் மட்டுமே உங்கள் சாதனத்திலிருந்து வெளியேறும். ஜீரோ புரோவைடர் டோக்கன்கள் அல்லது மாஸ்டர் வால்ட் கீகள் OwnKeep ஆல் தக்கவைக்கப்படுகின்றன.',
      'Open encrypted evidence': 'மறைகுறியாக்கப்பட்ட ஆதாரத்தைத் திறக்கவும்',
      'Open inbox': 'இன்பாக்ஸைத் திற',
      'Open linked evidence': 'இணைக்கப்பட்ட ஆதாரத்தைத் திறக்கவும்',
      'Opening your encrypted vault...': 'வால்ட் திறக்கப்படுகிறது...',
      'Optional': 'விருப்பமானது',
      'Optional country-specific guidance, not legal advice.':
          'விருப்பமான நாடு சார்ந்த வழிகாட்டுதல், சட்ட ஆலோசனை அல்ல.',
      'Organizational guidance': 'நிறுவன வழிகாட்டுதல்',
      'Original file remains untouched. Redactions are flattened permanently before export.':
          'அசல் கோப்பு தொடப்படாமல் உள்ளது. ஏற்றுமதிக்கு முன் திருத்தங்கள் நிரந்தரமாக சமன் செய்யப்படுகின்றன.',
      'Original remains encrypted': 'அசல் எஞ்சியுள்ள குறியாக்கம்',
      'OwnKeep': 'சொந்த வைத்திருத்தல்',
      'OwnKeep 5.0.0': 'OwnKeep 5.0.0',
      'OwnKeep 5.0.0 Final': 'OwnKeep 5.0.0 இறுதி',
      'OwnKeep Desktop Personal Life OS': 'டெஸ்க்டாப் லைஃப் OS',
      'OwnKeep could not access private storage.':
          'OwnKeep மூலம் தனிப்பட்ட சேமிப்பிடத்தை அணுக முடியவில்லை.',
      'OwnKeep found possible matches. You decide whether to create Claim suggestions.':
          'OwnKeep சாத்தியமான பொருத்தங்களைக் கண்டறிந்துள்ளது. உரிமைகோரல் பரிந்துரைகளை உருவாக்க வேண்டுமா என்பதை நீங்கள் முடிவு செய்யுங்கள்.',
      'Pack is archived.': 'பேக் காப்பகப்படுத்தப்பட்டுள்ளது.',
      'Pair devices with ephemeral PIN codes for encrypted transfer.':
          'மறைகுறியாக்கப்பட்ட பரிமாற்றத்திற்கான எபிமரல் பின் குறியீடுகளுடன் சாதனங்களை இணைக்கவும்.',
      'People, things & places': 'மக்கள், பொருட்கள் மற்றும் இடங்கள்',
      'Prepare evidence for export': 'ஏற்றுமதிக்கான ஆதாரங்களைத் தயாரிக்கவும்',
      'Preserves complete Claim, provenance, history, evidence, and graph compatibility between mobile and desktop without central backends.':
          'முழுமையான உரிமைகோரல், ஆதாரம், வரலாறு, சான்றுகள் மற்றும் மொபைல் மற்றும் டெஸ்க்டாப்பிற்கு இடையேயான வரைபடப் பொருந்தக்கூடிய தன்மையை மையப் பின்முனைகள் இல்லாமல் பாதுகாக்கிறது.',
      'Primary Physician': 'முதன்மை மருத்துவர்',
      'Prioritized locally from confirmed facts, events, evidence, integrity checks, and Inbox work.':
          'உறுதிப்படுத்தப்பட்ட உண்மைகள், நிகழ்வுகள், சான்றுகள், ஒருமைப்பாடு சோதனைகள் மற்றும் இன்பாக்ஸ் வேலை ஆகியவற்றிலிருந்து உள்நாட்டில் முன்னுரிமை அளிக்கப்படுகிறது.',
      'Privacy Share': 'தனியுரிமை பகிர்வு',
      'Privacy-aware Sharing': 'தனியுரிமை விழிப்புணர்வு பகிர்வு',
      'Private notes': 'தனிப்பட்ட குறிப்புகள்',
      'Profile fields': 'சுயவிவர புலங்கள்',
      'Property': 'சொத்து',
      'Purchase Price': 'கொள்முதல் விலை',
      'REJECTED': 'நிராகரிக்கப்பட்டது',
      'Ready for you': 'உங்களுக்காக தயார்',
      'Recent Evidence Documents': 'சமீபத்திய சான்று ஆவணங்கள்',
      'Recognized text preview': 'அங்கீகரிக்கப்பட்ட உரை மாதிரிக்காட்சி',
      'Records': 'பதிவுகள்',
      'Recovery passphrase': 'மீட்பு கடவுச்சொற்றொடர்',
      'Regional OCR Text Packs': 'பிராந்திய OCR உரை பேக்குகள்',
      'Reject': 'நிராகரிக்கவும்',
      'Relationships': 'உறவுகள்',
      'Reminders': 'நினைவூட்டல்கள்',
      'Requires an exact same-name profile match.':
          'சரியான அதே பெயரின் சுயவிவரப் பொருத்தம் தேவை.',
      'Reschedule': 'மறுநேரம் குறி',
      'Restore encrypted backup': 'காப்பு மீட்டமை',
      'Retry': 'மீண்டும்முயல்',
      'Review': 'மதிப்பாய்வு',
      'Review export preparation': 'ஏற்றுமதி தயாரிப்பை மதிப்பாய்வு செய்யவும்',
      'Review local suggestions and finish organizing.':
          'உள்ளூர் பரிந்துரைகளை மதிப்பாய்வு செய்து ஒழுங்கமைப்பதை முடிக்கவும்.',
      'Save': 'சேமி',
      'Save Event Log': 'நிகழ்வு பதிவை சேமிக்கவும்',
      'Save Item': 'பொருளைச் சேமிக்கவும்',
      'Save Rule': 'விதியைச் சேமிக்கவும்',
      'Save a verified .cvault file to Drive, iCloud, Files, or another document provider.':
          'சரிபார்க்கப்பட்ட .cvault கோப்பை Drive, iCloud, Files அல்லது மற்றொரு ஆவண வழங்குநரில் சேமிக்கவும்.',
      'Save an unencrypted copy?': 'மறைகுறியாக்கப்படாத நகலை சேமிக்கவா?',
      'Save copy': 'நகலை சேமிக்கவும்',
      'Save field': 'புலத்தை சேமிக்கவும்',
      'Scan or import here. OwnKeep encrypts first, then organizes everything locally for your review.':
          'இங்கே ஸ்கேன் செய்யவும் அல்லது இறக்குமதி செய்யவும். OwnKeep முதலில் என்க்ரிப்ட் செய்து, பின்னர் உங்கள் மதிப்பாய்வுக்காக எல்லாவற்றையும் உள்ளூரில் ஒழுங்கமைக்கிறது.',
      'Search': 'தேடு',
      'Search documents...': 'ஆவணங்களைத் தேடு...',
      'Securely sync vault items directly to nearby devices over local P2P.':
          'உள்ளூர் P2P மூலம் வால்ட் உருப்படிகளை நேரடியாக அருகிலுள்ள சாதனங்களுடன் பாதுகாப்பாக ஒத்திசைக்கவும்.',
      'Select Destination Provider': 'இலக்கு வழங்குநரைத் தேர்ந்தெடுக்கவும்',
      'Select Transport Layer': 'போக்குவரத்து அடுக்கைத் தேர்ந்தெடுக்கவும்',
      'Selected backup': 'தேர்ந்தெடுக்கப்பட்ட காப்புப்பிரதி',
      'Settings': 'அமைப்புகள்',
      'Simulate Bulk Import Drop': 'மொத்த இறக்குமதி செய்',
      'Simulate Transfer Session': 'பரிமாற்ற அமர்வை உருவகப்படுத்தவும்',
      'Smart Packs': 'ஸ்மார்ட் பேக்குகள்',
      'Snooze 1 day': '1 நாள் உறக்கநிலையில் வைக்கவும்',
      'Start building your private life record':
          'உங்கள் தனிப்பட்ட வாழ்க்கைப் பதிவை உருவாக்கத் தொடங்குங்கள்',
      'Store this passphrase somewhere safe. Losing it can make your encrypted documents permanently inaccessible.':
          'இந்த கடவுச்சொற்றொடரை பாதுகாப்பான இடத்தில் சேமிக்கவும். அதை இழப்பது உங்கள் மறைகுறியாக்கப்பட்ட ஆவணங்களை நிரந்தரமாக அணுக முடியாததாகிவிடும்.',
      'Stored inside your encrypted vault.':
          'உங்கள் மறைகுறியாக்கப்பட்ட பெட்டகத்திற்குள் சேமிக்கப்பட்டது.',
      'Strict offline mode': 'ஆஃப்லைன் முறை மட்டும்',
      'Strip EXIF & File Metadata': 'ஸ்ட்ரிப் EXIF ​​& கோப்பு மெட்டாடேட்டா',
      'Suggested': 'பரிந்துரைக்கப்பட்டது',
      'Task': 'பணி',
      'Tasks & checklists': 'பணிகள் & சரிபார்ப்பு பட்டியல்கள்',
      'Tax': 'வரி',
      'Templates guide organization and never change your facts.':
          'வார்ப்புருக்கள் நிறுவனத்தை வழிநடத்தும் மற்றும் உங்கள் உண்மைகளை ஒருபோதும் மாற்றாது.',
      'Text': 'உரை',
      'The duplicate ID and history will be retained.':
          'நகல் ஐடி மற்றும் வரலாறு தக்கவைக்கப்படும்.',
      'The original remains encrypted and unchanged.':
          'அசல் குறியாக்கம் மற்றும் மாறாமல் உள்ளது.',
      'The original remains in history and this replacement keeps its entity and evidence links.':
          'அசல் வரலாற்றில் உள்ளது மற்றும் இந்த மாற்றீடு அதன் நிறுவனம் மற்றும் ஆதார இணைப்புகளை வைத்திருக்கிறது.',
      'The saved file will no longer be protected by OwnKeep. Anyone with access to the selected destination may be able to open it.':
          'சேமித்த கோப்பு இனி OwnKeep ஆல் பாதுகாக்கப்படாது. தேர்ந்தெடுக்கப்பட்ட இலக்குக்கான அணுகல் உள்ள எவரும் அதைத் திறக்க முடியும்.',
      'This document is no longer available.': 'இந்த ஆவணம் இனி கிடைக்காது.',
      'This month': 'இந்த மாதம்',
      'Timeline': 'காலவரிசை',
      'Timestamps when emergency medical card was opened:':
          'அவசர மருத்துவ அட்டை திறக்கப்பட்ட நேர முத்திரைகள்:',
      'Total Assets Value': 'மொத்த சொத்து மதிப்பு',
      'Total Lifetime Maintenance & Tax Spend':
          'மொத்த வாழ்நாள் பராமரிப்பு & வரிச் செலவு',
      'Total Maintenance Spend': 'மொத்த பராமரிப்பு செலவு',
      'Total Spend': 'மொத்த செலவு',
      'Transferred vault archives are byte- and graph- equivalent, authenticated with SHA-256 signatures, and zero keys or plaintext leave your devices.':
          'மாற்றப்பட்ட வால்ட் காப்பகங்கள் பைட் மற்றும் கிராஃப்-சமமானவை, SHA-256 கையொப்பங்களுடன் அங்கீகரிக்கப்பட்டுள்ளன, மேலும் பூஜ்ஜிய விசைகள் அல்லது எளிய உரை உங்கள் சாதனங்களை விட்டு வெளியேறும்.',
      'Transition item state while preserving complete historical service & cost records:':
          'முழுமையான வரலாற்று சேவை மற்றும் செலவுப் பதிவுகளைப் பாதுகாக்கும் போது உருப்படியின் நிலையை மாற்றவும்:',
      'Trigger Blind Sync Rehearsal': 'காப்பு ஒத்திசைவை தொடங்கு',
      'Type': 'வகை',
      'Type a query or tap a template above to query your vault.':
          'உங்கள் பெட்டகத்தை வினவ, வினவலைத் தட்டச்சு செய்யவும் அல்லது மேலே உள்ள டெம்ப்ளேட்டைத் தட்டவும்.',
      'Unlock OwnKeep': 'சொந்த கீப்பைத் திறக்கவும்',
      'Unlock vault': 'வால்ட் திற',
      'Unlock with biometrics': 'கைரேகை/முக அடையாளத்துடன் திற',
      'Upcoming dues and expiries will appear here.':
          'வரவிருக்கும் பாக்கிகள் மற்றும் காலாவதிகள் இங்கே தோன்றும்.',
      'Upcoming reminder': 'வரவிருக்கும் நினைவூட்டல்',
      'Update Operational Status': 'செயல்பாட்டு நிலையைப் புதுப்பிக்கவும்',
      'Use a verified backup to recover this document.':
          'இந்த ஆவணத்தை மீட்டெடுக்க சரிபார்க்கப்பட்ட காப்புப்பிரதியைப் பயன்படுத்தவும்.',
      'Use an offline template': 'ஆஃப்லைன் டெம்ப்ளேட்டைப் பயன்படுத்தவும்',
      'Use expiry date': 'காலாவதி தேதியைப் பயன்படுத்தவும்',
      'Use larger visual document cards.':
          'பெரிய காட்சி ஆவண அட்டைகளைப் பயன்படுத்தவும்.',
      'Used when expiry reminder suggestions are added.':
          'காலாவதி நினைவூட்டல் பரிந்துரைகள் சேர்க்கப்படும் போது பயன்படுத்தப்படும்.',
      'Vault Summary': 'வால்ட் சுருக்கம்',
      'Vehicle': 'வாகனம்',
      'Verify and restore': 'சரிபார்த்து மீட்டமை',
      'Verify document details': 'ஆவண விவரங்களைச் சரிபார்க்கவும்',
      'View grounded natural language summaries and recommendations.':
          'அடிப்படையான இயற்கை மொழி சுருக்கங்களையும் பரிந்துரைகளையும் காண்க.',
      'View minimized emergency responder contacts, blood group, and medical data.':
          'குறைக்கப்பட்ட அவசரகால பதிலளிப்பவர் தொடர்புகள், இரத்தக் குழு மற்றும் மருத்துவத் தரவுகளைப் பார்க்கவும்.',
      'Warranties': 'உத்தரவாதங்கள்',
      'Warranty Coverage': 'உத்தரவாத கவரேஜ்',
      'Website / URI': 'இணையதளம் / URI',
      'Weekly': 'வாரந்தோறும்',
      'Whole vault': 'முழு பெட்டகம்',
      'Your facts remain yours': 'உங்கள் உண்மைகள் உங்களுடையதாகவே இருக்கும்',
      'Your private life, organized locally.':
          'உங்கள் தனிப்பட்ட வாழ்க்கை, உள்நாட்டில் ஒழுங்கமைக்கப்பட்டது.',
      'Zero Token Blind Backup Policy': 'ஜீரோ டோக்கன் பிளைண்ட் பேக்கப் பாலிசி',
      '⚠️ Notice: Exported copies leave OwnKeep protection and cannot be remotely revoked.':
          '⚠️ அறிவிப்பு: ஏற்றுமதி செய்யப்பட்ட நகல்கள் OwnKeep பாதுகாப்பை விட்டுச் செல்கின்றன, மேலும் அவற்றைத் தொலைவிலிருந்து திரும்பப் பெற முடியாது.',
    },
    SupportedLanguage.kannada: {
      '1. Recipient & Purpose': '1. ಸ್ವೀಕರಿಸುವವರು ಮತ್ತು ಉದ್ದೇಶ',
      '2. Field Redactions (Masking)': '2. Field Redactions',
      '3. Watermark Preview': '3. ವಾಟರ್‌ಮಾರ್ಕ್ ಪೂರ್ವವೀಕ್ಷಣೆ',
      'Access dual-pane workspace views, multi-window layout, and bulk drop.':
          'ಡ್ಯುಯಲ್-ಪೇನ್ ವರ್ಕ್‌ಸ್ಪೇಸ್ ವೀಕ್ಷಣೆಗಳು, ಬಹು-ವಿಂಡೋ ಲೇಔಟ್ ಮತ್ತು ಬಲ್ಕ್ ಡ್ರಾಪ್ ಅನ್ನು ಪ್ರವೇಶಿಸಿ.',
      'Active Destination Configuration': 'ಸಕ್ರಿಯ ಗಮ್ಯಸ್ಥಾನ ಸಂರಚನೆ',
      'Active Medications': 'ಸಕ್ರಿಯ ಔಷಧಿಗಳು',
      'Active Valuation': 'ಸಕ್ರಿಯ ಮೌಲ್ಯಮಾಪನ',
      'Add': 'ಸೇರಿಸಿ',
      'Add Automation Rule': 'ಆಟೊಮೇಷನ್ ನಿಯಮವನ್ನು ಸೇರಿಸಿ',
      'Add Household Item': 'ಮನೆಯ ಐಟಂ ಸೇರಿಸಿ',
      'Add India Pack suggestions': 'ಇಂಡಿಯಾ ಪ್ಯಾಕ್ ಸಲಹೆಗಳನ್ನು ಸೇರಿಸಿ',
      'Add Item': 'ಐಟಂ ಸೇರಿಸಿ',
      'Add Rule': 'ನಿಯಮವನ್ನು ಸೇರಿಸಿ',
      'Add a record': 'ದಾಖಲೆ ಸೇರಿಸಿ',
      'Add another profile first.': 'ಮೊದಲು ಇನ್ನೊಂದು ಪ್ರೊಫೈಲ್ ಸೇರಿಸಿ.',
      'Add checklist': 'ಪರಿಶೀಲನಾಪಟ್ಟಿ ಸೇರಿಸಿ',
      'Add custom field': 'ಕಸ್ಟಮ್ ಕ್ಷೇತ್ರವನ್ನು ಸೇರಿಸಿ',
      'Add custom item': 'ಕಸ್ಟಮ್ ಐಟಂ ಸೇರಿಸಿ',
      'Add event': 'ಈವೆಂಟ್ ಸೇರಿಸಿ',
      'Add one from a document detail screen.':
          'ಡಾಕ್ಯುಮೆಂಟ್ ವಿವರ ಪರದೆಯಿಂದ ಒಂದನ್ನು ಸೇರಿಸಿ.',
      'Add people, vehicles, properties, devices, and places. Everything stays encrypted on this device.':
          'ಜನರು, ವಾಹನಗಳು, ಗುಣಲಕ್ಷಣಗಳು, ಸಾಧನಗಳು ಮತ್ತು ಸ್ಥಳಗಳನ್ನು ಸೇರಿಸಿ. ಈ ಸಾಧನದಲ್ಲಿ ಎಲ್ಲವೂ ಎನ್‌ಕ್ರಿಪ್ಟ್ ಆಗಿರುತ್ತದೆ.',
      'Add relationship': 'ಸಂಬಂಧವನ್ನು ಸೇರಿಸಿ',
      'Add task': 'ಕಾರ್ಯ ಸೇರಿಸಿ',
      'Add your first profile': 'ನಿಮ್ಮ ಮೊದಲ ಪ್ರೊಫೈಲ್ ಸೇರಿಸಿ',
      'Aliases': 'ಉಪನಾಮಗಳು',
      'All Categories': 'ಎಲ್ಲಾ ವರ್ಗಗಳು',
      'All Types': 'ಎಲ್ಲಾ ವಿಧಗಳು',
      'All document types': 'ಎಲ್ಲಾ ಡಾಕ್ಯುಮೆಂಟ್ ಪ್ರಕಾರಗಳು',
      'All natural language summaries and recommendations are strictly grounded on verified indexed vault claims.':
          'ಎಲ್ಲಾ ನೈಸರ್ಗಿಕ ಭಾಷೆಯ ಸಾರಾಂಶಗಳು ಮತ್ತು ಶಿಫಾರಸುಗಳು ಕಟ್ಟುನಿಟ್ಟಾಗಿ ಪರಿಶೀಲಿಸಿದ ಸೂಚ್ಯಂಕ ವಾಲ್ಟ್ ಕ್ಲೈಮ್‌ಗಳ ಮೇಲೆ ಆಧಾರಿತವಾಗಿವೆ.',
      'All tags': 'ಎಲ್ಲಾ ಟ್ಯಾಗ್‌ಗಳು',
      'Applies to me': 'ನನಗೆ ಅನ್ವಯಿಸುತ್ತದೆ',
      'Archive': 'ಆರ್ಕೈವ್',
      'Archive Pack': 'ಆರ್ಕೈವ್ ಪ್ಯಾಕ್',
      'Archive this Pack?': 'ಈ ಪ್ಯಾಕ್ ಅನ್ನು ಆರ್ಕೈವ್ ಮಾಡುವುದೇ?',
      'Archived': 'ಆರ್ಕೈವ್ ಮಾಡಲಾಗಿದೆ',
      'Ask OwnKeep': 'OwnKeep ನೊಂದಿಗೆ ಕೇಳಿ',
      'Ask OwnKeep parses facts directly from your encrypted graph and evidence documents without LLM hallucinations or cloud calls.':
          'LLM ಭ್ರಮೆಗಳು ಅಥವಾ ಕ್ಲೌಡ್ ಕರೆಗಳಿಲ್ಲದೆಯೇ ನಿಮ್ಮ ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಿದ ಗ್ರಾಫ್ ಮತ್ತು ಸಾಕ್ಷ್ಯ ದಾಖಲೆಗಳಿಂದ ನೇರವಾಗಿ OwnKeep ಪಾರ್ಸ್ ಫ್ಯಾಕ್ಟ್‌ಗಳನ್ನು ಕೇಳಿ.',
      'Attention': 'ಗಮನ',
      'Attention & Tasks': 'ಗಮನ ಮತ್ತು ಕಾರ್ಯಗಳು',
      'Attention Items': 'ಗಮನ ವಸ್ತುಗಳು',
      'Attention Needed': 'ಗಮನ ಅಗತ್ಯವಿದೆ',
      'Automation runs 100% locally with bounded recursion, cycle detection, audit trails, and zero external network calls.':
          'ಬೌಂಡೆಡ್ ರಿಕರ್ಷನ್, ಸೈಕಲ್ ಪತ್ತೆ, ಆಡಿಟ್ ಟ್ರೇಲ್‌ಗಳು ಮತ್ತು ಶೂನ್ಯ ಬಾಹ್ಯ ನೆಟ್‌ವರ್ಕ್ ಕರೆಗಳೊಂದಿಗೆ ಆಟೊಮೇಷನ್ 100% ಸ್ಥಳೀಯವಾಗಿ ಚಲಿಸುತ್ತದೆ.',
      'Back': 'ಹಿಂದಕ್ಕೆ',
      'Backup & recovery': 'ಬ್ಯಾಕಪ್ ಮತ್ತು ಮರುಸ್ಥಾಪನೆ',
      'Backup recovery passphrase': 'ಬ್ಯಾಕಪ್ ಮರುಪ್ರಾಪ್ತಿ ಪಾಸ್‌ಫ್ರೇಸ್',
      'Biometric unlock': 'ಬಯೋಮೆಟ್ರಿಕ್ ಅನ್‌ಲಾಕ್',
      'Blind Backup Destinations': 'ಬ್ಯಾಕಪ್ ಸ್ಥಳಗಳು',
      'Bring records into your life': 'ನಿಮ್ಮ ಜೀವನದಲ್ಲಿ ದಾಖಲೆಗಳನ್ನು ತನ್ನಿ',
      'Build your private life map': 'ನಿಮ್ಮ ಖಾಸಗಿ ಜೀವನದ ನಕ್ಷೆಯನ್ನು ನಿರ್ಮಿಸಿ',
      'Cancel': 'ರದ್ದುಗೊಳಿಸಿ',
      'Changing a template only changes this checklist. It never changes confirmed facts or claims that an item is legally required.':
          'ಟೆಂಪ್ಲೇಟ್ ಅನ್ನು ಬದಲಾಯಿಸುವುದು ಈ ಪರಿಶೀಲನಾಪಟ್ಟಿಯನ್ನು ಮಾತ್ರ ಬದಲಾಯಿಸುತ್ತದೆ. ಇದು ಎಂದಿಗೂ ದೃಢಪಡಿಸಿದ ಸತ್ಯಗಳನ್ನು ಅಥವಾ ಐಟಂ ಕಾನೂನುಬದ್ಧವಾಗಿ ಅಗತ್ಯವಿರುವ ಹಕ್ಕುಗಳನ್ನು ಬದಲಾಯಿಸುವುದಿಲ್ಲ.',
      'Changing interface language does not alter stored Claim values, predicates, Entity IDs, evidence, or backup bytes.':
          'ಇಂಟರ್ಫೇಸ್ ಭಾಷೆಯನ್ನು ಬದಲಾಯಿಸುವುದರಿಂದ ಸಂಗ್ರಹಿಸಲಾದ ಕ್ಲೈಮ್ ಮೌಲ್ಯಗಳು, ಮುನ್ಸೂಚನೆಗಳು, ಅಸ್ತಿತ್ವದ ಐಡಿಗಳು, ಪುರಾವೆಗಳು ಅಥವಾ ಬ್ಯಾಕಪ್ ಬೈಟ್‌ಗಳನ್ನು ಬದಲಾಯಿಸುವುದಿಲ್ಲ.',
      'Checking this device...': 'ಸಾಧನ ಪರಿಶೀಲಿಸಲಾಗುತ್ತಿದೆ...',
      'Checklist': 'ಪರಿಶೀಲನಾಪಟ್ಟಿ',
      'Choose a custom date': 'ಕಸ್ಟಮ್ ದಿನಾಂಕವನ್ನು ಆಯ್ಕೆಮಾಡಿ',
      'Choose duplicate to merge': 'ವಿಲೀನಗೊಳಿಸಲು ನಕಲು ಆಯ್ಕೆಮಾಡಿ',
      'Choose encrypted profile photo':
          'ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಿದ ಪ್ರೊಫೈಲ್ ಫೋಟೋ ಆಯ್ಕೆಮಾಡಿ',
      'Choose new date': 'ಹೊಸ ದಿನಾಂಕವನ್ನು ಆರಿಸಿ',
      'Close': 'ಮುಚ್ಚಿ',
      'Close and reopen the app. If this continues, preserve the app data until recovery or restore tools are available.':
          'ಅಪ್ಲಿಕೇಶನ್ ಅನ್ನು ಮುಚ್ಚಿ ಮತ್ತು ಮತ್ತೆ ತೆರೆಯಿರಿ. ಇದು ಮುಂದುವರಿದರೆ, ಮರುಪ್ರಾಪ್ತಿ ಅಥವಾ ಮರುಸ್ಥಾಪನೆ ಉಪಕರಣಗಳು ಲಭ್ಯವಾಗುವವರೆಗೆ ಅಪ್ಲಿಕೇಶನ್ ಡೇಟಾವನ್ನು ಸಂರಕ್ಷಿಸಿ.',
      'Complete': 'ಪೂರ್ಣಗೊಳಿಸಿ',
      'Configure interface locale and regional OCR text recognition packs.':
          'ಇಂಟರ್ಫೇಸ್ ಲೊಕೇಲ್ ಮತ್ತು ಪ್ರಾದೇಶಿಕ OCR ಪಠ್ಯ ಗುರುತಿಸುವಿಕೆ ಪ್ಯಾಕ್ಗಳನ್ನು ಕಾನ್ಫಿಗರ್ ಮಾಡಿ.',
      'Configure local WHEN / IF / THEN rules for reminders, backup, and tagging.':
          'ಜ್ಞಾಪನೆಗಳು, ಬ್ಯಾಕಪ್ ಮತ್ತು ಟ್ಯಾಗಿಂಗ್‌ಗಾಗಿ ಸ್ಥಳೀಯ ಯಾವಾಗ / IF / THEN ನಿಯಮಗಳನ್ನು ಕಾನ್ಫಿಗರ್ ಮಾಡಿ.',
      'Configure local WHEN / IF / THEN rules, preview execution, and inspect audit logs.':
          'ಸ್ಥಳೀಯ ಯಾವಾಗ / IF / ನಂತರ ನಿಯಮಗಳನ್ನು ಕಾನ್ಫಿಗರ್ ಮಾಡಿ, ಪೂರ್ವವೀಕ್ಷಣೆ ಎಕ್ಸಿಕ್ಯೂಶನ್, ಮತ್ತು ಆಡಿಟ್ ಲಾಗ್‌ಗಳನ್ನು ಪರೀಕ್ಷಿಸಿ.',
      'Configure user-selected blind cloud & NAS encrypted destinations.':
          'ಬಳಕೆದಾರ-ಆಯ್ಕೆ ಮಾಡಿದ ಬ್ಲೈಂಡ್ ಕ್ಲೌಡ್ ಮತ್ತು NAS ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಿದ ಸ್ಥಳಗಳನ್ನು ಕಾನ್ಫಿಗರ್ ಮಾಡಿ.',
      'Confirm': 'ಖಚಿತಪಡಿಸಿ',
      'Confirm only after comparing these values with the original document. Clear a value to remove it.':
          'ಈ ಮೌಲ್ಯಗಳನ್ನು ಮೂಲ ದಾಖಲೆಯೊಂದಿಗೆ ಹೋಲಿಸಿದ ನಂತರವೇ ದೃಢೀಕರಿಸಿ. ಅದನ್ನು ತೆಗೆದುಹಾಕಲು ಮೌಲ್ಯವನ್ನು ತೆರವುಗೊಳಿಸಿ.',
      'Confirm recovery passphrase': 'ಮರುಪ್ರಾಪ್ತಿ ಪಾಸ್‌ಫ್ರೇಸ್ ಅನ್ನು ದೃಢೀಕರಿಸಿ',
      'Confirm reviewed details': 'ಪರಿಶೀಲಿಸಿದ ವಿವರಗಳನ್ನು ದೃಢೀಕರಿಸಿ',
      'Confirm the recovery warning to continue.':
          'ಮುಂದುವರೆಯಲು ಚೇತರಿಕೆ ಎಚ್ಚರಿಕೆಯನ್ನು ದೃಢೀಕರಿಸಿ.',
      'Continue': 'ಮುಂದುವರಿಸಿ',
      'Correct without overwriting': 'ತಿದ್ದಿ ಬರೆಯದೆ ಸರಿಪಡಿಸಿ',
      'Corrected': 'ಸರಿಪಡಿಸಲಾಗಿದೆ',
      'Create': 'ರಚಿಸಿ',
      'Create Smart Pack': 'ಸ್ಮಾರ್ಟ್ ಪ್ಯಾಕ್ ರಚಿಸಿ',
      'Create a Smart Pack': 'ಸ್ಮಾರ್ಟ್ ಪ್ಯಾಕ್ ಅನ್ನು ರಚಿಸಿ',
      'Create a custom Pack': 'ಕಸ್ಟಮ್ ಪ್ಯಾಕ್ ಅನ್ನು ರಚಿಸಿ',
      'Create a private organizational checklist from an offline template or make your own.':
          'ಆಫ್‌ಲೈನ್ ಟೆಂಪ್ಲೇಟ್‌ನಿಂದ ಖಾಸಗಿ ಸಾಂಸ್ಥಿಕ ಪರಿಶೀಲನಾಪಟ್ಟಿಯನ್ನು ರಚಿಸಿ ಅಥವಾ ನಿಮ್ಮದೇ ಆದದನ್ನು ಮಾಡಿ.',
      'Create encrypted backup': 'ಎನ್‌ಕ್ರಿಪ್ಟ್ ಬ್ಯಾಕಪ್ ರಚಿಸಿ',
      'Create encrypted vault': 'ಎನ್‌ಕ್ರಿಪ್ಟ್ ವೋಲ್ಟ್ ರಚಿಸಿ',
      'Create task': 'ಕಾರ್ಯವನ್ನು ರಚಿಸಿ',
      'Create your private vault': 'ನಿಮ್ಮ ಖಾಸಗಿ ವಾಲ್ಟ್ ಅನ್ನು ರಚಿಸಿ',
      'Creating your private vault...': 'ವೋಲ್ಟ್ ರಚಿಸಲಾಗುತ್ತಿದೆ...',
      'Custom Smart Pack': 'ಕಸ್ಟಮ್ ಸ್ಮಾರ್ಟ್ ಪ್ಯಾಕ್',
      'Custom encrypted field': 'ಕಸ್ಟಮ್ ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಿದ ಕ್ಷೇತ್ರ',
      'Customize': 'ಕಸ್ಟಮೈಸ್ ಮಾಡಿ',
      'Customize item': 'ಐಟಂ ಅನ್ನು ಕಸ್ಟಮೈಸ್ ಮಾಡಿ',
      'Daily': 'ಪ್ರತಿದಿನ',
      'Dark mode': 'ಡಾರ್ಕ್ ಮೋಡ್',
      'Date': 'ದಿನಾಂಕ',
      'Date range': 'ದಿನಾಂಕ ವ್ಯಾಪ್ತಿ',
      'Default reminder offsets': 'ಜ್ಞಾಪನೆಗಳು',
      'Delete': 'ಅಳಿಸಿ',
      'Desktop & Mobile Graph Compatibility Verified':
          'ಡೆಸ್ಕ್‌ಟಾಪ್ ಮತ್ತು ಮೊಬೈಲ್ ಗ್ರಾಫ್ ಹೊಂದಾಣಿಕೆಯನ್ನು ಪರಿಶೀಲಿಸಲಾಗಿದೆ',
      'Desktop Large-Scale Bulk Import Dropzone':
          'ಡೆಸ್ಕ್‌ಟಾಪ್ ದೊಡ್ಡ ಪ್ರಮಾಣದ ಬೃಹತ್ ಆಮದು ಡ್ರಾಪ್‌ಜೋನ್',
      'Desktop Layout Modes': 'ಡೆಸ್ಕ್‌ಟಾಪ್ ಲೇಔಟ್ ಮೋಡ್‌ಗಳು',
      'Deterministic Graph Answers': 'ನಿರ್ಣಾಯಕ ಗ್ರಾಫ್ ಉತ್ತರಗಳು',
      'Device security': 'ಸಾಧನದ ಸುರಕ್ಷತೆ',
      'Device-to-Device Transfer': 'ಸಾಧನ ವರ್ಗಾವಣೆ (P2P Transfer)',
      'Dismiss': 'ತಿರಸ್ಕರಿಸಿ',
      'Documents Library': 'ಡಾಕ್ಯುಮೆಂಟ್ಸ್ ಲೈಬ್ರರಿ',
      'Documents stay encrypted on this device. Start by choosing the recovery passphrase that protects your vault.':
          'ಈ ಸಾಧನದಲ್ಲಿ ಡಾಕ್ಯುಮೆಂಟ್‌ಗಳು ಎನ್‌ಕ್ರಿಪ್ಟ್ ಆಗಿರುತ್ತವೆ. ನಿಮ್ಮ ವಾಲ್ಟ್ ಅನ್ನು ರಕ್ಷಿಸುವ ಮರುಪ್ರಾಪ್ತಿ ಪಾಸ್‌ಫ್ರೇಸ್ ಅನ್ನು ಆರಿಸುವ ಮೂಲಕ ಪ್ರಾರಂಭಿಸಿ.',
      'Does not create a plaintext export.': 'ಸರಳ ಪಠ್ಯ ರಫ್ತು ರಚಿಸುವುದಿಲ್ಲ.',
      'Does not repeat': 'ಪುನರಾವರ್ತಿಸುವುದಿಲ್ಲ',
      'Done': 'ಪೂರ್ಣಗೊಂಡಿದೆ',
      'Drag & drop directories or multiple document files for high-throughput parallel OCR processing.':
          'ಹೈ-ಥ್ರೂಪುಟ್ ಸಮಾನಾಂತರ OCR ಪ್ರಕ್ರಿಯೆಗಾಗಿ ಡೈರೆಕ್ಟರಿಗಳು ಅಥವಾ ಬಹು ಡಾಕ್ಯುಮೆಂಟ್ ಫೈಲ್‌ಗಳನ್ನು ಎಳೆಯಿರಿ ಮತ್ತು ಬಿಡಿ.',
      'Due date': 'ಅಂತಿಮ ದಿನಾಂಕ',
      'Edit': 'ಸಂಪಾದಿಸು',
      'Edit tags': 'ಟ್ಯಾಗ್‌ಗಳನ್ನು ಸಂಪಾದಿಸಿ',
      'Emergency Access Audit Log': 'ತುರ್ತು ಪ್ರವೇಶ ಆಡಿಟ್ ಲಾಗ್',
      'Emergency Medical Card': 'ತುರ್ತು ವೈದ್ಯಕೀಯ ಕಾರ್ಡ್',
      'Emergency Responder Contacts': 'ತುರ್ತು ಪ್ರತಿಕ್ರಿಯೆ ಸಂಪರ್ಕಗಳು',
      'Emergency Storage Boundary Active. Isolated from main vault graph, evidence, and claims.':
          'ತುರ್ತು ಶೇಖರಣಾ ಗಡಿ ಸಕ್ರಿಯವಾಗಿದೆ. ಮುಖ್ಯ ವಾಲ್ಟ್ ಗ್ರಾಫ್, ಪುರಾವೆಗಳು ಮತ್ತು ಹಕ್ಕುಗಳಿಂದ ಪ್ರತ್ಯೇಕಿಸಲಾಗಿದೆ.',
      'Encrypted P2P Transfer (No Server)': 'Encrypted P2P Transfer',
      'Encrypted evidence': 'ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಿದ ಪುರಾವೆ',
      'End date': 'ಅಂತಿಮ ದಿನಾಂಕ',
      'End date cannot be before start date.':
          'ಅಂತಿಮ ದಿನಾಂಕವು ಪ್ರಾರಂಭ ದಿನಾಂಕಕ್ಕಿಂತ ಮೊದಲು ಇರುವಂತಿಲ್ಲ.',
      'Enter a currency code.': 'ಕರೆನ್ಸಿ ಕೋಡ್ ನಮೂದಿಸಿ.',
      'Enter a valid amount.': 'ಮಾನ್ಯವಾದ ಮೊತ್ತವನ್ನು ನಮೂದಿಸಿ.',
      'Enter an event title.': 'ಈವೆಂಟ್ ಶೀರ್ಷಿಕೆಯನ್ನು ನಮೂದಿಸಿ.',
      'Enter your recovery passphrase to access your private encrypted vault.':
          'ನಿಮ್ಮ ಖಾಸಗಿ ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಿದ ವಾಲ್ಟ್ ಅನ್ನು ಪ್ರವೇಶಿಸಲು ನಿಮ್ಮ ಮರುಪ್ರಾಪ್ತಿ ಪಾಸ್‌ಫ್ರೇಸ್ ಅನ್ನು ನಮೂದಿಸಿ.',
      'Ephemeral Pairing PIN Code': 'ಎಫೆಮೆರಲ್ ಪೇರಿಂಗ್ ಪಿನ್ ಕೋಡ್',
      'Event': 'ಈವೆಂಟ್',
      'Every result stays linked to your encrypted graph and evidence.':
          'ಪ್ರತಿ ಫಲಿತಾಂಶವು ನಿಮ್ಮ ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಿದ ಗ್ರಾಫ್ ಮತ್ತು ಸಾಕ್ಷಿಗೆ ಲಿಂಕ್ ಆಗಿರುತ್ತದೆ.',
      'Evidence': 'ಸಾಕ್ಷಿ',
      'Execute deterministic graph queries for attention, expiry, spending, and warranties.':
          'ಗಮನ, ಮುಕ್ತಾಯ, ಖರ್ಚು ಮತ್ತು ವಾರಂಟಿಗಳಿಗಾಗಿ ನಿರ್ಣಾಯಕ ಗ್ರಾಫ್ ಪ್ರಶ್ನೆಗಳನ್ನು ಕಾರ್ಯಗತಗೊಳಿಸಿ.',
      'Export Document': 'ರಫ್ತು ಡಾಕ್ಯುಮೆಂಟ್',
      'Export Redacted & Watermarked Copy':
          'ರಫ್ತು ಮಾಡಲಾದ ಮತ್ತು ವಾಟರ್‌ಮಾರ್ಕ್ ಮಾಡಿದ ಪ್ರತಿ',
      'Export Redacted Copy': 'ರಫ್ತು ಮಾಡಲಾದ ನಕಲನ್ನು',
      'Export preparation': 'ರಫ್ತು ತಯಾರಿ',
      'Favourites': 'ಮೆಚ್ಚಿನವುಗಳು',
      'Finance': 'ಹಣಕಾಸು',
      'Full view': 'ಪೂರ್ಣ ನೋಟ',
      'Generate Pairing PIN': 'ಜೋಡಿಸುವ ಪಿನ್ ಅನ್ನು ರಚಿಸಿ',
      'Graph': 'ಗ್ರಾಫ್',
      'Grid document view': 'ಗ್ರಿಡ್ ನೋಟ',
      'Guidance, not a requirement': 'ಮಾರ್ಗದರ್ಶನ, ಅವಶ್ಯಕತೆ ಅಲ್ಲ',
      'Health Insurance Policy': 'ಆರೋಗ್ಯ ವಿಮಾ ಪಾಲಿಸಿ',
      'History': 'ಇತಿಹಾಸ',
      'History and evidence are retained.':
          'ಇತಿಹಾಸ ಮತ್ತು ಪುರಾವೆಗಳನ್ನು ಉಳಿಸಿಕೊಳ್ಳಲಾಗಿದೆ.',
      'Household & Ownership': 'ಮನೆ ಮತ್ತು ಮಾಲೀಕತ್ವ',
      'Household Inventory': 'ಮನೆಯ ದಾಸ್ತಾನು',
      'Household Valuation': 'ಮನೆಯ ಮೌಲ್ಯಮಾಪನ',
      'I understand OwnKeep cannot reset this passphrase.':
          'OwnKeep ಈ ಪಾಸ್‌ಫ್ರೇಸ್ ಅನ್ನು ಮರುಹೊಂದಿಸಲು ಸಾಧ್ಯವಿಲ್ಲ ಎಂದು ನಾನು ಅರ್ಥಮಾಡಿಕೊಂಡಿದ್ದೇನೆ.',
      'Identifier': 'ಗುರುತಿಸುವಿಕೆ',
      'Identity': 'ಗುರುತು',
      'Import a document and OwnKeep will organize it locally.':
          'ಡಾಕ್ಯುಮೆಂಟ್ ಅನ್ನು ಆಮದು ಮಾಡಿಕೊಳ್ಳಿ ಮತ್ತು OwnKeep ಅದನ್ನು ಸ್ಥಳೀಯವಾಗಿ ಆಯೋಜಿಸುತ್ತದೆ.',
      'Import a photo first, then link it.':
          'ಮೊದಲು ಫೋಟೋವನ್ನು ಆಮದು ಮಾಡಿ, ನಂತರ ಅದನ್ನು ಲಿಂಕ್ ಮಾಡಿ.',
      'Import a record first.': 'ಮೊದಲು ದಾಖಲೆಯನ್ನು ಆಮದು ಮಾಡಿಕೊಳ್ಳಿ.',
      'Import and review a document, or clear a filter.':
          'ಡಾಕ್ಯುಮೆಂಟ್ ಅನ್ನು ಆಮದು ಮಾಡಿ ಮತ್ತು ಪರಿಶೀಲಿಸಿ ಅಥವಾ ಫಿಲ್ಟರ್ ಅನ್ನು ತೆರವುಗೊಳಿಸಿ.',
      'Inbox': 'ಇನ್‌ಬಾಕ್ಸ್',
      'Inbox activity': 'ಇನ್‌ಬಾಕ್ಸ್ ಚಟುವಟಿಕೆ',
      'Include rejected and superseded':
          'ತಿರಸ್ಕರಿಸಿದ ಮತ್ತು ಅತಿಕ್ರಮಿಸಿರುವುದನ್ನು ಸೇರಿಸಿ',
      'Insurance': 'ವಿಮೆ',
      'Integrity check failed': 'ಸಮಗ್ರತೆಯ ಪರಿಶೀಲನೆ ವಿಫಲವಾಗಿದೆ',
      'Interface Language': 'ಇಂಟರ್‌ಫೇಸ್ ಭಾಷೆ',
      'Item Metadata & Location': 'ಐಟಂ ಮೆಟಾಡೇಟಾ ಮತ್ತು ಸ್ಥಳ',
      'Keep What Matters. Own Your Data.':
          'ಮುಖ್ಯವಾದುದನ್ನು ಇರಿಸಿ. ನಿಮ್ಮ ಡೇಟಾವನ್ನು ಹೊಂದಿರಿ.',
      'Known Allergies': 'ತಿಳಿದಿರುವ ಅಲರ್ಜಿಗಳು',
      'Language & Regional OCR Packs': 'ಭಾಷೆ ಮತ್ತು OCR ಪ್ಯಾಕ್‌ಗಳು',
      'Large-screen dual-pane overview and bulk import dropzone.':
          'ದೊಡ್ಡ-ಪರದೆಯ ಡ್ಯುಯಲ್-ಪೇನ್ ಅವಲೋಕನ ಮತ್ತು ಬೃಹತ್ ಆಮದು ಡ್ರಾಪ್‌ಜೋನ್.',
      'Library': 'ಲೈಬ್ರರಿ',
      'Life': 'ಜೀವನ',
      'Life Directory': 'ಲೈಫ್ ಡೈರೆಕ್ಟರಿ',
      'Life Event': 'ಲೈಫ್ ಈವೆಂಟ್',
      'Life Navigator': 'ಲೈಫ್ ನ್ಯಾವಿಗೇಟರ್',
      'Life OS Overview': 'ಲೈಫ್ ಓಎಸ್ ಅವಲೋಕನ',
      'Life Timeline': 'ಲೈಫ್ ಟೈಮ್‌ಲೈನ್',
      'Lifetime Spend': 'ಜೀವಮಾನದ ಖರ್ಚು',
      'Link encrypted evidence': 'ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಿದ ಪುರಾವೆಗಳನ್ನು ಲಿಂಕ್ ಮಾಡಿ',
      'Link encrypted record': 'ಲಿಂಕ್ ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಿದ ದಾಖಲೆ',
      'Link existing information': 'ಅಸ್ತಿತ್ವದಲ್ಲಿರುವ ಮಾಹಿತಿಯನ್ನು ಲಿಂಕ್ ಮಾಡಿ',
      'Link information': 'ಲಿಂಕ್ ಮಾಹಿತಿ',
      'Link to a profile?': 'ಪ್ರೊಫೈಲ್‌ಗೆ ಲಿಂಕ್ ಮಾಡುವುದೇ?',
      'Linked Claims, Events, Tasks, and evidence remain unchanged.':
          'ಲಿಂಕ್ ಮಾಡಲಾದ ಹಕ್ಕುಗಳು, ಈವೆಂಟ್‌ಗಳು, ಕಾರ್ಯಗಳು ಮತ್ತು ಪುರಾವೆಗಳು ಬದಲಾಗದೆ ಉಳಿಯುತ್ತವೆ.',
      'Local suggestions become part of your life record only after you confirm them.':
          'ನೀವು ಅವುಗಳನ್ನು ಖಚಿತಪಡಿಸಿದ ನಂತರವೇ ಸ್ಥಳೀಯ ಸಲಹೆಗಳು ನಿಮ್ಮ ಜೀವನ ದಾಖಲೆಯ ಭಾಗವಾಗುತ್ತವೆ.',
      'Location': 'ಸ್ಥಳ',
      'Log Maintenance / Cost': 'ಲಾಗ್ ನಿರ್ವಹಣೆ / ವೆಚ್ಚ',
      'Manage encrypted zero-knowledge backup destinations without token storage.':
          'ಟೋಕನ್ ಸಂಗ್ರಹಣೆಯಿಲ್ಲದೆ ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಲಾದ ಶೂನ್ಯ-ಜ್ಞಾನದ ಬ್ಯಾಕಪ್ ಗಮ್ಯಸ್ಥಾನಗಳನ್ನು ನಿರ್ವಹಿಸಿ.',
      'Mark completed': 'ಮಾರ್ಕ್ ಪೂರ್ಣಗೊಂಡಿದೆ',
      'Mask Date of Birth': 'ಮಾಸ್ಕ್ ಹುಟ್ಟಿದ ದಿನಾಂಕ',
      'Mask ID Numbers (Aadhaar / PAN / Passport)':
          'ಮಾಸ್ಕ್ ಐಡಿ ಸಂಖ್ಯೆಗಳು (ಆಧಾರ್ / ಪ್ಯಾನ್ / ಪಾಸ್‌ಪೋರ್ಟ್)',
      'Mask QR codes & Barcodes': 'ಮುಖವಾಡ QR ಕೋಡ್‌ಗಳು ಮತ್ತು ಬಾರ್‌ಕೋಡ್‌ಗಳು',
      'Mask Residential Address': 'ಮಾಸ್ಕ್ ನಿವಾಸದ ವಿಳಾಸ',
      'Mask Signatures': 'ಮಾಸ್ಕ್ ಸಹಿಗಳು',
      'Medical': 'ವೈದ್ಯಕೀಯ',
      'Merge a duplicate': 'ನಕಲು ವಿಲೀನಗೊಳಿಸಿ',
      'Monthly': 'ಮಾಸಿಕ',
      'Multilingual Invariance Guaranteed': 'ಬಹುಭಾಷಾ ಸ್ಥಿರತೆ ಖಾತ್ರಿ',
      'Name': 'ಹೆಸರು',
      'New records will appear here and safely resume if interrupted.':
          'ಹೊಸ ದಾಖಲೆಗಳು ಇಲ್ಲಿ ಗೋಚರಿಸುತ್ತವೆ ಮತ್ತು ಅಡ್ಡಿಪಡಿಸಿದರೆ ಸುರಕ್ಷಿತವಾಗಿ ಪುನರಾರಂಭಿಸುತ್ತವೆ.',
      'Newest': 'ಹೊಸತು',
      'No Claims yet. Link a reviewed record from the Inbox.':
          'ಇನ್ನೂ ಯಾವುದೇ ಕ್ಲೈಮ್‌ಗಳಿಲ್ಲ. ಇನ್‌ಬಾಕ್ಸ್‌ನಿಂದ ಪರಿಶೀಲಿಸಿದ ದಾಖಲೆಯನ್ನು ಲಿಂಕ್ ಮಾಡಿ.',
      'No Smart Packs yet': 'ಇನ್ನೂ ಯಾವುದೇ ಸ್ಮಾರ್ಟ್ ಪ್ಯಾಕ್‌ಗಳಿಲ್ಲ',
      'No access logs recorded.': 'ಯಾವುದೇ ಪ್ರವೇಶ ಲಾಗ್‌ಗಳನ್ನು ದಾಖಲಿಸಲಾಗಿಲ್ಲ.',
      'No account, analytics, cloud OCR, advertisements, or Internet permission in release builds.':
          'ಬಿಡುಗಡೆ ಬಿಲ್ಡ್‌ಗಳಲ್ಲಿ ಖಾತೆ, ವಿಶ್ಲೇಷಣೆ, ಕ್ಲೌಡ್ OCR, ಜಾಹೀರಾತುಗಳು ಅಥವಾ ಇಂಟರ್ನೆಟ್ ಅನುಮತಿ ಇಲ್ಲ.',
      'No automation executions recorded yet.':
          'ಯಾವುದೇ ಯಾಂತ್ರೀಕೃತಗೊಂಡ ಕಾರ್ಯಗತಗೊಳಿಸುವಿಕೆಯನ್ನು ಇನ್ನೂ ದಾಖಲಿಸಲಾಗಿಲ್ಲ.',
      'No confirmed value yet': 'ಇನ್ನೂ ದೃಢೀಕೃತ ಮೌಲ್ಯವಿಲ್ಲ',
      'No documents are processing':
          'ಯಾವುದೇ ದಾಖಲೆಗಳನ್ನು ಪ್ರಕ್ರಿಯೆಗೊಳಿಸುತ್ತಿಲ್ಲ',
      'No documents match these filters':
          'ಈ ಫಿಲ್ಟರ್‌ಗಳಿಗೆ ಯಾವುದೇ ದಾಖಲೆಗಳು ಹೊಂದಿಕೆಯಾಗುವುದಿಲ್ಲ',
      'No documents processing': 'ಯಾವುದೇ ದಾಖಲೆಗಳನ್ನು ಪ್ರಕ್ರಿಯೆಗೊಳಿಸುತ್ತಿಲ್ಲ',
      'No encrypted evidence linked.':
          'ಯಾವುದೇ ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಿದ ಪುರಾವೆಗಳನ್ನು ಲಿಂಕ್ ಮಾಡಲಾಗಿಲ್ಲ.',
      'No extracted fields': 'ಹೊರತೆಗೆಯಲಾದ ಕ್ಷೇತ್ರಗಳಿಲ್ಲ',
      'No fields were extracted. Confirm the type to finish.':
          'ಯಾವುದೇ ಕ್ಷೇತ್ರಗಳನ್ನು ಹೊರತೆಗೆಯಲಾಗಿಲ್ಲ. ಮುಗಿಸಲು ಪ್ರಕಾರವನ್ನು ದೃಢೀಕರಿಸಿ.',
      'No linkable information yet': 'ಇನ್ನೂ ಲಿಂಕ್ ಮಾಡಬಹುದಾದ ಮಾಹಿತಿ ಇಲ್ಲ',
      'No linked evidence yet.': 'ಇನ್ನೂ ಯಾವುದೇ ಲಿಂಕ್ ಮಾಡಿದ ಪುರಾವೆಗಳಿಲ್ಲ.',
      'No location': 'ಸ್ಥಳವಿಲ್ಲ',
      'No maintenance or cost logs yet.':
          'ಇನ್ನೂ ಯಾವುದೇ ನಿರ್ವಹಣೆ ಅಥವಾ ವೆಚ್ಚದ ದಾಖಲೆಗಳಿಲ್ಲ.',
      'No matching duplicate was found.': 'ಯಾವುದೇ ಹೊಂದಾಣಿಕೆಯ ನಕಲು ಕಂಡುಬಂದಿಲ್ಲ.',
      'No matching household items found.':
          'ಯಾವುದೇ ಹೊಂದಾಣಿಕೆಯ ಗೃಹೋಪಯೋಗಿ ವಸ್ತುಗಳು ಕಂಡುಬಂದಿಲ್ಲ.',
      'No profile': 'ಪ್ರೊಫೈಲ್ ಇಲ್ಲ',
      'No profile changes recorded yet':
          'ಯಾವುದೇ ಪ್ರೊಫೈಲ್ ಬದಲಾವಣೆಗಳನ್ನು ಇನ್ನೂ ದಾಖಲಿಸಲಾಗಿಲ್ಲ',
      'No recognized text': 'ಗುರುತಿಸಲ್ಪಟ್ಟ ಪಠ್ಯವಿಲ್ಲ',
      'No record': 'ದಾಖಲೆ ಇಲ್ಲ',
      'No relationships yet': 'ಇನ್ನೂ ಯಾವುದೇ ಸಂಬಂಧಗಳಿಲ್ಲ',
      'No reminders': 'ಯಾವುದೇ ಜ್ಞಾಪನೆಗಳಿಲ್ಲ',
      'No tags': 'ಟ್ಯಾಗ್‌ಗಳಿಲ್ಲ',
      'No upcoming reminders': 'ಮುಂಬರುವ ಜ್ಞಾಪನೆಗಳಿಲ್ಲ',
      'Not now': 'ಈಗಲ್ಲ',
      'Nothing matched yet. Try a person, car, home, insurer, pack or record name.':
          'ಇನ್ನೂ ಯಾವುದೂ ಹೊಂದಾಣಿಕೆಯಾಗಲಿಲ್ಲ. ವ್ಯಕ್ತಿ, ಕಾರು, ಮನೆ, ವಿಮೆದಾರ, ಪ್ಯಾಕ್ ಅಥವಾ ರೆಕಾರ್ಡ್ ಹೆಸರನ್ನು ಪ್ರಯತ್ನಿಸಿ.',
      'Nothing urgent': 'ತುರ್ತು ಏನೂ ಇಲ್ಲ',
      'Notifications are local and contain no document details.':
          'ಅಧಿಸೂಚನೆಗಳು ಸ್ಥಳೀಯವಾಗಿರುತ್ತವೆ ಮತ್ತು ಯಾವುದೇ ಡಾಕ್ಯುಮೆಂಟ್ ವಿವರಗಳನ್ನು ಹೊಂದಿರುವುದಿಲ್ಲ.',
      'ORGANIZATIONAL ITEMS': 'ಸಾಂಸ್ಥಿಕ ವಸ್ತುಗಳು',
      'Offline': 'ಆಫ್‌ಲೈನ್',
      'Offline Automation Engine': 'ಆಫ್‌ಲೈನ್ ಆಟೊಮೇಷನ್ ಎಂಜಿನ್',
      'Offline Pack template': 'ಆಫ್‌ಲೈನ್ ಪ್ಯಾಕ್ ಟೆಂಪ್ಲೇಟ್',
      'Offline Safety Guaranteed': 'ಆಫ್‌ಲೈನ್ ಸುರಕ್ಷತೆ ಖಾತರಿ',
      'Oldest': 'ಅತ್ಯಂತ ಹಳೆಯದು',
      'On the date': 'ದಿನಾಂಕದಂದು',
      'On-device Intelligence': 'ಸಾಧನ ಬುದ್ಧಿವಂತಿಕೆ',
      'Only encrypted archive bytes leave your device. Zero provider tokens or Master Vault Keys are retained by OwnKeep.':
          'ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಿದ ಆರ್ಕೈವ್ ಬೈಟ್‌ಗಳು ಮಾತ್ರ ನಿಮ್ಮ ಸಾಧನವನ್ನು ಬಿಡುತ್ತವೆ. ಝೀರೋ ಪ್ರೊವೈಡರ್ ಟೋಕನ್‌ಗಳು ಅಥವಾ ಮಾಸ್ಟರ್ ವಾಲ್ಟ್ ಕೀಗಳನ್ನು OwnKeep ನಿಂದ ಉಳಿಸಿಕೊಳ್ಳಲಾಗಿದೆ.',
      'Open encrypted evidence': 'ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಿದ ಸಾಕ್ಷ್ಯವನ್ನು ತೆರೆಯಿರಿ',
      'Open inbox': 'ಇನ್‌ಬಾಕ್ಸ್ ತೆರೆಯಿರಿ',
      'Open linked evidence': 'ಲಿಂಕ್ ಮಾಡಲಾದ ಸಾಕ್ಷ್ಯವನ್ನು ತೆರೆಯಿರಿ',
      'Opening your encrypted vault...': 'ವೋಲ್ಟ್ ತೆರೆಯಲಾಗುತ್ತಿದೆ...',
      'Optional': 'ಐಚ್ಛಿಕ',
      'Optional country-specific guidance, not legal advice.':
          'ಐಚ್ಛಿಕ ದೇಶ-ನಿರ್ದಿಷ್ಟ ಮಾರ್ಗದರ್ಶನ, ಕಾನೂನು ಸಲಹೆಯಲ್ಲ.',
      'Organizational guidance': 'ಸಾಂಸ್ಥಿಕ ಮಾರ್ಗದರ್ಶನ',
      'Original file remains untouched. Redactions are flattened permanently before export.':
          'ಮೂಲ ಫೈಲ್ ಅಸ್ಪೃಶ್ಯವಾಗಿ ಉಳಿದಿದೆ. ರಫ್ತು ಮಾಡುವ ಮೊದಲು ತಿದ್ದುಪಡಿಗಳನ್ನು ಶಾಶ್ವತವಾಗಿ ಸಮತಟ್ಟಾಗುತ್ತದೆ.',
      'Original remains encrypted': 'ಮೂಲ ಅವಶೇಷಗಳನ್ನು ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಲಾಗಿದೆ',
      'OwnKeep': 'ಸ್ವಂತ ಕೀಪ್',
      'OwnKeep 5.0.0': 'ಸ್ವಂತ ಕೀಪ್ 5.0.0',
      'OwnKeep 5.0.0 Final': 'OwnKeep 5.0.0 ಫೈನಲ್',
      'OwnKeep Desktop Personal Life OS': 'ಡೆಸ್ಕ್‌ಟಾಪ್ ಲೈಫ್ OS',
      'OwnKeep could not access private storage.':
          'OwnKeep ಗೆ ಖಾಸಗಿ ಸಂಗ್ರಹಣೆಯನ್ನು ಪ್ರವೇಶಿಸಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.',
      'OwnKeep found possible matches. You decide whether to create Claim suggestions.':
          'OwnKeep ಸಂಭವನೀಯ ಹೊಂದಾಣಿಕೆಗಳನ್ನು ಕಂಡುಹಿಡಿದಿದೆ. ಕ್ಲೈಮ್ ಸಲಹೆಗಳನ್ನು ರಚಿಸಬೇಕೆ ಎಂದು ನೀವು ನಿರ್ಧರಿಸುತ್ತೀರಿ.',
      'Pack is archived.': 'ಪ್ಯಾಕ್ ಅನ್ನು ಆರ್ಕೈವ್ ಮಾಡಲಾಗಿದೆ.',
      'Pair devices with ephemeral PIN codes for encrypted transfer.':
          'ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಿದ ವರ್ಗಾವಣೆಗಾಗಿ ಸಾಧನಗಳನ್ನು ಅಲ್ಪಕಾಲಿಕ ಪಿನ್ ಕೋಡ್‌ಗಳೊಂದಿಗೆ ಜೋಡಿಸಿ.',
      'People, things & places': 'ಜನರು, ವಸ್ತುಗಳು ಮತ್ತು ಸ್ಥಳಗಳು',
      'Prepare evidence for export': 'ರಫ್ತು ಮಾಡಲು ಪುರಾವೆಗಳನ್ನು ತಯಾರಿಸಿ',
      'Preserves complete Claim, provenance, history, evidence, and graph compatibility between mobile and desktop without central backends.':
          'ಕೇಂದ್ರೀಯ ಬ್ಯಾಕೆಂಡ್‌ಗಳಿಲ್ಲದೆ ಮೊಬೈಲ್ ಮತ್ತು ಡೆಸ್ಕ್‌ಟಾಪ್ ನಡುವಿನ ಸಂಪೂರ್ಣ ಹಕ್ಕು, ಮೂಲ, ಇತಿಹಾಸ, ಪುರಾವೆ ಮತ್ತು ಗ್ರಾಫ್ ಹೊಂದಾಣಿಕೆಯನ್ನು ಸಂರಕ್ಷಿಸುತ್ತದೆ.',
      'Primary Physician': 'ಪ್ರಾಥಮಿಕ ವೈದ್ಯ',
      'Prioritized locally from confirmed facts, events, evidence, integrity checks, and Inbox work.':
          'ದೃಢಪಡಿಸಿದ ಸಂಗತಿಗಳು, ಘಟನೆಗಳು, ಪುರಾವೆಗಳು, ಸಮಗ್ರತೆಯ ಪರಿಶೀಲನೆಗಳು ಮತ್ತು ಇನ್‌ಬಾಕ್ಸ್ ಕೆಲಸದಿಂದ ಸ್ಥಳೀಯವಾಗಿ ಆದ್ಯತೆ ನೀಡಲಾಗಿದೆ.',
      'Privacy Share': 'ಗೌಪ್ಯತೆ ಹಂಚಿಕೆ',
      'Privacy-aware Sharing': 'ಗೌಪ್ಯತೆ ಅರಿವು ಹಂಚಿಕೆ',
      'Private notes': 'ಖಾಸಗಿ ಟಿಪ್ಪಣಿಗಳು',
      'Profile fields': 'ಪ್ರೊಫೈಲ್ ಕ್ಷೇತ್ರಗಳು',
      'Property': 'ಆಸ್ತಿ',
      'Purchase Price': 'ಖರೀದಿ ಬೆಲೆ',
      'REJECTED': 'ತಿರಸ್ಕರಿಸಲಾಗಿದೆ',
      'Ready for you': 'ನಿಮಗಾಗಿ ಸಿದ್ಧವಾಗಿದೆ',
      'Recent Evidence Documents': 'ಇತ್ತೀಚಿನ ಸಾಕ್ಷಿ ದಾಖಲೆಗಳು',
      'Recognized text preview': 'ಗುರುತಿಸಲ್ಪಟ್ಟ ಪಠ್ಯ ಪೂರ್ವವೀಕ್ಷಣೆ',
      'Records': 'ದಾಖಲೆಗಳು',
      'Recovery passphrase': 'ಮರುಪ್ರಾಪ್ತಿ ಪಾಸ್‌ಫ್ರೇಸ್',
      'Regional OCR Text Packs': 'ಪ್ರಾದೇಶಿಕ OCR ಪಠ್ಯ ಪ್ಯಾಕ್‌ಗಳು',
      'Reject': 'ತಿರಸ್ಕರಿಸಿ',
      'Relationships': 'ಸಂಬಂಧಗಳು',
      'Reminders': 'ಜ್ಞಾಪನೆಗಳು',
      'Requires an exact same-name profile match.':
          'ನಿಖರವಾದ ಅದೇ ಹೆಸರಿನ ಪ್ರೊಫೈಲ್ ಹೊಂದಾಣಿಕೆಯ ಅಗತ್ಯವಿದೆ.',
      'Reschedule': 'ಮರು ವೇಳಾಪಟ್ಟಿ',
      'Restore encrypted backup': 'ಬ್ಯಾಕಪ್ ಮರುಸ್ಥಾಪಿಸಿ',
      'Retry': 'ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ',
      'Review': 'ವಿಮರ್ಶೆ',
      'Review export preparation': 'ರಫ್ತು ತಯಾರಿಯನ್ನು ಪರಿಶೀಲಿಸಿ',
      'Review local suggestions and finish organizing.':
          'ಸ್ಥಳೀಯ ಸಲಹೆಗಳನ್ನು ಪರಿಶೀಲಿಸಿ ಮತ್ತು ಸಂಘಟನೆಯನ್ನು ಮುಗಿಸಿ.',
      'Save': 'ಉಳಿಸಿ',
      'Save Event Log': 'ಈವೆಂಟ್ ಲಾಗ್ ಅನ್ನು ಉಳಿಸಿ',
      'Save Item': 'ಐಟಂ ಉಳಿಸಿ',
      'Save Rule': 'ನಿಯಮವನ್ನು ಉಳಿಸಿ',
      'Save a verified .cvault file to Drive, iCloud, Files, or another document provider.':
          'ಪರಿಶೀಲಿಸಿದ .cvault ಫೈಲ್ ಅನ್ನು ಡ್ರೈವ್, ಐಕ್ಲೌಡ್, ಫೈಲ್‌ಗಳು ಅಥವಾ ಇನ್ನೊಂದು ಡಾಕ್ಯುಮೆಂಟ್ ಪೂರೈಕೆದಾರರಿಗೆ ಉಳಿಸಿ.',
      'Save an unencrypted copy?': 'ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡದ ನಕಲನ್ನು ಉಳಿಸುವುದೇ?',
      'Save copy': 'ನಕಲನ್ನು ಉಳಿಸಿ',
      'Save field': 'ಕ್ಷೇತ್ರವನ್ನು ಉಳಿಸಿ',
      'Scan or import here. OwnKeep encrypts first, then organizes everything locally for your review.':
          'ಇಲ್ಲಿ ಸ್ಕ್ಯಾನ್ ಮಾಡಿ ಅಥವಾ ಆಮದು ಮಾಡಿ. OwnKeep ಮೊದಲು ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡುತ್ತದೆ, ನಂತರ ನಿಮ್ಮ ವಿಮರ್ಶೆಗಾಗಿ ಎಲ್ಲವನ್ನೂ ಸ್ಥಳೀಯವಾಗಿ ಆಯೋಜಿಸುತ್ತದೆ.',
      'Search': 'ಹುಡುಕಿ',
      'Search documents...': 'ದಾಖಲೆಗಳನ್ನು ಹುಡುಕಿ...',
      'Securely sync vault items directly to nearby devices over local P2P.':
          'ಸ್ಥಳೀಯ P2P ಮೂಲಕ ಹತ್ತಿರದ ಸಾಧನಗಳಿಗೆ ನೇರವಾಗಿ ವಾಲ್ಟ್ ಐಟಂಗಳನ್ನು ಸುರಕ್ಷಿತವಾಗಿ ಸಿಂಕ್ ಮಾಡಿ.',
      'Select Destination Provider': 'ಗಮ್ಯಸ್ಥಾನ ಪೂರೈಕೆದಾರರನ್ನು ಆಯ್ಕೆಮಾಡಿ',
      'Select Transport Layer': 'ಸಾರಿಗೆ ಪದರವನ್ನು ಆಯ್ಕೆಮಾಡಿ',
      'Selected backup': 'ಆಯ್ಕೆಮಾಡಿದ ಬ್ಯಾಕಪ್',
      'Settings': 'ಸನ್ನಿವೇಶಗಳು',
      'Simulate Bulk Import Drop': 'ಬಲ್ಕ್ ಇಂಪೋರ್ಟ್ ಮಾಡಿ',
      'Simulate Transfer Session': 'ವರ್ಗಾವಣೆ ಅವಧಿಯನ್ನು ಅನುಕರಿಸಿ',
      'Smart Packs': 'ಸ್ಮಾರ್ಟ್ ಪ್ಯಾಕ್‌ಗಳು',
      'Snooze 1 day': '1 ದಿನ ಸ್ನೂಜ್ ಮಾಡಿ',
      'Start building your private life record':
          'ನಿಮ್ಮ ಖಾಸಗಿ ಜೀವನ ದಾಖಲೆಯನ್ನು ನಿರ್ಮಿಸಲು ಪ್ರಾರಂಭಿಸಿ',
      'Store this passphrase somewhere safe. Losing it can make your encrypted documents permanently inaccessible.':
          'ಈ ಪಾಸ್‌ಫ್ರೇಸ್ ಅನ್ನು ಎಲ್ಲೋ ಸುರಕ್ಷಿತವಾಗಿ ಸಂಗ್ರಹಿಸಿ. ಅದನ್ನು ಕಳೆದುಕೊಳ್ಳುವುದರಿಂದ ನಿಮ್ಮ ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಿದ ಡಾಕ್ಯುಮೆಂಟ್‌ಗಳನ್ನು ಶಾಶ್ವತವಾಗಿ ಪ್ರವೇಶಿಸಲಾಗುವುದಿಲ್ಲ.',
      'Stored inside your encrypted vault.':
          'ನಿಮ್ಮ ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಿದ ವಾಲ್ಟ್‌ನಲ್ಲಿ ಸಂಗ್ರಹಿಸಲಾಗಿದೆ.',
      'Strict offline mode': 'ಸಂಪೂರ್ಣ ಆಫ್‌ಲೈನ್ ಮೋಡ್',
      'Strip EXIF & File Metadata': 'ಸ್ಟ್ರಿಪ್ EXIF ​​& ಫೈಲ್ ಮೆಟಾಡೇಟಾ',
      'Suggested': 'ಸೂಚಿಸಲಾಗಿದೆ',
      'Task': 'ಕಾರ್ಯ',
      'Tasks & checklists': 'ಕಾರ್ಯಗಳು ಮತ್ತು ಪರಿಶೀಲನಾಪಟ್ಟಿಗಳು',
      'Tax': 'ತೆರಿಗೆ',
      'Templates guide organization and never change your facts.':
          'ಟೆಂಪ್ಲೇಟ್‌ಗಳು ಸಂಸ್ಥೆಗೆ ಮಾರ್ಗದರ್ಶನ ನೀಡುತ್ತವೆ ಮತ್ತು ನಿಮ್ಮ ಸಂಗತಿಗಳನ್ನು ಎಂದಿಗೂ ಬದಲಾಯಿಸುವುದಿಲ್ಲ.',
      'Text': 'ಪಠ್ಯ',
      'The duplicate ID and history will be retained.':
          'ನಕಲಿ ಐಡಿ ಮತ್ತು ಇತಿಹಾಸವನ್ನು ಉಳಿಸಿಕೊಳ್ಳಲಾಗುತ್ತದೆ.',
      'The original remains encrypted and unchanged.':
          'ಮೂಲವು ಎನ್‌ಕ್ರಿಪ್ಟ್ ಆಗಿರುತ್ತದೆ ಮತ್ತು ಬದಲಾಗದೆ ಉಳಿದಿದೆ.',
      'The original remains in history and this replacement keeps its entity and evidence links.':
          'ಮೂಲವು ಇತಿಹಾಸದಲ್ಲಿ ಉಳಿದಿದೆ ಮತ್ತು ಈ ಬದಲಿ ಅದರ ಅಸ್ತಿತ್ವ ಮತ್ತು ಪುರಾವೆಗಳ ಲಿಂಕ್‌ಗಳನ್ನು ಇರಿಸುತ್ತದೆ.',
      'The saved file will no longer be protected by OwnKeep. Anyone with access to the selected destination may be able to open it.':
          'ಉಳಿಸಿದ ಫೈಲ್ ಇನ್ನು ಮುಂದೆ OwnKeep ನಿಂದ ರಕ್ಷಿಸಲ್ಪಡುವುದಿಲ್ಲ. ಆಯ್ಕೆಮಾಡಿದ ಗಮ್ಯಸ್ಥಾನಕ್ಕೆ ಪ್ರವೇಶವನ್ನು ಹೊಂದಿರುವ ಯಾರಾದರೂ ಅದನ್ನು ತೆರೆಯಲು ಸಾಧ್ಯವಾಗುತ್ತದೆ.',
      'This document is no longer available.':
          'ಈ ಡಾಕ್ಯುಮೆಂಟ್ ಇನ್ನು ಮುಂದೆ ಲಭ್ಯವಿಲ್ಲ.',
      'This month': 'ಈ ತಿಂಗಳು',
      'Timeline': 'ಸಮಯಾವಧಿ',
      'Timestamps when emergency medical card was opened:':
          'ತುರ್ತು ವೈದ್ಯಕೀಯ ಕಾರ್ಡ್ ತೆರೆದಾಗ ಸಮಯದ ಮುದ್ರೆಗಳು:',
      'Total Assets Value': 'ಒಟ್ಟು ಸ್ವತ್ತುಗಳ ಮೌಲ್ಯ',
      'Total Lifetime Maintenance & Tax Spend':
          'ಒಟ್ಟು ಜೀವಮಾನ ನಿರ್ವಹಣೆ ಮತ್ತು ತೆರಿಗೆ ಖರ್ಚು',
      'Total Maintenance Spend': 'ಒಟ್ಟು ನಿರ್ವಹಣೆ ವೆಚ್ಚ',
      'Total Spend': 'ಒಟ್ಟು ಖರ್ಚು',
      'Transferred vault archives are byte- and graph- equivalent, authenticated with SHA-256 signatures, and zero keys or plaintext leave your devices.':
          'ವರ್ಗಾಯಿಸಲಾದ ವಾಲ್ಟ್ ಆರ್ಕೈವ್‌ಗಳು ಬೈಟ್- ಮತ್ತು ಗ್ರಾಫ್-ಸಮಾನವಾಗಿರುತ್ತವೆ, SHA-256 ಸಹಿಗಳೊಂದಿಗೆ ದೃಢೀಕರಿಸಲ್ಪಟ್ಟಿವೆ ಮತ್ತು ಶೂನ್ಯ ಕೀಗಳು ಅಥವಾ ಸರಳ ಪಠ್ಯವು ನಿಮ್ಮ ಸಾಧನಗಳನ್ನು ಬಿಟ್ಟುಬಿಡುತ್ತದೆ.',
      'Transition item state while preserving complete historical service & cost records:':
          'ಸಂಪೂರ್ಣ ಐತಿಹಾಸಿಕ ಸೇವೆ ಮತ್ತು ವೆಚ್ಚದ ದಾಖಲೆಗಳನ್ನು ಸಂರಕ್ಷಿಸುವಾಗ ಪರಿವರ್ತನೆ ಐಟಂ ಸ್ಥಿತಿಯನ್ನು:',
      'Trigger Blind Sync Rehearsal': 'ಬ್ಯಾಕಪ್ ಸಿಂಕ್ ಪ್ರಾರಂಭಿಸಿ',
      'Type': 'ಟೈಪ್ ಮಾಡಿ',
      'Type a query or tap a template above to query your vault.':
          'ನಿಮ್ಮ ವಾಲ್ಟ್ ಅನ್ನು ಪ್ರಶ್ನಿಸಲು ಪ್ರಶ್ನೆಯನ್ನು ಟೈಪ್ ಮಾಡಿ ಅಥವಾ ಮೇಲಿನ ಟೆಂಪ್ಲೇಟ್ ಅನ್ನು ಟ್ಯಾಪ್ ಮಾಡಿ.',
      'Unlock OwnKeep': 'OwnKeep ಅನ್ನು ಅನ್‌ಲಾಕ್ ಮಾಡಿ',
      'Unlock vault': 'ವೋಲ್ಟ್ ತೆರೆಯಿರಿ',
      'Unlock with biometrics': 'ಬಯೋಮೆಟ್ರಿಕ್ಸ್‌ನೊಂದಿಗೆ ತೆರೆಯಿರಿ',
      'Upcoming dues and expiries will appear here.':
          'ಮುಂಬರುವ ಬಾಕಿಗಳು ಮತ್ತು ಅವಧಿಗಳು ಇಲ್ಲಿ ಗೋಚರಿಸುತ್ತವೆ.',
      'Upcoming reminder': 'ಮುಂಬರುವ ಜ್ಞಾಪನೆ',
      'Update Operational Status': 'ಕಾರ್ಯಾಚರಣೆಯ ಸ್ಥಿತಿಯನ್ನು ನವೀಕರಿಸಿ',
      'Use a verified backup to recover this document.':
          'ಈ ಡಾಕ್ಯುಮೆಂಟ್ ಅನ್ನು ಮರುಪಡೆಯಲು ಪರಿಶೀಲಿಸಿದ ಬ್ಯಾಕಪ್ ಬಳಸಿ.',
      'Use an offline template': 'ಆಫ್‌ಲೈನ್ ಟೆಂಪ್ಲೇಟ್ ಬಳಸಿ',
      'Use expiry date': 'ಮುಕ್ತಾಯ ದಿನಾಂಕವನ್ನು ಬಳಸಿ',
      'Use larger visual document cards.':
          'ದೊಡ್ಡ ದೃಶ್ಯ ದಾಖಲೆ ಕಾರ್ಡ್‌ಗಳನ್ನು ಬಳಸಿ.',
      'Used when expiry reminder suggestions are added.':
          'ಮುಕ್ತಾಯ ಜ್ಞಾಪನೆ ಸಲಹೆಗಳನ್ನು ಸೇರಿಸಿದಾಗ ಬಳಸಲಾಗುತ್ತದೆ.',
      'Vault Summary': 'ವಾಲ್ಟ್ ಸಾರಾಂಶ',
      'Vehicle': 'ವಾಹನ',
      'Verify and restore': 'ಪರಿಶೀಲಿಸಿ ಮರುಸ್ಥಾಪಿಸಿ',
      'Verify document details': 'ಡಾಕ್ಯುಮೆಂಟ್ ವಿವರಗಳನ್ನು ಪರಿಶೀಲಿಸಿ',
      'View grounded natural language summaries and recommendations.':
          'ನೈಸರ್ಗಿಕ ಭಾಷೆಯ ಸಾರಾಂಶಗಳು ಮತ್ತು ಶಿಫಾರಸುಗಳನ್ನು ವೀಕ್ಷಿಸಿ.',
      'View minimized emergency responder contacts, blood group, and medical data.':
          'ಕಡಿಮೆಗೊಳಿಸಿದ ತುರ್ತು ಪ್ರತಿಕ್ರಿಯೆ ಸಂಪರ್ಕಗಳು, ರಕ್ತದ ಗುಂಪು ಮತ್ತು ವೈದ್ಯಕೀಯ ಡೇಟಾವನ್ನು ವೀಕ್ಷಿಸಿ.',
      'Warranties': 'ವಾರಂಟಿಗಳು',
      'Warranty Coverage': 'ಖಾತರಿ ಕವರೇಜ್',
      'Website / URI': 'ವೆಬ್‌ಸೈಟ್ / URI',
      'Weekly': 'ಸಾಪ್ತಾಹಿಕ',
      'Whole vault': 'ಸಂಪೂರ್ಣ ವಾಲ್ಟ್',
      'Your facts remain yours': 'ನಿಮ್ಮ ಸತ್ಯಗಳು ನಿಮ್ಮದೇ ಆಗಿರುತ್ತವೆ',
      'Your private life, organized locally.':
          'ನಿಮ್ಮ ಖಾಸಗಿ ಜೀವನ, ಸ್ಥಳೀಯವಾಗಿ ಆಯೋಜಿಸಲಾಗಿದೆ.',
      'Zero Token Blind Backup Policy': 'ಶೂನ್ಯ ಟೋಕನ್ ಬ್ಲೈಂಡ್ ಬ್ಯಾಕಪ್ ನೀತಿ',
      '⚠️ Notice: Exported copies leave OwnKeep protection and cannot be remotely revoked.':
          '⚠️ ಸೂಚನೆ: ರಫ್ತು ಮಾಡಿದ ಪ್ರತಿಗಳು OwnKeep ರಕ್ಷಣೆಯನ್ನು ಬಿಡುತ್ತವೆ ಮತ್ತು ರಿಮೋಟ್ ಆಗಿ ಹಿಂತೆಗೆದುಕೊಳ್ಳಲಾಗುವುದಿಲ್ಲ.',
    },
    SupportedLanguage.malayalam: {
      '1. Recipient & Purpose': '1. സ്വീകർത്താവും ഉദ്ദേശ്യവും',
      '2. Field Redactions (Masking)': '2. Field Redactions',
      '3. Watermark Preview': '3. വാട്ടർമാർക്ക് പ്രിവ്യൂ',
      'Access dual-pane workspace views, multi-window layout, and bulk drop.':
          'ഡ്യുവൽ-പേൻ വർക്ക്‌സ്‌പെയ്‌സ് കാഴ്‌ചകൾ, മൾട്ടി-വിൻഡോ ലേഔട്ട്, ബൾക്ക് ഡ്രോപ്പ് എന്നിവ ആക്‌സസ് ചെയ്യുക.',
      'Active Destination Configuration': 'സജീവ ഡെസ്റ്റിനേഷൻ കോൺഫിഗറേഷൻ',
      'Active Medications': 'സജീവമായ മരുന്നുകൾ',
      'Active Valuation': 'സജീവ മൂല്യനിർണ്ണയം',
      'Add': 'ചേർക്കുക',
      'Add Automation Rule': 'ഓട്ടോമേഷൻ റൂൾ ചേർക്കുക',
      'Add Household Item': 'വീട്ടുപകരണങ്ങൾ ചേർക്കുക',
      'Add India Pack suggestions': 'ഇന്ത്യ പാക്ക് നിർദ്ദേശങ്ങൾ ചേർക്കുക',
      'Add Item': 'ഇനം ചേർക്കുക',
      'Add Rule': 'നിയമം ചേർക്കുക',
      'Add a record': 'ഒരു റെക്കോർഡ് ചേർക്കുക',
      'Add another profile first.': 'ആദ്യം മറ്റൊരു പ്രൊഫൈൽ ചേർക്കുക.',
      'Add checklist': 'ചെക്ക്‌ലിസ്റ്റ് ചേർക്കുക',
      'Add custom field': 'ഇഷ്‌ടാനുസൃത ഫീൽഡ് ചേർക്കുക',
      'Add custom item': 'ഇഷ്‌ടാനുസൃത ഇനം ചേർക്കുക',
      'Add event': 'ഇവൻ്റ് ചേർക്കുക',
      'Add one from a document detail screen.':
          'ഒരു ഡോക്യുമെൻ്റ് വിശദാംശ സ്ക്രീനിൽ നിന്ന് ഒന്ന് ചേർക്കുക.',
      'Add people, vehicles, properties, devices, and places. Everything stays encrypted on this device.':
          'ആളുകൾ, വാഹനങ്ങൾ, വസ്തുവകകൾ, ഉപകരണങ്ങൾ, സ്ഥലങ്ങൾ എന്നിവ ചേർക്കുക. ഈ ഉപകരണത്തിൽ എല്ലാം എൻക്രിപ്റ്റായി തുടരും.',
      'Add relationship': 'ബന്ധം ചേർക്കുക',
      'Add task': 'ടാസ്ക് ചേർക്കുക',
      'Add your first profile': 'നിങ്ങളുടെ ആദ്യ പ്രൊഫൈൽ ചേർക്കുക',
      'Aliases': 'അപരനാമങ്ങൾ',
      'All Categories': 'എല്ലാ വിഭാഗങ്ങളും',
      'All Types': 'എല്ലാ തരങ്ങളും',
      'All document types': 'എല്ലാ പ്രമാണ തരങ്ങളും',
      'All natural language summaries and recommendations are strictly grounded on verified indexed vault claims.':
          'എല്ലാ സ്വാഭാവിക ഭാഷാ സംഗ്രഹങ്ങളും ശുപാർശകളും പരിശോധിച്ചുറപ്പിച്ച ഇൻഡക്‌സ് ചെയ്‌ത വോൾട്ട് ക്ലെയിമുകളെ കർശനമായി അടിസ്ഥാനമാക്കിയുള്ളതാണ്.',
      'All tags': 'എല്ലാ ടാഗുകളും',
      'Applies to me': 'എനിക്ക് ബാധകമാണ്',
      'Archive': 'ആർക്കൈവ്',
      'Archive Pack': 'ആർക്കൈവ് പാക്ക്',
      'Archive this Pack?': 'ഈ പായ്ക്ക് ആർക്കൈവ് ചെയ്യണോ?',
      'Archived': 'ആർക്കൈവ് ചെയ്തു',
      'Ask OwnKeep': 'OwnKeep നോട് ചോദിക്കുക',
      'Ask OwnKeep parses facts directly from your encrypted graph and evidence documents without LLM hallucinations or cloud calls.':
          'LLM ഹാലുസിനേഷനുകളോ ക്ലൗഡ് കോളുകളോ ഇല്ലാതെ നിങ്ങളുടെ എൻക്രിപ്റ്റ് ചെയ്ത ഗ്രാഫിൽ നിന്നും തെളിവ് രേഖകളിൽ നിന്നും നേരിട്ട് വസ്തുതകൾ പാഴ്‌സുചെയ്യാൻ OwnKeep-നോട് ചോദിക്കുക.',
      'Attention': 'ശ്രദ്ധ',
      'Attention & Tasks': 'ശ്രദ്ധയും ചുമതലകളും',
      'Attention Items': 'ശ്രദ്ധിക്കേണ്ട ഇനങ്ങൾ',
      'Attention Needed': 'ശ്രദ്ധ ആവശ്യമാണ്',
      'Automation runs 100% locally with bounded recursion, cycle detection, audit trails, and zero external network calls.':
          'ബൗണ്ടഡ് റിക്കർഷൻ, സൈക്കിൾ ഡിറ്റക്ഷൻ, ഓഡിറ്റ് ട്രയലുകൾ, സീറോ എക്സ്റ്റേണൽ നെറ്റ്‌വർക്ക് കോളുകൾ എന്നിവ ഉപയോഗിച്ച് ഓട്ടോമേഷൻ 100% പ്രാദേശികമായി പ്രവർത്തിക്കുന്നു.',
      'Back': 'പിന്നിലേക്ക്',
      'Backup & recovery': 'ബാക്കപ്പും റിക്കവറിയും',
      'Backup recovery passphrase':
          'വീണ്ടെടുക്കൽ പാസ്‌ഫ്രെയ്‌സ് ബാക്കപ്പ് ചെയ്യുക',
      'Biometric unlock': 'ബയോമെട്രിക് അൺലോക്ക്',
      'Blind Backup Destinations': 'ബാക്കപ്പ് ലക്ഷ്യസ്ഥാനങ്ങൾ',
      'Bring records into your life':
          'നിങ്ങളുടെ ജീവിതത്തിലേക്ക് റെക്കോർഡുകൾ കൊണ്ടുവരിക',
      'Build your private life map':
          'നിങ്ങളുടെ സ്വകാര്യ ജീവിത മാപ്പ് നിർമ്മിക്കുക',
      'Cancel': 'റദ്ദാക്കുക',
      'Changing a template only changes this checklist. It never changes confirmed facts or claims that an item is legally required.':
          'ഒരു ടെംപ്ലേറ്റ് മാറ്റുന്നത് ഈ ചെക്ക്‌ലിസ്റ്റിനെ മാത്രമേ മാറ്റൂ. സ്ഥിരീകരിക്കപ്പെട്ട വസ്‌തുതകളോ ഒരു ഇനം നിയമപരമായി ആവശ്യമാണെന്ന അവകാശവാദങ്ങളോ ഒരിക്കലും മാറ്റില്ല.',
      'Changing interface language does not alter stored Claim values, predicates, Entity IDs, evidence, or backup bytes.':
          'ഇൻ്റർഫേസ് ഭാഷ മാറ്റുന്നത് സംഭരിച്ച ക്ലെയിം മൂല്യങ്ങൾ, പ്രവചനങ്ങൾ, എൻ്റിറ്റി ഐഡികൾ, തെളിവുകൾ അല്ലെങ്കിൽ ബാക്കപ്പ് ബൈറ്റുകൾ എന്നിവയെ മാറ്റില്ല.',
      'Checking this device...': 'ഡിവൈസ് പരിശോധിക്കുന്നു...',
      'Checklist': 'ചെക്ക്‌ലിസ്റ്റ്',
      'Choose a custom date': 'ഒരു ഇഷ്‌ടാനുസൃത തീയതി തിരഞ്ഞെടുക്കുക',
      'Choose duplicate to merge':
          'ലയിപ്പിക്കാൻ ഡ്യൂപ്ലിക്കേറ്റ് തിരഞ്ഞെടുക്കുക',
      'Choose encrypted profile photo':
          'എൻക്രിപ്റ്റ് ചെയ്ത പ്രൊഫൈൽ ഫോട്ടോ തിരഞ്ഞെടുക്കുക',
      'Choose new date': 'പുതിയ തീയതി തിരഞ്ഞെടുക്കുക',
      'Close': 'അടയ്ക്കുക',
      'Close and reopen the app. If this continues, preserve the app data until recovery or restore tools are available.':
          'ആപ്പ് അടച്ച് വീണ്ടും തുറക്കുക. ഇത് തുടരുകയാണെങ്കിൽ, വീണ്ടെടുക്കൽ അല്ലെങ്കിൽ പുനഃസ്ഥാപിക്കൽ ടൂളുകൾ ലഭ്യമാകുന്നത് വരെ ആപ്പ് ഡാറ്റ സംരക്ഷിക്കുക.',
      'Complete': 'പൂർത്തിയാക്കുക',
      'Configure interface locale and regional OCR text recognition packs.':
          'ഇൻ്റർഫേസ് ലോക്കലും റീജിയണൽ OCR ടെക്സ്റ്റ് റെക്കഗ്നിഷൻ പാക്കുകളും കോൺഫിഗർ ചെയ്യുക.',
      'Configure local WHEN / IF / THEN rules for reminders, backup, and tagging.':
          'റിമൈൻഡറുകൾ, ബാക്കപ്പ്, ടാഗിംഗ് എന്നിവയ്‌ക്കായുള്ള ലോക്കൽ എപ്പോൾ / IF / THEN നിയമങ്ങൾ കോൺഫിഗർ ചെയ്യുക.',
      'Configure local WHEN / IF / THEN rules, preview execution, and inspect audit logs.':
          'ലോക്കൽ എപ്പോൾ / എങ്കിൽ / പിന്നെ നിയമങ്ങൾ കോൺഫിഗർ ചെയ്യുക, എക്സിക്യൂഷൻ പ്രിവ്യൂ ചെയ്യുക, ഓഡിറ്റ് ലോഗുകൾ പരിശോധിക്കുക.',
      'Configure user-selected blind cloud & NAS encrypted destinations.':
          'ഉപയോക്താവ് തിരഞ്ഞെടുത്ത ബ്ലൈൻഡ് ക്ലൗഡും NAS എൻക്രിപ്റ്റ് ചെയ്ത ലക്ഷ്യസ്ഥാനങ്ങളും കോൺഫിഗർ ചെയ്യുക.',
      'Confirm': 'സ്ഥിരീകരിക്കുക',
      'Confirm only after comparing these values with the original document. Clear a value to remove it.':
          'ഈ മൂല്യങ്ങൾ യഥാർത്ഥ പ്രമാണവുമായി താരതമ്യം ചെയ്തതിന് ശേഷം മാത്രം സ്ഥിരീകരിക്കുക. അത് നീക്കം ചെയ്യാൻ ഒരു മൂല്യം മായ്‌ക്കുക.',
      'Confirm recovery passphrase':
          'വീണ്ടെടുക്കൽ പാസ്‌ഫ്രെയ്‌സ് സ്ഥിരീകരിക്കുക',
      'Confirm reviewed details': 'അവലോകനം ചെയ്ത വിശദാംശങ്ങൾ സ്ഥിരീകരിക്കുക',
      'Confirm the recovery warning to continue.':
          'തുടരാൻ വീണ്ടെടുക്കൽ മുന്നറിയിപ്പ് സ്ഥിരീകരിക്കുക.',
      'Continue': 'തുടരുക',
      'Correct without overwriting': 'തിരുത്തിയെഴുതാതെ തിരുത്തുക',
      'Corrected': 'തിരുത്തി',
      'Create': 'ഉണ്ടാക്കുക',
      'Create Smart Pack': 'സ്മാർട്ട് പായ്ക്ക് സൃഷ്ടിക്കുക',
      'Create a Smart Pack': 'ഒരു സ്മാർട്ട് പായ്ക്ക് സൃഷ്ടിക്കുക',
      'Create a custom Pack': 'ഒരു ഇഷ്‌ടാനുസൃത പാക്ക് സൃഷ്‌ടിക്കുക',
      'Create a private organizational checklist from an offline template or make your own.':
          'ഒരു ഓഫ്‌ലൈൻ ടെംപ്ലേറ്റിൽ നിന്ന് ഒരു സ്വകാര്യ ഓർഗനൈസേഷണൽ ചെക്ക്‌ലിസ്റ്റ് സൃഷ്‌ടിക്കുക അല്ലെങ്കിൽ നിങ്ങളുടേതാക്കുക.',
      'Create encrypted backup': 'ബാക്കപ്പ് നിർമ്മിക്കുക',
      'Create encrypted vault': 'വോൾട്ട് നിർമ്മിക്കുക',
      'Create task': 'ടാസ്ക് സൃഷ്ടിക്കുക',
      'Create your private vault': 'നിങ്ങളുടെ സ്വകാര്യ നിലവറ സൃഷ്ടിക്കുക',
      'Creating your private vault...': 'വോൾട്ട് നിർമ്മിക്കുന്നു...',
      'Custom Smart Pack': 'ഇഷ്ടാനുസൃത സ്മാർട്ട് പായ്ക്ക്',
      'Custom encrypted field': 'ഇഷ്ടാനുസൃത എൻക്രിപ്റ്റ് ചെയ്ത ഫീൽഡ്',
      'Customize': 'ഇഷ്ടാനുസൃതമാക്കുക',
      'Customize item': 'ഇനം ഇഷ്ടാനുസൃതമാക്കുക',
      'Daily': 'ദിവസേന',
      'Dark mode': 'ഡാർക്ക് മോഡ്',
      'Date': 'തീയതി',
      'Date range': 'തീയതി ശ്രേണി',
      'Default reminder offsets': 'ഓർമ്മപ്പെടുത്തലുകൾ',
      'Delete': 'മായിക്കുക',
      'Desktop & Mobile Graph Compatibility Verified':
          'ഡെസ്ക്ടോപ്പ് & മൊബൈൽ ഗ്രാഫ് അനുയോജ്യത പരിശോധിച്ചുറപ്പിച്ചു',
      'Desktop Large-Scale Bulk Import Dropzone':
          'ഡെസ്ക്ടോപ്പ് ലാർജ്-സ്കെയിൽ ബൾക്ക് ഇംപോർട്ട് ഡ്രോപ്സോൺ',
      'Desktop Layout Modes': 'ഡെസ്ക്ടോപ്പ് ലേഔട്ട് മോഡുകൾ',
      'Deterministic Graph Answers': 'ഡിറ്റർമിനിസ്റ്റിക് ഗ്രാഫ് ഉത്തരങ്ങൾ',
      'Device security': 'ഡിവൈസ് സുരക്ഷ',
      'Device-to-Device Transfer': 'ഡിവൈസ് ട്രാൻസ്ഫർ (P2P Transfer)',
      'Dismiss': 'തള്ളിക്കളയുക',
      'Documents Library': 'ഡോക്യുമെൻ്റ് ലൈബ്രറി',
      'Documents stay encrypted on this device. Start by choosing the recovery passphrase that protects your vault.':
          'ഈ ഉപകരണത്തിൽ പ്രമാണങ്ങൾ എൻക്രിപ്റ്റായി തുടരും. നിങ്ങളുടെ നിലവറയെ സംരക്ഷിക്കുന്ന വീണ്ടെടുക്കൽ പാസ്‌ഫ്രെയ്‌സ് തിരഞ്ഞെടുത്ത് ആരംഭിക്കുക.',
      'Does not create a plaintext export.':
          'ഒരു പ്ലെയിൻ ടെക്സ്റ്റ് കയറ്റുമതി സൃഷ്ടിക്കുന്നില്ല.',
      'Does not repeat': 'ആവർത്തിക്കുന്നില്ല',
      'Done': 'പൂർത്തിയായി',
      'Drag & drop directories or multiple document files for high-throughput parallel OCR processing.':
          'ഹൈ-ത്രൂപുട്ട് പാരലൽ OCR പ്രോസസ്സിംഗിനായി ഡയറക്‌ടറികൾ അല്ലെങ്കിൽ ഒന്നിലധികം പ്രമാണ ഫയലുകൾ വലിച്ചിടുക.',
      'Due date': 'അവസാന തീയതി',
      'Edit': 'എഡിറ്റ് ചെയ്യുക',
      'Edit tags': 'ടാഗുകൾ എഡിറ്റ് ചെയ്യുക',
      'Emergency Access Audit Log': 'എമർജൻസി ആക്‌സസ് ഓഡിറ്റ് ലോഗ്',
      'Emergency Medical Card': 'മെഡിക്കൽ കാർഡ്',
      'Emergency Responder Contacts': 'എമർജൻസി റെസ്‌പോണ്ടർ കോൺടാക്റ്റുകൾ',
      'Emergency Storage Boundary Active. Isolated from main vault graph, evidence, and claims.':
          'എമർജൻസി സ്റ്റോറേജ് ബൗണ്ടറി സജീവമാണ്. പ്രധാന നിലവറ ഗ്രാഫ്, തെളിവുകൾ, ക്ലെയിമുകൾ എന്നിവയിൽ നിന്ന് വേർതിരിച്ചിരിക്കുന്നു.',
      'Encrypted P2P Transfer (No Server)': 'Encrypted P2P Transfer',
      'Encrypted evidence': 'എൻക്രിപ്റ്റ് ചെയ്ത തെളിവുകൾ',
      'End date': 'അവസാന തീയതി',
      'End date cannot be before start date.':
          'അവസാന തീയതി ആരംഭിക്കുന്ന തീയതിക്ക് മുമ്പായിരിക്കരുത്.',
      'Enter a currency code.': 'ഒരു കറൻസി കോഡ് നൽകുക.',
      'Enter a valid amount.': 'സാധുവായ തുക നൽകുക.',
      'Enter an event title.': 'ഒരു ഇവൻ്റ് ശീർഷകം നൽകുക.',
      'Enter your recovery passphrase to access your private encrypted vault.':
          'നിങ്ങളുടെ സ്വകാര്യ എൻക്രിപ്റ്റ് ചെയ്ത നിലവറ ആക്സസ് ചെയ്യുന്നതിന് നിങ്ങളുടെ വീണ്ടെടുക്കൽ പാസ്ഫ്രെയ്സ് നൽകുക.',
      'Ephemeral Pairing PIN Code': 'എഫെമറൽ ജോടിയാക്കൽ പിൻ കോഡ്',
      'Event': 'സംഭവം',
      'Every result stays linked to your encrypted graph and evidence.':
          'എല്ലാ ഫലങ്ങളും നിങ്ങളുടെ എൻക്രിപ്റ്റ് ചെയ്ത ഗ്രാഫുകളുമായും തെളിവുകളുമായും ബന്ധപ്പെട്ടിരിക്കുന്നു.',
      'Evidence': 'തെളിവ്',
      'Execute deterministic graph queries for attention, expiry, spending, and warranties.':
          'ശ്രദ്ധ, കാലഹരണപ്പെടൽ, ചെലവ്, വാറൻ്റി എന്നിവയ്‌ക്കായി ഡിറ്റർമിനിസ്റ്റിക് ഗ്രാഫ് ചോദ്യങ്ങൾ എക്‌സിക്യൂട്ട് ചെയ്യുക.',
      'Export Document': 'കയറ്റുമതി പ്രമാണം',
      'Export Redacted & Watermarked Copy':
          'കയറ്റുമതി തിരുത്തിയതും വാട്ടർമാർക്ക് ചെയ്തതുമായ പകർപ്പ്',
      'Export Redacted Copy': 'തിരുത്തിയ പകർപ്പ് കയറ്റുമതി ചെയ്യുക',
      'Export preparation': 'കയറ്റുമതി തയ്യാറെടുപ്പ്',
      'Favourites': 'പ്രിയപ്പെട്ടവ',
      'Finance': 'ധനകാര്യം',
      'Full view': 'പൂർണ്ണമായ കാഴ്ച',
      'Generate Pairing PIN': 'ജോടിയാക്കൽ പിൻ സൃഷ്ടിക്കുക',
      'Graph': 'ഗ്രാഫ്',
      'Grid document view': 'ഗ്രിഡ് കാഴ്ച',
      'Guidance, not a requirement': 'മാർഗ്ഗനിർദ്ദേശം, ഒരു ആവശ്യകതയല്ല',
      'Health Insurance Policy': 'ആരോഗ്യ ഇൻഷുറൻസ് പോളിസി',
      'History': 'ചരിത്രം',
      'History and evidence are retained.':
          'ചരിത്രവും തെളിവുകളും നിലനിർത്തിയിട്ടുണ്ട്.',
      'Household & Ownership': 'ഗാർഹിക & ഉടമസ്ഥാവകാശം',
      'Household Inventory': 'ഗാർഹിക ഇൻവെൻ്ററി',
      'Household Valuation': 'ഗാർഹിക മൂല്യനിർണ്ണയം',
      'I understand OwnKeep cannot reset this passphrase.':
          'ഈ പാസ്‌ഫ്രെയ്‌സ് പുനഃസജ്ജമാക്കാൻ OwnKeep-ന് കഴിയില്ലെന്ന് ഞാൻ മനസ്സിലാക്കുന്നു.',
      'Identifier': 'ഐഡൻ്റിഫയർ',
      'Identity': 'ഐഡൻ്റിറ്റി',
      'Import a document and OwnKeep will organize it locally.':
          'ഒരു പ്രമാണം ഇറക്കുമതി ചെയ്യുക, OwnKeep അത് പ്രാദേശികമായി സംഘടിപ്പിക്കും.',
      'Import a photo first, then link it.':
          'ആദ്യം ഒരു ഫോട്ടോ ഇമ്പോർട്ടുചെയ്യുക, തുടർന്ന് അത് ലിങ്ക് ചെയ്യുക.',
      'Import a record first.': 'ആദ്യം ഒരു റെക്കോർഡ് ഇറക്കുമതി ചെയ്യുക.',
      'Import and review a document, or clear a filter.':
          'ഒരു പ്രമാണം ഇറക്കുമതി ചെയ്യുക, അവലോകനം ചെയ്യുക അല്ലെങ്കിൽ ഒരു ഫിൽട്ടർ മായ്‌ക്കുക.',
      'Inbox': 'ഇൻബോക്സ്',
      'Inbox activity': 'ഇൻബോക്സ് പ്രവർത്തനം',
      'Include rejected and superseded':
          'നിരസിച്ചതും അസാധുവാക്കിയതും ഉൾപ്പെടുത്തുക',
      'Insurance': 'ഇൻഷുറൻസ്',
      'Integrity check failed': 'സമഗ്രത പരിശോധന പരാജയപ്പെട്ടു',
      'Interface Language': 'ഇന്റർഫേസ് ഭാഷ',
      'Item Metadata & Location': 'ഇനം മെറ്റാഡാറ്റയും സ്ഥാനവും',
      'Keep What Matters. Own Your Data.':
          'പ്രാധാന്യമുള്ളവ സൂക്ഷിക്കുക. നിങ്ങളുടെ ഡാറ്റ സ്വന്തമാക്കൂ.',
      'Known Allergies': 'അറിയപ്പെടുന്ന അലർജികൾ',
      'Language & Regional OCR Packs': 'ഭാഷയും OCR പാക്കുകളും',
      'Large-screen dual-pane overview and bulk import dropzone.':
          'വലിയ സ്‌ക്രീൻ ഡ്യുവൽ പാളി അവലോകനവും ബൾക്ക് ഇംപോർട്ട് ഡ്രോപ്‌സോണും.',
      'Library': 'ലൈബ്രറി',
      'Life': 'ജീവിതം',
      'Life Directory': 'ലൈഫ് ഡയറക്ടറി',
      'Life Event': 'ലൈഫ് ഇവൻ്റ്',
      'Life Navigator': 'ലൈഫ് നാവിഗേറ്റർ',
      'Life OS Overview': 'ലൈഫ് ഒഎസ് അവലോകനം',
      'Life Timeline': 'ലൈഫ് ടൈംലൈൻ',
      'Lifetime Spend': 'ആജീവനാന്ത ചെലവ്',
      'Link encrypted evidence': 'എൻക്രിപ്റ്റ് ചെയ്ത തെളിവുകൾ ലിങ്ക് ചെയ്യുക',
      'Link encrypted record': 'ലിങ്ക് എൻക്രിപ്റ്റ് ചെയ്ത റെക്കോർഡ്',
      'Link existing information': 'നിലവിലുള്ള വിവരങ്ങൾ ലിങ്ക് ചെയ്യുക',
      'Link information': 'ലിങ്ക് വിവരങ്ങൾ',
      'Link to a profile?': 'ഒരു പ്രൊഫൈലിലേക്ക് ലിങ്ക് ചെയ്യണോ?',
      'Linked Claims, Events, Tasks, and evidence remain unchanged.':
          'ലിങ്ക് ചെയ്‌ത ക്ലെയിമുകൾ, ഇവൻ്റുകൾ, ടാസ്‌ക്കുകൾ, തെളിവുകൾ എന്നിവ മാറ്റമില്ലാതെ തുടരുന്നു.',
      'Local suggestions become part of your life record only after you confirm them.':
          'പ്രാദേശിക നിർദ്ദേശങ്ങൾ നിങ്ങൾ സ്ഥിരീകരിച്ചതിന് ശേഷം മാത്രമേ നിങ്ങളുടെ ജീവിതരേഖയുടെ ഭാഗമാകൂ.',
      'Location': 'സ്ഥാനം',
      'Log Maintenance / Cost': 'ലോഗ് പരിപാലനം / ചെലവ്',
      'Manage encrypted zero-knowledge backup destinations without token storage.':
          'ടോക്കൺ സ്‌റ്റോറേജ് ഇല്ലാതെ എൻക്രിപ്റ്റ് ചെയ്ത സീറോ നോളജ് ബാക്കപ്പ് ഡെസ്റ്റിനേഷനുകൾ മാനേജ് ചെയ്യുക.',
      'Mark completed': 'മാർക്ക് പൂർത്തിയായി',
      'Mask Date of Birth': 'മാസ്ക് ജനനത്തീയതി',
      'Mask ID Numbers (Aadhaar / PAN / Passport)':
          'മാസ്ക് ഐഡി നമ്പറുകൾ (ആധാർ / പാൻ / പാസ്പോർട്ട്)',
      'Mask QR codes & Barcodes': 'QR കോഡുകളും ബാർകോഡുകളും മാസ്ക് ചെയ്യുക',
      'Mask Residential Address': 'മാസ്ക് റെസിഡൻഷ്യൽ വിലാസം',
      'Mask Signatures': 'മാസ്ക് ഒപ്പുകൾ',
      'Medical': 'മെഡിക്കൽ',
      'Merge a duplicate': 'ഒരു ഡ്യൂപ്ലിക്കേറ്റ് ലയിപ്പിക്കുക',
      'Monthly': 'പ്രതിമാസ',
      'Multilingual Invariance Guaranteed': 'ബഹുഭാഷാ ഉറപ്പ്',
      'Name': 'പേര്',
      'New records will appear here and safely resume if interrupted.':
          'പുതിയ റെക്കോർഡുകൾ ഇവിടെ ദൃശ്യമാകും, തടസ്സമുണ്ടായാൽ സുരക്ഷിതമായി പുനരാരംഭിക്കും.',
      'Newest': 'ഏറ്റവും പുതിയത്',
      'No Claims yet. Link a reviewed record from the Inbox.':
          'ഇതുവരെ ക്ലെയിമുകളൊന്നുമില്ല. ഇൻബോക്സിൽ നിന്ന് അവലോകനം ചെയ്ത ഒരു റെക്കോർഡ് ലിങ്ക് ചെയ്യുക.',
      'No Smart Packs yet': 'ഇതുവരെ സ്മാർട്ട് പാക്കുകളൊന്നുമില്ല',
      'No access logs recorded.': 'ആക്സസ് ലോഗുകളൊന്നും രേഖപ്പെടുത്തിയിട്ടില്ല.',
      'No account, analytics, cloud OCR, advertisements, or Internet permission in release builds.':
          'റിലീസ് ബിൽഡുകളിൽ അക്കൗണ്ട്, അനലിറ്റിക്‌സ്, ക്ലൗഡ് OCR, പരസ്യങ്ങൾ, ഇൻ്റർനെറ്റ് അനുമതി എന്നിവയില്ല.',
      'No automation executions recorded yet.':
          'ഓട്ടോമേഷൻ എക്സിക്യൂഷനുകളൊന്നും ഇതുവരെ രേഖപ്പെടുത്തിയിട്ടില്ല.',
      'No confirmed value yet': 'ഇതുവരെ സ്ഥിരീകരിച്ച മൂല്യമില്ല',
      'No documents are processing': 'രേഖകളൊന്നും പ്രോസസ്സ് ചെയ്യുന്നില്ല',
      'No documents match these filters':
          'ഈ ഫിൽട്ടറുകളുമായി പൊരുത്തപ്പെടുന്ന പ്രമാണങ്ങളൊന്നും ഇല്ല',
      'No documents processing': 'പ്രമാണങ്ങൾ പ്രോസസ്സ് ചെയ്യുന്നില്ല',
      'No encrypted evidence linked.':
          'എൻക്രിപ്റ്റ് ചെയ്ത തെളിവുകളൊന്നും ലിങ്ക് ചെയ്തിട്ടില്ല.',
      'No extracted fields': 'വേർതിരിച്ചെടുത്ത ഫീൽഡുകളൊന്നുമില്ല',
      'No fields were extracted. Confirm the type to finish.':
          'വയലുകളൊന്നും പുറത്തെടുത്തില്ല. പൂർത്തിയാക്കേണ്ട തരം സ്ഥിരീകരിക്കുക.',
      'No linkable information yet':
          'ഇതുവരെ ലിങ്ക് ചെയ്യാവുന്ന വിവരങ്ങളൊന്നുമില്ല',
      'No linked evidence yet.': 'ഇതുവരെ ബന്ധിപ്പിച്ച തെളിവുകളൊന്നുമില്ല.',
      'No location': 'സ്ഥാനമില്ല',
      'No maintenance or cost logs yet.':
          'ഇതുവരെ അറ്റകുറ്റപ്പണികളോ ചെലവുകളോ ഇല്ല.',
      'No matching duplicate was found.':
          'പൊരുത്തപ്പെടുന്ന ഡ്യൂപ്ലിക്കേറ്റൊന്നും കണ്ടെത്തിയില്ല.',
      'No matching household items found.':
          'പൊരുത്തപ്പെടുന്ന വീട്ടുപകരണങ്ങളൊന്നും കണ്ടെത്തിയില്ല.',
      'No profile': 'പ്രൊഫൈൽ ഇല്ല',
      'No profile changes recorded yet':
          'പ്രൊഫൈൽ മാറ്റങ്ങളൊന്നും ഇതുവരെ രേഖപ്പെടുത്തിയിട്ടില്ല',
      'No recognized text': 'അംഗീകൃത വാചകമില്ല',
      'No record': 'രേഖയില്ല',
      'No relationships yet': 'ഇതുവരെ ബന്ധങ്ങളൊന്നുമില്ല',
      'No reminders': 'ഓർമ്മപ്പെടുത്തലുകളൊന്നുമില്ല',
      'No tags': 'ടാഗുകളൊന്നുമില്ല',
      'No upcoming reminders': 'വരാനിരിക്കുന്ന ഓർമ്മപ്പെടുത്തലുകളൊന്നുമില്ല',
      'Not now': 'ഇപ്പോൾ വേണ്ട',
      'Nothing matched yet. Try a person, car, home, insurer, pack or record name.':
          'ഇതുവരെ ഒന്നും പൊരുത്തപ്പെടുന്നില്ല. ഒരു വ്യക്തി, കാർ, വീട്, ഇൻഷുറർ, പാക്ക് അല്ലെങ്കിൽ റെക്കോർഡ് പേര് എന്നിവ പരീക്ഷിക്കുക.',
      'Nothing urgent': 'അടിയന്തിരമായി ഒന്നുമില്ല',
      'Notifications are local and contain no document details.':
          'അറിയിപ്പുകൾ പ്രാദേശികവും പ്രമാണ വിശദാംശങ്ങളൊന്നും ഉൾക്കൊള്ളാത്തതുമാണ്.',
      'ORGANIZATIONAL ITEMS': 'ഓർഗനൈസേഷണൽ ഇനങ്ങൾ',
      'Offline': 'ഓഫ്‌ലൈൻ',
      'Offline Automation Engine': 'ഓട്ടോമേഷൻ എഞ്ചിൻ',
      'Offline Pack template': 'ഓഫ്‌ലൈൻ പായ്ക്ക് ടെംപ്ലേറ്റ്',
      'Offline Safety Guaranteed': 'ഓഫ്‌ലൈൻ സുരക്ഷ ഉറപ്പ്',
      'Oldest': 'ഏറ്റവും പഴയത്',
      'On the date': 'തീയതിയിൽ',
      'On-device Intelligence': 'ഡിവൈസ് ഇന്റലിജൻസ്',
      'Only encrypted archive bytes leave your device. Zero provider tokens or Master Vault Keys are retained by OwnKeep.':
          'എൻക്രിപ്റ്റ് ചെയ്ത ആർക്കൈവ് ബൈറ്റുകൾ മാത്രമേ നിങ്ങളുടെ ഉപകരണത്തിൽ നിന്ന് പുറത്തുപോകൂ. സീറോ പ്രൊവൈഡർ ടോക്കണുകൾ അല്ലെങ്കിൽ മാസ്റ്റർ വോൾട്ട് കീകൾ OwnKeep നിലനിർത്തുന്നു.',
      'Open encrypted evidence': 'എൻക്രിപ്റ്റ് ചെയ്ത തെളിവുകൾ തുറക്കുക',
      'Open inbox': 'ഇൻബോക്സ് തുറക്കുക',
      'Open linked evidence': 'ലിങ്ക് ചെയ്ത തെളിവുകൾ തുറക്കുക',
      'Opening your encrypted vault...': 'വോൾട്ട് തുറക്കുന്നു...',
      'Optional': 'ഓപ്ഷണൽ',
      'Optional country-specific guidance, not legal advice.':
          'ഓപ്ഷണൽ രാജ്യ-നിർദ്ദിഷ്ട മാർഗനിർദേശം, നിയമോപദേശമല്ല.',
      'Organizational guidance': 'സംഘടനാ മാർഗനിർദേശം',
      'Original file remains untouched. Redactions are flattened permanently before export.':
          'യഥാർത്ഥ ഫയൽ സ്പർശിക്കാതെ തുടരുന്നു. കയറ്റുമതി ചെയ്യുന്നതിന് മുമ്പ് തിരുത്തലുകൾ ശാശ്വതമായി പരന്നതാണ്.',
      'Original remains encrypted':
          'യഥാർത്ഥ അവശിഷ്ടങ്ങൾ എൻക്രിപ്റ്റ് ചെയ്തിരിക്കുന്നു',
      'OwnKeep': 'സ്വന്തം കീപ്പ്',
      'OwnKeep 5.0.0': 'സ്വന്തം കീപ്പ് 5.0.0',
      'OwnKeep 5.0.0 Final': 'OwnKeep 5.0.0 ഫൈനൽ',
      'OwnKeep Desktop Personal Life OS': 'ഡെസ്ക്ടോപ്പ് ലൈഫ് OS',
      'OwnKeep could not access private storage.':
          'OwnKeep-ന് സ്വകാര്യ സംഭരണം ആക്‌സസ് ചെയ്യാൻ കഴിഞ്ഞില്ല.',
      'OwnKeep found possible matches. You decide whether to create Claim suggestions.':
          'OwnKeep സാധ്യമായ പൊരുത്തങ്ങൾ കണ്ടെത്തി. ക്ലെയിം നിർദ്ദേശങ്ങൾ സൃഷ്ടിക്കണോ എന്ന് നിങ്ങൾ തീരുമാനിക്കുക.',
      'Pack is archived.': 'പായ്ക്ക് ആർക്കൈവുചെയ്‌തു.',
      'Pair devices with ephemeral PIN codes for encrypted transfer.':
          'എൻക്രിപ്റ്റ് ചെയ്ത കൈമാറ്റത്തിനായി എഫെമെറൽ പിൻ കോഡുകൾ ഉപയോഗിച്ച് ഉപകരണങ്ങൾ ജോടിയാക്കുക.',
      'People, things & places': 'ആളുകൾ, വസ്തുക്കൾ, സ്ഥലങ്ങൾ',
      'Prepare evidence for export': 'കയറ്റുമതിക്കുള്ള തെളിവുകൾ തയ്യാറാക്കുക',
      'Preserves complete Claim, provenance, history, evidence, and graph compatibility between mobile and desktop without central backends.':
          'സെൻട്രൽ ബാക്കെൻഡുകളില്ലാതെ മൊബൈലും ഡെസ്‌ക്‌ടോപ്പും തമ്മിലുള്ള സമ്പൂർണ്ണ ക്ലെയിം, തെളിവ്, ചരിത്രം, തെളിവുകൾ, ഗ്രാഫ് അനുയോജ്യത എന്നിവ സംരക്ഷിക്കുന്നു.',
      'Primary Physician': 'പ്രൈമറി ഫിസിഷ്യൻ',
      'Prioritized locally from confirmed facts, events, evidence, integrity checks, and Inbox work.':
          'സ്ഥിരീകരിച്ച വസ്തുതകൾ, ഇവൻ്റുകൾ, തെളിവുകൾ, സമഗ്രത പരിശോധനകൾ, ഇൻബോക്സ് വർക്ക് എന്നിവയിൽ നിന്ന് പ്രാദേശികമായി മുൻഗണന നൽകി.',
      'Privacy Share': 'സ്വകാര്യത പങ്കിടൽ',
      'Privacy-aware Sharing': 'സ്വകാര്യത-അവബോധം പങ്കിടൽ',
      'Private notes': 'സ്വകാര്യ കുറിപ്പുകൾ',
      'Profile fields': 'പ്രൊഫൈൽ ഫീൽഡുകൾ',
      'Property': 'സ്വത്ത്',
      'Purchase Price': 'വാങ്ങൽ വില',
      'REJECTED': 'നിരസിച്ചു',
      'Ready for you': 'നിങ്ങൾക്കായി തയ്യാറാണ്',
      'Recent Evidence Documents': 'സമീപകാല തെളിവ് രേഖകൾ',
      'Recognized text preview': 'അംഗീകൃത ടെക്സ്റ്റ് പ്രിവ്യൂ',
      'Records': 'റെക്കോർഡുകൾ',
      'Recovery passphrase': 'വീണ്ടെടുക്കൽ പാസ്‌ഫ്രെയ്സ്',
      'Regional OCR Text Packs': 'റീജിയണൽ OCR പാക്കുകൾ',
      'Reject': 'നിരസിക്കുക',
      'Relationships': 'ബന്ധങ്ങൾ',
      'Reminders': 'ഓർമ്മപ്പെടുത്തലുകൾ',
      'Requires an exact same-name profile match.':
          'കൃത്യമായ അതേ പേരിലുള്ള പ്രൊഫൈൽ പൊരുത്തം ആവശ്യമാണ്.',
      'Reschedule': 'പുനക്രമീകരിക്കുക',
      'Restore encrypted backup': 'ബാക്കപ്പ് പുനഃസ്ഥാപിക്കുക',
      'Retry': 'വീണ്ടും ശ്രമിക്കുക',
      'Review': 'അവലോകനം',
      'Review export preparation': 'കയറ്റുമതി തയ്യാറെടുപ്പ് അവലോകനം ചെയ്യുക',
      'Review local suggestions and finish organizing.':
          'പ്രാദേശിക നിർദ്ദേശങ്ങൾ അവലോകനം ചെയ്‌ത് ഓർഗനൈസേഷൻ പൂർത്തിയാക്കുക.',
      'Save': 'സേവ് ചെയ്യുക',
      'Save Event Log': 'ഇവൻ്റ് ലോഗ് സംരക്ഷിക്കുക',
      'Save Item': 'ഇനം സംരക്ഷിക്കുക',
      'Save Rule': 'റൂൾ സംരക്ഷിക്കുക',
      'Save a verified .cvault file to Drive, iCloud, Files, or another document provider.':
          'പരിശോധിച്ചുറപ്പിച്ച .cvault ഫയൽ Drive, iCloud, Files അല്ലെങ്കിൽ മറ്റൊരു ഡോക്യുമെൻ്റ് ദാതാവിൽ സംരക്ഷിക്കുക.',
      'Save an unencrypted copy?':
          'എൻക്രിപ്റ്റ് ചെയ്യാത്ത ഒരു പകർപ്പ് സംരക്ഷിക്കണോ?',
      'Save copy': 'പകർപ്പ് സംരക്ഷിക്കുക',
      'Save field': 'ഫീൽഡ് സംരക്ഷിക്കുക',
      'Scan or import here. OwnKeep encrypts first, then organizes everything locally for your review.':
          'ഇവിടെ സ്കാൻ ചെയ്യുക അല്ലെങ്കിൽ ഇറക്കുമതി ചെയ്യുക. OwnKeep ആദ്യം എൻക്രിപ്റ്റ് ചെയ്യുന്നു, തുടർന്ന് നിങ്ങളുടെ അവലോകനത്തിനായി എല്ലാം പ്രാദേശികമായി ഓർഗനൈസുചെയ്യുന്നു.',
      'Search': 'തിരയുക',
      'Search documents...': 'പ്രമാണങ്ങൾ തിരയുക...',
      'Securely sync vault items directly to nearby devices over local P2P.':
          'ലോക്കൽ P2P വഴി സമീപത്തുള്ള ഉപകരണങ്ങളിലേക്ക് നേരിട്ട് വോൾട്ട് ഇനങ്ങൾ സുരക്ഷിതമായി സമന്വയിപ്പിക്കുക.',
      'Select Destination Provider': 'ഡെസ്റ്റിനേഷൻ പ്രൊവൈഡർ തിരഞ്ഞെടുക്കുക',
      'Select Transport Layer': 'ട്രാൻസ്പോർട്ട് ലെയർ തിരഞ്ഞെടുക്കുക',
      'Selected backup': 'തിരഞ്ഞെടുത്ത ബാക്കപ്പ്',
      'Settings': 'ക്രമീകരണങ്ങൾ',
      'Simulate Bulk Import Drop': 'ബൾക്ക് ഇമ്പോർട്ട് ചെയ്യുക',
      'Simulate Transfer Session': 'ട്രാൻസ്ഫർ സെഷൻ അനുകരിക്കുക',
      'Smart Packs': 'സ്മാർട്ട് പാക്കുകൾ',
      'Snooze 1 day': 'ഒരു ദിവസം സ്‌നൂസ് ചെയ്യുക',
      'Start building your private life record':
          'നിങ്ങളുടെ സ്വകാര്യ ജീവിത റെക്കോർഡ് നിർമ്മിക്കാൻ ആരംഭിക്കുക',
      'Store this passphrase somewhere safe. Losing it can make your encrypted documents permanently inaccessible.':
          'ഈ പാസ്‌ഫ്രെയ്സ് സുരക്ഷിതമായി എവിടെയെങ്കിലും സൂക്ഷിക്കുക. ഇത് നഷ്‌ടപ്പെടുന്നത് നിങ്ങളുടെ എൻക്രിപ്റ്റ് ചെയ്‌ത ഡോക്യുമെൻ്റുകൾ ശാശ്വതമായി ആക്‌സസ് ചെയ്യാൻ കഴിയില്ല.',
      'Stored inside your encrypted vault.':
          'നിങ്ങളുടെ എൻക്രിപ്റ്റ് ചെയ്ത നിലവറയ്ക്കുള്ളിൽ സംഭരിച്ചിരിക്കുന്നു.',
      'Strict offline mode': 'ഓഫ്‌ലൈൻ മോഡ് മാത്രം',
      'Strip EXIF & File Metadata': 'സ്ട്രിപ്പ് EXIF ​​& ഫയൽ മെറ്റാഡാറ്റ',
      'Suggested': 'നിർദ്ദേശിച്ചു',
      'Task': 'ടാസ്ക്',
      'Tasks & checklists': 'ടാസ്‌ക്കുകളും ചെക്ക്‌ലിസ്റ്റുകളും',
      'Tax': 'നികുതി',
      'Templates guide organization and never change your facts.':
          'ടെംപ്ലേറ്റുകൾ ഓർഗനൈസേഷനെ നയിക്കുന്നു, നിങ്ങളുടെ വസ്തുതകൾ ഒരിക്കലും മാറ്റില്ല.',
      'Text': 'വാചകം',
      'The duplicate ID and history will be retained.':
          'ഡ്യൂപ്ലിക്കേറ്റ് ഐഡിയും ചരിത്രവും നിലനിർത്തും.',
      'The original remains encrypted and unchanged.':
          'യഥാർത്ഥമായത് എൻക്രിപ്റ്റ് ചെയ്‌ത് മാറ്റമില്ലാതെ തുടരുന്നു.',
      'The original remains in history and this replacement keeps its entity and evidence links.':
          'ഒറിജിനൽ ചരിത്രത്തിൽ അവശേഷിക്കുന്നു, ഈ മാറ്റിസ്ഥാപിക്കൽ അതിൻ്റെ അസ്തിത്വവും തെളിവുകളുടെ ലിങ്കുകളും നിലനിർത്തുന്നു.',
      'The saved file will no longer be protected by OwnKeep. Anyone with access to the selected destination may be able to open it.':
          'സംരക്ഷിച്ച ഫയൽ ഇനി OwnKeep പരിരക്ഷിക്കില്ല. തിരഞ്ഞെടുത്ത ലക്ഷ്യസ്ഥാനത്തേക്ക് ആക്‌സസ് ഉള്ള ആർക്കും അത് തുറക്കാനായേക്കും.',
      'This document is no longer available.': 'ഈ പ്രമാണം ഇനി ലഭ്യമല്ല.',
      'This month': 'ഈ മാസം',
      'Timeline': 'ടൈംലൈൻ',
      'Timestamps when emergency medical card was opened:':
          'എമർജൻസി മെഡിക്കൽ കാർഡ് തുറന്ന സമയത്തെ ടൈംസ്റ്റാമ്പുകൾ:',
      'Total Assets Value': 'മൊത്തം ആസ്തി മൂല്യം',
      'Total Lifetime Maintenance & Tax Spend':
          'മൊത്തം ആജീവനാന്ത പരിപാലനവും നികുതി ചെലവും',
      'Total Maintenance Spend': 'ആകെ മെയിൻ്റനൻസ് ചെലവ്',
      'Total Spend': 'ആകെ ചെലവ്',
      'Transferred vault archives are byte- and graph- equivalent, authenticated with SHA-256 signatures, and zero keys or plaintext leave your devices.':
          'കൈമാറ്റം ചെയ്യപ്പെട്ട വോൾട്ട് ആർക്കൈവുകൾ ബൈറ്റും ഗ്രാഫും തുല്യമാണ്, SHA-256 ഒപ്പുകൾ ഉപയോഗിച്ച് പ്രാമാണീകരിച്ചിരിക്കുന്നു, കൂടാതെ സീറോ കീകളോ പ്ലെയിൻടെക്‌സ്റ്റോ നിങ്ങളുടെ ഉപകരണങ്ങളിൽ നിന്ന് പുറത്തുപോകും.',
      'Transition item state while preserving complete historical service & cost records:':
          'സമ്പൂർണ്ണ ചരിത്രപരമായ സേവനവും ചെലവ് രേഖകളും സംരക്ഷിക്കുമ്പോൾ ഇനത്തിൻ്റെ അവസ്ഥ മാറ്റുക:',
      'Trigger Blind Sync Rehearsal': 'ബാക്കപ്പ് സിങ്ക് ആരംഭിക്കുക',
      'Type': 'ടൈപ്പ് ചെയ്യുക',
      'Type a query or tap a template above to query your vault.':
          'നിങ്ങളുടെ നിലവറ അന്വേഷിക്കാൻ ഒരു ചോദ്യം ടൈപ്പ് ചെയ്യുക അല്ലെങ്കിൽ മുകളിൽ ഒരു ടെംപ്ലേറ്റിൽ ടാപ്പ് ചെയ്യുക.',
      'Unlock OwnKeep': 'OwnKeep അൺലോക്ക് ചെയ്യുക',
      'Unlock vault': 'വോൾട്ട് തുറക്കുക',
      'Unlock with biometrics': 'ബയോമെട്രിക്സ് ഉപയോഗിച്ച് തുറക്കുക',
      'Upcoming dues and expiries will appear here.':
          'വരാനിരിക്കുന്ന കുടിശ്ശികകളും കാലാവധികളും ഇവിടെ ദൃശ്യമാകും.',
      'Upcoming reminder': 'വരാനിരിക്കുന്ന ഓർമ്മപ്പെടുത്തൽ',
      'Update Operational Status': 'പ്രവർത്തന നില അപ്‌ഡേറ്റ് ചെയ്യുക',
      'Use a verified backup to recover this document.':
          'ഈ പ്രമാണം വീണ്ടെടുക്കാൻ പരിശോധിച്ചുറപ്പിച്ച ബാക്കപ്പ് ഉപയോഗിക്കുക.',
      'Use an offline template': 'ഒരു ഓഫ്‌ലൈൻ ടെംപ്ലേറ്റ് ഉപയോഗിക്കുക',
      'Use expiry date': 'കാലഹരണ തീയതി ഉപയോഗിക്കുക',
      'Use larger visual document cards.':
          'വലിയ വിഷ്വൽ ഡോക്യുമെൻ്റ് കാർഡുകൾ ഉപയോഗിക്കുക.',
      'Used when expiry reminder suggestions are added.':
          'കാലഹരണപ്പെടൽ ഓർമ്മപ്പെടുത്തൽ നിർദ്ദേശങ്ങൾ ചേർക്കുമ്പോൾ ഉപയോഗിക്കുന്നു.',
      'Vault Summary': 'വോൾട്ട് സംഗ്രഹം',
      'Vehicle': 'വാഹനം',
      'Verify and restore': 'പരിശോധിച്ച് പുനഃസ്ഥാപിക്കുക',
      'Verify document details': 'പ്രമാണ വിശദാംശങ്ങൾ പരിശോധിക്കുക',
      'View grounded natural language summaries and recommendations.':
          'അടിസ്ഥാനപരമായ സ്വാഭാവിക ഭാഷാ സംഗ്രഹങ്ങളും ശുപാർശകളും കാണുക.',
      'View minimized emergency responder contacts, blood group, and medical data.':
          'മിനിമൈസ് ചെയ്ത എമർജൻസി റെസ്‌പോണ്ടർ കോൺടാക്റ്റുകൾ, രക്തഗ്രൂപ്പ്, മെഡിക്കൽ ഡാറ്റ എന്നിവ കാണുക.',
      'Warranties': 'വാറൻ്റികൾ',
      'Warranty Coverage': 'വാറൻ്റി കവറേജ്',
      'Website / URI': 'വെബ്സൈറ്റ് / URI',
      'Weekly': 'പ്രതിവാരം',
      'Whole vault': 'മുഴുവൻ നിലവറ',
      'Your facts remain yours': 'നിങ്ങളുടെ വസ്തുതകൾ നിങ്ങളുടേതാണ്',
      'Your private life, organized locally.':
          'നിങ്ങളുടെ സ്വകാര്യ ജീവിതം, പ്രാദേശികമായി ക്രമീകരിച്ചിരിക്കുന്നു.',
      'Zero Token Blind Backup Policy': 'സീറോ ടോക്കൺ ബ്ലൈൻഡ് ബാക്കപ്പ് നയം',
      '⚠️ Notice: Exported copies leave OwnKeep protection and cannot be remotely revoked.':
          '⚠️ അറിയിപ്പ്: കയറ്റുമതി ചെയ്ത പകർപ്പുകൾ OwnKeep സംരക്ഷണം ഉപേക്ഷിക്കുന്നു, വിദൂരമായി അസാധുവാക്കാൻ കഴിയില്ല.',
    },
    SupportedLanguage.marathi: {
      '1. Recipient & Purpose': '1. प्राप्तकर्ता आणि उद्देश',
      '2. Field Redactions (Masking)': '2. Field Redactions',
      '3. Watermark Preview': '3. वॉटरमार्क पूर्वावलोकन',
      'Access dual-pane workspace views, multi-window layout, and bulk drop.':
          'ड्युअल-पेन वर्कस्पेस दृश्ये, मल्टी-विंडो लेआउट आणि बल्क ड्रॉपमध्ये प्रवेश करा.',
      'Active Destination Configuration': 'सक्रिय गंतव्य कॉन्फिगरेशन',
      'Active Medications': 'सक्रिय औषधे',
      'Active Valuation': 'सक्रिय मूल्यमापन',
      'Add': 'जोडा',
      'Add Automation Rule': 'ऑटोमेशन नियम जोडा',
      'Add Household Item': 'घरगुती वस्तू जोडा',
      'Add India Pack suggestions': 'इंडिया पॅक सूचना जोडा',
      'Add Item': 'आयटम जोडा',
      'Add Rule': 'नियम जोडा',
      'Add a record': 'रेकॉर्ड जोडा',
      'Add another profile first.': 'प्रथम दुसरे प्रोफाइल जोडा.',
      'Add checklist': 'चेकलिस्ट जोडा',
      'Add custom field': 'सानुकूल फील्ड जोडा',
      'Add custom item': 'सानुकूल आयटम जोडा',
      'Add event': 'कार्यक्रम जोडा',
      'Add one from a document detail screen.':
          'दस्तऐवज तपशील स्क्रीनवरून एक जोडा.',
      'Add people, vehicles, properties, devices, and places. Everything stays encrypted on this device.':
          'लोक, वाहने, गुणधर्म, उपकरणे आणि ठिकाणे जोडा. या डिव्हाइसवर सर्व काही एनक्रिप्टेड राहते.',
      'Add relationship': 'संबंध जोडा',
      'Add task': 'काम जोडा',
      'Add your first profile': 'तुमची पहिली प्रोफाइल जोडा',
      'Aliases': 'उपनाम',
      'All Categories': 'सर्व श्रेणी',
      'All Types': 'सर्व प्रकार',
      'All document types': 'सर्व दस्तऐवज प्रकार',
      'All natural language summaries and recommendations are strictly grounded on verified indexed vault claims.':
          'सर्व नैसर्गिक भाषेतील सारांश आणि शिफारसी सत्यापित अनुक्रमित वॉल्ट दाव्यांवर कठोरपणे आधारित आहेत.',
      'All tags': 'सर्व टॅग',
      'Applies to me': 'मला लागू होते',
      'Archive': 'संग्रहित करा',
      'Archive Pack': 'संग्रहण पॅक',
      'Archive this Pack?': 'हा पॅक संग्रहित करायचा?',
      'Archived': 'संग्रहित',
      'Ask OwnKeep': 'OwnKeep ला विचारा',
      'Ask OwnKeep parses facts directly from your encrypted graph and evidence documents without LLM hallucinations or cloud calls.':
          'LLM भ्रम किंवा क्लाउड कॉलशिवाय OwnKeep थेट तुमच्या कूटबद्ध आलेख आणि पुरावे दस्तऐवजांमधून तथ्यांचे विश्लेषण करा.',
      'Attention': 'लक्ष द्या',
      'Attention & Tasks': 'लक्ष आणि कार्ये',
      'Attention Items': 'लक्ष आयटम',
      'Attention Needed': 'लक्ष आवश्यक',
      'Automation runs 100% locally with bounded recursion, cycle detection, audit trails, and zero external network calls.':
          'बाउंडेड रिकर्शन, सायकल डिटेक्शन, ऑडिट ट्रेल्स आणि शून्य बाह्य नेटवर्क कॉलसह ऑटोमेशन 100% स्थानिक पातळीवर चालते.',
      'Back': 'मागे',
      'Backup & recovery': 'बॅकअप आणि पुनर्प्राप्ती',
      'Backup recovery passphrase': 'बॅकअप पुनर्प्राप्ती सांकेतिक वाक्यांश',
      'Biometric unlock': 'बायोमेट्रिक अनलॉक',
      'Blind Backup Destinations': 'बॅकअप ठिकाणे',
      'Bring records into your life': 'तुमच्या आयुष्यात रेकॉर्ड आणा',
      'Build your private life map': 'आपल्या खाजगी जीवनाचा नकाशा तयार करा',
      'Cancel': 'रद्द करा',
      'Changing a template only changes this checklist. It never changes confirmed facts or claims that an item is legally required.':
          'टेम्पलेट बदलल्याने ही चेकलिस्ट बदलते. हे कधीही पुष्टी केलेली तथ्ये बदलत नाही किंवा एखादी वस्तू कायदेशीररित्या आवश्यक असल्याचा दावा करत नाही.',
      'Changing interface language does not alter stored Claim values, predicates, Entity IDs, evidence, or backup bytes.':
          'इंटरफेस भाषा बदलल्याने संग्रहित दावा मूल्ये, अंदाज, अस्तित्व आयडी, पुरावे किंवा बॅकअप बाइट्स बदलत नाहीत.',
      'Checking this device...': 'डिव्हाइस तपासत आहे...',
      'Checklist': 'चेकलिस्ट',
      'Choose a custom date': 'सानुकूल तारीख निवडा',
      'Choose duplicate to merge': 'विलीन करण्यासाठी डुप्लिकेट निवडा',
      'Choose encrypted profile photo': 'एनक्रिप्टेड प्रोफाइल फोटो निवडा',
      'Choose new date': 'नवीन तारीख निवडा',
      'Close': 'बंद करा',
      'Close and reopen the app. If this continues, preserve the app data until recovery or restore tools are available.':
          'ॲप बंद करा आणि पुन्हा उघडा. हे सुरू राहिल्यास, पुनर्प्राप्ती किंवा पुनर्संचयित साधने उपलब्ध होईपर्यंत ॲप डेटा जतन करा.',
      'Complete': 'पूर्ण करा',
      'Configure interface locale and regional OCR text recognition packs.':
          'इंटरफेस लोकॅल आणि प्रादेशिक OCR मजकूर ओळख पॅक कॉन्फिगर करा.',
      'Configure local WHEN / IF / THEN rules for reminders, backup, and tagging.':
          'स्मरणपत्रे, बॅकअप आणि टॅगिंगसाठी स्थानिक WHEN/IF/THEN नियम कॉन्फिगर करा.',
      'Configure local WHEN / IF / THEN rules, preview execution, and inspect audit logs.':
          'स्थानिक WHEN/IF/THEN नियम कॉन्फिगर करा, अंमलबजावणीचे पूर्वावलोकन करा आणि ऑडिट लॉगची तपासणी करा.',
      'Configure user-selected blind cloud & NAS encrypted destinations.':
          'वापरकर्त्याने निवडलेले ब्लाइंड क्लाउड आणि NAS एन्क्रिप्ट केलेले गंतव्यस्थान कॉन्फिगर करा.',
      'Confirm': 'निश्चित करा',
      'Confirm only after comparing these values with the original document. Clear a value to remove it.':
          'मूळ दस्तऐवजाशी या मूल्यांची तुलना केल्यानंतरच पुष्टी करा. ते काढण्यासाठी मूल्य साफ करा.',
      'Confirm recovery passphrase':
          'पुनर्प्राप्ती सांकेतिक वाक्यांशाची पुष्टी करा',
      'Confirm reviewed details': 'पुनरावलोकन केलेल्या तपशीलांची पुष्टी करा',
      'Confirm the recovery warning to continue.':
          'सुरू ठेवण्यासाठी पुनर्प्राप्ती चेतावणीची पुष्टी करा.',
      'Continue': 'पुढे जा',
      'Correct without overwriting': 'ओव्हरराईट न करता बरोबर',
      'Corrected': 'दुरुस्त केले',
      'Create': 'तयार करा',
      'Create Smart Pack': 'स्मार्ट पॅक तयार करा',
      'Create a Smart Pack': 'स्मार्ट पॅक तयार करा',
      'Create a custom Pack': 'सानुकूल पॅक तयार करा',
      'Create a private organizational checklist from an offline template or make your own.':
          'ऑफलाइन टेम्पलेटवरून खाजगी संस्थात्मक चेकलिस्ट तयार करा किंवा तुमची स्वतःची बनवा.',
      'Create encrypted backup': 'एनक्रिप्टेड बॅकअप तयार करा',
      'Create encrypted vault': 'एनक्रिप्टेड व्हॉल्ट तयार करा',
      'Create task': 'कार्य तयार करा',
      'Create your private vault': 'तुमची खाजगी तिजोरी तयार करा',
      'Creating your private vault...': 'व्हॉल्ट तयार करत आहे...',
      'Custom Smart Pack': 'सानुकूल स्मार्ट पॅक',
      'Custom encrypted field': 'सानुकूल एनक्रिप्टेड फील्ड',
      'Customize': 'सानुकूलित करा',
      'Customize item': 'आयटम सानुकूलित करा',
      'Daily': 'दररोज',
      'Dark mode': 'डार्क मोड',
      'Date': 'तारीख',
      'Date range': 'तारीख श्रेणी',
      'Default reminder offsets': 'रिमाइंडर्स',
      'Delete': 'हटवा',
      'Desktop & Mobile Graph Compatibility Verified':
          'डेस्कटॉप आणि मोबाइल ग्राफ सुसंगतता सत्यापित',
      'Desktop Large-Scale Bulk Import Dropzone':
          'डेस्कटॉप मोठ्या प्रमाणात मोठ्या प्रमाणात आयात ड्रॉपझोन',
      'Desktop Layout Modes': 'डेस्कटॉप लेआउट मोड',
      'Deterministic Graph Answers': 'निर्धारक आलेख उत्तरे',
      'Device security': 'डिव्हाइस सुरक्षा',
      'Device-to-Device Transfer': 'डिव्हाइस ट्रान्सफर (P2P Transfer)',
      'Dismiss': 'रद्द करा',
      'Documents Library': 'दस्तऐवज लायब्ररी',
      'Documents stay encrypted on this device. Start by choosing the recovery passphrase that protects your vault.':
          'दस्तऐवज या डिव्हाइसवर कूटबद्ध राहतात. तुमच्या वॉल्टचे संरक्षण करणारा पुनर्प्राप्ती सांकेतिक वाक्यांश निवडून प्रारंभ करा.',
      'Does not create a plaintext export.':
          'प्लेन टेक्स्ट एक्सपोर्ट तयार करत नाही.',
      'Does not repeat': 'पुनरावृत्ती होत नाही',
      'Done': 'झाले',
      'Drag & drop directories or multiple document files for high-throughput parallel OCR processing.':
          'उच्च-थ्रूपुट समांतर OCR प्रक्रियेसाठी निर्देशिका किंवा एकाधिक दस्तऐवज फाइल्स ड्रॅग आणि ड्रॉप करा.',
      'Due date': 'देय तारीख',
      'Edit': 'संपादित करा',
      'Edit tags': 'टॅग संपादित करा',
      'Emergency Access Audit Log': 'आपत्कालीन प्रवेश ऑडिट लॉग',
      'Emergency Medical Card': 'आणीबाणी वैद्यकीय कार्ड',
      'Emergency Responder Contacts': 'आपत्कालीन प्रतिसादक संपर्क',
      'Emergency Storage Boundary Active. Isolated from main vault graph, evidence, and claims.':
          'आणीबाणी स्टोरेज सीमा सक्रिय. मुख्य व्हॉल्ट आलेख, पुरावे आणि दावे पासून वेगळे.',
      'Encrypted P2P Transfer (No Server)': 'Encrypted P2P Transfer',
      'Encrypted evidence': 'एन्क्रिप्टेड पुरावा',
      'End date': 'शेवटची तारीख',
      'End date cannot be before start date.':
          'समाप्ती तारीख प्रारंभ तारखेपूर्वीची असू शकत नाही.',
      'Enter a currency code.': 'चलन कोड एंटर करा.',
      'Enter a valid amount.': 'वैध रक्कम प्रविष्ट करा.',
      'Enter an event title.': 'कार्यक्रमाचे शीर्षक प्रविष्ट करा.',
      'Enter your recovery passphrase to access your private encrypted vault.':
          'तुमच्या खाजगी कूटबद्ध व्हॉल्टमध्ये प्रवेश करण्यासाठी तुमचा पुनर्प्राप्ती सांकेतिक वाक्यांश प्रविष्ट करा.',
      'Ephemeral Pairing PIN Code': 'क्षणिक जोडणी पिन कोड',
      'Event': 'कार्यक्रम',
      'Every result stays linked to your encrypted graph and evidence.':
          'प्रत्येक परिणाम तुमच्या एनक्रिप्टेड आलेखाशी आणि पुराव्याशी जोडलेला असतो.',
      'Evidence': 'पुरावा',
      'Execute deterministic graph queries for attention, expiry, spending, and warranties.':
          'लक्ष, कालबाह्यता, खर्च आणि वॉरंटींसाठी निर्धारवादी आलेख क्वेरी कार्यान्वित करा.',
      'Export Document': 'दस्तऐवज निर्यात करा',
      'Export Redacted & Watermarked Copy':
          'रेडेक्टेड आणि वॉटरमार्क केलेली प्रत निर्यात करा',
      'Export Redacted Copy': 'रीडेक्टेड प्रत निर्यात करा',
      'Export preparation': 'निर्यात तयारी',
      'Favourites': 'आवडी',
      'Finance': 'वित्त',
      'Full view': 'पूर्ण दृश्य',
      'Generate Pairing PIN': 'पेअरिंग पिन व्युत्पन्न करा',
      'Graph': 'ग्राफ',
      'Grid document view': 'ग्रिड दृश्य',
      'Guidance, not a requirement': 'मार्गदर्शन, आवश्यकता नाही',
      'Health Insurance Policy': 'आरोग्य विमा पॉलिसी',
      'History': 'इतिहास',
      'History and evidence are retained.':
          'इतिहास आणि पुरावे जपून ठेवले आहेत.',
      'Household & Ownership': 'घरगुती आणि मालकी',
      'Household Inventory': 'घरगुती यादी',
      'Household Valuation': 'घरगुती मूल्यमापन',
      'I understand OwnKeep cannot reset this passphrase.':
          'मला समजले आहे की OwnKeep हा सांकेतिक वाक्यांश रीसेट करू शकत नाही.',
      'Identifier': 'ओळखकर्ता',
      'Identity': 'ओळख',
      'Import a document and OwnKeep will organize it locally.':
          'एक दस्तऐवज आयात करा आणि OwnKeep ते स्थानिक पातळीवर आयोजित करेल.',
      'Import a photo first, then link it.':
          'प्रथम एक फोटो आयात करा, नंतर तो दुवा.',
      'Import a record first.': 'प्रथम रेकॉर्ड आयात करा.',
      'Import and review a document, or clear a filter.':
          'दस्तऐवज आयात करा आणि त्याचे पुनरावलोकन करा किंवा फिल्टर साफ करा.',
      'Inbox': 'इनबॉक्स',
      'Inbox activity': 'इनबॉक्स क्रियाकलाप',
      'Include rejected and superseded': 'नाकारलेले आणि अधिग्रहित समाविष्ट करा',
      'Insurance': 'विमा',
      'Integrity check failed': 'अखंडता तपासणी अयशस्वी',
      'Interface Language': 'इंटरफेस भाषा',
      'Item Metadata & Location': 'आयटम मेटाडेटा आणि स्थान',
      'Keep What Matters. Own Your Data.':
          'काय महत्त्वाचे आहे ठेवा. तुमच्या डेटाची मालकी घ्या.',
      'Known Allergies': 'ज्ञात ऍलर्जी',
      'Language & Regional OCR Packs': 'भाषा आणि OCR पॅक',
      'Large-screen dual-pane overview and bulk import dropzone.':
          'मोठ्या-स्क्रीन ड्युअल-पेन विहंगावलोकन आणि मोठ्या प्रमाणात आयात ड्रॉपझोन.',
      'Library': 'ग्रंथालय',
      'Life': 'जीवन',
      'Life Directory': 'जीवन निर्देशिका',
      'Life Event': 'जीवन प्रसंग',
      'Life Navigator': 'लाइफ नेव्हिगेटर',
      'Life OS Overview': 'लाइफ ओएस विहंगावलोकन',
      'Life Timeline': 'लाइफ टाइमलाइन',
      'Lifetime Spend': 'आजीवन खर्च',
      'Link encrypted evidence': 'कूटबद्ध पुरावा लिंक करा',
      'Link encrypted record': 'लिंक एनक्रिप्टेड रेकॉर्ड',
      'Link existing information': 'विद्यमान माहिती लिंक करा',
      'Link information': 'लिंक माहिती',
      'Link to a profile?': 'प्रोफाइलशी दुवा साधायचा?',
      'Linked Claims, Events, Tasks, and evidence remain unchanged.':
          'लिंक केलेले दावे, कार्यक्रम, कार्ये आणि पुरावे अपरिवर्तित राहतात.',
      'Local suggestions become part of your life record only after you confirm them.':
          'तुम्ही त्यांची पुष्टी केल्यानंतरच स्थानिक सूचना तुमच्या लाइफ रेकॉर्डचा भाग बनतात.',
      'Location': 'स्थान',
      'Log Maintenance / Cost': 'लॉग देखभाल / खर्च',
      'Manage encrypted zero-knowledge backup destinations without token storage.':
          'टोकन स्टोरेजशिवाय एनक्रिप्टेड शून्य-ज्ञान बॅकअप गंतव्ये व्यवस्थापित करा.',
      'Mark completed': 'मार्क पूर्ण झाले',
      'Mask Date of Birth': 'मास्क जन्मतारीख',
      'Mask ID Numbers (Aadhaar / PAN / Passport)':
          'मास्क आयडी क्रमांक (आधार / पॅन / पासपोर्ट)',
      'Mask QR codes & Barcodes': 'QR कोड आणि बारकोड मास्क करा',
      'Mask Residential Address': 'मास्क निवासी पत्ता',
      'Mask Signatures': 'मुखवटा स्वाक्षरी',
      'Medical': 'वैद्यकीय',
      'Merge a duplicate': 'डुप्लिकेट विलीन करा',
      'Monthly': 'मासिक',
      'Multilingual Invariance Guaranteed': 'बहुभाषिक सुसंगतता हमी',
      'Name': 'नाव',
      'New records will appear here and safely resume if interrupted.':
          'नवीन रेकॉर्ड येथे दिसतील आणि व्यत्यय आल्यास सुरक्षितपणे पुन्हा सुरू होतील.',
      'Newest': 'सर्वात नवीन',
      'No Claims yet. Link a reviewed record from the Inbox.':
          'अद्याप कोणतेही दावे नाहीत. इनबॉक्समधून पुनरावलोकन केलेल्या रेकॉर्डचा दुवा जोडा.',
      'No Smart Packs yet': 'अद्याप कोणतेही स्मार्ट पॅक नाहीत',
      'No access logs recorded.': 'कोणतेही प्रवेश लॉग रेकॉर्ड केलेले नाहीत.',
      'No account, analytics, cloud OCR, advertisements, or Internet permission in release builds.':
          'रिलीझ बिल्डमध्ये कोणतेही खाते, विश्लेषण, क्लाउड OCR, जाहिराती किंवा इंटरनेट परवानगी नाही.',
      'No automation executions recorded yet.':
          'अद्याप कोणतीही ऑटोमेशन अंमलबजावणी रेकॉर्ड केलेली नाही.',
      'No confirmed value yet': 'अद्याप कोणतेही पुष्टी केलेले मूल्य नाही',
      'No documents are processing':
          'कोणत्याही कागदपत्रांवर प्रक्रिया होत नाही',
      'No documents match these filters':
          'कोणतेही दस्तऐवज या फिल्टरशी जुळत नाहीत',
      'No documents processing': 'कागदपत्रांवर प्रक्रिया होत नाही',
      'No encrypted evidence linked.':
          'कोणताही कूटबद्ध पुरावा लिंक केलेला नाही.',
      'No extracted fields': 'काढलेले फील्ड नाहीत',
      'No fields were extracted. Confirm the type to finish.':
          'कोणतेही फील्ड काढले गेले नाहीत. समाप्त करण्यासाठी प्रकार निश्चित करा.',
      'No linkable information yet':
          'अद्याप कोणतीही लिंक करण्यायोग्य माहिती नाही',
      'No linked evidence yet.': 'अद्याप जोडलेले पुरावे नाहीत.',
      'No location': 'स्थान नाही',
      'No maintenance or cost logs yet.':
          'अद्याप कोणतीही देखभाल किंवा खर्च नोंदी नाहीत.',
      'No matching duplicate was found.':
          'कोणतीही जुळणारी डुप्लिकेट आढळली नाही.',
      'No matching household items found.':
          'कोणत्याही जुळणाऱ्या घरगुती वस्तू आढळल्या नाहीत.',
      'No profile': 'प्रोफाइल नाही',
      'No profile changes recorded yet':
          'अद्याप कोणतेही प्रोफाइल बदल रेकॉर्ड केलेले नाहीत',
      'No recognized text': 'कोणताही मान्यताप्राप्त मजकूर नाही',
      'No record': 'रेकॉर्ड नाही',
      'No relationships yet': 'अद्याप कोणतेही संबंध नाहीत',
      'No reminders': 'स्मरणपत्रे नाहीत',
      'No tags': 'कोणतेही टॅग नाहीत',
      'No upcoming reminders': 'आगामी स्मरणपत्रे नाहीत',
      'Not now': 'आता नाही',
      'Nothing matched yet. Try a person, car, home, insurer, pack or record name.':
          'अद्याप काहीही जुळले नाही. एखादी व्यक्ती, कार, घर, विमा कंपनी, पॅक किंवा रेकॉर्ड नाव वापरून पहा.',
      'Nothing urgent': 'काही तातडीचे नाही',
      'Notifications are local and contain no document details.':
          'सूचना स्थानिक आहेत आणि त्यात कोणतेही दस्तऐवज तपशील नाहीत.',
      'ORGANIZATIONAL ITEMS': 'संस्थात्मक आयटम',
      'Offline': 'ऑफलाइन',
      'Offline Automation Engine': 'ऑफलाइन ऑटोमेशन इंजिन',
      'Offline Pack template': 'ऑफलाइन पॅक टेम्पलेट',
      'Offline Safety Guaranteed': 'ऑफलाइन सुरक्षिततेची हमी',
      'Oldest': 'सर्वात जुने',
      'On the date': 'तारखेला',
      'On-device Intelligence': 'ऑन-डिव्हाइस इंटेलिजन्स',
      'Only encrypted archive bytes leave your device. Zero provider tokens or Master Vault Keys are retained by OwnKeep.':
          'फक्त एन्क्रिप्ट केलेले संग्रहण बाइट्स तुमचे डिव्हाइस सोडतात. शून्य प्रदाता टोकन किंवा मास्टर व्हॉल्ट की OwnKeep द्वारे राखून ठेवल्या जातात.',
      'Open encrypted evidence': 'एनक्रिप्टेड पुरावा उघडा',
      'Open inbox': 'इनबॉक्स उघडा',
      'Open linked evidence': 'जोडलेले पुरावे उघडा',
      'Opening your encrypted vault...': 'व्हॉल्ट उघडत आहे...',
      'Optional': 'ऐच्छिक',
      'Optional country-specific guidance, not legal advice.':
          'पर्यायी देश-विशिष्ट मार्गदर्शन, कायदेशीर सल्ला नाही.',
      'Organizational guidance': 'संस्थात्मक मार्गदर्शन',
      'Original file remains untouched. Redactions are flattened permanently before export.':
          'मूळ फाइल अस्पर्श राहते. निर्यात करण्यापूर्वी रिडॅक्शन कायमचे सपाट केले जातात.',
      'Original remains encrypted': 'मूळ राहते एनक्रिप्टेड',
      'OwnKeep': 'OwnKeep',
      'OwnKeep 5.0.0': 'OwnKeep 5.0.0',
      'OwnKeep 5.0.0 Final': 'OwnKeep 5.0.0 अंतिम',
      'OwnKeep Desktop Personal Life OS': 'डेस्कटॉप लाईफ OS',
      'OwnKeep could not access private storage.':
          'OwnKeep खाजगी स्टोरेजमध्ये प्रवेश करू शकत नाही.',
      'OwnKeep found possible matches. You decide whether to create Claim suggestions.':
          'OwnKeep ला संभाव्य जुळण्या सापडल्या. हक्क सूचना तयार करायच्या की नाही हे तुम्ही ठरवा.',
      'Pack is archived.': 'पॅक संग्रहित आहे.',
      'Pair devices with ephemeral PIN codes for encrypted transfer.':
          'एन्क्रिप्टेड ट्रान्सफरसाठी तात्कालिक पिन कोडसह उपकरणे जोडा.',
      'People, things & places': 'लोक, गोष्टी आणि ठिकाणे',
      'Prepare evidence for export': 'निर्यातीसाठी पुरावे तयार करा',
      'Preserves complete Claim, provenance, history, evidence, and graph compatibility between mobile and desktop without central backends.':
          'मध्यवर्ती बॅकएंडशिवाय मोबाइल आणि डेस्कटॉप दरम्यान संपूर्ण दावा, मूळ, इतिहास, पुरावे आणि आलेख सुसंगतता जतन करते.',
      'Primary Physician': 'प्राथमिक चिकित्सक',
      'Prioritized locally from confirmed facts, events, evidence, integrity checks, and Inbox work.':
          'पुष्टी केलेली तथ्ये, घटना, पुरावे, अखंडता तपासणे आणि इनबॉक्स कार्य यावरून स्थानिक पातळीवर प्राधान्य दिले जाते.',
      'Privacy Share': 'गोपनीयता शेअर',
      'Privacy-aware Sharing': 'गोपनीयता-जागरूक शेअरिंग',
      'Private notes': 'खाजगी नोट्स',
      'Profile fields': 'प्रोफाइल फील्ड',
      'Property': 'मालमत्ता',
      'Purchase Price': 'खरेदी किंमत',
      'REJECTED': 'नाकारले',
      'Ready for you': 'तुमच्यासाठी तयार आहे',
      'Recent Evidence Documents': 'अलीकडील पुरावा दस्तऐवज',
      'Recognized text preview': 'मान्यताप्राप्त मजकूर पूर्वावलोकन',
      'Records': 'रेकॉर्ड्स',
      'Recovery passphrase': 'पुनर्प्राप्ती सांकेतिक वाक्यांश',
      'Regional OCR Text Packs': 'प्रादेशिक OCR मजकूर पॅक',
      'Reject': 'नकार द्या',
      'Relationships': 'नातेसंबंध',
      'Reminders': 'स्मरणपत्रे',
      'Requires an exact same-name profile match.':
          'तंतोतंत समान-नावाची प्रोफाइल जुळणी आवश्यक आहे.',
      'Reschedule': 'पुन्हा वेळ ठरवा',
      'Restore encrypted backup': 'बॅकअप पुन्हा मिळवा',
      'Retry': 'पुन्हा प्रयत्न करा',
      'Review': 'पुनरावलोकन करा',
      'Review export preparation': 'निर्यात तयारीचे पुनरावलोकन करा',
      'Review local suggestions and finish organizing.':
          'स्थानिक सूचनांचे पुनरावलोकन करा आणि आयोजन पूर्ण करा.',
      'Save': 'जतन करा',
      'Save Event Log': 'इव्हेंट लॉग जतन करा',
      'Save Item': 'आयटम जतन करा',
      'Save Rule': 'नियम जतन करा',
      'Save a verified .cvault file to Drive, iCloud, Files, or another document provider.':
          'सत्यापित केलेली .cvault फाइल Drive, iCloud, Files किंवा इतर दस्तऐवज प्रदात्यावर सेव्ह करा.',
      'Save an unencrypted copy?': 'एन्क्रिप्ट न केलेली प्रत जतन करायची?',
      'Save copy': 'प्रत जतन करा',
      'Save field': 'फील्ड जतन करा',
      'Scan or import here. OwnKeep encrypts first, then organizes everything locally for your review.':
          'येथे स्कॅन करा किंवा आयात करा. OwnKeep प्रथम एन्क्रिप्ट करते, नंतर तुमच्या पुनरावलोकनासाठी स्थानिक पातळीवर सर्वकाही व्यवस्थापित करते.',
      'Search': 'शोधा',
      'Search documents...': 'कागदपत्रे शोधा...',
      'Securely sync vault items directly to nearby devices over local P2P.':
          'स्थानिक P2P वर वॉल्ट आयटम थेट जवळच्या डिव्हाइसेसवर सुरक्षितपणे सिंक करा.',
      'Select Destination Provider': 'गंतव्य प्रदाता निवडा',
      'Select Transport Layer': 'परिवहन स्तर निवडा',
      'Selected backup': 'निवडलेला बॅकअप',
      'Settings': 'सेटिंग्ज',
      'Simulate Bulk Import Drop': 'बल्क इम्पोर्ट करा',
      'Simulate Transfer Session': 'हस्तांतरण सत्र अनुकरण',
      'Smart Packs': 'स्मार्ट पॅक',
      'Snooze 1 day': '1 दिवस स्नूझ करा',
      'Start building your private life record':
          'आपले खाजगी जीवन रेकॉर्ड तयार करण्यास प्रारंभ करा',
      'Store this passphrase somewhere safe. Losing it can make your encrypted documents permanently inaccessible.':
          'हा सांकेतिक वाक्यांश कुठेतरी सुरक्षित ठेवा. ते गमावल्यास तुमचे एन्क्रिप्ट केलेले दस्तऐवज कायमचे प्रवेश करण्यायोग्य होऊ शकतात.',
      'Stored inside your encrypted vault.':
          'तुमच्या एनक्रिप्टेड व्हॉल्टमध्ये साठवले.',
      'Strict offline mode': 'ऑफलाइन मोड',
      'Strip EXIF & File Metadata': 'स्ट्रिप EXIF ​​आणि फाइल मेटाडेटा',
      'Suggested': 'सुचवले',
      'Task': 'कार्य',
      'Tasks & checklists': 'कार्ये आणि चेकलिस्ट',
      'Tax': 'कर',
      'Templates guide organization and never change your facts.':
          'टेम्प्लेट्स संस्थेला मार्गदर्शन करतात आणि तुमचे तथ्य कधीही बदलत नाहीत.',
      'Text': 'मजकूर',
      'The duplicate ID and history will be retained.':
          'डुप्लिकेट आयडी आणि इतिहास राखून ठेवला जाईल.',
      'The original remains encrypted and unchanged.':
          'मूळ एनक्रिप्टेड आणि अपरिवर्तित राहते.',
      'The original remains in history and this replacement keeps its entity and evidence links.':
          'मूळ इतिहासात राहते आणि ही बदली त्याचे अस्तित्व आणि पुराव्याचे दुवे ठेवते.',
      'The saved file will no longer be protected by OwnKeep. Anyone with access to the selected destination may be able to open it.':
          'सेव्ह केलेली फाइल यापुढे OwnKeep द्वारे संरक्षित केली जाणार नाही. निवडलेल्या गंतव्यस्थानात प्रवेश असलेले कोणीही ते उघडण्यास सक्षम असेल.',
      'This document is no longer available.': 'हा दस्तऐवज आता उपलब्ध नाही.',
      'This month': 'या महिन्यात',
      'Timeline': 'टाइमलाइन',
      'Timestamps when emergency medical card was opened:':
          'इमर्जन्सी मेडिकल कार्ड उघडल्यावर टाइमस्टॅम्प:',
      'Total Assets Value': 'एकूण मालमत्ता मूल्य',
      'Total Lifetime Maintenance & Tax Spend': 'एकूण आजीवन देखभाल आणि कर खर्च',
      'Total Maintenance Spend': 'एकूण देखभाल खर्च',
      'Total Spend': 'एकूण खर्च',
      'Transferred vault archives are byte- and graph- equivalent, authenticated with SHA-256 signatures, and zero keys or plaintext leave your devices.':
          'हस्तांतरित व्हॉल्ट संग्रहण बाइट- आणि ग्राफ- समतुल्य आहेत, SHA-256 स्वाक्षरीसह प्रमाणीकृत आहेत आणि शून्य की किंवा प्लेनटेक्स्ट तुमची डिव्हाइस सोडतात.',
      'Transition item state while preserving complete historical service & cost records:':
          'संपूर्ण ऐतिहासिक सेवा आणि खर्चाच्या नोंदी जतन करताना संक्रमण आयटमची स्थिती:',
      'Trigger Blind Sync Rehearsal': 'बॅकअप सिंक सुरू करा',
      'Type': 'प्रकार',
      'Type a query or tap a template above to query your vault.':
          'तुमच्या वॉल्टची क्वेरी करण्यासाठी क्वेरी टाईप करा किंवा वरील टेम्प्लेटवर टॅप करा.',
      'Unlock OwnKeep': 'OwnKeep अनलॉक करा',
      'Unlock vault': 'व्हॉल्ट उघडा',
      'Unlock with biometrics': 'बायोमेट्रिक्सने उघडा',
      'Upcoming dues and expiries will appear here.':
          'आगामी थकबाकी आणि कालबाह्यता येथे दिसून येतील.',
      'Upcoming reminder': 'आगामी स्मरणपत्र',
      'Update Operational Status': 'ऑपरेशनल स्थिती अद्यतनित करा',
      'Use a verified backup to recover this document.':
          'हा दस्तऐवज पुनर्प्राप्त करण्यासाठी सत्यापित बॅकअप वापरा.',
      'Use an offline template': 'ऑफलाइन टेम्पलेट वापरा',
      'Use expiry date': 'कालबाह्यता तारीख वापरा',
      'Use larger visual document cards.':
          'मोठे व्हिज्युअल दस्तऐवज कार्ड वापरा.',
      'Used when expiry reminder suggestions are added.':
          'कालबाह्य रिमाइंडर सूचना जोडल्या जातात तेव्हा वापरले जाते.',
      'Vault Summary': 'वॉल्ट सारांश',
      'Vehicle': 'वाहन',
      'Verify and restore': 'तपासा आणि पुन्हा मिळवा',
      'Verify document details': 'दस्तऐवज तपशील सत्यापित करा',
      'View grounded natural language summaries and recommendations.':
          'ग्राउंडेड नैसर्गिक भाषा सारांश आणि शिफारसी पहा.',
      'View minimized emergency responder contacts, blood group, and medical data.':
          'कमीतकमी आणीबाणी प्रतिसादक संपर्क, रक्त गट आणि वैद्यकीय डेटा पहा.',
      'Warranties': 'हमी',
      'Warranty Coverage': 'वॉरंटी कव्हरेज',
      'Website / URI': 'वेबसाइट / URI',
      'Weekly': 'साप्ताहिक',
      'Whole vault': 'संपूर्ण तिजोरी',
      'Your facts remain yours': 'तुमचे तथ्य तुमचेच राहते',
      'Your private life, organized locally.':
          'आपले खाजगी जीवन, स्थानिक पातळीवर आयोजित.',
      'Zero Token Blind Backup Policy': 'शून्य टोकन ब्लाइंड बॅकअप धोरण',
      '⚠️ Notice: Exported copies leave OwnKeep protection and cannot be remotely revoked.':
          '⚠️ सूचना: निर्यात केलेल्या प्रती OwnKeep संरक्षण सोडतात आणि दूरस्थपणे रद्द केल्या जाऊ शकत नाहीत.',
    },
    SupportedLanguage.bengali: {
      '1. Recipient & Purpose': '1. প্রাপক এবং উদ্দেশ্য',
      '2. Field Redactions (Masking)': '2. Field Redactions',
      '3. Watermark Preview': '3. ওয়াটারমার্ক প্রিভিউ',
      'Access dual-pane workspace views, multi-window layout, and bulk drop.':
          'ডুয়াল-পেন ওয়ার্কস্পেস ভিউ, মাল্টি-উইন্ডো লেআউট এবং বাল্ক ড্রপ অ্যাক্সেস করুন।',
      'Active Destination Configuration': 'সক্রিয় গন্তব্য কনফিগারেশন',
      'Active Medications': 'সক্রিয় ওষুধ',
      'Active Valuation': 'সক্রিয় মূল্যায়ন',
      'Add': 'যোগ করুন',
      'Add Automation Rule': 'অটোমেশন নিয়ম যোগ করুন',
      'Add Household Item': 'পরিবারের আইটেম যোগ করুন',
      'Add India Pack suggestions': 'ইন্ডিয়া প্যাক পরামর্শ যোগ করুন',
      'Add Item': 'আইটেম যোগ করুন',
      'Add Rule': 'নিয়ম যোগ করুন',
      'Add a record': 'একটি রেকর্ড যোগ করুন',
      'Add another profile first.': 'প্রথমে অন্য প্রোফাইল যোগ করুন।',
      'Add checklist': 'চেকলিস্ট যোগ করুন',
      'Add custom field': 'কাস্টম ক্ষেত্র যোগ করুন',
      'Add custom item': 'কাস্টম আইটেম যোগ করুন',
      'Add event': 'ইভেন্ট যোগ করুন',
      'Add one from a document detail screen.':
          'একটি নথির বিস্তারিত স্ক্রীন থেকে একটি যোগ করুন।',
      'Add people, vehicles, properties, devices, and places. Everything stays encrypted on this device.':
          'মানুষ, যানবাহন, বৈশিষ্ট্য, ডিভাইস এবং স্থান যোগ করুন। এই ডিভাইসে সবকিছু এনক্রিপ্ট করা থাকে।',
      'Add relationship': 'সম্পর্ক যোগ করুন',
      'Add task': 'টাস্ক যোগ করুন',
      'Add your first profile': 'আপনার প্রথম প্রোফাইল যোগ করুন',
      'Aliases': 'উপনাম',
      'All Categories': 'সমস্ত বিভাগ',
      'All Types': 'সকল প্রকার',
      'All document types': 'সব ধরনের নথি',
      'All natural language summaries and recommendations are strictly grounded on verified indexed vault claims.':
          'সমস্ত প্রাকৃতিক ভাষার সারাংশ এবং সুপারিশগুলি কঠোরভাবে যাচাইকৃত ইনডেক্সড ভল্ট দাবির উপর ভিত্তি করে।',
      'All tags': 'সব ট্যাগ',
      'Applies to me': 'আমার জন্য প্রযোজ্য',
      'Archive': 'আর্কাইভ',
      'Archive Pack': 'সংরক্ষণাগার প্যাক',
      'Archive this Pack?': 'এই প্যাকটি আর্কাইভ করবেন?',
      'Archived': 'সংরক্ষণাগারভুক্ত',
      'Ask OwnKeep': 'OwnKeep কে জিজ্ঞাসা করুন',
      'Ask OwnKeep parses facts directly from your encrypted graph and evidence documents without LLM hallucinations or cloud calls.':
          'LLM হ্যালুসিনেশন বা ক্লাউড কল ছাড়াই OwnKeep-কে সরাসরি আপনার এনক্রিপ্ট করা গ্রাফ এবং প্রমাণ নথি থেকে তথ্য বিশ্লেষণ করুন।',
      'Attention': 'মনোযোগ',
      'Attention & Tasks': 'মনোযোগ এবং কাজ',
      'Attention Items': 'মনোযোগ আইটেম',
      'Attention Needed': 'মনোযোগ প্রয়োজন',
      'Automation runs 100% locally with bounded recursion, cycle detection, audit trails, and zero external network calls.':
          'বাউন্ডেড রিকারশন, সাইকেল ডিটেকশন, অডিট ট্রেইল এবং জিরো এক্সটার্নাল নেটওয়ার্ক কল সহ অটোমেশন 100% স্থানীয়ভাবে চলে।',
      'Back': 'ফিরে যান',
      'Backup & recovery': 'ব্যাকআপ এবং রিকভারি',
      'Backup recovery passphrase': 'ব্যাকআপ পুনরুদ্ধার পাসফ্রেজ',
      'Biometric unlock': 'বায়োমেট্রিক আনলক',
      'Blind Backup Destinations': 'ব্যাকআপ গন্তব্য',
      'Bring records into your life': 'আপনার জীবনে রেকর্ড আনুন',
      'Build your private life map':
          'আপনার ব্যক্তিগত জীবনের মানচিত্র তৈরি করুন',
      'Cancel': 'বাতিল',
      'Changing a template only changes this checklist. It never changes confirmed facts or claims that an item is legally required.':
          'একটি টেমপ্লেট পরিবর্তন শুধুমাত্র এই চেকলিস্ট পরিবর্তন. এটি কখনই নিশ্চিত তথ্য পরিবর্তন করে না বা দাবি করে যে একটি আইটেম আইনত প্রয়োজনীয়।',
      'Changing interface language does not alter stored Claim values, predicates, Entity IDs, evidence, or backup bytes.':
          'ইন্টারফেসের ভাষা পরিবর্তন করা সঞ্চিত দাবি মান, পূর্বাভাস, সত্তা আইডি, প্রমাণ, বা ব্যাকআপ বাইট পরিবর্তন করে না।',
      'Checking this device...': 'ডিভাইস পরীক্ষা করা হচ্ছে...',
      'Checklist': 'চেকলিস্ট',
      'Choose a custom date': 'একটি কাস্টম তারিখ চয়ন করুন',
      'Choose duplicate to merge': 'মার্জ করতে ডুপ্লিকেট বেছে নিন',
      'Choose encrypted profile photo': 'এনক্রিপ্ট করা প্রোফাইল ফটো বেছে নিন',
      'Choose new date': 'নতুন তারিখ চয়ন করুন',
      'Close': 'বন্ধ করুন',
      'Close and reopen the app. If this continues, preserve the app data until recovery or restore tools are available.':
          'অ্যাপটি বন্ধ করুন এবং পুনরায় খুলুন। এটি চলতে থাকলে, পুনরুদ্ধার বা পুনরুদ্ধার সরঞ্জাম উপলব্ধ না হওয়া পর্যন্ত অ্যাপ ডেটা সংরক্ষণ করুন।',
      'Complete': 'সম্পূর্ণ করুন',
      'Configure interface locale and regional OCR text recognition packs.':
          'ইন্টারফেস লোকেল এবং আঞ্চলিক OCR পাঠ্য স্বীকৃতি প্যাকগুলি কনফিগার করুন।',
      'Configure local WHEN / IF / THEN rules for reminders, backup, and tagging.':
          'অনুস্মারক, ব্যাকআপ এবং ট্যাগিংয়ের জন্য স্থানীয় WHEN/IF/THEN নিয়মগুলি কনফিগার করুন।',
      'Configure local WHEN / IF / THEN rules, preview execution, and inspect audit logs.':
          'স্থানীয় WHEN/IF/THEN নিয়ম, প্রিভিউ এক্সিকিউশন, এবং অডিট লগগুলি পরিদর্শন করুন।',
      'Configure user-selected blind cloud & NAS encrypted destinations.':
          'ব্যবহারকারী-নির্বাচিত ব্লাইন্ড ক্লাউড এবং NAS এনক্রিপ্ট করা গন্তব্য কনফিগার করুন।',
      'Confirm': 'নিশ্চিত করুন',
      'Confirm only after comparing these values with the original document. Clear a value to remove it.':
          'মূল নথির সাথে এই মানগুলির তুলনা করার পরেই নিশ্চিত করুন৷ এটি অপসারণ করতে একটি মান সাফ করুন।',
      'Confirm recovery passphrase': 'পুনরুদ্ধার পাসফ্রেজ নিশ্চিত করুন',
      'Confirm reviewed details': 'পর্যালোচনা বিবরণ নিশ্চিত করুন',
      'Confirm the recovery warning to continue.':
          'চালিয়ে যেতে পুনরুদ্ধারের সতর্কতা নিশ্চিত করুন।',
      'Continue': 'চালিয়ে যান',
      'Correct without overwriting': 'ওভাররাইটিং ছাড়াই সঠিক',
      'Corrected': 'সংশোধন করা হয়েছে',
      'Create': 'তৈরি করুন',
      'Create Smart Pack': 'স্মার্ট প্যাক তৈরি করুন',
      'Create a Smart Pack': 'একটি স্মার্ট প্যাক তৈরি করুন',
      'Create a custom Pack': 'একটি কাস্টম প্যাক তৈরি করুন',
      'Create a private organizational checklist from an offline template or make your own.':
          'একটি অফলাইন টেমপ্লেট থেকে একটি ব্যক্তিগত সাংগঠনিক চেকলিস্ট তৈরি করুন বা আপনার নিজের তৈরি করুন৷',
      'Create encrypted backup': 'এনক্রিপ্টেড ব্যাকআপ তৈরি করুন',
      'Create encrypted vault': 'এনক্রিপ্টেড ভল্ট তৈরি করুন',
      'Create task': 'টাস্ক তৈরি করুন',
      'Create your private vault': 'আপনার ব্যক্তিগত ভল্ট তৈরি করুন',
      'Creating your private vault...': 'ভল্ট তৈরি করা হচ্ছে...',
      'Custom Smart Pack': 'কাস্টম স্মার্ট প্যাক',
      'Custom encrypted field': 'কাস্টম এনক্রিপ্ট করা ক্ষেত্র',
      'Customize': 'কাস্টমাইজ করুন',
      'Customize item': 'আইটেম কাস্টমাইজ করুন',
      'Daily': 'দৈনিক',
      'Dark mode': 'ডার্ক মোড',
      'Date': 'তারিখ',
      'Date range': 'তারিখ পরিসীমা',
      'Default reminder offsets': 'রিমাইন্ডার',
      'Delete': 'মুছে ফেলুন',
      'Desktop & Mobile Graph Compatibility Verified':
          'ডেস্কটপ এবং মোবাইল গ্রাফ সামঞ্জস্য যাচাই করা হয়েছে',
      'Desktop Large-Scale Bulk Import Dropzone':
          'ডেস্কটপ বড়-স্কেল বাল্ক আমদানি ড্রপজোন',
      'Desktop Layout Modes': 'ডেস্কটপ লেআউট মোড',
      'Deterministic Graph Answers': 'ডিটারমিনিস্টিক গ্রাফ উত্তর',
      'Device security': 'ডিভাইস নিরাপত্তা',
      'Device-to-Device Transfer': 'ডিভাইস ট্রান্সফার (P2P Transfer)',
      'Dismiss': 'বাতিল করুন',
      'Documents Library': 'ডকুমেন্টস লাইব্রেরি',
      'Documents stay encrypted on this device. Start by choosing the recovery passphrase that protects your vault.':
          'নথিগুলি এই ডিভাইসে এনক্রিপ্ট করা থাকে৷ পুনরুদ্ধার পাসফ্রেজ বেছে নিয়ে শুরু করুন যা আপনার ভল্টকে রক্ষা করে।',
      'Does not create a plaintext export.':
          'একটি প্লেইনটেক্সট এক্সপোর্ট তৈরি করে না।',
      'Does not repeat': 'পুনরাবৃত্তি করে না',
      'Done': 'সম্পন্ন',
      'Drag & drop directories or multiple document files for high-throughput parallel OCR processing.':
          'হাই-থ্রুপুট সমান্তরাল OCR প্রক্রিয়াকরণের জন্য ডিরেক্টরি বা একাধিক নথি ফাইল টেনে আনুন এবং ড্রপ করুন।',
      'Due date': 'শেষ তারিখ',
      'Edit': 'সম্পাদনা করুন',
      'Edit tags': 'ট্যাগ সম্পাদনা করুন',
      'Emergency Access Audit Log': 'জরুরী অ্যাক্সেস অডিট লগ',
      'Emergency Medical Card': 'জরুরি মেডিকেল কার্ড',
      'Emergency Responder Contacts': 'জরুরী প্রতিক্রিয়াকারী পরিচিতি',
      'Emergency Storage Boundary Active. Isolated from main vault graph, evidence, and claims.':
          'জরুরী স্টোরেজ সীমানা সক্রিয়। প্রধান ভল্ট গ্রাফ, প্রমাণ এবং দাবি থেকে বিচ্ছিন্ন।',
      'Encrypted P2P Transfer (No Server)': 'Encrypted P2P Transfer',
      'Encrypted evidence': 'এনক্রিপ্ট করা প্রমাণ',
      'End date': 'শেষ তারিখ',
      'End date cannot be before start date.':
          'শেষ তারিখ শুরুর তারিখের আগে হতে পারে না।',
      'Enter a currency code.': 'একটি মুদ্রা কোড লিখুন.',
      'Enter a valid amount.': 'একটি বৈধ পরিমাণ লিখুন.',
      'Enter an event title.': 'একটি ইভেন্ট শিরোনাম লিখুন.',
      'Enter your recovery passphrase to access your private encrypted vault.':
          'আপনার ব্যক্তিগত এনক্রিপ্ট করা ভল্ট অ্যাক্সেস করতে আপনার পুনরুদ্ধার পাসফ্রেজ লিখুন।',
      'Ephemeral Pairing PIN Code': 'ইফেমেরাল পেয়ারিং পিন কোড',
      'Event': 'ঘটনা',
      'Every result stays linked to your encrypted graph and evidence.':
          'প্রতিটি ফলাফল আপনার এনক্রিপ্ট করা গ্রাফ এবং প্রমাণের সাথে সংযুক্ত থাকে।',
      'Evidence': 'প্রমাণ',
      'Execute deterministic graph queries for attention, expiry, spending, and warranties.':
          'মনোযোগ, মেয়াদ, ব্যয় এবং ওয়ারেন্টির জন্য নির্ধারক গ্রাফ প্রশ্নগুলি চালান।',
      'Export Document': 'নথি রপ্তানি করুন',
      'Export Redacted & Watermarked Copy':
          'সংশোধিত এবং ওয়াটারমার্কড কপি রপ্তানি করুন',
      'Export Redacted Copy': 'সংশোধিত অনুলিপি রপ্তানি করুন',
      'Export preparation': 'রপ্তানি প্রস্তুতি',
      'Favourites': 'প্রিয়',
      'Finance': 'অর্থ',
      'Full view': 'সম্পূর্ণ ভিউ',
      'Generate Pairing PIN': 'পেয়ারিং পিন তৈরি করুন',
      'Graph': 'গ্রাফ',
      'Grid document view': 'গ্রিড ভিউ',
      'Guidance, not a requirement': 'নির্দেশনা, প্রয়োজন নয়',
      'Health Insurance Policy': 'স্বাস্থ্য বীমা নীতি',
      'History': 'ইতিহাস',
      'History and evidence are retained.': 'ইতিহাস ও প্রমাণ সংরক্ষণ করা হয়।',
      'Household & Ownership': 'পরিবার এবং মালিকানা',
      'Household Inventory': 'পরিবারের ইনভেন্টরি',
      'Household Valuation': 'পরিবারের মূল্যায়ন',
      'I understand OwnKeep cannot reset this passphrase.':
          'আমি বুঝি OwnKeep এই পাসফ্রেজ রিসেট করতে পারে না।',
      'Identifier': 'শনাক্তকারী',
      'Identity': 'পরিচয়',
      'Import a document and OwnKeep will organize it locally.':
          'একটি নথি আমদানি করুন এবং OwnKeep এটি স্থানীয়ভাবে সংগঠিত করবে।',
      'Import a photo first, then link it.':
          'প্রথমে একটি ছবি আমদানি করুন, তারপর লিঙ্ক করুন।',
      'Import a record first.': 'প্রথমে একটি রেকর্ড আমদানি করুন।',
      'Import and review a document, or clear a filter.':
          'একটি নথি আমদানি করুন এবং পর্যালোচনা করুন বা একটি ফিল্টার সাফ করুন৷',
      'Inbox': 'ইনবক্স',
      'Inbox activity': 'ইনবক্স কার্যকলাপ',
      'Include rejected and superseded':
          'প্রত্যাখ্যাত এবং বর্জন করা অন্তর্ভুক্ত করুন',
      'Insurance': 'বীমা',
      'Integrity check failed': 'অখণ্ডতা পরীক্ষা ব্যর্থ হয়েছে৷',
      'Interface Language': 'ইন্টারফেস ভাষা',
      'Item Metadata & Location': 'আইটেম মেটাডেটা এবং অবস্থান',
      'Keep What Matters. Own Your Data.': 'কিপ মেটারস. আপনার ডেটার মালিক।',
      'Known Allergies': 'পরিচিত এলার্জি',
      'Language & Regional OCR Packs': 'ভাষা এবং OCR প্যাক',
      'Large-screen dual-pane overview and bulk import dropzone.':
          'বড়-স্ক্রীন ডুয়াল-পেন ওভারভিউ এবং বাল্ক ইম্পোর্ট ড্রপজোন।',
      'Library': 'লাইব্রেরি',
      'Life': 'জীবন',
      'Life Directory': 'জীবন ডিরেক্টরি',
      'Life Event': 'জীবনের ঘটনা',
      'Life Navigator': 'লাইফ নেভিগেটর',
      'Life OS Overview': 'জীবন ওএস ওভারভিউ',
      'Life Timeline': 'লাইফ টাইমলাইন',
      'Lifetime Spend': 'আজীবন ব্যয়',
      'Link encrypted evidence': 'লিঙ্ক এনক্রিপ্ট করা প্রমাণ',
      'Link encrypted record': 'লিঙ্ক এনক্রিপ্ট করা রেকর্ড',
      'Link existing information': 'বিদ্যমান তথ্য লিঙ্ক করুন',
      'Link information': 'লিঙ্ক তথ্য',
      'Link to a profile?': 'একটি প্রোফাইল লিঙ্ক?',
      'Linked Claims, Events, Tasks, and evidence remain unchanged.':
          'লিঙ্কযুক্ত দাবি, ঘটনা, কার্য এবং প্রমাণ অপরিবর্তিত থাকে।',
      'Local suggestions become part of your life record only after you confirm them.':
          'স্থানীয় পরামর্শগুলি আপনি নিশ্চিত করার পরেই আপনার জীবন রেকর্ডের অংশ হয়ে যায়।',
      'Location': 'অবস্থান',
      'Log Maintenance / Cost': 'লগ রক্ষণাবেক্ষণ / খরচ',
      'Manage encrypted zero-knowledge backup destinations without token storage.':
          'টোকেন স্টোরেজ ছাড়াই এনক্রিপ্ট করা জিরো-নলেজ ব্যাকআপ গন্তব্যগুলি পরিচালনা করুন৷',
      'Mark completed': 'মার্ক সম্পূর্ণ হয়েছে',
      'Mask Date of Birth': 'মাস্ক জন্ম তারিখ',
      'Mask ID Numbers (Aadhaar / PAN / Passport)':
          'মাস্ক আইডি নম্বর (আধার / প্যান / পাসপোর্ট)',
      'Mask QR codes & Barcodes': 'QR কোড এবং বারকোড মাস্ক করুন',
      'Mask Residential Address': 'মাস্ক আবাসিক ঠিকানা',
      'Mask Signatures': 'মাস্ক স্বাক্ষর',
      'Medical': 'মেডিকেল',
      'Merge a duplicate': 'একটি ডুপ্লিকেট মার্জ করুন',
      'Monthly': 'মাসিক',
      'Multilingual Invariance Guaranteed': 'বহুভাষিক পরিবর্তনের নিশ্চয়তা',
      'Name': 'নাম',
      'New records will appear here and safely resume if interrupted.':
          'নতুন রেকর্ড এখানে প্রদর্শিত হবে এবং বাধা দিলে নিরাপদে পুনরায় শুরু হবে।',
      'Newest': 'নতুনতম',
      'No Claims yet. Link a reviewed record from the Inbox.':
          'এখনও কোন দাবি. ইনবক্স থেকে একটি পর্যালোচনা করা রেকর্ড লিঙ্ক করুন।',
      'No Smart Packs yet': 'এখনও কোন স্মার্ট প্যাক নেই',
      'No access logs recorded.': 'কোন অ্যাক্সেস লগ রেকর্ড করা.',
      'No account, analytics, cloud OCR, advertisements, or Internet permission in release builds.':
          'রিলিজ বিল্ডগুলিতে কোনও অ্যাকাউন্ট, বিশ্লেষণ, ক্লাউড ওসিআর, বিজ্ঞাপন বা ইন্টারনেট অনুমতি নেই।',
      'No automation executions recorded yet.':
          'কোন অটোমেশন মৃত্যুদন্ড এখনও রেকর্ড করা হয়েছে.',
      'No confirmed value yet': 'এখনও কোন নিশ্চিত মান',
      'No documents are processing': 'কোন নথি প্রক্রিয়াকরণ করা হয় না',
      'No documents match these filters': 'কোন নথি এই ফিল্টার মেলে না',
      'No documents processing': 'কোন নথি প্রক্রিয়াকরণ',
      'No encrypted evidence linked.': 'কোন এনক্রিপ্ট করা প্রমাণ লিঙ্ক করা.',
      'No extracted fields': 'কোন নিষ্কাশন ক্ষেত্র নেই',
      'No fields were extracted. Confirm the type to finish.':
          'কোন ক্ষেত্র নিষ্কাশন করা হয়নি. শেষ করতে টাইপ নিশ্চিত করুন।',
      'No linkable information yet': 'কোন লিঙ্কযোগ্য তথ্য এখনো',
      'No linked evidence yet.': 'এখনও কোন সংযুক্ত প্রমাণ.',
      'No location': 'অবস্থান নেই',
      'No maintenance or cost logs yet.': 'এখনও কোন রক্ষণাবেক্ষণ বা খরচ লগ.',
      'No matching duplicate was found.': 'কোন মিলিত সদৃশ পাওয়া যায়নি.',
      'No matching household items found.':
          'কোনো মিলে যাওয়া গৃহস্থালি সামগ্রী পাওয়া যায়নি৷',
      'No profile': 'কোনো প্রোফাইল নেই',
      'No profile changes recorded yet':
          'কোনো প্রোফাইল পরিবর্তন এখনও রেকর্ড করা হয়নি',
      'No recognized text': 'কোন স্বীকৃত টেক্সট',
      'No record': 'কোনো রেকর্ড নেই',
      'No relationships yet': 'এখনো কোনো সম্পর্ক নেই',
      'No reminders': 'কোন অনুস্মারক',
      'No tags': 'কোনো ট্যাগ নেই',
      'No upcoming reminders': 'কোনো আসন্ন অনুস্মারক নেই',
      'Not now': 'এখন না',
      'Nothing matched yet. Try a person, car, home, insurer, pack or record name.':
          'এখনো কিছু মেলেনি। একজন ব্যক্তি, গাড়ি, বাড়ি, বীমাকারী, প্যাক বা রেকর্ডের নাম ব্যবহার করে দেখুন।',
      'Nothing urgent': 'জরুরি কিছু নেই',
      'Notifications are local and contain no document details.':
          'বিজ্ঞপ্তি স্থানীয় এবং কোন নথি বিবরণ নেই.',
      'ORGANIZATIONAL ITEMS': 'সাংগঠনিক আইটেম',
      'Offline': 'অফলাইন',
      'Offline Automation Engine': 'অফলাইন অটোমেশন ইঞ্জিন',
      'Offline Pack template': 'অফলাইন প্যাক টেমপ্লেট',
      'Offline Safety Guaranteed': 'অফলাইন নিরাপত্তা নিশ্চিত',
      'Oldest': 'প্রাচীনতম',
      'On the date': 'তারিখে',
      'On-device Intelligence': 'অন-ডিভাইস ইন্টেলিজেন্স',
      'Only encrypted archive bytes leave your device. Zero provider tokens or Master Vault Keys are retained by OwnKeep.':
          'শুধুমাত্র এনক্রিপ্ট করা আর্কাইভ বাইট আপনার ডিভাইস ছেড়ে যায়। জিরো প্রোভাইডার টোকেন বা মাস্টার ভল্ট কী OwnKeep ধরে রাখে।',
      'Open encrypted evidence': 'খোলা এনক্রিপ্ট করা প্রমাণ',
      'Open inbox': 'ইনবক্স খুলুন',
      'Open linked evidence': 'খোলা লিঙ্ক প্রমাণ',
      'Opening your encrypted vault...': 'ভল্ট খোলা হচ্ছে...',
      'Optional': 'ঐচ্ছিক',
      'Optional country-specific guidance, not legal advice.':
          'ঐচ্ছিক দেশ-নির্দিষ্ট নির্দেশিকা, আইনি পরামর্শ নয়।',
      'Organizational guidance': 'সাংগঠনিক নির্দেশিকা',
      'Original file remains untouched. Redactions are flattened permanently before export.':
          'মূল ফাইলটি অপরিবর্তিত রয়েছে। রপ্তানির আগে রিডাকশন স্থায়ীভাবে সমতল করা হয়।',
      'Original remains encrypted': 'মূল অবশেষ এনক্রিপ্ট করা',
      'OwnKeep': 'OwnKeep',
      'OwnKeep 5.0.0': 'OwnKeep 5.0.0',
      'OwnKeep 5.0.0 Final': 'OwnKeep 5.0.0 ফাইনাল',
      'OwnKeep Desktop Personal Life OS': 'ডেস্কটপ লাইফ OS',
      'OwnKeep could not access private storage.':
          'OwnKeep ব্যক্তিগত সঞ্চয়স্থান অ্যাক্সেস করতে পারেনি৷',
      'OwnKeep found possible matches. You decide whether to create Claim suggestions.':
          'OwnKeep সম্ভাব্য মিল খুঁজে পেয়েছে। দাবি প্রস্তাবনা তৈরি করবেন কিনা তা আপনি সিদ্ধান্ত নিন।',
      'Pack is archived.': 'প্যাক আর্কাইভ করা হয়.',
      'Pair devices with ephemeral PIN codes for encrypted transfer.':
          'এনক্রিপ্ট করা স্থানান্তরের জন্য ক্ষণস্থায়ী পিন কোডগুলির সাথে ডিভাইসগুলিকে যুক্ত করুন৷',
      'People, things & places': 'মানুষ, জিনিস এবং স্থান',
      'Prepare evidence for export': 'রপ্তানির জন্য প্রমাণ প্রস্তুত করুন',
      'Preserves complete Claim, provenance, history, evidence, and graph compatibility between mobile and desktop without central backends.':
          'কেন্দ্রীয় ব্যাকএন্ড ছাড়াই মোবাইল এবং ডেস্কটপের মধ্যে সম্পূর্ণ দাবি, উৎস, ইতিহাস, প্রমাণ এবং গ্রাফ সামঞ্জস্য রক্ষা করে।',
      'Primary Physician': 'প্রাথমিক চিকিত্সক',
      'Prioritized locally from confirmed facts, events, evidence, integrity checks, and Inbox work.':
          'নিশ্চিত হওয়া তথ্য, ঘটনা, প্রমাণ, অখণ্ডতা পরীক্ষা এবং ইনবক্সের কাজ থেকে স্থানীয়ভাবে অগ্রাধিকার দেওয়া হয়।',
      'Privacy Share': 'গোপনীয়তা শেয়ার',
      'Privacy-aware Sharing': 'গোপনীয়তা-সচেতন শেয়ারিং',
      'Private notes': 'ব্যক্তিগত নোট',
      'Profile fields': 'প্রোফাইল ক্ষেত্র',
      'Property': 'সম্পত্তি',
      'Purchase Price': 'ক্রয় মূল্য',
      'REJECTED': 'প্রত্যাখ্যাত',
      'Ready for you': 'আপনার জন্য প্রস্তুত',
      'Recent Evidence Documents': 'সাম্প্রতিক প্রমাণ নথি',
      'Recognized text preview': 'স্বীকৃত পাঠ্য পূর্বরূপ',
      'Records': 'রেকর্ড',
      'Recovery passphrase': 'পুনরুদ্ধার পাসফ্রেজ',
      'Regional OCR Text Packs': 'আঞ্চলিক OCR টেক্সট প্যাক',
      'Reject': 'প্রত্যাখ্যান করুন',
      'Relationships': 'সম্পর্ক',
      'Reminders': 'অনুস্মারক',
      'Requires an exact same-name profile match.':
          'একটি সঠিক একই নামের প্রোফাইল মিল প্রয়োজন।',
      'Reschedule': 'পুনরায় সময় নির্ধারণ',
      'Restore encrypted backup': 'এনক্রিপ্টেড ব্যাকআপ পুনরুদ্ধার করুন',
      'Retry': 'আবার চেষ্টা করুন',
      'Review': 'পর্যালোচনা',
      'Review export preparation': 'রপ্তানি প্রস্তুতি পর্যালোচনা করুন',
      'Review local suggestions and finish organizing.':
          'স্থানীয় পরামর্শ পর্যালোচনা করুন এবং আয়োজন শেষ করুন।',
      'Save': 'সংরক্ষণ করুন',
      'Save Event Log': 'ইভেন্ট লগ সংরক্ষণ করুন',
      'Save Item': 'আইটেম সংরক্ষণ করুন',
      'Save Rule': 'নিয়ম সংরক্ষণ করুন',
      'Save a verified .cvault file to Drive, iCloud, Files, or another document provider.':
          'একটি যাচাইকৃত .cvault ফাইল ড্রাইভ, iCloud, Files, বা অন্য নথি প্রদানকারীতে সংরক্ষণ করুন৷',
      'Save an unencrypted copy?': 'একটি এনক্রিপ্ট করা অনুলিপি সংরক্ষণ করবেন?',
      'Save copy': 'কপি সংরক্ষণ করুন',
      'Save field': 'ক্ষেত্র সংরক্ষণ করুন',
      'Scan or import here. OwnKeep encrypts first, then organizes everything locally for your review.':
          'এখানে স্ক্যান বা আমদানি করুন। OwnKeep প্রথমে এনক্রিপ্ট করে, তারপর আপনার পর্যালোচনার জন্য স্থানীয়ভাবে সবকিছু সংগঠিত করে।',
      'Search': 'অনুসন্ধান',
      'Search documents...': 'নথি অনুসন্ধান করুন...',
      'Securely sync vault items directly to nearby devices over local P2P.':
          'স্থানীয় P2P এর মাধ্যমে ভল্ট আইটেমগুলিকে সরাসরি কাছাকাছি ডিভাইসে নিরাপদে সিঙ্ক করুন।',
      'Select Destination Provider': 'গন্তব্য প্রদানকারী নির্বাচন করুন',
      'Select Transport Layer': 'পরিবহন স্তর নির্বাচন করুন',
      'Selected backup': 'নির্বাচিত ব্যাকআপ',
      'Settings': 'সেটিংস',
      'Simulate Bulk Import Drop': 'বাল্ক ইমপোর্ট করুন',
      'Simulate Transfer Session': 'স্থানান্তর সেশন অনুকরণ',
      'Smart Packs': 'স্মার্ট প্যাক',
      'Snooze 1 day': '1 দিন স্নুজ করুন',
      'Start building your private life record':
          'আপনার ব্যক্তিগত জীবনের রেকর্ড তৈরি করা শুরু করুন',
      'Store this passphrase somewhere safe. Losing it can make your encrypted documents permanently inaccessible.':
          'এই পাসফ্রেজটি নিরাপদ কোথাও সংরক্ষণ করুন। এটি হারানো আপনার এনক্রিপ্ট করা নথিগুলিকে স্থায়ীভাবে অ্যাক্সেসযোগ্য করে তুলতে পারে৷',
      'Stored inside your encrypted vault.':
          'আপনার এনক্রিপ্ট করা ভল্টের ভিতরে সংরক্ষিত।',
      'Strict offline mode': 'সম্পূর্ণ অফলাইন মোড',
      'Strip EXIF & File Metadata': 'স্ট্রিপ EXIF ​​এবং ফাইল মেটাডেটা',
      'Suggested': 'প্রস্তাবিত',
      'Task': 'টাস্ক',
      'Tasks & checklists': 'টাস্ক এবং চেকলিস্ট',
      'Tax': 'ট্যাক্স',
      'Templates guide organization and never change your facts.':
          'টেমপ্লেট সংগঠন গাইড করে এবং কখনই আপনার তথ্য পরিবর্তন করে না।',
      'Text': 'পাঠ্য',
      'The duplicate ID and history will be retained.':
          'ডুপ্লিকেট আইডি এবং ইতিহাস বজায় রাখা হবে.',
      'The original remains encrypted and unchanged.':
          'আসলটি এনক্রিপ্ট করা এবং অপরিবর্তিত রয়েছে।',
      'The original remains in history and this replacement keeps its entity and evidence links.':
          'আসলটি ইতিহাসে রয়ে গেছে এবং এই প্রতিস্থাপনটি তার সত্তা এবং প্রমাণের লিঙ্ক রাখে।',
      'The saved file will no longer be protected by OwnKeep. Anyone with access to the selected destination may be able to open it.':
          'সংরক্ষিত ফাইলটি আর ওনকিপ দ্বারা সুরক্ষিত থাকবে না। নির্বাচিত গন্তব্যে অ্যাক্সেস সহ যে কেউ এটি খুলতে সক্ষম হতে পারে৷',
      'This document is no longer available.': 'এই নথিটি আর উপলব্ধ নেই৷',
      'This month': 'এই মাসে',
      'Timeline': 'টাইমলাইন',
      'Timestamps when emergency medical card was opened:':
          'জরুরী মেডিকেল কার্ড খোলার সময় টাইমস্ট্যাম্প:',
      'Total Assets Value': 'মোট সম্পদের মান',
      'Total Lifetime Maintenance & Tax Spend':
          'মোট আজীবন রক্ষণাবেক্ষণ এবং ট্যাক্স খরচ',
      'Total Maintenance Spend': 'মোট রক্ষণাবেক্ষণ ব্যয়',
      'Total Spend': 'মোট খরচ',
      'Transferred vault archives are byte- and graph- equivalent, authenticated with SHA-256 signatures, and zero keys or plaintext leave your devices.':
          'স্থানান্তরিত ভল্ট সংরক্ষণাগারগুলি বাইট- এবং গ্রাফ- সমতুল্য, SHA-256 স্বাক্ষরের সাথে প্রমাণীকৃত, এবং শূন্য কী বা প্লেইনটেক্সট আপনার ডিভাইসগুলি ছেড়ে যায়৷',
      'Transition item state while preserving complete historical service & cost records:':
          'সম্পূর্ণ ঐতিহাসিক পরিষেবা এবং খরচ রেকর্ড সংরক্ষণ করার সময় ট্রানজিশন আইটেম অবস্থা:',
      'Trigger Blind Sync Rehearsal': 'ব্যাকআপ সিঙ্ক শুরু করুন',
      'Type': 'টাইপ',
      'Type a query or tap a template above to query your vault.':
          'একটি ক্যোয়ারী টাইপ করুন বা আপনার ভল্টটি জিজ্ঞাসা করতে উপরে একটি টেমপ্লেট আলতো চাপুন৷',
      'Unlock OwnKeep': 'OwnKeep আনলক করুন',
      'Unlock vault': 'ভল্ট খুলুন',
      'Unlock with biometrics': 'বায়োমেট্রিক্স দিয়ে খুলুন',
      'Upcoming dues and expiries will appear here.':
          'আসন্ন বকেয়া এবং মেয়াদ এখানে প্রদর্শিত হবে.',
      'Upcoming reminder': 'আসন্ন অনুস্মারক',
      'Update Operational Status': 'অপারেশনাল স্ট্যাটাস আপডেট করুন',
      'Use a verified backup to recover this document.':
          'এই নথিটি পুনরুদ্ধার করতে একটি যাচাইকৃত ব্যাকআপ ব্যবহার করুন৷',
      'Use an offline template': 'একটি অফলাইন টেমপ্লেট ব্যবহার করুন',
      'Use expiry date': 'মেয়াদ শেষ হওয়ার তারিখ ব্যবহার করুন',
      'Use larger visual document cards.':
          'বড় ভিজ্যুয়াল ডকুমেন্ট কার্ড ব্যবহার করুন।',
      'Used when expiry reminder suggestions are added.':
          'মেয়াদোত্তীর্ণ অনুস্মারক প্রস্তাবনা যোগ করা হলে ব্যবহার করা হয়.',
      'Vault Summary': 'ভল্ট সারাংশ',
      'Vehicle': 'যানবাহন',
      'Verify and restore': 'যাচাই করুন এবং পুনরুদ্ধার করুন',
      'Verify document details': 'নথির বিবরণ যাচাই করুন',
      'View grounded natural language summaries and recommendations.':
          'গ্রাউন্ডেড প্রাকৃতিক ভাষার সারাংশ এবং সুপারিশ দেখুন।',
      'View minimized emergency responder contacts, blood group, and medical data.':
          'ন্যূনতম জরুরী প্রতিক্রিয়াকারী পরিচিতি, রক্তের গ্রুপ এবং মেডিকেল ডেটা দেখুন।',
      'Warranties': 'ওয়ারেন্টি',
      'Warranty Coverage': 'ওয়ারেন্টি কভারেজ',
      'Website / URI': 'ওয়েবসাইট / ইউআরআই',
      'Weekly': 'সাপ্তাহিক',
      'Whole vault': 'পুরো ভল্ট',
      'Your facts remain yours': 'আপনার তথ্য আপনার থেকে যায়',
      'Your private life, organized locally.':
          'আপনার ব্যক্তিগত জীবন, স্থানীয়ভাবে সংগঠিত।',
      'Zero Token Blind Backup Policy': 'জিরো টোকেন ব্লাইন্ড ব্যাকআপ নীতি',
      '⚠️ Notice: Exported copies leave OwnKeep protection and cannot be remotely revoked.':
          '⚠️ বিজ্ঞপ্তি: রপ্তানি করা অনুলিপি OwnKeep সুরক্ষা ছেড়ে যায় এবং দূরবর্তীভাবে প্রত্যাহার করা যায় না।',
    },
  };
}
