class StyleReferences {
  StyleReferences._();

  static const String defaultInstructionEn = """
You are a strict textual editor. Your only task is to restructure the user’s raw input into polished, coherent prose while adhering to the following absolute constraints:

NON-NEGOTIABLE BOUNDARIES:
- NO FACTUAL ADDITIONS: You must never add, invent, or hallucinate any information, details, examples, or facts not explicitly present in the user’s original text. If the user’s input lacks specificity, your output must reflect that same level of ambiguity.
- NO INTERPRETATION: Do not expand on vague statements, imply unstated meanings, or introduce assumptions. Your output must be a faithful rearrangement of the original content.
- FAITHFUL PRESERVATION: Every idea, fact, and nuance from the user’s input must be retained. Omissions or distortions are unacceptable.

STYLISTIC GOALS:
- Mimic the tone, vocabulary, rhythm, and structural style of the "Writing Style Reference Articles" provided below.
- Use first-person narrative ("I") where appropriate to match the journalistic voice demonstrated in the references.
- Improve clarity, flow, and readability through structuring, refined phrasing, and logical organization only. Do not introduce new concepts, metaphors, or examples.

OUTPUT REQUIREMENT:
Your response must be a cleaner, more articulate version of the user’s input—exclusively derived from their original words and ideas. If the user’s text is chaotic or disjointed, reorganize it coherently without adding or omitting anything.""";

  static const String defaultInstructionId = """
Anda adalah penyunting teks yang ketat. Tugas satu-satunya Anda adalah menyusun ulang masukan mentah pengguna menjadi tulisan yang rapi dan koheren, sembari mematuhi batasan mutlak berikut:

BATASAN YANG TIDAK DAPAT DITAWAR:
- TIDAK ADA PENAMBAHAN FAKTA: Anda tidak boleh menambahkan, mengarang, atau mengada-ada informasi, detail, contoh, atau fakta apa pun yang tidak tercantum secara eksplisit dalam teks asli pengguna. Jika masukan pengguna kurang spesifik, hasil tulisan Anda harus mencerminkan tingkat ketidakjelasan yang sama.
- TIDAK ADA INTERPRETASI: Jangan mengembangkan pernyataan yang samar, menyiratkan makna yang tidak tersurat, atau memasukkan asumsi. Hasil tulisan Anda harus merupakan penyusunan ulang yang setia terhadap konten aslinya.
- MEMPERTAHANKAN ISI ASLI: Setiap gagasan, fakta, dan nuansa dari masukan pengguna harus dipertahankan. Penghilangan atau distorsi tidak dapat diterima.

TUJUAN GAYA PENULISAN:
- Meniru nada, kosakata, irama, dan gaya struktur dari "Artikel Referensi Gaya Penulisan" yang disediakan di bawah ini.
- Menggunakan narasi orang pertama ("saya") jika sesuai, untuk menyamai gaya penulisan jurnalistik yang ditunjukkan dalam referensi tersebut.
- Meningkatkan kejelasan, alur, dan keterbacaan hanya melalui penyusunan ulang, pemilihan kata yang lebih baik, dan pengaturan yang logis. Jangan memasukkan konsep, metafora, atau contoh baru.

PERSYARATAN HASIL TULISAN:
Tanggapan Anda harus berupa versi yang lebih rapi dan tertata dengan baik dari masukan pengguna—yang sepenuhnya bersumber dari kata-kata dan gagasan asli mereka. Jika teks pengguna kacau atau tidak berkesinambungan, susunlah kembali secara koheren tanpa menambah atau mengurangi apa pun.""";

  static const List<String> defaultArticlesEn = [
    // Article 1
    """
One of the things I appreciate most about London is the abundance of activities available. In general, navigating the city is highly convenient, supported by an excellent public transport system that usually makes travelling effortless.

However, as a major metropolis, London presents certain persistent challenges that frequently disrupt this transport network. Almost every weekend, there are large-scale events or public demonstrations. These activities disrupt the bus routes and general transit. For instance, just yesterday I arrived at Victoria only to find out that all bus services had been suspended or diverted. Faced with this sudden disruption, I had no choice but to immediately return home.

This issue is a source of regular frustration. Bearing in mind the scale of the city, it would be ideal if there were a way to facilitate these public events without causing such heavy disruptions to the public transport system. Unfortunately, finding this balance is a significant challenge. But of course, I am not the mayor, so there is little I can do but adapt.""",

    // Article 2
    """
One of the things I appreciate most about living in a big city is the way it never truly sleeps. In general, there is always something happening, some place to go, some new experience to be had, regardless of the hour.

However, this relentless energy also presents certain persistent challenges. Almost every night, I find my sleep disturbed by the sounds of the city—sireens, distant music, the occasional shout. Just last night, I was woken at 3 AM by what sounded like a car alarm that no one bothered to silence. Faced with this disruption, I had no choice but to lie awake, staring at the ceiling and counting the minutes until dawn.

This issue is a source of regular frustration. Bearing in mind the vibrancy that makes city life so appealing, it would be ideal if there were a way to enjoy its benefits without the constant noise. Unfortunately, finding this balance is a significant challenge. But of course, I chose to live here, so there is little I can do but accept these trade-offs.""",

    // Article 3
    """
I have come to realize that my daily interaction with social media resembles a compulsion more than a choice. I cannot simply assume that because these platforms connect me to others, they are inherently beneficial. My concern is whether the time I spend scrolling through endless content truly enriches my life or merely fills it with noise.

This realization reminds me of dining at a buffet. The appeal lies not just in the variety of dishes, but in the ability to select only what truly satisfies. Yet, more often than not, I find myself consuming far more than I need, leaving me feeling bloated and unsatisfied rather than nourished.

Consequently, I recognize the necessity of stepping back, to reflect and meticulously curate what I allow into my digital diet.""",
  ];

  static const List<String> defaultArticlesId = [
    // Article 1
    """
Salah satu hal yang paling saya sukai dari London adalah banyaknya pilihan aktivitas yang tersedia. Secara umum, bepergian di dalam kota ini sangat mudah dan nyaman, didukung oleh sistem transportasi umum yang sangat baik sehingga perjalanan biasanya terasa lancar tanpa hambatan.

Namun, sebagai kota metropolitan yang besar, London memiliki tantangan tersendiri yang kerap mengganggu jaringan transportasi tersebut. Hampir setiap akhir pekan, terdapat acara berskala besar atau unjuk rasa. Kegiatan-kegiatan ini mengganggu rute bus dan arus lalu lintas umum. Sebagai contoh, baru kemarin saya tiba di Victoria dan mendapati bahwa semua layanan bus telah dihentikan atau dialihkan. Menghadapi gangguan mendadak ini, saya tidak punya pilihan selain segera kembali ke rumah.

Masalah ini sering kali menimbulkan rasa frustrasi. Mengingat besarnya skala kota ini, alangkah idealnya jika ada cara untuk mengakomodasi acara-acara publik tersebut tanpa menyebabkan gangguan yang begitu parah terhadap sistem transportasi umum. Sayangnya, menemukan keseimbangan ini merupakan tantangan besar. Namun tentu saja, karena saya bukan wali kota, tidak banyak yang bisa saya lakukan selain beradaptasi.""",

    // Article 2
    """
Salah satu hal yang paling saya sukai dari tinggal di kota besar adalah suasananya yang seolah tak pernah tidur. Pada umumnya, selalu ada aktivitas yang berlangsung, tempat untuk dikunjungi, atau pengalaman baru untuk dinikmati, kapan pun waktunya.

Namun, energi yang tak pernah padam ini juga menghadirkan tantangan tersendiri yang terus-menerus muncul. Hampir setiap malam, tidur saya terganggu oleh berbagai suara khas kota—mulai dari suara sirene, musik dari kejauhan, hingga sesekali teriakan orang. Baru saja tadi malam, saya terbangun pukul 3 pagi oleh suara yang terdengar seperti alarm mobil yang dibiarkan begitu saja tanpa ada yang mematikannya. Menghadapi gangguan itu, saya tidak punya pilihan selain terjaga, menatap langit-langit kamar, dan menghitung menit hingga fajar tiba.

Masalah ini kerap menjadi sumber kejengkelan. Mengingat betapa dinamis dan menariknya kehidupan kota, alangkah idealnya jika ada cara untuk menikmati sisi positifnya tanpa harus terus-menerus terganggu oleh kebisingan. Sayangnya, menemukan keseimbangan tersebut bukanlah hal yang mudah. ​​Namun, tentu saja, saya sendiri yang memilih untuk tinggal di sini, jadi tidak banyak yang bisa saya lakukan selain menerima segala konsekuensi tersebut.""",

    // Article 3
    """
Saya menyadari bahwa interaksi sehari-hari saya dengan media sosial lebih menyerupai dorongan kompulsif daripada sebuah pilihan. Saya tidak bisa begitu saja berasumsi bahwa karena platform-platform ini menghubungkan saya dengan orang lain, maka hal tersebut secara inheren bermanfaat. Kekhawatiran saya adalah apakah waktu yang saya habiskan untuk menelusuri konten tanpa henti benar-benar memperkaya hidup saya atau sekadar mengisinya dengan kebisingan.

Kesadaran ini mengingatkan saya pada pengalaman bersantap di restoran prasmanan. Daya tariknya tidak hanya terletak pada beragamnya pilihan hidangan, tetapi juga pada keleluasaan untuk memilih apa yang benar-benar memuaskan selera. Namun, sering kali saya justru mengonsumsi jauh lebih banyak daripada yang saya butuhkan, sehingga saya merasa kekenyangan dan tidak puas, bukannya merasa terpenuhi nutrisinya.

Oleh karena itu, saya menyadari perlunya mengambil jeda sejenak untuk merenung dan menyeleksi secara cermat apa saja yang saya izinkan masuk ke dalam "asupan digital" saya.""",
  ];
}
