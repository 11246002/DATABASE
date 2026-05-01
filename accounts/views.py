from django.shortcuts import render

# Create your views here.
import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth.hashers import make_password, check_password

# 🌟 正式匯入同學寫好的 User 模型
from .models import User

# ==========================================
# 使用者註冊 API 
# ==========================================
@csrf_exempt
def register_api(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            user_name = data.get('user_name')
            password = data.get('password')

            if not user_name or not password:
                return JsonResponse({'status': 'error', 'message': '帳號密碼不可為空'}, status=400)

            # 檢查帳號是否重複
            if User.objects.filter(user_name=user_name).exists():
                return JsonResponse({'status': 'error', 'message': '此帳號已被註冊'}, status=400)

            # 密碼加密
            hashed_password = make_password(password)

            # 🌟 正式寫入 User 資料表
            new_user = User.objects.create(
                user_name=user_name,
                password=hashed_password
            )

            return JsonResponse({
                'status': 'success', 
                'message': '註冊成功',
                'user_id': new_user.id
            }, status=201)
            
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': str(e)}, status=500)

# ==========================================
# 使用者登入 API 
# ==========================================
@csrf_exempt
def login_api(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            user_name = data.get('user_name')
            password = data.get('password')

            # 🌟 從資料庫搜尋使用者
            user = User.objects.filter(user_name=user_name).first()

            if user and check_password(password, user.password):
                # 這裡目前維持簡單的角色分流邏輯
                role = 'admin' if user.user_name == 'admin' else 'user'
                
                return JsonResponse({
                    'status': 'success',
                    'message': '登入成功',
                    'data': {
                        'user_id': user.id,
                        'user_name': user.user_name,
                        'role': role,
                        'token': f'session_token_{user.id}' # 暫時用 ID 當作簡單權杖
                    }
                }, status=200)
            else:
                return JsonResponse({'status': 'error', 'message': '帳號或密碼錯誤'}, status=401)
                
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': str(e)}, status=500)