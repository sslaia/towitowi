import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final langCode = context.locale.languageCode;
    final isIndonesian = langCode == 'id';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isIndonesian ? 'Panduan Setup Gemini' : 'Gemini Setup Guide',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800.0),
            child: isIndonesian ? _buildIndonesianGuide(theme) : _buildEnglishGuide(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildEnglishGuide(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gemini AI Setup Guide',
          style: GoogleFonts.outfit(
            fontSize: 28.0,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primaryContainer,
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          'Configure your personal AI writing assistant in TowiTowi',
          style: GoogleFonts.outfit(
            fontSize: 16.0,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 24.0),
        Text(
          'If you want to use Gemini AI to help with restructuring your notes or crafting your social media posts, you need to provide a Gemini API key from Google AI Studio. Here is how you can get it and use it in the TowiTowi app.',
          style: const TextStyle(fontSize: 15.0, height: 1.6),
        ),
        const SizedBox(height: 24.0),

        _buildSectionHeader(theme, '1. Login to AI Studio'),
        _buildStepList([
          'Go to aistudio.google.com',
          'Click on Get started',
          'Login with your Gmail account',
          'Inside AI Studio, look for MANAGE in the left menu',
          'Click on Dashboard. You will see the list of API keys',
        ]),

        _buildSectionHeader(theme, '2. Create the TowiTowi project'),
        _buildStepList([
          'Click on Projects in the left menu',
          'Click Create a new project in the top right corner',
          'Enter the project name: TowiTowi',
          'Click Create project',
        ]),

        _buildSectionHeader(theme, '3. Create the API key'),
        _buildStepList([
          'Click on Create API key in the top right corner',
          'In the form, enter TowiTowi Gemini API key in the "Name your key" field',
          'Choose TowiTowi in the "Choose an imported project" dropdown',
          'Click Create key',
          'Copy the API key provided (you can also copy it later)',
        ]),

        _buildSectionHeader(theme, '4. Copy the API key'),
        _buildStepList([
          'From the list of API keys, click on TowiTowi Gemini API key in the "Key" column',
          'You will see the API Key. Click on the copy icon at the end of the API key',
        ]),

        _buildSectionHeader(theme, '5. Use the API key in TowiTowi app'),
        _buildStepList([
          'Run the TowiTowi app',
          'Click on the Menu (bottom left corner)',
          'Click on Settings',
          'Enter the previously copied API key in GEMINI API KEY',
        ]),

        _buildSectionHeader(theme, 'Addition: Style Personalization'),
        const Text(
          'If you want to use AI to tidy up your writing and create social media posts, it might be a good idea to have Gemini AI adapt your writing style.\n\n'
          'To do this, enter instructions in the SYSTEM INSTRUCTIONS field. Then, enter examples of Reference Articles in the STYLE REFERENCE ARTICLES field. For example, copy three different articles you\'ve written in the past that reflect your own style.\n\n'
          'Good luck!',
          style: TextStyle(fontSize: 15.0, height: 1.6),
        ),
        const SizedBox(height: 48.0),
      ],
    );
  }

  Widget _buildIndonesianGuide(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Panduan Setup Gemini AI',
          style: GoogleFonts.outfit(
            fontSize: 28.0,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primaryContainer,
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          'Konfigurasikan asisten penulis AI pribadi Anda di TowiTowi',
          style: GoogleFonts.outfit(
            fontSize: 16.0,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 24.0),
        Text(
          'Jika Anda ingin menggunakan Gemini AI untuk membantu menyusun ulang catatan atau membuat postingan media sosial, Anda perlu menyediakan kunci API Gemini dari Google AI Studio. Berikut adalah cara mendapatkan dan menggunakannya di aplikasi TowiTowi.',
          style: const TextStyle(fontSize: 15.0, height: 1.6),
        ),
        const SizedBox(height: 24.0),

        _buildSectionHeader(theme, '1. Masuk ke AI Studio'),
        _buildStepList([
          'Buka aistudio.google.com',
          'Klik Get started',
          'Masuk dengan akun Gmail Anda',
          'Di dalam AI Studio, cari menu MANAGE di sebelah kiri',
          'Klik Dashboard. Anda akan melihat daftar kunci API',
        ]),

        _buildSectionHeader(theme, '2. Buat proyek TowiTowi'),
        _buildStepList([
          'Klik Projects di menu sebelah kiri',
          'Klik Create a new project di sudut kanan atas',
          'Masukkan nama proyek: TowiTowi',
          'Klik Create project',
        ]),

        _buildSectionHeader(theme, '3. Buat kunci API'),
        _buildStepList([
          'Klik Create API key di sudut kanan atas',
          'Pada formulir, masukkan TowiTowi Gemini API key di kolom "Name your key"',
          'Pilih TowiTowi di dropdown "Choose an imported project"',
          'Klik Create key',
          'Salin kunci API yang disediakan (Anda juga dapat menyalinnya nanti)',
        ]),

        _buildSectionHeader(theme, '4. Salin kunci API'),
        _buildStepList([
          'Dari daftar kunci API, klik TowiTowi Gemini API key di kolom "Key"',
          'Anda akan melihat Kunci API Anda. Klik ikon salin di bagian akhir kunci API',
        ]),

        _buildSectionHeader(theme, '5. Gunakan kunci API di aplikasi TowiTowi'),
        _buildStepList([
          'Buka aplikasi TowiTowi',
          'Klik Menu (sudut kiri bawah)',
          'Klik Pengaturan',
          'Masukkan kunci API yang telah disalin sebelumnya di KUNCI API GEMINI',
        ]),

        _buildSectionHeader(theme, 'Tambahan: Personalisasi Gaya Penulisan'),
        const Text(
          'Jika Anda ingin menggunakan AI untuk merapikan tulisan Anda dan membuat postingan media sosial, sebaiknya biarkan Gemini AI mempelajari gaya penulisan Anda.\n\n'
          'Untuk melakukan ini, masukkan instruksi di kolom INSTRUKSI SISTEM. Kemudian, masukkan contoh Artikel Referensi di kolom ARTIKEL REFERENSI GAYA. Misalnya, salin tiga artikel berbeda yang pernah Anda tulis sebelumnya yang mencerminkan gaya Anda sendiri.\n\n'
          'Semoga berhasil!',
          style: TextStyle(fontSize: 15.0, height: 1.6),
        ),
        const SizedBox(height: 48.0),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildStepList(List<String> steps) {
    return Column(
      children: List.generate(steps.length, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${index + 1}. ',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0),
              ),
              Expanded(
                child: Text(
                  steps[index],
                  style: const TextStyle(fontSize: 15.0, height: 1.4),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
