migrate((app) => {
  const coursesCol = app.findCollectionByNameOrId("courses");
  const modulesCol = app.findCollectionByNameOrId("course_modules");
  const lessonsCol = app.findCollectionByNameOrId("lessons");
  const quizzesCol = app.findCollectionByNameOrId("lesson_quizzes");

  // Course
  const course = new Record(coursesCol);
  course.set("title_en", "Newborn Care Essentials");
  course.set("title_ms", "Penjagaan Bayi Baru Lahir");
  course.set("title_zh", "新生儿护理基础");
  course.set("description_en", "A practical guide for new parents covering the first months of your newborn's life — from the first hours after birth to feeding, bathing, and healthy sleep routines.");
  course.set("description_ms", "Panduan praktikal untuk ibu bapa baru meliputi bulan-bulan pertama kehidupan bayi anda — dari jam pertama selepas kelahiran hingga penyusuan, mandi, dan rutin tidur yang sihat.");
  course.set("description_zh", "适合新手父母的实用指南，涵盖新生儿出生后头几个月的护理 — 从出生后最初几小时到喂养、洗澡和健康睡眠习惯。");
  course.set("category", "parenting");
  course.set("level", "beginner");
  course.set("is_published", true);
  course.set("is_featured", true);
  course.set("has_modules", true);
  app.save(course);

  // Module 1
  const mod1 = new Record(modulesCol);
  mod1.set("course", course.id);
  mod1.set("title_en", "Your Baby's First Days");
  mod1.set("title_ms", "Hari-Hari Pertama Bayi Anda");
  mod1.set("title_zh", "宝宝的头几天");
  mod1.set("order", 1);
  app.save(mod1);

  // Module 2
  const mod2 = new Record(modulesCol);
  mod2.set("course", course.id);
  mod2.set("title_en", "Feeding Your Newborn");
  mod2.set("title_ms", "Menyusu Bayi Baru Lahir");
  mod2.set("title_zh", "喂养你的新生儿");
  mod2.set("order", 2);
  app.save(mod2);

  // Lesson 1.1 — free preview
  const l1 = new Record(lessonsCol);
  l1.set("course", course.id);
  l1.set("module", mod1.id);
  l1.set("title_en", "What to Expect in the First 24 Hours");
  l1.set("title_ms", "Apa yang Dijangkakan dalam 24 Jam Pertama");
  l1.set("title_zh", "出生后24小时内的情况");
  l1.set("description_en", "Learn what happens immediately after birth: skin-to-skin contact, the first feed, cord care, and the checks your healthcare team will perform. Replace this sample video URL with your own content in the admin panel.");
  l1.set("description_ms", "Ketahui apa yang berlaku sejurus selepas kelahiran: sentuhan kulit-ke-kulit, susu pertama, penjagaan tali pusat, dan pemeriksaan yang akan dilakukan oleh pasukan kesihatan anda.");
  l1.set("description_zh", "了解出生后立即发生的情况：肌肤接触、第一次喂养、脐带护理，以及医护团队将进行的检查。请在管理面板中将示例视频链接替换为您自己的内容。");
  l1.set("video_url", "https://www.youtube.com/watch?v=2Vv-BfVoq4g");
  l1.set("video_provider", "youtube");
  l1.set("video_duration", 480);
  l1.set("completion_threshold", 100);
  l1.set("has_quiz", false);
  l1.set("order", 1);
  l1.set("is_published", true);
  l1.set("is_free_preview", true);
  app.save(l1);

  // Lesson 1.2
  const l2 = new Record(lessonsCol);
  l2.set("course", course.id);
  l2.set("module", mod1.id);
  l2.set("title_en", "Bathing Your Newborn Safely");
  l2.set("title_ms", "Memandikan Bayi Baru Lahir dengan Selamat");
  l2.set("title_zh", "安全给新生儿洗澡");
  l2.set("description_en", "Step-by-step guide to your newborn's first bath: correct water temperature (36-37°C), support technique, and how to keep your baby calm. Best practice is to wait until the umbilical cord stump falls off.");
  l2.set("description_ms", "Panduan langkah demi langkah untuk mandian pertama bayi anda: suhu air yang betul (36-37°C), teknik sokongan, dan cara memastikan bayi tenang. Amalan terbaik adalah menunggu sehingga tali pusat gugur.");
  l2.set("description_zh", "新生儿第一次洗澡的分步指南：正确水温（36-37°C）、支撑技巧，以及如何保持宝宝平静。最好等脐带残端脱落后再洗澡。");
  l2.set("video_url", "https://www.youtube.com/watch?v=KZRGMdXNB0s");
  l2.set("video_provider", "youtube");
  l2.set("video_duration", 360);
  l2.set("completion_threshold", 100);
  l2.set("has_quiz", false);
  l2.set("order", 2);
  l2.set("is_published", true);
  l2.set("is_free_preview", false);
  app.save(l2);

  // Lesson 2.1 — with quiz
  const l3 = new Record(lessonsCol);
  l3.set("course", course.id);
  l3.set("module", mod2.id);
  l3.set("title_en", "Breastfeeding Basics");
  l3.set("title_ms", "Asas Penyusuan Susu Ibu");
  l3.set("title_zh", "母乳喂养基础");
  l3.set("description_en", "Master the fundamentals: correct latch, feeding positions, how to read hunger cues, and building a healthy milk supply. Complete the knowledge check quiz after watching.");
  l3.set("description_ms", "Kuasai asas: perlekatan yang betul, posisi penyusuan, cara membaca isyarat lapar, dan membina bekalan susu yang sihat. Lengkapkan kuiz semakan pengetahuan selepas menonton.");
  l3.set("description_zh", "掌握基础知识：正确含乳、喂养姿势、读懂饥饿信号，以及建立健康的奶水供应。观看后完成知识测验。");
  l3.set("video_url", "https://www.youtube.com/watch?v=ub82Xb1C8os");
  l3.set("video_provider", "youtube");
  l3.set("video_duration", 600);
  l3.set("completion_threshold", 100);
  l3.set("has_quiz", true);
  l3.set("order", 1);
  l3.set("is_published", true);
  l3.set("is_free_preview", false);
  app.save(l3);

  // Quiz for lesson 2.1
  const quiz = new Record(quizzesCol);
  quiz.set("lesson", l3.id);
  quiz.set("questions", [
    {
      question: "How often should a healthy newborn be breastfed?",
      options: [
        "Once every 5-6 hours",
        "Every 2-3 hours (8-12 times in 24 hours)",
        "Three times a day like adults",
        "Only when the baby cries loudly"
      ],
      correct: 1,
      explanation: "Newborns have tiny stomachs and breast milk digests quickly. Feeding every 2-3 hours ensures good nutrition and stimulates your milk supply."
    },
    {
      question: "What is the key sign of a correct breastfeeding latch?",
      options: [
        "Only the nipple is inside the baby's mouth",
        "The baby's mouth covers the nipple and most of the areola",
        "The mother feels sharp pain throughout the feed",
        "The baby's head should tilt backward during latching"
      ],
      correct: 1,
      explanation: "A deep latch where the mouth covers the nipple AND most of the areola is essential for effective milk transfer and to prevent nipple soreness."
    },
    {
      question: "What is colostrum?",
      options: [
        "A vitamin supplement taken during pregnancy",
        "Regular breast milk that comes in after one week",
        "The first milk produced after birth — thick, yellowish and rich in antibodies",
        "A formula supplement recommended for the first few days"
      ],
      correct: 2,
      explanation: "Colostrum is the precious 'first milk' produced in the first few days after birth. It is thick, yellowish, and packed with antibodies vital for your newborn's immune system."
    }
  ]);
  quiz.set("passing_score", 70);
  app.save(quiz);

  // Lesson 2.2
  const l4 = new Record(lessonsCol);
  l4.set("course", course.id);
  l4.set("module", mod2.id);
  l4.set("title_en", "Formula Feeding: A Complete Guide");
  l4.set("title_ms", "Penyusuan Formula: Panduan Lengkap");
  l4.set("title_zh", "配方奶粉喂养：完整指南");
  l4.set("description_en", "Everything you need to know about formula feeding: choosing the right formula, safe preparation, correct amounts per feed, and sterilising equipment properly.");
  l4.set("description_ms", "Semua yang perlu anda tahu tentang penyusuan formula: memilih formula yang betul, penyediaan yang selamat, jumlah yang betul setiap penyusuan, dan pensterilan peralatan dengan betul.");
  l4.set("description_zh", "关于配方奶喂养的完整知识：如何选择合适的配方奶、安全冲调方法、每次喂养的正确量，以及正确消毒器具。");
  l4.set("video_url", "https://www.youtube.com/watch?v=j5RKBm1xlY8");
  l4.set("video_provider", "youtube");
  l4.set("video_duration", 420);
  l4.set("completion_threshold", 100);
  l4.set("has_quiz", false);
  l4.set("order", 2);
  l4.set("is_published", true);
  l4.set("is_free_preview", false);
  app.save(l4);

}, (app) => {
  try {
    const cs = app.findRecordsByFilter("courses", "title_en = {:t}", "", 0, 0, { t: "Newborn Care Essentials" });
    for (const c of cs) app.delete(c);
  } catch(_) {}
});
