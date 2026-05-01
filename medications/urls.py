from django.urls import path
from . import views

urlpatterns = [
    # 第一階段：辨識藥單 (對應你 views.py 裡的第一個函數)
    path('api/scan/', views.analyze_prescription_api, name='api_scan'),
    
    # 第二階段：確認並存檔 (對應你 views.py 裡的第二個函數)
    path('api/confirm_and_save/', views.confirm_and_save_prescription_api, name='api_confirm_and_save'),
]