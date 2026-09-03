
migrate((app) => {
  const users = app.findCollectionByNameOrId("users")
  users.fields.add(new TextField({ name: "phone", max: 20 }))
  users.fields.add(new SelectField({ name: "language", values: ["en", "ms", "zh"], maxSelect: 1 }))
  app.save(users)

  const articles = app.findCollectionByNameOrId("articles")
  articles.fields.add(new TextField({ name: "title_ms", max: 300 }))
  articles.fields.add(new TextField({ name: "summary_ms", max: 500 }))
  articles.fields.add(new EditorField({ name: "content_ms" }))
  articles.fields.add(new TextField({ name: "title_zh", max: 300 }))
  articles.fields.add(new TextField({ name: "summary_zh", max: 500 }))
  articles.fields.add(new EditorField({ name: "content_zh" }))
  app.save(articles)

  const trans = {
    "Understanding Your Baby's Growth Charts": {
      title_ms: "Memahami Carta Pertumbuhan Bayi Anda",
      summary_ms: "Ketahui cara membaca persentil pertumbuhan WHO dan maksudnya untuk perkembangan anak anda.",
      content_ms: "<p>Carta pertumbuhan adalah antara alat terpenting yang digunakan oleh pakar pediatrik untuk memantau perkembangan fizikal bayi anda.</p><h3>Apa Itu Persentil?</h3><p>Jika bayi anda berada pada persentil ke-50 untuk berat badan, bermakna 50% bayi lebih berat dan 50% lebih ringan. Yang penting ialah bayi anda mengikuti lengkung pertumbuhan yang konsisten.</p><h3>Ukuran Utama</h3><p><strong>Berat:</strong> Penunjuk paling sensitif.<br><strong>Tinggi:</strong> Mencerminkan pertumbuhan keseluruhan.<br><strong>Lilitan Kepala:</strong> Penting untuk memantau pertumbuhan otak.</p>",
      title_zh: "了解宝宝的成长图表",
      summary_zh: "学习如何阅读WHO成长百分位数及其对孩子发育的意义。",
      content_zh: "<p>成长图表是儿科医生追踪宝宝身体发育最重要的工具之一。</p><h3>什么是百分位数？</h3><p>如果宝宝的体重在第50百分位，意味着50%的宝宝更重，50%更轻。重要的是宝宝遵循一致的成长曲线。</p><h3>关键测量</h3><p><strong>体重：</strong>最敏感的营养和健康指标。<br><strong>身高：</strong>反映整体生长。<br><strong>头围：</strong>对监测脑部发育很重要。</p>"
    },
    "Breastfeeding 101: Getting Started": {
      title_ms: "Penyusuan 101: Panduan Permulaan",
      summary_ms: "Tips penting untuk ibu baru yang memulakan perjalanan penyusuan dengan yakin.",
      content_ms: "<p>Penyusuan adalah kemahiran yang perlu dipelajari oleh ibu dan bayi. Walaupun ia semula jadi, ia tidak selalu datang secara semula jadi.</p><h3>Jam Pertama</h3><p>Sentuhan kulit ke kulit selepas kelahiran membantu mencetuskan naluri bayi untuk menyusu.</p><h3>Kekerapan Menyusu</h3><p>Bayi baru lahir biasanya menyusu 8-12 kali sehari. Perhatikan tanda lapar: mencari puting, tangan ke mulut, dan gelisah.</p>",
      title_zh: "母乳喂养入门指南",
      summary_zh: "帮助新妈妈自信开始母乳喂养之旅的基本技巧。",
      content_zh: "<p>母乳喂养是妈妈和宝宝都需要学习的技能。虽然它是自然的，但并不总是自然而然的。</p><h3>第一个小时</h3><p>产后立即进行肌肤接触有助于触发宝宝的吸吮本能。</p><h3>喂养频率</h3><p>新生儿通常每天喂养8-12次。注意饥饿信号：寻找、手到嘴的动作和烦躁。</p>"
    },
    "Introduction to Solid Foods": {
      title_ms: "Pengenalan kepada Makanan Pepejal",
      summary_ms: "Bila dan bagaimana untuk memperkenalkan makanan pepejal pertama bayi anda dengan selamat.",
      content_ms: "<p>Memulakan makanan pepejal adalah pencapaian yang menarik! Kebanyakan bayi bersedia antara 4-6 bulan.</p><h3>Tanda Kesediaan</h3><p>Bayi boleh duduk tegak dengan sokongan, menunjukkan minat terhadap makanan, dan boleh mengambil objek.</p><h3>Makanan Pertama</h3><p>Makanan pemula yang baik termasuk bijirin berbutir tunggal, ubi keledek lumat, avokado, pisang, dan kacang pis.</p>",
      title_zh: "辅食添加指南",
      summary_zh: "何时以及如何在6个月左右安全地为宝宝引入第一口辅食。",
      content_zh: "<p>开始添加辅食是一个令人兴奋的里程碑！大多数宝宝在4-6个月之间准备好。</p><h3>准备好的信号</h3><p>宝宝能在支撑下坐直，对食物表现出兴趣，并能抓住物体。</p><h3>第一口食物</h3><p>好的开始食物包括强化铁的单一谷物、红薯泥、牛油果、香蕉和豌豆。</p>"
    },
    "The Power of Tummy Time": {
      title_ms: "Kepentingan Tummy Time",
      summary_ms: "Mengapa tummy time penting dan bagaimana menjadikannya menyeronokkan untuk bayi anda.",
      content_ms: "<p>Tummy time adalah penting untuk membina kekuatan yang diperlukan bayi untuk berguling, duduk, merangkak, dan akhirnya berjalan.</p><h3>Faedah</h3><p>Mengukuhkan otot leher, bahu, dan teras. Mencegah bahagian rata di belakang kepala. Menggalakkan perkembangan motor.</p><h3>Cara Memulakan</h3><p><strong>Bayi baru lahir:</strong> Mulakan dengan 1-2 minit, 2-3 kali sehari.<br><strong>3-4 bulan:</strong> Sasarkan 20-30 minit sepanjang hari.</p>",
      title_zh: "俯卧时间的重要性",
      summary_zh: "为什么俯卧时间很重要以及如何让宝宝从第一天起就享受它。",
      content_zh: "<p>俯卧时间对于建立宝宝翻身、坐起、爬行和最终行走所需的力量至关重要。</p><h3>好处</h3><p>加强颈部、肩部和核心肌肉。防止后脑勺扁平。促进运动发育。</p><h3>如何开始</h3><p><strong>新生儿：</strong>每次1-2分钟，每天2-3次。<br><strong>3-4个月：</strong>每天总共20-30分钟。</p>"
    },
    "Key Developmental Milestones: 0-12 Months": {
      title_ms: "Pencapaian Perkembangan Utama: 0-12 Bulan",
      summary_ms: "Panduan lengkap tentang pencapaian menarik bayi anda dalam tahun pertama.",
      content_ms: "<p>Setiap bayi berkembang mengikut rentak masing-masing, tetapi pencapaian umum ini boleh membantu anda memantau kemajuan.</p><h3>0-3 Bulan</h3><p>Mengangkat kepala semasa tummy time, mengikuti objek dengan mata, senyum sosial.</p><h3>4-6 Bulan</h3><p>Berguling kedua-dua arah, mencapai dan menggenggam objek, ketawa kuat.</p><h3>7-12 Bulan</h3><p>Duduk tanpa sokongan, mula merangkak, bertepuk tangan, mungkin mengucapkan perkataan pertama.</p>",
      title_zh: "关键发育里程碑：0-12个月",
      summary_zh: "宝宝第一年将达到的激动人心的里程碑综合指南。",
      content_zh: "<p>每个宝宝都按自己的节奏发育，但这些一般性里程碑可以帮助您追踪进展。</p><h3>0-3个月</h3><p>俯卧时抬头，用眼睛追踪物体，社交微笑。</p><h3>4-6个月</h3><p>双向翻身，伸手抓物，大笑。</p><h3>7-12个月</h3><p>无支撑坐立，开始爬行，拍手，可能说出第一个词。</p>"
    },
    "Postpartum Mood: What's Normal and When to Seek Help": {
      title_ms: "Perasaan Selepas Bersalin: Apa yang Normal dan Bila Perlu Bantuan",
      summary_ms: "Memahami perubahan emosi selepas bersalin dan mengenali tanda-tanda kemurungan selepas bersalin.",
      content_ms: "<p>Tempoh selepas bersalin membawa perubahan emosi dan hormon yang besar.</p><h3>Baby Blues</h3><p>Sehingga 80% ibu baru mengalami perubahan mood, tangisan, dan kerisauan. Ini biasanya reda dalam dua minggu.</p><h3>Kemurungan Selepas Bersalin</h3><p>Menjejaskan kira-kira 1 daripada 7 ibu. Gejala termasuk kesedihan yang berterusan, kehilangan minat, dan kesukaran menjalin ikatan dengan bayi. Ia boleh dirawat — sila dapatkan bantuan.</p>",
      title_zh: "产后情绪：什么是正常的，何时寻求帮助",
      summary_zh: "了解产后情绪变化并识别产后抑郁症的征兆。",
      content_zh: "<p>产后期带来巨大的情绪和荷尔蒙变化。</p><h3>产后忧郁</h3><p>高达80%的新妈妈会经历情绪波动、哭泣和焦虑。这通常在两周内消退。</p><h3>产后抑郁症</h3><p>影响约七分之一的母亲。症状包括持续悲伤、失去兴趣和难以与宝宝建立联系。它是可以治疗的——请寻求帮助。</p>"
    },
    "Your Complete Vaccination Guide": {
      title_ms: "Panduan Lengkap Vaksinasi Anda",
      summary_ms: "Memahami jadual imunisasi yang disyorkan dan mengapa setiap vaksin penting.",
      content_ms: "<p>Vaksin adalah salah satu cara paling penting untuk melindungi anak anda daripada penyakit serius.</p><h3>Mengapa Vaksinasi?</h3><p>Vaksin berfungsi dengan melatih sistem imun untuk mengenali dan melawan kuman tertentu.</p><h3>Menguruskan Kesan Sampingan</h3><p>Kesan sampingan ringan seperti demam rendah dan kemerahan di tapak suntikan adalah normal dan biasanya reda dalam 48 jam.</p>",
      title_zh: "疫苗接种完全指南",
      summary_zh: "了解推荐的免疫接种计划以及每种疫苗的重要性。",
      content_zh: "<p>疫苗是保护孩子免受严重疾病侵害的最重要方式之一。</p><h3>为什么要接种疫苗？</h3><p>疫苗通过训练免疫系统识别和对抗特定病菌来发挥作用。</p><h3>管理副作用</h3><p>轻微副作用如低烧和注射部位发红是正常的，通常在48小时内消退。</p>"
    },
    "First Trimester: What to Expect": {
      title_ms: "Trimester Pertama: Apa yang Dijangka",
      summary_ms: "Panduan minggu demi minggu untuk 12 minggu pertama kehamilan anda.",
      content_ms: "<p>Trimester pertama (minggu 1-12) adalah masa perubahan yang luar biasa untuk anda dan bayi yang sedang berkembang.</p><h3>Perkembangan Bayi</h3><p><strong>Minggu 1-4:</strong> Persenyawaan dan implantasi berlaku.<br><strong>Minggu 5-8:</strong> Jantung mula berdegup. Tunas anggota badan muncul.<br><strong>Minggu 9-12:</strong> Semua organ utama terbentuk.</p><h3>Gejala Biasa</h3><p>Loya pagi, keletihan, sakit payudara, dan kerap membuang air kecil adalah pengalaman normal.</p>",
      title_zh: "孕早期：有什么期待",
      summary_zh: "孕期前12周的逐周指南。",
      content_zh: "<p>孕早期（第1-12周）是您和正在发育的宝宝经历巨大变化的时期。</p><h3>宝宝的发育</h3><p><strong>第1-4周：</strong>受精和着床发生。<br><strong>第5-8周：</strong>心脏开始跳动。小肢芽出现。<br><strong>第9-12周：</strong>所有主要器官形成。</p><h3>常见症状</h3><p>孕吐、疲劳、乳房胀痛和频繁排尿都是正常的孕早期体验。</p>"
    },
    "Preparing for Labor and Delivery": {
      title_ms: "Persediaan untuk Bersalin",
      summary_ms: "Semua yang perlu anda ketahui untuk berasa yakin dan bersedia pada hari besar.",
      content_ms: "<p>Persediaan boleh membantu mengurangkan kebimbangan dan memberi anda kuasa untuk pengalaman kelahiran.</p><h3>Tanda-tanda Bersalin</h3><p>Pengecutan yang teratur dan semakin kuat, ketuban pecah, dan sakit belakang yang berterusan.</p><h3>Bila ke Hospital</h3><p>Pergi apabila pengecutan setiap 5 minit, bertahan 1 minit, selama sekurang-kurangnya 1 jam (peraturan 5-1-1).</p>",
      title_zh: "分娩准备",
      summary_zh: "让您在大日子到来时感到自信和准备充分所需的一切。",
      content_zh: "<p>准备工作可以帮助减少焦虑，让您为分娩体验做好准备。</p><h3>分娩征兆</h3><p>规律且越来越强的宫缩、破水和持续的腰背疼痛。</p><h3>何时去医院</h3><p>当宫缩每5分钟一次、每次持续1分钟、持续至少1小时时（5-1-1规则）。</p>"
    },
    "Toddler Nutrition: Ages 1-3": {
      title_ms: "Pemakanan Kanak-kanak: Umur 1-3 Tahun",
      summary_ms: "Tips praktikal untuk memberi makan kanak-kanak anda diet yang seimbang dan berkhasiat.",
      content_ms: "<p>Kanak-kanak terkenal memilih makanan, tetapi dengan kesabaran dan strategi yang betul, anda boleh memastikan mereka mendapat nutrisi yang diperlukan.</p><h3>Keperluan Harian</h3><p>Kanak-kanak memerlukan kira-kira 1,000-1,400 kalori sehari daripada pelbagai kumpulan makanan.</p><h3>Menangani Pemilihan Makanan</h3><p>Tawarkan makanan baru bersama kegemaran. Ia boleh mengambil 10-15 pendedahan sebelum kanak-kanak menerima makanan baru.</p>",
      title_zh: "幼儿营养：1-3岁",
      summary_zh: "为成长中的幼儿提供均衡营养饮食的实用建议。",
      content_zh: "<p>幼儿以挑食闻名，但通过耐心和正确的策略，您可以确保他们获得所需的营养。</p><h3>每日需求</h3><p>幼儿每天需要约1,000-1,400卡路里，来自各种食物组。</p><h3>应对挑食</h3><p>将新食物与熟悉的食物一起提供。孩子可能需要10-15次接触才能接受新食物。</p>"
    },
    "Play-Based Learning for Toddlers": {
      title_ms: "Pembelajaran Berasaskan Permainan untuk Kanak-kanak",
      summary_ms: "Bagaimana aktiviti permainan harian menyokong perkembangan kognitif, sosial dan fizikal.",
      content_ms: "<p>Permainan adalah cara kanak-kanak belajar tentang dunia. Setiap permainan membina kemahiran penting.</p><h3>Jenis Permainan</h3><p><strong>Permainan fizikal:</strong> Berlari, memanjat — membina kemahiran motor kasar.<br><strong>Permainan konstruktif:</strong> Blok, teka-teki — mengembangkan penyelesaian masalah.<br><strong>Permainan olok-olok:</strong> Set dapur, anak patung — memupuk imaginasi.</p>",
      title_zh: "幼儿游戏式学习",
      summary_zh: "日常游戏活动如何支持幼儿的认知、社交和身体发展。",
      content_zh: "<p>游戏是幼儿了解世界的方式。每一个游戏都在培养关键技能。</p><h3>游戏类型</h3><p><strong>体能游戏：</strong>跑步、攀爬——培养大运动技能。<br><strong>建构游戏：</strong>积木、拼图——发展解决问题能力。<br><strong>假装游戏：</strong>厨房玩具、娃娃——培养想象力。</p>"
    },
    "Self-Care Tips for New Moms": {
      title_ms: "Tips Penjagaan Diri untuk Ibu Baru",
      summary_ms: "Strategi praktikal untuk menjaga kesihatan fizikal dan mental semasa tempoh selepas bersalin.",
      content_ms: "<p>Menjaga diri sendiri bukan mementingkan diri — ia adalah penting. Ibu yang sihat dan berehat lebih bersedia menjaga bayinya.</p><h3>Tidur</h3><p>Tidur ketika bayi tidur. Terima bantuan daripada pasangan, keluarga, atau rakan.</p><h3>Pemakanan</h3><p>Makanan mudah dan berkhasiat mengekalkan tenaga anda. Sediakan makanan ringkas lebih awal.</p><h3>Hubungan Sosial</h3><p>Sertai kumpulan ibu baru atau berhubung dengan rakan. Berkongsi pengalaman membantu menormalkan cabaran.</p>",
      title_zh: "新妈妈的自我护理建议",
      summary_zh: "产后期间维护身心健康的实用策略。",
      content_zh: "<p>照顾自己不是自私——这是必要的。一个健康、休息充分的母亲更能照顾好宝宝。</p><h3>睡眠</h3><p>宝宝睡觉时也要睡觉。接受伴侣、家人或朋友的帮助。</p><h3>营养</h3><p>简单营养的食物能保持您的精力。提前准备简单的食物。</p><h3>社交联系</h3><p>加入新妈妈小组或与朋友联系。分享经验有助于正常化挑战。</p>"
    }
  }

  const allArticles = app.findRecordsByFilter("articles", "id != ''", "", 0, 0, {})
  for (const r of allArticles) {
    const t = trans[r.get("title")]
    if (t) {
      for (const [k, v] of Object.entries(t)) {
        r.set(k, v)
      }
      app.save(r)
    }
  }
}, (app) => {
  const users = app.findCollectionByNameOrId("users")
  users.fields.removeByName("phone")
  users.fields.removeByName("language")
  app.save(users)

  const articles = app.findCollectionByNameOrId("articles")
  articles.fields.removeByName("title_ms")
  articles.fields.removeByName("summary_ms")
  articles.fields.removeByName("content_ms")
  articles.fields.removeByName("title_zh")
  articles.fields.removeByName("summary_zh")
  articles.fields.removeByName("content_zh")
  app.save(articles)
})
