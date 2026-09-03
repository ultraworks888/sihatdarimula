migrate((app) => {
  const col = app.findCollectionByNameOrId("articles");

  // ── 1. Newborn Sleep ─────────────────────────────────────────────────────
  const a1 = new Record(col);
  a1.set("title", "Newborn Sleep: What to Expect and How to Cope");
  a1.set("summary", "Why newborns sleep so little (or too much), how to build gentle routines, and safe sleep practices every parent must know.");
  a1.set("content", `<h2>Newborn Sleep — The Reality</h2>
<p>Newborns sleep a total of 14–17 hours per day, but rarely for more than 2–4 hours at a stretch. Their stomachs are tiny and fill quickly, so waking to feed is normal and necessary — not a sign that anything is wrong.</p>
<h2>Safe Sleep: The ABC Rule</h2>
<ul>
  <li><strong>A — Alone:</strong> Baby sleeps by themselves, not with adults or siblings.</li>
  <li><strong>B — Back:</strong> Always place baby on their back. This is the single most effective way to reduce SIDS risk.</li>
  <li><strong>C — Cot:</strong> A firm, flat surface with a fitted sheet and no loose bedding, pillows, or soft toys.</li>
</ul>
<h2>Why Babies Fight Sleep</h2>
<p>Overtiredness is counterintuitive — the more tired a baby gets, the harder it becomes for them to fall asleep. Watch for sleep cues: rubbing eyes, looking away, yawning, or becoming quiet. Act quickly when you see them.</p>
<h2>Building a Gentle Routine</h2>
<p>From around 6–8 weeks, begin a simple wind-down routine: a warm bath, a feed, dim lights, and quiet singing or white noise. Consistency helps your baby's brain learn that sleep is coming. Keep it short — 15–20 minutes is enough.</p>
<h2>Night and Day Confusion</h2>
<p>Newborns are born without a body clock. Help them learn: keep daytime feeds bright and social, and night feeds calm, dark, and quiet. Within a few weeks, they will begin to shift more sleep to nighttime.</p>
<h2>When to Ask for Help</h2>
<p>Talk to your doctor or child health nurse if your baby sleeps more than 17 hours a day and is hard to wake for feeds, if you are so sleep-deprived you are struggling to function safely, or if your baby snores loudly or stops breathing briefly during sleep.</p>`);
  a1.set("title_ms", "Tidur Bayi Baru Lahir: Apa yang Dijangkakan dan Cara Mengatasinya");
  a1.set("summary_ms", "Mengapa bayi baru lahir tidur sedikit (atau terlalu banyak), cara membina rutin lembut, dan amalan tidur selamat yang setiap ibu bapa perlu tahu.");
  a1.set("content_ms", `<h2>Tidur Bayi Baru Lahir — Realiti Sebenar</h2>
<p>Bayi baru lahir tidur sebanyak 14–17 jam sehari, tetapi jarang lebih dari 2–4 jam berturut-turut. Perut mereka kecil dan cepat penuh, jadi terjaga untuk menyusu adalah normal dan perlu — bukan tanda ada masalah.</p>
<h2>Tidur Selamat: Peraturan ABC</h2>
<ul>
  <li><strong>A — Alone (Bersendirian):</strong> Bayi tidur bersendirian, bukan bersama orang dewasa atau adik-beradik.</li>
  <li><strong>B — Back (Belakang):</strong> Sentiasa letakkan bayi menelentang. Ini cara paling berkesan untuk mengurangkan risiko SIDS.</li>
  <li><strong>C — Cot (Buaian/Katil Bayi):</strong> Permukaan keras dan rata dengan cadar yang sesuai — tiada tilam lembut, bantal, atau mainan.</li>
</ul>
<h2>Mengapa Bayi Menolak Tidur</h2>
<p>Keletihan berlebihan adalah berlawanan dengan intuisi — semakin penat bayi, semakin sukar untuk mereka tertidur. Perhatikan isyarat mengantuk: menggosok mata, memalingkan pandangan, menguap, atau menjadi senyap. Bertindak segera apabila anda melihatnya.</p>
<h2>Membina Rutin Lembut</h2>
<p>Dari sekitar 6–8 minggu, mulakan rutin sederhana: mandi suam, penyusuan, lampu redup, dan nyanyian lembut atau bunyi putih. Konsistensi membantu otak bayi belajar bahawa masa tidur sudah tiba. Jadikannya pendek — 15–20 minit sudah cukup.</p>
<h2>Kekeliruan Siang dan Malam</h2>
<p>Bayi baru lahir dilahirkan tanpa jam badan. Bantu mereka belajar: jadikan penyusuan siang cerah dan sosial, dan penyusuan malam tenang, gelap, dan senyap. Dalam beberapa minggu, mereka akan mula mengalihkan lebih banyak tidur ke waktu malam.</p>`);
  a1.set("title_zh", "新生儿睡眠：了解与应对");
  a1.set("summary_zh", "为什么新生儿睡眠如此碎片化、如何建立温和睡眠习惯，以及每位父母必须了解的安全睡眠规范。");
  a1.set("content_zh", `<h2>新生儿睡眠的现实</h2>
<p>新生儿每天总共睡14–17小时，但每次很少超过2–4小时。他们的胃很小，很快就会填满，因此醒来吃奶是正常且必要的——这不代表有什么问题。</p>
<h2>安全睡眠：ABC原则</h2>
<ul>
  <li><strong>A — Alone（独自）：</strong>宝宝单独睡觉，不与大人或兄弟姐妹共睡。</li>
  <li><strong>B — Back（仰卧）：</strong>始终让宝宝仰卧睡觉。这是降低婴儿猝死综合征风险最有效的方法。</li>
  <li><strong>C — Cot（婴儿床）：</strong>坚实平坦的床面，配有合适的床单，无松散床上用品、枕头或软玩具。</li>
</ul>
<h2>为什么宝宝抗拒睡觉</h2>
<p>过度疲劳与直觉相悖——宝宝越累，越难入睡。注意睡眠信号：揉眼睛、转移视线、打哈欠或变得安静。看到信号时迅速行动。</p>
<h2>建立温和睡眠习惯</h2>
<p>从大约6–8周开始，建立简单的睡前程序：温水浴、喂奶、调暗灯光、轻声哼唱或白噪音。一致性帮助宝宝的大脑学习睡眠时间到了。保持简短——15–20分钟就足够了。</p>
<h2>昼夜混淆</h2>
<p>新生儿没有生物钟。帮助他们学习：白天喂奶时保持明亮和互动，夜间喂奶时保持平静、黑暗和安静。几周内，他们就会开始将更多睡眠转移到夜间。</p>`);
  a1.set("category", "general");
  a1.set("reading_time", "5 min read");
  a1.set("min_age_months", 0);
  a1.set("max_age_months", 6);
  a1.set("is_pregnancy", false);
  app.save(a1);

  // ── 2. Pregnancy Nutrition ───────────────────────────────────────────────
  const a2 = new Record(col);
  a2.set("title", "Eating Well During Pregnancy: Trimester by Trimester");
  a2.set("summary", "What to eat, what to avoid, and the key nutrients that support your baby's development at every stage of pregnancy.");
  a2.set("content", `<h2>Why Pregnancy Nutrition Matters</h2>
<p>What you eat during pregnancy directly fuels your baby's brain, bones, organs, and immune system. You do not need to eat for two in terms of quantity — but quality matters enormously.</p>
<h2>First Trimester (Weeks 1–12)</h2>
<p><strong>Focus: Folic acid & preventing neural tube defects.</strong> Take 400–800 mcg of folic acid daily. Many women struggle with nausea — eat small, frequent meals of bland foods. Ginger tea, crackers, and cold foods often help. Stay hydrated even if eating is difficult.</p>
<h2>Second Trimester (Weeks 13–26)</h2>
<p><strong>Focus: Iron, calcium & growing bones.</strong> Your blood volume increases by up to 50% — iron demand rises sharply. Eat iron-rich foods (lean meat, lentils, spinach) with vitamin C to boost absorption. Include 3–4 servings of calcium-rich foods daily: milk, yoghurt, tofu, or sardines with bones. Most women find their appetite improves and nausea eases this trimester.</p>
<h2>Third Trimester (Weeks 27–40)</h2>
<p><strong>Focus: Omega-3, energy & preparing for breastfeeding.</strong> Your baby's brain grows rapidly now. Eat oily fish (salmon, sardines) 2–3 times a week for DHA. You need an extra 300–450 kcal per day — choose nutrient-dense snacks: nuts, eggs, fruit, and wholegrains.</p>
<h2>Key Nutrients at a Glance</h2>
<ul>
  <li><strong>Folic acid:</strong> Prevents neural tube defects (leafy greens, fortified cereals)</li>
  <li><strong>Iron:</strong> Prevents anaemia (lean meat, legumes, fortified cereals)</li>
  <li><strong>Calcium:</strong> Builds baby's bones (dairy, tofu, sardines)</li>
  <li><strong>Iodine:</strong> Supports brain development (seafood, iodised salt)</li>
  <li><strong>Omega-3 DHA:</strong> Brain and eye development (oily fish, chia seeds)</li>
</ul>
<h2>Foods to Avoid</h2>
<p>Raw or undercooked meat and seafood, unpasteurised dairy, deli meats, high-mercury fish (shark, swordfish, king mackerel), raw eggs, alcohol, and excess caffeine (keep under 200 mg/day — about one cup of coffee).</p>`);
  a2.set("title_ms", "Pemakanan Semasa Mengandung: Mengikut Trimester");
  a2.set("summary_ms", "Apa yang perlu dimakan, apa yang perlu dielakkan, dan nutrien utama yang menyokong perkembangan bayi anda di setiap peringkat kehamilan.");
  a2.set("content_ms", `<h2>Mengapa Pemakanan Semasa Mengandung Penting</h2>
<p>Apa yang anda makan semasa mengandung secara langsung membekalkan otak, tulang, organ, dan sistem imun bayi anda. Anda tidak perlu makan untuk dua orang dari segi kuantiti — tetapi kualiti sangat penting.</p>
<h2>Trimester Pertama (Minggu 1–12)</h2>
<p><strong>Fokus: Asid folik &amp; mencegah kecacatan tiub neural.</strong> Ambil 400–800 mcg asid folik setiap hari. Ramai wanita mengalami loya — makan sedikit tetapi kerap dengan makanan hambar. Teh halia, biskut, dan makanan sejuk sering membantu. Kekal terhidrat walaupun sukar makan.</p>
<h2>Trimester Kedua (Minggu 13–26)</h2>
<p><strong>Fokus: Zat besi, kalsium &amp; pertumbuhan tulang.</strong> Isipadu darah anda meningkat sehingga 50% — keperluan zat besi meningkat dengan ketara. Makan makanan kaya zat besi (daging tanpa lemak, kacang lentil, bayam) bersama vitamin C. Ambil 3–4 hidangan makanan kaya kalsium setiap hari: susu, yogurt, tauhu, atau sardin dengan tulang.</p>
<h2>Trimester Ketiga (Minggu 27–40)</h2>
<p><strong>Fokus: Omega-3, tenaga &amp; persediaan untuk penyusuan.</strong> Otak bayi anda berkembang pesat sekarang. Makan ikan berminyak (salmon, sardin) 2–3 kali seminggu untuk DHA. Anda memerlukan tambahan 300–450 kcal sehari — pilih snek padat nutrien: kacang, telur, buah-buahan, dan bijirin penuh.</p>
<h2>Nutrien Utama</h2>
<ul>
  <li><strong>Asid folik:</strong> Mencegah kecacatan tiub neural (sayuran berdaun, bijirin berfortifikasi)</li>
  <li><strong>Zat besi:</strong> Mencegah anemia (daging tanpa lemak, kekacang)</li>
  <li><strong>Kalsium:</strong> Membina tulang bayi (tenusu, tauhu, sardin)</li>
  <li><strong>Iodin:</strong> Menyokong perkembangan otak (makanan laut, garam beriodin)</li>
  <li><strong>Omega-3 DHA:</strong> Perkembangan otak dan mata (ikan berminyak, biji chia)</li>
</ul>
<h2>Makanan yang Perlu Dielakkan</h2>
<p>Daging dan makanan laut mentah atau kurang masak, tenusu tidak dipasteur, daging deli, ikan merkuri tinggi, telur mentah, alkohol, dan kafein berlebihan (kurangkan di bawah 200 mg/hari).</p>`);
  a2.set("title_zh", "孕期饮食指南：逐季解析");
  a2.set("summary_zh", "妊娠各阶段应该吃什么、避免什么，以及支持宝宝发育的关键营养素。");
  a2.set("content_zh", `<h2>孕期营养为何如此重要</h2>
<p>您在孕期的饮食直接为宝宝的大脑、骨骼、器官和免疫系统提供能量。您不需要在数量上"一人吃两人份"——但质量至关重要。</p>
<h2>孕早期（第1–12周）</h2>
<p><strong>重点：叶酸与预防神经管缺陷。</strong>每天补充400–800微克叶酸。许多孕妇有恶心感——少量多餐，选择清淡食物。姜茶、饼干和冷食通常有帮助。即使难以进食也要保持水分补充。</p>
<h2>孕中期（第13–26周）</h2>
<p><strong>重点：铁、钙与骨骼发育。</strong>血容量增加高达50%，铁需求急剧上升。食用富含铁的食物（瘦肉、小扁豆、菠菜）并搭配维生素C促进吸收。每天摄入3–4份富含钙的食物：牛奶、酸奶、豆腐或带骨沙丁鱼。大多数孕妇此阶段食欲改善，恶心减轻。</p>
<h2>孕晚期（第27–40周）</h2>
<p><strong>重点：Omega-3、能量与哺乳准备。</strong>宝宝的大脑现在迅速发育。每周吃2–3次富脂鱼（三文鱼、沙丁鱼）补充DHA。每天需要额外300–450千卡——选择营养密集的零食：坚果、鸡蛋、水果和全谷物。</p>
<h2>关键营养素一览</h2>
<ul>
  <li><strong>叶酸：</strong>预防神经管缺陷（深绿色蔬菜、强化谷物）</li>
  <li><strong>铁：</strong>预防贫血（瘦肉、豆类、强化谷物）</li>
  <li><strong>钙：</strong>构建宝宝骨骼（乳制品、豆腐、沙丁鱼）</li>
  <li><strong>碘：</strong>支持大脑发育（海鲜、碘盐）</li>
  <li><strong>Omega-3 DHA：</strong>大脑和眼睛发育（富脂鱼、奇亚籽）</li>
</ul>
<h2>应避免的食物</h2>
<p>生的或未熟透的肉类和海鲜、未经巴氏消毒的乳制品、熟食肉类、高汞鱼类（鲨鱼、箭鱼）、生鸡蛋、酒精，以及过量咖啡因（每天不超过200毫克——约一杯咖啡）。</p>`);
  a2.set("category", "pregnancy");
  a2.set("reading_time", "6 min read");
  a2.set("min_age_months", 0);
  a2.set("max_age_months", 0);
  a2.set("is_pregnancy", true);
  app.save(a2);

  // ── 3. 6–9 Month Milestones ─────────────────────────────────────────────
  const a3 = new Record(col);
  a3.set("title", "Your Baby at 6–9 Months: Milestones & Play Ideas");
  a3.set("summary", "From sitting unaided and starting solids to babbling and separation anxiety — what to expect and how to nurture your baby's rapid development.");
  a3.set("content", `<h2>A Busy, Curious Period</h2>
<p>Between 6 and 9 months, your baby's world expands dramatically. They are becoming mobile, vocal, and socially complex. This is one of the most rewarding and busy phases of the first year.</p>
<h2>Motor Development</h2>
<ul>
  <li><strong>6 months:</strong> Sits with minimal support, bears weight on legs when held standing, rolls in both directions</li>
  <li><strong>7 months:</strong> Sits unsupported, may begin to commando crawl (dragging body along floor)</li>
  <li><strong>8–9 months:</strong> Crawls on hands and knees, pulls to standing at furniture, may begin to cruise (walk while holding furniture)</li>
</ul>
<h2>Communication & Language</h2>
<p>Your baby is now babbling with consonant sounds: "ba-ba", "ma-ma", "da-da". They may not understand these as words yet, but they are practising the building blocks of language. Respond to their babbles as if they are saying something — this is called conversational turn-taking and is essential for language development.</p>
<h2>Cognitive & Social</h2>
<ul>
  <li>Understands object permanence (knows you still exist when out of sight)</li>
  <li>Separation anxiety begins — completely normal</li>
  <li>Loves peek-a-boo (it teaches that hidden things return)</li>
  <li>Imitates sounds, facial expressions, and simple actions</li>
  <li>Responds to name consistently by 9 months</li>
</ul>
<h2>Play Ideas for 6–9 Months</h2>
<ul>
  <li>Stacking and knocking down soft blocks</li>
  <li>Looking at board books together and naming objects</li>
  <li>Textured toys for sensory exploration</li>
  <li>Music: sing, use instruments, clap rhythms</li>
  <li>Floor play with safe household objects (wooden spoons, containers)</li>
</ul>
<h2>When to Mention to Your Doctor</h2>
<p>At the 9-month check, bring it up if your baby does not babble, does not bear weight on legs, does not sit with support, does not look at where you point, or does not respond to their name.</p>`);
  a3.set("title_ms", "Bayi Anda 6–9 Bulan: Pencapaian & Idea Permainan");
  a3.set("summary_ms", "Daripada duduk sendiri dan memulakan makanan pepejal hingga berceloteh dan kebimbangan berpisah — apa yang perlu dijangkakan dan cara memupuk perkembangan pesat bayi anda.");
  a3.set("content_ms", `<h2>Tempoh yang Sibuk dan Ingin Tahu</h2>
<p>Antara 6 dan 9 bulan, dunia bayi anda berkembang secara dramatik. Mereka menjadi lebih bergerak, bersuara, dan kompleks dari segi sosial. Ini adalah salah satu fasa yang paling memuaskan dan sibuk dalam tahun pertama.</p>
<h2>Perkembangan Motor</h2>
<ul>
  <li><strong>6 bulan:</strong> Duduk dengan sokongan minimum, menanggung berat pada kaki apabila dipegang berdiri, bergolek ke kedua-dua arah</li>
  <li><strong>7 bulan:</strong> Duduk tanpa sokongan, mungkin mula merangkak commando</li>
  <li><strong>8–9 bulan:</strong> Merangkak atas tangan dan lutut, berdiri di perabot, mungkin mula "cruising"</li>
</ul>
<h2>Komunikasi & Bahasa</h2>
<p>Bayi anda kini berceloteh dengan bunyi konsonan: "ba-ba", "ma-ma", "da-da". Mereka mungkin belum memahami ini sebagai kata-kata, tetapi mereka sedang berlatih blok binaan bahasa. Balas celoteh mereka seolah-olah mereka berkata sesuatu — ini dipanggil "conversational turn-taking" dan penting untuk perkembangan bahasa.</p>
<h2>Kognitif & Sosial</h2>
<ul>
  <li>Memahami kekalnya objek (tahu anda masih ada walaupun tidak kelihatan)</li>
  <li>Kebimbangan berpisah bermula — adalah normal sepenuhnya</li>
  <li>Suka permainan sembunyi-sembunyi (mengajar bahawa perkara tersembunyi akan kembali)</li>
  <li>Meniru bunyi, ekspresi wajah, dan tindakan mudah</li>
  <li>Bertindak balas terhadap nama secara konsisten menjelang 9 bulan</li>
</ul>
<h2>Idea Permainan untuk 6–9 Bulan</h2>
<ul>
  <li>Menimbun dan mengetuk blok lembut</li>
  <li>Melihat buku papan bersama dan menamakan objek</li>
  <li>Mainan bertekstur untuk penerokaan deria</li>
  <li>Muzik: nyanyikan, gunakan alatan muzik, tepuk irama</li>
  <li>Permainan lantai dengan objek rumah yang selamat</li>
</ul>`);
  a3.set("title_zh", "宝宝6–9个月：发育里程碑与游戏建议");
  a3.set("summary_zh", "从独坐、开始辅食到咿呀学语和分离焦虑——了解期望什么以及如何培养宝宝的快速发育。");
  a3.set("content_zh", `<h2>忙碌而充满好奇的阶段</h2>
<p>在6到9个月之间，宝宝的世界急剧扩展。他们变得更活跃、更善于表达，社交也更复杂。这是第一年中最令人满足也最忙碌的阶段之一。</p>
<h2>运动发育</h2>
<ul>
  <li><strong>6个月：</strong>少量支撑下能坐，扶着时能站立承重，双向翻身</li>
  <li><strong>7个月：</strong>无支撑独坐，可能开始腹爬（身体贴地拖行）</li>
  <li><strong>8–9个月：</strong>四肢爬行，扶着家具站立，可能开始扶走</li>
</ul>
<h2>沟通与语言</h2>
<p>宝宝现在用辅音咿呀学语："ba-ba"、"ma-ma"、"da-da"。他们可能还不理解这些是词语，但正在练习语言的基础。像回应真实话语一样回应他们的咿呀声——这称为"对话轮换"，对语言发展至关重要。</p>
<h2>认知与社交</h2>
<ul>
  <li>理解客体永久性（知道你不在视线内时仍然存在）</li>
  <li>分离焦虑开始——完全正常</li>
  <li>喜欢躲猫猫（教导隐藏的事物会回来）</li>
  <li>模仿声音、面部表情和简单动作</li>
  <li>9个月时能持续响应自己的名字</li>
</ul>
<h2>6–9个月游戏建议</h2>
<ul>
  <li>叠放和推倒软积木</li>
  <li>一起看硬板书并命名物品</li>
  <li>质地玩具用于感官探索</li>
  <li>音乐：唱歌、使用乐器、拍打节奏</li>
  <li>在地板上玩安全的家用物品（木勺、容器）</li>
</ul>`);
  a3.set("category", "growth");
  a3.set("reading_time", "5 min read");
  a3.set("min_age_months", 6);
  a3.set("max_age_months", 9);
  a3.set("is_pregnancy", false);
  app.save(a3);

  // ── 4. Colic & Soothing ─────────────────────────────────────────────────
  const a4 = new Record(col);
  a4.set("title", "Colic, Crying & Soothing: A Parent's Survival Guide");
  a4.set("summary", "Understanding why your baby cries, what colic really is, and the most effective evidence-based techniques to calm a distressed infant.");
  a4.set("content", `<h2>When Crying Feels Relentless</h2>
<p>All babies cry — it is their only form of communication. But some babies cry far more than others, and excessive crying can be one of the most distressing experiences of new parenthood. You are not doing anything wrong.</p>
<h2>What Is Colic?</h2>
<p>Colic is defined as crying in an otherwise healthy baby for more than <strong>3 hours a day, more than 3 days a week, for more than 3 weeks</strong>. It typically peaks around 6 weeks and resolves by 3–4 months. The exact cause is unknown, but theories include gut immaturity, gas, overstimulation, and feeding difficulties.</p>
<h2>The 5 S's (Dr Harvey Karp)</h2>
<p>These five techniques, used together, activate a calming reflex in newborns:</p>
<ul>
  <li><strong>Swaddle:</strong> Wrap snugly (hips free) to recreate the womb feeling</li>
  <li><strong>Side/Stomach hold:</strong> Hold baby on their side or stomach (supervised — not for sleep)</li>
  <li><strong>Shush:</strong> Make a loud "shhh" sound directly near the ear — louder than the cry</li>
  <li><strong>Swing:</strong> Gentle but fast rhythmic motion (3–4 jiggles per second)</li>
  <li><strong>Suck:</strong> Offer breast, finger, or dummy</li>
</ul>
<h2>Other Proven Techniques</h2>
<ul>
  <li><strong>White noise:</strong> Womb-like sounds mask stimulation. Hair dryer, fan, or white noise apps all work.</li>
  <li><strong>Skin-to-skin / babywearing:</strong> Carrying your baby reduces crying by up to 43% (studies show)</li>
  <li><strong>Warm bath:</strong> Especially effective for gas-related discomfort</li>
  <li><strong>Bicycle legs:</strong> Gently move baby's legs in a cycling motion to relieve gas</li>
  <li><strong>Change of environment:</strong> A pram walk or car ride often works when nothing else does</li>
</ul>
<h2>When to See a Doctor</h2>
<p>Take your baby to a doctor promptly if crying is accompanied by fever, vomiting, rash, blood in stools, or if your baby appears to be in real pain (arching back, inconsolable). Also seek help if you feel you are at risk of harming your baby — this is a medical emergency. Put the baby down in a safe place and call for help.</p>
<h2>Looking After Yourself</h2>
<p>Relentless crying is hard. Ask for help. Take turns with a partner. Step outside for 5 minutes when safe to do so. You cannot pour from an empty cup.</p>`);
  a4.set("title_ms", "Kolik, Tangisan & Penenangan: Panduan Kelangsungan Ibu Bapa");
  a4.set("summary_ms", "Memahami mengapa bayi anda menangis, apa itu kolik sebenarnya, dan teknik paling berkesan berasaskan bukti untuk menenangkan bayi yang tertekan.");
  a4.set("content_ms", `<h2>Apabila Tangisan Terasa Tanpa Henti</h2>
<p>Semua bayi menangis — ia adalah satu-satunya cara komunikasi mereka. Tetapi sesetengah bayi menangis jauh lebih banyak daripada yang lain. Anda tidak melakukan apa-apa yang salah.</p>
<h2>Apakah Kolik?</h2>
<p>Kolik ditakrifkan sebagai tangisan pada bayi yang sihat selama lebih daripada <strong>3 jam sehari, lebih daripada 3 hari seminggu, selama lebih daripada 3 minggu</strong>. Ia biasanya memuncak sekitar 6 minggu dan reda menjelang 3–4 bulan.</p>
<h2>5 S (Dr Harvey Karp)</h2>
<p>Lima teknik ini, digunakan bersama, mengaktifkan refleks menenangkan pada bayi baru lahir:</p>
<ul>
  <li><strong>Swaddle (Bungkus):</strong> Bungkus dengan ketat (pinggul bebas) untuk mencipta semula perasaan dalam rahim</li>
  <li><strong>Side/Stomach hold (Pegang Sisi/Perut):</strong> Pegang bayi di sisi atau perut (diselia — bukan untuk tidur)</li>
  <li><strong>Shush (Desis):</strong> Buat bunyi "shhh" kuat terus di dekat telinga</li>
  <li><strong>Swing (Ayun):</strong> Gerakan berirama yang lembut tetapi pantas</li>
  <li><strong>Suck (Hisap):</strong> Tawarkan payudara, jari, atau puting</li>
</ul>
<h2>Teknik Lain yang Terbukti</h2>
<ul>
  <li><strong>Bunyi putih:</strong> Bunyi seperti rahim menutup rangsangan. Pengering rambut, kipas, atau aplikasi bunyi putih semuanya berkesan.</li>
  <li><strong>Sentuhan kulit-ke-kulit / mendukung bayi:</strong> Mendukung bayi anda mengurangkan tangisan sehingga 43%</li>
  <li><strong>Mandi suam:</strong> Sangat berkesan untuk ketidakselesaan berkaitan gas</li>
  <li><strong>Kaki basikal:</strong> Gerakkan kaki bayi dengan lembut dalam gerakan mengayuh untuk mengurangkan gas</li>
</ul>`);
  a4.set("title_zh", "肠绞痛、哭闹与安抚：父母生存指南");
  a4.set("summary_zh", "了解宝宝哭闹的原因、肠绞痛的真相，以及最有效的循证安抚技巧。");
  a4.set("content_zh", `<h2>当哭声感觉永无止境</h2>
<p>所有宝宝都会哭——这是他们唯一的沟通方式。但有些宝宝哭得比其他宝宝多得多。您没有做错任何事。</p>
<h2>什么是肠绞痛？</h2>
<p>肠绞痛的定义是：健康宝宝每天哭泣超过<strong>3小时，每周超过3天，持续超过3周</strong>。通常在6周时达到高峰，并在3–4个月时消退。</p>
<h2>5S法（哈维·卡普医生）</h2>
<p>这五种技术一起使用，能激活新生儿的镇静反射：</p>
<ul>
  <li><strong>包裹（Swaddle）：</strong>紧紧包裹（髋部放松）以重现子宫的感觉</li>
  <li><strong>侧卧/俯卧抱持（Side/Stomach hold）：</strong>让宝宝侧卧或趴在手臂上（需监督——不用于睡眠）</li>
  <li><strong>嘘声（Shush）：</strong>在耳边发出响亮的"嘘"声——要比哭声还响</li>
  <li><strong>摇晃（Swing）：</strong>轻柔但快速的有节奏运动</li>
  <li><strong>吮吸（Suck）：</strong>提供乳房、手指或安抚奶嘴</li>
</ul>
<h2>其他经过验证的技巧</h2>
<ul>
  <li><strong>白噪音：</strong>类似子宫的声音屏蔽刺激。吹风机、风扇或白噪音应用都有效。</li>
  <li><strong>肌肤接触/婴儿背带：</strong>抱着宝宝可减少哭泣达43%（研究证实）</li>
  <li><strong>温水浴：</strong>对气体不适特别有效</li>
  <li><strong>自行车腿：</strong>轻轻活动宝宝的腿做踩单车动作以排气</li>
</ul>`);
  a4.set("category", "general");
  a4.set("reading_time", "6 min read");
  a4.set("min_age_months", 0);
  a4.set("max_age_months", 4);
  a4.set("is_pregnancy", false);
  app.save(a4);

  // ── 5. Baby-Led Weaning vs Purees ───────────────────────────────────────
  const a5 = new Record(col);
  a5.set("title", "Baby-Led Weaning vs. Purées: Which Approach Is Right for Your Baby?");
  a5.set("summary", "A balanced look at both methods of introducing solid foods — how they work, the evidence behind each, and how to combine them for the best start.");
  a5.set("content", `<h2>Two Paths to the Same Goal</h2>
<p>Both baby-led weaning (BLW) and traditional purée feeding are safe, evidence-based approaches to introducing solids. The "best" method is the one that works for your family — and many families successfully combine both.</p>
<h2>Traditional Purée Feeding</h2>
<p><strong>How it works:</strong> You prepare smooth, blended foods and spoon-feed your baby, gradually increasing texture as they develop.</p>
<p><strong>Advantages:</strong> Easier to track intake, less mess, familiar to most families, good for babies who are slow to develop the pincer grasp.</p>
<p><strong>Progression:</strong> Start with thin, smooth purées (6 months) → thicker mash (7 months) → soft lumps (8–9 months) → finely chopped soft foods (10–12 months).</p>
<h2>Baby-Led Weaning (BLW)</h2>
<p><strong>How it works:</strong> You offer soft, appropriately-sized finger foods from the start and let your baby self-feed, exploring textures and tastes at their own pace.</p>
<p><strong>Advantages:</strong> Promotes independent eating, better regulation of hunger and fullness, exposure to a wider variety of textures early, encourages fine motor development.</p>
<p><strong>What to offer:</strong> Soft-cooked vegetables (broccoli florets, carrot sticks), ripe banana or avocado, thick strips of soft fruit, scrambled eggs, flaked fish. Always cook until soft enough to squash between your fingers.</p>
<h2>Gagging vs. Choking</h2>
<p>Gagging is a normal and protective reflex — it is NOT the same as choking. Babies gag to move food forward in their mouth. Stay calm, do not intervene, and let them work it out. Choking is silent and requires immediate action. Take an infant first aid course before starting solids.</p>
<h2>Foods to Avoid Before 12 Months</h2>
<p>Honey, whole nuts, added salt or sugar, cow's milk as a main drink, and high-mercury fish. Also avoid hard, round foods (whole grapes, whole cherry tomatoes) that are choking hazards.</p>
<h2>The Combined Approach</h2>
<p>Start with purées at family mealtimes, but also offer one or two soft finger foods for your baby to explore. This gives you the control of purées plus the developmental benefits of self-feeding. Most babies transition naturally as their skills develop.</p>`);
  a5.set("title_ms", "Baby-Led Weaning vs. Puri: Pendekatan Mana yang Sesuai untuk Bayi Anda?");
  a5.set("summary_ms", "Tinjauan seimbang tentang kedua-dua kaedah memperkenalkan makanan pepejal — cara ia berfungsi, bukti di sebalik setiap satu, dan cara menggabungkannya untuk permulaan yang terbaik.");
  a5.set("content_ms", `<h2>Dua Laluan ke Matlamat yang Sama</h2>
<p>Kedua-dua baby-led weaning (BLW) dan pemberian makanan puri tradisional adalah pendekatan selamat dan berasaskan bukti untuk memperkenalkan makanan pepejal. Kaedah "terbaik" adalah yang berfungsi untuk keluarga anda.</p>
<h2>Pemberian Makanan Puri Tradisional</h2>
<p><strong>Cara ia berfungsi:</strong> Anda menyediakan makanan yang dihaluskan dan menyuap bayi anda, secara beransur-ansur meningkatkan tekstur apabila mereka berkembang.</p>
<p><strong>Kelebihan:</strong> Lebih mudah menjejaki pengambilan, kurang kotor, biasa bagi kebanyakan keluarga.</p>
<p><strong>Perkembangan:</strong> Mulakan dengan puri halus (6 bulan) → kisar lebih pekat (7 bulan) → ketulan lembut (8–9 bulan) → makanan lembut dicincang halus (10–12 bulan).</p>
<h2>Baby-Led Weaning (BLW)</h2>
<p><strong>Cara ia berfungsi:</strong> Anda menawarkan makanan jari yang lembut dan bersaiz sesuai dari awal dan membiarkan bayi anda makan sendiri.</p>
<p><strong>Kelebihan:</strong> Menggalakkan makan bebas, pengawalan lapar dan kenyang yang lebih baik, pendedahan kepada pelbagai tekstur lebih awal.</p>
<p><strong>Apa yang ditawarkan:</strong> Sayur-sayuran yang dimasak lembut (brokoli, lobak merah), pisang atau avokado masak, jalur buah-buahan lembut, telur hancur, ikan yang dikepingkan. Sentiasa masak sehingga cukup lembut untuk dihancurkan antara jari anda.</p>
<h2>Tersedak vs. Lemas</h2>
<p>Tersedak adalah refleks normal dan perlindungan — BUKAN sama dengan lemas. Bayi tersedak untuk memindahkan makanan ke hadapan dalam mulut mereka. Tetap tenang dan biarkan mereka mengatasinya. Lemas adalah senyap dan memerlukan tindakan segera.</p>`);
  a5.set("title_zh", "婴儿自主进食（BLW）vs. 泥糊状辅食：哪种方式适合您的宝宝？");
  a5.set("summary_zh", "全面解析两种辅食添加方法——各自的原理、背后的证据，以及如何结合两者给宝宝最好的起点。");
  a5.set("content_zh", `<h2>通向同一目标的两条路</h2>
<p>婴儿自主进食（BLW）和传统泥糊辅食喂养都是安全、循证的辅食添加方法。"最好的"方法是适合您家庭的方法——许多家庭成功地将两者结合使用。</p>
<h2>传统泥糊辅食喂养</h2>
<p><strong>方法：</strong>准备光滑的搅拌食物，用勺子喂宝宝，随发育逐渐增加食物质地。</p>
<p><strong>优点：</strong>更容易跟踪摄入量，较少混乱，大多数家庭熟悉。</p>
<p><strong>进阶：</strong>从细腻泥糊（6个月）→ 较稠的泥（7个月）→ 软块（8–9个月）→ 细碎软食（10–12个月）。</p>
<h2>婴儿自主进食（BLW）</h2>
<p><strong>方法：</strong>从一开始就提供适当大小的软手指食物，让宝宝自己进食，按自己的节奏探索质地和口味。</p>
<p><strong>优点：</strong>促进独立进食，更好地调节饥饿感和饱腹感，早期接触多种质地。</p>
<p><strong>可以提供的食物：</strong>煮软的蔬菜（西兰花、胡萝卜条）、成熟的香蕉或牛油果、软水果条、炒鸡蛋、鱼片。始终煮到足够软，可以用手指捏碎。</p>
<h2>作呕 vs. 噎住</h2>
<p>作呕是正常的保护性反射——与噎住不同。宝宝通过作呕将食物向前移动。保持冷静，让他们自己处理。噎住是无声的，需要立即行动。开始辅食前请参加婴幼儿急救课程。</p>`);
  a5.set("category", "nutrition");
  a5.set("reading_time", "6 min read");
  a5.set("min_age_months", 6);
  a5.set("max_age_months", 12);
  a5.set("is_pregnancy", false);
  app.save(a5);

}, (app) => {
  const titles = [
    "Newborn Sleep: What to Expect and How to Cope",
    "Eating Well During Pregnancy: Trimester by Trimester",
    "Your Baby at 6–9 Months: Milestones & Play Ideas",
    "Colic, Crying & Soothing: A Parent's Survival Guide",
    "Baby-Led Weaning vs. Purées: Which Approach Is Right for Your Baby?",
  ];
  for (const t of titles) {
    try { app.delete(app.findFirstRecordByData("articles", "title", t)); } catch (_) {}
  }
});
