from django.contrib import admin
from django.contrib.auth.models import Group as AuthGroup # 為了讓後台取消註冊django內建的group先引入並改名
from .models import User, Group, GroupMember

admin.site.register(User)
admin.site.register(Group)         
admin.site.register(GroupMember)


# 取消註冊 Django 內建的 AuthGroup
admin.site.unregister(AuthGroup)