from django.shortcuts import render

# Create your views here.
import json
import random
import string
from datetime import datetime, timedelta
from django.utils import timezone
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
            requester_member = GroupMember.objects.filter(group=group, user_id=user_id).first()
            if not requester_member:
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

            is_owner = (requester_member.group_role == 'owner')
            return JsonResponse({
                'status': 'success',
                'message': '群組成員列表讀取成功',
                'data': {
                    'group_id': group.group_id,
                    'group_name': group.group_name,
                    'invite_code': group.invite_code if is_owner else None,
                    'members': member_list
                }
            }, status=200)

        except json.JSONDecodeError:
            return JsonResponse({'status': 'error', 'message': 'JSON 格式錯誤'}, status=400)
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': f"系統錯誤: {str(e)}"}, status=500)

    return JsonResponse({'status': 'error', 'message': '僅支援 POST 請求'}, status=405)


# ==========================================
# 取得目前使用者所屬群組列表 API
# ==========================================
@csrf_exempt
def get_user_groups_api(request, user_id=None):
    if request.method not in ['GET', 'POST']:
        return JsonResponse({'status': 'error', 'message': '僅支援 GET 或 POST 請求'}, status=405)

    try:
        data = {}
        if request.method == 'POST' and request.body:
            try:
                data = json.loads(request.body)
            except Exception:
                pass

        uid = user_id or data.get('user_id') or request.GET.get('user_id')
        if not uid:
            auth_header = request.headers.get('Authorization') or request.META.get('HTTP_AUTHORIZATION')
            if auth_header and 'session_token_' in auth_header:
                token = auth_header.split('Bearer ')[-1].strip()
                uid = token.replace('session_token_', '')
            elif request.headers.get('X-User-Id'):
                uid = request.headers.get('X-User-Id')

        if not uid:
            return JsonResponse({'status': 'error', 'message': '缺少 user_id 參數'}, status=400)

        user = User.objects.filter(user_id=uid).first()
        if not user:
            return JsonResponse({'status': 'error', 'message': '找不到該使用者'}, status=404)

        group_memberships = GroupMember.objects.filter(user=user).select_related('group').order_by('-joined_at')

        group_list = []
        for gm in group_memberships:
            g = gm.group
            is_owner = (gm.group_role == 'owner')
            group_list.append({
                'group_id': g.group_id,
                'group_name': g.group_name,
                'group_role': gm.group_role,
                'invite_code': g.invite_code if is_owner else None,
                'joined_at': gm.joined_at.strftime('%Y-%m-%d %H:%M') if gm.joined_at else ''
            })

        return JsonResponse({
            'status': 'success',
            'message': '取得使用者所屬群組成功',
            'data': group_list
        }, status=200)
    except Exception as e:
        return JsonResponse({'status': 'error', 'message': f"系統錯誤: {str(e)}"}, status=500)


# ==========================================
# 群組邀請碼查詢與重新產生 API (限 Owner)
# ==========================================
@csrf_exempt
def manage_invite_code_api(request, group_id=None):
    if request.method not in ['GET', 'POST']:
        return JsonResponse({'status': 'error', 'message': '僅支援 GET 或 POST 請求'}, status=405)

    try:
        data = {}
        if request.body:
            try:
                data = json.loads(request.body)
            except Exception:
                pass

        gid = group_id or data.get('group_id') or request.GET.get('group_id')
        uid = data.get('user_id') or request.GET.get('user_id')
        if not uid:
            auth_header = request.headers.get('Authorization') or request.META.get('HTTP_AUTHORIZATION')
            if auth_header and 'session_token_' in auth_header:
                token = auth_header.split('Bearer ')[-1].strip()
                uid = token.replace('session_token_', '')
            elif request.headers.get('X-User-Id'):
                uid = request.headers.get('X-User-Id')

        if not gid or not uid:
            return JsonResponse({'status': 'error', 'message': '缺少 group_id 或 user_id'}, status=400)

        group = Group.objects.filter(group_id=gid).first()
        if not group:
            return JsonResponse({'status': 'error', 'message': '找不到該群組'}, status=404)

        membership = GroupMember.objects.filter(group=group, user_id=uid).first()
        if not membership:
            return JsonResponse({'status': 'error', 'message': '您不是此群組成員'}, status=403)
        if membership.group_role != 'owner':
            return JsonResponse({'status': 'error', 'message': '權限不足：只有群組建立者 (owner) 才能查看或重設邀請碼'}, status=403)

        regenerate = str(data.get('regenerate', request.GET.get('regenerate', 'false'))).lower() in ['true', '1']
        if regenerate:
            group.invite_code = generate_invite_code()
            group.save(update_fields=['invite_code'])

        return JsonResponse({
            'status': 'success',
            'message': '邀請碼重新產生成功' if regenerate else '邀請碼取得成功',
            'data': {
                'group_id': group.group_id,
                'group_name': group.group_name,
                'invite_code': group.invite_code
            }
        }, status=200)
    except Exception as e:
        return JsonResponse({'status': 'error', 'message': f"系統錯誤: {str(e)}"}, status=500)


def get_authenticated_user_id(request, data=None):
    """
    從 Request Header (Authorization)、Query Param 或 Body 取得 user_id
    支援:
    1. Header: Authorization: Bearer session_token_<user_id> 或 Bearer <user_id>
    2. Header: X-User-Id: <user_id>
    3. Body: {"user_id": <user_id>, ...}
    4. Query Param: ?user_id=<user_id>
    """
    auth_header = request.headers.get('Authorization') or request.META.get('HTTP_AUTHORIZATION')
    if auth_header and auth_header.startswith('Bearer '):
        token = auth_header.split(' ')[1].strip()
        if token.startswith('session_token_'):
            try:
                return int(token.replace('session_token_', ''))
            except ValueError:
                pass
        elif token.isdigit():
            return int(token)

    x_uid = request.headers.get('X-User-Id') or request.META.get('HTTP_X_USER_ID')
    if x_uid and str(x_uid).isdigit():
        return int(x_uid)

    if data and 'user_id' in data:
        try:
            return int(data['user_id'])
        except (ValueError, TypeError):
            pass

    uid = request.GET.get('user_id') or request.POST.get('user_id')
    if uid:
        try:
            return int(uid)
        except (ValueError, TypeError):
            pass

    if hasattr(request, 'user') and request.user and request.user.is_authenticated and hasattr(request.user, 'user_id'):
        return request.user.user_id

    return None


# ==========================================
# 取得群組成員服藥動態 API (今日打卡與逾期未服聚合)
# ==========================================
@csrf_exempt
def get_group_medication_activities_api(request, group_id):
    """
    群組成員服藥動態聚合 API [GET]
    路徑: GET /accounts/api/group/<int:group_id>/activities/
    處理流程:
      1. 安全檢查：確認發出請求的成員是否在此群組內（防越權 IDOR）
      2. 撈取群組成員：找出該群組的所有家人（例如爸爸、媽媽）
      3. 比對今日鬧鐘與打卡：
         - 🟢 已服藥項目 (status: "taken")：今天有打卡記錄 ➡️ 記錄實際吃藥時間（如 12:35）
         - 🔴 逾期未服項目 (status: "overdue")：今天無打卡記錄且現在時間 > 預計服藥時間 + 30 分鐘 ➡️ 標記為逾期未服
      4. 統計 overdue_count、taken_count 並回傳 activities 清單
    """
    if request.method != 'GET':
        return JsonResponse({'status': 'error', 'message': '請使用 GET 方法'}, status=405)

    try:
        # 1. 安全檢查：獲取發起請求的使用者 user_id
        user_id = get_authenticated_user_id(request)
        if not user_id:
            return JsonResponse({
                'status': 'error',
                'message': '缺少必要的使用者驗證資訊 (請帶入 user_id 參數或 Authorization Header)'
            }, status=401)

        # 檢查群組是否存在
        group = Group.objects.filter(group_id=group_id).first()
        if not group:
            return JsonResponse({'status': 'error', 'message': f'找不到編號為 {group_id} 的群組'}, status=404)

        # 防越權檢查：確認請求者是否為該群組成員
        if not GroupMember.objects.filter(group=group, user_id=user_id).exists():
            return JsonResponse({'status': 'error', 'message': '您不是此群組的成員，無權查看成員服藥動態'}, status=403)

        # 2. 撈取群組成員
        group_members = GroupMember.objects.filter(group=group).select_related('user')
        member_user_ids = [gm.user.user_id for gm in group_members]

        # 3. 比對今日鬧鐘與打卡
        today = timezone.localdate()
        now = timezone.localtime()

        from medications.models import Remind, TakingRecord

        # 撈取群組成員有效且未被軟刪除的提醒紀錄 (JOIN prescription_drug, prescription, user)
        reminds = Remind.objects.filter(
            prescription_drug__prescription__user_id__in=member_user_ids,
            is_active=True,
            is_deleted=False
        ).select_related(
            'prescription_drug',
            'prescription_drug__prescription',
            'prescription_drug__prescription__user'
        ).order_by('remind_time')

        # 批次查詢群組成員當日打卡紀錄
        taking_records = TakingRecord.objects.filter(
            remind__in=reminds,
            record_date=today
        ).order_by('-taken_at')

        # 建立 Map: remind_id -> TakingRecord
        records_map = {tr.remind_id: tr for tr in taking_records}

        activities = []

        for remind in reminds:
            p_drug = remind.prescription_drug
            prescription = p_drug.prescription
            member = prescription.user

            # 處方箋有效天數範圍檢查 (start_date ~ end_date)
            start_date = remind.start_date
            end_date = remind.end_date
            if start_date and p_drug.days and p_drug.days > 0:
                if not (start_date <= today <= end_date):
                    continue  # 不在處方給藥天數範圍內，略過

            member_name = member.nickname if member.nickname else member.user_name
            drug_name = p_drug.raw_name
            tag = remind.frequency_tag

            tr = records_map.get(remind.remind_id)

            # 🟢 狀況一：已服藥項目 (status: "taken")
            if tr and tr.status in ['已吃', 'taken', '已服藥']:
                taken_time_str = timezone.localtime(tr.taken_at).strftime('%H:%M') if tr.taken_at else ""
                activities.append({
                    'member_name': member_name,
                    'status': 'taken',
                    'drug_name': drug_name,
                    'taken_at': taken_time_str,
                    'message': f'已於 {taken_time_str} 完成服藥',
                    'tag': tag
                })
                continue

            # 🔴 狀況二：逾期未服項目 (status: "overdue")
            # 條件：今天尚未打卡，且 現在時間 > 預計服藥時間 + 30 分鐘寬限期
            if remind.remind_time:
                naive_dt = datetime.combine(today, remind.remind_time)
                expected_dt = timezone.make_aware(naive_dt, timezone.get_current_timezone())
                grace_dt = expected_dt + timedelta(minutes=30)

                if now > grace_dt:
                    expected_time_str = remind.remind_time.strftime('%H:%M')
                    activities.append({
                        'member_name': member_name,
                        'status': 'overdue',
                        'drug_name': drug_name,
                        'expected_time': expected_time_str,
                        'message': f'預定 {expected_time_str} 服藥，已逾期未吃！',
                        'tag': tag
                    })

        # 計算統計數量
        overdue_count = sum(1 for a in activities if a['status'] == 'overdue')
        taken_count = sum(1 for a in activities if a['status'] == 'taken')

        # 排序：逾期未吃 (overdue) 排在最前面，方便照護者第一時間掌握警報
        activities.sort(key=lambda x: (0 if x['status'] == 'overdue' else 1))

        # 4. 回傳標準結構
        return JsonResponse({
            'status': 'success',
            'data': {
                'overdue_count': overdue_count,
                'taken_count': taken_count,
                'activities': activities
            }
        }, status=200)

    except Exception as e:
        return JsonResponse({'status': 'error', 'message': f'系統錯誤: {str(e)}'}, status=500)
