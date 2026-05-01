from django.urls import path
from . import views

urlpatterns = [
    # 網址會是：/accounts/api/register/
    path('api/register/', views.register_api, name='api_register'),
    
    # 網址會是：/accounts/api/login/
    path('api/login/', views.login_api, name='api_login'),
]