from django.urls import path
from . import views

urlpatterns = [
    # 使用者註冊
    path('api/register/', views.register_api, name='api_register'),

    # 使用者登入
    path('api/login/', views.login_api, name='api_login'),

    # 建立群組
    path('api/group/create/', views.create_group_api, name='api_create_group'),

    # 加入群組
    path('api/group/join/', views.join_group_api, name='api_join_group'),
]