from django.shortcuts import render

# Create your views here.
import json
import random
import string
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth.hashers import make_password, check_password
from .models import User, Group, GroupMember

# ==========================================
# 一般使用者註冊 API 
# ==========================================
@csrf_exempt
def register_api(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            user_name = data.get('user_name')
            password = data.get('password')
            nickname = data.get('nickname')
            gender = data.get('gender')
            height = data.get('height')
            weight = data.get('weight')
            allergies = data.get('allergies')
            emergency_contact_phone = data.get('emergency_contact_phone')

            if not user_name or not password:
                return JsonResponse({'status': 'error', 'message': '帳號密碼不可為空'}, status=400)

            # 檢查帳號是否重複
            if User.objects.filter(user_name=user_name).exists():
                return JsonResponse({'status': 'error', 'message': '此帳號已被註冊'}, status=400)

            # 呼叫 create_user！自動處理密碼雜湊加密，還有其他底層邏輯
            new_user = User.objects.create_user(
                user_name=user_name,
                password=password, 
                nickname=nickname,
                gender=gender,
                height=height,
                weight=weight,
                allergies=allergies,
                emergency_contact_phone=emergency_contact_phone
            )

            return JsonResponse({
                'status': 'success', 
                'message': '註冊成功',
                'user_id': new_user.user_id
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

            # 從資料庫搜尋使用者
            user = User.objects.filter(user_name=user_name).first()

            if not user:
                return JsonResponse({'status': 'error', 'message': '帳號不存在'}, status=404)

            # 驗證密碼
            if not check_password(password, user.password):
                return JsonResponse({'status': 'error', 'message': '密碼錯誤'}, status=401)

            # 登入成功，回傳基本資料給前端 
            return JsonResponse({
                'status': 'success',
                'message': '登入成功',
                'data': {
                    'user_id': user.user_id,
                    'user_name': user.user_name,
                    'role': user.role, 
                    'nickname': user.nickname, 
                    'token': f'session_token_{user.user_id}' # 備註：這是暫時的假 Token，之後建議換成 JWT
                }
            }, status=200)
                
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': str(e)}, status=500)


# 產生不重複邀請碼的小工具 (不當作 API，只在後端內部使用)
def generate_invite_code():
    while True:
        code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
        if not Group.objects.filter(invite_code=code).exists():
            return code

# ==========================================
# 建立群組 API 
# ==========================================
@csrf_exempt
def create_group_api(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            user_id = data.get('user_id')   
            group_name = data.get('group_name')

            if not user_id or not group_name:
                return JsonResponse({'status': 'error', 'message': '缺少必要參數'}, status=400)

            user = User.objects.filter(user_id=user_id).first()
            if not user:
                return JsonResponse({'status': 'error', 'message': '找不到該使用者'}, status=404)

            # 產生唯一邀請碼，並建立群組
            new_invite_code = generate_invite_code()
            new_group = Group.objects.create(
                group_name=group_name,
                invite_code=new_invite_code
            )

            # 建立關聯，並將創立者設為 'owner'
            GroupMember.objects.create(
                group=new_group,
                user=user,
                group_role='owner' 
            )

            return JsonResponse({
                'status': 'success', 
                'message': '群組建立成功',
                'data': {
                    'group_id': new_group.group_id,
                    'group_name': new_group.group_name,
                    'invite_code': new_group.invite_code
                }
            }, status=201)
            
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': str(e)}, status=500)

# ==========================================
# 加入群組 API 
# ==========================================
@csrf_exempt
def join_group_api(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            user_id = data.get('user_id')         
            invite_code = data.get('invite_code') 

            if not user_id or not invite_code:
                return JsonResponse({'status': 'error', 'message': '缺少必要參數'}, status=400)

            user = User.objects.filter(user_id=user_id).first()
            if not user:
                return JsonResponse({'status': 'error', 'message': '找不到該使用者'}, status=404)

            target_group = Group.objects.filter(invite_code=invite_code).first()
            
            if not target_group:
                return JsonResponse({'status': 'error', 'message': '無效的邀請碼'}, status=404)

            if GroupMember.objects.filter(group=target_group, user=user).exists():
                return JsonResponse({'status': 'error', 'message': '您已經在這個群組中了'}, status=400)

            # 建立成員關聯，身分設為 'member'
            GroupMember.objects.create(
                group=target_group,
                user=user,
                group_role='member'
            )

            return JsonResponse({
                'status': 'success', 
                'message': f'成功加入 {target_group.group_name}',
                'data': {
                    'group_id': target_group.group_id,
                    'group_name': target_group.group_name
                }
            }, status=201)
            
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': str(e)}, status=500)