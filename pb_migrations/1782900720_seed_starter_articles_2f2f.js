migrate((app) => {
  const articles = app.findCollectionByNameOrId("articles")

  // ── Article 1: Nutrition – Breastfeeding in the First Weeks ──────────────
  const a1 = new Record(articles)
  a1.set("title", "Breastfeeding in the First Weeks")
  a1.set("summary", "Everything new mums need to know about establishing a breastfeeding routine — latching, frequency, and common challenges.")
  a1.set("content", `<h2>Why the First Weeks Matter</h2>
<p>The first few weeks of breastfeeding set the foundation for your entire nursing journey. Your body is learning to read your baby's hunger cues, and your baby is learning how to latch and feed effectively. Be patient — it takes practice for both of you.</p>
<h2>Getting the Latch Right</h2>
<p>A good latch is the key to comfortable, effective breastfeeding. Position your baby so their nose is level with your nipple. Allow your baby to open their mouth wide, then bring them to your breast — not your breast to them. Their lips should flare outward and you should see more areola above their top lip than below the bottom lip.</p>
<ul>
  <li>Signs of a good latch: no nipple pain, you can hear swallowing, baby's cheeks are rounded</li>
  <li>Signs of a poor latch: pain, clicking sounds, flattened or lipstick-shaped nipple after feeding</li>
</ul>
<h2>How Often Should You Feed?</h2>
<p>Newborns feed <strong>8–12 times per 24 hours</strong> — roughly every 2–3 hours. Feed on demand rather than by the clock. Watch for early hunger cues: rooting, sucking fists, turning the head side to side. Crying is a late hunger signal.</p>
<h2>Building Your Milk Supply</h2>
<p>Milk production works on a supply-and-demand basis. The more frequently and thoroughly your baby feeds, the more milk your body produces. Avoid supplementing with formula in the early weeks unless medically necessary, as this can reduce your supply.</p>
<h2>Common Challenges</h2>
<p><strong>Engorgement:</strong> Feed frequently, apply warm compresses before feeds, and cold packs after. <strong>Sore nipples:</strong> Check the latch first — this is the most common cause. Apply a small amount of expressed breast milk after feeds to soothe. <strong>Cluster feeding:</strong> Completely normal, especially in the evenings. Your baby is boosting your supply — hang in there.</p>
<h2>When to Seek Help</h2>
<p>Reach out to a lactation consultant or your healthcare provider if you experience severe pain, notice your baby is not producing enough wet nappies (less than 6 per day after day 4), or if your baby has not regained their birth weight by 2 weeks.</p>`)
  a1.set("summary_ms", "Semua yang ibu baru perlu tahu tentang penyusuan susu ibu — cara pelekatan betul, kekerapan, dan cabaran biasa.")
  a1.set("title_ms", "Penyusuan Susu Ibu pada Minggu-Minggu Pertama")
  a1.set("content_ms", `<h2>Mengapa Minggu Pertama Penting</h2>
<p>Beberapa minggu pertama penyusuan membentuk asas keseluruhan perjalanan penyusuan anda. Badan anda sedang belajar membaca isyarat lapar bayi, dan bayi anda belajar cara melekat dan menyusu dengan berkesan. Bersabarlah — ini memerlukan latihan untuk anda berdua.</p>
<h2>Cara Pelekatan yang Betul</h2>
<p>Pelekatan yang baik adalah kunci penyusuan yang selesa dan berkesan. Posisikan bayi anda supaya hidungnya selari dengan puting anda. Biarkan bayi membuka mulutnya lebar, kemudian bawa mereka ke payudara anda. Bibir mereka harus terlentang ke luar.</p>
<ul>
  <li>Tanda pelekatan baik: tiada kesakitan pada puting, anda boleh mendengar bunyi menelan, pipi bayi kembung</li>
  <li>Tanda pelekatan buruk: kesakitan, bunyi klik, puting berbentuk rata selepas menyusu</li>
</ul>
<h2>Berapa Kerap Perlu Menyusu?</h2>
<p>Bayi baru lahir menyusu <strong>8–12 kali dalam 24 jam</strong> — lebih kurang setiap 2–3 jam. Susu mengikut permintaan, bukan mengikut jam. Perhatikan isyarat lapar awal: mencari-cari, menghisap penumbuk, memalingkan kepala.</p>
<h2>Membina Bekalan Susu</h2>
<p>Pengeluaran susu berfungsi atas dasar permintaan dan bekalan. Semakin kerap bayi menyusu, semakin banyak susu yang dihasilkan badan anda.</p>`)
  a1.set("title_zh", "产后头几周的母乳喂养")
  a1.set("summary_zh", "新手妈妈需要了解的关于母乳喂养的一切——正确含乳、喂养频率及常见挑战。")
  a1.set("content_zh", `<h2>为什么头几周如此重要</h2>
<p>母乳喂养的头几周奠定了整个哺乳旅程的基础。您的身体正在学习识别宝宝的饥饿信号，而宝宝也在学习如何正确含乳和吸吮。请耐心等待——这对你们两人来说都需要练习。</p>
<h2>正确的含乳姿势</h2>
<p>良好的含乳是舒适、有效母乳喂养的关键。将宝宝放置在鼻子与乳头齐平的位置。让宝宝大张嘴巴，然后将宝宝引向乳房。宝宝的嘴唇应向外翻。</p>
<ul>
  <li>良好含乳的迹象：乳头不痛、能听到吞咽声、宝宝脸颊圆润</li>
  <li>含乳不良的迹象：疼痛、发出咔嗒声、哺乳后乳头变平</li>
</ul>
<h2>喂养频率</h2>
<p>新生儿每24小时喂养 <strong>8–12次</strong>——大约每2–3小时一次。按需喂养，而非按时间表。注意早期饥饿信号：寻乳反射、吸吮拳头、转头。</p>
<h2>建立奶水供应</h2>
<p>母乳分泌基于供需原则。宝宝吸吮越频繁，您的身体产奶越多。早期如无医疗必要，请避免补充奶粉，以免影响奶量。</p>`)
  a1.set("category", "nutrition")
  a1.set("reading_time", "6 min read")
  a1.set("min_age_months", 0)
  a1.set("max_age_months", 6)
  a1.set("is_pregnancy", false)
  app.save(a1)

  // ── Article 2: Growth – Your Baby's 3–6 Month Milestones ─────────────────
  const a2 = new Record(articles)
  a2.set("title", "Your Baby's 3–6 Month Developmental Milestones")
  a2.set("summary", "What to expect as your baby blossoms — from social smiles and rolling over to discovering their own hands.")
  a2.set("content", `<h2>A World of Discovery</h2>
<p>Between 3 and 6 months, your baby transforms from a sleepy newborn into a curious, interactive little person. This stage is full of exciting firsts — and understanding what to look for helps you support their development every step of the way.</p>
<h2>Social & Emotional</h2>
<ul>
  <li><strong>3 months:</strong> Recognises your face and voice, smiles responsively, begins to coo and babble</li>
  <li><strong>4 months:</strong> Laughs out loud for the first time, shows excitement by kicking and waving arms</li>
  <li><strong>5–6 months:</strong> Recognises own name, shows preferences for familiar faces, may show stranger anxiety</li>
</ul>
<h2>Physical Development</h2>
<ul>
  <li><strong>Tummy time:</strong> By 4 months, most babies lift their chest off the floor and hold their head steady. Aim for 20–30 minutes of tummy time spread across the day.</li>
  <li><strong>Rolling:</strong> Usually begins rolling from tummy to back around 4 months, and back to tummy by 5–6 months.</li>
  <li><strong>Hands:</strong> Discovers their hands around 3–4 months and brings them to their mouth. By 5 months, reaches and grasps toys deliberately.</li>
</ul>
<h2>Cognitive Development</h2>
<p>Your baby is rapidly building cause-and-effect understanding. They know that crying brings you to them, that shaking a rattle makes noise, and that your face changing expression means something is happening. Talk to them constantly — narrate your day, sing songs, and read aloud. Every word builds their brain.</p>
<h2>Sleep Patterns</h2>
<p>By 3–4 months, many babies consolidate nighttime sleep into longer stretches (4–6 hours). Total sleep is still 14–16 hours per day across night and naps. Every baby is different — if your baby is growing well and alert when awake, they are getting enough sleep.</p>
<h2>When to Talk to Your Doctor</h2>
<p>Mention it at your next check-up if your baby is not smiling by 3 months, is not reaching for objects by 5 months, seems very floppy or very stiff, or you notice they do not respond to sounds or voices.</p>`)
  a2.set("title_ms", "Pencapaian Perkembangan Bayi Anda: 3–6 Bulan")
  a2.set("summary_ms", "Apa yang perlu dijangkakan apabila bayi anda berkembang — daripada senyuman sosial dan bergolek hinggalah menemui tangannya sendiri.")
  a2.set("content_ms", `<h2>Dunia Penemuan</h2>
<p>Antara 3 hingga 6 bulan, bayi anda berubah daripada bayi baru lahir yang mengantuk kepada seorang kecil yang ingin tahu dan interaktif. Peringkat ini penuh dengan pencapaian pertama yang menarik.</p>
<h2>Sosial & Emosi</h2>
<ul>
  <li><strong>3 bulan:</strong> Mengenali wajah dan suara anda, senyum secara responsif, mula bersuara</li>
  <li><strong>4 bulan:</strong> Ketawa kuat buat pertama kali, menunjukkan keseronokan dengan menendang dan melambai tangan</li>
  <li><strong>5–6 bulan:</strong> Mengenali namanya sendiri, menunjukkan keutamaan untuk wajah yang biasa</li>
</ul>
<h2>Perkembangan Fizikal</h2>
<ul>
  <li><strong>Masa perut:</strong> Pada 4 bulan, kebanyakan bayi mengangkat dada dari lantai. Sasarkan 20–30 minit masa perut setiap hari.</li>
  <li><strong>Bergolek:</strong> Biasanya mula bergolek dari perut ke belakang sekitar 4 bulan.</li>
  <li><strong>Tangan:</strong> Menemui tangannya sekitar 3–4 bulan dan membawa ke mulut.</li>
</ul>
<h2>Perkembangan Kognitif</h2>
<p>Bayi anda sedang membina pemahaman sebab-akibat dengan cepat. Bercakap dengan mereka secara berterusan — ceritakan hari anda, nyanyikan lagu, dan baca dengan kuat. Setiap perkataan membina otak mereka.</p>`)
  a2.set("title_zh", "宝宝3–6个月发育里程碑")
  a2.set("summary_zh", "了解宝宝的成长历程——从社交微笑和翻身，到发现自己的小手。")
  a2.set("content_zh", `<h2>探索的世界</h2>
<p>在3到6个月之间，您的宝宝从一个嗜睡的新生儿变成一个好奇、互动的小人儿。这个阶段充满了令人兴奋的第一次。</p>
<h2>社交与情感</h2>
<ul>
  <li><strong>3个月：</strong>认出您的脸和声音，会微笑回应，开始咿呀学语</li>
  <li><strong>4个月：</strong>第一次大声笑，踢腿挥手表达兴奋</li>
  <li><strong>5–6个月：</strong>认出自己的名字，对熟悉的面孔表现出偏好</li>
</ul>
<h2>体格发育</h2>
<ul>
  <li><strong>俯卧时间：</strong>4个月时，大多数宝宝能抬起胸部。每天目标20–30分钟俯卧时间。</li>
  <li><strong>翻身：</strong>通常在4个月左右从趴到仰，5–6个月从仰到趴。</li>
  <li><strong>小手：</strong>3–4个月发现自己的手并放入嘴里，5个月时开始有意识地抓握玩具。</li>
</ul>
<h2>认知发展</h2>
<p>您的宝宝正在迅速建立因果理解。持续和他们说话——讲述您的一天、唱歌、大声朗读。每一个词都在构建他们的大脑。</p>`)
  a2.set("category", "growth")
  a2.set("reading_time", "5 min read")
  a2.set("min_age_months", 3)
  a2.set("max_age_months", 6)
  a2.set("is_pregnancy", false)
  app.save(a2)

  // ── Article 3: Wellbeing – Understanding the Baby Blues & PND ─────────────
  const a3 = new Record(articles)
  a3.set("title", "Baby Blues vs. Postnatal Depression: What Every Mum Should Know")
  a3.set("summary", "Feeling overwhelmed after birth is common — but knowing the difference between baby blues and postnatal depression could be life-changing.")
  a3.set("content", `<h2>You Are Not Alone</h2>
<p>The arrival of a new baby brings profound joy — but also exhaustion, uncertainty, and sometimes, unexpected sadness. Feeling emotional after birth is incredibly common. What matters is understanding what your feelings mean and knowing when to reach out for support.</p>
<h2>What Are the Baby Blues?</h2>
<p>The <strong>baby blues</strong> affect up to <strong>80% of new mothers</strong> and typically begin within 2–3 days after birth, peaking around day 4–5. They are caused by the dramatic hormonal shift as oestrogen and progesterone levels drop after delivery.</p>
<p>Signs of the baby blues include: tearfulness for no clear reason, mood swings, irritability, feeling overwhelmed, and difficulty sleeping even when the baby is asleep. The baby blues resolve on their own within 2 weeks.</p>
<h2>What Is Postnatal Depression?</h2>
<p><strong>Postnatal depression (PND)</strong> affects approximately <strong>1 in 5 Malaysian mothers</strong>. Unlike the baby blues, PND does not simply pass — it requires care and support.</p>
<p>Symptoms of PND include:</p>
<ul>
  <li>Persistent sadness, emptiness, or hopelessness lasting more than 2 weeks</li>
  <li>Loss of interest in things you used to enjoy</li>
  <li>Difficulty bonding with your baby</li>
  <li>Feeling like a failure or that your baby would be better off without you</li>
  <li>Severe anxiety or panic attacks</li>
  <li>Thoughts of self-harm</li>
</ul>
<h2>Key Differences at a Glance</h2>
<p><strong>Baby Blues:</strong> Starts 2–3 days after birth, lasts up to 2 weeks, mild and self-resolving.<br>
<strong>Postnatal Depression:</strong> Can start anytime in the first year, lasts weeks or months without treatment, requires professional support.</p>
<h2>How to Support Yourself</h2>
<ul>
  <li>Accept help — from your partner, family, and friends. You do not need to do this alone.</li>
  <li>Rest whenever you can. Sleep deprivation amplifies every difficult emotion.</li>
  <li>Eat regularly. Skipping meals lowers your mood and energy.</li>
  <li>Talk about your feelings. Keeping them inside makes them heavier.</li>
  <li>Use the Wellbeing tracker in this app to monitor your mood over time.</li>
</ul>
<h2>When to Seek Help</h2>
<p>If your low mood, anxiety, or hopelessness lasts more than 2 weeks after birth — or is severe at any point — please speak to your doctor, midwife, or a mental health professional. PND is treatable. Reaching out is a sign of strength, not weakness.</p>
<p>In Malaysia, you can contact <strong>Befrienders KL</strong> at 03-7627 2929 (24 hours) if you need someone to talk to.</p>`)
  a3.set("title_ms", "Baby Blues vs. Kemurungan Selepas Bersalin: Apa yang Setiap Ibu Perlu Tahu")
  a3.set("summary_ms", "Berasa tertekan selepas bersalin adalah perkara biasa — tetapi mengetahui perbezaan antara baby blues dan kemurungan selepas bersalin boleh mengubah hidup anda.")
  a3.set("content_ms", `<h2>Anda Tidak Keseorangan</h2>
<p>Kedatangan bayi baru membawa kegembiraan yang mendalam — tetapi juga keletihan, ketidakpastian, dan kadangkala, kesedihan yang tidak dijangka. Berasa emosional selepas bersalin adalah perkara yang sangat biasa.</p>
<h2>Apakah Baby Blues?</h2>
<p><strong>Baby blues</strong> mempengaruhi sehingga <strong>80% ibu baru</strong> dan biasanya bermula dalam 2–3 hari selepas bersalin. Ia disebabkan oleh perubahan hormon yang dramatik selepas bersalin.</p>
<p>Tanda-tanda baby blues: menangis tanpa sebab yang jelas, perubahan mood, mudah marah, berasa tertekan. Baby blues akan hilang sendiri dalam masa 2 minggu.</p>
<h2>Apakah Kemurungan Selepas Bersalin?</h2>
<p><strong>Kemurungan selepas bersalin (KSB)</strong> mempengaruhi kira-kira <strong>1 dalam 5 ibu Malaysia</strong>. Tidak seperti baby blues, KSB tidak berlalu begitu sahaja — ia memerlukan penjagaan dan sokongan.</p>
<p>Gejala KSB termasuk: kesedihan berterusan lebih dari 2 minggu, kehilangan minat, kesukaran untuk membentuk ikatan dengan bayi, perasaan gagal, kebimbangan yang teruk.</p>
<h2>Cara Menyokong Diri Sendiri</h2>
<ul>
  <li>Terima bantuan daripada pasangan, keluarga, dan rakan. Anda tidak perlu melakukan ini seorang diri.</li>
  <li>Berehat bila boleh. Kekurangan tidur memperburuk setiap emosi yang sukar.</li>
  <li>Gunakan penjejak Kesejahteraan dalam aplikasi ini untuk memantau mood anda dari masa ke masa.</li>
</ul>
<h2>Bila Perlu Mendapatkan Bantuan</h2>
<p>Jika mood rendah atau kebimbangan berlangsung lebih dari 2 minggu — sila bercakap dengan doktor atau profesional kesihatan mental anda. Di Malaysia, anda boleh menghubungi <strong>Befrienders KL</strong> di 03-7627 2929 (24 jam).</p>`)
  a3.set("title_zh", "产后忧郁与产后抑郁：每位妈妈都应了解的知识")
  a3.set("summary_zh", "产后感到不知所措很常见——但了解产后忧郁和产后抑郁之间的区别可能改变您的人生。")
  a3.set("content_zh", `<h2>您并不孤单</h2>
<p>新生命的到来带来深深的喜悦——但也带来疲惫、不确定，有时还有意想不到的悲伤。产后情绪化非常普遍。</p>
<h2>什么是产后忧郁？</h2>
<p><strong>产后忧郁</strong>影响高达<strong>80%的新妈妈</strong>，通常在产后2–3天内开始，由分娩后雌激素和孕激素水平骤降引起。</p>
<p>产后忧郁的迹象：无故哭泣、情绪波动、易怒、感到不知所措。产后忧郁会在2周内自然消退。</p>
<h2>什么是产后抑郁？</h2>
<p><strong>产后抑郁（PND）</strong>影响约<strong>五分之一的马来西亚母亲</strong>。与产后忧郁不同，产后抑郁不会自行消失——需要护理和支持。</p>
<p>产后抑郁的症状包括：持续超过2周的悲伤、对事物失去兴趣、难以与宝宝建立亲密关系、感觉失败、严重焦虑。</p>
<h2>如何照顾自己</h2>
<ul>
  <li>接受帮助——来自伴侣、家人和朋友。您不必独自承担。</li>
  <li>尽可能休息。睡眠不足会放大每一种困难情绪。</li>
  <li>使用本应用中的健康追踪器随时间监测您的情绪变化。</li>
</ul>
<h2>何时寻求帮助</h2>
<p>如果产后情绪低落或焦虑持续超过2周，请向医生或心理健康专业人士咨询。在马来西亚，您可以拨打<strong>Befrienders KL</strong>热线 03-7627 2929（24小时）寻求帮助。</p>`)
  a3.set("category", "wellbeing")
  a3.set("reading_time", "7 min read")
  a3.set("min_age_months", 0)
  a3.set("max_age_months", 12)
  a3.set("is_pregnancy", false)
  app.save(a3)

}, (app) => {
  const titles = [
    "Breastfeeding in the First Weeks",
    "Your Baby's 3–6 Month Developmental Milestones",
    "Baby Blues vs. Postnatal Depression: What Every Mum Should Know",
  ]
  for (const title of titles) {
    try {
      const record = app.findFirstRecordByData("articles", "title", title)
      app.delete(record)
    } catch (_) {}
  }
})