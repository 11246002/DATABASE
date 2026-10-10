import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;

// 🌟 1. 新增的套件：用來把 Token 存在瀏覽器記憶體裡
import 'package:shared_preferences/shared_preferences.dart';

// 🌟 2. 新增的變數：因為你用網頁版測試，所以直接用 127.0.0.1 即可！
// 網頁開發建議改為 127.0.0.1 或 localhost，避免跨網域問題
const String API_BASE_URL = 'http://127.0.0.1:8000';

// 🌟 [暫時測試] 長輩大字體全域開關 (預設標準 1.0x，開啟時 1.28x)
final ValueNotifier<bool> isLargeFontNotifier = ValueNotifier<bool>(false);

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('相機錯誤: ${e.code}, ${e.description}');
  }

  runApp(
    ValueListenableBuilder<bool>(
      valueListenable: isLargeFontNotifier,
      builder: (context, isLargeFont, _) {
        return MaterialApp(
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
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(isLargeFont ? 1.28 : 1.0),
              ),
              child: child!,
            );
          },
          home: const LoginPage(),
        );
      },
    ),
  );
}

// --- 頁面 1: 歡迎頁面 ---
// ==========================================
// 🌟 乾淨整潔版：登入頁面
// ==========================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 🌟 你的變數完全保留
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _isLoading = false;

  // 🌟 你的 _login() 邏輯完全保留，一字不改
  Future<void> _login() async {
    if (_usernameCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入帳號與密碼'), backgroundColor: Colors.redAccent));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/accounts/api/login/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"user_name": _usernameCtrl.text, "password": _passwordCtrl.text}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', int.parse(data['data']['user_id'].toString()));
        await prefs.setString('token', data['data']['token'].toString());
        await prefs.setString('user_name', _usernameCtrl.text.trim());
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainAppPage()));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('登入失敗：${data['message']}'), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('連線伺服器失敗'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 只替換畫面排版 (乾淨整潔風格 + Logo)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.medication_liquid, size: 60, color: Colors.teal),
              ),
              const SizedBox(height: 15),
              const Text('智慧藥管家', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.teal, letterSpacing: 2)),
              const SizedBox(height: 40),
              
              const Align(alignment: Alignment.centerLeft, child: Text('歡迎回來', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87))),
              const SizedBox(height: 10),
              const Align(alignment: Alignment.centerLeft, child: Text('請輸入您的帳號密碼以繼續使用', style: TextStyle(fontSize: 15, color: Colors.grey))),
              const SizedBox(height: 30),
              
              // 綁定你原本的 Controller
              _buildCleanInput('帳號', Icons.person_outline, _usernameCtrl, false),
              const SizedBox(height: 20),
              _buildCleanInput('密碼', Icons.lock_outline, _passwordCtrl, true),
              
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 55, 
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login, 
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('立即登入', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                )
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('還沒有帳號嗎？', style: TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const RegisterPage())),
                    child: const Text('立即註冊', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 16)),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCleanInput(String hint, IconData icon, TextEditingController controller, bool isPassword) {
    return TextField(
      controller: controller, obscureText: isPassword,
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        filled: true, fillColor: const Color(0xFFF2F2F7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }
}// 🌟 串接真實 API 版：頁面 2 登入頁面
// ==========================================
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // 🌟 你原本定義的所有欄位，一字不漏保留
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

  // 🌟 將你原本串好後端的 _register() 邏輯貼在下面這裡！
// 🌟 完整的註冊 API 呼叫邏輯 (已對齊 API 規格書一-1)
  Future<void> _register() async {
    // 1. 檢查必填欄位 (至少帳號、密碼、姓名要填)
    if (_usernameCtrl.text.isEmpty || _passwordCtrl.text.isEmpty || _nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('帳號、密碼與真實姓名為必填欄位'), backgroundColor: Colors.orangeAccent));
      return;
    }

    // 2. 開啟載入動畫 (按鈕變成轉圈圈)
    setState(() => _isLoading = true);

    try {
      // 3. 呼叫 Django 註冊 API
      final response = await http.post(
        Uri.parse('$API_BASE_URL/accounts/api/register/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "user_name": _usernameCtrl.text,
          "password": _passwordCtrl.text,
          "nickname": _nicknameCtrl.text.isEmpty ? _nameCtrl.text : _nicknameCtrl.text,
          "gender": selectedGender,
          "height": double.tryParse(_heightCtrl.text) ?? 0.0,
          "weight": double.tryParse(_weightCtrl.text) ?? 0.0,
          "allergies": _allergiesCtrl.text.isEmpty ? "無" : _allergiesCtrl.text,
          "emergency_contact_phone": _phoneCtrl.text,
        }),
      );

      final data = json.decode(utf8.decode(response.bodyBytes));
      
      // 4. 判斷註冊是否成功
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        _showSuccessDialog(); // 成功就跳出對話框
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('註冊失敗：${data['message']}'), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('連線伺服器失敗，請檢查後端是否已啟動！'), backgroundColor: Colors.redAccent));
    } finally {
      // 5. 無論成功或失敗，都把轉圈圈關掉
      if (mounted) setState(() => _isLoading = false);
    }
  }

void _showSuccessDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),

      // 標題置中
      title: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 28,
          ),
          SizedBox(width: 8),
          Text('註冊成功'),
        ],
      ),

      // 內容文字置中
      content: const Text(
        '您的帳號已成功建立，請使用新帳號登入。',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16),
      ),

      // 按鈕置中
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: 140,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginPage(),
                ),
              );
            },
            child: const Text(
              '前往登入',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  // 🌟 只替換畫面排版 (白色卡片分組，完美綁定你的 8 個 Controller)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(title: const Text('建立帳號', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFFF2F2F7), elevation: 0, iconTheme: const IconThemeData(color: Colors.black87), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildCardGroup('帳號資訊 (必填)', [
              _buildField(_nameCtrl, '真實姓名', Icons.badge_outlined),
              _buildField(_nicknameCtrl, '暱稱', Icons.face),
              _buildField(_usernameCtrl, '設定登入帳號', Icons.person_outline),
              _buildField(_passwordCtrl, '設定密碼', Icons.lock_outline, isPass: true),
            ]),
            const SizedBox(height: 20),
            
            _buildCardGroup('健康指標', [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(
                  children: [
                    const Text('性別', style: TextStyle(color: Colors.black87, fontSize: 16)),
                    const Spacer(),
                    Radio(value: '男', groupValue: selectedGender, activeColor: Colors.teal, onChanged: (val) => setState(() => selectedGender = val!)), const Text('男'),
                    const SizedBox(width: 10),
                    Radio(value: '女', groupValue: selectedGender, activeColor: Colors.teal, onChanged: (val) => setState(() => selectedGender = val!)), const Text('女'),
                  ]
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF2F2F7)),
              Row(
                children: [
                  Expanded(child: _buildField(_heightCtrl, '身高 (cm)', Icons.height, type: TextInputType.number, isBordered: false)),
                  Container(width: 1, height: 40, color: const Color(0xFFF2F2F7)), 
                  Expanded(child: _buildField(_weightCtrl, '體重 (kg)', Icons.monitor_weight_outlined, type: TextInputType.number, isBordered: false)),
                ]
              ),
              const Divider(height: 1, color: Color(0xFFF2F2F7)),
              _buildField(_allergiesCtrl, '藥物過敏史 (無則填無)', Icons.warning_amber_rounded),
            ]),
            const SizedBox(height: 20),

            _buildCardGroup('安全聯繫', [
              _buildField(_phoneCtrl, '緊急聯絡人電話', Icons.contact_phone_outlined, type: TextInputType.phone)
            ]),
            
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 55, 
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _isLoading ? null : _register, // 🌟 呼叫你的 API
                child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('完成註冊', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              )
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCardGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 10, bottom: 8), child: Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold))),
        Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(children: children)),
      ],
    );
  }

  Widget _buildField(TextEditingController ctrl, String hint, IconData icon, {bool isPass = false, TextInputType type = TextInputType.text, bool isBordered = true}) {
    return TextField(
      controller: ctrl, obscureText: isPass, keyboardType: type,
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
        prefixIcon: Icon(icon, color: Colors.grey.shade400),
        border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}// ==========================================
// 🌟 串接真實 API 版：頁面 3 註冊頁面
// ==========================================

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
  // 🌟 [暫時測試] 方案 A：藥袋姓名防呆確認開關
  bool _isConfirmedPatientName = false;
  String _currentUserName = '本人';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) async {
      final cachedName = prefs.getString('nickname') ?? prefs.getString('user_name');
      if (cachedName != null && cachedName.isNotEmpty && mounted) {
        setState(() => _currentUserName = cachedName);
      }
      final userId = prefs.getInt('user_id');
      if (userId != null && userId > 0) {
        try {
          final res = await http.post(
            Uri.parse('$API_BASE_URL/accounts/api/user/profile/'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({"user_id": userId}),
          );
          if (res.statusCode == 200) {
            final data = json.decode(utf8.decode(res.bodyBytes));
            if (data['status'] == 'success' && data['data'] != null) {
              final p = data['data'];
              final name = (p['nickname'] != null && p['nickname'].toString().trim().isNotEmpty)
                  ? p['nickname'].toString().trim()
                  : ((p['user_name'] != null && p['user_name'].toString().trim().isNotEmpty)
                      ? p['user_name'].toString().trim()
                      : '本人');
              if (mounted) {
                setState(() => _currentUserName = name);
              }
            }
          }
        } catch (_) {}
      }
    });
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
    if (!_isConfirmedPatientName) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請先確認藥袋姓名與身分相符！'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) _processImage(image);
  }

  Future<void> _takePicture() async {
    if (!_isConfirmedPatientName) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請先確認藥袋姓名與身分相符！'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
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
    _showLoadingDialog("正在由 AI 分析藥單");
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
              const Text("需要幾秒鐘的時間", style: TextStyle(color: Colors.grey, fontSize: 12)),
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
            Center( // 👈 1. 在最外層加上 Center
  child: ElevatedButton(
    onPressed: () => Navigator.pop(context), 
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white, 
      foregroundColor: Colors.redAccent, 
      side: const BorderSide(color: Colors.redAccent),
    ), 
    child: const Text('資料有誤重拍'),
  ),
),
Center( // 👈 1. 在最外層加上 Center
  child: ElevatedButton(
    onPressed: () {
      Navigator.pop(context); 
      // 💡 修改點 3：把圖片傳給儲存 API
      _checkInteractionsAndSave(drugsData, imageFile); 
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.teal, 
      foregroundColor: Colors.white,
    ),
    child: const Text('確認並檢測'),
  ),
)
          ],
        );
      },
    );
  }

  // 🌟 💡 終極修改：改用 Form-data 傳送，並符合所有欄位名稱
  Future<void> _checkInteractionsAndSave(List<dynamic> drugsData, XFile imageFile) async {
    _showLoadingDialog("正在進行交互作用檢測");
    
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
        // 1. 藥單存檔成功了！
        debugPrint('✅ 存檔成功，準備呼叫安全檢查 API...');
        
        // 2. 緊接著打第二支 API：進行總體安全檢查 (這支才會回傳紅綠燈資料)
        final safetyResponse = await http.post(
          Uri.parse('$API_BASE_URL/medications/api/check_all_safety/'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({"user_id": userId}),
        );

        final safetyData = json.decode(utf8.decode(safetyResponse.bodyBytes));
        bool hasInteraction = false;
        String interactionDetails = "請留意藥物使用安全，若有不適請立即停藥。";

        // 3. 判斷安全檢查的結果
        if (safetyResponse.statusCode == 200 && safetyData['status'] == 'success') {
          List<dynamic> rawList = safetyData['data'] ?? [];

          // 過濾出真的有觸發紅燈危險的藥物
          List<dynamic> actualDangerList = rawList.where((item) {
            return item['is_severe_danger'] == true;
          }).toList();

          if (actualDangerList.isNotEmpty) {
            hasInteraction = true;
            // 抓出有衝突的藥名顯示在彈窗上
            List<String> dangerNames = actualDangerList.map((e) => e['raw_name'].toString()).toList();
            interactionDetails = "衝突藥物包含：\n${dangerNames.join('、')}";
          }
        }

        // 4. 根據真實的安全檢查結果，決定跳紅燈還是綠燈
        _showFinalResultDialog(hasInteraction, interactionDetails);
        
      } else {
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
title: Center(
  child: FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          hasInteraction
              ? Icons.warning_amber_rounded
              : Icons.check_circle,
          color: hasInteraction ? Colors.red : Colors.green,
          size: 28,
        ),
        const SizedBox(width: 8),
        Text(
          hasInteraction ? '發現交互作用風險' : '檢測通過',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ],
    ),
  ),
),
content: Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Text(
      hasInteraction
          ? details
          : '無任何藥物交互作用',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 15, height: 1.5),
    ),
  ],
),        actions: [
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
            
            // 🌟 [暫時測試] 藥袋身分核對確認卡片（核對後自動移除不擋鏡頭）
            if (!_isConfirmedPatientName)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_user_outlined, color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '請先核對藥單身分("$_currentUserName")',
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '拍照前請先確認藥單姓名是否相符',
                      style: TextStyle(color: Color(0xFFB45309), fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('我已確認姓名相符，開始拍照', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmedPatientName = true;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('已確認身分相符，請對準藥單拍照'),
                              backgroundColor: Colors.teal,
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
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
// ==========================================
// 🌟 真實功能+用藥安全紅綠燈版：【我的藥單袋】(原功能對齊規格書四)
// ==========================================
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

  // 🌟 核心 API 串接：取得該用戶的所有藥单紀錄
  Future<void> _fetchPrescriptions() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('user_id');
      if (userId == null || userId <= 0) {
        setState(() => _isLoading = false);
        return;
      }
      final response = await http.get(
        Uri.parse('$API_BASE_URL/medications/api/prescriptions/$userId/'),
        headers: {
          'Accept': 'application/json',
          'X-User-Id': userId.toString(),
        },
      );
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

  // 🌟 核心 API 串接：真實刪除特定藥單與旗下藥品 (對齊規格書四-6)
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
          content: const Text('太棒了！無發現任何交互作用與過敏風險。請安心服藥！', style: TextStyle(fontSize: 15, height: 1.5)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('太好了', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)))],
        )
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 30), SizedBox(width: 10), Expanded(child: Text('跨藥單交互作用', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))]),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: dangerList.length,
            itemBuilder: (context, index) {
              final item = dangerList[index];
              
              // 🌟 核心過濾邏輯：只抓出「真的有跟其他藥物衝突」或「過敏」的警告！
// 🌟 核心過濾邏輯：只抓出「真的有跟其他藥物衝突」或「過敏」的警告！
              List<dynamic> actualConflicts = (item['warnings'] as List).where((w) {
                return w['is_drug_conflict'] == true || w['is_allergy_conflict'] == true;
              }).toList();

              // 🌟 終極去重魔法：解決雙向警告的問題
              // 檢查這顆藥是否有「資料庫原廠」的直接警告 (沒有包含"反向衝突"字眼的)
              bool hasDirectWarning = actualConflicts.any((w) => !w['conflict_target'].toString().contains('反向衝突'));
              
              // 如果有直接警告，就把系統自動加的「反向衝突」隱藏起來，保持畫面乾淨
              if (hasDirectWarning) {
                actualConflicts.removeWhere((w) => w['conflict_target'].toString().contains('反向衝突'));
              }

              // 如果過濾後沒有東西，就不渲染這個卡片
              if (actualConflicts.isEmpty) return const SizedBox.shrink();
              return Card(
                color: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), 
                  side: BorderSide(color: Colors.redAccent.withOpacity(0.5), width: 1)
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🌟 清楚標示這顆藥的名字與「所屬藥單」
                      Text('💊 藥品：${item['raw_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text('🏥 來源藥單：${item['hospital']}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                      
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(height: 1, color: Colors.redAccent),
                      ),
                      
                      // 🌟 只印出真正的交互作用
                      ...actualConflicts.map<Widget>((w) {
                        String targetName = w['conflict_target'].toString().replaceAll('反向衝突：', '').trim();
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8)
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.flash_on, color: Colors.redAccent, size: 18),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                                        children: [
                                          const TextSpan(text: '嚴重警告：不可與 '),
                                          TextSpan(text: '【$targetName】', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                          const TextSpan(text: ' 併用！'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('詳情：${w['warning_desc']}', style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4)),
                            ],
                          ),
                        );
                      })
                    ],
                  ),
                ),
              );
            }
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('我了解了', style: TextStyle(color: Colors.white))
          )
        ],
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
    // 💡 資料搜尋篩選邏輯
    List<Map<String, dynamic>> displayedData = _prescriptions.where((item) {
      return item['hospital_name'].toString().contains(_searchQuery) || item['visit_date'].toString().contains(_searchQuery);
    }).toList();

    // 💡 資料排序篩選邏輯
    if (_currentFilter == '最新加入') {
      displayedData.sort((a, b) => b['visit_date'].compareTo(a['visit_date']));
    } else if (_currentFilter == '最早加入') displayedData.sort((a, b) => a['visit_date'].compareTo(b['visit_date']));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 標題卡片
            Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 32), // 🌟 占位符號用來置中標題
                  // 💡 修正 1：用 Expanded 包住標題，這樣它就不會擠出螢幕
                  const Expanded(
                    child: Text('我的藥單紀錄', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ),
                  IconButton(icon: const Icon(Icons.add_circle, color: Colors.teal, size: 32), onPressed: _showAddPrescriptionDialog)
                ],
              ),
            ),
            const SizedBox(height: 15),

            // 🌟 用藥安全總體檢查按鈕
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

            // 💡 搜尋與篩選行
            Row(
              children: [
                Expanded(
                  flex: 7, // 🌟 占 7 成空間
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
                  flex: 3, // 🌟 占 3 成空間
                  child: PopupMenuButton<String>(
                    onSelected: (String value) { setState(() { _currentFilter = value; }); },
                    itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(value: '全部時間', child: Text('全部時間')),
                      PopupMenuItem<String>(value: '最新加入', child: Text('最新加入')),
                      PopupMenuItem<String>(value: '最早加入', child: Text('最早加入')),
                    ],
                    child: Container(
                      height: 45, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center, 
                        children: [
                          const Icon(Icons.filter_list, size: 18, color: Colors.teal), 
                          const SizedBox(width: 5),
                          // 💡 修正 2：用 Expanded 包住文字，並且加上自動變「...」
                          Expanded(
                            child: Text(
                              _currentFilter == '全部時間' ? '篩選' : _currentFilter.substring(0, 2), 
                              style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold), 
                              overflow: TextOverflow.ellipsis, // 🌟 自動變「...」
                              maxLines: 1 // 🌟 只顯示一行
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // 🌟 藥單列表區域
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
                                // 🌟 進入藥單詳細頁
                                await Navigator.push(context, MaterialPageRoute(builder: (context) => PrescriptionDetailPage(prescription: item)));
                                _fetchPrescriptions(); // 從詳細頁回來後重新整理清單
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.teal.shade100, width: 1.0)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // 💡 修正 3：藥單名字太長擠出螢幕的問題
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item['hospital_name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Text('看診日期: ${item['visit_date']}   |   藥品數量: ${item['drug_count'] ?? 0} 種', style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    // 🌟 加入編輯按鈕與箭頭
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
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
}// ==========================================
// 🌟 真實功能+用藥安全紅綠燈版：【個別藥單詳細頁面】
// ==========================================
// ==========================================
// 🌟 真實功能+用藥安全紅綠燈版：【個別藥單詳細頁面】
// ==========================================
// ==========================================
// 🌟 真實功能+用藥安全紅綠燈版：【個別藥單詳細頁面】
// ==========================================
class PrescriptionDetailPage extends StatefulWidget {
  final Map<String, dynamic> prescription;
  final bool readOnly;
  const PrescriptionDetailPage({
    super.key,
    required this.prescription,
    this.readOnly = false,
  });
  @override
  State<PrescriptionDetailPage> createState() => _PrescriptionDetailPageState();
}

class _PrescriptionDetailPageState extends State<PrescriptionDetailPage> {
  bool _isLoading = true; // 載入狀態
  List<dynamic> _meds = []; // 用來裝後端傳來的藥品明細
  bool _hasSevereDanger = false;
  String? _prescriptionDetailError;

  @override
  void initState() {
    super.initState();
    _fetchPrescriptionDetails(); // 一進畫面就去抓資料
  }

  // 🌟 核心 API 串接：取得特定藥單的詳情 
  Future<void> _fetchPrescriptionDetails() async {
    final pid = widget.prescription['prescription_id'];
    if (pid == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _prescriptionDetailError = '無法載入藥單詳情';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _prescriptionDetailError = null;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getInt('user_id');
      if (currentUserId == null || currentUserId <= 0) {
        _prescriptionDetailError = '登入資訊已失效，請重新登入';
        return;
      }
      debugPrint('👉 準備獲取藥單明細，ID: $pid');
      final response = await http
          .get(
            Uri.parse(
              '$API_BASE_URL/medications/api/prescription_details/$pid/',
            ),
            headers: {
              'Accept': 'application/json',
              'X-User-Id': currentUserId.toString(),
            },
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic>? data;
      try {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        debugPrint('藥單詳情 response 解析失敗: $e');
      }

      final isTransportSuccess =
          response.statusCode >= 200 && response.statusCode < 300;
      if (response.statusCode == 401) {
        _prescriptionDetailError = '登入資訊已失效，請重新登入';
      } else if (response.statusCode == 403) {
        final backendMessage = data?['message'];
        _prescriptionDetailError = backendMessage is String &&
                backendMessage.trim().isNotEmpty
            ? backendMessage.trim()
            : '你沒有權限查看此藥單';
      } else if (isTransportSuccess &&
          data?['status'] == 'success' &&
          data?['data'] is List) {
        if (!mounted) return;
        setState(() {
          _meds = List<dynamic>.from(data!['data']);
          _hasSevereDanger = _meds.any(
            (m) => m is Map && m['is_severe_danger'] == true,
          );
        });
      } else {
        final backendMessage = data?['message'];
        _prescriptionDetailError = backendMessage is String &&
                backendMessage.trim().isNotEmpty
            ? backendMessage.trim()
            : '無法載入藥單詳情';
      }
    } catch (e) {
      debugPrint('連線錯誤: $e');
      _prescriptionDetailError = '無法載入藥單詳情';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 核心 API 串接：手動新增單筆藥品
  Future<void> _addSingleDrug(String rawName, String frequency, String days, String totalAmount) async {
    if (widget.readOnly) return;
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
    if (widget.readOnly) return;
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
    if (widget.readOnly) return;
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
        title: Text(
          widget.readOnly ? '藥單詳細資訊（唯讀）' : '藥單詳細資訊',
          style: const TextStyle(
            color: Colors.teal,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                          // 🌟 修正 1：用 Expanded 包住日期的框框，讓它有彈性
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 5),
                                  // 🌟 修正 2：如果字還是太長，就自動變成「...」
                                  Expanded(
                                    child: Text(widget.prescription['visit_date'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (widget.readOnly) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.visibility_outlined,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    '唯讀',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: _showAddDrugDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),

                      // 🌟 動態顯示藥品清單
                      Expanded(
                        child: _isLoading 
                        ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                        : _prescriptionDetailError != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _prescriptionDetailError!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _fetchPrescriptionDetails,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('重新載入'),
                                  ),
                                ],
                              ),
                            )
                        : _meds.isEmpty
                          ? const Center(child: Text('此藥單目前沒有任何藥品紀錄', style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: _meds.length,
                              itemBuilder: (context, index) {
                                final med = _meds[index];
                                bool isMedSevere = med['is_severe_danger'] == true;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Dismissible(
                                    key: Key(med['id'].toString()),
                                    direction: widget.readOnly
                                        ? DismissDirection.none
                                        : DismissDirection.endToStart,
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
                                        border: Border.all(color: isMedSevere ? Colors.redAccent : Colors.grey.shade200, width: isMedSevere ? 2.0 : 1.0),
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
                                                    if (isMedSevere) ...[
                                                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                                                      const SizedBox(width: 6),
                                                    ],
                                                    Expanded(
                                                      child: Text(
                                                        med['raw_name'] ?? '未知藥品', 
                                                        style: TextStyle(
                                                          fontSize: 18, 
                                                          fontWeight: FontWeight.bold, 
                                                          color: isMedSevere ? Colors.redAccent : Colors.black87
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
                                                  decoration: BoxDecoration(color: isMedSevere ? Colors.red.withOpacity(0.1) : Colors.teal.shade50, shape: BoxShape.circle),
                                                  child: Center(child: Icon(Icons.info_outline, color: isMedSevere ? Colors.redAccent : Colors.teal, size: 18)),
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
                                            })
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
}// ==========================================
// 🌟 吃藥提醒鬧鐘頁面
// ==========================================
// ==========================================
// 🌟 吃藥提醒鬧鐘頁面
// ==========================================
// ==========================================
// 🌟 吃藥提醒鬧鐘頁面
// ==========================================
class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key});
  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  int _reminderViewIndex = 0;
  bool _isTodayLoading = true;
  bool _todayLoadFailed = false;
  bool _todayMissingUser = false;
  String? _todayErrorDetail;
  String? _todayDate;
  int _todaySkippedInvalidCount = 0;
  List<Map<String, dynamic>> _todayReminders = [];
  final Map<int, String> _submittingReminderStatuses = {};

  bool _isPrescriptionsLoading = true;
  bool _prescriptionsLoadFailed = false;
  bool _isDrugsLoading = false;
  List<dynamic> _prescriptions = [];
  
  // 💡 下拉選單改為只綁定藥單 ID，避免 Flutter 報錯
  int? _selectedPrescriptionId; 
  
  List<dynamic> _drugs = [];

  // 🌟 核心資料結構：將藥品依照「頻率」分類群組
  Map<String, List<dynamic>> _groupedDrugs = {};
  final Map<String, List<String>> _groupTimes = {};
  final Map<String, List<String>> _groupTags = {};

  bool _isReminderListLoading = false;
  bool _reminderListLoadFailed = false;
  String? _reminderListErrorMessage;
  int _reminderListSkippedInvalidCount = 0;
  List<Map<String, dynamic>> _savedReminders = [];
  bool _isBatchSaving = false;
  final Set<int> _togglingReminderIds = {};
  final Set<int> _deletingReminderIds = {};

  static const List<String> _standardReminderTags = [
    '早飯後',
    '午飯後',
    '晚飯後',
    '睡前',
  ];

  @override
  void initState() {
    super.initState();
    _fetchTodayReminders();
    _fetchUserPrescriptions(); // 頁面載入時先抓取該用戶的所有藥單
  }

  int? _parsePositiveInt(dynamic value) {
    if (value is int && value > 0) return value;
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  int? _reminderTimeSortKey(dynamic value) {
    if (value is! String) return null;
    final parts = value.trim().split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    final second = parts.length == 3 ? int.tryParse(parts[2]) : 0;
    if (hour == null ||
        minute == null ||
        second == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59 ||
        second < 0 ||
        second > 59) {
      return null;
    }
    return hour * 3600 + minute * 60 + second;
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _formatLocalDate(DateTime value) {
    return '${value.year}-${_twoDigits(value.month)}-${_twoDigits(value.day)}';
  }

  String _formatLocalDateTime(DateTime value) {
    return '${_formatLocalDate(value)} '
        '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}:${_twoDigits(value.second)}';
  }

  String? _formatTodayDate(String? value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return '${parsed.year}/${_twoDigits(parsed.month)}/${_twoDigits(parsed.day)}';
  }

  String _formatReminderTime(String value) {
    final parts = value.split(':');
    return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : value;
  }

  String? _formatTakenAt(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    final normalized = value.trim().replaceFirst('T', ' ');
    final timePart = normalized.contains(' ')
        ? normalized.split(' ').last
        : normalized;
    final parts = timePart.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return '${_twoDigits(hour)}:${_twoDigits(minute)}';
  }

  String? _displayRemainingAmount(dynamic value) {
    if (value is int && value >= 0) return value.toString();
    if (value is num && value >= 0) return value.toString();
    if (value is String && value.trim().isNotEmpty) {
      final parsed = num.tryParse(value.trim());
      if (parsed != null && parsed >= 0) return value.trim();
    }
    return null;
  }

  String? _canonicalReminderTag(dynamic value) {
    if (value is! String) return null;
    switch (value.trim()) {
      case '早飯後':
      case '早餐後':
        return '早飯後';
      case '午飯後':
      case '午餐後':
      case '中午':
        return '午飯後';
      case '晚飯後':
      case '晚餐後':
        return '晚飯後';
      case '睡前':
      case '睡覺前':
        return '睡前';
      default:
        return null;
    }
  }

  String? _normalizeReminderTime(dynamic value) {
    final sortKey = _reminderTimeSortKey(value);
    if (sortKey == null) return null;
    final hour = sortKey ~/ 3600;
    final minute = (sortKey % 3600) ~/ 60;
    final second = sortKey % 60;
    return '${_twoDigits(hour)}:${_twoDigits(minute)}:${_twoDigits(second)}';
  }

  void _showReminderMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.teal,
      ),
    );
  }

  Future<void> _fetchTodayReminders() async {
    if (mounted) {
      setState(() {
        _isTodayLoading = true;
        _todayLoadFailed = false;
        _todayMissingUser = false;
        _todayErrorDetail = null;
      });
    }

    List<Map<String, dynamic>>? loadedReminders;
    String? loadedDate;
    String? errorDetail;
    bool loadFailed = false;
    bool missingUser = false;
    int skippedInvalidCount = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId == null || userId <= 0) {
        loadFailed = true;
        missingUser = true;
      } else {
        final uri = Uri.parse(
          '$API_BASE_URL/medications/api/reminders/today/',
        ).replace(queryParameters: {'user_id': userId.toString()});
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 15));

        Map<String, dynamic>? responseData;
        try {
          final decoded = json.decode(utf8.decode(response.bodyBytes));
          if (decoded is Map) {
            responseData = Map<String, dynamic>.from(decoded);
          }
        } catch (e) {
          debugPrint('今日提醒 response 解析失敗: $e');
        }

        final backendMessage = responseData?['message'];
        if (backendMessage is String && backendMessage.trim().isNotEmpty) {
          errorDetail = backendMessage.trim();
        }

        final rawDate = responseData?['date'];
        final formattedDate =
            rawDate is String ? _formatTodayDate(rawDate) : null;
        final rawItems = responseData?['data'];
        final isTransportSuccess =
            response.statusCode >= 200 && response.statusCode < 300;

        if (isTransportSuccess &&
            responseData?['status'] == 'success' &&
            formattedDate != null &&
            rawItems is List) {
          final validItems = <Map<String, dynamic>>[];
          for (final rawItem in rawItems) {
            if (rawItem is! Map) {
              skippedInvalidCount++;
              continue;
            }

            final item = Map<String, dynamic>.from(rawItem);
            final remindId = _parsePositiveInt(item['remind_id']);
            final sortKey = _reminderTimeSortKey(item['remind_time']);
            final status = item['status'];
            final frequencyTag = item['frequency_tag'];
            final medCh = item['med_ch'];
            final rawName = item['raw_name'];
            final drugName = medCh is String && medCh.trim().isNotEmpty
                ? medCh.trim()
                : rawName is String && rawName.trim().isNotEmpty
                    ? rawName.trim()
                    : null;

            if (remindId == null ||
                sortKey == null ||
                status is! String ||
                status.trim().isEmpty ||
                frequencyTag is! String ||
                frequencyTag.trim().isEmpty ||
                drugName == null) {
              skippedInvalidCount++;
              continue;
            }

            item['remind_id'] = remindId;
            item['_sort_key'] = sortKey;
            item['_display_drug_name'] = drugName;
            validItems.add(item);
          }

          if (rawItems.isNotEmpty && validItems.isEmpty) {
            loadFailed = true;
          } else {
            validItems.sort(
              (a, b) => (a['_sort_key'] as int).compareTo(
                b['_sort_key'] as int,
              ),
            );
            loadedReminders = validItems;
            loadedDate = formattedDate;
          }
        } else {
          loadFailed = true;
        }
      }
    } catch (e) {
      debugPrint('今日提醒載入失敗: $e');
      loadFailed = true;
    }

    if (!mounted) return;
    setState(() {
      if (loadedReminders != null && loadedDate != null) {
        _todayReminders = loadedReminders!;
        _todayDate = loadedDate;
      }
      _todaySkippedInvalidCount = skippedInvalidCount;
      _todayLoadFailed = loadFailed;
      _todayMissingUser = missingUser;
      _todayErrorDetail = loadFailed ? errorDetail : null;
      _isTodayLoading = false;
    });
  }

  // 🌟 1. 獲取使用者藥單清單 (用來塞下拉選單)
  Future<void> _fetchUserPrescriptions() async {
    if (mounted) {
      setState(() {
        _isPrescriptionsLoading = true;
        _prescriptionsLoadFailed = false;
      });
    }

    List<dynamic>? loadedPrescriptions;
    bool loadFailed = false;

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('user_id');
      if (userId == null || userId <= 0) {
        loadFailed = true;
      } else {
        final response = await http
            .get(
              Uri.parse(
                '$API_BASE_URL/medications/api/prescriptions/$userId/',
              ),
              headers: {
                'Accept': 'application/json',
                'X-User-Id': userId.toString(),
              },
            )
            .timeout(const Duration(seconds: 15));
        final data = json.decode(utf8.decode(response.bodyBytes));

        if (response.statusCode == 200 &&
            data is Map &&
            data['status'] == 'success' &&
            data['data'] is List) {
          loadedPrescriptions = List<dynamic>.from(data['data']);
        } else {
          loadFailed = true;
        }
      }
    } catch (e) {
      debugPrint('鬧鐘頁面獲取藥單失敗: $e');
      loadFailed = true;
    }

    if (!mounted) return;
    setState(() {
      if (loadedPrescriptions != null) {
        _prescriptions = loadedPrescriptions!;
      }
      _prescriptionsLoadFailed = loadFailed;
      _isPrescriptionsLoading = false;
    });
  }

  Widget _buildPrescriptionsLoadError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, color: Colors.grey.shade500, size: 48),
          const SizedBox(height: 14),
          const Text(
            '無法載入提醒資料，請稍後再試',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _fetchUserPrescriptions,
            icon: const Icon(Icons.refresh),
            label: const Text('重新載入'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.teal,
              side: const BorderSide(color: Colors.teal),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPrescriptionsState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, color: Colors.grey, size: 48),
          SizedBox(height: 14),
          Text(
            '尚無可設定提醒的藥單',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  bool _isDuplicateTakingRecordMessage(String? message) {
    if (message == null) return false;
    return message.contains('重複打卡') ||
        (message.contains('鬧鐘時段') && message.contains('記錄為'));
  }

  Future<void> _recordTakingStatus(
    Map<String, dynamic> reminder,
    String status, {
    bool force = false,
    DateTime? recordedAt,
  }) async {
    final remindId = _parsePositiveInt(reminder['remind_id']);
    if (remindId == null || _submittingReminderStatuses.containsKey(remindId)) {
      return;
    }

    final requestTime = recordedAt ?? DateTime.now();
    const fallbackError = '操作失敗，請稍後再試';
    String errorMessage = fallbackError;
    String? backendMessage;
    bool succeeded = false;
    bool shouldConfirmOverwrite = false;

    setState(() => _submittingReminderStatuses[remindId] = status);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId == null) {
        errorMessage = '登入資訊已失效，請重新登入。';
      } else {
        final response = await http
            .post(
              Uri.parse('$API_BASE_URL/medications/api/history/record/'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'user_id': userId,
                'remind_id': remindId,
                'status': status,
                'record_date': _formatLocalDate(requestTime),
                'actual_taken_at': _formatLocalDateTime(requestTime),
                'force': force,
              }),
            )
            .timeout(const Duration(seconds: 15));

        Map<String, dynamic>? responseData;
        try {
          final decoded = json.decode(utf8.decode(response.bodyBytes));
          if (decoded is Map) {
            responseData = Map<String, dynamic>.from(decoded);
          }
        } catch (e) {
          debugPrint('服藥打卡 response 解析失敗: $e');
        }

        final message = responseData?['message'];
        if (message is String && message.trim().isNotEmpty) {
          backendMessage = message.trim();
        }

        final isTransportSuccess =
            response.statusCode >= 200 && response.statusCode < 300;
        if (isTransportSuccess && responseData?['status'] == 'success') {
          succeeded = true;
        } else if (response.statusCode == 400 &&
            !force &&
            _isDuplicateTakingRecordMessage(backendMessage)) {
          shouldConfirmOverwrite = true;
        } else if (backendMessage != null) {
          errorMessage = backendMessage!;
        }
      }
    } catch (e) {
      debugPrint('服藥打卡失敗: $e');
    } finally {
      if (mounted) {
        setState(() => _submittingReminderStatuses.remove(remindId));
      }
    }

    if (!mounted) return;

    if (succeeded) {
      await _fetchTodayReminders();
      if (!mounted) return;
      if (backendMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(backendMessage!), backgroundColor: Colors.teal),
        );
      }
      return;
    }

    if (shouldConfirmOverwrite) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '確認重新覆蓋',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text('今日該時段已記錄過，是否重新覆蓋？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('確定', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        await _recordTakingStatus(
          reminder,
          status,
          force: true,
          recordedAt: requestTime,
        );
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage), backgroundColor: Colors.redAccent),
    );
  }

  Widget _buildTodayLoadError() {
    final primaryMessage = _todayMissingUser
        ? '登入資訊已失效，請重新登入。'
        : '無法載入今日服藥日程，請稍後再試';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy, color: Colors.grey.shade500, size: 50),
            const SizedBox(height: 14),
            Text(
              primaryMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            if (!_todayMissingUser && _todayErrorDetail != null) ...[
              const SizedBox(height: 8),
              Text(
                _todayErrorDetail!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _fetchTodayReminders,
              icon: const Icon(Icons.refresh),
              label: const Text('重新載入'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal,
                side: const BorderSide(color: Colors.teal),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayReminderStatus(Map<String, dynamic> reminder) {
    final status = reminder['status'].toString().trim();
    final remindId = reminder['remind_id'] as int;
    final submittingStatus = _submittingReminderStatuses[remindId];

    if (status == '已吃') {
      final takenAt = _formatTakenAt(reminder['taken_at']);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          takenAt == null ? '✓ 已吃' : '✓ 已吃 $takenAt',
          style: const TextStyle(
            color: Colors.teal,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (status == '略過') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '已略過',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (status != '未吃') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: const Text(
          '狀態資料異常',
          style: TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final isSubmitting = submittingStatus != null;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: isSubmitting
                ? null
                : () => _recordTakingStatus(reminder, '已吃'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: submittingStatus == '已吃'
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('已吃'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: isSubmitting
                ? null
                : () => _recordTakingStatus(reminder, '略過'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: submittingStatus == '略過'
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey,
                    ),
                  )
                : const Text('略過'),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayReminderCard(Map<String, dynamic> reminder) {
    final hospitalName = reminder['hospital_name'];
    final remainingAmount =
        _displayRemainingAmount(reminder['remaining_amount']);
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _formatReminderTime(reminder['remind_time'] as String),
                    style: const TextStyle(
                      color: Colors.teal,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder['frequency_tag'].toString(),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reminder['_display_drug_name'].toString(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hospitalName is String && hospitalName.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                hospitalName.trim(),
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            if (remainingAmount != null) ...[
              const SizedBox(height: 6),
              Text(
                '剩餘：$remainingAmount 顆',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            _buildTodayReminderStatus(reminder),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayView() {
    if (_isTodayLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.teal),
      );
    }
    if (_todayLoadFailed) return _buildTodayLoadError();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '今天',
                style: TextStyle(
                  color: Colors.teal,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _todayDate ?? '',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),
            ],
          ),
        ),
        if (_todaySkippedInvalidCount > 0)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '有 $_todaySkippedInvalidCount 筆提醒資料格式錯誤，已略過顯示。',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
            ),
          ),
        Expanded(
          child: _todayReminders.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_available_outlined,
                        color: Colors.grey,
                        size: 50,
                      ),
                      SizedBox(height: 14),
                      Text(
                        '今天沒有需要服用的藥物',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 60),
                  itemCount: _todayReminders.length,
                  itemBuilder: (context, index) {
                    return _buildTodayReminderCard(_todayReminders[index]);
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _loadPrescriptionReminderSettings(int prescriptionId) async {
    if (!mounted) return;
    setState(() {
      _isDrugsLoading = true;
      _isReminderListLoading = true;
      _reminderListLoadFailed = false;
      _reminderListErrorMessage = null;
      _reminderListSkippedInvalidCount = 0;
      _drugs = [];
      _groupedDrugs = {};
      _groupTags.clear();
      _groupTimes.clear();
      _savedReminders = [];
    });

    await Future.wait([
      _fetchDrugsForPrescription(prescriptionId),
      _fetchRemindersForPrescription(prescriptionId),
    ]);

    if (!mounted || _selectedPrescriptionId != prescriptionId) return;
    setState(_applySavedRemindersToEditor);
  }

  Future<void> _fetchRemindersForPrescription(int prescriptionId) async {
    if (mounted && _selectedPrescriptionId == prescriptionId) {
      setState(() {
        _isReminderListLoading = true;
        _reminderListLoadFailed = false;
        _reminderListErrorMessage = null;
      });
    }

    List<Map<String, dynamic>>? loadedReminders;
    String? errorMessage;
    int skippedInvalidCount = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId == null) {
        errorMessage = '登入資訊已失效，請重新登入。';
      } else {
        final uri = Uri.parse(
          '$API_BASE_URL/medications/api/reminders/list/',
        ).replace(
          queryParameters: {
            'prescription_id': prescriptionId.toString(),
            'user_id': userId.toString(),
            'active_only': 'false',
          },
        );
        final response = await http
            .get(uri, headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 15));

        Map<String, dynamic>? responseData;
        try {
          final decoded = json.decode(utf8.decode(response.bodyBytes));
          if (decoded is Map) {
            responseData = Map<String, dynamic>.from(decoded);
          }
        } catch (e) {
          debugPrint('提醒列表 response 解析失敗: $e');
        }

        final backendMessage = responseData?['message'];
        final isTransportSuccess =
            response.statusCode >= 200 && response.statusCode < 300;
        final rawItems = responseData?['data'];

        if (isTransportSuccess &&
            responseData?['status'] == 'success' &&
            rawItems is List) {
          final validItems = <Map<String, dynamic>>[];
          for (final rawItem in rawItems) {
            if (rawItem is! Map) {
              skippedInvalidCount++;
              continue;
            }

            final item = Map<String, dynamic>.from(rawItem);
            final remindId = _parsePositiveInt(item['remind_id']);
            final prescriptionDrugId =
                _parsePositiveInt(item['prescription_drug_id']);
            final frequencyTag = item['frequency_tag'];
            final normalizedTime = _normalizeReminderTime(item['remind_time']);
            final isActive = item['is_active'];
            if (remindId == null ||
                prescriptionDrugId == null ||
                frequencyTag is! String ||
                frequencyTag.trim().isEmpty ||
                normalizedTime == null ||
                isActive is! bool) {
              skippedInvalidCount++;
              continue;
            }

            item['remind_id'] = remindId;
            item['prescription_drug_id'] = prescriptionDrugId;
            item['frequency_tag'] = frequencyTag.trim();
            item['remind_time'] = normalizedTime;
            validItems.add(item);
          }
          if (rawItems.isNotEmpty && validItems.isEmpty) {
            errorMessage = '提醒列表資料格式錯誤，請稍後再試。';
          } else {
            validItems.sort(
              (a, b) => (_reminderTimeSortKey(a['remind_time']) ?? 0)
                  .compareTo(_reminderTimeSortKey(b['remind_time']) ?? 0),
            );
            loadedReminders = validItems;
          }
        } else if (backendMessage is String &&
            backendMessage.trim().isNotEmpty) {
          errorMessage = backendMessage.trim();
        } else {
          errorMessage = '無法載入已設定提醒，請稍後再試。';
        }
      }
    } catch (e) {
      debugPrint('載入已設定提醒失敗: $e');
      errorMessage = '無法載入已設定提醒，請稍後再試。';
    }

    if (!mounted || _selectedPrescriptionId != prescriptionId) return;
    setState(() {
      if (loadedReminders != null) {
        _savedReminders = loadedReminders!;
      }
      _reminderListSkippedInvalidCount = skippedInvalidCount;
      _reminderListLoadFailed = errorMessage != null;
      _reminderListErrorMessage = errorMessage;
      _isReminderListLoading = false;
      if (loadedReminders != null) {
        _applySavedRemindersToEditor();
      }
    });
  }

  void _applySavedRemindersToEditor() {
    if (_groupedDrugs.isEmpty || _savedReminders.isEmpty) return;

    _groupedDrugs.forEach((frequency, drugList) {
      final drugIds = drugList
          .map((drug) => _parsePositiveInt(
                drug['id'] ?? drug['prescription_drug_id'],
              ))
          .whereType<int>()
          .toSet();
      final loadedTagTimes = <String, String>{};

      for (final reminder in _savedReminders) {
        if (!drugIds.contains(reminder['prescription_drug_id'])) continue;
        final canonicalTag = _canonicalReminderTag(reminder['frequency_tag']);
        final normalizedTime =
            _normalizeReminderTime(reminder['remind_time']);
        if (canonicalTag == null || normalizedTime == null) continue;
        loadedTagTimes.putIfAbsent(
          canonicalTag,
          () => _formatReminderTime(normalizedTime),
        );
      }

      if (loadedTagTimes.isEmpty) return;
      final sortedTags = loadedTagTimes.keys.toList()
        ..sort(
          (a, b) => _standardReminderTags
              .indexOf(a)
              .compareTo(_standardReminderTags.indexOf(b)),
        );
      _groupTags[frequency] = sortedTags;
      _groupTimes[frequency] = [
        for (final tag in sortedTags) loadedTagTimes[tag]!,
      ];
    });
  }

  bool? _savedReminderActiveState(int prescriptionDrugId, String tag) {
    for (final reminder in _savedReminders) {
      if (reminder['prescription_drug_id'] == prescriptionDrugId &&
          _canonicalReminderTag(reminder['frequency_tag']) == tag &&
          reminder['is_active'] is bool) {
        return reminder['is_active'] as bool;
      }
    }
    return null;
  }

  // 🌟 2. 當選取某張藥單時，獲取其底下的所有藥品明細
  Future<void> _fetchDrugsForPrescription(int prescriptionId) async {
    List<dynamic>? loadedDrugs;
    String? loadError;

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getInt('user_id');
      if (currentUserId == null || currentUserId <= 0) {
        loadError = '登入資訊已失效，請重新登入';
      } else {
        final response = await http
            .get(
              Uri.parse(
                '$API_BASE_URL/medications/api/prescription_details/$prescriptionId/',
              ),
              headers: {
                'Accept': 'application/json',
                'X-User-Id': currentUserId.toString(),
              },
            )
            .timeout(const Duration(seconds: 15));
        Map<String, dynamic>? data;
        try {
          final decoded = json.decode(utf8.decode(response.bodyBytes));
          if (decoded is Map) data = Map<String, dynamic>.from(decoded);
        } catch (e) {
          debugPrint('提醒藥單詳情 response 解析失敗: $e');
        }

        final backendMessage = data?['message'];
        if (response.statusCode == 401) {
          loadError = '登入資訊已失效，請重新登入';
        } else if (response.statusCode == 403) {
          loadError = backendMessage is String &&
                  backendMessage.trim().isNotEmpty
              ? backendMessage.trim()
              : '你沒有權限查看此藥單';
        } else if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            data?['status'] == 'success' &&
            data?['data'] is List) {
          loadedDrugs = List<dynamic>.from(data!['data']);
        } else {
          loadError = backendMessage is String &&
                  backendMessage.trim().isNotEmpty
              ? backendMessage.trim()
              : '無法載入藥單詳情';
        }
      }
    } catch (e) {
      debugPrint('獲取藥品明細失敗: $e');
      loadError = '無法載入藥單詳情';
    }

    if (!mounted || _selectedPrescriptionId != prescriptionId) return;
    setState(() {
      _drugs = loadedDrugs ?? [];
      _groupDrugsByFrequency();
      _applySavedRemindersToEditor();
      _isDrugsLoading = false;
    });
    if (loadError != null) {
      _showReminderMessage(loadError, isError: true);
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
        tags = ['早飯後', '午飯後', '晚飯後'];
        times = ['08:30', '12:30', '18:30'];
      } else if (freq.contains('二') || freq.contains('2') || freq.toLowerCase().contains('bid')) {
        tags = ['早飯後', '晚飯後'];
        times = ['08:30', '18:30'];
      } else if (freq.contains('睡前') || freq.toLowerCase().contains('hs')) {
        tags = ['睡前'];
        times = ['21:30'];
      } else {
        tags = ['早飯後'];
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

  Future<void> _toggleReminder(
    Map<String, dynamic> reminder,
    bool requestedValue,
  ) async {
    final remindId = _parsePositiveInt(reminder['remind_id']);
    final originalValue = reminder['is_active'];
    if (remindId == null ||
        originalValue is! bool ||
        _togglingReminderIds.contains(remindId) ||
        _deletingReminderIds.contains(remindId)) {
      return;
    }

    String errorMessage = '提醒開關更新失敗，請稍後再試。';
    bool succeeded = false;
    bool confirmedValue = originalValue;

    setState(() {
      _togglingReminderIds.add(remindId);
      reminder['is_active'] = requestedValue;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId == null) {
        errorMessage = '登入資訊已失效，請重新登入。';
      } else {
        final response = await http
            .post(
              Uri.parse(
                '$API_BASE_URL/medications/api/reminders/$remindId/toggle/',
              ),
              headers: const {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
              body: json.encode({
                'user_id': userId,
                'is_active': requestedValue,
              }),
            )
            .timeout(const Duration(seconds: 15));

        Map<String, dynamic>? responseData;
        try {
          final decoded = json.decode(utf8.decode(response.bodyBytes));
          if (decoded is Map) {
            responseData = Map<String, dynamic>.from(decoded);
          }
        } catch (e) {
          debugPrint('提醒開關 response 解析失敗: $e');
        }

        final backendMessage = responseData?['message'];
        final responseValue = responseData?['data'] is Map
            ? responseData!['data']['is_active']
            : null;
        final isTransportSuccess =
            response.statusCode >= 200 && response.statusCode < 300;
        if (isTransportSuccess &&
            responseData?['status'] == 'success' &&
            responseValue is bool) {
          succeeded = true;
          confirmedValue = responseValue;
        } else if (backendMessage is String &&
            backendMessage.trim().isNotEmpty) {
          errorMessage = backendMessage.trim();
        }
      }
    } catch (e) {
      debugPrint('提醒開關更新失敗: $e');
    } finally {
      if (mounted) {
        setState(() {
          reminder['is_active'] = succeeded ? confirmedValue : originalValue;
          _togglingReminderIds.remove(remindId);
        });
      }
    }

    if (!succeeded) {
      _showReminderMessage(errorMessage, isError: true);
    }
  }

  Future<void> _confirmDeleteReminder(Map<String, dynamic> reminder) async {
    final remindId = _parsePositiveInt(reminder['remind_id']);
    if (remindId == null ||
        _deletingReminderIds.contains(remindId) ||
        _togglingReminderIds.contains(remindId)) {
      return;
    }

    final rawTag = reminder['frequency_tag']?.toString() ?? '';
    final frequencyTag = _canonicalReminderTag(rawTag) ?? rawTag;
    final remindTime = _normalizeReminderTime(reminder['remind_time']);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          '確定要刪除此提醒嗎？',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '$frequencyTag  ${remindTime == null ? '' : _formatReminderTime(remindTime)}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('刪除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteReminder(reminder);
    }
  }

  Future<void> _deleteReminder(Map<String, dynamic> reminder) async {
    final remindId = _parsePositiveInt(reminder['remind_id']);
    final prescriptionId = _selectedPrescriptionId;
    if (remindId == null ||
        prescriptionId == null ||
        _deletingReminderIds.contains(remindId)) {
      return;
    }

    String errorMessage = '提醒刪除失敗，請稍後再試。';
    String? successMessage;
    bool succeeded = false;
    setState(() => _deletingReminderIds.add(remindId));

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId == null) {
        errorMessage = '登入資訊已失效，請重新登入。';
      } else {
        final response = await http.delete(
          Uri.parse(
            '$API_BASE_URL/medications/api/reminders/$remindId/delete/',
          ),
          headers: {
            'X-User-Id': userId.toString(),
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));

        Map<String, dynamic>? responseData;
        try {
          final decoded = json.decode(utf8.decode(response.bodyBytes));
          if (decoded is Map) {
            responseData = Map<String, dynamic>.from(decoded);
          }
        } catch (e) {
          debugPrint('刪除提醒 response 解析失敗: $e');
        }

        final backendMessage = responseData?['message'];
        final isTransportSuccess =
            response.statusCode >= 200 && response.statusCode < 300;
        if (isTransportSuccess && responseData?['status'] == 'success') {
          succeeded = true;
          if (backendMessage is String && backendMessage.trim().isNotEmpty) {
            successMessage = backendMessage.trim();
          }
        } else if (backendMessage is String &&
            backendMessage.trim().isNotEmpty) {
          errorMessage = backendMessage.trim();
        }
      }

      if (succeeded &&
          mounted &&
          _selectedPrescriptionId == prescriptionId) {
        if (successMessage != null) {
          _showReminderMessage(successMessage!);
        }
        await _fetchRemindersForPrescription(prescriptionId);
      }
    } catch (e) {
      debugPrint('刪除提醒失敗: $e');
    } finally {
      if (mounted) {
        setState(() => _deletingReminderIds.remove(remindId));
      }
    }

    if (!succeeded) {
      _showReminderMessage(errorMessage, isError: true);
    }
  }

  // 🌟 5. 將分群結構轉回以「藥品」為單位的 API Payload 並上傳
  Future<void> _saveReminders() async {
    if (_isBatchSaving) return;
    setState(() => _isBatchSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId == null) {
        _showReminderMessage(
          '登入資訊已失效，請重新登入。',
          isError: true,
        );
        return;
      }

      final prescriptionId = _parsePositiveInt(_selectedPrescriptionId);
      if (prescriptionId == null || _drugs.isEmpty) {
        _showReminderMessage('提醒設定資料不足，請重新選擇藥單。', isError: true);
        return;
      }
      if (_isReminderListLoading ||
          _reminderListLoadFailed ||
          _reminderListSkippedInvalidCount > 0) {
        _showReminderMessage(
          '請先成功載入完整的已設定提醒後再儲存。',
          isError: true,
        );
        return;
      }

      final drugsPayload = <Map<String, dynamic>>[];
      bool hasInvalidData = false;
      int reminderCount = 0;

      for (final entry in _groupedDrugs.entries) {
        final tags = _groupTags[entry.key] ?? const <String>[];
        final times = _groupTimes[entry.key] ?? const <String>[];
        if (tags.isEmpty || tags.length != times.length) {
          hasInvalidData = true;
          break;
        }

        for (final drug in entry.value) {
          final prescriptionDrugId = _parsePositiveInt(
            drug['id'] ?? drug['prescription_drug_id'],
          );
          if (prescriptionDrugId == null) {
            hasInvalidData = true;
            break;
          }

          final remindersPayload = <Map<String, dynamic>>[];
          for (int index = 0; index < tags.length; index++) {
            final tag = tags[index];
            final normalizedTime = _normalizeReminderTime(times[index]);
            if (!_standardReminderTags.contains(tag) ||
                normalizedTime == null) {
              hasInvalidData = true;
              break;
            }
            remindersPayload.add({
              'frequency_tag': tag,
              'remind_time': normalizedTime,
              'is_active':
                  _savedReminderActiveState(prescriptionDrugId, tag) ?? true,
            });
          }
          if (hasInvalidData || remindersPayload.isEmpty) {
            hasInvalidData = true;
            break;
          }

          reminderCount += remindersPayload.length;
          drugsPayload.add({
            'prescription_drug_id': prescriptionDrugId,
            'reminders': remindersPayload,
          });
        }
        if (hasInvalidData) break;
      }

      if (hasInvalidData || drugsPayload.isEmpty || reminderCount == 0) {
        _showReminderMessage(
          '提醒設定資料不完整，請確認藥品、時段與時間。',
          isError: true,
        );
        return;
      }

      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/medications/api/reminders/set/'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'user_id': userId,
              'prescription_id': prescriptionId,
              'drugs': drugsPayload,
            }),
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic>? responseData;
      try {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        if (decoded is Map) {
          responseData = Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        debugPrint('儲存提醒 response 解析失敗: $e');
      }

      final backendMessage = responseData?['message'];
      final isTransportSuccess =
          response.statusCode >= 200 && response.statusCode < 300;
if (isTransportSuccess && responseData?['status'] == 'success') {
  _showReminderMessage(
    backendMessage is String && backendMessage.trim().isNotEmpty
        ? backendMessage.trim()
        : '提醒設定已儲存。',
  );

  // 重新整理今日服藥日程
  await _fetchTodayReminders();

  if (!mounted) return;

  // 重新整理目前藥單的提醒設定
  if (_selectedPrescriptionId == prescriptionId) {
    await _fetchRemindersForPrescription(prescriptionId);
  }
} else {
        _showReminderMessage(
          backendMessage is String && backendMessage.trim().isNotEmpty
              ? backendMessage.trim()
              : '提醒設定儲存失敗，請稍後再試。',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('儲存提醒失敗: $e');
      _showReminderMessage('提醒設定儲存失敗，請稍後再試。', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isBatchSaving = false);
      }
    }
  }

  Widget _buildSavedReminderRow(Map<String, dynamic> reminder) {
    final remindId = reminder['remind_id'] as int;
    final isActive = reminder['is_active'] as bool;
    final isToggling = _togglingReminderIds.contains(remindId);
    final isDeleting = _deletingReminderIds.contains(remindId);
    final rawTag = reminder['frequency_tag'].toString();
    final frequencyTag = _canonicalReminderTag(rawTag) ?? rawTag;
    final remindTime = _formatReminderTime(reminder['remind_time'].toString());
    final rawName = reminder['raw_name'];

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rawName is String && rawName.trim().isNotEmpty) ...[
                  Text(
                    rawName.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  '$frequencyTag  $remindTime',
                  style: const TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (isToggling)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.teal,
                ),
              ),
            ),
          Switch.adaptive(
            value: isActive,
            activeColor: Colors.teal,
            onChanged: isToggling || isDeleting
                ? null
                : (value) => _toggleReminder(reminder, value),
          ),
          if (isDeleting)
            const SizedBox(
              width: 40,
              height: 40,
              child: Padding(
                padding: EdgeInsets.all(11),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.redAccent,
                ),
              ),
            )
          else
            IconButton(
              tooltip: '刪除提醒',
              onPressed: isToggling
                  ? null
                  : () => _confirmDeleteReminder(reminder),
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
        ],
      ),
    );
  }

  Widget _buildReminderListSection(int prescriptionId) {
    if (_isReminderListLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: CircularProgressIndicator(color: Colors.teal),
          ),
        ),
      );
    }

    if (_reminderListLoadFailed) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                _reminderListErrorMessage ??
                    '無法載入已設定提醒，請稍後再試。',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    _fetchRemindersForPrescription(prescriptionId),
                icon: const Icon(Icons.refresh),
                label: const Text('重新載入'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: const BorderSide(color: Colors.teal),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.notifications_active_outlined, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  '已設定提醒',
                  style: TextStyle(
                    color: Colors.teal,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (_reminderListSkippedInvalidCount > 0) ...[
              const SizedBox(height: 10),
              Text(
                '有 $_reminderListSkippedInvalidCount 筆提醒資料格式錯誤，已略過顯示。',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontSize: 13,
                ),
              ),
            ],
            if (_savedReminders.isEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                '此藥單尚未設定提醒，可使用下方時段建立。',
                style: TextStyle(color: Colors.grey),
              ),
            ] else
              ..._savedReminders.map(_buildSavedReminderRow),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderSettingsView() {
    return _isPrescriptionsLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.teal))
              : _prescriptionsLoadFailed
                  ? _buildPrescriptionsLoadError()
                  : _prescriptions.isEmpty
                      ? _buildNoPrescriptionsState()
                      : Column(
                  children: [
                    // 💡 下拉選單
                    DropdownButtonFormField<int>(
                      isExpanded: true, 
                      decoration: InputDecoration(
                        labelText: '選擇要設定的藥單紀錄',
                        filled: true, fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      initialValue: _selectedPrescriptionId,
                      items: _prescriptions.map<DropdownMenuItem<int>>((p) {
                        return DropdownMenuItem<int>(
                          value: p['prescription_id'] as int,
                          child: Text(
                            '${p['hospital_name']} (${p['visit_date']})', 
                            overflow: TextOverflow.ellipsis, 
                            maxLines: 1
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPrescriptionId = val;
                          if (val == null) {
                            _drugs = [];
                            _groupedDrugs = {};
                            _groupTags.clear();
                            _groupTimes.clear();
                            _savedReminders = [];
                          }
                        });
                        if (val != null) {
                          _loadPrescriptionReminderSettings(val);
                        }
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
                                      children: [
                                        _buildReminderListSection(
                                          _selectedPrescriptionId!,
                                        ),
                                        ..._groupedDrugs.keys.map((freq) {
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
                                                    Expanded(
                                                      child: Text('服用頻率：$freq', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal), maxLines: 2, overflow: TextOverflow.ellipsis),
                                                    ),
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
                                      }),
                                      ],
                                    ),
                    ),
                    
                    if (_selectedPrescriptionId != null && _groupedDrugs.isNotEmpty)
                      Padding(
                        // 🌟 修正：在這裡加上 bottom: 50！把它往上頂，避開底部的掃描按鈕
                        padding: const EdgeInsets.only(top: 10, bottom: 50),
                        child: SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal, 
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isBatchSaving ||
                                    _isReminderListLoading ||
                                    _reminderListLoadFailed ||
                                    _reminderListSkippedInvalidCount > 0
                                ? null
                                : _saveReminders,
                            child: _isBatchSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('儲存提醒鬧鐘設定', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                          ),
                        ),
                      )
                  ],
                );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '吃藥提醒鬧鐘 ⏰',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(
                  height: 58,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              if (_reminderViewIndex != 0) {
                                setState(() => _reminderViewIndex = 0);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _reminderViewIndex == 0
                                    ? Colors.teal
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '今日服藥日程',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _reminderViewIndex == 0
                                      ? Colors.white
                                      : Colors.teal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              if (_reminderViewIndex != 1) {
                                setState(() => _reminderViewIndex = 1);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _reminderViewIndex == 1
                                    ? Colors.teal
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '藥單鬧鐘設定',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _reminderViewIndex == 1
                                      ? Colors.white
                                      : Colors.teal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _reminderViewIndex == 0
                    ? _buildTodayView()
                    : _buildReminderSettingsView(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _HealthBankConsentDialog extends StatefulWidget {
  const _HealthBankConsentDialog();

  @override
  State<_HealthBankConsentDialog> createState() =>
      _HealthBankConsentDialogState();
}

class _HealthBankConsentDialogState extends State<_HealthBankConsentDialog> {
  static const int _countdownStart = 5;
  int _secondsRemaining = _countdownStart;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsRemaining = 0);
        return;
      }
      if (mounted) setState(() => _secondsRemaining--);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const headerColor = Color(0xFFC62828);
    final canConfirm = _secondsRemaining == 0;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.84;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  color: headerColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  child: const Text(
                    '下載健康存摺資料供他方APP使用聲明',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.35,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            style: TextStyle(
                              color: Color(0xFF333333),
                              fontSize: 15,
                              height: 1.65,
                            ),
                            children: [
                              TextSpan(
                                text: '「健康存摺」',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text:
                                    '存有您的健康資料，您可以經身分認證後下載個人至少三年的就醫及健康資料。',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '健康資料包含：',
                          style: TextStyle(
                            color: Color(0xFF222222),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '門診資料（西醫、中醫、牙醫）、住院資料、過敏藥物資料、檢驗（查）結果資料、影像或病理檢驗（查）報告摘要資料。',
                          style: TextStyle(
                            color: Color(0xFF333333),
                            fontSize: 15,
                            height: 1.65,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '資料包含有個人隱私，下載後如欲提供他方使用，應請自行評估風險與責任。',
                          style: TextStyle(
                            color: Color(0xFF333333),
                            fontSize: 15,
                            height: 1.65,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text.rich(
                          TextSpan(
                            style: TextStyle(
                              color: Color(0xFF333333),
                              fontSize: 15,
                              height: 1.65,
                            ),
                            children: [
                              TextSpan(
                                text: '提醒您：',
                                style: TextStyle(
                                  color: headerColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text:
                                    '資料提供給此行動應用程式（APP）時，請充分了解自身權益，並留意是否只提供部分資料、使用期間，以及日後可要求刪除資料的權利。',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                  ),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '倒數計時 $_secondsRemaining 秒',
                          style: TextStyle(
                            color: canConfirm
                                ? Colors.grey.shade600
                                : headerColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                                side: BorderSide(color: Colors.grey.shade400),
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                '不產製',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: canConfirm
                                  ? () => Navigator.of(context).pop(true)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: headerColor,
                                disabledBackgroundColor:
                                    headerColor.withOpacity(0.35),
                                foregroundColor: Colors.white,
                                disabledForegroundColor: Colors.white70,
                                elevation: canConfirm ? 2 : 0,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                '是，我了解',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FamilyGroupPage extends StatefulWidget {
  const FamilyGroupPage({super.key});

  @override
  State<FamilyGroupPage> createState() => _FamilyGroupPageState();
}

class _FamilyGroupPageState extends State<FamilyGroupPage> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _inviteCodeController = TextEditingController();

  int? _currentUserId;
  int? _currentGroupId;
  String? _currentGroupName;
  String? _currentGroupRole;
  String? _currentInviteCode;
  List<Map<String, dynamic>> _groupMembers = [];
  // 🌟 [暫時測試] 群組服藥動態與逾期統計
  List<Map<String, dynamic>> _groupActivities = [];
  int _overdueCount = 0;
  bool _isRestoringGroup = true;
  bool _isCreatingGroup = false;
  bool _isJoiningGroup = false;
  bool _isMembersLoading = false;
  bool _isRegeneratingInviteCode = false;
  String? _membersError;
  int? _openingMemberUserId;

  @override
  void initState() {
    super.initState();
    _restoreGroupState();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  int? _parseGroupPositiveInt(dynamic value) {
    if (value is int && value > 0) return value;
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  void _showGroupMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.teal,
      ),
    );
  }

  Future<void> _restoreGroupState() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.get('user_id');
    final userId = _parseGroupPositiveInt(storedUserId);
    final storedGroupId = _parseGroupPositiveInt(prefs.get('group_id'));
    final storedGroupUserId =
        _parseGroupPositiveInt(prefs.get('group_user_id'));
    final storedGroupName = prefs.getString('group_name');
    final storedGroupRole = prefs.getString('group_role');
    final storedInviteCode = prefs.getString('invite_code');

    if (!mounted) return;
    if (userId == null) {
      setState(() {
        _isRestoringGroup = false;
        _membersError = '登入資訊已失效，請重新登入。';
      });
      return;
    }

    final belongsToCurrentUser =
        storedGroupUserId == null || storedGroupUserId == userId;
    setState(() {
      _currentUserId = userId;
      _currentGroupId = belongsToCurrentUser ? storedGroupId : null;
      _currentGroupName = belongsToCurrentUser &&
              storedGroupName != null &&
              storedGroupName.trim().isNotEmpty
          ? storedGroupName.trim()
          : null;
      _currentGroupRole = belongsToCurrentUser &&
              storedGroupRole != null &&
              storedGroupRole.trim().isNotEmpty
          ? storedGroupRole.trim()
          : null;
      _currentInviteCode = belongsToCurrentUser &&
              storedInviteCode != null &&
              storedInviteCode.trim().isNotEmpty
          ? storedInviteCode.trim()
          : null;
    });

    if (belongsToCurrentUser && storedGroupId != null) {
      final loaded = await _fetchGroupMembers(storedGroupId);
      if (!loaded) {
        await _recoverCurrentUserGroup();
      }
    } else {
      await _recoverCurrentUserGroup();
    }

    if (mounted) {
      setState(() => _isRestoringGroup = false);
    }
  }

  Future<void> _persistCurrentGroup(
    int groupId,
    String groupName, {
    required String groupRole,
    String? inviteCode,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('group_id', groupId);
    await prefs.setString('group_name', groupName);
    await prefs.setInt('group_user_id', userId);
    await prefs.setString('group_role', groupRole);
    if (inviteCode != null && inviteCode.trim().isNotEmpty) {
      await prefs.setString('invite_code', inviteCode.trim());
    } else {
      await prefs.remove('invite_code');
    }
  }

  Future<Map<String, dynamic>?> _postGroupRequest(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse('$API_BASE_URL$path'),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 15));

    Map<String, dynamic>? responseData;
    try {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        responseData = Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      debugPrint('Group API response 解析失敗: $e');
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        responseData?['status'] == 'success') {
      return responseData;
    }

    final backendMessage = responseData?['message'];
    if (backendMessage is String && backendMessage.trim().isNotEmpty) {
      throw FormatException(backendMessage.trim());
    }
    return null;
  }

  Map<String, dynamic>? _extractRecoveredGroup(dynamic rawData) {
    dynamic candidate;
    if (rawData == null) return null;

    if (rawData is List) {
      if (rawData.isEmpty) return null;
      if (rawData.length != 1) {
        throw const FormatException('帳號包含多個群組，無法自動判定目前群組');
      }
      candidate = rawData.first;
    } else if (rawData is Map) {
      final data = Map<String, dynamic>.from(rawData);
      if (data.containsKey('group_id')) {
        candidate = data;
      } else if (data['group'] is Map) {
        candidate = data['group'];
      } else if (data.containsKey('group') && data['group'] == null) {
        return null;
      } else if (data['groups'] is List) {
        final groups = data['groups'] as List;
        if (groups.isEmpty) return null;
        if (groups.length != 1) {
          throw const FormatException('帳號包含多個群組，無法自動判定目前群組');
        }
        candidate = groups.first;
      } else if (data.isEmpty || data['has_group'] == false) {
        return null;
      }
    }

    if (candidate is! Map) {
      throw const FormatException('群組資料格式不正確');
    }
    return Map<String, dynamic>.from(candidate);
  }

  Future<void> _clearPersistedGroup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('group_id');
    await prefs.remove('group_name');
    await prefs.remove('group_user_id');
    await prefs.remove('group_role');
    await prefs.remove('invite_code');
  }

  Future<void> _recoverCurrentUserGroup() async {
    final userId = _currentUserId;
    if (userId == null) {
      if (mounted) {
        setState(() => _membersError = '登入資訊已失效，請重新登入');
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isMembersLoading = true;
        _membersError = null;
      });
    }

    String errorMessage = '無法恢復群組資料，請稍後再試';
    try {
      final responseData = await _postGroupRequest(
        '/accounts/api/user/groups/',
        {'user_id': userId},
      );
      if (responseData == null) {
        throw FormatException(errorMessage);
      }

      final group = _extractRecoveredGroup(responseData['data']);
      if (group == null) {
        await _clearPersistedGroup();
        if (!mounted) return;
        setState(() {
          _currentGroupId = null;
          _currentGroupName = null;
          _currentGroupRole = null;
          _currentInviteCode = null;
          _groupMembers = [];
          _isMembersLoading = false;
          _membersError = null;
        });
        return;
      }

      final groupId = _parseGroupPositiveInt(group['group_id']);
      final rawGroupName = group['group_name'];
      final rawGroupRole = group['group_role'];
      final rawInviteCode = group['invite_code'];
      final inviteCode = rawInviteCode is String &&
              rawInviteCode.trim().isNotEmpty
          ? rawInviteCode.trim()
          : null;
      if (groupId == null ||
          rawGroupName is! String ||
          rawGroupName.trim().isEmpty ||
          rawGroupRole is! String ||
          rawGroupRole.trim().isEmpty ||
          (rawInviteCode != null && rawInviteCode is! String)) {
        throw const FormatException('群組資料格式不正確');
      }

      await _persistCurrentGroup(
        groupId,
        rawGroupName.trim(),
        groupRole: rawGroupRole.trim(),
        inviteCode: inviteCode,
      );
      if (!mounted) return;
      setState(() {
        _currentGroupId = groupId;
        _currentGroupName = rawGroupName.trim();
        _currentGroupRole = rawGroupRole.trim();
        _currentInviteCode = inviteCode;
      });
      await _fetchGroupMembers(groupId);
      return;
    } on FormatException catch (e) {
      errorMessage = e.message;
    } catch (e) {
      debugPrint('恢復群組資料失敗: $e');
    }

    if (!mounted) return;
    setState(() {
      _isMembersLoading = false;
      _membersError = errorMessage;
    });
  }

  Future<void> _createGroup() async {
    if (_isCreatingGroup || _isJoiningGroup) return;
    final userId = _currentUserId;
    if (userId == null) {
      _showGroupMessage('登入資訊已失效，請重新登入。', isError: true);
      return;
    }
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      _showGroupMessage('請輸入群組名稱。', isError: true);
      return;
    }

    setState(() => _isCreatingGroup = true);
    String errorMessage = '建立群組失敗，請稍後再試';
    try {
      final responseData = await _postGroupRequest(
        '/accounts/api/group/create/',
        {'user_id': userId, 'group_name': groupName},
      );
      final data = responseData?['data'];
      if (data is Map) {
        final groupId = _parseGroupPositiveInt(data['group_id']);
        final returnedName = data['group_name'];
        final inviteCode = data['invite_code'];
        if (groupId != null &&
            returnedName is String &&
            returnedName.trim().isNotEmpty &&
            inviteCode is String &&
            inviteCode.trim().isNotEmpty) {
          await _persistCurrentGroup(
            groupId,
            returnedName.trim(),
            groupRole: 'owner',
            inviteCode: inviteCode.trim(),
          );
          if (!mounted) return;
          setState(() {
            _currentGroupId = groupId;
            _currentGroupName = returnedName.trim();
            _currentGroupRole = 'owner';
            _currentInviteCode = inviteCode.trim();
            _groupNameController.clear();
          });
          _showGroupMessage(
            responseData?['message'] is String
                ? responseData!['message'].toString()
                : '群組建立成功',
          );
          await _fetchGroupMembers(groupId);
          return;
        }
      }
    } on FormatException catch (e) {
      errorMessage = e.message;
    } catch (e) {
      debugPrint('建立群組失敗: $e');
    } finally {
      if (mounted) setState(() => _isCreatingGroup = false);
    }
    _showGroupMessage(errorMessage, isError: true);
  }

  Future<void> _joinGroup() async {
    if (_isJoiningGroup || _isCreatingGroup) return;
    final userId = _currentUserId;
    if (userId == null) {
      _showGroupMessage('登入資訊已失效，請重新登入。', isError: true);
      return;
    }
    final inviteCode = _inviteCodeController.text.trim().toUpperCase();
    if (inviteCode.isEmpty) {
      _showGroupMessage('請輸入邀請碼。', isError: true);
      return;
    }

    setState(() => _isJoiningGroup = true);
    String errorMessage = '加入群組失敗，請稍後再試';
    try {
      final responseData = await _postGroupRequest(
        '/accounts/api/group/join/',
        {'user_id': userId, 'invite_code': inviteCode},
      );
      final data = responseData?['data'];
      if (data is Map) {
        final groupId = _parseGroupPositiveInt(data['group_id']);
        final returnedName = data['group_name'];
        if (groupId != null &&
            returnedName is String &&
            returnedName.trim().isNotEmpty) {
          await _persistCurrentGroup(
            groupId,
            returnedName.trim(),
            groupRole: 'member',
          );
          if (!mounted) return;
          setState(() {
            _currentGroupId = groupId;
            _currentGroupName = returnedName.trim();
            _currentGroupRole = 'member';
            _currentInviteCode = null;
            _inviteCodeController.clear();
          });
          _showGroupMessage(
            responseData?['message'] is String
                ? responseData!['message'].toString()
                : '加入群組成功',
          );
          await _fetchGroupMembers(groupId);
          return;
        }
      }
    } on FormatException catch (e) {
      errorMessage = e.message;
    } catch (e) {
      debugPrint('加入群組失敗: $e');
    } finally {
      if (mounted) setState(() => _isJoiningGroup = false);
    }
    _showGroupMessage(errorMessage, isError: true);
  }

  Future<bool> _fetchGroupMembers(int groupId) async {
    final userId = _currentUserId;
    if (userId == null || groupId <= 0) {
      if (mounted) {
        setState(() {
          _isMembersLoading = false;
          _membersError = userId == null
              ? '登入資訊已失效，請重新登入。'
              : '無法載入群組成員';
        });
      }
      return false;
    }

    setState(() {
      _isMembersLoading = true;
      _membersError = null;
    });
    String errorMessage = '無法載入群組成員';

    try {
      final responseData = await _postGroupRequest(
        '/accounts/api/group/members/',
        {'user_id': userId, 'group_id': groupId},
      );
      final data = responseData?['data'];
      if (data is Map) {
        final returnedGroupId = _parseGroupPositiveInt(data['group_id']);
        final returnedGroupName = data['group_name'];
        final rawMembers = data['members'];
        final rawInviteCode = data['invite_code'];
        if (returnedGroupId == groupId &&
            returnedGroupName is String &&
            returnedGroupName.trim().isNotEmpty &&
            rawMembers is List) {
          final parsedMembers = <Map<String, dynamic>>[];
          bool hasInvalidMember = false;
          String? requesterRole;
          for (final rawMember in rawMembers) {
            if (rawMember is! Map) {
              hasInvalidMember = true;
              break;
            }
            final member = Map<String, dynamic>.from(rawMember);
            final memberUserId = _parseGroupPositiveInt(member['user_id']);
            final userName = member['user_name'];
            final nickname = member['nickname'];
            final role = member['group_role'];
            final joinedAt = member['joined_at'];
            if (memberUserId == null ||
                userName is! String ||
                userName.trim().isEmpty ||
                role is! String ||
                role.trim().isEmpty ||
                (nickname != null && nickname is! String) ||
                (joinedAt != null && joinedAt is! String)) {
              hasInvalidMember = true;
              break;
            }
            member['user_id'] = memberUserId;
            member['user_name'] = userName.trim();
            member['nickname'] = nickname is String ? nickname.trim() : '';
            member['group_role'] = role.trim();
            member['joined_at'] = joinedAt is String ? joinedAt.trim() : '';
            if (memberUserId == userId) {
              requesterRole = role.trim();
            }
            parsedMembers.add(member);
          }

          if (!hasInvalidMember &&
              requesterRole != null &&
              (rawInviteCode == null || rawInviteCode is String)) {
            final inviteCode = requesterRole == 'owner' &&
                    rawInviteCode is String &&
                    rawInviteCode.trim().isNotEmpty
                ? rawInviteCode.trim()
                : null;
            await _persistCurrentGroup(
              groupId,
              returnedGroupName.trim(),
              groupRole: requesterRole,
              inviteCode: inviteCode,
            );
            if (!mounted || _currentGroupId != groupId) return false;
            setState(() {
              _currentGroupName = returnedGroupName.trim();
              _currentGroupRole = requesterRole;
              _currentInviteCode = inviteCode;
              _groupMembers = parsedMembers;
              _isMembersLoading = false;
              _membersError = null;
            });
            _fetchGroupActivities(groupId);
            return true;
          }
        }
      }
    } on FormatException catch (e) {
      errorMessage = e.message;
    } catch (e) {
      debugPrint('載入群組成員失敗: $e');
    }

    if (!mounted || _currentGroupId != groupId) return false;
    setState(() {
      _isMembersLoading = false;
      _membersError = errorMessage;
    });
    return false;
  }

  Future<void> _fetchGroupActivities(int groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId == null || userId <= 0) return;

      final response = await http.get(
        Uri.parse('$API_BASE_URL/accounts/api/group/$groupId/activities/'),
        headers: {
          'Accept': 'application/json',
          'X-User-Id': userId.toString(),
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        final data = resData['data'];
        if (mounted && data != null) {
          setState(() {
            _overdueCount = data['overdue_count'] ?? 0;
            _groupActivities =
                List<Map<String, dynamic>>.from(data['activities'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint('取得群組服藥動態失敗: $e');
    }
  }

  Future<void> _refreshGroupMembers() async {
    final groupId = _currentGroupId;
    if (groupId == null) {
      await _recoverCurrentUserGroup();
      return;
    }
    _fetchGroupActivities(groupId);
    final loaded = await _fetchGroupMembers(groupId);
    if (!loaded) {
      await _recoverCurrentUserGroup();
    }
  }

  Future<void> _confirmRegenerateInviteCode() async {
    if (_currentGroupRole != 'owner' || _isRegeneratingInviteCode) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重新產生邀請碼'),
        content: const Text('重新產生後，舊邀請碼將失效，確定要繼續嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('確定'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _regenerateInviteCode();
    }
  }

  Future<void> _regenerateInviteCode() async {
    final userId = _currentUserId;
    final groupId = _currentGroupId;
    if (_currentGroupRole != 'owner' || userId == null || groupId == null) {
      return;
    }

    setState(() => _isRegeneratingInviteCode = true);
    String errorMessage = '重新產生邀請碼失敗，請稍後再試';
    try {
      final responseData = await _postGroupRequest(
        '/accounts/api/group/invite_code/',
        {
          'user_id': userId,
          'group_id': groupId,
          'regenerate': true,
        },
      );
      final data = responseData?['data'];
      final rawInviteCode = data is Map
          ? data['invite_code']
          : responseData?['invite_code'];
      if (rawInviteCode is! String || rawInviteCode.trim().isEmpty) {
        throw const FormatException('邀請碼回應格式不正確');
      }

      final inviteCode = rawInviteCode.trim();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('invite_code', inviteCode);
      if (!mounted) return;
      setState(() => _currentInviteCode = inviteCode);
      _showGroupMessage('邀請碼已重新產生');
      return;
    } on FormatException catch (e) {
      errorMessage = e.message;
    } catch (e) {
      debugPrint('重新產生邀請碼失敗: $e');
    } finally {
      if (mounted) setState(() => _isRegeneratingInviteCode = false);
    }
    _showGroupMessage(errorMessage, isError: true);
  }

  Future<void> _openMemberPrescriptions(
    Map<String, dynamic> member,
  ) async {
    final memberUserId = _parseGroupPositiveInt(member['user_id']);
    final currentUserId = _currentUserId;
    if (memberUserId == null ||
        currentUserId == null ||
        _openingMemberUserId != null) {
      return;
    }
    final nickname = member['nickname'];
    final userName = member['user_name'];
    final displayName = nickname is String && nickname.trim().isNotEmpty
        ? nickname.trim()
        : userName.toString();

    setState(() => _openingMemberUserId = memberUserId);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GroupMemberPrescriptionsPage(
            memberUserId: memberUserId,
            currentUserId: currentUserId,
            memberDisplayName: displayName,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingMemberUserId = null);
    }
  }

  Widget _buildGroupInputCard({
    required IconData icon,
    required String title,
    required String description,
    required TextEditingController controller,
    required String hint,
    required String buttonLabel,
    required bool isLoading,
    required VoidCallback onPressed,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    final anyActionLoading = _isCreatingGroup || _isJoiningGroup;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.teal),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              enabled: !anyActionLoading,
              textCapitalization: textCapitalization,
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: Icon(icon, color: Colors.teal),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: anyActionLoading ? null : onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        buttonLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupActivityCard() {
    if (_groupActivities.isEmpty) return const SizedBox.shrink();

    final hasOverdue = _overdueCount > 0;
    final cardBg = hasOverdue ? const Color(0xFFFFF4F2) : const Color(0xFFF0FDF4);
    final borderColor = hasOverdue ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC);
    final titleColor = hasOverdue ? const Color(0xFFDC2626) : const Color(0xFF16A34A);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasOverdue ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                color: titleColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                hasOverdue
                    ? '今日用藥警示 ($_overdueCount 筆逾期未服)'
                    : '今日群組成員用藥動態良好',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: titleColor,
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          ..._groupActivities.map((act) {
            final isOverdue = act['status'] == 'overdue';
            final itemColor = isOverdue ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isOverdue ? Icons.cancel_outlined : Icons.check_circle,
                    size: 16,
                    color: itemColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${act['member_name']}｜${act['drug_name']}：',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      act['message'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: isOverdue ? const Color(0xFFB91C1C) : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final memberUserId = member['user_id'] as int;
    final nickname = member['nickname'] as String;
    final userName = member['user_name'] as String;
    final displayName = nickname.isNotEmpty ? nickname : userName;
    final role = member['group_role'] as String;
    final joinedAt = member['joined_at'] as String;
    final isOpening = _openingMemberUserId == memberUserId;
    final roleLabel = role == 'owner' ? '建立者' : (role == 'member' ? '成員' : role);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.teal.shade50,
              child: const Icon(Icons.person_outline, color: Colors.teal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    roleLabel,
                    style: const TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (joinedAt.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      '加入時間：$joinedAt',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _openingMemberUserId == null
                  ? () => _openMemberPrescriptions(member)
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal,
                side: const BorderSide(color: Colors.teal),
              ),
              child: isOpening
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        color: Colors.teal,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('查看藥單'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal,
        elevation: 0,
        title: const Text(
          '家庭群組',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isRestoringGroup
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _currentGroupId == null
              ? ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    if (_membersError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(13),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _membersError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                    _buildGroupInputCard(
                      icon: Icons.group_add_outlined,
                      title: '建立群組',
                      description: '建立家庭群組，邀請家人一起查看用藥資訊。',
                      controller: _groupNameController,
                      hint: '輸入群組名稱',
                      buttonLabel: '建立',
                      isLoading: _isCreatingGroup,
                      onPressed: _createGroup,
                    ),
                    _buildGroupInputCard(
                      icon: Icons.vpn_key_outlined,
                      title: '加入群組',
                      description: '輸入家人提供的邀請碼。',
                      controller: _inviteCodeController,
                      hint: '輸入邀請碼',
                      buttonLabel: '加入',
                      isLoading: _isJoiningGroup,
                      onPressed: _joinGroup,
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ],
                )
              : RefreshIndicator(
                  color: Colors.teal,
                  onRefresh: _refreshGroupMembers,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(18),
                    children: [
                      Card(
                        elevation: 2,
                        color: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentGroupName ?? '家庭群組',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_currentInviteCode != null ||
                                  _currentGroupRole == 'owner') ...[
                                const SizedBox(height: 12),
                                Text(
                                  _currentInviteCode != null
                                      ? '邀請碼：$_currentInviteCode'
                                      : '邀請碼尚未提供',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    if (_currentInviteCode != null)
                                      TextButton.icon(
                                        onPressed: () async {
                                          await Clipboard.setData(
                                            ClipboardData(
                                              text: _currentInviteCode!,
                                            ),
                                          );
                                          _showGroupMessage('邀請碼已複製');
                                        },
                                        icon: const Icon(
                                          Icons.copy,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          '複製',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    if (_currentGroupRole == 'owner')
                                      TextButton.icon(
                                        onPressed: _isRegeneratingInviteCode
                                            ? null
                                            : _confirmRegenerateInviteCode,
                                        icon: _isRegeneratingInviteCode
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.refresh,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                        label: Text(
                                          _isRegeneratingInviteCode
                                              ? '產生中'
                                              : '重新產生',
                                          style: TextStyle(
                                            color: _isRegeneratingInviteCode
                                                ? Colors.white70
                                                : Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildGroupActivityCard(),
                      const Text(
                        '群組成員',
                        style: TextStyle(
                          color: Colors.teal,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_isMembersLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.teal,
                            ),
                          ),
                        )
                      else if (_membersError != null)
                        Column(
                          children: [
                            Text(
                              _membersError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _refreshGroupMembers,
                              icon: const Icon(Icons.refresh),
                              label: const Text('重新載入'),
                            ),
                          ],
                        )
                      else if (_groupMembers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(child: Text('目前沒有群組成員')),
                        )
                      else
                        ..._groupMembers.map(_buildMemberCard),
                    ],
                  ),
                ),
    );
  }
}

class GroupMemberPrescriptionsPage extends StatefulWidget {
  final int memberUserId;
  final int currentUserId;
  final String memberDisplayName;

  const GroupMemberPrescriptionsPage({
    super.key,
    required this.memberUserId,
    required this.currentUserId,
    required this.memberDisplayName,
  });

  @override
  State<GroupMemberPrescriptionsPage> createState() =>
      _GroupMemberPrescriptionsPageState();
}

class _GroupMemberPrescriptionsPageState
    extends State<GroupMemberPrescriptionsPage> {
  bool _isMemberPrescriptionsLoading = true;
  String? _memberPrescriptionsError;
  List<Map<String, dynamic>> _memberPrescriptions = [];
  int? _openingPrescriptionId;

  @override
  void initState() {
    super.initState();
    _fetchMemberPrescriptions();
  }

  int? _parseMemberPrescriptionInt(dynamic value) {
    if (value is int && value > 0) return value;
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  int? _parseMemberDrugCount(dynamic value) {
    if (value is int && value >= 0) return value;
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed >= 0 ? parsed : null;
  }

  String _formatMemberVisitDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return '${parsed.year}/${parsed.month.toString().padLeft(2, '0')}/'
        '${parsed.day.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchMemberPrescriptions() async {
    if (mounted) {
      setState(() {
        _isMemberPrescriptionsLoading = true;
        _memberPrescriptionsError = null;
      });
    }

    List<Map<String, dynamic>>? loadedPrescriptions;
    String errorMessage = '無法載入此成員的藥單';
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getInt('user_id');
      if (currentUserId == null || currentUserId <= 0) {
        errorMessage = '登入資訊已失效，請重新登入';
        throw const FormatException('missing current user id');
      }
      final response = await http
          .get(
            Uri.parse(
              '$API_BASE_URL/medications/api/prescriptions/${widget.memberUserId}/',
            ),
            headers: {
              'Accept': 'application/json',
              'X-User-Id': currentUserId.toString(),
            },
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic>? responseData;
      try {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        if (decoded is Map) {
          responseData = Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        debugPrint('成員藥單 response 解析失敗: $e');
      }

      final backendMessage = responseData?['message'];
      final rawItems = responseData?['data'];
      final isTransportSuccess =
          response.statusCode >= 200 && response.statusCode < 300;
      if (isTransportSuccess &&
          responseData?['status'] == 'success' &&
          rawItems is List) {
        final parsedItems = <Map<String, dynamic>>[];
        bool hasInvalidItem = false;
        for (final rawItem in rawItems) {
          if (rawItem is! Map) {
            hasInvalidItem = true;
            break;
          }
          final item = Map<String, dynamic>.from(rawItem);
          final prescriptionId =
              _parseMemberPrescriptionInt(item['prescription_id']);
          final hospitalName = item['hospital_name'];
          final visitDate = item['visit_date'];
          final drugCount = _parseMemberDrugCount(item['drug_count']);
          if (prescriptionId == null ||
              hospitalName is! String ||
              hospitalName.trim().isEmpty ||
              visitDate is! String ||
              visitDate.trim().isEmpty ||
              drugCount == null) {
            hasInvalidItem = true;
            break;
          }
          item['prescription_id'] = prescriptionId;
          item['hospital_name'] = hospitalName.trim();
          item['visit_date'] = visitDate.trim();
          item['drug_count'] = drugCount;
          parsedItems.add(item);
        }
        if (!hasInvalidItem) loadedPrescriptions = parsedItems;
      } else if (response.statusCode == 401) {
        errorMessage = '登入資訊已失效，請重新登入';
      } else if (response.statusCode == 403) {
        errorMessage = backendMessage is String &&
                backendMessage.trim().isNotEmpty
            ? backendMessage.trim()
            : '你沒有權限查看此藥單';
      } else if (backendMessage is String &&
          backendMessage.trim().isNotEmpty) {
        errorMessage = backendMessage.trim();
      }
    } on FormatException catch (e) {
      if (e.message != 'missing current user id') {
        debugPrint('群組成員藥單 response 解析失敗: $e');
      }
    } catch (e) {
      debugPrint('載入成員藥單失敗: $e');
    }

    if (!mounted) return;
    setState(() {
      _isMemberPrescriptionsLoading = false;
      if (loadedPrescriptions != null) {
        _memberPrescriptions = loadedPrescriptions!;
        _memberPrescriptionsError = null;
      } else {
        _memberPrescriptionsError = errorMessage;
      }
    });
  }

  Future<void> _openPrescriptionDetail(
    Map<String, dynamic> prescription,
  ) async {
    final prescriptionId =
        _parseMemberPrescriptionInt(prescription['prescription_id']);
    if (prescriptionId == null || _openingPrescriptionId != null) return;

    setState(() => _openingPrescriptionId = prescriptionId);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PrescriptionDetailPage(
            prescription: prescription,
            readOnly: widget.memberUserId != widget.currentUserId,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingPrescriptionId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal,
        elevation: 0,
        title: Text(
          '${widget.memberDisplayName}的藥單',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isMemberPrescriptionsLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _memberPrescriptionsError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          color: Colors.grey,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _memberPrescriptionsError!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _fetchMemberPrescriptions,
                          icon: const Icon(Icons.refresh),
                          label: const Text('重新載入'),
                        ),
                      ],
                    ),
                  ),
                )
              : _memberPrescriptions.isEmpty
                  ? const Center(
                      child: Text(
                        '此成員目前沒有藥單紀錄',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _memberPrescriptions.length,
                      itemBuilder: (context, index) {
                        final prescription = _memberPrescriptions[index];
                        final prescriptionId =
                            prescription['prescription_id'] as int;
                        final isOpening =
                            _openingPrescriptionId == prescriptionId;
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _openingPrescriptionId == null
                                ? () => _openPrescriptionDetail(prescription)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long_outlined,
                                      color: Colors.teal,
                                    ),
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          prescription['hospital_name']
                                              .toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          _formatMemberVisitDate(
                                            prescription['visit_date']
                                                .toString(),
                                          ),
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${prescription['drug_count']} 種藥',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isOpening)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.teal,
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Colors.teal,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  bool _isLoading = true;
  bool _isHealthBankSyncing = false;
  Map<String, dynamic> _profileData = {};
  int _selectedAdherenceDays = 7;
  bool _isAdherenceLoading = true;
  String? _adherenceError;
  Map<String, dynamic>? _adherenceSummary;
  String? _adherenceStartDate;
  String? _adherenceEndDate;
  int _adherenceRequestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _fetchAdherenceStats(7);
  }

  int? _parseAdherenceCount(dynamic value) {
    if (value is int && value >= 0) return value;
    if (value is num && value >= 0 && value == value.roundToDouble()) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null && parsed >= 0) return parsed;
    }
    return null;
  }

  double? _parseAdherenceRate(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (parsed == null || !parsed.isFinite) return null;
    return parsed;
  }

  String? _formatAdherenceDate(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) return null;
    return '${parsed.year}/${parsed.month.toString().padLeft(2, '0')}/'
        '${parsed.day.toString().padLeft(2, '0')}';
  }

  bool _isAdherenceMapList(dynamic value) {
    return value is List && value.every((item) => item is Map);
  }

  Future<void> _fetchAdherenceStats([int? requestedDays]) async {
    final days = requestedDays ?? _selectedAdherenceDays;
    if (!const [7, 14, 30].contains(days)) return;

    final requestGeneration = ++_adherenceRequestGeneration;
    if (mounted) {
      setState(() {
        _selectedAdherenceDays = days;
        _isAdherenceLoading = true;
        _adherenceError = null;
      });
    }

    Map<String, dynamic>? loadedSummary;
    String? loadedStartDate;
    String? loadedEndDate;
    String? errorMessage;

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.get('user_id');
      final userId = storedUserId is int
          ? storedUserId
          : int.tryParse(storedUserId?.toString() ?? '');

      if (userId == null || userId <= 0) {
        errorMessage = '登入資訊已失效，請重新登入。';
      } else {
        final uri = Uri.parse(
          '$API_BASE_URL/medications/api/history/stats/',
        ).replace(
          queryParameters: {
            'user_id': userId.toString(),
            'days': days.toString(),
          },
        );
        final response = await http
            .get(uri, headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 15));

        Map<String, dynamic>? responseData;
        try {
          final decoded = json.decode(utf8.decode(response.bodyBytes));
          if (decoded is Map) {
            responseData = Map<String, dynamic>.from(decoded);
          }
        } catch (e) {
          debugPrint('服藥遵從率 response 解析失敗: $e');
        }

        final backendMessage = responseData?['message'];
        final rawSummary = responseData?['summary'];
        final isTransportSuccess =
            response.statusCode >= 200 && response.statusCode < 300;

        if (isTransportSuccess &&
            responseData?['status'] == 'success' &&
            rawSummary is Map &&
            _isAdherenceMapList(responseData?['daily_stats']) &&
            _isAdherenceMapList(responseData?['recent_history'])) {
          final summary = Map<String, dynamic>.from(rawSummary);
          final totalExpected =
              _parseAdherenceCount(summary['total_expected']);
          final totalTaken = _parseAdherenceCount(summary['total_taken']);
          final totalSkipped =
              _parseAdherenceCount(summary['total_skipped']);
          final totalMissed = _parseAdherenceCount(summary['total_missed']);
          final adherenceRate =
              _parseAdherenceRate(summary['adherence_rate']);
          final rating = summary['rating'];
          final startDate = responseData?['start_date'];
          final endDate = responseData?['end_date'];
          final formattedStartDate = startDate == null
              ? null
              : _formatAdherenceDate(startDate);
          final formattedEndDate =
              endDate == null ? null : _formatAdherenceDate(endDate);

          if (totalExpected != null &&
              totalTaken != null &&
              totalSkipped != null &&
              totalMissed != null &&
              adherenceRate != null &&
              rating is String &&
              rating.trim().isNotEmpty &&
              (startDate == null || formattedStartDate != null) &&
              (endDate == null || formattedEndDate != null)) {
            loadedSummary = {
              'total_expected': totalExpected,
              'total_taken': totalTaken,
              'total_skipped': totalSkipped,
              'total_missed': totalMissed,
              'adherence_rate': adherenceRate,
              'rating': rating.trim(),
            };
            loadedStartDate = formattedStartDate;
            loadedEndDate = formattedEndDate;
          } else {
            errorMessage = '無法載入服藥統計，請稍後再試';
          }
        } else if (backendMessage is String &&
            backendMessage.trim().isNotEmpty) {
          errorMessage = backendMessage.trim();
        } else {
          errorMessage = '無法載入服藥統計，請稍後再試';
        }
      }
    } catch (e) {
      debugPrint('載入服藥遵從率失敗: $e');
      errorMessage = '無法載入服藥統計，請稍後再試';
    }

    if (!mounted || requestGeneration != _adherenceRequestGeneration) return;
    setState(() {
      _isAdherenceLoading = false;
      _adherenceError = errorMessage;
      if (loadedSummary != null) {
        _adherenceSummary = loadedSummary;
        _adherenceStartDate = loadedStartDate;
        _adherenceEndDate = loadedEndDate;
      }
    });
  }

  Future<void> _fetchUserProfile() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('user_id');
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
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
        if (!mounted) return;
        setState(() {
          _profileData = data['data'];
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _showHealthBankConsentDialog() async {
    if (_isHealthBankSyncing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _HealthBankConsentDialog(),
    );

    if (confirmed == true && mounted) {
      await _onHealthBankConsentConfirmed();
    }
  }

  int? _parseHealthBankSyncCount(dynamic value) {
    if (value is int && value >= 0) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null && parsed >= 0) return parsed;
    }
    return null;
  }

  Future<void> _onHealthBankConsentConfirmed() async {
    if (_isHealthBankSyncing || !mounted) return;

    const fallbackError = '健康存摺資料匯入失敗，請稍後再試。';
    String errorMessage = fallbackError;
    String? successMessage;
    int? syncedMedications;
    int? syncedAllergies;

    setState(() => _isHealthBankSyncing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.get('user_id');
      final userId = storedUserId is int
          ? storedUserId
          : int.tryParse(storedUserId?.toString() ?? '');

      if (userId == null || userId <= 0) {
        errorMessage = '登入資訊已失效，請重新登入。';
      } else {
        final response = await http
            .post(
              Uri.parse(
                '$API_BASE_URL/medications/api/v1/health-bank/sync/',
              ),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'user_id': userId}),
            )
            .timeout(const Duration(seconds: 15));

        Map<String, dynamic>? responseData;
        try {
          final decoded = json.decode(utf8.decode(response.bodyBytes));
          if (decoded is Map) {
            responseData = Map<String, dynamic>.from(decoded);
          }
        } catch (e) {
          debugPrint('Health Bank response parse failed: $e');
        }

        final backendMessage = responseData?['message'];
        final hasBackendMessage =
            backendMessage is String && backendMessage.trim().isNotEmpty;
        final isDeclaredSuccess = response.statusCode == 200 &&
            responseData?['status'] == 'success';

        if (isDeclaredSuccess) {
          final medicationCount =
              _parseHealthBankSyncCount(responseData?['synced_medications']);
          final allergyCount =
              _parseHealthBankSyncCount(responseData?['synced_allergies']);

          if (hasBackendMessage &&
              medicationCount != null &&
              allergyCount != null) {
            successMessage = backendMessage;
            syncedMedications = medicationCount;
            syncedAllergies = allergyCount;
          }
        } else if (hasBackendMessage) {
          errorMessage = backendMessage;
        }
      }
    } catch (e) {
      debugPrint('Health Bank sync failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isHealthBankSyncing = false);
      }
    }

    if (!mounted) return;

    if (successMessage != null &&
        syncedMedications != null &&
        syncedAllergies != null) {
      unawaited(_fetchUserProfile());
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.teal, size: 30),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '健康存摺資料匯入完成',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            '$successMessage\n\n'
            '已同步藥歷 $syncedMedications 筆\n'
            '已同步過敏原 $syncedAllergies 筆',
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '完成',
                style: TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildAdherenceMetric(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value 次',
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildAdherenceContent() {
    if (_isAdherenceLoading) {
      return const Card(
        elevation: 1,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 34),
          child: Center(
            child: CircularProgressIndicator(color: Colors.teal),
          ),
        ),
      );
    }

    if (_adherenceError != null) {
      return Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(Icons.insights_outlined, color: Colors.grey.shade500),
              const SizedBox(height: 10),
              Text(
                _adherenceError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    _fetchAdherenceStats(_selectedAdherenceDays),
                icon: const Icon(Icons.refresh),
                label: const Text('重新載入'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: const BorderSide(color: Colors.teal),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _adherenceSummary;
    if (summary == null) {
      return const SizedBox.shrink();
    }

    final totalExpected = summary['total_expected'] as int;
    if (totalExpected == 0) {
      return Card(
        elevation: 1,
        color: const Color(0xFFF7F4FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
          child: Column(
            children: [
              const Icon(
                Icons.event_note_outlined,
                color: Colors.teal,
                size: 38,
              ),
              const SizedBox(height: 10),
              const Text(
                '此期間尚無服藥紀錄',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_adherenceStartDate != null &&
                  _adherenceEndDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  '$_adherenceStartDate ～ $_adherenceEndDate',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final adherenceRate = summary['adherence_rate'] as double;
    final progress = (adherenceRate / 100).clamp(0.0, 1.0).toDouble();
    final rating = summary['rating'] as String;

    return Card(
      elevation: 2,
      color: const Color(0xFFF7F4FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            SizedBox(
              width: 132,
              height: 132,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 11,
                      backgroundColor: Colors.teal.shade100,
                      color: Colors.teal,
                    ),
                  ),
                  Text(
                    '${adherenceRate.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.teal,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '總服藥遵從率',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Chip(
              label: Text(
                rating,
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: Colors.teal.shade50,
              side: BorderSide(color: Colors.teal.shade100),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildAdherenceMetric('應吃', totalExpected, Colors.blueGrey),
                _buildAdherenceMetric(
                  '已吃',
                  summary['total_taken'] as int,
                  Colors.teal,
                ),
                _buildAdherenceMetric(
                  '略過',
                  summary['total_skipped'] as int,
                  Colors.orange,
                ),
                _buildAdherenceMetric(
                  '遺漏',
                  summary['total_missed'] as int,
                  Colors.redAccent,
                ),
              ],
            ),
            if (_adherenceStartDate != null &&
                _adherenceEndDate != null) ...[
              const SizedBox(height: 18),
              Text(
                '$_adherenceStartDate ～ $_adherenceEndDate',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdherenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoSlidingSegmentedControl<int>(
          groupValue: _selectedAdherenceDays,
          backgroundColor: Colors.teal.shade50,
          thumbColor: Colors.teal,
          padding: const EdgeInsets.all(4),
          children: {
            for (final days in const [7, 14, 30])
              days: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '$days 天',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedAdherenceDays == days
                        ? Colors.white
                        : Colors.teal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          },
          onValueChanged: (days) {
            if (days == null || days == _selectedAdherenceDays) return;
            _fetchAdherenceStats(days);
          },
        ),
        const SizedBox(height: 12),
        _buildAdherenceContent(),
      ],
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

    return Stack(
      fit: StackFit.expand,
      children: [
        ListView(
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
        _buildSectionTitle('服藥遵從率'),
        _buildAdherenceSection(),

        const SizedBox(height: 20),
        _buildSectionTitle('家庭群組'),
        Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const FamilyGroupPage(),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.groups_outlined,
                      color: Colors.teal,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '家庭群組',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '建立或加入群組，查看同群組成員藥單',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.teal),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        _buildSectionTitle('緊急聯絡人'),
        _buildInfoCard(Icons.contact_phone, '緊急聯絡人 (家屬)', emergencyPhone, Colors.teal),

        const SizedBox(height: 20),
        _buildSectionTitle('健康存摺'),
        Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap:
                _isHealthBankSyncing ? null : _showHealthBankConsentDialog,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.cloud_download_outlined,
                      color: Colors.teal,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '匯入政府健康存摺資料',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Demo 資料匯入，開始前請閱讀使用聲明',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Colors.teal),
                ],
              ),
            ),
          ),
        ),
            const SizedBox(height: 10),
          ],
        ),
        if (_isHealthBankSyncing) ...[
          const ModalBarrier(
            dismissible: false,
            color: Color(0x66000000),
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text(
                    '正在匯入健康存摺資料…',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
        ValueListenableBuilder<bool>(
          valueListenable: isLargeFontNotifier,
          builder: (context, isLarge, _) {
            return SwitchListTile(
              secondary: const Icon(Icons.format_size, color: Colors.blue),
              title: const Text('大字體模式'),
              subtitle: Text(
                isLarge ? '目前為長輩大字體 (1.28x)' : '目前為標準字體',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              value: isLarge,
              onChanged: (val) {
                isLargeFontNotifier.value = val;
              },
            );
          },
        ),
        _buildGroupTitle('資料管理'),
        ListTile(leading: const Icon(Icons.cloud_upload_outlined, color: Colors.orange), title: const Text('同步雲端資料庫'), onTap: () {}),
        ListTile(leading: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red), title: const Text('匯出服藥紀錄 (PDF)'), onTap: () {}),
        
        _buildGroupTitle('關於系統'),
        const ListTile(leading: Icon(Icons.info_outline), title: Text('版本資訊'), trailing: Text('v1.2.0')),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.grey),
          title: const Text('登出帳號'),
          onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (r) => false),
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
