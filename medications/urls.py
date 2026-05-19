from django.urls import path
from . import views
from . import reminders
from . import history

urlpatterns = [
    # 辨識藥單 
    path('api/scan/', views.analyze_prescription_api, name='api_scan'),
    
    # 確認並存檔 
    path('api/confirm_and_save/', views.confirm_and_save_prescription_api, name='api_confirm_and_save'),

    # 取得使用者的藥單列表
    path('api/prescriptions/<int:user_id>/', views.get_user_prescriptions_api, name='api_get_user_prescriptions'),
    
    # 取得特定藥單的詳情 
    path('api/prescription_details/<int:prescription_id>/', views.get_prescription_detail_api, name='api_get_prescription_detail'),

    # 手動新增藥單 
    path('api/prescriptions/create/', views.create_manual_prescription_api, name='api_create_manual_prescription'),

    # 手動更新藥單 
    path('api/prescriptions/<int:prescription_id>/update/', views.update_prescription_api, name='api_update_prescription'),

    # 手動新增藥品紀錄到某張藥單 
    path('api/prescriptions/<int:prescription_id>/add_drug/', views.add_single_drug_api, name='api_add_single_drug'),

   # 刪除整張藥單 
    path('api/prescriptions/<int:prescription_id>/delete/', views.delete_prescription_api, name='api_delete_prescription'),

    # 刪除藥單中的某一顆藥品紀錄
    path('api/prescriptions/drug/<int:pd_id>/delete/', views.delete_single_drug_api, name='api_delete_single_drug'),

    # 用藥安全檢查
    path('api/check_all_safety/', views.check_all_medications_safety_api, name='check_all_safety'),

    # 設定吃藥提醒的 
    path('api/reminders/set/', reminders.set_medication_reminder, name='set_reminder'),

    # 吃藥紀錄回報 
    path('api/history/record/', history.record_taking_status, name='record_taking_status'),
]