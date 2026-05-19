import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;

// 🌟 1. 新增的套件：用來把 Token 存在瀏覽器記憶體裡
import 'package:shared_preferences/shared_preferences.dart';

// 🌟 2. 新增的變數：因為你用網頁版測試，所以直接用 127.0.0.1 即可！
const String API_BASE_URL = 'http://127.0.0.1:8000'; 

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

// ==========================================
// 🌟 串接真實 API 版：頁面 2 登入頁面
// ==========================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _isLoading = false;

// 執行登入 API 串接
  Future<void> _login() async {
    if (_usernameCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入帳號與密碼'), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('👉 準備發送登入請求給: $API_BASE_URL/accounts/api/login/');
      
      final response = await http.post(
        Uri.parse('$API_BASE_URL/accounts/api/login/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "user_name": _usernameCtrl.text,
          "password": _passwordCtrl.text,
        }),
      );

      debugPrint('👈 收到伺服器回應！狀態碼: ${response.statusCode}');
      debugPrint('👈 伺服器回傳內容: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        
        try {
          int userId = int.parse(data['data']['user_id'].toString());
          String token = data['data']['token'].toString();
          String nickname = data['data']['nickname']?.toString() ?? '使用者';

          await prefs.setInt('user_id', userId);
          await prefs.setString('token', token);
          await prefs.setString('nickname', nickname);
          debugPrint('✅ 登入成功！Token 已儲存: $token');
        } catch (parseError) {
          debugPrint('❌ 資料解析錯誤: $parseError');
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 登入成功！'), backgroundColor: Colors.teal));
        
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainAppPage()));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('登入失敗：${data['message'] ?? '帳號或密碼錯誤'}'), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      debugPrint('❌ 登入發生致命錯誤: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('連線伺服器失敗，請檢查網路或 IP 設定'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('會員登入')),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(labelText: '帳號', prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '密碼', prefixIcon: Icon(Icons.lock)),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 55, 
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login, 
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('登入', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              )
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🌟 串接真實 API 版：頁面 3 註冊頁面
// ==========================================
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _nicknameCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _allergiesCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  
  String selectedGender = '男';
  bool _isLoading = false;

  Future<void> _register() async {
    if (_usernameCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('帳號與密碼為必填欄位'), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/accounts/api/register/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "user_name": _usernameCtrl.text,
          "password": _passwordCtrl.text,
          "nickname": _nicknameCtrl.text.isNotEmpty ? _nicknameCtrl.text : _nameCtrl.text,
          "gender": selectedGender,
          "height": double.tryParse(_heightCtrl.text) ?? 0,
          "weight": double.tryParse(_weightCtrl.text) ?? 0,
          "allergies": _allergiesCtrl.text.isNotEmpty ? _allergiesCtrl.text : "無",
          "emergency_contact_phone": _phoneCtrl.text
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['status'] == 'success') {
          _showSuccessDialog();
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('註冊失敗：${data['message']}'), backgroundColor: Colors.redAccent));
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('伺服器錯誤：${response.statusCode}'), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      debugPrint('註冊發生錯誤: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('連線伺服器失敗，請檢查網路設定'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: const Text('帳號已成功建立！\n您的健康資料已同步至資料庫。', textAlign: TextAlign.center),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context); 
                Navigator.pop(context); 
              },
              child: const Text('好的，去登入', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
            ),
          )
        ],
      ),
    );
  }

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
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '真實姓名', prefixIcon: Icon(Icons.badge_outlined))),
            const SizedBox(height: 15),
            TextField(controller: _nicknameCtrl, decoration: const InputDecoration(labelText: '暱稱 (顯示於首頁)', prefixIcon: Icon(Icons.face))),
            const SizedBox(height: 15),
            TextField(controller: _usernameCtrl, decoration: const InputDecoration(labelText: '登入帳號', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 15),
            TextField(controller: _passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: '密碼設定', prefixIcon: Icon(Icons.lock_outline))),
            
            const SizedBox(height: 30),
            _buildSectionTitle('核心健康資訊 (必填)'),
            const Text('性別', style: TextStyle(fontSize: 16, color: Colors.grey)),
            Row(
              children: [
                Radio(value: '男', groupValue: selectedGender, onChanged: (val) => setState(() => selectedGender = val!)), const Text('男'),
                const SizedBox(width: 20),
                Radio(value: '女', groupValue: selectedGender, onChanged: (val) => setState(() => selectedGender = val!)), const Text('女'),
              ]
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: _heightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '身高 (cm)', prefixIcon: Icon(Icons.height)))),
                const SizedBox(width: 15),
                Expanded(child: TextField(controller: _weightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '體重 (kg)', prefixIcon: Icon(Icons.monitor_weight_outlined)))),
              ]
            ),
            const SizedBox(height: 15),
            TextField(controller: _allergiesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '藥物過敏史', hintText: '若無請填「無」', prefixIcon: Icon(Icons.warning_amber_rounded), border: OutlineInputBorder())),
            
            const SizedBox(height: 30),
            _buildSectionTitle('安全聯繫'),
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '緊急聯絡人電話', prefixIcon: Icon(Icons.contact_phone_outlined))),
            
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 55, 
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: _isLoading ? null : _register,
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('完成並送出', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              )
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) { 
    return Padding(
      padding: const EdgeInsets.only(bottom: 15), 
      child: Row(
        children: [
          Container(width: 5, height: 20, color: Colors.teal), 
          const SizedBox(width: 10), 
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal))
        ]
      )
    ); 
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
// ==========================================
// 🌟 串接真實 API 版：全螢幕掃描相機視窗
// ==========================================
// ==========================================
// 🌟 串接真實 API 版：全螢幕掃描相機視窗
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

  // 🌟 真實串接 1：上傳圖片給 AI 辨識
  Future<void> _uploadAndAnalyze(XFile imageFile) async { 
    _showLoadingDialog("正在由 AI 分析藥單...");
    var apiUrl = Uri.parse('$API_BASE_URL/medications/api/scan/');

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
      var responseData = utf8.decode(await response.stream.toBytes()); 
      
      if (!mounted) return;
      Navigator.pop(context); 

      if (response.statusCode == 200) {
        var jsonResult = json.decode(responseData);
        if (jsonResult['status'] == 'success') {
          // 💡 修改點 1：把 imageFile 一起丟給確認視窗，因為下一步還要用！
          _showResultDialog(jsonResult['data'] ?? [], imageFile);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('辨識失敗: ${jsonResult['message']}'), backgroundColor: Colors.red));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('伺服器錯誤，請檢查後端 AI 是否正常運行！'), backgroundColor: Colors.red));
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
              const Text("請稍候，這可能需要幾秒鐘的時間...", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  // 💡 修改點 2：函式多接收一個 XFile 參數
  void _showResultDialog(List<dynamic> drugsData, XFile imageFile) {
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
                      ? <Widget>[const Text('未能辨識出任何藥品，請重拍', style: TextStyle(color: Colors.red))]
                      : drugsData.map<Widget>((drug) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 6, child: Text('• ${drug['raw_name'] ?? '未知藥物'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))),
                                Expanded(flex: 4, child: Text('${drug['frequency'] ?? ''} \n${drug['total_amount'] ?? ''}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.2))),
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
                // 💡 修改點 3：把圖片傳給儲存 API
                _checkInteractionsAndSave(drugsData, imageFile); 
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              child: const Text('確認並檢測'),
            ),
          ],
        );
      },
    );
  }

  // 🌟 💡 終極修改：改用 Form-data 傳送，並符合所有欄位名稱
  Future<void> _checkInteractionsAndSave(List<dynamic> drugsData, XFile imageFile) async {
    _showLoadingDialog("正在安全儲存藥單並進行交互作用檢測...");
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('user_id');

      // 1. 整理藥品陣列，嚴格對齊規格書要求的欄位
      List<Map<String, dynamic>> confirmedDrugs = drugsData.map((drug) {
        return {
          "raw_name": drug['raw_name'] ?? "未知藥物",
          "search_keyword": drug['search_keyword'] ?? drug['raw_name'] ?? "未知藥物", // 規格書要求要有這個
          "frequency": drug['frequency'] ?? "每日三次",
          "days": drug['days']?.toString() ?? "3", 
          "total_amount": drug['total_amount']?.toString() ?? "9"
        };
      }).toList();

      // 2. 準備打包成 JSON 字串的 data
      Map<String, dynamic> payloadData = {
        "user_id": userId,
        "hospital_name": "掃描建立的藥單",
        "visit_date": "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}",
        "confirmed_drugs": confirmedDrugs // 陣列名稱改為 confirmed_drugs
      };

      // 3. 改用 MultipartRequest (Form-data) 發送
      var apiUrl = Uri.parse('$API_BASE_URL/medications/api/confirm_and_save/');
      var request = http.MultipartRequest('POST', apiUrl);

      // (A) 把 JSON 轉成字串，塞進 'data' 欄位
      request.fields['data'] = json.encode(payloadData);

      // (B) 把圖片再次塞進 'prescription_img' 欄位
      if (kIsWeb) {
        var bytes = await imageFile.readAsBytes();
        var pic = http.MultipartFile.fromBytes('prescription_img', bytes, filename: imageFile.name);
        request.files.add(pic);
      } else {
        var pic = await http.MultipartFile.fromPath('prescription_img', imageFile.path);
        request.files.add(pic);
      }

      debugPrint('👉 準備傳送 Form-data 儲存資料至後端...');
      var response = await request.send();
      var responseData = utf8.decode(await response.stream.toBytes());
      
      debugPrint('👈 收到檢測結果: $responseData');
      
      if (!mounted) return;
      Navigator.pop(context); // 關閉載入框

      if (response.statusCode == 200 || response.statusCode == 201) {
        var data = json.decode(responseData);
        bool hasInteraction = data['has_danger'] == true; 
        String interactionDetails = data['danger_message'] ?? "請留意藥物使用安全，若有不適請立即停藥。";
        
        _showFinalResultDialog(hasInteraction, interactionDetails);
      } else {
        // 如果還是出錯，直接把後端的錯誤吐在畫面上，方便抓蟲
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('儲存失敗: $responseData'), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 5)));
      }

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      debugPrint('❌ 檢測發生錯誤: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('連線失敗: $e'), backgroundColor: Colors.redAccent));
    }
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
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainAppPage()));
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
                      const Text('相簿上傳', style: TextStyle(color: Colors.white, fontSize: 12)),
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
class MyMedicationBagPage extends StatefulWidget {
  const MyMedicationBagPage({super.key});
  @override
  State<MyMedicationBagPage> createState() => _MyMedicationBagPageState();
}

class _MyMedicationBagPageState extends State<MyMedicationBagPage> {
  List<Map<String, dynamic>> _prescriptions = [];
  String _searchQuery = '';
  String _currentFilter = '全部時間';
  bool _isLoading = true; 

  @override
  void initState() {
    super.initState();
    _fetchPrescriptions();
  }

  Future<void> _fetchPrescriptions() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('user_id');
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }
      final response = await http.get(Uri.parse('$API_BASE_URL/medications/api/prescriptions/$userId/'));
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() => _prescriptions = List<Map<String, dynamic>>.from(data['data']));
      }
    } catch (e) {
      debugPrint('抓取藥單列表錯誤: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createManualPrescription(String hospitalName, String visitDate) async {
    if (hospitalName.trim().isEmpty || visitDate.trim().isEmpty) return;
    setState(() => _isLoading = true); 
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('user_id');
      if (userId == null) return;
      final response = await http.post(
        Uri.parse('$API_BASE_URL/medications/api/prescriptions/create/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"user_id": userId, "hospital_name": hospitalName, "visit_date": visitDate}),
      );
      final data = json.decode(utf8.decode(response.bodyBytes));
      if ((response.statusCode == 200 || response.statusCode == 201) && data['status'] == 'success') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ 成功手動建立 「$hospitalName」 藥單！'), backgroundColor: Colors.teal));
        _fetchPrescriptions(); 
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('連線失敗：$e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 新增：手動更新藥單資訊 API (對齊規格書四-4)
  Future<void> _updatePrescription(int prescriptionId, String hospitalName, String visitDate) async {
    if (hospitalName.trim().isEmpty || visitDate.trim().isEmpty) return;
    setState(() => _isLoading = true); 
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/medications/api/prescriptions/$prescriptionId/update/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "hospital_name": hospitalName, 
          "visit_date": visitDate
        }),
      );
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data['status'] == 'success') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📝 藥單資料更新成功！'), backgroundColor: Colors.teal));
        _fetchPrescriptions(); // 🌟 重新整理列表，顯示修改後的名字
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失敗：${data['message']}'), backgroundColor: Colors.redAccent));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('連線失敗：$e'), backgroundColor: Colors.redAccent));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePrescription(int prescriptionId, String hospitalName) async {
    try {
      final response = await http.post(Uri.parse('$API_BASE_URL/medications/api/prescriptions/$prescriptionId/delete/'));
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data['status'] == 'success') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ 已從資料庫刪除 $hospitalName 的藥單'), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      debugPrint('刪除藥單失敗: $e');
    }
  }

  Future<void> _checkAllSafety() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userId = prefs.getInt('user_id');
    if (userId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.teal)),
    );

    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/medications/api/check_all_safety/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"user_id": userId}),
      );
      
      if (!mounted) return;
      Navigator.pop(context); 

      final data = json.decode(utf8.decode(response.bodyBytes));
      
      if (response.statusCode == 200 && data['status'] == 'success') {
        List<dynamic> rawList = data['data'] ?? [];
        List<dynamic> actualDangerList = rawList.where((item) {
          final warnings = item['warnings'] as List?;
          return warnings != null && warnings.isNotEmpty;
        }).toList();

        _showSafetyResultDialog(actualDangerList);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('檢查失敗：${data['message']}'), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('連線失敗：$e'), backgroundColor: Colors.redAccent));
    }
  }

  void _showSafetyResultDialog(List<dynamic> dangerList) {
    if (dangerList.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 30), SizedBox(width: 10), Text('安全過關！')]),
          content: const Text('太棒了！您目前身上所有的藥單之間沒有發現任何交互作用與過敏風險。請安心服藥！', style: TextStyle(fontSize: 15, height: 1.5)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('太好了', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)))],
        )
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 30), SizedBox(width: 10), Expanded(child: Text('發現跨藥單風險！', style: TextStyle(fontSize: 18)))]),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: dangerList.length,
            itemBuilder: (context, index) {
              final item = dangerList[index];
              return Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('💊 ${item['raw_name']} (${item['hospital']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.redAccent)),
                      const SizedBox(height: 8),
                      ...(item['warnings'] as List).map<Widget>((w) => Text('⚠️ 【${w['conflict_target']}】${w['warning_desc']}', style: const TextStyle(fontSize: 13, height: 1.3))).toList()
                    ],
                  ),
                ),
              );
            }
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('我了解了', style: TextStyle(color: Colors.grey)))],
      )
    );
  }

  void _showAddPrescriptionDialog() {
    final TextEditingController hospitalCtrl = TextEditingController();
    final TextEditingController dateCtrl = TextEditingController(text: "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.add_box, color: Colors.teal), SizedBox(width: 10), Text('手動新增藥單', style: TextStyle(fontWeight: FontWeight.bold))]),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: hospitalCtrl, decoration: const InputDecoration(labelText: '醫院/診所名稱', hintText: '例如：長庚醫院')),
            const SizedBox(height: 10),
            TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: '看診日期', hintText: '格式：YYYY-MM-DD')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              Navigator.pop(context); 
              _createManualPrescription(hospitalCtrl.text, dateCtrl.text);
            },
            child: const Text('建立', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 🌟 新增：顯示編輯藥單彈窗
  void _showEditPrescriptionDialog(Map<String, dynamic> item) {
    final TextEditingController hospitalCtrl = TextEditingController(text: item['hospital_name']);
    final TextEditingController dateCtrl = TextEditingController(text: item['visit_date']);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.edit_document, color: Colors.orangeAccent), SizedBox(width: 10), Text('編輯藥單資訊', style: TextStyle(fontWeight: FontWeight.bold))]),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: hospitalCtrl, decoration: const InputDecoration(labelText: '醫院/診所名稱')),
            const SizedBox(height: 10),
            TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: '看診日期', hintText: '格式：YYYY-MM-DD')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              Navigator.pop(context);
              _updatePrescription(item['prescription_id'], hospitalCtrl.text, dateCtrl.text);
            },
            child: const Text('儲存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> displayedData = _prescriptions.where((item) {
      return item['hospital_name'].toString().contains(_searchQuery) || item['visit_date'].toString().contains(_searchQuery);
    }).toList();

    if (_currentFilter == '最新加入') displayedData.sort((a, b) => b['visit_date'].compareTo(a['visit_date']));
    else if (_currentFilter == '最早加入') displayedData.sort((a, b) => a['visit_date'].compareTo(b['visit_date']));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 32), 
                  const Text('我的藥單紀錄', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.teal)),
                  IconButton(icon: const Icon(Icons.add_circle, color: Colors.teal, size: 32), onPressed: _showAddPrescriptionDialog)
                ],
              ),
            ),
            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity, height: 45,
              child: ElevatedButton.icon(
                onPressed: _checkAllSafety,
                icon: const Icon(Icons.health_and_safety, color: Colors.white),
                label: const Text('進行總體用藥安全檢查', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
              ),
            ),
            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  flex: 7,
                  child: Container(
                    height: 45, padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.grey), const SizedBox(width: 10),
                        Expanded(child: TextField(onChanged: (value) { setState(() { _searchQuery = value; }); }, decoration: const InputDecoration(hintText: '搜尋...', border: InputBorder.none, isDense: true))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: PopupMenuButton<String>(
                    onSelected: (String value) { setState(() { _currentFilter = value; }); },
                    itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(value: '全部時間', child: Text('全部時間')),
                      PopupMenuItem<String>(value: '最新加入', child: Text('最新加入')),
                      PopupMenuItem<String>(value: '最早加入', child: Text('最早加入')),
                    ],
                    child: Container(
                      height: 45, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.filter_list, size: 18, color: Colors.teal), const SizedBox(width: 5), Text(_currentFilter == '全部時間' ? '篩選' : _currentFilter.substring(0, 2), style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold))]),
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
                child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.teal)) 
                : displayedData.isEmpty 
                  ? const Center(child: Text('目前沒有任何藥單紀錄', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: displayedData.length,
                      itemBuilder: (context, index) {
                        final item = displayedData[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Dismissible(
                            key: Key(item['prescription_id'].toString()),
                            direction: DismissDirection.endToStart, 
                            background: Container(
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.redAccent),
                              alignment: Alignment.centerRight,
                              child: const Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text('刪除藥單', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), SizedBox(width: 5), Icon(Icons.delete, color: Colors.white)]),
                            ),
                            onDismissed: (direction) {
                              _deletePrescription(item['prescription_id'], item['hospital_name']);
                              setState(() { _prescriptions.removeWhere((p) => p['prescription_id'] == item['prescription_id']); });
                            },
                            child: InkWell(
                              onTap: () async {
                                item['meds'] ??= [];
                                await Navigator.push(context, MaterialPageRoute(builder: (context) => PrescriptionDetailPage(prescription: item)));
                                _fetchPrescriptions(); 
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.teal.shade100, width: 1.0)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['hospital_name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                        const SizedBox(height: 4),
                                        Text('看診日期: ${item['visit_date']}   |   藥品數量: ${item['drug_count'] ?? 0} 種', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                    // 🌟 加入編輯按鈕與箭頭
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.orangeAccent, size: 20),
                                          onPressed: () => _showEditPrescriptionDialog(item),
                                        ),
                                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.teal),
                                      ],
                                    ),
                                  ],
                                ),
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
    );
  }
}
// ==========================================
// 🌟 真實功能+用藥安全紅綠燈版：【個別藥單詳細頁面】
// ==========================================
// ==========================================
// 🌟 真實功能+用藥安全紅綠燈版：【個別藥單詳細頁面】
// ==========================================
class PrescriptionDetailPage extends StatefulWidget {
  final Map<String, dynamic> prescription;
  const PrescriptionDetailPage({super.key, required this.prescription});
  @override
  State<PrescriptionDetailPage> createState() => _PrescriptionDetailPageState();
}

class _PrescriptionDetailPageState extends State<PrescriptionDetailPage> {
  bool _isLoading = true; // 載入狀態
  List<dynamic> _meds = []; // 用來裝後端傳來的藥品明細
  bool _hasSevereDanger = false;

  @override
  void initState() {
    super.initState();
    _fetchPrescriptionDetails(); // 一進畫面就去抓資料
  }

  // 🌟 核心 API 串接：取得特定藥單的詳情 
  Future<void> _fetchPrescriptionDetails() async {
    final pid = widget.prescription['prescription_id'];
    if (pid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      debugPrint('👉 準備獲取藥單明細，ID: $pid');
      final response = await http.get(
        Uri.parse('$API_BASE_URL/medications/api/prescription_details/$pid/'),
      );

      final rawResponse = utf8.decode(response.bodyBytes);
      final data = json.decode(rawResponse);

      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          if (data['data'] is List) {
            _meds = List<dynamic>.from(data['data']); 
          } else {
            _meds = data['data']['medications'] ?? data['data']['drugs'] ?? data['data']['meds'] ?? [];
          }
          
          _hasSevereDanger = _meds.any((m) => m['is_severe_danger'] == true);
        });
      }
    } catch (e) {
      debugPrint('連線錯誤: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 核心 API 串接：手動新增單筆藥品
  Future<void> _addSingleDrug(String rawName, String frequency, String days, String totalAmount) async {
    final pid = widget.prescription['prescription_id'];
    if (pid == null) return;

    if (rawName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入藥品名稱！'), backgroundColor: Colors.orangeAccent));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/medications/api/prescriptions/$pid/add_drug/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"raw_name": rawName, "frequency": frequency, "days": days, "total_amount": totalAmount}),
      );

      final data = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && data['status'] == 'success') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ 成功加入藥品 「$rawName」！'), backgroundColor: Colors.teal));
        _fetchPrescriptionDetails(); 
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('新增失敗：${data['message']}'), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('連線失敗：$e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 核心 API 串接：真實刪除單一藥品 (對齊規格書四-7)
  Future<void> _deleteSingleDrug(int pdId, String drugName) async {
    try {
      debugPrint('👉 準備刪除藥品明細，ID: $pdId');
      final response = await http.post(
        Uri.parse('$API_BASE_URL/medications/api/prescriptions/drug/$pdId/delete/'),
      );
      
      final data = json.decode(utf8.decode(response.bodyBytes));
      
      if (response.statusCode == 200 && data['status'] == 'success') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🗑️ 已成功刪除藥品「$drugName」'), backgroundColor: Colors.teal)
        );
        // 刪除成功後，重新抓一次藥單明細，確保安全檢測與紅綠燈狀態是正確的
        _fetchPrescriptionDetails();
      } else {
        // 如果後端刪除失敗，把資料重新抓回來還原畫面
        _fetchPrescriptionDetails();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刪除失敗：${data['message']}'), backgroundColor: Colors.redAccent)
        );
      }
    } catch (e) {
      _fetchPrescriptionDetails(); // 還原畫面
      debugPrint('❌ 刪除單一藥品發生錯誤: $e');
    }
  }

  void _showAddDrugDialog() {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController freqCtrl = TextEditingController(text: '每日三次');
    final TextEditingController daysCtrl = TextEditingController(text: '3');
    final TextEditingController amountCtrl = TextEditingController(text: '9');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [Icon(Icons.medication, color: Colors.teal), SizedBox(width: 10), Text('手動新增藥品', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '藥品原名 (raw_name)', hintText: '例如：Aspirin')),
              TextField(controller: freqCtrl, decoration: const InputDecoration(labelText: '服用頻率 (frequency)', hintText: '例如：每日一次')),
              Row(
                children: [
                  Expanded(child: TextField(controller: daysCtrl, decoration: const InputDecoration(labelText: '天數 (days)', hintText: '例如：3'))),
                  const SizedBox(width: 15),
                  Expanded(child: TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: '總量 (total_amount)', hintText: '例如：9'))),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              Navigator.pop(context);
              _addSingleDrug(nameCtrl.text, freqCtrl.text, daysCtrl.text, amountCtrl.text);
            },
            child: const Text('加入', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, 
        iconTheme: const IconThemeData(color: Colors.teal),
        title: const Text('藥單詳細資訊', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 25),
                decoration: BoxDecoration(
                  color: _hasSevereDanger ? Colors.redAccent : Colors.teal,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: (_hasSevereDanger ? Colors.red : Colors.teal).withOpacity(0.3), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 3))],
                ),
                child: Center(
                  child: Text(
                    widget.prescription['hospital_name'] ?? '醫院名稱載入中', 
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)
                  ),
                ),
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
                            child: Row(
                              children: [
                                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 5),
                                Text(widget.prescription['visit_date'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: _showAddDrugDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.teal.shade200)),
                              child: const Row(
                                children: [
                                  Icon(Icons.add, size: 16, color: Colors.teal),
                                  SizedBox(width: 5),
                                  Text('手動新增藥品', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),

                      // 🌟 動態顯示藥品清單
                      Expanded(
                        child: _isLoading 
                        ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                        : _meds.isEmpty
                          ? const Center(child: Text('此藥單目前沒有任何藥品紀錄', style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: _meds.length,
                              itemBuilder: (context, index) {
                                final med = _meds[index];
                                bool _isMedSevere = med['is_severe_danger'] == true;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Dismissible(
                                    key: Key(med['id'].toString()),
                                    direction: DismissDirection.endToStart, 
                                    background: Container(
                                      padding: const EdgeInsets.only(right: 20),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.redAccent,
                                      ),
                                      alignment: Alignment.centerRight,
                                      child: const Icon(Icons.delete_forever, color: Colors.white, size: 28),
                                    ),
                                    onDismissed: (direction) {
                                      // 💡 1. 取得要刪除的 ID 與名稱
                                      final deletedId = med['id'];
                                      final deletedName = med['raw_name'] ?? '未知藥品';
                                      
                                      // 💡 2. 畫面上先樂觀移除，讓動畫順利播放
                                      setState(() { _meds.removeAt(index); });

                                      // 💡 3. 呼叫後端真正刪除
                                      _deleteSingleDrug(deletedId, deletedName);
                                    },
                                    child: Container(
                                      width: double.infinity, padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: _isMedSevere ? Colors.redAccent : Colors.grey.shade200, width: _isMedSevere ? 2.0 : 1.0),
                                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 3)],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    if (_isMedSevere) ...[
                                                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                                                      const SizedBox(width: 6),
                                                    ],
                                                    Expanded(
                                                      child: Text(
                                                        med['raw_name'] ?? '未知藥品', 
                                                        style: TextStyle(
                                                          fontSize: 18, 
                                                          fontWeight: FontWeight.bold, 
                                                          color: _isMedSevere ? Colors.redAccent : Colors.black87 
                                                        )
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  showDialog(
                                                    context: context, 
                                                    builder: (context) => AlertDialog(
                                                      title: Text('${med['raw_name']} 詳細資訊', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                                      content: Text('中文譯名：${med['med_ch'] ?? "無資料"}\n服用天數：${med['days'] ?? "未知"} \n總計數量：${med['total_amount'] ?? "未知"}'),
                                                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉'))],
                                                    )
                                                  );
                                                },
                                                child: Container(
                                                  width: 35, height: 35,
                                                  decoration: BoxDecoration(color: _isMedSevere ? Colors.red.withOpacity(0.1) : Colors.teal.shade50, shape: BoxShape.circle),
                                                  child: Center(child: Icon(Icons.info_outline, color: _isMedSevere ? Colors.redAccent : Colors.teal, size: 18)),
                                                ),
                                              )
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text('用法頻率: ${med['frequency'] ?? ""}  |  看診天數: ${med['days'] ?? ""}  |  總量: ${med['total_amount'] ?? ""}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                          
                                          if (med['warnings'] != null && (med['warnings'] as List).isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            const Divider(),
                                            const SizedBox(height: 4),
                                            ...(med['warnings'] as List).map<Widget>((warn) {
                                              bool isConflict = warn['is_drug_conflict'] == true;
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 4.0),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(Icons.gpp_maybe, size: 16, color: isConflict ? Colors.redAccent : Colors.orange),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        '【${warn['conflict_target']}】${warn['warning_desc']}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: isConflict ? Colors.redAccent : Colors.black87,
                                                          fontWeight: isConflict ? FontWeight.bold : FontWeight.normal,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList()
                                          ]
                                        ],
                                      ),
                                    ),
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
  bool _isPrescriptionsLoading = true;
  bool _isDrugsLoading = false;
  List<dynamic> _prescriptions = [];
  
  // 💡 修正 1：下拉選單改為只綁定藥單 ID，避免 Flutter 報錯
  int? _selectedPrescriptionId; 
  
  List<dynamic> _drugs = [];

  // 🌟 核心資料結構：將藥品依照「頻率」分類群組
  Map<String, List<dynamic>> _groupedDrugs = {};
  Map<String, List<String>> _groupTimes = {};
  Map<String, List<String>> _groupTags = {};

  @override
  void initState() {
    super.initState();
    _fetchUserPrescriptions(); // 頁面載入時先抓取該用戶的所有藥單
  }

  // 🌟 1. 獲取使用者藥單清單 (用來塞下拉選單)
  Future<void> _fetchUserPrescriptions() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('user_id');
      if (userId == null) {
        setState(() => _isPrescriptionsLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse('$API_BASE_URL/medications/api/prescriptions/$userId/'),
      );
      final data = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          _prescriptions = data['data'] ?? [];
          _isPrescriptionsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('鬧鐘頁面獲取藥單失敗: $e');
      setState(() => _isPrescriptionsLoading = false);
    }
  }

  // 🌟 2. 當選取某張藥單時，獲取其底下的所有藥品明細
  Future<void> _fetchDrugsForPrescription(int prescriptionId) async {
    setState(() {
      _isDrugsLoading = true;
      _drugs = [];
      _groupedDrugs = {};
    });

    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/medications/api/prescription_details/$prescriptionId/'),
      );
      final data = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && data['status'] == 'success') {
        _drugs = data['data'] ?? [];
        _groupDrugsByFrequency(); // 執行自動分群演算法
      }
    } catch (e) {
      debugPrint('獲取藥品明細失敗: $e');
    } finally {
      setState(() => _isDrugsLoading = false);
    }
  }

  // 🌟 3. 核心演算法：依照藥品服用頻率自動分群，並初始化預設 Tag 與時間 
  void _groupDrugsByFrequency() {
    _groupedDrugs.clear();
    _groupTimes.clear();
    _groupTags.clear();

    for (var drug in _drugs) {
      String freq = drug['frequency'] ?? '每日一次';
      if (!_groupedDrugs.containsKey(freq)) {
        _groupedDrugs[freq] = [];
      }
      _groupedDrugs[freq]!.add(drug);
    }

    _groupedDrugs.forEach((freq, drugList) {
      List<String> tags = [];
      List<String> times = [];

      if (freq.contains('三') || freq.contains('3') || freq.toLowerCase().contains('tid')) {
        tags = ['早餐後', '午餐後', '晚餐後'];
        times = ['08:30', '12:30', '18:30'];
      } else if (freq.contains('二') || freq.contains('2') || freq.toLowerCase().contains('bid')) {
        tags = ['早餐後', '晚餐後'];
        times = ['08:30', '18:30'];
      } else if (freq.contains('睡前') || freq.toLowerCase().contains('hs')) {
        tags = ['睡前'];
        times = ['21:30'];
      } else {
        tags = ['隨餐'];
        times = ['08:30'];
      }

      _groupTags[freq] = tags;
      _groupTimes[freq] = times;
    });
  }

  // 🌟 4. 時間選擇器彈窗
  void _showGroupTimePicker(String freq, int timeIndex) {
    final currentTimes = _groupTimes[freq] ?? ['08:30'];
    final timeParts = currentTimes[timeIndex].split(':');
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
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10), 
                  child: Text('設定【$freq】的第 ${timeIndex + 1} 劑時間', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal))
                ),
                const Divider(),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time, 
                    initialDateTime: initialDateTime, 
                    use24hFormat: true, 
                    onDateTimeChanged: (DateTime newDate) { 
                      setState(() { 
                        _groupTimes[freq]![timeIndex] = "${newDate.hour.toString().padLeft(2, '0')}:${newDate.minute.toString().padLeft(2, '0')}"; 
                      }); 
                    },
                  )
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end, 
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Colors.grey))), 
                    const SizedBox(width: 10), 
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context), 
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), 
                      child: const Text('完成', style: TextStyle(color: Colors.white))
                    )
                  ]
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // 🌟 5. 將分群結構轉回以「藥品」為單位的 API Payload 並上傳 [cite: 4]
  Future<void> _saveReminders() async {
    if (_selectedPrescriptionId == null || _drugs.isEmpty) return;

    final pid = _selectedPrescriptionId;
    List<Map<String, dynamic>> drugsPayload = [];

    _groupedDrugs.forEach((freq, drugList) {
      final tags = _groupTags[freq] ?? [];
      final times = _groupTimes[freq] ?? [];

      for (var drug in drugList) {
        final drugId = drug['id']; 
        if (drugId == null) continue;

        List<Map<String, String>> remindersList = [];
        for (int i = 0; i < tags.length; i++) {
          remindersList.add({
            "frequency_tag": tags[i],
            "remind_time": "${times[i]}:00" 
          });
        }

        drugsPayload.add({
          "prescription_drug_id": drugId,
          "reminders": remindersList
        });
      }
    });

    final payload = {
      "prescription_id": pid,
      "drugs": drugsPayload
    };

    try {
      debugPrint('👉 準備發送鬧鐘批次設定：${json.encode(payload)}');
      final response = await http.post(
        Uri.parse('$API_BASE_URL/medications/api/reminders/set/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      final data = json.decode(utf8.decode(response.bodyBytes));
// 💡 修正：把 201 (Created) 也加入成功的判斷條件中
      if ((response.statusCode == 200 || response.statusCode == 201) && data['status'] == 'success') {        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🎉 ${data['message'] ?? "已成功同步雲端鬧鐘！"}'), backgroundColor: Colors.teal)
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('設定失敗：${data['message']}'), backgroundColor: Colors.redAccent)
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('連線失敗：$e'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isPrescriptionsLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.teal))
              : Column(
                  children: [
                    // 標題卡片
                    Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)]),
                      child: const Center(child: Text('吃藥提醒鬧鐘 ⏰', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.teal))),
                    ),
                    const SizedBox(height: 15),

                    // 💡 修正 2：下拉選單的 value 改綁定整數 ID
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: '選擇要設定的藥單紀錄',
                        filled: true, fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      value: _selectedPrescriptionId,
                      items: _prescriptions.map<DropdownMenuItem<int>>((p) {
                        return DropdownMenuItem<int>(
                          value: p['prescription_id'] as int,
                          child: Text('${p['hospital_name']} (${p['visit_date']})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPrescriptionId = val;
                          if (val != null) _fetchDrugsForPrescription(val);
                        });
                      },
                    ),
                    const SizedBox(height: 15),

                    // 下半部動態分群清單
                    Expanded(
                      child: _isDrugsLoading
                          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                          : _selectedPrescriptionId == null
                              ? const Center(child: Text('請先在上方選擇一張藥單', style: TextStyle(color: Colors.grey)))
                              : _groupedDrugs.isEmpty
                                  ? const Center(child: Text('此藥單內目前沒有任何藥品明細', style: TextStyle(color: Colors.grey)))
                                  : ListView(
                                      children: _groupedDrugs.keys.map((freq) {
                                        final drugList = _groupedDrugs[freq]!;
                                        final tags = _groupTags[freq] ?? [];
                                        final times = _groupTimes[freq] ?? [];

                                        return Card(
                                          elevation: 2, margin: const EdgeInsets.only(bottom: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(Icons.alarm_add, color: Colors.teal),
                                                    const SizedBox(width: 8),
                                                    Text('服用頻率：$freq', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Text('包含藥品：${drugList.map((d) => d['raw_name']).join('、 ')}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                                const SizedBox(height: 15),
                                                const Divider(),
                                                const SizedBox(height: 10),
                                                
                                                Wrap(
                                                  spacing: 10, runSpacing: 10,
                                                  children: List.generate(tags.length, (timeIdx) {
                                                    return InkWell(
                                                      onTap: () => _showGroupTimePicker(freq, timeIdx),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                        decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.teal.shade200)),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text('${tags[timeIdx]}：', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal)),
                                                            Text(times[timeIdx], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal)),
                                                            const SizedBox(width: 4),
                                                            const Icon(Icons.edit, size: 14, color: Colors.teal),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                )
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                    ),
                    
                    // 💡 修正 3：按鈕語法修復
                    if (_selectedPrescriptionId != null && _groupedDrugs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal, 
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _saveReminders,
                            child: const Text('儲存提醒鬧鐘設定', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                          ),
                        ),
                      )
                  ],
                ),
        ),
      ),
    );
  }
}
// 🌟 真實 API 串接版：個人資料頁面
// ==========================================
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  bool _isLoading = true;
  Map<String, dynamic> _profileData = {};

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('user_id');
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }
      final response = await http.post(
        Uri.parse('$API_BASE_URL/accounts/api/user/profile/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"user_id": userId}),
      );
      final rawResponse = utf8.decode(response.bodyBytes);
      final data = json.decode(rawResponse);
      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          _profileData = data['data'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // 🌟 新增：更新個人資料 API (規格書一-4)
  Future<void> _updateProfile(String n, String h, String w, String a, String p) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userId = prefs.getInt('user_id');
    if (userId == null) return;
    
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/accounts/api/user/update/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "user_id": userId,
          "nickname": n.isEmpty ? _profileData['nickname'] : n,
          "height": double.tryParse(h) ?? _profileData['height'],
          "weight": double.tryParse(w) ?? _profileData['weight'],
          "allergies": a.isEmpty ? "無" : a,
          "emergency_contact_phone": p.isEmpty ? _profileData['emergency_contact_phone'] : p
        }),
      );
      
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data['status'] == 'success') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 個人資料更新成功！'), backgroundColor: Colors.teal));
        _fetchUserProfile(); // 重新抓取更新後的資料
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失敗：${data['message']}'), backgroundColor: Colors.redAccent));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('連線失敗：$e'), backgroundColor: Colors.redAccent));
      setState(() => _isLoading = false);
    }
  }

  // 🌟 新增：顯示編輯資料彈窗
  void _showEditProfileDialog() {
    final TextEditingController nickCtrl = TextEditingController(text: _profileData['nickname']);
    final TextEditingController heightCtrl = TextEditingController(text: _profileData['height']?.toString());
    final TextEditingController weightCtrl = TextEditingController(text: _profileData['weight']?.toString());
    final TextEditingController allergiesCtrl = TextEditingController(text: _profileData['allergies']);
    final TextEditingController phoneCtrl = TextEditingController(text: _profileData['emergency_contact_phone']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(children: [Icon(Icons.edit, color: Colors.teal), SizedBox(width: 10), Text('修改健康資料', style: TextStyle(fontWeight: FontWeight.bold))]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nickCtrl, decoration: const InputDecoration(labelText: '暱稱 (顯示於首頁)')),
              TextField(controller: heightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '身高 (cm)')),
              TextField(controller: weightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '體重 (kg)')),
              TextField(controller: allergiesCtrl, decoration: const InputDecoration(labelText: '藥物過敏史', hintText: '若無請填無')),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '緊急聯絡電話')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              Navigator.pop(context);
              _updateProfile(nickCtrl.text, heightCtrl.text, weightCtrl.text, allergiesCtrl.text, phoneCtrl.text);
            },
            child: const Text('儲存變更', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.teal));

    final nickname = _profileData['nickname'] ?? '未知用戶';
    final userName = _profileData['user_name'] ?? '無帳號';
    final allergies = _profileData['allergies'] ?? '無';
    final height = _profileData['height']?.toString() ?? '未知';
    final weight = _profileData['weight']?.toString() ?? '未知';
    final emergencyPhone = _profileData['emergency_contact_phone'] ?? '未設定';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Column(
            children: [
              const CircleAvatar(radius: 50, backgroundColor: Colors.teal, child: Icon(Icons.person, size: 50, color: Colors.white)),
              const SizedBox(height: 10),
              Text(nickname, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text('帳號: $userName', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              // 🌟 加入編輯按鈕
              OutlinedButton.icon(
                onPressed: _showEditProfileDialog, 
                icon: const Icon(Icons.edit, size: 16), 
                label: const Text('編輯資料'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.teal, side: const BorderSide(color: Colors.teal), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              )
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('核心健康資訊'),
        _buildInfoCard(
          Icons.warning_amber_rounded, 
          '藥物過敏史', 
          allergies, 
          (allergies == '無' || allergies == '無過敏') ? Colors.green : Colors.redAccent
        ),
        _buildInfoCard(Icons.monitor_weight_outlined, '身體數值', '身高: ${height}cm / 體重: ${weight}kg', Colors.blue),
        
        const SizedBox(height: 20),
        _buildSectionTitle('緊急聯絡人'),
        _buildInfoCard(Icons.contact_phone, '緊急聯絡人 (家屬)', emergencyPhone, Colors.teal),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)));
  }

  Widget _buildInfoCard(IconData icon, String title, String value, Color color) {
    return Card(
      elevation: 2, margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
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