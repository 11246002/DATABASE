import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: WelcomePage(),
  ));
}

// --- 1. 歡迎頁面 ---
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('藥物系統')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage())), child: const Text('登入')),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage())), child: const Text('註冊')),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 2. 登入頁面 ---
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('會員登入')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const TextField(decoration: InputDecoration(labelText: '帳號', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            const TextField(obscureText: true, decoration: InputDecoration(labelText: '密碼', border: OutlineInputBorder())),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MainAppPage())), child: const Text('登入進入系統')),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 3. 註冊頁面 ---
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('註冊新帳號')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
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

  // 最終步驟：顯示「註冊完成」的訊息框，按下才跳轉登入
  void showFinalSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: const Text('註冊手續已全部完成！\n現在將引導您前往登入頁面。', textAlign: TextAlign.center),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context); // 關閉此視窗
                // 真正跳轉回登入頁
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

  // 顯示群組代碼輸入框的視窗
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
              Navigator.pop(context); // 關閉輸入代碼視窗
              showFinalSuccessDialog(); // 跳到最後一個成功視窗
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
            const SizedBox(height: 20),
            const TextField(decoration: InputDecoration(labelText: '暱稱', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            const Text('性別', style: TextStyle(fontSize: 16)),
            Row(
              children: [
                Radio(value: '男', groupValue: selectedGender, onChanged: (val) => setState(() => selectedGender = val!)),
                const Text('男'),
                const SizedBox(width: 20),
                Radio(value: '女', groupValue: selectedGender, onChanged: (val) => setState(() => selectedGender = val!)),
                const Text('女'),
              ],
            ),
            const SizedBox(height: 20),
            const TextField(decoration: InputDecoration(labelText: '其他資訊 1', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            const TextField(decoration: InputDecoration(labelText: '其他資訊 2', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            const TextField(decoration: InputDecoration(labelText: '其他資訊 3', border: OutlineInputBorder())),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('註冊成功'),
                      content: const Text('是否需要加入藥物討論群組？'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); // 關閉詢問視窗
                            showFinalSuccessDialog(); // 直接跳到最後一個成功視窗
                          }, 
                          child: const Text('否')
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); 
                            showGroupCodeDialog(); // 跳到代碼輸入
                          }, 
                          child: const Text('是')
                        ),
                      ],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                child: const Text('註冊完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 5. 主功能空頁面 ---
class MainAppPage extends StatelessWidget {
  const MainAppPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('藥物辨識主系統'), automaticallyImplyLeading: false),
      body: const Center(child: Text('歡迎使用系統！')),
    );
  }
}