migrate((app) => {

  // ── 1. Add zh_CN to language_code select ─────────────────────────────────
  const coll      = app.findCollectionByNameOrId("whatsapp_templates");
  const langField = coll.fields.getByName("language_code");
  langField.values = ["en", "ms", "zh_CN"];
  app.save(coll);

  // ── 2. Seed templates ─────────────────────────────────────────────────────
  const templates = [

    // ══ BAHASA MALAYSIA ════════════════════════════════════════════════════

    {
      display_name:       "Mesej Selamat Datang (BM)",
      trigger_event:      "user.registered",
      trigger_description:"Dihantar secara automatik apabila pengguna baharu mencipta akaun",
      meta_template_name: "sdm_welcome_new_user_ms",
      category: "UTILITY", language_code: "ms",
      header_type: "TEXT",
      header_text: "Selamat Datang ke Sihat Dari Mula!",
      body:        "Hai {{1}}!\n\nSelamat datang ke Sihat Dari Mula. Kami sangat gembira anda bersama kami.\n\nPerjalanan anda menuju kehamilan dan penjagaan bayi yang lebih sihat bermula di sini. Terokai kursus kami yang dipimpin oleh pakar, pantau pencapaian bayi anda, dan berhubung dengan komuniti ibu-ibu.\n\nMulakan pelajaran pertama anda di sini:\n{{2}}",
      footer_text: "Balas STOP untuk berhenti melanggan.",
      buttons:   [{ type: "URL", text: "Buka Aplikasi", url: "https://app.sihatdarimula.my" }],
      variables: [
        { index: 1, name: "first_name", description: "Nama pertama pengguna", example: "Siti" },
        { index: 2, name: "app_link",   description: "Pautan aplikasi",        example: "https://app.sihatdarimula.my" },
      ],
      approval_status: "draft", is_active: false, sort_order: 11,
    },
    {
      display_name:       "Pengesahan Pendaftaran (BM)",
      trigger_event:      "user.enrolled",
      trigger_description:"Dihantar apabila pengguna berjaya mendaftar dalam sebuah kursus",
      meta_template_name: "sdm_enrollment_confirmation_ms",
      category: "UTILITY", language_code: "ms",
      header_type: "TEXT",
      header_text: "Anda Telah Berjaya Mendaftar!",
      body:        "Hai {{1}}!\n\nTahniah — anda kini telah berjaya mendaftar dalam *{{2}}*.\n\nPelajaran pertama anda sudah sedia. Kami mencadangkan anda meluangkan masa 15-20 minit sehari untuk mencapai kemajuan yang konsisten.\n\nKetik pautan di bawah untuk bermula:\n{{3}}",
      footer_text: "",
      buttons:   [{ type: "URL", text: "Mulakan Pembelajaran", url: "https://app.sihatdarimula.my" }],
      variables: [
        { index: 1, name: "first_name",  description: "Nama pertama pengguna",                example: "Aishah" },
        { index: 2, name: "course_name", description: "Nama kursus yang didaftarkan",          example: "Pemakanan Semasa Kehamilan" },
        { index: 3, name: "course_link", description: "Pautan terus ke kursus dalam aplikasi", example: "https://app.sihatdarimula.my" },
      ],
      approval_status: "draft", is_active: false, sort_order: 12,
    },
    {
      display_name:       "Peringatan Kemajuan Mingguan (BM)",
      trigger_event:      "cron.weekly_nudge",
      trigger_description:"Dihantar setiap Isnin kepada pelajar yang belum menyelesaikan kursus aktif",
      meta_template_name: "sdm_weekly_progress_nudge_ms",
      category: "MARKETING", language_code: "ms",
      header_type: "NONE", header_text: "",
      body:        "Hai {{1}}, jom kita check in!\n\nAnda kini berada pada tahap *{{2}}%* daripada *{{3}}* — teruskan!\n\nPelajaran seterusnya anda ialah: *{{4}}*\n\nSambung pembelajaran anda di sini: {{5}}",
      footer_text: "Balas STOP untuk berhenti menerima peringatan mingguan.",
      buttons: [],
      variables: [
        { index: 1, name: "first_name",        description: "Nama pertama pengguna",              example: "Nurul" },
        { index: 2, name: "progress_percent",  description: "Peratusan kursus yang diselesaikan", example: "45" },
        { index: 3, name: "course_name",       description: "Nama kursus aktif",                  example: "Asas Penyusuan Susu Ibu" },
        { index: 4, name: "next_lesson_title", description: "Tajuk pelajaran seterusnya",          example: "Pelajaran 3: Kedudukan dan Pelekatan" },
        { index: 5, name: "course_link",       description: "Pautan terus ke kursus",              example: "https://app.sihatdarimula.my" },
      ],
      approval_status: "draft", is_active: false, sort_order: 13,
    },
    {
      display_name:       "Perayaan Tamat Kursus (BM)",
      trigger_event:      "user.completed_course",
      trigger_description:"Dihantar apabila pengguna mencapai 100% penyelesaian kursus",
      meta_template_name: "sdm_course_completion_ms",
      category: "UTILITY", language_code: "ms",
      header_type: "TEXT",
      header_text: "Kursus Selesai!",
      body:        "Tahniah {{1}}!\n\nAnda telah berjaya menamatkan *{{2}}* — pencapaian yang luar biasa!\n\nKami sangat bangga dengan usaha anda dalam melabur untuk kesihatan diri dan masa depan bayi anda. Bersedia untuk meneroka kursus seterusnya?\n\n{{3}}",
      footer_text: "",
      buttons:   [{ type: "URL", text: "Terokai Lebih Banyak Kursus", url: "https://app.sihatdarimula.my" }],
      variables: [
        { index: 1, name: "first_name",  description: "Nama pertama pengguna",                example: "Farah" },
        { index: 2, name: "course_name", description: "Nama kursus yang diselesaikan",         example: "Pemulihan Selepas Bersalin" },
        { index: 3, name: "app_link",    description: "Pautan aplikasi untuk meneroka kursus", example: "https://app.sihatdarimula.my" },
      ],
      approval_status: "draft", is_active: false, sort_order: 14,
    },
    {
      display_name:       "Pengumuman Kursus Baharu (BM)",
      trigger_event:      "admin.published_course",
      trigger_description:"Dihantar apabila admin menerbitkan kursus baharu",
      meta_template_name: "sdm_new_course_announcement_ms",
      category: "MARKETING", language_code: "ms",
      header_type: "TEXT",
      header_text: "Kursus Baharu Tersedia!",
      body:        "Hai {{1}}!\n\nKami baru sahaja melancarkan kursus baharu di Sihat Dari Mula:\n\n*{{2}}*\n{{3}}\n\nDaftar sekarang dan jadilah antara yang pertama untuk memulakan pembelajaran:\n{{4}}",
      footer_text: "Balas STOP untuk berhenti menerima pengumuman.",
      buttons:   [{ type: "URL", text: "Daftar Sekarang", url: "https://app.sihatdarimula.my" }],
      variables: [
        { index: 1, name: "first_name",        description: "Nama pertama pengguna",                example: "Rina" },
        { index: 2, name: "course_title",       description: "Tajuk kursus baharu",                  example: "Memahami Tidur Bayi Anda" },
        { index: 3, name: "course_description", description: "Penerangan ringkas kursus (1-2 ayat)", example: "Pelajari strategi berasaskan bukti untuk membantu bayi anda membina tabiat tidur yang sihat." },
        { index: 4, name: "course_link",        description: "Pautan terus ke kursus baharu",        example: "https://app.sihatdarimula.my" },
      ],
      approval_status: "draft", is_active: false, sort_order: 15,
    },
    {
      display_name:       "Peringatan Pencapaian Bayi (BM)",
      trigger_event:      "cron.baby_milestone",
      trigger_description:"Dihantar apabila bayi mencapai usia 1, 2, 3, 6, 9, 12, 18, atau 24 bulan",
      meta_template_name: "sdm_baby_milestone_reminder_ms",
      category: "UTILITY", language_code: "ms",
      header_type: "TEXT",
      header_text: "Pencapaian Bayi Dicapai!",
      body:        "Hai {{1}}!\n\nTahniah — si kecil *{{2}}* sudah mencapai usia {{3}} bulan hari ini!\n\nBerikut adalah perkara yang perlu diberi perhatian pada peringkat ini:\n{{4}}\n\nPantau semua pencapaian {{2}} dan dapatkan tips peribadi dalam aplikasi:\n{{5}}",
      footer_text: "",
      buttons: [],
      variables: [
        { index: 1, name: "parent_name",   description: "Nama pertama ibu bapa",                 example: "Nadia" },
        { index: 2, name: "baby_name",     description: "Nama bayi",                              example: "Sofea" },
        { index: 3, name: "age_months",    description: "Umur bayi dalam bulan",                  example: "6" },
        { index: 4, name: "milestone_tip", description: "Tip kesihatan mengikut usia (2-3 ayat)", example: "Bayi anda mungkin sudah bersedia untuk makanan pejal. Mulakan dengan puri bahan tunggal dan perkenalkan satu makanan baharu setiap 3 hari." },
        { index: 5, name: "app_link",      description: "Pautan aplikasi",                        example: "https://app.sihatdarimula.my" },
      ],
      approval_status: "draft", is_active: false, sort_order: 16,
    },

    // ══ CHINESE SIMPLIFIED — body text uses actual Chinese characters ═══════
    // Note: no ASCII double-quote characters inside any string value below.

    {
      display_name:       "Huan Ying Xiao Xi (ZH)",
      trigger_event:      "user.registered",
      trigger_description:"Xin yong hu zhu ce shi zi dong fa song",
      meta_template_name: "sdm_welcome_new_user_zh",
      category: "UTILITY", language_code: "zh_CN",
      header_type: "TEXT",
      header_text: "Huan ying jia ru Sihat Dari Mula",
      body:        "Nin hao {{1}}! Huan ying jia ru Sihat Dari Mula.\n\nNin de jian kang yun qi yu yu er zhi lu cong zhe li zheng shi kai shi. Tan suo wo men you zhuan jia zhu jiang de ke cheng, zhui zong bao bao de cheng zhang li cheng bei, bing yu zhong duo ma ma xie shou tong xing.\n\nLi ji kai shi nin de di yi tang ke:\n{{2}}",
      footer_text: "Ru xu qu xiao, qing hui fu STOP.",
      buttons:   [{ type: "URL", text: "Da kai ying yong", url: "https://app.sihatdarimula.my" }],
      variables: [
        { index: 1, name: "first_name", description: "Yong hu de ming zi (e.g. Li Hua)", example: "Li Hua" },
        { index: 2, name: "app_link",   description: "App URL",                           example: "https://app.sihatdarimula.my" },
      ],
      approval_status: "draft", is_active: false, sort_order: 21,
    },
    {
      display_name:       "Bao Ming Que Ren (ZH)",
      trigger_event:      "user.enrolled",
      trigger_description:"Yong hu cheng gong bao ming ke cheng shi fa song",
      meta_template_name: "sdm_enrollment_confirmation_zh",
      category: "UTILITY", language_code: "zh_CN",
      header_type: "TEXT",
      header_text: "Bao ming cheng gong",
      body:        "Nin hao {{1}}!\n\nGong xi nin cheng gong bao ming *{{2}}*.\n\nNin de di yi tang ke yi zhun bei jiu xu. Wo men jian yi mei tian an pai 15-20 fen zhong xue xi, xiao guo zui jia.\n\nDian ji yi xia lian jie, li ji kai shi:\n{{3}}",
      footer_text: "",
      buttons:   [{ type: "URL", text: "Kai shi xue xi", url: "https://app.sihatdarimula.my" }],
      variables: [
        { index: 1, name: "first_name",  description: "Yong hu de ming zi",              example: "Mei Ling" },
        { index: 2, name: "course_name", description: "Yi bao ming ke cheng de ming cheng", example: "Yun qi ying yang zhi nan" },
        { index: 3, name: "course_link", description: "Ke cheng zhi da lian jie",         example: "https://app.sihatdarimula.my" },
      ],
      approval_status: "draft", is_active: false, sort_order: 22,
    },
    {
      display_name:       "Mei Zhou Xue Xi Ti Xing (ZH)",
      trigger_event:      "cron.weekly_nudge",
      trigger_description:"Mei zhou yi xiang shang wei wan cheng ke cheng de xue yuan fa song",
      meta_template_name: "sdm_weekly_progress_nudge_zh",
      category: "MARKETING", language_code: "zh_CN",
      header_type: "NONE", header_text: "",
      body:        "Nin hao {{1}}, lai da ge ka!\n\nNin mu qian yi wan cheng *{{3}}* de *{{2}}%* — ji xu jia you!\n\nXia yi tang ke deng zhe nin: *{{4}}*\n\nDian ji ji xu xue xi: {{5}}",
      footer_text: "Ru xu qu xiao mei zhou ti xing, qing hui fu STOP.",
      buttons: [],
      variables: [
        { index: 1, name: "first_name",        description: "Yong hu de ming zi",                   example: "Hui Fang" },
        { index: 2, name: "progress_percent",  description: "Ke cheng dang qian wan cheng bai fen bi", example: "45" },
        { index: 3, name: "course_name",       description: "Jin xing zhong ke cheng ming cheng",    example: "Mu ru wei yang ji chu" },
        { index: 4, name: "next_lesson_title", description: "Xia yi tang ke biao ti",               example: "Di 3 ke: bu ru zi shi yu han ru" },
        { index: 5, name: "course_link",       description: "Ke cheng zhi da lian jie",              example: "https://app.sihatdarimula.my" },
      ],
      approval_status: "draft", is_active: false, sort_order: 23,
    },
    {
      display_name:       "Ke Cheng Wan Cheng Qing He (ZH)",
      trigger_event:      "user.completed_course",
      trigger_description:"Yong hu wan cheng ke cheng (jin du 100%) shi fa song",
      meta_template_name: "sdm_course_completion_zh",
      category: "UTILITY", language_code: "zh_CN",
      header_type: "TEXT",
      header_text: "Ke cheng wan cheng",
      body:        "Gong xi nin, {{1}}!\n\nNin yi wan cheng *{{2}}* — zhe shi ling ren jiao ao de cheng jiu!\n\nGan xie nin wei zi shen jian kang ji bao bao de wei lai suo zuo de tou zi. Zhun bei hao tan suo xia yi men ke cheng le ma?\n\n{{3}}",
      footer_text: "",
      buttons:   [{ type: "URL", text: "Tan suo geng duo ke cheng", url: "https://app.sihatdarimula.my" }],
      variables: [
        { index: 1, name: "first_name",  description: "Yong hu de ming zi",                  example: "Xiu Lan" },
        { index: 2, name: "course_name", description: "Yi wan cheng ke cheng de ming cheng", example: "Chan hou hui fu zhi nan" },
        { index: 3, name: "app_link",    description: "App URL",                              example: "https://app.sihatdarimula.my" },
      ],
      approval_status: "draft", is_active: false, sort_order: 24,
    },
    {
      display_name:       "Xin Ke Cheng Gong Gao (ZH)",
      trigger_event:      "admin.published_course",
      trigger_description:"Guan li yuan fa bu xin ke cheng shi fa song gei suo you yi ding yue yong hu",
      meta_template_name: "sdm_new_course_announcement_zh",
      category: "MARKETING", language_code: "zh_CN",
      header_type: "TEXT",
      header_text: "Xin ke cheng shang xian",
      body:        "Nin hao {{1}}!\n\nSihat Dari Mula gang gang shang xian le yi men quan xin ke cheng:\n\n*{{2}}*\n{{3}}\n\nLi ji bao ming, cheng wei zui zao kai shi xue xi de ma ma zhi yi:\n{{4}}",
      footer_text: "Ru xu qu xiao jie shou gong gao, qing hui fu STOP.",
      buttons:   [{ type: "URL", text: "Li ji bao ming", url: "https://app.sihatdarimula.my" }],
      variables: [
        { index: 1, name: "first_name",        description: "Yong hu de ming zi",               example: "Xiao Yan" },
        { index: 2, name: "course_title",       description: "Xin ke cheng biao ti",              example: "Du dong bao bao de shui mian mi ma" },
        { index: 3, name: "course_description", description: "Ke cheng jian jie (1-2 ju hua)",   example: "Tong guo xun zheng ce lue bang zhu nin de xin sheng er cong chu sheng qi jian li jian kang de shui mian xi guan." },
        { index: 4, name: "course_link",        description: "Xin ke cheng de zhi da lian jie",  example: "https://app.sihatdarimula.my" },
      ],
      approval_status: "draft", is_active: false, sort_order: 25,
    },
    {
      display_name:       "Bao Bao Li Cheng Bei Ti Xing (ZH)",
      trigger_event:      "cron.baby_milestone",
      trigger_description:"Bao bao da dao 1, 2, 3, 6, 9, 12, 18 huo 24 ge yue shi fa song",
      meta_template_name: "sdm_baby_milestone_reminder_zh",
      category: "UTILITY", language_code: "zh_CN",
      header_type: "TEXT",
      header_text: "Bao bao cheng zhang li cheng bei",
      body:        "Nin hao {{1}}!\n\nXiao *{{2}}* jin tian man {{3}} ge yue le — duo me mei hao de li cheng bei!\n\nZai zhe ge jie duan, you yi xia ji dian qing liu yi:\n{{4}}\n\nZai ying yong cheng xu zhong zhui zong {{2}} de suo you cheng zhang li cheng bei, bing huo qu ge xing hua yu er jian yi:\n{{5}}",
      footer_text: "",
      buttons: [],
      variables: [
        { index: 1, name: "parent_name",   description: "Jia zhang de ming zi",               example: "Ya Wen" },
        { index: 2, name: "baby_name",     description: "Bao bao de ming zi",                 example: "Xiao En" },
        { index: 3, name: "age_months",    description: "Bao bao de yue ling",                example: "6" },
        { index: 4, name: "milestone_tip", description: "Shi ling yu er ti shi (2-3 ju hua)", example: "Bao bao ke neng yi zhun bei hao chang shi fu shi. Jian yi cong dan yi shi cai ni kai shi, mei ge 3 tian yin ru yi zhong xin shi wu, guan cha shi fou you guo min fan ying." },
        { index: 5, name: "app_link",      description: "App URL",                            example: "https://app.sihatdarimula.my" },
      ],
      approval_status: "draft", is_active: false, sort_order: 26,
    },

  ];

  const freshColl = app.findCollectionByNameOrId("whatsapp_templates");
  for (const t of templates) {
    const r = new Record(freshColl);
    for (const [k, v] of Object.entries(t)) r.set(k, v);
    app.save(r);
  }

}, (app) => {
  const allMs = app.findRecordsByFilter("whatsapp_templates", "language_code = 'ms'",    "", 0, 0, {});
  const allZh = app.findRecordsByFilter("whatsapp_templates", "language_code = 'zh_CN'", "", 0, 0, {});
  for (const r of [...allMs, ...allZh]) app.delete(r);

  const c  = app.findCollectionByNameOrId("whatsapp_templates");
  const lf = c.fields.getByName("language_code");
  lf.values = ["en", "ms"];
  app.save(c);
});
