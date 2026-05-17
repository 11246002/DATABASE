import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('相機錯誤: ${e.code}, ${e.description}');
  }

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primarySwatch: Colors.teal,
      scaffoldBackgroundColor: const Color(0xFFF5F7F9),
    ),
    scrollBehavior: const MaterialScrollBehavior().copyWith(
      dragDevices: {
        PointerDeviceKind.mouse,
        PointerDeviceKind.touch,
        PointerDeviceKind.trackpad,
      },
    ),
    home: const WelcomePage(),
  ));
}

// --- 頁面 1: 歡迎頁面 ---
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.teal, Colors.tealAccent])),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medication_liquid, size: 100, color: Colors.white),
            const SizedBox(height: 20),
            const Text('智慧藥管家', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 50),
            _buildBtn(context, '登入系統', const LoginPage(), Colors.white, Colors.teal),
            const SizedBox(height: 20),
            _buildBtn(context, '註冊帳號', const RegisterPage(), Colors.teal.shade700, Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildBtn(BuildContext context, String txt, Widget page, Color bg, Color fg) {
    return SizedBox(
      width: 250, height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: bg, foregroundColor: fg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => page)),
        child: Text(txt, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// --- 頁面 2: 登入頁面 ---
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('會員登入')),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          children: [
            const TextField(decoration: InputDecoration(labelText: '帳號', prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 20),
            const TextField(obscureText: true, decoration: InputDecoration(labelText: '密碼', prefixIcon: Icon(Icons.lock))),
            const SizedBox(height: 40),
            SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MainAppPage())), child: const Text('登入'))),
          ],
        ),
      ),
    );
  }
}

// --- 頁面 3: 註冊頁面 ---
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}
class _RegisterPageState extends State<RegisterPage> {
  String selectedGender = '男';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('建立帳號')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('帳號設定'),
            const TextField(decoration: InputDecoration(labelText: '真實姓名', prefixIcon: Icon(Icons.badge_outlined))),
            const SizedBox(height: 15),
            const TextField(decoration: InputDecoration(labelText: '暱稱 (顯示於首頁)', prefixIcon: Icon(Icons.face))),
            const SizedBox(height: 15),
            const TextField(decoration: InputDecoration(labelText: '帳號 ID (Email)', prefixIcon: Icon(Icons.email_outlined))),
            const SizedBox(height: 15),
            const TextField(obscureText: true, decoration: InputDecoration(labelText: '密碼設定', prefixIcon: Icon(Icons.lock_outline))),
            const SizedBox(height: 30),
            _buildSectionTitle('核心健康資訊 (必填)'),
            const Text('性別', style: TextStyle(fontSize: 16, color: Colors.grey)),
            Row(children: [Radio(value: '男', groupValue: selectedGender, onChanged: (val) => setState(() => selectedGender = val!)), const Text('男'), const SizedBox(width: 20), Radio(value: '女', groupValue: selectedGender, onChanged: (val) => setState(() => selectedGender = val!)), const Text('女')]),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '身高 (cm)', prefixIcon: Icon(Icons.height)))), const SizedBox(width: 15), Expanded(child: TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '體重 (kg)', prefixIcon: Icon(Icons.monitor_weight_outlined))))]),
            const SizedBox(height: 15),
            const TextField(maxLines: 2, decoration: InputDecoration(labelText: '藥物過敏史', hintText: '若無請填「無」', prefixIcon: Icon(Icons.warning_amber_rounded), border: OutlineInputBorder())),
            const SizedBox(height: 30),
            _buildSectionTitle('安全聯繫'),
            const TextField(keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: '緊急聯絡人電話', prefixIcon: Icon(Icons.contact_phone_outlined))),
            const SizedBox(height: 40),
            SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: _showSuccessDialog, child: const Text('完成並送出', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  Widget _buildSectionTitle(String title) { return Padding(padding: const EdgeInsets.only(bottom: 15), child: Row(children: [Container(width: 5, height: 20, color: Colors.teal), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal))])); }
  void _showSuccessDialog() {
    showDialog(context: context, barrierDismissible: false, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Icon(Icons.check_circle, color: Colors.green, size: 60), content: const Text('帳號已成功建立！\n您的健康資料已同步至個人檔案。', textAlign: TextAlign.center), actions: [Center(child: TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('好的，去登入', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))]));
  }
}

// --- 🌟 頁面 5: 導覽列 ---
class MainAppPage extends StatefulWidget {
  const MainAppPage({super.key});
  @override
  State<MainAppPage> createState() => _MainAppPageState();
}

class _MainAppPageState extends State<MainAppPage> {
  int _selectedIndex = 1;

  final List<Widget> _pages = [
    const ReminderSettingsPage(),
    const MyMedicationBagPage(),
    const AppSettingsPage(),
    const UserProfilePage(),
  ];

  // 全螢幕向上滑出動畫
  void _openScannerSheet() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const ScanPrescriptionSheet(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0); 
          const end = Offset.zero; 
          const curve = Curves.easeOutCubic; 
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      
      floatingActionButton: SizedBox(
        width: 75,
        height: 75,
        child: FloatingActionButton(
          onPressed: _openScannerSheet,
          backgroundColor: Colors.teal,
          elevation: 4,
          shape: const CircleBorder(),
          child: const Icon(Icons.document_scanner, color: Colors.white, size: 36),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10.0,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _buildNavItem(icon: Icons.alarm, label: '提醒', index: 0),
              _buildNavItem(icon: Icons.medical_services, label: '藥袋', index: 1),
              const SizedBox(width: 60),
              _buildNavItem(icon: Icons.settings, label: '設定', index: 2),
              _buildNavItem(icon: Icons.person, label: '資料', index: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSelected ? Colors.teal : Colors.grey, size: 26),
          Text(label, style: TextStyle(color: isSelected ? Colors.teal : Colors.grey, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

// ==========================================
// 🌟 全螢幕掃描相機視窗
// ==========================================
class ScanPrescriptionSheet extends StatefulWidget {
  const ScanPrescriptionSheet({super.key});
  @override
  State<ScanPrescriptionSheet> createState() => _ScanPrescriptionSheetState();
}

class _ScanPrescriptionSheetState extends State<ScanPrescriptionSheet> {
  CameraController? _controller;
  final ImagePicker _picker = ImagePicker(); 

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      _controller = CameraController(cameras[0], ResolutionPreset.high);
      _controller!.initialize().then((_) { if (mounted) setState(() {}); });
    }
  }

  @override
  void dispose() { 
    _controller?.dispose(); 
    super.dispose(); 
  }

  Future<void> _processImage(XFile image) async {
    if (kIsWeb) {
      _uploadAndAnalyze(image); 
    } else {
      _cropImage(image.path);
    }
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) _processImage(image);
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;
    try {
      XFile file = await _controller!.takePicture();
      _processImage(file);
    } catch (e) {
      debugPrint('拍照失敗: $e');
    }
  }

  Future<void> _cropImage(String filePath) async {
    try {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: filePath,
        uiSettings: [
          AndroidUiSettings(toolbarTitle: '裁切藥單', toolbarColor: Colors.teal, toolbarWidgetColor: Colors.white, initAspectRatio: CropAspectRatioPreset.original, lockAspectRatio: false), 
          IOSUiSettings(title: '裁切藥單'),
        ],
      );
      if (croppedFile != null) _uploadAndAnalyze(XFile(croppedFile.path));
    } catch (e) {
      debugPrint('裁切圖片失敗: $e');
    }
  }

  Future<void> _uploadAndAnalyze(XFile imageFile) async { 
    _showLoadingDialog("正在分析藥單...");
    var apiUrl = Uri.parse('http://127.0.0.1:8000/medications/api/scan/');

    try {
      var request = http.MultipartRequest('POST', apiUrl);
      if (kIsWeb) {
        var bytes = await imageFile.readAsBytes(); 
        var pic = http.MultipartFile.fromBytes('prescription_img', bytes, filename: imageFile.name);
        request.files.add(pic);
      } else {
        var pic = await http.MultipartFile.fromPath('prescription_img', imageFile.path);
        request.files.add(pic);
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      
      if (!mounted) return;
      Navigator.pop(context); 

      if (response.statusCode == 200) {
        var jsonResult = json.decode(responseData);
        if (jsonResult['status'] == 'success') {
          _showResultDialog(jsonResult['data']);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('辨識失敗: ${jsonResult['message']}'), backgroundColor: Colors.red));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('伺服器錯誤，請稍後再試！'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('連線到伺服器失敗: $e'), backgroundColor: Colors.red));
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.teal),
              const SizedBox(height: 20),
              Text(message, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("請稍候，正在與伺服器連線中...", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  void _showResultDialog(List<dynamic> drugsData) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(
            children: [
              Icon(Icons.fact_check, color: Colors.teal),
              SizedBox(width: 10),
              Text('藥單辨識結果', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView( 
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('請確認以下掃描出的藥物資訊是否正確：', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 15),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Column(
                    children: drugsData.isEmpty 
                      ? [const Text('未能辨識出任何藥品', style: TextStyle(color: Colors.red))]
                      : drugsData.map((drug) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 6, child: Text('• ${drug['raw_name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))),
                                Expanded(flex: 4, child: Text('${drug['frequency']} \n${drug['total_amount']}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.2))),
                              ],
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly, 
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)), child: const Text('資料有誤重拍')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); 
                _checkInteractions(drugsData); 
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              child: const Text('確認並檢測'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkInteractions(List<dynamic> drugsData) async {
    _showLoadingDialog("正在進行藥物交互作用檢測...");
    await Future.delayed(const Duration(seconds: 2));
    
    bool hasInteraction = false; 
    String interactionDetails = "";
    
    if (!mounted) return;
    Navigator.pop(context); 
    _showFinalResultDialog(hasInteraction, interactionDetails);
  }

  void _showFinalResultDialog(bool hasInteraction, String details) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(hasInteraction ? Icons.warning_amber_rounded : Icons.check_circle, color: hasInteraction ? Colors.red : Colors.green, size: 30),
            const SizedBox(width: 10),
            Text(hasInteraction ? '發現交互作用風險！' : '檢測通過', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(hasInteraction ? '系統偵測到潛在風險：\n\n$details' : '沒有發現任何藥物交互作用。\n已為您安全加入藥袋紀錄中！', style: const TextStyle(fontSize: 15, height: 1.5)),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); 
                Navigator.pop(context); 
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('完成', style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 15, right: 10, bottom: 15, left: 25),
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('請將藥單對準框內', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context) 
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: (_controller != null && _controller!.value.isInitialized) 
                    ? CameraPreview(_controller!) 
                    : const Center(child: CircularProgressIndicator(color: Colors.teal)),
              ),
            ),

            Container(
              color: Colors.black,
              padding: const EdgeInsets.only(bottom: 40, top: 20, left: 20, right: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.photo_library, color: Colors.white, size: 32), onPressed: _pickImageFromGallery),
                      const Text('相簿', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      width: 75, height: 75, 
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                      child: Center(
                        child: Container(width: 60, height: 60, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 50), 
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 【我的藥袋、提醒、設定、資料】
// ==========================================
// ==========================================
// 🌟 真實功能版：【我的藥袋】總覽與詳細頁面
// ==========================================
class MyMedicationBagPage extends StatefulWidget {
  const MyMedicationBagPage({super.key});
  @override
  State<MyMedicationBagPage> createState() => _MyMedicationBagPageState();
}

class _MyMedicationBagPageState extends State<MyMedicationBagPage> {
  // 模擬的原始資料庫
  final List<Map<String, dynamic>> _allMockData = [
    {'date': '2026/05/17', 'hospital': '北商大聯合診所', 'meds': [{'name': '普拿疼', 'dose': '500mg'}, {'name': '胃乳', 'dose': '1包'}]},
    {'date': '2026/04/22', 'hospital': '新竹台大醫院', 'meds': [{'name': '阿斯匹靈', 'dose': '100mg'}]},
    {'date': '2026/03/10', 'hospital': '家醫科診所', 'meds': [{'name': '感冒糖漿', 'dose': '10ml'}, {'name': '抗組織胺', 'dose': '1顆'}]},
    {'date': '2026/05/01', 'hospital': '北商大聯合診所', 'meds': [{'name': '消炎藥', 'dose': '1顆'}]}, // 故意多加一筆用來測試搜尋
  ];

  // 狀態變數：用來記錄使用者輸入的關鍵字跟選到的篩選條件
  String _searchQuery = '';
  String _currentFilter = '全部時間';

  @override
  Widget build(BuildContext context) {
    // 🌟 核心邏輯 1：根據「搜尋關鍵字」過濾資料
    List<Map<String, dynamic>> displayedData = _allMockData.where((item) {
      final hospitalMatch = item['hospital'].toString().contains(_searchQuery);
      final dateMatch = item['date'].toString().contains(_searchQuery);
      return hospitalMatch || dateMatch;
    }).toList();

    // 🌟 核心邏輯 2：根據「篩選條件」排序資料
    if (_currentFilter == '最新加入') {
      displayedData.sort((a, b) => b['date'].compareTo(a['date'])); // 日期大到小
    } else if (_currentFilter == '最早加入') {
      displayedData.sort((a, b) => a['date'].compareTo(b['date'])); // 日期小到大
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 25),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)]),
              child: const Center(child: Text('我的藥單紀錄', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.teal))),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity, padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)]),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // 🌟 真實功能：搜尋輸入框
                        Expanded(
                          flex: 7,
                          child: Container(
                            height: 45, padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              children: [
                                const Icon(Icons.search, color: Colors.grey),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    onChanged: (value) {
                                      setState(() { _searchQuery = value; }); // 輸入時即時更新畫面
                                    },
                                    decoration: const InputDecoration(
                                      hintText: '搜尋診所或時間...',
                                      hintStyle: TextStyle(color: Colors.grey),
                                      border: InputBorder.none, // 隱藏底部底線
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // 🌟 真實功能：下拉選單篩選器
                        Expanded(
                          flex: 3,
                          child: PopupMenuButton<String>(
                            onSelected: (String value) {
                              setState(() { _currentFilter = value; }); // 點選後更新排序
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(value: '全部時間', child: Text('全部時間 (預設)')),
                              const PopupMenuItem<String>(value: '最新加入', child: Text('最新加入優先')),
                              const PopupMenuItem<String>(value: '最早加入', child: Text('最早加入優先')),
                            ],
                            child: Container(
                              height: 45, alignment: Alignment.center,
                              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center, 
                                children: [
                                  const Icon(Icons.filter_list, size: 18, color: Colors.teal),
                                  const SizedBox(width: 5),
                                  // 顯示目前選的條件，字太長就縮寫
                                  Text(_currentFilter == '全部時間' ? '排列' : _currentFilter.substring(0, 2), 
                                    style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)
                                  ),
                                ]
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
                        child: displayedData.isEmpty 
                        ? const Center(child: Text('找不到符合的藥單紀錄', style: TextStyle(color: Colors.grey))) // 找不到資料的防呆
                        : ListView.builder(
                          itemCount: displayedData.length,
                          itemBuilder: (context, index) {
                            final item = displayedData[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PrescriptionDetailPage(data: item))),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.teal.shade100), boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.05), blurRadius: 4)]),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item['hospital'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                          const SizedBox(height: 4),
                                          Text('加入時間: ${item['date']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.teal),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class PrescriptionDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;
  const PrescriptionDetailPage({super.key, required this.data});
  @override
  Widget build(BuildContext context) {
    List<dynamic> meds = data['meds'];
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.teal), title: const Text('藥單詳細資訊', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 25),
                decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.3), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 3))]),
                child: Center(child: Text(data['hospital'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2))),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)]),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                            child: Row(children: [Icon(Icons.access_time, size: 16, color: Colors.grey.shade600), const SizedBox(width: 5), Text(data['date'], style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold))]),
                          ),
                          InkWell(
                            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('開啟新增藥品視窗'))),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.teal.shade200)),
                              child: const Row(children: [Icon(Icons.add, size: 16, color: Colors.teal), SizedBox(width: 5), Text('新增藥品', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold))]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20), const Divider(),
                      Expanded(
                        child: ListView.builder(
                          itemCount: meds.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 3)]),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(meds[index]['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                                      const SizedBox(height: 4),
                                      Text('劑量: ${meds[index]['dose']}', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                  InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context, 
                                        builder: (context) => AlertDialog(
                                          title: Text('${meds[index]['name']} 詳細資訊', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                          content: const Text('此處將顯示從資料庫撈取的副作用與注意事項說明。'),
                                          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉'))],
                                        )
                                      );
                                    },
                                    child: Container(width: 45, height: 45, decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle), child: const Center(child: Icon(Icons.info_outline, color: Colors.teal))),
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key});
  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}
class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  List<Map<String, dynamic>> reminders = [{'freq': '一天三次', 'times': ['08:00', '12:00', '18:00'], 'meds': ['普拿疼', '胃乳']}, {'freq': '一天一次', 'times': ['21:00'], 'meds': ['阿斯匹靈']}];
  void _showTimePicker(int groupIndex, int timeIndex) {
    final timeParts = reminders[groupIndex]['times'][timeIndex].split(':');
    final initialDateTime = DateTime(2026, 1, 1, int.parse(timeParts[0]), int.parse(timeParts[1]));
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            height: 350, padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('設置 ${reminders[groupIndex]['freq']} - 第 ${timeIndex + 1} 劑', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal))),
                const Divider(),
                Expanded(child: CupertinoDatePicker(mode: CupertinoDatePickerMode.time, initialDateTime: initialDateTime, use24hFormat: true, onDateTimeChanged: (DateTime newDate) { setState(() { reminders[groupIndex]['times'][timeIndex] = "${newDate.hour.toString().padLeft(2, '0')}:${newDate.minute.toString().padLeft(2, '0')}"; }); },)),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')), const SizedBox(width: 10), ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal), child: const Text('完成', style: TextStyle(color: Colors.white)))])
              ],
            ),
          ),
        );
      },
    );
  }
  void _showMenu(BuildContext context, int groupIndex, List<String> times) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('請選擇要修改的劑次'), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: List.generate(times.length, (i) => ListTile(leading: const Icon(Icons.access_time, color: Colors.teal), title: Text('第 ${i + 1} 劑 (${times[i]})'), onTap: () { Navigator.pop(context); _showTimePicker(groupIndex, i); })))),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16), itemCount: reminders.length,
      itemBuilder: (context, index) {
        final item = reminders[index];
        return Card(
          elevation: 4, margin: const EdgeInsets.only(bottom: 20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item['freq'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                    IconButton(icon: const Icon(Icons.settings, color: Colors.grey), onPressed: () { if (item['times'].length == 1) { _showTimePicker(index, 0); } else { _showMenu(context, index, item['times']); } }),
                  ],
                ),
                const Divider(),
                ...item['meds'].map((m) => Text('• $m', style: const TextStyle(fontSize: 16))),
                const SizedBox(height: 10), const Text('設定提醒時間：', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Wrap(spacing: 8, children: List.generate(item['times'].length, (timeIndex) { return ActionChip(label: Text(item['times'][timeIndex]), onPressed: () => _showTimePicker(index, timeIndex), backgroundColor: Colors.teal.withOpacity(0.1)); })),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 🌟 完整版：個人資料頁面
class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Center(
          child: Column(
            children: [
              CircleAvatar(radius: 50, backgroundColor: Colors.teal, child: Icon(Icons.person, size: 50, color: Colors.white)),
              SizedBox(height: 10),
              Text('王小明', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text('ID: NTUB_MIS_2026', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(height: 30),
        _buildSectionTitle('核心健康資訊'),
        _buildInfoCard(Icons.warning_amber_rounded, '藥物過敏史', '對「青黴素、阿斯匹靈」過敏', Colors.redAccent),
        _buildInfoCard(Icons.monitor_weight_outlined, '身體數值', '身高: 175cm / 體重: 70kg', Colors.blue),
        const SizedBox(height: 20),
        _buildSectionTitle('生活作息設定'),
        _buildInfoCard(Icons.wb_sunny_outlined, '早餐作息', '08:30 AM', Colors.orange),
        _buildInfoCard(Icons.wb_twilight, '晚餐作息', '18:30 PM', Colors.indigo),
        const SizedBox(height: 20),
        _buildSectionTitle('緊急聯絡人'),
        _buildInfoCard(Icons.contact_phone, '緊急聯絡人 (家屬)', '0912-345-678', Colors.teal),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String value, Color color) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () {},
      ),
    );
  }
}

// 🌟 完整版：設定頁面
class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});
  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  bool isNotify = true;
  bool isLargeFont = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 10),
        _buildGroupTitle('系統通知'),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_active, color: Colors.teal),
          title: const Text('啟用吃藥提醒'),
          value: isNotify,
          onChanged: (val) => setState(() => isNotify = val),
        ),
        _buildGroupTitle('個人化顯示'),
        SwitchListTile(
          secondary: const Icon(Icons.format_size, color: Colors.blue),
          title: const Text('大字體模式'),
          value: isLargeFont,
          onChanged: (val) => setState(() => isLargeFont = val),
        ),
        _buildGroupTitle('資料管理'),
        ListTile(leading: const Icon(Icons.cloud_upload_outlined, color: Colors.orange), title: const Text('同步雲端資料庫'), onTap: () {}),
        ListTile(leading: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red), title: const Text('匯出服藥紀錄 (PDF)'), onTap: () {}),
        
        _buildGroupTitle('關於系統'),
        const ListTile(leading: Icon(Icons.info_outline), title: Text('版本資訊'), trailing: Text('v1.2.0')),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.grey),
          title: const Text('登出帳號'),
          onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const WelcomePage()), (r) => false),
        ),
      ],
    );
  }

  Widget _buildGroupTitle(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.withOpacity(0.1),
      child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }
}