
migrate((app) => {
  const col = app.findCollectionByNameOrId("articles")

  const articles = [
    {
      title: "Understanding Your Baby's Growth Charts",
      summary: "Learn how to read WHO growth percentiles and what they mean for your child's development.",
      content: "<p>Growth charts are one of the most important tools your pediatrician uses to track your baby's physical development. They compare your child's measurements against thousands of healthy children of the same age and gender.</p><h3>What Are Percentiles?</h3><p>If your baby is at the 50th percentile for weight, it means 50% of babies weigh more and 50% weigh less. Being at a higher or lower percentile isn't necessarily good or bad — what matters most is that your baby follows a consistent growth curve over time.</p><h3>Key Measurements</h3><p><strong>Weight:</strong> Measured at every visit, this is the most sensitive indicator of nutrition and health.</p><p><strong>Length/Height:</strong> Reflects overall growth and genetic potential.</p><p><strong>Head Circumference:</strong> Important for monitoring brain growth, especially in the first two years.</p><h3>When to Be Concerned</h3><p>Talk to your doctor if your baby crosses two or more percentile lines up or down, or if measurements fall below the 3rd or above the 97th percentile consistently.</p>",
      category: "growth",
      min_age_months: 0,
      max_age_months: 36,
      is_pregnancy: false,
      reading_time: "4 min read"
    },
    {
      title: "Breastfeeding 101: Getting Started",
      summary: "Essential tips for new mothers beginning their breastfeeding journey with confidence.",
      content: "<p>Breastfeeding is a learned skill for both mother and baby. While it's natural, it doesn't always come naturally. Here's what you need to know to get started.</p><h3>The First Hour</h3><p>Skin-to-skin contact immediately after birth helps trigger your baby's instinct to latch. Most babies will begin to root and latch within the first hour if given the chance.</p><h3>How Often to Feed</h3><p>Newborns typically feed 8-12 times per day. Watch for hunger cues: rooting, hand-to-mouth movements, and fussing. Crying is a late hunger sign.</p><h3>Signs of Good Latch</h3><p>A proper latch should feel like a tugging sensation, not pain. Your baby's mouth should be wide open with lips flanged outward, and you should hear swallowing sounds.</p><h3>Building Supply</h3><p>Your milk supply works on demand — the more your baby feeds, the more milk you produce. Stay hydrated, eat well, and try to rest when possible.</p>",
      category: "nutrition",
      min_age_months: 0,
      max_age_months: 12,
      is_pregnancy: false,
      reading_time: "5 min read"
    },
    {
      title: "Introduction to Solid Foods",
      summary: "When and how to safely introduce your baby to their first solid foods around 6 months.",
      content: "<p>Starting solids is an exciting milestone! Most babies are ready between 4-6 months, but the WHO recommends exclusive breastfeeding until 6 months.</p><h3>Signs of Readiness</h3><p>Your baby can sit upright with support, shows interest in food, has lost the tongue-thrust reflex, and can pick up objects and bring them to their mouth.</p><h3>First Foods</h3><p>Great starter foods include iron-fortified single-grain cereal, pureed sweet potato, avocado, banana, and peas. Introduce one new food every 3-5 days to watch for allergies.</p><h3>Texture Progression</h3><p><strong>6 months:</strong> Smooth purees<br><strong>7-8 months:</strong> Mashed and lumpy textures<br><strong>9-10 months:</strong> Finely chopped soft foods<br><strong>12+ months:</strong> Family foods, cut appropriately</p><h3>Foods to Avoid</h3><p>Before age 1, avoid honey (botulism risk), whole nuts (choking hazard), cow's milk as a main drink, and excessive salt or sugar.</p>",
      category: "nutrition",
      min_age_months: 4,
      max_age_months: 12,
      is_pregnancy: false,
      reading_time: "4 min read"
    },
    {
      title: "The Power of Tummy Time",
      summary: "Why tummy time matters and how to make it enjoyable for your baby from day one.",
      content: "<p>Tummy time is essential for building the strength your baby needs to roll over, sit up, crawl, and eventually walk. Start from the very first day home!</p><h3>Benefits</h3><p>Strengthens neck, shoulder, and core muscles. Prevents flat spots on the back of the head. Promotes motor development and sensory exploration.</p><h3>How to Start</h3><p><strong>Newborns:</strong> Start with 1-2 minutes, 2-3 times daily. Placing baby on your chest counts!<br><strong>1-2 months:</strong> Build to 10 minutes total per day<br><strong>3-4 months:</strong> Aim for 20-30 minutes spread throughout the day<br><strong>5-6 months:</strong> As much as they enjoy!</p><h3>Making It Fun</h3><p>Use colorful toys, mirrors, and tummy time mats. Get down on the floor at your baby's level. Sing songs and make faces to keep them engaged.</p>",
      category: "activity",
      min_age_months: 0,
      max_age_months: 6,
      is_pregnancy: false,
      reading_time: "3 min read"
    },
    {
      title: "Key Developmental Milestones: 0-12 Months",
      summary: "A comprehensive guide to the exciting milestones your baby will reach in their first year.",
      content: "<p>Every baby develops at their own pace, but these general milestones can help you track progress and know what to look for.</p><h3>0-3 Months</h3><p>Lifts head during tummy time, follows objects with eyes, smiles socially, coos and makes sounds, recognizes familiar faces.</p><h3>4-6 Months</h3><p>Rolls over both ways, reaches for and grasps objects, laughs out loud, begins to sit with support, babbles with consonant sounds.</p><h3>7-9 Months</h3><p>Sits without support, starts to crawl, uses pincer grasp, responds to own name, may say 'mama' or 'dada', shows stranger anxiety.</p><h3>10-12 Months</h3><p>Pulls to stand, may take first steps, waves bye-bye, uses simple gestures, says 1-3 words, follows simple instructions.</p><h3>When to Talk to Your Doctor</h3><p>Every child develops differently, but consult your pediatrician if your baby isn't meeting several milestones for their age group.</p>",
      category: "activity",
      min_age_months: 0,
      max_age_months: 12,
      is_pregnancy: false,
      reading_time: "5 min read"
    },
    {
      title: "Postpartum Mood: What's Normal and When to Seek Help",
      summary: "Understanding the emotional changes after birth and recognizing signs of postpartum depression.",
      content: "<p>The postpartum period brings enormous emotional and hormonal changes. Understanding what's normal can help you know when to reach out for support.</p><h3>Baby Blues</h3><p>Up to 80% of new mothers experience the 'baby blues' — mood swings, crying spells, anxiety, and difficulty sleeping. These typically start 2-3 days after delivery and resolve within two weeks.</p><h3>Postpartum Depression (PPD)</h3><p>PPD affects about 1 in 7 mothers and can develop anytime in the first year. Symptoms include persistent sadness, loss of interest, difficulty bonding with baby, withdrawal from loved ones, changes in appetite or sleep, and feelings of worthlessness.</p><h3>The EPDS Screening</h3><p>The Edinburgh Postnatal Depression Scale (EPDS) is a simple 10-question screening tool. A score of 12 or higher suggests possible depression. This app includes a simplified screening to help you track your emotional wellbeing.</p><h3>Getting Help</h3><p>PPD is treatable. Talk to your doctor, a therapist, or call a helpline. You are not alone, and seeking help is a sign of strength, not weakness.</p>",
      category: "wellbeing",
      min_age_months: 0,
      max_age_months: 12,
      is_pregnancy: false,
      reading_time: "5 min read"
    },
    {
      title: "Your Complete Vaccination Guide",
      summary: "Understanding the recommended immunisation schedule and why each vaccine matters.",
      content: "<p>Vaccines are one of the most important ways to protect your child from serious diseases. Here's what you need to know about the recommended schedule.</p><h3>Why Vaccinate?</h3><p>Vaccines work by training the immune system to recognize and fight specific germs. They protect not only your child but also vulnerable community members who cannot be vaccinated.</p><h3>Key Vaccines</h3><p><strong>BCG (Birth):</strong> Protects against tuberculosis<br><strong>Hepatitis B (Birth, 6mo):</strong> Prevents liver disease<br><strong>DTaP (2, 4, 6, 18mo):</strong> Guards against diphtheria, tetanus, and whooping cough<br><strong>IPV (2, 4, 6, 18mo):</strong> Polio protection<br><strong>MMR (12, 24mo):</strong> Measles, mumps, and rubella<br><strong>PCV (2, 6, 9mo):</strong> Pneumococcal disease</p><h3>Managing Side Effects</h3><p>Mild side effects like low fever, fussiness, and injection site redness are normal and usually resolve within 48 hours. Use a cool compress and consult your doctor about appropriate pain relief.</p>",
      category: "immunisation",
      min_age_months: 0,
      max_age_months: 36,
      is_pregnancy: false,
      reading_time: "4 min read"
    },
    {
      title: "First Trimester: What to Expect",
      summary: "A week-by-week guide to the first 12 weeks of your pregnancy journey.",
      content: "<p>The first trimester (weeks 1-12) is a time of incredible change for both you and your developing baby.</p><h3>Your Baby's Development</h3><p><strong>Weeks 1-4:</strong> Fertilization and implantation occur. The neural tube (future brain and spinal cord) begins forming.<br><strong>Weeks 5-8:</strong> The heart starts beating. Tiny limb buds appear. Facial features begin to form.<br><strong>Weeks 9-12:</strong> All major organs are formed. Fingers and toes develop. Baby begins to move (you can't feel it yet).</p><h3>Common Symptoms</h3><p>Morning sickness (can happen any time of day), fatigue, breast tenderness, frequent urination, and food aversions are all normal first trimester experiences.</p><h3>Essential Actions</h3><p>Start prenatal vitamins (especially folic acid), schedule your first prenatal appointment, avoid alcohol and raw foods, stay hydrated, and get adequate rest.</p>",
      category: "pregnancy",
      min_age_months: 0,
      max_age_months: 0,
      is_pregnancy: true,
      reading_time: "4 min read"
    },
    {
      title: "Preparing for Labor and Delivery",
      summary: "Everything you need to know to feel confident and prepared for the big day.",
      content: "<p>As your due date approaches, preparation can help reduce anxiety and empower you for the birth experience.</p><h3>Signs of Labor</h3><p>Regular contractions that get stronger and closer together, water breaking, bloody show (mucus plug), and lower back pain that doesn't go away.</p><h3>When to Go to the Hospital</h3><p>The general rule for first-time mothers: go when contractions are 5 minutes apart, lasting 1 minute each, for at least 1 hour (the 5-1-1 rule). Go immediately if your water breaks or you have heavy bleeding.</p><h3>Hospital Bag Essentials</h3><p>For mom: comfortable clothes, toiletries, nursing bras, phone charger, snacks. For baby: going-home outfit, car seat (installed!), blanket. Documents: ID, insurance card, birth plan.</p><h3>Pain Management Options</h3><p>Discuss options with your provider: breathing techniques, movement, water therapy, epidural, and other medical options. Having a flexible birth plan helps manage expectations.</p>",
      category: "pregnancy",
      min_age_months: 0,
      max_age_months: 0,
      is_pregnancy: true,
      reading_time: "5 min read"
    },
    {
      title: "Toddler Nutrition: Ages 1-3",
      summary: "Practical tips for feeding your growing toddler a balanced and nutritious diet.",
      content: "<p>Toddlers are notoriously picky eaters, but with patience and the right strategies, you can ensure they get the nutrition they need.</p><h3>Daily Nutritional Needs</h3><p>Toddlers need about 1,000-1,400 calories per day from a variety of food groups: grains, fruits, vegetables, protein, and dairy.</p><h3>Portion Sizes</h3><p>A toddler portion is roughly one-quarter of an adult portion. Offer small amounts and let them ask for more. Trust their hunger and fullness cues.</p><h3>Handling Picky Eating</h3><p>Offer new foods alongside familiar favorites. It can take 10-15 exposures before a child accepts a new food. Avoid making mealtimes a battle — keep the atmosphere positive and pressure-free.</p><h3>Healthy Snack Ideas</h3><p>Cut fruit, cheese cubes, yogurt, whole grain crackers, hummus with veggie sticks, and small portions of nut butter on toast.</p>",
      category: "nutrition",
      min_age_months: 12,
      max_age_months: 36,
      is_pregnancy: false,
      reading_time: "4 min read"
    },
    {
      title: "Play-Based Learning for Toddlers",
      summary: "How everyday play activities support your toddler's cognitive, social, and physical development.",
      content: "<p>Play is how toddlers learn about the world. Every game, toy interaction, and pretend scenario builds critical skills.</p><h3>Types of Play</h3><p><strong>Physical play:</strong> Running, climbing, dancing — builds gross motor skills<br><strong>Constructive play:</strong> Blocks, puzzles, drawing — develops fine motor skills and problem-solving<br><strong>Pretend play:</strong> Kitchen sets, dolls, dress-up — fosters imagination and social skills<br><strong>Sensory play:</strong> Water, sand, playdough — enhances sensory processing</p><h3>Age-Appropriate Activities</h3><p><strong>12-18 months:</strong> Stacking rings, shape sorters, push toys, reading board books<br><strong>18-24 months:</strong> Simple puzzles, crayons, playing with water, singing songs<br><strong>24-36 months:</strong> Pretend play, tricycle riding, painting, simple board games</p><h3>Screen Time</h3><p>The WHO recommends no screen time for children under 2, and no more than 1 hour per day for ages 2-5. Quality matters — choose educational content and watch together.</p>",
      category: "activity",
      min_age_months: 12,
      max_age_months: 36,
      is_pregnancy: false,
      reading_time: "4 min read"
    },
    {
      title: "Self-Care Tips for New Moms",
      summary: "Practical strategies for maintaining your physical and mental health during the postpartum period.",
      content: "<p>Taking care of yourself isn't selfish — it's essential. A healthy, rested mother is better equipped to care for her baby.</p><h3>Sleep When You Can</h3><p>The old advice to 'sleep when the baby sleeps' has merit. Even short naps can help reduce the effects of sleep deprivation. Accept help from partners, family, or friends.</p><h3>Nutrition Matters</h3><p>Easy, nutritious meals and snacks keep your energy up. Prep simple foods in advance: overnight oats, cut vegetables, trail mix, and freezer meals. Stay hydrated, especially if breastfeeding.</p><h3>Move Your Body</h3><p>Gentle walks, postpartum yoga, and stretching can boost mood and energy. Wait for medical clearance before resuming intense exercise (usually 6 weeks postpartum).</p><h3>Connect with Others</h3><p>Isolation can worsen postpartum mood issues. Join a new mothers' group, connect with friends, or find online communities. Sharing experiences helps normalize the challenges of new parenthood.</p><h3>Set Boundaries</h3><p>It's okay to say no to visitors, ask for specific help, and take time alone. Your needs matter too.</p>",
      category: "wellbeing",
      min_age_months: 0,
      max_age_months: 12,
      is_pregnancy: false,
      reading_time: "4 min read"
    }
  ]

  for (const a of articles) {
    const r = new Record(col)
    r.set("title", a.title)
    r.set("summary", a.summary)
    r.set("content", a.content)
    r.set("category", a.category)
    r.set("min_age_months", a.min_age_months)
    r.set("max_age_months", a.max_age_months)
    r.set("is_pregnancy", a.is_pregnancy)
    r.set("reading_time", a.reading_time)
    app.save(r)
  }
}, (app) => {
  const articles = app.findRecordsByFilter("articles", "title != ''", "", 0, 0, {})
  for (const r of articles) app.delete(r)
})
