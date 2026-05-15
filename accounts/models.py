from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager

# 專屬管理員製造機 (UserManager)
# 負責處理「建立帳號」與「密碼加密」的底層邏輯
class UserManager(BaseUserManager):
    def create_user(self, user_name, password=None, **extra_fields):
        if not user_name:
            raise ValueError('一定要填寫帳號 (user_name)')
        user = self.model(user_name=user_name, **extra_fields)
        user.set_password(password)  # 這裡會自動幫密碼進行雜湊加密！
        user.save(using=self._db)
        return user

    def create_superuser(self, user_name, password=None, **extra_fields):
        # 建立超級管理員時，自動把 role 設為 sys_admin
        extra_fields.setdefault('role', 'sys_admin') 
        return self.create_user(user_name, password, **extra_fields)


class User(AbstractBaseUser):
    user_id = models.AutoField(primary_key=True)
    user_name = models.CharField(max_length=50, unique=True) # 帳號必須唯一
    # password 欄位 AbstractBaseUser 已內建

    role = models.CharField(max_length=20, default='user')
    nickname = models.CharField(max_length=50, blank=True, null=True)
    gender = models.CharField(max_length=2, blank=True, null=True)
    height = models.FloatField(blank=True, null=True)
    weight = models.FloatField(blank=True, null=True)
    allergies = models.TextField(blank=True, null=True)
    emergency_contact_phone = models.CharField(max_length=20, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    # 綁定剛剛寫好的製造機
    objects = UserManager()

    # 告訴 Django 系統的核心設定
    USERNAME_FIELD = 'user_name'  # 用這個欄位當帳號登入
    REQUIRED_FIELDS = []          # 終端機建立時不強制要求填身高體重

    def __str__(self):
        return self.user_name

    # 以下是能順利登入 Django 網頁後台的必備通行證
    @property
    def is_staff(self):
        return self.role == 'sys_admin'

    @property
    def is_superuser(self):
        return self.role == 'sys_admin'

    def has_perm(self, perm, obj=None):
        return True

    def has_module_perms(self, app_label):
        return True

class Group(models.Model):
    group_id = models.AutoField(primary_key=True)
    group_name = models.CharField(max_length=100)
    created_at = models.DateTimeField(auto_now_add=True)
    invite_code = models.CharField(max_length=10, unique=True)

    def __str__(self):
        return self.group_name
    

class GroupMember(models.Model):
    group = models.ForeignKey(Group, on_delete=models.CASCADE)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    joined_at = models.DateTimeField(auto_now_add=True)
    group_role = models.CharField(max_length=20, default='member')
    

    def __str__(self):
        return f"{self.user} in {self.group}"
