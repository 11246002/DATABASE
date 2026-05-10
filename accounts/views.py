from django.shortcuts import render

# Create your views here.
import json
import random
import string
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth.hashers import make_password, check_password
from .models import User
from .models import Group, GroupMember

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

            # 正式寫入 User 資料表
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

            # 從資料庫搜尋使用者
            user = User.objects.filter(user_name=user_name).first()

            return JsonResponse({
                'status': 'success',
                'message': '登入成功',
                'data': {
                    'user_id': user.id,
                    'user_name': user.user_name,
                    'role': user.role, 
                    'token': f'session_token_{user.id}'
                }
            }, status=200)
                
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': str(e)}, status=500)


# 產生不重複邀請碼的小工具 (不當作 API，只在後端內部使用)
def generate_invite_code():
    while True:
        code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
        if not GroupMember.objects.filter(invite_code=code).exists():
            return code

# ==========================================
#  建立群組 API 
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

            user = User.objects.filter(id=user_id).first()
            if not user:
                return JsonResponse({'status': 'error', 'message': '找不到該使用者'}, status=404)

            # 步驟一：正式建立群組
            new_group = Group.objects.create(group_name=group_name)

            # 步驟二：發給創立者一張「會員證」，並產生他的專屬邀請碼
            new_invite_code = generate_invite_code()
            GroupMember.objects.create(
                group=new_group,
                user=user,
                invite_code=new_invite_code
            )

            return JsonResponse({
                'status': 'success', 
                'message': '群組建立成功',
                'data': {
                    'group_id': new_group.id,
                    'group_name': new_group.group_name,
                    'invite_code': new_invite_code
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

            user = User.objects.filter(id=user_id).first()
            if not user:
                return JsonResponse({'status': 'error', 'message': '找不到該使用者'}, status=404)


            inviter_member = GroupMember.objects.filter(invite_code=invite_code).first()
            
            if not inviter_member:
                return JsonResponse({'status': 'error', 'message': '無效的邀請碼'}, status=404)

            target_group = inviter_member.group


            if GroupMember.objects.filter(group=target_group, user=user).exists():
                return JsonResponse({'status': 'error', 'message': '您已經在這個群組中了'}, status=400)

            new_invite_code = generate_invite_code()
            GroupMember.objects.create(
                group=target_group,
                user=user,
                invite_code=new_invite_code
            )

            return JsonResponse({
                'status': 'success', 
                'message': f'成功加入 {target_group.group_name}',
                'data': {
                    'group_id': target_group.id,
                    'group_name': target_group.group_name,
                    'my_invite_code': new_invite_code
                }
            }, status=201)
            
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': str(e)}, status=500)