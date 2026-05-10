from django.urls import path
from . import views

urlpatterns = [
    # 網址會是：/accounts/api/register/
    path('api/register/', views.register_api, name='api_register'),
    path('api/login/', views.login_api, name='api_login'),
    path('api/group/create/', views.create_group_api, name='api_create_group'),
    path('api/group/join/', views.join_group_api, name='api_join_group'),
]