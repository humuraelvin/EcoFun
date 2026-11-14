/// EcoFun's Privacy Policy and Terms of Use, in English and Kinyarwanda.
///
/// Each document is a list of (heading, paragraphs). Bump [legalUpdated] whenever the text changes.
library;

const legalUpdated = (en: '14 November 2026', rw: '14 Ugushyingo 2026');

typedef LegalSection = (String heading, List<String> paragraphs);

const privacyEn = <LegalSection>[
  ('Who we are', [
    'EcoFun is a free mobile app that helps people in Rwanda learn about the environment, sort their waste correctly '
        'and take small daily actions. It was created by a student research team at Isomo Academy. This policy explains '
        'what information EcoFun keeps, why, and the choices you have.',
  ]),
  ('What we collect', [
    'Account details: your name, email address and password. Your password is stored encrypted and nobody at EcoFun can read it. '
        'If you sign in with Google, we receive your name, email and profile photo from Google.',
    'What you share: your profile photo, the photos and captions you post in the Community, your comments and ratings, '
        'and the messages you send to support.',
    'What you do in the app: stories you read, quiz answers, missions, waste scans, disposal photos, points, streaks and your chosen language.',
    'We do not collect your location, contacts, phone number or anything stored on your phone. The camera is used only when you choose to take a photo.',
  ]),
  ('Why we use it', [
    'To run your account and keep you signed in.',
    'To award points, show the leaderboard and keep your streak.',
    'To identify waste in your photos and check disposal photos with AI.',
    'To send you important emails (sign-up codes, password changes) and, only if you keep it on, streak emails.',
    'To keep the Community safe: reviewing reported posts and answering support messages.',
    'To understand, in total numbers only, how EcoFun is used so we can improve it. We never sell your information or show you ads.',
  ]),
  ('Who else sees it', [
    'Other members see only your name, profile photo, points and the posts, comments and ratings you share. Your email is never shown to other members.',
    'EcoFun admins can see account details and activity in order to keep the app safe and to answer support messages.',
    'Trusted services that run EcoFun for us: Supabase (secure database and file storage), NVIDIA AI (reads waste photos and '
        'writes quiz questions), Google Translate (translates stories between English and Kinyarwanda) and Gmail (sends EcoFun emails). '
        'They receive only what they need to do that job.',
  ]),
  ('How long we keep it', [
    'We keep your information while your account exists. When you delete your account (Profile → Delete account), your profile, '
        'photos, posts, scans, points and history are permanently deleted. Accounts that never confirm their email are removed automatically.',
  ]),
  ('Your rights', [
    'Under Rwanda\'s law on the protection of personal data and privacy (Law Nº 058/2021), you can ask to see, correct or delete your '
        'information. You can change your name and photo in Profile, turn streak emails off, and delete your account at any time. '
        'For anything else, use Contact support in your profile.',
  ]),
  ('Keeping it safe', [
    'Information travels over encrypted connections, and every request is checked so members can only reach their own private data. '
        'No system is perfect, so please use a strong password that you do not use anywhere else.',
  ]),
  ('Children', [
    'EcoFun is made for everyone who wants to protect the environment. Children under 16 should use it with a parent\'s or teacher\'s permission.',
  ]),
  ('Changes', [
    'If this policy changes, we will update the date below and tell you in the app.',
  ]),
];

const termsEn = <LegalSection>[
  ('Agreeing to these terms', [
    'By creating an account or using EcoFun, you agree to these Terms of Use and to the Privacy Policy. If you do not agree, please do not use the app.',
  ]),
  ('Your account', [
    'Use your real name and an email address you own. Keep your password private; you are responsible for what happens on your account. One person, one account.',
  ]),
  ('Community rules', [
    'Share photos that are about the environment: waste sorting, clean-ups, trees, recycling and similar actions.',
    'Do not post anything offensive, violent, sexual, hateful, political, misleading or unrelated, and do not post photos of other people without their permission.',
    'Do not spam, cheat for points (for example with fake or repeated photos) or harass other members.',
    'Members can report posts. Admins may remove any post that breaks these rules and may suspend or permanently ban accounts that break them.',
  ]),
  ('Points and rewards', [
    'Points show your progress and your place on the leaderboard. They have no cash value and cannot be sold or exchanged. '
        'Admins may correct points that were earned by mistake or by cheating.',
  ]),
  ('AI results and information', [
    'Waste identification, disposal checks and quizzes are produced by AI and may sometimes be wrong. Always follow the instructions '
        'of your local authorities (City of Kigali, REMA, your sector) on how to sort and dispose of waste.',
    'News stories belong to their publishers. EcoFun shows a short summary and links to the original article.',
  ]),
  ('Your content', [
    'You keep ownership of the photos and text you share. By posting them, you allow EcoFun to show them to other members inside the app. '
        'You can delete your posts, and deleting your account removes them all.',
  ]),
  ('The app itself', [
    'EcoFun is free and is provided "as is". We work hard to keep it running and correct, but we cannot promise it will always be available or free of errors. '
        'We may change, pause or stop features at any time.',
  ]),
  ('Changes and contact', [
    'We may update these terms. When we do, we will change the date below and tell you in the app; continuing to use EcoFun means you accept the new terms. '
        'These terms follow the laws of the Republic of Rwanda. Questions? Use Contact support in your profile.',
  ]),
];

const privacyRw = <LegalSection>[
  ('Abo turi bo', [
    'EcoFun ni porogaramu ya telefoni y\'ubuntu ifasha abantu bo mu Rwanda kumenya ibijyanye n\'ibidukikije, gutandukanya imyanda neza '
        'no gukora ibikorwa bito bya buri munsi. Yakozwe n\'itsinda ry\'abanyeshuri bakora ubushakashatsi muri Isomo Academy. '
        'Iyi politiki isobanura amakuru EcoFun ibika, impamvu iyabika, n\'uburenganzira ufite.',
  ]),
  ('Amakuru dukusanya', [
    'Amakuru ya konti: izina ryawe, imeyili n\'ijambobanga. Ijambobanga ribikwa mu buryo bw\'ibanga kandi nta muntu wo muri EcoFun ushobora kuribona. '
        'Niwinjira ukoresheje Google, duhabwa izina, imeyili n\'ifoto yawe na Google.',
    'Ibyo usangiza: ifoto ya porofayili, amafoto n\'ibisobanuro ushyira mu Muryango, ibitekerezo n\'amanota utanga, n\'ubutumwa woherereza ubufasha.',
    'Ibyo ukorera muri porogaramu: inkuru usoma, ibisubizo by\'ibibazo, ibikorwa, isuzuma ry\'imyanda, amafoto yo kujugunya imyanda, amanota, '
        'iminsi ikurikirana n\'ururimi wahisemo.',
    'Ntidukusanya aho uherereye, nimero zawe, nimero ya telefoni cyangwa ibindi biri muri telefoni yawe. Kamera ikoreshwa gusa iyo uhisemo gufata ifoto.',
  ]),
  ('Impamvu tuyakoresha', [
    'Gukoresha konti yawe no kukugumisha winjiye.',
    'Kuguha amanota, kwerekana urutonde rw\'abahize abandi no kubika iminsi ukurikiranya.',
    'Kumenya ubwoko bw\'imyanda iri ku mafoto yawe no kugenzura amafoto yo kujugunya imyanda hakoreshejwe AI.',
    'Kukoherereza imeyili z\'ingenzi (kode yo kwiyandikisha, guhindura ijambobanga) kandi, niba ubyemeye, imeyili z\'iminsi ukurikiranya.',
    'Kurinda Umuryango: gusuzuma inyandiko zatanzweho raporo no gusubiza ubutumwa bw\'ubufasha.',
    'Kumenya, mu mibare rusange gusa, uko EcoFun ikoreshwa kugira ngo tuyinoze. Ntitwigera tugurisha amakuru yawe cyangwa ngo tukwereke amatangazo yamamaza.',
  ]),
  ('Abandi bayabona', [
    'Abandi banyamuryango babona izina ryawe, ifoto ya porofayili, amanota yawe n\'ibyo usangiza gusa. Imeyili yawe ntigaragazwa abandi banyamuryango.',
    'Abayobozi ba EcoFun bashobora kubona amakuru ya konti n\'ibikorwa byayo kugira ngo barinde umutekano wa porogaramu kandi basubize ubutumwa bw\'ubufasha.',
    'Serivisi zizewe zidufasha gukoresha EcoFun: Supabase (ububiko bwizewe bw\'amakuru n\'amafoto), NVIDIA AI (isoma amafoto y\'imyanda kandi ikandika ibibazo), '
        'Google Translate (ihindura inkuru hagati y\'Icyongereza n\'Ikinyarwanda) na Gmail (yohereza imeyili za EcoFun). '
        'Zihabwa gusa ibyo zikeneye kugira ngo zikore ako kazi.',
  ]),
  ('Igihe tuyabika', [
    'Tubika amakuru yawe igihe cyose konti yawe ikiriho. Iyo usibye konti yawe (Porofayili → Siba konti), porofayili, amafoto, inyandiko, '
        'isuzuma, amanota n\'amateka yawe bisibwa burundu. Konti zitemeje imeyili zisibwa ku buryo bwikora.',
  ]),
  ('Uburenganzira bwawe', [
    'Hakurikijwe itegeko ry\'u Rwanda rirengera amakuru bwite n\'ubuzima bwite (Itegeko Nº 058/2021), ushobora gusaba kubona, gukosora cyangwa gusiba amakuru yawe. '
        'Ushobora guhindura izina n\'ifoto muri Porofayili, guhagarika imeyili z\'iminsi ukurikiranya, no gusiba konti yawe igihe icyo ari cyo cyose. '
        'Ku bindi byose, koresha “Vugana n\'ubufasha” muri porofayili yawe.',
  ]),
  ('Kurinda amakuru', [
    'Amakuru anyura mu nzira z\'ibanga, kandi buri busabe buragenzurwa kugira ngo umunyamuryango agere ku makuru ye bwite gusa. '
        'Nta buryo butunganye 100%, rero koresha ijambobanga rikomeye udakoresha ahandi.',
  ]),
  ('Abana', [
    'EcoFun yagenewe buri wese ushaka kurinda ibidukikije. Abana bari munsi y\'imyaka 16 bayikoresha babiherewe uruhushya n\'ababyeyi cyangwa abarimu.',
  ]),
  ('Impinduka', [
    'Iyi politiki nihinduka, tuzahindura itariki iri hepfo kandi tubakumenyeshe muri porogaramu.',
  ]),
];

const termsRw = <LegalSection>[
  ('Kwemera aya mabwiriza', [
    'Iyo ufunguye konti cyangwa ukoresha EcoFun, uba wemeye aya Mabwiriza y\'Imikoreshereze na Politiki y\'Ibanga. Niba utabyemera, ntukoreshe iyi porogaramu.',
  ]),
  ('Konti yawe', [
    'Koresha izina ryawe nyakuri n\'imeyili yawe bwite. Gira ibanga ijambobanga ryawe; ni wowe ubazwa ibikorerwa kuri konti yawe. Umuntu umwe, konti imwe.',
  ]),
  ('Amategeko y\'Umuryango', [
    'Sangiza amafoto ajyanye n\'ibidukikije: gutandukanya imyanda, gusukura, ibiti, gutunganya imyanda n\'ibindi bikorwa nk\'ibyo.',
    'Ntugashyireho ibintu bitukana, iby\'urugomo, iby\'urukozasoni, iby\'urwango, ibya politiki, ibiyobya cyangwa bidafite aho bihuriye, '
        'kandi ntugashyireho amafoto y\'abandi bantu batabiguhereye uburenganzira.',
    'Ntugakwirakwize ubutumwa budakenewe, ntugashake amanota mu buriganya (urugero: amafoto y\'impimbano cyangwa asubiwemo) kandi ntugahohotere abandi banyamuryango.',
    'Abanyamuryango bashobora gutanga raporo ku nyandiko. Abayobozi bashobora gusiba inyandiko yose irenga kuri aya mategeko, '
        'kandi bashobora guhagarika cyangwa kwirukana burundu konti ziyarengaho.',
  ]),
  ('Amanota n\'ibihembo', [
    'Amanota agaragaza aho ugeze n\'umwanya wawe ku rutonde. Nta gaciro k\'amafaranga afite kandi ntashobora kugurishwa cyangwa kuvunjwa. '
        'Abayobozi bashobora gukosora amanota yabonetse ku makosa cyangwa mu buriganya.',
  ]),
  ('Ibisubizo bya AI n\'amakuru', [
    'Kumenya ubwoko bw\'imyanda, kugenzura uko yajugunywe n\'ibibazo bikorwa na AI kandi rimwe na rimwe bishobora kwibeshya. '
        'Buri gihe kurikiza amabwiriza y\'inzego z\'ibanze (Umujyi wa Kigali, REMA, umurenge wawe) ku gutandukanya no kujugunya imyanda.',
    'Inkuru ni iz\'ibitangazamakuru byazanditse. EcoFun yerekana incamake ngufi n\'ihuza rijya ku nkuru y\'umwimerere.',
  ]),
  ('Ibyo usangiza', [
    'Amafoto n\'inyandiko usangiza bikomeza kuba ibyawe. Iyo ubishyizeho, uba wemereye EcoFun kubyereka abandi banyamuryango muri porogaramu. '
        'Ushobora gusiba inyandiko zawe, kandi gusiba konti bisiba byose.',
  ]),
  ('Porogaramu ubwayo', [
    'EcoFun ni ubuntu kandi itangwa uko iri. Duharanira ko ikora neza, ariko ntidushobora kwizeza ko izahora iboneka cyangwa idafite amakosa. '
        'Dushobora guhindura, guhagarika by\'agateganyo cyangwa gukuraho ibice byayo igihe icyo ari cyo cyose.',
  ]),
  ('Impinduka no kutuvugisha', [
    'Dushobora kuvugurura aya mabwiriza. Nitubikora, tuzahindura itariki iri hepfo kandi tubakumenyeshe muri porogaramu; gukomeza gukoresha EcoFun '
        'bivuze ko wemeye amabwiriza mashya. Aya mabwiriza agengwa n\'amategeko ya Repubulika y\'u Rwanda. '
        'Ufite ikibazo? Koresha “Vugana n\'ubufasha” muri porofayili yawe.',
  ]),
];
