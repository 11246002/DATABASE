from django.urls import path
from . import views

urlpatterns = [
    # 當前端呼叫 /api/scan/ 時，交給 views 裡面的 analyze_prescription_api 處理
    path('api/scan/', views.analyze_prescription_api, name='api_scan'),
]