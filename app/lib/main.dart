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
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.teal, Colors.tealAccent])
        ),
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
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('註冊新帳號')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          children: [
<<<<<<< HEAD
            const TextField(decoration: InputDecoration(labelText: '真實姓名')),
=======
            const TextField(decoration: InputDecoration(labelText: '名字', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            const TextField(decoration: InputDecoration(labelText: '帳號', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            const TextField(obscureText: true, decoration: InputDecoration(labelText: '密碼', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            const TextField(obscureText: true, decoration: InputDecoration(labelText: '再次輸入密碼', border: OutlineInputBorder())),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                child: const Text('完成註冊'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 4. 個人資料頁面 ---
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String selectedGender = '男';
  final TextEditingController groupCodeController = TextEditingController();

  void showFinalSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: const Text('註冊已全部完成！\n現在將引導您前往登入頁面。', textAlign: TextAlign.center),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context); 
                Navigator.pushAndRemoveUntil(
                  context, 
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false
                );
              },
              child: const Text('好，去登入'),
            ),
          ),
        ],
      ),
    );
  }

  void showGroupCodeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('加入群組'),
        content: TextField(
          controller: groupCodeController,
          decoration: const InputDecoration(
            hintText: "請輸入群組代碼",
            border: UnderlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
              showFinalSuccessDialog(); 
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('填寫個人資料')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('基本資料', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
>>>>>>> 8b2d049c2c1a2be420fa6b3e248f0955c0ac2134
            const SizedBox(height: 20),
            const TextField(decoration: InputDecoration(labelText: '帳號設定')),
            const SizedBox(height: 20),
            const TextField(obscureText: true, decoration: InputDecoration(labelText: '密碼')),
            const SizedBox(height: 20),
            const TextField(decoration: InputDecoration(labelText: '緊急聯絡人電話')),
            const SizedBox(height: 40),
            SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('提交註冊'))),
          ],
        ),
      ),
    );
  }
}

// --- 頁面 5: 主功能導覽頁面 ---
class MainAppPage extends StatefulWidget {
  const MainAppPage({super.key});
  @override
  State<MainAppPage> createState() => _MainAppPageState();
}

class _MainAppPageState extends State<MainAppPage> {
  int _selectedIndex = 2;

  final List<Widget> _pages = [
    const ReminderSettingsPage(),
    const MyMedicationBagPage(),
    const AddPrescriptionPage(),
    const AppSettingsPage(),
    const UserProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('智慧藥管家'), automaticallyImplyLeading: false, elevation: 0),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.alarm), label: '提醒'),
          BottomNavigationBarItem(icon: Icon(Icons.medical_services), label: '藥袋'),
          BottomNavigationBarItem(icon: Icon(Icons.document_scanner), label: '加入'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '設定'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '資料'),
        ],
      ),
    );
  }
}

// --- 【我的藥袋】診所列表 ---
class MyMedicationBagPage extends StatefulWidget {
  const MyMedicationBagPage({super.key});
  @override
  State<MyMedicationBagPage> createState() => _MyMedicationBagPageState();
}

class _MyMedicationBagPageState extends State<MyMedicationBagPage> {
  final List<Map<String, dynamic>> clinicData = [
    {
      'name': '北商大聯合診所',
      'meds': [
        {'name': '普拿疼', 'info': '用於緩解疼痛、發燒。每日三次。', 'dose': '500mg'},
        {'name': '胃乳', 'info': '保護胃壁，飯前服用。', 'dose': '1包'},
      ]
    },
    {
      'name': '新竹台大醫院',
      'meds': [
        {'name': '阿斯匹靈', 'info': '抗血栓藥物，飯後服用。', 'dose': '100mg'},
      ]
    }
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: clinicData.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: SizedBox(
            width: double.infinity,
            height: 70,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.teal,
                side: const BorderSide(color: Colors.teal, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => MedicationListPage(clinic: clinicData[index]),
                ));
              },
              child: Text(clinicData[index]['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }
}

// --- 【我的藥袋】藥品清單 (左上角加入、右滑刪除) ---
class MedicationListPage extends StatefulWidget {
  final Map<String, dynamic> clinic;
  const MedicationListPage({super.key, required this.clinic});
  @override
  State<MedicationListPage> createState() => _MedicationListPageState();
}

class _MedicationListPageState extends State<MedicationListPage> {
  void _addMedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增藥品紀錄'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: InputDecoration(labelText: '藥品名稱')),
            TextField(decoration: InputDecoration(labelText: '劑量')),
            TextField(decoration: InputDecoration(labelText: '備註/副作用說明')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('加入')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.clinic['name']),
        leading: IconButton(icon: const Icon(Icons.add), onPressed: _addMedDialog),
        backgroundColor: Colors.teal,
      ),
      body: ListView.builder(
        itemCount: widget.clinic['meds'].length,
        itemBuilder: (context, index) {
          final med = widget.clinic['meds'][index];
          return Dismissible(
            key: Key(med['name']),
            direction: DismissDirection.startToEnd,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (dir) => setState(() => widget.clinic['meds'].removeAt(index)),
            child: ListTile(
              title: Text(med['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(med['dose']),
              onTap: () {
                showDialog(context: context, builder: (context) => AlertDialog(
                  title: Text(med['name']),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  content: Text(med['info']),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉'))],
                ));
              },
            ),
          );
        },
      ),
    );
  }
}

// --- 【提醒設定】中間彈出滾輪 ---
class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key});
  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  List<Map<String, dynamic>> reminders = [
    {'freq': '一天三次', 'times': ['08:00', '12:00', '18:00'], 'meds': ['普拿疼', '胃乳']},
    {'freq': '一天一次', 'times': ['21:00'], 'meds': ['阿斯匹靈']}
  ];

  void _showTimePicker(int groupIndex, int timeIndex) {
    final timeParts = reminders[groupIndex]['times'][timeIndex].split(':');
    final initialDateTime = DateTime(2026, 1, 1, int.parse(timeParts[0]), int.parse(timeParts[1]));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            height: 350,
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    '設置 ${reminders[groupIndex]['freq']} - 第 ${timeIndex + 1} 劑',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: initialDateTime,
                    use24hFormat: true,
                    onDateTimeChanged: (DateTime newDate) {
                      setState(() {
                        String hour = newDate.hour.toString().padLeft(2, '0');
                        String minute = newDate.minute.toString().padLeft(2, '0');
                        reminders[groupIndex]['times'][timeIndex] = "$hour:$minute";
                      });
                    },
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                      child: const Text('完成', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                )
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
        title: const Text('請選擇要修改的劑次'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(times.length, (i) => ListTile(
              leading: const Icon(Icons.access_time, color: Colors.teal),
              title: Text('第 ${i + 1} 劑 (${times[i]})'),
              onTap: () {
                Navigator.pop(context);
                _showTimePicker(groupIndex, i);
              },
            )),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reminders.length,
      itemBuilder: (context, index) {
        final item = reminders[index];
        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item['freq'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.grey),
                      onPressed: () {
                        if (item['times'].length == 1) {
                          _showTimePicker(index, 0);
                        } else {
                          _showMenu(context, index, item['times']);
                        }
                      }
                    ),
                  ],
                ),
                const Divider(),
                ...item['meds'].map((m) => Text('• $m', style: const TextStyle(fontSize: 16))),
                const SizedBox(height: 10),
                const Text('設定提醒時間：', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Wrap(
                  spacing: 8,
                  children: List.generate(item['times'].length, (timeIndex) {
                    return ActionChip(
                      label: Text(item['times'][timeIndex]),
                      onPressed: () => _showTimePicker(index, timeIndex),
                      backgroundColor: Colors.teal.withOpacity(0.1),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- 🌟 個人資料頁面 ---
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

// --- 🌟 設定頁面 ---
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

// --- 【藥單加入】 ---
class AddPrescriptionPage extends StatefulWidget {
  const AddPrescriptionPage({super.key});
  @override
  State<AddPrescriptionPage> createState() => _AddPrescriptionPageState();
}

class _AddPrescriptionPageState extends State<AddPrescriptionPage> {
  CameraController? _controller;
  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      _controller = CameraController(cameras[0], ResolutionPreset.high);
      _controller!.initialize().then((_) { if (mounted) setState(() {}); });
    }
  }
  @override
<<<<<<< HEAD
  void dispose() { _controller?.dispose(); super.dispose(); }
=======
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // --- 🌟 完美支援 Web 與手機版的流程控制 ---
  Future<void> _processImage(XFile image) async {
    if (kIsWeb) {
      // 如果是 Chrome 網頁版：直接跳過裁切，上傳給伺服器
      debugPrint('目前為網頁版，跳過裁切，直接上傳...');
      _uploadAndAnalyze(image); 
    } else {
      // 如果是真實的手機 App：呼叫裁切畫面
      debugPrint('目前為手機版，進入裁切畫面');
      _cropImage(image.path);
    }
  }

  // 從相簿選擇圖片
  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _processImage(image);
    }
  }

  // 拍照
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

  // --- 裁切圖片 (只有手機版會執行到這裡) ---
  Future<void> _cropImage(String filePath) async {
    try {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: filePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '裁切藥單', 
            toolbarColor: Colors.teal, 
            toolbarWidgetColor: Colors.white, 
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [CropAspectRatioPreset.original, CropAspectRatioPreset.square, CropAspectRatioPreset.ratio4x3],
          ), 
          IOSUiSettings(
            title: '裁切藥單',
            aspectRatioPresets: [CropAspectRatioPreset.original, CropAspectRatioPreset.square, CropAspectRatioPreset.ratio4x3],
          ),
        ],
      );

      if (croppedFile != null) {
        debugPrint('圖片裁切完成！檔案路徑: ${croppedFile.path}');
        // 手機版裁切完後，把 CroppedFile 轉成 XFile 丟給上傳 API
        _uploadAndAnalyze(XFile(croppedFile.path));
      }
    } catch (e) {
      debugPrint('裁切圖片失敗: $e');
    }
  }

  // --- 🌟 完美支援 Web 與手機的上傳 API ---
  Future<void> _uploadAndAnalyze(XFile imageFile) async { 
    _showLoadingDialog();

    var apiUrl = Uri.parse('http://127.0.0.1:8000/medications/api/scan/');

    try {
      var request = http.MultipartRequest('POST', apiUrl);
      
      // 根據平台選擇打包圖片的方式
      if (kIsWeb) {
        // 網頁版必須用 Bytes 傳送
        var bytes = await imageFile.readAsBytes(); 
        var pic = http.MultipartFile.fromBytes(
          'prescription_img', 
          bytes, 
          filename: imageFile.name, 
        );
        request.files.add(pic);
      } else {
        // 手機版可以直接用檔案路徑傳送
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
        debugPrint('伺服器錯誤: $responseData');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('伺服器錯誤，請稍後再試！'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); 
      debugPrint('網路連線錯誤: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('連線到伺服器失敗: $e'), backgroundColor: Colors.red));
    }
  }

  // --- 顯示轉圈圈的 Dialog ---
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.teal),
              SizedBox(height: 20),
              Text("正在進行 AI 辨識...", style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Text("正在與伺服器連線中", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  // --- 辨識結果確認視窗 ---
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
              Text('辨識結果確認', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView( 
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('系統在您的藥單上找到以下藥品：', style: TextStyle(fontSize: 15)),
                const SizedBox(height: 15),
                
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: drugsData.isEmpty 
                      ? [const Text('未能辨識出任何藥品', style: TextStyle(color: Colors.red))]
                      : drugsData.map((drug) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              '• ${drug['raw_name']} (${drug['frequency']}, ${drug['total_amount']})', 
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                            ),
                          );
                        }).toList(),
                  ),
                ),
                const SizedBox(height: 15),
                const Text('請問以上結果是否正確？', style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          actionsAlignment: MainAxisAlignment.spaceEvenly, 
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); 
              },
              icon: const Icon(Icons.close),
              label: const Text('錯誤'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
              ),
            ),
            
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); 
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ 準備進行資料庫存檔'), backgroundColor: Colors.teal),
                );
              },
              icon: const Icon(Icons.check),
              label: const Text('正確'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

>>>>>>> 8b2d049c2c1a2be420fa6b3e248f0955c0ac2134
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('請將藥單對準框內', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 300, height: 400,
            decoration: BoxDecoration(border: Border.all(color: Colors.teal, width: 3), borderRadius: BorderRadius.circular(20)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: (_controller != null && _controller!.value.isInitialized) ? CameraPreview(_controller!) : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.camera_alt),
          label: const Text('開始掃描', style: TextStyle(fontSize: 18)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
        ),
      ],
    );
  }
}
