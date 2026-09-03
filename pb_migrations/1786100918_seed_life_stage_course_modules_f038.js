migrate((app) => {
  const modulesCol = app.findCollectionByNameOrId("course_modules");
  const lessonsCol = app.findCollectionByNameOrId("lessons");
  const quizzesCol = app.findCollectionByNameOrId("lesson_quizzes");

  // Find the existing "Newborn Care Essentials" course
  const course = app.findFirstRecordByFilter("courses", "title_en = {:t}", { t: "Newborn Care Essentials" });

  // ═══════════════════════════════════════════════════════════════════════════
  // MODULE 3: Sleep & Soothing (0–3 Months)
  // ═══════════════════════════════════════════════════════════════════════════
  const mod3 = new Record(modulesCol);
  mod3.set("course", course.id);
  mod3.set("title_en", "Sleep & Soothing (0–3 Months)");
  mod3.set("title_ms", "Tidur & Penenangan (0–3 Bulan)");
  mod3.set("title_zh", "睡眠与安抚（0–3个月）");
  mod3.set("order", 3);
  app.save(mod3);

  // Lesson 3.1 — free preview
  const l31 = new Record(lessonsCol);
  l31.set("course", course.id);
  l31.set("module", mod3.id);
  l31.set("title_en", "Understanding Newborn Sleep Patterns");
  l31.set("title_ms", "Memahami Pola Tidur Bayi Baru Lahir");
  l31.set("title_zh", "了解新生儿睡眠规律");
  l31.set("description_en", "Newborns sleep 14–17 hours a day but rarely for more than 2–4 hours at a stretch. This lesson covers the science of newborn sleep cycles, safe sleep practices (ABC: Alone, Back, Cot), how to tell day from night, and building a gentle bedtime routine from 6–8 weeks. Learn why a baby who 'won't sleep' is often simply overtired — and how to spot and respond to sleep cues before the window closes.");
  l31.set("description_ms", "Bayi baru lahir tidur 14–17 jam sehari tetapi jarang lebih dari 2–4 jam berturut-turut. Pelajaran ini merangkumi sains kitaran tidur bayi baru lahir, amalan tidur selamat (ABC: Alone, Back, Cot), cara membezakan siang dan malam, dan membina rutin waktu tidur yang lembut dari usia 6–8 minggu.");
  l31.set("description_zh", "新生儿每天睡14–17小时，但很少连续超过2–4小时。本课介绍新生儿睡眠周期的科学原理、安全睡眠规范（ABC：独自、仰卧、婴儿床）、如何区分白天和夜晚，以及从6–8周开始建立温和的睡前习惯。");
  l31.set("video_url", "https://www.youtube.com/watch?v=s1w2GF-XZGA");
  l31.set("video_provider", "youtube");
  l31.set("video_duration", 540);
  l31.set("completion_threshold", 100);
  l31.set("has_quiz", false);
  l31.set("order", 1);
  l31.set("is_published", true);
  l31.set("is_free_preview", true);
  app.save(l31);

  // Lesson 3.2 — with quiz
  const l32 = new Record(lessonsCol);
  l32.set("course", course.id);
  l32.set("module", mod3.id);
  l32.set("title_en", "Soothing Techniques & Colic Relief");
  l32.set("title_ms", "Teknik Penenangan & Melegakan Kolik");
  l32.set("title_zh", "安抚技巧与肠绞痛缓解");
  l32.set("description_en", "Colic affects up to 25% of babies and peaks at 6 weeks. This lesson covers the 5 S method (Swaddle, Side, Shush, Swing, Suck), white noise, skin-to-skin contact, and bicycle leg exercises for gas relief. You'll also learn the difference between normal fussiness and colic, and when crying signals that something more serious needs medical attention. Complete the knowledge check to confirm your soothing toolkit.");
  l32.set("description_ms", "Kolik mempengaruhi sehingga 25% bayi dan memuncak pada 6 minggu. Pelajaran ini merangkumi kaedah 5 S (Swaddle, Side, Shush, Swing, Suck), bunyi putih, sentuhan kulit-ke-kulit, dan senaman kaki basikal untuk melegakan gas.");
  l32.set("description_zh", "肠绞痛影响高达25%的宝宝，在6周时达到高峰。本课涵盖5S法（包裹、侧卧、嘘声、摇晃、吮吸）、白噪音、肌肤接触，以及自行车腿运动排气。完成知识测验以确认您的安抚工具箱。");
  l32.set("video_url", "https://www.youtube.com/watch?v=EESM-3oFnv8");
  l32.set("video_provider", "youtube");
  l32.set("video_duration", 480);
  l32.set("completion_threshold", 100);
  l32.set("has_quiz", true);
  l32.set("order", 2);
  l32.set("is_published", true);
  l32.set("is_free_preview", false);
  app.save(l32);

  const quiz32 = new Record(quizzesCol);
  quiz32.set("lesson", l32.id);
  quiz32.set("passing_score", 70);
  quiz32.set("questions", [
    {
      question: "What does the 'B' in the safe sleep ABC rule stand for?",
      options: ["Blanket — always use a light blanket", "Back — always place baby on their back to sleep", "Bassinet — baby must sleep in a bassinet for the first 6 months", "Breathing — monitor baby's breathing with an app"],
      correct: 1,
      explanation: "Always placing baby on their Back is the single most effective safe sleep practice for reducing the risk of Sudden Infant Death Syndrome (SIDS)."
    },
    {
      question: "At what age does colic typically peak and then begin to resolve?",
      options: ["Peaks at 2 weeks, resolves by 6 weeks", "Peaks at 6 weeks, resolves by 3–4 months", "Peaks at 3 months, resolves by 6 months", "Colic does not resolve on its own"],
      correct: 1,
      explanation: "Colic typically peaks around 6 weeks of age and usually resolves on its own by 3–4 months, as the baby's digestive system matures."
    },
    {
      question: "Which of the 5 S's involves wrapping the baby snugly to recreate a womb-like feeling?",
      options: ["Swing", "Shush", "Swaddle", "Suck"],
      correct: 2,
      explanation: "Swaddling recreates the snug, secure feeling of the womb. It should be firm around the upper body but leave room at the hips for healthy hip development."
    }
  ]);
  app.save(quiz32);

  // ═══════════════════════════════════════════════════════════════════════════
  // MODULE 4: Growth & Discovery (3–6 Months)
  // ═══════════════════════════════════════════════════════════════════════════
  const mod4 = new Record(modulesCol);
  mod4.set("course", course.id);
  mod4.set("title_en", "Growth & Discovery (3–6 Months)");
  mod4.set("title_ms", "Pertumbuhan & Penemuan (3–6 Bulan)");
  mod4.set("title_zh", "成长与探索（3–6个月）");
  mod4.set("order", 4);
  app.save(mod4);

  // Lesson 4.1
  const l41 = new Record(lessonsCol);
  l41.set("course", course.id);
  l41.set("module", mod4.id);
  l41.set("title_en", "Motor Milestones: Rolling, Reaching & Tummy Time");
  l41.set("title_ms", "Pencapaian Motor: Bergolek, Meraih & Masa Perut");
  l41.set("title_zh", "运动里程碑：翻身、抓握与俯卧时间");
  l41.set("description_en", "Between 3 and 6 months your baby will roll front-to-back (around 4 months) and back-to-front (5–6 months), discover their hands, reach and grasp toys deliberately, and begin to bear weight on their legs. This lesson shows you how to support each milestone through play — the right tummy time exercises, which toys encourage reaching and grasping, and how to create a safe floor environment for rolling practice.");
  l41.set("description_ms", "Antara 3 hingga 6 bulan bayi anda akan bergolek depan-ke-belakang (sekitar 4 bulan) dan belakang-ke-depan (5–6 bulan), menemui tangan mereka, meraih dan menggenggam mainan dengan sengaja, dan mula menanggung berat pada kaki mereka. Pelajaran ini menunjukkan cara anda menyokong setiap pencapaian melalui permainan.");
  l41.set("description_zh", "在3到6个月之间，宝宝会从趴到仰翻身（约4个月），从仰到趴翻身（5–6个月），发现自己的双手，有意识地抓握玩具，并开始用腿承重。本课展示如何通过游戏支持每个里程碑——正确的俯卧练习、哪些玩具促进抓握，以及如何为翻身练习创造安全的地板环境。");
  l41.set("video_url", "https://www.youtube.com/watch?v=nXDUqCFLhxo");
  l41.set("video_provider", "youtube");
  l41.set("video_duration", 420);
  l41.set("completion_threshold", 100);
  l41.set("has_quiz", false);
  l41.set("order", 1);
  l41.set("is_published", true);
  l41.set("is_free_preview", false);
  app.save(l41);

  // Lesson 4.2
  const l42 = new Record(lessonsCol);
  l42.set("course", course.id);
  l42.set("module", mod4.id);
  l42.set("title_en", "Talking, Laughing & Sensory Play");
  l42.set("title_ms", "Bercakap, Ketawa & Permainan Deria");
  l42.set("title_zh", "说话、大笑与感官游戏");
  l42.set("description_en", "Your baby is now a social being — they smile responsively, laugh out loud, and babble with delight. Language development happens long before your baby says their first word. This lesson explains conversational turn-taking, the best ways to talk and read to your baby, and how simple sensory activities (textures, sounds, colours, smells) wire the developing brain. Includes practical play ideas you can do at home with no special equipment.");
  l42.set("description_ms", "Bayi anda kini adalah makhluk sosial — mereka senyum secara responsif, ketawa kuat, dan berceloteh dengan gembira. Perkembangan bahasa berlaku jauh sebelum bayi anda mengucapkan perkataan pertama mereka. Pelajaran ini menerangkan giliran perbualan, cara terbaik bercakap dan membaca kepada bayi anda, dan cara aktiviti deria mudah menyambungkan otak yang sedang berkembang.");
  l42.set("description_zh", "您的宝宝现在是一个社交生物——他们会报以微笑、放声大笑，并高兴地咿呀学语。语言发育在宝宝说出第一个词之前很久就开始了。本课解释对话轮换、与宝宝交谈和阅读的最佳方式，以及简单的感官活动如何连接正在发育的大脑。包含在家无需特殊设备即可进行的实用游戏创意。");
  l42.set("video_url", "https://www.youtube.com/watch?v=O3H4djzRLss");
  l42.set("video_provider", "youtube");
  l42.set("video_duration", 360);
  l42.set("completion_threshold", 100);
  l42.set("has_quiz", false);
  l42.set("order", 2);
  l42.set("is_published", true);
  l42.set("is_free_preview", false);
  app.save(l42);

  // ═══════════════════════════════════════════════════════════════════════════
  // MODULE 5: Starting Solids (6 Months+)
  // ═══════════════════════════════════════════════════════════════════════════
  const mod5 = new Record(modulesCol);
  mod5.set("course", course.id);
  mod5.set("title_en", "Starting Solids (6 Months+)");
  mod5.set("title_ms", "Memulakan Makanan Pepejal (6 Bulan ke Atas)");
  mod5.set("title_zh", "开始辅食（6个月以上）");
  mod5.set("order", 5);
  app.save(mod5);

  // Lesson 5.1 — free preview
  const l51 = new Record(lessonsCol);
  l51.set("course", course.id);
  l51.set("module", mod5.id);
  l51.set("title_en", "First Foods: Signs of Readiness & Safe Choices");
  l51.set("title_ms", "Makanan Pertama: Tanda-tanda Kesediaan & Pilihan Selamat");
  l51.set("title_zh", "第一口辅食：准备好的信号与安全选择");
  l51.set("description_en", "The WHO recommends introducing solids at around 6 months, alongside continued breastfeeding. But readiness is more important than age. This lesson covers the three key readiness signs, the safest first foods for Malaysian babies (including iron-rich options critical for breastfed babies), what to expect in the first few weeks, and the common allergens to introduce early and carefully. You'll also learn which foods are not safe before 12 months.");
  l51.set("description_ms", "WHO mengesyorkan memperkenalkan makanan pepejal pada sekitar 6 bulan, bersama penyusuan berterusan. Tetapi kesediaan lebih penting daripada usia. Pelajaran ini merangkumi tiga tanda kesediaan utama, makanan pertama yang paling selamat untuk bayi Malaysia (termasuk pilihan kaya zat besi yang kritikal untuk bayi yang disusukan), apa yang diharapkan dalam beberapa minggu pertama, dan alergen biasa yang perlu diperkenalkan awal dengan berhati-hati.");
  l51.set("description_zh", "世卫组织建议在6个月左右引入辅食，同时继续母乳喂养。但准备好比年龄更重要。本课涵盖三个关键准备信号、马来西亚宝宝最安全的第一口辅食（包括母乳宝宝至关重要的富铁选项）、最初几周的预期，以及需要早期谨慎引入的常见过敏原。");
  l51.set("video_url", "https://www.youtube.com/watch?v=sXM-YVYcHNE");
  l51.set("video_provider", "youtube");
  l51.set("video_duration", 600);
  l51.set("completion_threshold", 100);
  l51.set("has_quiz", false);
  l51.set("order", 1);
  l51.set("is_published", true);
  l51.set("is_free_preview", true);
  app.save(l51);

  // Lesson 5.2 — with quiz
  const l52 = new Record(lessonsCol);
  l52.set("course", course.id);
  l52.set("module", mod5.id);
  l52.set("title_en", "Purées vs. Baby-Led Weaning: A Practical Comparison");
  l52.set("title_ms", "Puri vs. Baby-Led Weaning: Perbandingan Praktikal");
  l52.set("title_zh", "泥糊状辅食 vs. 婴儿自主进食：实用比较");
  l52.set("description_en", "Both purées and baby-led weaning (BLW) are safe, evidence-based approaches — and the best families combine both. This lesson compares the two methods in depth: the research evidence, practical day-to-day differences, how to do each safely, and how to create a simple weekly meal plan for a 6–9 month old. Critically, you will learn to distinguish gagging (normal and protective) from choking (an emergency), and how to respond to each. Complete the quiz to check your knowledge.");
  l52.set("description_ms", "Kedua-dua puri dan baby-led weaning (BLW) adalah pendekatan yang selamat dan berasaskan bukti — dan keluarga terbaik menggabungkan kedua-duanya. Pelajaran ini membandingkan dua kaedah secara mendalam dan cara membuat rancangan makan mingguan yang mudah untuk bayi berusia 6–9 bulan. Anda juga akan belajar membezakan tersedak (normal dan pelindung) daripada lemas (kecemasan).");
  l52.set("description_zh", "泥糊状辅食和婴儿自主进食（BLW）都是安全、循证的方法——最好的家庭将两者结合使用。本课深入比较这两种方法，以及如何为6–9个月的宝宝制定简单的每周膳食计划。关键是，您将学会区分作呕（正常且有保护性）和噎住（紧急情况），以及如何应对。完成测验检验您的知识。");
  l52.set("video_url", "https://www.youtube.com/watch?v=xHmBJEFm6-0");
  l52.set("video_provider", "youtube");
  l52.set("video_duration", 720);
  l52.set("completion_threshold", 100);
  l52.set("has_quiz", true);
  l52.set("order", 2);
  l52.set("is_published", true);
  l52.set("is_free_preview", false);
  app.save(l52);

  const quiz52 = new Record(quizzesCol);
  quiz52.set("lesson", l52.id);
  quiz52.set("passing_score", 70);
  quiz52.set("questions", [
    {
      question: "What are the THREE key signs that a baby is ready to start solid foods?",
      options: [
        "Baby has reached exactly 6 months of age",
        "Baby can sit upright with minimal support, has lost the tongue-thrust reflex, and shows interest in food",
        "Baby has doubled their birth weight and is sleeping through the night",
        "Baby is fussing more than usual and waking frequently at night"
      ],
      correct: 1,
      explanation: "Readiness for solids is about developmental signs, not just age. All three signs should be present: sitting with support, loss of the tongue-thrust reflex (no longer pushing food out), and showing interest in food."
    },
    {
      question: "What is the difference between gagging and choking during baby-led weaning?",
      options: [
        "There is no difference — both require immediate intervention",
        "Gagging is silent and dangerous; choking is noisy and normal",
        "Gagging is a normal protective reflex that moves food forward; choking is silent and requires immediate action",
        "Gagging only happens with purées; choking only happens with finger foods"
      ],
      correct: 2,
      explanation: "Gagging is a normal, protective reflex — babies gag to move food forward in the mouth. It is noisy and baby usually resolves it themselves. Choking is different — the airway is blocked, the baby cannot cry or cough effectively, and immediate first aid is needed."
    },
    {
      question: "Why is iron particularly important when starting solids at 6 months?",
      options: [
        "Because babies are born with no iron at all",
        "Because breast milk contains no nutrients after 6 months",
        "Because babies' iron stores from birth begin to deplete around 6 months, and breast milk alone cannot meet the growing demand",
        "Because iron prevents allergies when introduced early"
      ],
      correct: 2,
      explanation: "Babies are born with iron stores that last approximately 6 months. After this, breast milk alone cannot provide enough iron for their rapid growth. Iron-rich first foods (pureed meat, lentils, fortified cereals) are especially important for breastfed babies."
    }
  ]);
  app.save(quiz52);

}, (app) => {
  try {
    const course = app.findFirstRecordByFilter("courses", "title_en = {:t}", { t: "Newborn Care Essentials" });
    const mods = app.findRecordsByFilter("course_modules", "course = {:c} && order >= 3", "", 0, 0, { c: course.id });
    for (const m of mods) app.delete(m);
  } catch (_) {}
});
