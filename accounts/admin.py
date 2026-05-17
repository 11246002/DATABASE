from django.contrib import admin
from django.contrib.auth.models import Group as AuthGroup # 為了讓後台取消註冊django內建的group先引入並改名
from .models import User, Group, GroupMember


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = (
        'user_id',
        'user_name',
        'nickname',
        'role',
    )


@admin.register(Group)
class GroupAdmin(admin.ModelAdmin):
    list_display = (
        'group_id',
        'group_name',
        'invite_code',
        'created_at',
    )


@admin.register(GroupMember)
class GroupMemberAdmin(admin.ModelAdmin):
    list_display = (
        'user',
        'group',
        'group_role',
        'joined_at',
    )


# 取消註冊 Django 內建的 AuthGroup
admin.site.unregister(AuthGroup)