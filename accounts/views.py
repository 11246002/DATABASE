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

# ==========================================
# 取得使用者資料 API
# ==========================================
@csrf_exempt
def get_user_profile_api(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            user_id = data.get('user_id')

            if not user_id:
                return JsonResponse({'status': 'error', 'message': '缺少 user_id'}, status=400)

            # 尋找使用者
            user = User.objects.filter(user_id=user_id).first()
            if not user:
                return JsonResponse({'status': 'error', 'message': '找不到該使用者'}, status=404)

            # 把所有前端需要的個人資料包裝起來回傳
            return JsonResponse({
                'status': 'success',
                'message': '個人資料讀取成功',
                'data': {
                    'user_id': user.user_id,
                    'user_name': user.user_name,
                    'nickname': user.nickname,
                    'gender': user.gender,
                    'height': user.height,
                    'weight': user.weight,
                    'allergies': user.allergies,
                    'emergency_contact_phone': user.emergency_contact_phone
                }
            }, status=200)

        except json.JSONDecodeError:
            return JsonResponse({'status': 'error', 'message': 'JSON 格式錯誤'}, status=400)
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': f"系統錯誤: {str(e)}"}, status=500)

    return JsonResponse({'status': 'error', 'message': '僅支援 POST 請求'}, status=405)

# ==========================================
# 修改使用者資料 API (支援局部更新)
# ==========================================
@csrf_exempt
def update_user_profile_api(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            user_id = data.get('user_id')

            if not user_id:
                return JsonResponse({'status': 'error', 'message': '缺少 user_id'}, status=400)

            user = User.objects.filter(user_id=user_id).first()
            if not user:
                return JsonResponse({'status': 'error', 'message': '找不到該使用者'}, status=404)

            if 'nickname' in data:
                user.nickname = data['nickname']
            if 'gender' in data:
                user.gender = data['gender']
            if 'height' in data:
                user.height = data['height']
            if 'weight' in data:
                user.weight = data['weight']
            if 'allergies' in data:
                user.allergies = data['allergies']
            if 'emergency_contact_phone' in data:
                user.emergency_contact_phone = data['emergency_contact_phone']

            user.save()

            return JsonResponse({
                'status': 'success',
                'message': '個人資料更新成功！',
                'data': {
                    'user_id': user.user_id,
                    'user_name': user.user_name,
                    'nickname': user.nickname,
                    }
            }, status=200)

        except json.JSONDecodeError:
            return JsonResponse({'status': 'error', 'message': 'JSON 格式錯誤'}, status=400)
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': f"系統錯誤: {str(e)}"}, status=500)

    return JsonResponse({'status': 'error', 'message': '僅支援 POST 請求'}, status=405)


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
        
# ==========================================
# 取得群組成員列表 API
# ==========================================
@csrf_exempt
def get_group_members_api(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            # 🌟 雙重驗證：要知道是「誰」想看「哪個群組」
            user_id = data.get('user_id')
            group_id = data.get('group_id')

            if not user_id or not group_id:
                return JsonResponse({'status': 'error', 'message': '缺少 user_id 或 group_id'}, status=400)

            # 1. 檢查群組是否存在
            group = Group.objects.filter(group_id=group_id).first()
            if not group:
                return JsonResponse({'status': 'error', 'message': '找不到該群組'}, status=404)

            # 2. 資安防護：檢查發送請求的人，是不是這個群組的成員
            is_member = GroupMember.objects.filter(group=group, user_id=user_id).exists()
            if not is_member:
                return JsonResponse({'status': 'error', 'message': '您不是此群組的成員，無權查看'}, status=403)

            # 3. 撈出群組內所有成員
            # 🌟 效能優化：使用 select_related('user') 一次把 User 表格的資料也抓出來
            members = GroupMember.objects.filter(group=group).select_related('user').order_by('joined_at')

            member_list = []
            for m in members:
                # 貼心設計：如果該使用者沒有填寫暱稱，就退而求其次顯示他的帳號名稱
                display_name = m.user.nickname if m.user.nickname else m.user.user_name

                member_list.append({
                    'user_id': m.user.user_id,
                    'user_name': m.user.user_name,
                    'nickname': display_name,
                    'group_role': m.group_role,
                    'joined_at': m.joined_at.strftime('%Y-%m-%d %H:%M') if m.joined_at else ''
                })

            return JsonResponse({
                'status': 'success',
                'message': '群組成員列表讀取成功',
                'data': {
                    'group_id': group.group_id,
                    'group_name': group.group_name,
                    'members': member_list
                }
            }, status=200)

        except json.JSONDecodeError:
            return JsonResponse({'status': 'error', 'message': 'JSON 格式錯誤'}, status=400)
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': f"系統錯誤: {str(e)}"}, status=500)

    return JsonResponse({'status': 'error', 'message': '僅支援 POST 請求'}, status=405)